class_name V32Manager
extends Node
## Mandala VR v32
## - Grand 8 de la mort : rupture du tunnel, chute libre, portail et reentree.
## - Premiere vraie page Accueil : hub vers les grandes familles de l'application.

const ETAT_TUNNEL: int = 0
const ETAT_RUPTURE: int = 1
const ETAT_CHUTE: int = 2
const ETAT_REENTREE: int = 3

const NB_CHUTE: int = 96
const DUREE_RUPTURE: float = 0.72
const DUREE_CHUTE: float = 3.4
const DUREE_REENTREE: float = 2.15

var app = null
var v26 = null
var v31 = null
var _installe: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# Accueil
var _page_accueil: VBoxContainer = null
var _scroll_accueil: ScrollContainer = null
var _btn_accueil: Button = null

# Grand 8 de la mort
var _mort: bool = false
var _attente_demarrage: bool = false
var _attente_t: float = 0.0
var _confirmation_t: float = 0.0
var _btn_mort: Button = null
var _etat_mort: int = ETAT_TUNNEL
var _phase_t: float = 0.0
var _prochaine_rupture: float = 10.0
var _cine_t: float = 0.0
var _snapshot_v31: Dictionary = {}

# Chute libre
var _chute_node: MultiMeshInstance3D = null
var _chute_mm: MultiMesh = null
var _chute_angle: Array = []
var _chute_rayon: Array = []
var _chute_phase: Array = []
var _chute_vitesse: Array = []

# Portail de reentree
var _portail: Node3D = null
var _portail_mats: Array = []

var _etat_label: Label = null
var _etat_ui_t: float = 0.0


func _ready() -> void:
	app = get_parent()
	v26 = app.get_node_or_null("V26Manager")
	v31 = app.get_node_or_null("V31Manager")
	process_priority = 260
	_rng.randomize()


func _process(dt: float) -> void:
	if app == null:
		return

	if not _installe:
		var pret: bool = (
			app.panneau != null
			and app.camera != null
			and app.origine != null
			and v26 != null
			and bool(v26.get("_installe"))
			and v31 != null
			and bool(v31.get("_installe"))
		)
		if pret:
			_installer()
		return

	_sync_navigation_accueil()

	if _confirmation_t > 0.0:
		_confirmation_t -= dt
		if _confirmation_t <= 0.0 and _btn_mort != null and not _mort:
			_btn_mort.text = "GRAND 8 DE LA MORT"

	if _attente_demarrage:
		_attente_t += dt
		if bool(v31.get("_actif")):
			_attente_demarrage = false
			_commencer_mort()
		elif _attente_t > 5.0:
			_attente_demarrage = false
			_restaurer_reglages_v31()
			app.message("Grand 8 de la mort : demarrage annule")

	if _mort:
		if not bool(v31.get("_actif")):
			_fin_mort_sans_arreter_v31()
		else:
			_maj_mort(dt)

	_etat_ui_t -= dt
	if _etat_ui_t <= 0.0:
		_etat_ui_t = 0.4
		_maj_etat()


# ================================================================== ACCUEIL

func _installer() -> void:
	_installe = true
	_creer_accueil()
	_ajouter_bouton_accueil()
	_creer_chute()
	_creer_portail()
	_ajouter_ui_mort()

	# Le menu est cache au demarrage : on prepare simplement l'Accueil comme
	# premiere page qui apparaitra quand l'utilisateur ouvrira les reglages.
	if _scroll_accueil != null:
		app.panneau.onglets.current_tab = _scroll_accueil.get_index()

	app.panneau.rafraichir()
	app.message("v32 : Accueil + Grand 8 de la mort")


