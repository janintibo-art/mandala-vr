class_name MandalaMoteur
extends RefCounted
## Mandala VR v60 : moteur de mandalas complexes, reutilisable.
##
## Compose un vrai mandala en couches (centre, anneaux, petales, pointes, perles,
## arches de dentelle, cercles secondaires, etoiles, rayons, losanges, halos) dans un
## disque de rayon 1, dans le plan XY, face a +Z. Les couches sont regroupees en
## quatre maillages (halo fixe + 3 groupes qui tournent a des vitesses differentes).
## Le meme moteur sert aux toiles du musee, aux sols, aux plafonds, aux portails,
## aux monuments et aux planetes.
##
## Usage :
##   var m: Node3D = MandalaMoteur.noeud(graine, [couleurs...], rayon)
##   (chaque image) MandalaMoteur.animer(m, dt)

static var _cache: Dictionary = {}
static var _materiau: StandardMaterial3D = null


## Pinceau : accumule des triangles colores (couleur par sommet, melange additif).
class Pinceau:
	var p: PackedVector3Array = PackedVector3Array()
	var c: PackedColorArray = PackedColorArray()
	var idx: PackedInt32Array = PackedInt32Array()

	func s(v: Vector2, col: Color) -> int:
		p.append(Vector3(v.x, v.y, 0.0))
		c.append(col)
		return p.size() - 1

	func tri(a: Vector2, b: Vector2, d: Vector2, ca: Color, cb: Color, cd: Color) -> void:
		var k: int = s(a, ca)
		s(b, cb)
		s(d, cd)
		idx.append(k)
		idx.append(k + 1)
		idx.append(k + 2)

	func quad(a: Vector2, b: Vector2, d: Vector2, e: Vector2, ca: Color, cb: Color, cd: Color, ce: Color) -> void:
		var k: int = s(a, ca)
		s(b, cb)
		s(d, cd)
		s(e, ce)
		idx.append(k)
		idx.append(k + 1)
		idx.append(k + 2)
		idx.append(k)
		idx.append(k + 2)
		idx.append(k + 3)

	func ligne(a: Vector2, b: Vector2, w: float, ca: Color, cb: Color) -> void:
		var d: Vector2 = b - a
		if d.length() < 0.00001:
			return
		var n: Vector2 = d.normalized().orthogonal() * (w * 0.5)
		quad(a - n, a + n, b + n, b - n, ca, ca, cb, cb)

	func polyligne(pts: PackedVector2Array, w: float, c0: Color, c1: Color, ferme: bool = false) -> void:
		var n: int = pts.size()
		var m: int = n if ferme else n - 1
		for i in m:
			var u0: float = float(i) / float(maxi(m, 1))
			var u1: float = float(i + 1) / float(maxi(m, 1))
			ligne(pts[i], pts[(i + 1) % n], w, c0.lerp(c1, u0), c0.lerp(c1, u1))

	func disque(ctr: Vector2, r: float, c_ctr: Color, c_bord: Color, seg: int = 14) -> void:
		var k0: int = s(ctr, c_ctr)
		for i in seg:
			var a: float = TAU * float(i) / float(seg)
			s(ctr + Vector2(cos(a), sin(a)) * r, c_bord)
		for i in seg:
			idx.append(k0)
			idx.append(k0 + 1 + i)
			idx.append(k0 + 1 + (i + 1) % seg)

	func anneau(r0: float, r1: float, c_in: Color, c_out: Color, seg: int = 64, a0: float = 0.0, a1: float = TAU) -> void:
		var k0: int = p.size()
		for i in seg + 1:
			var a: float = a0 + (a1 - a0) * float(i) / float(seg)
			var d: Vector2 = Vector2(cos(a), sin(a))
			s(d * r0, c_in)
			s(d * r1, c_out)
		for i in seg:
			var k: int = k0 + i * 2
			idx.append(k)
			idx.append(k + 1)
			idx.append(k + 3)
			idx.append(k)
			idx.append(k + 3)
			idx.append(k + 2)

	func cercle(ctr: Vector2, r: float, w: float, col: Color, seg: int = 28) -> void:
		var pts: PackedVector2Array = PackedVector2Array()
		for i in seg:
			var a: float = TAU * float(i) / float(seg)
			pts.append(ctr + Vector2(cos(a), sin(a)) * r)
		polyligne(pts, w, col, col, true)

	func fabriquer() -> ArrayMesh:
		var m: ArrayMesh = ArrayMesh.new()
		if p.size() == 0:
			return m
		var a: Array = []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = p
		a[Mesh.ARRAY_COLOR] = c
		a[Mesh.ARRAY_INDEX] = idx
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		m.custom_aabb = AABB(Vector3(-1.3, -1.3, -0.1), Vector3(2.6, 2.6, 0.2))
		return m


