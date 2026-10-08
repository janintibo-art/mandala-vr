class_name V44Manager
extends Node
## Mandala VR v44 : architecture vivante.
##
## Ajoute du mouvement aux grandes structures sans surcharger la scene :
## - machoires laterales qui se ferment puis s'ouvrent ;
## - pales / lames qui tournent autour du tunnel ;
## - portes respirantes et ponts mobiles dans la Course ;
## - intensite adaptee aux chapitres / secteurs.
##
## Aucun texte n'est affiche pendant l'experience.
## Une zone centrale de securite reste toujours libre.

const DEATH_JAWS: int = 20
const DEATH_BLADES: int = 18
const COURSE_JAWS: int = 18
const COURSE_BLADES: int = 16

var app = null
var v31 = null
var v32 = null
var v33 = null
var v36 = null
var v43 = null

var _installe: bool = false

# Grand 8
var _death_parent: Node3D = null
var _death_jaws_node: MultiMeshInstance3D = null
var _death_jaws_mm: MultiMesh = null
var _death_blades_node: MultiMeshInstance3D = null
var _death_blades_mm: MultiMesh = null
var _death_jaw_mat: StandardMaterial3D = null
var _death_blade_mat: StandardMaterial3D = null

# Course
var _course_parent: Node3D = null
var _course_jaws_node: MultiMeshInstance3D = null
var _course_jaws_mm: MultiMesh = null
var _course_blades_node: MultiMeshInstance3D = null
var _course_blades_mm: MultiMesh = null
var _course_jaw_mat: StandardMaterial3D = null
var _course_blade_mat: StandardMaterial3D = null


func _ready() -> void:
	app = get_parent()
	v31 = app.get_node_or_null("V31Manager")
	v32 = app.get_node_or_null("V32Manager")
	v33 = app.get_node_or_null("V33Manager")
	v36 = app.get_node_or_null("V36Manager")
	v43 = app.get_node_or_null("V43Manager")
	process_priority = 350


func _process(_dt: float) -> void:
	if app == null:
		return

	if not _installe:
		var ready_ok: bool = (
			v31 != null and bool(v31.get("_installe"))
			and v32 != null and bool(v32.get("_installe"))
			and v33 != null and bool(v33.get("_installe"))
			and v36 != null and bool(v36.get("_installe"))
			and v43 != null and bool(v43.get("_installe"))
		)
		if ready_ok:
			_installer()
		return

	_maj_death_motion()
	_maj_course_motion()


func _installer() -> void:
	_installe = true
	_creer_death_motion()
	_creer_course_motion()


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


func _set_color(m: StandardMaterial3D, c: Color, energy: float) -> void:
	if m == null:
		return
	m.albedo_color = c
	m.emission = Color(c.r, c.g, c.b, 1.0)
	m.emission_energy_multiplier = energy


# =====================================================================
# GRAND 8

func _creer_death_motion() -> void:
	var root_v: Variant = v31.get("_racine")
	if not (root_v is Node3D):
		return
	_death_parent = root_v

	var jaw_mesh: BoxMesh = BoxMesh.new()
	jaw_mesh.size = Vector3(2.8, 0.18, 0.22)
	_death_jaw_mat = _glow(Color(0.22, 0.70, 1.0, 0.48), 1.9)
	jaw_mesh.material = _death_jaw_mat

	_death_jaws_mm = MultiMesh.new()
	_death_jaws_mm.transform_format = MultiMesh.TRANSFORM_3D
	_death_jaws_mm.instance_count = DEATH_JAWS
	_death_jaws_mm.mesh = jaw_mesh

	_death_jaws_node = MultiMeshInstance3D.new()
	_death_jaws_node.name = "V44DeathJaws"
	_death_jaws_node.multimesh = _death_jaws_mm
	_death_jaws_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_death_jaws_node.extra_cull_margin = 220.0
	_death_jaws_node.visible = false
	_death_parent.add_child(_death_jaws_node)

	var blade_mesh: BoxMesh = BoxMesh.new()
	blade_mesh.size = Vector3(2.4, 0.09, 0.09)
	_death_blade_mat = _glow(Color(0.90, 0.26, 1.0, 0.52), 2.1)
	blade_mesh.material = _death_blade_mat

	_death_blades_mm = MultiMesh.new()
	_death_blades_mm.transform_format = MultiMesh.TRANSFORM_3D
	_death_blades_mm.instance_count = DEATH_BLADES
	_death_blades_mm.mesh = blade_mesh

	_death_blades_node = MultiMeshInstance3D.new()
	_death_blades_node.name = "V44DeathBlades"
	_death_blades_node.multimesh = _death_blades_mm
	_death_blades_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_death_blades_node.extra_cull_margin = 220.0
	_death_blades_node.visible = false
	_death_parent.add_child(_death_blades_node)


func _death_basis(d: float, chapitre: int, ratio: float) -> Basis:
	var p0_v: Variant = v36.call("_death_point", d, chapitre, ratio)
	var p1_v: Variant = v36.call("_death_point", d + 0.30, chapitre, ratio)
	if not (p0_v is Vector3) or not (p1_v is Vector3):
		return Basis()
	var p0: Vector3 = p0_v
	var p1: Vector3 = p1_v
	return Basis.looking_at((p1 - p0).normalized(), Vector3.UP)


