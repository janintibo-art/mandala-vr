extends Node3D

const VITESSE_VOL: float = 3.5
const BUDGETS: Array = [45000, 90000, 160000]
const RM: float = Tables.RM

var xr: XRInterface = null
var xr_actif: bool = false
var origine: XROrigin3D
var camera: XRCamera3D
var main_d: XRController3D
var main_g: XRController3D
var sc: Scene3D
var panneau: Panneau
var env: Environment
var sol: MeshInstance3D

var reg: Reglages = Reglages.new()
var tout: bool = true
var qualite: int = 1
var sol_visible: bool = true
var duree_defaut: float = 25.0
var vizu_duree: float = 20.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _curseur: MeshInstance3D
var _rayon: MeshInstance3D
var _hud: Label3D
var _msg_label: Label3D
var _msg_temps: float = 0.0
var _aide: Label3D
var _aide_temps: float = 80.0
var _bouts: Dictionary = {}
var _tour_libre: bool = true
var _live_k: int = 0
var _prefs_sale: bool = false
var _prefs_chrono: float = 0.0

# diffusion
var _diff_actif: bool = false
var _diff_vizu: bool = false
var _diff_liste: int = 0
var _diff_i: int = -1
var _diff_t: float = 0.0
var _diff_dur: float = 0.0
var _diff_phase: int = 0
var _diff_phase_t: float = 0.0
var _diff_suite: int = 1
var _voile: MeshInstance3D
var _voile_mat: StandardMaterial3D


func _ready() -> void:
	rng.randomize()
	_init_xr()
	_construire_monde()
	_construire_joueur()
	_charger_prefs()
	sc.budget = int(BUDGETS[qualite])
	panneau.rafraichir()
	hasard()


func _init_xr() -> void:
	xr = XRServer.find_interface("OpenXR")
	if xr != null and xr.is_initialized():
		get_viewport().use_xr = true
		xr_actif = true
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		xr.set("foveation_level", 2)
		xr.set("foveation_dynamic", true)


func _construire_monde() -> void:
	env = Environment.new()
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	add_child(we)

	sol = MeshInstance3D.new()
	var pm: PlaneMesh = PlaneMesh.new()
	pm.size = Vector2(300.0, 300.0)
	sol.mesh = pm
	var ms: ShaderMaterial = ShaderMaterial.new()
	ms.shader = load("res://shaders/sol.gdshader")
	sol.material_override = ms
	add_child(sol)

	sc = Scene3D.new()
	sc.position = Vector3(0.0, 2.0, -7.0)
	add_child(sc)
	sc.appliquer_fond(env)


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
	var rmesh: BoxMesh = BoxMesh.new()
	rmesh.size = Vector3(0.004, 0.004, 1.0)
	_rayon.mesh = rmesh
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

	_hud = _etiquette(0.0009, 36)
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

	panneau = Panneau.new()
	panneau.app = self
	panneau.visible = false
	add_child(panneau)
	panneau.vp.render_target_update_mode = SubViewport.UPDATE_DISABLED

	_voile = MeshInstance3D.new()
	var vs: SphereMesh = SphereMesh.new()
	vs.radius = 0.4
	vs.height = 0.8
	_voile.mesh = vs
	_voile_mat = StandardMaterial3D.new()
	_voile_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_voile_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_voile_mat.albedo_color = Color(0, 0, 0, 0)
	_voile_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_voile_mat.no_depth_test = true
	_voile_mat.render_priority = 100
	_voile.material_override = _voile_mat
	_voile.visible = false
	camera.add_child(_voile)


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
	t += "Bouton menu gauche : TOUS LES REGLAGES\n"
	t += "A : genre   B : palette   X : couleurs   Y : relief\n"
	t += "Clic joystick droit : tirage au sort\n"
	t += "Grip droit : annuler   Grip gauche : retour au départ\n"
	t += "Les deux grips : toile vierge"
	return t


func _maj_hud() -> void:
	var g: String = str(Tables.GENRES[reg.genre][0])
	var p: String = str(Tables.palettes[reg.palette]["nom"])
	var m: String = str(Tables.NOMS_MODES[reg.mode])
	var s: String = "%s | %s\n%s | %d branches | trait %.1f" % [g, p, m, reg.branches, reg.epaisseur]
	if _diff_actif:
		s += "\n" + ("Vizu" if _diff_vizu else "Diffusion %d" % (_diff_i + 1))
	_hud.text = s


