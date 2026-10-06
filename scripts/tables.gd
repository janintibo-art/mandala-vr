class_name Tables
extends RefCounted

const R_METRES: float = 6.0
const PX: float = 0.012
const RM: float = 500.0

const SIMPLE: int = 0
const ECHO: int = 1
const SPIRALE: int = 2
const INVERSION: int = 3
const TOILE: int = 4
const ETOILE: int = 5
const RAYONS: int = 6
const PONT: int = 7
const FRACTALE: int = 8
const FRACTALE_DOUBLE: int = 9

const LIGNE: int = 0
const PERLES: int = 1
const HACHURES: int = 2
const RAILS: int = 3
const POUSSIERE: int = 4
const POINTILLE: int = 5
const RUBAN: int = 6
const PLUME: int = 7
const HALO: int = 8
const CRISTAL: int = 9
const BULLES: int = 10
const TUBE: int = 11
const FIBRES: int = 12
const TAMPON: int = 13
const MATRICE: int = 14
const VITRAIL: int = 15
const CIRCUIT: int = 16
const HELICE: int = 17
const GIVRE: int = 18
const CONSTELLATION: int = 19

# nom, disposition, decor, miroir
const GENRES: Array = [
	["Kaleido", 0, 0, false],
	["Miroir", 0, 0, true],
	["Toile", 4, 0, false],
	["Etoile", 5, 0, false],
	["Perles", 0, 1, true],
	["Rosace", 1, 0, true],
	["Spirale", 2, 0, false],
	["Rayons", 6, 0, false],
	["Inversion", 3, 0, true],
	["Ruban", 0, 6, true],
	["Plume", 0, 7, true],
	["Rails", 0, 3, true],
	["Hachures", 0, 2, true],
	["Pont", 7, 0, false],
	["Pointille", 0, 5, true],
	["Poussiere", 0, 4, true],
	["Bulles", 0, 10, true],
	["Noeud", 4, 1, true],
	["Halo", 1, 8, false],
	["Cristal", 5, 9, true],
	["Tube", 0, 11, true],
	["Fibres", 0, 12, true],
	["Tresse", 4, 11, true],
	["Resille", 5, 12, true],
	["Tampons", 0, 13, true],
	["Guirlande", 4, 13, true],
	["Semis", 1, 13, false],
	["Matrix", 0, 14, true],
	["Pluie", 6, 14, false],
	["Vitrail", 0, 15, true],
	["Cathedrale", 4, 15, true],
	["Circuit", 0, 16, true],
	["Helice", 0, 17, true],
	["Givre", 0, 18, true],
	["Constellation", 5, 19, false],
	["Fractale", 8, 0, true],
	["Gigogne", 8, 11, true],
	["Semence", 8, 1, true],
	["Dentelle", 8, 5, true],
	["Cascade", 8, 13, true],
	["Ronces", 8, 18, true],
	["Nebuleuse", 8, 4, false],
	["Rosace infinie", 8, 15, true],
	["Codex", 8, 14, true],
	["Lacis", 9, 0, true],
	["Filigrane", 9, 5, true],
	["Orfevrerie", 9, 11, true],
	["Meduse", 9, 17, false],
]

const NOMS_SYMBOLES: Array = [
	"De", "Smiley", "Etoile", "Coeur", "Fleur", "Losange", "Triangle", "Lune",
	"Spirale", "Flocon", "Oeil", "Croix", "Hexagone", "Pentagone", "Soleil", "Eclair",
	"Goutte", "Feuille", "Papillon", "Note", "Engrenage", "Sablier", "Trefle", "Chevron",
]

const NOMS_FAMILLES: Array = ["Bases", "Tissages", "Matieres", "Symboles", "Fractales", "Themes"]

const FAMILLES_GENRES: Array = [
	["Kaleido", "Miroir", "Perles", "Rosace", "Spirale", "Rayons", "Inversion", "Pointille", "Poussiere", "Bulles", "Hachures", "Rails"],
	["Toile", "Etoile", "Pont", "Noeud", "Resille", "Tresse", "Constellation", "Helice", "Circuit", "Givre"],
	["Tube", "Fibres", "Ruban", "Plume", "Halo", "Cristal", "Vitrail", "Cathedrale"],
	["Tampons", "Guirlande", "Semis"],
	["Fractale", "Gigogne", "Semence", "Dentelle", "Cascade", "Ronces", "Nebuleuse", "Rosace infinie", "Codex", "Lacis", "Filigrane", "Orfevrerie", "Meduse"],
	["Matrix", "Pluie"],
]

