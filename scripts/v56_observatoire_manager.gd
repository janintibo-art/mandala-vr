class_name V56ObservatoireManager
extends Node
## Mandala VR v56/v57/v58/v59 : Observatoire.
##
## Deux experiences accessibles depuis l'Accueil :
## - Grand Musee : galerie monumentale de grandes toiles mandala.
## - Galaxie Mandala : plusieurs centaines de planetes a explorer librement.
##
## v59 :
## - chemins lumineux dans les 6 mondes ;
## - 3 balises mandala interactives par monde ;
## - portail vers le monde suivant une fois les balises activees ;
## - objets flottants animes uniquement dans le monde courant ;
## - interactions par visee + gachette droite.
##
## v58 :
## - 6 mondes visitables au lieu de 3 ;
## - ciel, horizon et relief propres a chaque monde ;
## - architectures et silhouettes tres differentes ;
## - toujours un seul manager Observatoire.
##
## v57 :
## - les toiles du Musee reprennent noms et palettes des creations sauvegardees ;
## - les 3 premiers mondes majeurs deviennent visitables ;
## - entree en visant le monde puis gachette droite ;
## - retour a la position exacte dans la galaxie.
##
## Les scenes sont majoritairement statiques et instanciees avec MultiMesh
## afin de rester raisonnables sur Quest 3. Le manager dort hors Observatoire.

const MODE_AUCUN: int = 0
const MODE_MUSEE: int = 1
const MODE_GALAXIE: int = 2
const MODE_PLANETE: int = 3

const MUSEUM_PAINTINGS: int = 16
const GALAXY_PLANETS: int = 288
const GALAXY_RINGS: int = 96
const GALAXY_STARS: int = 720
const HERO_PLANETS: int = 12
const WORLD_NAMES: Array = [
	"Temple Solaire",
	"Cite Radiale",
	"Sanctuaire des Portails",
]
const VISITABLE_WORLDS: int = 3

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
var _museum_paintings: Array = []
var _museum_etat: Dictionary = {}
var _world_etats: Array = []
var _hero_etats: Array = []
var _t60: float = 0.0

var _galaxy_root: Node3D = null
var _hero_roots: Array = []
var _galaxy_trigger_was: bool = false

var _planet_world_root: Node3D = null
var _planet_worlds: Array = []
var _planet_index: int = -1
var _planet_return_origin: Transform3D = Transform3D()

var _world_beacons: Array = []
var _world_beacon_state: Array = []
var _world_portals: Array = []
var _world_floaters: Array = []
var _world_interact_trigger_was: bool = false

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
			(ray_v as Node3D).visible = (_snapshot.get("ray_visible", true) == true)
	else:
		if ray_v is Node3D:
			(ray_v as Node3D).visible = false
		if cursor_v is Node3D:
			(cursor_v as Node3D).visible = false

	var trigger_now: bool = app.main_d.get_float("trigger") > 0.58
	var trigger_edge: bool = trigger_now and not _galaxy_trigger_was
	_galaxy_trigger_was = trigger_now

	if _mode == MODE_MUSEE:
		_maintenir_musee()
		_t60 += dt
		Observatoire60.animer(_museum_etat, dt, _t60)

	elif _mode == MODE_GALAXIE:
		for i in _hero_roots.size():
			var h: Node3D = _hero_roots[i]
			h.rotation.y += dt * (0.07 + float(i % 5) * 0.012)
			h.rotation.z += dt * (0.04 + float(i % 4) * 0.010)
			if i < _hero_etats.size():
				Observatoire60.animer(_hero_etats[i], dt, _t60)
		_t60 += dt

		if trigger_edge and not app.panneau.visible:
			_try_visit_planet()

	elif _mode == MODE_PLANETE:
		_maintenir_planete()
		if _planet_index >= 0 and _planet_index < _planet_worlds.size():
			var world: Node3D = _planet_worlds[_planet_index]
			_t60 += dt
			if _planet_index < _world_etats.size():
				Observatoire60.animer(_world_etats[_planet_index], dt, _t60)

			_update_world_floaters(_planet_index, dt)
			_update_world_portal(_planet_index, dt)

		var interact_now: bool = app.main_d.get_float("trigger") > 0.58
		var interact_edge: bool = interact_now and not _world_interact_trigger_was
		_world_interact_trigger_was = interact_now
		if interact_edge and not app.panneau.visible:
			_try_world_interaction()


# =====================================================================
# Installation et interface

func _installer() -> void:
	_installe = true
	_build_museum()
	_build_galaxy()
	_build_planet_worlds()
	_build_ui()
	_add_home_card()


func _build_ui() -> void:
	var p: VBoxContainer = app.panneau._page("Observatoire")

	app.panneau._titre(p, "Observatoire")
	app.panneau._note(
		p,
		"Deux lieux a explorer librement. Le Musee expose aussi tes creations sauvegardees. Dans la Galaxie, les six premiers mondes majeurs sont visitables : vise leur grand anneau lumineux et appuie sur la gachette droite.")

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
	app.panneau._bouton(actions, "Retour Galaxie", retourner_galaxie)
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