# ---------------------------------------------------------------- outils

static func materiau() -> StandardMaterial3D:
	if _materiau == null:
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.disable_fog = true
		m.albedo_color = Color(1, 1, 1, 1)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_materiau = m
	return _materiau


## Couleur de la palette a la position t (0..1), interpolee.
static func _pal(pal: Array, t: float) -> Color:
	if pal.is_empty():
		return Color(0.6, 0.7, 1.0)
	var u: float = clampf(t, 0.0, 0.9999) * float(pal.size() - 1)
	var i: int = int(u)
	return (pal[i] as Color).lerp(pal[mini(i + 1, pal.size() - 1)] as Color, u - float(i))


## Couleur adoucie : evite que les superpositions additives virent au blanc.
static func _k(col: Color, a: float, lum: float = 0.82) -> Color:
	return Color(col.r * lum, col.g * lum, col.b * lum, a)


static func _pol(r: float, a: float) -> Vector2:
	return Vector2(cos(a), sin(a)) * r


# ---------------------------------------------------------------- motifs (bandes)

## Petales pleins en degrade, avec nervure centrale et contour fin.
static func _petales(pb: Pinceau, r0: float, r1: float, n: int, larg: float, ci: Color, co: Color, rot: float, pointu: float, det: float) -> void:
	var m: int = maxi(5, int(8.0 * det))
	for k in n:
		var a: float = rot + TAU * float(k) / float(n)
		var dir: Vector2 = _pol(1.0, a)
		var perp: Vector2 = dir.orthogonal()
		var gauche: PackedVector2Array = PackedVector2Array()
		var droite: PackedVector2Array = PackedVector2Array()
		var axe: PackedVector2Array = PackedVector2Array()
		for j in m + 1:
			var t: float = float(j) / float(m)
			var r: float = lerpf(r0, r1, t)
			var w: float = larg * sin(PI * pow(t, pointu)) * 0.5
			axe.append(dir * r)
			gauche.append(dir * r + perp * w)
			droite.append(dir * r - perp * w)
		for j in m:
			var t0: float = float(j) / float(m)
			var t1: float = float(j + 1) / float(m)
			var cA: Color = ci.lerp(co, t0)
			var cB: Color = ci.lerp(co, t1)
			var f0: Color = _k(cA, 0.30)
			var f1: Color = _k(cB, 0.30)
			pb.quad(gauche[j], gauche[j + 1], axe[j + 1], axe[j], f0, f1, _k(cB, 0.55), _k(cA, 0.55))
			pb.quad(axe[j], axe[j + 1], droite[j + 1], droite[j], _k(cA, 0.55), _k(cB, 0.55), f1, f0)
		pb.polyligne(gauche, 0.0045, _k(ci, 0.95, 1.0), _k(co, 0.95, 1.0))
		pb.polyligne(droite, 0.0045, _k(ci, 0.95, 1.0), _k(co, 0.95, 1.0))
		pb.polyligne(axe, 0.003, _k(ci, 0.7, 1.0), _k(co, 0.7, 1.0))


static func _pointes(pb: Pinceau, r0: float, r1: float, n: int, larg: float, ci: Color, co: Color, rot: float, inverse: bool) -> void:
	for k in n:
		var a: float = rot + TAU * float(k) / float(n)
		var dir: Vector2 = _pol(1.0, a)
		var perp: Vector2 = dir.orthogonal()
		var base: float = r1 if inverse else r0
		var pointe: float = r0 if inverse else r1
		var b1: Vector2 = dir * base + perp * larg * 0.5
		var b2: Vector2 = dir * base - perp * larg * 0.5
		var sommet: Vector2 = dir * pointe
		pb.tri(b1, b2, sommet, _k(ci, 0.18), _k(ci, 0.18), _k(co, 0.7))
		pb.ligne(b1, sommet, 0.004, _k(ci, 0.9, 1.0), _k(co, 0.9, 1.0))
		pb.ligne(b2, sommet, 0.004, _k(ci, 0.9, 1.0), _k(co, 0.9, 1.0))


