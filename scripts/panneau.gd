class_name Panneau
extends Node3D
## Menu VR : une interface Godot classique rendue dans un SubViewport,
## affichee sur un grand ecran flottant et pilotee par le rayon de la manette.

const LARG: int = 1600
const HAUT: int = 1000
const TAILLE: Vector2 = Vector2(1.76, 1.10)

var app: Node = null
var vp: SubViewport
var ecran: MeshInstance3D
var onglets: TabContainer
var _bas: Label
var _sl: Dictionary = {}
var _gr: Dictionary = {}
var _tg: Dictionary = {}
var _presse: bool = false
var _der: Vector2 = Vector2.ZERO
var _dedans: bool = false
var _couleurs_perso: PackedColorArray = PackedColorArray()
var _rang_perso: HBoxContainer
var _picker: ColorPicker
var _liste_creations: VBoxContainer
var _zone_listes: VBoxContainer
var _zone_seq: VBoxContainer
var _famille: int = 0
var _grilles_genres: Array = []
var _liste_choisie: int = 0


class Pastille extends Button:
	var cols: PackedColorArray = PackedColorArray()
	var etiquette: String = ""

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2(4, 4), size - Vector2(8, 8))
		if cols.size() > 0:
			var w: float = r.size.x / float(cols.size())
			for i in cols.size():
				draw_rect(Rect2(r.position + Vector2(w * float(i), 0), Vector2(w + 1.0, r.size.y)), cols[i])
		if etiquette != "":
			var f: Font = get_theme_default_font()
			var fs: int = 22
			draw_string_outline(f, Vector2(12, size.y * 0.5 + 6), etiquette, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, fs, 6, Color(0, 0, 0, 0.9))
			draw_string(f, Vector2(12, size.y * 0.5 + 6), etiquette, HORIZONTAL_ALIGNMENT_LEFT, size.x - 20, fs, Color(1, 1, 1, 1))
		if button_pressed:
			draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color(1, 1, 1, 1), false, 4.0)
		elif is_hovered():
			draw_rect(Rect2(Vector2(1, 1), size - Vector2(2, 2)), Color(1, 1, 1, 0.5), false, 2.0)


func _ready() -> void:
	vp = SubViewport.new()
	vp.size = Vector2i(LARG, HAUT)
	vp.transparent_bg = false
	vp.gui_embed_subwindows = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)

	var fond: PanelContainer = PanelContainer.new()
	fond.theme = _theme()
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(fond)
	var col: VBoxContainer = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	fond.add_child(col)

	onglets = TabContainer.new()
	onglets.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(onglets)
	_bas = Label.new()
	_bas.text = "Mandala VR"
	_bas.add_theme_font_size_override("font_size", 24)
	col.add_child(_bas)

	_onglet_genres()
	_onglet_trait()
	_onglet_couleurs()
	_onglet_lumiere()
	_onglet_relief()
	_onglet_creations()
	_onglet_diffusion()
	_onglet_scenes()
	onglets.tab_changed.connect(_sur_onglet)

	ecran = MeshInstance3D.new()
	var q: QuadMesh = QuadMesh.new()
	q.size = TAILLE
	ecran.mesh = q
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = vp.get_texture()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	ecran.material_override = m
	add_child(ecran)
	# liseré
	var cadre: MeshInstance3D = MeshInstance3D.new()
	var q2: QuadMesh = QuadMesh.new()
	q2.size = TAILLE + Vector2(0.04, 0.04)
	cadre.mesh = q2
	var m2: StandardMaterial3D = StandardMaterial3D.new()
	m2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m2.albedo_color = Color(0.4, 0.6, 1.0)
	cadre.material_override = m2
	cadre.position = Vector3(0, 0, -0.003)
	add_child(cadre)


# ------------------------------------------------------------------ theme

func _style(c: Color, rayon: int = 10, marge_h: int = 14, marge_v: int = 8) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(rayon)
	s.content_margin_left = marge_h
	s.content_margin_right = marge_h
	s.content_margin_top = marge_v
	s.content_margin_bottom = marge_v
	return s


