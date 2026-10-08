class_name V52VisualManager
extends Node
## Mandala VR v52 : consolidation visuelle.
##
## Regroupe les anciennes couches v43, v44, v45 et v46 dans un seul
## manager runtime :
## - profondeur / parallaxe ;
## - architecture vivante ;
## - grands moments ;
## - echelle / vertige.
##
## Les quatre logiques restent separees en modules internes afin de
## conserver le rendu valide, mais une seule boucle _process les orchestre.

var app = null
var v31 = null
var v32 = null
var v33 = null
var v36 = null
var v53_fx = null

var _installe: bool = false
var _death_prev_active: bool = false
var _course_prev_active: bool = false
var _slow_flip: bool = false

var _layer43 = null
var _layer44 = null
var _layer45 = null
var _layer46 = null


func _ready() -> void:
	app = get_parent()
	v31 = app.get_node_or_null("V31Manager")
	v32 = app.get_node_or_null("V32Manager")
	v33 = app.get_node_or_null("V33Manager")
	v36 = app.get_node_or_null("V36Manager")
	v53_fx = app.get_node_or_null("V53RideFXManager")
	process_priority = 340


func _process(_dt: float) -> void:
	if app == null:
		return

	if not _installe:
		var ready_ok: bool = (
			v31 != null and bool(v31.get("_installe"))
			and v32 != null and bool(v32.get("_installe"))
			and v33 != null and bool(v33.get("_installe"))
			and v36 != null and bool(v36.get("_installe"))
			and v53_fx != null and bool(v53_fx.get("_installe"))
		)
		if ready_ok:
			_installer()
		return

	var death_active: bool = bool(v32.get("_mort"))
	var course_active: bool = bool(v33.get("_actif"))
	_slow_flip = not _slow_flip

	# Les couches lointaines v43/v46 restent a demi-cadence.
	# Les mouvements proches v44/v45 restent a pleine cadence.
	if death_active or _death_prev_active:
		var transition_death: bool = death_active != _death_prev_active

		if transition_death or _slow_flip:
			_layer43._maj_death_depth()

		_layer44._maj_death_motion()
		_layer45._maj_death_macro()

		if transition_death or _slow_flip:
			_layer46._maj_death_scale()

	if course_active or _course_prev_active:
		var transition_course: bool = course_active != _course_prev_active

		if transition_course or _slow_flip:
			_layer43._maj_course_depth()

		_layer44._maj_course_motion()
		_layer45._maj_course_macro()

		if transition_course or _slow_flip:
			_layer46._maj_course_scale()

	_death_prev_active = death_active
	_course_prev_active = course_active


func _installer() -> void:
	_layer43 = Layer43.new()
	_layer43.app = app
	_layer43.v31 = v31
	_layer43.v32 = v32
	_layer43.v33 = v33
	_layer43.v36 = v36
	_layer43._installer()

	_layer44 = Layer44.new()
	_layer44.app = app
	_layer44.v31 = v31
	_layer44.v32 = v32
	_layer44.v33 = v33
	_layer44.v36 = v36
	_layer44._installer()

	_layer45 = Layer45.new()
	_layer45.app = app
	_layer45.v31 = v31
	_layer45.v32 = v32
	_layer45.v33 = v33
	_layer45.v36 = v36
	_layer45._installer()

	_layer46 = Layer46.new()
	_layer46.app = app
	_layer46.v31 = v31
	_layer46.v32 = v32
	_layer46.v33 = v33
	_layer46.v36 = v36
	_layer46._installer()

	_installe = true


class Layer43:
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

	var _installe: bool = false

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


class Layer44:
	## v51 : ordonnancement optimise des couches decoratives Quest.
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


class Layer45:
	## v51 : ordonnancement optimise des couches decoratives Quest.
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


class Layer46:
	## v51 : ordonnancement optimise des couches decoratives Quest.
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
