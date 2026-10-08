class_name V38Manager
extends Node
## Mandala VR v38 : flux de proximite.
##
## Le parcours v36 reste intact, mais on remet le "bombardement visuel"
## qui donnait beaucoup de vitesse dans les versions plus lineaires :
## - traits lumineux qui surgissent de l'avant ;
## - fragments geometriques qui passent pres du visage ;
## - portiques / traverses qui grossissent tres vite ;
## - densite progressive selon le chapitre du Grand 8 de la mort ;
## - version plus legere egalement pendant la Course.
##
## Une zone centrale reste volontairement vide pour garder la lecture
## du parcours et eviter qu'un objet masque completement la vue.

const DEATH_SHARDS: int = 72
const DEATH_BARS: int = 28
const COURSE_SHARDS: int = 54

const DEATH_LOOP: float = 82.0
const COURSE_LOOP: float = 104.0

var app = null
var v31 = null
var v32 = null
var v33 = null
var v36 = null

var _installe: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Grand 8
var _death_root: Node3D = null
var _death_shards_node: MultiMeshInstance3D = null
var _death_shards_mm: MultiMesh = null
var _death_bars_node: MultiMeshInstance3D = null
var _death_bars_mm: MultiMesh = null
var _death_shard_phase: Array = []
var _death_shard_angle: Array = []
var _death_shard_radius: Array = []
var _death_shard_speed: Array = []
var _death_bar_phase: Array = []
var _death_bar_side: Array = []
var _death_bar_height: Array = []

# Course
var _course_root: Node3D = null
var _course_shards_node: MultiMeshInstance3D = null
var _course_shards_mm: MultiMesh = null
var _course_phase: Array = []
var _course_angle: Array = []
var _course_radius: Array = []
var _course_speed: Array = []

var _death_mat: StandardMaterial3D = null
var _bar_mat: StandardMaterial3D = null
var _course_mat: StandardMaterial3D = null

var _death_on: bool = false
var _course_on: bool = false
var _chapitre_avant: int = -1


func _ready() -> void:
	app = get_parent()
	v31 = app.get_node_or_null("V31Manager")
	v32 = app.get_node_or_null("V32Manager")
	v33 = app.get_node_or_null("V33Manager")
	v36 = app.get_node_or_null("V36Manager")
	process_priority = 300
	_rng.randomize()


func _process(_dt: float) -> void:
	if app == null:
		return

	if not _installe:
		var pret: bool = (
			v31 != null and bool(v31.get("_installe"))
			and v32 != null and bool(v32.get("_installe"))
			and v33 != null and bool(v33.get("_installe"))
			and v36 != null and bool(v36.get("_installe"))
		)
		if pret:
			_installer()
		return

	_maj_death_flux()
	_maj_course_flux()


# =====================================================================
# INSTALLATION

func _installer() -> void:
	_installe = true
	_creer_death_flux()
	_creer_course_flux()


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
# GRAND 8 DE LA MORT

func _creer_death_flux() -> void:
	var root_v: Variant = v31.get("_racine")
	if not (root_v is Node3D):
		return
	_death_root = root_v

	# Traits / fragments longitudinaux.
	var shard_mesh: BoxMesh = BoxMesh.new()
	shard_mesh.size = Vector3(0.045, 0.045, 1.85)
	_death_mat = _glow(Color(0.28, 0.72, 1.0, 0.66), 2.7)
	shard_mesh.material = _death_mat

	_death_shards_mm = MultiMesh.new()
	_death_shards_mm.transform_format = MultiMesh.TRANSFORM_3D
	_death_shards_mm.instance_count = DEATH_SHARDS
	_death_shards_mm.mesh = shard_mesh

	_death_shards_node = MultiMeshInstance3D.new()
	_death_shards_node.name = "V38DeathShards"
	_death_shards_node.multimesh = _death_shards_mm
	_death_shards_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_death_shards_node.extra_cull_margin = 180.0
	_death_shards_node.visible = false
	_death_root.add_child(_death_shards_node)

	for i in DEATH_SHARDS:
		_death_shard_phase.append(_rng.randf() * DEATH_LOOP)
		_death_shard_angle.append(_rng.randf() * TAU)
		# Jamais au centre : minimum 1.15 m autour de la tete.
		_death_shard_radius.append(_rng.randf_range(1.15, 3.20))
		_death_shard_speed.append(_rng.randf_range(1.20, 1.90))

	# Traverses / plaques : plus grosses, moins nombreuses.
	var bar_mesh: BoxMesh = BoxMesh.new()
	bar_mesh.size = Vector3(1.30, 0.08, 0.08)
	_bar_mat = _glow(Color(0.90, 0.38, 1.0, 0.64), 2.4)
	bar_mesh.material = _bar_mat

	_death_bars_mm = MultiMesh.new()
	_death_bars_mm.transform_format = MultiMesh.TRANSFORM_3D
	_death_bars_mm.instance_count = DEATH_BARS
	_death_bars_mm.mesh = bar_mesh

	_death_bars_node = MultiMeshInstance3D.new()
	_death_bars_node.name = "V38DeathBars"
	_death_bars_node.multimesh = _death_bars_mm
	_death_bars_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_death_bars_node.extra_cull_margin = 180.0
	_death_bars_node.visible = false
	_death_root.add_child(_death_bars_node)

	for i in DEATH_BARS:
		_death_bar_phase.append(_rng.randf() * DEATH_LOOP)
		_death_bar_side.append(-1.0 if _rng.randf() < 0.5 else 1.0)
		_death_bar_height.append(_rng.randf_range(-1.55, 1.55))