func _lire(n: Node, nom: String, defaut: bool) -> bool:
	if n == null:
		return defaut
	var v: Variant = n.get(nom)
	if v == null:
		return defaut
	return v == true


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
		txt = "Galaxie Mandala active - vise un grand anneau et tire pour visiter"
	elif _mode == MODE_PLANETE:
		if _planet_index >= 0 and _planet_index < WORLD_NAMES.size():
			txt = "Monde : " + str(WORLD_NAMES[_planet_index]) + " - active 3 balises puis vise le portail"
		else:
			txt = "Monde Mandala"

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

	# v60 : grand musee compose par Observatoire60 (arches, colonnade, toiles-mandalas).
	_museum_etat = Observatoire60.musee(_museum_root)
	_museum_paintings = _museum_etat["toiles"]
	_museum_spinners = []








func _refresh_museum_saved_art() -> void:
	var oeuvres: Array = Stockage.lister()

	for i in _museum_paintings.size():
		var p: Dictionary = _museum_paintings[i]
		var plaque: Label3D = p["label"]

		if i >= oeuvres.size():
			plaque.text = "Collection Mandala %02d" % (i + 1)
			continue

		var meta: Dictionary = oeuvres[i]
		var id_oeuvre: String = str(meta.get("id", ""))
		var brut: String = Stockage.lire(id_oeuvre)
		var oeuvre: Dictionary = Oeuvre.decoder(brut)
		if oeuvre.is_empty():
			plaque.text = str(meta.get("nom", "Sans titre")).left(40)
			continue

		plaque.text = str(oeuvre.get("nom", "Sans titre")).left(40)

		var couleurs: Array = []
		var traits_v: Variant = oeuvre.get("traits", [])
		if traits_v is Array:
			for trait_v in (traits_v as Array):
				if not (trait_v is TraitDessin):
					continue
				var td: TraitDessin = trait_v
				var pi: int = td.reglages.palette
				if pi < 0 or pi >= Tables.palettes.size():
					continue
				var pal: Dictionary = Tables.palettes[pi]
				var cols_v: Variant = pal.get("cols", PackedColorArray())
				if cols_v is PackedColorArray:
					var cols: PackedColorArray = cols_v
					for c in cols:
						couleurs.append(c)
						if couleurs.size() >= 6:
							break
				if couleurs.size() >= 6:
					break

		if couleurs.is_empty():
			continue
		while couleurs.size() < 3:
			couleurs.append((couleurs[couleurs.size() - 1] as Color).lightened(0.15))

		# v60 : la toile affiche un vrai mandala complexe dans les couleurs de l'oeuvre.
		Observatoire60.changer_toile(_museum_etat, i, hash(id_oeuvre) & 0xffff, couleurs)


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

	# Douze mondes majeurs : planetes mandala.
	var palette_hero: Array = [
		Color(0.20, 0.72, 1.0), Color(0.70, 0.24, 1.0), Color(1.0, 0.34, 0.64), Color(0.18, 1.0, 0.70),
		Color(1.0, 0.68, 0.18), Color(0.38, 0.46, 1.0), Color(1.0, 0.26, 0.20), Color(0.82, 0.90, 1.0)]
	for i in HERO_PLANETS:
		var planet_i: int = i * 24
		var hero: Node3D = Node3D.new()
		hero.name = "MondeMajeur" + str(i + 1)
		hero.position = _planet_positions[planet_i]
		_galaxy_root.add_child(hero)

		if i < VISITABLE_WORLDS:
			var visit_ring: MeshInstance3D = MeshInstance3D.new()
			visit_ring.name = "AnneauVisitable"
			var vtm: TorusMesh = TorusMesh.new()
			vtm.inner_radius = 1.55
			vtm.outer_radius = 1.67
			vtm.rings = 36
			vtm.ring_segments = 8
			visit_ring.mesh = vtm
			visit_ring.material_override = _mat(Color(1.0, 0.86, 0.32, 0.88), 3.0, true)
			visit_ring.rotation.x = PI * 0.5
			visit_ring.scale = Vector3.ONE * maxf(1.0, float(_planet_sizes[planet_i]) * 1.55)
			visit_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			hero.add_child(visit_ring)

		# v60 : vraie planete mandala (surface shader, atmosphere, couronne de mandala).
		var col1: Color = _planet_colors[planet_i]
		var col2: Color = palette_hero[(i * 3 + 2) % palette_hero.size()]
		var col3: Color = col1.lerp(col2, 0.5).lightened(0.25)
		var taille: float = float(_planet_sizes[planet_i])
		var holder: Node3D = Node3D.new()
		holder.name = "PlaneteMandala"
		holder.scale = Vector3.ONE * taille
		hero.add_child(holder)
		var he: Dictionary = Observatoire60.planete(holder, 0.56, col1, col2, col3, 40 + i * 9, 28.0 + float(i % 4) * 14.0)
		_hero_etats.append(he)

		_hero_roots.append(hero)


