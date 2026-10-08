class_name V47Manager
extends Node
## Mandala VR v47/v48 : Tir Mandala.
##
## v48 :
## - page Tir dediee dans Experiences ;
## - tir a deux mains ;
## - cibles qui se divisent ;
## - cibles a bouclier rotatif ;
## - vagues couleur : ne tirer que la couleur indiquee ;
## - vagues 360 degres ;
## - boss mandala avec 8 points faibles.
##
## Aucun texte descriptif n'apparait au milieu de la vue.
## Le HUD utile reste discret sur la main gauche.

const TYPE_NORMAL: int = 0
const TYPE_RAPIDE: int = 1
const TYPE_BLINDEE: int = 2
const TYPE_BOMBE: int = 3
const TYPE_DIVISEE: int = 4
const TYPE_BOUCLIER: int = 5

const MAX_TARGETS: int = 18
const BURST_SLOTS: int = 10
const PETALS: int = 12
const BURST_INSTANCES: int = BURST_SLOTS * PETALS
const BOSS_WEAKPOINTS: int = 8

var app = null
var v26 = null
var v31 = null
var v32 = null
var v33 = null
var v46 = null

var _installe: bool = false
var _actif: bool = false
var _running: bool = false
var _paused: bool = false

var _root: Node3D = null
var _targets_root: Node3D = null
var _targets: Array = []
var _target_mats: Array = []
var _color_mats: Array = []

var _burst_node: MultiMeshInstance3D = null
var _burst_mm: MultiMesh = null
var _burst_mat: StandardMaterial3D = null
var _bursts: Array = []

var _laser_d: MeshInstance3D = null
var _laser_g: MeshInstance3D = null
var _laser_mat: StandardMaterial3D = null
var _laser_t_d: float = 0.0
var _laser_t_g: float = 0.0

var _hud: Label3D = null
var _status_label: Label = null

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _trigger_d_was: bool = false
var _trigger_g_was: bool = false

var _score: int = 0
var _best_score: int = 0
var _combo: int = 0
var _lives: int = 5
var _wave: int = 1
var _wave_t: float = 0.0
var _game_t: float = 0.0
var _spawn_t: float = 0.0
var _spawn_serial: int = 0
var _wanted_color: int = 0

# Boss
var _boss_root: Node3D = null
var _boss_core: MeshInstance3D = null
var _boss_ring: MeshInstance3D = null
var _boss_shield: Node3D = null
var _boss_weakpoints: Array = []
var _boss_active: bool = false
var _boss_t: float = 0.0

# 0 Zen, 1 Arcade, 2 Chaos
var _difficulty: int = 1
var _spawn_base: float = 0.78
var _speed_base: float = 5.0
var _max_alive: int = 11
var _start_lives: int = 5

var _origin_xf: Transform3D = Transform3D()
var _snapshot: Dictionary = {}


func _ready() -> void:
	app = get_parent()
	v26 = app.get_node_or_null("V26Manager")
	v31 = app.get_node_or_null("V31Manager")
	v32 = app.get_node_or_null("V32Manager")
	v33 = app.get_node_or_null("V33Manager")
	v46 = app.get_node_or_null("V46Manager")
	process_priority = 400
	_rng.randomize()


func _process(dt: float) -> void:
	if app == null:
		return

	if not _installe:
		var ready_ok: bool = (
			app.panneau != null
			and app.camera != null
			and app.main_d != null
			and app.main_g != null
			and v26 != null and bool(v26.get("_installe"))
			and v32 != null and bool(v32.get("_installe"))
			and v33 != null and bool(v33.get("_installe"))
			and v46 != null and bool(v46.get("_installe"))
		)
		if ready_ok:
			_installer()
		return

	if not _actif:
		return

	# Le Main traite ses entrees avant nous. On neutralise ensuite le mouvement
	# libre et les snap-turns pour garder l'arene parfaitement stable.
	app.origine.global_transform = _origin_xf

	var trigger_d: bool = app.main_d.get_float("trigger") > 0.55
	var trigger_g: bool = app.main_g.get_float("trigger") > 0.55
	var shot_d: bool = trigger_d and not _trigger_d_was
	var shot_g: bool = trigger_g and not _trigger_g_was
	_trigger_d_was = trigger_d
	_trigger_g_was = trigger_g

	_paused = app.panneau.visible

	var main_ray_v: Variant = app.get("_rayon")
	var main_cursor_v: Variant = app.get("_curseur")

	if not _paused:
		if main_ray_v is GeometryInstance3D:
			(main_ray_v as GeometryInstance3D).visible = false
		if main_cursor_v is GeometryInstance3D:
			(main_cursor_v as GeometryInstance3D).visible = false
	else:
		if main_ray_v is GeometryInstance3D:
			(main_ray_v as GeometryInstance3D).visible = bool(_snapshot.get("ray_visible", true))

	if _paused:
		if _laser_d != null:
			_laser_d.visible = false
		if _laser_g != null:
			_laser_g.visible = false
		return

	if _running:
		_game_t += dt

		if _boss_active:
			_update_boss(dt)
		else:
			_wave_t += dt
			if _wave_t >= 16.0:
				_wave_t -= 16.0
				_wave += 1
				_wanted_color = posmod(int(_wave / 4) - 1, 3)
				if _wave % 5 == 0:
					_start_boss()

			if not _boss_active:
				_spawn_t -= dt
				if _spawn_t <= 0.0:
					_spawn_target()
					var accel: float = pow(0.94, float(_wave - 1))
					_spawn_t = maxf(0.25, _spawn_base * accel)

				_update_targets(dt)

		if shot_d:
			_shoot_from(app.main_d, 0)
		if shot_g:
			_shoot_from(app.main_g, 1)
	else:
		if shot_d or shot_g:
			_start_round()

	_update_bursts(dt)
	_update_lasers(dt)
	_update_hud()


