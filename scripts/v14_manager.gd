class_name V14Manager
extends Node
## Mandala VR v14 : styles de rendu du mandala, sans geometrie supplementaire.
## Les effets restent dans les quatre shaders existants pour limiter l'overdraw.

const PREFS_V14: String = "user://v14_mandala_style.json"
const NOMS: Array = ["Classique", "Neon", "Plasma", "Cristal", "Hologramme", "Or", "Prismatique"]

var app = null
var v12 = null
var v13 = null
var _installe: bool = false
var _prefs: Dictionary = {}

var _style: int = 1
var _force: float = 0.68
var _halo_couches: float = 0.62
var _profondeur: float = 0.52
var _scintillement: float = 0.28
var _vitesse: float = 0.85

var _etat_label: Label = null
var _etat_t: float = 0.0


func _ready() -> void:
	app = get_parent()
	v12 = app.get_node_or_null("V12Manager")
	v13 = app.get_node_or_null("V13Manager")
	process_priority = 140
	_lire_prefs()


func _process(dt: float) -> void:
	if app == null:
		return
	if not _installe:
		if app.panneau != null and app.sc != null and v12 != null and bool(v12.get("_installe")):
			_installer()
		return

	_etat_t -= dt
	if _etat_t <= 0.0:
		_etat_t = 0.5
		_maj_etat()


# -------------------------------------------------------------- prefs

func _lire_prefs() -> void:
	if FileAccess.file_exists(PREFS_V14):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREFS_V14))
		if j is Dictionary:
			_prefs = j
	_style = clampi(int(_prefs.get("style", 1)), 0, NOMS.size() - 1)
	_force = clampf(float(_prefs.get("force", 0.68)), 0.0, 1.25)
	_halo_couches = clampf(float(_prefs.get("halo_couches", 0.62)), 0.0, 1.0)
	_profondeur = clampf(float(_prefs.get("profondeur", 0.52)), 0.0, 1.0)
	_scintillement = clampf(float(_prefs.get("scintillement", 0.28)), 0.0, 1.0)
	_vitesse = clampf(float(_prefs.get("vitesse", 0.85)), 0.0, 2.0)


func _sauver_prefs() -> void:
	_prefs = {
		"style": _style,
		"force": _force,
		"halo_couches": _halo_couches,
		"profondeur": _profondeur,
		"scintillement": _scintillement,
		"vitesse": _vitesse,
	}
	var f: FileAccess = FileAccess.open(PREFS_V14, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_prefs))
		f.close()


# -------------------------------------------------------------- installation / UI

func _installer() -> void:
	_installe = true
	_appliquer()

	var p: VBoxContainer = _page_rapide()
	if p != null:
		_installer_ui(p)

	app.panneau.rafraichir()
	app.message("Mandala VR v14 : styles visuels actifs")


func _page_rapide() -> VBoxContainer:
	for c in app.panneau.onglets.get_children():
		if str(c.name) == "Rapide" and c.get_child_count() > 0:
			return c.get_child(0) as VBoxContainer
	return null


func _installer_ui(p: VBoxContainer) -> void:
	app.panneau._titre(p, "Style du mandala")
	app.panneau._note(p, "Materiaux proceduraux sans dupliquer la geometrie : neon, plasma, cristal, hologramme, or et prismatique.")

	var g: GridContainer = GridContainer.new()
	g.columns = 3
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(g)

	for i in NOMS.size():
		_gros(g, str(NOMS[i]), _set_style.bind(i))

	app.panneau._curseur(p, "v14_force", "Intensite du style", 0.0, 1.25, 0.05,
		func() -> float: return _force,
		func(v: float) -> void: _set_force(v), "%.2f")
	app.panneau._curseur(p, "v14_halo", "Halos multicouches", 0.0, 1.0, 0.05,
		func() -> float: return _halo_couches,
		func(v: float) -> void: _set_halo(v), "%.2f")
	app.panneau._curseur(p, "v14_depth", "Profondeur visuelle", 0.0, 1.0, 0.05,
		func() -> float: return _profondeur,
		func(v: float) -> void: _set_profondeur(v), "%.2f")
	app.panneau._curseur(p, "v14_spark", "Scintillement", 0.0, 1.0, 0.05,
		func() -> float: return _scintillement,
		func(v: float) -> void: _set_scintillement(v), "%.2f")
	app.panneau._curseur(p, "v14_speed", "Animation du materiau", 0.0, 2.0, 0.10,
		func() -> float: return _vitesse,
		func(v: float) -> void: _set_vitesse(v), "%.1f")

	var rp: HBoxContainer = app.panneau._rangee(p)
	app.panneau._bouton(rp, "Neon doux", _preset_neon_doux)
	app.panneau._bouton(rp, "Plasma vivant", _preset_plasma_vivant)
	app.panneau._bouton(rp, "Cristal calme", _preset_cristal_calme)

	var rp2: HBoxContainer = app.panneau._rangee(p)
	app.panneau._bouton(rp2, "Or royal", _preset_or_royal)
	app.panneau._bouton(rp2, "Prisme intense", _preset_prisme_intense)
	app.panneau._bouton(rp2, "Retour classique", _preset_classique)

	_etat_label = Label.new()
	_etat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etat_label.add_theme_font_size_override("font_size", 22)
	p.add_child(_etat_label)


