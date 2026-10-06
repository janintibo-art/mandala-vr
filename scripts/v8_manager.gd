class_name V8Manager
extends Node
## Mandala VR v8 : meditation 2.0, performance Quest 3, confort VR,
## favoris/sauvegarde et options d'immersion. Isole de la logique v7.

const PREFS_V8: String = "user://v8.json"
const VITESSE_BASE: float = 3.5
const MONDES_CALMES: Array = [1, 2, 3, 4, 7, 8, 10, 11]
const MOUVEMENTS_CALMES: Array = [4, 5, 6, 7]

var app = null
var _ui_installee: bool = false
var _prefs: Dictionary = {}

# meditation
var _meditation: bool = false
var _meditation_restant: float = 0.0
var _meditation_scene_t: float = 0.0
var _meditation_snapshot: Dictionary = {}
var _meditation_label: Label3D = null

# performance
var _qualite_auto: bool = true
var _vrs_actif: bool = true
var _fps_lisse: float = 72.0
var _fps_bas_t: float = 0.0
var _fps_haut_t: float = 0.0
var _diag_t: float = 0.0
var _diag_label: Label = null

# confort
var _vitesse_mult: float = 1.0
var _angle_rotation: float = 30.0
var _teleportation: bool = false
var _voile_confort: bool = true
var _mode_assis: bool = false
var _hauteur_assis: float = 0.65
var _assis_applique: bool = false
var _origine_precedente: Vector3 = Vector3.ZERO
var _origine_connue: bool = false
var _snap_pret: bool = true
var _teleport_g_avant: bool = false
var _teleport_marqueur: MeshInstance3D = null
var _voile: MeshInstance3D = null
var _voile_mat: StandardMaterial3D = null

# immersion / favoris
var _passthrough: bool = false
var _favoris: Array = []
var _favori_boutons: Array = []


func _ready() -> void:
	app = get_parent()
	process_priority = 100
	_lire_prefs()


func _process(dt: float) -> void:
	if app == null:
		return
	if not _ui_installee:
		if app.panneau != null and app.camera != null and app.origine != null:
			_installer_v8()
		return
	_maj_meditation(dt)
	_maj_qualite_auto(dt)
	_maj_confort(dt)
	_maj_diagnostic(dt)


# ---------------------------------------------------------------- preferences

func _lire_prefs() -> void:
	if FileAccess.file_exists(PREFS_V8):
		var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(PREFS_V8))
		if j is Dictionary:
			_prefs = j
	_qualite_auto = bool(_prefs.get("qualite_auto", true))
	_vrs_actif = bool(_prefs.get("vrs", true))
	_vitesse_mult = clampf(float(_prefs.get("vitesse_mult", 1.0)), 0.45, 1.40)
	_angle_rotation = clampf(float(_prefs.get("angle_rotation", 30.0)), 15.0, 45.0)
	_teleportation = bool(_prefs.get("teleportation", false))
	_voile_confort = bool(_prefs.get("voile_confort", true))
	_mode_assis = bool(_prefs.get("mode_assis", false))
	_hauteur_assis = clampf(float(_prefs.get("hauteur_assis", 0.65)), 0.25, 1.00)
	_favoris = _prefs.get("favoris", []) if _prefs.get("favoris", null) is Array else []


func _sauver_prefs() -> void:
	_prefs = {
		"qualite_auto": _qualite_auto,
		"vrs": _vrs_actif,
		"vitesse_mult": _vitesse_mult,
		"angle_rotation": _angle_rotation,
		"teleportation": _teleportation,
		"voile_confort": _voile_confort,
		"mode_assis": _mode_assis,
		"hauteur_assis": _hauteur_assis,
		"favoris": _favoris,
	}
	var f: FileAccess = FileAccess.open(PREFS_V8, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(_prefs))
		f.close()


# ---------------------------------------------------------------- installation

func _installer_v8() -> void:
	_ui_installee = true
	_origine_precedente = app.origine.global_position
	_origine_connue = true
	_creer_voile_confort()
	_creer_marqueur_teleport()
	_creer_hud_meditation()
	_installer_ui()
	_appliquer_vrs()
	if _mode_assis and not _assis_applique:
		app.origine.global_position.y += _hauteur_assis
		_assis_applique = true
	app.message("Mandala VR v8 pret")


