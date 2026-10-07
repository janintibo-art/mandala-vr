class_name V28Manager
extends Node
## Mandala VR v28 : arriere-plans garantis et beaucoup plus varies.
## L'ancien monde 0 devient "Auto sombre". Les anciennes scenes qui n'avaient
## aucun monde recoivent automatiquement un fond sombre choisi dans une famille.

const PREFS_V28: String = "user://v28_backgrounds.json"

const SOMBRES: Array = [1, 2, 3, 4, 6, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17, 18, 19]
const COSMIQUES: Array = [1, 2, 3, 11, 16, 19]
const NATURE: Array = [3, 4, 8, 10, 12, 13, 17]
const CHAUDS: Array = [5, 7, 9, 14, 18]
const ZEN: Array = [3, 13, 15, 17]
const SOMBRES_PROFONDS: Array = [1, 2, 4, 6, 12, 16, 19]

var app = null
var v27 = null
var _installe: bool = false
var _prefs: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _variation_auto: bool = true
var _monde_avant: int = -1
var _etat_label: Label = null
var _etat_t: float = 0.0
var _en_changement: bool = false


func _ready() -> void:
	app = get_parent()
	v27 = app.get_node_or_null("V27Manager")
	process_priority = 230
	_rng.randomize()
	_charger()


func _process(dt: float) -> void:
	if app == null or app.monde == null or app.panneau == null:
		return

	if not _installe:
		var pret: bool = v27 != null and bool(v27.get("_installe"))
		if pret:
			_installer()
		return

	var courant: int = app.monde.courant
	if courant != _monde_avant:
		_monde_avant = courant
		if courant == 0 and _variation_auto and not _en_changement:
			_choisir(SOMBRES)
			return

	_etat_t -= dt
	if _etat_t <= 0.0:
		_etat_t = 0.6
		_maj_etat()


func _installer() -> void:
	_installe = true
	_monde_avant = app.monde.courant

	# Les anciennes scenes sans monde ne restent plus sur un vide clair.
	if app.monde.courant == 0 and _variation_auto:
		_choisir(SOMBRES)

	var p: VBoxContainer = _page_monde()
	if p != null:
		_installer_ui(p)

	app.panneau.rafraichir()
	app.message("v28 : arriere-plans garantis et 8 nouveaux mondes")


func _page_monde() -> VBoxContainer:
	for c in app.panneau.onglets.get_children():
		if str(c.name) == "Monde" and c.get_child_count() > 0:
			return c.get_child(0) as VBoxContainer
	return null


func _installer_ui(p: VBoxContainer) -> void:
	app.panneau._titre(p, "Arriere-plans v28")
	app.panneau._note(p,
		"Il n'y a plus de scene sans fond. Les anciennes scenes sur 'Aucun' passent automatiquement sur un fond sombre. 8 nouveaux univers portent le total a 20.")

	var g: GridContainer = GridContainer.new()
	g.columns = 3
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(g)
	_gros(g, "Surprise", func() -> void: _choisir_tout())
	_gros(g, "Cosmique", func() -> void: _choisir(COSMIQUES))
	_gros(g, "Nature", func() -> void: _choisir(NATURE))
	_gros(g, "Chaud", func() -> void: _choisir(CHAUDS))
	_gros(g, "Zen", func() -> void: _choisir(ZEN))
	_gros(g, "Sombre profond", func() -> void: _choisir(SOMBRES_PROFONDS))

	app.panneau._bascule(p, "v28_auto",
		"Varier automatiquement les anciennes scenes sans fond",
		func() -> bool: return _variation_auto,
		func(on: bool) -> void: _set_variation_auto(on))

	var r: HBoxContainer = app.panneau._rangee(p)
	app.panneau._bouton(r, "Autre fond", _autre_fond)
	app.panneau._bouton(r, "Auto sombre", func() -> void:
		_variation_auto = true
		_sauver()
		_choisir(SOMBRES))

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


func _choisir_tout() -> void:
	var candidats: Array = []
	for i in range(1, Monde.NOMS.size()):
		candidats.append(i)
	_choisir(candidats)


func _autre_fond() -> void:
	var candidats: Array = []
	for i in range(1, Monde.NOMS.size()):
		if i != app.monde.courant:
			candidats.append(i)
	_choisir(candidats)


func _choisir(candidats: Array) -> void:
	if candidats.is_empty():
		return

	var i: int = int(candidats[_rng.randi_range(0, candidats.size() - 1)])
	if candidats.size() > 1 and i == app.monde.courant:
		for _k in 4:
			i = int(candidats[_rng.randi_range(0, candidats.size() - 1)])
			if i != app.monde.courant:
				break

	_en_changement = true
	app.set_monde(i)
	_monde_avant = i
	_en_changement = false
	app.message("Arriere-plan : " + str(Monde.NOMS[i]))


func _set_variation_auto(on: bool) -> void:
	_variation_auto = on
	_sauver()
	if on and app.monde.courant == 0:
		_choisir(SOMBRES)


func _charger() -> void:
	if not FileAccess.file_exists(PREFS_V28):
		return
	var f: FileAccess = FileAccess.open(PREFS_V28, FileAccess.READ)
	if f == null:
		return
	var j: Variant = JSON.parse_string(f.get_as_text())
	if j is Dictionary:
		_variation_auto = bool((j as Dictionary).get("variation_auto", true))


func _sauver() -> void:
	var f: FileAccess = FileAccess.open(PREFS_V28, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"variation_auto": _variation_auto}))


func _maj_etat() -> void:
	if _etat_label == null:
		return
	var i: int = clampi(app.monde.courant, 0, Monde.NOMS.size() - 1)
	_etat_label.text = "%s | %d arriere-plans | auto %s" % [
		str(Monde.NOMS[i]),
		Monde.NOMS.size(),
		"oui" if _variation_auto else "non"]
