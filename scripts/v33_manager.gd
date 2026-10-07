class_name V33Manager
extends Node
## Mandala VR v33/v34 : Mode Course.
## v34 : la piste est maintenant enfermee dans un tunnel geometrique 360 degres.
## Conduite au stick gauche, assistance anticipative et turbo a la gachette gauche.

const PREFS_V33: String = "user://v33_course.json"
const NB_SEGMENTS: int = 72
const NB_RAILS: int = NB_SEGMENTS * 2
const NB_TUNNEL: int = 58
const ESPACEMENT: float = 1.45
const TUNNEL_ESPACEMENT: float = 1.72
const DEMI_LARGEUR: float = 3.15
const LIMITE_VEHICULE: float = 2.45

var app = null
var v8 = null
var v29 = null
var v31 = null
var v32 = null
var _installe: bool = false

var _actif: bool = false
var _profil: int = 0 # 0 assiste, 1 sport, 2 libre
var _vitesse_base: float = 27.0
var _assistance: float = 0.82
var _virages: float = 0.82
var _turbo_actif: bool = true

var _racine: Node3D = null
var _piste_node: MultiMeshInstance3D = null
var _piste_mm: MultiMesh = null
var _rails_node: MultiMeshInstance3D = null
var _rails_mm: MultiMesh = null
var _tunnel_node: MultiMeshInstance3D = null
var _tunnel_mm: MultiMesh = null
var _tunnel_mat: ShaderMaterial = null
var _vehicule: Node3D = null
var _hud: Label3D = null

var _distance: float = 0.0
var _lane: float = 0.0
var _lane_v: float = 0.0
var _vitesse_reelle: float = 0.0
var _origine_xf: Transform3D
var _snapshot: Dictionary = {}
var _bord_cooldown: float = 0.0
var _etat_label: Label = null
var _etat_t: float = 0.0


func _ready() -> void:
	app = get_parent()
	v8 = app.get_node_or_null("V8Manager")
	v29 = app.get_node_or_null("V29Manager")
	v31 = app.get_node_or_null("V31Manager")
	v32 = app.get_node_or_null("V32Manager")
	process_priority = 270
	_charger()


func _exit_tree() -> void:
	if _actif:
		_arreter_immediat()


func _process(dt: float) -> void:
	if app == null:
		return

	if not _installe:
		var pret: bool = (
			app.camera != null
			and app.origine != null
			and app.panneau != null
			and v32 != null
			and bool(v32.get("_installe"))
		)
		if pret:
			_installer()
		return

	if _actif:
		if app.panneau.visible:
			arreter()
			return
		_maj_course(dt)

	_etat_t -= dt
	if _etat_t <= 0.0:
		_etat_t = 0.4
		_maj_etat()


# -------------------------------------------------------------- preferences

func _charger() -> void:
	if not FileAccess.file_exists(PREFS_V33):
		return
	var f: FileAccess = FileAccess.open(PREFS_V33, FileAccess.READ)
	if f == null:
		return
	var j: Variant = JSON.parse_string(f.get_as_text())
	if j is Dictionary:
		var d: Dictionary = j
		_profil = clampi(int(d.get("profil", 0)), 0, 2)
		_vitesse_base = clampf(float(d.get("vitesse", 27.0)), 14.0, 45.0)
		_assistance = clampf(float(d.get("assistance", 0.82)), 0.0, 1.0)
		_virages = clampf(float(d.get("virages", 0.82)), 0.35, 1.35)
		_turbo_actif = bool(d.get("turbo", true))


func _sauver() -> void:
	var f: FileAccess = FileAccess.open(PREFS_V33, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({
			"profil": _profil,
			"vitesse": _vitesse_base,
			"assistance": _assistance,
			"virages": _virages,
			"turbo": _turbo_actif,
		}))


# -------------------------------------------------------------- installation / menu

func _installer() -> void:
	_installe = true
	_creer_piste()
	_creer_vehicule()
	_creer_hud()
	_creer_page_course()
	app.panneau.rafraichir()
	app.message("v34 : Course tunnel disponible depuis Experiences")


