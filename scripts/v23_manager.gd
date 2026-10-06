class_name V23Manager
extends Node
## Mandala VR v23 : sensations fortes.
## Plateforme au-dessus du vide, plongee dans le tunnel, manege autour du mandala,
## changement d'echelle. Intensite reglable, bord assombri, arret en ouvrant le menu.

const PREFS_V23: String = "user://v23_sensations.json"
const NOMS: Dictionary = {
	"vide": "Plateforme au-dessus du vide",
	"tunnel": "Plongee dans le tunnel",
	"manege": "Manege autour du mandala",
	"echelle": "Changement d'echelle",
	"hardcore": "Mode hardcore",
}
const DUREE_HARDCORE: float = 120.0
const MOUVEMENTS_HARDCORE: Array = [7, 3, 9, 8]
const NB_TRAINEES: int = 360

var app = null
var v19 = null
var _installe: bool = false
var _prefs: Dictionary = {}

var _inten: float = 0.5
var _duree: float = 90.0
var _bord: bool = true

var _mode: String = ""
var _attente_mode: String = ""
var _attente_t: float = 0.0
var _t: float = 0.0
var _k: float = 0.0
var _sortie: bool = false
var _snap: Dictionary = {}
var _etat_label: Label = null
var _etat_t: float = 0.0

var _vignette: MeshInstance3D = null
var _m_vignette: ShaderMaterial = null
var _warp: MeshInstance3D = null
var _m_warp: ShaderMaterial = null
var _plateforme: Node3D = null
var _m_plat: StandardMaterial3D = null
var _m_anneau: StandardMaterial3D = null
var _dir_voyage: Vector3 = Vector3(0.0, 0.0, -1.0)
var _a0: float = 0.0
var _r0: float = 6.0
var _dt: float = 0.0
var _ph: float = 0.0
var _hc_arme_t: float = 0.0
var _hc_bouton: Button = null
var _hc_haptique: float = 0.0
var _hc_mv: int = -1


func _ready() -> void:
	app = get_parent()
	v19 = app.get_node_or_null("V19Manager")
	process_priority = 210
	_lire_prefs()


func _exit_tree() -> void:
	if _mode != "" and app != null and app.is_inside_tree():
		_restaurer()


func _process(dt: float) -> void:
	if app == null:
		return
	if not _installe:
		if app.panneau != null and app.sc != null and app.camera != null and v19 != null and v19.get("_installe") == true:
			_installer()
		return

	if _hc_arme_t > 0.0:
		_hc_arme_t -= dt
		if _hc_arme_t <= 0.0 and _hc_bouton != null:
			_hc_bouton.text = "Mode hardcore (public averti)"

	if _attente_mode != "":
		_attente_t -= dt
		if _attente_t <= 0.0:
			var m: String = _attente_mode
			_attente_mode = ""
			_commencer(m)

	if _mode != "":
		_maj(dt)

	_etat_t -= dt
	if _etat_t <= 0.0:
		_etat_t = 0.4
		_maj_etat()


# -------------------------------------------------------------- preferences

func _lire_prefs() -> void:
	if FileAccess.file_exists(PREFS_V23):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREFS_V23))
		if j is Dictionary:
			_prefs = j
	_inten = clampf(float(_prefs.get("intensite", 0.5)), 0.2, 1.0)
	_duree = clampf(float(_prefs.get("duree", 90.0)), 30.0, 300.0)
	_bord = bool(_prefs.get("bord", true))


func _sauver_prefs() -> void:
	_prefs = {"intensite": _inten, "duree": _duree, "bord": _bord}
	var f: FileAccess = FileAccess.open(PREFS_V23, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_prefs))
		f.close()


# -------------------------------------------------------------- installation

func _installer() -> void:
	_installe = true
	_creer_vignette()
	_creer_warp()
	_creer_plateforme()
	_creer_page()
	app.panneau.rafraichir()


