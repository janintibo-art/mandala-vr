class_name Generateur
extends RefCounted
## Port de generateur.dart et config.dart du telephone : gestes de depart,
## composition de scenes, 13 configurations livrees, tirage au sort.

const BRANCHES_HEUREUSES: Array = [6, 8, 9, 10, 12, 14, 16, 18, 20, 24]
const FONDS_SOMBRES: Array = [0, 1, 2, 4, 5]


static func _pol(r: float, a: float) -> Vector2:
	return Vector2(cos(a) * r, sin(a) * r)


static func _geste(h: RandomNumberGenerator, rayon: float) -> PackedVector2Array:
	var type: int = h.randi_range(0, 5)
	var n: int = 70 + h.randi_range(0, 129)
	var a0: float = h.randf() * TAU
	var pts: PackedVector2Array = PackedVector2Array()
	match type:
		0:
			var r0: float = rayon * (0.10 + h.randf() * 0.28)
			var r1: float = rayon * (0.48 + h.randf() * 0.46)
			var da: float = h.randf() * 1.5 - 0.75
			var amp: float = h.randf() * 0.22
			var k: int = 2 + h.randi_range(0, 4)
			for i in n + 1:
				var u: float = float(i) / float(n)
				pts.append(_pol(r0 + (r1 - r0) * u + rayon * amp * sin(u * PI * float(k)), a0 + da * u))
		1:
			var r0: float = rayon * (0.08 + h.randf() * 0.16)
			var r1: float = rayon * (0.55 + h.randf() * 0.4)
			var large: float = 0.25 + h.randf() * 0.7
			for i in n + 1:
				var u: float = float(i) / float(n)
				pts.append(_pol(r0 + (r1 - r0) * sin(u * PI), a0 + large * (u - 0.5)))
		2:
			var r0: float = rayon * (0.05 + h.randf() * 0.12)
			var r1: float = rayon * (0.6 + h.randf() * 0.38)
			var tours: float = 0.6 + h.randf() * 2.4
			for i in n + 1:
				var u: float = float(i) / float(n)
				pts.append(_pol(r0 + (r1 - r0) * u, a0 + tours * TAU * u))
		3:
			var rc: float = rayon * (0.28 + h.randf() * 0.55)
			var amp: float = rayon * (0.03 + h.randf() * 0.14)
			var k: int = 3 + h.randi_range(0, 7)
			var etendue: float = 0.6 + h.randf() * 2.2
			for i in n + 1:
				var u: float = float(i) / float(n)
				pts.append(_pol(rc + amp * sin(u * PI * float(k)), a0 + etendue * u))
		4:
			var r0: float = rayon * (0.04 + h.randf() * 0.1)
			var r1: float = rayon * (0.7 + h.randf() * 0.3)
			var courbe: float = h.randf() * 0.9 - 0.45
			for i in n + 1:
				var u: float = float(i) / float(n)
				pts.append(_pol(r0 + (r1 - r0) * u, a0 + courbe * u * u))
		_:
			var d: float = rayon * (0.25 + h.randf() * 0.45)
			var rr: float = rayon * (0.1 + h.randf() * 0.25)
			var centre: Vector2 = _pol(d, a0)
			var lobes: int = 2 + h.randi_range(0, 4)
			var deform: float = h.randf() * 0.45
			for i in n + 1:
				var u: float = float(i) / float(n)
				var a: float = u * TAU
				var r: float = rr * (1.0 + deform * sin(a * float(lobes)))
				pts.append(centre + _pol(r, a))
	return pts