# =====================================================================
# Mondes visitables

func _build_planet_worlds() -> void:
	_planet_world_root = Node3D.new()
	_planet_world_root.name = "ObservatoireMondesVisitables"
	_planet_world_root.visible = false
	app.add_child(_planet_world_root)

	# v60 : trois mondes premium, chacun avec une architecture mandala forte.
	_build_one_world(
		0,
		"TempleSolaire",
		Color(1.0, 0.62, 0.18),
		Color(0.32, 0.40, 1.0))
	_build_one_world(
		1,
		"CiteRadiale",
		Color(0.20, 0.82, 1.0),
		Color(0.95, 0.25, 0.70))
	_build_one_world(
		2,
		"SanctuairePortails",
		Color(0.16, 1.0, 0.66),
		Color(0.72, 0.26, 1.0))


func _build_one_world(index: int, nom: String, c1: Color, c2: Color) -> void:
	var world: Node3D = Node3D.new()
	world.name = nom
	world.visible = false
	_planet_world_root.add_child(world)
	_planet_worlds.append(world)

	var floor: MeshInstance3D = MeshInstance3D.new()
	var floor_mesh: CylinderMesh = CylinderMesh.new()
	floor_mesh.top_radius = 18.0
	floor_mesh.bottom_radius = 18.0
	floor_mesh.height = 0.28
	floor_mesh.radial_segments = 48
	floor.mesh = floor_mesh
	floor.material_override = _mat(c1.darkened(0.80))
	floor.position.y = -0.14
	floor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(floor)

	var etat: Dictionary = Observatoire60.nouvel_etat()
	_world_etats.append(etat)

	_add_world_sky(world, index, c1, c2)
	_add_world_interactives(world, index, c1, c2)

	if index == 0:
		Observatoire60.monde_temple(world, c1, c2, etat)
	elif index == 1:
		Observatoire60.monde_cite(world, c1, c2, etat)
	else:
		Observatoire60.monde_portails(world, c1, c2, etat)

	var portal: Node3D = _world_portals[index]
	Observatoire60.embellir_interactifs(
		world, etat,
		_world_beacons[index], portal, _world_floaters[index],
		c1, c2)


func _add_world_sky(
	world: Node3D,
	index: int,
	c1: Color,
	c2: Color
) -> void:
	var sky: MeshInstance3D = MeshInstance3D.new()
	sky.name = "CielMonde"
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 44.0
	sm.height = 88.0
	sm.radial_segments = 28
	sm.rings = 14
	sky.mesh = sm

	var mix: float = 0.22 + float(index % 3) * 0.10
	var sky_color: Color = c1.darkened(0.82).lerp(c2.darkened(0.76), mix)
	var mat: StandardMaterial3D = _mat(sky_color)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sky.material_override = mat
	sky.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(sky)


func _add_world_horizon(
	world: Node3D,
	index: int,
	c1: Color,
	c2: Color
) -> void:
	# Relief circulaire lointain autour de la zone jouable.
	var ridge_mesh: BoxMesh = BoxMesh.new()
	ridge_mesh.size = Vector3(1.8, 1.0, 0.75)
	ridge_mesh.material = _instance_color_mat()

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = 48
	mm.mesh = ridge_mesh

	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = "ReliefHorizon"
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(node)

	for i in 48:
		var a: float = TAU * float(i) / 48.0
		var wave: float = 1.0 + 0.35 * sin(float(i) * (0.78 + float(index) * 0.06))
		var radius: float = 23.0 + float(i % 4) * 0.7
		var h: float = (2.8 + float(i % 7) * 0.58) * wave
		var pos: Vector3 = Vector3(cos(a) * radius, h * 0.5 - 0.1, sin(a) * radius - 3.0)
		var b: Basis = Basis(Vector3.UP, -a)
		b = b.scaled(Vector3(1.0, h, 1.0))
		mm.set_instance_transform(i, Transform3D(b, pos))
		mm.set_instance_color(i, c1.darkened(0.25) if i % 2 == 0 else c2.darkened(0.30))


func _add_world_path(
	world: Node3D,
	index: int,
	c1: Color,
	c2: Color
) -> void:
	var path_mesh: BoxMesh = BoxMesh.new()
	path_mesh.size = Vector3(0.85, 0.06, 1.10)
	path_mesh.material = _instance_color_mat()

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = 18
	mm.mesh = path_mesh

	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = "CheminLumineux"
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(node)

	for i in 18:
		var z: float = 2.0 - float(i) * 1.25
		var x: float = sin(float(i) * 0.42 + float(index)) * 1.05
		var pos: Vector3 = Vector3(x, 0.05, z)
		var b: Basis = Basis(Vector3.UP, sin(float(i) * 0.24) * 0.12)
		mm.set_instance_transform(i, Transform3D(b, pos))
		var c: Color = c1.lightened(0.12) if i % 2 == 0 else c2.lightened(0.10)
		mm.set_instance_color(i, c)