func _creer_vignette() -> void:
	_vignette = MeshInstance3D.new()
	var sp: SphereMesh = SphereMesh.new()
	sp.radius = 0.36
	sp.height = 0.72
	sp.radial_segments = 32
	sp.rings = 16
	_vignette.mesh = sp
	_m_vignette = ShaderMaterial.new()
	_m_vignette.shader = load("res://shaders/vignette_v23.gdshader")
	_m_vignette.render_priority = 100
	_vignette.material_override = _m_vignette
	_vignette.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vignette.visible = false
	app.camera.add_child(_vignette)


func _creer_warp() -> void:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = 2323
	var v: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var c: PackedColorArray = PackedColorArray()
	var idx: PackedInt32Array = PackedInt32Array()
	for i in NB_TRAINEES:
		var graine: Color = Color(r.randf(), r.randf(), r.randf(), 1.0)
		var k: int = v.size()
		for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			v.append(Vector3.ZERO)
			uv.append(q)
			c.append(graine)
		idx.append_array(PackedInt32Array([k, k + 1, k + 2, k + 2, k + 1, k + 3]))
	var a: Array = []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_TEX_UV] = uv
	a[Mesh.ARRAY_COLOR] = c
	a[Mesh.ARRAY_INDEX] = idx
	var m: ArrayMesh = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	m.custom_aabb = AABB(Vector3(-500, -500, -500), Vector3(1000, 1000, 1000))
	_warp = MeshInstance3D.new()
	_warp.mesh = m
	_m_warp = ShaderMaterial.new()
	_m_warp.shader = load("res://shaders/warp_v23.gdshader")
	_warp.material_override = _m_warp
	_warp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_warp.extra_cull_margin = 1000.0
	_warp.top_level = true
	_warp.visible = false
	app.add_child(_warp)


func _creer_plateforme() -> void:
	_plateforme = Node3D.new()
	_plateforme.top_level = true
	_plateforme.visible = false
	app.add_child(_plateforme)

	var disque: MeshInstance3D = MeshInstance3D.new()
	var cy: CylinderMesh = CylinderMesh.new()
	cy.top_radius = 1.3
	cy.bottom_radius = 1.3
	cy.height = 0.03
	disque.mesh = cy
	_m_plat = StandardMaterial3D.new()
	_m_plat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_m_plat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_m_plat.albedo_color = Color(0.45, 0.75, 1.0, 0.0)
	_m_plat.cull_mode = BaseMaterial3D.CULL_DISABLED
	disque.material_override = _m_plat
	disque.position = Vector3(0.0, -0.02, 0.0)
	_plateforme.add_child(disque)

	var anneau: MeshInstance3D = MeshInstance3D.new()
	var to: TorusMesh = TorusMesh.new()
	to.inner_radius = 1.27
	to.outer_radius = 1.33
	to.rings = 48
	to.ring_segments = 8
	anneau.mesh = to
	_m_anneau = StandardMaterial3D.new()
	_m_anneau.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_m_anneau.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_m_anneau.albedo_color = Color(0.5, 0.9, 1.0, 0.0)
	anneau.material_override = _m_anneau
	anneau.position = Vector3(0.0, -0.01, 0.0)
	_plateforme.add_child(anneau)


