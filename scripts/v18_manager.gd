class_name V18Manager
extends Node
## Mandala VR v18 : aura, anneaux et particules orbitales.
## Deux draw calls principaux : un quad shader + un MultiMesh de petites spheres.

const PREFS_V18: String = "user://v18_aura.json"

var app = null
var v14 = null
var v17 = null
var _installe: bool = false
var _prefs: Dictionary = {}

var _actif: bool = true
var _aura: bool = true
var _anneaux: bool = true
var _orbes: bool = true
var _etincelles: bool = true
var _intensite: float = 0.72
var _vitesse: float = 0.65
var _nb_orbes: int = 30
var _rayon: float = 5.15

var _aura_node: MeshInstance3D = null
var _aura_mat: ShaderMaterial = null
var _orb_node: MultiMeshInstance3D = null
var _orb_mm: MultiMesh = null
var _orb_mat: ShaderMaterial = null

var _temps: float = 0.0
var _style_avant: int = -1
var _etat_t: float = 0.0
var _etat_label: Label = null


func _ready() -> void:
	app = get_parent()
	v14 = app.get_node_or_null("V14Manager")
	v17 = app.get_node_or_null("V17Manager")
	process_priority = 180
	_lire_prefs()


func _exit_tree() -> void:
	if is_instance_valid(_aura_node):
		_aura_node.queue_free()
	if is_instance_valid(_orb_node):
		_orb_node.queue_free()


func _process(dt: float) -> void:
	if app == null:
		return

	if not _installe:
		if app.sc != null and app.panneau != null and v17 != null and bool(v17.get("_installe")):
			_installer()
		return

	_temps += dt

	var style_now: int = _style_mandala()
	if style_now != _style_avant:
		_style_avant = style_now
		_appliquer_couleurs()

	_maj_effets()

	_etat_t -= dt
	if _etat_t <= 0.0:
		_etat_t = 0.5
		_maj_etat()


# -------------------------------------------------------------- preferences

func _lire_prefs() -> void:
	if FileAccess.file_exists(PREFS_V18):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREFS_V18))
		if j is Dictionary:
			_prefs = j

	_actif = bool(_prefs.get("actif", true))
	_aura = bool(_prefs.get("aura", true))
	_anneaux = bool(_prefs.get("anneaux", true))
	_orbes = bool(_prefs.get("orbes", true))
	_etincelles = bool(_prefs.get("etincelles", true))
	_intensite = clampf(float(_prefs.get("intensite", 0.72)), 0.0, 1.0)
	_vitesse = clampf(float(_prefs.get("vitesse", 0.65)), 0.10, 1.80)
	_nb_orbes = clampi(int(_prefs.get("nb_orbes", 30)), 8, 48)
	_rayon = clampf(float(_prefs.get("rayon", 5.15)), 4.0, 6.2)


func _sauver_prefs() -> void:
	_prefs = {
		"actif": _actif,
		"aura": _aura,
		"anneaux": _anneaux,
		"orbes": _orbes,
		"etincelles": _etincelles,
		"intensite": _intensite,
		"vitesse": _vitesse,
		"nb_orbes": _nb_orbes,
		"rayon": _rayon,
	}
	var f: FileAccess = FileAccess.open(PREFS_V18, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_prefs))
		f.close()


# -------------------------------------------------------------- installation

func _installer() -> void:
	_installe = true
	_style_avant = _style_mandala()
	_creer_aura()
	_creer_orbes()
	_appliquer_couleurs()
	_appliquer_options()

	var p: VBoxContainer = _page_rapide()
	if p != null:
		_installer_ui(p)

	app.panneau.rafraichir()
	app.message("Mandala VR v18 : aura et particules orbitales actives")


func _page_rapide() -> VBoxContainer:
	for c in app.panneau.onglets.get_children():
		if str(c.name) == "Rapide" and c.get_child_count() > 0:
			return c.get_child(0) as VBoxContainer
	return null


# -------------------------------------------------------------- creation graphique

func _creer_aura() -> void:
	_aura_node = MeshInstance3D.new()
	_aura_node.name = "V18Aura"
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(13.0, 13.0)
	_aura_node.mesh = q
	_aura_node.position = Vector3(0.0, 0.0, -0.72)
	_aura_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_aura_node.extra_cull_margin = 20.0

	_aura_mat = ShaderMaterial.new()
	_aura_mat.shader = load("res://shaders/aura_v18.gdshader")
	_aura_node.material_override = _aura_mat
	app.sc.add_child(_aura_node)
	app.sc.move_child(_aura_node, 0)


func _creer_orbes() -> void:
	_orb_node = MultiMeshInstance3D.new()
	_orb_node.name = "V18Orbitals"
	_orb_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_orb_node.extra_cull_margin = 20.0

	var sph: SphereMesh = SphereMesh.new()
	sph.radius = 0.045
	sph.height = 0.09
	sph.radial_segments = 8
	sph.rings = 4

	_orb_mat = ShaderMaterial.new()
	_orb_mat.shader = load("res://shaders/orbite_v18.gdshader")
	sph.material = _orb_mat

	_orb_mm = MultiMesh.new()
	_orb_mm.transform_format = MultiMesh.TRANSFORM_3D
	_orb_mm.instance_count = _nb_orbes
	_orb_mm.mesh = sph
	_orb_node.multimesh = _orb_mm

	app.sc.add_child(_orb_node)
	_reconstruire_orbes()


