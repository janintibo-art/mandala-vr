class_name V21Manager
extends Node
## Mandala VR v21 : menu reorganise en onglets thematiques,
## acces direct au mouvement et barres d'accent assorties au theme.

const ORDRE: Array = ["Rapide", "Modeles", "Genres", "Trait", "Couleurs", "Lumiere", "Mouvement", "Relief", "Monde", "Style", "Creations", "Diffusion", "V8"]
const TITRES: Dictionary = {
	"Rapide": "Accueil", "Modeles": "Modeles", "Genres": "Formes", "Trait": "Trait",
	"Couleurs": "Couleurs", "Lumiere": "Lumiere", "Mouvement": "Mouvement", "Relief": "Relief",
	"Monde": "Monde", "Style": "Style", "Creations": "Galerie", "Diffusion": "Diapo", "V8": "Reglages",
}
const VERS_MONDE: Array = ["Mondes cinematographiques"]
const VERS_STYLE: Array = ["Style du mandala", "Aura et orbites du mandala", "Profondeur 3D du mandala", "Visuel reactif", "Transitions visuelles premium"]
const VERS_REGLAGES: Array = ["Qualite graphique Quest 3", "Session et securite", "Confort du menu", "Gestes mains securises", "Mains Quest", "Interface VR premium"]

var app = null
var v15 = null
var v19 = null
var _installe: bool = false
var _attente: float = 0.0
var _etat_label: Label = null
var _etat_t: float = 0.0
var _accent_prec: Color = Color(0, 0, 0, 0)
var _balayages: int = 0


func _ready() -> void:
	app = get_parent()
	v15 = app.get_node_or_null("V15Manager")
	v19 = app.get_node_or_null("V19Manager")
	process_priority = 200


func _process(dt: float) -> void:
	if app == null:
		return
	if not _installe:
		_attente += dt
		if app.panneau == null or app.sc == null:
			return
		var pret: bool = v19 != null and v19.get("_installe") == true
		for nom in ["V10Manager", "V11Manager", "V12Manager", "V13Manager", "V14Manager", "V15Manager", "V16Manager", "V17Manager", "V18Manager"]:
			var mg: Node = app.get_node_or_null(nom)
			if mg != null and mg.get("_installe") != true:
				pret = false
		if pret or _attente > 30.0:
			_installer()
		return
	_etat_t -= dt
	if _etat_t <= 0.0:
		_etat_t = 0.4
		_maj_etat()
		_maj_barres()
		if _balayages < 50:
			_balayages += 1
			_balayer()


func _contenu(nom: String) -> VBoxContainer:
	for c in app.panneau.onglets.get_children():
		if str(c.name) == nom and c.get_child_count() > 0:
			return c.get_child(0) as VBoxContainer
	return null


func _installer() -> void:
	_installe = true
	var accueil: VBoxContainer = _contenu("Rapide")
	var monde: VBoxContainer = _contenu("Monde")
	var reglages: VBoxContainer = _contenu("V8")
	if accueil == null or monde == null or reglages == null:
		app.message("Menu v21 : pages introuvables")
		return
	var style: VBoxContainer = app.panneau._page("Style")
	_balayer()
	_nettoyer_debut(style)
	_renommer_intro(reglages)
	_ajouter_mouvement(accueil)

	var o: TabContainer = app.panneau.onglets
	for i in ORDRE.size():
		for c in o.get_children():
			if str(c.name) == str(ORDRE[i]):
				o.move_child(c, i)
	for i in o.get_child_count():
		var nom: String = str(o.get_child(i).name)
		if TITRES.has(nom):
			o.set_tab_title(i, str(TITRES[nom]))
	o.current_tab = 0

	if v15 != null:
		v15.call("_styliser_labels")
	_maj_barres()
	app.panneau.rafraichir()
	app.message("Menu v21 : onglets reorganises")


## Deplace les sections (un titre et ce qui le suit) vers une autre page.
func _deplacer(src: VBoxContainer, dst: VBoxContainer, titres: Array) -> int:
	var enfants: Array = src.get_children()
	var courant: String = ""
	var a_deplacer: Array = []
	for i in enfants.size():
		var c: Node = enfants[i]
		var sec: String = courant
		if c.has_meta("titre"):
			courant = str(c.get_meta("titre"))
			sec = courant
		elif i + 1 < enfants.size() and (enfants[i + 1] as Node).has_meta("titre") and c.get_class() == "Control" and c.get_child_count() == 0:
			sec = str((enfants[i + 1] as Node).get_meta("titre"))
		if titres.has(sec):
			a_deplacer.append(c)
	for c in a_deplacer:
		var nd: Node = c
		src.remove_child(nd)
		dst.add_child(nd)
	return a_deplacer.size()


