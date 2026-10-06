class_name V15Manager
extends Node
## Mandala VR v15 : interface VR premium.
## Re-theme toute l'interface existante sans toucher a sa logique metier.

const PREFS_V15: String = "user://v15_interface.json"
const ACCENTS: Array = [
	Color(0.18, 0.72, 1.00), # Azur
	Color(0.66, 0.38, 1.00), # Violet
	Color(1.00, 0.66, 0.18), # Or
]
const NOMS_ACCENTS: Array = ["Azur", "Violet", "Or"]

var app = null
var v14 = null
var _installe: bool = false
var _prefs: Dictionary = {}

var _accent_i: int = 0
var _verre: float = 0.92
var _lisible: bool = false
var _halo_ui: float = 0.55

var _header: PanelContainer = null
var _header_titre: Label = null
var _header_sous: Label = null
var _header_etat: Label = null
var _theme_actuel: Theme = null
var _glow_mats: Array = []
var _pulse_t: float = 0.0
var _etat_t: float = 0.0
var _etat_label: Label = null


func _ready() -> void:
	app = get_parent()
	v14 = app.get_node_or_null("V14Manager")
	process_priority = 150
	_lire_prefs()


func _process(dt: float) -> void:
	if app == null:
		return

	if not _installe:
		if app.panneau != null and app.panneau.vp != null and v14 != null and bool(v14.get("_installe")):
			_installer()
		return

	_pulse_t += dt
	_animer_cadre()

	_etat_t -= dt
	if _etat_t <= 0.0:
		_etat_t = 0.5
		_maj_etat()


# -------------------------------------------------------------- preferences

func _lire_prefs() -> void:
	if FileAccess.file_exists(PREFS_V15):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREFS_V15))
		if j is Dictionary:
			_prefs = j
	_accent_i = clampi(int(_prefs.get("accent", 0)), 0, ACCENTS.size() - 1)
	_verre = clampf(float(_prefs.get("verre", 0.92)), 0.78, 1.0)
	_lisible = bool(_prefs.get("lisible", false))
	_halo_ui = clampf(float(_prefs.get("halo_ui", 0.55)), 0.0, 1.0)


func _sauver_prefs() -> void:
	_prefs = {
		"accent": _accent_i,
		"verre": _verre,
		"lisible": _lisible,
		"halo_ui": _halo_ui,
	}
	var f: FileAccess = FileAccess.open(PREFS_V15, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_prefs))
		f.close()


# -------------------------------------------------------------- installation

func _installer() -> void:
	_installe = true
	app.panneau.vp.transparent_bg = true

	_creer_header()
	_creer_glow_3d()
	_appliquer_theme()
	_styliser_labels()
	_styliser_ecran()

	var p: VBoxContainer = _page_rapide()
	if p != null:
		_installer_ui(p)

	app.panneau.rafraichir()
	app.message("Mandala VR v15 : interface premium active")


func _page_rapide() -> VBoxContainer:
	for c in app.panneau.onglets.get_children():
		if str(c.name) == "Rapide" and c.get_child_count() > 0:
			return c.get_child(0) as VBoxContainer
	return null


# -------------------------------------------------------------- theme

func _accent() -> Color:
	return ACCENTS[_accent_i]


func _style(c: Color, rayon: int, bord: Color = Color(0, 0, 0, 0), bw: int = 0,
		marge_h: int = 14, marge_v: int = 9, ombre: bool = false) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(rayon)
	s.content_margin_left = marge_h
	s.content_margin_right = marge_h
	s.content_margin_top = marge_v
	s.content_margin_bottom = marge_v
	if bw > 0:
		s.border_color = bord
		s.border_width_left = bw
		s.border_width_right = bw
		s.border_width_top = bw
		s.border_width_bottom = bw
	if ombre:
		s.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
		s.shadow_size = 8
		s.shadow_offset = Vector2(0, 4)
	return s