const FONDS: Array = [
	Color(0.043, 0.051, 0.071),
	Color(0.0, 0.0, 0.0),
	Color(0.086, 0.075, 0.063),
	Color(0.949, 0.929, 0.894),
	Color(0.027, 0.075, 0.165),
	Color(0.102, 0.051, 0.078),
]
const NOMS_FONDS: Array = ["Nuit", "Noir", "Terre", "Papier", "Marine", "Prune"]

const NOMS_MODES: Array = [
	"Unie", "Par branche", "Par trait", "Progressive", "Degrade", "Anneaux",
	"Spectre", "Vitesse", "Alternance", "Hasard", "Prisme", "Torsade", "Profondeur", "Marbre",
]

const NOMS_MOUVEMENTS: Array = [
	"Aucun", "Rotation", "Inverse", "Tourbillon", "Respiration", "Balancement",
	"Ensemble", "Infini", "Gouffre", "Musique",
]

const NOMS_RESEAUX: Array = ["Radial", "Grille", "Damier", "Triangles", "Hexagones", "Frise"]

const NOMS_RELIEFS: Array = ["Plat", "Dome", "Cone", "Entonnoir", "Vague", "Ondes", "Bol", "Tore", "Marches", "Bulbe"]

const NOMS_MOTIFS: Array = ["Ton trait", "Koch", "Cesaro", "Levy", "Minkowski", "Dragon"]

const MOTIFS_GENERATEURS: Array = [
	[],
	[0, 0, 0.3333, 0, 0.5, -0.2887, 0.6667, 0, 1, 0],
	[0, 0, 0.5, -0.36, 1, 0],
	[0, 0, 0.5, -0.5, 1, 0],
	[0, 0, 0.25, 0, 0.25, -0.25, 0.5, -0.25, 0.5, 0, 0.75, 0, 0.75, 0.25, 1, 0.25, 1, 0],
	[0, 0, 0.5, -0.5, 1, 0],
]
const MOTIFS_ALTERNES: Array = [false, false, false, false, false, true]

