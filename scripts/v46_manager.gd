class_name V46Manager
extends Node
## Mandala VR v46 : echelle et vertige.
##
## On ajoute des reperes lointains, pas du bruit proche :
## - grille abyssale tres loin sous le joueur ;
## - anneau d'horizon gigantesque ;
## - piliers verticaux qui donnent l'echelle ;
## - profondeur variable selon chapitre / secteur.
##
## Aucun texte en plein trajet.
## Aucun mouvement force de la camera XR.

const GRID_LINES: int = 34
const VERTICALS: int = 26
const COURSE_GRID_LINES: int = 30
const COURSE_VERTICALS: int = 22

var app = null
var v31 = null
var v32 = null
var v33 = null
var v36 = null
var v45 = null

var _installe: bool = false

# Grand 8
var _death_root: Node3D = null
var _death_grid_node: MultiMeshInstance3D = null
var _death_grid_mm: MultiMesh = null
var _death_vert_node: MultiMeshInstance3D = null
var _death_vert_mm: MultiMesh = null
var _death_horizon: MeshInstance3D = null
var _death_grid_mat: StandardMaterial3D = null
var _death_vert_mat: StandardMaterial3D = null
var _death_horizon_mat: StandardMaterial3D = null

# Course
var _course_root: Node3D = null
var _course_grid_node: MultiMeshInstance3D = null
var _course_grid_mm: MultiMesh = null
var _course_vert_node: MultiMeshInstance3D = null
var _course_vert_mm: MultiMesh = null
var _course_horizon: MeshInstance3D = null
var _course_grid_mat: StandardMaterial3D = null
var _course_vert_mat: StandardMaterial3D = null
var _course_horizon_mat: StandardMaterial3D = null


func _ready() -> void:
	app = get_parent()
	v31 = app.get_node_or_null("V31Manager")
	v32 = app.get_node_or_null("V32Manager")
	v33 = app.get_node_or_null("V33Manager")
	v36 = app.get_node_or_null("V36Manager")
	v45 = app.get_node_or_null("V45Manager")
	process_priority = 370


func _process(_dt: float) -> void:
	if app == null:
		return

	if not _installe:
		var ready_ok: bool = (
			v31 != null and bool(v31.get("_installe"))
			and v32 != null and bool(v32.get("_installe"))
			and v33 != null and bool(v33.get("_installe"))
			and v36 != null and bool(v36.get("_installe"))
			and v45 != null and bool(v45.get("_installe"))
		)
		if ready_ok:
			_installer()
		return

	_maj_death_scale()
	_maj_course_scale()


func _installer() -> void:
	_installe = true
	_creer_death_scale()
	_creer_course_scale()


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


# =====================================================================
# GRAND 8

func _creer_death_scale() -> void:
	var rv: Variant = v31.get("_racine")
	if not (rv is Node3D):
		return
	_death_root = rv

	var grid_mesh: BoxMesh = BoxMesh.new()
	grid_mesh.size = Vector3(64.0, 0.035, 0.035)
	_death_grid_mat = _glow(Color(0.08, 0.42, 0.92, 0.20), 0.9)
	grid_mesh.material = _death_grid_mat

	_death_grid_mm = MultiMesh.new()
	_death_grid_mm.transform_format = MultiMesh.TRANSFORM_3D
	_death_grid_mm.instance_count = GRID_LINES
	_death_grid_mm.mesh = grid_mesh

	_death_grid_node = MultiMeshInstance3D.new()
	_death_grid_node.name = "V46DeathAbyssGrid"
	_death_grid_node.multimesh = _death_grid_mm
	_death_grid_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_death_grid_node.extra_cull_margin = 320.0
	_death_grid_node.visible = false
	_death_root.add_child(_death_grid_node)

	var vert_mesh: BoxMesh = BoxMesh.new()
	vert_mesh.size = Vector3(0.08, 1.0, 0.08)
	_death_vert_mat = _glow(Color(0.18, 0.60, 1.0, 0.22), 1.0)
	vert_mesh.material = _death_vert_mat

	_death_vert_mm = MultiMesh.new()
	_death_vert_mm.transform_format = MultiMesh.TRANSFORM_3D
	_death_vert_mm.instance_count = VERTICALS
	_death_vert_mm.mesh = vert_mesh

	_death_vert_node = MultiMeshInstance3D.new()
	_death_vert_node.name = "V46DeathVerticalScale"
	_death_vert_node.multimesh = _death_vert_mm
	_death_vert_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_death_vert_node.extra_cull_margin = 360.0
	_death_vert_node.visible = false
	_death_root.add_child(_death_vert_node)

	_death_horizon = MeshInstance3D.new()
	_death_horizon.name = "V46DeathHorizon"
	var horizon_mesh: TorusMesh = TorusMesh.new()
	horizon_mesh.inner_radius = 27.0
	horizon_mesh.outer_radius = 27.22
	horizon_mesh.rings = 64
	horizon_mesh.ring_segments = 8
	_death_horizon_mat = _glow(Color(0.14, 0.54, 1.0, 0.18), 1.0)
	horizon_mesh.material = _death_horizon_mat
	_death_horizon.mesh = horizon_mesh
	_death_horizon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_death_horizon.visible = false
	_death_root.add_child(_death_horizon)