func _construire_theme() -> Theme:
	var t: Theme = Theme.new()
	var a: Color = _accent()
	var base_fs: int = 31 if _lisible else 28
	t.default_font_size = base_fs

	# panneau verre sombre
	var panel_c: Color = Color(0.025, 0.035, 0.075, _verre)
	t.set_stylebox("panel", "PanelContainer",
		_style(panel_c, 22, Color(a.r, a.g, a.b, 0.48), 2, 22, 16, true))

	# boutons : relief subtil, contour lumineux et etat actif clair
	var b_norm: StyleBoxFlat = _style(
		Color(0.075, 0.095, 0.16, 0.94), 14,
		Color(a.r, a.g, a.b, 0.22), 1, 16, 10, true)
	var b_hover: StyleBoxFlat = _style(
		Color(0.11 + a.r * 0.08, 0.13 + a.g * 0.08, 0.21 + a.b * 0.08, 0.98), 14,
		Color(a.r, a.g, a.b, 0.90), 2, 16, 10, true)
	var b_press: StyleBoxFlat = _style(
		Color(a.r * 0.33, a.g * 0.33, a.b * 0.33, 1.0), 14,
		Color(a.r, a.g, a.b, 1.0), 3, 16, 10, true)
	var b_focus: StyleBoxFlat = _style(
		Color(0.075, 0.095, 0.16, 0.94), 14,
		Color(a.r, a.g, a.b, 0.60), 2, 16, 10, true)

	t.set_stylebox("normal", "Button", b_norm)
	t.set_stylebox("hover", "Button", b_hover)
	t.set_stylebox("pressed", "Button", b_press)
	t.set_stylebox("hover_pressed", "Button", b_press)
	t.set_stylebox("focus", "Button", b_focus)
	t.set_stylebox("disabled", "Button",
		_style(Color(0.06, 0.07, 0.10, 0.70), 14, Color(0.2, 0.22, 0.28, 0.30), 1))

	t.set_color("font_color", "Button", Color(0.90, 0.94, 1.0))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_hover_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.48, 0.52, 0.62))

	# onglets
	t.set_stylebox("tab_selected", "TabContainer",
		_style(Color(a.r * 0.28, a.g * 0.28, a.b * 0.28, 0.98), 12,
			Color(a.r, a.g, a.b, 0.95), 2, 16, 11, true))
	t.set_stylebox("tab_unselected", "TabContainer",
		_style(Color(0.055, 0.065, 0.115, 0.88), 12,
			Color(0.18, 0.22, 0.34, 0.60), 1, 16, 11))
	t.set_stylebox("tab_hovered", "TabContainer",
		_style(Color(0.095, 0.11, 0.18, 0.96), 12,
			Color(a.r, a.g, a.b, 0.62), 2, 16, 11))
	t.set_stylebox("panel", "TabContainer",
		_style(Color(0.035, 0.045, 0.085, 0.82), 18,
			Color(a.r, a.g, a.b, 0.20), 1, 12, 12))
	t.set_font_size("font_size", "TabContainer", 25 if _lisible else 22)
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", Color(0.70, 0.76, 0.90))
	t.set_color("font_hovered_color", "TabContainer", Color.WHITE)

	# sliders
	var slider: StyleBoxFlat = _style(Color(0.10, 0.12, 0.19, 0.95), 10, Color(0.22, 0.26, 0.38, 0.65), 1, 0, 0)
	slider.content_margin_top = 14.0
	slider.content_margin_bottom = 14.0
	var area: StyleBoxFlat = _style(Color(a.r * 0.82, a.g * 0.82, a.b * 0.82, 1.0), 10, Color(a.r, a.g, a.b, 0.82), 1, 0, 0)
	var area_hi: StyleBoxFlat = _style(Color(minf(1.0, a.r + 0.12), minf(1.0, a.g + 0.12), minf(1.0, a.b + 0.12), 1.0), 10, Color.WHITE, 1, 0, 0)
	t.set_stylebox("slider", "HSlider", slider)
	t.set_stylebox("grabber_area", "HSlider", area)
	t.set_stylebox("grabber_area_highlight", "HSlider", area_hi)

	var gi: Image = Image.create(46, 46, false, Image.FORMAT_RGBA8)
	gi.fill(Color(0, 0, 0, 0))
	for y in 46:
		for x in 46:
			var d: float = Vector2(x - 22.5, y - 22.5).length()
			if d < 21.0:
				var k: float = smoothstep(21.0, 14.0, d)
				gi.set_pixel(x, y, Color(
					lerpf(0.82, 1.0, k),
					lerpf(0.88, 1.0, k),
					1.0,
					1.0))
	var tex: ImageTexture = ImageTexture.create_from_image(gi)
	t.set_icon("grabber", "HSlider", tex)
	t.set_icon("grabber_highlight", "HSlider", tex)
	t.set_icon("grabber_disabled", "HSlider", tex)

	# barres de defilement
	t.set_stylebox("scroll", "VScrollBar",
		_style(Color(0.04, 0.05, 0.09, 0.75), 10, Color(0.15, 0.18, 0.28, 0.5), 1, 0, 0))
	t.set_stylebox("grabber", "VScrollBar",
		_style(Color(a.r * 0.68, a.g * 0.68, a.b * 0.68, 0.88), 10, Color(a.r, a.g, a.b, 0.6), 1, 0, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar",
		_style(Color(a.r, a.g, a.b, 0.98), 10, Color.WHITE, 1, 0, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar",
		_style(Color(minf(1.0, a.r + 0.12), minf(1.0, a.g + 0.12), minf(1.0, a.b + 0.12), 1.0), 10, Color.WHITE, 2, 0, 0))

	# check buttons et labels
	t.set_color("font_color", "CheckButton", Color(0.88, 0.92, 1.0))
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)
	t.set_color("font_pressed_color", "CheckButton", Color.WHITE)
	t.set_font_size("font_size", "CheckButton", base_fs)

	t.set_color("font_color", "Label", Color(0.84, 0.88, 0.97))

	t.set_constant("separation", "VBoxContainer", 12 if _lisible else 10)
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_constant("h_separation", "GridContainer", 12)
	t.set_constant("v_separation", "GridContainer", 12)

	return t


func _appliquer_theme() -> void:
	_theme_actuel = _construire_theme()
	var fond: PanelContainer = _fond_racine()
	if fond != null:
		fond.theme = _theme_actuel

	var a: Color = _accent()
	if _header != null:
		var hs: StyleBoxFlat = _style(
			Color(0.025, 0.045, 0.09, minf(1.0, _verre + 0.02)),
			18, Color(a.r, a.g, a.b, 0.55), 2, 18, 10, true)
		_header.add_theme_stylebox_override("panel", hs)
	if _header_titre != null:
		_header_titre.add_theme_color_override("font_color", Color.WHITE)
	if _header_sous != null:
		_header_sous.add_theme_color_override("font_color", Color(a.r, a.g, a.b, 0.88))
	if _header_etat != null:
		_header_etat.add_theme_color_override("font_color", Color(0.62, 1.0, 0.78))

	_styliser_labels()
	_styliser_ecran()


func _fond_racine() -> PanelContainer:
	if app.panneau.vp == null or app.panneau.vp.get_child_count() == 0:
		return null
	return app.panneau.vp.get_child(0) as PanelContainer


# -------------------------------------------------------------- header

func _creer_header() -> void:
	var fond: PanelContainer = _fond_racine()
	if fond == null or fond.get_child_count() == 0:
		return
	var col: VBoxContainer = fond.get_child(0) as VBoxContainer
	if col == null:
		return

	_header = PanelContainer.new()
	_header.name = "V15Header"
	_header.custom_minimum_size = Vector2(0, 78)

	var marge: MarginContainer = MarginContainer.new()
	marge.add_theme_constant_override("margin_left", 18)
	marge.add_theme_constant_override("margin_right", 18)
	marge.add_theme_constant_override("margin_top", 6)
	marge.add_theme_constant_override("margin_bottom", 6)
	_header.add_child(marge)

	var ligne: HBoxContainer = HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 16)
	marge.add_child(ligne)

	var textes: VBoxContainer = VBoxContainer.new()
	textes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	textes.add_theme_constant_override("separation", -2)
	ligne.add_child(textes)

	_header_titre = Label.new()
	_header_titre.text = "MANDALA VR"
	_header_titre.add_theme_font_size_override("font_size", 34 if _lisible else 31)
	textes.add_child(_header_titre)

	_header_sous = Label.new()
	_header_sous.text = "CREATION IMMERSIVE • QUEST 3"
	_header_sous.add_theme_font_size_override("font_size", 20 if _lisible else 18)
	textes.add_child(_header_sous)

	_header_etat = Label.new()
	_header_etat.text = "● VR"
	_header_etat.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_header_etat.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header_etat.custom_minimum_size = Vector2(210, 0)
	_header_etat.add_theme_font_size_override("font_size", 24)
	ligne.add_child(_header_etat)

	col.add_child(_header)
	col.move_child(_header, 0)


