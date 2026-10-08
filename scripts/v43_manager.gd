class_name V43Manager
extends Node
## v51 : ordonnancement optimise des couches decoratives Quest.
## Mandala VR v43 : profondeur et transitions.
##
## Objectif : faire exister un monde autour du tunnel.
## Les structures lointaines arrivent avant les structures proches,
## passent autour du joueur puis disparaissent derriere lui.
## Aucun texte n'est affiche pendant l'experience.

const DEATH_TOWERS: int = 48
const DEATH_ARCHES: int = 14
const COURSE_TOWERS: int = 56
const COURSE_ARCHES: int = 14
const COURSE_BRIDGES: int = 18

var app = null
var v31 = null
var v32 = null
var v33 = null
var v36 = null
var v41 = null

var _installe: bool = false
var _death_prev_active: bool = false
var _course_prev_active: bool = false
var _slow_flip: bool = false

# Grand 8
var _death_parent: Node3D = null
var _death_towers_node: MultiMeshInstance3D = null
var _death_towers_mm: MultiMesh = null
var _death_arches_node: MultiMeshInstance3D = null
var _death_arches_mm: MultiMesh = null
var _death_tower_mat: StandardMaterial3D = null
var _death_arch_mat: StandardMaterial3D = null

# Course
var _course_parent: Node3D = null
var _course_towers_node: MultiMeshInstance3D = null
var _course_towers_mm: MultiMesh = null
var _course_arches_node: MultiMeshInstance3D = null
var _course_arches_mm: MultiMesh = null
var _course_bridges_node: MultiMeshInstance3D = null
var _course_bridges_mm: MultiMesh = null
var _course_tower_mat: StandardMaterial3D = null
var _course_arch_mat: StandardMaterial3D = null
var _course_bridge_mat: StandardMaterial3D = null


func _ready() -> void:
	app = get_parent()
	v31 = app.get_node_or_null("V31Manager")
	v32 = app.get_node_or_null("V32Manager")
	v33 = app.get_node_or_null("V33Manager")
	v36 = app.get_node_or_null("V36Manager")
	v41 = app.get_node_or_null("V41Manager")
	process_priority = 340


func _process(_dt: float) -> void:
	if app == null:
		return

	if not _installe:
		var pret: bool = (
			v31 != null and bool(v31.get("_installe"))
			and v32 != null and bool(v32.get("_installe"))
			and v33 != null and bool(v33.get("_installe"))
			and v36 != null and bool(v36.get("_installe"))
			and v41 != null and bool(v41.get("_installe"))
		)
		if pret:
			_installer()
		return

	_slow_flip = not _slow_flip
	var death_active: bool = bool(v32.get("_mort"))
	var course_active: bool = bool(v33.get("_actif"))

	# v51 : les couches decoratives ne travaillent que dans le mode actif.
	# Une derniere mise a jour est executee a la sortie pour masquer proprement
	# les geometries avant de mettre la couche au repos.
	if death_active or _death_prev_active:
		if death_active != _death_prev_active or _slow_flip:
			_maj_death_depth()
	if course_active or _course_prev_active:
		if course_active != _course_prev_active or _slow_flip:
			_maj_course_depth()

	_death_prev_active = death_active
	_course_prev_active = course_active


func _installer() -> void:
	_installe = true
	_creer_death_depth()
	_creer_course_depth()


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


# =====================================================================
# GRAND 8 : profondeur / parallaxe