func _gros(parent: Control, texte: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(0, 70)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# -------------------------------------------------------------- styles / presets

func _set_style(i: int) -> void:
	_style = clampi(i, 0, NOMS.size() - 1)
	_appliquer()
	_sauver_prefs()
	app.message("Style mandala : " + str(NOMS[_style]))


func _set_force(v: float) -> void:
	_force = clampf(v, 0.0, 1.25)
	_appliquer()
	_sauver_prefs()


func _set_halo(v: float) -> void:
	_halo_couches = clampf(v, 0.0, 1.0)
	_appliquer()
	_sauver_prefs()


func _set_profondeur(v: float) -> void:
	_profondeur = clampf(v, 0.0, 1.0)
	_appliquer()
	_sauver_prefs()


func _set_scintillement(v: float) -> void:
	_scintillement = clampf(v, 0.0, 1.0)
	_appliquer()
	_sauver_prefs()


func _set_vitesse(v: float) -> void:
	_vitesse = clampf(v, 0.0, 2.0)
	_appliquer()
	_sauver_prefs()


func _preset_neon_doux() -> void:
	_style = 1
	_force = 0.62
	_halo_couches = 0.58
	_profondeur = 0.42
	_scintillement = 0.12
	_vitesse = 0.45
	_fin_preset("Neon doux")


func _preset_plasma_vivant() -> void:
	_style = 2
	_force = 0.92
	_halo_couches = 0.72
	_profondeur = 0.66
	_scintillement = 0.42
	_vitesse = 1.35
	_fin_preset("Plasma vivant")


func _preset_cristal_calme() -> void:
	_style = 3
	_force = 0.72
	_halo_couches = 0.36
	_profondeur = 0.76
	_scintillement = 0.16
	_vitesse = 0.30
	_fin_preset("Cristal calme")


func _preset_or_royal() -> void:
	_style = 5
	_force = 0.78
	_halo_couches = 0.42
	_profondeur = 0.72
	_scintillement = 0.18
	_vitesse = 0.25
	_fin_preset("Or royal")


func _preset_prisme_intense() -> void:
	_style = 6
	_force = 1.00
	_halo_couches = 0.74
	_profondeur = 0.64
	_scintillement = 0.36
	_vitesse = 0.90
	_fin_preset("Prisme intense")


func _preset_classique() -> void:
	_style = 0
	_force = 0.0
	_halo_couches = 0.0
	_profondeur = 0.0
	_scintillement = 0.0
	_vitesse = 0.0
	_fin_preset("Classique")


func _fin_preset(nom: String) -> void:
	_appliquer()
	_sauver_prefs()
	app.panneau.rafraichir()
	app.message("Style : " + nom)


# -------------------------------------------------------------- shaders

func _appliquer() -> void:
	if app.sc == null:
		return
	for nom in ["m_ruban_add", "m_ruban_mix", "m_disque_add", "m_disque_mix"]:
		var m: Variant = app.sc.get(nom)
		if m is ShaderMaterial:
			var sm: ShaderMaterial = m
			sm.set_shader_parameter("v14_style", _style)
			sm.set_shader_parameter("v14_force", _force)
			sm.set_shader_parameter("v14_halo_layers", _halo_couches)
			sm.set_shader_parameter("v14_depth", _profondeur)
			sm.set_shader_parameter("v14_spark", _scintillement)
			sm.set_shader_parameter("v14_speed", _vitesse)


func _maj_etat() -> void:
	if _etat_label == null:
		return
	var fps: int = int(round(Engine.get_frames_per_second()))
	_etat_label.text = "%s | intensite %.0f%% | profondeur %.0f%% | FPS %d" % [
		str(NOMS[_style]), _force / 1.25 * 100.0, _profondeur * 100.0, fps]