func message(texte: String) -> void:
	_msg_label.text = texte
	_msg_temps = 3.0
	if panneau != null:
		panneau.message(texte)


# ------------------------------------------------------------ preferences

func _charger_prefs() -> void:
	var p: Dictionary = Stockage.prefs()
	if p.get("perso", null) is Array:
		for e in (p["perso"] as Array):
			var d: Dictionary = e
			var cols: PackedColorArray = PackedColorArray()
			for h in (d.get("cols", []) as Array):
				cols.append(Color.html(str(h)))
			if cols.size() >= 2:
				Tables.ajouter_palette(str(d.get("nom", "Perso")), cols)
	if p.get("fx", null) is Dictionary:
		for k in (p["fx"] as Dictionary).keys():
			sc.fx[str(k)] = float((p["fx"] as Dictionary)[k])
		sc.appliquer_fx()
	qualite = clampi(int(p.get("qualite", 1)), 0, 2)
	sc.lumineux = bool(p.get("lumineux", true))
	tout = bool(p.get("tout", true))
	duree_defaut = float(p.get("duree", 25.0))
	vizu_duree = float(p.get("vizu", 20.0))
	sol_visible = bool(p.get("sol", true))
	sol.visible = sol_visible
	panneau.palettes_changees()


func _prefs_a_sauver() -> void:
	_prefs_sale = true
	_prefs_chrono = 1.5


func _sauver_prefs() -> void:
	var perso: Array = []
	for i in range(Tables.NB_LIVREES, Tables.palettes.size()):
		if i < Tables.PALETTES_BRUTES.size():
			continue
		var cols: Array = []
		for c in (Tables.palettes[i]["cols"] as PackedColorArray):
			cols.append(c.to_html(false))
		perso.append({"nom": Tables.palettes[i]["nom"], "cols": cols})
	Stockage.sauver_prefs({
		"perso": perso, "fx": sc.fx, "qualite": qualite, "lumineux": sc.lumineux,
		"tout": tout, "duree": duree_defaut, "vizu": vizu_duree, "sol": sol_visible,
	})


# ------------------------------------------------------------- reglages

func regler(champ: String, v: Variant) -> void:
	var ancien: Variant = reg.get(champ)
	reg.set(champ, v)
	if tout:
		for t in sc.traits:
			var td: TraitDessin = t
			if champ == "epaisseur" or champ == "opacite":
				var a: float = float(ancien)
				var f: float = 1.0 if a <= 0.0001 else float(v) / a
				var nv: float = float(td.reglages.get(champ)) * f
				td.reglages.set(champ, clampf(nv, 0.3, 12.0) if champ == "epaisseur" else clampf(nv, 0.1, 1.0))
			else:
				td.reglages.set(champ, v)
			if champ == "recursion" or champ == "motif" or champ == "segments_gen":
				td.oublier()
		sc.demander_rec_differe(0.3)
	if champ == "reduction" or champ == "torsion":
		_maj_boucle()
	_maj_hud()
	_prefs_a_sauver()


func _maj_boucle() -> void:
	var r: Reglages = reg
	for t in sc.traits:
		r = (t as TraitDessin).reglages
		break
	sc.reduction_boucle = r.reduction
	sc.torsion_boucle = r.torsion


func set_relief(i: int) -> void:
	sc.rel_mode = i
	sc.demander_rec_differe(0.2)


func set_relief_h(v: float) -> void:
	sc.rel_h = v
	sc.demander_rec_differe(0.35)


func set_relief_lum(v: float) -> void:
	sc.rel_lum = v
	sc.demander_rec_differe(0.35)


func set_fond(i: int) -> void:
	sc.fond = i
	sc.appliquer_fond(env)


func set_mouvement(i: int) -> void:
	sc.mouvement = i
	_maj_boucle()
	if i != 0:
		sc.anime = true
	panneau.rafraichir()


func set_vitesse(v: float) -> void:
	sc.vitesse = v


