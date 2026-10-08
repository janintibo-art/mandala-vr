class_name V41Manager
extends Node
## Mandala VR v41 : parcours vivant.
##
## Grand 8 de la mort :
## - architecture geometrique autour du tunnel ;
## - decor different pour chaque chapitre ;
## - grandes structures visibles de loin pour donner de l'echelle.
##
## Course :
## - bifurcations gauche/droite regulieres ;
## - choix selon la position du joueur dans la piste ;
## - branche selectionnee mise en avant ;
## - deplacement lateral de tout le parcours puis raccord progressif.
##
## Aucun mouvement force de la camera XR.

const DEATH_STRUCTURES: int = 52
const DEATH_MEGA_RINGS: int = 12

const BRANCH_RINGS: int = 16
const BRANCH_STEP: float = 3.15
const BRANCH_PERIOD: float = 330.0
const BRANCH_WINDOW: float = 112.0

var app = null
var v31 = null
var v32 = null
var v33 = null
var v36 = null
var v40 = null

var _installe: bool = false

# Grand 8 : decor architectural
var _death_parent: Node3D = null
var _death_struct_node: MultiMeshInstance3D = null
var _death_struct_mm: MultiMesh = null
var _death_ring_node: MultiMeshInstance3D = null
var _death_ring_mm: MultiMesh = null
var _death_struct_mat: StandardMaterial3D = null
var _death_ring_mat: StandardMaterial3D = null
var _death_on: bool = false
var _death_chapter_prev: int = -1

# Course : bifurcation
var _course_parent: Node3D = null
var _branch_left_node: MultiMeshInstance3D = null
var _branch_left_mm: MultiMesh = null
var _branch_right_node: MultiMeshInstance3D = null
var _branch_right_mm: MultiMesh = null
var _branch_left_mat: StandardMaterial3D = null
var _branch_right_mat: StandardMaterial3D = null

var _course_on: bool = false
var _course_base_pos: Vector3 = Vector3.ZERO
var _branch_index: int = -1
var _branch_side: float = 0.0
var _branch_locked: bool = false


func _ready() -> void:
	app = get_parent()
	v31 = app.get_node_or_null("V31Manager")
	v32 = app.get_node_or_null("V32Manager")
	v33 = app.get_node_or_null("V33Manager")
	v36 = app.get_node_or_null("V36Manager")
	v40 = app.get_node_or_null("V40Manager")
	process_priority = 330


func _process(_dt: float) -> void:
	if app == null:
		return

	if not _installe:
		var pret: bool = (
			v31 != null and bool(v31.get("_installe"))
			and v32 != null and bool(v32.get("_installe"))
			and v33 != null and bool(v33.get("_installe"))
			and v36 != null and bool(v36.get("_installe"))
			and v40 != null and bool(v40.get("_installe"))
		)
		if pret:
			_installer()
		return

	_maj_death_world()
	_maj_course_branches()


# =====================================================================
# Installation

func _installer() -> void:
	_installe = true
	_creer_death_world()
	_creer_course_branches()


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
# GRAND 8 : MONDE AUTOUR DU TUNNEL

func _creer_death_world() -> void:
	var rv: Variant = v31.get("_racine")
	if not (rv is Node3D):
		return
	_death_parent = rv

	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.45, 4.0, 0.45)
	_death_struct_mat = _glow(Color(0.18, 0.55, 1.0, 0.30), 1.25)
	box.material = _death_struct_mat

	_death_struct_mm = MultiMesh.new()
	_death_struct_mm.transform_format = MultiMesh.TRANSFORM_3D
	_death_struct_mm.instance_count = DEATH_STRUCTURES
	_death_struct_mm.mesh = box

	_death_struct_node = MultiMeshInstance3D.new()
	_death_struct_node.name = "V41DeathArchitecture"
	_death_struct_node.multimesh = _death_struct_mm
	_death_struct_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_death_struct_node.extra_cull_margin = 220.0
	_death_struct_node.visible = false
	_death_parent.add_child(_death_struct_node)

	var tor: TorusMesh = TorusMesh.new()
	tor.inner_radius = 5.9
	tor.outer_radius = 6.08
	tor.rings = 40
	tor.ring_segments = 8
	_death_ring_mat = _glow(Color(0.35, 0.72, 1.0, 0.30), 1.35)
	tor.material = _death_ring_mat

	_death_ring_mm = MultiMesh.new()
	_death_ring_mm.transform_format = MultiMesh.TRANSFORM_3D
	_death_ring_mm.instance_count = DEATH_MEGA_RINGS
	_death_ring_mm.mesh = tor

	_death_ring_node = MultiMeshInstance3D.new()
	_death_ring_node.name = "V41DeathMegaRings"
	_death_ring_node.multimesh = _death_ring_mm
	_death_ring_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_death_ring_node.extra_cull_margin = 240.0
	_death_ring_node.visible = false
	_death_parent.add_child(_death_ring_node)


