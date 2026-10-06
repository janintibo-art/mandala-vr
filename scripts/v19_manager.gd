class_name V19Manager
extends Node
## Mandala VR v19 : reaction au son reel et au geste de dessin.
## Lecture du niveau Master + 6 ondes de dessin recyclees.

const PREFS_V19: String = "user://v19_reactive.json"
const NB_ONDES: int = 6

var app = null
var v14 = null
var v18 = null
var _installe: bool = false
var _prefs: Dictionary = {}

var _actif: bool = true
var _son_actif: bool = true
var _dessin_actif: bool = true
var _sensibilite: float = 1.0
var _reaction_aura: float = 0.70
var _reaction_orbes: float = 0.75
var _ondes_force: float = 0.80
var _ondes_taille: float = 1.25

var _audio: float = 0.0
var _draw_flash: float = 0.0
var _live_avant: bool = false
var _points_avant: int = 0
var _dernier_pt: Vector2 = Vector2.ZERO
var _dernier_ripple_ms: int = 0
var _dernier_note_ms: int = -1

var _ondes: Array = []
var _onde_i: int = 0
var _etat_label: Label = null
var _etat_t: float = 0.0


func _ready() -> void:
	app = get_parent()
	v14 = app.get_node_or_null("V14Manager")
	v18 = app.get_node_or_null("V18Manager")
	process_priority = 190
	_lire_prefs()


func _exit_tree() -> void:
	_reinitialiser_reaction()


func _process(dt: float) -> void:
	if app == null:
		return

	if not _installe:
		if app.sc != null and app.son != null and app.panneau != null and v18 != null and bool(v18.get("_installe")):
			_installer()
		return

	_maj_audio(dt)
	_maj_dessin(dt)
	_maj_ondes(dt)
	_appliquer_reaction()

	_etat_t -= dt
	if _etat_t <= 0.0:
		_etat_t = 0.4
		_maj_etat()


# -------------------------------------------------------------- preferences

func _lire_prefs() -> void:
	if FileAccess.file_exists(PREFS_V19):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREFS_V19))
		if j is Dictionary:
			_prefs = j

	_actif = bool(_prefs.get("actif", true))
	_son_actif = bool(_prefs.get("son_actif", true))
	_dessin_actif = bool(_prefs.get("dessin_actif", true))
	_sensibilite = clampf(float(_prefs.get("sensibilite", 1.0)), 0.25, 2.0)
	_reaction_aura = clampf(float(_prefs.get("reaction_aura", 0.70)), 0.0, 1.0)
	_reaction_orbes = clampf(float(_prefs.get("reaction_orbes", 0.75)), 0.0, 1.0)
	_ondes_force = clampf(float(_prefs.get("ondes_force", 0.80)), 0.0, 1.0)
	_ondes_taille = clampf(float(_prefs.get("ondes_taille", 1.25)), 0.60, 2.40)


func _sauver_prefs() -> void:
	_prefs = {
		"actif": _actif,
		"son_actif": _son_actif,
		"dessin_actif": _dessin_actif,
		"sensibilite": _sensibilite,
		"reaction_aura": _reaction_aura,
		"reaction_orbes": _reaction_orbes,
		"ondes_force": _ondes_force,
		"ondes_taille": _ondes_taille,
	}
	var f: FileAccess = FileAccess.open(PREFS_V19, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_prefs))
		f.close()


# -------------------------------------------------------------- installation

func _installer() -> void:
	_installe = true
	_creer_ondes()
	_dernier_note_ms = int(app.son.get("_dernier_t"))

	var p: VBoxContainer = _page_rapide()
	if p != null:
		_installer_ui(p)

	app.panneau.rafraichir()
	app.message("Mandala VR v19 : reactions son et dessin actives")


func _page_rapide() -> VBoxContainer:
	for c in app.panneau.onglets.get_children():
		if str(c.name) == "Rapide" and c.get_child_count() > 0:
			return c.get_child(0) as VBoxContainer
	return null


# -------------------------------------------------------------- audio reel

