class_name V53RideFXManager
extends Node
## Mandala VR v53/v54 : consolidation des effets Grand 8 / Course.
##
## v54 corrige les liaisons internes de la consolidation.
## Regroupe les anciennes couches v38, v39, v40 et v41 :
## - flux de proximite ;
## - evenements ponctuels ;
## - mise en scene dynamique ;
## - architecture / bifurcations.
##
## Le rendu et l'ordre d'execution sont conserves, mais 4 Nodes et
## 4 boucles _process deviennent un seul bloc runtime.

var app = null
var v31 = null
var v32 = null
var v33 = null
var v36 = null

var _installe: bool = false
var _death_prev_active: bool = false
var _course_prev_active: bool = false
var _slow_flip: bool = false

var _layer38 = null
var _layer39 = null
var _layer40 = null
var _layer41 = null


func _ready() -> void:
	app = get_parent()
	v31 = app.get_node_or_null("V31Manager")
	v32 = app.get_node_or_null("V32Manager")
	v33 = app.get_node_or_null("V33Manager")
	v36 = app.get_node_or_null("V36Manager")
	process_priority = 300


func _process(_dt: float) -> void:
	if app == null:
		return

	if not _installe:
		var ready_ok: bool = (
			v31 != null and bool(v31.get("_installe"))
			and v32 != null and bool(v32.get("_installe"))
			and v33 != null and bool(v33.get("_installe"))
			and v36 != null and bool(v36.get("_installe"))
		)
		if ready_ok:
			_installer()
		return

	var death_active: bool = bool(v32.get("_mort"))
	var course_active: bool = bool(v33.get("_actif"))
	_slow_flip = not _slow_flip

	# Ordre historique conserve : v38 -> v39 -> v40 -> v41.
	if death_active or _death_prev_active:
		_layer38._maj_death_flux()
		_layer39._maj_death_events()
		_layer40._maj_death_scene()

		# Architecture lointaine : cadence reduite comme en v51.
		if death_active != _death_prev_active or _slow_flip:
			_layer41._maj_death_world()

	if course_active or _course_prev_active:
		_layer38._maj_course_flux()
		_layer39._maj_course_events()
		_layer40._maj_course_scene()

		# Les bifurcations restent a pleine cadence car elles deplacent
		# lateralement le parcours pendant le choix de branche.
		_layer41._maj_course_branches()

	_death_prev_active = death_active
	_course_prev_active = course_active


func _installer() -> void:
	_layer38 = Layer38.new()
	_layer38.app = app
	_layer38.v31 = v31
	_layer38.v32 = v32
	_layer38.v33 = v33
	_layer38.v36 = v36
	_layer38._rng.randomize()
	_layer38._installer()

	_layer39 = Layer39.new()
	_layer39.app = app
	_layer39.v31 = v31
	_layer39.v32 = v32
	_layer39.v33 = v33
	_layer39.v36 = v36
	_layer39._installer()

	_layer40 = Layer40.new()
	_layer40.app = app
	_layer40.v31 = v31
	_layer40.v32 = v32
	_layer40.v33 = v33
	_layer40.v36 = v36
	_layer40.v38 = _layer38
	_layer40.v39 = _layer39
	_layer40._installer()

	_layer41 = Layer41.new()
	_layer41.app = app
	_layer41.v31 = v31
	_layer41.v32 = v32
	_layer41.v33 = v33
	_layer41.v36 = v36
	_layer41._installer()

	_installe = true


class Layer38:
	## v51 : ordonnancement optimise des couches decoratives Quest.
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


