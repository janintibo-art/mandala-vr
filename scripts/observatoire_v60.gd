class_name Observatoire60
extends RefCounted
## Mandala VR v60 : refonte visuelle de l'Observatoire.
##
## Grand musee (arches, colonnade, toiles-mandalas, sculptures armillaires, rosace),
## trois mondes premium (Temple Solaire, Cite Radiale, Sanctuaire des Portails)
## et planetes mandala de la galaxie. Tout est compose avec MandalaMoteur.

const OR: Color = Color(0.70, 0.52, 0.21)
const OR_VIF: Color = Color(0.98, 0.78, 0.36)
const PIERRE: Color = Color(0.12, 0.11, 0.16)

const PALETTES_TOILES: Array = [
	[Color(1.0, 0.62, 0.18), Color(0.95, 0.25, 0.45), Color(0.45, 0.30, 1.0)],
	[Color(0.20, 0.80, 1.0), Color(0.50, 0.40, 1.0), Color(1.0, 0.40, 0.70)],
	[Color(0.20, 1.0, 0.65), Color(0.20, 0.70, 1.0), Color(0.70, 0.30, 1.0)],
	[Color(1.0, 0.82, 0.30), Color(1.0, 0.45, 0.20), Color(0.80, 0.15, 0.35)],
	[Color(0.75, 0.35, 1.0), Color(0.25, 0.55, 1.0), Color(0.20, 1.0, 0.85)],
	[Color(1.0, 0.35, 0.55), Color(1.0, 0.70, 0.30), Color(0.40, 0.90, 1.0)],
	[Color(0.30, 1.0, 0.50), Color(0.90, 0.95, 0.25), Color(1.0, 0.45, 0.25)],
	[Color(0.35, 0.50, 1.0), Color(0.85, 0.40, 1.0), Color(1.0, 0.80, 0.50)],
]

static var _mat_opaque: StandardMaterial3D = null


# ================================================================ outils

static func mat(c: Color, additive: bool = false) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_fog = true
	m.albedo_color = c
	if additive:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


static func mat_opaque_vc() -> StandardMaterial3D:
	if _mat_opaque == null:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.disable_fog = true
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat_opaque = m
	return _mat_opaque


static func _poser(parent: Node3D, mesh: Mesh, m: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func boite(parent: Node3D, pos: Vector3, taille: Vector3, c: Color, additive: bool = false) -> MeshInstance3D:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = taille
	return _poser(parent, bm, mat(c, additive), pos)


static func cylindre(parent: Node3D, pos: Vector3, r_haut: float, r_bas: float, h: float, c: Color, seg: int = 18, additive: bool = false) -> MeshInstance3D:
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = r_haut
	cm.bottom_radius = r_bas
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	return _poser(parent, cm, mat(c, additive), pos)


static func tore(parent: Node3D, pos: Vector3, rayon: float, tube: float, c: Color, rot_deg: Vector3 = Vector3.ZERO, additive: bool = false, seg: int = 48) -> MeshInstance3D:
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = rayon - tube
	tm.outer_radius = rayon + tube
	tm.rings = seg
	tm.ring_segments = 8
	return _poser(parent, tm, mat(c, additive), pos, rot_deg)


static func quad_degrade(parent: Node3D, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ca: Color, cb: Color, cc: Color, cd: Color) -> MeshInstance3D:
	var m: ArrayMesh = ArrayMesh.new()
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([a, b, c, d])
	arr[Mesh.ARRAY_COLOR] = PackedColorArray([ca, cb, cc, cd])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return _poser(parent, m, mat_opaque_vc(), Vector3.ZERO)


## Cone de lumiere translucide de apex vers cible (eclairage dirige).
static func faisceau(parent: Node3D, apex: Vector3, cible: Vector3, rayon: float, col: Color, alpha: float, seg: int = 14) -> MeshInstance3D:
	var axe: Vector3 = (cible - apex).normalized()
	var u: Vector3 = axe.cross(Vector3.UP)
	if u.length() < 0.01:
		u = axe.cross(Vector3.RIGHT)
	u = u.normalized()
	var v: Vector3 = axe.cross(u).normalized()
	var p: PackedVector3Array = PackedVector3Array()
	var c: PackedColorArray = PackedColorArray()
	var idx: PackedInt32Array = PackedInt32Array()
	p.append(apex)
	c.append(Color(col.r, col.g, col.b, 0.0))
	var etages: Array = [[0.55, 0.55, 0.6], [1.0, 1.0, 0.0]]
	for e in etages:
		var t: float = float(e[0])
		var r: float = rayon * float(e[1])
		var al: float = alpha * float(e[2])
		var centre: Vector3 = apex.lerp(cible, t)
		for i in seg:
			var a: float = TAU * float(i) / float(seg)
			p.append(centre + (u * cos(a) + v * sin(a)) * r)
			c.append(Color(col.r, col.g, col.b, al))
	for i in seg:
		idx.append(0)
		idx.append(1 + i)
		idx.append(1 + (i + 1) % seg)
	for e in 1:
		for i in seg:
			var a0: int = 1 + i
			var a1: int = 1 + (i + 1) % seg
			var b0: int = 1 + seg + i
			var b1: int = 1 + seg + (i + 1) % seg
			idx.append(a0)
			idx.append(b0)
			idx.append(b1)
			idx.append(a0)
			idx.append(b1)
			idx.append(a1)
	var m: ArrayMesh = ArrayMesh.new()
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = p
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_INDEX] = idx
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return _poser(parent, m, MandalaMoteur.materiau(), Vector3.ZERO)