func _niveau_master() -> float:
	# Le bus Master contient les ambiances et les notes de dessin.
	var db: float = AudioServer.get_bus_peak_volume_left_db(0, 0)
	if db <= -60.0:
		return 0.0
	var lin: float = pow(10.0, db / 20.0)
	return clampf(lin * _sensibilite, 0.0, 1.0)


func _maj_audio(dt: float) -> void:
	var cible: float = 0.0
	if _actif and _son_actif and not app.son.muet:
		cible = _niveau_master()

	# Attaque rapide, relache plus lente : visuellement stable en VR.
	var vitesse: float = 12.0 if cible > _audio else 3.2
	_audio = lerpf(_audio, cible, clampf(dt * vitesse, 0.0, 1.0))

	# Une note de dessin declenche un petit accent visuel net.
	var note_ms: int = int(app.son.get("_dernier_t"))
	if note_ms != _dernier_note_ms:
		_dernier_note_ms = note_ms
		if note_ms > 0 and _actif and _son_actif:
			_draw_flash = maxf(_draw_flash, 0.55)

	_draw_flash = move_toward(_draw_flash, 0.0, dt * 1.9)


# -------------------------------------------------------------- dessin

func _maj_dessin(_dt: float) -> void:
	var live: bool = app.sc.live_actif()

	if not _actif or not _dessin_actif:
		_live_avant = live
		return

	var td: TraitDessin = app.sc.get("_live_t") as TraitDessin
	if live and td != null:
		var n: int = td.points.size()

		if not _live_avant:
			_draw_flash = 1.0
			_points_avant = 0
			if n > 0:
				_dernier_pt = td.points[n - 1]
				_lancer_onde(_dernier_pt, td.calque, 1.0)

		if n > _points_avant and n > 0:
			var pt: Vector2 = td.points[n - 1]
			var maintenant: int = Time.get_ticks_msec()
			var assez_loin: bool = pt.distance_to(_dernier_pt) > 38.0
			var assez_tard: bool = maintenant - _dernier_ripple_ms > 170
			if n <= 2 or (assez_loin and assez_tard):
				_lancer_onde(pt, td.calque, 0.62)
				_dernier_pt = pt
			_points_avant = n

	elif _live_avant and not live:
		_draw_flash = maxf(_draw_flash, 0.48)
		_points_avant = 0

	_live_avant = live


# -------------------------------------------------------------- ondes recyclees

func _creer_ondes() -> void:
	var shader: Shader = load("res://shaders/onde_v19.gdshader")
	for i in NB_ONDES:
		var mi: MeshInstance3D = MeshInstance3D.new()
		mi.name = "V19Onde%d" % i
		var q: QuadMesh = QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		mi.mesh = q
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 10.0
		mi.visible = false

		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = shader
		mi.material_override = mat
		app.sc.add_child(mi)

		_ondes.append({
			"node": mi,
			"mat": mat,
			"age": 99.0,
			"duree": 0.72,
			"force": 0.0,
		})


func _couleur_style() -> Color:
	if v18 != null:
		var c: Variant = v18.call("_couleur_style")
		if c is Color:
			return c
	return Color(0.18, 0.72, 1.0)


func _lancer_onde(pt: Vector2, calque: int, force_evt: float) -> void:
	if app.sc.dome > 0.30 or app.sc.dome_cible > 0.5:
		return
	if _ondes.is_empty():
		return

	var d: Dictionary = _ondes[_onde_i]
	_onde_i = (_onde_i + 1) % _ondes.size()

	var mi: MeshInstance3D = d["node"]
	var mat: ShaderMaterial = d["mat"]
	var k: int = clampi(calque, 0, app.sc.pivots.size() - 1)
	var pivot: Node3D = app.sc.pivots[k]

	var local_pt: Vector3 = Vector3(
		pt.x * Scene3D.PX,
		-pt.y * Scene3D.PX,
		0.12)
	var sc_pt: Vector3 = pivot.transform * local_pt

	mi.position = sc_pt
	mi.scale = Vector3.ONE
	mi.visible = true

	var f: float = clampf(force_evt * _ondes_force, 0.0, 1.0)
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("intensity", f)
	mat.set_shader_parameter("tint", _couleur_style())
	mat.set_shader_parameter("audio", _audio)

	d["age"] = 0.0
	d["duree"] = 0.62 + (1.0 - f) * 0.20
	d["force"] = f
	_ondes[(_onde_i - 1 + _ondes.size()) % _ondes.size()] = d
	_dernier_ripple_ms = Time.get_ticks_msec()