# =====================================================================
# Installation / interface

func _installer() -> void:
	_installe = true
	_build_game()
	_build_ui()
	_add_home_card()


func _build_ui() -> void:
	var p: VBoxContainer = app.panneau._page("Tir")

	app.panneau._titre(p, "Tir Mandala")
	app.panneau._note(
		p,
		"Deux gachettes pour tirer. Les cibles rapides sont nerveuses, les blindees demandent 3 impacts, les bombes nettoient une zone, les vertes se divisent et les violettes ont un bouclier rotatif. Certaines vagues demandent de ne tirer que la couleur affichee sur le HUD. Tous les 5 niveaux, un boss mandala arrive.")

	var diffs: HBoxContainer = app.panneau._rangee(p)
	app.panneau._bouton(diffs, "Zen", func() -> void: _set_difficulty(0))
	app.panneau._bouton(diffs, "Arcade", func() -> void: _set_difficulty(1))
	app.panneau._bouton(diffs, "Chaos", func() -> void: _set_difficulty(2))

	var actions: HBoxContainer = app.panneau._rangee(p)
	app.panneau._bouton(actions, "JOUER", demarrer)
	app.panneau._bouton(actions, "Arreter", arreter)
	if v32 != null and v32.has_method("_aller_accueil"):
		app.panneau._bouton(actions, "Retour Accueil", Callable(v32, "_aller_accueil"))

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 22)
	p.add_child(_status_label)
	_update_menu_status()


func _add_home_card() -> void:
	if v32 == null or not v32.has_method("_carte"):
		return

	var page_v: Variant = v32.get("_page_accueil")
	if not (page_v is VBoxContainer):
		return

	var page: VBoxContainer = page_v
	var grid: GridContainer = null
	for c in page.get_children():
		if c is GridContainer:
			grid = c
			break
	if grid == null:
		return

	v32.call(
		"_carte",
		grid,
		"TIR MANDALA\nCibles, combos, boss et 360 degres",
		Color(0.18, 0.62, 0.76),
		Callable(self, "demarrer"))


func _set_difficulty(i: int) -> void:
	_difficulty = clampi(i, 0, 2)
	match _difficulty:
		0:
			_spawn_base = 1.08
			_speed_base = 3.7
			_max_alive = 8
			_start_lives = 7
		1:
			_spawn_base = 0.78
			_speed_base = 5.0
			_max_alive = 11
			_start_lives = 5
		_:
			_spawn_base = 0.54
			_speed_base = 6.3
			_max_alive = 15
			_start_lives = 4
	_update_menu_status()


func _update_menu_status() -> void:
	if _status_label == null:
		return
	var noms: Array = ["ZEN", "ARCADE", "CHAOS"]
	var etat: String = "En cours" if _running else ("Pret" if not _actif else "Fin de partie")
	_status_label.text = "Mode %s  |  %s  |  meilleur score : %d" % [
		str(noms[_difficulty]), etat, _best_score]


# =====================================================================
# Construction visuelle