func _creer_hud_meditation() -> void:
	_meditation_label = Label3D.new()
	_meditation_label.pixel_size = 0.0009
	_meditation_label.font_size = 42
	_meditation_label.outline_size = 8
	_meditation_label.no_depth_test = true
	_meditation_label.position = Vector3(0.0, -0.19, -1.15)
	_meditation_label.visible = false
	app.camera.add_child(_meditation_label)


func _creer_voile_confort() -> void:
	_voile = MeshInstance3D.new()
	var sp: SphereMesh = SphereMesh.new()
	sp.radius = 0.39
	sp.height = 0.78
	_voile.mesh = sp
	_voile_mat = StandardMaterial3D.new()
	_voile_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_voile_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_voile_mat.albedo_color = Color(0, 0, 0, 0)
	_voile_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_voile_mat.no_depth_test = true
	_voile_mat.render_priority = 90
	_voile.material_override = _voile_mat
	app.camera.add_child(_voile)


func _creer_marqueur_teleport() -> void:
	_teleport_marqueur = MeshInstance3D.new()
	var cy: CylinderMesh = CylinderMesh.new()
	cy.top_radius = 0.18
	cy.bottom_radius = 0.18
	cy.height = 0.015
	_teleport_marqueur.mesh = cy
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.25, 0.8, 1.0, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_teleport_marqueur.material_override = mat
	_teleport_marqueur.visible = false
	app.add_child(_teleport_marqueur)


# ---------------------------------------------------------------- interface V8

func _installer_ui() -> void:
	var p: VBoxContainer = app.panneau._page("V8")
	app.panneau._titre(p, "Mandala VR v8")
	app.panneau._note(p, "Meditation 2.0, performances Quest 3, confort VR, favoris, sauvegarde complete et realite mixte.")

	app.panneau._titre(p, "Meditation 2.0")
	var rm: HBoxContainer = app.panneau._rangee(p)
	for minutes in [5, 10, 20, 30]:
		app.panneau._bouton(rm, "%d min" % int(minutes), _demarrer_meditation.bind(int(minutes)))
	app.panneau._bouton(rm, "Stop", _arreter_meditation)
	app.panneau._note(p, "Scenes lentes, respiration guidee, ruisseau verrouille et restauration des reglages a la fin.")

	app.panneau._titre(p, "Performance Quest 3")
	app.panneau._bascule(p, "v8_qa", "Qualite automatique selon les FPS", func() -> bool: return _qualite_auto, func(on: bool) -> void: _set_qualite_auto(on))
	app.panneau._bascule(p, "v8_vrs", "VRS XR / foveation Mobile", func() -> bool: return _vrs_actif, func(on: bool) -> void: _set_vrs(on))
	_diag_label = Label.new()
	_diag_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_diag_label.add_theme_font_size_override("font_size", 22)
	p.add_child(_diag_label)

	app.panneau._titre(p, "Confort VR")
	app.panneau._curseur(p, "v8_vit", "Vitesse de deplacement", 0.45, 1.40, 0.05, func() -> float: return _vitesse_mult, func(v: float) -> void: _set_vitesse(v), "%.2f")
	app.panneau._curseur(p, "v8_rot", "Rotation par cran", 15.0, 45.0, 15.0, func() -> float: return _angle_rotation, func(v: float) -> void: _set_angle(v), "%.0f")
	app.panneau._bascule(p, "v8_tel", "Teleportation (viser avec la main droite, gachette gauche)", func() -> bool: return _teleportation, func(on: bool) -> void: _set_teleportation(on))
	app.panneau._bascule(p, "v8_voile", "Voile confort pendant les deplacements", func() -> bool: return _voile_confort, func(on: bool) -> void: _set_voile(on))
	app.panneau._bascule(p, "v8_assis", "Mode assis", func() -> bool: return _mode_assis, func(on: bool) -> void: _set_mode_assis(on))
	app.panneau._curseur(p, "v8_hassis", "Compensation hauteur assise", 0.25, 1.00, 0.05, func() -> float: return _hauteur_assis, func(v: float) -> void: _set_hauteur_assis(v), "%.2f")
	var rc: HBoxContainer = app.panneau._rangee(p)
	app.panneau._bouton(rc, "Recentrer confort", _recentrer_confort)
	app.panneau._bouton(rc, "Retour vitesse normale", func() -> void: _set_vitesse(1.0))

	app.panneau._titre(p, "Immersion Quest 3")
	app.panneau._bascule(p, "v8_pass", "Passthrough / realite mixte", func() -> bool: return _passthrough, func(on: bool) -> void: _set_passthrough(on))
	app.panneau._note(p, "Hand tracking optionnel active dans OpenXR. Les manettes restent le mode de controle principal.")

	app.panneau._titre(p, "Favoris de modeles")
	var gf: GridContainer = GridContainer.new()
	gf.columns = 3
	gf.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_child(gf)
	var modeles: Array = Generateur.modeles()
	for i in modeles.size():
		var b: Button = Button.new()
		b.toggle_mode = true
		b.clip_text = true
		b.custom_minimum_size = Vector2(0, 62)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_toggle_favori.bind(i))
		gf.add_child(b)
		_favori_boutons.append(b)
	_rafraichir_favoris()
	var rf: HBoxContainer = app.panneau._rangee(p)
	app.panneau._bouton(rf, "Lancer un favori au hasard", _lancer_favori)
	app.panneau._bouton(rf, "Effacer les favoris", _effacer_favoris)

	app.panneau._titre(p, "Sauvegarde complete")
	var rs: HBoxContainer = app.panneau._rangee(p)
	app.panneau._bouton(rs, "Copier la sauvegarde", _backup_copier)
	app.panneau._bouton(rs, "Restaurer le presse-papiers", _backup_restaurer)
	app.panneau._note(p, "La sauvegarde contient les creations du casque, listes de diffusion, reglages v7 et reglages v8.")
	app.panneau.rafraichir()


