class_name V56ObservatoireManager
extends Node
## Mandala VR v56 : Observatoire.
##
## Deux experiences accessibles depuis l'Accueil :
## - Grand Musee : galerie monumentale de grandes toiles mandala.
## - Galaxie Mandala : plusieurs centaines de planetes a explorer librement.
##
## Les scenes sont majoritairement statiques et instanciees avec MultiMesh
## afin de rester raisonnables sur Quest 3. Le manager dort hors Observatoire.

const MODE_AUCUN: int = 0
const MODE_MUSEE: int = 1
const MODE_GALAXIE: int = 2

const MUSEUM_PAINTINGS: int = 24
const GALAXY_PLANETS: int = 288
const GALAXY_RINGS: int = 96
const GALAXY_STARS: int = 720
const HERO_PLANETS: int = 12

var app = null
var v8 = null
var v26 = null
var v29 = null
var v31 = null
var v32 = null
var v33 = null
var v47 = null

var _installe: bool = false
var _active: bool = false
var _mode: int = MODE_AUCUN
var _snapshot: Dictionary = {}

var _museum_root: Node3D = null
var _museum_spinners: Array = []
var _galaxy_root: Node3D = null
var _hero_roots: Array = []

var _status_label: Label = null

var _museum_frame_mat: StandardMaterial3D = null
var _museum_wall_mat: StandardMaterial3D = null
var _museum_floor_mat: StandardMaterial3D = null
var _museum_art_mats: Array = []

var _planet_mm: MultiMesh = null
var _planet_node: MultiMeshInstance3D = null
var _ring_mm: MultiMesh = null
var _ring_node: MultiMeshInstance3D = null
var _star_mm: MultiMesh = null
var _star_node: MultiMeshInstance3D = null
var _planet_positions: Array = []
var _planet_sizes: Array = []
var _planet_colors: Array = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	app = get_parent()
	v8 = app.get_node_or_null("V8Manager")
	v26 = app.get_node_or_null("V26Manager")
	v29 = app.get_node_or_null("V29Manager")
	v31 = app.get_node_or_null("V31Manager")
	v32 = app.get_node_or_null("V32Manager")
	v33 = app.get_node_or_null("V33Manager")
	v47 = app.get_node_or_null("V47Manager")
	process_priority = 420
	_rng.seed = 5602026


func _process(dt: float) -> void:
	if app == null:
		return

	if not _installe:
		var pret: bool = (
			app.panneau != null
			and app.camera != null
			and app.origine != null
			and v26 != null and v26.get("_installe") == true
			and v32 != null and v32.get("_installe") == true
		)
		if pret:
			_installer()
		return

	if not _active:
		return

	# Rayon de creation masque pendant l'exploration, mais disponible
	# automatiquement lorsque le menu est ouvert.
	var ray_v: Variant = app.get("_rayon")
	var cursor_v: Variant = app.get("_curseur")
	if app.panneau.visible:
		if ray_v is Node3D:
			(ray_v as Node3D).visible = bool(_snapshot.get("ray_visible", true))
	else:
		if ray_v is Node3D:
			(ray_v as Node3D).visible = false
		if cursor_v is Node3D:
			(cursor_v as Node3D).visible = false

	if _mode == MODE_MUSEE:
		_maintenir_musee()
		for i in _museum_spinners.size():
			var n: Node3D = _museum_spinners[i]
			n.rotation.x += dt * (0.08 + float(i % 3) * 0.025)
			n.rotation.z += dt * (0.12 + float(i % 4) * 0.020)

	elif _mode == MODE_GALAXIE:
		for i in _hero_roots.size():
			var h: Node3D = _hero_roots[i]
			h.rotation.y += dt * (0.07 + float(i % 5) * 0.012)
			h.rotation.z += dt * (0.04 + float(i % 4) * 0.010)


# =====================================================================
# Installation et interface

func _installer() -> void:
	_installe = true
	_build_museum()
	_build_galaxy()
	_build_ui()
	_add_home_card()