func _mat(c: Color, energy: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = Color(c.r, c.g, c.b, 1.0)
	m.emission_energy_multiplier = energy
	return m


func _build_game() -> void:
	_root = Node3D.new()
	_root.name = "V48TirMandala"
	_root.visible = false
	app.origine.add_child(_root)

	_target_mats = [
		_mat(Color(0.18, 0.78, 1.0, 0.88), 2.7),
		_mat(Color(1.0, 0.26, 0.82, 0.90), 3.0),
		_mat(Color(1.0, 0.72, 0.18, 0.92), 2.8),
		_mat(Color(1.0, 0.22, 0.12, 0.94), 3.2),
		_mat(Color(0.18, 1.0, 0.52, 0.90), 2.9),
		_mat(Color(0.66, 0.28, 1.0, 0.92), 3.0),
	]
	_color_mats = [
		_mat(Color(0.14, 0.74, 1.0, 0.92), 3.0),
		_mat(Color(1.0, 0.28, 0.78, 0.92), 3.0),
		_mat(Color(1.0, 0.72, 0.16, 0.94), 3.0),
	]

	_targets_root = Node3D.new()
	_targets_root.name = "Targets"
	_root.add_child(_targets_root)

	for i in MAX_TARGETS:
		var n: Node3D = Node3D.new()
		n.name = "Target" + str(i)
		n.visible = false
		_targets_root.add_child(n)

		var ring: MeshInstance3D = MeshInstance3D.new()
		var tor: TorusMesh = TorusMesh.new()
		tor.inner_radius = 0.43
		tor.outer_radius = 0.62
		tor.rings = 28
		tor.ring_segments = 8
		ring.mesh = tor
		ring.rotation.x = PI * 0.5
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(ring)

		var core: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.16
		sm.height = 0.32
		core.mesh = sm
		core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(core)

		var shield: Node3D = Node3D.new()
		shield.name = "Shield"
		shield.visible = false
		n.add_child(shield)

		for k in 3:
			var seg: MeshInstance3D = MeshInstance3D.new()
			var bm: BoxMesh = BoxMesh.new()
			bm.size = Vector3(0.62, 0.10, 0.10)
			seg.mesh = bm
			seg.material_override = _target_mats[TYPE_BOUCLIER]
			seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var a: float = TAU * float(k) / 3.0
			seg.position = Vector3(cos(a) * 0.68, sin(a) * 0.68, 0.0)
			seg.rotation.z = a + PI * 0.5
			shield.add_child(seg)

		_targets.append({
			"node": n,
			"ring": ring,
			"core": core,
			"shield": shield,
			"active": false,
			"type": TYPE_NORMAL,
			"hp": 1,
			"speed": 5.0,
			"radius": 0.66,
			"scale_base": 1.0,
			"base_x": 0.0,
			"base_y": 0.0,
			"phase": 0.0,
			"weave": 0.2,
			"flash": 0.0,
			"color_id": 0,
			"radial_360": false,
		})

	_build_bursts()
	_build_lasers()
	_build_hud()
	_build_boss()


func _build_bursts() -> void:
	var petal: SphereMesh = SphereMesh.new()
	petal.radius = 0.055
	petal.height = 0.18
	_burst_mat = _mat(Color(0.70, 0.34, 1.0, 0.82), 3.1)
	petal.material = _burst_mat

	_burst_mm = MultiMesh.new()
	_burst_mm.transform_format = MultiMesh.TRANSFORM_3D
	_burst_mm.instance_count = BURST_INSTANCES
	_burst_mm.mesh = petal

	_burst_node = MultiMeshInstance3D.new()
	_burst_node.name = "MandalaBursts"
	_burst_node.multimesh = _burst_mm
	_burst_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_burst_node.extra_cull_margin = 120.0
	_root.add_child(_burst_node)

	for i in BURST_SLOTS:
		_bursts.append({
			"active": false,
			"t": 0.0,
			"pos": Vector3.ZERO,
			"strength": 1.0,
		})

	_clear_bursts()


func _make_laser(parent: Node3D, nom: String) -> MeshInstance3D:
	var laser: MeshInstance3D = MeshInstance3D.new()
	laser.name = nom
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.012, 0.012, 1.0)
	bm.material = _laser_mat
	laser.mesh = bm
	laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	laser.visible = false
	parent.add_child(laser)

	var muzzle: MeshInstance3D = MeshInstance3D.new()
	var tor: TorusMesh = TorusMesh.new()
	tor.inner_radius = 0.055
	tor.outer_radius = 0.070
	tor.rings = 20
	tor.ring_segments = 6
	muzzle.mesh = tor
	muzzle.rotation.x = PI * 0.5
	muzzle.position = Vector3(0.0, 0.0, -0.09)
	muzzle.material_override = _laser_mat
	muzzle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(muzzle)

	return laser


func _build_lasers() -> void:
	_laser_mat = _mat(Color(0.42, 0.92, 1.0, 0.90), 4.0)
	_laser_d = _make_laser(app.main_d, "TirLaserD")
	_laser_g = _make_laser(app.main_g, "TirLaserG")


func _build_hud() -> void:
	_hud = Label3D.new()
	_hud.name = "TirHUD"
	_hud.pixel_size = 0.00082
	_hud.font_size = 34
	_hud.outline_size = 8
	_hud.no_depth_test = true
	_hud.render_priority = 30
	_hud.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hud.modulate = Color(0.78, 0.94, 1.0)
	_hud.position = Vector3(0.0, 0.08, -0.13)
	_hud.visible = false
	app.main_g.add_child(_hud)


func _build_boss() -> void:
	_boss_root = Node3D.new()
	_boss_root.name = "BossMandala"
	_boss_root.visible = false
	_root.add_child(_boss_root)

	_boss_ring = MeshInstance3D.new()
	var tor: TorusMesh = TorusMesh.new()
	tor.inner_radius = 1.85
	tor.outer_radius = 2.15
	tor.rings = 40
	tor.ring_segments = 10
	_boss_ring.mesh = tor
	_boss_ring.rotation.x = PI * 0.5
	_boss_ring.material_override = _target_mats[TYPE_BOUCLIER]
	_boss_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_boss_root.add_child(_boss_ring)

	_boss_core = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.52
	sm.height = 1.04
	_boss_core.mesh = sm
	_boss_core.material_override = _target_mats[TYPE_BOMBE]
	_boss_core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_boss_root.add_child(_boss_core)

	_boss_shield = Node3D.new()
	_boss_shield.name = "BossShield"
	_boss_root.add_child(_boss_shield)

	for k in 4:
		var bar: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(1.85, 0.08, 0.08)
		bar.mesh = bm
		bar.material_override = _target_mats[TYPE_BOUCLIER]
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a: float = TAU * float(k) / 4.0
		bar.position = Vector3(cos(a) * 2.65, sin(a) * 2.65, 0.0)
		bar.rotation.z = a + PI * 0.5
		_boss_shield.add_child(bar)

	for i in BOSS_WEAKPOINTS:
		var wp: MeshInstance3D = MeshInstance3D.new()
		wp.name = "Weak" + str(i)
		var ws: SphereMesh = SphereMesh.new()
		ws.radius = 0.24
		ws.height = 0.48
		wp.mesh = ws
		wp.material_override = _color_mats[i % 3]
		wp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var a: float = TAU * float(i) / float(BOSS_WEAKPOINTS)
		wp.position = Vector3(cos(a) * 1.48, sin(a) * 1.48, -0.10)
		_boss_root.add_child(wp)
		_boss_weakpoints.append({
			"node": wp,
			"active": true,
			"hp": 2,
		})


