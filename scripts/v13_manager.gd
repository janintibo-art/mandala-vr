class_name V13Manager
extends Node
## Mandala VR v13 : mondes cinematographiques pour Quest 3.
## Ambiance procedurale par monde + brouillard Mobile leger + particules thematiques.

const PREFS_V13: String = "user://v13_worlds.json"

var app = null
var v8 = null
var v12 = null
var _installe: bool = false
var _prefs: Dictionary = {}

var _actif: bool = true
var _brouillard: bool = true
var _intensite: float = 0.72
var _vitesse: float = 1.0

var _monde_avant: int = -1
var _passthrough_avant: bool = false
var _etat_label: Label = null
var _etat_t: float = 0.0


func _ready() -> void:
	app = get_parent()
	v8 = app.get_node_or_null("V8Manager")
	v12 = app.get_node_or_null("V12Manager")
	process_priority = 130
	_lire_prefs()


func _process(dt: float) -> void:
	if app == null:
		return
	if not _installe:
		if app.panneau != null and app.env != null and app.monde != null and v12 != null and bool(v12.get("_installe")):
			_installer()
		return

	var monde_i: int = app.monde.courant
	var pass: bool = v8 != null and bool(v8.get("_passthrough"))
	if monde_i != _monde_avant or pass != _passthrough_avant:
		_monde_avant = monde_i
		_passthrough_avant = pass
		_appliquer_monde()

	_etat_t -= dt
	if _etat_t <= 0.0:
		_etat_t = 0.6
		_maj_etat()


# -------------------------------------------------------------- prefs

func _lire_prefs() -> void:
	if FileAccess.file_exists(PREFS_V13):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREFS_V13))
		if j is Dictionary:
			_prefs = j
	_actif = bool(_prefs.get("actif", true))
	_brouillard = bool(_prefs.get("brouillard", true))
	_intensite = clampf(float(_prefs.get("intensite", 0.72)), 0.0, 1.25)
	_vitesse = clampf(float(_prefs.get("vitesse", 1.0)), 0.20, 1.80)


func _sauver_prefs() -> void:
	_prefs = {
		"actif": _actif,
		"brouillard": _brouillard,
		"intensite": _intensite,
		"vitesse": _vitesse,
	}
	var f: FileAccess = FileAccess.open(PREFS_V13, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_prefs))
		f.close()


# -------------------------------------------------------------- installation / UI

func _installer() -> void:
	_installe = true
	_monde_avant = app.monde.courant
	_passthrough_avant = v8 != null and bool(v8.get("_passthrough"))
	_appliquer_monde()

	var p: VBoxContainer = _page_rapide()
	if p != null:
		_installer_ui(p)

	app.panneau.rafraichir()
	app.message("Mandala VR v13 : mondes cinematographiques actifs")


func _page_rapide() -> VBoxContainer:
	for c in app.panneau.onglets.get_children():
		if str(c.name) == "Rapide" and c.get_child_count() > 0:
			return c.get_child(0) as VBoxContainer
	return null


func _installer_ui(p: VBoxContainer) -> void:
	app.panneau._titre(p, "Mondes cinematographiques")
	app.panneau._note(p, "Chaque monde possede maintenant sa propre profondeur, animation de ciel et particules proches.")

	var gp: GridContainer = GridContainer.new()
	gp.columns = 3
	gp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(gp)
	_gros(gp, "Atmosphere douce", _preset_doux)
	_gros(gp, "Atmosphere immersive", _preset_immersif)
	_gros(gp, "Atmosphere intense", _preset_intense)

	app.panneau._bascule(p, "v13_actif", "Details cinematographiques des mondes",
		func() -> bool: return _actif,
		func(on: bool) -> void: _set_actif(on))
	app.panneau._bascule(p, "v13_fog", "Profondeur atmospherique",
		func() -> bool: return _brouillard,
		func(on: bool) -> void: _set_brouillard(on))
	app.panneau._curseur(p, "v13_int", "Intensite de l'atmosphere", 0.0, 1.25, 0.05,
		func() -> float: return _intensite,
		func(v: float) -> void: _set_intensite(v), "%.2f")
	app.panneau._curseur(p, "v13_vit", "Vitesse du ciel", 0.20, 1.80, 0.10,
		func() -> float: return _vitesse,
		func(v: float) -> void: _set_vitesse(v), "%.1f")

	_etat_label = Label.new()
	_etat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etat_label.add_theme_font_size_override("font_size", 22)
	p.add_child(_etat_label)