func _creer_death_depth() -> void:
	var rv: Variant = v31.get("_racine")
	if not (rv is Node3D):
		return
	_death_parent = rv

	var tower_mesh: BoxMesh = BoxMesh.new()
	tower_mesh.size = Vector3(0.55, 7.5, 0.55)
	_death_tower_mat = _glow(Color(0.10, 0.34, 0.78, 0.18), 0.95)
	tower_mesh.material = _death_tower_mat

	_death_towers_mm = MultiMesh.new()
	_death_towers_mm.transform_format = MultiMesh.TRANSFORM_3D
	_death_towers_mm.instance_count = DEATH_TOWERS
	_death_towers_mm.mesh = tower_mesh

	_death_towers_node = MultiMeshInstance3D.new()
	_death_towers_node.name = "V43DeathTowers"
	_death_towers_node.multimesh = _death_towers_mm
	_death_towers_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_death_towers_node.extra_cull_margin = 260.0
	_death_towers_node.visible = false
	_death_parent.add_child(_death_towers_node)

	var arch_mesh: TorusMesh = TorusMesh.new()
	arch_mesh.inner_radius = 8.8
	arch_mesh.outer_radius = 9.02
	arch_mesh.rings = 44
	arch_mesh.ring_segments = 8
	_death_arch_mat = _glow(Color(0.28, 0.70, 1.0, 0.22), 1.10)
	arch_mesh.material = _death_arch_mat

	_death_arches_mm = MultiMesh.new()
	_death_arches_mm.transform_format = MultiMesh.TRANSFORM_3D
	_death_arches_mm.instance_count = DEATH_ARCHES
	_death_arches_mm.mesh = arch_mesh

	_death_arches_node = MultiMeshInstance3D.new()
	_death_arches_node.name = "V43DeathFarArches"
	_death_arches_node.multimesh = _death_arches_mm
	_death_arches_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_death_arches_node.extra_cull_margin = 300.0
	_death_arches_node.visible = false
	_death_parent.add_child(_death_arches_node)


func _death_basis(d: float, chapitre: int, ratio: float) -> Basis:
	var p0_v: Variant = v36.call("_death_point", d, chapitre, ratio)
	var p1_v: Variant = v36.call("_death_point", d + 0.34, chapitre, ratio)
	if not (p0_v is Vector3) or not (p1_v is Vector3):
		return Basis()
	var p0: Vector3 = p0_v
	var p1: Vector3 = p1_v
	return Basis.looking_at((p1 - p0).normalized(), Vector3.UP)


func _set_mat_color(mat: StandardMaterial3D, c: Color, energy: float) -> void:
	if mat == null:
		return
	mat.albedo_color = c
	mat.emission = Color(c.r, c.g, c.b, 1.0)
	mat.emission_energy_multiplier = energy


