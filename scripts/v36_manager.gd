class_name V36Manager
extends Node
## Mandala VR v36 : directeur de parcours.
##
## v35 avait apporte la sensation. v36 apporte le level design :
## - Grand 8 de la mort : chaque chapitre a une geometrie differente.
## - sections ouvertes sur le vide, compressions, cathedrales, fractures,
##   helices et chaos final.
## - Course : remplacement visuel de la piste lineaire par 6 secteurs
##   geometriques reellement differents, tout en gardant la conduite v33.
##
## Le moteur intervient APRES v31/v32/v33/v35 afin que ses transformations
## soient les dernieres appliquees a l'image.

const DEATH_RINGS: int = 56
const DEATH_SPACING: float = 1.35
const DEATH_LENGTH: float = DEATH_RINGS * DEATH_SPACING

const COURSE_SEGMENTS: int = 72
const COURSE_RINGS: int = 66
const COURSE_RIB_DEPTH: int = 34
const COURSE_RIBS: int = 10
const COURSE_RIB_COUNT: int = COURSE_RIB_DEPTH * COURSE_RIBS
const COURSE_STEP: float = 1.48
const COURSE_RING_STEP: float = 1.65
const SECTOR_LEN: float = 165.0

const COURSE_NAMES: Array = [
	"LANCEMENT",
	"HELICE",
	"CATHEDRALE",
	"ABYSSE",
	"ZERO-G",
	"FRACTURE",
]

var app = null
var v31 = null
var v32 = null
var v33 = null
var v35 = null

var _installe: bool = false

# Etat Grand 8
var _death_on: bool = false
var _death_chap_avant: int = -1
var _death_acte_avant: int = -1
var _death_open: bool = false
var _death_depart_yaw: float = 0.0

# Geometrie Course v36
var _course_root: Node3D = null
var _course_floor_node: MultiMeshInstance3D = null
var _course_floor_mm: MultiMesh = null
var _course_rings_node: MultiMeshInstance3D = null
var _course_rings_mm: MultiMesh = null
var _course_ribs_node: MultiMeshInstance3D = null
var _course_ribs_mm: MultiMesh = null
var _course_gate_node: MultiMeshInstance3D = null
var _course_gate_mm: MultiMesh = null
var _course_glow: StandardMaterial3D = null

var _course_on: bool = false
var _course_sector_avant: int = -1
var _course_saved: Dictionary = {}


func _ready() -> void:
	app = get_parent()
	v31 = app.get_node_or_null("V31Manager")
	v32 = app.get_node_or_null("V32Manager")
	v33 = app.get_node_or_null("V33Manager")
	v35 = app.get_node_or_null("V35Manager")
	process_priority = 290


func _process(_dt: float) -> void:
	if app == null:
		return

	if not _installe:
		var pret: bool = (
			v31 != null and bool(v31.get("_installe"))
			and v32 != null and bool(v32.get("_installe"))
			and v33 != null and bool(v33.get("_installe"))
			and v35 != null and bool(v35.get("_installe"))
		)
		if pret:
			_installer()
		return

	_maj_death_director()
	_maj_course_director()


func _installer() -> void:
	_installe = true
	_creer_course_v36()


# =====================================================================
# GRAND 8 DE LA MORT : GEOMETRIE PAR CHAPITRE

