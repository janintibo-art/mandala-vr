class_name V40Manager
extends Node
## Mandala VR v40 : mise en scene dynamique.
## Chaque evenement suit preparation -> tension -> climax -> relance.

const PRE_RINGS: int = 4

var app = null
var v31 = null
var v32 = null
var v33 = null
var v36 = null
var v38 = null
var v39 = null

var _installe: bool = false
var _death_root: Node3D = null
var _death_pre: Array = []
var _death_pre_mat: StandardMaterial3D = null
var _death_key: int = -1
var _death_climax_done: bool = false

var _course_root: Node3D = null
var _course_pre: Array = []
var _course_pre_mat: StandardMaterial3D = null
var _course_key: int = -1
var _course_climax_done: bool = false


func _ready() -> void:
	app = get_parent()
	v31 = app.get_node_or_null("V31Manager")
	v32 = app.get_node_or_null("V32Manager")
	v33 = app.get_node_or_null("V33Manager")
	v36 = app.get_node_or_null("V36Manager")
	v38 = app.get_node_or_null("V38Manager")
	v39 = app.get_node_or_null("V39Manager")
	process_priority = 320


func _process(_dt: float) -> void:
	if app == null:
		return
	if not _installe:
		var pret: bool = (
			v31 != null and bool(v31.get("_installe"))
			and v32 != null and bool(v32.get("_installe"))
			and v33 != null and bool(v33.get("_installe"))
			and v36 != null and bool(v36.get("_installe"))
			and v38 != null and bool(v38.get("_installe"))
			and v39 != null and bool(v39.get("_installe"))
		)
		if pret:
			_installer()
		return
	_maj_death_scene()
	_maj_course_scene()


func _installer() -> void:
	_installe = true
	_creer_death_pre()
	_creer_course_pre()