func _death_basis(d: float, chapitre: int, ratio: float) -> Basis:
	var p_v: Variant = v36.call("_death_point", d, chapitre, ratio)
	var p2_v: Variant = v36.call("_death_point", d + 0.22, chapitre, ratio)
	if not (p_v is Vector3) or not (p2_v is Vector3):
		return Basis()
	var p: Vector3 = p_v
	var p2: Vector3 = p2_v
	var dir: Vector3 = (p2 - p).normalized()
	return Basis.looking_at(dir, Vector3.UP)


func _maj_death_flux() -> void:
	var mort: bool = bool(v32.get("_mort"))
	var etat: int = int(v32.get("_etat_mort"))

	if mort != _death_on:
		_death_on = mort
		if _death_shards_node != null:
			_death_shards_node.visible = mort
		if _death_bars_node != null:
			_death_bars_node.visible = mort

	if not mort or _death_shards_mm == null:
		return

	# Pendant la chute libre, on coupe le trafic longitudinal :
	# la chute v35 garde sa propre lecture verticale.
	var tunnel: bool = etat == 0 or etat == 1 or etat == 3
	_death_shards_node.visible = tunnel
	_death_bars_node.visible = tunnel
	if not tunnel:
		return

	var chapitre: int = mini(int(v32.get("_chapitre")), 5)
	var phase: float = float(v32.get("_phase_t"))
	var fin: float = maxf(1.0, float(v32.get("_prochaine_rupture")))
	var ratio: float = clampf(phase / fin, 0.0, 1.0)
	var travel: float = float(v31.get("_travel"))

	# Plus le chapitre avance, plus il y a d'objets visibles.
	var shard_actifs: int = mini(DEATH_SHARDS, 34 + chapitre * 8)
	var bars_actives: int = mini(DEATH_BARS, 10 + chapitre * 3)

	for i in DEATH_SHARDS:
		if i >= shard_actifs:
			_death_shards_mm.set_instance_transform(
				i, Transform3D(Basis().scaled(Vector3.ONE * 0.001), Vector3(0, 0, -100)))
			continue

		var d: float = fposmod(
			float(_death_shard_phase[i]) - travel * float(_death_shard_speed[i]),
			DEATH_LOOP) + 0.75

		var p_v: Variant = v36.call("_death_point", d, chapitre, ratio)
		if not (p_v is Vector3):
			continue
		var p: Vector3 = p_v
		var b: Basis = _death_basis(d, chapitre, ratio)

		var a: float = float(_death_shard_angle[i]) + d * 0.018
		var rayon: float = float(_death_shard_radius[i])

		# Les derniers chapitres ont davantage de passages tres proches.
		if chapitre >= 3 and i % 5 == 0:
			rayon *= 0.82
		if chapitre >= 5 and i % 7 == 0:
			rayon *= 0.80

		var radial: Vector3 = b.x * cos(a) * rayon + b.y * sin(a) * rayon
		var pos: Vector3 = p + radial

		# Etirement tres fort quand l'objet approche.
		var proche: float = 1.0 - clampf(d / 26.0, 0.0, 1.0)
		var stretch: float = 1.0 + proche * proche * (3.0 + chapitre * 0.32)
		var sb: Basis = b.scaled(Vector3(1.0, 1.0, stretch))
		_death_shards_mm.set_instance_transform(i, Transform3D(sb, pos))

	for i in DEATH_BARS:
		if i >= bars_actives:
			_death_bars_mm.set_instance_transform(
				i, Transform3D(Basis().scaled(Vector3.ONE * 0.001), Vector3(0, 0, -100)))
			continue

		var d2: float = fposmod(
			float(_death_bar_phase[i]) - travel * (1.12 + float(i % 5) * 0.09),
			DEATH_LOOP) + 2.0

		var p2_v: Variant = v36.call("_death_point", d2, chapitre, ratio)
		if not (p2_v is Vector3):
			continue
		var p2: Vector3 = p2_v
		var b2: Basis = _death_basis(d2, chapitre, ratio)

		var side: float = float(_death_bar_side[i])
		var lateral: float = side * (1.55 + float(i % 3) * 0.30)
		var hauteur: float = float(_death_bar_height[i])

		# Les grandes barres "rasent" la trajectoire mais ne passent jamais
		# dans le centre de vision.
		if chapitre >= 4 and i % 4 == 0:
			lateral *= 0.78

		var pos2: Vector3 = p2 + b2.x * lateral + b2.y * hauteur
		var roll: float = (float(i % 7) - 3.0) * 0.12 + d2 * 0.018
		var bb: Basis = b2 * Basis(Vector3.FORWARD, roll)

		var proche2: float = 1.0 - clampf(d2 / 24.0, 0.0, 1.0)
		var sc: float = 1.0 + proche2 * 0.55
		bb = bb.scaled(Vector3(sc, sc, 1.0))
		_death_bars_mm.set_instance_transform(i, Transform3D(bb, pos2))

	# Couleurs par chapitre.
	var couleurs: Array = [
		Color(0.20, 0.68, 1.0, 0.66),
		Color(0.72, 0.22, 1.0, 0.68),
		Color(0.12, 0.82, 1.0, 0.66),
		Color(1.0, 0.26, 0.72, 0.70),
		Color(1.0, 0.40, 0.12, 0.72),
		Color(0.78, 0.18, 1.0, 0.76),
	]
	if _death_mat != null:
		var c: Color = couleurs[chapitre]
		_death_mat.albedo_color = c
		_death_mat.emission = Color(c.r, c.g, c.b, 1.0)
		_death_mat.emission_energy_multiplier = 2.5 + chapitre * 0.18

	if _bar_mat != null:
		_bar_mat.emission_energy_multiplier = 2.1 + chapitre * 0.22