## Tache de lumiere douce (disque a bord transparent), a plat ou verticale.
static func lueur(parent: Node3D, pos: Vector3, rayon: float, col: Color, alpha: float, rot_deg: Vector3) -> MeshInstance3D:
	var pb: MandalaMoteur.Pinceau = MandalaMoteur.Pinceau.new()
	pb.disque(Vector2.ZERO, 1.0, Color(col.r, col.g, col.b, alpha), Color(col.r, col.g, col.b, 0.0), 28)
	var mi: MeshInstance3D = _poser(parent, pb.fabriquer(), MandalaMoteur.materiau(), pos, rot_deg)
	mi.scale = Vector3.ONE * rayon
	return mi


## Pose un mandala dans la scene et l'enregistre pour l'animation.
static func mandala(parent: Node3D, etat: Dictionary, pos: Vector3, rot_deg: Vector3, rayon: float, graine: int, pal: Array, detail: float = 1.0, vitesse: float = 1.0) -> Node3D:
	var n: Node3D = MandalaMoteur.noeud(graine, pal, rayon, detail, vitesse)
	n.position = pos
	n.rotation_degrees = rot_deg
	parent.add_child(n)
	(etat["mandalas"] as Array).append(n)
	return n


## Sphere armillaire : trois mandalas verticaux entrecroises autour d'un noyau lumineux.
static func armillaire(parent: Node3D, etat: Dictionary, pos: Vector3, rayon: float, graine: int, pal: Array) -> Node3D:
	var g: Node3D = Node3D.new()
	g.name = "Armillaire"
	g.position = pos
	parent.add_child(g)
	for k in 3:
		var n: Node3D = MandalaMoteur.noeud(graine + k * 5, pal, rayon, 0.7)
		n.rotation.y = PI * float(k) / 3.0
		g.add_child(n)
		(etat["mandalas"] as Array).append(n)
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = rayon * 0.15
	sm.height = rayon * 0.30
	sm.radial_segments = 14
	sm.rings = 7
	var c: Color = (pal[1] as Color)
	_poser(g, sm, mat(Color(c.r * 0.9 + 0.1, c.g * 0.9 + 0.1, c.b * 0.9 + 0.1, 0.85), true), Vector3.ZERO)
	(etat["tournants"] as Array).append(g)
	return g


static func nouvel_etat() -> Dictionary:
	return {"mandalas": [], "tournants": [], "toiles": []}


static func animer(etat: Dictionary, dt: float, t: float) -> void:
	for m in (etat["mandalas"] as Array):
		if is_instance_valid(m):
			MandalaMoteur.animer(m as Node3D, dt)
	var i: int = 0
	for g in (etat["tournants"] as Array):
		if is_instance_valid(g):
			(g as Node3D).rotation.y += dt * (0.20 + 0.04 * float(i % 3))
			(g as Node3D).rotation.x = sin(t * 0.3 + float(i)) * 0.12
		i += 1


## Arche en ellipse (ruban sous la voute) avec filets dores sur les bords.
static func arche_mesh(demi: float, y0: float, haut: float, ez: float, epaisseur: float, c_pierre: Color, c_or: Color) -> ArrayMesh:
	var p: PackedVector3Array = PackedVector3Array()
	var c: PackedColorArray = PackedColorArray()
	var idx: PackedInt32Array = PackedInt32Array()
	var m: int = 28
	var pts: Array = []
	var ints: Array = []
	for i in m + 1:
		var a: float = PI * float(i) / float(m)
		var x: float = -demi * cos(a)
		var y: float = y0 + haut * sin(a)
		pts.append(Vector2(x, y))
		var nrm: Vector2 = Vector2(x / (demi * demi), (y - y0) / (haut * haut)).normalized()
		ints.append(Vector2(x, y) - nrm * epaisseur)
	for i in m:
		var a0: Vector2 = pts[i]
		var a1: Vector2 = pts[i + 1]
		var b0: Vector2 = ints[i]
		var b1: Vector2 = ints[i + 1]
		var fond: float = 0.55 + 0.45 * sin(PI * float(i) / float(m))
		var cp: Color = c_pierre * fond
		cp.a = 1.0
		var k: int = p.size()
		# face inferieure
		p.append(Vector3(b0.x, b0.y, -ez))
		p.append(Vector3(b0.x, b0.y, ez))
		p.append(Vector3(b1.x, b1.y, ez))
		p.append(Vector3(b1.x, b1.y, -ez))
		for q in 4:
			c.append(cp)
		idx.append_array(PackedInt32Array([k, k + 1, k + 2, k, k + 2, k + 3]))
		# filets dores sur les deux bords
		for sgn in [-1.0, 1.0]:
			var z0: float = ez * float(sgn)
			var k2: int = p.size()
			p.append(Vector3(a0.x, a0.y, z0))
			p.append(Vector3(b0.x, b0.y, z0))
			p.append(Vector3(b1.x, b1.y, z0))
			p.append(Vector3(a1.x, a1.y, z0))
			for q in 4:
				c.append(c_or)
			idx.append_array(PackedInt32Array([k2, k2 + 1, k2 + 2, k2, k2 + 2, k2 + 3]))
	var mesh: ArrayMesh = ArrayMesh.new()
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = p
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## Arcades circulaires entre colonnes (temple) : ogives dorees.
static func arcades_mesh(n: int, rayon: float, y0: float, haut: float, largeur: float, c_or: Color) -> ArrayMesh:
	var p: PackedVector3Array = PackedVector3Array()
	var c: PackedColorArray = PackedColorArray()
	var idx: PackedInt32Array = PackedInt32Array()
	var m: int = 14
	for i in n:
		var a0: float = TAU * float(i) / float(n)
		var da: float = TAU / float(n)
		for j in m:
			var tA: float = float(j) / float(m)
			var tB: float = float(j + 1) / float(m)
			var pa: float = pow(sin(PI * tA), 0.62)
			var pb: float = pow(sin(PI * tB), 0.62)
			var angA: float = a0 + da * tA
			var angB: float = a0 + da * tB
			var yA: float = y0 + haut * pa
			var yB: float = y0 + haut * pb
			var dA: Vector3 = Vector3(cos(angA), 0.0, sin(angA))
			var dB: Vector3 = Vector3(cos(angB), 0.0, sin(angB))
			var k: int = p.size()
			p.append(dA * (rayon - largeur) + Vector3(0, yA, 0))
			p.append(dA * (rayon + largeur) + Vector3(0, yA, 0))
			p.append(dB * (rayon + largeur) + Vector3(0, yB, 0))
			p.append(dB * (rayon - largeur) + Vector3(0, yB, 0))
			var cc: Color = c_or * (0.7 + 0.3 * pa)
			cc.a = 1.0
			for q in 4:
				c.append(cc)
			idx.append_array(PackedInt32Array([k, k + 1, k + 2, k, k + 2, k + 3]))
	var mesh: ArrayMesh = ArrayMesh.new()
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = p
	arr[Mesh.ARRAY_COLOR] = c
	arr[Mesh.ARRAY_INDEX] = idx
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return mesh


