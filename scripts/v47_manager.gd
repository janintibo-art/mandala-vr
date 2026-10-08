class_name V47Manager
extends Node
## Mandala VR v47 : Tir Mandala.
##
## Jeu de tir VR :
## - cibles rondes qui arrivent vers le joueur ;
## - visee avec le controleur droit, tir a la gachette droite ;
## - explosion en petites rosaces / mandalas ;
## - score, combo, vies et vagues ;
## - cibles normales, rapides, blindees et bombes ;
## - formations qui changent avec les vagues.
##
## Aucun texte descriptif n'apparait au milieu de la vue.
## Le HUD utile reste discret sur la main gauche.

const TYPE_NORMAL: int = 0
const TYPE_RAPIDE: int = 1
const TYPE_BLINDEE: int = 2
const TYPE_BOMBE: int = 3

const MAX_TARGETS: int = 14
const BURST_SLOTS: int = 8
const PETALS: int = 12
const BURST_INSTANCES: int = BURST_SLOTS * PETALS

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

var _burst_node: MultiMeshInstance3D = null
var _burst_mm: MultiMesh = null
var _burst_mat: StandardMaterial3D = null
var _bursts: Array = []

var _laser: MeshInstance3D = null
var _laser_mat: StandardMaterial3D = null
var _laser_t: float = 0.0

var _hud: Label3D = null
var _status_label: Label = null

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _trigger_was: bool = false

var _score: int = 0
var _best_score: int = 0
var _combo: int = 0
var _lives: int = 5
var _wave: int = 1
var _game_t: float = 0.0
var _spawn_t: float = 0.0
var _spawn_serial: int = 0

# 0 Zen, 1 Arcade, 2 Chaos
var _difficulty: int = 1
var _spawn_base: float = 0.78
var _speed_base: float = 5.0
var _max_alive: int = 10
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

	# Main traite ses entrees avant nous. On neutralise le deplacement libre
	# et les snap-turns afin que le stand de tir reste parfaitement stable.
	app.origine.global_transform = _origin_xf

	var trigger_now: bool = app.main_d.get_float("trigger") > 0.55
	var shot_edge: bool = trigger_now and not _trigger_was
	_trigger_was = trigger_now

	_paused = app.panneau.visible

	# Quand le menu est ferme, on cache le rayon/cursor de creation.
	# Quand le menu est ouvert, on les laisse visibles pour naviguer.
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
		_laser.visible = false
		return

	if _running:
		_game_t += dt
		_wave = 1 + int(floor(_game_t / 16.0))
		_spawn_t -= dt
		if _spawn_t <= 0.0:
			_spawn_target()
			var accel: float = pow(0.94, float(_wave - 1))
			_spawn_t = maxf(0.28, _spawn_base * accel)

		_update_targets(dt)

		if shot_edge:
			_shoot()
	else:
		if shot_edge:
			_start_round()

	_update_bursts(dt)
	_update_laser(dt)
	_update_hud()


# =====================================================================
# Installation / interface

func _installer() -> void:
	_installe = true
	_build_game()
	_build_ui()
	_add_home_card()


func _build_ui() -> void:
	var p: VBoxContainer = null
	for c in app.panneau.onglets.get_children():
		if str(c.name) == "Sensations" and c.get_child_count() > 0:
			p = c.get_child(0) as VBoxContainer
			break
	if p == null:
		return

	app.panneau._titre(p, "Tir Mandala")
	app.panneau._note(
		p,
		"Des cibles rondes arrivent vers toi. Vise avec le controleur droit et tire avec la gachette. Les impacts eclatent en petits mandalas. Les cibles roses sont rapides, les dorees sont blindees et les rouges declenchent une explosion de zone.")

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
		"TIR MANDALA\nCibles, combos et explosions",
		Color(0.18, 0.62, 0.76),
		Callable(self, "demarrer"))


