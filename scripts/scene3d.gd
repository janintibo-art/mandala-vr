class_name Scene3D
extends Node3D
## Le monde du mandala : trois calques (pivots), construction parallele des
## maillages, trace en direct, relief, mouvements, effets lumineux.

const PX: float = Tables.PX
const RM: float = Tables.RM

var traits: Array = []
var pivots: Array = []

var rel_mode: int = 0
var rel_h: float = 0.55
var rel_lum: float = 0.6
var fond: int = 0
var mouvement: int = 0
var vitesse: float = 1.0
var temps: float = 0.0
var lumineux: bool = true
var anime: bool = true
var budget: int = 90000
var fx: Dictionary = {"gain": 0.55, "halo": 0.5, "coeur": 0.4, "scint": 0.0, "pulse": 0.0, "arc": 0.0, "vit": 1.0}

var ciel: bool = false
var dome: float = 0.0
var dome_cible: float = 0.0
var dome_ang: float = 1.9
var dome_r: float = 7.0
var dome_c: Vector3 = Vector3(0.0, 1.6, 0.0)
var dome_b: Basis = Basis()

var reduction_boucle: float = 0.62
var torsion_boucle: float = 0.35

var m_ruban_add: ShaderMaterial
var m_ruban_mix: ShaderMaterial
var m_disque_add: ShaderMaterial
var m_disque_mix: ShaderMaterial

var occupe: bool = false
var derniere_stat: String = ""
var couverture: float = 0.0
var adapt: float = 1.0
var _relancer: bool = false
var _phase: int = 0
var _groupe: int = -1
var _snap: Array = []
var _res: Array = []
var _sonde: PackedFloat32Array = PackedFloat32Array()
var _stride: int = 1
var _par: Dictionary = {}
var _file: Array = []
var _nouveaux: Array = []
var _differe_chrono: float = -1.0
var _apres: Array = []

var _live_t: TraitDessin = null
var _live_p: Peintre = null
var _live_acc: Dictionary = {}
var _live_node: MeshInstance3D = null
var _live_dirty: bool = false
var _live_chrono: float = 0.0
var _live_prims: int = 0


func _ready() -> void:
	for i in 3:
		var p: Node3D = Node3D.new()
		add_child(p)
		pivots.append(p)
	m_ruban_add = _materiel("res://shaders/ruban_add.gdshader")
	m_ruban_mix = _materiel("res://shaders/ruban_mix.gdshader")
	m_disque_add = _materiel("res://shaders/disque_add.gdshader")
	m_disque_mix = _materiel("res://shaders/disque_mix.gdshader")
	appliquer_fx()


func _exit_tree() -> void:
	if _groupe >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_groupe)
		_groupe = -1


func _materiel(chemin: String) -> ShaderMaterial:
	var m: ShaderMaterial = ShaderMaterial.new()
	m.shader = load(chemin)
	return m


# ------------------------------------------------------------- apparence

func fond_clair() -> bool:
	var c: Color = Tables.FONDS[clampi(fond, 0, Tables.FONDS.size() - 1)]
	return c.get_luminance() > 0.45


func additif() -> bool:
	return lumineux and (ciel or not fond_clair())


func _maj_adapt() -> void:
	adapt = clampf(1.0 / (1.0 + 0.55 * couverture), 0.05, 1.0)
	appliquer_fx()


func appliquer_fx() -> void:
	for m in [m_ruban_add, m_ruban_mix, m_disque_add, m_disque_mix]:
		var sm: ShaderMaterial = m
		if sm == null:
			continue
		sm.set_shader_parameter("gain", float(fx["gain"]))
		sm.set_shader_parameter("adapt", adapt)
		sm.set_shader_parameter("dome", dome)
		sm.set_shader_parameter("dome_c", dome_c)
		sm.set_shader_parameter("dome_r", dome_r)
		sm.set_shader_parameter("dome_ang", dome_ang)
		sm.set_shader_parameter("dome_b", dome_b)
		sm.set_shader_parameter("halo", float(fx["halo"]))
		sm.set_shader_parameter("coeur", float(fx["coeur"]))
		sm.set_shader_parameter("scint", float(fx["scint"]))
		sm.set_shader_parameter("pulse", float(fx["pulse"]))
		sm.set_shader_parameter("arc", float(fx["arc"]))
		sm.set_shader_parameter("vitesse_fx", float(fx["vit"]))


func appliquer_fond(env: Environment) -> void:
	env.background_mode = Environment.BG_COLOR
	env.background_color = Tables.FONDS[clampi(fond, 0, Tables.FONDS.size() - 1)]
	appliquer_materiaux()


