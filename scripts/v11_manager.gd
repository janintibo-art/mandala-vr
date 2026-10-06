class_name V11Manager
extends Node
## Mandala VR v11 : gestes mains securises, recuperation automatique
## et confort du panneau en VR. Ce gestionnaire s'installe par-dessus v8/v10.

const PREFS_V11: String = "user://v11.json"
const RECUP_V11: String = "user://v11_recovery.json"
const AUTOSAVE_SECONDES: float = 60.0

var app = null
var v8 = null
var v10 = null
var _installe: bool = false
var _prefs: Dictionary = {}

# panneau
var _menu_distance: float = 1.35
var _menu_echelle: float = 1.0
var _panneau_visible_avant: bool = false

# gestes
var _poing_d_t: float = 0.0
var _poing_g_t: float = 0.0
var _deux_poings_t: float = 0.0
var _poing_d_fait: bool = false
var _poing_g_fait: bool = false
var _deux_poings_fait: bool = false
var _geste_label: Label3D = null

# session / recuperation
var _autosave_t: float = AUTOSAVE_SECONDES
var _session_t: float = 0.0
var _etat_t: float = 0.0
var _session_label: Label = null
var _recup_label: Label = null


func _ready() -> void:
	app = get_parent()
	v8 = app.get_node_or_null("V8Manager")
	v10 = app.get_node_or_null("V10Manager")
	# Doit passer AVANT main.gd afin de neutraliser les anciens raccourcis grip
	# quand les mains nues sont utilisees.
	process_priority = -100
	_lire_prefs()


func _exit_tree() -> void:
	_sauvegarde_auto(true)


func _process(dt: float) -> void:
	if app == null:
		return

	_session_t += dt

	# Securite mains : executee avant _entrees() de main.gd.
	_preparer_grips_mains()
	_maj_gestes(dt)

	if not _installe:
		if app.panneau != null and v8 != null and v10 != null and bool(v10.get("_installe")):
			_installer()
		return

	_maj_panneau()
	_maj_autosave(dt)
	_maj_etat(dt)


# -------------------------------------------------------------- preferences

func _lire_prefs() -> void:
	if FileAccess.file_exists(PREFS_V11):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREFS_V11))
		if j is Dictionary:
			_prefs = j
	_menu_distance = clampf(float(_prefs.get("menu_distance", 1.35)), 0.90, 2.20)
	_menu_echelle = clampf(float(_prefs.get("menu_echelle", 1.0)), 0.75, 1.35)


func _sauver_prefs() -> void:
	_prefs = {
		"menu_distance": _menu_distance,
		"menu_echelle": _menu_echelle,
	}
	var f: FileAccess = FileAccess.open(PREFS_V11, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_prefs))
		f.close()


# -------------------------------------------------------------- installation

func _installer() -> void:
	_installe = true
	_creer_hud_geste()
	var p: VBoxContainer = _page_rapide()
	if p != null:
		_installer_ui(p)
	_panneau_visible_avant = app.panneau.visible
	if app.panneau.visible:
		_appliquer_menu()
	app.panneau.rafraichir()
	app.message("Mandala VR v11 : gestes et recuperation prets")


func _page_rapide() -> VBoxContainer:
	for c in app.panneau.onglets.get_children():
		if str(c.name) == "Rapide" and c.get_child_count() > 0:
			return c.get_child(0) as VBoxContainer
	return null


func _installer_ui(p: VBoxContainer) -> void:
	app.panneau._titre(p, "Session et securite")
	app.panneau._note(p, "Recuperation automatique de la derniere session et gestes mains maintenus pour eviter les commandes accidentelles.")

	var rr: HBoxContainer = app.panneau._rangee(p)
	app.panneau._bouton(rr, "Sauver recuperation maintenant", func() -> void: _sauvegarde_auto(true), 470)
	app.panneau._bouton(rr, "Recuperer derniere session", _restaurer_recuperation, 430)

	_recup_label = Label.new()
	_recup_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recup_label.add_theme_font_size_override("font_size", 22)
	p.add_child(_recup_label)

	app.panneau._titre(p, "Confort du menu")
	app.panneau._curseur(p, "v11_dist", "Distance du panneau", 0.90, 2.20, 0.05,
		func() -> float: return _menu_distance,
		func(v: float) -> void: _set_menu_distance(v), "%.2f")
	app.panneau._curseur(p, "v11_scale", "Taille du panneau", 0.75, 1.35, 0.05,
		func() -> float: return _menu_echelle,
		func(v: float) -> void: _set_menu_echelle(v), "%.2f")
	var rm: HBoxContainer = app.panneau._rangee(p)
	app.panneau._bouton(rm, "Menu proche", func() -> void: _preset_menu(1.05, 1.10))
	app.panneau._bouton(rm, "Menu normal", func() -> void: _preset_menu(1.35, 1.00))
	app.panneau._bouton(rm, "Menu loin", func() -> void: _preset_menu(1.75, 1.10))

	app.panneau._titre(p, "Gestes mains securises")
	app.panneau._note(p,
		"Main droite fermee 0,8 s : Annuler.  Main gauche fermee 0,8 s : Recentrer.  " +
		"Deux mains fermees 1,2 s : Pause / reprise animation.  " +
		"Le pincement droit continue de dessiner et le pincement gauche maintenu ouvre le menu.")

	_session_label = Label.new()
	_session_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_session_label.add_theme_font_size_override("font_size", 22)
	p.add_child(_session_label)
	_maj_labels_recup()


