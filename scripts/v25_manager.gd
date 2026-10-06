class_name V25Manager
extends Node
## Mandala VR v25 : plein les yeux.
## Kaleidoscope total (le mandala se replie sur toute la sphere), gerbes de particules
## sur le rythme ou le son, zone qui s'illumine la ou tu regardes.

const PREFS_V25: String = "user://v25_eclat.json"
const NB_PARTICULES: int = 420
const NB_GERBES: int = 3
const VIE_GERBE: float = 2.4

var app = null
var v21 = null
var _installe: bool = false
var _prefs: Dictionary = {}

var _kal: bool = false
var _kal_avant: Dictionary = {}
var _expl: bool = false
var _expl_force: float = 0.7
var _expl_bpm: float = 0.0
var _expl_son: bool = true
var _regard: bool = false
var _regard_force: float = 0.6
var _regard_r: float = 1.2

var _gerbes: Array = []
var _m_gerbes: Array = []
var _ages: Array = []
var _g_i: int = 0
var _t_bpm: float = 0.0
var _niv_moy: float = 0.0
var _niv_prec: float = 0.0
var _refroid: float = 0.0
var _pt_regard: Vector3 = Vector3.ZERO
var _regard_actif_avant: bool = false
var _etat_label: Label = null
var _etat_t: float = 0.0
var _compteur: int = 0


func _ready() -> void:
	app = get_parent()
	v21 = app.get_node_or_null("V21Manager")
	process_priority = 220
	_lire_prefs()


func _exit_tree() -> void:
	if _kal and app != null and app.sc != null and app.sc.is_inside_tree():
		_regler_kaleidoscope(false)


func _process(dt: float) -> void:
	if app == null:
		return
	if not _installe:
		if app.panneau != null and app.sc != null and app.camera != null and v21 != null and v21.get("_installe") == true:
			_installer()
		return
	_maj_gerbes(dt)
	_maj_regard(dt)
	_etat_t -= dt
	if _etat_t <= 0.0:
		_etat_t = 0.5
		_maj_etat()


# -------------------------------------------------------------- preferences

func _lire_prefs() -> void:
	if FileAccess.file_exists(PREFS_V25):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREFS_V25))
		if j is Dictionary:
			_prefs = j
	_expl = bool(_prefs.get("expl", false))
	_expl_force = clampf(float(_prefs.get("expl_force", 0.7)), 0.1, 1.0)
	_expl_bpm = clampf(float(_prefs.get("expl_bpm", 0.0)), 0.0, 160.0)
	_expl_son = bool(_prefs.get("expl_son", true))
	_regard = bool(_prefs.get("regard", false))
	_regard_force = clampf(float(_prefs.get("regard_force", 0.6)), 0.1, 1.0)
	_regard_r = clampf(float(_prefs.get("regard_r", 1.2)), 0.4, 3.0)


func _sauver_prefs() -> void:
	_prefs = {
		"expl": _expl, "expl_force": _expl_force, "expl_bpm": _expl_bpm, "expl_son": _expl_son,
		"regard": _regard, "regard_force": _regard_force, "regard_r": _regard_r,
	}
	var f: FileAccess = FileAccess.open(PREFS_V25, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_prefs))
		f.close()


# -------------------------------------------------------------- installation

func _installer() -> void:
	_installe = true
	_creer_gerbes()
	_creer_ui()
	app.panneau.rafraichir()


func _creer_gerbes() -> void:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = 2525
	var v: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var c: PackedColorArray = PackedColorArray()
	var idx: PackedInt32Array = PackedInt32Array()
	for i in NB_PARTICULES:
		var graine: Color = Color(r.randf(), r.randf(), r.randf(), 1.0)
		var k: int = v.size()
		for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			v.append(Vector3.ZERO)
			uv.append(q)
			c.append(graine)
		idx.append_array(PackedInt32Array([k, k + 1, k + 2, k + 2, k + 1, k + 3]))
	var a: Array = []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_TEX_UV] = uv
	a[Mesh.ARRAY_COLOR] = c
	a[Mesh.ARRAY_INDEX] = idx
	var m: ArrayMesh = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	m.custom_aabb = AABB(Vector3(-500, -500, -500), Vector3(1000, 1000, 1000))
	var sh: Shader = load("res://shaders/explosion_v25.gdshader")
	for i in NB_GERBES:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.mesh = m
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = sh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 1000.0
		mi.top_level = true
		mi.visible = false
		app.add_child(mi)
		_gerbes.append(mi)
		_m_gerbes.append(mat)
		_ages.append(99.0)


