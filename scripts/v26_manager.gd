class_name V26Manager
extends Node
## Mandala VR v26/v34 : navigation principale unifiee.
## v34 : Accueil, Creer, Univers, Experiences, Galerie et Reglages deviennent
## les familles officielles. Les pages inconnues ne sont plus melangees au dernier
## groupe et la barre d'actions de creation n'apparait plus dans les experiences.

const GROUPES: Array = [
	["Accueil", ["Accueil"]],
	["Creer", ["Rapide", "Modeles", "Genres", "Trait"]],
	["Univers", ["Couleurs", "Lumiere", "Style", "Eclat", "Monde"]],
	["Experiences", ["Sensations", "Course", "Tir", "Diffusion"]],
	["Galerie", ["Creations"]],
	["Reglages", ["Mouvement", "Relief", "V8"]],
]
const VIOLET: Color = Color(0.48, 0.45, 0.84)

var app = null
var v21 = null
var _installe: bool = false
var _attente: float = 0.0
var _nav: VBoxContainer = null
var _rang_groupes: HBoxContainer = null
var _rang_pages: HBoxContainer = null
var _barre: HBoxContainer = null
var _btn_groupes: Array = []
var _groupe: int = 0
var _nb_pages: int = -1
var _t: float = 0.0


func _ready() -> void:
	app = get_parent()
	v21 = app.get_node_or_null("V21Manager")
	process_priority = 210


func _process(dt: float) -> void:
	if app == null:
		return
	if not _installe:
		_attente += dt
		if app.panneau == null:
			return
		var pret: bool = v21 != null and v21.get("_installe") == true
		if pret or _attente > 40.0:
			_installer()
		return
	_t -= dt
	if _t <= 0.0:
		_t = 0.3
		_synchroniser()


func _fond_col() -> VBoxContainer:
	var o: TabContainer = app.panneau.onglets
	return o.get_parent() as VBoxContainer


func _installer() -> void:
	_installe = true
	var o: TabContainer = app.panneau.onglets
	var col: VBoxContainer = _fond_col()
	if col == null:
		return
	o.tabs_visible = false

	_nav = VBoxContainer.new()
	_nav.name = "V26Nav"
	_nav.add_theme_constant_override("separation", 6)
	_rang_groupes = HBoxContainer.new()
	_rang_groupes.add_theme_constant_override("separation", 10)
	_nav.add_child(_rang_groupes)
	_rang_pages = HBoxContainer.new()
	_rang_pages.add_theme_constant_override("separation", 8)
	_nav.add_child(_rang_pages)

	for i in GROUPES.size():
		var b: Button = Button.new()
		b.text = str((GROUPES[i] as Array)[0])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 62)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_pastille(b, 30, 24)
		b.pressed.connect(_choisir_groupe.bind(i))
		_rang_groupes.add_child(b)
		_btn_groupes.append(b)

	col.add_child(_nav)
	col.move_child(_nav, o.get_index())

	_barre = HBoxContainer.new()
	_barre.name = "V26Barre"
	_barre.add_theme_constant_override("separation", 8)
	var actions: Array = [
		["Annuler", "_a_annuler"], ["Hasard", "_a_hasard"], ["Enregistrer", "_a_enregistrer"],
		["Toile vierge", "_a_vierge"], ["Animer / Pause", "_a_animer"], ["Plan / Dome", "_a_dome"],
	]
	for a in actions:
		var b2: Button = Button.new()
		b2.text = str(a[0])
		b2.custom_minimum_size = Vector2(0, 58)
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b2.add_theme_font_size_override("font_size", 24)
		b2.pressed.connect(Callable(self, str(a[1])))
		_barre.add_child(b2)

	col.add_child(_barre)
	col.move_child(_barre, app.panneau._bas.get_index())

	_synchroniser()