const PALETTES_BRUTES: Array = [
	["Argent", ["e8eef6", "b6c2d2", "8a97a8", "ffffff"]],
	["Or", ["f4ce7e", "e0913a", "fff1cb", "b9701f"]],
	["Spectre", ["7f77dd", "378add", "5dcaa5", "ef9f27", "e24b4a", "ed93b1"]],
	["Lagon", ["5dcaa5", "85b7eb", "e1f5ee", "1d9e75"]],
	["Braise", ["f0997b", "d85a30", "fac775", "993c1d"]],
	["Encre", ["85b7eb", "378add", "185fa5", "b5d4f4"]],
	["Neon", ["00e5c0", "ff3d9a", "9b5de5", "ffe566"]],
	["Aurore", ["7df9c4", "4fc3f7", "b388ff", "ff8ac9"]],
	["Sable", ["e8d5b0", "c9a66b", "8c6d3f", "f7edd9"]],
	["Jade", ["43e08a", "0fa36b", "a8f0c4", "1b6b4a"]],
	["Prisme", ["ff4d4d", "ffa23a", "ffe94f", "5ce06b", "3aa7ff", "9b5de5"]],
	["Matrix", ["00ff6a", "00c24e", "0a7a34", "c8ffdc"]],
	["Cathedrale", ["2050d8", "d01b3c", "0e9e5a", "e8a317", "7a2bc4", "15b8c4"]],
	["Crepuscule", ["ff7a3d", "c3468c", "5b3e9b", "23306e", "ffc97a"]],
	["Foret", ["6fa83c", "2f6b34", "a8c46a", "6b4a26"]],
	["Bonbon", ["ffa8d2", "9be7d8", "fff3a0", "c7b4f5"]],
	["Metal", ["d8dee6", "8e9aa8", "e0b44c", "b3714a"]],
	["Corail", ["ff6f61", "2ec4b6", "ffe0b5", "e8503a"]],
	["Polaire", ["cdebff", "7fb6e8", "b7a6e8", "ffffff"]],
	["Cendre", ["6e7b8b", "9fb0c2", "3d4854", "d5dfe9"]],
	["Rubis", ["3a0010", "a8001f", "ff2a4a", "ff8aa0", "ffd0d8"]],
	["Emeraude", ["02261a", "05804f", "14d98a", "8fffc9", "e0fff2"]],
	["Saphir", ["020a3a", "0a2fa8", "2a6bff", "8fb4ff", "dce8ff"]],
	["Amethyste", ["1a0536", "5a1aa8", "9d4dff", "d2a6ff", "f3e6ff"]],
	["Opale", ["f4fbff", "c6f0e6", "c9d8ff", "f2c9ff", "ffe7c9", "bff5ff"]],
	["Topaze", ["3a1d00", "b86a00", "ffb21a", "ffe08a", "fff6d6"]],
	["Turquoise", ["003a40", "00a3a8", "19e6d4", "9ffff0", "e6fffb"]],
	["Grenat", ["2a0006", "7a0014", "c4112f", "ff5a70", "ffb3be"]],
	["Lave", ["0a0000", "6a0800", "ff2a00", "ff8c00", "ffe14d"]],
	["Magma", ["000004", "3b0f70", "8c2981", "de4968", "fe9f6d", "fcfdbf"]],
	["Banquise", ["f5fcff", "bfe6ff", "7fc4ff", "3d8ee8", "1a4fb0"]],
	["Aube", ["1a1038", "6a2d7a", "d9577a", "ff9a6a", "ffd98a", "fff3c9"]],
	["Zenith", ["000814", "001d3d", "003566", "ffc300", "ffd60a"]],
	["Brume", ["dfe6ee", "b7c4d2", "8fa3b8", "6a7f99", "f4f7fa"]],
	["Menthe", ["e6fff4", "a8f5d3", "5de0b0", "1fbf8f", "0a8f6a"]],
	["Framboise", ["2a0020", "8a0a5a", "e0207f", "ff6aa8", "ffc2dc"]],
	["Citron", ["fff9c2", "fff06a", "ffd91a", "c9e82a", "7fc41a"]],
	["Mandarine", ["ff5a00", "ff8a1a", "ffb347", "ffd699", "c43a00"]],
	["Lavande", ["f0e6ff", "d2bfff", "b399f2", "8f70d6", "5a3fa0"]],
	["Orchidee", ["ffe6f7", "ffb3e6", "ff6ad5", "c13aa0", "7a1a66"]],
	["Sakura", ["fff0f5", "ffd1e0", "ffa8c5", "ff7aa8", "d94a7a"]],
	["Abysses", ["000a14", "002a4a", "005a8a", "00a3c4", "7fe8ff"]],
	["Recif", ["ff5a5f", "ffb400", "00c9a7", "2a9df4", "8a4fff", "fff0a8"]],
	["Savane", ["e8c872", "c98a2a", "8a5a1a", "5a3a12", "f2e0a8"]],
	["Desert", ["f4d9a0", "e8b46a", "d0824a", "a8503a", "6a2f2a"]],
	["Automne", ["8a1a0a", "d2491a", "ff8a1a", "ffc233", "7a5a1a"]],
	["Printemps", ["b8f2a0", "7fe08a", "ffd6ec", "ffb3d9", "fff3a0"]],
	["Hiver", ["f2f8ff", "cfe2f5", "9fb8d6", "6a86ad", "3a4f78"]],
	["Ete", ["ffe14d", "ff9a1a", "ff4a4a", "19c2ff", "19e6a0"]],
	["Cyber", ["00fff2", "ff00e6", "fff200", "7a00ff", "00ff6a"]],
	["Synthwave", ["120038", "6a00b8", "ff2bd6", "ff7a3a", "ffd23a", "21e6ff"]],
	["Vaporwave", ["ff71ce", "01cdfe", "05ffa1", "b967ff", "fffb96"]],
	["Laser", ["ff0040", "ff00ff", "00e5ff", "00ff66", "ffee00"]],
	["Plasma", ["0d0887", "6a00a8", "b12a90", "e16462", "fca636", "f0f921"]],
	["Galaxie", ["05001a", "1a0a4a", "4a1a8a", "9a4aff", "ff7ad9", "7ae8ff"]],
	["Nebuleuse2", ["0a0a28", "3a1a6a", "8a2a9a", "e0407a", "ff9a5a", "7ad0ff"]],
	["Supernova", ["fff6e0", "ffd27a", "ff8a3a", "e0382a", "7a1a5a", "2a1a6a"]],
	["Aurore boreale", ["03140f", "0a6a4a", "14e08a", "7affc9", "7a9aff", "c97aff"]],
	["Feu dartifice", ["ff2a4a", "ffd02a", "2aff8a", "2ab4ff", "c92aff", "ffffff"]],
	["Bijou", ["ffd700", "e8e8f2", "ff2a6a", "2a7aff", "19c97a"]],
	["Hologramme", ["ff9ad5", "9affea", "fff29a", "9ab8ff", "e29aff", "ffffff"]],
	["Corail clair", ["ffd6cc", "ffb3a0", "ff8a73", "5fd4c9", "d9fff9"]],
	["Encre rouge", ["1a0000", "5a0a0a", "c41a1a", "ff5a4a", "ffd0c9"]],
	["Orage", ["0a0f1a", "1f2f4a", "3f5f8a", "8ab4e8", "fff2a8"]],
	["Cuivre", ["2a0f05", "7a3417", "c8702e", "f0a860", "ffe0b0"]],
	["Pistache", ["f0ffd6", "c9f28a", "8fd44a", "5a9e1a", "2a5a0a"]],
]

