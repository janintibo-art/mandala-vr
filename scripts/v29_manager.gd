class_name V29Manager
extends Node
## Mandala VR v29 : paysages proceduraux en trois profondeurs.
## Trois spheres transparentes seulement : lointain, milieu, premier plan.
## Les couches restent dans le monde pour donner un vrai parallaxe stereo.

const PREFS_V29: String = "user://v29_landscapes.json"
const RAYONS: Array = [48.0, 31.0, 18.0]
const ALPHAS: Array = [0.22, 0.31, 0.44]

const COULEURS: Array = [
	Color(0.050, 0.070, 0.120), # auto sombre
	Color(0.035, 0.075, 0.150), # nuit
	Color(0.120, 0.035, 0.185), # nebuleuse
	Color(0.025, 0.130, 0.105), # aurore
	Color(0.015, 0.105, 0.155), # abysses
	Color(0.260, 0.080, 0.110), # crepuscule
	Color(0.015, 0.130, 0.045), # code
	Color(0.150, 0.080, 0.030), # cathedrale
	Color(0.035, 0.125, 0.055), # lucioles
	Color(0.180, 0.035, 0.012), # volcan
	Color(0.110, 0.205, 0.285), # glacier
	Color(0.210, 0.075, 0.220), # reve rose
	Color(0.018, 0.095, 0.038), # foret
	Color(0.018, 0.155, 0.215), # ocean
	Color(0.180, 0.055, 0.155), # dunes
	Color(0.105, 0.120, 0.155), # zen
	Color(0.070, 0.180, 0.300), # cristaux
	Color(0.235, 0.060, 0.125), # sakura
	Color(0.285, 0.055, 0.018), # soleil rouge
	Color(0.055, 0.025, 0.180), # vortex
]

var app = null
var v8 = null
var v28 = null
var _installe: bool = false
var _prefs: Dictionary = {}

var _actif: bool = true
var _intensite: float = 0.82
var _profondeur: float = 1.0
var _premier_plan: bool = true
var _animation: float = 0.55

var _racine: Node3D = null
var _couches: Array = []
var _mats: Array = []
var _monde_avant: int = -1
var _passthrough_avant: bool = false
var _etat_label: Label = null
var _etat_t: float = 0.0


func _ready() -> void:
	app = get_parent()
	v8 = app.get_node_or_null("V8Manager")
	v28 = app.get_node_or_null("V28Manager")
	process_priority = 240
	_charger()


func _exit_tree() -> void:
	if is_instance_valid(_racine):
		_racine.queue_free()


func _process(dt: float) -> void:
	if app == null:
		return

	if not _installe:
		var pret: bool = (
			app.camera != null
			and app.monde != null
			and app.panneau != null
			and v28 != null
			and bool(v28.get("_installe"))
		)
		if pret:
			_installer()
		return

	var monde_i: int = app.monde.courant
	var pass: bool = v8 != null and bool(v8.get("_passthrough"))
	if monde_i != _monde_avant or pass != _passthrough_avant:
		_monde_avant = monde_i
		_passthrough_avant = pass
		_appliquer_monde()

	_recentrer_si_besoin(dt)

	_etat_t -= dt
	if _etat_t <= 0.0:
		_etat_t = 0.6
		_maj_etat()


# -------------------------------------------------------------- prefs

func _charger() -> void:
	if not FileAccess.file_exists(PREFS_V29):
		return
	var f: FileAccess = FileAccess.open(PREFS_V29, FileAccess.READ)
	if f == null:
		return
	var j: Variant = JSON.parse_string(f.get_as_text())
	if j is Dictionary:
		var d: Dictionary = j
		_actif = bool(d.get("actif", true))
		_intensite = clampf(float(d.get("intensite", 0.82)), 0.0, 1.0)
		_profondeur = clampf(float(d.get("profondeur", 1.0)), 0.60, 1.35)
		_premier_plan = bool(d.get("premier_plan", true))
		_animation = clampf(float(d.get("animation", 0.55)), 0.0, 1.2)