static func _perles(pb: Pinceau, r: float, n: int, rad: float, col: Color, rot: float, col2: Color) -> void:
	for k in n:
		var a: float = rot + TAU * float(k) / float(n)
		var c: Vector2 = _pol(r, a)
		pb.disque(c, rad, _k(col2, 1.0, 1.0), _k(col, 0.55), 10)
		pb.cercle(c, rad * 1.45, 0.003, _k(col, 0.5, 1.0), 14)


## Arches festonnees : chaque arc relie deux points voisins en se soulevant (dentelle).
static func _arches(pb: Pinceau, r0: float, r1: float, n: int, ci: Color, co: Color, rot: float, det: float) -> void:
	var m: int = maxi(6, int(10.0 * det))
	for k in n:
		var a0: float = rot + TAU * float(k) / float(n)
		var da: float = TAU / float(n)
		var ext: PackedVector2Array = PackedVector2Array()
		var inte: PackedVector2Array = PackedVector2Array()
		for j in m + 1:
			var s: float = float(j) / float(m)
			var bump: float = pow(sin(PI * s), 0.72)
			ext.append(_pol(lerpf(r0, r1, bump), a0 + da * s))
			inte.append(_pol(lerpf(r0, r0 + (r1 - r0) * 0.55, bump), a0 + da * s))
		pb.polyligne(ext, 0.006, _k(ci, 0.95, 1.0), _k(co, 0.95, 1.0))
		pb.polyligne(inte, 0.004, _k(ci, 0.6, 1.0), _k(co, 0.6, 1.0))
		for j in m:
			pb.quad(ext[j], ext[j + 1], inte[j + 1], inte[j], _k(co, 0.22), _k(co, 0.22), _k(ci, 0.08), _k(ci, 0.08))


## Cercles secondaires poses sur un anneau : ils se recouvrent comme une fleur de vie.
static func _cercles(pb: Pinceau, r: float, n: int, rc: float, ci: Color, co: Color, rot: float, det: float) -> void:
	var seg: int = maxi(14, int(26.0 * det))
	for k in n:
		var a: float = rot + TAU * float(k) / float(n)
		var c: Vector2 = _pol(r, a)
		pb.cercle(c, rc, 0.0055, _k(ci.lerp(co, float(k % 2)), 0.9, 1.0), seg)
		pb.disque(c, rc * 0.16, _k(co, 0.9, 1.0), _k(co, 0.25), 8)


static func _etoile(pb: Pinceau, r: float, n: int, saut: int, w: float, ci: Color, co: Color, rot: float) -> void:
	for k in n:
		var a: Vector2 = _pol(r, rot + TAU * float(k) / float(n))
		var b: Vector2 = _pol(r, rot + TAU * float((k + saut) % n) / float(n))
		pb.ligne(a, b, w, _k(ci, 0.85, 1.0), _k(co, 0.85, 1.0))


static func _rayons(pb: Pinceau, r0: float, r1: float, n: int, w: float, ci: Color, co: Color, rot: float) -> void:
	for k in n:
		var d: Vector2 = _pol(1.0, rot + TAU * float(k) / float(n))
		pb.ligne(d * r0, d * r1, w, _k(ci, 0.9, 1.0), _k(co, 0.05, 1.0))


static func _fil(pb: Pinceau, r: float, w: float, col: Color, seg: int = 96) -> void:
	pb.cercle(Vector2.ZERO, r, w, col, seg)


## Dents de scie : deux rangs de triangles entrelaces.
static func _dentelle(pb: Pinceau, r0: float, r1: float, n: int, ci: Color, co: Color, rot: float) -> void:
	for k in n:
		var a: float = rot + TAU * float(k) / float(n)
		var da: float = TAU / float(n)
		pb.tri(_pol(r0, a), _pol(r0, a + da), _pol(r1, a + da * 0.5), _k(ci, 0.3), _k(ci, 0.3), _k(co, 0.8))
		pb.tri(_pol(r1, a), _pol(r1, a + da), _pol(r0 + (r1 - r0) * 0.45, a + da * 0.5), _k(co, 0.14), _k(co, 0.14), _k(ci, 0.5))


static func _losanges(pb: Pinceau, r: float, n: int, taille: float, ci: Color, co: Color, rot: float) -> void:
	for k in n:
		var a: float = rot + TAU * float(k) / float(n)
		var c: Vector2 = _pol(r, a)
		var d: Vector2 = _pol(1.0, a)
		var o: Vector2 = d.orthogonal()
		var h: Vector2 = d * taille
		var l: Vector2 = o * taille * 0.62
		pb.quad(c - h, c + l, c + h, c - l, _k(ci, 0.7), _k(co, 0.25), _k(ci, 0.7), _k(co, 0.25))
		pb.polyligne(PackedVector2Array([c - h, c + l, c + h, c - l]), 0.0042, _k(ci, 0.95, 1.0), _k(co, 0.95, 1.0), true)