func _build_ui() -> void:
	var p: VBoxContainer = app.panneau._page("Observatoire")

	app.panneau._titre(p, "Observatoire")
	app.panneau._note(
		p,
		"Deux lieux a explorer librement. Le Musee est une grande galerie de toiles mandala. La Galaxie contient des centaines de planetes-spheres mandala reparties dans l'espace.")

	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	p.add_child(grid)

	v32.call(
		"_carte",
		grid,
		"GRAND MUSEE\nGaleries monumentales et grandes toiles",
		Color(0.52, 0.38, 0.18),
		Callable(self, "demarrer_musee"))

	v32.call(
		"_carte",
		grid,
		"GALAXIE MANDALA\n288 planetes a visiter librement",
		Color(0.18, 0.34, 0.70),
		Callable(self, "demarrer_galaxie"))

	var actions: HBoxContainer = app.panneau._rangee(p)
	app.panneau._bouton(actions, "Quitter l'Observatoire", arreter)
	if v32.has_method("_aller_accueil"):
		app.panneau._bouton(actions, "Retour Accueil", Callable(self, "_retour_accueil"))

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 22)
	p.add_child(_status_label)
	_update_status()


func _add_home_card() -> void:
	var page_v: Variant = v32.get("_page_accueil")
	if not (page_v is VBoxContainer):
		return

	var page: VBoxContainer = page_v
	var grid: GridContainer = null
	for c in page.get_children():
		if c is GridContainer:
			grid = c
			break
	if grid == null:
		return

	v32.call(
		"_carte",
		grid,
		"OBSERVATOIRE\nGrand musee et galaxie mandala",
		Color(0.30, 0.30, 0.66),
		func() -> void: v32.call("_aller_page", "Observatoire"))


func _retour_accueil() -> void:
	arreter()
	if v32.has_method("_aller_accueil"):
		v32.call("_aller_accueil")


func _update_status() -> void:
	if _status_label == null:
		return

	var txt: String = "Pret"
	if _mode == MODE_MUSEE:
		txt = "Grand Musee actif"
	elif _mode == MODE_GALAXIE:
		txt = "Galaxie Mandala active"

	_status_label.text = txt


# =====================================================================
# Materiaux

func _mat(c: Color, emission: float = 0.0, additive: bool = false) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	if additive:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = Color(c.r, c.g, c.b, 1.0)
		m.emission_energy_multiplier = emission
	return m