func _theme() -> Theme:
	var t: Theme = Theme.new()
	t.default_font_size = 28
	t.set_stylebox("panel", "PanelContainer", _style(Color(0.06, 0.07, 0.12), 0, 16, 12))
	for etat in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		var c: Color = Color(0.17, 0.19, 0.28)
		if etat == "hover":
			c = Color(0.26, 0.30, 0.44)
		elif etat == "pressed" or etat == "hover_pressed":
			c = Color(0.20, 0.42, 0.85)
		elif etat == "focus":
			c = Color(0.17, 0.19, 0.28)
		t.set_stylebox(etat, "Button", _style(c))
	t.set_color("font_color", "Button", Color(0.92, 0.94, 1.0))
	t.set_color("font_pressed_color", "Button", Color(1, 1, 1))
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_hover_pressed_color", "Button", Color(1, 1, 1))
	t.set_stylebox("tab_selected", "TabContainer", _style(Color(0.20, 0.42, 0.85), 8, 18, 10))
	t.set_stylebox("tab_unselected", "TabContainer", _style(Color(0.14, 0.16, 0.25), 8, 18, 10))
	t.set_stylebox("tab_hovered", "TabContainer", _style(Color(0.26, 0.30, 0.44), 8, 18, 10))
	t.set_stylebox("panel", "TabContainer", _style(Color(0.09, 0.10, 0.17), 8, 8, 8))
	t.set_font_size("font_size", "TabContainer", 28)
	t.set_color("font_selected_color", "TabContainer", Color.WHITE)
	t.set_color("font_unselected_color", "TabContainer", Color(0.8, 0.84, 0.95))
	t.set_color("font_hovered_color", "TabContainer", Color.WHITE)
	var fond_s: StyleBoxFlat = _style(Color(0.2, 0.22, 0.32), 8, 0, 0)
	fond_s.content_margin_top = 14.0
	fond_s.content_margin_bottom = 14.0
	t.set_stylebox("slider", "HSlider", fond_s)
	t.set_stylebox("grabber_area", "HSlider", _style(Color(0.3, 0.55, 1.0), 8, 0, 0))
	t.set_stylebox("grabber_area_highlight", "HSlider", _style(Color(0.4, 0.65, 1.0), 8, 0, 0))
	var gi: Image = Image.create(40, 40, false, Image.FORMAT_RGBA8)
	gi.fill(Color(0, 0, 0, 0))
	for y in 40:
		for x in 40:
			if Vector2(x - 19.5, y - 19.5).length() < 19.0:
				gi.set_pixel(x, y, Color(0.95, 0.97, 1.0))
	var tex: ImageTexture = ImageTexture.create_from_image(gi)
	t.set_icon("grabber", "HSlider", tex)
	t.set_icon("grabber_highlight", "HSlider", tex)
	t.set_icon("grabber_disabled", "HSlider", tex)
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("h_separation", "GridContainer", 10)
	t.set_constant("v_separation", "GridContainer", 10)
	t.set_stylebox("scroll", "VScrollBar", _style(Color(0.15, 0.16, 0.24), 8, 0, 0))
	t.set_stylebox("grabber", "VScrollBar", _style(Color(0.4, 0.6, 1.0), 8, 0, 0))
	t.set_stylebox("grabber_highlight", "VScrollBar", _style(Color(0.55, 0.72, 1.0), 8, 0, 0))
	t.set_stylebox("grabber_pressed", "VScrollBar", _style(Color(0.7, 0.85, 1.0), 8, 0, 0))
	return t


# ---------------------------------------------------------------- briques

func _page(titre: String) -> VBoxContainer:
	var sc: ScrollContainer = ScrollContainer.new()
	sc.name = titre
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	onglets.add_child(sc)
	var v: VBoxContainer = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(v)
	return v


func _titre(parent: Control, texte: String) -> void:
	var l: Label = Label.new()
	l.text = texte
	l.add_theme_font_size_override("font_size", 32)
	l.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	parent.add_child(l)


func _note(parent: Control, texte: String) -> void:
	var l: Label = Label.new()
	l.text = texte
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 23)
	l.add_theme_color_override("font_color", Color(0.7, 0.75, 0.88))
	parent.add_child(l)


func _bouton(parent: Control, texte: String, cb: Callable, largeur: int = 0) -> Button:
	var b: Button = Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(largeur, 64)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _rangee(parent: Control) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	parent.add_child(h)
	return h


func _grille(parent: Control, cle: String, noms: Array, colonnes: int, get: Callable, choisir: Callable, hauteur: int = 64) -> GridContainer:
	var g: GridContainer = GridContainer.new()
	g.columns = colonnes
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(g)
	var btns: Array = []
	for i in noms.size():
		var b: Button = Button.new()
		b.text = str(noms[i])
		b.toggle_mode = true
		b.clip_text = true
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, hauteur)
		b.pressed.connect(func() -> void:
			choisir.call(i)
			rafraichir())
		g.add_child(b)
		btns.append(b)
	if cle != "":
		_gr[cle] = {"btns": btns, "get": get}
	return g


