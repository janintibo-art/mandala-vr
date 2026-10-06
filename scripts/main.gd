extends Node3D

const BUDGET_QUADS: int = 90000
const PAS_TRACE: float = 0.02
const MAX_LIVE_PTS: int = 1500
const MAX_TRAITS: int = 80
const VITESSE_VOL: float = 3.5

var xr: XRInterface = null
var xr_actif: bool = false
var origine: XROrigin3D
var camera: XRCamera3D
var main_d: XRController3D
var main_g: XRController3D
var monde: Node3D
var anneaux: Array = []
var mat_ruban: ShaderMaterial

var traits: Array = []
var etat: Dictionary = {"n": 12, "genre": 1, "palette": 0, "relief": 1, "mode": 0, "largeur": 0.009}
var anime: bool = true
var vit_anneaux: Array = [0.20, -0.12, 0.07]
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var nom_scene: String = ""

var _thread: Thread = null
var _occupe: bool = false
var _relancer: bool = false
var _file: Array = []
var _creation: bool = false
var _nouveaux: Array = []
var _differe: Array = []

var _trace: bool = false
var _veut_tracer: bool = false
var _live_pts: PackedVector2Array = PackedVector2Array()
var _live_acc: Array = []
var _live_nodes: Array = []
var _live_dirty: bool = false
var _live_chrono: float = 0.0
var _live_long: float = 0.0

var _bouts: Dictionary = {}
var _tour_libre: bool = true
var _curseur: MeshInstance3D
var _rayon: MeshInstance3D
var _hud: Label3D
var _msg_label: Label3D
var _msg_temps: float = 0.0
var _aide: Label3D
var _aide_temps: float = 70.0


func _ready() -> void:
	rng.randomize()
	_init_xr()
	_construire_monde()
	_construire_joueur()
	_nouvelle_scene(-1)


func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null


func _init_xr() -> void:
	xr = XRServer.find_interface("OpenXR")
	if xr != null and xr.is_initialized():
		get_viewport().use_xr = true
		xr_actif = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		xr.set("foveation_level", 2)
		xr.set("foveation_dynamic", true)


func _construire_monde() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.004, 0.004, 0.02)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sol: MeshInstance3D = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(300.0, 300.0)
	sol.mesh = pm
	var ms: ShaderMaterial = ShaderMaterial.new()
	ms.shader = load("res://shaders/sol.gdshader")
	sol.material_override = ms
	add_child(sol)

	mat_ruban = ShaderMaterial.new()
	mat_ruban.shader = load("res://shaders/ruban.gdshader")

	monde = Node3D.new()
	monde.position = Vector3(0.0, 2.0, -7.0)
	add_child(monde)
	for i in 3:
		var a: Node3D = Node3D.new()
		monde.add_child(a)
		anneaux.append(a)


func _construire_joueur() -> void:
	origine = XROrigin3D.new()
	add_child(origine)
	camera = XRCamera3D.new()
	origine.add_child(camera)
	if not xr_actif:
		camera.position = Vector3(0.0, 1.6, 0.0)

	main_d = XRController3D.new()
	main_d.tracker = &"right_hand"
	main_d.pose = &"aim"
	origine.add_child(main_d)
	main_g = XRController3D.new()
	main_g.tracker = &"left_hand"
	origine.add_child(main_g)

	for h in [main_d, main_g]:
		var corps: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.035, 0.035, 0.12)
		corps.mesh = bm
		var mc: StandardMaterial3D = StandardMaterial3D.new()
		mc.albedo_color = Color(0.25, 0.28, 0.35)
		mc.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		corps.material_override = mc
		corps.position = Vector3(0.0, 0.0, 0.03)
		(h as Node3D).add_child(corps)

	_rayon = MeshInstance3D.new()
	var rm: BoxMesh = BoxMesh.new()
	rm.size = Vector3(0.004, 0.004, 1.0)
	_rayon.mesh = rm
	var mr: StandardMaterial3D = StandardMaterial3D.new()
	mr.albedo_color = Color(0.6, 0.9, 1.0)
	mr.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rayon.material_override = mr
	main_d.add_child(_rayon)

	_curseur = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.07
	sm.height = 0.14
	_curseur.mesh = sm
	var mq: StandardMaterial3D = StandardMaterial3D.new()
	mq.albedo_color = Color(1.0, 1.0, 1.0)
	mq.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_curseur.material_override = mq
	_curseur.visible = false
	add_child(_curseur)

	_hud = _etiquette(0.0009, 40)
	_hud.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hud.position = Vector3(0.0, 0.13, 0.0)
	main_g.add_child(_hud)

	_msg_label = _etiquette(0.0009, 56)
	_msg_label.position = Vector3(0.0, -0.14, -1.0)
	camera.add_child(_msg_label)

	_aide = _etiquette(0.003, 36)
	_aide.position = Vector3(0.0, 1.9, -3.2)
	_aide.text = _texte_aide()
	add_child(_aide)


