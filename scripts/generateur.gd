class_name Generateur
extends RefCounted

const CONFIGS: Array = [
	{"nom": "Fleur de cristal", "genre": 13, "palette": 8, "relief": 1, "mode": 0, "n": 12, "fam": [1, 3, 5]},
	{"nom": "Tourbillon océan", "genre": 14, "palette": 2, "relief": 6, "mode": 1, "n": 10, "fam": [0, 2]},
	{"nom": "Pulsar néon", "genre": 12, "palette": 4, "relief": 9, "mode": 3, "n": 8, "fam": [1, 2, 4]},
	{"nom": "Entonnoir doré", "genre": 7, "palette": 12, "relief": 3, "mode": 0, "n": 12, "fam": [0, 1]},
	{"nom": "Dôme de verre", "genre": 9, "palette": 10, "relief": 1, "mode": 2, "n": 12, "fam": [3, 5, 1]},
	{"nom": "Vague aurore", "genre": 15, "palette": 6, "relief": 4, "mode": 4, "n": 16, "fam": [4, 0, 3]},
	{"nom": "Cône de feu", "genre": 3, "palette": 1, "relief": 2, "mode": 0, "n": 8, "fam": [0, 1]},
	{"nom": "Tore arc-en-ciel", "genre": 8, "palette": 0, "relief": 7, "mode": 3, "n": 12, "fam": [2, 3]},
	{"nom": "Marches vitrail", "genre": 6, "palette": 10, "relief": 8, "mode": 2, "n": 10, "fam": [5, 1, 4]},
	{"nom": "Bulbe forêt", "genre": 5, "palette": 3, "relief": 9, "mode": 1, "n": 12, "fam": [3, 1]},
	{"nom": "Bol Matrix", "genre": 4, "palette": 11, "relief": 6, "mode": 0, "n": 10, "fam": [0, 5]},
	{"nom": "Ondes glace", "genre": 2, "palette": 8, "relief": 5, "mode": 4, "n": 12, "fam": [2, 0, 3]},
]


static func nouvelle_scene(rng: RandomNumberGenerator, cfg: int) -> Dictionary:
	var idx: int = cfg
	if idx < 0 or idx >= CONFIGS.size():
		idx = rng.randi_range(0, CONFIGS.size() - 1)
	var c: Dictionary = CONFIGS[idx]
	var fam: Array = c["fam"]
	var nb: int = rng.randi_range(3, 6)
	var traits: Array = []
	for k in nb:
		var f: int = int(fam[rng.randi_range(0, fam.size() - 1)])
		traits.append(_trait(rng, f))
	return {
		"nom": c["nom"],
		"genre": c["genre"],
		"palette": c["palette"],
		"relief": c["relief"],
		"mode": c["mode"],
		"n": c["n"],
		"traits": traits,
	}


static func _trait(rng: RandomNumberGenerator, f: int) -> PackedVector2Array:
	var pts: PackedVector2Array
	match f:
		0:
			pts = _spirale(rng)
		1:
			pts = _rose(rng)
		2:
			pts = _spiro(rng)
		3:
			pts = _petales(rng)
		4:
			pts = _zigzag(rng)
		_:
			pts = _etoile(rng)
	return _densifier(pts, 0.03)


static func _pgcd(a: int, b: int) -> int:
	while b != 0:
		var t: int = a % b
		a = b
		b = t
	return a


