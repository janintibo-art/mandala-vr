class_name V35Manager
extends Node
## Mandala VR v35 : moteur de sensations v2.
##
## Objectifs :
## - donner un rythme "vraies montagnes russes" au Grand 8 de la mort :
##   montee lente -> sommet -> bascule -> plongee -> pleine vitesse.
## - rendre la chute libre beaucoup plus lisible avec un sol tres loin,
##   une cage verticale et des reperes qui remontent autour du joueur.
## - rendre la Course encore plus intrusive avec une vraie cage/tube lumineux
##   continu autour du vehicule, en plus des anneaux v34.
##
## Le moteur se superpose aux v31/v32/v33 sans modifier leur logique stable.

const NB_CHUTE_RINGS: int = 22
const NB_CHUTE_PILIERS: int = 14
const NB_COURSE_LONGS: int = 360
const COURSE_RADIAUX: int = 12
const COURSE_PROFONDEUR: int = 30
const COURSE_PAS: float = 3.05
const COURSE_RAYON: float = 3.55

var app = null
var v31 = null
var v32 = null
var v33 = null

var _installe: bool = false
var _mort_avant: bool = false
var _course_avant: bool = false
var _etat_mort_avant: int = -1
var _ride_stage_avant: int = -1

# Reference visuelle proche dans le Grand 8.
var _nacelle: Node3D = null

# Chute libre v2.
var _chute_root: Node3D = null
var _chute_rings_node: MultiMeshInstance3D = null
var _chute_rings_mm: MultiMesh = null
var _chute_piliers_node: MultiMeshInstance3D = null
var _chute_piliers_mm: MultiMesh = null
var _sol_chute: MeshInstance3D = null
var _sol_glow: MeshInstance3D = null

# Tube Course v2.
var _course_tube_node: MultiMeshInstance3D = null
var _course_tube_mm: MultiMesh = null
var _course_tube_mat: StandardMaterial3D = null

var _message_cooldown: float = 0.0


func _ready() -> void:
	app = get_parent()
	v31 = app.get_node_or_null("V31Manager")
	v32 = app.get_node_or_null("V32Manager")
	v33 = app.get_node_or_null("V33Manager")
	process_priority = 280


func _process(dt: float) -> void:
	if app == null:
		return

	if not _installe:
		var pret: bool = (
			app.camera != null
			and app.origine != null
			and v31 != null
			and bool(v31.get("_installe"))
			and v32 != null
			and bool(v32.get("_installe"))
			and v33 != null
			and bool(v33.get("_installe"))
		)
		if pret:
			_installer()
		return

	_message_cooldown = maxf(0.0, _message_cooldown - dt)

	_maj_grand8_v2(dt)
	_maj_course_v2(dt)


# ================================================================== INSTALLATION

func _installer() -> void:
	_installe = true
	_creer_nacelle()
	_creer_chute_v2()
	_creer_course_v2()
	app.message("v35 : moteur de sensations v2 actif")


