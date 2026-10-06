class_name V12Manager
extends Node
## Mandala VR v12 : qualite graphique Quest 3.
## Tonemapping, glow, MSAA dynamique et reglages de finesse des shaders.

const PREFS_V12: String = "user://v12_graphics.json"
const NOMS_PROFILS: Array = ["Performance", "Equilibre", "Spectacle"]

var app = null
var v8 = null
var v10 = null
var v11 = null
var _installe: bool = false
var _prefs: Dictionary = {}

var _profil: int = 1
var _glow: bool = true
var _glow_force: float = 0.55
var _contraste: float = 1.06
var _saturation: float = 1.08
var _exposition: float = 1.00
var _detail: float = 1.00
var _profondeur: float = 0.45
var _brillance: float = 0.45

var _etat_label: Label = null
var _etat_t: float = 0.0
var _passthrough_avant: bool = false


func _ready() -> void:
	app = get_parent()
	v8 = app.get_node_or_null("V8Manager")
	v10 = app.get_node_or_null("V10Manager")
	v11 = app.get_node_or_null("V11Manager")
	process_priority = 120
	_lire_prefs()


func _process(dt: float) -> void:
	if app == null:
		return
	if not _installe:
		if app.panneau != null and app.env != null and app.monde != null and v10 != null and bool(v10.get("_installe")):
			_installer()
		return

	var pass: bool = v8 != null and bool(v8.get("_passthrough"))
	if pass != _passthrough_avant:
		_passthrough_avant = pass
		_appliquer_environnement()

	_etat_t -= dt
	if _etat_t <= 0.0:
		_etat_t = 0.5
		_maj_etat()


# -------------------------------------------------------------- prefs

func _lire_prefs() -> void:
	if FileAccess.file_exists(PREFS_V12):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREFS_V12))
		if j is Dictionary:
			_prefs = j
	_profil = clampi(int(_prefs.get("profil", 1)), 0, 2)
	_glow = bool(_prefs.get("glow", true))
	_glow_force = clampf(float(_prefs.get("glow_force", 0.55)), 0.0, 1.0)
	_contraste = clampf(float(_prefs.get("contraste", 1.06)), 0.90, 1.25)
	_saturation = clampf(float(_prefs.get("saturation", 1.08)), 0.80, 1.30)
	_exposition = clampf(float(_prefs.get("exposition", 1.00)), 0.80, 1.20)
	_detail = clampf(float(_prefs.get("detail", 1.00)), 0.60, 1.30)
	_profondeur = clampf(float(_prefs.get("profondeur", 0.45)), 0.0, 1.0)
	_brillance = clampf(float(_prefs.get("brillance", 0.45)), 0.0, 1.0)


func _sauver_prefs() -> void:
	_prefs = {
		"profil": _profil,
		"glow": _glow,
		"glow_force": _glow_force,
		"contraste": _contraste,
		"saturation": _saturation,
		"exposition": _exposition,
		"detail": _detail,
		"profondeur": _profondeur,
		"brillance": _brillance,
	}
	var f: FileAccess = FileAccess.open(PREFS_V12, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_prefs))
		f.close()


# -------------------------------------------------------------- installation / UI

func _installer() -> void:
	_installe = true
	_passthrough_avant = v8 != null and bool(v8.get("_passthrough"))
	_appliquer_tout()

	var p: VBoxContainer = _page_rapide()
	if p != null:
		_installer_ui(p)

	app.panneau.rafraichir()
	app.message("Mandala VR v12 : qualite graphique active")


func _page_rapide() -> VBoxContainer:
	for c in app.panneau.onglets.get_children():
		if str(c.name) == "Rapide" and c.get_child_count() > 0:
			return c.get_child(0) as VBoxContainer
	return null