func _add_world_interactives(
	world: Node3D,
	index: int,
	c1: Color,
	c2: Color
) -> void:
	var beacon_list: Array = []
	var beacon_state: Array = []

	var positions: Array = [
		Vector3(-5.8, 1.35, -4.0),
		Vector3(5.8, 1.35, -5.8),
		Vector3(0.0, 1.35, -12.8),
	]

	for i in 3:
		var beacon: Node3D = Node3D.new()
		beacon.name = "BaliseMandala%d" % (i + 1)
		beacon.position = positions[i]
		world.add_child(beacon)

		var sphere: MeshInstance3D = MeshInstance3D.new()
		sphere.name = "Coeur"
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.34
		sm.height = 0.68
		sm.radial_segments = 12
		sm.rings = 6
		sphere.mesh = sm
		sphere.material_override = _mat(c1.darkened(0.18), 1.0, true)
		sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		beacon.add_child(sphere)

		for k in 2:
			var ring: MeshInstance3D = MeshInstance3D.new()
			ring.name = "Anneau%d" % k
			var tm: TorusMesh = TorusMesh.new()
			tm.inner_radius = 0.58 + float(k) * 0.25
			tm.outer_radius = 0.65 + float(k) * 0.25
			tm.rings = 24
			tm.ring_segments = 6
			ring.mesh = tm
			ring.material_override = _mat(
				c1.darkened(0.16) if k == 0 else c2.darkened(0.16),
				1.15,
				true)
			ring.rotation.x = PI * (0.28 + float(k) * 0.22)
			ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			beacon.add_child(ring)

		beacon_list.append(beacon)
		beacon_state.append(false)

	_world_beacons.append(beacon_list)
	_world_beacon_state.append(beacon_state)

	# Portail, ferme visuellement tant que les 3 balises ne sont pas actives.
	var portal: Node3D = Node3D.new()
	portal.name = "PortailMondeSuivant"
	portal.position = Vector3(0.0, 2.5, -16.0)
	world.add_child(portal)

	var outer: MeshInstance3D = MeshInstance3D.new()
	outer.name = "AnneauExterieur"
	var otm: TorusMesh = TorusMesh.new()
	otm.inner_radius = 2.0
	otm.outer_radius = 2.15
	otm.rings = 36
	otm.ring_segments = 8
	outer.mesh = otm
	outer.material_override = _mat(c1.darkened(0.32), 0.8, true)
	outer.rotation.x = PI * 0.5
	outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	portal.add_child(outer)

	var inner: MeshInstance3D = MeshInstance3D.new()
	inner.name = "AnneauInterieur"
	var itm: TorusMesh = TorusMesh.new()
	itm.inner_radius = 1.42
	itm.outer_radius = 1.53
	itm.rings = 32
	itm.ring_segments = 7
	inner.mesh = itm
	inner.material_override = _mat(c2.darkened(0.34), 0.75, true)
	inner.rotation.x = PI * 0.5
	inner.rotation.z = PI * 0.23
	inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	portal.add_child(inner)

	_world_portals.append(portal)

	# Quelques objets flottants très légers, animes seulement dans le monde actif.
	var floaters: Array = []
	for i in 8:
		var floater: Node3D = Node3D.new()
		floater.name = "Flottant%d" % i
		var a: float = TAU * float(i) / 8.0
		var r: float = 7.0 + float(i % 3) * 1.8
		floater.position = Vector3(cos(a) * r, 3.8 + float(i % 4) * 0.65, sin(a) * r - 5.0)
		world.add_child(floater)

		var ring: MeshInstance3D = MeshInstance3D.new()
		var ftm: TorusMesh = TorusMesh.new()
		ftm.inner_radius = 0.34
		ftm.outer_radius = 0.41
		ftm.rings = 18
		ftm.ring_segments = 6
		ring.mesh = ftm
		ring.material_override = _mat(c1 if i % 2 == 0 else c2, 1.8, true)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		floater.add_child(ring)

		floaters.append(floater)

	_world_floaters.append(floaters)


func _beacons_complete(index: int) -> bool:
	if index < 0 or index >= _world_beacon_state.size():
		return false
	var states: Array = _world_beacon_state[index]
	if states.size() < 3:
		return false
	for state_v in states:
		if state_v != true:
			return false
	return true