# ---------------------------------------------------------------- meditation

func _demarrer_meditation(minutes: int) -> void:
	if _meditation:
		_arreter_meditation()
	if app._diff_actif:
		app.diff_stop()
	_meditation_snapshot = {
		"oeuvre": Oeuvre.encoder("__avant_meditation__", app.sc),
		"reg": app.reg.copie(),
		"monde": app.monde.courant,
		"ambiance": app.son.ambiance,
		"gamme": app.son.gamme,
		"muet": app.son.muet,
		"souffle": app.sc.souffle,
		"souffle_periode": app.sc.souffle_periode,
		"anime": app.sc.anime,
		"qualite": app.qualite,
		"sol": app.sol_visible,
		"dome": app.sc.dome,
		"dome_cible": app.sc.dome_cible,
		"dome_ang": app.sc.dome_ang,
		"dome_c": app.sc.dome_c,
		"dome_b": app.sc.dome_b,
		"passthrough": _passthrough,
	}
	if _passthrough:
		_set_passthrough(false)
	_meditation = true
	_meditation_restant = float(clampi(minutes, 1, 120) * 60)
	_meditation_scene_t = 0.0
	app.sc.souffle = true
	app.sc.souffle_periode = 10.0
	app.son.gamme = 0
	app.son.choisir_ambiance(4)
	_nouvelle_scene_meditation()
	_meditation_label.visible = true
	app.message("Meditation %d min" % minutes)


func _nouvelle_scene_meditation() -> void:
	var c: Dictionary = Generateur.tirage(app.rng, "Meditation", true)
	var r: Reglages = c["reglages"]
	r.branches = clampi(r.branches, 6, 16)
	r.epaisseur = clampf(r.epaisseur, 0.8, 2.0)
	r.opacite = clampf(r.opacite, 0.65, 0.95)
	r.recursion = mini(r.recursion, 2)
	c["monde"] = int(MONDES_CALMES[app.rng.randi_range(0, MONDES_CALMES.size() - 1)])
	c["mouvement"] = int(MOUVEMENTS_CALMES[app.rng.randi_range(0, MOUVEMENTS_CALMES.size() - 1)])
	c["vitesse"] = 0.14 + app.rng.randf() * 0.22
	c["ambiance"] = 4
	app._appliquer_config(c)
	app.sc.souffle = true
	app.sc.souffle_periode = 10.0
	if app.son.ambiance != 4:
		app.son.choisir_ambiance(4)
	_meditation_scene_t = 55.0


