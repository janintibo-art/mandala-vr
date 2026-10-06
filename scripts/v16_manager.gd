class_name V16Manager
extends Node
## Mandala VR v16 : transitions premium legeres pour Quest 3.
## Un seul quad devant la camera, aucun framebuffer supplementaire.

const PREFS_V16: String = "user://v16_transitions.json"
const NOMS: Array = ["Auto", "Fondu colore", "Flash doux", "Portail", "Dissolution", "Prismatique"]

var app = null
var v14 = null
var v15 = null
var _installe: bool = false
var _prefs: Dictionary = {}

var _mode: int = 0
var _intensite: float = 0.78
var _duree: float = 0.72
var _auto_mandala: bool = true
var _auto_monde: bool = true

var _voile: MeshInstance3D = null
var _mat: ShaderMaterial = null
var _phase: int = 0 # 0 repos, 1 fermeture, 2 attente construction, 3 revelation
var _p: float = 1.0
var _style_courant: int = 1
var _construction_avant: bool = false
var _monde_avant: int = -1
var _etat_label: Label = null
var _etat_t: float = 0.0


func _ready() -> void:
	app = get_parent()
	v14 = app.get_node_or_null("V14Manager")
	v15 = app.get_node_or_null("V15Manager")
	process_priority = 160
	_lire_prefs()


func _process(dt: float) -> void:
	if app == null:
		return

	if not _installe:
		if app.camera != null and app.sc != null and app.monde != null and v15 != null and bool(v15.get("_installe")):
			_installer()
		return

	_detecter_evenements()
	_animer_transition(dt)

	_etat_t -= dt
	if _etat_t <= 0.0:
		_etat_t = 0.5
		_maj_etat()


# -------------------------------------------------------------- prefs

func _lire_prefs() -> void:
	if FileAccess.file_exists(PREFS_V16):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREFS_V16))
		if j is Dictionary:
			_prefs = j
	_mode = clampi(int(_prefs.get("mode", 0)), 0, NOMS.size() - 1)
	_intensite = clampf(float(_prefs.get("intensite", 0.78)), 0.20, 1.0)
	_duree = clampf(float(_prefs.get("duree", 0.72)), 0.25, 1.50)
	_auto_mandala = bool(_prefs.get("auto_mandala", true))
	_auto_monde = bool(_prefs.get("auto_monde", true))


func _sauver_prefs() -> void:
	_prefs = {
		"mode": _mode,
		"intensite": _intensite,
		"duree": _duree,
		"auto_mandala": _auto_mandala,
		"auto_monde": _auto_monde,
	}
	var f: FileAccess = FileAccess.open(PREFS_V16, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_prefs))
		f.close()


# -------------------------------------------------------------- installation

func _installer() -> void:
	_installe = true
	_construction_avant = app.sc.occupe
	_monde_avant = app.monde.courant
	_creer_voile()

	var p: VBoxContainer = _page_rapide()
	if p != null:
		_installer_ui(p)

	app.panneau.rafraichir()
	app.message("Mandala VR v16 : transitions premium actives")


func _page_rapide() -> VBoxContainer:
	for c in app.panneau.onglets.get_children():
		if str(c.name) == "Rapide" and c.get_child_count() > 0:
			return c.get_child(0) as VBoxContainer
	return null


func _creer_voile() -> void:
	_voile = MeshInstance3D.new()
	_voile.name = "V16Transition"
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(3.2, 2.2)
	_voile.mesh = q
	_voile.position = Vector3(0.0, 0.0, -0.45)
	_voile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_voile.extra_cull_margin = 10.0

	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/transition_v16.gdshader")
	_mat.render_priority = 120
	_voile.material_override = _mat
	_voile.visible = false
	app.camera.add_child(_voile)

	_appliquer_shader()


# -------------------------------------------------------------- UI

func _installer_ui(p: VBoxContainer) -> void:
	app.panneau._titre(p, "Transitions visuelles premium")
	app.panneau._note(p, "Transitions legeres entre mondes et mandalas. Auto adapte l'effet au style Neon, Plasma, Cristal, Hologramme, Or ou Prismatique.")

	var g: GridContainer = GridContainer.new()
	g.columns = 3
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(g)
	for i in NOMS.size():
		var b: Button = Button.new()
		b.text = str(NOMS[i])
		b.custom_minimum_size = Vector2(0, 70)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_set_mode.bind(i))
		g.add_child(b)

	var r: HBoxContainer = app.panneau._rangee(p)
	app.panneau._bouton(r, "Tester maintenant", _tester)
	app.panneau._bouton(r, "Portail", func() -> void: _tester_style(3))
	app.panneau._bouton(r, "Dissolution", func() -> void: _tester_style(4))
	app.panneau._bouton(r, "Prisme", func() -> void: _tester_style(5))

	app.panneau._bascule(p, "v16_mandala", "Transition automatique des mandalas",
		func() -> bool: return _auto_mandala,
		func(on: bool) -> void: _set_auto_mandala(on))
	app.panneau._bascule(p, "v16_monde", "Transition automatique des mondes",
		func() -> bool: return _auto_monde,
		func(on: bool) -> void: _set_auto_monde(on))
	app.panneau._curseur(p, "v16_intensite", "Intensite", 0.20, 1.0, 0.05,
		func() -> float: return _intensite,
		func(v: float) -> void: _set_intensite(v), "%.2f")
	app.panneau._curseur(p, "v16_duree", "Duree de revelation", 0.25, 1.50, 0.05,
		func() -> float: return _duree,
		func(v: float) -> void: _set_duree(v), "%.2f s")

	_etat_label = Label.new()
	_etat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etat_label.add_theme_font_size_override("font_size", 22)
	p.add_child(_etat_label)