func appliquer_materiaux() -> void:
	for t in traits:
		var td: TraitDessin = t
		if td.noeud != null:
			_mat_noeud(td.noeud)
	if _live_node != null:
		_mat_noeud(_live_node)


func _mat_noeud(nd: MeshInstance3D) -> void:
	var m: ArrayMesh = nd.mesh as ArrayMesh
	if m == null:
		return
	var add: bool = additif()
	var sr: int = int(nd.get_meta("sr", -1))
	var sd: int = int(nd.get_meta("sd", -1))
	if sr >= 0:
		m.surface_set_material(sr, m_ruban_add if add else m_ruban_mix)
	if sd >= 0:
		m.surface_set_material(sd, m_disque_add if add else m_disque_mix)


func peintre_neuf() -> Peintre:
	var p: Peintre = Peintre.new()
	p.rm = RM
	p.demi_h = RM
	p.rel_mode = rel_mode
	p.rel_h = rel_h
	p.rel_lum = rel_lum
	return p


func _mesh_de(d: Dictionary, nd: MeshInstance3D) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	_remplir(mesh, d, nd)
	mesh.custom_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
	return mesh


func _remplir(mesh: ArrayMesh, d: Dictionary, nd: MeshInstance3D) -> void:
	var s: int = 0
	nd.set_meta("sr", -1)
	nd.set_meta("sd", -1)
	if (d["ri"] as PackedInt32Array).size() > 0:
		var a: Array = []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = d["rv"]
		a[Mesh.ARRAY_NORMAL] = d["rn"]
		a[Mesh.ARRAY_TEX_UV] = d["ruv"]
		a[Mesh.ARRAY_COLOR] = d["rc"]
		a[Mesh.ARRAY_INDEX] = d["ri"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
		nd.set_meta("sr", s)
		s += 1
	if (d["di"] as PackedInt32Array).size() > 0:
		var b: Array = []
		b.resize(Mesh.ARRAY_MAX)
		b[Mesh.ARRAY_VERTEX] = d["dv"]
		b[Mesh.ARRAY_TEX_UV] = d["duv"]
		b[Mesh.ARRAY_TEX_UV2] = d["duv2"]
		b[Mesh.ARRAY_COLOR] = d["dc"]
		b[Mesh.ARRAY_INDEX] = d["di"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, b)
		nd.set_meta("sd", s)
	_mat_noeud(nd)


func _nouveau_noeud(calque: int, d: Dictionary) -> MeshInstance3D:
	var nd: MeshInstance3D = MeshInstance3D.new()
	nd.mesh = _mesh_de(d, nd)
	nd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	nd.extra_cull_margin = 100.0
	(pivots[clampi(calque, 0, 2)] as Node3D).add_child(nd)
	_mat_noeud(nd)
	return nd


# ------------------------------------------------------------ construction

func bande(dist_px: float) -> int:
	var u: float = clampf(dist_px / RM, 0.0, 0.999)
	return clampi(int(floorf(u * 3.0)), 0, 2)


func vider() -> void:
	if occupe:
		_annuler_construction()
	_fin_live_sans_garder()
	for t in traits:
		var td: TraitDessin = t
		if td.noeud != null:
			td.noeud.queue_free()
			td.noeud = null
	traits.clear()


func _annuler_construction() -> void:
	if _groupe >= 0:
		WorkerThreadPool.wait_for_group_task_completion(_groupe)
		_groupe = -1
	for nd in _nouveaux:
		if nd != null:
			(nd as Node).queue_free()
	_nouveaux = []
	_snap = []
	_res = []
	_file = []
	occupe = false
	_relancer = false
	_phase = 0


func installer(nouveaux: Array) -> void:
	vider()
	for t in nouveaux:
		var td: TraitDessin = t
		td.calque = bande(td.points[0].length()) if td.calque < 0 else td.calque
		traits.append(td)
	demander_rec()


func demander_rec_differe(delai: float = 0.25) -> void:
	_differe_chrono = delai


func demander_rec() -> void:
	_differe_chrono = -1.0
	if traits.is_empty():
		return
	if occupe:
		_relancer = true
		return
	_lancer()


func apres_construction(f: Callable) -> void:
	if occupe:
		_apres.append(f)
	else:
		f.call()


func _lancer() -> void:
	occupe = true
	_relancer = false
	_snap = traits.duplicate()
	_par = {"rel_mode": rel_mode, "rel_h": rel_h, "rel_lum": rel_lum}
	_phase = 1
	_sonde = PackedFloat32Array()
	_sonde.resize(_snap.size())
	_groupe = WorkerThreadPool.add_group_task(_tache_prep, _snap.size(), -1, false, "mandala prep")


func _tache_prep(i: int) -> void:
	var t: TraitDessin = _snap[i]
	Peintre.preparer(t)
	var p: Peintre = Peintre.new()
	p.rm = RM
	p.demi_h = RM
	p.rel_mode = int(_par["rel_mode"])
	p.rel_h = float(_par["rel_h"])
	p.rel_lum = float(_par["rel_lum"])
	var n: int = Peintre.points_effectifs(t).size()
	var pas: int = maxi(1, n / 14)
	var vus: int = 0
	var i2: int = pas
	while i2 < n:
		vus += 1
		i2 += pas
	p.dessine_plage(t, 1, n, pas)
	var np: int = Peintre.nb_prims(p.sortie())
	_sonde[i] = float(np) * float(maxi(n - 1, 1)) / float(maxi(vus, 1))


func _tache_dessin(i: int) -> void:
	var t: TraitDessin = _snap[i]
	var p: Peintre = Peintre.new()
	p.rm = RM
	p.demi_h = RM
	p.rel_mode = int(_par["rel_mode"])
	p.rel_h = float(_par["rel_h"])
	p.rel_lum = float(_par["rel_lum"])
	var n: int = Peintre.points_effectifs(t).size()
	p.dessine_plage(t, 1, n, _stride)
	_res[i] = p.sortie()


func _lancer_dessin() -> void:
	var cout: float = 0.0
	for v in _sonde:
		cout += v
	_stride = maxi(1, ceili(cout / float(budget)))
	_res = []
	_res.resize(_snap.size())
	_phase = 2
	_groupe = WorkerThreadPool.add_group_task(_tache_dessin, _snap.size(), -1, false, "mandala dessin")


func _suivi_construction() -> void:
	if not occupe:
		return
	if _phase == 1:
		if WorkerThreadPool.is_group_task_completed(_groupe):
			WorkerThreadPool.wait_for_group_task_completion(_groupe)
			_groupe = -1
			_lancer_dessin()
		return
	if _phase == 2:
		if WorkerThreadPool.is_group_task_completed(_groupe):
			WorkerThreadPool.wait_for_group_task_completion(_groupe)
			_groupe = -1
			var total: int = 0
			for r in _res:
				total += Peintre.nb_prims(r as Dictionary)
			if total > int(float(budget) * 1.5) and _stride < 200:
				_stride = maxi(_stride + 1, ceili(float(_stride) * float(total) / float(budget)))
				_res = []
				_res.resize(_snap.size())
				_groupe = WorkerThreadPool.add_group_task(_tache_dessin, _snap.size(), -1, false, "mandala dessin")
				return
			var aire_tot: float = 0.0
			for r2 in _res:
				aire_tot += float((r2 as Dictionary).get("aire", 0.0))
			couverture = aire_tot / (PI * RM * PX * RM * PX)
			derniere_stat = "%d elements, pas %d, couv %.2f" % [total, _stride, couverture]
			_maj_adapt()
			_nouveaux = []
			_file = []
			for i in _snap.size():
				_nouveaux.append(null)
				_file.append(i)
			_phase = 3
		return
	if _phase == 3:
		var k: int = 0
		while k < 3 and not _file.is_empty():
			var i: int = int(_file.pop_front())
			var t: TraitDessin = _snap[i]
			var d: Dictionary = _res[i]
			if Peintre.nb_prims(d) > 0:
				var nd: MeshInstance3D = _nouveau_noeud(t.calque, d)
				nd.visible = false
				_nouveaux[i] = nd
			_res[i] = null
			k += 1
		if _file.is_empty():
			_finir()


func _finir() -> void:
	for i in _snap.size():
		var t: TraitDessin = _snap[i]
		if t.noeud != null:
			t.noeud.queue_free()
		t.noeud = _nouveaux[i]
		if t.noeud != null:
			t.noeud.visible = true
	_nouveaux = []
	_snap = []
	_res = []
	occupe = false
	_phase = 0
	var fns: Array = _apres.duplicate()
	_apres.clear()
	for f in fns:
		(f as Callable).call()
	if _relancer and not occupe:
		demander_rec()


# --------------------------------------------------------------- trace live

func live_actif() -> bool:
	return _live_t != null


func live_debut(reg: Reglages, calque: int) -> void:
	_live_t = TraitDessin.new(reg, traits.size())
	_live_t.calque = calque
	_live_p = peintre_neuf()
	_live_acc = Peintre.sortie_vide()
	_live_prims = 0
	_live_node = _nouveau_noeud(calque, _live_acc)


func live_point(p: Vector2) -> void:
	if _live_t == null:
		return
	var n: int = _live_t.points.size()
	if n > 0 and p.distance_to(_live_t.points[n - 1]) < 7.0:
		return
	if n >= 1600 or _live_prims > 70000:
		return
	_live_t.ajouter(p)
	if n > 0:
		_live_p.vider_sortie()
		_live_p.dessine_plage(_live_t, n, n + 1, 1)
		var s: Dictionary = _live_p.sortie()
		_live_prims += Peintre.nb_prims(s)
		Peintre.fusionner(_live_acc, s)
		_live_dirty = true


func _maj_live(forcer: bool) -> void:
	if not _live_dirty or _live_node == null:
		return
	if not forcer and _live_chrono < 0.1:
		return
	_live_chrono = 0.0
	_live_dirty = false
	var m: ArrayMesh = _live_node.mesh as ArrayMesh
	m.clear_surfaces()
	_remplir(m, _live_acc, _live_node)


func _fin_live_sans_garder() -> void:
	if _live_node != null:
		_live_node.queue_free()
	_live_node = null
	_live_t = null
	_live_p = null
	_live_acc = {}


func live_fin() -> void:
	if _live_t == null:
		return
	_maj_live(true)
	if _live_t.points.size() < 3:
		_fin_live_sans_garder()
		return
	var t: TraitDessin = _live_t
	t.fige = true
	t.noeud = _live_node
	traits.append(t)
	_live_node = null
	_live_t = null
	_live_p = null
	_live_acc = {}
	while traits.size() > 150:
		var v: TraitDessin = traits.pop_front()
		if v.noeud != null:
			v.noeud.queue_free()
	var cout: float = 0.0
	for x in traits:
		cout += Peintre.cout_trait(x as TraitDessin)
	if t.reglages.recursion > 0 or cout > float(budget):
		demander_rec()


func annuler() -> bool:
	if occupe or _live_t != null or traits.is_empty():
		return false
	var t: TraitDessin = traits.pop_back()
	if t.noeud != null:
		t.noeud.queue_free()
	return true


# --------------------------------------------------------------- visee

func relief_monde(x: float, y: float) -> float:
	if rel_mode == 0:
		return 0.0
	var d: float = sqrt(x * x + y * y) / PX
	return Tables.relief_z(rel_mode, rel_h, d, RM) * PX


func _ecart(p: Vector3) -> float:
	return p.z - relief_monde(p.x, p.y)


func regler_dome(actif_: bool, cam_pos: Vector3, yaw: float, recentrer: bool = true) -> void:
	dome_cible = 1.0 if actif_ else 0.0
	if recentrer:
		dome_c = cam_pos
		dome_b = Basis(Vector3.UP, yaw)
	appliquer_fx()


func dome_map(rel: Vector3) -> Vector3:
	var th: float = minf(Vector2(rel.x, rel.y).length() / (RM * PX) * dome_ang, 3.0)
	var ph: float = atan2(rel.y, rel.x)
	var d: Vector3 = Vector3(sin(th) * cos(ph), sin(th) * sin(ph), -cos(th))
	return dome_c + (dome_b * d) * (dome_r + rel.z)


func vers_monde(pt: Vector3) -> Vector3:
	if dome >= 0.5:
		return dome_map(pt)
	return to_global(pt)


func _viser_dome(o_w: Vector3, d_w: Vector3) -> Variant:
	var d: Vector3 = d_w.normalized()
	var oc: Vector3 = o_w - dome_c
	var b: float = oc.dot(d)
	var c: float = oc.dot(oc) - dome_r * dome_r
	var disc: float = b * b - c
	if disc < 0.0:
		return null
	var t: float = -b + sqrt(disc)
	if t <= 0.0:
		return null
	var dir: Vector3 = ((oc + d * t) / dome_r)
	dir = dome_b.inverse() * dir
	var th: float = acos(clampf(-dir.z, -1.0, 1.0))
	var u: float = th / dome_ang
	if u > 1.02:
		return null
	var ph: float = atan2(dir.y, dir.x)
	return Vector3(cos(ph), sin(ph), 0.0) * u * RM * PX


func viser(o_w: Vector3, d_w: Vector3) -> Variant:
	if dome >= 0.5:
		return _viser_dome(o_w, d_w)
	var inv: Transform3D = global_transform.affine_inverse()
	var o: Vector3 = inv * o_w
	var d: Vector3 = (inv.basis * d_w).normalized()
	var rmax: float = RM * PX * 1.02
	# v9 : un mandala plat n'a pas besoin du raymarch de plusieurs centaines
	# d'etapes. Une intersection rayon/plan suffit et coute presque rien.
	if rel_mode == 0:
		if absf(d.z) < 0.00001:
			return null
		var tp: float = -o.z / d.z
		if tp <= 0.0:
			return null
		var pp: Vector3 = o + d * tp
		if Vector2(pp.x, pp.y).length() <= rmax:
			return pp
		return null
	var t: float = 0.1
	var prev: float = _ecart(o + d * t)
	while t < 80.0:
		var t2: float = t + 0.12
		var cur: float = _ecart(o + d * t2)
		if prev * cur <= 0.0 and prev != cur:
			var a: float = t
			var b: float = t2
			for _k in 14:
				var mid: float = 0.5 * (a + b)
				var fm: float = _ecart(o + d * mid)
				if fm * prev <= 0.0:
					b = mid
				else:
					a = mid
			var pt: Vector3 = o + d * (0.5 * (a + b))
			if Vector2(pt.x, pt.y).length() <= rmax:
				return pt
		prev = cur
		t = t2
	return null


func vers_local(k: int, pt: Vector3) -> Vector2:
	var l: Vector3 = (pivots[k] as Node3D).transform.affine_inverse() * Vector3(pt.x, pt.y, 0.0)
	return Vector2(l.x / PX, -l.y / PX)


func calque_de(pt: Vector3) -> int:
	return bande(Vector2(pt.x, pt.y).length() / PX)


# -------------------------------------------------------------- animation

func _phase_boucle() -> float:
	return fposmod(temps * vitesse * 0.13, 1.0)


func angle_calque(k: int) -> float:
	var t: float = temps * vitesse
	match mouvement:
		1:
			return t * 0.32 * (1.0 + float(k) * 0.45)
		2:
			return t * 0.32 * (1.0 + float(k) * 0.35) * (1.0 if k % 2 == 0 else -1.0)
		3:
			return t * 0.16 * float((k + 1) * (k + 1))
		5:
			return 0.42 * sin(t * 0.9 + float(k) * 0.8)
		6:
			return t * 0.30
		7:
			return _phase_boucle() * torsion_boucle
		8:
			return -_phase_boucle() * torsion_boucle
		9:
			var parts: Array = [1.0, -0.7, 1.45]
			return t * 0.5 * float(parts[k]) + 0.25 * sin(t * 3.1)
	return 0.0


func zoom_calque(k: int) -> float:
	var t: float = temps * vitesse
	if mouvement == 4:
		return 1.0 + 0.11 * sin(t * 1.1 + float(k) * PI / 2.0)
	var f: float = clampf(reduction_boucle, 0.30, 0.95)
	if mouvement == 7:
		return pow(f, -_phase_boucle())
	if mouvement == 8:
		return pow(f, _phase_boucle())
	if mouvement == 9:
		return 1.0 + 0.18 * maxf(0.0, sin(t * 4.0 + float(k) * 1.3))
	return 1.0


## Respiration : le mandala gonfle et se vide doucement (meditation).
var souffle: bool = false
var souffle_periode: float = 10.0
var _souffle_t: float = 0.0


func facteur_souffle() -> float:
	if not souffle:
		return 1.0
	return 1.0 + 0.07 * sin(_souffle_t * TAU / maxf(souffle_periode, 2.0))


func appliquer_pivots() -> void:
	var fs: float = facteur_souffle()
	for k in 3:
		var p: Node3D = pivots[k]
		var z: float = zoom_calque(k) * fs
		p.rotation = Vector3(0.0, 0.0, -angle_calque(k))
		p.scale = Vector3(z, z, z)


func _process(dt: float) -> void:
	if absf(dome - dome_cible) > 0.0005:
		dome = move_toward(dome, dome_cible, dt * 0.6)
		appliquer_fx()
	if anime:
		temps += dt
	if souffle:
		_souffle_t += dt
	appliquer_pivots()
	_live_chrono += dt
	_maj_live(false)
	if _differe_chrono >= 0.0:
		_differe_chrono -= dt
		if _differe_chrono < 0.0:
			demander_rec()
	_suivi_construction()