func _death_basis(d: float, chapitre: int, ratio: float) -> Basis:
	var p_v: Variant = v36.call("_death_point", d, chapitre, ratio)
	var p2_v: Variant = v36.call("_death_point", d + 0.32, chapitre, ratio)
	if not (p_v is Vector3) or not (p2_v is Vector3):
		return Basis()
	var p: Vector3 = p_v
	var p2: Vector3 = p2_v
	var dir: Vector3 = (p2 - p).normalized()
	return Basis.looking_at(dir, Vector3.UP)


func _death_colors(chapitre: int) -> Array:
	match mini(chapitre, 5):
		0:
			return [Color(0.16, 0.55, 1.0, 0.28), Color(0.38, 0.78, 1.0, 0.34)]
		1:
			return [Color(0.64, 0.20, 1.0, 0.30), Color(0.96, 0.32, 0.90, 0.35)]
		2:
			return [Color(0.08, 0.40, 0.86, 0.24), Color(0.10, 0.78, 1.0, 0.34)]
		3:
			return [Color(0.88, 0.58, 0.18, 0.28), Color(1.0, 0.82, 0.34, 0.36)]
		4:
			return [Color(1.0, 0.24, 0.12, 0.30), Color(1.0, 0.48, 0.18, 0.38)]
		_:
			return [Color(0.72, 0.12, 1.0, 0.32), Color(0.20, 0.90, 1.0, 0.40)]


func _maj_death_world() -> void:
	if _death_struct_node == null:
		return

	var mort: bool = bool(v32.get("_mort"))
	var etat: int = int(v32.get("_etat_mort"))
	var visible: bool = mort and etat == 0

	_death_struct_node.visible = visible
	_death_ring_node.visible = visible

	if not visible:
		_death_on = false
		return

	var chapitre: int = mini(int(v32.get("_chapitre")), 5)
	var phase: float = float(v32.get("_phase_t"))
	var fin: float = maxf(1.0, float(v32.get("_prochaine_rupture")))
	var ratio: float = clampf(phase / fin, 0.0, 1.0)
	var travel: float = float(v31.get("_travel"))

	if not _death_on or chapitre != _death_chapter_prev:
		_death_on = true
		_death_chapter_prev = chapitre
		var cs: Array = _death_colors(chapitre)
		var c0: Color = cs[0]
		var c1: Color = cs[1]
		_death_struct_mat.albedo_color = c0
		_death_struct_mat.emission = Color(c0.r, c0.g, c0.b, 1.0)
		_death_ring_mat.albedo_color = c1
		_death_ring_mat.emission = Color(c1.r, c1.g, c1.b, 1.0)

	# Structures laterales, toutes calees sur le vrai trace.
	for i in DEATH_STRUCTURES:
		var d: float = fposmod(float(i) * 3.35 - travel * 0.68, 118.0) + 8.0
		var p_v: Variant = v36.call("_death_point", d, chapitre, ratio)
		if not (p_v is Vector3):
			continue
		var p: Vector3 = p_v
		var b: Basis = _death_basis(d, chapitre, ratio)

		var cote: float = -1.0 if i % 2 == 0 else 1.0
		var rayon: float = 5.0 + float(i % 5) * 0.72
		var hauteur: float = 0.0
		var sx: float = 1.0
		var sy: float = 1.0
		var sz: float = 1.0
		var roll: float = 0.0

		match chapitre:
			0:
				# Tours de lancement / ascension.
				hauteur = -1.0 + float(i % 4) * 0.75
				sy = 1.2 + float(i % 5) * 0.28
				rayon += 0.8
			1:
				# Lames en spirale autour du tube.
				var a1: float = d * 0.14 + float(i) * 0.47
				cote = cos(a1)
				hauteur = sin(a1) * 4.2
				rayon = 5.1 + 0.8 * sin(float(i) * 1.7)
				sy = 0.55 + float(i % 3) * 0.25
				roll = a1
			2:
				# Canyon / vide : piliers tres eloignes et tres hauts.
				rayon = 7.0 + float(i % 6) * 1.05
				hauteur = -3.0 + float(i % 7) * 1.0
				sy = 2.1 + float(i % 4) * 0.55
				sx = 1.5
				sz = 1.5
			3:
				# Cathedrale : colonnes regulieres.
				rayon = 5.8 + float(i % 3) * 0.42
				hauteur = 1.2
				sy = 2.6 + float(i % 4) * 0.35
				sx = 0.75
				sz = 0.75
			4:
				# Fracture : blocs flottants et inclines.
				rayon = 4.7 + float(i % 7) * 0.65
				hauteur = sin(float(i) * 2.3) * 3.4
				sx = 1.0 + float(i % 4) * 0.45
				sy = 0.45 + float(i % 3) * 0.32
				sz = 1.0 + float((i + 2) % 5) * 0.30
				roll = float(i % 9) * 0.31
			_:
				# Chaos : toutes les familles melangees.
				var a6: float = d * 0.11 + float(i) * 0.73
				cote = cos(a6)
				hauteur = sin(a6) * (3.0 + float(i % 3))
				rayon = 4.7 + float(i % 8) * 0.62
				sx = 0.7 + float(i % 5) * 0.35
				sy = 0.6 + float((i + 2) % 6) * 0.38
				sz = 0.7 + float((i + 4) % 4) * 0.40
				roll = a6

		var radial: Vector3 = b.x * cote * rayon + b.y * hauteur
		var pos: Vector3 = p + radial
		var bb: Basis = b * Basis(Vector3.FORWARD, roll)
		bb = bb.scaled(Vector3(sx, sy, sz))
		_death_struct_mm.set_instance_transform(i, Transform3D(bb, pos))

	# Anneaux monumentaux : espacements beaucoup plus grands que le tunnel.
	var base_ring: Basis = Basis(Vector3.RIGHT, PI * 0.5)
	for i in DEATH_MEGA_RINGS:
		var d2: float = fposmod(float(i) * 10.5 - travel * 0.52, 126.0) + 16.0
		var p2_v: Variant = v36.call("_death_point", d2, chapitre, ratio)
		if not (p2_v is Vector3):
			continue
		var p2: Vector3 = p2_v
		var b2: Basis = _death_basis(d2, chapitre, ratio)

		var ring_scale: float = 0.85
		if chapitre == 2:
			ring_scale = 1.35
		elif chapitre == 3:
			ring_scale = 1.15
		elif chapitre >= 4:
			ring_scale = 0.82 + 0.30 * sin(float(i) * 1.4 + phase)

		var rb: Basis = b2 * base_ring
		rb = rb.scaled(Vector3(ring_scale, ring_scale, 1.0))
		_death_ring_mm.set_instance_transform(i, Transform3D(rb, p2))

	_death_struct_mat.emission_energy_multiplier = 1.05 + float(chapitre) * 0.12
	_death_ring_mat.emission_energy_multiplier = 1.25 + float(chapitre) * 0.16