func _set_mode(i: int) -> void:
	_mode = clampi(i, 0, NOMS.size() - 1)
	_sauver_prefs()
	app.message("Transition : " + str(NOMS[_mode]))


func _set_auto_mandala(on: bool) -> void:
	_auto_mandala = on
	_sauver_prefs()


func _set_auto_monde(on: bool) -> void:
	_auto_monde = on
	_sauver_prefs()


func _set_intensite(v: float) -> void:
	_intensite = clampf(v, 0.20, 1.0)
	_appliquer_shader()
	_sauver_prefs()


func _set_duree(v: float) -> void:
	_duree = clampf(v, 0.25, 1.50)
	_sauver_prefs()


# -------------------------------------------------------------- detection

func _detecter_evenements() -> void:
	var construit: bool = app.sc.occupe

	if _auto_mandala:
		if construit and not _construction_avant:
			_commencer_fermeture()
		elif not construit and _construction_avant:
			_commencer_revelation()

	_construction_avant = construit

	var monde_i: int = app.monde.courant
	if monde_i != _monde_avant:
		_monde_avant = monde_i
		if _auto_monde and not construit:
			_commencer_revelation()


# -------------------------------------------------------------- styles

func _style_auto() -> int:
	if _mode > 0:
		return _mode
	if v14 == null:
		return 1
	var s: int = int(v14.get("_style"))
	match s:
		1: # Neon
			return 3
		2: # Plasma
			return 5
		3: # Cristal
			return 4
		4: # Hologramme
			return 4
		5: # Or
			return 2
		6: # Prismatique
			return 5
		_:
			return 1


func _teinte() -> Color:
	# Reprend l'accent de l'interface v15 pour une identite coherente.
	if v15 != null:
		var i: int = clampi(int(v15.get("_accent_i")), 0, 2)
		match i:
			1:
				return Color(0.66, 0.38, 1.0, 1.0)
			2:
				return Color(1.0, 0.66, 0.18, 1.0)
	return Color(0.18, 0.72, 1.0, 1.0)


func _appliquer_shader() -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("progress", _p)
	_mat.set_shader_parameter("style", _style_courant)
	_mat.set_shader_parameter("intensity", _intensite)
	_mat.set_shader_parameter("tint", _teinte())


# -------------------------------------------------------------- animation

func _commencer_fermeture() -> void:
	_style_courant = _style_auto()
	_phase = 1
	_p = 1.0
	if _voile != null:
		_voile.visible = true
	_appliquer_shader()


func _commencer_revelation() -> void:
	_style_courant = _style_auto()
	_phase = 3
	_p = 0.0
	if _voile != null:
		_voile.visible = true
	_appliquer_shader()


func _animer_transition(dt: float) -> void:
	if _phase == 0 or _mat == null:
		return

	if _phase == 1:
		var fermeture: float = maxf(0.18, _duree * 0.45)
		_p = maxf(0.0, _p - dt / fermeture)
		if _p <= 0.001:
			_p = 0.0
			_phase = 2

	elif _phase == 2:
		# Reste couvert pendant la construction.
		if not app.sc.occupe:
			_phase = 3

	elif _phase == 3:
		_p = minf(1.0, _p + dt / _duree)
		if _p >= 0.999:
			_p = 1.0
			_phase = 0
			if _voile != null:
				_voile.visible = false

	_appliquer_shader()


func _tester() -> void:
	_style_courant = _style_auto()
	_phase = 3
	_p = 0.0
	_voile.visible = true
	_appliquer_shader()


func _tester_style(s: int) -> void:
	_style_courant = clampi(s, 1, NOMS.size() - 1)
	_phase = 3
	_p = 0.0
	_voile.visible = true
	_appliquer_shader()


# -------------------------------------------------------------- etat

func _maj_etat() -> void:
	if _etat_label == null:
		return
	var nom: String = str(NOMS[_style_auto()])
	var phase_txt: String = "repos"
	match _phase:
		1:
			phase_txt = "fermeture"
		2:
			phase_txt = "construction"
		3:
			phase_txt = "revelation"
	_etat_label.text = "%s | %.2f s | intensite %.0f%% | %s" % [
		nom, _duree, _intensite * 100.0, phase_txt]