func _maj_meditation(dt: float) -> void:
	if not _meditation:
		return
	_meditation_restant -= dt
	_meditation_scene_t -= dt
	if _meditation_restant <= 0.0:
		_arreter_meditation()
		return
	if _meditation_scene_t <= 0.0 and not app.sc.occupe:
		_nouvelle_scene_meditation()
	var reste: int = maxi(0, int(ceil(_meditation_restant)))
	var periode: float = maxf(app.sc.souffle_periode, 2.0)
	var phase: float = fposmod(app.sc._souffle_t, periode) / periode
	var mot: String = "INSPIRE" if phase < 0.5 else "EXPIRE"
	_meditation_label.text = "%s   %02d:%02d" % [mot, reste / 60, reste % 60]


func _arreter_meditation() -> void:
	if not _meditation:
		return
	_meditation = false
	_meditation_label.visible = false
	var snap: Dictionary = _meditation_snapshot
	_meditation_snapshot = {}
	var o: Dictionary = Oeuvre.decoder(str(snap.get("oeuvre", "")))
	if not o.is_empty():
		Oeuvre.appliquer(o, app.sc)
	app.reg = (snap["reg"] as Reglages).copie()
	app.set_monde(int(snap.get("monde", 0)))
	app.son.gamme = int(snap.get("gamme", 0))
	var avant_muet: bool = bool(snap.get("muet", false))
	if app.son.muet != avant_muet:
		app.son.basculer_muet()
	app.son.choisir_ambiance(int(snap.get("ambiance", 0)))
	app.sc.souffle = bool(snap.get("souffle", false))
	app.sc.souffle_periode = float(snap.get("souffle_periode", 10.0))
	app.sc.anime = bool(snap.get("anime", true))
	app.set_qualite(int(snap.get("qualite", 1)))
	app.sol_visible = bool(snap.get("sol", true))
	app.sc.dome = float(snap.get("dome", 0.0))
	app.sc.dome_cible = float(snap.get("dome_cible", 0.0))
	app.sc.dome_ang = float(snap.get("dome_ang", 1.9))
	app.sc.dome_c = snap.get("dome_c", Vector3(0.0, 1.6, 0.0))
	app.sc.dome_b = snap.get("dome_b", Basis())
	app.sc.appliquer_fx()
	app.sc.appliquer_fond(app.env)
	app.sol.visible = app.sol_visible and app.sc.dome_cible < 0.5
	app._maj_boucle()
	app._maj_hud()
	app.panneau.palettes_changees()
	app.panneau.rafraichir()
	if bool(snap.get("passthrough", false)):
		_set_passthrough(true)
	app.son.demarrage()
	app.message("Seance terminee - reglages restaures")


# ---------------------------------------------------------------- performance

func _set_qualite_auto(on: bool) -> void:
	_qualite_auto = on
	_fps_bas_t = 0.0
	_fps_haut_t = 0.0
	_sauver_prefs()


func _set_vrs(on: bool) -> void:
	_vrs_actif = on
	_appliquer_vrs()
	_sauver_prefs()


func _appliquer_vrs() -> void:
	if not _ui_installee:
		return
	get_viewport().vrs_mode = Viewport.VRS_XR if _vrs_actif else Viewport.VRS_DISABLED
	if app.xr != null:
		app.xr.set("vrs_min_radius", 24.0)
		app.xr.set("vrs_strength", 1.15 if _vrs_actif else 0.0)


