class_name V31Manager
extends Node
## Mandala VR v31 : vrai mode Grand 8.
## Tunnel 3D MultiMesh autour du joueur, defilement rapide et sequences
## cinematographiques changeantes. Base de la future v32 "Grand 8 de la mort".

const PREFS_V31: String = "user://v31_grand8.json"
const NB_ANNEAUX: int = 56
const NB_TRAINEES: int = 120
const ESPACEMENT: float = 1.35
const LONGUEUR: float = NB_ANNEAUX * ESPACEMENT

const NOMS_CINE: Array = [
	"Ligne droite",
	"Slalom",
	"Vagues",
	"Spirale",
	"Plongee",
	"Serpent",
]

var app = null
var v8 = null
var v23 = null
var v29 = null
var v32 = null
var v36 = null
var _installe: bool = false
var _prefs: Dictionary = {}
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _actif: bool = false
var _profil: int = 1 # 0 confort, 1 normal, 2 extreme
var _vitesse: float = 18.0
var _courbes: float = 1.0
var _auto_cine: bool = true
var _duree_cine: float = 10.0
var _vignette_force: float = 0.35

var _racine: Node3D = null
var _anneaux_node: MultiMeshInstance3D = null
var _anneaux: MultiMesh = null
var _anneaux_mat: ShaderMaterial = null
var _trainees_node: MultiMeshInstance3D = null
var _trainees: MultiMesh = null
var _vignette: MeshInstance3D = null
var _vignette_mat: ShaderMaterial = null

var _travel: float = 0.0
var _t: float = 0.0
var _cine_t: float = 0.0
var _cine: int = 0
var _cine_avant: int = 0
var _transition_cine: float = 1.0
var _centre_local: Vector3 = Vector3.ZERO
var _snapshot: Dictionary = {}

var _streak_angle: Array = []
var _streak_radius: Array = []
var _streak_phase: Array = []
var _etat_label: Label = null
var _etat_t: float = 0.0


func _ready() -> void:
	app = get_parent()
	v8 = app.get_node_or_null("V8Manager")
	v23 = app.get_node_or_null("V23Manager")
	v29 = app.get_node_or_null("V29Manager")
	v32 = app.get_node_or_null("V32Manager")
	v36 = app.get_node_or_null("V36Manager")
	process_priority = 250
	_rng.randomize()
	_charger()


func _exit_tree() -> void:
	if _actif:
		_arreter_immediat()


func _process(dt: float) -> void:
	if app == null:
		return

	if not _installe:
		var pret: bool = (
			app.camera != null
			and app.origine != null
			and app.panneau != null
			and v23 != null
			and bool(v23.get("_installe"))
		)
		if pret:
			_installer()
		return

	if _actif:
		if app.panneau.visible:
			arreter()
			return
		_maj_grand8(dt)

	_etat_t -= dt
	if _etat_t <= 0.0:
		_etat_t = 0.4
		_maj_etat()


# -------------------------------------------------------------- prefs

func _charger() -> void:
	if not FileAccess.file_exists(PREFS_V31):
		return
	var f: FileAccess = FileAccess.open(PREFS_V31, FileAccess.READ)
	if f == null:
		return
	var j: Variant = JSON.parse_string(f.get_as_text())
	if j is Dictionary:
		var d: Dictionary = j
		_profil = clampi(int(d.get("profil", 1)), 0, 2)
		_vitesse = clampf(float(d.get("vitesse", 18.0)), 6.0, 34.0)
		_courbes = clampf(float(d.get("courbes", 1.0)), 0.25, 1.65)
		_auto_cine = bool(d.get("auto_cine", true))
		_duree_cine = clampf(float(d.get("duree_cine", 10.0)), 5.0, 20.0)
		_vignette_force = clampf(float(d.get("vignette", 0.35)), 0.0, 0.75)


func _sauver() -> void:
	var f: FileAccess = FileAccess.open(PREFS_V31, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({
			"profil": _profil,
			"vitesse": _vitesse,
			"courbes": _courbes,
			"auto_cine": _auto_cine,
			"duree_cine": _duree_cine,
			"vignette": _vignette_force,
		}))


# -------------------------------------------------------------- installation