func _maj_death_director() -> void:
	var mort: bool = bool(v32.get("_mort"))
	if mort != _death_on:
		_death_on = mort
		_death_chap_avant = -1
		_death_acte_avant = -1

		if mort:
			# v37 : le tunnel doit demarrer exactement dans la direction
			# ou regarde le joueur, pas selon l'axe global de la scene.
			_death_depart_yaw = app.camera.rotation.y
			var root_v: Variant = v31.get("_racine")
			if root_v is Node3D:
				var root: Node3D = root_v
				root.position = app.camera.position
				root.rotation.y = _death_depart_yaw
		else:
			_restaurer_death_visuel()

	if not mort:
		return

	var root_fix_v: Variant = v31.get("_racine")
	if root_fix_v is Node3D:
		(root_fix_v as Node3D).rotation.y = _death_depart_yaw

	var etat: int = int(v32.get("_etat_mort"))
	if etat != 0:
		# Rupture/chute/reentree restent gerees par v32/v35.
		_set_death_world_open(false)
		return

	var chapitre: int = int(v32.get("_chapitre"))
	var phase: float = float(v32.get("_phase_t"))
	var fin: float = maxf(1.0, float(v32.get("_prochaine_rupture")))
	var ratio: float = clampf(phase / fin, 0.0, 1.0)
	var acte: int = mini(3, int(floor(ratio * 4.0)))

	if chapitre != _death_chap_avant:
		_death_chap_avant = chapitre
		_death_acte_avant = -1

	if acte != _death_acte_avant:
		_death_acte_avant = acte
		_annonce_death(chapitre, acte)

	_redessiner_death_tunnel(chapitre, ratio)


func _annonce_death(_chapitre: int, _acte: int) -> void:
	# v42 : le decor annonce lui-meme les changements.
	pass


func _death_point(d: float, chapitre: int, ratio: float) -> Vector3:
	var c: int = mini(chapitre, 5)
	var x: float = 0.0
	var y: float = 0.0

	match c:
		0:
			# Grand profil de montagne russe : montee, crete, grosse plongee.
			x = sin(d * 0.055) * 0.45
			y = sin(d * 0.036 + ratio * 2.0) * 1.15
			y += sin(d * 0.014) * 2.0

		1:
			# Helice avec rayon qui grossit vers l'avant.
			var r1: float = 0.45 + d * 0.025
			var a1: float = d * 0.13 + ratio * 3.2
			x = cos(a1) * r1
			y = sin(a1) * r1 * 0.78

		2:
			# Abysses : grandes courbes et descente vers un espace ouvert.
			x = sin(d * 0.046 + ratio * 1.4) * 2.3
			y = -d * 0.018 + sin(d * 0.085) * 0.75

		3:
			# Tempete geometrique : changements de frequence.
			x = (
				sin(d * 0.105 + ratio * 4.0) * 1.45
				+ sin(d * 0.039) * 1.0)
			y = (
				cos(d * 0.083 + ratio * 2.5) * 1.15
				+ sin(d * 0.17) * 0.40)

		4:
			# Fracture : trajectoire en zig-zag mais lissee.
			x = sin(d * 0.067) * 2.0 + sin(d * 0.19) * 0.55
			y = cos(d * 0.051) * 1.2 - sin(d * 0.12) * 0.55

		_:
			# Chaos : helix + serpent + ondulation verticale.
			var a6: float = d * 0.115 + ratio * 5.0
			var r6: float = 0.9 + 0.65 * sin(d * 0.031)
			x = cos(a6) * r6 + sin(d * 0.049) * 1.8
			y = sin(a6) * r6 + cos(d * 0.071) * 1.25

	# v37 : les 9 premiers metres restent parfaitement droits.
	# Entre 9 et 24 m, le parcours prend progressivement sa forme.
	# Cela evite l'effet "le tunnel part sur la gauche" au lancement.
	var entree: float = smoothstep(9.0, 24.0, d)
	x *= entree
	y *= entree

	return Vector3(x, y, -d)


func _death_width(chapitre: int, d: float, ratio: float) -> float:
	var c: int = mini(chapitre, 5)
	match c:
		0:
			return 1.0 + 0.08 * sin(d * 0.08)
		1:
			return 0.92 + 0.18 * sin(d * 0.12 + ratio * 2.0)
		2:
			# Tunnel qui s'ouvre enormement au milieu du chapitre.
			var ouverture: float = sin(PI * clampf((ratio - 0.25) / 0.55, 0.0, 1.0))
			return 1.0 + ouverture * 0.85
		3:
			return 0.76 + 0.34 * (0.5 + 0.5 * sin(d * 0.17))
		4:
			return 0.82 + 0.20 * sin(d * 0.22)
		_:
			return 0.72 + 0.68 * (0.5 + 0.5 * sin(d * 0.105 + ratio * 4.0))