func _curseur(parent: Control, cle: String, titre: String, mn: float, mx: float, pas: float, get: Callable, set: Callable, fmt: String = "%.2f") -> void:
	var h: HBoxContainer = _rangee(parent)
	var l: Label = Label.new()
	l.custom_minimum_size = Vector2(430, 0)
	l.text = titre
	h.add_child(l)
	var s: HSlider = HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = pas
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.custom_minimum_size = Vector2(500, 56)
	h.add_child(s)
	var lv: Label = Label.new()
	lv.custom_minimum_size = Vector2(110, 0)
	lv.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(lv)
	s.value_changed.connect(func(v: float) -> void:
		set.call(v)
		lv.text = fmt % v)
	_sl[cle] = {"s": s, "l": lv, "get": get, "fmt": fmt, "t": l, "titre": titre}


func _bascule(parent: Control, cle: String, texte: String, get: Callable, set: Callable) -> void:
	var b: CheckButton = CheckButton.new()
	b.text = texte
	b.custom_minimum_size = Vector2(0, 60)
	b.toggled.connect(func(on: bool) -> void: set.call(on))
	parent.add_child(b)
	_tg[cle] = {"b": b, "get": get}


func rafraichir() -> void:
	for k in _sl.keys():
		var d: Dictionary = _sl[k]
		var v: float = float((d["get"] as Callable).call())
		(d["s"] as HSlider).set_value_no_signal(v)
		(d["l"] as Label).text = str(d["fmt"]) % v
	for k in _gr.keys():
		var d: Dictionary = _gr[k]
		var cur: int = int((d["get"] as Callable).call())
		var btns: Array = d["btns"]
		for i in btns.size():
			(btns[i] as Button).set_pressed_no_signal(i == cur)
	for k in _tg.keys():
		var d: Dictionary = _tg[k]
		(d["b"] as CheckButton).set_pressed_no_signal(bool((d["get"] as Callable).call()))
	if _grilles_genres.size() > 0:
		for f in _grilles_genres.size():
			(_grilles_genres[f] as Control).visible = (f == _famille)


func message(t: String) -> void:
	_bas.text = t


# ----------------------------------------------------------- onglet genres