## MultiMesh d'un meme maillage avec une couleur par instance.
static func multi(parent: Node3D, mesh: Mesh, transforms: Array, couleurs: Array, nom: String, additive: bool = false) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = transforms.size()
	mm.mesh = mesh
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	if additive:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.name = nom
	node.multimesh = mm
	node.material_override = m
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
		mm.set_instance_color(i, couleurs[i])
	return node


# ================================================================ MUSEE

const MUSEE_X: float = 13.29
const MUSEE_H: float = 10.6
const MUSEE_Z0: float = 6.0
const MUSEE_Z1: float = -65.7
const NB_TOILES: int = 16


static func musee(racine: Node3D) -> Dictionary:
	var etat: Dictionary = nouvel_etat()
	var haut: float = MUSEE_H
	var zc: float = (MUSEE_Z0 + MUSEE_Z1) * 0.5

	# Sol : degrade de pierre sombre, chemin central.
	quad_degrade(racine,
		Vector3(-MUSEE_X, 0, MUSEE_Z0), Vector3(MUSEE_X, 0, MUSEE_Z0),
		Vector3(MUSEE_X, 0, MUSEE_Z1), Vector3(-MUSEE_X, 0, MUSEE_Z1),
		Color(0.13, 0.115, 0.16), Color(0.13, 0.115, 0.16), Color(0.05, 0.05, 0.09), Color(0.05, 0.05, 0.09))
	quad_degrade(racine,
		Vector3(-1.9, 0.012, MUSEE_Z0 - 1.0), Vector3(1.9, 0.012, MUSEE_Z0 - 1.0),
		Vector3(1.9, 0.012, MUSEE_Z1 + 1.0), Vector3(-1.9, 0.012, MUSEE_Z1 + 1.0),
		Color(0.22, 0.07, 0.17), Color(0.22, 0.07, 0.17), Color(0.09, 0.04, 0.16), Color(0.09, 0.04, 0.16))
	for sx in [-1.9, 1.9]:
		boite(racine, Vector3(float(sx), 0.02, zc), Vector3(0.09, 0.03, MUSEE_Z0 - MUSEE_Z1 - 2.0), OR_VIF)

	# Murs : degrade chaud en bas, sombre en haut.
	var bas: Color = Color(0.17, 0.12, 0.17)
	var top: Color = Color(0.035, 0.035, 0.07)
	for sx in [-1.0, 1.0]:
		var x: float = MUSEE_X * float(sx)
		quad_degrade(racine, Vector3(x, 0, MUSEE_Z0), Vector3(x, 0, MUSEE_Z1), Vector3(x, haut, MUSEE_Z1), Vector3(x, haut, MUSEE_Z0), bas, bas, top, top)
		boite(racine, Vector3(x * 0.998, 1.1, zc), Vector3(0.14, 0.16, MUSEE_Z0 - MUSEE_Z1), OR)
		boite(racine, Vector3(x * 0.998, 7.6, zc), Vector3(0.20, 0.30, MUSEE_Z0 - MUSEE_Z1), OR)
	quad_degrade(racine, Vector3(-MUSEE_X, 0, MUSEE_Z1), Vector3(MUSEE_X, 0, MUSEE_Z1), Vector3(MUSEE_X, haut, MUSEE_Z1), Vector3(-MUSEE_X, haut, MUSEE_Z1), bas, bas, top, top)
	quad_degrade(racine, Vector3(-MUSEE_X, 0, MUSEE_Z0), Vector3(MUSEE_X, 0, MUSEE_Z0), Vector3(MUSEE_X, haut, MUSEE_Z0), Vector3(-MUSEE_X, haut, MUSEE_Z0), bas, bas, top, top)
	quad_degrade(racine, Vector3(-MUSEE_X, haut, MUSEE_Z0), Vector3(MUSEE_X, haut, MUSEE_Z0), Vector3(MUSEE_X, haut, MUSEE_Z1), Vector3(-MUSEE_X, haut, MUSEE_Z1), Color(0.04, 0.04, 0.07), Color(0.04, 0.04, 0.07), Color(0.025, 0.025, 0.05), Color(0.025, 0.025, 0.05))

	# Colonnade doree + arches de voute au meme rythme.
	var pas: float = 7.8
	var arche: ArrayMesh = arche_mesh(MUSEE_X - 0.15, 7.6, 2.9, 0.42, 0.34, Color(0.30, 0.24, 0.20), OR)
	var colonnes: int = 9
	for i in colonnes:
		var z: float = -2.6 - float(i) * pas
		for sx in [-1.0, 1.0]:
			var x: float = 11.9 * float(sx)
			boite(racine, Vector3(x, 0.12, z), Vector3(1.15, 0.24, 1.15), OR)
			cylindre(racine, Vector3(x, 0.52, z), 0.52, 0.62, 0.55, OR_VIF * 0.85, 14)
			cylindre(racine, Vector3(x, 3.95, z), 0.30, 0.34, 6.9, OR * 1.05, 10)
			for k in 3:
				cylindre(racine, Vector3(x, 1.4 + float(k) * 2.5, z), 0.37, 0.37, 0.10, OR_VIF * 0.9, 12)
			cylindre(racine, Vector3(x, 7.55, z), 0.66, 0.34, 0.62, OR_VIF * 0.85, 14)
			boite(racine, Vector3(x, 7.95, z), Vector3(1.25, 0.22, 1.25), OR)
		var mi: MeshInstance3D = _poser(racine, arche, mat_opaque_vc(), Vector3(0, 0, z))
		mi.name = "ArcheVoute%d" % i

	# Rosaces de voute et de sol, grande rosace au fond.
	var z_roses: Array = [-14.0, -34.0, -54.0]
	for i in z_roses.size():
		var pal: Array = PALETTES_TOILES[(i * 3 + 1) % PALETTES_TOILES.size()]
		mandala(racine, etat, Vector3(0, haut - 0.05, float(z_roses[i])), Vector3(90, 0, 0), 6.4, 700 + i * 31, pal, 1.0, 0.7)
		mandala(racine, etat, Vector3(0, 0.035, float(z_roses[i])), Vector3(-90, 0, 0), 5.3 if i != 1 else 6.4, 710 + i * 29, PALETTES_TOILES[(i * 2 + 4) % PALETTES_TOILES.size()], 1.1, 0.8)
		lueur(racine, Vector3(0, 0.02, float(z_roses[i])), 7.5, Color(0.5, 0.4, 1.0), 0.10, Vector3(-90, 0, 0))

	var pal_fond: Array = [Color(1.0, 0.62, 0.18), Color(0.95, 0.25, 0.45), Color(0.45, 0.30, 1.0), Color(0.20, 0.80, 1.0)]
	mandala(racine, etat, Vector3(0, 5.3, MUSEE_Z1 + 0.12), Vector3.ZERO, 4.8, 777, pal_fond, 1.5, 0.8)
	tore(racine, Vector3(0, 5.3, MUSEE_Z1 + 0.10), 5.1, 0.11, OR_VIF, Vector3(90, 0, 0))
	tore(racine, Vector3(0, 5.3, MUSEE_Z1 + 0.10), 5.45, 0.05, OR, Vector3(90, 0, 0))
	for sx in [-1.0, 1.0]:
		mandala(racine, etat, Vector3(8.4 * float(sx), 5.3, MUSEE_Z1 + 0.12), Vector3.ZERO, 2.0, 790 + int(sx), PALETTES_TOILES[(int(sx) + 3) % PALETTES_TOILES.size()], 1.0, 0.9)
		tore(racine, Vector3(8.4 * float(sx), 5.3, MUSEE_Z1 + 0.10), 2.15, 0.06, OR_VIF, Vector3(90, 0, 0))
	lueur(racine, Vector3(0, 5.3, MUSEE_Z1 + 0.30), 8.5, Color(0.6, 0.3, 0.9), 0.14, Vector3.ZERO)
	# Estrade devant la rosace.
	cylindre(racine, Vector3(0, 0.18, -59.0), 5.2, 5.4, 0.36, PIERRE * 1.4, 28)
	cylindre(racine, Vector3(0, 0.46, -59.0), 4.1, 4.2, 0.20, PIERRE * 1.7, 28)
	tore(racine, Vector3(0, 0.37, -59.0), 5.3, 0.05, OR_VIF, Vector3.ZERO, false, 40)
	armillaire(racine, etat, Vector3(0, 3.3, -59.0), 2.2, 801, PALETTES_TOILES[0])
	faisceau(racine, Vector3(0, haut - 0.3, -59.0), Vector3(0, 0.5, -59.0), 3.4, Color(1.0, 0.8, 0.5), 0.13)

	# Toiles : huit de chaque cote, cadre dore, eclairage dirige.
	for i in NB_TOILES:
		var cote: float = -1.0 if i % 2 == 0 else 1.0
		var rang: int = i / 2
		var z: float = -6.5 - float(rang) * pas
		_toile(racine, etat, cote, rang, z, i)

	# Sculptures : trois armillaires centrales sur socle, quatre mandalas sur colonnes.
	for z in [-24.0, -44.0]:
		_socle(racine, Vector3(0, 0, float(z)), 1.0)
		armillaire(racine, etat, Vector3(0, 3.0, float(z)), 1.35, 820 + int(-z), PALETTES_TOILES[(int(-z) / 4) % PALETTES_TOILES.size()])
		faisceau(racine, Vector3(0, haut - 0.3, float(z)), Vector3(0, 1.5, float(z)), 2.0, Color(0.8, 0.85, 1.0), 0.11)
		lueur(racine, Vector3(0, 0.025, float(z)), 3.2, Color(0.5, 0.5, 1.0), 0.16, Vector3(-90, 0, 0))
		for sx in [-1.0, 1.0]:
			var px: float = 6.4 * float(sx)
			_socle(racine, Vector3(px, 0, float(z)), 0.6)
			var d: Node3D = mandala(racine, etat, Vector3(px, 2.6, float(z)), Vector3(0, 90, 0), 0.95, 850 + int(-z) + int(sx), PALETTES_TOILES[(int(-z) / 3 + int(sx) + 8) % PALETTES_TOILES.size()], 0.9, 1.0)
			d.name = "DisqueSocle"
			lueur(racine, Vector3(px, 0.025, float(z)), 2.2, Color(1.0, 0.7, 0.4), 0.14, Vector3(-90, 0, 0))
	return etat