func _creer_page_course() -> void:
	var p: VBoxContainer = app.panneau._page("Course")

	var titre: Label = Label.new()
	titre.text = "MODE COURSE"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", 44)
	titre.add_theme_color_override("font_color", Color(0.55, 0.82, 1.0))
	p.add_child(titre)

	app.panneau._note(p,
		"La course se deroule maintenant DANS un tunnel geometrique complet, proche du Grand 8 de la mort. Stick gauche : direction. Gachette gauche : turbo. La piste, les anneaux et les virages defilent autour du vehicule a grande vitesse.")

	var g: GridContainer = GridContainer.new()
	g.columns = 3
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(g)
	_gros(g, "ASSISTE", func() -> void: _preset(0))
	_gros(g, "SPORT", func() -> void: _preset(1))
	_gros(g, "LIBRE", func() -> void: _preset(2))

	var r: HBoxContainer = app.panneau._rangee(p)
	app.panneau._bouton(r, "DEMARRER LA COURSE", demarrer)
	app.panneau._bouton(r, "ARRETER", arreter)

	app.panneau._curseur(p, "v33_speed", "Vitesse de base", 14.0, 45.0, 1.0,
		func() -> float: return _vitesse_base,
		func(v: float) -> void: _set_vitesse(v), "%.0f m/s")
	app.panneau._curseur(p, "v33_assist", "Assistance de trajectoire", 0.0, 1.0, 0.05,
		func() -> float: return _assistance,
		func(v: float) -> void: _set_assistance(v), "%.2f")
	app.panneau._curseur(p, "v33_curve", "Virages du parcours", 0.35, 1.35, 0.05,
		func() -> float: return _virages,
		func(v: float) -> void: _set_virages(v), "%.2f")
	app.panneau._bascule(p, "v33_turbo", "Turbo sur la gachette gauche",
		func() -> bool: return _turbo_actif,
		func(on: bool) -> void: _set_turbo(on))

	var r2: HBoxContainer = app.panneau._rangee(p)
	app.panneau._bouton(r2, "Retour Accueil", _retour_accueil)

	_etat_label = Label.new()
	_etat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etat_label.add_theme_font_size_override("font_size", 23)
	p.add_child(_etat_label)

	app.panneau._titre(p, "Commandes")
	app.panneau._note(p,
		"Stick gauche gauche/droite : se placer dans la piste. Relache le stick et l'assistance corrige progressivement la trajectoire. La gachette gauche ajoute jusqu'a 45 % de vitesse. Ouvre le menu pour stopper immediatement.")


func _gros(parent: Control, texte: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(0, 82)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 27)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _retour_accueil() -> void:
	if v32 != null and v32.has_method("_aller_accueil"):
		v32.call("_aller_accueil")



# -------------------------------------------------------------- presets

func _preset(i: int) -> void:
	_profil = clampi(i, 0, 2)
	match _profil:
		0:
			_vitesse_base = 25.0
			_assistance = 0.86
			_virages = 0.72
		1:
			_vitesse_base = 32.0
			_assistance = 0.56
			_virages = 0.92
		2:
			_vitesse_base = 39.0
			_assistance = 0.22
			_virages = 1.16
	_sauver()
	app.panneau.rafraichir()
	app.message("Course : " + ["Assiste", "Sport", "Libre"][_profil])


func _set_vitesse(v: float) -> void:
	_vitesse_base = clampf(v, 14.0, 45.0)
	_sauver()


func _set_assistance(v: float) -> void:
	_assistance = clampf(v, 0.0, 1.0)
	_sauver()


func _set_virages(v: float) -> void:
	_virages = clampf(v, 0.35, 1.35)
	_sauver()


func _set_turbo(on: bool) -> void:
	_turbo_actif = on
	_sauver()


# -------------------------------------------------------------- creation piste