func _maj_qualite_auto(dt: float) -> void:
	if not _qualite_auto or not app.xr_actif:
		return
	var fps: float = Engine.get_frames_per_second()
	if fps < 1.0:
		return
	_fps_lisse = lerpf(_fps_lisse, fps, clampf(dt * 2.0, 0.0, 1.0))
	var cible: float = 72.0
	if app.xr != null:
		var rr: Variant = app.xr.get("display_refresh_rate")
		if rr is float and float(rr) > 30.0:
			cible = float(rr)
	if _fps_lisse < cible - 9.0:
		_fps_bas_t += dt
		_fps_haut_t = 0.0
		if _fps_bas_t >= 3.0 and app.qualite > 0:
			app.set_qualite(app.qualite - 1)
			app.panneau.rafraichir()
			_fps_bas_t = 0.0
			app.message("Qualite auto : " + ["Eco", "Normal", "Maximum"][app.qualite])
	elif _fps_lisse > cible - 1.5:
		_fps_haut_t += dt
		_fps_bas_t = 0.0
		if _fps_haut_t >= 18.0 and app.qualite < 2 and not app.sc.occupe:
			app.set_qualite(app.qualite + 1)
			app.panneau.rafraichir()
			_fps_haut_t = 0.0
			app.message("Qualite auto : " + ["Eco", "Normal", "Maximum"][app.qualite])
	else:
		_fps_bas_t = maxf(0.0, _fps_bas_t - dt)
		_fps_haut_t = maxf(0.0, _fps_haut_t - dt)


func _maj_diagnostic(dt: float) -> void:
	_diag_t -= dt
	if _diag_t > 0.0 or _diag_label == null:
		return
	_diag_t = 0.5
	var q: String = ["Eco", "Normal", "Maximum"][clampi(app.qualite, 0, 2)]
	var xr_txt: String = "XR actif" if app.xr_actif else "XR inactif"
	var vrs_txt: String = "VRS XR" if get_viewport().vrs_mode == Viewport.VRS_XR else "VRS off"
	var mode_txt: String = "Passthrough" if _passthrough else "VR"
	_diag_label.text = "FPS %d | %s%s | %s\n%s | %s\n%s" % [int(round(_fps_lisse)), q, " auto" if _qualite_auto else "", vrs_txt, xr_txt, mode_txt, app.sc.derniere_stat]


# ---------------------------------------------------------------- confort VR

func _set_vitesse(v: float) -> void:
	_vitesse_mult = clampf(v, 0.45, 1.40)
	_sauver_prefs()
	if app.panneau != null:
		app.panneau.rafraichir()


func _set_angle(v: float) -> void:
	_angle_rotation = clampf(v, 15.0, 45.0)
	_sauver_prefs()


func _set_teleportation(on: bool) -> void:
	_teleportation = on
	if not on and _teleport_marqueur != null:
		_teleport_marqueur.visible = false
	_sauver_prefs()
	app.message("Teleportation : " + ("oui" if on else "non"))


func _set_voile(on: bool) -> void:
	_voile_confort = on
	if not on and _voile_mat != null:
		_voile_mat.albedo_color = Color(0, 0, 0, 0)
	_sauver_prefs()


func _set_mode_assis(on: bool) -> void:
	if on == _mode_assis:
		return
	app.origine.global_position.y += _hauteur_assis if on else -_hauteur_assis
	_mode_assis = on
	_assis_applique = on
	_origine_precedente = app.origine.global_position
	_sauver_prefs()
	app.message("Mode assis" if on else "Mode debout")


func _set_hauteur_assis(v: float) -> void:
	var nv: float = clampf(v, 0.25, 1.00)
	if _mode_assis:
		app.origine.global_position.y += nv - _hauteur_assis
	_hauteur_assis = nv
	_origine_precedente = app.origine.global_position
	_sauver_prefs()


func _recentrer_confort() -> void:
	var y: float = _hauteur_assis if _mode_assis else 0.0
	app.origine.global_transform = Transform3D(Basis(), Vector3(0.0, y, 0.0))
	_origine_precedente = app.origine.global_position
	app.message("Position recentree")


func _cible_teleport() -> Variant:
	if app.main_d == null:
		return null
	var o: Vector3 = app.main_d.global_position
	var d: Vector3 = -app.main_d.global_transform.basis.z
	if d.y >= -0.02:
		return null
	var t: float = -o.y / d.y
	if t < 0.35 or t > 12.0:
		return null
	return o + d * t


func _teleporter(pt: Vector3) -> void:
	var delta: Vector3 = pt - app.camera.global_position
	delta.y = 0.0
	app.origine.global_position += delta
	_origine_precedente = app.origine.global_position
	app.main_g.trigger_haptic_pulse("haptic", 0.0, 0.45, 0.05, 0.0)
	app.message("Teleporte")