static func _socle(racine: Node3D, pos: Vector3, echelle: float) -> void:
	var e: float = echelle
	cylindre(racine, pos + Vector3(0, 0.11 * e, 0), 1.25 * e, 1.30 * e, 0.22 * e, PIERRE * 1.5, 24)
	cylindre(racine, pos + Vector3(0, 0.37 * e, 0), 1.0 * e, 1.1 * e, 0.30 * e, PIERRE * 1.9, 24)
	cylindre(racine, pos + Vector3(0, 1.12 * e, 0), 0.72 * e, 0.80 * e, 1.2 * e, PIERRE * 2.2, 20)
	cylindre(racine, pos + Vector3(0, 0.78 * e, 0), 0.84 * e, 0.84 * e, 0.08 * e, OR_VIF * 0.9, 24)
	cylindre(racine, pos + Vector3(0, 1.66 * e, 0), 0.90 * e, 0.86 * e, 0.12 * e, OR_VIF * 0.9, 24)
	cylindre(racine, pos + Vector3(0, 1.78 * e, 0), 0.62 * e, 0.62 * e, 0.06 * e, Color(0.45, 0.35, 0.9, 1.0), 24)


static func _toile(racine: Node3D, etat: Dictionary, cote: float, rang: int, z: float, index: int) -> void:
	var g: Node3D = Node3D.new()
	g.name = "GrandeToile%d%s" % [rang, "G" if cote < 0.0 else "D"]
	g.position = Vector3(cote * (MUSEE_X - 0.10), 4.3, z)
	g.rotation_degrees.y = 90.0 if cote < 0.0 else -90.0
	racine.add_child(g)
	var pal: Array = PALETTES_TOILES[index % PALETTES_TOILES.size()]

	# Cadre dore a deux filets + clous d'angle.
	var L: float = 5.5
	boite(g, Vector3(0, L * 0.5, 0.10), Vector3(L, 0.32, 0.22), OR)
	boite(g, Vector3(0, -L * 0.5, 0.10), Vector3(L, 0.32, 0.22), OR)
	boite(g, Vector3(-L * 0.5, 0, 0.10), Vector3(0.32, L, 0.22), OR)
	boite(g, Vector3(L * 0.5, 0, 0.10), Vector3(0.32, L, 0.22), OR)
	var L2: float = L - 0.55
	boite(g, Vector3(0, L2 * 0.5, 0.20), Vector3(L2, 0.08, 0.10), OR_VIF)
	boite(g, Vector3(0, -L2 * 0.5, 0.20), Vector3(L2, 0.08, 0.10), OR_VIF)
	boite(g, Vector3(-L2 * 0.5, 0, 0.20), Vector3(0.08, L2, 0.10), OR_VIF)
	boite(g, Vector3(L2 * 0.5, 0, 0.20), Vector3(0.08, L2, 0.10), OR_VIF)
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			var cm: CylinderMesh = CylinderMesh.new()
			cm.top_radius = 0.22
			cm.bottom_radius = 0.22
			cm.height = 0.14
			cm.radial_segments = 14
			_poser(g, cm, mat(OR_VIF), Vector3(float(sx) * L * 0.5, float(sy) * L * 0.5, 0.26), Vector3(90, 0, 0))

	# Toile sombre, lueur, mandala.
	boite(g, Vector3(0, 0, 0.04), Vector3(L - 0.5, L - 0.5, 0.05), Color(0.012, 0.012, 0.03))
	lueur(g, Vector3(0, 0, 0.07), 2.7, pal[1], 0.30, Vector3.ZERO)
	var m: Node3D = mandala(g, etat, Vector3(0, 0, 0.09), Vector3.ZERO, 2.25, 100 + index * 13, pal, 1.0, 1.0)

	# Cartel et eclairage dirige (cone depuis le plafond + tache au sol).
	boite(g, Vector3(0, -3.15, 0.08), Vector3(2.4, 0.34, 0.06), Color(0.10, 0.08, 0.06))
	boite(g, Vector3(0, -3.15, 0.115), Vector3(2.34, 0.28, 0.02), OR * 0.8)
	var plaque: Label3D = Label3D.new()
	plaque.name = "Plaque"
	plaque.text = "Collection Mandala %02d" % (index + 1)
	plaque.font_size = 26
	plaque.pixel_size = 0.0019
	plaque.outline_size = 5
	plaque.modulate = Color(1.0, 0.95, 0.85)
	plaque.position = Vector3(0, -3.15, 0.16)
	g.add_child(plaque)

	var apex: Vector3 = Vector3(cote * 8.6, MUSEE_H - 0.4, z)
	var cible: Vector3 = Vector3(cote * (MUSEE_X - 0.5), 4.3, z)
	faisceau(racine, apex, cible, 2.9, pal[0], 0.075)
	lueur(racine, Vector3(cote * 10.6, 0.025, z), 2.6, pal[0], 0.16, Vector3(-90, 0, 0))

	(etat["toiles"] as Array).append({
		"holder": g,
		"mandala": m,
		"label": plaque,
		"graine": 100 + index * 13,
		"pal": pal,
	})