func _creer_hud_geste() -> void:
	_geste_label = Label3D.new()
	_geste_label.pixel_size = 0.00085
	_geste_label.font_size = 38
	_geste_label.outline_size = 8
	_geste_label.no_depth_test = true
	_geste_label.position = Vector3(0.0, -0.29, -1.10)
	_geste_label.visible = false
	app.camera.add_child(_geste_label)


# -------------------------------------------------------------- panneau

func _set_menu_distance(v: float) -> void:
	_menu_distance = clampf(v, 0.90, 2.20)
	_sauver_prefs()
	if app.panneau.visible:
		_appliquer_menu()


func _set_menu_echelle(v: float) -> void:
	_menu_echelle = clampf(v, 0.75, 1.35)
	_sauver_prefs()
	if app.panneau.visible:
		_appliquer_menu()


func _preset_menu(distance: float, echelle: float) -> void:
	_menu_distance = distance
	_menu_echelle = echelle
	_sauver_prefs()
	_appliquer_menu()
	app.panneau.rafraichir()
	app.message("Confort du menu applique")


func _appliquer_menu() -> void:
	if app.camera == null or app.panneau == null:
		return
	var cam: Vector3 = app.camera.global_position
	var avant: Vector3 = -app.camera.global_transform.basis.z
	avant.y = 0.0
	if avant.length() < 0.01:
		avant = Vector3(0, 0, -1)
	avant = avant.normalized()
	var pos: Vector3 = cam + avant * _menu_distance
	pos.y = cam.y - 0.05
	app.panneau.global_transform = Transform3D(Basis.looking_at(avant, Vector3.UP), pos)
	app.panneau.scale = Vector3.ONE * _menu_echelle


func _maj_panneau() -> void:
	var visible: bool = app.panneau.visible
	if visible and not _panneau_visible_avant:
		# main.gd vient de placer le menu avec ses valeurs par defaut :
		# on reapplique les preferences v11 au frame suivant.
		_appliquer_menu()
	_panneau_visible_avant = visible


# -------------------------------------------------------------- mains

func _mains_actives() -> bool:
	var tr: XRTracker = XRServer.get_tracker(&"left_hand")
	if tr is XRPositionalTracker:
		return str((tr as XRPositionalTracker).profile).contains("hand_interaction")
	return false


func _preparer_grips_mains() -> void:
	if not _mains_actives() or app.main_d == null or app.main_g == null:
		return

	var gd: bool = app.main_d.get_float("grip") > 0.60
	var gg: bool = app.main_g.get_float("grip") > 0.60

	# main.gd utilise ces cles pour detecter le front montant du grip.
	# En les synchronisant avant son _process, le geste "fermer la main"
	# ne declenche plus instantanement Annuler / Retour / Toile vierge.
	app._bouts["grip_d_f"] = gd
	app._bouts["grip_g_f"] = gg