func _maj_death_depth() -> void:
	if _death_towers_node == null:
		return

	var mort: bool = bool(v32.get("_mort"))
	var etat: int = int(v32.get("_etat_mort"))
	var visible: bool = mort and etat == 0
	_death_towers_node.visible = visible
	_death_arches_node.visible = visible
	if not visible:
		return

	var chapitre: int = mini(int(v32.get("_chapitre")), 5)
	var phase: float = float(v32.get("_phase_t"))
	var fin: float = maxf(1.0, float(v32.get("_prochaine_rupture")))
	var ratio: float = clampf(phase / fin, 0.0, 1.0)
	var travel: float = float(v31.get("_travel"))
	var acte_f: float = ratio * 4.0
	var local: float = acte_f - floor(acte_f)

	# Les gros changements se preparent avant le milieu de chaque acte,
	# puis s'ouvrent de nouveau. Cela remplace les anciens titres de zones.
	var transition: float = sin(PI * local)
	transition *= transition

	var colors: Array = [
		Color(0.12, 0.46, 1.0, 0.18),
		Color(0.70, 0.18, 1.0, 0.20),
		Color(0.06, 0.58, 0.92, 0.17),
		Color(0.96, 0.58, 0.16, 0.20),
		Color(1.0, 0.22, 0.10, 0.22),
		Color(0.66, 0.12, 1.0, 0.24),
	]
	var c: Color = colors[chapitre]
	_set_mat_color(_death_tower_mat, c, 0.82 + transition * 0.55 + float(chapitre) * 0.08)
	_set_mat_color(_death_arch_mat, c.lightened(0.22), 0.95 + transition * 0.75 + float(chapitre) * 0.10)

	for i in DEATH_TOWERS:
		# Couche lointaine : elle defile volontairement moins vite
		# que le tunnel pour creer du parallaxe.
		var d: float = fposmod(float(i) * 5.9 - travel * 0.34, 154.0) + 16.0
		var p_v: Variant = v36.call("_death_point", d, chapitre, ratio)
		if not (p_v is Vector3):
			continue
		var p: Vector3 = p_v
		var b: Basis = _death_basis(d, chapitre, ratio)

		var side: float = -1.0 if i % 2 == 0 else 1.0
		var radial: float = 9.0 + float(i % 6) * 1.25
		var height: float = sin(float(i) * 1.37 + phase * 0.18) * 4.0
		var sx: float = 1.0
		var sy: float = 1.0
		var sz: float = 1.0
		var roll: float = 0.0

		match chapitre:
			0:
				radial += 1.8
				height = -2.0 + float(i % 5) * 1.4
				sy = 1.25 + float(i % 4) * 0.40
			1:
				var a1: float = d * 0.06 + float(i) * 0.43
				side = cos(a1)
				height = sin(a1) * 6.0
				radial = 8.5 + float(i % 5) * 0.85
				roll = a1 * 0.35
			2:
				radial = 12.0 + float(i % 7) * 1.55
				height = -5.0 + float(i % 8) * 1.35
				sy = 2.0 + float(i % 4) * 0.55
				sx = 1.4
				sz = 1.4
			3:
				radial = 9.5 + float(i % 3) * 1.0
				height = 2.0
				sy = 2.6 + float(i % 4) * 0.65
				sx = 0.75
				sz = 0.75
			4:
				radial = 8.0 + float(i % 8) * 1.15
				height = sin(float(i) * 2.1) * 6.5
				sx = 0.8 + float(i % 4) * 0.50
				sy = 0.45 + float(i % 5) * 0.36
				sz = 0.8 + float(i % 3) * 0.45
				roll = float(i % 9) * 0.29
			_:
				var a6: float = d * 0.075 + float(i) * 0.61
				side = cos(a6)
				height = sin(a6) * (4.0 + float(i % 4))
				radial = 8.0 + float(i % 9) * 1.05
				sx = 0.65 + float(i % 5) * 0.42
				sy = 0.55 + float((i + 2) % 6) * 0.40
				sz = 0.75 + float((i + 3) % 4) * 0.38
				roll = a6

		# Les structures s'ecartent en transition et se resserrent au climax.
		radial *= lerpf(1.18, 0.92, transition)
		var pos: Vector3 = p + b.x * side * radial + b.y * height
		var bb: Basis = b * Basis(Vector3.FORWARD, roll)
		bb = bb.scaled(Vector3(sx, sy, sz))
		_death_towers_mm.set_instance_transform(i, Transform3D(bb, pos))

	var base_ring: Basis = Basis(Vector3.RIGHT, PI * 0.5)
	for i in DEATH_ARCHES:
		var d2: float = fposmod(float(i) * 13.0 - travel * 0.22, 182.0) + 24.0
		var p2_v: Variant = v36.call("_death_point", d2, chapitre, ratio)
		if not (p2_v is Vector3):
			continue
		var p2: Vector3 = p2_v
		var b2: Basis = _death_basis(d2, chapitre, ratio)
		var sc: float = 0.82 + float(i % 4) * 0.13 + transition * 0.12
		if chapitre == 2:
			sc *= 1.35
		elif chapitre == 3:
			sc *= 1.15
		elif chapitre >= 4:
			sc *= 0.88 + 0.20 * sin(float(i) * 1.3 + phase)
		var rb: Basis = b2 * base_ring
		rb = rb.scaled(Vector3(sc, sc, 1.0))
		_death_arches_mm.set_instance_transform(i, Transform3D(rb, p2))


# =====================================================================
# COURSE : profondeur des secteurs