func _creer_piste() -> void:
	_racine = Node3D.new()
	_racine.name = "V33Course"
	_racine.visible = false
	app.origine.add_child(_racine)

	var piste_mesh: BoxMesh = BoxMesh.new()
	piste_mesh.size = Vector3(DEMI_LARGEUR * 2.0, 0.10, ESPACEMENT * 1.10)
	var piste_mat: StandardMaterial3D = StandardMaterial3D.new()
	piste_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	piste_mat.albedo_color = Color(0.055, 0.075, 0.13)
	piste_mat.metallic = 0.35
	piste_mat.roughness = 0.55
	piste_mat.emission_enabled = true
	piste_mat.emission = Color(0.018, 0.04, 0.11)
	piste_mat.emission_energy_multiplier = 1.15
	piste_mesh.material = piste_mat

	_piste_mm = MultiMesh.new()
	_piste_mm.transform_format = MultiMesh.TRANSFORM_3D
	_piste_mm.instance_count = NB_SEGMENTS
	_piste_mm.mesh = piste_mesh

	_piste_node = MultiMeshInstance3D.new()
	_piste_node.name = "Piste"
	_piste_node.multimesh = _piste_mm
	_piste_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_piste_node.extra_cull_margin = 180.0
	_racine.add_child(_piste_node)

	var rail_mesh: BoxMesh = BoxMesh.new()
	rail_mesh.size = Vector3(0.10, 0.44, ESPACEMENT * 1.08)
	var rail_mat: StandardMaterial3D = StandardMaterial3D.new()
	rail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rail_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rail_mat.albedo_color = Color(0.18, 0.72, 1.0, 0.78)
	rail_mat.emission_enabled = true
	rail_mat.emission = Color(0.10, 0.58, 1.0)
	rail_mat.emission_energy_multiplier = 2.2
	rail_mesh.material = rail_mat

	_rails_mm = MultiMesh.new()
	_rails_mm.transform_format = MultiMesh.TRANSFORM_3D
	_rails_mm.instance_count = NB_RAILS
	_rails_mm.mesh = rail_mesh

	_rails_node = MultiMeshInstance3D.new()
	_rails_node.name = "Rails"
	_rails_node.multimesh = _rails_mm
	_rails_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_rails_node.extra_cull_margin = 180.0
	_racine.add_child(_rails_node)


	# Tunnel 360 degres inspire du Grand 8 : le joueur n'a plus seulement
	# deux lignes sur les cotes, il roule au coeur d'une structure lumineuse.
	var tunnel_mesh: TorusMesh = TorusMesh.new()
	tunnel_mesh.inner_radius = 3.55
	tunnel_mesh.outer_radius = 3.66
	tunnel_mesh.rings = 32
	tunnel_mesh.ring_segments = 6

	_tunnel_mat = ShaderMaterial.new()
	_tunnel_mat.shader = load("res://shaders/grand8_v31.gdshader")
	_tunnel_mat.set_shader_parameter("speed", _vitesse_base)
	_tunnel_mat.set_shader_parameter("cine", 5)
	_tunnel_mat.set_shader_parameter("world_index", app.monde.courant)
	tunnel_mesh.material = _tunnel_mat

	_tunnel_mm = MultiMesh.new()
	_tunnel_mm.transform_format = MultiMesh.TRANSFORM_3D
	_tunnel_mm.instance_count = NB_TUNNEL
	_tunnel_mm.mesh = tunnel_mesh

	_tunnel_node = MultiMeshInstance3D.new()
	_tunnel_node.name = "TunnelCourse"
	_tunnel_node.multimesh = _tunnel_mm
	_tunnel_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_tunnel_node.extra_cull_margin = 180.0
	_racine.add_child(_tunnel_node)