func _pastille(b: Button, rayon: int, taille: int) -> void:
	b.add_theme_font_size_override("font_size", taille)
	for etat in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var s: StyleBoxFlat = StyleBoxFlat.new()
		s.set_corner_radius_all(rayon)
		s.content_margin_left = 20
		s.content_margin_right = 20
		s.content_margin_top = 8
		s.content_margin_bottom = 8
		var on: bool = etat == "pressed" or etat == "hover_pressed"
		s.bg_color = VIOLET if on else (Color(0.24, 0.26, 0.38) if etat == "hover" else Color(0.13, 0.14, 0.21))
		s.border_color = Color(1, 1, 1, 0.85) if on else Color(1, 1, 1, 0.16)
		s.set_border_width_all(2 if on else 1)
		if on:
			s.shadow_color = Color(0.5, 0.47, 1.0, 0.55)
			s.shadow_size = 10
		b.add_theme_stylebox_override(etat, s)
	b.add_theme_color_override("font_color", Color(0.8, 0.84, 0.95))
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)


func _pages_du_groupe(g: int) -> Array:
	if g < 0 or g >= GROUPES.size():
		return []
	var o: TabContainer = app.panneau.onglets
	var noms: Array = (GROUPES[g] as Array)[1]
	var out: Array = []
	for i in o.get_child_count():
		var nom: String = str(o.get_child(i).name)
		if noms.has(nom):
			out.append(i)
	return out


func _groupe_de_page(i: int) -> int:
	var o: TabContainer = app.panneau.onglets
	if i < 0 or i >= o.get_child_count():
		return -1
	var nom: String = str(o.get_child(i).name)
	for g in GROUPES.size():
		if ((GROUPES[g] as Array)[1] as Array).has(nom):
			return g
	return -1


func _choisir_groupe(g: int) -> void:
	_groupe = g
	var pages: Array = _pages_du_groupe(g)
	var o: TabContainer = app.panneau.onglets
	if pages.size() > 0 and not pages.has(o.current_tab):
		o.current_tab = int(pages[0])
	_nb_pages = -1
	_synchroniser()


func _choisir_page(i: int) -> void:
	app.panneau.onglets.current_tab = i
	_synchroniser()


func _synchroniser() -> void:
	var o: TabContainer = app.panneau.onglets

	if o.current_tab >= 0 and o.get_child_count() > 0:
		var gc: int = _groupe_de_page(o.current_tab)
		if gc != _groupe:
			_groupe = gc
			_nb_pages = -1

	for i in _btn_groupes.size():
		(_btn_groupes[i] as Button).set_pressed_no_signal(i == _groupe)

	var pages: Array = _pages_du_groupe(_groupe)
	if pages.size() != _nb_pages or _rang_pages.get_child_count() != pages.size():
		_nb_pages = pages.size()
		for c in _rang_pages.get_children():
			_rang_pages.remove_child(c)
			c.queue_free()
		for idx in pages:
			var b: Button = Button.new()
			b.text = o.get_tab_title(int(idx))
			b.toggle_mode = true
			b.custom_minimum_size = Vector2(0, 52)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_pastille(b, 22, 24)
			b.pressed.connect(_choisir_page.bind(int(idx)))
			_rang_pages.add_child(b)

	_rang_pages.visible = pages.size() > 1
	for k in _rang_pages.get_child_count():
		if k < pages.size():
			(_rang_pages.get_child(k) as Button).set_pressed_no_signal(int(pages[k]) == o.current_tab)

	# La barre Annuler / Hasard / Toile vierge n'a de sens que pour la creation.
	if _barre != null:
		_barre.visible = _groupe == 1


# ------------------------------------------------------------ barre d'actions

func _a_annuler() -> void:
	app.annuler()


func _a_enregistrer() -> void:
	app.sauver()


func _a_vierge() -> void:
	var v10: Node = app.get_node_or_null("V10Manager")
	if v10 != null and v10.has_method("_action_vierge"):
		v10.call("_action_vierge")
	else:
		app.vierge()


func _a_hasard() -> void:
	var v10: Node = app.get_node_or_null("V10Manager")
	if v10 != null and v10.has_method("_action_hasard"):
		v10.call("_action_hasard")


func _a_animer() -> void:
	if v21 != null and v21.has_method("_anim_bascule"):
		v21.call("_anim_bascule")


func _a_dome() -> void:
	var v10: Node = app.get_node_or_null("V10Manager")
	if v10 != null and v10.has_method("_toggle_dome"):
		v10.call("_toggle_dome")
