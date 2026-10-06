class_name V17Manager
extends Node
## Mandala VR v17 : profondeur 3D et parallaxe confortable.
## Utilise uniquement les trois pivots deja presents dans Scene3D.

const PREFS_V17: String = "user://v17_depth.json"

var app = null
var v16 = null
var _installe: bool = false
var _prefs: Dictionary = {}

var _actif: bool = true
var _profondeur: float = 0.24
var _parallaxe: float = 0.28
var _flottement: float = 0.025
var _vitesse: float = 0.55

var _bases: Array = []
var _centre_tete: Vector3 = Vector3.ZERO
var _centre_pret: bool = false
var _temps: float = 0.0
var _etat_t: float = 0.0
var _etat_label: Label = null


func _ready() -> void:
	app = get_parent()
	v16 = app.get_node_or_null("V16Manager")
	# Scene3D applique rotation/echelle en priorite normale ; v17 passe ensuite
	# et ne touche qu'a la position des trois pivots.
	process_priority = 170
	_lire_prefs()


func _exit_tree() -> void:
	_restaurer_pivots()


func _process(dt: float) -> void:
	if app == null:
		return

	if not _installe:
		if app.sc != null and app.camera != null and app.panneau != null and v16 != null and bool(v16.get("_installe")):
			_installer()
		return

	_temps += dt
	_maj_centre_tete(dt)
	_appliquer_profondeur()

	_etat_t -= dt
	if _etat_t <= 0.0:
		_etat_t = 0.5
		_maj_etat()


# -------------------------------------------------------------- preferences

func _lire_prefs() -> void:
	if FileAccess.file_exists(PREFS_V17):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREFS_V17))
		if j is Dictionary:
			_prefs = j
	_actif = bool(_prefs.get("actif", true))
	_profondeur = clampf(float(_prefs.get("profondeur", 0.24)), 0.0, 0.55)
	_parallaxe = clampf(float(_prefs.get("parallaxe", 0.28)), 0.0, 0.65)
	_flottement = clampf(float(_prefs.get("flottement", 0.025)), 0.0, 0.08)
	_vitesse = clampf(float(_prefs.get("vitesse", 0.55)), 0.10, 1.60)


func _sauver_prefs() -> void:
	_prefs = {
		"actif": _actif,
		"profondeur": _profondeur,
		"parallaxe": _parallaxe,
		"flottement": _flottement,
		"vitesse": _vitesse,
	}
	var f: FileAccess = FileAccess.open(PREFS_V17, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_prefs))
		f.close()


# -------------------------------------------------------------- installation

func _installer() -> void:
	if app.sc.pivots.size() < 3:
		return

	_installe = true
	_bases.clear()
	for i in app.sc.pivots.size():
		var p: Node3D = app.sc.pivots[i]
		_bases.append(p.position)

	_recentrer_tete()

	var page: VBoxContainer = _page_rapide()
	if page != null:
		_installer_ui(page)

	app.panneau.rafraichir()
	app.message("Mandala VR v17 : profondeur 3D active")


func _page_rapide() -> VBoxContainer:
	for c in app.panneau.onglets.get_children():
		if str(c.name) == "Rapide" and c.get_child_count() > 0:
			return c.get_child(0) as VBoxContainer
	return null


# -------------------------------------------------------------- UI

func _installer_ui(p: VBoxContainer) -> void:
	app.panneau._titre(p, "Profondeur 3D du mandala")
	app.panneau._note(p,
		"Les trois calques prennent une vraie profondeur. Les petits mouvements de tete renforcent naturellement le relief sans suivre les deplacements au joystick.")

	var g: GridContainer = GridContainer.new()
	g.columns = 3
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(g)
	_gros(g, "Subtil", _preset_subtil)
	_gros(g, "Immersif", _preset_immersif)
	_gros(g, "Tunnel 3D", _preset_tunnel)

	app.panneau._bascule(p, "v17_actif", "Profondeur 3D active",
		func() -> bool: return _actif,
		func(on: bool) -> void: _set_actif(on))
	app.panneau._curseur(p, "v17_depth", "Ecart entre les calques", 0.0, 0.55, 0.01,
		func() -> float: return _profondeur,
		func(v: float) -> void: _set_profondeur(v), "%.2f m")
	app.panneau._curseur(p, "v17_para", "Parallaxe renforce", 0.0, 0.65, 0.01,
		func() -> float: return _parallaxe,
		func(v: float) -> void: _set_parallaxe(v), "%.2f")
	app.panneau._curseur(p, "v17_float", "Flottement des calques", 0.0, 0.08, 0.005,
		func() -> float: return _flottement,
		func(v: float) -> void: _set_flottement(v), "%.3f m")
	app.panneau._curseur(p, "v17_speed", "Vitesse du flottement", 0.10, 1.60, 0.05,
		func() -> float: return _vitesse,
		func(v: float) -> void: _set_vitesse(v), "%.2f")

	var r: HBoxContainer = app.panneau._rangee(p)
	app.panneau._bouton(r, "Recentrer le parallaxe", _recentrer_tete)
	app.panneau._bouton(r, "Couper la profondeur", func() -> void: _set_actif(false))

	_etat_label = Label.new()
	_etat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etat_label.add_theme_font_size_override("font_size", 22)
	p.add_child(_etat_label)