func _maj_gestes(dt: float) -> void:
	if not _mains_actives() or app.main_d == null or app.main_g == null:
		_reset_gestes()
		return

	var gd: bool = app.main_d.get_float("grip") > 0.68
	var gg: bool = app.main_g.get_float("grip") > 0.68
	var pd: bool = app.main_d.get_float("trigger") > 0.35

	if gd and gg:
		_poing_d_t = 0.0
		_poing_g_t = 0.0
		_poing_d_fait = false
		_poing_g_fait = false
		_deux_poings_t += dt
		_afficher_progression("PAUSE / REPRISE", _deux_poings_t / 1.20)
		if _deux_poings_t >= 1.20 and not _deux_poings_fait:
			_deux_poings_fait = true
			app.sc.anime = not app.sc.anime
			app.message("Animation : " + ("oui" if app.sc.anime else "pause"))
		return
	else:
		_deux_poings_t = 0.0
		_deux_poings_fait = false

	if gd and not pd:
		_poing_d_t += dt
		_afficher_progression("ANNULER", _poing_d_t / 0.80)
		if _poing_d_t >= 0.80 and not _poing_d_fait:
			_poing_d_fait = true
			app.annuler()
			app.message("Geste mains : Annuler")
	else:
		_poing_d_t = 0.0
		_poing_d_fait = false

	if gg:
		_poing_g_t += dt
		_afficher_progression("RECENTRER", _poing_g_t / 0.80)
		if _poing_g_t >= 0.80 and not _poing_g_fait:
			_poing_g_fait = true
			if v8 != null:
				v8.call("_recentrer_confort")
			else:
				app.retour_depart()
			app.message("Geste mains : Recentrer")
	else:
		_poing_g_t = 0.0
		_poing_g_fait = false

	if not gd and not gg and _geste_label != null:
		_geste_label.visible = false


func _afficher_progression(nom: String, u: float) -> void:
	if _geste_label == null:
		return
	var pct: int = clampi(int(round(clampf(u, 0.0, 1.0) * 100.0)), 0, 100)
	_geste_label.text = "%s  %d%%" % [nom, pct]
	_geste_label.visible = pct < 100


func _reset_gestes() -> void:
	_poing_d_t = 0.0
	_poing_g_t = 0.0
	_deux_poings_t = 0.0
	_poing_d_fait = false
	_poing_g_fait = false
	_deux_poings_fait = false
	if _geste_label != null:
		_geste_label.visible = false


# -------------------------------------------------------------- recuperation

func _sauvegarde_auto(force: bool = false) -> void:
	if app == null or v10 == null or app.sc == null:
		return
	if not force:
		if app.sc.occupe or app.sc.live_actif() or app.sc.traits.is_empty():
			return
		if v8 != null and bool(v8.get("_meditation")):
			return

	var snap: Variant = v10.call("_capture", "Recuperation")
	if not (snap is Dictionary):
		return
	var d: Dictionary = snap
	d["v11_recup"] = true
	d["date_recup"] = Time.get_datetime_string_from_system()

	var f: FileAccess = FileAccess.open(RECUP_V11, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d))
		f.close()
		_maj_labels_recup()
		if force:
			app.message("Recuperation de session sauvegardee")


func _maj_autosave(dt: float) -> void:
	_autosave_t -= dt
	if _autosave_t > 0.0:
		return
	_autosave_t = AUTOSAVE_SECONDES
	_sauvegarde_auto(false)


func _restaurer_recuperation() -> void:
	if not FileAccess.file_exists(RECUP_V11):
		app.message("Aucune session a recuperer")
		return
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECUP_V11))
	if not (j is Dictionary):
		app.message("Recuperation invalide")
		return
	var courant: Variant = v10.call("_capture", "Precedent")
	if courant is Dictionary:
		v10.set("_precedent", courant)
	v10.call("_restaurer", j)
	app.message("Derniere session recuperee")


func _maj_labels_recup() -> void:
	if _recup_label == null:
		return
	if not FileAccess.file_exists(RECUP_V11):
		_recup_label.text = "Recuperation : aucune sauvegarde pour le moment."
		return
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(RECUP_V11))
	if j is Dictionary:
		var d: String = str((j as Dictionary).get("date_recup", (j as Dictionary).get("date", "")))
		_recup_label.text = "Derniere recuperation : " + d.replace("T", " ")
	else:
		_recup_label.text = "Recuperation presente mais illisible."


# -------------------------------------------------------------- etat

func _maj_etat(dt: float) -> void:
	_etat_t -= dt
	if _etat_t > 0.0 or _session_label == null:
		return
	_etat_t = 1.0
	var total: int = int(_session_t)
	var h: int = total / 3600
	var m: int = (total % 3600) / 60
	var s: int = total % 60
	var mains: String = "Mains" if _mains_actives() else "Manettes"
	var recup: String = "active" if FileAccess.file_exists(RECUP_V11) else "en attente"
	_session_label.text = "Session %02d:%02d:%02d | %s | recuperation auto : %s" % [h, m, s, mains, recup]