func _installer() -> void:
	_installe = true
	_creer_tunnel()
	_creer_vignette()
	_creer_ui()
	app.panneau.rafraichir()
	app.message("v31 : Mode Grand 8 disponible dans Sensations")


func _page_sensations() -> VBoxContainer:
	for c in app.panneau.onglets.get_children():
		if str(c.name) == "Sensations" and c.get_child_count() > 0:
			return c.get_child(0) as VBoxContainer
	return null


func _creer_ui() -> void:
	var p: VBoxContainer = _page_sensations()
	if p == null:
		return

	app.panneau._titre(p, "Mode Grand 8")
	app.panneau._note(p,
		"Tu es au centre d'un tunnel 3D qui file a toute vitesse. Le parcours change automatiquement : ligne droite, slalom, vagues, spirale, plongee et serpent. Ouvre le menu pour tout arreter.")

	var g: GridContainer = GridContainer.new()
	g.columns = 3
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(g)
	_gros(g, "Confort", func() -> void: _preset(0))
	_gros(g, "Normal", func() -> void: _preset(1))
	_gros(g, "Extreme", func() -> void: _preset(2))

	var r0: HBoxContainer = app.panneau._rangee(p)
	app.panneau._bouton(r0, "DEMARRER GRAND 8", demarrer)
	app.panneau._bouton(r0, "ARRETER", arreter)

	app.panneau._curseur(p, "v31_speed", "Vitesse du Grand 8", 6.0, 34.0, 1.0,
		func() -> float: return _vitesse,
		func(v: float) -> void: _set_vitesse(v), "%.0f")
	app.panneau._curseur(p, "v31_curve", "Force des virages", 0.25, 1.65, 0.05,
		func() -> float: return _courbes,
		func(v: float) -> void: _set_courbes(v), "%.2f")
	app.panneau._bascule(p, "v31_auto", "Changer automatiquement de cinematique",
		func() -> bool: return _auto_cine,
		func(on: bool) -> void: _set_auto(on))
	app.panneau._curseur(p, "v31_cine_d", "Duree d'une sequence", 5.0, 20.0, 1.0,
		func() -> float: return _duree_cine,
		func(v: float) -> void: _set_duree_cine(v), "%.0f s")
	app.panneau._curseur(p, "v31_vignette", "Bord assombri confort", 0.0, 0.75, 0.05,
		func() -> float: return _vignette_force,
		func(v: float) -> void: _set_vignette(v), "%.2f")

	var r1: HBoxContainer = app.panneau._rangee(p)
	app.panneau._bouton(r1, "Cinematique suivante", _cine_suivante)
	app.panneau._bouton(r1, "Ligne droite", func() -> void: _set_cine(0))
	app.panneau._bouton(r1, "Spirale", func() -> void: _set_cine(3))
	app.panneau._bouton(r1, "Plongee", func() -> void: _set_cine(4))

	_etat_label = Label.new()
	_etat_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_etat_label.add_theme_font_size_override("font_size", 23)
	p.add_child(_etat_label)

	app.panneau._note(p,
		"Le futur Grand 8 de la mort utilisera cette base pour couper le tunnel, te laisser tomber dans le vide puis te faire rentrer dans un nouveau tunnel.")


func _gros(parent: Control, texte: String, cb: Callable) -> Button:
	var b: Button = Button.new()
	b.text = texte
	b.custom_minimum_size = Vector2(0, 78)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# -------------------------------------------------------------- geometrie