func _creer_accueil() -> void:
	_page_accueil = app.panneau._page("Accueil")
	_scroll_accueil = _page_accueil.get_parent() as ScrollContainer
	if _scroll_accueil != null:
		app.panneau.onglets.move_child(_scroll_accueil, 0)

	var titre: Label = Label.new()
	titre.text = "MANDALA VR"
	titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titre.add_theme_font_size_override("font_size", 48)
	titre.add_theme_color_override("font_color", Color(0.78, 0.90, 1.0))
	_page_accueil.add_child(titre)

	var sous: Label = Label.new()
	sous.text = "Choisis une experience"
	sous.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sous.add_theme_font_size_override("font_size", 27)
	sous.add_theme_color_override("font_color", Color(0.60, 0.70, 0.88))
	_page_accueil.add_child(sous)

	var espace: Control = Control.new()
	espace.custom_minimum_size = Vector2(0, 14)
	_page_accueil.add_child(espace)

	var g: GridContainer = GridContainer.new()
	g.columns = 2
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 14)
	_page_accueil.add_child(g)

	_carte(g, "CREER\nMandala, couleurs et styles", Color(0.15, 0.48, 0.88), func() -> void: _aller_page("Rapide"))
	_carte(g, "UNIVERS\nMondes, paysages et ambiances", Color(0.18, 0.55, 0.46), func() -> void: _aller_page("Monde"))
	_carte(g, "SENSATIONS\nGrand 8, vertige et extreme", Color(0.72, 0.22, 0.44), func() -> void: _aller_page("Sensations"))
	_carte(g, "MEDITATION\nRespiration et sessions", Color(0.42, 0.34, 0.78), func() -> void: _aller_page("V8"))
	_carte(g, "DIFFUSION\nCreations en lecture automatique", Color(0.68, 0.42, 0.16), func() -> void: _aller_page("Diffusion"))
	_carte(g, "MODE COURSE\nVehicule assiste - prochaine experience", Color(0.18, 0.34, 0.62), _course_bientot)
	_carte(g, "CREATIONS\nSauvegardes et galerie", Color(0.36, 0.48, 0.70), func() -> void: _aller_page("Creations"))
	_carte(g, "REGLAGES VR\nConfort et options", Color(0.30, 0.32, 0.46), func() -> void: _aller_page("V8"))

	app.panneau._note(_page_accueil,
		"Cette page devient le hub du projet. Les futures experiences (Course, Vol, Chute infinie, Surf spatial...) pourront avoir leur propre menu sans surcharger les reglages existants.")


func _carte(parent: Control, texte: String, couleur: Color, cb: Callable) -> void:
	var b: Button = Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(0, 124)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 27)
	b.pressed.connect(cb)

	for etat in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		var sb: StyleBoxFlat = StyleBoxFlat.new()
		sb.set_corner_radius_all(20)
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		sb.content_margin_top = 14
		sb.content_margin_bottom = 14

		if etat == "hover":
			sb.bg_color = couleur.lightened(0.10)
			sb.border_color = Color(1, 1, 1, 0.72)
			sb.set_border_width_all(2)
		elif etat == "pressed" or etat == "hover_pressed":
			sb.bg_color = couleur.lightened(0.18)
			sb.border_color = Color.WHITE
			sb.set_border_width_all(3)
		else:
			sb.bg_color = Color(couleur.r * 0.55, couleur.g * 0.55, couleur.b * 0.55, 0.96)
			sb.border_color = Color(couleur.r, couleur.g, couleur.b, 0.72)
			sb.set_border_width_all(2)

		sb.shadow_color = Color(0, 0, 0, 0.34)
		sb.shadow_size = 7
		b.add_theme_stylebox_override(etat, sb)

	b.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_hover_pressed_color", Color.WHITE)
	parent.add_child(b)


func _ajouter_bouton_accueil() -> void:
	var rg: Variant = v26.get("_rang_groupes")
	if not (rg is HBoxContainer):
		return

	_btn_accueil = Button.new()
	_btn_accueil.text = "Accueil"
	_btn_accueil.toggle_mode = true
	_btn_accueil.custom_minimum_size = Vector2(0, 62)
	_btn_accueil.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v26.call("_pastille", _btn_accueil, 30, 24)
	_btn_accueil.pressed.connect(_aller_accueil)

	var rang: HBoxContainer = rg
	rang.add_child(_btn_accueil)
	rang.move_child(_btn_accueil, 0)


func _aller_accueil() -> void:
	if _scroll_accueil == null:
		return
	app.panneau.onglets.current_tab = _scroll_accueil.get_index()
	_sync_navigation_accueil()


func _aller_page(nom: String) -> void:
	var o: TabContainer = app.panneau.onglets
	for i in o.get_child_count():
		if str(o.get_child(i).name) == nom:
			o.current_tab = i
			if v26.has_method("_synchroniser"):
				v26.call("_synchroniser")
			return
	app.message("Menu indisponible : " + nom)


func _course_bientot() -> void:
	app.message("Mode Course : vehicule rapide assiste - prochaine grande experience")


func _sur_accueil() -> bool:
	if _scroll_accueil == null:
		return false
	return app.panneau.onglets.current_tab == _scroll_accueil.get_index()