## Remplace le mandala d'une toile (oeuvre enregistree de l'utilisateur).
static func changer_toile(etat: Dictionary, i: int, graine: int, pal: Array) -> void:
	var toiles: Array = etat["toiles"]
	if i < 0 or i >= toiles.size():
		return
	var d: Dictionary = toiles[i]
	var holder: Node3D = d["holder"]
	var vieux: Node3D = d["mandala"]
	(etat["mandalas"] as Array).erase(vieux)
	vieux.queue_free()
	var m: Node3D = MandalaMoteur.noeud(graine, pal, 2.25, 1.0, 1.0)
	m.position = Vector3(0, 0, 0.09)
	holder.add_child(m)
	(etat["mandalas"] as Array).append(m)
	d["mandala"] = m
	toiles[i] = d


# ================================================================ MONDES

## Prepare le ciel : un grand mandala au zenith et une rosace monumentale dans le fond.
static func ciel_mandala(w: Node3D, etat: Dictionary, pal: Array, graine: int) -> void:
	mandala(w, etat, Vector3(0, 31.0, -5.0), Vector3(90, 0, 0), 30.0, graine, pal, 1.2, 0.5)
	mandala(w, etat, Vector3(0, 15.0, -39.0), Vector3.ZERO, 24.0, graine + 7, pal, 1.2, 0.5)
	lueur(w, Vector3(0, 15.0, -38.5), 30.0, pal[1], 0.07, Vector3.ZERO)