static func _densifier(pts: PackedVector2Array, pas_max: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	if pts.is_empty():
		return out
	out.append(pts[0])
	for k in range(1, pts.size()):
		var a: Vector2 = pts[k - 1]
		var b: Vector2 = pts[k]
		var l: float = a.distance_to(b)
		var nb: int = maxi(1, int(ceil(l / pas_max)))
		for j in range(1, nb + 1):
			out.append(a.lerp(b, float(j) / float(nb)))
	return out


static func _tourner(pts: PackedVector2Array, ang: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for p in pts:
		out.append(p.rotated(ang))
	return out


static func _spirale(rng: RandomNumberGenerator) -> PackedVector2Array:
	var tours: float = rng.randf_range(1.5, 4.0)
	var sens: float = 1.0 if rng.randf() < 0.5 else -1.0
	var pts: PackedVector2Array = PackedVector2Array()
	var nb: int = 160
	for k in nb + 1:
		var t: float = float(k) / float(nb)
		var r: float = 0.04 + 0.92 * pow(t, 0.85)
		pts.append(Vector2(r, 0.0).rotated(sens * TAU * tours * t))
	return _tourner(pts, rng.randf_range(0.0, TAU))


static func _rose(rng: RandomNumberGenerator) -> PackedVector2Array:
	var choix: Array = [[3, 1], [5, 1], [5, 2], [7, 3], [4, 3], [7, 2]]
	var ch: Array = choix[rng.randi_range(0, choix.size() - 1)]
	var k: float = float(ch[0]) / float(ch[1])
	var tmax: float = TAU * float(ch[1])
	var pts: PackedVector2Array = PackedVector2Array()
	var nb: int = 420
	for j in nb + 1:
		var th: float = tmax * float(j) / float(nb)
		var r: float = 0.92 * cos(k * th)
		pts.append(Vector2(r * cos(th), r * sin(th)))
	return _tourner(pts, rng.randf_range(0.0, TAU))


static func _spiro(rng: RandomNumberGenerator) -> PackedVector2Array:
	var choix: Array = [[5, 2], [7, 3], [8, 3], [5, 3], [7, 2], [9, 4]]
	var ch: Array = choix[rng.randi_range(0, choix.size() - 1)]
	var gr: float = float(ch[0])
	var pr: float = float(ch[1])
	var d: float = pr * rng.randf_range(0.7, 1.3)
	var g: int = _pgcd(int(ch[0]), int(ch[1]))
	var tmax: float = TAU * pr / float(g)
	var pts: PackedVector2Array = PackedVector2Array()
	var nb: int = 460
	var rmax: float = 0.0001
	for j in nb + 1:
		var t: float = tmax * float(j) / float(nb)
		var x: float = (gr - pr) * cos(t) + d * cos((gr - pr) / pr * t)
		var y: float = (gr - pr) * sin(t) - d * sin((gr - pr) / pr * t)
		var v: Vector2 = Vector2(x, y)
		rmax = maxf(rmax, v.length())
		pts.append(v)
	for j in pts.size():
		pts[j] = pts[j] * (0.93 / rmax)
	return _tourner(pts, rng.randf_range(0.0, TAU))


static func _petales(rng: RandomNumberGenerator) -> PackedVector2Array:
	var k: int = rng.randi_range(3, 9)
	var pts: PackedVector2Array = PackedVector2Array()
	var nb: int = 320
	for j in nb + 1:
		var th: float = TAU * float(j) / float(nb)
		var r: float = 0.12 + 0.8 * (0.5 + 0.5 * cos(float(k) * th))
		pts.append(Vector2(r * cos(th), r * sin(th)))
	return _tourner(pts, rng.randf_range(0.0, TAU))


static func _zigzag(rng: RandomNumberGenerator) -> PackedVector2Array:
	var amp: float = rng.randf_range(0.08, 0.22)
	var f: float = float(rng.randi_range(3, 9))
	var pts: PackedVector2Array = PackedVector2Array()
	var nb: int = 170
	for j in nb + 1:
		var t: float = 0.04 + 0.9 * float(j) / float(nb)
		pts.append(Vector2(t, amp * sin(f * TAU * t) * (0.4 + t)))
	return _tourner(pts, rng.randf_range(0.0, TAU))


static func _etoile(rng: RandomNumberGenerator) -> PackedVector2Array:
	var ks: Array = [5, 7, 9, 11]
	var k: int = int(ks[rng.randi_range(0, ks.size() - 1)])
	var j: int = rng.randi_range(2, (k - 1) / 2)
	while _pgcd(k, j) != 1:
		j += 1
	var pts: PackedVector2Array = PackedVector2Array()
	for i in k + 1:
		var a: float = float(i * j) * TAU / float(k)
		pts.append(Vector2(0.9, 0.0).rotated(a))
	return _tourner(pts, rng.randf_range(0.0, TAU))