func _etiquette(taille_pixel: float, taille_police: int) -> Label3D:
	var l: Label3D = Label3D.new()
	l.pixel_size = taille_pixel
	l.font_size = taille_police
	l.outline_size = 8
	l.no_depth_test = true
	l.render_priority = 10
	l.modulate = Color(1.0, 1.0, 1.0)
	return l


func _texte_aide() -> String:
	var t: String = "MANDALA VR\n\n"
	t += "Joystick gauche : voler vers où tu regardes\n"
	t += "Gâchette gauche : aller plus vite\n"
	t += "Joystick droit : tourner, monter, descendre\n"
	t += "Gâchette droite : dessiner sur l'image\n"
	t += "A : genre     B : palette\n"
	t += "X : relief     Y : couleurs\n"
	t += "Clic joystick droit : nouveau mandala\n"
	t += "Clic joystick gauche : nombre de branches\n"
	t += "Grip droit : annuler\n"
	t += "Grip gauche : retour au départ\n"
	t += "Les deux grips : toile vierge\n"
	t += "Menu : animation"
	return t


func _texte_hud() -> String:
	var g: String = str(Tables.GENRES[int(etat["genre"])]["nom"])
	var p: String = str(Tables.PALETTES[int(etat["palette"])][0])
	var r: String = str(Tables.RELIEFS[int(etat["relief"])])
	var c: String = str(Tables.MODES_COULEUR[int(etat["mode"])])
	return "%s\n%s\nRelief : %s\nCouleur : %s\n%d branches" % [g, p, r, c, int(etat["n"])]


func _maj_hud() -> void:
	if _hud != null:
		_hud.text = _texte_hud()


func _msg(texte: String) -> void:
	if _msg_label != null:
		_msg_label.text = texte
		_msg_temps = 3.0


func _params() -> Dictionary:
	return etat.duplicate()


# ---------------------------------------------------------------- scènes

func _vider() -> void:
	for t in traits:
		for nd in (t["nodes"] as Array):
			(nd as Node).queue_free()
	traits.clear()


func _nouvelle_scene(cfg: int) -> void:
	if _occupe:
		_differe.clear()
		_differe.append(func() -> void: _nouvelle_scene(cfg))
		return
	if _trace:
		_fin_trace()
	var s: Dictionary = Generateur.nouvelle_scene(rng, cfg)
	_vider()
	etat["n"] = int(s["n"])
	etat["genre"] = int(s["genre"])
	etat["palette"] = int(s["palette"])
	etat["relief"] = int(s["relief"])
	etat["mode"] = int(s["mode"])
	for pts in (s["traits"] as Array):
		traits.append({"pts": pts, "nodes": []})
	nom_scene = str(s["nom"])
	_maj_hud()
	_msg(nom_scene)
	_demander_rec()


func _toile_vierge() -> void:
	if _occupe:
		return
	if _trace:
		_fin_trace()
	_vider()
	_msg("Toile vierge")


func _cycler(cle: String, pas: int) -> void:
	var total: int = 1
	match cle:
		"genre":
			total = Tables.GENRES.size()
		"palette":
			total = Tables.PALETTES.size()
		"relief":
			total = Tables.RELIEFS.size()
		"mode":
			total = Tables.MODES_COULEUR.size()
	etat[cle] = (int(etat[cle]) + pas + total) % total
	_maj_hud()
	match cle:
		"genre":
			_msg("Genre : " + str(Tables.GENRES[int(etat[cle])]["nom"]))
		"palette":
			_msg("Palette : " + str(Tables.PALETTES[int(etat[cle])][0]))
		"relief":
			_msg("Relief : " + str(Tables.RELIEFS[int(etat[cle])]))
		"mode":
			_msg("Couleur : " + str(Tables.MODES_COULEUR[int(etat[cle])]))
	_demander_rec()