func _creer_tunnel() -> void:
	_racine = Node3D.new()
	_racine.name = "V31Grand8"
	_racine.visible = false
	app.origine.add_child(_racine)

	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = 2.32
	torus.outer_radius = 2.40
	torus.rings = 32
	torus.ring_segments = 6

	_anneaux_mat = ShaderMaterial.new()
	_anneaux_mat.shader = load("res://shaders/grand8_v31.gdshader")
	torus.material = _anneaux_mat

	_anneaux = MultiMesh.new()
	_anneaux.transform_format = MultiMesh.TRANSFORM_3D
	_anneaux.instance_count = NB_ANNEAUX
	_anneaux.mesh = torus

	_anneaux_node = MultiMeshInstance3D.new()
	_anneaux_node.name = "Anneaux"
	_anneaux_node.multimesh = _anneaux
	_anneaux_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_anneaux_node.extra_cull_margin = 200.0
	_racine.add_child(_anneaux_node)

	# Traits de vitesse : un seul MultiMesh supplementaire.
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.018, 0.018, 0.72)
	var sm: StandardMaterial3D = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	sm.albedo_color = Color(0.28, 0.76, 1.0, 0.58)
	sm.emission_enabled = true
	sm.emission = Color(0.18, 0.62, 1.0)
	sm.emission_energy_multiplier = 1.6
	bm.material = sm

	_trainees = MultiMesh.new()
	_trainees.transform_format = MultiMesh.TRANSFORM_3D
	_trainees.instance_count = NB_TRAINEES
	_trainees.mesh = bm

	_trainees_node = MultiMeshInstance3D.new()
	_trainees_node.name = "Trainees"
	_trainees_node.multimesh = _trainees
	_trainees_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trainees_node.extra_cull_margin = 200.0
	_racine.add_child(_trainees_node)

	_streak_angle.clear()
	_streak_radius.clear()
	_streak_phase.clear()
	for i in NB_TRAINEES:
		_streak_angle.append(_rng.randf() * TAU)
		_streak_radius.append(_rng.randf_range(1.25, 2.20))
		_streak_phase.append(_rng.randf() * LONGUEUR)


func _creer_vignette() -> void:
	_vignette = MeshInstance3D.new()
	var sp: SphereMesh = SphereMesh.new()
	sp.radius = 0.36
	sp.height = 0.72
	sp.radial_segments = 32
	sp.rings = 16
	_vignette.mesh = sp
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = load("res://shaders/vignette_v23.gdshader")
	_vignette_mat.render_priority = 101
	_vignette.material_override = _vignette_mat
	_vignette.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_vignette.visible = false
	app.camera.add_child(_vignette)


# -------------------------------------------------------------- commandes

func _preset(i: int) -> void:
	_profil = clampi(i, 0, 2)
	match _profil:
		0:
			_vitesse = 10.0
			_courbes = 0.55
			_duree_cine = 14.0
			_vignette_force = 0.58
		1:
			_vitesse = 18.0
			_courbes = 1.0
			_duree_cine = 10.0
			_vignette_force = 0.35
		2:
			_vitesse = 29.0
			_courbes = 1.45
			_duree_cine = 7.0
			_vignette_force = 0.18
	_sauver()
	app.panneau.rafraichir()
	app.message("Grand 8 : " + ["Confort", "Normal", "Extreme"][_profil])


func _set_vitesse(v: float) -> void:
	_vitesse = clampf(v, 6.0, 34.0)
	_sauver()


func _set_courbes(v: float) -> void:
	_courbes = clampf(v, 0.25, 1.65)
	_sauver()


func _set_auto(on: bool) -> void:
	_auto_cine = on
	_sauver()


func _set_duree_cine(v: float) -> void:
	_duree_cine = clampf(v, 5.0, 20.0)
	_sauver()


func _set_vignette(v: float) -> void:
	_vignette_force = clampf(v, 0.0, 0.75)
	_sauver()
	if _actif:
		_regler_vignette()


func demarrer() -> void:
	call_deferred("_demarrer_differe")


