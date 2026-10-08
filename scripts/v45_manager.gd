class_name V45Manager
extends Node
## Mandala VR v45 : grands moments / set-pieces.
##
## Cette couche ne rajoute pas du bruit continu : elle cree des ruptures
## d'echelle memorables, deux fois par chapitre/secteur :
## - immense chambre geometrique ;
## - double tunnel fantome ;
## - explosion de structure ;
## - ouverture sur le vide + portail monumental.
##
## Aucun texte en plein trajet. La camera XR n'est jamais forcee.

const CHAMBER_RINGS: int = 14
const TWIN_RINGS: int = 18
const BURST_SHARDS: int = 28

var app = null
var v31 = null
var v32 = null
var v33 = null
var v36 = null
var v44 = null

var _installe: bool = false

# Grand 8
var _death_root: Node3D = null
var _death_chamber_node: MultiMeshInstance3D = null
var _death_chamber_mm: MultiMesh = null
var _death_left_node: MultiMeshInstance3D = null
var _death_left_mm: MultiMesh = null
var _death_right_node: MultiMeshInstance3D = null
var _death_right_mm: MultiMesh = null
var _death_burst_node: MultiMeshInstance3D = null
var _death_burst_mm: MultiMesh = null
var _death_void_floor: MeshInstance3D = null
var _death_void_gate: MeshInstance3D = null

var _death_chamber_mat: StandardMaterial3D = null
var _death_twin_mat: StandardMaterial3D = null
var _death_burst_mat: StandardMaterial3D = null
var _death_void_mat: StandardMaterial3D = null

# Course
var _course_root: Node3D = null
var _course_chamber_node: MultiMeshInstance3D = null
var _course_chamber_mm: MultiMesh = null
var _course_left_node: MultiMeshInstance3D = null
var _course_left_mm: MultiMesh = null
var _course_right_node: MultiMeshInstance3D = null
var _course_right_mm: MultiMesh = null
var _course_burst_node: MultiMeshInstance3D = null
var _course_burst_mm: MultiMesh = null
var _course_gate: MeshInstance3D = null

var _course_chamber_mat: StandardMaterial3D = null
var _course_twin_mat: StandardMaterial3D = null
var _course_burst_mat: StandardMaterial3D = null
var _course_gate_mat: StandardMaterial3D = null


func _ready() -> void:
	app = get_parent()
	v31 = app.get_node_or_null("V31Manager")
	v32 = app.get_node_or_null("V32Manager")
	v33 = app.get_node_or_null("V33Manager")
	v36 = app.get_node_or_null("V36Manager")
	v44 = app.get_node_or_null("V44Manager")
	process_priority = 360


func _process(_dt: float) -> void:
	if app == null:
		return

	if not _installe:
		var ready_ok: bool = (
			v31 != null and bool(v31.get("_installe"))
			and v32 != null and bool(v32.get("_installe"))
			and v33 != null and bool(v33.get("_installe"))
			and v36 != null and bool(v36.get("_installe"))
			and v44 != null and bool(v44.get("_installe"))
		)
		if ready_ok:
			_installer()
		return

	_maj_death_macro()
	_maj_course_macro()


func _installer() -> void:
	_installe = true
	_creer_death_macro()
	_creer_course_macro()