func _onglet_genres() -> void:
	var p: VBoxContainer = _page("Genres")
	_titre(p, "Genre (48)")
	var rf: HBoxContainer = _rangee(p)
	var noms_f: Array = Tables.NOMS_FAMILLES
	for f in noms_f.size():
		var b: Button = Button.new()
		b.text = str(noms_f[f])
		b.custom_minimum_size = Vector2(0, 60)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			_famille = f
			rafraichir())
		rf.add_child(b)
	for f in noms_f.size():
		var idx: Array = Tables.genres_de_famille(f)
		var noms: Array = []
		for gi in idx:
			noms.append(str(Tables.GENRES[int(gi)][0]))
		var g: GridContainer = _grille(p, "", noms, 4, Callable(), func(i: int) -> void: app.regler("genre", int(idx[i])))
		var bt: Array = []
		for ch in g.get_children():
			bt.append(ch)
		_gr["genre_%d" % f] = {"btns": bt, "get": func() -> int: return idx.find(int(app.reg.genre))}
		_grilles_genres.append(g)
	_curseur(p, "branches", "Branches (symetrie)", 2, 36, 1, func() -> float: return float(app.reg.branches), func(v: float) -> void: app.regler("branches", int(v)), "%d")
	_bascule(p, "miroir", "Miroir en plus", func() -> bool: return app.reg.miroir, func(on: bool) -> void: app.regler("miroir", on))
	_titre(p, "Pavage")
	_grille(p, "reseau", Tables.NOMS_RESEAUX, 6, func() -> int: return app.reg.reseau, func(i: int) -> void: app.regler("reseau", i))
	_titre(p, "Perles et symboles")
	_note(p, "Les symboles se posent avec les genres Tampons, Guirlande, Semis et Cascade. Les perles : genres Perles, Noeud, Semence.")
	var rs: HBoxContainer = _rangee(p)
	_bouton(rs, "Genre Tampons", func() -> void: app.regler("genre", Tables.genre_par_nom("Tampons")))
	_bouton(rs, "Genre Guirlande", func() -> void: app.regler("genre", Tables.genre_par_nom("Guirlande")))
	_bouton(rs, "Genre Perles", func() -> void: app.regler("genre", Tables.genre_par_nom("Perles")))
	_grille(p, "symbole", Tables.NOMS_SYMBOLES, 6, func() -> int: return app.reg.symbole, func(i: int) -> void: app.regler("symbole", i), 56)
	_curseur(p, "espacement", "Espacement des motifs", 2, 16, 1, func() -> float: return float(app.reg.espacement), func(v: float) -> void: app.regler("espacement", int(v)), "%d")
	_titre(p, "Fractales et mode infini")
	_note(p, "Genres fractals : famille Fractales ci-dessus. Pour un zoom sans fin, choisis le mouvement Infini ou Gouffre.")
	_grille(p, "motif", Tables.NOMS_MOTIFS, 6, func() -> int: return app.reg.motif, func(i: int) -> void: app.regler("motif", i))
	_curseur(p, "recursion", "Recursion du motif", 0, 4, 1, func() -> float: return float(app.reg.recursion), func(v: float) -> void: app.regler("recursion", int(v)), "%d")
	_curseur(p, "iterations", "Niveaux d'echelle", 2, 12, 1, func() -> float: return float(app.reg.iterations), func(v: float) -> void: app.regler("iterations", int(v)), "%d")
	_curseur(p, "reduction", "Reduction par niveau", 0.30, 0.95, 0.01, func() -> float: return app.reg.reduction, func(v: float) -> void: app.regler("reduction", v))
	_curseur(p, "torsion", "Torsion par niveau", 0.0, 1.2, 0.01, func() -> float: return app.reg.torsion, func(v: float) -> void: app.regler("torsion", v))
	_curseur(p, "segments_gen", "Segments du generateur", 2, 8, 1, func() -> float: return float(app.reg.segments_gen), func(v: float) -> void: app.regler("segments_gen", int(v)), "%d")
	var ri: HBoxContainer = _rangee(p)
	_bouton(ri, "Zoom infini", func() -> void: app.set_mouvement(7))
	_bouton(ri, "Gouffre", func() -> void: app.set_mouvement(8))
	_bouton(ri, "Arreter le zoom", func() -> void: app.set_mouvement(0))
	_bascule(p, "tout", "Les reglages modifient tout le dessin (sinon : prochains traits seulement)", func() -> bool: return app.tout, func(on: bool) -> void: app.tout = on)


# ------------------------------------------------------------ onglet trait

func _onglet_trait() -> void:
	var p: VBoxContainer = _page("Trait")
	_titre(p, "Epaisseur du trait")
	_curseur(p, "epaisseur", "Epaisseur", 0.3, 12.0, 0.1, func() -> float: return app.reg.epaisseur, func(v: float) -> void: app.regler("epaisseur", v), "%.1f")
	var h: HBoxContainer = _rangee(p)
	for e in [[0.5, "Filament"], [1.0, "Fin"], [1.6, "Moyen"], [3.0, "Epais"], [6.0, "Tres epais"], [11.0, "Geant"]]:
		var v: float = float(e[0])
		var b: Button = _bouton(h, str(e[1]), func() -> void:
			app.regler("epaisseur", v)
			rafraichir())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_curseur(p, "opacite", "Opacite", 0.1, 1.0, 0.01, func() -> float: return app.reg.opacite, func(v: float) -> void: app.regler("opacite", v))
	_note(p, "L'epaisseur et l'opacite s'appliquent aux nouveaux traits, et a tout le dessin si l'option « tout le dessin » est cochee (onglet Genres).")
	_titre(p, "Qualite d'affichage")
	_grille(p, "qualite", ["Eco", "Normal", "Maximum"], 3, func() -> int: return app.qualite, func(i: int) -> void: app.set_qualite(i))
	_note(p, "Plus la qualite est haute, plus le dessin est detaille (et plus le casque travaille).")


# --------------------------------------------------------- onglet couleurs