func _demarrer_differe() -> void:
	if _actif:
		return

	# Coupe proprement une ancienne sensation v23 si elle est active.
	if v23 != null:
		v23.set("_attente_mode", "")
		if str(v23.get("_mode")) != "" and v23.has_method("_restaurer"):
			v23.call("_restaurer")

	app.diff_stop()

	var paysage_visible: bool = false
	var paysage: Node3D = null
	if v29 != null:
		var pv: Variant = v29.get("_racine")
		if pv is Node3D:
			paysage = pv
			paysage_visible = paysage.visible

	var passthrough_avant: bool = false
	if v8 != null:
		passthrough_avant = bool(v8.get("_passthrough"))
		if passthrough_avant and v8.has_method("_set_passthrough"):
			v8.call("_set_passthrough", false)

	_snapshot = {
		"sc_visible": app.sc.visible,
		"monde_visible": app.monde.visible,
		"sol_visible": app.sol.visible,
		"paysage": paysage,
		"paysage_visible": paysage_visible,
		"passthrough": passthrough_avant,
	}

	app.sc.visible = false
	app.monde.visible = false
	app.sol.visible = false
	if paysage != null:
		paysage.visible = false

	_centre_local = app.camera.position
	_racine.position = _centre_local
	_racine.rotation = Vector3.ZERO
	_racine.visible = true
	_vignette.visible = _vignette_force > 0.001
	_regler_vignette()

	_travel = 0.0
	_t = 0.0
	_cine_t = 0.0
	_cine = 0
	_cine_avant = 0
	_transition_cine = 1.0
	_actif = true

	if app.panneau.visible:
		app.basculer_panneau()

	app.message("GRAND 8 lance - ouvre le menu pour arreter")


func arreter() -> void:
	if not _actif:
		return
	_arreter_immediat()
	app.message("Grand 8 termine")


func _arreter_immediat() -> void:
	_actif = false
	if _racine != null:
		_racine.visible = false
	if _vignette != null:
		_vignette.visible = false
	if _vignette_mat != null:
		_vignette_mat.set_shader_parameter("force", 0.0)

	if not _snapshot.is_empty() and app != null:
		app.sc.visible = bool(_snapshot.get("sc_visible", true))
		app.monde.visible = bool(_snapshot.get("monde_visible", true))
		app.sol.visible = bool(_snapshot.get("sol_visible", true))

		var paysage: Variant = _snapshot.get("paysage", null)
		if paysage is Node3D and is_instance_valid(paysage):
			(paysage as Node3D).visible = bool(_snapshot.get("paysage_visible", true))

		if bool(_snapshot.get("passthrough", false)) and v8 != null and v8.has_method("_set_passthrough"):
			v8.call("_set_passthrough", true)

	_snapshot = {}


# -------------------------------------------------------------- cinematique

func _cine_suivante() -> void:
	_set_cine((_cine + 1) % NOMS_CINE.size())


func _set_cine(i: int) -> void:
	var n: int = clampi(i, 0, NOMS_CINE.size() - 1)
	if n == _cine:
		return
	_cine_avant = _cine
	_cine = n
	_transition_cine = 0.0
	_cine_t = 0.0
	if _actif:
		app.message("Grand 8 : " + str(NOMS_CINE[_cine]))


func _changer_cine_auto() -> void:
	var suivant: int = _cine
	while suivant == _cine:
		suivant = _rng.randi_range(0, NOMS_CINE.size() - 1)
	_set_cine(suivant)


func _offset_cine(mode: int, d: float, t: float) -> Vector2:
	var a: float = _courbes
	match mode:
		0:
			return Vector2.ZERO
		1:
			return Vector2(
				sin(d * 0.085 + t * 0.65) * 0.95 * a,
				sin(d * 0.045 + t * 0.31) * 0.30 * a)
		2:
			return Vector2(
				sin(d * 0.052 + t * 0.42) * 0.58 * a,
				sin(d * 0.105 + t * 0.54) * 0.78 * a)
		3:
			var ang: float = d * 0.105 + t * 0.48
			var rr: float = (0.35 + 0.010 * d) * a
			return Vector2(cos(ang), sin(ang)) * rr
		4:
			return Vector2(
				sin(d * 0.052 + t * 0.28) * 0.42 * a,
				-sin(d * 0.040 + t * 0.36) * 1.22 * a)
		_:
			return Vector2(
				sin(d * 0.074 + t * 0.55) * 0.85 * a
					+ sin(d * 0.151 - t * 0.24) * 0.24 * a,
				cos(d * 0.058 + t * 0.33) * 0.58 * a)


func _offset(d: float) -> Vector2:
	var ancien: Vector2 = _offset_cine(_cine_avant, d, _t)
	var actuel: Vector2 = _offset_cine(_cine, d, _t)
	var k: float = _transition_cine * _transition_cine * (3.0 - 2.0 * _transition_cine)
	return ancien.lerp(actuel, k)