func _creer_ui() -> void:
	var p: VBoxContainer = null
	for c in app.panneau.onglets.get_children():
		if str(c.name) == "Style" and c.get_child_count() > 0:
			p = c.get_child(0) as VBoxContainer
	if p == null:
		p = app.panneau._page("Eclat")
	var pn: Node = app.panneau
	pn._titre(p, "Kaleidoscope total")
	pn._note(p, "Le mandala se replie sur toute la sphere : tu es au centre d'une rosace qui t'entoure de partout, miroir au-dessus, autour et dessous.")
	pn._bascule(p, "v25_kal", "Kaleidoscope total", func() -> bool: return _kal, func(on: bool) -> void: _regler_kaleidoscope(on))

	pn._titre(p, "Explosions de particules")
	pn._note(p, "Des gerbes de particules colorees jaillissent du mandala (ou autour de toi en dome) sur le son et sur un rythme regle.")
	pn._bascule(p, "v25_expl", "Explosions actives", func() -> bool: return _expl, func(on: bool) -> void: _set_expl(on))
	pn._curseur(p, "v25_expl_f", "Force", 0.1, 1.0, 0.05, func() -> float: return _expl_force, func(v: float) -> void: _set_expl_force(v), "%.2f")
	pn._curseur(p, "v25_expl_b", "Rythme (battements/min, 0 = son seul)", 0.0, 160.0, 5.0, func() -> float: return _expl_bpm, func(v: float) -> void: _set_expl_bpm(v), "%d")
	pn._bascule(p, "v25_expl_s", "Reagir au son", func() -> bool: return _expl_son, func(on: bool) -> void: _set_expl_son(on))
	pn._bouton(p, "Tester une explosion", func() -> void: _gerbe())

	pn._titre(p, "Eclat sous le regard")
	pn._note(p, "La zone du mandala que tu regardes s'illumine et suit ton regard.")
	pn._bascule(p, "v25_reg", "Eclat sous le regard", func() -> bool: return _regard, func(on: bool) -> void: _set_regard(on))
	pn._curseur(p, "v25_reg_f", "Intensite", 0.1, 1.0, 0.05, func() -> float: return _regard_force, func(v: float) -> void: _set_regard_force(v), "%.2f")
	pn._curseur(p, "v25_reg_r", "Taille de la zone", 0.4, 3.0, 0.1, func() -> float: return _regard_r, func(v: float) -> void: _set_regard_r(v), "%.1f")

	_etat_label = Label.new()
	_etat_label.add_theme_font_size_override("font_size", 22)
	p.add_child(_etat_label)


# -------------------------------------------------------------- reglages

func _set_expl(on: bool) -> void:
	_expl = on
	_sauver_prefs()


func _set_expl_force(v: float) -> void:
	_expl_force = v
	_sauver_prefs()


func _set_expl_bpm(v: float) -> void:
	_expl_bpm = v
	_sauver_prefs()


func _set_expl_son(on: bool) -> void:
	_expl_son = on
	_sauver_prefs()


func _set_regard(on: bool) -> void:
	_regard = on
	_sauver_prefs()


func _set_regard_force(v: float) -> void:
	_regard_force = v
	_sauver_prefs()


func _set_regard_r(v: float) -> void:
	_regard_r = v
	_sauver_prefs()


func _regler_kaleidoscope(on: bool) -> void:
	if on == _kal:
		return
	if on:
		_kal_avant = {"dome": app.sc.dome_cible > 0.5, "ang": app.sc.dome_ang}
		app.set_dome(true)
		app.sc.dome_ang = TAU
		app.sc.dome_fold = 1.0
	else:
		app.sc.dome_fold = 0.0
		app.sc.dome_ang = float(_kal_avant.get("ang", 1.9))
		app.set_dome(bool(_kal_avant.get("dome", false)))
	_kal = on
	app.sc.appliquer_fx()
	app.panneau.rafraichir()
	app.message("Kaleidoscope total : " + ("oui" if on else "non"))