func _glow(c: Color, energy: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = Color(c.r, c.g, c.b, 1.0)
	m.emission_energy_multiplier = energy
	return m


func _set_color(m: StandardMaterial3D, c: Color, energy: float) -> void:
	if m == null:
		return
	m.albedo_color = c
	m.emission = Color(c.r, c.g, c.b, 1.0)
	m.emission_energy_multiplier = energy


func _hide_death_macro() -> void:
	if _death_chamber_node != null:
		_death_chamber_node.visible = false
	if _death_left_node != null:
		_death_left_node.visible = false
	if _death_right_node != null:
		_death_right_node.visible = false
	if _death_burst_node != null:
		_death_burst_node.visible = false
	if _death_void_floor != null:
		_death_void_floor.visible = false
	if _death_void_gate != null:
		_death_void_gate.visible = false


func _hide_course_macro() -> void:
	if _course_chamber_node != null:
		_course_chamber_node.visible = false
	if _course_left_node != null:
		_course_left_node.visible = false
	if _course_right_node != null:
		_course_right_node.visible = false
	if _course_burst_node != null:
		_course_burst_node.visible = false
	if _course_gate != null:
		_course_gate.visible = false


# =====================================================================
# GRAND 8

func _creer_death_macro() -> void:
	var rv: Variant = v31.get("_racine")
	if not (rv is Node3D):
		return
	_death_root = rv

	var chamber_mesh: TorusMesh = TorusMesh.new()
	chamber_mesh.inner_radius = 10.8
	chamber_mesh.outer_radius = 11.1
	chamber_mesh.rings = 44
	chamber_mesh.ring_segments = 8
	_death_chamber_mat = _glow(Color(0.22, 0.70, 1.0, 0.26), 1.35)
	chamber_mesh.material = _death_chamber_mat

	_death_chamber_mm = MultiMesh.new()
	_death_chamber_mm.transform_format = MultiMesh.TRANSFORM_3D
	_death_chamber_mm.instance_count = CHAMBER_RINGS
	_death_chamber_mm.mesh = chamber_mesh

	_death_chamber_node = MultiMeshInstance3D.new()
	_death_chamber_node.name = "V45DeathChamber"
	_death_chamber_node.multimesh = _death_chamber_mm
	_death_chamber_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_death_chamber_node.extra_cull_margin = 320.0
	_death_chamber_node.visible = false
	_death_root.add_child(_death_chamber_node)

	var twin_mesh: TorusMesh = TorusMesh.new()
	twin_mesh.inner_radius = 2.85
	twin_mesh.outer_radius = 2.98
	twin_mesh.rings = 32
	twin_mesh.ring_segments = 6
	_death_twin_mat = _glow(Color(0.66, 0.26, 1.0, 0.40), 1.85)
	twin_mesh.material = _death_twin_mat

	_death_left_mm = MultiMesh.new()
	_death_left_mm.transform_format = MultiMesh.TRANSFORM_3D
	_death_left_mm.instance_count = TWIN_RINGS
	_death_left_mm.mesh = twin_mesh
	_death_right_mm = MultiMesh.new()
	_death_right_mm.transform_format = MultiMesh.TRANSFORM_3D
	_death_right_mm.instance_count = TWIN_RINGS
	_death_right_mm.mesh = twin_mesh

	_death_left_node = MultiMeshInstance3D.new()
	_death_left_node.name = "V45DeathTwinLeft"
	_death_left_node.multimesh = _death_left_mm
	_death_left_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_death_left_node.extra_cull_margin = 250.0
	_death_left_node.visible = false
	_death_root.add_child(_death_left_node)

	_death_right_node = MultiMeshInstance3D.new()
	_death_right_node.name = "V45DeathTwinRight"
	_death_right_node.multimesh = _death_right_mm
	_death_right_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_death_right_node.extra_cull_margin = 250.0
	_death_right_node.visible = false
	_death_root.add_child(_death_right_node)

	var burst_mesh: BoxMesh = BoxMesh.new()
	burst_mesh.size = Vector3(0.22, 1.8, 0.22)
	_death_burst_mat = _glow(Color(1.0, 0.32, 0.16, 0.48), 2.15)
	burst_mesh.material = _death_burst_mat

	_death_burst_mm = MultiMesh.new()
	_death_burst_mm.transform_format = MultiMesh.TRANSFORM_3D
	_death_burst_mm.instance_count = BURST_SHARDS
	_death_burst_mm.mesh = burst_mesh

	_death_burst_node = MultiMeshInstance3D.new()
	_death_burst_node.name = "V45DeathBurst"
	_death_burst_node.multimesh = _death_burst_mm
	_death_burst_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_death_burst_node.extra_cull_margin = 260.0
	_death_burst_node.visible = false
	_death_root.add_child(_death_burst_node)

	_death_void_mat = _glow(Color(0.12, 0.52, 1.0, 0.25), 1.25)

	_death_void_floor = MeshInstance3D.new()
	_death_void_floor.name = "V45DeathVoidFloor"
	var floor_mesh: CylinderMesh = CylinderMesh.new()
	floor_mesh.top_radius = 18.0
	floor_mesh.bottom_radius = 18.0
	floor_mesh.height = 0.18
	floor_mesh.radial_segments = 48
	_death_void_floor.mesh = floor_mesh
	_death_void_floor.material_override = _death_void_mat
	_death_void_floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_death_void_floor.visible = false
	_death_root.add_child(_death_void_floor)

	_death_void_gate = MeshInstance3D.new()
	_death_void_gate.name = "V45DeathVoidGate"
	var gate_mesh: TorusMesh = TorusMesh.new()
	gate_mesh.inner_radius = 7.8
	gate_mesh.outer_radius = 8.05
	gate_mesh.rings = 48
	gate_mesh.ring_segments = 8
	_death_void_gate.mesh = gate_mesh
	_death_void_gate.material_override = _death_void_mat
	_death_void_gate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_death_void_gate.visible = false
	_death_root.add_child(_death_void_gate)


func _death_basis(d: float, chapitre: int, ratio: float) -> Basis:
	var p0_v: Variant = v36.call("_death_point", d, chapitre, ratio)
	var p1_v: Variant = v36.call("_death_point", d + 0.32, chapitre, ratio)
	if not (p0_v is Vector3) or not (p1_v is Vector3):
		return Basis()
	var p0: Vector3 = p0_v
	var p1: Vector3 = p1_v
	return Basis.looking_at((p1 - p0).normalized(), Vector3.UP)


func _maj_death_macro() -> void:
	if _death_root == null:
		return

	var mort: bool = bool(v32.get("_mort"))
	var etat: int = int(v32.get("_etat_mort"))
	if not mort or etat != 0:
		_hide_death_macro()
		return

	var chapitre: int = mini(int(v32.get("_chapitre")), 5)
	var phase: float = float(v32.get("_phase_t"))
	var fin: float = maxf(1.0, float(v32.get("_prochaine_rupture")))
	var ratio: float = clampf(phase / fin, 0.0, 1.0)

	# Deux grands moments par chapitre.
	var half: int = 0 if ratio < 0.5 else 1
	var local: float = ratio * 2.0 if half == 0 else (ratio - 0.5) * 2.0
	var type_evt: int = (chapitre * 2 + half) % 4

	_hide_death_macro()

	var colors: Array = [
		Color(0.20, 0.68, 1.0, 0.32),
		Color(0.70, 0.24, 1.0, 0.34),
		Color(0.10, 0.86, 1.0, 0.32),
		Color(1.0, 0.64, 0.18, 0.34),
		Color(1.0, 0.28, 0.12, 0.36),
		Color(0.82, 0.18, 1.0, 0.38),
	]
	var c: Color = colors[chapitre]

	match type_evt:
		0:
			_death_evt_chamber(chapitre, ratio, local, c)
		1:
			_death_evt_twins(chapitre, ratio, local, c)
		2:
			_death_evt_burst(chapitre, ratio, local, c)
		_:
			_death_evt_void(chapitre, ratio, local, c)


func _death_evt_chamber(chapitre: int, ratio: float, local: float, c: Color) -> void:
	_death_chamber_node.visible = true
	_set_color(_death_chamber_mat, c.lightened(0.18), 1.20 + sin(PI * local) * 1.15)

	var base_ring: Basis = Basis(Vector3.RIGHT, PI * 0.5)
	for i in CHAMBER_RINGS:
		var d: float = 10.0 + float(i) * 5.4
		var p_v: Variant = v36.call("_death_point", d, chapitre, ratio)
		if not (p_v is Vector3):
			continue
		var p: Vector3 = p_v
		var b: Basis = _death_basis(d, chapitre, ratio)
		var pulse: float = 0.86 + 0.18 * sin(local * TAU + float(i) * 0.72)
		var bb: Basis = b * base_ring
		bb = bb.scaled(Vector3(pulse, pulse, 1.0))
		_death_chamber_mm.set_instance_transform(i, Transform3D(bb, p))


func _death_evt_twins(chapitre: int, ratio: float, local: float, c: Color) -> void:
	_death_left_node.visible = true
	_death_right_node.visible = true
	_set_color(_death_twin_mat, c, 1.60 + sin(PI * local) * 1.30)

	var base_ring: Basis = Basis(Vector3.RIGHT, PI * 0.5)
	for i in TWIN_RINGS:
		var d: float = 12.0 + float(i) * 3.7
		var p_v: Variant = v36.call("_death_point", d, chapitre, ratio)
		if not (p_v is Vector3):
			continue
		var p: Vector3 = p_v
		var b: Basis = _death_basis(d, chapitre, ratio)

		var env: float = sin(PI * clampf(float(i) / float(TWIN_RINGS - 1), 0.0, 1.0))
		var split: float = 1.8 + env * (3.2 + sin(PI * local) * 1.2)

		var bb: Basis = b * base_ring
		_death_left_mm.set_instance_transform(i, Transform3D(bb, p - b.x * split))
		_death_right_mm.set_instance_transform(i, Transform3D(bb, p + b.x * split))


func _death_evt_burst(chapitre: int, ratio: float, local: float, c: Color) -> void:
	_death_burst_node.visible = true
	_set_color(_death_burst_mat, c.lightened(0.10), 1.75 + sin(PI * local) * 1.55)

	var opening: float = smoothstep(0.12, 0.72, local)
	for i in BURST_SHARDS:
		var d: float = 14.0 + float(i % 9) * 4.2
		var p_v: Variant = v36.call("_death_point", d, chapitre, ratio)
		if not (p_v is Vector3):
			continue
		var p: Vector3 = p_v
		var b: Basis = _death_basis(d, chapitre, ratio)

		var a: float = TAU * float(i) / float(BURST_SHARDS) + local * 1.2
		var radius: float = 2.4 + opening * (5.0 + float(i % 4) * 0.45)
		var radial: Vector3 = b.x * cos(a) * radius + b.y * sin(a) * radius
		var pos: Vector3 = p + radial

		var spin: float = a + opening * TAU * (0.18 + float(i % 5) * 0.025)
		var bb: Basis = b * Basis(Vector3.FORWARD, spin)
		var s: float = 0.75 + float(i % 4) * 0.20
		bb = bb.scaled(Vector3(s, s, s))
		_death_burst_mm.set_instance_transform(i, Transform3D(bb, pos))


func _death_evt_void(chapitre: int, ratio: float, local: float, c: Color) -> void:
	_death_void_floor.visible = true
	_death_void_gate.visible = true
	_set_color(_death_void_mat, c.darkened(0.08), 1.05 + sin(PI * local) * 1.45)

	var d: float = lerpf(58.0, 11.0, smoothstep(0.0, 0.82, local))
	var p_v: Variant = v36.call("_death_point", d, chapitre, ratio)
	if not (p_v is Vector3):
		return
	var p: Vector3 = p_v
	var b: Basis = _death_basis(d, chapitre, ratio)

	var floor_pos: Vector3 = p - b.y * (13.0 - sin(PI * local) * 2.0)
	_death_void_floor.transform = Transform3D(b, floor_pos)

	var gate_basis: Basis = b * Basis(Vector3.RIGHT, PI * 0.5)
	var gate_scale: float = 0.78 + sin(PI * local) * 0.42
	gate_basis = gate_basis.scaled(Vector3(gate_scale, gate_scale, 1.0))
	_death_void_gate.transform = Transform3D(gate_basis, p)


# =====================================================================
# COURSE

func _creer_course_macro() -> void:
	var rv: Variant = v33.get("_racine")
	if not (rv is Node3D):
		return
	_course_root = rv

	var chamber_mesh: TorusMesh = TorusMesh.new()
	chamber_mesh.inner_radius = 9.4
	chamber_mesh.outer_radius = 9.65
	chamber_mesh.rings = 40
	chamber_mesh.ring_segments = 8
	_course_chamber_mat = _glow(Color(0.20, 0.72, 1.0, 0.24), 1.25)
	chamber_mesh.material = _course_chamber_mat

	_course_chamber_mm = MultiMesh.new()
	_course_chamber_mm.transform_format = MultiMesh.TRANSFORM_3D
	_course_chamber_mm.instance_count = CHAMBER_RINGS
	_course_chamber_mm.mesh = chamber_mesh

	_course_chamber_node = MultiMeshInstance3D.new()
	_course_chamber_node.name = "V45CourseChamber"
	_course_chamber_node.multimesh = _course_chamber_mm
	_course_chamber_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_course_chamber_node.extra_cull_margin = 300.0
	_course_chamber_node.visible = false
	_course_root.add_child(_course_chamber_node)

	var twin_mesh: TorusMesh = TorusMesh.new()
	twin_mesh.inner_radius = 2.85
	twin_mesh.outer_radius = 2.98
	twin_mesh.rings = 32
	twin_mesh.ring_segments = 6
	_course_twin_mat = _glow(Color(0.72, 0.24, 1.0, 0.38), 1.75)
	twin_mesh.material = _course_twin_mat

	_course_left_mm = MultiMesh.new()
	_course_left_mm.transform_format = MultiMesh.TRANSFORM_3D
	_course_left_mm.instance_count = TWIN_RINGS
	_course_left_mm.mesh = twin_mesh
	_course_right_mm = MultiMesh.new()
	_course_right_mm.transform_format = MultiMesh.TRANSFORM_3D
	_course_right_mm.instance_count = TWIN_RINGS
	_course_right_mm.mesh = twin_mesh

	_course_left_node = MultiMeshInstance3D.new()
	_course_left_node.name = "V45CourseTwinLeft"
	_course_left_node.multimesh = _course_left_mm
	_course_left_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_course_left_node.extra_cull_margin = 230.0
	_course_left_node.visible = false
	_course_root.add_child(_course_left_node)

	_course_right_node = MultiMeshInstance3D.new()
	_course_right_node.name = "V45CourseTwinRight"
	_course_right_node.multimesh = _course_right_mm
	_course_right_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_course_right_node.extra_cull_margin = 230.0
	_course_right_node.visible = false
	_course_root.add_child(_course_right_node)

	var burst_mesh: BoxMesh = BoxMesh.new()
	burst_mesh.size = Vector3(0.20, 1.65, 0.20)
	_course_burst_mat = _glow(Color(1.0, 0.36, 0.18, 0.44), 2.0)
	burst_mesh.material = _course_burst_mat

	_course_burst_mm = MultiMesh.new()
	_course_burst_mm.transform_format = MultiMesh.TRANSFORM_3D
	_course_burst_mm.instance_count = BURST_SHARDS
	_course_burst_mm.mesh = burst_mesh

	_course_burst_node = MultiMeshInstance3D.new()
	_course_burst_node.name = "V45CourseBurst"
	_course_burst_node.multimesh = _course_burst_mm
	_course_burst_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_course_burst_node.extra_cull_margin = 240.0
	_course_burst_node.visible = false
	_course_root.add_child(_course_burst_node)

	_course_gate = MeshInstance3D.new()
	_course_gate.name = "V45CourseMegaGate"
	var gate_mesh: TorusMesh = TorusMesh.new()
	gate_mesh.inner_radius = 7.0
	gate_mesh.outer_radius = 7.25
	gate_mesh.rings = 44
	gate_mesh.ring_segments = 8
	_course_gate.mesh = gate_mesh
	_course_gate_mat = _glow(Color(0.18, 0.74, 1.0, 0.30), 1.30)
	_course_gate.material_override = _course_gate_mat
	_course_gate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_course_gate.visible = false
	_course_root.add_child(_course_gate)


func _course_basis(s: float) -> Basis:
	var b_v: Variant = v36.call("_course_basis", s)
	if b_v is Basis:
		return b_v
	return Basis()


func _course_transform(s: float, distance: float, lane: float) -> Transform3D:
	var p_v: Variant = v36.call("_course_point", s)
	var base_v: Variant = v36.call("_course_point", distance)
	if not (p_v is Vector3) or not (base_v is Vector3):
		return Transform3D()
	var p: Vector3 = p_v
	var base: Vector3 = base_v
	var b: Basis = _course_basis(s)
	return Transform3D(b, p - base - b.x * lane)


func _maj_course_macro() -> void:
	if _course_root == null:
		return

	var actif: bool = bool(v33.get("_actif"))
	if not actif:
		_hide_course_macro()
		return

	var distance: float = float(v33.get("_distance"))
	var lane: float = float(v33.get("_lane"))
	var secteur: int = int(v36.call("_course_sector", distance))
	var u: float = fposmod(distance, 165.0) / 165.0

	var half: int = 0 if u < 0.5 else 1
	var local: float = u * 2.0 if half == 0 else (u - 0.5) * 2.0
	var type_evt: int = (secteur * 2 + half) % 4

	_hide_course_macro()

	var colors: Array = [
		Color(0.18, 0.68, 1.0, 0.30),
		Color(0.64, 0.22, 1.0, 0.32),
		Color(1.0, 0.68, 0.18, 0.30),
		Color(0.10, 0.46, 1.0, 0.30),
		Color(0.14, 0.94, 0.72, 0.32),
		Color(1.0, 0.24, 0.46, 0.34),
	]
	var c: Color = colors[secteur]

	match type_evt:
		0:
			_course_evt_chamber(distance, lane, local, c)
		1:
			_course_evt_twins(distance, lane, local, c)
		2:
			_course_evt_burst(distance, lane, local, c)
		_:
			_course_evt_gate(distance, lane, local, c)


func _course_evt_chamber(distance: float, lane: float, local: float, c: Color) -> void:
	_course_chamber_node.visible = true
	_set_color(_course_chamber_mat, c.lightened(0.18), 1.15 + sin(PI * local) * 1.10)

	var base_ring: Basis = Basis(Vector3.RIGHT, PI * 0.5)
	for i in CHAMBER_RINGS:
		var s: float = distance + 10.0 + float(i) * 5.1
		var tr: Transform3D = _course_transform(s, distance, lane)
		var pulse: float = 0.86 + 0.18 * sin(local * TAU + float(i) * 0.70)
		var bb: Basis = tr.basis * base_ring
		bb = bb.scaled(Vector3(pulse, pulse, 1.0))
		_course_chamber_mm.set_instance_transform(i, Transform3D(bb, tr.origin))


func _course_evt_twins(distance: float, lane: float, local: float, c: Color) -> void:
	_course_left_node.visible = true
	_course_right_node.visible = true
	_set_color(_course_twin_mat, c, 1.55 + sin(PI * local) * 1.20)

	var base_ring: Basis = Basis(Vector3.RIGHT, PI * 0.5)
	for i in TWIN_RINGS:
		var s: float = distance + 12.0 + float(i) * 3.6
		var tr: Transform3D = _course_transform(s, distance, lane)

		var env: float = sin(PI * clampf(float(i) / float(TWIN_RINGS - 1), 0.0, 1.0))
		var split: float = 1.8 + env * (3.0 + sin(PI * local) * 1.15)
		var bb: Basis = tr.basis * base_ring

		_course_left_mm.set_instance_transform(i, Transform3D(bb, tr.origin - tr.basis.x * split))
		_course_right_mm.set_instance_transform(i, Transform3D(bb, tr.origin + tr.basis.x * split))


func _course_evt_burst(distance: float, lane: float, local: float, c: Color) -> void:
	_course_burst_node.visible = true
	_set_color(_course_burst_mat, c.lightened(0.08), 1.70 + sin(PI * local) * 1.45)

	var opening: float = smoothstep(0.12, 0.72, local)
	for i in BURST_SHARDS:
		var s: float = distance + 14.0 + float(i % 9) * 4.1
		var tr: Transform3D = _course_transform(s, distance, lane)

		var a: float = TAU * float(i) / float(BURST_SHARDS) + local * 1.1
		var radius: float = 2.5 + opening * (4.5 + float(i % 4) * 0.42)
		var radial: Vector3 = tr.basis.x * cos(a) * radius + tr.basis.y * sin(a) * radius
		var pos: Vector3 = tr.origin + radial

		var bb: Basis = tr.basis * Basis(Vector3.FORWARD, a + opening * TAU * 0.20)
		var scale_v: float = 0.78 + float(i % 4) * 0.18
		bb = bb.scaled(Vector3.ONE * scale_v)
		_course_burst_mm.set_instance_transform(i, Transform3D(bb, pos))


func _course_evt_gate(distance: float, lane: float, local: float, c: Color) -> void:
	_course_gate.visible = true
	_set_color(_course_gate_mat, c.lightened(0.18), 1.15 + sin(PI * local) * 1.55)

	var d: float = lerpf(64.0, 8.0, smoothstep(0.0, 0.86, local))
	var s: float = distance + d
	var tr: Transform3D = _course_transform(s, distance, lane)

	var gate_basis: Basis = tr.basis * Basis(Vector3.RIGHT, PI * 0.5)
	var pulse: float = 0.78 + sin(PI * local) * 0.48
	gate_basis = gate_basis.scaled(Vector3(pulse, pulse, 1.0))
	_course_gate.transform = Transform3D(gate_basis, tr.origin)