func _gros(parent: Control, texte: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(0, 74)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# -------------------------------------------------------------- presets / setters

func _preset_doux() -> void:
	_actif = true
	_brouillard = false
	_intensite = 0.42
	_vitesse = 0.65
	_appliquer_monde()
	_sauver_prefs()
	app.panneau.rafraichir()
	app.message("Atmosphere : douce")


func _preset_immersif() -> void:
	_actif = true
	_brouillard = true
	_intensite = 0.72
	_vitesse = 1.0
	_appliquer_monde()
	_sauver_prefs()
	app.panneau.rafraichir()
	app.message("Atmosphere : immersive")


func _preset_intense() -> void:
	_actif = true
	_brouillard = true
	_intensite = 1.05
	_vitesse = 1.25
	_appliquer_monde()
	_sauver_prefs()
	app.panneau.rafraichir()
	app.message("Atmosphere : intense")


func _set_actif(on: bool) -> void:
	_actif = on
	_appliquer_monde()
	_sauver_prefs()


func _set_brouillard(on: bool) -> void:
	_brouillard = on
	_appliquer_monde()
	_sauver_prefs()


func _set_intensite(v: float) -> void:
	_intensite = clampf(v, 0.0, 1.25)
	_appliquer_monde()
	_sauver_prefs()


func _set_vitesse(v: float) -> void:
	_vitesse = clampf(v, 0.20, 1.80)
	_appliquer_monde()
	_sauver_prefs()


# -------------------------------------------------------------- application

func _appliquer_monde() -> void:
	if app.monde == null:
		return
	var i: int = clampi(app.monde.courant, 0, Monde.NOMS.size() - 1)
	var pass: bool = v8 != null and bool(v8.get("_passthrough"))

	if app.monde.m_ciel != null:
		app.monde.m_ciel.set_shader_parameter("v13_monde", i)
		app.monde.m_ciel.set_shader_parameter("v13_intensite", _intensite if _actif else 0.0)
		app.monde.m_ciel.set_shader_parameter("v13_vitesse", _vitesse)

	if app.monde.m_pous != null:
		app.monde.m_pous.set_shader_parameter("v13_monde", i)
		app.monde.m_pous.set_shader_parameter("v13_intensite", _intensite if _actif else 0.0)
		app.monde.m_pous.set_shader_parameter("v13_vitesse", _vitesse)

	_appliquer_brouillard(i, pass)


func _appliquer_brouillard(i: int, pass: bool) -> void:
	if app.env == null:
		return

	if pass or not _actif or not _brouillard or i <= 0:
		app.env.fog_enabled = false
		return

	app.env.fog_enabled = true
	app.env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	app.env.fog_aerial_perspective = 0.0
	app.env.fog_sun_scatter = 0.0

	var col: Color = Color(0.08, 0.10, 0.16)
	var densite: float = 0.0018
	var energie: float = 0.65
	var hauteur: float = 0.0
	var hauteur_d: float = 0.0
	var ciel: float = 0.04

	match i:
		1: # nuit etoilee
			col = Color(0.035, 0.055, 0.13)
			densite = 0.0014
			energie = 0.55
			ciel = 0.02
		2: # nebuleuse
			col = Color(0.10, 0.035, 0.16)
			densite = 0.0026
			energie = 0.68
			ciel = 0.04
		3: # aurore
			col = Color(0.025, 0.13, 0.12)
			densite = 0.0021
			energie = 0.62
			ciel = 0.03
		4: # abysses
			col = Color(0.015, 0.10, 0.17)
			densite = 0.0052
			energie = 0.52
			hauteur = 2.0
			hauteur_d = 0.018
			ciel = 0.06
		5: # crepuscule
			col = Color(0.24, 0.085, 0.11)
			densite = 0.0028
			energie = 0.72
			ciel = 0.05
		6: # code
			col = Color(0.015, 0.12, 0.045)
			densite = 0.0018
			energie = 0.58
			ciel = 0.02
		7: # cathedrale
			col = Color(0.12, 0.075, 0.035)
			densite = 0.0034
			energie = 0.66
			hauteur = 1.0
			hauteur_d = 0.008
			ciel = 0.04
		8: # lucioles
			col = Color(0.035, 0.11, 0.055)
			densite = 0.0038
			energie = 0.58
			hauteur = 1.5
			hauteur_d = 0.012
			ciel = 0.04
		9: # volcan
			col = Color(0.18, 0.045, 0.018)
			densite = 0.0046
			energie = 0.62
			hauteur = 1.2
			hauteur_d = 0.012
			ciel = 0.05
		10: # glacier
			col = Color(0.12, 0.20, 0.27)
			densite = 0.0034
			energie = 0.76
			ciel = 0.06
		11: # reve rose
			col = Color(0.21, 0.09, 0.20)
			densite = 0.0031
			energie = 0.68
			ciel = 0.05

	var facteur: float = lerpf(0.45, 1.15, clampf(_intensite / 1.25, 0.0, 1.0))
	app.env.fog_light_color = col
	app.env.fog_light_energy = energie
	app.env.fog_density = densite * facteur
	app.env.fog_height = hauteur
	app.env.fog_height_density = hauteur_d * facteur
	app.env.fog_sky_affect = ciel


func _maj_etat() -> void:
	if _etat_label == null or app.monde == null:
		return
	var i: int = clampi(app.monde.courant, 0, Monde.NOMS.size() - 1)
	var fog: String = "brume" if app.env.fog_enabled else "sans brume"
	var dyn: String = "cinema" if _actif else "classique"
	_etat_label.text = "%s | %s | %s | intensite %.0f%%" % [
		str(Monde.NOMS[i]), dyn, fog, _intensite / 1.25 * 100.0]