func _instance_color_mat(alpha: float = 1.0) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color(1.0, 1.0, 1.0, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


# =====================================================================
# Grand Musee

func _build_museum() -> void:
	_museum_root = Node3D.new()
	_museum_root.name = "ObservatoireGrandMusee"
	_museum_root.visible = false
	app.add_child(_museum_root)

	_museum_wall_mat = _mat(Color(0.075, 0.078, 0.105, 1.0))
	_museum_floor_mat = _mat(Color(0.10, 0.105, 0.135, 1.0))
	_museum_frame_mat = _mat(Color(0.68, 0.52, 0.22, 1.0), 0.55)

	_museum_art_mats = [
		_mat(Color(0.18, 0.70, 1.0, 0.92), 2.2, true),
		_mat(Color(0.82, 0.22, 1.0, 0.92), 2.2, true),
		_mat(Color(1.0, 0.46, 0.18, 0.92), 2.2, true),
		_mat(Color(0.18, 1.0, 0.62, 0.92), 2.2, true),
		_mat(Color(1.0, 0.22, 0.54, 0.92), 2.2, true),
		_mat(Color(0.52, 0.40, 1.0, 0.92), 2.2, true),
	]

	# Sol monumental.
	var floor: MeshInstance3D = MeshInstance3D.new()
	var floor_mesh: BoxMesh = BoxMesh.new()
	floor_mesh.size = Vector3(27.0, 0.18, 72.0)
	floor.mesh = floor_mesh
	floor.material_override = _museum_floor_mat
	floor.position = Vector3(0.0, -0.09, -30.0)
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_museum_root.add_child(floor)

	# Murs et plafond.
	_add_museum_box(Vector3(-13.4, 4.0, -30.0), Vector3(0.22, 8.0, 72.0), _museum_wall_mat)
	_add_museum_box(Vector3(13.4, 4.0, -30.0), Vector3(0.22, 8.0, 72.0), _museum_wall_mat)
	_add_museum_box(Vector3(0.0, 8.0, -30.0), Vector3(27.0, 0.18, 72.0), _museum_wall_mat)
	_add_museum_box(Vector3(0.0, 4.0, -65.8), Vector3(27.0, 8.0, 0.22), _museum_wall_mat)

	# Ligne centrale lumineuse au sol.
	var line: MeshInstance3D = MeshInstance3D.new()
	var line_mesh: BoxMesh = BoxMesh.new()
	line_mesh.size = Vector3(0.08, 0.02, 68.0)
	line.mesh = line_mesh
	line.material_override = _museum_art_mats[0]
	line.position = Vector3(0.0, 0.02, -30.0)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_museum_root.add_child(line)

	# Colonnes.
	var column_mesh: BoxMesh = BoxMesh.new()
	column_mesh.size = Vector3(0.42, 7.4, 0.42)
	column_mesh.material = _museum_frame_mat

	var columns: MultiMesh = MultiMesh.new()
	columns.transform_format = MultiMesh.TRANSFORM_3D
	columns.instance_count = 24
	columns.mesh = column_mesh

	var columns_node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	columns_node.name = "MuseumColumns"
	columns_node.multimesh = columns
	columns_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_museum_root.add_child(columns_node)

	for i in 12:
		var z: float = -4.0 - float(i) * 5.2
		columns.set_instance_transform(i * 2, Transform3D(Basis(), Vector3(-11.7, 3.7, z)))
		columns.set_instance_transform(i * 2 + 1, Transform3D(Basis(), Vector3(11.7, 3.7, z)))

	# Toiles : 12 de chaque cote.
	for i in MUSEUM_PAINTINGS:
		var side: float = -1.0 if i % 2 == 0 else 1.0
		var row: int = i / 2
		var z: float = -3.0 - float(row) * 5.25
		_add_painting(side, row, z)

	# Quelques sculptures centrales donnent de la profondeur au lieu.
	for i in 6:
		var sculpture: Node3D = Node3D.new()
		sculpture.name = "Sculpture" + str(i)
		sculpture.position = Vector3(
			0.0,
			2.0 + float(i % 2) * 0.55,
			-8.0 - float(i) * 9.0)
		_museum_root.add_child(sculpture)

		var torus_a: MeshInstance3D = MeshInstance3D.new()
		var tm_a: TorusMesh = TorusMesh.new()
		tm_a.inner_radius = 1.05
		tm_a.outer_radius = 1.13
		tm_a.rings = 32
		tm_a.ring_segments = 7
		torus_a.mesh = tm_a
		torus_a.material_override = _museum_art_mats[(i + 1) % _museum_art_mats.size()]
		torus_a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sculpture.add_child(torus_a)

		var torus_b: MeshInstance3D = MeshInstance3D.new()
		var tm_b: TorusMesh = TorusMesh.new()
		tm_b.inner_radius = 0.62
		tm_b.outer_radius = 0.70
		tm_b.rings = 28
		tm_b.ring_segments = 7
		torus_b.mesh = tm_b
		torus_b.rotation.x = PI * 0.5
		torus_b.material_override = _museum_art_mats[(i + 3) % _museum_art_mats.size()]
		torus_b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sculpture.add_child(torus_b)

		_museum_spinners.append(sculpture)


func _add_museum_box(pos: Vector3, size: Vector3, mat: Material) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_museum_root.add_child(mi)


func _add_painting(side: float, index: int, z: float) -> void:
	var root: Node3D = Node3D.new()
	root.name = "GrandeToile" + str(index) + ("G" if side < 0.0 else "D")
	root.position = Vector3(side * 13.18, 2.65, z)
	_museum_root.add_child(root)

	var frame: MeshInstance3D = MeshInstance3D.new()
	var fm: BoxMesh = BoxMesh.new()
	fm.size = Vector3(0.18, 4.05, 4.95)
	frame.mesh = fm
	frame.material_override = _museum_frame_mat
	frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(frame)

	var canvas: MeshInstance3D = MeshInstance3D.new()
	var cm: BoxMesh = BoxMesh.new()
	cm.size = Vector3(0.22, 3.55, 4.45)
	canvas.mesh = cm
	canvas.material_override = _mat(
		Color(
			0.035 + float(index % 3) * 0.012,
			0.036,
			0.055 + float(index % 4) * 0.010,
			1.0))
	canvas.position.x = -side * 0.13
	canvas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(canvas)

	# Mandala mural : trois anneaux imbriques.
	for k in 3:
		var ring: MeshInstance3D = MeshInstance3D.new()
		var tm: TorusMesh = TorusMesh.new()
		tm.inner_radius = 0.54
		tm.outer_radius = 0.62
		tm.rings = 28
		tm.ring_segments = 7
		ring.mesh = tm
		ring.material_override = _museum_art_mats[(index + k) % _museum_art_mats.size()]
		ring.rotation.z = PI * 0.5
		ring.position.x = -side * (0.28 + float(k) * 0.012)
		var scale_v: float = 1.15 + float(k) * 0.58
		ring.scale = Vector3.ONE * scale_v
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(ring)

	var core: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.20
	sm.height = 0.40
	sm.radial_segments = 12
	sm.rings = 6
	core.mesh = sm
	core.material_override = _museum_art_mats[(index + 4) % _museum_art_mats.size()]
	core.position.x = -side * 0.33
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(core)


func _maintenir_musee() -> void:
	# Dans le Musee on marche : pas de vol vertical et pas de traversée
	# des murs avec les sticks.
	var p: Vector3 = app.origine.global_position
	p.x = clampf(p.x, -12.2, 12.2)
	p.y = 0.0
	p.z = clampf(p.z, -64.0, 3.0)
	app.origine.global_position = p


# =====================================================================
# Galaxie Mandala

func _build_galaxy() -> void:
	_galaxy_root = Node3D.new()
	_galaxy_root.name = "ObservatoireGalaxieMandala"
	_galaxy_root.visible = false
	app.add_child(_galaxy_root)

	var bg: MeshInstance3D = MeshInstance3D.new()
	var bg_mesh: SphereMesh = SphereMesh.new()
	bg_mesh.radius = 150.0
	bg_mesh.height = 300.0
	bg_mesh.radial_segments = 32
	bg_mesh.rings = 16
	bg.mesh = bg_mesh
	var bg_mat: StandardMaterial3D = _mat(Color(0.004, 0.006, 0.018, 1.0))
	bg_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	bg.material_override = bg_mat
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_galaxy_root.add_child(bg)

	var palette: Array = [
		Color(0.20, 0.72, 1.0, 1.0),
		Color(0.70, 0.24, 1.0, 1.0),
		Color(1.0, 0.34, 0.64, 1.0),
		Color(0.18, 1.0, 0.70, 1.0),
		Color(1.0, 0.68, 0.18, 1.0),
		Color(0.38, 0.46, 1.0, 1.0),
		Color(1.0, 0.26, 0.20, 1.0),
		Color(0.82, 0.90, 1.0, 1.0),
	]

	# Planetes.
	var planet_mesh: SphereMesh = SphereMesh.new()
	planet_mesh.radius = 0.50
	planet_mesh.height = 1.0
	planet_mesh.radial_segments = 14
	planet_mesh.rings = 7
	planet_mesh.material = _instance_color_mat()

	_planet_mm = MultiMesh.new()
	_planet_mm.transform_format = MultiMesh.TRANSFORM_3D
	_planet_mm.use_colors = true
	_planet_mm.instance_count = GALAXY_PLANETS
	_planet_mm.mesh = planet_mesh

	_planet_node = MultiMeshInstance3D.new()
	_planet_node.name = "GalaxyPlanets"
	_planet_node.multimesh = _planet_mm
	_planet_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_planet_node.extra_cull_margin = 180.0
	_galaxy_root.add_child(_planet_node)

	for i in GALAXY_PLANETS:
		var yy: float = _rng.randf_range(-0.82, 0.82)
		var theta: float = _rng.randf_range(0.0, TAU)
		var rr: float = sqrt(maxf(0.0, 1.0 - yy * yy))
		var dir: Vector3 = Vector3(cos(theta) * rr, yy, sin(theta) * rr)

		var radius: float = 9.0 + pow(_rng.randf(), 0.74) * 76.0
		var pos: Vector3 = dir * radius
		pos.y *= 0.78

		var size_v: float = _rng.randf_range(0.42, 1.45)
		if i % 24 == 0:
			size_v = _rng.randf_range(1.8, 2.8)

		var color_id: int = _rng.randi_range(0, palette.size() - 1)
		var c: Color = palette[color_id]

		_planet_positions.append(pos)
		_planet_sizes.append(size_v)
		_planet_colors.append(c)

		var b: Basis = Basis()
		b = b.scaled(Vector3.ONE * size_v)
		_planet_mm.set_instance_transform(i, Transform3D(b, pos))
		_planet_mm.set_instance_color(i, c)

	# Anneaux mandala sur un tiers des mondes.
	var ring_mesh: TorusMesh = TorusMesh.new()
	ring_mesh.inner_radius = 0.66
	ring_mesh.outer_radius = 0.74
	ring_mesh.rings = 20
	ring_mesh.ring_segments = 6
	ring_mesh.material = _instance_color_mat(0.76)

	_ring_mm = MultiMesh.new()
	_ring_mm.transform_format = MultiMesh.TRANSFORM_3D
	_ring_mm.use_colors = true
	_ring_mm.instance_count = GALAXY_RINGS
	_ring_mm.mesh = ring_mesh

	_ring_node = MultiMeshInstance3D.new()
	_ring_node.name = "GalaxyMandalaRings"
	_ring_node.multimesh = _ring_mm
	_ring_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ring_node.extra_cull_margin = 180.0
	_galaxy_root.add_child(_ring_node)

	for i in GALAXY_RINGS:
		var planet_i: int = (i * 3) % GALAXY_PLANETS
		var pos: Vector3 = _planet_positions[planet_i]
		var size_v: float = float(_planet_sizes[planet_i])
		var c: Color = _planet_colors[planet_i]

		var axis: Vector3 = Vector3(
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-1.0, 1.0)).normalized()
		if axis.length() < 0.1:
			axis = Vector3.UP

		var rot: Basis = Basis(axis, _rng.randf_range(0.0, TAU))
		rot = rot.scaled(Vector3.ONE * (size_v * 1.55))
		_ring_mm.set_instance_transform(i, Transform3D(rot, pos))
		_ring_mm.set_instance_color(i, c.lightened(0.12))

	# Etoiles de fond.
	var star_mesh: BoxMesh = BoxMesh.new()
	star_mesh.size = Vector3(0.055, 0.055, 0.055)
	star_mesh.material = _instance_color_mat()

	_star_mm = MultiMesh.new()
	_star_mm.transform_format = MultiMesh.TRANSFORM_3D
	_star_mm.use_colors = true
	_star_mm.instance_count = GALAXY_STARS
	_star_mm.mesh = star_mesh

	_star_node = MultiMeshInstance3D.new()
	_star_node.name = "GalaxyStars"
	_star_node.multimesh = _star_mm
	_star_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_star_node.extra_cull_margin = 220.0
	_galaxy_root.add_child(_star_node)

	for i in GALAXY_STARS:
		var yy: float = _rng.randf_range(-1.0, 1.0)
		var theta: float = _rng.randf_range(0.0, TAU)
		var rr: float = sqrt(maxf(0.0, 1.0 - yy * yy))
		var dir: Vector3 = Vector3(cos(theta) * rr, yy, sin(theta) * rr)
		var radius: float = _rng.randf_range(55.0, 142.0)
		var pos: Vector3 = dir * radius
		var sc: float = _rng.randf_range(0.55, 1.85)
		var b: Basis = Basis().scaled(Vector3.ONE * sc)
		_star_mm.set_instance_transform(i, Transform3D(b, pos))
		var c: Color = Color(0.70, 0.80, 1.0, 1.0)
		if i % 7 == 0:
			c = Color(1.0, 0.50, 0.86, 1.0)
		elif i % 5 == 0:
			c = Color(0.54, 0.90, 1.0, 1.0)
		_star_mm.set_instance_color(i, c)

	# Douze mondes majeurs avec doubles anneaux animes.
	for i in HERO_PLANETS:
		var planet_i: int = i * 24
		var hero: Node3D = Node3D.new()
		hero.name = "MondeMajeur" + str(i + 1)
		hero.position = _planet_positions[planet_i]
		_galaxy_root.add_child(hero)

		for k in 2:
			var ring: MeshInstance3D = MeshInstance3D.new()
			var tm: TorusMesh = TorusMesh.new()
			tm.inner_radius = 0.82 + float(k) * 0.35
			tm.outer_radius = 0.90 + float(k) * 0.35
			tm.rings = 28
			tm.ring_segments = 7
			ring.mesh = tm
			ring.material_override = _mat(
				(_planet_colors[planet_i] as Color).lightened(0.18 + float(k) * 0.08),
				2.4,
				true)
			ring.rotation.x = PI * 0.5 if k == 0 else PI * 0.18
			ring.scale = Vector3.ONE * (float(_planet_sizes[planet_i]) * 1.45)
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			hero.add_child(ring)

		_hero_roots.append(hero)