func _update_world_floaters(index: int, dt: float) -> void:
	if index < 0 or index >= _world_floaters.size():
		return

	var floaters: Array = _world_floaters[index]
	for i in floaters.size():
		var f: Node3D = floaters[i]
		f.rotation.y += dt * (0.18 + float(i % 4) * 0.04)
		f.rotation.z += dt * (0.10 + float(i % 3) * 0.03)
		var p: Vector3 = f.position
		p.y += sin(Time.get_ticks_msec() * 0.0012 + float(i) * 0.8) * dt * 0.12
		f.position = p


func _update_world_portal(index: int, dt: float) -> void:
	if index < 0 or index >= _world_portals.size():
		return

	var portal: Node3D = _world_portals[index]
	var open: bool = _beacons_complete(index)

	# v60 : le portail reste face au joueur, ses mandalas tournent (plus vite une fois ouvert).
	var rosace: Node3D = portal.get_node_or_null("Rosace") as Node3D
	var couronne: Node3D = portal.get_node_or_null("Couronne") as Node3D
	var vit: float = 3.2 if open else 0.6
	if rosace != null:
		MandalaMoteur.animer(rosace, dt * vit)
	if couronne != null:
		MandalaMoteur.animer(couronne, dt * vit * 0.7)

	var outer: MeshInstance3D = portal.get_node_or_null("AnneauExterieur") as MeshInstance3D
	var inner: MeshInstance3D = portal.get_node_or_null("AnneauInterieur") as MeshInstance3D
	if outer != null:
		outer.rotation.z += dt * (0.42 if open else 0.08)
		var pulse: float = 1.0 + (0.08 * sin(Time.get_ticks_msec() * 0.004) if open else 0.0)
		outer.scale = Vector3.ONE * pulse
	if inner != null:
		inner.rotation.z -= dt * (0.56 if open else 0.06)


func _try_world_interaction() -> void:
	if _planet_index < 0 or _planet_index >= _planet_worlds.size():
		return

	var ray_o: Vector3 = app.main_d.global_position
	var ray_d: Vector3 = -app.main_d.global_transform.basis.z
	ray_d = ray_d.normalized()

	# 1) Balises.
	if _planet_index < _world_beacons.size():
		var beacons: Array = _world_beacons[_planet_index]
		for i in beacons.size():
			var beacon: Node3D = beacons[i]
			if _ray_near_point(ray_o, ray_d, beacon.global_position, 0.95, 30.0):
				_activate_beacon(_planet_index, i)
				app.main_d.trigger_haptic_pulse("haptic", 0.0, 0.42, 0.06, 0.0)
				return

	# 2) Portail.
	if _planet_index < _world_portals.size():
		var portal: Node3D = _world_portals[_planet_index]
		if _ray_near_point(ray_o, ray_d, portal.global_position, 2.4, 34.0):
			if _beacons_complete(_planet_index):
				_switch_to_next_world()
				app.main_d.trigger_haptic_pulse("haptic", 0.0, 0.58, 0.08, 0.0)
			else:
				app.main_d.trigger_haptic_pulse("haptic", 0.0, 0.18, 0.04, 0.0)


func _ray_near_point(
	ray_o: Vector3,
	ray_d: Vector3,
	point: Vector3,
	radius: float,
	max_t: float
) -> bool:
	var v: Vector3 = point - ray_o
	var t: float = v.dot(ray_d)
	if t <= 0.0 or t > max_t:
		return false
	var closest: Vector3 = ray_o + ray_d * t
	return closest.distance_to(point) <= radius


func _activate_beacon(world_index: int, beacon_index: int) -> void:
	if world_index < 0 or world_index >= _world_beacon_state.size():
		return

	var states: Array = _world_beacon_state[world_index]
	if beacon_index < 0 or beacon_index >= states.size():
		return
	if states[beacon_index] == true:
		return

	states[beacon_index] = true
	_world_beacon_state[world_index] = states

	var beacons: Array = _world_beacons[world_index]
	var beacon: Node3D = beacons[beacon_index]

	var heart: MeshInstance3D = beacon.get_node_or_null("Coeur") as MeshInstance3D
	if heart != null:
		heart.material_override = _mat(Color(1.0, 0.92, 0.42, 1.0), 3.0, true)

	for k in 2:
		var ring: MeshInstance3D = beacon.get_node_or_null("Anneau%d" % k) as MeshInstance3D
		if ring != null:
			ring.material_override = _mat(
				Color(1.0, 0.76 + float(k) * 0.10, 0.28, 1.0),
				2.8,
				true)

	Observatoire60.activer_balise(beacon)
	beacon.scale = Vector3.ONE * 1.14


func _switch_to_next_world() -> void:
	if _planet_index < 0:
		return
	var next_index: int = (_planet_index + 1) % VISITABLE_WORLDS
	_set_planet_world(next_index)


func _set_planet_world(index: int) -> void:
	if index < 0 or index >= VISITABLE_WORLDS:
		return

	for i in _planet_worlds.size():
		var world: Node3D = _planet_worlds[i]
		world.visible = i == index

	_planet_index = index
	app.origine.global_transform = Transform3D(Basis(), Vector3.ZERO)
	_world_interact_trigger_was = app.main_d.get_float("trigger") > 0.58
	_update_status()