func set_sol(on: bool) -> void:
	sol_visible = on
	sol.visible = on
	_prefs_a_sauver()


func set_lumineux(on: bool) -> void:
	sc.lumineux = on
	sc.appliquer_materiaux()
	_prefs_a_sauver()


func set_fx(cle: String, v: float) -> void:
	sc.fx[cle] = v
	sc.appliquer_fx()
	_prefs_a_sauver()


func preset_fx(nom: String) -> void:
	var f: Dictionary = Presets.fx(nom)
	for k in f.keys():
		sc.fx[k] = f[k]
	sc.appliquer_fx()
	panneau.rafraichir()
	message("Ambiance : " + nom)
	_prefs_a_sauver()


func set_qualite(i: int) -> void:
	qualite = i
	sc.budget = int(BUDGETS[i])
	sc.demander_rec_differe(0.2)
	_prefs_a_sauver()


func ajouter_palette_perso(cols: PackedColorArray) -> void:
	var n: int = Tables.nb_perso + 1
	var idx: int = Tables.ajouter_palette("Perso %d" % n, cols)
	panneau.palettes_changees()
	regler("palette", idx)
	panneau.rafraichir()
	message("Palette Perso %d creee" % n)
	_prefs_a_sauver()


# ---------------------------------------------------------------- scenes

func _appliquer_config(c: Dictionary) -> void:
	reg = (c["reglages"] as Reglages).copie()
	sc.rel_mode = int(c["rel_mode"])
	sc.rel_h = float(c["rel_h"])
	sc.rel_lum = float(c["rel_lum"])
	sc.mouvement = int(c["mouvement"])
	sc.vitesse = float(c["vitesse"])
	sc.fond = int(c["fond"])
	var fxd: Dictionary = c["fx"]
	for k in fxd.keys():
		sc.fx[k] = fxd[k]
	sc.appliquer_fx()
	sc.anime = true
	var traits: Array = Generateur.composer_scene(reg, RM, rng)
	sc.installer(traits)
	sc.appliquer_fond(env)
	_maj_boucle()
	_maj_hud()
	panneau.rafraichir()


func scene_livree(i: int) -> void:
	diff_stop()
	var l: Array = Generateur.configs_livrees()
	var c: Dictionary = l[i]
	_appliquer_config(c)
	message(str(c["nom"]))


func hasard() -> void:
	if _diff_actif:
		diff_stop()
	var c: Dictionary = Generateur.tirage(rng, "Hasard")
	_appliquer_config(c)
	message("%s - %s" % [str(Tables.GENRES[reg.genre][0]), str(Tables.palettes[reg.palette]["nom"])])


func vierge() -> void:
	sc.vider()
	message("Toile vierge")


func annuler() -> void:
	if sc.annuler():
		message("Annule")


func retour_depart() -> void:
	origine.global_transform = Transform3D(Basis(), Vector3.ZERO)


func _cycler(champ: String, pas: int, total: int, nom: String) -> void:
	var v: int = (int(reg.get(champ)) + pas + total) % total
	regler(champ, v)
	panneau.rafraichir()
	if champ == "genre":
		message("Genre : " + str(Tables.GENRES[v][0]))
	elif champ == "palette":
		message("Palette : " + str(Tables.palettes[v]["nom"]))
	else:
		message("%s : %s" % [nom, str(Tables.NOMS_MODES[v])])


# ------------------------------------------------------- creations / listes

func sauver() -> void:
	var nom: String = "%s - %s" % [str(Tables.GENRES[reg.genre][0]), Time.get_datetime_string_from_system().replace("T", " ").substr(5, 11)]
	var id: String = Stockage.ecrire(Oeuvre.encoder(nom, sc))
	message("Enregistre : " + nom if id != "" else "Echec de l'enregistrement")


func _charger_sans_message(id: String) -> bool:
	var o: Dictionary = Oeuvre.decoder(Stockage.lire(id))
	if o.is_empty():
		return false
	Oeuvre.appliquer(o, sc)
	sc.appliquer_fond(env)
	sc.anime = true
	for t in sc.traits:
		reg = (t as TraitDessin).reglages.copie()
		break
	_maj_boucle()
	_maj_hud()
	panneau.palettes_changees()
	panneau.rafraichir()
	return true