static func monde_temple(w: Node3D, c1: Color, c2: Color, etat: Dictionary) -> void:
	var pal: Array = MandalaMoteur.palette_de(c1, c2)
	var pal2: Array = MandalaMoteur.palette_de(c2, c1)
	mandala(w, etat, Vector3(0, 0.03, -3), Vector3(-90, 0, 0), 10.5, 601, pal, 1.3, 0.6)
	mandala(w, etat, Vector3(0, 0.02, -3), Vector3(-90, 0, 0), 16.5, 602, pal2, 1.1, 0.4)
	lueur(w, Vector3(0, 0.015, -3), 17.0, c2, 0.10, Vector3(-90, 0, 0))
	var centre: Vector3 = Vector3(0, 0, -3)
	# Estrade a trois niveaux.
	cylindre(w, centre + Vector3(0, 0.15, 0), 4.5, 4.7, 0.30, PIERRE * 1.6, 32)
	cylindre(w, centre + Vector3(0, 0.40, 0), 3.6, 3.8, 0.22, PIERRE * 1.9, 32)
	cylindre(w, centre + Vector3(0, 0.60, 0), 2.7, 2.9, 0.20, PIERRE * 2.2, 32)
	tore(w, centre + Vector3(0, 0.31, 0), 4.7, 0.07, OR_VIF, Vector3.ZERO, false, 48)
	tore(w, centre + Vector3(0, 0.52, 0), 3.8, 0.05, OR_VIF, Vector3.ZERO, false, 48)
	armillaire(w, etat, centre + Vector3(0, 3.6, 0), 2.5, 611, pal)
	faisceau(w, centre + Vector3(0, 10.2, 0), centre + Vector3(0, 0.7, 0), 3.4, c1.lightened(0.2), 0.14)
	# Peristyle : seize colonnes, entablement et arcades dorees.
	var n: int = 16
	var R: float = 12.0
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var p: Vector3 = centre + Vector3(cos(a) * R, 0, sin(a) * R)
		boite(w, p + Vector3(0, 0.18, 0), Vector3(1.25, 0.36, 1.25), OR)
		cylindre(w, p + Vector3(0, 3.4, 0), 0.34, 0.40, 6.2, OR * 1.05, 12)
		cylindre(w, p + Vector3(0, 6.55, 0), 0.72, 0.38, 0.55, OR_VIF * 0.85, 14)
		boite(w, p + Vector3(0, 6.95, 0), Vector3(1.3, 0.24, 1.3), OR)
		var halo: Node3D = mandala(w, etat, p + Vector3(0, 8.3, 0), Vector3(0, rad_to_deg(-a) + 90.0, 0), 0.9, 620 + i, pal if i % 2 == 0 else pal2, 0.6, 1.0)
		halo.name = "HaloColonne%d" % i
	tore(w, centre + Vector3(0, 7.1, 0), R, 0.22, OR, Vector3.ZERO, false, 64)
	_poser(w, arcades_mesh(n, R, 7.2, 1.7, 0.16, OR_VIF * 0.9), mat_opaque_vc(), centre)
	mandala(w, etat, centre + Vector3(0, 9.8, 0), Vector3(90, 0, 0), 11.0, 631, pal, 1.2, 0.6)
	ciel_mandala(w, etat, pal2, 640)