# =====================================================================
# COURSE : BIFURCATIONS

func _creer_course_branches() -> void:
	var rv: Variant = v33.get("_racine")
	if not (rv is Node3D):
		return
	_course_parent = rv

	var tor_l: TorusMesh = TorusMesh.new()
	tor_l.inner_radius = 2.70
	tor_l.outer_radius = 2.82
	tor_l.rings = 32
	tor_l.ring_segments = 6
	_branch_left_mat = _glow(Color(0.16, 0.72, 1.0, 0.48), 2.0)
	tor_l.material = _branch_left_mat

	_branch_left_mm = MultiMesh.new()
	_branch_left_mm.transform_format = MultiMesh.TRANSFORM_3D
	_branch_left_mm.instance_count = BRANCH_RINGS
	_branch_left_mm.mesh = tor_l

	_branch_left_node = MultiMeshInstance3D.new()
	_branch_left_node.name = "V41BranchLeft"
	_branch_left_node.multimesh = _branch_left_mm
	_branch_left_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_branch_left_node.extra_cull_margin = 180.0
	_branch_left_node.visible = false
	_course_parent.add_child(_branch_left_node)

	var tor_r: TorusMesh = TorusMesh.new()
	tor_r.inner_radius = 2.70
	tor_r.outer_radius = 2.82
	tor_r.rings = 32
	tor_r.ring_segments = 6
	_branch_right_mat = _glow(Color(0.94, 0.24, 0.92, 0.48), 2.0)
	tor_r.material = _branch_right_mat

	_branch_right_mm = MultiMesh.new()
	_branch_right_mm.transform_format = MultiMesh.TRANSFORM_3D
	_branch_right_mm.instance_count = BRANCH_RINGS
	_branch_right_mm.mesh = tor_r

	_branch_right_node = MultiMeshInstance3D.new()
	_branch_right_node.name = "V41BranchRight"
	_branch_right_node.multimesh = _branch_right_mm
	_branch_right_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_branch_right_node.extra_cull_margin = 180.0
	_branch_right_node.visible = false
	_course_parent.add_child(_branch_right_node)