# -------------------------------------------------------------- panneau 3D

func _styliser_ecran() -> void:
	if app.panneau.ecran != null and app.panneau.ecran.material_override is StandardMaterial3D:
		var em: StandardMaterial3D = app.panneau.ecran.material_override
		em.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		em.albedo_color = Color(1.0, 1.0, 1.0, 0.985)

	var a: Color = _accent()
	for c in app.panneau.get_children():
		if c is MeshInstance3D and c != app.panneau.ecran:
			var mi: MeshInstance3D = c
			if mi.material_override is StandardMaterial3D:
				var mat: StandardMaterial3D = mi.material_override
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color = Color(a.r, a.g, a.b, 0.70)


func _creer_glow_3d() -> void:
	if not _glow_mats.is_empty():
		return
	var tailles: Array = [Vector2(1.86, 1.20), Vector2(1.94, 1.28)]
	var zs: Array = [-0.006, -0.010]
	for i in 2:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var q: QuadMesh = QuadMesh.new()
		q.size = tailles[i]
		mi.mesh = q

		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var a: Color = _accent()
		m.albedo_color = Color(a.r, a.g, a.b, 0.08 if i == 0 else 0.035)
		mi.material_override = m
		mi.position = Vector3(0, 0, zs[i])
		app.panneau.add_child(mi)
		app.panneau.move_child(mi, 0)
		_glow_mats.append(m)


