class_name V10Manager
extends Node
## Mandala VR v10 : onglet Rapide, profils confort, instantanes et mains Quest.

const FICHIER_SLOTS: String = "user://v10_slots.json"

var app = null
var v8 = null
var _installe: bool = false
var _slots: Array = [{}, {}, {}]
var _slot_labels: Array = []
var _precedent: Dictionary = {}
var _etat_label: Label = null
var _etat_t: float = 0.0
var _pinch_g_t: float = 0.0
var _pinch_g_declenche: bool = false


func _ready() -> void:
	app = get_parent()
	v8 = app.get_node_or_null("V8Manager")
	process_priority = 110
	_lire_slots()


func _process(dt: float) -> void:
	if app == null:
		return
	if not _installe:
		if app.panneau != null and v8 != null and bool(v8.get("_ui_installee")):
			_installer()
		return
	_maj_mains(dt)
	_maj_etat(dt)


# -------------------------------------------------------------- installation

func _installer() -> void:
	_installe = true
	var p: VBoxContainer = app.panneau._page("Rapide")
	var sc: Node = p.get_parent()
	app.panneau.onglets.move_child(sc, 0)
	app.panneau.onglets.current_tab = 0

	app.panneau._titre(p, "Commandes rapides")
	app.panneau._note(p, "Les fonctions les plus utiles sans parcourir tous les onglets.")
	var g: GridContainer = _grille(p, 3)
	_gros(g, "Hasard", _action_hasard)
	_gros(g, "Favori au hasard", _action_favori)
	_gros(g, "Enregistrer", func() -> void: app.sauver())
	_gros(g, "Annuler", func() -> void: app.annuler())
	_gros(g, "Toile vierge", _action_vierge)
	_gros(g, "Retour precedent", _retour_precedent)
	_gros(g, "Plan / Dome", _toggle_dome)
	_gros(g, "Monde suivant", _monde_suivant)
	_gros(g, "Son suivant", _ambiance_suivante)
	_gros(g, "Meditation 10 min", _meditation_10)
	_gros(g, "Stop meditation", _meditation_stop)
	_gros(g, "VR / Passthrough", _toggle_passthrough)

	app.panneau._titre(p, "Profils confort")
	var gp: GridContainer = _grille(p, 4)
	_gros(gp, "Doux", _profil_doux)
	_gros(gp, "Normal", _profil_normal)
	_gros(gp, "Dynamique", _profil_dynamique)
	_gros(gp, "Assis", _profil_assis)
	app.panneau._note(p, "Doux : lent + teleportation. Normal : reglages equilibres. Dynamique : mouvement libre. Assis : confort maximum.")

	app.panneau._titre(p, "Instantanes rapides")
	app.panneau._note(p, "Trois emplacements pour garder temporairement un etat complet du mandala et y revenir en un clic.")
	for i in 3:
		var r: HBoxContainer = app.panneau._rangee(p)
		var l: Label = Label.new()
		l.custom_minimum_size = Vector2(450, 60)
		r.add_child(l)
		_slot_labels.append(l)
		app.panneau._bouton(r, "Memoriser", _slot_sauver.bind(i), 260)
		app.panneau._bouton(r, "Rappeler", _slot_charger.bind(i), 260)
		app.panneau._bouton(r, "Vider", _slot_vider.bind(i), 180)
	_rafraichir_slots()

	app.panneau._titre(p, "Mains Quest")
	app.panneau._note(p, "Avec le hand tracking : pincement main droite = dessiner / cliquer. Maintenir le pincement main gauche environ 1 seconde = ouvrir ou fermer le menu.")
	_etat_label = Label.new()
	_etat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etat_label.add_theme_font_size_override("font_size", 23)
	p.add_child(_etat_label)

	app.panneau.rafraichir()
	app.message("Mandala VR v10 : menu rapide pret")


func _grille(parent: Control, colonnes: int) -> GridContainer:
	var g: GridContainer = GridContainer.new()
	g.columns = colonnes
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(g)
	return g