func _cycler_n() -> void:
	var k: int = Tables.N_VALEURS.find(int(etat["n"]))
	k = (k + 1) % Tables.N_VALEURS.size()
	etat["n"] = int(Tables.N_VALEURS[k])
	_maj_hud()
	_msg("%d branches" % int(etat["n"]))
	_demander_rec()


# ------------------------------------------------- construction (thread)

func _stride() -> int:
	var genre: Dictionary = Tables.GENRES[int(etat["genre"])]
	var nc: int = (genre["copies"] as Array).size()
	var nm: int = 2 if bool(genre["miroir"]) else 1
	var total: int = 0
	for t in traits:
		total += (t["pts"] as PackedVector2Array).size() - 1
	total *= int(etat["n"]) * nm * nc
	return maxi(1, ceili(float(total) / float(BUDGET_QUADS)))


func _demander_rec() -> void:
	if traits.is_empty():
		return
	if _occupe:
		_relancer = true
		return
	_lancer()


func _lancer() -> void:
	_occupe = true
	_relancer = false
	var donnees: Array = []
	for t in traits:
		donnees.append(t["pts"])
	var par: Dictionary = _params()
	_thread = Thread.new()
	_thread.start(_travail.bind(donnees, par, _stride()))


func _travail(donnees: Array, par: Dictionary, stride: int) -> Array:
	var out: Array = []
	for i in donnees.size():
		out.append(Builder.construire(donnees[i], i, par, stride))
	return out


func _creer_noeud(r: int, d: Dictionary) -> MeshInstance3D:
	var mesh: ArrayMesh = ArrayMesh.new()
	_surface(mesh, d)
	var nd: MeshInstance3D = MeshInstance3D.new()
	nd.mesh = mesh
	nd.material_override = mat_ruban
	nd.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(anneaux[r] as Node3D).add_child(nd)
	return nd


func _surface(mesh: ArrayMesh, d: Dictionary) -> void:
	if (d["v"] as PackedVector3Array).size() == 0:
		return
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = d["v"]
	arr[Mesh.ARRAY_NORMAL] = d["n"]
	arr[Mesh.ARRAY_COLOR] = d["c"]
	arr[Mesh.ARRAY_TEX_UV] = d["uv"]
	arr[Mesh.ARRAY_INDEX] = d["i"]
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)


func _suivi_thread() -> void:
	if _thread != null and not _thread.is_alive():
		var res: Array = _thread.wait_to_finish()
		_thread = null
		_file.clear()
		_nouveaux = []
		for i in traits.size():
			_nouveaux.append([])
		for i in res.size():
			var par_anneau: Array = res[i]
			for r in 3:
				var d: Dictionary = par_anneau[r]
				if (d["v"] as PackedVector3Array).size() > 0:
					_file.append([i, r, d])
		_creation = true
	if _creation:
		var k: int = 0
		while k < 6 and not _file.is_empty():
			var it: Array = _file.pop_front()
			var nd: MeshInstance3D = _creer_noeud(int(it[1]), it[2])
			nd.visible = false
			(_nouveaux[int(it[0])] as Array).append(nd)
			k += 1
		if _file.is_empty():
			_finir_creation()


func _finir_creation() -> void:
	for i in traits.size():
		for nd in (traits[i]["nodes"] as Array):
			(nd as Node).queue_free()
		var nv: Array = _nouveaux[i]
		for nd in nv:
			(nd as Node3D).visible = true
		traits[i]["nodes"] = nv
	_nouveaux = []
	_creation = false
	_occupe = false
	var fns: Array = _differe.duplicate()
	_differe.clear()
	for f in fns:
		(f as Callable).call()
	if _relancer and not _occupe:
		_demander_rec()


# --------------------------------------------------------------- dessin

func _ecart(p: Vector3, rel: int) -> float:
	var u: float = minf(Vector2(p.x, p.y).length() / Tables.R_METRES, 1.0)
	return p.z - Tables.H_METRES * Tables.relief_z(rel, u)