func _death_floor_height(chapitre: int, ratio: float) -> float:
	var wave: float = sin(PI * ratio)
	wave *= wave

	match chapitre:
		0:
			# Pendant l'ascension, le sol s'eloigne progressivement.
			return lerpf(-10.0, -34.0, smoothstep(0.0, 0.72, ratio))
		1:
			return -28.0 - wave * 8.0
		2:
			# Abysses : tres grande profondeur.
			return -42.0 - wave * 12.0
		3:
			return -30.0 - wave * 7.0
		4:
			# Fracture : profondeur qui change fortement.
			return -24.0 - (0.5 + 0.5 * sin(ratio * TAU * 2.0)) * 18.0
		_:
			return -34.0 - (0.5 + 0.5 * sin(ratio * TAU * 3.0)) * 16.0


func _maj_death_scale() -> void:
	if _death_grid_node == null:
		return

	var mort: bool = bool(v32.get("_mort"))
	var etat: int = int(v32.get("_etat_mort"))
	var visible: bool = mort and etat == 0

	_death_grid_node.visible = visible
	_death_vert_node.visible = visible
	_death_horizon.visible = visible

	if not visible:
		return

	var chapitre: int = mini(int(v32.get("_chapitre")), 5)
	var phase: float = float(v32.get("_phase_t"))
	var fin: float = maxf(1.0, float(v32.get("_prochaine_rupture")))
	var ratio: float = clampf(phase / fin, 0.0, 1.0)

	var floor_y: float = _death_floor_height(chapitre, ratio)
	var pulse: float = sin(PI * ratio)
	pulse *= pulse

	var colors: Array = [
		Color(0.10, 0.48, 1.0, 0.19),
		Color(0.58, 0.16, 1.0, 0.20),
		Color(0.05, 0.62, 1.0, 0.21),
		Color(0.96, 0.50, 0.12, 0.20),
		Color(1.0, 0.20, 0.10, 0.22),
		Color(0.64, 0.10, 1.0, 0.24),
	]
	var c: Color = colors[chapitre]

	_set_color(_death_grid_mat, c, 0.72 + pulse * 0.42)
	_set_color(_death_vert_mat, c.lightened(0.18), 0.82 + pulse * 0.52)
	_set_color(_death_horizon_mat, c.lightened(0.28), 0.78 + pulse * 0.62)

	# Grille 17 lignes X + 17 lignes Z.
	for i in GRID_LINES:
		var half: int = GRID_LINES / 2
		var idx: int = i % half
		var offset: float = (float(idx) - float(half - 1) * 0.5) * 4.0
		var b: Basis = Basis()
		var pos: Vector3 = Vector3.ZERO

		if i < half:
			pos = Vector3(0.0, floor_y, offset)
		else:
			b = Basis(Vector3.UP, PI * 0.5)
			pos = Vector3(offset, floor_y, 0.0)

		_death_grid_mm.set_instance_transform(i, Transform3D(b, pos))

	# Tours tres hautes du sol jusqu'au niveau du joueur.
	var height: float = absf(floor_y)
	for i in VERTICALS:
		var a: float = TAU * float(i) / float(VERTICALS)
		var radius: float = 15.0 + float(i % 5) * 2.3
		var x: float = cos(a) * radius
		var z: float = sin(a) * radius
		var y: float = floor_y * 0.5
		var sy: float = height
		var b2: Basis = Basis().scaled(Vector3(1.0, sy, 1.0))
		_death_vert_mm.set_instance_transform(i, Transform3D(b2, Vector3(x, y, z)))

	# Horizon toujours au niveau du "sol lointain".
	_death_horizon.position = Vector3(0.0, floor_y + 0.15, 0.0)
	_death_horizon.rotation = Vector3.ZERO
	var horizon_scale: float = 1.0 + pulse * 0.16
	_death_horizon.scale = Vector3(horizon_scale, 1.0, horizon_scale)


# =====================================================================
# COURSE