func _set_difficulty(i: int) -> void:
	_difficulty = clampi(i, 0, 2)
	match _difficulty:
		0:
			_spawn_base = 1.05
			_speed_base = 3.8
			_max_alive = 8
			_start_lives = 7
		1:
			_spawn_base = 0.78
			_speed_base = 5.0
			_max_alive = 10
			_start_lives = 5
		_:
			_spawn_base = 0.56
			_speed_base = 6.2
			_max_alive = 13
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
	_root.name = "V47TirMandala"
	_root.visible = false
	app.origine.add_child(_root)

	_targets_root = Node3D.new()
	_targets_root.name = "Targets"
	_root.add_child(_targets_root)

	_target_mats = [
		_mat(Color(0.18, 0.78, 1.0, 0.86), 2.7),
		_mat(Color(1.0, 0.26, 0.82, 0.88), 3.0),
		_mat(Color(1.0, 0.72, 0.18, 0.90), 2.8),
		_mat(Color(1.0, 0.22, 0.12, 0.92), 3.2),
	]

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

		_targets.append({
			"node": n,
			"ring": ring,
			"core": core,
			"active": false,
			"type": TYPE_NORMAL,
			"hp": 1,
			"speed": 5.0,
			"radius": 0.66,
			"base_x": 0.0,
			"base_y": 0.0,
			"phase": 0.0,
			"weave": 0.2,
			"flash": 0.0,
		})

	_build_bursts()
	_build_laser()
	_build_hud()


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

	for i in BURST_INSTANCES:
		_burst_mm.set_instance_transform(
			i,
			Transform3D(
				Basis().scaled(Vector3.ONE * 0.001),
				Vector3(0.0, -100.0, 0.0)))


func _build_laser() -> void:
	_laser = MeshInstance3D.new()
	_laser.name = "TirLaser"
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.012, 0.012, 1.0)
	_laser_mat = _mat(Color(0.42, 0.92, 1.0, 0.90), 4.0)
	bm.material = _laser_mat
	_laser.mesh = bm
	_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_laser.visible = false
	app.main_d.add_child(_laser)

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
	app.main_d.add_child(muzzle)


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


# =====================================================================
# Demarrage / arret

func demarrer() -> void:
	call_deferred("_demarrer_differe")


func _demarrer_differe() -> void:
	if _actif and _running:
		if app.panneau.visible:
			app.basculer_panneau()
		return

	# Coupe les autres modes avant de prendre la main.
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
	}

	app.sc.visible = false
	# Eloigner aussi la toile : cela empeche le systeme de dessin du Main
	# de capter accidentellement les tirs pendant ce mode.
	app.sc.global_position = Vector3(0.0, -1000.0, 0.0)
	app.sol.visible = false

	if main_hud_v is Node3D:
		(main_hud_v as Node3D).visible = false
	if main_msg_v is Node3D:
		(main_msg_v as Node3D).visible = false
	if main_help_v is Node3D:
		(main_help_v as Node3D).visible = false

	_origin_xf = app.origine.global_transform

	# Le stand se centre dans l'axe horizontal du regard au lancement.
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
	_trigger_was = app.main_d.get_float("trigger") > 0.55
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
	_laser.visible = false
	_disable_all_targets()

	if not _snapshot.is_empty():
		app.origine.global_transform = _origin_xf
		app.sc.global_transform = _snapshot.get("sc_transform", app.sc.global_transform)
		app.sc.visible = bool(_snapshot.get("sc_visible", true))
		app.sol.visible = bool(_snapshot.get("sol_visible", true))

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
	_game_t = 0.0
	_spawn_t = 0.15
	_spawn_serial = 0
	_running = true
	_disable_all_targets()
	_clear_bursts()
	_update_hud()
	_update_menu_status()


func _game_over() -> void:
	_running = false
	_combo = 0
	_best_score = maxi(_best_score, _score)
	_disable_all_targets()
	_update_hud()
	_update_menu_status()


# =====================================================================
# Cibles / vagues

func _alive_count() -> int:
	var n: int = 0
	for t_v in _targets:
		var t: Dictionary = t_v
		if bool(t["active"]):
			n += 1
	return n


func _spawn_target() -> void:
	if _alive_count() >= _max_alive:
		return

	var index: int = -1
	for i in _targets.size():
		var td: Dictionary = _targets[i]
		if not bool(td["active"]):
			index = i
			break
	if index < 0:
		return

	var type_id: int = TYPE_NORMAL
	var r: float = _rng.randf()
	if _wave >= 3 and r < 0.12:
		type_id = TYPE_BOMBE
	elif _wave >= 2 and r < 0.30:
		type_id = TYPE_BLINDEE
	elif _wave >= 2 and r < 0.52:
		type_id = TYPE_RAPIDE

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

	var z: float = -18.0 - _rng.randf_range(0.0, 7.0)
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

	var t: Dictionary = _targets[index]
	var node: Node3D = t["node"]
	var ring: MeshInstance3D = t["ring"]
	var core: MeshInstance3D = t["core"]

	node.position = Vector3(x, y, z)
	node.scale = Vector3.ONE * scale_v
	node.rotation = Vector3.ZERO
	node.visible = true
	ring.material_override = _target_mats[type_id]
	core.material_override = _target_mats[type_id]

	t["active"] = true
	t["type"] = type_id
	t["hp"] = hp
	t["speed"] = speed
	t["radius"] = radius
	t["base_x"] = x
	t["base_y"] = y
	t["phase"] = _rng.randf() * TAU
	t["weave"] = weave
	t["flash"] = 0.0
	_targets[index] = t

	_spawn_serial += 1