# =====================================================================
# Demarrage / arret

func demarrer() -> void:
	call_deferred("_demarrer_differe")


func _demarrer_differe() -> void:
	if _actif and _running:
		if app.panneau.visible:
			app.basculer_panneau()
		return

	if v32 != null and v32.has_method("arreter_mort"):
		v32.call("arreter_mort")
	if v31 != null and bool(v31.get("_actif")):
		v31.call("arreter")
	if v33 != null and bool(v33.get("_actif")):
		v33.call("arreter")
	app.diff_stop()

	var main_hud_v: Variant = app.get("_hud")
	var main_msg_v: Variant = app.get("_msg_label")
	var main_help_v: Variant = app.get("_aide")
	var main_ray_v: Variant = app.get("_rayon")

	_snapshot = {
		"sc_visible": app.sc.visible,
		"sc_transform": app.sc.global_transform,
		"sol_visible": app.sol.visible,
		"main_hud_visible": (main_hud_v as Node3D).visible if main_hud_v is Node3D else true,
		"msg_visible": (main_msg_v as Node3D).visible if main_msg_v is Node3D else true,
		"help_visible": (main_help_v as Node3D).visible if main_help_v is Node3D else true,
		"ray_visible": (main_ray_v as Node3D).visible if main_ray_v is Node3D else true,
		"left_pose": str(app.main_g.pose),
	}

	app.sc.visible = false
	app.sc.global_position = Vector3(0.0, -1000.0, 0.0)
	app.sol.visible = false

	if main_hud_v is Node3D:
		(main_hud_v as Node3D).visible = false
	if main_msg_v is Node3D:
		(main_msg_v as Node3D).visible = false
	if main_help_v is Node3D:
		(main_help_v as Node3D).visible = false

	_origin_xf = app.origine.global_transform
	app.main_g.pose = &"aim"

	var forward: Vector3 = -app.camera.global_transform.basis.z
	forward.y = 0.0
	if forward.length() < 0.01:
		forward = Vector3(0.0, 0.0, -1.0)
	forward = forward.normalized()
	var basis: Basis = Basis.looking_at(forward, Vector3.UP)
	_root.global_transform = Transform3D(basis, app.camera.global_position)
	_root.visible = true
	_hud.visible = true

	_actif = true
	_trigger_d_was = app.main_d.get_float("trigger") > 0.55
	_trigger_g_was = app.main_g.get_float("trigger") > 0.55
	_start_round()

	if app.panneau.visible:
		app.basculer_panneau()

	_update_menu_status()


func arreter() -> void:
	if not _actif:
		return

	_actif = false
	_running = false
	_paused = false
	_root.visible = false
	_hud.visible = false
	_laser_d.visible = false
	_laser_g.visible = false
	_boss_root.visible = false
	_boss_active = false
	_disable_all_targets()

	if not _snapshot.is_empty():
		app.origine.global_transform = _origin_xf
		app.sc.global_transform = _snapshot.get("sc_transform", app.sc.global_transform)
		app.sc.visible = bool(_snapshot.get("sc_visible", true))
		app.sol.visible = bool(_snapshot.get("sol_visible", true))
		app.main_g.pose = StringName(str(_snapshot.get("left_pose", "default")))

		var main_hud_v: Variant = app.get("_hud")
		var main_msg_v: Variant = app.get("_msg_label")
		var main_help_v: Variant = app.get("_aide")
		var main_ray_v: Variant = app.get("_rayon")

		if main_hud_v is Node3D:
			(main_hud_v as Node3D).visible = bool(_snapshot.get("main_hud_visible", true))
		if main_msg_v is Node3D:
			(main_msg_v as Node3D).visible = bool(_snapshot.get("msg_visible", true))
		if main_help_v is Node3D:
			(main_help_v as Node3D).visible = bool(_snapshot.get("help_visible", false))
		if main_ray_v is Node3D:
			(main_ray_v as Node3D).visible = bool(_snapshot.get("ray_visible", true))

	_snapshot = {}
	_update_menu_status()


func _start_round() -> void:
	_score = 0
	_combo = 0
	_lives = _start_lives
	_wave = 1
	_wave_t = 0.0
	_game_t = 0.0
	_spawn_t = 0.15
	_spawn_serial = 0
	_wanted_color = 0
	_running = true
	_boss_active = false
	_boss_t = 0.0
	_boss_root.visible = false
	_disable_all_targets()
	_reset_boss_weakpoints()
	_clear_bursts()
	_update_hud()
	_update_menu_status()


func _game_over() -> void:
	_running = false
	_combo = 0
	_best_score = maxi(_best_score, _score)
	_disable_all_targets()
	_boss_active = false
	_boss_root.visible = false
	_update_hud()
	_update_menu_status()


# =====================================================================
# Regles de vagues

func _precision_wave() -> bool:
	return _wave >= 4 and _wave % 4 == 0 and not _boss_active