func _gros(parent: Control, texte: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(0, 72)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# -------------------------------------------------------------- presets

func _preset_subtil() -> void:
	_actif = true
	_profondeur = 0.11
	_parallaxe = 0.12
	_flottement = 0.010
	_vitesse = 0.40
	_fin_preset("Profondeur : Subtil")


func _preset_immersif() -> void:
	_actif = true
	_profondeur = 0.24
	_parallaxe = 0.28
	_flottement = 0.025
	_vitesse = 0.55
	_fin_preset("Profondeur : Immersif")


func _preset_tunnel() -> void:
	_actif = true
	_profondeur = 0.44
	_parallaxe = 0.48
	_flottement = 0.045
	_vitesse = 0.72
	_fin_preset("Profondeur : Tunnel 3D")


func _fin_preset(msg: String) -> void:
	_recentrer_tete()
	_appliquer_profondeur()
	_sauver_prefs()
	app.panneau.rafraichir()
	app.message(msg)


# -------------------------------------------------------------- setters

func _set_actif(on: bool) -> void:
	_actif = on
	if on:
		_recentrer_tete()
		_appliquer_profondeur()
	else:
		_restaurer_pivots()
	_sauver_prefs()
	app.message("Profondeur 3D : " + ("active" if on else "coupee"))


func _set_profondeur(v: float) -> void:
	_profondeur = clampf(v, 0.0, 0.55)
	_sauver_prefs()


func _set_parallaxe(v: float) -> void:
	_parallaxe = clampf(v, 0.0, 0.65)
	_sauver_prefs()


func _set_flottement(v: float) -> void:
	_flottement = clampf(v, 0.0, 0.08)
	_sauver_prefs()


func _set_vitesse(v: float) -> void:
	_vitesse = clampf(v, 0.10, 1.60)
	_sauver_prefs()


# -------------------------------------------------------------- profondeur

func _recentrer_tete() -> void:
	if app == null or app.camera == null:
		return
	_centre_tete = app.camera.position
	_centre_pret = true
	app.message("Parallaxe recentre")


func _maj_centre_tete(dt: float) -> void:
	if not _centre_pret:
		_recentrer_tete()
		return

	# Le centre suit tres lentement la tete : une posture durable devient le
	# nouveau neutre, alors qu'une inclinaison courte produit du parallaxe.
	var vitesse_centre: float = 0.22
	_centre_tete = _centre_tete.lerp(app.camera.position, clampf(dt * vitesse_centre, 0.0, 1.0))


func _delta_tete() -> Vector3:
	var d: Vector3 = app.camera.position - _centre_tete
	# Limites confort : les mouvements extremes ne peuvent pas faire glisser
	# le mandala brutalement.
	d.x = clampf(d.x, -0.22, 0.22)
	d.y = clampf(d.y, -0.18, 0.18)
	d.z = clampf(d.z, -0.16, 0.16)
	return d


func _facteur_confort() -> float:
	# Dans un dome, les pivots passent deja par une projection spherique.
	# On conserve seulement une petite partie de la profondeur pour ne pas
	# deformer la voute.
	if app.sc.dome > 0.35 or app.sc.dome_cible > 0.5:
		return 0.18

	# Si le relief geometrique natif est deja important, on baisse legerement
	# l'ecart des calques afin de ne pas exagerer l'effet.
	if app.sc.rel_mode != 0:
		return 0.72
	return 1.0


func _appliquer_profondeur() -> void:
	if not _actif or app.sc == null or app.sc.pivots.size() < 3:
		return

	var d: Vector3 = _delta_tete()
	var cf: float = _facteur_confort()
	var sep: float = _profondeur * cf
	var para: float = _parallaxe * cf
	var fl: float = _flottement * cf

	# Calque 0 (centre) proche, calque 1 neutre, calque 2 (exterieur) recule.
	# +Z rapproche du joueur car le mandala se trouve devant lui a Z negatif.
	var z0: float = sep
	var z1: float = 0.0
	var z2: float = -sep

	var osc0: float = sin(_temps * _vitesse * 1.07) * fl
	var osc1: float = sin(_temps * _vitesse * 0.83 + 2.1) * fl * 0.45
	var osc2: float = sin(_temps * _vitesse * 0.71 + 4.2) * fl

	# Translation opposee au mouvement de tete sur le plan de l'image :
	# elle renforce le parallaxe qui existe deja grace au vrai decalage Z.
	var p0: Vector3 = Vector3(-d.x * para, -d.y * para, z0 + osc0)
	var p1: Vector3 = Vector3(-d.x * para * 0.15, -d.y * para * 0.15, z1 + osc1)
	var p2: Vector3 = Vector3(d.x * para * 0.55, d.y * para * 0.55, z2 + osc2)

	var cibles: Array = [p0, p1, p2]
	for i in 3:
		var pivot: Node3D = app.sc.pivots[i]
		var base: Vector3 = _bases[i] if i < _bases.size() else Vector3.ZERO
		var cible: Vector3 = base + (cibles[i] as Vector3)
		# Lissage rapide mais non instantane pour eviter les micro-tremblements.
		pivot.position = pivot.position.lerp(cible, 0.18)


func _restaurer_pivots() -> void:
	if app == null or app.sc == null:
		return
	var n: int = mini(app.sc.pivots.size(), _bases.size())
	for i in n:
		var pivot: Node3D = app.sc.pivots[i]
		pivot.position = _bases[i]


# -------------------------------------------------------------- etat

func _maj_etat() -> void:
	if _etat_label == null:
		return
	if not _actif:
		_etat_label.text = "Profondeur 3D coupee"
		return

	var cf: float = _facteur_confort()
	var contexte: String = "dome protege" if cf < 0.3 else ("relief adapte" if cf < 0.9 else "plein effet")
	_etat_label.text = "Ecart %.0f cm | parallaxe %.0f%% | flottement %.1f cm | %s" % [
		_profondeur * cf * 100.0,
		_parallaxe * cf * 100.0,
		_flottement * cf * 100.0,
		contexte]