func _sync_navigation_accueil() -> void:
	if _btn_accueil == null:
		return

	var home: bool = _sur_accueil()
	_btn_accueil.set_pressed_no_signal(home)

	if home:
		var btns: Variant = v26.get("_btn_groupes")
		if btns is Array:
			for b in btns:
				if b is Button:
					(b as Button).set_pressed_no_signal(false)
		var rang_pages: Variant = v26.get("_rang_pages")
		if rang_pages is HBoxContainer:
			(rang_pages as HBoxContainer).visible = false


# ================================================================== GRAND 8 DE LA MORT

func _ajouter_ui_mort() -> void:
	var p: VBoxContainer = null
	for c in app.panneau.onglets.get_children():
		if str(c.name) == "Sensations" and c.get_child_count() > 0:
			p = c.get_child(0) as VBoxContainer
	if p == null:
		return

	app.panneau._titre(p, "Grand 8 de la mort")
	app.panneau._note(p,
		"Le tunnel se coupe sans prevenir. Tu tombes dans le vide, un portail reapparait plus bas puis t'aspire dans un nouveau tunnel a pleine vitesse. Les ruptures et les cinematiques changent a chaque cycle.")

	_btn_mort = Button.new()
	_btn_mort.text = "GRAND 8 DE LA MORT"
	_btn_mort.custom_minimum_size = Vector2(0, 96)
	_btn_mort.add_theme_font_size_override("font_size", 30)
	_btn_mort.pressed.connect(_demander_mort)
	p.add_child(_btn_mort)

	var r: HBoxContainer = app.panneau._rangee(p)
	app.panneau._bouton(r, "Arreter le mode de la mort", arreter_mort)
	app.panneau._bouton(r, "Retour Accueil", _aller_accueil)

	_etat_label = Label.new()
	_etat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etat_label.add_theme_font_size_override("font_size", 23)
	p.add_child(_etat_label)

	app.panneau._note(p,
		"Conseil : commence assis. Ouvrir le menu stoppe immediatement le Grand 8 et restaure l'environnement precedent.")


func _demander_mort() -> void:
	if _mort or _attente_demarrage:
		return

	if _confirmation_t > 0.0:
		_confirmation_t = 0.0
		if _btn_mort != null:
			_btn_mort.text = "GRAND 8 DE LA MORT"
		_preparer_demarrage_mort()
	else:
		_confirmation_t = 8.0
		if _btn_mort != null:
			_btn_mort.text = "CONFIRMER : JE SUIS PRET ET ASSIS"


func _preparer_demarrage_mort() -> void:
	if bool(v31.get("_actif")):
		v31.call("arreter")

	_snapshot_v31 = {
		"profil": int(v31.get("_profil")),
		"vitesse": float(v31.get("_vitesse")),
		"courbes": float(v31.get("_courbes")),
		"auto": bool(v31.get("_auto_cine")),
		"duree": float(v31.get("_duree_cine")),
		"vignette": float(v31.get("_vignette_force")),
	}

	v31.set("_profil", 2)
	v31.set("_vitesse", 28.0)
	v31.set("_courbes", 1.38)
	v31.set("_auto_cine", false)
	v31.set("_duree_cine", 7.0)
	v31.set("_vignette_force", 0.22)

	_attente_demarrage = true
	_attente_t = 0.0
	v31.call("demarrer")
	app.message("Grand 8 de la mort : depart...")


func _commencer_mort() -> void:
	_mort = true
	_etat_mort = ETAT_TUNNEL
	_phase_t = 0.0
	_cine_t = 0.0
	_prochaine_rupture = _rng.randf_range(8.0, 13.0)
	_cacher_chute()
	_cacher_portail()
	_tunnel_visible(true)
	_choisir_cine_mort()
	app.message("GRAND 8 DE LA MORT")


func arreter_mort() -> void:
	_attente_demarrage = false
	if bool(v31.get("_actif")):
		v31.call("arreter")
	_fin_mort_sans_arreter_v31()


func _fin_mort_sans_arreter_v31() -> void:
	_mort = false
	_attente_demarrage = false
	_cacher_chute()
	_cacher_portail()
	_tunnel_scale(Vector3.ONE)
	_restaurer_reglages_v31()
	if _btn_mort != null:
		_btn_mort.text = "GRAND 8 DE LA MORT"


func _restaurer_reglages_v31() -> void:
	if _snapshot_v31.is_empty() or v31 == null:
		return
	v31.set("_profil", int(_snapshot_v31.get("profil", 1)))
	v31.set("_vitesse", float(_snapshot_v31.get("vitesse", 18.0)))
	v31.set("_courbes", float(_snapshot_v31.get("courbes", 1.0)))
	v31.set("_auto_cine", bool(_snapshot_v31.get("auto", true)))
	v31.set("_duree_cine", float(_snapshot_v31.get("duree", 10.0)))
	v31.set("_vignette_force", float(_snapshot_v31.get("vignette", 0.35)))
	_snapshot_v31 = {}