func _onglet_couleurs() -> void:
	var p: VBoxContainer = _page("Couleurs")
	_titre(p, "Mode de coloration (14)")
	_grille(p, "mode", Tables.NOMS_MODES, 5, func() -> int: return app.reg.mode, func(i: int) -> void: app.regler("mode", i))
	_titre(p, "Palettes")
	var g: GridContainer = GridContainer.new()
	g.columns = 4
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(g)
	_gr["palette_grille"] = {"btns": [], "get": func() -> int: return app.reg.palette}
	_construire_palettes(g)
	_pal_grille = g
	_titre(p, "Ma palette")
	_note(p, "Choisis une couleur, ajoute-la (jusqu'a 8), puis cree la palette.")
	_picker = ColorPicker.new()
	_picker.edit_alpha = false
	_picker.color = Color(1.0, 0.4, 0.2)
	_picker.sampler_visible = false
	_picker.color_modes_visible = false
	_picker.presets_visible = true
	_picker.custom_minimum_size = Vector2(0, 360)
	p.add_child(_picker)
	_rang_perso = _rangee(p)
	var r2: HBoxContainer = _rangee(p)
	_bouton(r2, "Ajouter la couleur", func() -> void: _ajouter_perso())
	_bouton(r2, "Creer la palette", func() -> void: _creer_perso())
	_bouton(r2, "Vider", func() -> void:
		_couleurs_perso = PackedColorArray()
		_maj_perso())
	_titre(p, "Fond")
	var rf: HBoxContainer = _rangee(p)
	var fbtns: Array = []
	for i in Tables.FONDS.size():
		var b: Pastille = Pastille.new()
		b.cols = PackedColorArray([Tables.FONDS[i]])
		b.etiquette = str(Tables.NOMS_FONDS[i])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			app.set_fond(i)
			rafraichir())
		rf.add_child(b)
		fbtns.append(b)
	_gr["fond"] = {"btns": fbtns, "get": func() -> int: return app.sc.fond}


var _pal_grille: GridContainer = null


func _construire_palettes(g: GridContainer) -> void:
	for c in g.get_children():
		c.queue_free()
	var btns: Array = []
	for i in Tables.palettes.size():
		var b: Pastille = Pastille.new()
		b.cols = Tables.palettes[i]["cols"]
		b.etiquette = str(Tables.palettes[i]["nom"])
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 64)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			app.regler("palette", i)
			rafraichir())
		g.add_child(b)
		btns.append(b)
	if _gr.has("palette_grille"):
		(_gr["palette_grille"] as Dictionary)["btns"] = btns
	_pal_btns = btns


var _pal_btns: Array = []


func palettes_changees() -> void:
	if _pal_grille != null:
		_construire_palettes(_pal_grille)
		rafraichir()


func _ajouter_perso() -> void:
	if _couleurs_perso.size() < 8:
		_couleurs_perso.append(_picker.color)
	_maj_perso()


func _maj_perso() -> void:
	for c in _rang_perso.get_children():
		c.queue_free()
	for c in _couleurs_perso:
		var r: ColorRect = ColorRect.new()
		r.color = c
		r.custom_minimum_size = Vector2(70, 56)
		_rang_perso.add_child(r)


func _creer_perso() -> void:
	if _couleurs_perso.size() < 2:
		message("Ajoute au moins deux couleurs.")
		return
	app.ajouter_palette_perso(_couleurs_perso)
	_couleurs_perso = PackedColorArray()
	_maj_perso()


# ---------------------------------------------------------- onglet lumiere

func _onglet_lumiere() -> void:
	var p: VBoxContainer = _page("Lumiere")
	_titre(p, "Effets lumineux")
	_bascule(p, "lumineux", "Traits lumineux (additifs). Decoche : traits opaques", func() -> bool: return app.sc.lumineux, func(on: bool) -> void: app.set_lumineux(on))
	_note(p, "Sur un fond clair les traits passent automatiquement en mode opaque.")
	_titre(p, "Ambiances")
	_grille(p, "", Presets.noms(), 5, Callable(), func(i: int) -> void: app.preset_fx(str(Presets.noms()[i])))
	_titre(p, "Reglages fins")
	_curseur(p, "fx_gain", "Intensite", 0.10, 1.6, 0.01, func() -> float: return app.sc.fx["gain"], func(v: float) -> void: app.set_fx("gain", v))
	_curseur(p, "fx_halo", "Halo", 0.0, 2.0, 0.01, func() -> float: return app.sc.fx["halo"], func(v: float) -> void: app.set_fx("halo", v))
	_curseur(p, "fx_coeur", "Coeur blanc", 0.0, 1.0, 0.01, func() -> float: return app.sc.fx["coeur"], func(v: float) -> void: app.set_fx("coeur", v))
	_curseur(p, "fx_scint", "Scintillement", 0.0, 1.0, 0.01, func() -> float: return app.sc.fx["scint"], func(v: float) -> void: app.set_fx("scint", v))
	_curseur(p, "fx_pulse", "Pulsation", 0.0, 1.0, 0.01, func() -> float: return app.sc.fx["pulse"], func(v: float) -> void: app.set_fx("pulse", v))
	_curseur(p, "fx_arc", "Arc-en-ciel mobile", 0.0, 1.0, 0.01, func() -> float: return app.sc.fx["arc"], func(v: float) -> void: app.set_fx("arc", v))
	_curseur(p, "fx_vit", "Vitesse des effets", 0.2, 3.0, 0.05, func() -> float: return app.sc.fx["vit"], func(v: float) -> void: app.set_fx("vit", v))


