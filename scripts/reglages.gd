class_name Reglages
extends RefCounted

var genre: int = 0
var branches: int = 12
var miroir: bool = false
var epaisseur: float = 1.4
var opacite: float = 0.85
var palette: int = 0
var mode: int = 1
var symbole: int = 0
var espacement: int = 6
var iterations: int = 4
var reduction: float = 0.62
var torsion: float = 0.35
var reseau: int = 0
var recursion: int = 0
var motif: int = 0
var segments_gen: int = 4


func copie() -> Reglages:
	var r: Reglages = Reglages.new()
	r.genre = genre
	r.branches = branches
	r.miroir = miroir
	r.epaisseur = epaisseur
	r.opacite = opacite
	r.palette = palette
	r.mode = mode
	r.symbole = symbole
	r.espacement = espacement
	r.iterations = iterations
	r.reduction = reduction
	r.torsion = torsion
	r.reseau = reseau
	r.recursion = recursion
	r.motif = motif
	r.segments_gen = segments_gen
	return r


func vers_json() -> Dictionary:
	return {
		"g": genre, "b": branches, "m": miroir, "e": epaisseur, "o": opacite,
		"pa": palette, "mo": mode, "sy": symbole, "es": espacement, "it": iterations,
		"re": reduction, "to": torsion, "rs": reseau, "rc": recursion, "mt": motif,
		"sg": segments_gen,
	}


static func depuis_json(j: Dictionary) -> Reglages:
	var r: Reglages = Reglages.new()
	r.genre = clampi(_ent(j, "g", 0), 0, Tables.GENRES.size() - 1)
	r.branches = clampi(_ent(j, "b", 12), 2, 36)
	r.miroir = j.get("m", false) == true
	# v9 : tout ce qui vient d'un JSON est borne comme dans l'interface.
	r.epaisseur = clampf(_reel(j, "e", 1.4), 0.3, 12.0)
	r.opacite = clampf(_reel(j, "o", 0.85), 0.1, 1.0)
	r.palette = clampi(_ent(j, "pa", 0), 0, Tables.palettes.size() - 1)
	r.mode = clampi(_ent(j, "mo", 1), 0, Tables.NOMS_MODES.size() - 1)
	r.symbole = clampi(_ent(j, "sy", 0), 0, Tables.NOMS_SYMBOLES.size() - 1)
	r.espacement = clampi(_ent(j, "es", 6), 2, 16)
	r.iterations = clampi(_ent(j, "it", 4), 2, 12)
	r.reduction = clampf(_reel(j, "re", 0.62), 0.30, 0.95)
	r.torsion = clampf(_reel(j, "to", 0.35), 0.0, 1.2)
	r.reseau = clampi(_ent(j, "rs", 0), 0, Tables.NOMS_RESEAUX.size() - 1)
	r.recursion = clampi(_ent(j, "rc", 0), 0, 4)
	r.motif = clampi(_ent(j, "mt", 0), 0, Tables.NOMS_MOTIFS.size() - 1)
	r.segments_gen = clampi(_ent(j, "sg", 4), 2, 8)
	return r


static func _ent(j: Dictionary, c: String, d: int) -> int:
	var v: Variant = j.get(c, null)
	if v is float or v is int:
		return int(v)
	return d


static func _reel(j: Dictionary, c: String, d: float) -> float:
	var v: Variant = j.get(c, null)
	if v is float or v is int:
		return float(v)
	return d