## Coeur : lueur, deux couronnes de petales decalees, etoile, noyau brillant.
static func _centre(pb: Pinceau, r: float, n: int, pal: Array, rot: float, det: float) -> void:
	var c0: Color = _pal(pal, 0.0)
	var c1: Color = _pal(pal, 0.4)
	var c2: Color = _pal(pal, 0.8)
	pb.disque(Vector2.ZERO, r * 1.05, _k(c1, 0.40), _k(c0, 0.0), 24)
	_petales(pb, r * 0.12, r, n, r * 0.85, c0.darkened(0.2), c1.darkened(0.15), rot, 0.85, det)
	_petales(pb, r * 0.10, r * 0.62, n, r * 0.60, c2.darkened(0.2), c1.darkened(0.2), rot + PI / float(n), 0.9, det)
	_etoile(pb, r * 0.46, n, maxi(2, n / 4), 0.004, c2, c0, rot)
	pb.disque(Vector2.ZERO, r * 0.18, _k(c2.lightened(0.35), 0.95, 1.0), _k(c2, 0.4), 14)
	pb.cercle(Vector2.ZERO, r * 0.26, 0.005, _k(c2, 0.95, 1.0), 20)


# ---------------------------------------------------------------- composition

## Construit les quatre maillages d'un mandala. Retourne [{mesh, vitesse}, ...].
## graine : meme graine + meme palette = meme mandala. detail : 0.5 (leger) a 1.5 (riche).
static func composer(graine: int, pal: Array, detail: float = 1.0) -> Array:
	var cle: String = "%d|%d|%.2f" % [graine, hash(str(pal)), detail]
	if _cache.has(cle):
		return _cache[cle]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = graine * 7919 + 17
	var det: float = detail
	var tailles: Array = [8, 12, 12, 16, 16, 24]
	var n: int = int(tailles[rng.randi() % tailles.size()])

	var halo: Pinceau = Pinceau.new()
	var g_in: Pinceau = Pinceau.new()
	var g_mid: Pinceau = Pinceau.new()
	var g_out: Pinceau = Pinceau.new()
	var groupes: Array = [g_in, g_mid, g_out]

	var ca: Color = _pal(pal, 0.0)
	var cb: Color = _pal(pal, 0.5)
	var cc: Color = _pal(pal, 1.0)

	# Halo fixe : lueur douce + cadre fin avec graduation.
	halo.disque(Vector2.ZERO, 1.12, _k(cb, 0.16), _k(ca, 0.0), 40)
	halo.anneau(0.90, 1.16, _k(ca, 0.0), _k(cc, 0.16), 72)
	_fil(halo, 0.992, 0.006, _k(cc, 0.95, 1.0))
	_fil(halo, 1.030, 0.0035, _k(ca, 0.8, 1.0))
	_fil(halo, 1.075, 0.0030, _k(cb, 0.55, 1.0))
	for k in 96:
		var a: float = TAU * float(k) / 96.0
		var l: float = 0.030 if k % 4 == 0 else 0.016
		halo.ligne(_pol(1.04, a), _pol(1.04 + l, a), 0.004, _k(cc, 0.8, 1.0), _k(cc, 0.5, 1.0))

	# Centre (groupe interieur).
	var r_centre: float = 0.20 + rng.randf() * 0.04
	_centre(g_in, r_centre, n, pal, rng.randf() * TAU, det)

	# Bandes de motifs, du centre vers le bord.
	var nb: int = 7 + rng.randi() % 3
	var bords: Array = [r_centre + 0.02]
	var reste: float = 0.965 - float(bords[0])
	var poids: Array = []
	var somme: float = 0.0
	for i in nb:
		var w: float = 0.7 + rng.randf() * 0.9
		poids.append(w)
		somme += w
	for i in nb:
		bords.append(float(bords[i]) + reste * float(poids[i]) / somme)

	var types: Array = ["petales", "pointes", "perles", "arches", "cercles", "dentelle", "losanges", "rayons", "petales", "arches"]
	var dernier: String = ""
	for i in nb:
		var r0: float = float(bords[i])
		var r1: float = float(bords[i + 1])
		var u: float = float(i) / float(nb)
		var g: Pinceau = groupes[0 if r1 < 0.40 else (1 if r1 < 0.72 else 2)]
		var ci: Color = _pal(pal, u)
		var co: Color = _pal(pal, minf(1.0, u + 0.22))
		var rot: float = rng.randf() * TAU
		var t: String = str(types[rng.randi() % types.size()])
		if t == dernier:
			t = str(types[(rng.randi() + 3) % types.size()])
		dernier = t
		var nn: int = n * (2 if (r0 > 0.55 and rng.randf() < 0.55) else 1)
		var mid: float = (r0 + r1) * 0.5
		var ep: float = r1 - r0
		match t:
			"petales":
				_petales(g, r0, r1, nn, minf(TAU * mid / float(nn) * 1.05, ep * 2.4), ci, co, rot, 0.8 + rng.randf() * 0.5, det)
			"pointes":
				_pointes(g, r0, r1, nn, TAU * r0 / float(nn) * 0.95, ci, co, rot, rng.randf() < 0.4)
			"perles":
				var rad: float = minf(ep * 0.34, TAU * mid / float(nn) * 0.26)
				_perles(g, mid, nn, rad, ci, rot, co)
			"arches":
				_arches(g, r0, r1, nn, ci, co, rot, det)
			"cercles":
				_cercles(g, mid, nn, minf(ep * 0.62, TAU * mid / float(nn) * 0.55), ci, co, rot, det)
			"dentelle":
				_dentelle(g, r0, r1, nn * 2, ci, co, rot)
			"losanges":
				_losanges(g, mid, nn, minf(ep * 0.55, TAU * mid / float(nn) * 0.5), ci, co, rot)
			_:
				_rayons(g, r0, r1, nn * 2, 0.0045, ci, co, rot)
		# Fil de separation entre deux bandes.
		_fil(g, r1, 0.0042, _k(co, 0.8, 1.0), int(72.0 * det) + 24)

	# Superpositions : etoile polygonale dans le groupe moyen, couronne decalee a l'exterieur.
	var saut: int = 3 + rng.randi() % 2
	if n % saut == 0:
		saut += 1
	_etoile(g_mid, 0.70, n, saut, 0.0042, cb, ca, rng.randf() * TAU)
	_petales(g_out, 0.84, 0.985, n, TAU * 0.9 / float(n), _pal(pal, 0.9), _pal(pal, 1.0), PI / float(n), 1.1, det)

	var v1: float = 0.28 + rng.randf() * 0.22
	var v2: float = 0.10 + rng.randf() * 0.12
	var v3: float = 0.035 + rng.randf() * 0.05
	var signe: float = -1.0 if rng.randf() < 0.5 else 1.0
	var res: Array = [
		{"mesh": halo.fabriquer(), "vitesse": 0.0},
		{"mesh": g_in.fabriquer(), "vitesse": v1 * signe},
		{"mesh": g_mid.fabriquer(), "vitesse": -v2 * signe},
		{"mesh": g_out.fabriquer(), "vitesse": v3 * signe},
	]
	_cache[cle] = res
	return res