# ---------------------------------------------------------- onglet relief

func _onglet_relief() -> void:
	var p: VBoxContainer = _page("Relief")
	_titre(p, "Relief (10)")
	_grille(p, "relief", Tables.NOMS_RELIEFS, 5, func() -> int: return app.sc.rel_mode, func(i: int) -> void: app.set_relief(i))
	_curseur(p, "rel_h", "Hauteur du relief", 0.1, 1.2, 0.01, func() -> float: return app.sc.rel_h, func(v: float) -> void: app.set_relief_h(v))
	_curseur(p, "rel_lum", "Ombrage du relief", 0.0, 1.0, 0.01, func() -> float: return app.sc.rel_lum, func(v: float) -> void: app.set_relief_lum(v))
	_note(p, "Le relief est vraiment en 3D : tu peux voler au-dessus, autour et dedans avec le joystick.")
	_titre(p, "Mouvement (10)")
	_grille(p, "mouvement", Tables.NOMS_MOUVEMENTS, 5, func() -> int: return app.sc.mouvement, func(i: int) -> void: app.set_mouvement(i))
	_curseur(p, "vitesse", "Vitesse", 0.1, 3.0, 0.05, func() -> float: return app.sc.vitesse, func(v: float) -> void: app.set_vitesse(v))
	_bascule(p, "anime", "Animation en marche", func() -> bool: return app.sc.anime, func(on: bool) -> void: app.sc.anime = on)
	_bascule(p, "sol", "Grille au sol", func() -> bool: return app.sol_visible, func(on: bool) -> void: app.set_sol(on))
	_note(p, "Musique : sans micro dans cette version, le mouvement suit un rythme interne.")


# -------------------------------------------------------- onglet creations

func _onglet_creations() -> void:
	var p: VBoxContainer = _page("Creations")
	_titre(p, "Mes creations")
	var r: HBoxContainer = _rangee(p)
	_bouton(r, "Enregistrer la scene", func() -> void:
		app.sauver()
		rafraichir_creations())
	_bouton(r, "Coller depuis le presse-papiers", func() -> void:
		app.coller()
		rafraichir_creations())
	_bouton(r, "Actualiser", func() -> void: rafraichir_creations())
	_note(p, "Les creations sont dans le casque. Le format est le meme que sur le telephone : une creation du telephone se charge ici (voir le README).")
	_liste_creations = VBoxContainer.new()
	_liste_creations.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(_liste_creations)


func rafraichir_creations() -> void:
	for c in _liste_creations.get_children():
		c.queue_free()
	var l: Array = Stockage.lister()
	if l.is_empty():
		_note(_liste_creations, "Aucune creation pour l'instant.")
	var lists: Array = Stockage.listes()
	var cible: String = ""
	if _liste_choisie < lists.size():
		cible = str((lists[_liste_choisie] as Dictionary).get("n", ""))
	for it in l:
		var d: Dictionary = it
		var id: String = str(d["id"])
		var h: HBoxContainer = _rangee(_liste_creations)
		var lab: Label = Label.new()
		lab.text = "%s  (%s)" % [str(d["nom"]), str(d["origine"])]
		lab.clip_text = true
		lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(lab)
		_bouton(h, "Charger", func() -> void: app.charger(id), 170)
		if cible != "":
			_bouton(h, "+ " + cible.left(10), func() -> void:
				app.liste_ajouter(_liste_choisie, id), 230)
		if id.begins_with("u:"):
			_bouton(h, "Suppr.", func() -> void:
				app.supprimer(id)
				rafraichir_creations(), 150)


# -------------------------------------------------------- onglet diffusion