func _reconstruire_orbes() -> void:
	if _orb_mm == null:
		return
	_orb_mm.instance_count = _nb_orbes
	for i in _nb_orbes:
		_orb_mm.set_instance_transform(i, Transform3D(Basis(), Vector3.ZERO))


# -------------------------------------------------------------- couleurs / style

func _style_mandala() -> int:
	if v14 == null:
		return 1
	return clampi(int(v14.get("_style")), 0, 6)


func _couleur_style() -> Color:
	match _style_mandala():
		1: # neon
			return Color(0.10, 0.78, 1.00)
		2: # plasma
			return Color(0.92, 0.20, 1.00)
		3: # cristal
			return Color(0.52, 0.82, 1.00)
		4: # hologramme
			return Color(0.12, 1.00, 0.88)
		5: # or
			return Color(1.00, 0.58, 0.08)
		6: # prismatique
			return Color(0.88, 0.45, 1.00)
		_:
			return Color(0.32, 0.66, 1.00)


func _appliquer_couleurs() -> void:
	var c: Color = _couleur_style()
	if _aura_mat != null:
		_aura_mat.set_shader_parameter("tint", c)
		_aura_mat.set_shader_parameter("style", _style_mandala())
	if _orb_mat != null:
		_orb_mat.set_shader_parameter("tint", c)
		_orb_mat.set_shader_parameter("style", _style_mandala())


# -------------------------------------------------------------- animation

func _facteur_respiration() -> float:
	if app.sc.souffle:
		return app.sc.facteur_souffle()
	return 1.0 + 0.018 * sin(_temps * _vitesse * 1.7)


func _dome_reduction() -> float:
	# L'aura est plane, donc on la coupe presque completement quand le mandala
	# devient une voute autour du joueur.
	if app.sc.dome > 0.35 or app.sc.dome_cible > 0.5:
		return 0.08
	return 1.0


func _maj_effets() -> void:
	var dome_f: float = _dome_reduction()
	var visible_global: bool = _actif and _intensite > 0.001 and dome_f > 0.02
	var souffle: float = _facteur_respiration()
	var intens: float = _intensite * dome_f

	if _aura_node != null:
		_aura_node.visible = visible_global and (_aura or _anneaux or _etincelles)
		_aura_node.scale = Vector3.ONE * souffle

	if _aura_mat != null:
		_aura_mat.set_shader_parameter("intensity", intens)
		_aura_mat.set_shader_parameter("speed", _vitesse)
		_aura_mat.set_shader_parameter("show_aura", 1.0 if _aura else 0.0)
		_aura_mat.set_shader_parameter("show_rings", 1.0 if _anneaux else 0.0)
		_aura_mat.set_shader_parameter("show_sparks", 1.0 if _etincelles else 0.0)
		_aura_mat.set_shader_parameter("breath", souffle)

	if _orb_node != null:
		_orb_node.visible = visible_global and _orbes

	if _orb_mat != null:
		_orb_mat.set_shader_parameter("intensity", intens)
		_orb_mat.set_shader_parameter("pulse", souffle)

	if visible_global and _orbes:
		_maj_orbites(souffle, dome_f)


func _maj_orbites(souffle: float, dome_f: float) -> void:
	if _orb_mm == null:
		return

	var n: int = _nb_orbes
	var style_i: int = _style_mandala()
	for i in n:
		var f: float = float(i) / float(maxi(n, 1))
		var couche: int = i % 3
		var vitesse_i: float = _vitesse * (0.28 + float(couche) * 0.08)
		var sens: float = -1.0 if couche == 1 else 1.0
		var a: float = f * TAU + _temps * vitesse_i * sens

		var rr: float = _rayon + (float(couche) - 1.0) * 0.34
		rr *= souffle
		var wobble: float = sin(_temps * _vitesse * 0.7 + float(i) * 1.73) * 0.12
		var x: float = cos(a) * (rr + wobble)
		var y: float = sin(a) * (rr + wobble)

		# Trois couches de profondeur discretes autour du mandala.
		var z: float = 0.10 + (float(couche) - 1.0) * 0.22
		z += sin(a * 2.0 + float(i)) * 0.06

		var scint: float = 0.72 + 0.28 * sin(_temps * (1.5 + f) + float(i) * 2.1)
		var taille: float = (0.65 + scint * 0.55) * (0.85 + _intensite * 0.25)
		if style_i == 5:
			taille *= 1.08
		elif style_i == 3:
			taille *= 0.90

		taille *= dome_f
		var b: Basis = Basis().scaled(Vector3.ONE * taille)
		_orb_mm.set_instance_transform(i, Transform3D(b, Vector3(x, y, z)))


# -------------------------------------------------------------- options