func _mat_glow(c: Color, energie: float = 2.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = Color(c.r, c.g, c.b, 1.0)
	m.emission_energy_multiplier = energie
	return m


# ================================================================== NACELLE / REPERE PROCHE

func _creer_nacelle() -> void:
	_nacelle = Node3D.new()
	_nacelle.name = "V35Nacelle"
	_nacelle.visible = false
	app.camera.add_child(_nacelle)

	var sombre: StandardMaterial3D = StandardMaterial3D.new()
	sombre.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sombre.albedo_color = Color(0.035, 0.045, 0.075)
	sombre.metallic = 0.55
	sombre.roughness = 0.34

	var glow: StandardMaterial3D = _mat_glow(Color(0.20, 0.66, 1.0, 0.88), 2.5)

	# Bord avant de la nacelle.
	var avant: MeshInstance3D = MeshInstance3D.new()
	var avant_mesh: BoxMesh = BoxMesh.new()
	avant_mesh.size = Vector3(1.35, 0.11, 0.22)
	avant.mesh = avant_mesh
	avant.material_override = sombre
	avant.position = Vector3(0.0, -0.58, -0.78)
	_nacelle.add_child(avant)

	# Barre de maintien visible en bas du champ de vision.
	var barre: MeshInstance3D = MeshInstance3D.new()
	var barre_mesh: BoxMesh = BoxMesh.new()
	barre_mesh.size = Vector3(1.12, 0.055, 0.055)
	barre.mesh = barre_mesh
	barre.material_override = glow
	barre.position = Vector3(0.0, -0.43, -0.70)
	_nacelle.add_child(barre)

	for cote in [-1.0, 1.0]:
		var rail: MeshInstance3D = MeshInstance3D.new()
		var rail_mesh: BoxMesh = BoxMesh.new()
		rail_mesh.size = Vector3(0.055, 0.055, 1.10)
		rail.mesh = rail_mesh
		rail.material_override = glow
		rail.position = Vector3(0.58 * cote, -0.53, -0.36)
		rail.rotation.y = deg_to_rad(5.0 * cote)
		_nacelle.add_child(rail)


# ================================================================== GRAND 8 DE LA MORT V2

func _maj_grand8_v2(dt: float) -> void:
	var mort: bool = bool(v32.get("_mort"))
	if mort != _mort_avant:
		_mort_avant = mort
		if mort:
			_nacelle.visible = true
			_ride_stage_avant = -1
		else:
			_fin_grand8_v2()

	if not mort:
		return

	var etat: int = int(v32.get("_etat_mort"))
	if etat != _etat_mort_avant:
		_etat_mort_avant = etat
		if etat == 2:
			_debut_chute_v2()
		elif etat != 2:
			_cacher_chute_v2()

	match etat:
		0:
			_maj_tunnel_scenarise(dt)
		1:
			_maj_rupture_v2()
		2:
			_maj_chute_v2()
		3:
			_maj_reentree_v2()


func _fin_grand8_v2() -> void:
	_cacher_chute_v2()
	if _nacelle != null:
		_nacelle.visible = false
		_nacelle.rotation = Vector3.ZERO
	var r: Variant = v31.get("_racine")
	if r is Node3D:
		(r as Node3D).rotation = Vector3.ZERO
	_ride_stage_avant = -1
	_etat_mort_avant = -1


func _maj_tunnel_scenarise(dt: float) -> void:
	var phase: float = float(v32.get("_phase_t"))
	var fin: float = maxf(1.0, float(v32.get("_prochaine_rupture")))
	var ratio: float = clampf(phase / fin, 0.0, 1.0)
	var chapitre: int = int(v32.get("_chapitre"))

	var stage: int = 3
	if ratio < 0.27:
		stage = 0 # montee
	elif ratio < 0.39:
		stage = 1 # sommet
	elif ratio < 0.61:
		stage = 2 # bascule / plongee

	if stage != _ride_stage_avant:
		_ride_stage_avant = stage
		_annoncer_stage(stage)

	var root_v: Variant = v31.get("_racine")
	if not (root_v is Node3D):
		return
	var root: Node3D = root_v

	var vitesse_chapitre: float = 27.0 + minf(float(chapitre), 5.0) * 1.25
	var pitch: float = 0.0
	var roll: float = 0.0
	var vitesse: float = vitesse_chapitre

	if stage == 0:
		var k0: float = ratio / 0.27
		vitesse = lerpf(8.0, 13.0 + float(chapitre) * 0.8, k0)
		pitch = deg_to_rad(lerpf(5.0, 18.0 + float(chapitre) * 1.4, k0))
		roll = sin(phase * 0.35) * 0.025

	elif stage == 1:
		var k1: float = (ratio - 0.27) / 0.12
		vitesse = lerpf(8.0, 4.5, k1)
		pitch = deg_to_rad(lerpf(18.0 + float(chapitre), -5.0, k1))
		roll = sin(phase * 0.6) * 0.018

	elif stage == 2:
		var k2: float = (ratio - 0.39) / 0.22
		vitesse = lerpf(8.0, minf(34.0, 30.0 + float(chapitre)), k2)
		pitch = deg_to_rad(lerpf(-7.0, -31.0 - float(chapitre) * 1.2, k2))
		roll = sin(phase * 0.85) * deg_to_rad(6.0 + float(chapitre) * 0.8)

	else:
		var k3: float = (ratio - 0.61) / 0.39
		vitesse = minf(34.0, vitesse_chapitre + 4.0)
		pitch = deg_to_rad(lerpf(-25.0, 2.0, k3))
		roll = sin(phase * 0.72) * deg_to_rad(8.0 + float(chapitre))

	v31.set("_vitesse", vitesse)

	# On ne tourne pas la camera : on incline le monde/tunnel autour d'elle.
	root.rotation.x = lerp_angle(root.rotation.x, pitch, clampf(dt * 2.7, 0.0, 1.0))
	root.rotation.z = lerp_angle(root.rotation.z, roll, clampf(dt * 2.2, 0.0, 1.0))

	# La nacelle est un repere stable mais reagit legerement a la trajectoire.
	if _nacelle != null:
		_nacelle.rotation.x = lerp_angle(
			_nacelle.rotation.x,
			-pitch * 0.22,
			clampf(dt * 3.5, 0.0, 1.0))
		_nacelle.rotation.z = lerp_angle(
			_nacelle.rotation.z,
			-roll * 0.55,
			clampf(dt * 3.2, 0.0, 1.0))


func _annoncer_stage(stage: int) -> void:
	if _message_cooldown > 0.0:
		return
	_message_cooldown = 1.0
	match stage:
		0:
			app.message("MONTEE...")
		1:
			app.message("SOMMET...")
		2:
			app.message("BASCULE !")
		_:
			app.message("PLEINE VITESSE")


func _maj_rupture_v2() -> void:
	var root_v: Variant = v31.get("_racine")
	if root_v is Node3D:
		var root: Node3D = root_v
		var k: float = clampf(float(v32.get("_phase_t")) / 0.72, 0.0, 1.0)
		root.rotation.x = deg_to_rad(lerpf(-25.0, -42.0, k))
		root.rotation.z *= 0.96

	if _nacelle != null:
		_nacelle.rotation.x = deg_to_rad(6.0)


func _maj_reentree_v2() -> void:
	var root_v: Variant = v31.get("_racine")
	if root_v is Node3D:
		var root: Node3D = root_v
		var k: float = clampf(float(v32.get("_phase_t")) / 2.15, 0.0, 1.0)
		root.rotation.x = deg_to_rad(lerpf(-24.0, 0.0, k))
		root.rotation.z = sin(k * PI) * deg_to_rad(9.0)

	if _nacelle != null:
		var k2: float = clampf(float(v32.get("_phase_t")) / 2.15, 0.0, 1.0)
		_nacelle.rotation.x = deg_to_rad(lerpf(8.0, 0.0, k2))
		_nacelle.rotation.z = sin(k2 * PI) * deg_to_rad(-5.0)


# ================================================================== CHUTE LIBRE V2

func _creer_chute_v2() -> void:
	_chute_root = Node3D.new()
	_chute_root.name = "V35ChuteV2"
	_chute_root.visible = false
	app.origine.add_child(_chute_root)

	# Anneaux horizontaux : ils remontent autour du joueur pendant la chute.
	var tor: TorusMesh = TorusMesh.new()
	tor.inner_radius = 5.7
	tor.outer_radius = 5.82
	tor.rings = 32
	tor.ring_segments = 6
	tor.material = _mat_glow(Color(0.18, 0.58, 1.0, 0.42), 1.8)

	_chute_rings_mm = MultiMesh.new()
	_chute_rings_mm.transform_format = MultiMesh.TRANSFORM_3D
	_chute_rings_mm.instance_count = NB_CHUTE_RINGS
	_chute_rings_mm.mesh = tor

	_chute_rings_node = MultiMeshInstance3D.new()
	_chute_rings_node.name = "AnneauxChuteV35"
	_chute_rings_node.multimesh = _chute_rings_mm
	_chute_rings_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chute_rings_node.extra_cull_margin = 140.0
	_chute_root.add_child(_chute_rings_node)

	# Piliers tres longs : donnent l'echelle et la hauteur de la cavite.
	var pilier_mesh: BoxMesh = BoxMesh.new()
	pilier_mesh.size = Vector3(0.10, 32.0, 0.10)
	pilier_mesh.material = _mat_glow(Color(0.10, 0.34, 0.72, 0.26), 1.3)

	_chute_piliers_mm = MultiMesh.new()
	_chute_piliers_mm.transform_format = MultiMesh.TRANSFORM_3D
	_chute_piliers_mm.instance_count = NB_CHUTE_PILIERS
	_chute_piliers_mm.mesh = pilier_mesh

	_chute_piliers_node = MultiMeshInstance3D.new()
	_chute_piliers_node.name = "PiliersChuteV35"
	_chute_piliers_node.multimesh = _chute_piliers_mm
	_chute_piliers_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chute_piliers_node.extra_cull_margin = 160.0
	_chute_root.add_child(_chute_piliers_node)

	for i in NB_CHUTE_PILIERS:
		var a: float = TAU * float(i) / float(NB_CHUTE_PILIERS)
		var rayon: float = 7.0 + sin(float(i) * 2.1) * 0.9
		var pos: Vector3 = Vector3(cos(a) * rayon, -10.0, sin(a) * rayon)
		_chute_piliers_mm.set_instance_transform(i, Transform3D(Basis(), pos))

	# Sol lointain : gros repere qui grossit et remonte vers le joueur.
	_sol_chute = MeshInstance3D.new()
	var disque: CylinderMesh = CylinderMesh.new()
	disque.top_radius = 15.0
	disque.bottom_radius = 15.0
	disque.height = 0.22
	disque.radial_segments = 48
	var sol_mat: StandardMaterial3D = StandardMaterial3D.new()
	sol_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sol_mat.albedo_color = Color(0.008, 0.012, 0.028)
	sol_mat.emission_enabled = true
	sol_mat.emission = Color(0.015, 0.05, 0.11)
	sol_mat.emission_energy_multiplier = 1.4
	disque.material = sol_mat
	_sol_chute.mesh = disque
	_chute_root.add_child(_sol_chute)

	_sol_glow = MeshInstance3D.new()
	var glow_tor: TorusMesh = TorusMesh.new()
	glow_tor.inner_radius = 10.8
	glow_tor.outer_radius = 11.0
	glow_tor.rings = 48
	glow_tor.ring_segments = 8
	glow_tor.material = _mat_glow(Color(0.22, 0.70, 1.0, 0.78), 3.0)
	_sol_glow.mesh = glow_tor
	_sol_glow.rotation.x = 0.0
	_chute_root.add_child(_sol_glow)


func _debut_chute_v2() -> void:
	if _chute_root == null:
		return
	_chute_root.position = app.camera.position
	_chute_root.rotation = Vector3.ZERO
	_chute_root.visible = true
	if _nacelle != null:
		_nacelle.visible = true
	app.message("CHUTE LIBRE")


func _cacher_chute_v2() -> void:
	if _chute_root != null:
		_chute_root.visible = false


func _maj_chute_v2() -> void:
	if _chute_root == null or not _chute_root.visible:
		return

	_chute_root.position = app.camera.position

	var phase: float = float(v32.get("_phase_t"))
	var duree: float = maxf(1.0, float(v32.get("_duree_chute_actuelle")))
	var k: float = clampf(phase / duree, 0.0, 1.0)

	# Les anneaux remontent de plus en plus vite : accelere visuellement la chute.
	var accel: float = 7.0 + k * k * 28.0
	var hauteur_total: float = 34.0
	for i in NB_CHUTE_RINGS:
		var y: float = fposmod(float(i) * 1.65 + phase * accel + 18.0, hauteur_total) - 18.0
		var scale_ring: float = 0.80 + 0.20 * (1.0 - absf(y) / 18.0)
		var b: Basis = Basis().scaled(Vector3.ONE * scale_ring)
		_chute_rings_mm.set_instance_transform(i, Transform3D(b, Vector3(0.0, y, 0.0)))

	# Le sol tres loin se rapproche de facon non lineaire.
	var chute_ease: float = k * k
	var y_sol: float = lerpf(-46.0, -6.5, chute_ease)
	_sol_chute.position = Vector3(0.0, y_sol, -1.5)
	_sol_glow.position = Vector3(0.0, y_sol + 0.16, -1.5)

	var s: float = lerpf(0.62, 1.35, chute_ease)
	_sol_chute.scale = Vector3.ONE * s
	_sol_glow.scale = Vector3.ONE * s

	# La cavite tourne tres legerement, pas la camera.
	_chute_root.rotation.y = sin(phase * 0.34) * 0.08

	if _nacelle != null:
		_nacelle.rotation.x = deg_to_rad(7.0 + k * 4.0)
		_nacelle.position.y = sin(phase * 7.0) * 0.006


# ================================================================== COURSE V2 : CAGE LUMINEUSE COMPLETE

func _creer_course_v2() -> void:
	var root_v: Variant = v33.get("_racine")
	if not (root_v is Node3D):
		return
	var course_root: Node3D = root_v

	var barre: BoxMesh = BoxMesh.new()
	barre.size = Vector3(0.035, 0.035, COURSE_PAS * 1.20)

	_course_tube_mat = _mat_glow(Color(0.16, 0.62, 1.0, 0.48), 1.9)
	barre.material = _course_tube_mat

	_course_tube_mm = MultiMesh.new()
	_course_tube_mm.transform_format = MultiMesh.TRANSFORM_3D
	_course_tube_mm.instance_count = NB_COURSE_LONGS
	_course_tube_mm.mesh = barre

	_course_tube_node = MultiMeshInstance3D.new()
	_course_tube_node.name = "V35CourseTubeContinu"
	_course_tube_node.multimesh = _course_tube_mm
	_course_tube_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_course_tube_node.extra_cull_margin = 180.0
	_course_tube_node.visible = false
	course_root.add_child(_course_tube_node)


func _maj_course_v2(_dt: float) -> void:
	var actif: bool = bool(v33.get("_actif"))
	if actif != _course_avant:
		_course_avant = actif
		if _course_tube_node != null:
			_course_tube_node.visible = actif

	if not actif or _course_tube_mm == null:
		return

	var distance: float = float(v33.get("_distance"))
	var lane: float = float(v33.get("_lane"))

	var base_v: Variant = v33.call("_courbe", distance)
	if not (base_v is Vector3):
		return
	var base: Vector3 = base_v

	var idx: int = 0
	for j in COURSE_PROFONDEUR:
		var d: float = 1.0 + float(j) * COURSE_PAS
		var s: float = distance + d

		var monde_v: Variant = v33.call("_courbe", s)
		var basis_v: Variant = v33.call("_segment_basis", s)
		if not (monde_v is Vector3) or not (basis_v is Basis):
			continue

		var monde: Vector3 = monde_v
		var route_basis: Basis = basis_v
		var centre: Vector3 = Vector3(
			monde.x - base.x - lane,
			monde.y - base.y - 0.08,
			-d)

		for a_i in COURSE_RADIAUX:
			if idx >= NB_COURSE_LONGS:
				break
			var a: float = TAU * float(a_i) / float(COURSE_RADIAUX)
			var radial_local: Vector3 = Vector3(
				cos(a) * COURSE_RAYON,
				sin(a) * COURSE_RAYON,
				0.0)
			var radial_world: Vector3 = route_basis * radial_local
			var pos: Vector3 = centre + radial_world

			# Les lignes suivent l'axe de la route. Ensemble elles forment
			# une cage/tube 360 degres au lieu de simples rails lateraux.
			_course_tube_mm.set_instance_transform(
				idx,
				Transform3D(route_basis, pos))
			idx += 1

	var secteur: int = int(floor(distance / 220.0)) % 6
	var secteurs: Array = [
		"NOVA",
		"PRISME",
		"AURORA",
		"MATRIX",
		"INFERNO",
		"ABYSSE",
	]

	if _course_tube_mat != null:
		var puls: float = 1.55 + 0.45 * sin(distance * 0.055)
		_course_tube_mat.emission_energy_multiplier = puls

	var tunnel_mat_v: Variant = v33.get("_tunnel_mat")
	if tunnel_mat_v is ShaderMaterial:
		var tunnel_mat: ShaderMaterial = tunnel_mat_v
		var mondes: Array = [1, 11, 3, 6, 9, 19]
		tunnel_mat.set_shader_parameter("world_index", int(mondes[secteur]))

	var hud_v: Variant = v33.get("_hud")
	if hud_v is Label3D:
		var hud: Label3D = hud_v
		if not hud.text.contains("SECTEUR"):
			hud.text += "  |  SECTEUR " + str(secteurs[secteur])