func _maj_grand8(dt: float) -> void:
	_t += dt
	_cine_t += dt
	_travel = fposmod(_travel + _vitesse * dt, LONGUEUR)

	if _auto_cine and _cine_t >= _duree_cine:
		_changer_cine_auto()

	_transition_cine = minf(1.0, _transition_cine + dt / 1.8)

	# Suit lentement la position de tete : les petits mouvements restent visibles
	# et donnent une sensation d'etre vraiment a l'interieur du tube.
	_centre_local = _centre_local.lerp(app.camera.position, clampf(dt * 0.45, 0.0, 1.0))
	_racine.position = _centre_local

	# v50 : en mode "Grand 8 de la mort", v36 redessine les memes
	# 56 anneaux juste apres nous. On evite donc ce calcul double.
	var anneaux_externes: bool = (
		v32 != null
		and v36 != null
		and bool(v36.get("_installe"))
		and bool(v32.get("_mort"))
		and int(v32.get("_etat_mort")) == 0
	)
	if not anneaux_externes:
		_maj_anneaux()

	# Les trainees restent actives : elles participent au flux de proximite.
	_maj_trainees()
	_regler_vignette()

	if _anneaux_mat != null:
		_anneaux_mat.set_shader_parameter("speed", _vitesse)
		_anneaux_mat.set_shader_parameter("cine", _cine)
		_anneaux_mat.set_shader_parameter("world_index", app.monde.courant)


func _maj_anneaux() -> void:
	if _anneaux == null:
		return

	var base_ring: Basis = Basis(Vector3.RIGHT, PI * 0.5)

	for i in NB_ANNEAUX:
		var d: float = fposmod(float(i) * ESPACEMENT - _travel, LONGUEUR)
		d += 0.75

		var p: Vector2 = _offset(d)
		var eps: float = 0.18
		var p2: Vector2 = _offset(d + eps)
		var dx: float = (p2.x - p.x) / eps
		var dy: float = (p2.y - p.y) / eps

		var yaw: float = clampf(-dx * 0.18, -0.34, 0.34)
		var pitch: float = clampf(dy * 0.18, -0.34, 0.34)
		var roll: float = 0.0
		if _cine == 3:
			roll = d * 0.075 + _t * 0.55
		elif _cine == 5:
			roll = sin(d * 0.09 + _t * 0.4) * 0.45 * _courbes

		var b: Basis = Basis(Vector3.FORWARD, roll)
		b = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch) * b * base_ring

		var pos: Vector3 = Vector3(p.x, p.y, -d)
		_anneaux.set_instance_transform(i, Transform3D(b, pos))


func _maj_trainees() -> void:
	if _trainees == null:
		return

	for i in NB_TRAINEES:
		var d: float = fposmod(float(_streak_phase[i]) - _travel * 1.34, LONGUEUR)
		d += 0.55
		var a: float = float(_streak_angle[i])
		var r: float = float(_streak_radius[i])
		var centre: Vector2 = _offset(d)
		var pos: Vector3 = Vector3(
			centre.x + cos(a) * r,
			centre.y + sin(a) * r,
			-d)

		var stretch: float = 0.75 + _vitesse / 22.0
		var b: Basis = Basis().scaled(Vector3(1.0, 1.0, stretch))
		_trainees.set_instance_transform(i, Transform3D(b, pos))


func _regler_vignette() -> void:
	if _vignette == null or _vignette_mat == null:
		return
	var f: float = _vignette_force
	if _profil == 0:
		f += minf(0.12, _courbes * 0.05)
	_vignette.visible = _actif and f > 0.001
	_vignette_mat.set_shader_parameter("force", clampf(f, 0.0, 0.85))


# -------------------------------------------------------------- etat

func _maj_etat() -> void:
	if _etat_label == null:
		return
	if not _actif:
		_etat_label.text = "Grand 8 arrete | profil %s | vitesse %.0f" % [
			["Confort", "Normal", "Extreme"][_profil], _vitesse]
		return

	_etat_label.text = "GRAND 8 EN COURS | %s | vitesse %.0f | virages %.0f%%" % [
		str(NOMS_CINE[_cine]), _vitesse, _courbes / 1.65 * 100.0]