# =====================================================================
# Activation / restauration

func demarrer_musee() -> void:
	_start_mode(MODE_MUSEE)


func demarrer_galaxie() -> void:
	_start_mode(MODE_GALAXIE)


func _stop_other_modes() -> void:
	if v32 != null and v32.has_method("arreter_mort"):
		v32.call("arreter_mort")

	if v31 != null and v31.get("_actif") == true and v31.has_method("arreter"):
		v31.call("arreter")

	if v33 != null and v33.get("_actif") == true and v33.has_method("arreter"):
		v33.call("arreter")

	if v47 != null and v47.get("_actif") == true and v47.has_method("arreter"):
		v47.call("arreter")

	app.diff_stop()


func _capture_state() -> void:
	var paysage: Node3D = null
	var paysage_visible: bool = false
	if v29 != null:
		var pv: Variant = v29.get("_racine")
		if pv is Node3D:
			paysage = pv
			paysage_visible = paysage.visible

	var passthrough: bool = false
	if v8 != null:
		passthrough = v8.get("_passthrough") == true

	var hud_v: Variant = app.get("_hud")
	var msg_v: Variant = app.get("_msg_label")
	var help_v: Variant = app.get("_aide")
	var ray_v: Variant = app.get("_rayon")

	_snapshot = {
		"origin": app.origine.global_transform,
		"sc_visible": app.sc.visible,
		"sc_transform": app.sc.global_transform,
		"sol_visible": app.sol.visible,
		"paysage": paysage,
		"paysage_visible": paysage_visible,
		"passthrough": passthrough,
		"hud_visible": (hud_v as Node3D).visible if hud_v is Node3D else true,
		"msg_visible": (msg_v as Node3D).visible if msg_v is Node3D else true,
		"help_visible": (help_v as Node3D).visible if help_v is Node3D else true,
		"ray_visible": (ray_v as Node3D).visible if ray_v is Node3D else true,
	}