func _maj_ondes(dt: float) -> void:
	for i in _ondes.size():
		var d: Dictionary = _ondes[i]
		var mi: MeshInstance3D = d["node"]
		if not mi.visible:
			continue

		var age: float = float(d["age"]) + dt
		var duree: float = float(d["duree"])
		var p: float = clampf(age / maxf(duree, 0.05), 0.0, 1.0)
		var mat: ShaderMaterial = d["mat"]

		mat.set_shader_parameter("progress", p)
		mat.set_shader_parameter("audio", _audio)
		var taille: float = lerpf(0.18, _ondes_taille, p)
		mi.scale = Vector3.ONE * taille

		if p >= 0.999:
			mi.visible = false

		d["age"] = age
		_ondes[i] = d


# -------------------------------------------------------------- reaction v18

func _appliquer_reaction() -> void:
	if v18 == null:
		return

	var son_gain: float = _audio if (_actif and _son_actif) else 0.0
	var draw_gain: float = _draw_flash if (_actif and _dessin_actif) else 0.0

	var aura: Variant = v18.get("_aura_mat")
	if aura is ShaderMaterial:
		var am: ShaderMaterial = aura
		am.set_shader_parameter("reactive", son_gain * _reaction_aura)
		am.set_shader_parameter("draw_flash", draw_gain)

	var orb: Variant = v18.get("_orb_mat")
	if orb is ShaderMaterial:
		var om: ShaderMaterial = orb
		om.set_shader_parameter("reactive", son_gain * _reaction_orbes)
		om.set_shader_parameter("draw_flash", draw_gain)

	var orb_node: Variant = v18.get("_orb_node")
	if orb_node is MultiMeshInstance3D:
		var n: MultiMeshInstance3D = orb_node
		var s: float = 1.0 + son_gain * 0.025 + draw_gain * 0.018
		n.scale = Vector3.ONE * s


func _reinitialiser_reaction() -> void:
	if v18 == null:
		return
	var aura: Variant = v18.get("_aura_mat")
	if aura is ShaderMaterial:
		(aura as ShaderMaterial).set_shader_parameter("reactive", 0.0)
		(aura as ShaderMaterial).set_shader_parameter("draw_flash", 0.0)
	var orb: Variant = v18.get("_orb_mat")
	if orb is ShaderMaterial:
		(orb as ShaderMaterial).set_shader_parameter("reactive", 0.0)
		(orb as ShaderMaterial).set_shader_parameter("draw_flash", 0.0)
	var orb_node: Variant = v18.get("_orb_node")
	if orb_node is MultiMeshInstance3D:
		(orb_node as MultiMeshInstance3D).scale = Vector3.ONE


# -------------------------------------------------------------- UI

