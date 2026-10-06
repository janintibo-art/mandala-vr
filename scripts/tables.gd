class_name Tables
extends RefCounted

const R_METRES: float = 6.0
const H_METRES: float = 5.0

const RELIEFS: Array = ["Plat", "Dôme", "Cône", "Entonnoir", "Vague", "Ondes", "Bol", "Tore", "Marches", "Bulbe"]
const MODES_COULEUR: Array = ["Rayon", "Angle", "Trait", "Longueur", "Rayon et angle", "Unie"]
const N_VALEURS: Array = [6, 8, 10, 12, 16, 24]

const LUM_X: float = -0.4508
const LUM_Y: float = -0.6211
const LUM_Z: float = 0.6411
const LUM_PLAT: float = 0.87439

const GENRES: Array = [
	{"nom": "Rosace", "twist": 0.0, "miroir": false, "ond": 0.0, "copies": [[1.0, 0.0]]},
	{"nom": "Rosace miroir", "twist": 0.0, "miroir": true, "ond": 0.0, "copies": [[1.0, 0.0]]},
	{"nom": "Spirale douce", "twist": 0.7, "miroir": false, "ond": 0.0, "copies": [[1.0, 0.0]]},
	{"nom": "Spirale forte", "twist": 1.6, "miroir": false, "ond": 0.0, "copies": [[1.0, 0.0]]},
	{"nom": "Spirale miroir", "twist": 0.9, "miroir": true, "ond": 0.0, "copies": [[1.0, 0.0]]},
	{"nom": "Fleur", "twist": 0.0, "miroir": true, "ond": 0.06, "copies": [[1.0, 0.0]]},
	{"nom": "Étoile", "twist": 0.0, "miroir": false, "ond": 0.0, "copies": [[1.0, 0.0], [0.5, 0.5]]},
	{"nom": "Double couronne", "twist": 0.0, "miroir": true, "ond": 0.0, "copies": [[1.0, 0.0], [0.55, 0.25]]},
	{"nom": "Triple couronne", "twist": 0.0, "miroir": false, "ond": 0.0, "copies": [[1.0, 0.0], [0.62, 0.33], [0.3, 0.5]]},
	{"nom": "Kaléidoscope", "twist": 0.3, "miroir": true, "ond": 0.0, "copies": [[1.0, 0.0], [0.7, 0.5]]},
	{"nom": "Hélice", "twist": -1.1, "miroir": true, "ond": 0.0, "copies": [[1.0, 0.0]]},
	{"nom": "Vague", "twist": 0.0, "miroir": false, "ond": 0.1, "copies": [[1.0, 0.0]]},
	{"nom": "Pulsar", "twist": 0.4, "miroir": false, "ond": 0.0, "copies": [[0.85, 0.0], [0.6, 0.5], [0.38, 0.0]]},
	{"nom": "Cristal", "twist": 0.0, "miroir": true, "ond": 0.03, "copies": [[1.0, 0.0], [0.5, 0.0]]},
	{"nom": "Tourbillon", "twist": 2.4, "miroir": false, "ond": 0.0, "copies": [[1.0, 0.0]]},
	{"nom": "Ondulation", "twist": 0.5, "miroir": true, "ond": 0.08, "copies": [[1.0, 0.0], [0.5, 0.5]]},
]