func _start_mode(mode: int) -> void:
	_stop_other_modes()

	if not _active:
		_capture_state()

	_active = true
	_mode = mode

	if v8 != null and v8.get("_passthrough") == true and v8.has_method("_set_passthrough"):
		v8.call("_set_passthrough", false)

	app.origine.global_transform = Transform3D(Basis(), Vector3.ZERO)

	app.sc.visible = false
	app.sc.global_position = Vector3(0.0, -1000.0, 0.0)
	app.sol.visible = false

	var paysage_v: Variant = _snapshot.get("paysage", null)
	if paysage_v is Node3D and is_instance_valid(paysage_v):
		(paysage_v as Node3D).visible = false

	var hud_v: Variant = app.get("_hud")
	var msg_v: Variant = app.get("_msg_label")
	var help_v: Variant = app.get("_aide")
	if hud_v is Node3D:
		(hud_v as Node3D).visible = false
	if msg_v is Node3D:
		(msg_v as Node3D).visible = false
	if help_v is Node3D:
		(help_v as Node3D).visible = false

	_museum_root.visible = mode == MODE_MUSEE
	_galaxy_root.visible = mode == MODE_GALAXIE

	if app.panneau.visible:
		app.basculer_panneau()

	_update_status()


func arreter() -> void:
	if not _active:
		return

	_active = false
	_mode = MODE_AUCUN
	_museum_root.visible = false
	_galaxy_root.visible = false

	if not _snapshot.is_empty():
		app.origine.global_transform = _snapshot.get("origin", app.origine.global_transform)
		app.sc.global_transform = _snapshot.get("sc_transform", app.sc.global_transform)
		app.sc.visible = bool(_snapshot.get("sc_visible", true))
		app.sol.visible = bool(_snapshot.get("sol_visible", true))

		var paysage_v: Variant = _snapshot.get("paysage", null)
		if paysage_v is Node3D and is_instance_valid(paysage_v):
			(paysage_v as Node3D).visible = bool(_snapshot.get("paysage_visible", true))

		if (
			bool(_snapshot.get("passthrough", false))
			and v8 != null
			and v8.has_method("_set_passthrough")
		):
			v8.call("_set_passthrough", true)

		var hud_v: Variant = app.get("_hud")
		var msg_v: Variant = app.get("_msg_label")
		var help_v: Variant = app.get("_aide")
		var ray_v: Variant = app.get("_rayon")

		if hud_v is Node3D:
			(hud_v as Node3D).visible = bool(_snapshot.get("hud_visible", true))
		if msg_v is Node3D:
			(msg_v as Node3D).visible = bool(_snapshot.get("msg_visible", true))
		if help_v is Node3D:
			(help_v as Node3D).visible = bool(_snapshot.get("help_visible", false))
		if ray_v is Node3D:
			(ray_v as Node3D).visible = bool(_snapshot.get("ray_visible", true))

	_snapshot = {}
	_update_status()