func _creer_course_depth() -> void:
	var rv: Variant = v33.get("_racine")
	if not (rv is Node3D):
		return
	_course_parent = rv

	var tower_mesh: BoxMesh = BoxMesh.new()
	tower_mesh.size = Vector3(0.50, 7.2, 0.50)
	_course_tower_mat = _glow(Color(0.10, 0.46, 0.90, 0.18), 0.95)
	tower_mesh.material = _course_tower_mat

	_course_towers_mm = MultiMesh.new()
	_course_towers_mm.transform_format = MultiMesh.TRANSFORM_3D
	_course_towers_mm.instance_count = COURSE_TOWERS
	_course_towers_mm.mesh = tower_mesh

	_course_towers_node = MultiMeshInstance3D.new()
	_course_towers_node.name = "V43CourseTowers"
	_course_towers_node.multimesh = _course_towers_mm
	_course_towers_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_course_towers_node.extra_cull_margin = 260.0
	_course_towers_node.visible = false
	_course_parent.add_child(_course_towers_node)

	var arch_mesh: TorusMesh = TorusMesh.new()
	arch_mesh.inner_radius = 7.4
	arch_mesh.outer_radius = 7.60
	arch_mesh.rings = 40
	arch_mesh.ring_segments = 8
	_course_arch_mat = _glow(Color(0.22, 0.72, 1.0, 0.20), 1.10)
	arch_mesh.material = _course_arch_mat

	_course_arches_mm = MultiMesh.new()
	_course_arches_mm.transform_format = MultiMesh.TRANSFORM_3D
	_course_arches_mm.instance_count = COURSE_ARCHES
	_course_arches_mm.mesh = arch_mesh

	_course_arches_node = MultiMeshInstance3D.new()
	_course_arches_node.name = "V43CourseFarArches"
	_course_arches_node.multimesh = _course_arches_mm
	_course_arches_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_course_arches_node.extra_cull_margin = 280.0
	_course_arches_node.visible = false
	_course_parent.add_child(_course_arches_node)

	var bridge_mesh: BoxMesh = BoxMesh.new()
	bridge_mesh.size = Vector3(8.0, 0.16, 0.16)
	_course_bridge_mat = _glow(Color(0.50, 0.82, 1.0, 0.22), 1.20)
	bridge_mesh.material = _course_bridge_mat

	_course_bridges_mm = MultiMesh.new()
	_course_bridges_mm.transform_format = MultiMesh.TRANSFORM_3D
	_course_bridges_mm.instance_count = COURSE_BRIDGES
	_course_bridges_mm.mesh = bridge_mesh

	_course_bridges_node = MultiMeshInstance3D.new()
	_course_bridges_node.name = "V43CourseBridges"
	_course_bridges_node.multimesh = _course_bridges_mm
	_course_bridges_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_course_bridges_node.extra_cull_margin = 240.0
	_course_bridges_node.visible = false
	_course_parent.add_child(_course_bridges_node)


func _course_basis(s: float) -> Basis:
	var bv: Variant = v36.call("_course_basis", s)
	if bv is Basis:
		return bv
	return Basis()