static func monde_cite(w: Node3D, c1: Color, c2: Color, etat: Dictionary) -> void:
	var pal: Array = MandalaMoteur.palette_de(c1, c2)
	var pal2: Array = MandalaMoteur.palette_de(c2, c1)
	var centre: Vector3 = Vector3(0, 0, -3)
	mandala(w, etat, Vector3(0, 0.03, -3), Vector3(-90, 0, 0), 15.0, 651, pal, 1.4, 0.5)
	lueur(w, Vector3(0, 0.015, -3), 17.5, c1, 0.10, Vector3(-90, 0, 0))
	# Avenues radiales lumineuses.
	for i in 8:
		var a: float = TAU * (float(i) + 0.5) / 8.0
		var d: Vector3 = Vector3(cos(a), 0, sin(a))
		var o: Vector3 = d.cross(Vector3.UP).normalized() * 0.20
		var p: PackedVector3Array = PackedVector3Array([
			centre + d * 2.5 - o + Vector3(0, 0.04, 0), centre + d * 2.5 + o + Vector3(0, 0.04, 0),
			centre + d * 15.5 + o + Vector3(0, 0.04, 0), centre + d * 15.5 - o + Vector3(0, 0.04, 0)])
		var cc: Color = Color(c2.r, c2.g, c2.b, 0.55)
		quad_degrade(w, p[0], p[1], p[2], p[3], cc, cc, Color(c2.r, c2.g, c2.b, 0.0), Color(c2.r, c2.g, c2.b, 0.0)).material_override = MandalaMoteur.materiau()
	# Tours sur trois couronnes (MultiMesh) + lanternes.
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(1.0, 1.0, 1.0)
	var cm: CylinderMesh = CylinderMesh.new()
	cm.top_radius = 0.5
	cm.bottom_radius = 0.5
	cm.height = 1.0
	cm.radial_segments = 10
	var tf_t: Array = []
	var co_t: Array = []
	var tf_l: Array = []
	var co_l: Array = []
	var couronnes: Array = [[5.6, 8, 4.5], [9.2, 16, 5.8], [12.9, 24, 7.2]]
	var idx: int = 0
	for cr in couronnes:
		var r: float = float(cr[0])
		var nn: int = int(cr[1])
		var hmax: float = float(cr[2])
		for i in nn:
			var a: float = TAU * float(i) / float(nn)
			var h: float = hmax * (0.55 + 0.45 * absf(sin(float(i) * 1.7 + float(idx))))
			var larg: float = 0.9 + 0.5 * float(idx % 2)
			var pos: Vector3 = centre + Vector3(cos(a) * r, h * 0.5, sin(a) * r)
			var b: Basis = Basis(Vector3.UP, -a).scaled(Vector3(larg, h, larg))
			tf_t.append(Transform3D(b, pos))
			co_t.append((c1.darkened(0.55) if i % 2 == 0 else c2.darkened(0.6)))
			var bl: Basis = Basis(Vector3.UP, -a).scaled(Vector3(larg * 0.5, 0.35, larg * 0.5))
			tf_l.append(Transform3D(bl, pos + Vector3(0, h + 0.18, 0)))
			co_l.append(Color(c2.r, c2.g, c2.b, 0.9) if i % 2 == 0 else Color(c1.r, c1.g, c1.b, 0.9))
			idx += 1
	multi(w, bm, tf_t, co_t, "TourCite")
	multi(w, cm, tf_l, co_l, "LanterneCite", true)
	# Anneaux architecturaux qui ceinturent la ville.
	tore(w, centre + Vector3(0, 5.2, 0), 9.2, 0.10, c1, Vector3.ZERO, true, 64)
	tore(w, centre + Vector3(0, 7.6, 0), 12.9, 0.12, c2, Vector3.ZERO, true, 64)
	for k in 3:
		tore(w, centre + Vector3(0, 9.0, 0), 6.5 + float(k) * 0.9, 0.06, c1.lerp(c2, float(k) / 2.0), Vector3(62.0 + float(k) * 8.0, float(k) * 60.0, 0), true, 56)
	# Tour centrale : fut conique et pile de mandalas horizontaux.
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.9
	cone.height = 11.5
	cone.radial_segments = 14
	_poser(w, cone, mat(PIERRE * 2.2), centre + Vector3(0, 5.75, 0))
	for k in 3:
		mandala(w, etat, centre + Vector3(0, 5.2 + float(k) * 2.2, 0), Vector3(-90, 0, 0), 4.4 - float(k) * 1.2, 660 + k * 3, pal if k % 2 == 0 else pal2, 1.0, 1.4)
	ciel_mandala(w, etat, pal2, 670)


static func monde_portails(w: Node3D, c1: Color, c2: Color, etat: Dictionary) -> void:
	var pal: Array = MandalaMoteur.palette_de(c1, c2)
	var pal2: Array = MandalaMoteur.palette_de(c2, c1)
	var centre: Vector3 = Vector3(0, 0, -3)
	mandala(w, etat, Vector3(0, 0.03, -3), Vector3(-90, 0, 0), 8.5, 681, pal, 1.3, 0.7)
	lueur(w, Vector3(0, 0.015, -3), 10.0, c2, 0.12, Vector3(-90, 0, 0))
	# Relief geometrique : prismes hexagonaux de hauteurs variees autour de la clairiere.
	var hexm: CylinderMesh = CylinderMesh.new()
	hexm.top_radius = 0.82
	hexm.bottom_radius = 0.82
	hexm.height = 1.0
	hexm.radial_segments = 6
	var hexl: CylinderMesh = CylinderMesh.new()
	hexl.top_radius = 0.70
	hexl.bottom_radius = 0.70
	hexl.height = 1.0
	hexl.radial_segments = 6
	var tf: Array = []
	var co: Array = []
	var tf_l: Array = []
	var co_l: Array = []
	for q in range(-12, 13):
		for r in range(-12, 13):
			var x: float = (float(q) + float(r) * 0.5) * 1.45
			var z: float = float(r) * 1.255
			var d: float = Vector2(x, z).length()
			if d < 10.2 or d > 17.0:
				continue
			var h: float = 0.35 + 1.5 * (0.5 + 0.5 * sin(x * 0.55 + z * 0.37)) * (0.6 + 0.4 * sin(x * 0.21 - z * 0.43)) + (d - 10.0) * 0.12
			var pos: Vector3 = centre + Vector3(x, h * 0.5 - 0.1, z)
			tf.append(Transform3D(Basis().scaled(Vector3(1.0, h, 1.0)), pos))
			co.append(c1.darkened(0.62).lerp(c2.darkened(0.55), clampf(h / 3.0, 0.0, 1.0)))
			tf_l.append(Transform3D(Basis().scaled(Vector3(1.0, 0.05, 1.0)), pos + Vector3(0, h * 0.5 + 0.0, 0)))
			co_l.append(Color(c1.r, c1.g, c1.b, 0.55).lerp(Color(c2.r, c2.g, c2.b, 0.55), clampf(h / 3.0, 0.0, 1.0)))
	multi(w, hexm, tf, co, "ReliefHex")
	multi(w, hexl, tf_l, co_l, "ReliefHexLueur", true)
	# Six portails geants autour de la clairiere.
	var angles: Array = [40.0, 85.0, 130.0, 230.0, 275.0, 320.0]
	for i in angles.size():
		var a: float = deg_to_rad(float(angles[i]))
		var pos: Vector3 = centre + Vector3(sin(a), 0, cos(a)) * 13.2
		var dir: Vector3 = (centre - pos)
		dir.y = 0.0
		dir = dir.normalized()
		var yaw: float = atan2(dir.x, dir.z)
		var p: Node3D = Node3D.new()
		p.name = "PortailGeant%d" % i
		p.position = pos + Vector3(0, 4.6, 0)
		p.rotation.y = yaw
		w.add_child(p)
		var pp: Array = pal if i % 2 == 0 else pal2
		var m: Node3D = MandalaMoteur.noeud(690 + i * 7, pp, 3.9, 1.0, 1.0)
		p.add_child(m)
		(etat["mandalas"] as Array).append(m)
		tore(p, Vector3(0, 0, 0.05), 4.25, 0.14, OR_VIF, Vector3(90, 0, 0), false, 56)
		tore(p, Vector3(0, 0, 0.05), 4.6, 0.07, OR, Vector3(90, 0, 0), false, 56)
		boite(p, Vector3(-4.35, -2.3, 0.0), Vector3(0.5, 4.6, 0.5), PIERRE * 2.0)
		boite(p, Vector3(4.35, -2.3, 0.0), Vector3(0.5, 4.6, 0.5), PIERRE * 2.0)
		lueur(p, Vector3(0, 0, 0.1), 5.4, pp[1], 0.13, Vector3.ZERO)
	ciel_mandala(w, etat, pal2, 700)