func _death_ring_missing(chapitre: int, i: int, ratio: float) -> bool:
	var c: int = mini(chapitre, 5)
	if c == 2 and ratio > 0.32 and ratio < 0.72:
		return (i % 3) != 0
	if c == 4:
		return (i % 7 == 2) or (i % 11 == 5)
	if c == 5 and ratio > 0.45:
		return (i % 5 == 1) or (i % 9 == 4)
	return false


func _redessiner_death_tunnel(chapitre: int, ratio: float) -> void:
	var mm_v: Variant = v31.get("_anneaux")
	if not (mm_v is MultiMesh):
		return
	var mm: MultiMesh = mm_v

	var travel: float = float(v31.get("_travel"))
	var base_ring: Basis = Basis(Vector3.RIGHT, PI * 0.5)

	for i in DEATH_RINGS:
		var d: float = fposmod(float(i) * DEATH_SPACING - travel, DEATH_LENGTH) + 0.75
		var p: Vector3 = _death_point(d, chapitre, ratio)
		var p2: Vector3 = _death_point(d + 0.22, chapitre, ratio)
		var dir: Vector3 = (p2 - p).normalized()

		var route: Basis = Basis.looking_at(dir, Vector3.UP)
		var roll: float = 0.0
		var c: int = mini(chapitre, 5)
		if c == 1:
			roll = d * 0.075
		elif c == 3:
			roll = sin(d * 0.10) * 0.55
		elif c == 5:
			roll = d * 0.055 + sin(d * 0.08) * 0.35

		var b: Basis = route * Basis(Vector3.FORWARD, roll) * base_ring
		var largeur: float = _death_width(chapitre, d, ratio)

		if _death_ring_missing(chapitre, i, ratio):
			largeur = 0.015

		b = b.scaled(Vector3(largeur, largeur, 1.0))
		mm.set_instance_transform(i, Transform3D(b, p))

	var c2: int = mini(chapitre, 5)
	var ouvrir: bool = (
		(c2 == 2 and ratio > 0.30 and ratio < 0.76)
		or (c2 == 4 and ratio > 0.48)
		or (c2 == 5 and ratio > 0.35 and ratio < 0.68)
	)
	_set_death_world_open(ouvrir)


func _set_death_world_open(on: bool) -> void:
	if on == _death_open:
		return
	_death_open = on
	if bool(v32.get("_mort")):
		app.monde.visible = on


func _restaurer_death_visuel() -> void:
	_death_open = false
	_death_acte_avant = -1
	_death_chap_avant = -1


# =====================================================================
# COURSE V36 : UN VRAI PARCOURS A SECTEURS

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