func _update_targets(dt: float) -> void:
	for i in _targets.size():
		var t: Dictionary = _targets[i]
		if not bool(t["active"]):
			continue

		var node: Node3D = t["node"]
		var type_id: int = int(t["type"])
		var pos: Vector3 = node.position
		pos.z += float(t["speed"]) * dt

		var weave: float = float(t["weave"])
		var phase: float = float(t["phase"])
		var wiggle_speed: float = 2.1
		if type_id == TYPE_RAPIDE:
			wiggle_speed = 4.4
		elif type_id == TYPE_BOMBE:
			wiggle_speed = 2.8

		pos.x = float(t["base_x"]) + sin(_game_t * wiggle_speed + phase) * weave
		pos.y = float(t["base_y"]) + cos(_game_t * (wiggle_speed * 0.73) + phase) * weave * 0.55
		node.position = pos
		node.rotation.z += dt * (0.8 + float(type_id) * 0.38)

		var pulse: float = 1.0 + sin(_game_t * 5.0 + phase) * 0.045
		var base_scale: float = 1.0
		if type_id == TYPE_RAPIDE:
			base_scale = 0.78
		elif type_id == TYPE_BLINDEE:
			base_scale = 1.18
		elif type_id == TYPE_BOMBE:
			base_scale = 1.08

		var flash: float = maxf(0.0, float(t["flash"]) - dt)
		t["flash"] = flash
		if flash > 0.0:
			pulse += 0.16

		node.scale = Vector3.ONE * base_scale * pulse

		if pos.z > -0.65:
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

func _shoot() -> void:
	var ray_o: Vector3 = app.main_d.global_position
	var ray_d: Vector3 = -app.main_d.global_transform.basis.z
	ray_d = ray_d.normalized()

	var best_i: int = -1
	var best_t: float = 9999.0

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

	var laser_len: float = 24.0
	if best_i >= 0:
		laser_len = best_t
		_hit_target(best_i)
	else:
		_combo = 0
		app.main_d.trigger_haptic_pulse("haptic", 0.0, 0.10, 0.035, 0.0)

	_show_laser(clampf(laser_len, 0.4, 28.0))


func _hit_target(i: int) -> void:
	var t: Dictionary = _targets[i]
	var type_id: int = int(t["type"])
	var node: Node3D = t["node"]
	var hp: int = int(t["hp"]) - 1

	if type_id == TYPE_BLINDEE and hp > 0:
		t["hp"] = hp
		t["flash"] = 0.14
		_targets[i] = t
		_score += 35
		_combo += 1
		app.main_d.trigger_haptic_pulse("haptic", 0.0, 0.28, 0.045, 0.0)
		return

	var pos: Vector3 = node.position
	var strength: float = 1.0
	var base_points: int = 100

	if type_id == TYPE_RAPIDE:
		base_points = 180
		strength = 0.85
	elif type_id == TYPE_BLINDEE:
		base_points = 280
		strength = 1.25
	elif type_id == TYPE_BOMBE:
		base_points = 220
		strength = 1.65

	_combo += 1
	var mult: int = mini(5, 1 + _combo / 8)
	_score += base_points * mult

	_spawn_burst(pos, strength)
	_deactivate_target(i)
	app.main_d.trigger_haptic_pulse("haptic", 0.0, 0.50, 0.055, 0.0)

	if type_id == TYPE_BOMBE:
		_bomb_area(pos)


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


func _show_laser(length: float) -> void:
	_laser.visible = true
	_laser.position = Vector3(0.0, 0.0, -length * 0.5)
	_laser.scale = Vector3(1.0, 1.0, length)
	_laser_t = 0.055


func _update_laser(dt: float) -> void:
	if _laser_t <= 0.0:
		_laser.visible = false
		return
	_laser_t -= dt
	if _laser_t <= 0.0:
		_laser.visible = false


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
		# Recycle la plus ancienne si toutes les rosaces sont occupees.
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
			var radial: Vector3 = Vector3(cos(a), sin(a), sin(a * 2.0) * 0.08)
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

	_hud.text = "%d   x%d\nV%d  %s" % [
		_score,
		maxi(1, _combo),
		_wave,
		hearts]


func _haptic_both(force: float, duration: float) -> void:
	if app.main_d != null:
		app.main_d.trigger_haptic_pulse("haptic", 0.0, force, duration, 0.0)
	if app.main_g != null:
		app.main_g.trigger_haptic_pulse("haptic", 0.0, force * 0.72, duration, 0.0)