func _creer_page() -> void:
	var p: VBoxContainer = app.panneau._page("Sensations")
	app.panneau._titre(p, "Sensations fortes")
	app.panneau._note(p, "Tiens-toi bien ou assieds-toi. Pour tout arreter : ouvre le menu (bouton gauche) ou serre les deux poignees.")
	app.panneau._curseur(p, "v23_inten", "Intensite", 0.2, 1.0, 0.05,
		func() -> float: return _inten,
		func(v: float) -> void: _set_inten(v), "%.2f")
	app.panneau._curseur(p, "v23_duree", "Duree maximale (s)", 30.0, 300.0, 10.0,
		func() -> float: return _duree,
		func(v: float) -> void: _set_duree(v), "%d")
	app.panneau._bascule(p, "v23_bord", "Bord assombri (confort)",
		func() -> bool: return _bord,
		func(on: bool) -> void: _set_bord(on))

	app.panneau._titre(p, "Choisis ton vertige")
	var g: GridContainer = GridContainer.new()
	g.columns = 2
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(g)
	for cle in ["vide", "tunnel", "manege", "echelle"]:
		var b: Button = Button.new()
		b.text = str(NOMS[cle])
		b.custom_minimum_size = Vector2(0, 92)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_demander.bind(str(cle)))
		g.add_child(b)
	var stop: Button = Button.new()
	stop.text = "Tout arreter"
	stop.custom_minimum_size = Vector2(0, 74)
	stop.pressed.connect(func() -> void: arreter())
	p.add_child(stop)

	app.panneau._titre(p, "Mode hardcore")
	app.panneau._note(p, "Pour les plus endurants : 2 minutes de montee en puissance, tunnel + changements d'echelle de plus en plus violents, mouvements qui s'enchainent, vibrations. Risque de nausee : assieds-toi, ne l'utilise pas si tu es fatigue(e) ou sensible. Aucun flash stroboscopique.")
	_hc_bouton = Button.new()
	_hc_bouton.text = "Mode hardcore (public averti)"
	_hc_bouton.custom_minimum_size = Vector2(0, 92)
	_hc_bouton.pressed.connect(_demander_hardcore)
	p.add_child(_hc_bouton)

	_etat_label = Label.new()
	_etat_label.add_theme_font_size_override("font_size", 25)
	_etat_label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))
	p.add_child(_etat_label)

	app.panneau._titre(p, "Ce que ca fait")
	app.panneau._note(p, "Vide : le mandala se couche et s'enfonce tres loin sous tes pieds, tu restes sur une plaque de verre.")
	app.panneau._note(p, "Tunnel : le dome s'anime en zoom infini et des traits de lumiere filent vers toi.")
	app.panneau._note(p, "Manege : tu glisses en spirale autour du mandala, en montant et en descendant.")
	app.panneau._note(p, "Echelle : tu rapetisses dans un mandala geant, puis tu deviens geant au-dessus de lui.")


# -------------------------------------------------------------- commandes

func _set_inten(v: float) -> void:
	_inten = v
	_sauver_prefs()


func _set_duree(v: float) -> void:
	_duree = v
	_sauver_prefs()


func _set_bord(on: bool) -> void:
	_bord = on
	_sauver_prefs()


func _demander_hardcore() -> void:
	if _hc_arme_t > 0.0:
		_hc_arme_t = 0.0
		_hc_bouton.text = "Mode hardcore (public averti)"
		_demander("hardcore")
	else:
		_hc_arme_t = 8.0
		_hc_bouton.text = "CONFIRMER : je suis pret(e) et assis(e)"


func _demander(mode: String) -> void:
	call_deferred("_demarrer", mode)


func _demarrer(mode: String) -> void:
	if _mode != "":
		_restaurer()
	if app.panneau.visible:
		app.basculer_panneau()
	_attente_mode = mode
	_attente_t = 2.5
	app.message("%s dans quelques secondes... Pour arreter : menu." % str(NOMS[mode]))


func arreter() -> void:
	_attente_mode = ""
	if _mode != "" and not _sortie:
		_sortie = true
		app.message("Retour en douceur")


func _commencer(mode: String) -> void:
	_mode = mode
	_t = 0.0
	_k = 0.0
	_sortie = false
	var o: XROrigin3D = app.origine
	_snap = {
		"vit": app.sc.vitesse,
		"mv": app.sc.mouvement,
		"anime": app.sc.anime,
		"dome": app.sc.dome_cible > 0.5,
		"sol": app.sol.visible,
		"sc_xf": app.sc.global_transform,
		"o_pos": o.global_position,
		"o_rot": o.rotation.y,
		"ws": o.world_scale,
		"amb": app.son.ambiance,
	}
	_ph = 0.0
	_hc_mv = -1
	_hc_haptique = 0.0
	if _bord and mode != "vide":
		_vignette.visible = true
	match mode:
		"vide":
			if app.sc.dome_cible > 0.5:
				app.set_dome(false)
			app.sol.visible = false
			var p0: Vector3 = o.global_position
			_plateforme.global_position = Vector3(p0.x, p0.y, p0.z)
			_plateforme.visible = true
		"tunnel", "hardcore":
			app.set_dome(true)
			app.set_mouvement(7)
			_dir_voyage = (-app.camera.global_transform.basis.z).normalized()
			_warp.visible = true
			if mode == "hardcore":
				_vignette.visible = _bord
				if app.son.ambiance != 2:
					app.son.choisir_ambiance(2)
		"manege":
			if app.sc.dome_cible > 0.5:
				app.set_dome(false)
			var c: Vector3 = app.sc.global_position
			var p: Vector3 = o.global_position
			_a0 = atan2(p.x - c.x, p.z - c.z)
			_r0 = clampf(Vector2(p.x - c.x, p.z - c.z).length(), 4.0, 9.0)
	app.message(str(NOMS[mode]))