func _appliquer_options() -> void:
	if _aura_node != null:
		_aura_node.visible = _actif
	if _orb_node != null:
		_orb_node.visible = _actif and _orbes


func _installer_ui(p: VBoxContainer) -> void:
	app.panneau._titre(p, "Aura et orbites du mandala")
	app.panneau._note(p,
		"Une aura procedurale et des particules orbitales entourent le mandala. Elles suivent sa respiration et adaptent leur couleur au style Neon, Plasma, Cristal, Hologramme, Or ou Prismatique.")

	var g: GridContainer = GridContainer.new()
	g.columns = 3
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(g)
	_gros(g, "Zen", _preset_zen)
	_gros(g, "Cosmique", _preset_cosmique)
	_gros(g, "Energie", _preset_energie)

	app.panneau._bascule(p, "v18_actif", "Effets autour du mandala",
		func() -> bool: return _actif,
		func(on: bool) -> void: _set_actif(on))
	app.panneau._bascule(p, "v18_aura", "Aura circulaire",
		func() -> bool: return _aura,
		func(on: bool) -> void: _set_aura(on))
	app.panneau._bascule(p, "v18_rings", "Anneaux lumineux",
		func() -> bool: return _anneaux,
		func(on: bool) -> void: _set_anneaux(on))
	app.panneau._bascule(p, "v18_orb", "Particules orbitales",
		func() -> bool: return _orbes,
		func(on: bool) -> void: _set_orbes(on))
	app.panneau._bascule(p, "v18_spark", "Etincelles",
		func() -> bool: return _etincelles,
		func(on: bool) -> void: _set_etincelles(on))

	app.panneau._curseur(p, "v18_int", "Intensite", 0.0, 1.0, 0.05,
		func() -> float: return _intensite,
		func(v: float) -> void: _set_intensite(v), "%.2f")
	app.panneau._curseur(p, "v18_speed", "Vitesse des orbites", 0.10, 1.80, 0.05,
		func() -> float: return _vitesse,
		func(v: float) -> void: _set_vitesse(v), "%.2f")
	app.panneau._curseur(p, "v18_count", "Nombre de particules", 8, 48, 2,
		func() -> float: return float(_nb_orbes),
		func(v: float) -> void: _set_nb_orbes(int(v)), "%d")
	app.panneau._curseur(p, "v18_radius", "Rayon des orbites", 4.0, 6.2, 0.05,
		func() -> float: return _rayon,
		func(v: float) -> void: _set_rayon(v), "%.2f m")

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


func _preset_zen() -> void:
	_actif = true
	_aura = true
	_anneaux = true
	_orbes = true
	_etincelles = false
	_intensite = 0.38
	_vitesse = 0.30
	_nb_orbes = 18
	_rayon = 5.05
	_fin_preset("Aura : Zen")


func _preset_cosmique() -> void:
	_actif = true
	_aura = true
	_anneaux = true
	_orbes = true
	_etincelles = true
	_intensite = 0.72
	_vitesse = 0.65
	_nb_orbes = 30
	_rayon = 5.15
	_fin_preset("Aura : Cosmique")


func _preset_energie() -> void:
	_actif = true
	_aura = true
	_anneaux = true
	_orbes = true
	_etincelles = true
	_intensite = 0.95
	_vitesse = 1.10
	_nb_orbes = 44
	_rayon = 5.35
	_fin_preset("Aura : Energie")


func _fin_preset(msg: String) -> void:
	_reconstruire_orbes()
	_appliquer_options()
	_sauver_prefs()
	app.panneau.rafraichir()
	app.message(msg)


func _set_actif(on: bool) -> void:
	_actif = on
	_appliquer_options()
	_sauver_prefs()


func _set_aura(on: bool) -> void:
	_aura = on
	_sauver_prefs()


func _set_anneaux(on: bool) -> void:
	_anneaux = on
	_sauver_prefs()


func _set_orbes(on: bool) -> void:
	_orbes = on
	_appliquer_options()
	_sauver_prefs()


func _set_etincelles(on: bool) -> void:
	_etincelles = on
	_sauver_prefs()


func _set_intensite(v: float) -> void:
	_intensite = clampf(v, 0.0, 1.0)
	_sauver_prefs()


func _set_vitesse(v: float) -> void:
	_vitesse = clampf(v, 0.10, 1.80)
	_sauver_prefs()


func _set_nb_orbes(v: int) -> void:
	_nb_orbes = clampi(v, 8, 48)
	_reconstruire_orbes()
	_sauver_prefs()


func _set_rayon(v: float) -> void:
	_rayon = clampf(v, 4.0, 6.2)
	_sauver_prefs()


# -------------------------------------------------------------- etat

func _maj_etat() -> void:
	if _etat_label == null:
		return
	if not _actif:
		_etat_label.text = "Aura et orbites coupees"
		return
	var dome_txt: String = "reduites en dome" if _dome_reduction() < 0.5 else "plein effet"
	_etat_label.text = "%d orbes | intensite %.0f%% | rayon %.2f m | %s" % [
		_nb_orbes, _intensite * 100.0, _rayon, dome_txt]