func _creer_vehicule() -> void:
	_vehicule = Node3D.new()
	_vehicule.name = "Vehicule"
	_vehicule.position = Vector3(0.0, -0.92, -0.70)
	_racine.add_child(_vehicule)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.07, 0.12, 0.22)
	mat.metallic = 0.72
	mat.roughness = 0.28
	mat.emission_enabled = true
	mat.emission = Color(0.02, 0.08, 0.18)
	mat.emission_energy_multiplier = 1.2

	var glow: StandardMaterial3D = StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(0.20, 0.72, 1.0, 0.92)
	glow.emission_enabled = true
	glow.emission = Color(0.12, 0.62, 1.0)
	glow.emission_energy_multiplier = 2.8

	var capot: MeshInstance3D = MeshInstance3D.new()
	var capot_mesh: BoxMesh = BoxMesh.new()
	capot_mesh.size = Vector3(1.05, 0.20, 1.35)
	capot.mesh = capot_mesh
	capot.material_override = mat
	capot.position = Vector3(0, 0, -0.15)
	_vehicule.add_child(capot)

	for cote in [-1.0, 1.0]:
		var aile: MeshInstance3D = MeshInstance3D.new()
		var aile_mesh: BoxMesh = BoxMesh.new()
		aile_mesh.size = Vector3(0.22, 0.14, 1.58)
		aile.mesh = aile_mesh
		aile.material_override = mat
		aile.position = Vector3(0.68 * cote, 0.02, -0.12)
		aile.rotation.z = deg_to_rad(-8.0 * cote)
		_vehicule.add_child(aile)

		var ligne: MeshInstance3D = MeshInstance3D.new()
		var ligne_mesh: BoxMesh = BoxMesh.new()
		ligne_mesh.size = Vector3(0.035, 0.045, 1.45)
		ligne.mesh = ligne_mesh
		ligne.material_override = glow
		ligne.position = Vector3(0.50 * cote, 0.12, -0.20)
		_vehicule.add_child(ligne)

	var nez: MeshInstance3D = MeshInstance3D.new()
	var nez_mesh: BoxMesh = BoxMesh.new()
	nez_mesh.size = Vector3(0.34, 0.10, 0.40)
	nez.mesh = nez_mesh
	nez.material_override = glow
	nez.position = Vector3(0, 0.12, -0.88)
	_vehicule.add_child(nez)


func _creer_hud() -> void:
	_hud = Label3D.new()
	_hud.name = "CourseHUD"
	_hud.pixel_size = 0.00085
	_hud.font_size = 34
	_hud.outline_size = 8
	_hud.no_depth_test = true
	_hud.render_priority = 20
	_hud.modulate = Color(0.76, 0.90, 1.0)
	_hud.position = Vector3(0.0, -0.34, -1.12)
	_hud.visible = false
	app.camera.add_child(_hud)


# -------------------------------------------------------------- course

func demarrer() -> void:
	call_deferred("_demarrer_differe")


func _demarrer_differe() -> void:
	if _actif:
		return

	# Coupe les modes sensations avant la course.
	if v32 != null and v32.has_method("arreter_mort"):
		v32.call("arreter_mort")
	if v31 != null and bool(v31.get("_actif")):
		v31.call("arreter")

	app.diff_stop()

	var paysage: Node3D = null
	var paysage_visible: bool = false
	if v29 != null:
		var pv: Variant = v29.get("_racine")
		if pv is Node3D:
			paysage = pv
			paysage_visible = paysage.visible

	var passthrough_avant: bool = false
	if v8 != null:
		passthrough_avant = bool(v8.get("_passthrough"))
		if passthrough_avant and v8.has_method("_set_passthrough"):
			v8.call("_set_passthrough", false)

	_snapshot = {
		"sc_visible": app.sc.visible,
		"sol_visible": app.sol.visible,
		"paysage": paysage,
		"paysage_visible": paysage_visible,
		"passthrough": passthrough_avant,
	}

	app.sc.visible = false
	app.sol.visible = false
	if paysage != null:
		paysage.visible = false

	_origine_xf = app.origine.global_transform
	_racine.position = app.camera.position
	_racine.rotation = Vector3.ZERO
	_racine.visible = true
	_hud.visible = true

	_distance = 0.0
	_lane = 0.0
	_lane_v = 0.0
	_vitesse_reelle = _vitesse_base
	_bord_cooldown = 0.0
	_actif = true

	if app.panneau.visible:
		app.basculer_panneau()

	_maj_piste()
	app.message("MODE COURSE TUNNEL - stick gauche direction, gachette gauche turbo")


func arreter() -> void:
	if not _actif:
		return
	_arreter_immediat()
	app.message("Course terminee")


