class_name Presets
extends RefCounted
## Ambiances lumineuses : gain, halo, coeur blanc, scintillement, pulsation, arc-en-ciel.

const LISTE: Array = [
	["Neon", 0.80, 0.90, 0.60, 0.0, 0.0, 0.0],
	["Braise", 0.65, 0.70, 0.55, 0.35, 0.25, 0.0],
	["Cristal", 0.60, 0.50, 0.80, 0.70, 0.0, 0.0],
	["Aurore", 0.60, 1.00, 0.30, 0.0, 0.35, 0.25],
	["Pulsar", 0.70, 0.80, 0.50, 0.0, 0.90, 0.0],
	["Arc-en-ciel", 0.60, 0.60, 0.40, 0.0, 0.0, 1.00],
	["Vitrail", 0.55, 0.10, 0.10, 0.0, 0.0, 0.0],
	["Doux", 0.45, 1.20, 0.20, 0.0, 0.0, 0.0],
	["Etincelles", 0.75, 0.40, 0.90, 1.00, 0.30, 0.0],
	["Mat", 0.55, 0.0, 0.0, 0.0, 0.0, 0.0],
]


static func noms() -> Array:
	var out: Array = []
	for p in LISTE:
		out.append(str((p as Array)[0]))
	return out


static func fx(nom: String) -> Dictionary:
	for p in LISTE:
		var a: Array = p
		if str(a[0]) == nom:
			return {"gain": a[1], "halo": a[2], "coeur": a[3], "scint": a[4], "pulse": a[5], "arc": a[6], "vit": 1.0}
	return {"gain": 0.55, "halo": 0.5, "coeur": 0.4, "scint": 0.0, "pulse": 0.0, "arc": 0.0, "vit": 1.0}
