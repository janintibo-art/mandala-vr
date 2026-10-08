class_name V39Manager
extends Node
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
var v38 = null

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


func _ready() -> void:
	app = get_parent()
	v31 = app.get_node_or_null("V31Manager")
	v32 = app.get_node_or_null("V32Manager")
	v33 = app.get_node_or_null("V33Manager")
	v36 = app.get_node_or_null("V36Manager")
	v38 = app.get_node_or_null("V38Manager")
	process_priority = 310


func _process(_dt: float) -> void:
	if app == null:
		return

	if not _installe:
		var pret: bool = (
			v31 != null and bool(v31.get("_installe"))
			and v32 != null and bool(v32.get("_installe"))
			and v33 != null and bool(v33.get("_installe"))
			and v36 != null and bool(v36.get("_installe"))
			and v38 != null and bool(v38.get("_installe"))
		)
		if pret:
			_installer()
		return

	_maj_death_events()
	_maj_course_events()


# ================================================================== installation

func _installer() -> void:
	_installe = true

	_mat_blue = _glow(Color(0.16, 0.68, 1.0, 0.70), 3.0)
	_mat_pink = _glow(Color(0.90, 0.20, 1.0, 0.68), 3.0)
	_mat_gold = _glow(Color(1.0, 0.62, 0.14, 0.68), 3.0)
	_mat_red = _glow(Color(1.0, 0.18, 0.10, 0.72), 3.2)

	_creer_death_events()
	_creer_course_events()
	app.message("v39 : evenements de parcours actifs")


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
		var noms: Array = [
			"IRIS",
			"PORTIQUE",
			"FAUX MUR",
			"TRAVERSES",
		]
		app.message("EVENEMENT : " + str(noms[(chapitre + acte) % noms.size()]))

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
		var noms: Array = [
			"PORTES",
			"ANNEAUX GEANTS",
			"COLONNES",
			"FAILLE",
		]
		app.message("COURSE : " + str(noms[(secteur + demi) % noms.size()]))

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