func _maj_mort(dt: float) -> void:
	_phase_t += dt

	match _etat_mort:
		ETAT_TUNNEL:
			_maj_tunnel_mort(dt)
		ETAT_RUPTURE:
			_maj_rupture()
		ETAT_CHUTE:
			_maj_chute(dt)
		ETAT_REENTREE:
			_maj_reentree()


func _maj_tunnel_mort(dt: float) -> void:
	_cine_t += dt
	if _cine_t > _rng.randf_range(3.8, 5.8):
		_cine_t = 0.0
		_choisir_cine_mort()

	if _phase_t >= _prochaine_rupture:
		_etat_mort = ETAT_RUPTURE
		_phase_t = 0.0
		_vibrer(0.55, 0.20)
		app.message("RUPTURE DU TUNNEL")


func _maj_rupture() -> void:
	var k: float = clampf(_phase_t / DUREE_RUPTURE, 0.0, 1.0)

	# Le tube se contracte puis disparait brutalement.
	var z: float = maxf(0.12, 1.0 - k * 0.88)
	_tunnel_scale(Vector3(1.0 + k * 0.08, 1.0 + k * 0.08, z))

	if k > 0.58:
		_tunnel_visible(false)

	if _phase_t >= DUREE_RUPTURE:
		_etat_mort = ETAT_CHUTE
		_phase_t = 0.0
		_tunnel_scale(Vector3.ONE)
		app.monde.visible = true
		_montrer_chute()
		_vibrer(0.32, 0.16)


func _maj_chute(dt: float) -> void:
	_animer_chute(dt)
	var k: float = clampf(_phase_t / DUREE_CHUTE, 0.0, 1.0)

	if k > 0.52:
		_montrer_portail()
		var pk: float = clampf((k - 0.52) / 0.48, 0.0, 1.0)
		_animer_portail(pk)

	if _phase_t >= DUREE_CHUTE:
		_etat_mort = ETAT_REENTREE
		_phase_t = 0.0
		_cacher_chute()
		app.monde.visible = false
		_tunnel_visible(true)
		_tunnel_scale(Vector3.ONE)
		v31.set("_vitesse", 34.0)
		v31.set("_courbes", 1.58)
		v31.call("_set_cine", 4)
		_vibrer(0.78, 0.28)
		app.message("REENTREE !")


func _maj_reentree() -> void:
	var k: float = clampf(_phase_t / DUREE_REENTREE, 0.0, 1.0)
	_animer_portail(1.0 - k * 0.25)

	var s: float = lerpf(1.22, 1.0, k)
	_tunnel_scale(Vector3.ONE * s)

	if _phase_t >= DUREE_REENTREE:
		_cacher_portail()
		_etat_mort = ETAT_TUNNEL
		_phase_t = 0.0
		_cine_t = 0.0
		_prochaine_rupture = _rng.randf_range(7.0, 12.5)
		v31.set("_vitesse", _rng.randf_range(27.0, 33.0))
		v31.set("_courbes", _rng.randf_range(1.28, 1.58))
		_choisir_cine_mort()


func _choisir_cine_mort() -> void:
	var choix: Array = [1, 2, 3, 4, 5]
	var i: int = int(choix[_rng.randi_range(0, choix.size() - 1)])
	v31.call("_set_cine", i)


func _tunnel_root() -> Node3D:
	var r: Variant = v31.get("_racine")
	if r is Node3D:
		return r
	return null


func _tunnel_visible(on: bool) -> void:
	var r: Node3D = _tunnel_root()
	if r != null:
		r.visible = on


func _tunnel_scale(s: Vector3) -> void:
	var r: Node3D = _tunnel_root()
	if r != null:
		r.scale = s


# -------------------------------------------------------------- chute libre