func _viser(o_w: Vector3, d_w: Vector3) -> Variant:
	var inv: Transform3D = monde.global_transform.affine_inverse()
	var o: Vector3 = inv * o_w
	var d: Vector3 = (inv.basis * d_w).normalized()
	var rel: int = int(etat["relief"])
	var t: float = 0.1
	var prev: float = _ecart(o + d * t, rel)
	while t < 80.0:
		var t2: float = t + 0.12
		var cur: float = _ecart(o + d * t2, rel)
		if prev * cur <= 0.0 and prev != cur:
			var a: float = t
			var b: float = t2
			for _k in 14:
				var mid: float = 0.5 * (a + b)
				var fm: float = _ecart(o + d * mid, rel)
				if fm * prev <= 0.0:
					b = mid
				else:
					a = mid
			var pt: Vector3 = o + d * (0.5 * (a + b))
			var R: float = Tables.R_METRES
			if Vector2(pt.x, pt.y).length() / R <= 1.0:
				return Vector2(pt.x / R, pt.y / R)
		prev = cur
		t = t2
	return null


func _debut_trace() -> void:
	_trace = true
	_live_pts = PackedVector2Array()
	_live_long = 0.0
	_live_acc = [Builder.vide(), Builder.vide(), Builder.vide()]
	_live_nodes = []
	for r in 3:
		_live_nodes.append(_creer_noeud(r, Builder.vide()))
	_aide_temps = 0.0


func _ajouter_point(p: Vector2) -> void:
	var n: int = _live_pts.size()
	if n > 0 and p.distance_to(_live_pts[n - 1]) < PAS_TRACE:
		return
	if n >= MAX_LIVE_PTS:
		return
	_live_pts.append(p)
	if n > 0:
		var a: Vector2 = _live_pts[n - 1]
		var seg: PackedVector2Array = PackedVector2Array([a, p])
		var res: Array = Builder.construire(seg, traits.size(), _params(), 1, _live_long, 3.0)
		_live_long += a.distance_to(p)
		for r in 3:
			Builder.fusionner(_live_acc[r], res[r])
		_live_dirty = true


func _maj_live(forcer: bool) -> void:
	if not _live_dirty:
		return
	if not forcer and _live_chrono < 0.1:
		return
	_live_chrono = 0.0
	_live_dirty = false
	for r in 3:
		var mesh: ArrayMesh = (_live_nodes[r] as MeshInstance3D).mesh as ArrayMesh
		mesh.clear_surfaces()
		_surface(mesh, _live_acc[r])


func _fin_trace() -> void:
	_trace = false
	_maj_live(true)
	if _live_pts.size() < 3:
		for nd in _live_nodes:
			(nd as Node).queue_free()
	else:
		traits.append({"pts": _live_pts.duplicate(), "nodes": _live_nodes.duplicate()})
		while traits.size() > MAX_TRAITS:
			var vieux: Dictionary = traits.pop_front()
			for nd in (vieux["nodes"] as Array):
				(nd as Node).queue_free()
	_live_nodes = []
	_live_pts = PackedVector2Array()
	_live_acc = []


func _annuler() -> void:
	if _occupe or _trace or traits.is_empty():
		return
	var t: Dictionary = traits.pop_back()
	for nd in (t["nodes"] as Array):
		(nd as Node).queue_free()
	_msg("Annulé")


# ------------------------------------------------------------- entrées

func _front(nom: String, actif: bool) -> bool:
	var avant: bool = bool(_bouts.get(nom, false))
	_bouts[nom] = actif
	return actif and not avant


func _seuil(nom: String, v: float) -> bool:
	var cle: String = "h_" + nom
	var etat_h: bool = bool(_bouts.get(cle, false))
	if v > 0.6:
		etat_h = true
	elif v < 0.3:
		etat_h = false
	_bouts[cle] = etat_h
	return etat_h


func _tourner(deg: float) -> void:
	var pivot: Vector3 = camera.global_position
	var rot: Basis = Basis(Vector3.UP, deg_to_rad(deg))
	var o: Transform3D = origine.global_transform
	o.origin = pivot + rot * (o.origin - pivot)
	o.basis = rot * o.basis
	origine.global_transform = o