func _maj_death_motion() -> void:
	if _death_jaws_node == null:
		return

	var mort: bool = bool(v32.get("_mort"))
	var etat: int = int(v32.get("_etat_mort"))
	var visible: bool = mort and etat == 0
	_death_jaws_node.visible = visible
	_death_blades_node.visible = visible
	if not visible:
		return

	var chapitre: int = mini(int(v32.get("_chapitre")), 5)
	var phase: float = float(v32.get("_phase_t"))
	var fin: float = maxf(1.0, float(v32.get("_prochaine_rupture")))
	var ratio: float = clampf(phase / fin, 0.0, 1.0)
	var travel: float = float(v31.get("_travel"))

	var colors_jaw: Array = [
		Color(0.18, 0.62, 1.0, 0.48),
		Color(0.64, 0.20, 1.0, 0.52),
		Color(0.12, 0.78, 1.0, 0.48),
		Color(1.0, 0.52, 0.18, 0.50),
		Color(1.0, 0.24, 0.12, 0.54),
		Color(0.72, 0.16, 1.0, 0.58),
	]
	var colors_blade: Array = [
		Color(0.48, 0.84, 1.0, 0.50),
		Color(0.92, 0.30, 1.0, 0.54),
		Color(0.20, 0.90, 1.0, 0.50),
		Color(1.0, 0.74, 0.20, 0.52),
		Color(1.0, 0.38, 0.16, 0.56),
		Color(0.92, 0.20, 1.0, 0.60),
	]
	_set_color(_death_jaw_mat, colors_jaw[chapitre], 1.75 + float(chapitre) * 0.13)
	_set_color(_death_blade_mat, colors_blade[chapitre], 1.95 + float(chapitre) * 0.15)

	# Paires de machoires : fermeture au milieu du passage puis ouverture.
	for i in DEATH_JAWS:
		var pair_index: int = i / 2
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var d: float = fposmod(float(pair_index) * 9.2 - travel * 0.58, 96.0) + 10.0

		var p_v: Variant = v36.call("_death_point", d, chapitre, ratio)
		if not (p_v is Vector3):
			continue
		var p: Vector3 = p_v
		var b: Basis = _death_basis(d, chapitre, ratio)

		# 1 loin, 0 tres proche.
		var proximity: float = 1.0 - clampf(d / 30.0, 0.0, 1.0)
		var pulse: float = 0.5 + 0.5 * sin(
			phase * (1.25 + float(chapitre) * 0.10)
			+ float(pair_index) * 1.35)

		# Couloir libre minimum ~1.45 m depuis le centre.
		var gap: float = lerpf(3.3, 1.55, pulse * proximity)
		if chapitre >= 4:
			gap -= 0.08
		gap = maxf(gap, 1.45)

		var height: float = sin(float(pair_index) * 1.70 + phase * 0.38) * 0.85
		var pos: Vector3 = p + b.x * side * gap + b.y * height

		var tilt: float = side * lerpf(0.08, 0.34, pulse * proximity)
		var bb: Basis = b * Basis(Vector3.FORWARD, tilt)
		var stretch: float = 0.85 + proximity * 0.40
		bb = bb.scaled(Vector3(stretch, 1.0, 1.0))
		_death_jaws_mm.set_instance_transform(i, Transform3D(bb, pos))

	# Pales rotatives sur une orbite plus large : elles ne traversent jamais
	# le centre mais donnent l'impression que tout le decor est mecanique.
	for i in DEATH_BLADES:
		var d2: float = fposmod(float(i) * 6.3 - travel * 0.42, 112.0) + 13.0
		var p2_v: Variant = v36.call("_death_point", d2, chapitre, ratio)
		if not (p2_v is Vector3):
			continue
		var p2: Vector3 = p2_v
		var b2: Basis = _death_basis(d2, chapitre, ratio)

		var speed: float = 0.42 + float(chapitre) * 0.08
		var a: float = phase * speed + float(i) * 1.17
		var radius: float = 3.4 + float(i % 4) * 0.38
		if chapitre >= 4:
			radius -= 0.20
		radius = maxf(radius, 3.0)

		var radial: Vector3 = b2.x * cos(a) * radius + b2.y * sin(a) * radius
		var pos2: Vector3 = p2 + radial
		var bb2: Basis = b2 * Basis(Vector3.FORWARD, a + PI * 0.5)
		_death_blades_mm.set_instance_transform(i, Transform3D(bb2, pos2))


# =====================================================================
# COURSE