func _arreter_immediat() -> void:
	_actif = false
	if _racine != null:
		_racine.visible = false
	if _hud != null:
		_hud.visible = false

	if app != null and not _snapshot.is_empty():
		app.origine.global_transform = _origine_xf
		app.sc.visible = bool(_snapshot.get("sc_visible", true))
		app.sol.visible = bool(_snapshot.get("sol_visible", true))

		var paysage: Variant = _snapshot.get("paysage", null)
		if paysage is Node3D and is_instance_valid(paysage):
			(paysage as Node3D).visible = bool(_snapshot.get("paysage_visible", true))

		if bool(_snapshot.get("passthrough", false)) and v8 != null and v8.has_method("_set_passthrough"):
			v8.call("_set_passthrough", true)

	_snapshot = {}


func _maj_course(dt: float) -> void:
	# Neutralise le deplacement libre et le snap-turn du Main pendant la course.
	app.origine.global_transform = _origine_xf

	var stick: Vector2 = app.main_g.get_vector2("primary")
	var steer: float = stick.x
	if absf(steer) < 0.12:
		steer = 0.0

	var turbo: float = 0.0
	if _turbo_actif:
		turbo = clampf(app.main_g.get_float("trigger"), 0.0, 1.0)

	var bord_facteur: float = 1.0
	if absf(_lane) > 2.20:
		bord_facteur = lerpf(1.0, 0.78, clampf((absf(_lane) - 2.20) / 0.25, 0.0, 1.0))

	var cible_v: float = _vitesse_base * (1.0 + turbo * 0.45) * bord_facteur
	_vitesse_reelle = lerpf(_vitesse_reelle, cible_v, clampf(dt * 2.8, 0.0, 1.0))
	_distance += _vitesse_reelle * dt

	# Assistance anticipative : vise legerement l'interieur du virage a venir.
	var ici: Vector3 = _courbe(_distance)
	var devant: Vector3 = _courbe(_distance + 18.0)
	var delta_x: float = devant.x - ici.x
	var ideal: float = clampf(-delta_x * 0.13, -0.82, 0.82)

	var effort_assist: float = (ideal - _lane) * _assistance * 4.2
	var effort_pilote: float = steer * lerpf(4.4, 6.0, 1.0 - _assistance)
	var attenuation_assist: float = 1.0 - absf(steer) * 0.62
	_lane_v += (effort_pilote + effort_assist * attenuation_assist) * dt
	_lane_v *= exp(-dt * lerpf(4.0, 2.2, 1.0 - _assistance))
	_lane += _lane_v

	if _lane > LIMITE_VEHICULE:
		_lane = LIMITE_VEHICULE
		_lane_v = minf(_lane_v, 0.0)
		_toucher_bord()
	elif _lane < -LIMITE_VEHICULE:
		_lane = -LIMITE_VEHICULE
		_lane_v = maxf(_lane_v, 0.0)
		_toucher_bord()

	_bord_cooldown = maxf(0.0, _bord_cooldown - dt)

	_maj_piste()
	_maj_vehicule(steer, turbo, dt)
	_maj_hud(turbo)


func _toucher_bord() -> void:
	if _bord_cooldown > 0.0:
		return
	_bord_cooldown = 0.22
	if app.main_g != null:
		app.main_g.trigger_haptic_pulse("haptic", 0.0, 0.34, 0.06, 0.0)
	if app.main_d != null:
		app.main_d.trigger_haptic_pulse("haptic", 0.0, 0.22, 0.05, 0.0)


# -------------------------------------------------------------- parcours procedural

func _courbe(s: float) -> Vector3:
	var v: float = _virages
	var x: float = (
		sin(s * 0.043) * 4.4
		+ sin(s * 0.091 + 1.4) * 1.65
		+ sin(s * 0.017 + 0.6) * 2.1
	) * v
	var y: float = (
		sin(s * 0.031 + 0.7) * 0.72
		+ sin(s * 0.073) * 0.22
	) * v
	return Vector3(x, y, -s)