func _restaurer() -> void:
	if _snap.is_empty():
		_mode = ""
		return
	var o: XROrigin3D = app.origine
	var vivant: bool = app.sc.is_inside_tree() and o.is_inside_tree()
	if vivant:
		app.sc.global_transform = _snap["sc_xf"]
	o.world_scale = float(_snap["ws"])
	if _mode == "manege" and vivant:
		o.global_position = _snap["o_pos"]
		o.rotation.y = float(_snap["o_rot"])
	if (_mode == "tunnel" or _mode == "hardcore") and vivant:
		app.set_dome(bool(_snap["dome"]))
		app.set_mouvement(int(_snap["mv"]))
		app.sc.vitesse = float(_snap["vit"])
		app.sc.anime = bool(_snap["anime"])
	if _mode == "hardcore" and int(_snap["amb"]) != app.son.ambiance:
		app.son.choisir_ambiance(int(_snap["amb"]))
	if vivant:
		app.sol.visible = bool(_snap["sol"])
	_plateforme.visible = false
	_warp.visible = false
	_vignette.visible = false
	_m_vignette.set_shader_parameter("force", 0.0)
	_mode = ""
	_sortie = false
	_k = 0.0
	_snap = {}


# -------------------------------------------------------------- boucle

func _maj(dt: float) -> void:
	_t += dt
	_dt = dt
	# arret : menu ouvert, deux poignees serrees, duree depassee
	if not _sortie:
		var deux_poignees: bool = app.main_d.get_float("grip") > 0.85 and app.main_g.get_float("grip") > 0.85
		if app.panneau.visible or deux_poignees or (_mode != "vide" and _t > (DUREE_HARDCORE if _mode == "hardcore" else _duree)):
			arreter()
	if _sortie:
		_k = maxf(0.0, _k - dt / 2.5)
		if _k <= 0.0:
			_restaurer()
			app.message("Sensation terminee")
			return
	else:
		_k = minf(1.0, _k + dt / 4.0)
	var e: float = _k * _k * (3.0 - 2.0 * _k)

	match _mode:
		"vide":
			_maj_vide(e)
		"tunnel":
			_maj_tunnel(e)
		"manege":
			_maj_manege(e)
		"echelle":
			_maj_echelle(e)
		"hardcore":
			_maj_hardcore(e)


func _maj_vide(e: float) -> void:
	var prof: float = 8.0 + 34.0 * _inten
	var echelle: float = 1.5 + 4.5 * _inten
	var xf0: Transform3D = _snap["sc_xf"]
	var base: Vector3 = _plateforme.global_position
	var cible_pos: Vector3 = Vector3(base.x, base.y - prof, base.z)
	var q0: Quaternion = xf0.basis.get_rotation_quaternion()
	var q1: Quaternion = Quaternion(Vector3.RIGHT, -PI * 0.5)
	var q: Quaternion = q0.slerp(q1, e)
	var s: float = lerpf(1.0, echelle, e)
	app.sc.global_transform = Transform3D(Basis(q).scaled(Vector3(s, s, s)), xf0.origin.lerp(cible_pos, e))
	_m_plat.albedo_color = Color(0.45, 0.75, 1.0, 0.08 * e)
	_m_anneau.albedo_color = Color(0.5, 0.9, 1.0, 0.9 * e)