func _installer_ui(p: VBoxContainer) -> void:
	app.panneau._titre(p, "Qualite graphique Quest 3")
	app.panneau._note(p, "Image plus nette, couleurs plus riches et eclat lumineux. Le profil Spectacle utilise le MSAA 4x.")

	var gp: GridContainer = GridContainer.new()
	gp.columns = 3
	gp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(gp)
	_gros(gp, "Performance", _profil_performance)
	_gros(gp, "Equilibre", _profil_equilibre)
	_gros(gp, "Spectacle", _profil_spectacle)

	app.panneau._bascule(p, "v12_glow", "Glow / halo lumineux", func() -> bool: return _glow, func(on: bool) -> void: _set_glow(on))
	app.panneau._curseur(p, "v12_glowf", "Force du glow", 0.0, 1.0, 0.05,
		func() -> float: return _glow_force, func(v: float) -> void: _set_glow_force(v), "%.2f")
	app.panneau._curseur(p, "v12_cont", "Contraste", 0.90, 1.25, 0.01,
		func() -> float: return _contraste, func(v: float) -> void: _set_contraste(v), "%.2f")
	app.panneau._curseur(p, "v12_sat", "Saturation", 0.80, 1.30, 0.01,
		func() -> float: return _saturation, func(v: float) -> void: _set_saturation(v), "%.2f")
	app.panneau._curseur(p, "v12_exp", "Exposition", 0.80, 1.20, 0.01,
		func() -> float: return _exposition, func(v: float) -> void: _set_exposition(v), "%.2f")
	app.panneau._curseur(p, "v12_det", "Detail du monde", 0.60, 1.30, 0.05,
		func() -> float: return _detail, func(v: float) -> void: _set_detail(v), "%.2f")
	app.panneau._curseur(p, "v12_prof", "Profondeur du mandala", 0.0, 1.0, 0.05,
		func() -> float: return _profondeur, func(v: float) -> void: _set_profondeur(v), "%.2f")
	app.panneau._curseur(p, "v12_bri", "Brillance du coeur", 0.0, 1.0, 0.05,
		func() -> float: return _brillance, func(v: float) -> void: _set_brillance(v), "%.2f")

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


# -------------------------------------------------------------- profils

func _profil_performance() -> void:
	_profil = 0
	_glow = false
	_glow_force = 0.20
	_contraste = 1.02
	_saturation = 1.02
	_exposition = 1.00
	_detail = 0.70
	_profondeur = 0.25
	_brillance = 0.25
	_appliquer_tout()
	_sauver_prefs()
	app.panneau.rafraichir()
	app.message("Graphisme : Performance")


func _profil_equilibre() -> void:
	_profil = 1
	_glow = true
	_glow_force = 0.55
	_contraste = 1.06
	_saturation = 1.08
	_exposition = 1.00
	_detail = 1.00
	_profondeur = 0.45
	_brillance = 0.45
	_appliquer_tout()
	_sauver_prefs()
	app.panneau.rafraichir()
	app.message("Graphisme : Equilibre")


func _profil_spectacle() -> void:
	_profil = 2
	_glow = true
	_glow_force = 0.78
	_contraste = 1.10
	_saturation = 1.14
	_exposition = 1.03
	_detail = 1.25
	_profondeur = 0.72
	_brillance = 0.72
	_appliquer_tout()
	_sauver_prefs()
	app.panneau.rafraichir()
	app.message("Graphisme : Spectacle")


# -------------------------------------------------------------- setters

func _set_glow(on: bool) -> void:
	_glow = on
	_appliquer_environnement()
	_sauver_prefs()


func _set_glow_force(v: float) -> void:
	_glow_force = clampf(v, 0.0, 1.0)
	_appliquer_environnement()
	_sauver_prefs()


func _set_contraste(v: float) -> void:
	_contraste = clampf(v, 0.90, 1.25)
	_appliquer_environnement()
	_sauver_prefs()


func _set_saturation(v: float) -> void:
	_saturation = clampf(v, 0.80, 1.30)
	_appliquer_environnement()
	_appliquer_shaders()
	_sauver_prefs()


func _set_exposition(v: float) -> void:
	_exposition = clampf(v, 0.80, 1.20)
	_appliquer_environnement()
	_sauver_prefs()


