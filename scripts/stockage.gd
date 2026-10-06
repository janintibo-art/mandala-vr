class_name Stockage
extends RefCounted
## Bibliotheque de creations, listes de diffusion et preferences.
## Dossier utilisateur : user://oeuvres. Creations livrees : res://creations.

const DOSSIER: String = "user://oeuvres"
const LIVREES: String = "res://creations"
const FICHIER_LISTES: String = "user://listes.json"
const FICHIER_PREFS: String = "user://reglages.json"


static func _assurer() -> void:
	DirAccess.make_dir_recursive_absolute(DOSSIER)


## [{id, nom, date, origine}] triees de la plus recente a la plus ancienne.
static func lister() -> Array:
	_assurer()
	var out: Array = []
	for pair in [[DOSSIER, "u:"], [LIVREES, "r:"]]:
		var dossier: String = str(pair[0])
		var pref: String = str(pair[1])
		var d: DirAccess = DirAccess.open(dossier)
		if d == null:
			continue
		for f in d.get_files():
			var nom_f: String = f
			if nom_f.ends_with(".remap"):
				nom_f = nom_f.trim_suffix(".remap")
			if not nom_f.ends_with(".json"):
				continue
			var txt: String = FileAccess.get_file_as_string(dossier + "/" + nom_f)
			var j: Variant = JSON.parse_string(txt)
			if not (j is Dictionary):
				continue
			var jd: Dictionary = j
			out.append({
				"id": pref + nom_f,
				"nom": str(jd.get("nom", "Sans titre")),
				"date": int(jd.get("date", 0)),
				"origine": "mes creations" if pref == "u:" else "livree",
			})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["date"]) > int(b["date"]))
	return out


static func _chemin(id: String) -> String:
	if id.begins_with("r:"):
		return LIVREES + "/" + id.substr(2)
	return DOSSIER + "/" + id.substr(2)


static func lire(id: String) -> String:
	return FileAccess.get_file_as_string(_chemin(id))


static func ecrire(contenu: String) -> String:
	_assurer()
	var nom: String = "%d.json" % int(Time.get_unix_time_from_system() * 1000.0)
	var f: FileAccess = FileAccess.open(DOSSIER + "/" + nom, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(contenu)
	f.close()
	return "u:" + nom


static func supprimer(id: String) -> void:
	if id.begins_with("u:"):
		DirAccess.remove_absolute(_chemin(id))


static func nom_de(id: String) -> String:
	var j: Variant = JSON.parse_string(lire(id))
	if j is Dictionary:
		return str((j as Dictionary).get("nom", "?"))
	return "?"


# ------------------------------------------------------ listes de diffusion
## liste = {n: nom, t: transition, o: [{c: id, d: duree, m: mouvement}]}

static func listes() -> Array:
	if not FileAccess.file_exists(FICHIER_LISTES):
		return []
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER_LISTES))
	if j is Array:
		return j
	return []


static func sauver_listes(l: Array) -> void:
	var f: FileAccess = FileAccess.open(FICHIER_LISTES, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(l))
		f.close()


# --------------------------------------------------------------- preferences

static func prefs() -> Dictionary:
	if not FileAccess.file_exists(FICHIER_PREFS):
		return {}
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(FICHIER_PREFS))
	if j is Dictionary:
		return j
	return {}


static func sauver_prefs(p: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(FICHIER_PREFS, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(p))
		f.close()