func _build_prismatic_garden(world: Node3D, c1: Color, c2: Color) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.22, 1.0, 0.22)
	mesh.material = _instance_color_mat()

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = 56
	mm.mesh = mesh

	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = "CrystalGarden"
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(node)

	for i in 56:
		var a: float = TAU * float(i) / 56.0 + float(i % 7) * 0.12
		var radius: float = 5.0 + float(i % 5) * 2.0
		var h: float = 1.2 + float(i % 8) * 0.42
		var pos: Vector3 = Vector3(cos(a) * radius, h * 0.5, sin(a) * radius - 3.0)
		var b: Basis = Basis(Vector3.UP, -a)
		b = b.scaled(Vector3(1.0, h, 1.0))
		mm.set_instance_transform(i, Transform3D(b, pos))
		mm.set_instance_color(i, c1 if i % 2 == 0 else c2)


func _build_orbital_temple(world: Node3D, c1: Color, c2: Color) -> void:
	for i in 12:
		var a: float = TAU * float(i) / 12.0
		var pillar: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.55, 4.4, 0.55)
		pillar.mesh = bm
		pillar.material_override = _mat(c1.darkened(0.35), 0.45)
		pillar.position = Vector3(cos(a) * 10.0, 2.2, sin(a) * 10.0 - 3.0)
		pillar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(pillar)

		var halo: MeshInstance3D = MeshInstance3D.new()
		var tm: TorusMesh = TorusMesh.new()
		tm.inner_radius = 0.74
		tm.outer_radius = 0.83
		tm.rings = 24
		tm.ring_segments = 7
		halo.mesh = tm
		halo.material_override = _mat(c2, 2.2, true)
		halo.position = pillar.position + Vector3(0.0, 2.25, 0.0)
		halo.rotation.x = PI * 0.5
		halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(halo)


func _build_fractal_sea(world: Node3D, c1: Color, c2: Color) -> void:
	var island_mesh: BoxMesh = BoxMesh.new()
	island_mesh.size = Vector3(1.0, 0.30, 1.0)
	island_mesh.material = _instance_color_mat()

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = 48
	mm.mesh = island_mesh

	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = "FractalIslands"
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(node)

	for i in 48:
		var a: float = float(i) * 2.399963
		var radius: float = 2.0 + sqrt(float(i)) * 1.75
		var pos: Vector3 = Vector3(
			cos(a) * radius,
			0.15 + sin(float(i) * 0.73) * 0.28,
			sin(a) * radius - 3.0)
		var sc: float = 0.8 + float(i % 5) * 0.34
		var b: Basis = Basis(Vector3.UP, a).scaled(Vector3(sc, 1.0, sc))
		mm.set_instance_transform(i, Transform3D(b, pos))
		mm.set_instance_color(i, c1 if i % 3 != 0 else c2)


func _build_crystal_forest(world: Node3D, c1: Color, c2: Color) -> void:
	var trunk_mesh: BoxMesh = BoxMesh.new()
	trunk_mesh.size = Vector3(0.28, 1.0, 0.28)
	trunk_mesh.material = _instance_color_mat()

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = 72
	mm.mesh = trunk_mesh

	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = "ForetCristal"
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(node)

	for i in 72:
		var a: float = float(i) * 2.399963
		var radius: float = 3.4 + sqrt(float(i)) * 1.55
		var h: float = 1.8 + float(i % 9) * 0.55
		var pos: Vector3 = Vector3(
			cos(a) * radius,
			h * 0.5,
			sin(a) * radius - 3.0)
		var b: Basis = Basis(Vector3.UP, a * 0.2)
		b = b.scaled(Vector3(
			0.72 + float(i % 3) * 0.22,
			h,
			0.72 + float((i + 1) % 3) * 0.22))
		mm.set_instance_transform(i, Transform3D(b, pos))
		mm.set_instance_color(i, c1 if i % 3 != 0 else c2)

	# Couronne suspendue au-dessus de la foret.
	for k in 3:
		var ring: MeshInstance3D = MeshInstance3D.new()
		var tm: TorusMesh = TorusMesh.new()
		tm.inner_radius = 5.0 + float(k) * 2.5
		tm.outer_radius = 5.10 + float(k) * 2.5
		tm.rings = 40
		tm.ring_segments = 7
		ring.mesh = tm
		ring.material_override = _mat(c2 if k % 2 == 0 else c1, 1.9, true)
		ring.position = Vector3(0.0, 6.0 + float(k) * 1.0, -4.0)
		ring.rotation.x = PI * (0.22 + float(k) * 0.12)
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(ring)