func _maj_confort(dt: float) -> void:
	if app.origine == null or app.main_g == null or app.main_d == null:
		return
	var mv: Vector2 = app.main_g.get_vector2("primary")
	var dr: Vector2 = app.main_d.get_vector2("primary")

	# Corrige apres le deplacement v7 afin de garder sa logique et ses collisions.
	var cur: Vector3 = app.origine.global_position
	if _origine_connue and absf(_vitesse_mult - 1.0) > 0.001:
		var mouvement_actif: bool = mv.length() > 0.15 or absf(dr.y) > 0.2
		var delta: Vector3 = cur - _origine_precedente
		if mouvement_actif and delta.length() < 1.2:
			cur = _origine_precedente + delta * _vitesse_mult
			app.origine.global_position = cur
	_origine_precedente = app.origine.global_position
	_origine_connue = true

	# La v7 tourne de 30 degres. On ajoute seulement la difference demandee.
	if not app.panneau.visible:
		if absf(dr.x) < 0.3:
			_snap_pret = true
		elif absf(dr.x) > 0.7 and _snap_pret:
			_snap_pret = false
			var extra: float = (30.0 - _angle_rotation) * signf(dr.x)
			if absf(extra) > 0.1:
				app._tourner(extra)

	# Teleport : rayon droit + gachette gauche, sans modifier le dessin v7.
	var cible: Variant = _cible_teleport() if _teleportation and not app.panneau.visible else null
	if cible != null:
		_teleport_marqueur.visible = true
		_teleport_marqueur.global_position = (cible as Vector3) + Vector3(0.0, 0.015, 0.0)
	else:
		_teleport_marqueur.visible = false
	var g: bool = app.main_g.get_float("trigger") > 0.72
	if _teleportation and g and not _teleport_g_avant and cible != null:
		_teleporter(cible as Vector3)
	_teleport_g_avant = g

	# Voile discret pendant les mouvements / rotations.
	if _voile_mat != null:
		var cible_a: float = 0.0
		if _voile_confort and (mv.length() > 0.16 or absf(dr.x) > 0.55 or absf(dr.y) > 0.55):
			cible_a = 0.12
		var a: float = move_toward(_voile_mat.albedo_color.a, cible_a, dt * 1.8)
		_voile_mat.albedo_color = Color(0, 0, 0, a)


# ---------------------------------------------------------------- passthrough / immersion

func _set_passthrough(on: bool) -> void:
	var xi: XRInterface = XRServer.primary_interface
	if xi == null:
		_passthrough = false
		app.message("Passthrough indisponible")
		if app.panneau != null:
			app.panneau.rafraichir()
		return
	var modes: Array = xi.get_supported_environment_blend_modes()
	if on:
		if XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND in modes:
			xi.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ALPHA_BLEND
			get_viewport().transparent_bg = true
		elif XRInterface.XR_ENV_BLEND_MODE_ADDITIVE in modes:
			xi.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_ADDITIVE
			get_viewport().transparent_bg = false
		else:
			_passthrough = false
			app.message("Passthrough non supporte")
			app.panneau.rafraichir()
			return
		_passthrough = true
		app.monde.visible = false
		app.sol.visible = false
		app.sc.ciel = false
		app.env.background_mode = Environment.BG_COLOR
		app.env.background_color = Color(0, 0, 0, 0)
		app.env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		app.env.ambient_light_color = Color(0.55, 0.55, 0.55)
		app.env.ambient_light_energy = 1.0
	else:
		if XRInterface.XR_ENV_BLEND_MODE_OPAQUE in modes:
			xi.environment_blend_mode = XRInterface.XR_ENV_BLEND_MODE_OPAQUE
		get_viewport().transparent_bg = false
		_passthrough = false
		app.monde.visible = true
		app.set_monde(app.monde.courant)
		app.sc.appliquer_fond(app.env)
		app.sol.visible = app.sol_visible and app.sc.dome_cible < 0.5
	app.sc.appliquer_materiaux()
	app.panneau.rafraichir()
	app.message("Realite mixte" if on else "Monde virtuel")