func _entrees(dt: float) -> void:
	var mv: Vector2 = main_g.get_vector2("primary")
	if mv.length() < 0.15:
		mv = Vector2.ZERO
	if mv != Vector2.ZERO:
		var boost: float = 1.0 + 3.0 * main_g.get_float("trigger")
		var b: Basis = camera.global_transform.basis
		var dir: Vector3 = (-b.z * mv.y) + (b.x * mv.x)
		origine.global_position += dir * VITESSE_VOL * boost * dt

	var dr: Vector2 = main_d.get_vector2("primary")
	if absf(dr.x) < 0.3:
		_tour_libre = true
	elif absf(dr.x) > 0.7 and _tour_libre:
		_tour_libre = false
		_tourner(-30.0 * signf(dr.x))
	if absf(dr.y) > 0.2:
		origine.global_position.y += dr.y * 2.5 * dt

	if _front("d_a", main_d.is_button_pressed("ax_button")):
		_cycler("genre", 1)
	if _front("d_b", main_d.is_button_pressed("by_button")):
		_cycler("palette", 1)
	if _front("g_x", main_g.is_button_pressed("ax_button")):
		_cycler("relief", 1)
	if _front("g_y", main_g.is_button_pressed("by_button")):
		_cycler("mode", 1)
	if _front("d_clic", main_d.is_button_pressed("primary_click")):
		_nouvelle_scene(-1)
	if _front("g_clic", main_g.is_button_pressed("primary_click")):
		_cycler_n()
	if _front("g_menu", main_g.is_button_pressed("menu_button")):
		anime = not anime
		_msg("Animation : " + ("oui" if anime else "non"))

	var grip_d: bool = _seuil("grip_d", main_d.get_float("grip"))
	var grip_g: bool = _seuil("grip_g", main_g.get_float("grip"))
	if _front("grip_d_f", grip_d):
		if not grip_g:
			_annuler()
		else:
			_toile_vierge()
	if _front("grip_g_f", grip_g):
		if grip_d:
			_toile_vierge()
		else:
			origine.global_transform = Transform3D(Basis(), Vector3.ZERO)

	_veut_tracer = _seuil("trigger_d", main_d.get_float("trigger"))
	var hit: Variant = _viser(main_d.global_position, -main_d.global_transform.basis.z)
	var longueur: float = 3.0
	if hit != null:
		var pu: Vector2 = hit
		var wpos: Vector3 = monde.to_global(Vector3(
			pu.x * Tables.R_METRES, pu.y * Tables.R_METRES,
			Tables.H_METRES * Tables.relief_z(int(etat["relief"]), pu.length())))
		_curseur.visible = true
		_curseur.global_position = wpos
		longueur = maxf(0.1, main_d.global_position.distance_to(wpos))
	else:
		_curseur.visible = false
	_rayon.scale = Vector3(1.0, 1.0, longueur)
	_rayon.position = Vector3(0.0, 0.0, -longueur * 0.5)

	if _veut_tracer and not _occupe and _aligne():
		if hit != null:
			if not _trace:
				_debut_trace()
			_ajouter_point(hit)
		elif _trace:
			_fin_trace()
	elif _trace and not _veut_tracer:
		_fin_trace()


func _aligne() -> bool:
	for a in anneaux:
		var ang: float = (a as Node3D).rotation.z
		if absf(ang - roundf(ang / TAU) * TAU) > 0.01:
			return false
	return true


func _animer(dt: float) -> void:
	var fixer: bool = _veut_tracer or _trace
	for i in anneaux.size():
		var nd: Node3D = anneaux[i]
		var a: float = nd.rotation.z
		if fixer:
			var cible: float = roundf(a / TAU) * TAU
			a += (cible - a) * minf(1.0, 8.0 * dt)
			if absf(cible - a) < 0.002:
				a = cible
		elif anime:
			a += float(vit_anneaux[i]) * dt
		nd.rotation.z = wrapf(a, -PI, PI)


func _process(dt: float) -> void:
	if main_d == null:
		return
	_entrees(dt)
	_animer(dt)
	_live_chrono += dt
	_maj_live(false)
	_suivi_thread()
	if _msg_temps > 0.0:
		_msg_temps -= dt
		if _msg_temps <= 0.0:
			_msg_label.text = ""
	if _aide != null and _aide.visible:
		_aide_temps -= dt
		if _aide_temps <= 0.0:
			_aide.visible = false