func _build_ring_city(world: Node3D, c1: Color, c2: Color) -> void:
	# Tours concentriques avec anneaux suspendus.
	for i in 18:
		var a: float = TAU * float(i) / 18.0
		var radius: float = 6.5 + float(i % 3) * 3.2
		var h: float = 2.8 + float(i % 6) * 0.75

		var tower: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.85, h, 0.85)
		tower.mesh = bm
		tower.material_override = _mat(c1.darkened(0.38), 0.55)
		tower.position = Vector3(cos(a) * radius, h * 0.5, sin(a) * radius - 3.0)
		tower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(tower)

		if i % 2 == 0:
			var halo: MeshInstance3D = MeshInstance3D.new()
			var tm: TorusMesh = TorusMesh.new()
			tm.inner_radius = 1.0 + float(i % 4) * 0.22
			tm.outer_radius = tm.inner_radius + 0.09
			tm.rings = 28
			tm.ring_segments = 7
			halo.mesh = tm
			halo.material_override = _mat(c2, 2.3, true)
			halo.position = tower.position + Vector3(0.0, h * 0.55, 0.0)
			halo.rotation.x = PI * 0.5
			halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			world.add_child(halo)

	# Porte monumentale.
	var gate: MeshInstance3D = MeshInstance3D.new()
	var gtm: TorusMesh = TorusMesh.new()
	gtm.inner_radius = 4.0
	gtm.outer_radius = 4.18
	gtm.rings = 48
	gtm.ring_segments = 8
	gate.mesh = gtm
	gate.material_override = _mat(c1.lightened(0.18), 2.5, true)
	gate.position = Vector3(0.0, 4.2, -12.0)
	gate.rotation.x = PI * 0.5
	gate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(gate)


func _build_luminous_abyss(world: Node3D, c1: Color, c2: Color) -> void:
	# Plateau central sombre entouré de piliers descendant dans un faux vide.
	var pit: MeshInstance3D = MeshInstance3D.new()
	var pm: CylinderMesh = CylinderMesh.new()
	pm.top_radius = 9.0
	pm.bottom_radius = 12.0
	pm.height = 5.0
	pm.radial_segments = 40
	pit.mesh = pm
	pit.material_override = _mat(Color(0.008, 0.014, 0.045, 1.0))
	pit.position = Vector3(0.0, -2.65, -3.0)
	pit.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(pit)

	var beam_mesh: BoxMesh = BoxMesh.new()
	beam_mesh.size = Vector3(0.14, 1.0, 0.14)
	beam_mesh.material = _instance_color_mat()

	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = 44
	mm.mesh = beam_mesh

	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = "PiliersAbyssaux"
	node.multimesh = mm
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(node)

	for i in 44:
		var a: float = TAU * float(i) / 44.0
		var radius: float = 10.5 + float(i % 4) * 2.0
		var h: float = 4.5 + float(i % 8) * 0.75
		var pos: Vector3 = Vector3(cos(a) * radius, -h * 0.5 + 0.2, sin(a) * radius - 3.0)
		var b: Basis = Basis().scaled(Vector3(1.0, h, 1.0))
		mm.set_instance_transform(i, Transform3D(b, pos))
		mm.set_instance_color(i, c1 if i % 2 == 0 else c2)

	for k in 4:
		var abyss_ring: MeshInstance3D = MeshInstance3D.new()
		var tm: TorusMesh = TorusMesh.new()
		tm.inner_radius = 4.6 + float(k) * 2.1
		tm.outer_radius = 4.72 + float(k) * 2.1
		tm.rings = 40
		tm.ring_segments = 7
		abyss_ring.mesh = tm
		abyss_ring.material_override = _mat(c2 if k % 2 == 0 else c1, 2.0, true)
		abyss_ring.position = Vector3(0.0, -1.0 - float(k) * 1.0, -3.0)
		abyss_ring.rotation.x = PI * 0.5
		abyss_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(abyss_ring)


func _try_visit_planet() -> void:
	var ray_o: Vector3 = app.main_d.global_position
	var ray_d: Vector3 = -app.main_d.global_transform.basis.z
	ray_d = ray_d.normalized()

	var best_index: int = -1
	var best_t: float = 9999.0

	for i in VISITABLE_WORLDS:
		if i >= _hero_roots.size():
			continue

		var hero: Node3D = _hero_roots[i]
		var centre: Vector3 = hero.global_position
		var to_centre: Vector3 = centre - ray_o
		var along: float = to_centre.dot(ray_d)
		if along <= 0.0 or along >= best_t:
			continue

		var closest: Vector3 = ray_o + ray_d * along
		var hit_radius: float = 2.2 + float(_planet_sizes[i * 24]) * 1.8
		if closest.distance_to(centre) <= hit_radius:
			best_index = i
			best_t = along

	if best_index >= 0:
		_enter_planet(best_index)
		app.main_d.trigger_haptic_pulse("haptic", 0.0, 0.48, 0.07, 0.0)