func _creer_course_v36() -> void:
	var root_v: Variant = v33.get("_racine")
	if not (root_v is Node3D):
		return
	var parent: Node3D = root_v

	_course_root = Node3D.new()
	_course_root.name = "V36CourseDirector"
	_course_root.visible = false
	parent.add_child(_course_root)

	# Route centrale sombre : elle donne une reference stable au pilotage.
	var floor_mesh: BoxMesh = BoxMesh.new()
	floor_mesh.size = Vector3(5.8, 0.11, COURSE_STEP * 1.08)
	var floor_mat: StandardMaterial3D = StandardMaterial3D.new()
	floor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mat.albedo_color = Color(0.025, 0.035, 0.065)
	floor_mat.emission_enabled = true
	floor_mat.emission = Color(0.02, 0.07, 0.14)
	floor_mat.emission_energy_multiplier = 1.0
	floor_mesh.material = floor_mat

	_course_floor_mm = MultiMesh.new()
	_course_floor_mm.transform_format = MultiMesh.TRANSFORM_3D
	_course_floor_mm.instance_count = COURSE_SEGMENTS
	_course_floor_mm.mesh = floor_mesh

	_course_floor_node = MultiMeshInstance3D.new()
	_course_floor_node.multimesh = _course_floor_mm
	_course_floor_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_course_floor_node.extra_cull_margin = 180.0
	_course_root.add_child(_course_floor_node)

	# Anneaux principaux.
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = 3.30
	ring_mesh.outer_radius = 3.40
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 6
	var ring_mat: ShaderMaterial = ShaderMaterial.new()
	ring_mat.shader = load("res://shaders/grand8_v31.gdshader")
	ring_mesh.material = ring_mat

	_course_rings_mm = MultiMesh.new()
	_course_rings_mm.transform_format = MultiMesh.TRANSFORM_3D
	_course_rings_mm.instance_count = COURSE_RINGS
	_course_rings_mm.mesh = ring_mesh

	_course_rings_node = MultiMeshInstance3D.new()
	_course_rings_node.multimesh = _course_rings_mm
	_course_rings_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_course_rings_node.extra_cull_margin = 190.0
	_course_root.add_child(_course_rings_node)

	# Nervures longitudinales : ce sont elles qui cassent l'effet "lignes sur les cotes".
	var rib_mesh: BoxMesh = BoxMesh.new()
	rib_mesh.size = Vector3(0.045, 0.045, COURSE_STEP * 1.16)
	_course_glow = _glow(Color(0.16, 0.66, 1.0, 0.62), 2.2)
	rib_mesh.material = _course_glow

	_course_ribs_mm = MultiMesh.new()
	_course_ribs_mm.transform_format = MultiMesh.TRANSFORM_3D
	_course_ribs_mm.instance_count = COURSE_RIB_COUNT
	_course_ribs_mm.mesh = rib_mesh

	_course_ribs_node = MultiMeshInstance3D.new()
	_course_ribs_node.multimesh = _course_ribs_mm
	_course_ribs_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_course_ribs_node.extra_cull_margin = 190.0
	_course_root.add_child(_course_ribs_node)

	# Portes proches qui donnent l'echelle et la vitesse.
	var gate_mesh: BoxMesh = BoxMesh.new()
	gate_mesh.size = Vector3(0.10, 6.4, 0.12)
	gate_mesh.material = _glow(Color(0.72, 0.88, 1.0, 0.78), 2.8)

	_course_gate_mm = MultiMesh.new()
	_course_gate_mm.transform_format = MultiMesh.TRANSFORM_3D
	_course_gate_mm.instance_count = 18
	_course_gate_mm.mesh = gate_mesh

	_course_gate_node = MultiMeshInstance3D.new()
	_course_gate_node.multimesh = _course_gate_mm
	_course_gate_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_course_gate_node.extra_cull_margin = 190.0
	_course_root.add_child(_course_gate_node)


func _course_sector(s: float) -> int:
	return int(floor(s / SECTOR_LEN)) % COURSE_NAMES.size()


func _course_local(s: float) -> float:
	return fposmod(s, SECTOR_LEN) / SECTOR_LEN