# -------------------------------------------------------------- explosions

func _centre_gerbe() -> Vector3:
	if app.sc.dome_cible > 0.5:
		return app.camera.global_position
	return app.sc.global_position


func _gerbe() -> void:
	var i: int = _g_i
	_g_i = (_g_i + 1) % NB_GERBES
	_ages[i] = 0.0
	var mat: ShaderMaterial = _m_gerbes[i]
	mat.set_shader_parameter("centre", _centre_gerbe())
	mat.set_shader_parameter("force", _expl_force)
	mat.set_shader_parameter("vitesse", 3.5 + 4.5 * _expl_force)
	mat.set_shader_parameter("age", 0.0)
	(_gerbes[i] as MeshInstance3D).visible = true


func _maj_gerbes(dt: float) -> void:
	_refroid = maxf(0.0, _refroid - dt)
	if _expl:
		if _expl_bpm > 0.0:
			_t_bpm -= dt
			if _t_bpm <= 0.0:
				_t_bpm = 60.0 / _expl_bpm
				_gerbe()
		if _expl_son:
			var db: float = AudioServer.get_bus_peak_volume_left_db(0, 0)
			var niv: float = clampf((db + 50.0) / 50.0, 0.0, 1.0)
			_niv_moy = lerpf(_niv_moy, niv, 0.04)
			if niv > _niv_moy * 1.35 + 0.08 and niv > 0.25 and _refroid <= 0.0:
				_refroid = 0.3
				_gerbe()
			_niv_prec = niv
	for i in NB_GERBES:
		var age: float = float(_ages[i])
		if age >= VIE_GERBE:
			if (_gerbes[i] as MeshInstance3D).visible:
				(_gerbes[i] as MeshInstance3D).visible = false
			continue
		age += dt
		_ages[i] = age
		(_m_gerbes[i] as ShaderMaterial).set_shader_parameter("age", age)


# -------------------------------------------------------------- regard

func _materiaux() -> Array:
	var out: Array = []
	for nom in ["m_ruban_add", "m_ruban_mix", "m_disque_add", "m_disque_mix"]:
		var m: Variant = app.sc.get(nom)
		if m is ShaderMaterial:
			out.append(m)
	return out


func _point_regard() -> Vector3:
	var o: Vector3 = app.camera.global_position
	var f: Vector3 = -app.camera.global_transform.basis.z
	if app.sc.dome_cible > 0.5:
		return app.sc.dome_c + f * app.sc.dome_r
	var n: Vector3 = app.sc.global_transform.basis.z.normalized()
	var den: float = f.dot(n)
	if absf(den) > 0.0001:
		var t: float = (app.sc.global_position - o).dot(n) / den
		if t > 0.0:
			return o + f * t
	return o + f * 5.0


func _maj_regard(dt: float) -> void:
	if not _regard:
		if _regard_actif_avant:
			_regard_actif_avant = false
			for m in _materiaux():
				(m as ShaderMaterial).set_shader_parameter("regard_force", 0.0)
		return
	_regard_actif_avant = true
	var cible: Vector3 = _point_regard()
	_pt_regard = _pt_regard.lerp(cible, clampf(dt * 6.0, 0.0, 1.0))
	for m in _materiaux():
		var sm: ShaderMaterial = m
		sm.set_shader_parameter("regard_pos", _pt_regard)
		sm.set_shader_parameter("regard_force", _regard_force)
		sm.set_shader_parameter("regard_r", _regard_r)


func _maj_etat() -> void:
	if _etat_label == null:
		return
	var l: Array = []
	if _kal:
		l.append("kaleidoscope")
	if _expl:
		l.append("explosions")
	if _regard:
		l.append("regard")
	_etat_label.text = "Actif : " + (", ".join(l) if not l.is_empty() else "rien")