func _onglet_diffusion() -> void:
	var p: VBoxContainer = _page("Diffusion")
	_titre(p, "Listes de diffusion")
	var r: HBoxContainer = _rangee(p)
	_bouton(r, "Nouvelle liste", func() -> void:
		app.liste_nouvelle()
		rafraichir_diffusion())
	_bouton(r, "Supprimer la liste", func() -> void:
		app.liste_supprimer(_liste_choisie)
		_liste_choisie = 0
		rafraichir_diffusion())
	_zone_listes = VBoxContainer.new()
	_zone_listes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(_zone_listes)
	_titre(p, "Lecture")
	var r2: HBoxContainer = _rangee(p)
	_bouton(r2, "Lecture", func() -> void: app.diff_lire(_liste_choisie))
	_bouton(r2, "Precedent", func() -> void: app.diff_pas(-1))
	_bouton(r2, "Suivant", func() -> void: app.diff_pas(1))
	_bouton(r2, "Stop", func() -> void: app.diff_stop())
	_grille(p, "transition", ["Coupure", "Fondu noir", "Fondu enchaine"], 3, func() -> int: return app.diff_transition(_liste_choisie), func(i: int) -> void: app.diff_set_transition(_liste_choisie, i))
	_curseur(p, "duree_def", "Duree par defaut (s)", 5, 120, 5, func() -> float: return app.duree_defaut, func(v: float) -> void: app.duree_defaut = v, "%d")
	_titre(p, "Sequences de la liste")
	_zone_seq = VBoxContainer.new()
	_zone_seq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(_zone_seq)
	_titre(p, "Vizu automatique")
	_note(p, "Enchaine sans fin des scenes tirees au hasard, avec mouvement.")
	_curseur(p, "vizu_duree", "Duree par scene (s)", 8, 90, 1, func() -> float: return app.vizu_duree, func(v: float) -> void: app.vizu_duree = v, "%d")
	var r3: HBoxContainer = _rangee(p)
	_bouton(r3, "Lancer Vizu", func() -> void: app.vizu_lancer())
	_bouton(r3, "Arreter", func() -> void: app.diff_stop())


func rafraichir_diffusion() -> void:
	for c in _zone_listes.get_children():
		c.queue_free()
	var lists: Array = Stockage.listes()
	if lists.is_empty():
		_note(_zone_listes, "Aucune liste. Cree-en une, puis ajoute des creations depuis l'onglet Creations.")
		_liste_choisie = 0
	else:
		_liste_choisie = clampi(_liste_choisie, 0, lists.size() - 1)
		var g: GridContainer = GridContainer.new()
		g.columns = 3
		g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_zone_listes.add_child(g)
		for i in lists.size():
			var b: Button = Button.new()
			b.text = "%s (%d)" % [str((lists[i] as Dictionary).get("n", "?")), ((lists[i] as Dictionary).get("o", []) as Array).size()]
			b.toggle_mode = true
			b.button_pressed = (i == _liste_choisie)
			b.custom_minimum_size = Vector2(0, 64)
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			b.pressed.connect(func() -> void:
				_liste_choisie = i
				rafraichir_diffusion())
			g.add_child(b)
	for c in _zone_seq.get_children():
		c.queue_free()
	if _liste_choisie < lists.size():
		var seqs: Array = (lists[_liste_choisie] as Dictionary).get("o", [])
		if seqs.is_empty():
			_note(_zone_seq, "Liste vide.")
		for i in seqs.size():
			var s: Dictionary = seqs[i]
			var h: HBoxContainer = _rangee(_zone_seq)
			var lab: Label = Label.new()
			lab.text = "%d. %s" % [i + 1, Stockage.nom_de(str(s.get("c", "")))]
			lab.clip_text = true
			lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(lab)
			var dur: float = float(s.get("d", 0.0))
			_bouton(h, "-", func() -> void:
				app.seq_regler(_liste_choisie, i, "d", maxf(0.0, dur - 5.0))
				rafraichir_diffusion(), 70)
			var ld: Label = Label.new()
			ld.text = "auto" if dur <= 0.0 else "%d s" % int(dur)
			ld.custom_minimum_size = Vector2(110, 0)
			ld.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			h.add_child(ld)
			_bouton(h, "+", func() -> void:
				app.seq_regler(_liste_choisie, i, "d", dur + 5.0)
				rafraichir_diffusion(), 70)
			var mv: int = int(s.get("m", -1))
			_bouton(h, "Mvt: " + ("auto" if mv < 0 else str(Tables.NOMS_MOUVEMENTS[mv]).left(7)), func() -> void:
				var nv: int = mv + 1
				if nv >= Tables.NOMS_MOUVEMENTS.size():
					nv = -1
				app.seq_regler(_liste_choisie, i, "m", nv)
				rafraichir_diffusion(), 260)
			_bouton(h, "Haut", func() -> void:
				app.seq_deplacer(_liste_choisie, i, -1)
				rafraichir_diffusion(), 100)
			_bouton(h, "x", func() -> void:
				app.seq_retirer(_liste_choisie, i)
				rafraichir_diffusion(), 70)