func _course_point(s: float) -> Vector3:
	var secteur: int = _course_sector(s)
	var u: float = _course_local(s)
	var env: float = sin(PI * u)
	env *= env

	var vir: float = float(v33.get("_virages"))
	var x: float = sin(s * 0.021) * 1.1
	var y: float = sin(s * 0.017 + 0.6) * 0.42

	match secteur:
		0:
			# Lancement : grande courbe qui prepare le joueur.
			x += sin(u * TAU) * 1.8 * env
			y += sin(u * PI) * 1.0

		1:
			# Helice : vraie rotation spatiale.
			x += sin(u * TAU * 2.0) * 4.2 * env
			y += cos(u * TAU * 2.0) * 2.7 * env

		2:
			# Cathedrale : grandes courbes lentes et hauteur.
			x += sin(u * TAU) * 5.2 * env
			y += sin(u * PI) * 4.0 * env

		3:
			# Abysses : chute puis remontee.
			x += sin(u * TAU * 1.5) * 3.0 * env
			y -= pow(sin(PI * u), 2.0) * 7.5

		4:
			# Zero-G : vagues verticales et grande inversion visuelle.
			x += sin(u * TAU * 2.0) * 3.2 * env
			y += sin(u * TAU * 4.0) * 2.7 * env

		_:
			# Fracture : virages courts, changements de hauteur.
			x += (
				sin(u * TAU * 3.0) * 3.4
				+ sin(u * TAU * 7.0) * 0.75) * env
			y += sin(u * TAU * 3.0 + 0.8) * 2.0 * env

	return Vector3(x * vir, y * vir, -s)


func _course_basis(s: float) -> Basis:
	var p0: Vector3 = _course_point(s)
	var p1: Vector3 = _course_point(s + 0.28)
	var dir: Vector3 = (p1 - p0).normalized()
	return Basis.looking_at(dir, Vector3.UP)


func _course_roll(s: float) -> float:
	var secteur: int = _course_sector(s)
	var u: float = _course_local(s)
	var env: float = sin(PI * u)
	env *= env

	match secteur:
		1:
			return u * TAU * 1.55 * env
		3:
			return sin(u * TAU) * 0.48 * env
		4:
			return sin(u * PI) * PI * 0.80
		5:
			return sin(u * TAU * 3.0) * 0.68 * env
		_:
			return sin(u * TAU) * 0.18 * env


func _course_radius(s: float) -> float:
	var secteur: int = _course_sector(s)
	var u: float = _course_local(s)
	var env: float = sin(PI * u)
	env *= env

	match secteur:
		0:
			return 3.35
		1:
			return 3.0 - 0.45 * env
		2:
			return 3.4 + 2.3 * env
		3:
			return 3.25 + 0.75 * env
		4:
			return 3.0 + 0.35 * sin(u * TAU * 4.0) * env
		_:
			return 3.15 + 0.55 * sin(u * TAU * 3.0) * env


func _course_gap(s: float, index: int) -> bool:
	var secteur: int = _course_sector(s)
	var u: float = _course_local(s)

	if secteur == 3 and u > 0.35 and u < 0.58:
		return index % 4 != 0
	if secteur == 5:
		return (index % 8 == 2) or (index % 11 == 6)
	return false