func _gros(parent: Control, texte: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(0, 74)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# -------------------------------------------------------------- commandes rapides

func _memoriser_avant() -> void:
	_precedent = _capture("Precedent")


func _action_hasard() -> void:
	_memoriser_avant()
	app.hasard()


func _action_favori() -> void:
	_memoriser_avant()
	v8.call("_lancer_favori")


func _action_vierge() -> void:
	_memoriser_avant()
	app.vierge()


func _retour_precedent() -> void:
	if _precedent.is_empty():
		app.message("Aucun etat precedent")
		return
	var courant: Dictionary = _capture("Courant")
	_restaurer(_precedent)
	_precedent = courant
	app.message("Etat precedent restaure")


func _toggle_dome() -> void:
	app.set_dome(app.sc.dome_cible < 0.5)


func _monde_suivant() -> void:
	var i: int = (app.monde.courant + 1) % Monde.NOMS.size()
	app.set_monde(i)
	app.message("Monde : " + str(Monde.NOMS[i]))


func _ambiance_suivante() -> void:
	var i: int = (app.son.ambiance + 1) % Son.NOMS_AMBIANCES.size()
	app.son.choisir_ambiance(i)
	app.message("Son : " + str(Son.NOMS_AMBIANCES[i]))


func _meditation_10() -> void:
	v8.call("_demarrer_meditation", 10)


func _meditation_stop() -> void:
	v8.call("_arreter_meditation")


func _toggle_passthrough() -> void:
	v8.call("_set_passthrough", not bool(v8.get("_passthrough")))


# -------------------------------------------------------------- profils confort

func _profil_doux() -> void:
	v8.call("_set_vitesse", 0.60)
	v8.call("_set_angle", 30.0)
	v8.call("_set_teleportation", true)
	v8.call("_set_voile", true)
	app.message("Profil confort : Doux")


func _profil_normal() -> void:
	v8.call("_set_vitesse", 1.00)
	v8.call("_set_angle", 30.0)
	v8.call("_set_teleportation", false)
	v8.call("_set_voile", true)
	app.message("Profil confort : Normal")


func _profil_dynamique() -> void:
	v8.call("_set_vitesse", 1.25)
	v8.call("_set_angle", 45.0)
	v8.call("_set_teleportation", false)
	v8.call("_set_voile", false)
	app.message("Profil confort : Dynamique")


func _profil_assis() -> void:
	v8.call("_set_vitesse", 0.60)
	v8.call("_set_angle", 30.0)
	v8.call("_set_teleportation", true)
	v8.call("_set_voile", true)
	if not bool(v8.get("_mode_assis")):
		v8.call("_set_mode_assis", true)
	app.message("Profil confort : Assis")


# -------------------------------------------------------------- instantanes

func _capture(nom: String) -> Dictionary:
	return {
		"nom": nom,
		"date": Time.get_datetime_string_from_system(),
		"oeuvre": Oeuvre.encoder(nom, app.sc, {
			"monde": app.monde.courant,
			"ambiance": app.son.ambiance,
			"dome": app.sc.dome_cible,
			"ouverture": rad_to_deg(app.sc.dome_ang),
		}),
		"reg": app.reg.vers_json(),
		"monde": app.monde.courant,
		"ambiance": app.son.ambiance,
		"gamme": app.son.gamme,
		"souffle": app.sc.souffle,
		"souffle_periode": app.sc.souffle_periode,
		"dome": app.sc.dome_cible > 0.5,
		"ouverture": rad_to_deg(app.sc.dome_ang),
		"sol": app.sol_visible,
		"anime": app.sc.anime,
		"passthrough": bool(v8.get("_passthrough")),
	}


func _restaurer(s: Dictionary) -> void:
	var o: Dictionary = Oeuvre.decoder(str(s.get("oeuvre", "")))
	if o.is_empty():
		app.message("Instantane invalide")
		return
	Oeuvre.appliquer(o, app.sc)
	if s.get("reg", null) is Dictionary:
		app.reg = Reglages.depuis_json(s["reg"])
	app.sc.appliquer_fond(app.env)
	app.set_monde(clampi(int(s.get("monde", 0)), 0, Monde.NOMS.size() - 1))
	app.son.gamme = clampi(int(s.get("gamme", 0)), 0, Son.NOMS_GAMMES.size() - 1)
	app.son.choisir_ambiance(clampi(int(s.get("ambiance", 0)), 0, Son.NOMS_AMBIANCES.size() - 1))
	app.sc.souffle_periode = clampf(float(s.get("souffle_periode", 10.0)), 2.0, 30.0)
	app.set_souffle(bool(s.get("souffle", false)))
	app.set_ouverture(clampf(float(s.get("ouverture", 109.0)), 45.0, 180.0))
	app.set_dome(bool(s.get("dome", false)))
	app.set_sol(bool(s.get("sol", true)))
	app.sc.anime = bool(s.get("anime", true))
	v8.call("_set_passthrough", bool(s.get("passthrough", false)))
	app._maj_boucle()
	app._maj_hud()
	app.panneau.palettes_changees()
	app.panneau.rafraichir()


func _slot_sauver(i: int) -> void:
	if i < 0 or i >= _slots.size():
		return
	_slots[i] = _capture("Slot %d" % (i + 1))
	_sauver_slots()
	_rafraichir_slots()
	app.message("Instantane %d memorise" % (i + 1))


func _slot_charger(i: int) -> void:
	if i < 0 or i >= _slots.size() or not (_slots[i] is Dictionary) or (_slots[i] as Dictionary).is_empty():
		app.message("Instantane %d vide" % (i + 1))
		return
	_precedent = _capture("Precedent")
	_restaurer(_slots[i])
	app.message("Instantane %d restaure" % (i + 1))


func _slot_vider(i: int) -> void:
	if i < 0 or i >= _slots.size():
		return
	_slots[i] = {}
	_sauver_slots()
	_rafraichir_slots()
	app.message("Instantane %d vide" % (i + 1))


func _rafraichir_slots() -> void:
	for i in mini(_slot_labels.size(), _slots.size()):
		var l: Label = _slot_labels[i]
		var s: Dictionary = _slots[i] if _slots[i] is Dictionary else {}
		if s.is_empty():
			l.text = "Slot %d : vide" % (i + 1)
		else:
			var d: String = str(s.get("date", ""))
			if d.length() > 16:
				d = d.substr(0, 16).replace("T", " ")
			l.text = "Slot %d : %s" % [i + 1, d]


func _lire_slots() -> void:
	if not FileAccess.file_exists(FICHIER_SLOTS):
		return
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER_SLOTS))
	if not (j is Array):
		return
	var a: Array = j
	for i in mini(3, a.size()):
		if a[i] is Dictionary:
			_slots[i] = a[i]