static var PALETTES: Array = [
	["Arc-en-ciel", PackedColorArray([Color(1.0000, 0.2314, 0.2314), Color(1.0000, 0.6941, 0.2314), Color(0.9608, 1.0000, 0.2314), Color(0.2314, 1.0000, 0.4157), Color(0.2314, 0.7843, 1.0000), Color(0.4784, 0.2314, 1.0000), Color(1.0000, 0.2314, 0.8157)])],
	["Feu", PackedColorArray([Color(0.1255, 0.0000, 0.0000), Color(0.5412, 0.0588, 0.0000), Color(1.0000, 0.2314, 0.0000), Color(1.0000, 0.6157, 0.0000), Color(1.0000, 0.8902, 0.4157), Color(1.0000, 1.0000, 1.0000)])],
	["Océan", PackedColorArray([Color(0.0000, 0.1020, 0.2000), Color(0.0000, 0.3020, 0.5608), Color(0.0000, 0.5882, 0.8392), Color(0.2314, 0.8784, 1.0000), Color(0.7216, 1.0000, 0.9569), Color(0.0431, 0.2392, 0.5686)])],
	["Forêt", PackedColorArray([Color(0.0235, 0.1686, 0.0706), Color(0.0588, 0.4196, 0.1725), Color(0.2314, 0.7098, 0.2902), Color(0.7137, 0.8902, 0.3529), Color(0.9490, 0.8902, 0.5804), Color(0.1843, 0.4902, 0.4196)])],
	["Néon", PackedColorArray([Color(1.0000, 0.0000, 0.6667), Color(0.0000, 0.9412, 1.0000), Color(0.7137, 1.0000, 0.0000), Color(1.0000, 0.4157, 0.0000), Color(0.5412, 0.0000, 1.0000), Color(0.0000, 1.0000, 0.5216)])],
	["Pastel", PackedColorArray([Color(1.0000, 0.8196, 0.8627), Color(0.7882, 0.9490, 1.0000), Color(0.8471, 1.0000, 0.7882), Color(1.0000, 0.9529, 0.6902), Color(0.8824, 0.7882, 1.0000), Color(1.0000, 0.7882, 0.6588)])],
	["Aurore", PackedColorArray([Color(0.0431, 0.1176, 0.2902), Color(0.0000, 0.7608, 0.6588), Color(0.2980, 1.0000, 0.6039), Color(0.7216, 0.4196, 1.0000), Color(1.0000, 0.4196, 0.8353), Color(0.1647, 0.2941, 0.8392)])],
	["Cuivre", PackedColorArray([Color(0.1647, 0.0588, 0.0196), Color(0.4784, 0.2039, 0.0902), Color(0.7843, 0.4392, 0.1804), Color(0.9412, 0.6588, 0.3765), Color(1.0000, 0.8784, 0.6902), Color(0.5412, 0.3529, 0.2667)])],
	["Glace", PackedColorArray([Color(1.0000, 1.0000, 1.0000), Color(0.7882, 0.9451, 1.0000), Color(0.4980, 0.8157, 1.0000), Color(0.2314, 0.5451, 1.0000), Color(0.1137, 0.2471, 0.7490), Color(0.6588, 1.0000, 0.9647)])],
	["Coucher de soleil", PackedColorArray([Color(0.1647, 0.0392, 0.2902), Color(0.5412, 0.1216, 0.4196), Color(0.9098, 0.2667, 0.3529), Color(1.0000, 0.5412, 0.2314), Color(1.0000, 0.8275, 0.3529), Color(1.0000, 0.3725, 0.5412)])],
	["Vitrail", PackedColorArray([Color(0.8157, 0.1098, 0.1098), Color(0.1098, 0.3098, 0.8157), Color(0.9098, 0.7608, 0.1098), Color(0.1098, 0.6588, 0.3098), Color(0.5412, 0.1098, 0.8157), Color(1.0000, 0.4784, 0.1098), Color(0.1098, 0.7843, 0.8157)])],
	["Matrix", PackedColorArray([Color(0.0000, 0.1020, 0.0235), Color(0.0000, 0.6392, 0.1216), Color(0.0000, 1.0000, 0.2549), Color(0.5529, 1.0000, 0.6039), Color(0.8510, 1.0000, 0.8784)])],
	["Or et nuit", PackedColorArray([Color(0.0196, 0.0275, 0.0588), Color(0.1020, 0.1373, 0.3137), Color(0.7843, 0.6353, 0.2275), Color(1.0000, 0.8863, 0.4784), Color(1.0000, 0.9647, 0.8157), Color(0.2275, 0.1647, 0.4392)])],
	["Violet", PackedColorArray([Color(0.0706, 0.0000, 0.1647), Color(0.2275, 0.0588, 0.4784), Color(0.4784, 0.1843, 0.8784), Color(0.7529, 0.4196, 1.0000), Color(1.0000, 0.7020, 1.0000), Color(0.3529, 0.2471, 0.8392)])],
]


static func relief_z(idx: int, u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	match idx:
		1:
			return sqrt(maxf(0.0, 1.0 - u * u))
		2:
			return maxf(0.0, 1.0 - u)
		3:
			return -u * u
		4:
			return cos(2.2 * PI * u) * (1.0 - 0.45 * u)
		5:
			return 0.8 * sin(3.4 * PI * u)
		6:
			return -sqrt(maxf(0.0, 1.0 - u * u))
		7:
			var w: float = (u - 0.58) / 0.36
			return sqrt(maxf(0.0, 1.0 - w * w))
		8:
			return maxf(0.0, 1.0 - floorf(6.0 * u) / 6.0)
		9:
			return sqrt(maxf(0.0, 1.0 - u * u * u * u))
		_:
			return 0.0


static func pente(idx: int, u: float) -> float:
	if idx == 0:
		return 0.0
	var e: float = 0.01
	var a: float = maxf(u - e, 0.0)
	var b: float = minf(u + e, 1.0)
	if b - a < 0.0001:
		return 0.0
	return (relief_z(idx, b) - relief_z(idx, a)) * H_METRES / ((b - a) * R_METRES)


static func luminosite(g: float, inv: float, cphi: float, sphi: float) -> float:
	var proj: float = cphi * LUM_X + sphi * LUM_Y
	var dot: float = (LUM_Z - g * proj) * inv
	var lum: float = 0.30 + 0.70 * (dot * 0.5 + 0.5)
	return clampf(lum / LUM_PLAT, 0.18, 1.3)


static func echantillon(pal: int, t: float) -> Color:
	var cols: PackedColorArray = PALETTES[pal % PALETTES.size()][1]
	var n: int = cols.size()
	var x: float = fposmod(t, 1.0) * n
	var i: int = int(floor(x)) % n
	var f: float = x - floor(x)
	f = f * f * (3.0 - 2.0 * f)
	return cols[i].lerp(cols[(i + 1) % n], f)