func charger(id: String) -> void:
	diff_stop()
	if _charger_sans_message(id):
		message("Charge : " + Stockage.nom_de(id))
	else:
		message("Creation illisible")


func coller() -> void:
	var txt: String = DisplayServer.clipboard_get()
	var o: Dictionary = Oeuvre.decoder(txt)
	if o.is_empty() or (o["traits"] as Array).is_empty():
		message("Presse-papiers : pas de creation valide")
		return
	diff_stop()
	Oeuvre.appliquer(o, sc)
	sc.appliquer_fond(env)
	for t in sc.traits:
		reg = (t as TraitDessin).reglages.copie()
		break
	_maj_boucle()
	_maj_hud()
	panneau.palettes_changees()
	panneau.rafraichir()
	Stockage.ecrire(txt)
	message("Creation collee et enregistree")


func supprimer(id: String) -> void:
	Stockage.supprimer(id)
	message("Supprime")


func liste_nouvelle() -> void:
	var l: Array = Stockage.listes()
	l.append({"n": "Liste %d" % (l.size() + 1), "t": 1, "o": []})
	Stockage.sauver_listes(l)


func liste_supprimer(i: int) -> void:
	var l: Array = Stockage.listes()
	if i >= 0 and i < l.size():
		l.remove_at(i)
		Stockage.sauver_listes(l)


func liste_ajouter(i: int, id: String) -> void:
	var l: Array = Stockage.listes()
	if i < 0 or i >= l.size():
		return
	var o: Array = (l[i] as Dictionary)["o"]
	for s in o:
		if str((s as Dictionary).get("c", "")) == id:
			message("Deja dans la liste")
			return
	o.append({"c": id, "d": 0.0, "m": -1})
	Stockage.sauver_listes(l)
	message("Ajoute a la liste")


func diff_transition(i: int) -> int:
	var l: Array = Stockage.listes()
	if i >= 0 and i < l.size():
		return int((l[i] as Dictionary).get("t", 1))
	return 1


func diff_set_transition(i: int, t: int) -> void:
	var l: Array = Stockage.listes()
	if i >= 0 and i < l.size():
		(l[i] as Dictionary)["t"] = t
		Stockage.sauver_listes(l)


func seq_regler(i: int, k: int, champ: String, v: Variant) -> void:
	var l: Array = Stockage.listes()
	if i < 0 or i >= l.size():
		return
	var o: Array = (l[i] as Dictionary)["o"]
	if k >= 0 and k < o.size():
		(o[k] as Dictionary)[champ] = v
		Stockage.sauver_listes(l)


func seq_deplacer(i: int, k: int, sens: int) -> void:
	var l: Array = Stockage.listes()
	if i < 0 or i >= l.size():
		return
	var o: Array = (l[i] as Dictionary)["o"]
	var k2: int = k + sens
	if k >= 0 and k < o.size() and k2 >= 0 and k2 < o.size():
		var tmp: Variant = o[k]
		o[k] = o[k2]
		o[k2] = tmp
		Stockage.sauver_listes(l)


func seq_retirer(i: int, k: int) -> void:
	var l: Array = Stockage.listes()
	if i < 0 or i >= l.size():
		return
	var o: Array = (l[i] as Dictionary)["o"]
	if k >= 0 and k < o.size():
		o.remove_at(k)
		Stockage.sauver_listes(l)


# ------------------------------------------------------------- diffusion

func diff_lire(i: int) -> void:
	var l: Array = Stockage.listes()
	if i < 0 or i >= l.size() or ((l[i] as Dictionary)["o"] as Array).is_empty():
		message("Liste vide")
		return
	_diff_actif = true
	_diff_vizu = false
	_diff_liste = i
	_diff_i = -1
	_diff_suite = 1
	_diff_avancer()
	message("Diffusion : " + str((l[i] as Dictionary)["n"]))


func vizu_lancer() -> void:
	_diff_actif = true
	_diff_vizu = true
	_diff_i = -1
	_diff_avancer()
	message("Vizu automatique")


func diff_stop() -> void:
	if not _diff_actif:
		return
	_diff_actif = false
	_diff_phase = 0
	_voile_mat.albedo_color = Color(0, 0, 0, 0)
	_voile.visible = false
	_maj_hud()