# ---------------------------------------------------------------- favoris

func _toggle_favori(i: int) -> void:
	var modeles: Array = Generateur.modeles()
	if i < 0 or i >= modeles.size():
		return
	var nom: String = str((modeles[i] as Dictionary)["nom"])
	if _favoris.has(nom):
		_favoris.erase(nom)
	else:
		_favoris.append(nom)
	_sauver_prefs()
	_rafraichir_favoris()


func _rafraichir_favoris() -> void:
	var modeles: Array = Generateur.modeles()
	for i in mini(_favori_boutons.size(), modeles.size()):
		var nom: String = str((modeles[i] as Dictionary)["nom"])
		var fav: bool = _favoris.has(nom)
		var b: Button = _favori_boutons[i]
		b.set_pressed_no_signal(fav)
		b.text = ("★ " if fav else "") + nom


func _lancer_favori() -> void:
	var indices: Array = []
	var modeles: Array = Generateur.modeles()
	for i in modeles.size():
		if _favoris.has(str((modeles[i] as Dictionary)["nom"])):
			indices.append(i)
	if indices.is_empty():
		app.message("Aucun modele favori")
		return
	var k: int = int(indices[app.rng.randi_range(0, indices.size() - 1)])
	app.scene_livree(k)


func _effacer_favoris() -> void:
	_favoris.clear()
	_sauver_prefs()
	_rafraichir_favoris()
	app.message("Favoris effaces")


# ---------------------------------------------------------------- backup complet

func _backup_copier() -> void:
	var oeuvres: Array = []
	var d: DirAccess = DirAccess.open(Stockage.DOSSIER)
	if d != null:
		for nom in d.get_files():
			var f: String = str(nom)
			if f.ends_with(".json"):
				oeuvres.append({"f": f, "c": FileAccess.get_file_as_string(Stockage.DOSSIER + "/" + f)})
	var pack: Dictionary = {
		"type": "mandala_vr_backup",
		"v": 8,
		"date": int(Time.get_unix_time_from_system() * 1000.0),
		"oeuvres": oeuvres,
		"listes": FileAccess.get_file_as_string(Stockage.FICHIER_LISTES) if FileAccess.file_exists(Stockage.FICHIER_LISTES) else "[]",
		"reglages": FileAccess.get_file_as_string(Stockage.FICHIER_PREFS) if FileAccess.file_exists(Stockage.FICHIER_PREFS) else "{}",
		"v8": FileAccess.get_file_as_string(PREFS_V8) if FileAccess.file_exists(PREFS_V8) else "{}",
	}
	DisplayServer.clipboard_set(JSON.stringify(pack))
	app.message("Sauvegarde complete copiee")


func _backup_restaurer() -> void:
	var j: Variant = JSON.parse_string(DisplayServer.clipboard_get())
	if not (j is Dictionary):
		app.message("Presse-papiers : sauvegarde invalide")
		return
	var pack: Dictionary = j
	if str(pack.get("type", "")) != "mandala_vr_backup":
		app.message("Presse-papiers : sauvegarde invalide")
		return
	DirAccess.make_dir_recursive_absolute(Stockage.DOSSIER)
	if pack.get("oeuvres", null) is Array:
		for it in (pack["oeuvres"] as Array):
			if not (it is Dictionary):
				continue
			var nom: String = str((it as Dictionary).get("f", "")).get_file()
			if nom == "" or not nom.ends_with(".json"):
				continue
			_ecrire_texte(Stockage.DOSSIER + "/" + nom, str((it as Dictionary).get("c", "")))
	_ecrire_texte(Stockage.FICHIER_LISTES, str(pack.get("listes", "[]")))
	_ecrire_texte(Stockage.FICHIER_PREFS, str(pack.get("reglages", "{}")))
	_ecrire_texte(PREFS_V8, str(pack.get("v8", "{}")))
	app.message("Sauvegarde restauree - relance l'application")


func _ecrire_texte(chemin: String, contenu: String) -> void:
	var f: FileAccess = FileAccess.open(chemin, FileAccess.WRITE)
	if f != null:
		f.store_string(contenu)
		f.close()
