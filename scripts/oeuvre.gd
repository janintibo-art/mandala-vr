class_name Oeuvre
extends RefCounted
## Codec des creations. Format compatible avec l'application telephone
## (champs v, nom, date, cote, fond, format, mouvement, vitesse, relief, traits)
## plus quelques champs propres a la VR (ignores par le telephone).


static func encoder(nom: String, sc: Scene3D) -> String:
	var liste: Array = []
	var perso: Dictionary = {}
	for t in sc.traits:
		var td: TraitDessin = t
		var sb: PackedStringArray = PackedStringArray()
		for p in td.points:
			sb.append("%.1f" % p.x)
			sb.append("%.1f" % p.y)
		var rj: Dictionary = td.reglages.vers_json()
		var pi: int = td.reglages.palette
		var pal: Dictionary = Tables.palettes[pi % Tables.palettes.size()]
		rj["pn"] = str(pal["nom"])
		if pi >= Tables.PALETTES_BRUTES.size():
			perso[str(pal["nom"])] = _cols_hex(pal["cols"])
		liste.append({"c": td.calque, "r": rj, "p": ",".join(sb)})
	return JSON.stringify({
		"v": 1,
		"nom": nom,
		"date": int(Time.get_unix_time_from_system() * 1000.0),
		"cote": 1000.0,
		"fond": sc.fond,
		"format": 0,
		"mouvement": sc.mouvement,
		"vitesse": sc.vitesse,
		"relief": {"mode": sc.rel_mode, "hauteur": sc.rel_h, "inclinaison": 0.0, "lumiere": sc.rel_lum},
		"traits": liste,
		"vr": {"fx": sc.fx, "lumineux": sc.lumineux, "perso": perso,
			"reduction": sc.reduction_boucle, "torsion": sc.torsion_boucle},
	})


static func _cols_hex(cols: PackedColorArray) -> Array:
	var out: Array = []
	for c in cols:
		out.append(c.to_html(false))
	return out


static func _num(j: Dictionary, k: String, d: float) -> float:
	var v: Variant = j.get(k, null)
	if v is float or v is int:
		return float(v)
	return d


## Renvoie un dictionnaire : nom, fond, mouvement, vitesse, rel_mode, rel_h,
## rel_lum, traits (Array de TraitDessin), fx (ou vide), lumineux, reduction, torsion.
static func decoder(source: String) -> Dictionary:
	var parse: Variant = JSON.parse_string(source)
	if not (parse is Dictionary):
		return {}
	var j: Dictionary = parse
	var cote: float = _num(j, "cote", 1000.0)
	var f: float = 1.0 if cote <= 0.0 else 1000.0 / cote
	var vr: Dictionary = {}
	if j.get("vr", null) is Dictionary:
		vr = j["vr"]
	if vr.get("perso", null) is Dictionary:
		var pers: Dictionary = vr["perso"]
		for nom in pers.keys():
			if Tables.palette_par_nom(str(nom)) == 0 and str(nom) != str(Tables.palettes[0]["nom"]):
				var cols: PackedColorArray = PackedColorArray()
				for h in (pers[nom] as Array):
					cols.append(Color.html(str(h)))
				if cols.size() > 0:
					Tables.ajouter_palette(str(nom), cols)
	var jr: Dictionary = {}
	if j.get("relief", null) is Dictionary:
		jr = j["relief"]
	var traits: Array = []
	var brut: Array = []
	if j.get("traits", null) is Array:
		brut = j["traits"]
	for k in brut.size():
		if not (brut[k] is Dictionary):
			continue
		var jt: Dictionary = brut[k]
		var rj: Dictionary = {}
		if jt.get("r", null) is Dictionary:
			rj = jt["r"]
		var r: Reglages = Reglages.depuis_json(rj)
		if rj.has("pn"):
			r.palette = Tables.palette_par_nom(str(rj["pn"]))
		r.epaisseur = r.epaisseur * f
		var t: TraitDessin = TraitDessin.new(r, k)
		t.calque = clampi(int(_num(jt, "c", 0.0)), 0, 2)
		var ps: String = str(jt.get("p", ""))
		if ps != "":
			var m: PackedStringArray = ps.split(",")
			var i: int = 0
			while i + 1 < m.size():
				t.ajouter(Vector2(float(m[i]) * f, float(m[i + 1]) * f))
				i += 2
		t.fige = true
		if t.points.size() > 1:
			traits.append(t)
	var out: Dictionary = {
		"nom": str(j.get("nom", "Sans titre")),
		"date": int(_num(j, "date", 0.0)),
		"fond": clampi(int(_num(j, "fond", 0.0)), 0, Tables.FONDS.size() - 1),
		"mouvement": clampi(int(_num(j, "mouvement", 0.0)), 0, Tables.NOMS_MOUVEMENTS.size() - 1),
		"vitesse": _num(j, "vitesse", 1.0),
		"rel_mode": clampi(int(_num(jr, "mode", 0.0)), 0, Tables.NOMS_RELIEFS.size() - 1),
		"rel_h": _num(jr, "hauteur", 0.55),
		"rel_lum": _num(jr, "lumiere", 0.6),
		"traits": traits,
		"fx": vr.get("fx", {}) if vr.get("fx", null) is Dictionary else {},
		"lumineux": bool(vr.get("lumineux", true)),
		"reduction": _num(vr, "reduction", 0.62),
		"torsion": _num(vr, "torsion", 0.35),
	}
	return out


## Applique une creation decodee a la scene.
static func appliquer(o: Dictionary, sc: Scene3D) -> void:
	sc.vider()
	sc.fond = int(o["fond"])
	sc.mouvement = int(o["mouvement"])
	sc.vitesse = float(o["vitesse"])
	sc.rel_mode = int(o["rel_mode"])
	sc.rel_h = float(o["rel_h"])
	sc.rel_lum = float(o["rel_lum"])
	sc.reduction_boucle = float(o["reduction"])
	sc.torsion_boucle = float(o["torsion"])
	var fxd: Dictionary = o["fx"]
	if not fxd.is_empty():
		for k in fxd.keys():
			sc.fx[str(k)] = float(fxd[k])
		sc.lumineux = bool(o["lumineux"])
		sc.appliquer_fx()
	sc.installer(o["traits"])