# ================================================================ interactifs

static func embellir_interactifs(w: Node3D, etat: Dictionary, balises: Array, portail: Node3D, flottants: Array, c1: Color, c2: Color) -> void:
	var pal: Array = MandalaMoteur.palette_de(c1, c2)
	for i in balises.size():
		var b: Node3D = balises[i]
		var g: Node3D = armillaire(b, etat, Vector3.ZERO, 0.85, 900 + i * 11, pal)
		g.name = "Rosace"
	# Portail : rosace dans l'anneau, couronne monumentale derriere.
	var r: Node3D = MandalaMoteur.noeud(930, pal, 1.42, 1.0, 1.0)
	r.name = "Rosace"
	portail.add_child(r)
	var cr: Node3D = MandalaMoteur.noeud(931, MandalaMoteur.palette_de(c2, c1), 3.0, 0.9, 1.0)
	cr.name = "Couronne"
	cr.position.z = -0.08
	portail.add_child(cr)
	lueur(portail, Vector3(0, 0, 0.1), 3.8, c1, 0.14, Vector3.ZERO)
	for i in flottants.size():
		var f: Node3D = flottants[i]
		var m: Node3D = MandalaMoteur.noeud(940 + i, pal, 0.55, 0.5, 1.0)
		f.add_child(m)
		(etat["mandalas"] as Array).append(m)


## Balise activee : le mandala passe a l'or.
static func activer_balise(balise: Node3D) -> void:
	var g: Node3D = balise.get_node_or_null("Rosace") as Node3D
	if g == null:
		return
	var or_pal: Array = [Color(1.0, 0.72, 0.25), Color(1.0, 0.55, 0.2), Color(1.0, 0.85, 0.45), Color(1.0, 0.42, 0.25)]
	for k in 3:
		if k < g.get_child_count():
			var vieux: Node = g.get_child(k)
			if vieux is Node3D and vieux.name.begins_with("Mandala"):
				var nv: Node3D = MandalaMoteur.noeud(960 + k * 5, or_pal, 0.85, 0.7, 1.4)
				nv.rotation = (vieux as Node3D).rotation
				g.add_child(nv)
				vieux.queue_free()


# ================================================================ planetes

## Planete heroique : sphere a surface mandala, atmosphere, couronne de mandala inclinee.
static func planete(parent: Node3D, rayon: float, c1: Color, c2: Color, c3: Color, graine: int, inclinaison: float) -> Dictionary:
	var etat: Dictionary = {"mandalas": [], "tournants": []}
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = rayon
	sm.height = rayon * 2.0
	sm.radial_segments = 40
	sm.rings = 20
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load("res://shaders/planete_v60.gdshader")
	m.set_shader_parameter("c1", Vector3(c1.r, c1.g, c1.b))
	m.set_shader_parameter("c2", Vector3(c2.r, c2.g, c2.b))
	m.set_shader_parameter("c3", Vector3(c3.r, c3.g, c3.b))
	m.set_shader_parameter("graine", float(graine % 7))
	var corps: MeshInstance3D = _poser(parent, sm, m, Vector3.ZERO)
	corps.name = "CorpsPlanete"
	var sa: SphereMesh = SphereMesh.new()
	sa.radius = rayon * 1.12
	sa.height = rayon * 2.24
	sa.radial_segments = 32
	sa.rings = 16
	var ma: ShaderMaterial = ShaderMaterial.new()
	ma.shader = load("res://shaders/atmosphere_v60.gdshader")
	ma.set_shader_parameter("couleur", Vector3(c3.r, c3.g, c3.b))
	var atm: MeshInstance3D = _poser(parent, sa, ma, Vector3.ZERO)
	atm.name = "Atmosphere"
	var anneau: Node3D = MandalaMoteur.noeud(graine, [c1, c2, c3], rayon * 2.15, 0.6, 1.0)
	anneau.name = "CouronneMandala"
	anneau.rotation_degrees = Vector3(90.0 - inclinaison, 0.0, 0.0)
	parent.add_child(anneau)
	(etat["mandalas"] as Array).append(anneau)
	corps.set_meta("tourne", true)
	return etat