func _creer_course_scale() -> void:
	var rv: Variant = v33.get("_racine")
	if not (rv is Node3D):
		return
	_course_root = rv

	var grid_mesh: BoxMesh = BoxMesh.new()
	grid_mesh.size = Vector3(58.0, 0.03, 0.03)
	_course_grid_mat = _glow(Color(0.10, 0.48, 0.92, 0.18), 0.82)
	grid_mesh.material = _course_grid_mat

	_course_grid_mm = MultiMesh.new()
	_course_grid_mm.transform_format = MultiMesh.TRANSFORM_3D
	_course_grid_mm.instance_count = COURSE_GRID_LINES
	_course_grid_mm.mesh = grid_mesh

	_course_grid_node = MultiMeshInstance3D.new()
	_course_grid_node.name = "V46CourseAbyssGrid"
	_course_grid_node.multimesh = _course_grid_mm
	_course_grid_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_course_grid_node.extra_cull_margin = 300.0
	_course_grid_node.visible = false
	_course_root.add_child(_course_grid_node)

	var vert_mesh: BoxMesh = BoxMesh.new()
	vert_mesh.size = Vector3(0.075, 1.0, 0.075)
	_course_vert_mat = _glow(Color(0.18, 0.64, 1.0, 0.20), 0.95)
	vert_mesh.material = _course_vert_mat

	_course_vert_mm = MultiMesh.new()
	_course_vert_mm.transform_format = MultiMesh.TRANSFORM_3D
	_course_vert_mm.instance_count = COURSE_VERTICALS
	_course_vert_mm.mesh = vert_mesh

	_course_vert_node = MultiMeshInstance3D.new()
	_course_vert_node.name = "V46CourseVerticalScale"
	_course_vert_node.multimesh = _course_vert_mm
	_course_vert_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_course_vert_node.extra_cull_margin = 330.0
	_course_vert_node.visible = false
	_course_root.add_child(_course_vert_node)

	_course_horizon = MeshInstance3D.new()
	_course_horizon.name = "V46CourseHorizon"
	var horizon_mesh: TorusMesh = TorusMesh.new()
	horizon_mesh.inner_radius = 24.0
	horizon_mesh.outer_radius = 24.20
	horizon_mesh.rings = 60
	horizon_mesh.ring_segments = 8
	_course_horizon_mat = _glow(Color(0.16, 0.58, 1.0, 0.17), 0.95)
	horizon_mesh.material = _course_horizon_mat
	_course_horizon.mesh = horizon_mesh
	_course_horizon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_course_horizon.visible = false
	_course_root.add_child(_course_horizon)


func _course_floor_height(secteur: int, u: float) -> float:
	var wave: float = sin(PI * u)
	wave *= wave

	match secteur:
		0:
			return -16.0 - wave * 8.0
		1:
			return -24.0 - wave * 10.0
		2:
			return -20.0 - wave * 8.0
		3:
			# Abysse : le repere au sol est extremement bas.
			return -40.0 - wave * 12.0
		4:
			return -28.0 - wave * 10.0
		_:
			return -22.0 - (0.5 + 0.5 * sin(u * TAU * 2.0)) * 15.0


func _maj_course_scale() -> void:
	if _course_grid_node == null:
		return

	var actif: bool = bool(v33.get("_actif"))
	_course_grid_node.visible = actif
	_course_vert_node.visible = actif
	_course_horizon.visible = actif

	if not actif:
		return

	var distance: float = float(v33.get("_distance"))
	var secteur: int = int(v36.call("_course_sector", distance))
	var u: float = fposmod(distance, 165.0) / 165.0
	var floor_y: float = _course_floor_height(secteur, u)

	var colors: Array = [
		Color(0.12, 0.60, 1.0, 0.18),
		Color(0.58, 0.18, 1.0, 0.20),
		Color(1.0, 0.62, 0.14, 0.18),
		Color(0.06, 0.34, 0.92, 0.20),
		Color(0.10, 0.90, 0.70, 0.20),
		Color(1.0, 0.22, 0.44, 0.22),
	]
	var c: Color = colors[secteur]
	var pulse: float = sin(PI * u)
	pulse *= pulse

	_set_color(_course_grid_mat, c, 0.68 + pulse * 0.36)
	_set_color(_course_vert_mat, c.lightened(0.18), 0.78 + pulse * 0.46)
	_set_color(_course_horizon_mat, c.lightened(0.28), 0.74 + pulse * 0.55)

	for i in COURSE_GRID_LINES:
		var half: int = COURSE_GRID_LINES / 2
		var idx: int = i % half
		var offset: float = (float(idx) - float(half - 1) * 0.5) * 4.0
		var b: Basis = Basis()
		var pos: Vector3 = Vector3.ZERO

		if i < half:
			pos = Vector3(0.0, floor_y, offset)
		else:
			b = Basis(Vector3.UP, PI * 0.5)
			pos = Vector3(offset, floor_y, 0.0)

		_course_grid_mm.set_instance_transform(i, Transform3D(b, pos))

	var height: float = absf(floor_y)
	for i in COURSE_VERTICALS:
		var a: float = TAU * float(i) / float(COURSE_VERTICALS)
		var radius: float = 14.0 + float(i % 5) * 2.0
		var x: float = cos(a) * radius
		var z: float = sin(a) * radius
		var y: float = floor_y * 0.5
		var b2: Basis = Basis().scaled(Vector3(1.0, height, 1.0))
		_course_vert_mm.set_instance_transform(i, Transform3D(b2, Vector3(x, y, z)))

	_course_horizon.position = Vector3(0.0, floor_y + 0.12, 0.0)
	_course_horizon.rotation = Vector3.ZERO
	var hs: float = 1.0 + pulse * 0.14
	_course_horizon.scale = Vector3(hs, 1.0, hs)