func _maj_tunnel(e: float, it: float = -1.0) -> void:
	if it < 0.0:
		it = _inten
	var vmax: float = 0.7 + 1.8 * it
	app.sc.vitesse = lerpf(float(_snap["vit"]), vmax, e)
	app.sc.anime = true
	var vit_m: float = (5.0 + 16.0 * it) * e
	_m_warp.set_shader_parameter("cam", app.camera.global_position)
	_m_warp.set_shader_parameter("dir", _dir_voyage)
	_m_warp.set_shader_parameter("vitesse", vit_m)
	_m_warp.set_shader_parameter("force", e)
	_regler_vignette(0.25 + 0.5 * it * e)


func _maj_manege(e: float) -> void:
	var o: XROrigin3D = app.origine
	var c: Vector3 = app.sc.global_position
	var w: float = 0.12 + 0.28 * _inten
	var a: float = _a0 + w * _t
	var r: float = _r0 * (1.0 + 0.4 * _inten * sin(_t * 0.37))
	var h: float = 2.6 * _inten * sin(_t * 0.53)
	var p0: Vector3 = _snap["o_pos"]
	var chemin: Vector3 = Vector3(c.x + r * sin(a), p0.y + h, c.z + r * cos(a))
	o.global_position = p0.lerp(chemin, e)
	var fx: float = c.x - o.global_position.x
	var fz: float = c.z - o.global_position.z
	var theta: float = atan2(-fx, -fz)
	o.rotation.y = lerp_angle(float(_snap["o_rot"]), theta, e)
	_regler_vignette(0.3 + 0.45 * _inten * e)


func _maj_echelle(e: float, it: float = -1.0, periode: float = 20.0) -> void:
	var x: float = sin(TAU * _t / periode) * e
	if it < 0.0:
		it = _inten
	else:
		_ph += _dt * TAU / periode
		x = sin(_ph) * e
	var gros: float = log(1.0 + 5.0 * it)
	var petit: float = log(1.0 + 11.0 * it)
	var ws: float = exp(x * gros) if x >= 0.0 else exp(x * petit)
	app.origine.world_scale = float(_snap["ws"]) * ws
	if it == _inten:
		_regler_vignette(0.2 * it * e)


## Montee en puissance : intensite de 0,5 a 1,7, mouvements qui s'enchainent, vibrations.
func _maj_hardcore(e: float) -> void:
	var p: float = clampf(_t / 90.0, 0.0, 1.0)
	var it: float = lerpf(0.5, 1.7, p)
	_maj_tunnel(e, it)
	var periode: float = lerpf(20.0, 8.0, p)
	_maj_echelle(e, it, periode)
	_regler_vignette(0.3 + 0.5 * it * e * 0.7)
	var mv: int = int(MOUVEMENTS_HARDCORE[int(_t / 20.0) % MOUVEMENTS_HARDCORE.size()])
	if mv != _hc_mv:
		_hc_mv = mv
		app.set_mouvement(mv)
	app.sc.anime = true
	_hc_haptique -= _dt
	if _hc_haptique <= 0.0 and not _sortie:
		_hc_haptique = lerpf(0.5, 0.18, p)
		app.main_d.trigger_haptic_pulse("haptic", 0.0, 0.15 + 0.45 * p, 0.08, 0.0)
		app.main_g.trigger_haptic_pulse("haptic", 0.0, 0.15 + 0.45 * p, 0.08, 0.0)


func _regler_vignette(f: float) -> void:
	if _bord:
		_m_vignette.set_shader_parameter("force", clampf(f, 0.0, 1.0))


func _maj_etat() -> void:
	if _etat_label == null:
		return
	if _attente_mode != "":
		_etat_label.text = "Depart imminent : " + str(NOMS[_attente_mode])
	elif _mode != "":
		_etat_label.text = "En cours : %s (%d s)" % [str(NOMS[_mode]), int(_t)]
	else:
		_etat_label.text = "Aucune sensation en cours."