func _maj_course_depth() -> void:
	if _course_towers_node == null:
		return

	var actif: bool = bool(v33.get("_actif"))
	_course_towers_node.visible = actif
	_course_arches_node.visible = actif
	_course_bridges_node.visible = actif
	if not actif:
		return

	var distance: float = float(v33.get("_distance"))
	var lane: float = float(v33.get("_lane"))
	var base_v: Variant = v36.call("_course_point", distance)
	if not (base_v is Vector3):
		return
	var base: Vector3 = base_v

	var secteur: int = int(v36.call("_course_sector", distance))
	var u: float = fposmod(distance, 165.0) / 165.0
	var transition: float = sin(PI * u)
	transition *= transition

	var colors: Array = [
		Color(0.12, 0.62, 1.0, 0.18),
		Color(0.62, 0.18, 1.0, 0.20),
		Color(1.0, 0.68, 0.16, 0.18),
		Color(0.08, 0.36, 0.90, 0.17),
		Color(0.12, 0.92, 0.72, 0.20),
		Color(1.0, 0.22, 0.44, 0.22),
	]
	var c: Color = colors[secteur]
	_set_mat_color(_course_tower_mat, c, 0.85 + transition * 0.55)
	_set_mat_color(_course_arch_mat, c.lightened(0.22), 1.00 + transition * 0.70)
	_set_mat_color(_course_bridge_mat, c.lightened(0.30), 1.05 + transition * 0.85)

	for i in COURSE_TOWERS:
		var d: float = 18.0 + float(i) * 3.4
		var s: float = distance + d
		var p_v: Variant = v36.call("_course_point", s)
		if not (p_v is Vector3):
			continue
		var p: Vector3 = p_v
		var b: Basis = _course_basis(s)
		var centre: Vector3 = p - base - b.x * lane

		var side: float = -1.0 if i % 2 == 0 else 1.0
		var radial: float = 8.0 + float(i % 6) * 1.05
		var height: float = sin(float(i) * 1.21 + distance * 0.012) * 3.0
		var sx: float = 1.0
		var sy: float = 1.0
		var sz: float = 1.0
		var roll: float = 0.0

		match secteur:
			0:
				height = -1.0 + float(i % 5) * 0.85
				sy = 1.0 + float(i % 4) * 0.35
			1:
				var a1: float = s * 0.055 + float(i) * 0.51
				side = cos(a1)
				height = sin(a1) * 5.2
				radial = 7.2 + float(i % 4) * 0.85
				roll = a1 * 0.30
			2:
				radial = 9.0 + float(i % 4) * 0.85
				height = 1.6
				sy = 2.5 + float(i % 5) * 0.55
				sx = 0.72
				sz = 0.72
			3:
				radial = 11.0 + float(i % 7) * 1.25
				height = -6.0 + float(i % 9) * 1.35
				sy = 1.8 + float(i % 4) * 0.55
			4:
				var a4: float = s * 0.070 + float(i) * 0.63
				side = cos(a4)
				height = sin(a4) * 6.0
				radial = 7.8 + float(i % 5) * 1.0
				roll = a4
			_:
				radial = 7.2 + float(i % 8) * 1.1
				height = sin(float(i) * 2.2) * 5.0
				sx = 0.7 + float(i % 4) * 0.46
				sy = 0.45 + float(i % 5) * 0.36
				sz = 0.75 + float(i % 3) * 0.42
				roll = float(i % 9) * 0.32

		radial *= lerpf(1.15, 0.94, transition)
		var pos: Vector3 = centre + b.x * side * radial + b.y * height
		var bb: Basis = b * Basis(Vector3.FORWARD, roll)
		bb = bb.scaled(Vector3(sx, sy, sz))
		_course_towers_mm.set_instance_transform(i, Transform3D(bb, pos))

	var base_ring: Basis = Basis(Vector3.RIGHT, PI * 0.5)
	for i in COURSE_ARCHES:
		var d2: float = 28.0 + float(i) * 9.5
		var s2: float = distance + d2
		var p2_v: Variant = v36.call("_course_point", s2)
		if not (p2_v is Vector3):
			continue
		var p2: Vector3 = p2_v
		var b2: Basis = _course_basis(s2)
		var centre2: Vector3 = p2 - base - b2.x * lane
		var sc: float = 0.84 + float(i % 4) * 0.12 + transition * 0.10
		if secteur == 2:
			sc *= 1.25
		elif secteur == 3:
			sc *= 1.42
		elif secteur == 5:
			sc *= 0.86 + 0.18 * sin(float(i) * 1.4 + distance * 0.02)
		var rb: Basis = b2 * base_ring
		rb = rb.scaled(Vector3(sc, sc, 1.0))
		_course_arches_mm.set_instance_transform(i, Transform3D(rb, centre2))

	for i in COURSE_BRIDGES:
		var d3: float = 16.0 + float(i) * 7.5
		var s3: float = distance + d3
		var p3_v: Variant = v36.call("_course_point", s3)
		if not (p3_v is Vector3):
			continue
		var p3: Vector3 = p3_v
		var b3: Basis = _course_basis(s3)
		var centre3: Vector3 = p3 - base - b3.x * lane
		var height3: float = 3.6 + float(i % 3) * 0.75
		if secteur == 3:
			height3 += 2.0
		elif secteur == 5:
			height3 = 2.8 + float(i % 4) * 0.65
		var pos3: Vector3 = centre3 + b3.y * height3
		var bridge_basis: Basis = b3
		if secteur == 5:
			bridge_basis = b3 * Basis(Vector3.FORWARD, sin(float(i) * 1.7) * 0.42)
		_course_bridges_mm.set_instance_transform(i, Transform3D(bridge_basis, pos3))