## Noeud pret a poser dans la scene. Les couches tournent via animer().
static func noeud(graine: int, pal: Array, rayon: float = 1.0, detail: float = 1.0, vitesse: float = 1.0) -> Node3D:
	var racine: Node3D = Node3D.new()
	racine.name = "Mandala"
	var couches: Array = composer(graine, pal, detail)
	for i in couches.size():
		var d: Dictionary = couches[i]
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "Couche%d" % i
		mi.mesh = d["mesh"]
		mi.material_override = materiau()
		mi.scale = Vector3.ONE * rayon
		mi.position.z = float(i) * 0.0015 * rayon
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("vit", float(d["vitesse"]) * vitesse)
		racine.add_child(mi)
	return racine


static func animer(n: Node3D, dt: float) -> void:
	if n == null:
		return
	for c in n.get_children():
		if c.has_meta("vit"):
			(c as Node3D).rotation.z += float(c.get_meta("vit")) * dt


## Palette de couleurs saturees mais pas blanchatres a partir de deux teintes.
static func palette_de(c1: Color, c2: Color) -> Array:
	var p1: Color = c1.lerp(c2, 0.5)
	return [c1.darkened(0.1), p1, c2, c2.lerp(c1, 0.65).lightened(0.05), c1.lightened(0.12)]