func diff_pas(sens: int) -> void:
	if not _diff_actif:
		return
	_diff_suite = sens
	_diff_avancer()


func _diff_avancer() -> void:
	# lance la transition vers l'element suivant
	var t: int = 1
	if not _diff_vizu:
		t = diff_transition(_diff_liste)
	if t == 0 or _diff_i < 0:
		_diff_charger_suivant()
		_diff_phase = 0
		return
	_diff_phase = 1
	_diff_phase_t = 0.0


func _diff_charger_suivant() -> void:
	_diff_t = 0.0
	if _diff_vizu:
		var c: Dictionary = Generateur.tirage(rng, "Vizu", true)
		_appliquer_config(c)
		_diff_dur = vizu_duree
		_diff_i += 1
		return
	var l: Array = Stockage.listes()
	if _diff_liste >= l.size():
		diff_stop()
		return
	var o: Array = (l[_diff_liste] as Dictionary)["o"]
	if o.is_empty():
		diff_stop()
		return
	var essais: int = 0
	while essais < o.size():
		_diff_i = posmod(_diff_i + _diff_suite, o.size())
		var s: Dictionary = o[_diff_i]
		if _charger_sans_message(str(s.get("c", ""))):
			var d: float = float(s.get("d", 0.0))
			_diff_dur = d if d > 0.0 else duree_defaut
			var mv: int = int(s.get("m", -1))
			if mv >= 0 and mv < Tables.NOMS_MOUVEMENTS.size():
				sc.mouvement = mv
				sc.anime = true
				_maj_boucle()
			message("%d/%d  %s" % [_diff_i + 1, o.size(), Stockage.nom_de(str(s.get("c", "")))])
			return
		essais += 1
	diff_stop()


func _diff_maj(dt: float) -> void:
	if not _diff_actif:
		return
	if _diff_phase == 0:
		_diff_t += dt
		if _diff_t >= _diff_dur and not sc.occupe:
			_diff_suite = 1
			_diff_avancer()
		return
	var duree_f: float = 0.9
	if not _diff_vizu and diff_transition(_diff_liste) == 2:
		duree_f = 0.45
	_diff_phase_t += dt
	_voile.visible = true
	if _diff_phase == 1:
		var a: float = clampf(_diff_phase_t / duree_f, 0.0, 1.0)
		_voile_mat.albedo_color = Color(0, 0, 0, a)
		if a >= 1.0:
			_diff_charger_suivant()
			_diff_phase = 3
			_diff_phase_t = 0.0
	elif _diff_phase == 3:
		if sc.occupe and _diff_phase_t < 6.0:
			return
		var a2: float = 1.0 - clampf(_diff_phase_t / duree_f, 0.0, 1.0)
		_voile_mat.albedo_color = Color(0, 0, 0, a2)
		if a2 <= 0.0:
			_voile.visible = false
			_diff_phase = 0


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


func _placer_panneau() -> void:
	var cam: Vector3 = camera.global_position
	var avant: Vector3 = -camera.global_transform.basis.z
	avant.y = 0.0
	if avant.length() < 0.01:
		avant = Vector3(0, 0, -1)
	avant = avant.normalized()
	var pos: Vector3 = cam + avant * 1.35
	pos.y = cam.y - 0.05
	panneau.global_transform = Transform3D(Basis.looking_at(avant, Vector3.UP), pos)