static func composer_scene(base: Reglages, rayon: float, h: RandomNumberGenerator) -> Array:
	var nb: int = 2 + h.randi_range(0, 3)
	var traits: Array = []
	var choix: Array = [6, 8, 9, 12, 14, 16, 18, 24]
	for i in nb:
		var r: Reglages = base.copie()
		r.epaisseur = clampf(base.epaisseur * (0.65 + h.randf() * 0.9), 0.3, 12.0)
		r.opacite = clampf(base.opacite * (0.7 + h.randf() * 0.45), 0.15, 1.0)
		if h.randf() < 0.35:
			r.branches = int(choix[h.randi_range(0, 7)])
		if r.reseau != 0:
			r.recursion = 0
		if r.recursion > 4:
			r.recursion = 4
		var t: TraitDessin = TraitDessin.new(r, i)
		for p in _geste(h, rayon):
			t.ajouter(p)
		t.fige = true
		t.calque = 0
		if t.points.size() > 2:
			t.calque = clampi(int(floorf(clampf(t.points[0].length() / rayon, 0.0, 0.999) * 3.0)), 0, 2)
			traits.append(t)
	return traits


# ----------------------------------------------------------- configurations

static func _cfg(nom: String, g: String, pal: String, b: int, e: float, o: float, mode: int, extra: Dictionary = {}) -> Dictionary:
	var r: Reglages = Reglages.new()
	r.genre = Tables.genre_par_nom(g)
	r.palette = Tables.palette_par_nom(pal)
	r.branches = b
	r.epaisseur = e
	r.opacite = o
	r.mode = mode
	r.symbole = Tables.symbole_par_nom(str(extra.get("symbole", "De")))
	r.espacement = int(extra.get("espacement", 6))
	r.iterations = int(extra.get("iterations", 4))
	r.reduction = float(extra.get("reduction", 0.62))
	r.torsion = float(extra.get("torsion", 0.35))
	return {
		"nom": nom, "reglages": r,
		"rel_mode": int(extra.get("rel_mode", 0)),
		"rel_h": float(extra.get("rel_h", 0.55)),
		"rel_lum": float(extra.get("rel_lum", 0.6)),
		"mouvement": int(extra.get("mouvement", 0)),
		"vitesse": float(extra.get("vitesse", 1.0)),
		"fond": int(extra.get("fond", 0)),
		"fx": extra.get("fx", {}),
	}


static func configs_livrees() -> Array:
	return [
		_cfg("Cathedrale", "Cathedrale", "Cathedrale", 12, 2.2, 1.0, 1, {"fx": Presets.fx("Vitrail")}),
		_cfg("Nuit Matrix", "Matrix", "Matrix", 16, 1.1, 0.72, 3, {"espacement": 4, "fond": 1, "fx": Presets.fx("Neon")}),
		_cfg("Dome d'argent", "Toile", "Argent", 14, 1.0, 0.8, 5, {"rel_mode": 1, "rel_h": 0.82, "mouvement": 1, "vitesse": 0.6, "fx": Presets.fx("Cristal")}),
		_cfg("Puits sans fond", "Gigogne", "Encre", 10, 1.6, 0.9, 4, {"iterations": 7, "reduction": 0.68, "torsion": 0.4, "rel_mode": 3, "rel_h": 0.9, "mouvement": 7, "vitesse": 0.7, "fx": Presets.fx("Neon")}),
		_cfg("Givre clair", "Givre", "Lagon", 18, 0.9, 0.85, 1, {"fond": 3, "fx": Presets.fx("Mat")}),
		_cfg("Constellation", "Constellation", "Argent", 20, 0.8, 0.95, 9, {"fond": 1, "fx": Presets.fx("Cristal")}),
		_cfg("Vitrail tournant", "Vitrail", "Cathedrale", 10, 2.0, 1.0, 1, {"rel_mode": 1, "rel_h": 0.6, "mouvement": 6, "vitesse": 0.5, "fx": Presets.fx("Vitrail")}),
		_cfg("Spirale d'or", "Fractale", "Or", 8, 1.3, 0.9, 4, {"iterations": 12, "reduction": 0.93, "torsion": 0.28, "mouvement": 7, "vitesse": 0.8, "fx": Presets.fx("Braise")}),
		_cfg("Dentelle de braise", "Filigrane", "Braise", 12, 1.1, 0.9, 4, {"iterations": 6, "reduction": 0.7, "torsion": 0.5, "fx": Presets.fx("Braise")}),
		_cfg("Circuit imprime", "Circuit", "Jade", 8, 1.4, 1.0, 8, {"fond": 1, "fx": Presets.fx("Neon")}),
		_cfg("Meduse", "Meduse", "Polaire", 9, 1.0, 0.8, 5, {"iterations": 5, "reduction": 0.74, "torsion": 0.22, "rel_mode": 1, "rel_h": 0.7, "mouvement": 4, "vitesse": 0.9, "fx": Presets.fx("Aurore")}),
		_cfg("Chapelet d'etoiles", "Cascade", "Prisme", 12, 1.2, 0.95, 2, {"symbole": "Etoile", "espacement": 5, "iterations": 5, "reduction": 0.66, "torsion": 0.3, "fx": Presets.fx("Arc-en-ciel")}),
		_cfg("Nuit de glace", "Rosace infinie", "Banquise", 14, 1.2, 0.9, 10, {"iterations": 8, "reduction": 0.72, "torsion": 0.3, "fond": 4, "mouvement": 7, "vitesse": 0.6, "fx": Presets.fx("Cristal")}),
		_cfg("Lave vivante", "Nebuleuse", "Lave", 16, 1.8, 0.85, 12, {"rel_mode": 4, "rel_h": 0.7, "fond": 1, "mouvement": 3, "vitesse": 0.5, "fx": Presets.fx("Braise")}),
	]