const NB_LIVREES: int = 20

static var palettes: Array = _construire_palettes()
static var nb_perso: int = 0


static func _construire_palettes() -> Array:
	var out: Array = []
	for p in PALETTES_BRUTES:
		var cols: PackedColorArray = PackedColorArray()
		for h in (p[1] as Array):
			cols.append(Color.html(str(h)))
		out.append({"nom": str(p[0]), "cols": cols})
	return out


static func ajouter_palette(nom: String, cols: PackedColorArray) -> int:
	palettes.append({"nom": nom, "cols": cols})
	nb_perso += 1
	return palettes.size() - 1


static func genre_par_nom(n: String) -> int:
	for i in GENRES.size():
		if GENRES[i][0] == n:
			return i
	return 0


static func palette_par_nom(n: String) -> int:
	for i in palettes.size():
		if palettes[i]["nom"] == n:
			return i
	return 0


static func symbole_par_nom(n: String) -> int:
	var i: int = NOMS_SYMBOLES.find(n)
	return 0 if i < 0 else i


static func genres_de_famille(f: int) -> Array:
	var out: Array = []
	for nom in (FAMILLES_GENRES[clampi(f, 0, FAMILLES_GENRES.size() - 1)] as Array):
		out.append(genre_par_nom(str(nom)))
	return out


static func famille_de(genre: int) -> int:
	var nom: String = str(GENRES[clampi(genre, 0, GENRES.size() - 1)][0])
	for f in FAMILLES_GENRES.size():
		if (FAMILLES_GENRES[f] as Array).has(nom):
			return f
	return 0


static func relief_z(mode: int, hauteur: float, d: float, rayon: float) -> float:
	if rayon <= 0.0 or mode == 0:
		return 0.0
	var u: float = clampf(d / rayon, 0.0, 1.6)
	var h: float = hauteur * rayon
	match mode:
		1:
			return h * sqrt(maxf(0.0, 1.0 - u * u))
		2:
			return h * maxf(0.0, 1.0 - u)
		3:
			return -h * u * u
		4:
			return h * cos(u * PI * 2.2) * (1.0 - u * 0.45)
		5:
			return h * 0.8 * sin(u * PI * 3.4)
		6:
			return -h * sqrt(maxf(0.0, 1.0 - u * u))
		7:
			var w: float = (u - 0.58) / 0.36
			return h * sqrt(maxf(0.0, 1.0 - w * w))
		8:
			var p: float = floorf(u * 6.0) / 6.0
			return h * maxf(0.0, 1.0 - p)
		9:
			var q: float = u * u
			return h * sqrt(maxf(0.0, 1.0 - q * q))
	return 0.0


static func gradient(pal: int, t: float) -> Color:
	var cols: PackedColorArray = palettes[pal % palettes.size()]["cols"]
	var n: int = cols.size()
	var x: float = fposmod(t, 1.0) * float(n)
	var i0: int = int(floorf(x)) % n
	return cols[i0].lerp(cols[(i0 + 1) % n], x - floorf(x))