func _segment_basis(s: float) -> Basis:
	var p0: Vector3 = _courbe(s)
	var p1: Vector3 = _courbe(s + 0.35)
	var dir: Vector3 = (p1 - p0).normalized()
	return Basis.looking_at(dir, Vector3.UP)


func _maj_piste() -> void:
	if _piste_mm == null or _rails_mm == null:
		return

	var base: Vector3 = _courbe(_distance)

	for i in NB_SEGMENTS:
		var d: float = 0.70 + float(i) * ESPACEMENT
		var s: float = _distance + d
		var monde: Vector3 = _courbe(s) - base
		var b: Basis = _segment_basis(s)

		var centre: Vector3 = Vector3(
			monde.x - _lane,
			-1.30 + monde.y,
			-d)
		_piste_mm.set_instance_transform(i, Transform3D(b, centre))

		var cote: Vector3 = b.x.normalized()
		var haut: Vector3 = Vector3.UP * 0.20
		var gauche: Vector3 = centre - cote * DEMI_LARGEUR + haut
		var droite: Vector3 = centre + cote * DEMI_LARGEUR + haut
		_rails_mm.set_instance_transform(i * 2, Transform3D(b, gauche))
		_rails_mm.set_instance_transform(i * 2 + 1, Transform3D(b, droite))

	if _tunnel_mm != null:
		var base_ring: Basis = Basis(Vector3.RIGHT, PI * 0.5)
		for i in NB_TUNNEL:
			var d2: float = 1.0 + float(i) * TUNNEL_ESPACEMENT
			var s2: float = _distance + d2
			var monde2: Vector3 = _courbe(s2) - base
			var route_basis: Basis = _segment_basis(s2)
			var roll: float = (
				sin(s2 * 0.045) * 0.22
				+ sin(s2 * 0.093 + 1.2) * 0.08
			) * _virages
			var ring_basis: Basis = route_basis * Basis(Vector3.FORWARD, roll) * base_ring
			var centre2: Vector3 = Vector3(
				monde2.x - _lane,
				-0.08 + monde2.y,
				-d2)
			_tunnel_mm.set_instance_transform(i, Transform3D(ring_basis, centre2))

	if _tunnel_mat != null:
		_tunnel_mat.set_shader_parameter("speed", _vitesse_reelle)
		_tunnel_mat.set_shader_parameter("cine", 5 if _profil < 2 else 3)
		_tunnel_mat.set_shader_parameter("world_index", app.monde.courant)


func _maj_vehicule(steer: float, turbo: float, dt: float) -> void:
	if _vehicule == null:
		return

	var cible_roll: float = -steer * 0.15 - _lane_v * 0.018
	var cible_yaw: float = steer * 0.055
	_vehicule.rotation.z = lerp_angle(_vehicule.rotation.z, cible_roll, clampf(dt * 6.0, 0.0, 1.0))
	_vehicule.rotation.y = lerp_angle(_vehicule.rotation.y, cible_yaw, clampf(dt * 5.0, 0.0, 1.0))
	_vehicule.position.y = -0.92 + sin(_distance * 0.08) * 0.012
	_vehicule.scale = Vector3.ONE * (1.0 + turbo * 0.018)


func _maj_hud(turbo: float) -> void:
	if _hud == null:
		return
	var kmh: int = int(_vitesse_reelle * 3.6)
	var profil_nom: String = ["ASSISTE", "SPORT", "LIBRE"][_profil]
	var t: String = "%d km/h  |  %s" % [kmh, profil_nom]
	if turbo > 0.15:
		t += "  |  TURBO"
	_hud.text = t


# -------------------------------------------------------------- statut

func _maj_etat() -> void:
	if _etat_label == null:
		return

	if not _actif:
		_etat_label.text = "Course prete | %s | %.0f m/s | assistance %.0f%%" % [
			["Assiste", "Sport", "Libre"][_profil],
			_vitesse_base,
			_assistance * 100.0]
		return

	_etat_label.text = "COURSE TUNNEL | %d km/h | position %.0f%% | assistance %.0f%%" % [
		int(_vitesse_reelle * 3.6),
		_lane / LIMITE_VEHICULE * 100.0,
		_assistance * 100.0]