static func tirage(h: RandomNumberGenerator, nom: String, vizu: bool = false) -> Dictionary:
	var g: int = h.randi_range(0, Tables.GENRES.size() - 1)
	var pa: int = h.randi_range(0, Tables.palettes.size() - 1)
	var avec_relief: bool = h.randf() < 0.45
	var bouge: bool = h.randf() < 0.6
	var cols: PackedColorArray = Tables.palettes[pa]["cols"]
	var claire: bool = cols[0].get_luminance() > 0.58
	var r: Reglages = Reglages.new()
	r.genre = g
	r.palette = pa
	r.reseau = h.randi_range(1, 5) if h.randf() < 0.25 else 0
	r.branches = int(BRANCHES_HEUREUSES[h.randi_range(0, BRANCHES_HEUREUSES.size() - 1)])
	r.miroir = h.randf() < 0.4
	r.epaisseur = 0.6 + h.randf() * 2.4
	r.opacite = 0.55 + h.randf() * 0.45
	r.mode = h.randi_range(0, Tables.NOMS_MODES.size() - 1)
	r.symbole = h.randi_range(0, Tables.NOMS_SYMBOLES.size() - 1)
	r.espacement = 3 + h.randi_range(0, 7)
	r.iterations = 3 + h.randi_range(0, 6)
	r.reduction = 0.55 + h.randf() * 0.35
	r.torsion = h.randf() * 0.7
	var mv: int = 0
	if vizu:
		mv = h.randi_range(1, 8)
	elif bouge:
		mv = h.randi_range(1, 9)
	var noms_fx: Array = Presets.noms()
	return {
		"nom": nom, "reglages": r,
		"rel_mode": h.randi_range(1, Tables.NOMS_RELIEFS.size() - 1) if avec_relief else 0,
		"rel_h": 0.4 + h.randf() * 0.7,
		"rel_lum": 0.6,
		"mouvement": mv,
		"vitesse": 0.4 + h.randf() * (1.1 if vizu else 1.2),
		"fond": 3 if claire else int(FONDS_SOMBRES[h.randi_range(0, FONDS_SOMBRES.size() - 1)]),
		"fx": Presets.fx(str(noms_fx[h.randi_range(0, noms_fx.size() - 1)])),
	}