func _installer_ui(p: VBoxContainer) -> void:
	app.panneau._titre(p, "Visuel reactif")
	app.panneau._note(p,
		"L'aura reagit au niveau sonore reel de l'application. Quand tu dessines, des ondes lumineuses partent du pinceau et les notes produisent de petits impacts visuels.")

	var g: GridContainer = GridContainer.new()
	g.columns = 3
	g.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(g)
	_gros(g, "Calme", _preset_calme)
	_gros(g, "Musical", _preset_musical)
	_gros(g, "Live", _preset_live)

	app.panneau._bascule(p, "v19_on", "Reactivite visuelle",
		func() -> bool: return _actif,
		func(on: bool) -> void: _set_actif(on))
	app.panneau._bascule(p, "v19_sound", "Reactif au son",
		func() -> bool: return _son_actif,
		func(on: bool) -> void: _set_son(on))
	app.panneau._bascule(p, "v19_draw", "Reactif au dessin",
		func() -> bool: return _dessin_actif,
		func(on: bool) -> void: _set_dessin(on))

	app.panneau._curseur(p, "v19_sens", "Sensibilite sonore", 0.25, 2.0, 0.05,
		func() -> float: return _sensibilite,
		func(v: float) -> void: _set_sensibilite(v), "%.2f")
	app.panneau._curseur(p, "v19_aura", "Reaction de l'aura", 0.0, 1.0, 0.05,
		func() -> float: return _reaction_aura,
		func(v: float) -> void: _set_reaction_aura(v), "%.2f")
	app.panneau._curseur(p, "v19_orb", "Reaction des orbites", 0.0, 1.0, 0.05,
		func() -> float: return _reaction_orbes,
		func(v: float) -> void: _set_reaction_orbes(v), "%.2f")
	app.panneau._curseur(p, "v19_wave", "Force des ondes de dessin", 0.0, 1.0, 0.05,
		func() -> float: return _ondes_force,
		func(v: float) -> void: _set_ondes_force(v), "%.2f")
	app.panneau._curseur(p, "v19_size", "Taille des ondes", 0.60, 2.40, 0.05,
		func() -> float: return _ondes_taille,
		func(v: float) -> void: _set_ondes_taille(v), "%.2f m")

	var r: HBoxContainer = app.panneau._rangee(p)
	app.panneau._bouton(r, "Tester impact", _tester_impact)
	app.panneau._bouton(r, "Tester onde centre", _tester_onde)

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


func _preset_calme() -> void:
	_actif = true
	_son_actif = true
	_dessin_actif = true
	_sensibilite = 0.75
	_reaction_aura = 0.35
	_reaction_orbes = 0.30
	_ondes_force = 0.45
	_ondes_taille = 0.95
	_fin_preset("Reactif : Calme")


func _preset_musical() -> void:
	_actif = true
	_son_actif = true
	_dessin_actif = true
	_sensibilite = 1.0
	_reaction_aura = 0.70
	_reaction_orbes = 0.75
	_ondes_force = 0.80
	_ondes_taille = 1.25
	_fin_preset("Reactif : Musical")


func _preset_live() -> void:
	_actif = true
	_son_actif = true
	_dessin_actif = true
	_sensibilite = 1.45
	_reaction_aura = 1.0
	_reaction_orbes = 1.0
	_ondes_force = 1.0
	_ondes_taille = 1.75
	_fin_preset("Reactif : Live")


func _fin_preset(msg: String) -> void:
	_sauver_prefs()
	app.panneau.rafraichir()
	app.message(msg)


func _set_actif(on: bool) -> void:
	_actif = on
	if not on:
		_audio = 0.0
		_draw_flash = 0.0
		_reinitialiser_reaction()
	_sauver_prefs()


func _set_son(on: bool) -> void:
	_son_actif = on
	_sauver_prefs()


func _set_dessin(on: bool) -> void:
	_dessin_actif = on
	_sauver_prefs()


func _set_sensibilite(v: float) -> void:
	_sensibilite = clampf(v, 0.25, 2.0)
	_sauver_prefs()


func _set_reaction_aura(v: float) -> void:
	_reaction_aura = clampf(v, 0.0, 1.0)
	_sauver_prefs()


func _set_reaction_orbes(v: float) -> void:
	_reaction_orbes = clampf(v, 0.0, 1.0)
	_sauver_prefs()


func _set_ondes_force(v: float) -> void:
	_ondes_force = clampf(v, 0.0, 1.0)
	_sauver_prefs()


func _set_ondes_taille(v: float) -> void:
	_ondes_taille = clampf(v, 0.60, 2.40)
	_sauver_prefs()


func _tester_impact() -> void:
	_draw_flash = 1.0


func _tester_onde() -> void:
	_lancer_onde(Vector2.ZERO, 0, 1.0)


# -------------------------------------------------------------- etat

func _maj_etat() -> void:
	if _etat_label == null:
		return
	if not _actif:
		_etat_label.text = "Reactivite visuelle coupee"
		return

	var dessin: String = "dessin" if _dessin_actif else "dessin off"
	var son_txt: String = "son %.0f%%" % (_audio * 100.0) if _son_actif else "son off"
	_etat_label.text = "%s | %s | impact %.0f%% | 6 ondes recyclees" % [
		son_txt, dessin, _draw_flash * 100.0]