func _set_detail(v: float) -> void:
	_detail = clampf(v, 0.60, 1.30)
	_appliquer_shaders()
	_sauver_prefs()


func _set_profondeur(v: float) -> void:
	_profondeur = clampf(v, 0.0, 1.0)
	_appliquer_shaders()
	_sauver_prefs()


func _set_brillance(v: float) -> void:
	_brillance = clampf(v, 0.0, 1.0)
	_appliquer_shaders()
	_sauver_prefs()


# -------------------------------------------------------------- application graphique

func _appliquer_tout() -> void:
	_appliquer_viewport()
	_appliquer_environnement()
	_appliquer_shaders()


func _appliquer_viewport() -> void:
	var vp: Viewport = get_viewport()
	if _profil >= 2:
		vp.msaa_3d = Viewport.MSAA_4X
	else:
		vp.msaa_3d = Viewport.MSAA_2X
	# Le VRS XR reste gere par la v8 afin de conserver les FPS du Quest.
	if v8 != null and bool(v8.get("_vrs_actif")):
		vp.vrs_mode = Viewport.VRS_XR


func _appliquer_environnement() -> void:
	if app.env == null:
		return
	var pass: bool = v8 != null and bool(v8.get("_passthrough"))

	app.env.tonemap_mode = Environment.TONE_MAPPER_ACES
	app.env.tonemap_exposure = _exposition
	app.env.tonemap_white = 4.0

	app.env.adjustment_enabled = true
	app.env.adjustment_brightness = 1.0
	app.env.adjustment_contrast = _contraste
	app.env.adjustment_saturation = _saturation

	# En realite mixte on coupe le bloom pour garder une camera propre.
	app.env.glow_enabled = _glow and not pass
	app.env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	app.env.glow_hdr_threshold = 0.88
	app.env.glow_hdr_scale = 1.35
	app.env.glow_intensity = 1.15 + _glow_force * 0.55
	app.env.glow_strength = 0.70 + _glow_force * 0.60
	app.env.glow_bloom = _glow_force * 0.11


func _appliquer_shaders() -> void:
	if app.sc != null:
		for nom in ["m_ruban_add", "m_ruban_mix", "m_disque_add", "m_disque_mix"]:
			var m: Variant = app.sc.get(nom)
			if m is ShaderMaterial:
				var sm: ShaderMaterial = m
				sm.set_shader_parameter("v12_finesse", _detail)
				sm.set_shader_parameter("v12_profondeur", _profondeur)
				sm.set_shader_parameter("v12_vibrance", _saturation)
				sm.set_shader_parameter("v12_brillance", _brillance)

	if app.monde != null:
		if app.monde.m_ciel != null:
			app.monde.m_ciel.set_shader_parameter("v12_detail", _detail)
			app.monde.m_ciel.set_shader_parameter("v12_vibrance", _saturation)
			app.monde.m_ciel.set_shader_parameter("v12_lum", 0.96 + _exposition * 0.08)
		if app.monde.m_pous != null:
			app.monde.m_pous.set_shader_parameter("v12_qualite", _detail)
			app.monde.m_pous.set_shader_parameter("v12_intensite", 0.85 + _brillance * 0.35)

	if app.sol != null and app.sol.material_override is ShaderMaterial:
		var ms: ShaderMaterial = app.sol.material_override
		ms.set_shader_parameter("v12_qualite", _detail)
		ms.set_shader_parameter("v12_intensite", 0.80 + _brillance * 0.35)


func _maj_etat() -> void:
	if _etat_label == null:
		return
	var msaa: String = "4x" if get_viewport().msaa_3d == Viewport.MSAA_4X else "2x"
	var glow_txt: String = "Glow %.0f%%" % (_glow_force * 100.0) if app.env.glow_enabled else "Glow off"
	var fps: int = int(round(Engine.get_frames_per_second()))
	_etat_label.text = "%s | MSAA %s | %s | FPS %d" % [str(NOMS_PROFILS[_profil]), msaa, glow_txt, fps]