func _wave_360() -> bool:
	return _wave >= 6 and _wave % 6 == 0 and not _boss_active


func _free_target() -> int:
	for i in _targets.size():
		var td: Dictionary = _targets[i]
		if not bool(td["active"]):
			return i
	return -1


func _alive_count() -> int:
	var n: int = 0
	for t_v in _targets:
		var t: Dictionary = t_v
		if bool(t["active"]):
			n += 1
	return n


# =====================================================================
# Cibles / vagues

func _spawn_target() -> void:
	if _alive_count() >= _max_alive:
		return

	var index: int = _free_target()
	if index < 0:
		return

	var type_id: int = TYPE_NORMAL
	var r: float = _rng.randf()

	if _wave >= 5 and r < 0.10:
		type_id = TYPE_BOUCLIER
	elif _wave >= 4 and r < 0.22:
		type_id = TYPE_DIVISEE
	elif _wave >= 3 and r < 0.34:
		type_id = TYPE_BOMBE
	elif _wave >= 2 and r < 0.52:
		type_id = TYPE_BLINDEE
	elif _wave >= 2 and r < 0.72:
		type_id = TYPE_RAPIDE

	var color_id: int = _rng.randi_range(0, 2)
	var pos: Vector3 = Vector3.ZERO
	var radial_360: bool = _wave_360()

	if radial_360:
		var yaw: float = _rng.randf_range(-PI, PI)
		var pitch: float = _rng.randf_range(-0.34, 0.34)
		var dist: float = _rng.randf_range(14.0, 21.0)
		var dir: Vector3 = Vector3(
			sin(yaw) * cos(pitch),
			sin(pitch),
			-cos(yaw) * cos(pitch)).normalized()
		pos = dir * dist
	else:
		var angle: float = float(_spawn_serial) * 0.83
		var x: float = 0.0
		var y: float = 0.0
		var pattern: int = _wave % 4

		match pattern:
			0:
				x = _rng.randf_range(-3.2, 3.2)
				y = _rng.randf_range(-1.8, 1.9)
			1:
				var rr: float = 1.0 + float(_spawn_serial % 5) * 0.43
				x = cos(angle) * rr
				y = sin(angle) * rr * 0.72
			2:
				var lanes: Array = [-2.7, -1.35, 0.0, 1.35, 2.7]
				x = float(lanes[_spawn_serial % lanes.size()])
				y = sin(float(_spawn_serial) * 0.92) * 1.5
			_:
				x = sin(float(_spawn_serial) * 0.74) * 3.0
				y = cos(float(_spawn_serial) * 0.48) * 1.65

		pos = Vector3(x, y, -18.0 - _rng.randf_range(0.0, 7.0))

	_activate_target(index, type_id, pos, color_id, radial_360, false)
	_spawn_serial += 1


func _activate_target(
	index: int,
	type_id: int,
	pos: Vector3,
	color_id: int,
	radial_360: bool,
	child: bool
) -> void:
	var speed: float = _speed_base + float(_wave - 1) * 0.30
	var hp: int = 1
	var radius: float = 0.66
	var scale_v: float = 1.0
	var weave: float = 0.22

	match type_id:
		TYPE_RAPIDE:
			speed *= 1.55
			radius = 0.54
			scale_v = 0.78
			weave = 0.90
		TYPE_BLINDEE:
			speed *= 0.80
			hp = 3
			radius = 0.78
			scale_v = 1.18
			weave = 0.12
		TYPE_BOMBE:
			speed *= 0.96
			radius = 0.72
			scale_v = 1.08
			weave = 0.34
		TYPE_DIVISEE:
			speed *= 0.95
			radius = 0.70
			scale_v = 1.04
			weave = 0.42
		TYPE_BOUCLIER:
			speed *= 0.88
			radius = 0.76
			scale_v = 1.10
			weave = 0.30

	if child:
		speed *= 1.18
		radius = 0.40
		scale_v = 0.56
		weave = 0.44

	var t: Dictionary = _targets[index]
	var node: Node3D = t["node"]
	var ring: MeshInstance3D = t["ring"]
	var core: MeshInstance3D = t["core"]
	var shield: Node3D = t["shield"]

	node.position = pos
	node.scale = Vector3.ONE * scale_v
	node.rotation = Vector3.ZERO
	node.visible = true

	# En vague couleur, l'anneau porte la couleur de la regle.
	# Hors vague couleur, on garde une couleur lisible autour du type.
	if _precision_wave():
		ring.material_override = _color_mats[color_id]
	else:
		ring.material_override = _target_mats[type_id]

	core.material_override = _target_mats[type_id]
	shield.visible = type_id == TYPE_BOUCLIER
	shield.rotation = Vector3.ZERO

	t["active"] = true
	t["type"] = type_id
	t["hp"] = hp
	t["speed"] = speed
	t["radius"] = radius
	t["scale_base"] = scale_v
	t["base_x"] = pos.x
	t["base_y"] = pos.y
	t["phase"] = _rng.randf() * TAU
	t["weave"] = weave
	t["flash"] = 0.0
	t["color_id"] = color_id
	t["radial_360"] = radial_360
	_targets[index] = t

	if radial_360:
		node.look_at(_root.global_position, Vector3.UP)