func _sauver() -> void:
	var f: FileAccess = FileAccess.open(PREFS_V29, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({
			"actif": _actif,
			"intensite": _intensite,
			"profondeur": _profondeur,
			"premier_plan": _premier_plan,
			"animation": _animation,
		}))


# -------------------------------------------------------------- creation

func _installer() -> void:
	_installe = true
	_creer_paysages()
	_monde_avant = app.monde.courant
	_passthrough_avant = v8 != null and bool(v8.get("_passthrough"))
	_appliquer_monde()

	var p: VBoxContainer = _page_monde()
	if p != null:
		_installer_ui(p)

	app.panneau.rafraichir()
	app.message("v29 : paysages 3D en trois profondeurs")


func _creer_paysages() -> void:
	_racine = Node3D.new()
	_racine.name = "V29Paysages"
	_racine.global_position = app.camera.global_position
	app.add_child(_racine)

	var shader: Shader = load("res://shaders/paysage_v29.gdshader")

	for i in 3:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Couche%d" % i

		var sp: SphereMesh = SphereMesh.new()
		sp.radius = float(RAYONS[i])
		sp.height = float(RAYONS[i]) * 2.0
		sp.radial_segments = 64
		sp.rings = 28
		mi.mesh = sp
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 100.0

		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = shader
		mat.render_priority = -88 + i * 4
		mat.set_shader_parameter("layer_index", i)
		mat.set_shader_parameter("alpha_base", float(ALPHAS[i]))
		mi.material_override = mat

		_racine.add_child(mi)
		_couches.append(mi)
		_mats.append(mat)


func _page_monde() -> VBoxContainer:
	for c in app.panneau.onglets.get_children():
		if str(c.name) == "Monde" and c.get_child_count() > 0:
			return c.get_child(0) as VBoxContainer
	return null


# -------------------------------------------------------------- rendu

func _couleur(i: int, couche: int) -> Color:
	var idx: int = clampi(i, 0, COULEURS.size() - 1)
	var base: Color = COULEURS[idx]

	# Le lointain est plus atmospherique, le premier plan plus sombre.
	var k: float = 1.28 if couche == 0 else (0.94 if couche == 1 else 0.62)
	return Color(
		clampf(base.r * k, 0.0, 1.0),
		clampf(base.g * k, 0.0, 1.0),
		clampf(base.b * k, 0.0, 1.0),
		1.0)


func _appliquer_monde() -> void:
	if _racine == null:
		return

	var monde_i: int = clampi(app.monde.courant, 0, Monde.NOMS.size() - 1)
	var pass: bool = v8 != null and bool(v8.get("_passthrough"))
	_racine.visible = _actif and not pass

	for i in _couches.size():
		var mi: MeshInstance3D = _couches[i]
		var mat: ShaderMaterial = _mats[i]

		mi.visible = _actif and not pass and (_premier_plan or i < 2)

		# Profondeur : le premier plan reagit davantage que le fond.
		var s: float = 1.0
		if i == 0:
			s = lerpf(0.94, 1.07, (_profondeur - 0.60) / 0.75)
		elif i == 1:
			s = 1.0
		else:
			s = lerpf(1.12, 0.82, (_profondeur - 0.60) / 0.75)
		mi.scale = Vector3.ONE * s

		mat.set_shader_parameter("world_index", monde_i)
		mat.set_shader_parameter("land_color", _couleur(monde_i, i))
		mat.set_shader_parameter("intensity", _intensite)
		mat.set_shader_parameter("motion", _animation)


func _recentrer_si_besoin(dt: float) -> void:
	if _racine == null or app.camera == null:
		return

	var cam: Vector3 = app.camera.global_position
	var delta: Vector3 = cam - _racine.global_position

	# Le decor reste fixe autour du joueur pour que les petits mouvements de tete
	# produisent du vrai parallaxe. On recentre seulement apres un grand vol.
	if delta.length() > 8.0:
		var cible: Vector3 = cam
		_racine.global_position = _racine.global_position.lerp(
			cible, clampf(dt * 0.75, 0.0, 1.0))


# -------------------------------------------------------------- UI