func _sauver_slots() -> void:
	var f: FileAccess = FileAccess.open(FICHIER_SLOTS, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_slots))
		f.close()


# -------------------------------------------------------------- hand tracking

func _mains_actives() -> bool:
	var tr: XRTracker = XRServer.get_tracker(&"left_hand")
	if tr is XRPositionalTracker:
		return str((tr as XRPositionalTracker).profile).contains("hand_interaction")
	return false


func _maj_mains(dt: float) -> void:
	if not _mains_actives() or app.main_g == null:
		_pinch_g_t = 0.0
		_pinch_g_declenche = false
		return
	var pinch: bool = app.main_g.get_float("trigger") > 0.72
	if pinch:
		_pinch_g_t += dt
		if _pinch_g_t >= 1.0 and not _pinch_g_declenche:
			_pinch_g_declenche = true
			app.basculer_panneau()
			app.message("Menu mains")
	else:
		_pinch_g_t = 0.0
		_pinch_g_declenche = false


# -------------------------------------------------------------- etat rapide

func _maj_etat(dt: float) -> void:
	_etat_t -= dt
	if _etat_t > 0.0 or _etat_label == null:
		return
	_etat_t = 0.5
	var mains: String = "Mains actives" if _mains_actives() else "Manettes"
	var monde_nom: String = str(Monde.NOMS[clampi(app.monde.courant, 0, Monde.NOMS.size() - 1)])
	var son_nom: String = str(Son.NOMS_AMBIANCES[clampi(app.son.ambiance, 0, Son.NOMS_AMBIANCES.size() - 1)])
	var vit: float = float(v8.get("_vitesse_mult"))
	var tel: bool = bool(v8.get("_teleportation"))
	var pass: bool = bool(v8.get("_passthrough"))
	_etat_label.text = "%s | Monde : %s | Son : %s\nVitesse x%.2f | Teleportation : %s | %s" % [mains, monde_nom, son_nom, vit, "oui" if tel else "non", "Passthrough" if pass else "VR"]