func _creer_chute() -> void:
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.025, 1.10, 0.025)

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(0.52, 0.78, 1.0, 0.60)
	mat.emission_enabled = true
	mat.emission = Color(0.24, 0.60, 1.0)
	mat.emission_energy_multiplier = 1.9
	bm.material = mat

	_chute_mm = MultiMesh.new()
	_chute_mm.transform_format = MultiMesh.TRANSFORM_3D
	_chute_mm.instance_count = NB_CHUTE
	_chute_mm.mesh = bm

	_chute_node = MultiMeshInstance3D.new()
	_chute_node.name = "V32ChuteLibre"
	_chute_node.multimesh = _chute_mm
	_chute_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_chute_node.extra_cull_margin = 100.0
	_chute_node.visible = false
	app.origine.add_child(_chute_node)

	for i in NB_CHUTE:
		_chute_angle.append(_rng.randf() * TAU)
		_chute_rayon.append(_rng.randf_range(1.2, 6.5))
		_chute_phase.append(_rng.randf_range(-8.0, 8.0))
		_chute_vitesse.append(_rng.randf_range(7.0, 15.0))


func _montrer_chute() -> void:
	if _chute_node != null:
		_chute_node.position = app.camera.position
		_chute_node.visible = true


func _cacher_chute() -> void:
	if _chute_node != null:
		_chute_node.visible = false


func _animer_chute(_dt: float) -> void:
	if _chute_mm == null or _chute_node == null:
		return

	_chute_node.position = app.camera.position
	for i in NB_CHUTE:
		var a: float = float(_chute_angle[i])
		var r: float = float(_chute_rayon[i])
		var vit: float = float(_chute_vitesse[i])
		var y: float = fposmod(float(_chute_phase[i]) + _phase_t * vit + 8.0, 16.0) - 8.0
		var torsion: float = _phase_t * 0.12
		var pos: Vector3 = Vector3(
			cos(a + torsion) * r,
			y,
			sin(a + torsion) * r - 1.5)
		var stretch: float = 0.75 + vit / 9.0
		var b: Basis = Basis().scaled(Vector3(1.0, stretch, 1.0))
		_chute_mm.set_instance_transform(i, Transform3D(b, pos))


# -------------------------------------------------------------- portail

func _creer_portail() -> void:
	_portail = Node3D.new()
	_portail.name = "V32Portail"
	_portail.visible = false
	app.origine.add_child(_portail)

	for i in 3:
		var mi: MeshInstance3D = MeshInstance3D.new()
		var tor: TorusMesh = TorusMesh.new()
		tor.inner_radius = 0.90 + float(i) * 0.16
		tor.outer_radius = 0.96 + float(i) * 0.16
		tor.rings = 40
		tor.ring_segments = 8
		mi.mesh = tor
		mi.rotation.x = PI * 0.5

		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = Color(
			0.28 + float(i) * 0.18,
			0.52,
			1.0 - float(i) * 0.12,
			0.82 - float(i) * 0.12)
		mat.emission_enabled = true
		mat.emission = mat.albedo_color
		mat.emission_energy_multiplier = 1.8 + float(i) * 0.35
		mi.material_override = mat
		_portail.add_child(mi)
		_portail_mats.append(mat)


func _montrer_portail() -> void:
	if _portail != null:
		_portail.visible = true


func _cacher_portail() -> void:
	if _portail != null:
		_portail.visible = false


func _animer_portail(k: float) -> void:
	if _portail == null:
		return

	var e: float = k * k * (3.0 - 2.0 * k)
	_portail.position = app.camera.position + Vector3(
		sin(_phase_t * 0.6) * 0.25,
		lerpf(-3.2, -0.10, e),
		lerpf(-10.0, -1.8, e))
	var s: float = lerpf(0.45, 1.85, e)
	_portail.scale = Vector3.ONE * s
	_portail.rotation.z = _phase_t * 0.35

	for i in _portail_mats.size():
		var mat: StandardMaterial3D = _portail_mats[i]
		mat.emission_energy_multiplier = 1.5 + e * (2.4 + float(i) * 0.35)


func _vibrer(force: float, duree: float) -> void:
	if app.main_d != null:
		app.main_d.trigger_haptic_pulse("haptic", 0.0, force, duree, 0.0)
	if app.main_g != null:
		app.main_g.trigger_haptic_pulse("haptic", 0.0, force, duree, 0.0)


# -------------------------------------------------------------- statut

func _maj_etat() -> void:
	if _etat_label == null:
		return

	if _attente_demarrage:
		_etat_label.text = "Grand 8 de la mort : depart..."
		return

	if not _mort:
		_etat_label.text = "Grand 8 de la mort arrete"
		return

	var nom: String = "Tunnel"
	match _etat_mort:
		ETAT_RUPTURE:
			nom = "Rupture"
		ETAT_CHUTE:
			nom = "CHUTE LIBRE"
		ETAT_REENTREE:
			nom = "Reentree"

	_etat_label.text = "GRAND 8 DE LA MORT | %s | cycle %.1f s" % [nom, _phase_t]