func _update_targets(dt: float) -> void:
	for i in _targets.size():
		var t: Dictionary = _targets[i]
		if not bool(t["active"]):
			continue

		var node: Node3D = t["node"]
		var shield: Node3D = t["shield"]
		var type_id: int = int(t["type"])
		var pos: Vector3 = node.position
		var radial_360: bool = bool(t["radial_360"])

		if radial_360:
			var toward: Vector3 = -pos.normalized()
			pos += toward * float(t["speed"]) * dt
			node.position = pos
			node.look_at(_root.global_position, Vector3.UP)
		else:
			pos.z += float(t["speed"]) * dt

			var weave: float = float(t["weave"])
			var phase: float = float(t["phase"])
			var wiggle_speed: float = 2.1
			if type_id == TYPE_RAPIDE:
				wiggle_speed = 4.4
			elif type_id == TYPE_BOMBE:
				wiggle_speed = 2.8
			elif type_id == TYPE_DIVISEE:
				wiggle_speed = 3.2

			pos.x = float(t["base_x"]) + sin(_game_t * wiggle_speed + phase) * weave
			pos.y = float(t["base_y"]) + cos(
				_game_t * (wiggle_speed * 0.73) + phase) * weave * 0.55
			node.position = pos
			node.rotation.z += dt * (0.8 + float(type_id) * 0.28)

		if type_id == TYPE_BOUCLIER:
			shield.rotation.z = _game_t * 2.15 + float(t["phase"])

		var pulse: float = 1.0 + sin(_game_t * 5.0 + float(t["phase"])) * 0.045
		var flash: float = maxf(0.0, float(t["flash"]) - dt)
		t["flash"] = flash
		if flash > 0.0:
			pulse += 0.16

		node.scale = Vector3.ONE * float(t["scale_base"]) * pulse

		var missed: bool = false
		if radial_360:
			missed = pos.length() < 0.85
		else:
			missed = pos.z > -0.65

		if missed:
			_spawn_burst(pos, 0.65)
			_deactivate_target(i)
			_combo = 0
			_lives -= 1
			_haptic_both(0.22, 0.06)
			if _lives <= 0:
				_game_over()
				return

		_targets[i] = t


func _deactivate_target(i: int) -> void:
	var t: Dictionary = _targets[i]
	t["active"] = false
	var node: Node3D = t["node"]
	node.visible = false
	_targets[i] = t


func _disable_all_targets() -> void:
	for i in _targets.size():
		_deactivate_target(i)


# =====================================================================
# Tir / collision

func _shoot_from(controller: XRController3D, hand: int) -> void:
	var ray_o: Vector3 = controller.global_position
	var ray_d: Vector3 = -controller.global_transform.basis.z
	ray_d = ray_d.normalized()

	# Boss prioritaire.
	if _boss_active:
		var boss_hit: Dictionary = _boss_ray_hit(ray_o, ray_d)
		if not boss_hit.is_empty():
			var length: float = float(boss_hit["t"])
			_hit_boss_weakpoint(int(boss_hit["index"]), controller)
			_show_laser(hand, clampf(length, 0.4, 28.0))
			return

	var best_i: int = -1
	var best_t: float = 9999.0
	var best_hit: Vector3 = Vector3.ZERO

	for i in _targets.size():
		var td: Dictionary = _targets[i]
		if not bool(td["active"]):
			continue

		var node: Node3D = td["node"]
		var centre: Vector3 = node.global_position
		var to_centre: Vector3 = centre - ray_o
		var along: float = to_centre.dot(ray_d)
		if along <= 0.0 or along >= best_t:
			continue

		var closest: Vector3 = ray_o + ray_d * along
		var dist: float = closest.distance_to(centre)
		if dist <= float(td["radius"]):
			best_i = i
			best_t = along
			best_hit = closest

	var laser_len: float = 24.0

	if best_i >= 0:
		laser_len = best_t
		var td: Dictionary = _targets[best_i]

		if int(td["type"]) == TYPE_BOUCLIER and _shield_blocks(td, best_hit):
			_combo = 0
			controller.trigger_haptic_pulse("haptic", 0.0, 0.22, 0.04, 0.0)
		else:
			_hit_target(best_i, controller)
	else:
		_combo = 0
		controller.trigger_haptic_pulse("haptic", 0.0, 0.10, 0.035, 0.0)

	_show_laser(hand, clampf(laser_len, 0.4, 28.0))


func _shield_blocks(t: Dictionary, hit_world: Vector3) -> bool:
	var node: Node3D = t["node"]
	var shield: Node3D = t["shield"]
	var local: Vector3 = node.global_transform.affine_inverse() * hit_world
	var a: float = atan2(local.y, local.x) - shield.rotation.z

	for k in 3:
		var seg: float = TAU * float(k) / 3.0
		var diff: float = absf(wrapf(a - seg, -PI, PI))
		if diff < 0.30:
			return true

	return false