func basculer_panneau() -> void:
	panneau.visible = not panneau.visible
	if panneau.visible:
		_placer_panneau()
		panneau.rafraichir()
		_aide.visible = false
	else:
		panneau.quitter()
	panneau.vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if panneau.visible else SubViewport.UPDATE_DISABLED


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
	var sur_panneau: bool = false
	var gachette: bool = _seuil("trigger_d", main_d.get_float("trigger"))
	var o_ray: Vector3 = main_d.global_position
	var d_ray: Vector3 = -main_d.global_transform.basis.z

	var longueur: float = 3.0
	var hit_panneau: Variant = null
	if panneau.visible:
		hit_panneau = panneau.intersecter(o_ray, d_ray)
	var hit: Variant = sc.viser(o_ray, d_ray)

	if hit_panneau != null:
		var hp: Dictionary = hit_panneau
		sur_panneau = true
		panneau.souris(hp["px"], gachette)
		longueur = float(hp["t"])
		_curseur.visible = true
		_curseur.scale = Vector3(0.25, 0.25, 0.25)
		_curseur.global_position = hp["mondial"]
		if absf(dr.y) > 0.5:
			if _front("molette", true) or true:
				var pas: float = dt * 4.0
				_bouts["mol"] = float(_bouts.get("mol", 0.0)) + pas
				if float(_bouts["mol"]) > 0.12:
					_bouts["mol"] = 0.0
					panneau.molette(dr.y > 0.0, hp["px"])
	else:
		panneau.quitter()
		_curseur.scale = Vector3.ONE
		if hit != null:
			var pt: Vector3 = hit
			_curseur.visible = true
			_curseur.global_position = sc.to_global(pt)
			longueur = maxf(0.1, o_ray.distance_to(sc.to_global(pt)))
		else:
			_curseur.visible = false
	_rayon.scale = Vector3(1.0, 1.0, longueur)
	_rayon.position = Vector3(0.0, 0.0, -longueur * 0.5)

	# rotation / altitude (sauf quand le stick sert a defiler le menu)
	if not sur_panneau:
		if absf(dr.x) < 0.3:
			_tour_libre = true
		elif absf(dr.x) > 0.7 and _tour_libre:
			_tour_libre = false
			_tourner(-30.0 * signf(dr.x))
		if absf(dr.y) > 0.2:
			origine.global_position.y += dr.y * 2.5 * dt
	else:
		if absf(dr.x) < 0.3:
			_tour_libre = true

	if _front("g_menu", main_g.is_button_pressed("menu_button")):
		basculer_panneau()
	if _front("d_a", main_d.is_button_pressed("ax_button")):
		_cycler("genre", 1, Tables.GENRES.size(), "Genre")
	if _front("d_b", main_d.is_button_pressed("by_button")):
		_cycler("palette", 1, Tables.palettes.size(), "Palette")
	if _front("g_x", main_g.is_button_pressed("ax_button")):
		_cycler("mode", 1, Tables.NOMS_MODES.size(), "Couleurs")
	if _front("g_y", main_g.is_button_pressed("by_button")):
		var ni: int = (sc.rel_mode + 1) % Tables.NOMS_RELIEFS.size()
		set_relief(ni)
		panneau.rafraichir()
		message("Relief : " + str(Tables.NOMS_RELIEFS[ni]))
	if _front("d_clic", main_d.is_button_pressed("primary_click")):
		hasard()
	if _front("g_clic", main_g.is_button_pressed("primary_click")):
		sc.anime = not sc.anime
		message("Animation : " + ("oui" if sc.anime else "pause"))

	var grip_d: bool = _seuil("grip_d", main_d.get_float("grip"))
	var grip_g: bool = _seuil("grip_g", main_g.get_float("grip"))
	if _front("grip_d_f", grip_d):
		if not grip_g:
			annuler()
		else:
			vierge()
	if _front("grip_g_f", grip_g):
		if grip_d:
			vierge()
		else:
			retour_depart()

	# dessin
	var veut: bool = gachette and not sur_panneau and not panneau_bloque()
	if veut and hit != null:
		var pt2: Vector3 = hit
		if not sc.live_actif():
			_live_k = sc.calque_de(pt2)
			sc.live_debut(reg.copie(), _live_k)
			_aide_temps = 0.0
		sc.live_point(sc.vers_local(_live_k, pt2))
	elif sc.live_actif():
		sc.live_fin()


func panneau_bloque() -> bool:
	return false


func _process(dt: float) -> void:
	if main_d == null:
		return
	_entrees(dt)
	_diff_maj(dt)
	if _msg_temps > 0.0:
		_msg_temps -= dt
		if _msg_temps <= 0.0:
			_msg_label.text = ""
	if _aide != null and _aide.visible:
		_aide_temps -= dt
		if _aide_temps <= 0.0:
			_aide.visible = false
	if _prefs_sale:
		_prefs_chrono -= dt
		if _prefs_chrono <= 0.0:
			_prefs_sale = false
			_sauver_prefs()