# ----------------------------------------------------------- onglet scenes

func _onglet_scenes() -> void:
	var p: VBoxContainer = _page("Scenes")
	_titre(p, "Scenes livrees")
	var noms: Array = []
	for c in Generateur.configs_livrees():
		noms.append(str((c as Dictionary)["nom"]))
	_grille(p, "", noms, 3, Callable(), func(i: int) -> void: app.scene_livree(i))
	_titre(p, "Hasard")
	var r: HBoxContainer = _rangee(p)
	_bouton(r, "Tirage au sort", func() -> void: app.hasard())
	_bouton(r, "Lancer Vizu", func() -> void: app.vizu_lancer())
	_titre(p, "Dessin")
	var r2: HBoxContainer = _rangee(p)
	_bouton(r2, "Annuler le dernier trait", func() -> void: app.annuler())
	_bouton(r2, "Toile vierge", func() -> void: app.vierge())
	_bouton(r2, "Retour au depart", func() -> void: app.retour_depart())
	_titre(p, "Manettes")
	_note(p, "Joystick gauche : voler. Gachette gauche : accelerer. Joystick droit : tourner / monter. Gachette droite : dessiner. A : genre suivant. B : palette suivante. X : mode de couleur. Y : relief. Clic joystick droit : tirage au sort. Grip droit : annuler. Grip gauche : retour au depart. Bouton menu gauche : ce menu.")


func _sur_onglet(i: int) -> void:
	var nom: String = onglets.get_child(i).name
	if nom == "Creations":
		rafraichir_creations()
	elif nom == "Diffusion":
		rafraichir_diffusion()


# ------------------------------------------------------------ pointeur

func intersecter(o: Vector3, d: Vector3) -> Variant:
	var inv: Transform3D = global_transform.affine_inverse()
	var ol: Vector3 = inv * o
	var dl: Vector3 = inv.basis * d
	if dl.z >= -0.00001:
		return null
	var t: float = -ol.z / dl.z
	if t <= 0.0:
		return null
	var h: Vector3 = ol + dl * t
	if absf(h.x) > TAILLE.x * 0.5 or absf(h.y) > TAILLE.y * 0.5:
		return null
	return {"t": t, "mondial": global_transform * h,
		"px": Vector2((h.x / TAILLE.x + 0.5) * float(LARG), (0.5 - h.y / TAILLE.y) * float(HAUT))}


func souris(pos: Vector2, presse: bool) -> void:
	var mv: InputEventMouseMotion = InputEventMouseMotion.new()
	mv.position = pos
	mv.global_position = pos
	mv.relative = pos - _der
	mv.button_mask = MOUSE_BUTTON_MASK_LEFT if presse else 0
	vp.push_input(mv)
	if presse != _presse:
		var b: InputEventMouseButton = InputEventMouseButton.new()
		b.position = pos
		b.global_position = pos
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = presse
		b.button_mask = MOUSE_BUTTON_MASK_LEFT if presse else 0
		vp.push_input(b)
		_presse = presse
	_der = pos
	_dedans = true


func quitter() -> void:
	if _presse:
		var b: InputEventMouseButton = InputEventMouseButton.new()
		b.position = _der
		b.global_position = _der
		b.button_index = MOUSE_BUTTON_LEFT
		b.pressed = false
		vp.push_input(b)
		_presse = false
	if _dedans:
		var mv: InputEventMouseMotion = InputEventMouseMotion.new()
		mv.position = Vector2(-50, -50)
		mv.global_position = Vector2(-50, -50)
		vp.push_input(mv)
		_dedans = false


func molette(vers_haut: bool, pos: Vector2) -> void:
	for etat in [true, false]:
		var b: InputEventMouseButton = InputEventMouseButton.new()
		b.position = pos
		b.global_position = pos
		b.button_index = MOUSE_BUTTON_WHEEL_UP if vers_haut else MOUSE_BUTTON_WHEEL_DOWN
		b.pressed = bool(etat)
		b.factor = 1.0
		vp.push_input(b)