func _enter_planet(index: int) -> void:
	if _mode != MODE_GALAXIE:
		return
	if index < 0 or index >= VISITABLE_WORLDS:
		return

	_planet_return_origin = app.origine.global_transform
	_mode = MODE_PLANETE

	_galaxy_root.visible = false
	_planet_world_root.visible = true
	_set_planet_world(index)


func retourner_galaxie() -> void:
	if not _active or _mode != MODE_PLANETE:
		return

	for world_v in _planet_worlds:
		var world: Node3D = world_v
		world.visible = false

	_planet_world_root.visible = false
	_galaxy_root.visible = true
	app.origine.global_transform = _planet_return_origin
	_planet_index = -1
	_mode = MODE_GALAXIE
	_galaxy_trigger_was = app.main_d.get_float("trigger") > 0.58
	_update_status()


func _maintenir_planete() -> void:
	var p: Vector3 = app.origine.global_position
	p.y = 0.0

	var horizontal: Vector2 = Vector2(p.x, p.z)
	if horizontal.length() > 16.5:
		horizontal = horizontal.normalized() * 16.5
		p.x = horizontal.x
		p.z = horizontal.y

	app.origine.global_position = p


# =====================================================================
# Activation / restauration

func demarrer_musee() -> void:
	_refresh_museum_saved_art()
	_start_mode(MODE_MUSEE)


func demarrer_galaxie() -> void:
	_planet_index = -1
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
		"monde": app.monde.courant,
		"v28_auto": _lire(app.get_node_or_null("V28Manager"), "_variation_auto", true),
		"v29_actif": _lire(app.get_node_or_null("V29Manager"), "_actif", true),
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

	# v60 : le ciel du monde actif se dessine par-dessus la geometrie opaque
	# (profondeur desactivee) : on l'eteint pendant l'Observatoire.
	# V28 choisit un fond au hasard des que le monde est a zero et V29 redessine
	# ses paysages a chaque changement de monde : on les met en pause.
	var m28: Node = app.get_node_or_null("V28Manager")
	if m28 != null:
		m28.set("_variation_auto", false)
	var m29: Node = app.get_node_or_null("V29Manager")
	if m29 != null:
		m29.set("_actif", false)
	if app.monde.courant != 0:
		app.set_monde(0)
	if m29 != null and m29.has_method("_appliquer_monde"):
		m29.call("_appliquer_monde")
	app.monde.ciel.visible = false

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
	_planet_world_root.visible = false
	for world_v in _planet_worlds:
		var world: Node3D = world_v
		world.visible = false
	_planet_index = -1
	_galaxy_trigger_was = app.main_d.get_float("trigger") > 0.58

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
	_planet_world_root.visible = false
	for world_v in _planet_worlds:
		var world: Node3D = world_v
		world.visible = false
	_planet_index = -1

	if not _snapshot.is_empty():
		app.origine.global_transform = _snapshot.get("origin", app.origine.global_transform)
		app.sc.global_transform = _snapshot.get("sc_transform", app.sc.global_transform)
		app.sc.visible = (_snapshot.get("sc_visible", true) == true)
		app.sol.visible = (_snapshot.get("sol_visible", true) == true)
		var m28b: Node = app.get_node_or_null("V28Manager")
		if m28b != null:
			m28b.set("_variation_auto", _snapshot.get("v28_auto", true) == true)
		var m29b: Node = app.get_node_or_null("V29Manager")
		if m29b != null:
			m29b.set("_actif", _snapshot.get("v29_actif", true) == true)
		var monde_avant: int = int(_snapshot.get("monde", 0))
		if monde_avant != app.monde.courant:
			app.set_monde(monde_avant)
		if m29b != null and m29b.has_method("_appliquer_monde"):
			m29b.call("_appliquer_monde")
		app.monde.ciel.visible = true

		var paysage_v: Variant = _snapshot.get("paysage", null)
		if paysage_v is Node3D and is_instance_valid(paysage_v):
			(paysage_v as Node3D).visible = (_snapshot.get("paysage_visible", true) == true)

		if (
			(_snapshot.get("passthrough", false) == true)
			and v8 != null
			and v8.has_method("_set_passthrough")
		):
			v8.call("_set_passthrough", true)

		var hud_v: Variant = app.get("_hud")
		var msg_v: Variant = app.get("_msg_label")
		var help_v: Variant = app.get("_aide")
		var ray_v: Variant = app.get("_rayon")

		if hud_v is Node3D:
			(hud_v as Node3D).visible = (_snapshot.get("hud_visible", true) == true)
		if msg_v is Node3D:
			(msg_v as Node3D).visible = (_snapshot.get("msg_visible", true) == true)
		if help_v is Node3D:
			(help_v as Node3D).visible = (_snapshot.get("help_visible", false) == true)
		if ray_v is Node3D:
			(ray_v as Node3D).visible = (_snapshot.get("ray_visible", true) == true)

	_snapshot = {}
	_update_status()