func _creer_course_motion() -> void:
	var root_v: Variant = v33.get("_racine")
	if not (root_v is Node3D):
		return
	_course_parent = root_v

	var jaw_mesh: BoxMesh = BoxMesh.new()
	jaw_mesh.size = Vector3(2.6, 0.16, 0.20)
	_course_jaw_mat = _glow(Color(0.18, 0.66, 1.0, 0.42), 1.8)
	jaw_mesh.material = _course_jaw_mat

	_course_jaws_mm = MultiMesh.new()
	_course_jaws_mm.transform_format = MultiMesh.TRANSFORM_3D
	_course_jaws_mm.instance_count = COURSE_JAWS
	_course_jaws_mm.mesh = jaw_mesh

	_course_jaws_node = MultiMeshInstance3D.new()
	_course_jaws_node.name = "V44CourseJaws"
	_course_jaws_node.multimesh = _course_jaws_mm
	_course_jaws_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_course_jaws_node.extra_cull_margin = 220.0
	_course_jaws_node.visible = false
	_course_parent.add_child(_course_jaws_node)

	var blade_mesh: BoxMesh = BoxMesh.new()
	blade_mesh.size = Vector3(2.2, 0.085, 0.085)
	_course_blade_mat = _glow(Color(0.76, 0.30, 1.0, 0.46), 1.95)
	blade_mesh.material = _course_blade_mat

	_course_blades_mm = MultiMesh.new()
	_course_blades_mm.transform_format = MultiMesh.TRANSFORM_3D
	_course_blades_mm.instance_count = COURSE_BLADES
	_course_blades_mm.mesh = blade_mesh

	_course_blades_node = MultiMeshInstance3D.new()
	_course_blades_node.name = "V44CourseBlades"
	_course_blades_node.multimesh = _course_blades_mm
	_course_blades_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_course_blades_node.extra_cull_margin = 220.0
	_course_blades_node.visible = false
	_course_parent.add_child(_course_blades_node)


func _course_basis(s: float) -> Basis:
	var b_v: Variant = v36.call("_course_basis", s)
	if b_v is Basis:
		return b_v
	return Basis()


func _maj_course_motion() -> void:
	if _course_jaws_node == null:
		return

	var actif: bool = bool(v33.get("_actif"))
	_course_jaws_node.visible = actif
	_course_blades_node.visible = actif
	if not actif:
		return

	var distance: float = float(v33.get("_distance"))
	var lane: float = float(v33.get("_lane"))
	var base_v: Variant = v36.call("_course_point", distance)
	if not (base_v is Vector3):
		return
	var base: Vector3 = base_v

	var secteur: int = int(v36.call("_course_sector", distance))
	var sector_colors: Array = [
		Color(0.18, 0.68, 1.0, 0.44),
		Color(0.66, 0.22, 1.0, 0.48),
		Color(1.0, 0.70, 0.18, 0.44),
		Color(0.12, 0.48, 1.0, 0.44),
		Color(0.18, 0.96, 0.74, 0.48),
		Color(1.0, 0.26, 0.46, 0.52),
	]
	var c: Color = sector_colors[secteur]
	_set_color(_course_jaw_mat, c, 1.65 + float(secteur) * 0.06)
	_set_color(_course_blade_mat, c.lightened(0.18), 1.85 + float(secteur) * 0.08)

	for i in COURSE_JAWS:
		var pair_index: int = i / 2
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var d: float = 10.0 + float(pair_index) * 10.2
		var s: float = distance + d

		var p_v: Variant = v36.call("_course_point", s)
		if not (p_v is Vector3):
			continue
		var p: Vector3 = p_v
		var b: Basis = _course_basis(s)
		var centre: Vector3 = p - base - b.x * lane

		var proximity: float = 1.0 - clampf(d / 34.0, 0.0, 1.0)
		var pulse_speed: float = 0.060 + float(secteur) * 0.005
		var pulse: float = 0.5 + 0.5 * sin(
			distance * pulse_speed + float(pair_index) * 1.45)

		var gap: float = lerpf(3.1, 1.62, pulse * proximity)
		if secteur == 5:
			gap -= 0.10
		gap = maxf(gap, 1.50)

		var height: float = sin(float(pair_index) * 1.30 + distance * 0.025) * 0.75
		var pos: Vector3 = centre + b.x * side * gap + b.y * height

		var tilt: float = side * lerpf(0.06, 0.30, pulse * proximity)
		var bb: Basis = b * Basis(Vector3.FORWARD, tilt)
		_course_jaws_mm.set_instance_transform(i, Transform3D(bb, pos))

	for i in COURSE_BLADES:
		var d2: float = 14.0 + float(i) * 6.5
		var s2: float = distance + d2
		var p2_v: Variant = v36.call("_course_point", s2)
		if not (p2_v is Vector3):
			continue
		var p2: Vector3 = p2_v
		var b2: Basis = _course_basis(s2)
		var centre2: Vector3 = p2 - base - b2.x * lane

		var a: float = distance * (0.022 + float(secteur) * 0.0025) + float(i) * 1.29
		var radius: float = 3.3 + float(i % 4) * 0.34
		if secteur == 1 or secteur == 5:
			radius -= 0.20
		radius = maxf(radius, 3.0)

		var radial: Vector3 = b2.x * cos(a) * radius + b2.y * sin(a) * radius
		var pos2: Vector3 = centre2 + radial
		var bb2: Basis = b2 * Basis(Vector3.FORWARD, a + PI * 0.5)
		_course_blades_mm.set_instance_transform(i, Transform3D(bb2, pos2))