func _maj_course_branches() -> void:
	if _course_parent == null:
		return

	var actif: bool = bool(v33.get("_actif"))
	if actif != _course_on:
		_course_on = actif
		if actif:
			_course_base_pos = _course_parent.position
			_branch_index = -1
			_branch_side = 0.0
			_branch_locked = false
		else:
			_course_parent.position = _course_base_pos
			_branch_left_node.visible = false
			_branch_right_node.visible = false

	if not actif:
		return

	var distance: float = float(v33.get("_distance"))
	var lane: float = float(v33.get("_lane"))

	# Une bifurcation tous les 330 m.
	var index: int = int(floor(distance / BRANCH_PERIOD))
	var local_m: float = fposmod(distance, BRANCH_PERIOD)

	# Fenetre active au milieu de chaque periode.
	var debut: float = 108.0
	var fin: float = debut + BRANCH_WINDOW
	var dans: bool = local_m >= debut and local_m <= fin

	_branch_left_node.visible = dans
	_branch_right_node.visible = dans

	if not dans:
		# Retour en douceur a l'axe central.
		var retour: float = 0.16
		_course_parent.position.x = lerpf(_course_parent.position.x, _course_base_pos.x, retour)
		if local_m < debut:
			_branch_locked = false
			_branch_side = 0.0
		return

	if index != _branch_index:
		_branch_index = index
		_branch_locked = false
		_branch_side = 0.0

	var u: float = clampf((local_m - debut) / BRANCH_WINDOW, 0.0, 1.0)

	# Verrouillage du choix apres avoir laisse le temps de se placer.
	if not _branch_locked and u >= 0.30:
		if lane < -0.18:
			_branch_side = -1.0
		elif lane > 0.18:
			_branch_side = 1.0
		else:
			# Si le joueur reste centre, alterne automatiquement les branches.
			_branch_side = -1.0 if index % 2 == 0 else 1.0
		_branch_locked = true

	# Divergence puis reunion.
	var separation: float = sin(PI * u)
	separation *= separation
	var max_offset: float = 3.8

	# Le monde entier de la Course suit la branche choisie.
	var target_x: float = _course_base_pos.x
	if _branch_locked:
		target_x += _branch_side * max_offset * separation
	_course_parent.position.x = lerpf(_course_parent.position.x, target_x, 0.18)

	var base_ring: Basis = Basis(Vector3.RIGHT, PI * 0.5)

	for i in BRANCH_RINGS:
		var d: float = 12.0 + float(i) * BRANCH_STEP
		var ahead_u: float = clampf(u + d / BRANCH_WINDOW, 0.0, 1.0)
		var env: float = sin(PI * ahead_u)
		env *= env
		var spread: float = max_offset * env

		var s: float = distance + d
		var p_v: Variant = v36.call("_course_point", s)
		var base_v: Variant = v36.call("_course_point", distance)
		var b_v: Variant = v36.call("_course_basis", s)
		if not (p_v is Vector3) or not (base_v is Vector3) or not (b_v is Basis):
			continue

		var p: Vector3 = p_v
		var base: Vector3 = base_v
		var b: Basis = b_v
		var centre: Vector3 = p - base - b.x * lane

		var left_pos: Vector3 = centre - b.x * spread
		var right_pos: Vector3 = centre + b.x * spread

		var lb: Basis = b * base_ring
		var rb: Basis = b * base_ring

		# Apres le choix, la branche non selectionnee retrecit progressivement.
		var left_scale: float = 1.0
		var right_scale: float = 1.0
		if _branch_locked:
			var fade: float = smoothstep(0.34, 0.60, u)
			if _branch_side < 0.0:
				right_scale = lerpf(1.0, 0.22, fade)
			else:
				left_scale = lerpf(1.0, 0.22, fade)

		lb = lb.scaled(Vector3(left_scale, left_scale, 1.0))
		rb = rb.scaled(Vector3(right_scale, right_scale, 1.0))

		_branch_left_mm.set_instance_transform(i, Transform3D(lb, left_pos))
		_branch_right_mm.set_instance_transform(i, Transform3D(rb, right_pos))

	# Mise en valeur de la branche selectionnee.
	if _branch_locked:
		if _branch_side < 0.0:
			_branch_left_mat.emission_energy_multiplier = 3.3
			_branch_right_mat.emission_energy_multiplier = 0.75
		else:
			_branch_left_mat.emission_energy_multiplier = 0.75
			_branch_right_mat.emission_energy_multiplier = 3.3
	else:
		_branch_left_mat.emission_energy_multiplier = 2.0
		_branch_right_mat.emission_energy_multiplier = 2.0
