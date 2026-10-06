class_name V27Manager
extends Node
## Mandala VR v27 : demarrage immersif.
## Au lancement, le dome aleatoire demarre tout seul (mondes, sons, mouvements
## tires au hasard, en dome autour de toi), menu ferme. Peut se desactiver dans Options.

const PREFS_V27: String = "user://v27_demarrage.json"
const DELAI_DEMARRAGE: float = 4.0

var app = null
var v26 = null
var _installe: bool = false
var _attente: float = 0.0
var _compte: float = 0.0
var _lance: bool = false
var _auto: bool = true


func _ready() -> void:
	app = get_parent()
	v26 = app.get_node_or_null("V26Manager")
	process_priority = 220
	_charger()


func _process(dt: float) -> void:
	if app == null or app.panneau == null:
		return
	if not _installe:
		_attente += dt
		var pret: bool = v26 != null and v26.get("_installe") == true
		if pret or _attente > 50.0:
			_installer()
		return
	if _lance or not _auto:
		return
	_compte += dt
	if _compte >= DELAI_DEMARRAGE:
		_lance = true
		_demarrer()


func _installer() -> void:
	_installe = true
	var page: Node = null
	for c in app.panneau.onglets.get_children():
		if str(c.name) == "V8":
			page = c
	if page == null or page.get_child_count() == 0:
		return
	var p: VBoxContainer = page.get_child(0) as VBoxContainer
	app.panneau._titre(p, "Demarrage")
	app.panneau._note(p, "Au lancement de l'application, le mode immersif aleatoire demarre tout seul : dome autour de toi, mondes, sons et mouvements tires au hasard. Le menu reste ferme (bouton menu gauche pour l'ouvrir).")
	app.panneau._bascule(p, "v27_auto", "Demarrer en mode immersif aleatoire", func() -> bool: return _auto, func(on: bool) -> void:
		_auto = on
		_sauver())
	var r: HBoxContainer = app.panneau._rangee(p)
	app.panneau._bouton(r, "Lancer maintenant", func() -> void: _demarrer())
	app.panneau._bouton(r, "Arreter", func() -> void: app.diff_stop())
	app.panneau.rafraichir()


func _demarrer() -> void:
	if app.panneau.visible:
		return
	app.dome_aleatoire_lancer()
	var aide: Node = app.get("_aide")
	if aide != null:
		(aide as Node3D).visible = false
	app.message("Mode immersif aleatoire - bouton menu gauche : reglages et arret")


func _charger() -> void:
	if not FileAccess.file_exists(PREFS_V27):
		return
	var f: FileAccess = FileAccess.open(PREFS_V27, FileAccess.READ)
	if f == null:
		return
	var j: Variant = JSON.parse_string(f.get_as_text())
	if j is Dictionary:
		_auto = bool((j as Dictionary).get("auto", true))


func _sauver() -> void:
	var f: FileAccess = FileAccess.open(PREFS_V27, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"auto": _auto}))