func _animer_cadre() -> void:
	if _glow_mats.is_empty():
		return
	var a: Color = _accent()
	var pulse: float = 0.5 + 0.5 * sin(_pulse_t * 1.2)
	for i in _glow_mats.size():
		var m: StandardMaterial3D = _glow_mats[i]
		var base: float = (0.055 if i == 0 else 0.022) * _halo_ui
		var extra: float = (0.045 if i == 0 else 0.020) * _halo_ui * pulse
		m.albedo_color = Color(a.r, a.g, a.b, base + extra)


# -------------------------------------------------------------- labels / lisibilite

func _styliser_labels() -> void:
	var fond: PanelContainer = _fond_racine()
	if fond == null:
		return
	var a: Color = _accent()
	_parcourir_labels(fond, a)


func _parcourir_labels(n: Node, a: Color) -> void:
	if n is Label and n != _header_titre and n != _header_sous and n != _header_etat:
		var l: Label = n
		var fs: int = l.get_theme_font_size("font_size")
		if fs >= 30:
			l.add_theme_color_override("font_color", Color(
				minf(1.0, a.r + 0.22),
				minf(1.0, a.g + 0.22),
				minf(1.0, a.b + 0.22)))
			l.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.72))
			l.add_theme_constant_override("outline_size", 5)
		elif fs <= 24:
			l.add_theme_color_override("font_color", Color(0.70, 0.77, 0.90))
			if _lisible and fs < 24:
				l.add_theme_font_size_override("font_size", 25)

	for c in n.get_children():
		_parcourir_labels(c, a)


# -------------------------------------------------------------- options UI

func _installer_ui(p: VBoxContainer) -> void:
	app.panneau._titre(p, "Interface VR premium")
	app.panneau._note(p, "Theme verre sombre, contraste renforce, feedback lumineux et cadre flottant. Les reglages n'affectent pas le mandala.")

	var g: GridContainer = GridContainer.new()
	g.columns = 3
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(g)
	for i in NOMS_ACCENTS.size():
		var b: Button = Button.new()
		b.text = str(NOMS_ACCENTS[i])
		b.custom_minimum_size = Vector2(0, 72)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_accent.bind(i))
		g.add_child(b)

	app.panneau._bascule(p, "v15_lisible", "Mode tres lisible en casque",
		func() -> bool: return _lisible,
		func(on: bool) -> void: _set_lisible(on))
	app.panneau._curseur(p, "v15_verre", "Opacite du verre", 0.78, 1.0, 0.01,
		func() -> float: return _verre,
		func(v: float) -> void: _set_verre(v), "%.2f")
	app.panneau._curseur(p, "v15_halo", "Halo du panneau", 0.0, 1.0, 0.05,
		func() -> float: return _halo_ui,
		func(v: float) -> void: _set_halo_ui(v), "%.2f")

	_etat_label = Label.new()
	_etat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etat_label.add_theme_font_size_override("font_size", 22)
	p.add_child(_etat_label)

	# Le bloc vient d'etre cree apres la premiere passe de theme.
	_styliser_labels()


func _set_accent(i: int) -> void:
	_accent_i = clampi(i, 0, ACCENTS.size() - 1)
	_appliquer_theme()
	_sauver_prefs()
	app.message("Interface : " + str(NOMS_ACCENTS[_accent_i]))


func _set_lisible(on: bool) -> void:
	_lisible = on
	if _header_titre != null:
		_header_titre.add_theme_font_size_override("font_size", 34 if _lisible else 31)
	if _header_sous != null:
		_header_sous.add_theme_font_size_override("font_size", 20 if _lisible else 18)
	_appliquer_theme()
	_sauver_prefs()
	app.panneau.rafraichir()
	app.message("Lisibilite interface : " + ("maximum" if on else "normale"))


func _set_verre(v: float) -> void:
	_verre = clampf(v, 0.78, 1.0)
	_appliquer_theme()
	_sauver_prefs()


func _set_halo_ui(v: float) -> void:
	_halo_ui = clampf(v, 0.0, 1.0)
	_sauver_prefs()


# -------------------------------------------------------------- statut

func _maj_etat() -> void:
	if _header_etat != null:
		var fps: int = int(round(Engine.get_frames_per_second()))
		var mode: String = "MR" if app.get_node_or_null("V8Manager") != null and bool(app.get_node("V8Manager").get("_passthrough")) else "VR"
		_header_etat.text = "● %s  %d FPS" % [mode, fps]

	if _etat_label != null:
		_etat_label.text = "%s | verre %.0f%% | halo %.0f%% | %s" % [
			str(NOMS_ACCENTS[_accent_i]),
			_verre * 100.0,
			_halo_ui * 100.0,
			"tres lisible" if _lisible else "lisibilite normale"]