# =====================================================================
# COURSE : MEME IDEE, MAIS PLUS LEGERE

func _creer_course_flux() -> void:
	var root_v: Variant = v33.get("_racine")
	if not (root_v is Node3D):
		return
	_course_root = root_v

	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.04, 0.04, 1.45)
	_course_mat = _glow(Color(0.18, 0.70, 1.0, 0.54), 2.2)
	mesh.material = _course_mat

	_course_shards_mm = MultiMesh.new()
	_course_shards_mm.transform_format = MultiMesh.TRANSFORM_3D
	_course_shards_mm.instance_count = COURSE_SHARDS
	_course_shards_mm.mesh = mesh

	_course_shards_node = MultiMeshInstance3D.new()
	_course_shards_node.name = "V38CourseShards"
	_course_shards_node.multimesh = _course_shards_mm
	_course_shards_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_course_shards_node.extra_cull_margin = 180.0
	_course_shards_node.visible = false
	_course_root.add_child(_course_shards_node)

	for i in COURSE_SHARDS:
		_course_phase.append(_rng.randf() * COURSE_LOOP)
		_course_angle.append(_rng.randf() * TAU)
		_course_radius.append(_rng.randf_range(1.25, 3.00))
		_course_speed.append(_rng.randf_range(1.12, 1.62))


func _maj_course_flux() -> void:
	var actif: bool = bool(v33.get("_actif"))

	if actif != _course_on:
		_course_on = actif
		if _course_shards_node != null:
			_course_shards_node.visible = actif

	if not actif or _course_shards_mm == null:
		return

	var distance: float = float(v33.get("_distance"))
	var lane: float = float(v33.get("_lane"))

	for i in COURSE_SHARDS:
		var d: float = fposmod(
			float(_course_phase[i]) - distance * float(_course_speed[i]),
			COURSE_LOOP) + 1.0
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

		var a: float = float(_course_angle[i]) + s * 0.013
		var r: float = float(_course_radius[i])
		var radial: Vector3 = b.x * cos(a) * r + b.y * sin(a) * r

		var proche: float = 1.0 - clampf(d / 28.0, 0.0, 1.0)
		var stretch: float = 1.0 + proche * proche * 3.2
		var sb: Basis = b.scaled(Vector3(1.0, 1.0, stretch))
		_course_shards_mm.set_instance_transform(i, Transform3D(sb, centre + radial))

	if _course_mat != null:
		var secteur_v: Variant = v36.call("_course_sector", distance)
		var secteur: int = int(secteur_v)
		var couleurs: Array = [
			Color(0.18, 0.70, 1.0, 0.54),
			Color(0.62, 0.24, 1.0, 0.58),
			Color(1.0, 0.72, 0.22, 0.54),
			Color(0.14, 0.46, 1.0, 0.56),
			Color(0.20, 1.0, 0.74, 0.58),
			Color(1.0, 0.28, 0.48, 0.62),
		]
		var c: Color = couleurs[secteur]
		_course_mat.albedo_color = c
		_course_mat.emission = Color(c.r, c.g, c.b, 1.0)