class Layer39:
	## v51 : ordonnancement optimise des couches decoratives Quest.
	## Mandala VR v39 : directeur d'evenements.
	##
	## v38 apporte le flux continu. v39 ajoute des "set pieces" ponctuels :
	## iris geants, portiques, faux murs, anneaux monumentaux et traverses.
	## L'objectif est que le joueur se souvienne de moments precis du parcours,
	## pas seulement d'un tunnel rapide.

	const DEATH_EVENT_COUNT: int = 4
	const COURSE_EVENT_COUNT: int = 4

	var app = null
	var v31 = null
	var v32 = null
	var v33 = null
	var v36 = null

	var _installe: bool = false
	var _death_root: Node3D = null
	var _course_root: Node3D = null

	# Evenements Grand 8
	var _death_rings: Array = []
	var _death_panels: Array = []
	var _death_beams: Array = []
	var _death_event_key: int = -1

	# Evenements Course
	var _course_rings: Array = []
	var _course_panels: Array = []
	var _course_columns: Array = []
	var _course_event_key: int = -1

	var _mat_blue: StandardMaterial3D
	var _mat_pink: StandardMaterial3D
	var _mat_gold: StandardMaterial3D
	var _mat_red: StandardMaterial3D


	func _installer() -> void:
		_installe = true

		_mat_blue = _glow(Color(0.16, 0.68, 1.0, 0.70), 3.0)
		_mat_pink = _glow(Color(0.90, 0.20, 1.0, 0.68), 3.0)
		_mat_gold = _glow(Color(1.0, 0.62, 0.14, 0.68), 3.0)
		_mat_red = _glow(Color(1.0, 0.18, 0.10, 0.72), 3.2)

		_creer_death_events()
		_creer_course_events()


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


	func _hide_all(nodes: Array) -> void:
		for n in nodes:
			if n is Node3D:
				(n as Node3D).visible = false


	# ================================================================== GRAND 8

	func _creer_death_events() -> void:
		var rv: Variant = v31.get("_racine")
		if not (rv is Node3D):
			return
		var parent: Node3D = rv

		_death_root = Node3D.new()
		_death_root.name = "V39DeathEvents"
		parent.add_child(_death_root)

		# 4 anneaux geants.
		for i in DEATH_EVENT_COUNT:
			var mi: MeshInstance3D = MeshInstance3D.new()
			var tor: TorusMesh = TorusMesh.new()
			tor.inner_radius = 2.15
			tor.outer_radius = 2.30
			tor.rings = 40
			tor.ring_segments = 8
			mi.mesh = tor
			mi.material_override = _mat_blue if i % 2 == 0 else _mat_pink
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visible = false
			_death_root.add_child(mi)
			_death_rings.append(mi)

		# 4 panneaux / faux murs.
		for i in DEATH_EVENT_COUNT:
			var mi: MeshInstance3D = MeshInstance3D.new()
			var bm: BoxMesh = BoxMesh.new()
			bm.size = Vector3(3.6, 4.6, 0.10)
			mi.mesh = bm
			mi.material_override = _mat_red if i % 2 == 0 else _mat_gold
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visible = false
			_death_root.add_child(mi)
			_death_panels.append(mi)

		# Traverses rotatives, toujours avec trou central.
		for i in 6:
			var mi: MeshInstance3D = MeshInstance3D.new()
			var bm: BoxMesh = BoxMesh.new()
			bm.size = Vector3(2.2, 0.10, 0.10)
			mi.mesh = bm
			mi.material_override = _mat_pink
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visible = false
			_death_root.add_child(mi)
			_death_beams.append(mi)


	func _death_transform(d: float, chapitre: int, ratio: float) -> Transform3D:
		var p_v: Variant = v36.call("_death_point", d, chapitre, ratio)
		var p2_v: Variant = v36.call("_death_point", d + 0.25, chapitre, ratio)
		if not (p_v is Vector3) or not (p2_v is Vector3):
			return Transform3D()

		var p: Vector3 = p_v
		var p2: Vector3 = p2_v
		var dir: Vector3 = (p2 - p).normalized()
		var b: Basis = Basis.looking_at(dir, Vector3.UP)
		return Transform3D(b, p)


	func _maj_death_events() -> void:
		if _death_root == null:
			return

		var mort: bool = bool(v32.get("_mort"))
		var etat: int = int(v32.get("_etat_mort"))
		_death_root.visible = mort and etat == 0

		if not _death_root.visible:
			_hide_all(_death_rings)
			_hide_all(_death_panels)
			_hide_all(_death_beams)
			return

		var chapitre: int = mini(int(v32.get("_chapitre")), 5)
		var phase: float = float(v32.get("_phase_t"))
		var fin: float = maxf(1.0, float(v32.get("_prochaine_rupture")))
		var ratio: float = clampf(phase / fin, 0.0, 1.0)

		# 4 actes par chapitre.
		var acte_f: float = ratio * 4.0
		var acte: int = mini(3, int(floor(acte_f)))
		var local: float = clampf(acte_f - float(acte), 0.0, 1.0)
		var key: int = chapitre * 10 + acte

		if key != _death_event_key:
			_death_event_key = key

		_hide_all(_death_rings)
		_hide_all(_death_panels)
		_hide_all(_death_beams)

		var type_evt: int = (chapitre + acte) % 4

		# L'evenement part de loin et traverse le joueur sur l'acte.
		var d: float = lerpf(52.0, 1.2, local)
		var tr: Transform3D = _death_transform(d, chapitre, ratio)

		match type_evt:
			0:
				_event_death_iris(tr, local, chapitre)
			1:
				_event_death_portique(tr, local, chapitre)
			2:
				_event_death_faux_mur(tr, local, chapitre)
			_:
				_event_death_traverses(tr, local, chapitre)


	func _event_death_iris(tr: Transform3D, local: float, chapitre: int) -> void:
		for i in _death_rings.size():
			var n: MeshInstance3D = _death_rings[i]
			n.visible = true
			var decal: float = float(i) * 2.4
			var t2: Transform3D = _death_transform(
				maxf(1.0, tr.origin.length() + decal),
				chapitre,
				clampf(float(v32.get("_phase_t")) / maxf(1.0, float(v32.get("_prochaine_rupture"))), 0.0, 1.0))
			# On garde surtout l'orientation de l'evenement principal.
			n.transform = tr
			n.position += tr.basis.z * (-decal)

			var fermeture: float = sin(PI * local)
			var s: float = 1.0 - fermeture * 0.34 + float(i) * 0.035
			n.scale = Vector3.ONE * s
			n.rotation.z = local * TAU * (0.15 + float(i) * 0.04)


	func _event_death_portique(tr: Transform3D, local: float, chapitre: int) -> void:
		for i in 2:
			var n: MeshInstance3D = _death_panels[i]
			n.visible = true
			n.transform = tr
			var cote: float = -1.0 if i == 0 else 1.0
			var fermeture: float = sin(PI * local)
			var ecart: float = lerpf(3.3, 1.55, fermeture)
			n.position += tr.basis.x * ecart * cote
			n.scale = Vector3(0.40, 1.0 + chapitre * 0.04, 1.0)


	func _event_death_faux_mur(tr: Transform3D, local: float, chapitre: int) -> void:
		var left: MeshInstance3D = _death_panels[0]
		var right: MeshInstance3D = _death_panels[1]
		left.visible = true
		right.visible = true
		left.transform = tr
		right.transform = tr

		# Le "mur" semble fermer la voie puis s'ouvre au dernier moment.
		var ouverture: float = smoothstep(0.58, 0.92, local)
		var x: float = lerpf(0.95, 3.2, ouverture)
		left.position += tr.basis.x * -x
		right.position += tr.basis.x * x
		left.scale = Vector3(0.58, 1.15, 1.0)
		right.scale = Vector3(0.58, 1.15, 1.0)


	func _event_death_traverses(tr: Transform3D, local: float, chapitre: int) -> void:
		for i in _death_beams.size():
			var n: MeshInstance3D = _death_beams[i]
			n.visible = true
			n.transform = tr
			var a: float = TAU * float(i) / float(_death_beams.size())
			var rayon: float = 1.75 + float(i % 2) * 0.35
			n.position += (
				tr.basis.x * cos(a) * rayon
				+ tr.basis.y * sin(a) * rayon
				+ tr.basis.z * (-float(i) * 0.55))
			n.rotation.z = a + local * TAU * (0.45 + chapitre * 0.05)
			n.scale = Vector3(0.95 + chapitre * 0.035, 1.0, 1.0)


	# ================================================================== COURSE

	func _creer_course_events() -> void:
		var rv: Variant = v33.get("_racine")
		if not (rv is Node3D):
			return
		var parent: Node3D = rv

		_course_root = Node3D.new()
		_course_root.name = "V39CourseEvents"
		parent.add_child(_course_root)

		for i in COURSE_EVENT_COUNT:
			var mi: MeshInstance3D = MeshInstance3D.new()
			var tor: TorusMesh = TorusMesh.new()
			tor.inner_radius = 2.35
			tor.outer_radius = 2.48
			tor.rings = 40
			tor.ring_segments = 8
			mi.mesh = tor
			mi.material_override = _mat_blue if i % 2 == 0 else _mat_pink
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visible = false
			_course_root.add_child(mi)
			_course_rings.append(mi)

		for i in COURSE_EVENT_COUNT:
			var mi: MeshInstance3D = MeshInstance3D.new()
			var bm: BoxMesh = BoxMesh.new()
			bm.size = Vector3(2.7, 4.9, 0.10)
			mi.mesh = bm
			mi.material_override = _mat_gold
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visible = false
			_course_root.add_child(mi)
			_course_panels.append(mi)

		for i in 8:
			var mi: MeshInstance3D = MeshInstance3D.new()
			var bm: BoxMesh = BoxMesh.new()
			bm.size = Vector3(0.12, 5.8, 0.12)
			mi.mesh = bm
			mi.material_override = _mat_blue
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visible = false
			_course_root.add_child(mi)
			_course_columns.append(mi)


	func _course_transform(s: float, distance: float, lane: float) -> Transform3D:
		var p_v: Variant = v36.call("_course_point", s)
		var b_v: Variant = v36.call("_course_basis", s)
		var base_v: Variant = v36.call("_course_point", distance)
		if not (p_v is Vector3) or not (b_v is Basis) or not (base_v is Vector3):
			return Transform3D()

		var p: Vector3 = p_v
		var base: Vector3 = base_v
		var b: Basis = b_v
		var centre: Vector3 = p - base - b.x * lane
		return Transform3D(b, centre)


	func _maj_course_events() -> void:
		if _course_root == null:
			return

		var actif: bool = bool(v33.get("_actif"))
		_course_root.visible = actif

		if not actif:
			_hide_all(_course_rings)
			_hide_all(_course_panels)
			_hide_all(_course_columns)
			return

		var distance: float = float(v33.get("_distance"))
		var lane: float = float(v33.get("_lane"))
		var secteur: int = int(v36.call("_course_sector", distance))
		var u: float = fposmod(distance, 165.0) / 165.0

		# Deux gros evenements par secteur.
		var demi: int = 0 if u < 0.5 else 1
		var local: float = (u * 2.0) if demi == 0 else ((u - 0.5) * 2.0)
		var key: int = secteur * 10 + demi

		if key != _course_event_key:
			_course_event_key = key

		_hide_all(_course_rings)
		_hide_all(_course_panels)
		_hide_all(_course_columns)

		var d: float = lerpf(62.0, 2.0, local)
		var s: float = distance + d
		var tr: Transform3D = _course_transform(s, distance, lane)
		var type_evt: int = (secteur + demi) % 4

		match type_evt:
			0:
				_course_evt_portes(tr, local)
			1:
				_course_evt_anneaux(tr, local)
			2:
				_course_evt_colonnes(tr, local)
			_:
				_course_evt_faille(tr, local)


	func _course_evt_portes(tr: Transform3D, local: float) -> void:
		for i in 2:
			var n: MeshInstance3D = _course_panels[i]
			n.visible = true
			n.transform = tr
			var cote: float = -1.0 if i == 0 else 1.0
			var fermeture: float = sin(PI * local)
			var x: float = lerpf(3.0, 1.45, fermeture)
			n.position += tr.basis.x * x * cote
			n.scale = Vector3(0.34, 1.0, 1.0)


	func _course_evt_anneaux(tr: Transform3D, local: float) -> void:
		for i in _course_rings.size():
			var n: MeshInstance3D = _course_rings[i]
			n.visible = true
			n.transform = tr
			n.position += tr.basis.z * (-float(i) * 2.6)
			var pulse: float = 0.90 + 0.18 * sin(local * TAU * 2.0 + float(i))
			n.scale = Vector3.ONE * pulse
			n.rotation.z = local * TAU * (0.20 + float(i) * 0.035)


	func _course_evt_colonnes(tr: Transform3D, local: float) -> void:
		for i in _course_columns.size():
			var n: MeshInstance3D = _course_columns[i]
			n.visible = true
			n.transform = tr
			var cote: float = -1.0 if i % 2 == 0 else 1.0
			var rang: float = float(i / 2)
			n.position += tr.basis.x * cote * 2.55
			n.position += tr.basis.z * (-rang * 2.7)
			var bal: float = sin(local * TAU + rang * 0.7) * 0.32
			n.position += tr.basis.x * bal


	func _course_evt_faille(tr: Transform3D, local: float) -> void:
		# Illusion d'un passage brise : panneaux decales qui forment une fente.
		for i in _course_panels.size():
			var n: MeshInstance3D = _course_panels[i]
			n.visible = true
			n.transform = tr
			var cote: float = -1.0 if i % 2 == 0 else 1.0
			var profondeur: float = float(i) * 1.8
			n.position += tr.basis.x * cote * (1.65 + float(i % 2) * 0.35)
			n.position += tr.basis.z * (-profondeur)
			n.rotation.z = cote * deg_to_rad(18.0 + float(i) * 3.0)
			n.scale = Vector3(0.42, 0.72, 1.0)


class Layer40:
	## v51 : ordonnancement optimise des couches decoratives Quest.
	# v54 : références internes conservées après consolidation.
	var v38 = null
	var v39 = null
	## Mandala VR v40 : mise en scene dynamique.
	## Chaque evenement suit preparation -> tension -> climax -> relance.

	const PRE_RINGS: int = 4

	var app = null
	var v31 = null
	var v32 = null
	var v33 = null
	var v36 = null

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


class Layer41:
	## v51 : ordonnancement optimise des couches decoratives Quest.
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