func _hit_target(i: int, controller: XRController3D) -> void:
	var t: Dictionary = _targets[i]
	var type_id: int = int(t["type"])
	var node: Node3D = t["node"]

	# Vagues couleur : une mauvaise couleur ne detruit pas la cible.
	if _precision_wave() and int(t["color_id"]) != _wanted_color:
		_combo = 0
		_score = maxi(0, _score - 50)
		t["flash"] = 0.16
		_targets[i] = t
		controller.trigger_haptic_pulse("haptic", 0.0, 0.16, 0.04, 0.0)
		return

	var hp: int = int(t["hp"]) - 1

	if type_id == TYPE_BLINDEE and hp > 0:
		t["hp"] = hp
		t["flash"] = 0.14
		_targets[i] = t
		_score += 35
		_combo += 1
		controller.trigger_haptic_pulse("haptic", 0.0, 0.28, 0.045, 0.0)
		return

	var pos: Vector3 = node.position
	var strength: float = 1.0
	var base_points: int = 100

	match type_id:
		TYPE_RAPIDE:
			base_points = 180
			strength = 0.85
		TYPE_BLINDEE:
			base_points = 280
			strength = 1.25
		TYPE_BOMBE:
			base_points = 220
			strength = 1.65
		TYPE_DIVISEE:
			base_points = 240
			strength = 1.25
		TYPE_BOUCLIER:
			base_points = 260
			strength = 1.20

	_combo += 1
	var mult: int = mini(5, 1 + int(_combo / 8))
	_score += base_points * mult

	_spawn_burst(pos, strength)
	_deactivate_target(i)
	controller.trigger_haptic_pulse("haptic", 0.0, 0.50, 0.055, 0.0)

	if type_id == TYPE_BOMBE:
		_bomb_area(pos)
	elif type_id == TYPE_DIVISEE:
		_split_target(pos, int(t["color_id"]))


func _split_target(center: Vector3, color_id: int) -> void:
	for side in [-1.0, 1.0]:
		var index: int = _free_target()
		if index < 0:
			return
		var child_pos: Vector3 = center + Vector3(
			0.52 * float(side),
			0.20 * float(side),
			-0.15)
		_activate_target(index, TYPE_RAPIDE, child_pos, color_id, false, true)


func _bomb_area(center: Vector3) -> void:
	var destroyed: int = 0

	for i in _targets.size():
		var t: Dictionary = _targets[i]
		if not bool(t["active"]):
			continue

		var node: Node3D = t["node"]
		if node.position.distance_to(center) <= 4.8:
			_spawn_burst(node.position, 1.10)
			_deactivate_target(i)
			destroyed += 1

	if destroyed > 0:
		_score += destroyed * 140
		_combo += destroyed
		_haptic_both(0.34, 0.07)


func _show_laser(hand: int, length: float) -> void:
	var laser: MeshInstance3D = _laser_d if hand == 0 else _laser_g
	laser.visible = true
	laser.position = Vector3(0.0, 0.0, -length * 0.5)
	laser.scale = Vector3(1.0, 1.0, length)

	if hand == 0:
		_laser_t_d = 0.055
	else:
		_laser_t_g = 0.055


func _update_lasers(dt: float) -> void:
	if _laser_t_d > 0.0:
		_laser_t_d -= dt
		if _laser_t_d <= 0.0:
			_laser_d.visible = false
	else:
		_laser_d.visible = false

	if _laser_t_g > 0.0:
		_laser_t_g -= dt
		if _laser_t_g <= 0.0:
			_laser_g.visible = false
	else:
		_laser_g.visible = false


# =====================================================================
# Boss Mandala

func _reset_boss_weakpoints() -> void:
	for i in _boss_weakpoints.size():
		var d: Dictionary = _boss_weakpoints[i]
		d["active"] = true
		d["hp"] = 2
		var n: MeshInstance3D = d["node"]
		n.visible = true
		_boss_weakpoints[i] = d


func _start_boss() -> void:
	_disable_all_targets()
	_reset_boss_weakpoints()
	_boss_active = true
	_boss_t = 0.0
	_boss_root.visible = true
	_boss_root.position = Vector3(0.0, 0.2, -15.5)
	_boss_root.rotation = Vector3.ZERO
	_haptic_both(0.18, 0.08)


func _update_boss(dt: float) -> void:
	_boss_t += dt
	_boss_root.rotation.z += dt * 0.18
	_boss_shield.rotation.z -= dt * 0.62
	_boss_ring.rotation.z += dt * 0.34

	var approach: float = clampf(_boss_t / 26.0, 0.0, 1.0)
	_boss_root.position.z = lerpf(-15.5, -7.5, approach)
	_boss_root.position.x = sin(_boss_t * 0.42) * 1.25
	_boss_root.position.y = 0.15 + sin(_boss_t * 0.65) * 0.55

	if _boss_t >= 27.0:
		_boss_active = false
		_boss_root.visible = false
		_combo = 0
		_lives -= 2
		_haptic_both(0.42, 0.09)
		if _lives <= 0:
			_game_over()
		else:
			_spawn_t = 0.45
			_wave_t = 0.0


func _boss_ray_hit(ray_o: Vector3, ray_d: Vector3) -> Dictionary:
	var best_i: int = -1
	var best_t: float = 9999.0

	for i in _boss_weakpoints.size():
		var d: Dictionary = _boss_weakpoints[i]
		if not bool(d["active"]):
			continue

		var wp: MeshInstance3D = d["node"]
		var centre: Vector3 = wp.global_position
		var to_centre: Vector3 = centre - ray_o
		var along: float = to_centre.dot(ray_d)
		if along <= 0.0 or along >= best_t:
			continue

		var closest: Vector3 = ray_o + ray_d * along
		if closest.distance_to(centre) <= 0.30:
			best_i = i
			best_t = along

	if best_i < 0:
		return {}

	return {"index": best_i, "t": best_t}