func _glow(c: Color, energie: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = Color(c.r, c.g, c.b, 1.0)
	m.emission_energy_multiplier = energie
	return m


func _creer_ring(parent: Node3D, mat: StandardMaterial3D, nom: String) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = nom
	var tor: TorusMesh = TorusMesh.new()
	tor.inner_radius = 2.02
	tor.outer_radius = 2.12
	tor.rings = 36
	tor.ring_segments = 8
	mi.mesh = tor
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visible = false
	parent.add_child(mi)
	return mi


func _creer_death_pre() -> void:
	var rv: Variant = v31.get("_racine")
	if not (rv is Node3D):
		return
	_death_root = rv
	_death_pre_mat = _glow(Color(0.40, 0.82, 1.0, 0.60), 1.6)
	for i in PRE_RINGS:
		_death_pre.append(_creer_ring(_death_root, _death_pre_mat, "V40DeathPre" + str(i)))


func _death_transform(d: float, chapitre: int, ratio: float) -> Transform3D:
	var p_v: Variant = v36.call("_death_point", d, chapitre, ratio)
	var p2_v: Variant = v36.call("_death_point", d + 0.24, chapitre, ratio)
	if not (p_v is Vector3) or not (p2_v is Vector3):
		return Transform3D()
	var p: Vector3 = p_v
	var p2: Vector3 = p2_v
	var dir: Vector3 = (p2 - p).normalized()
	return Transform3D(Basis.looking_at(dir, Vector3.UP), p)


func _hide_death_pre() -> void:
	for n in _death_pre:
		if n is MeshInstance3D:
			(n as MeshInstance3D).visible = false


func _maj_death_scene() -> void:
	if _death_root == null:
		return
	var mort: bool = bool(v32.get("_mort"))
	var etat: int = int(v32.get("_etat_mort"))
	if not mort or etat != 0:
		_hide_death_pre()
		if not mort:
			_death_root.scale = Vector3.ONE
		return

	var chapitre: int = mini(int(v32.get("_chapitre")), 5)
	var phase: float = float(v32.get("_phase_t"))
	var fin: float = maxf(1.0, float(v32.get("_prochaine_rupture")))
	var ratio: float = clampf(phase / fin, 0.0, 1.0)
	var acte_f: float = ratio * 4.0
	var acte: int = mini(3, int(floor(acte_f)))
	var local: float = clampf(acte_f - float(acte), 0.0, 1.0)
	var key: int = chapitre * 10 + acte

	if key != _death_key:
		_death_key = key
		_death_climax_done = false

	var tension: float = smoothstep(0.12, 0.56, local)
	var climax: float = sin(PI * clampf((local - 0.46) / 0.34, 0.0, 1.0))
	var relance: float = smoothstep(0.70, 1.0, local)

	var souffle: float = 1.0 - tension * 0.055 + climax * 0.095 + relance * 0.025
	_death_root.scale = Vector3(souffle, souffle, 1.0)

	var dm_v: Variant = v38.get("_death_mat")
	if dm_v is StandardMaterial3D:
		(dm_v as StandardMaterial3D).emission_energy_multiplier = 2.15 + float(chapitre) * 0.18 + tension * 0.65 + climax * 1.15

	var bm_v: Variant = v38.get("_bar_mat")
	if bm_v is StandardMaterial3D:
		(bm_v as StandardMaterial3D).emission_energy_multiplier = 1.85 + tension * 0.65 + climax * 1.25

	for mat_name in ["_mat_blue", "_mat_pink", "_mat_gold", "_mat_red"]:
		var mv: Variant = v39.get(mat_name)
		if mv is StandardMaterial3D:
			(mv as StandardMaterial3D).emission_energy_multiplier = 2.0 + tension * 0.85 + climax * 1.45

	for i in _death_pre.size():
		var n: MeshInstance3D = _death_pre[i]
		n.visible = local > 0.08 and local < 0.72
		if not n.visible:
			continue
		var progression: float = clampf((local - 0.08) / 0.64, 0.0, 1.0)
		var d: float = lerpf(44.0 + float(i) * 4.0, 2.2 + float(i) * 0.70, progression)
		n.transform = _death_transform(d, chapitre, ratio)
		var pulse: float = 0.88 + 0.12 * sin(progression * TAU * 2.0 + float(i))
		n.scale = Vector3.ONE * pulse
		n.rotation.z = progression * TAU * (0.18 + float(i) * 0.04)

	if _death_pre_mat != null:
		_death_pre_mat.emission_energy_multiplier = 1.2 + tension * 1.1 + climax * 2.3

	if local >= 0.56 and not _death_climax_done:
		_death_climax_done = true
		_vibrer(0.34 + float(chapitre) * 0.035, 0.08)

	var base_speed: float = float(v31.get("_vitesse"))
	var mult: float = 1.0
	if local < 0.46:
		mult = lerpf(1.0, 0.88, smoothstep(0.08, 0.46, local))
	elif local < 0.72:
		mult = lerpf(0.88, 1.14, smoothstep(0.46, 0.72, local))
	else:
		mult = lerpf(1.14, 1.02, smoothstep(0.72, 1.0, local))
	v31.set("_vitesse", clampf(base_speed * mult, 4.0, 38.0))


func _creer_course_pre() -> void:
	var rv: Variant = v33.get("_racine")
	if not (rv is Node3D):
		return
	_course_root = rv
	_course_pre_mat = _glow(Color(0.28, 0.88, 1.0, 0.56), 1.5)
	for i in PRE_RINGS:
		_course_pre.append(_creer_ring(_course_root, _course_pre_mat, "V40CoursePre" + str(i)))


func _course_transform(s: float, distance: float, lane: float) -> Transform3D:
	var p_v: Variant = v36.call("_course_point", s)
	var b_v: Variant = v36.call("_course_basis", s)
	var base_v: Variant = v36.call("_course_point", distance)
	if not (p_v is Vector3) or not (b_v is Basis) or not (base_v is Vector3):
		return Transform3D()
	var p: Vector3 = p_v
	var b: Basis = b_v
	var base: Vector3 = base_v
	return Transform3D(b, p - base - b.x * lane)


func _hide_course_pre() -> void:
	for n in _course_pre:
		if n is MeshInstance3D:
			(n as MeshInstance3D).visible = false


func _maj_course_scene() -> void:
	if _course_root == null:
		return
	var actif: bool = bool(v33.get("_actif"))
	if not actif:
		_hide_course_pre()
		return

	var distance: float = float(v33.get("_distance"))
	var lane: float = float(v33.get("_lane"))
	var secteur: int = int(v36.call("_course_sector", distance))
	var u: float = fposmod(distance, 165.0) / 165.0
	var demi: int = 0 if u < 0.5 else 1
	var local: float = u * 2.0 if demi == 0 else (u - 0.5) * 2.0
	var key: int = secteur * 10 + demi

	if key != _course_key:
		_course_key = key
		_course_climax_done = false

	var tension: float = smoothstep(0.10, 0.56, local)
	var climax: float = sin(PI * clampf((local - 0.45) / 0.36, 0.0, 1.0))

	var cg_v: Variant = v36.get("_course_glow")
	if cg_v is StandardMaterial3D:
		var cg: StandardMaterial3D = cg_v
		var bases: Array = [1.9, 2.5, 1.7, 2.1, 2.8, 3.1]
		cg.emission_energy_multiplier = float(bases[secteur]) + tension * 0.55 + climax * 0.95

	var cm_v: Variant = v38.get("_course_mat")
	if cm_v is StandardMaterial3D:
		(cm_v as StandardMaterial3D).emission_energy_multiplier = 1.8 + tension * 0.55 + climax * 1.1

	for mat_name in ["_mat_blue", "_mat_pink", "_mat_gold", "_mat_red"]:
		var mv: Variant = v39.get(mat_name)
		if mv is StandardMaterial3D:
			(mv as StandardMaterial3D).emission_energy_multiplier = 2.0 + tension * 0.75 + climax * 1.3

	for i in _course_pre.size():
		var n: MeshInstance3D = _course_pre[i]
		n.visible = local > 0.09 and local < 0.70
		if not n.visible:
			continue
		var progression: float = clampf((local - 0.09) / 0.61, 0.0, 1.0)
		var d: float = lerpf(50.0 + float(i) * 4.5, 2.5 + float(i) * 0.75, progression)
		n.transform = _course_transform(distance + d, distance, lane)
		var pulse: float = 0.90 + 0.11 * sin(progression * TAU * 2.2 + float(i))
		n.scale = Vector3.ONE * pulse
		n.rotation.z = progression * TAU * (0.14 + float(i) * 0.035)

	if _course_pre_mat != null:
		_course_pre_mat.emission_energy_multiplier = 1.15 + tension * 0.9 + climax * 2.0

	if local >= 0.57 and not _course_climax_done:
		_course_climax_done = true
		_vibrer(0.24, 0.06)


func _vibrer(force: float, duree: float) -> void:
	if app.main_d != null:
		app.main_d.trigger_haptic_pulse("haptic", 0.0, force, duree, 0.0)
	if app.main_g != null:
		app.main_g.trigger_haptic_pulse("haptic", 0.0, force, duree, 0.0)