## Range les sections qui seraient arrivees en retard sur la page d'accueil.
func _balayer() -> void:
	var accueil: VBoxContainer = _contenu("Rapide")
	var monde: VBoxContainer = _contenu("Monde")
	var style: VBoxContainer = _contenu("Style")
	var reglages: VBoxContainer = _contenu("V8")
	if accueil == null or monde == null or style == null or reglages == null:
		return
	_deplacer(accueil, monde, VERS_MONDE)
	_deplacer(accueil, style, VERS_STYLE)
	_deplacer(accueil, reglages, VERS_REGLAGES)


func _nettoyer_debut(p: VBoxContainer) -> void:
	if p.get_child_count() == 0:
		return
	var c: Node = p.get_child(0)
	if c.get_class() == "Control" and c.get_child_count() == 0 and not c.has_meta("titre"):
		p.remove_child(c)
		c.queue_free()


func _renommer_intro(p: VBoxContainer) -> void:
	for c in p.get_children():
		if c.has_meta("titre") and str(c.get_meta("titre")) == "Mandala VR v8":
			c.set_meta("titre", "Reglages et confort")
			for e in c.get_children():
				if e is Label:
					(e as Label).text = "Reglages et confort"
			return


func _ajouter_mouvement(p: VBoxContainer) -> void:
	var cible: int = -1
	for i in p.get_child_count():
		var c: Node = p.get_child(i)
		if c.has_meta("titre") and str(c.get_meta("titre")) == "Profils confort":
			cible = i - 1
			break
	var n0: int = p.get_child_count()
	app.panneau._titre(p, "Mouvement")
	_etat_label = Label.new()
	_etat_label.add_theme_font_size_override("font_size", 25)
	_etat_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	p.add_child(_etat_label)
	var g: GridContainer = GridContainer.new()
	g.columns = 4
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(g)
	_gros(g, "Mouvement suivant", _mv_suivant)
	_gros(g, "Animer / Pause", _anim_bascule)
	_gros(g, "Moins vite", _vitesse.bind(0.8))
	_gros(g, "Plus vite", _vitesse.bind(1.25))
	if cible >= 0:
		var k: int = 0
		while p.get_child_count() > n0 + k:
			p.move_child(p.get_child(n0 + k), cible + k)
			k += 1
			if k > 8:
				break


func _gros(parent: Control, texte: String, cb: Callable) -> void:
	var b: Button = Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(0, 74)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)


func _mv_suivant() -> void:
	var n: int = Tables.NOMS_MOUVEMENTS.size()
	var nv: int = (app.sc.mouvement + 1) % n
	app.set_mouvement(nv)
	if nv == 0:
		app.sc.anime = true
	app.message("Mouvement : " + str(Tables.NOMS_MOUVEMENTS[nv]))


func _anim_bascule() -> void:
	app.sc.anime = not app.sc.anime
	app.panneau.rafraichir()
	app.message("Animation : " + ("en marche" if app.sc.anime else "en pause"))


func _vitesse(f: float) -> void:
	app.set_vitesse(clampf(app.sc.vitesse * f, 0.1, 3.0))
	app.panneau.rafraichir()


func _maj_etat() -> void:
	if _etat_label == null:
		return
	var mv: int = clampi(app.sc.mouvement, 0, Tables.NOMS_MOUVEMENTS.size() - 1)
	_etat_label.text = "%s  |  vitesse %.2f  |  %s" % [str(Tables.NOMS_MOUVEMENTS[mv]), app.sc.vitesse, "en marche" if app.sc.anime else "en pause"]


func _maj_barres() -> void:
	if v15 == null:
		return
	var a: Color = v15.call("_accent")
	if a == _accent_prec:
		return
	_accent_prec = a
	for n in get_tree().get_nodes_in_group("barres_titre"):
		(n as ColorRect).color = Color(minf(1.0, a.r + 0.1), minf(1.0, a.g + 0.1), minf(1.0, a.b + 0.1))