func _hit_boss_weakpoint(i: int, controller: XRController3D) -> void:
	var d: Dictionary = _boss_weakpoints[i]
	if not bool(d["active"]):
		return

	var hp: int = int(d["hp"]) - 1
	d["hp"] = hp
	var wp: MeshInstance3D = d["node"]

	if hp > 0:
		_score += 80
		controller.trigger_haptic_pulse("haptic", 0.0, 0.30, 0.045, 0.0)
	else:
		d["active"] = false
		wp.visible = false
		_score += 320
		_combo += 2
		_spawn_burst(_root.to_local(wp.global_position), 1.15)
		controller.trigger_haptic_pulse("haptic", 0.0, 0.52, 0.06, 0.0)

	_boss_weakpoints[i] = d

	for x_v in _boss_weakpoints:
		var x: Dictionary = x_v
		if bool(x["active"]):
			return

	_boss_defeat()


func _boss_defeat() -> void:
	_spawn_burst(_boss_root.position, 2.45)
	_spawn_burst(_boss_root.position + Vector3(0.8, 0.4, 0.0), 1.65)
	_spawn_burst(_boss_root.position + Vector3(-0.8, -0.4, 0.0), 1.65)
	_score += 2500 + _wave * 120
	_combo += 8
	_boss_active = false
	_boss_root.visible = false
	_spawn_t = 0.35
	_wave_t = 0.0
	_haptic_both(0.62, 0.11)


# =====================================================================
# Explosions mandala

func _spawn_burst(pos: Vector3, strength: float) -> void:
	var slot: int = -1

	for i in _bursts.size():
		var b: Dictionary = _bursts[i]
		if not bool(b["active"]):
			slot = i
			break

	if slot < 0:
		var max_t: float = -1.0
		for i in _bursts.size():
			var age: float = float((_bursts[i] as Dictionary)["t"])
			if age > max_t:
				max_t = age
				slot = i

	var burst: Dictionary = _bursts[slot]
	burst["active"] = true
	burst["t"] = 0.0
	burst["pos"] = pos
	burst["strength"] = strength
	_bursts[slot] = burst


func _update_bursts(dt: float) -> void:
	for slot in BURST_SLOTS:
		var burst: Dictionary = _bursts[slot]
		var start: int = slot * PETALS

		if not bool(burst["active"]):
			for j in PETALS:
				_burst_mm.set_instance_transform(
					start + j,
					Transform3D(
						Basis().scaled(Vector3.ONE * 0.001),
						Vector3(0.0, -100.0, 0.0)))
			continue

		var t: float = float(burst["t"]) + dt
		burst["t"] = t
		var duration: float = 0.78
		var p: float = clampf(t / duration, 0.0, 1.0)
		var strength: float = float(burst["strength"])
		var centre: Vector3 = burst["pos"]

		if p >= 1.0:
			burst["active"] = false
			_bursts[slot] = burst
			continue

		var radius: float = (0.18 + p * 1.45) * strength
		var petal_scale: float = sin(PI * p) * (0.75 + strength * 0.28)
		var spin: float = p * 1.35

		for j in PETALS:
			var a: float = TAU * float(j) / float(PETALS) + spin
			var radial: Vector3 = Vector3(
				cos(a),
				sin(a),
				sin(a * 2.0) * 0.08)
			var pos: Vector3 = centre + radial * radius

			var bb: Basis = Basis(Vector3.FORWARD, a)
			bb = bb.scaled(Vector3(
				maxf(0.001, petal_scale * 0.70),
				maxf(0.001, petal_scale * 1.75),
				maxf(0.001, petal_scale * 0.70)))
			_burst_mm.set_instance_transform(start + j, Transform3D(bb, pos))

		_bursts[slot] = burst


func _clear_bursts() -> void:
	for i in _bursts.size():
		var b: Dictionary = _bursts[i]
		b["active"] = false
		b["t"] = 0.0
		_bursts[i] = b

	for i in BURST_INSTANCES:
		_burst_mm.set_instance_transform(
			i,
			Transform3D(
				Basis().scaled(Vector3.ONE * 0.001),
				Vector3(0.0, -100.0, 0.0)))


# =====================================================================
# HUD / haptique

func _update_hud() -> void:
	if _hud == null:
		return

	if not _running:
		_hud.text = "FIN  %d\nMeilleur %d\nGachette : rejouer" % [_score, _best_score]
		return

	var hearts: String = ""
	for i in _lives:
		hearts += "◆"

	var extra: String = ""
	if _boss_active:
		var left: int = 0
		for d_v in _boss_weakpoints:
			var d: Dictionary = d_v
			if bool(d["active"]):
				left += 1
		extra = "  BOSS %d/8" % left
	elif _precision_wave():
		var noms: Array = ["BLEU", "ROSE", "OR"]
		extra = "  C:" + str(noms[_wanted_color])
	elif _wave_360():
		extra = "  360"

	_hud.text = "%d   x%d\nV%d%s  %s" % [
		_score,
		maxi(1, _combo),
		_wave,
		extra,
		hearts]


func _haptic_both(force: float, duration: float) -> void:
	if app.main_d != null:
		app.main_d.trigger_haptic_pulse("haptic", 0.0, force, duration, 0.0)
	if app.main_g != null:
		app.main_g.trigger_haptic_pulse("haptic", 0.0, force * 0.72, duration, 0.0)