func _maj_course_director() -> void:
	var actif: bool = bool(v33.get("_actif"))
	if actif != _course_on:
		_course_on = actif
		if actif:
			_debut_course_v36()
		else:
			_fin_course_v36()

	if not actif or _course_root == null:
		return

	var distance: float = float(v33.get("_distance"))
	var lane: float = float(v33.get("_lane"))
	var base: Vector3 = _course_point(distance)
	var secteur: int = _course_sector(distance)

	if secteur != _course_sector_avant:
		_course_sector_avant = secteur

	# Route / sol.
	for i in COURSE_SEGMENTS:
		var d: float = 0.75 + float(i) * COURSE_STEP
		var s: float = distance + d
		var p: Vector3 = _course_point(s) - base
		var b: Basis = _course_basis(s)
		var pos: Vector3 = p - b.x * lane + Vector3(0.0, -1.32, 0.0)
		_course_floor_mm.set_instance_transform(i, Transform3D(b, pos))

	# Tunnel variable.
	var base_ring: Basis = Basis(Vector3.RIGHT, PI * 0.5)
	for i in COURSE_RINGS:
		var d2: float = 1.0 + float(i) * COURSE_RING_STEP
		var s2: float = distance + d2
		var p2: Vector3 = _course_point(s2) - base
		var route: Basis = _course_basis(s2)
		var roll: float = _course_roll(s2)
		var r: float = _course_radius(s2) / 3.35

		var b2: Basis = route * Basis(Vector3.FORWARD, roll) * base_ring
		if _course_gap(s2, i):
			r = 0.012
		b2 = b2.scaled(Vector3(r, r, 1.0))

		var pos2: Vector3 = p2 - route.x * lane
		_course_rings_mm.set_instance_transform(i, Transform3D(b2, pos2))

	# Nervures longitudinales : suivent le rayon variable du tube.
	var idx: int = 0
	for j in COURSE_RIB_DEPTH:
		var d3: float = 0.9 + float(j) * 3.0
		var s3: float = distance + d3
		var p3: Vector3 = _course_point(s3) - base
		var route3: Basis = _course_basis(s3)
		var roll3: float = _course_roll(s3)
		var rr: float = _course_radius(s3)
		var radial_basis: Basis = route3 * Basis(Vector3.FORWARD, roll3)

		for a_i in COURSE_RIBS:
			var a: float = TAU * float(a_i) / float(COURSE_RIBS)
			var radial: Vector3 = Vector3(cos(a) * rr, sin(a) * rr, 0.0)
			var pos3: Vector3 = p3 - route3.x * lane + radial_basis * radial
			_course_ribs_mm.set_instance_transform(idx, Transform3D(route3, pos3))
			idx += 1

	# Portes placees devant, avec certains passages volontairement tres proches.
	for g in 18:
		var dg: float = 7.0 + float(g) * 8.5
		var sg: float = distance + dg
		var pg: Vector3 = _course_point(sg) - base
		var bg: Basis = _course_basis(sg)
		var secteur_g: int = _course_sector(sg)
		var lateral: float = 0.0
		if secteur_g == 5:
			lateral = sin(float(g) * 1.7) * 2.0
		var posg: Vector3 = pg - bg.x * lane + bg.x * lateral
		var scale_x: float = 1.0
		if secteur_g == 2:
			scale_x = 1.55
		elif secteur_g == 1:
			scale_x = 0.82
		var gb: Basis = bg.scaled(Vector3(scale_x, 1.0, 1.0))
		_course_gate_mm.set_instance_transform(g, Transform3D(gb, posg))

	# Couleur/energie change avec le secteur.
	if _course_glow != null:
		var energies: Array = [1.9, 2.5, 1.7, 2.1, 2.8, 3.1]
		_course_glow.emission_energy_multiplier = float(energies[secteur])



func _debut_course_v36() -> void:
	if _course_root == null:
		return
	_course_root.visible = true
	_course_sector_avant = -1

	# Cache les trois representations precedentes pour n'en garder qu'une,
	# celle du directeur v36.
	_course_saved = {}
	for cle in ["_piste_node", "_rails_node", "_tunnel_node"]:
		var n: Variant = v33.get(cle)
		if n is GeometryInstance3D:
			_course_saved[cle] = (n as GeometryInstance3D).visible
			(n as GeometryInstance3D).visible = false

	var old_v: Variant = v35.get("_course_tube_node")
	if old_v is GeometryInstance3D:
		_course_saved["v35_tube"] = (old_v as GeometryInstance3D).visible
		(old_v as GeometryInstance3D).visible = false


func _fin_course_v36() -> void:
	if _course_root != null:
		_course_root.visible = false

	for cle in ["_piste_node", "_rails_node", "_tunnel_node"]:
		var n: Variant = v33.get(cle)
		if n is GeometryInstance3D:
			(n as GeometryInstance3D).visible = bool(_course_saved.get(cle, true))

	var old_v: Variant = v35.get("_course_tube_node")
	if old_v is GeometryInstance3D:
		(old_v as GeometryInstance3D).visible = bool(_course_saved.get("v35_tube", false))

	_course_saved = {}
	_course_sector_avant = -1