func _installer_ui(p: VBoxContainer) -> void:
	app.panneau._titre(p, "Profondeur des paysages")
	app.panneau._note(p,
		"Trois couches de silhouettes entourent maintenant les mondes : horizon lointain, relief intermediaire et premier plan. Elles restent a des distances differentes pour produire un vrai parallaxe stereo.")

	var g: GridContainer = GridContainer.new()
	g.columns = 3
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(g)
	_gros(g, "Discret", _preset_discret)
	_gros(g, "Immersif", _preset_immersif)
	_gros(g, "Spectacle", _preset_spectacle)

	app.panneau._bascule(p, "v29_actif", "Paysages en profondeur",
		func() -> bool: return _actif,
		func(on: bool) -> void: _set_actif(on))
	app.panneau._bascule(p, "v29_avant", "Premier plan proche",
		func() -> bool: return _premier_plan,
		func(on: bool) -> void: _set_premier_plan(on))

	app.panneau._curseur(p, "v29_int", "Presence du decor", 0.0, 1.0, 0.05,
		func() -> float: return _intensite,
		func(v: float) -> void: _set_intensite(v), "%.2f")
	app.panneau._curseur(p, "v29_depth", "Profondeur des plans", 0.60, 1.35, 0.05,
		func() -> float: return _profondeur,
		func(v: float) -> void: _set_profondeur(v), "%.2f")
	app.panneau._curseur(p, "v29_motion", "Vie subtile du paysage", 0.0, 1.20, 0.05,
		func() -> float: return _animation,
		func(v: float) -> void: _set_animation(v), "%.2f")

	var r: HBoxContainer = app.panneau._rangee(p)
	app.panneau._bouton(r, "Recentrer les paysages", _recentrer)

	_etat_label = Label.new()
	_etat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etat_label.add_theme_font_size_override("font_size", 22)
	p.add_child(_etat_label)


func _gros(parent: Control, texte: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(0, 72)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _preset_discret() -> void:
	_actif = true
	_intensite = 0.48
	_profondeur = 0.78
	_premier_plan = false
	_animation = 0.25
	_fin_preset("Paysage : discret")


func _preset_immersif() -> void:
	_actif = true
	_intensite = 0.82
	_profondeur = 1.0
	_premier_plan = true
	_animation = 0.55
	_fin_preset("Paysage : immersif")


func _preset_spectacle() -> void:
	_actif = true
	_intensite = 1.0
	_profondeur = 1.28
	_premier_plan = true
	_animation = 0.90
	_fin_preset("Paysage : spectacle")


func _fin_preset(msg: String) -> void:
	_appliquer_monde()
	_sauver()
	app.panneau.rafraichir()
	app.message(msg)


func _set_actif(on: bool) -> void:
	_actif = on
	_appliquer_monde()
	_sauver()


func _set_premier_plan(on: bool) -> void:
	_premier_plan = on
	_appliquer_monde()
	_sauver()


func _set_intensite(v: float) -> void:
	_intensite = clampf(v, 0.0, 1.0)
	_appliquer_monde()
	_sauver()


func _set_profondeur(v: float) -> void:
	_profondeur = clampf(v, 0.60, 1.35)
	_appliquer_monde()
	_sauver()


func _set_animation(v: float) -> void:
	_animation = clampf(v, 0.0, 1.20)
	_appliquer_monde()
	_sauver()


func _recentrer() -> void:
	if _racine != null and app.camera != null:
		_racine.global_position = app.camera.global_position
		app.message("Paysages recentres")


func _maj_etat() -> void:
	if _etat_label == null:
		return
	if not _actif:
		_etat_label.text = "Paysages 3D coupes"
		return
	var i: int = clampi(app.monde.courant, 0, Monde.NOMS.size() - 1)
	var couches: int = 3 if _premier_plan else 2
	_etat_label.text = "%s | %d plans | presence %.0f%% | profondeur %.0f%%" % [
		str(Monde.NOMS[i]), couches, _intensite * 100.0,
		(_profondeur - 0.60) / 0.75 * 100.0]
