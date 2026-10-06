class_name Peintre
extends RefCounted

const PX: float = Tables.PX

var rm: float = 500.0
var demi_h: float = 500.0
var rel_mode: int = 0
var rel_h: float = 0.55
var rel_lum: float = 0.6

var rv: PackedVector3Array = PackedVector3Array()
var rn: PackedVector3Array = PackedVector3Array()
var ruv: PackedVector2Array = PackedVector2Array()
var rc: PackedColorArray = PackedColorArray()
var ri: PackedInt32Array = PackedInt32Array()

var dv: PackedVector3Array = PackedVector3Array()
var duv: PackedVector2Array = PackedVector2Array()
var duv2: PackedVector2Array = PackedVector2Array()
var dc: PackedColorArray = PackedColorArray()
var di: PackedInt32Array = PackedInt32Array()

var lc: Color = Color.WHITE
var lw: float = 1.0
var pc: Color = Color.WHITE

var prof: float = 1.0
var lum: float = 1.0
var ep_loc: float = 1.0

var _t: Transform2D = Transform2D.IDENTITY
var _pile: Array = []
var _sym_z: float = 0.0
var aire: float = 0.0


func vider_sortie() -> void:
	aire = 0.0
	rv = PackedVector3Array()
	rn = PackedVector3Array()
	ruv = PackedVector2Array()
	rc = PackedColorArray()
	ri = PackedInt32Array()
	dv = PackedVector3Array()
	duv = PackedVector2Array()
	duv2 = PackedVector2Array()
	dc = PackedColorArray()
	di = PackedInt32Array()


func sortie() -> Dictionary:
	return {
		"rv": rv, "rn": rn, "ruv": ruv, "rc": rc, "ri": ri,
		"dv": dv, "duv": duv, "duv2": duv2, "dc": dc, "di": di, "aire": aire,
	}


static func fusionner(dst: Dictionary, src: Dictionary) -> void:
	dst["aire"] = float(dst.get("aire", 0.0)) + float(src.get("aire", 0.0))
	var drv: PackedVector3Array = dst["rv"]
	var decal: int = drv.size()
	drv.append_array(src["rv"])
	var drn: PackedVector3Array = dst["rn"]
	drn.append_array(src["rn"])
	var druv: PackedVector2Array = dst["ruv"]
	druv.append_array(src["ruv"])
	var drc: PackedColorArray = dst["rc"]
	drc.append_array(src["rc"])
	var si: PackedInt32Array = src["ri"]
	var dri: PackedInt32Array = dst["ri"]
	for k in si.size():
		dri.append(si[k] + decal)
	var ddv: PackedVector3Array = dst["dv"]
	var decal2: int = ddv.size()
	ddv.append_array(src["dv"])
	var dduv: PackedVector2Array = dst["duv"]
	dduv.append_array(src["duv"])
	var dduv2: PackedVector2Array = dst["duv2"]
	dduv2.append_array(src["duv2"])
	var ddc: PackedColorArray = dst["dc"]
	ddc.append_array(src["dc"])
	var sd: PackedInt32Array = src["di"]
	var ddi: PackedInt32Array = dst["di"]
	for k in sd.size():
		ddi.append(sd[k] + decal2)


static func sortie_vide() -> Dictionary:
	return {
		"rv": PackedVector3Array(), "rn": PackedVector3Array(), "ruv": PackedVector2Array(),
		"rc": PackedColorArray(), "ri": PackedInt32Array(),
		"dv": PackedVector3Array(), "duv": PackedVector2Array(), "duv2": PackedVector2Array(),
		"dc": PackedColorArray(), "di": PackedInt32Array(), "aire": 0.0,
	}


static func nb_prims(s: Dictionary) -> int:
	return (s["ri"] as PackedInt32Array).size() / 6 + (s["di"] as PackedInt32Array).size() / 6


# ------------------------------------------------------------ primitives

func _w(p: Vector3) -> Vector3:
	return Vector3(p.x * PX, -p.y * PX, p.z * PX)


func g_ligne(a: Vector3, b: Vector3) -> void:
	var wa: Vector3 = _w(a)
	var wb: Vector3 = _w(b)
	var d: Vector3 = wb - wa
	var l: float = d.length()
	if l < 0.000001:
		return
	d /= l
	var hw: float = maxf(lw * 0.5 * PX, 0.004)
	aire += l * hw * 2.0 * lc.a
	var k: int = rv.size()
	rv.append(wa)
	rv.append(wa)
	rv.append(wb)
	rv.append(wb)
	rn.append(d)
	rn.append(d)
	rn.append(d)
	rn.append(d)
	ruv.append(Vector2(-1.0, hw))
	ruv.append(Vector2(1.0, hw))
	ruv.append(Vector2(-1.0, hw))
	ruv.append(Vector2(1.0, hw))
	rc.append(lc)
	rc.append(lc)
	rc.append(lc)
	rc.append(lc)
	ri.append(k)
	ri.append(k + 1)
	ri.append(k + 2)
	ri.append(k + 2)
	ri.append(k + 1)
	ri.append(k + 3)


func g_disque(c: Vector3, r_px: float, col: Color) -> void:
	var wc: Vector3 = _w(c)
	var s: float = maxf(r_px * PX, 0.004)
	aire += PI * s * s * col.a
	var k: int = dv.size()
	for i in 4:
		dv.append(wc)
		duv2.append(Vector2(s, 0.0))
		dc.append(col)
	duv.append(Vector2(-1.0, -1.0))
	duv.append(Vector2(1.0, -1.0))
	duv.append(Vector2(-1.0, 1.0))
	duv.append(Vector2(1.0, 1.0))
	di.append(k)
	di.append(k + 1)
	di.append(k + 2)
	di.append(k + 2)
	di.append(k + 1)
	di.append(k + 3)


func g_cercle(c: Vector3, r_px: float, plein: bool) -> void:
	if plein:
		g_disque(c, r_px, pc)
		return
	var n: int = clampi(int(8.0 + r_px * 0.9), 10, 28)
	var prec: Vector3 = Vector3(c.x + r_px, c.y, c.z)
	for i in range(1, n + 1):
		var a: float = float(i) * TAU / float(n)
		var p: Vector3 = Vector3(c.x + cos(a) * r_px, c.y + sin(a) * r_px, c.z)
		g_ligne(prec, p)
		prec = p


# ------------------------------------------------------- pile de transformation

func _sauver() -> void:
	_pile.append(_t)


func _restaurer() -> void:
	if not _pile.is_empty():
		_t = _pile.pop_back()


func _translater(x: float, y: float) -> void:
	_t = _t.translated_local(Vector2(x, y))


func _tourner(a: float) -> void:
	_t = _t.rotated_local(a)


func _sp(p: Vector2) -> Vector3:
	var q: Vector2 = _t * p
	return Vector3(q.x, q.y, _sym_z)


func _sligne(a: Vector2, b: Vector2) -> void:
	g_ligne(_sp(a), _sp(b))


func _spoly(pts: Array, ferme: bool) -> void:
	for i in range(1, pts.size()):
		g_ligne(_sp(pts[i - 1]), _sp(pts[i]))
	if ferme and pts.size() > 2:
		g_ligne(_sp(pts[pts.size() - 1]), _sp(pts[0]))


func _scercle(c: Vector2, r: float, plein: bool) -> void:
	if plein:
		g_disque(_sp(c), r, pc)
		return
	var n: int = clampi(int(8.0 + r * 0.9), 10, 24)
	var prec: Vector2 = c + Vector2(r, 0.0)
	for i in range(1, n + 1):
		var a: float = float(i) * TAU / float(n)
		var p: Vector2 = c + Vector2(cos(a) * r, sin(a) * r)
		g_ligne(_sp(prec), _sp(p))
		prec = p


func _sovale(c: Vector2, w: float, h: float) -> void:
	var n: int = 16
	var prec: Vector2 = c + Vector2(w * 0.5, 0.0)
	for i in range(1, n + 1):
		var a: float = float(i) * TAU / float(n)
		var p: Vector2 = c + Vector2(cos(a) * w * 0.5, sin(a) * h * 0.5)
		g_ligne(_sp(prec), _sp(p))
		prec = p


func _sarc(c: Vector2, rx: float, ry: float, debut: float, etendue: float) -> void:
	var n: int = 14
	var prec: Vector2 = c + Vector2(cos(debut) * rx, sin(debut) * ry)
	for i in range(1, n + 1):
		var a: float = debut + etendue * float(i) / float(n)
		var p: Vector2 = c + Vector2(cos(a) * rx, sin(a) * ry)
		g_ligne(_sp(prec), _sp(p))
		prec = p


func _bez2(p0: Vector2, p1: Vector2, p2: Vector2) -> Array:
	var out: Array = []
	for i in range(1, 9):
		var t: float = float(i) / 8.0
		var u: float = 1.0 - t
		out.append(p0 * (u * u) + p1 * (2.0 * u * t) + p2 * (t * t))
	return out


func _bez3(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> Array:
	var out: Array = []
	for i in range(1, 11):
		var t: float = float(i) / 10.0
		var u: float = 1.0 - t
		out.append(p0 * (u * u * u) + p1 * (3.0 * u * u * t) + p2 * (3.0 * u * t * t) + p3 * (t * t * t))
	return out


func _polygone(cotes: int, r: float, phase: float) -> Array:
	var out: Array = []
	for i in cotes:
		var a: float = phase + float(i) * TAU / float(cotes)
		out.append(Vector2(cos(a) * r, sin(a) * r))
	return out


func _etoile_pts(branches: int, externe: float, interne: float) -> Array:
	var out: Array = []
	for i in branches * 2:
		var a: float = -PI / 2.0 + float(i) * PI / float(branches)
		var d: float = externe if i % 2 == 0 else interne
		out.append(Vector2(cos(a) * d, sin(a) * d))
	return out


const SEPT_SEGMENTS: Array = [0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F]


func chiffre(valeur: int, p: Vector3, angle: float, u: float) -> void:
	var masque: int = int(SEPT_SEGMENTS[valeur % 10])
	var w: float = u * 0.56
	_t = Transform2D.IDENTITY.translated(Vector2(p.x, p.y))
	_t = _t.rotated_local(angle)
	_sym_z = p.z
	if masque & 0x01 != 0:
		_sligne(Vector2(-w, -u), Vector2(w, -u))
	if masque & 0x02 != 0:
		_sligne(Vector2(w, -u), Vector2(w, 0.0))
	if masque & 0x04 != 0:
		_sligne(Vector2(w, 0.0), Vector2(w, u))
	if masque & 0x08 != 0:
		_sligne(Vector2(-w, u), Vector2(w, u))
	if masque & 0x10 != 0:
		_sligne(Vector2(-w, 0.0), Vector2(-w, u))
	if masque & 0x20 != 0:
		_sligne(Vector2(-w, -u), Vector2(-w, 0.0))
	if masque & 0x40 != 0:
		_sligne(Vector2(-w, 0.0), Vector2(w, 0.0))


func symbole(type: int, p: Vector3, angle: float, u: float) -> void:
	_t = Transform2D.IDENTITY.translated(Vector2(p.x, p.y))
	_t = _t.rotated_local(angle)
	_pile.clear()
	_sym_z = p.z
	match type % 24:
		0:
			var r0: float = u * 0.28
			var pts: Array = []
			var coins: Array = [Vector2(u - r0, -u + r0), Vector2(u - r0, u - r0), Vector2(-u + r0, u - r0), Vector2(-u + r0, -u + r0)]
			var debuts: Array = [-PI / 2.0, 0.0, PI / 2.0, PI]
			for k in 4:
				for j in 5:
					var a: float = float(debuts[k]) + (PI / 2.0) * float(j) / 4.0
					pts.append((coins[k] as Vector2) + Vector2(cos(a) * r0, sin(a) * r0))
			_spoly(pts, true)
			var d0: float = u * 0.44
			for o in [Vector2(-d0, -d0), Vector2(d0, -d0), Vector2(-d0, d0), Vector2(d0, d0), Vector2.ZERO]:
				_scercle(o, u * 0.15, true)
		1:
			_scercle(Vector2.ZERO, u, false)
			_scercle(Vector2(-u * 0.36, -u * 0.28), u * 0.13, true)
			_scercle(Vector2(u * 0.36, -u * 0.28), u * 0.13, true)
			_sarc(Vector2(0.0, u * 0.06), u * 0.56, u * 0.51, 0.38, 2.38)
		2:
			_spoly(_etoile_pts(5, u, u * 0.42), true)
		3:
			var pts3: Array = [Vector2(0.0, u * 0.92)]
			pts3.append_array(_bez3(Vector2(0.0, u * 0.92), Vector2(-u * 1.45, -u * 0.12), Vector2(-u * 0.55, -u * 1.12), Vector2(0.0, -u * 0.34)))
			pts3.append_array(_bez3(Vector2(0.0, -u * 0.34), Vector2(u * 0.55, -u * 1.12), Vector2(u * 1.45, -u * 0.12), Vector2(0.0, u * 0.92)))
			_spoly(pts3, true)
		4:
			for k in 6:
				_sauver()
				_tourner(float(k) * PI / 3.0)
				_sovale(Vector2(0.0, -u * 0.55), u * 0.52, u * 0.92)
				_restaurer()
		5:
			_spoly([Vector2(0.0, -u), Vector2(u * 0.68, 0.0), Vector2(0.0, u), Vector2(-u * 0.68, 0.0)], true)
		6:
			_spoly([Vector2(0.0, -u), Vector2(u * 0.88, u * 0.72), Vector2(-u * 0.88, u * 0.72)], true)
		7:
			_sarc(Vector2.ZERO, u, u, PI * 0.34, PI * 1.32)
			_sarc(Vector2(-u * 0.46, 0.0), u * 0.98, u * 0.98, PI * 0.42, PI * 1.16)
		8:
			var pts8: Array = [Vector2.ZERO]
			for i in range(1, 45):
				var a8: float = float(i) * 0.42
				var d8: float = u * float(i) / 44.0
				pts8.append(Vector2(cos(a8) * d8, sin(a8) * d8))
			_spoly(pts8, false)
		9:
			for k in 6:
				_sauver()
				_tourner(float(k) * PI / 3.0)
				_sligne(Vector2.ZERO, Vector2(0.0, -u))
				_sligne(Vector2(0.0, -u * 0.58), Vector2(-u * 0.3, -u * 0.86))
				_sligne(Vector2(0.0, -u * 0.58), Vector2(u * 0.3, -u * 0.86))
				_restaurer()
		10:
			var pts10: Array = [Vector2(-u, 0.0)]
			pts10.append_array(_bez2(Vector2(-u, 0.0), Vector2(0.0, -u * 0.86), Vector2(u, 0.0)))
			pts10.append_array(_bez2(Vector2(u, 0.0), Vector2(0.0, u * 0.86), Vector2(-u, 0.0)))
			_spoly(pts10, true)
			_scercle(Vector2.ZERO, u * 0.3, true)
		11:
			_sligne(Vector2(-u * 0.75, -u * 0.75), Vector2(u * 0.75, u * 0.75))
			_sligne(Vector2(u * 0.75, -u * 0.75), Vector2(-u * 0.75, u * 0.75))
		12:
			_spoly(_polygone(6, u, -PI / 2.0), true)
		13:
			_spoly(_polygone(5, u, -PI / 2.0), true)
		14:
			_scercle(Vector2.ZERO, u * 0.46, false)
			for k in 8:
				var a14: float = float(k) * PI / 4.0
				_sligne(Vector2(cos(a14) * u * 0.66, sin(a14) * u * 0.66), Vector2(cos(a14) * u, sin(a14) * u))
		15:
			_spoly([Vector2(u * 0.25, -u), Vector2(-u * 0.55, u * 0.08), Vector2(-u * 0.05, u * 0.08), Vector2(-u * 0.3, u), Vector2(u * 0.6, -u * 0.16), Vector2(u * 0.08, -u * 0.16)], true)
		16:
			var pts16: Array = [Vector2(0.0, -u)]
			pts16.append_array(_bez2(Vector2(0.0, -u), Vector2(u * 0.78, u * 0.16), Vector2(0.0, u)))
			pts16.append_array(_bez2(Vector2(0.0, u), Vector2(-u * 0.78, u * 0.16), Vector2(0.0, -u)))
			_spoly(pts16, true)
		17:
			var pts17: Array = [Vector2(0.0, -u)]
			pts17.append_array(_bez2(Vector2(0.0, -u), Vector2(u * 0.9, 0.0), Vector2(0.0, u)))
			pts17.append_array(_bez2(Vector2(0.0, u), Vector2(-u * 0.9, 0.0), Vector2(0.0, -u)))
			_spoly(pts17, true)
			_sligne(Vector2(0.0, -u * 0.8), Vector2(0.0, u * 0.8))
		18:
			for k in 4:
				var sx: float = -1.0 if k < 2 else 1.0
				var sy: float = -1.0 if k % 2 == 0 else 1.0
				_sauver()
				_translater(sx * u * 0.42, sy * u * 0.38)
				_tourner(sx * sy * 0.5)
				_sovale(Vector2.ZERO, u * 0.82, u * 0.62)
				_restaurer()
		19:
			_sovale(Vector2(-u * 0.3, u * 0.62), u * 0.72, u * 0.5)
			_sligne(Vector2(u * 0.06, u * 0.6), Vector2(u * 0.06, -u * 0.9))
			_sligne(Vector2(u * 0.06, -u * 0.9), Vector2(u * 0.7, -u * 0.6))
		20:
			_scercle(Vector2.ZERO, u * 0.6, false)
			_scercle(Vector2.ZERO, u * 0.24, false)
			for k in 8:
				var a20: float = float(k) * PI / 4.0
				_sligne(Vector2(cos(a20) * u * 0.58, sin(a20) * u * 0.58), Vector2(cos(a20) * u, sin(a20) * u))
		21:
			_spoly([Vector2(-u * 0.7, -u), Vector2(u * 0.7, -u), Vector2(0.0, 0.0)], true)
			_spoly([Vector2(-u * 0.7, u), Vector2(u * 0.7, u), Vector2(0.0, 0.0)], true)
		22:
			for k in 3:
				var a22: float = -PI / 2.0 + float(k) * TAU / 3.0
				_scercle(Vector2(cos(a22) * u * 0.44, sin(a22) * u * 0.44), u * 0.42, false)
			_sligne(Vector2(0.0, u * 0.3), Vector2(u * 0.2, u))
		_:
			_spoly([Vector2(-u * 0.8, -u * 0.5), Vector2(0.0, u * 0.16), Vector2(u * 0.8, -u * 0.5)], false)
			_spoly([Vector2(-u * 0.8, u * 0.2), Vector2(0.0, u * 0.86), Vector2(u * 0.8, u * 0.2)], false)


# ------------------------------------------------------------------ optique

static func bruit(graine: int) -> float:
	var x: int = graine * 1103515245 + 12345
	x = (x ^ (x >> 13)) & 0x7FFFFFFF
	return float(x % 2000) / 1000.0 - 1.0


func couleur(r: Reglages, secteur: int, rang: int, index: int, b: Vector2, ang: float, v: float) -> Color:
	var cols: PackedColorArray = Tables.palettes[r.palette % Tables.palettes.size()]["cols"]
	var n: int = cols.size()
	match r.mode:
		0:
			return cols[0]
		1:
			return cols[secteur % n]
		2:
			return cols[rang % n]
		3:
			return cols[(index / 10) % n]
		4:
			var t: float = float(index % 140) / 140.0 * float(n)
			var i0: int = int(floorf(t)) % n
			return cols[i0].lerp(cols[(i0 + 1) % n], t - floorf(t))
		5:
			var u: float = b.length() / rm
			return cols[absi(int(floorf(u * float(n) * 2.4))) % n]
		6:
			var h: float = fposmod((ang / TAU) * 360.0 + float(index) * 0.7, 360.0)
			return Color.from_hsv(h / 360.0, 0.82, 1.0)
		7:
			return cols[clampi(int(floorf(v * 0.32)), 0, n - 1)]
		8:
			return cols[0] if (index + secteur) % 2 == 0 else cols[1 % n]
		9:
			var g: int = (index * 73856093) ^ ((secteur + 1) * 19349663)
			return cols[absi(g) % n]
		10:
			var h10: float = fposmod(float(index) * 0.9 + float(secteur) * 31.0, 360.0)
			return Color.from_hsv(h10 / 360.0, 0.75, 1.0)
		11:
			return Tables.gradient(r.palette, ang / TAU + b.length() / rm * 1.5 + float(index) * 0.002)
		12:
			var zz: float = 0.0
			if rel_mode != 0:
				zz = Tables.relief_z(rel_mode, rel_h, b.length(), rm) / maxf(rel_h * rm, 1.0)
			return Tables.gradient(r.palette, (zz + 1.0) * 0.5)
		_:
			return Tables.gradient(r.palette, 0.5 + 0.5 * sin(b.x * 0.02 + sin(b.y * 0.017) * 2.0) + float(index) * 0.001)


func place(p: Vector2, ca: float, sa: float, m: bool) -> Vector3:
	var y: float = -p.y if m else p.y
	var x: float = p.x * ca - y * sa
	var yy: float = p.x * sa + y * ca
	if rel_mode == 0:
		return Vector3(x, yy, 0.0)
	return Vector3(x, yy, Tables.relief_z(rel_mode, rel_h, sqrt(x * x + yy * yy), rm))


func optique(p: Vector2, ca: float, sa: float, m: bool) -> void:
	if rel_mode == 0:
		prof = 1.0
		lum = 1.0
		return
	var y: float = -p.y if m else p.y
	var x: float = p.x * ca - y * sa
	var yy: float = p.x * sa + y * ca
	var d: float = sqrt(x * x + yy * yy)
	var z: float = Tables.relief_z(rel_mode, rel_h, d, rm)
	var u: float = clampf(z / rm, -1.0, 1.0)
	prof = clampf(0.40 + 0.60 * (u + 1.0) / 2.0, 0.28, 1.0)
	var h: float = rm / 48.0
	var pente: float = (Tables.relief_z(rel_mode, rel_h, d + h, rm) - Tables.relief_z(rel_mode, rel_h, d - h, rm)) / (2.0 * h)
	var dd: float = 0.0001 if d < 0.0001 else d
	var nx: float = -pente * x / dd
	var ny: float = -pente * yy / dd
	var norme: float = sqrt(nx * nx + ny * ny + 1.0)
	var produit: float = 1.0 if norme < 0.0001 else (nx * -0.45 + ny * -0.62 + 0.64) / norme
	lum = clampf(0.30 + 0.70 * (produit * 0.5 + 0.5), 0.12, 1.0)


func teinter(base: Color) -> Color:
	if rel_mode == 0 or rel_lum <= 0.001:
		return base
	return base.lerp(Color.BLACK, (1.0 - lum) * rel_lum)


func _al(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, clampf(a, 0.0, 1.0))


# -------------------------------------------------------------------- décor

func decor(a: Vector3, b: Vector3, v: float, r: Reglages, g: Array, index: int) -> void:
	var dec: int = int(g[2])
	match dec:
		0:
			g_ligne(a, b)
		1:
			g_ligne(a, b)
			if index % 2 == 0:
				g_cercle(b, ep_loc * 1.7 + 0.6, true)
		3:
			var d: Vector3 = b - a
			var l: float = Vector2(d.x, d.y).length()
			if l < 0.001:
				g_ligne(a, b)
				return
			var nrm: Vector3 = Vector3(-d.y / l, d.x / l, 0.0) * (ep_loc * 2.0 + 1.0)
			g_ligne(a + nrm, b + nrm)
			g_ligne(a - nrm, b - nrm)
		2:
			g_ligne(a, b)
			if index % 4 == 0:
				var d2: Vector3 = b - a
				var l2: float = Vector2(d2.x, d2.y).length()
				if l2 > 0.001:
					var n2: Vector3 = Vector3(-d2.y / l2, d2.x / l2, 0.0) * (ep_loc * 3.5 + 2.0)
					g_ligne(b - n2, b + n2)
		4:
			g_ligne(a, b)
			for k in 3:
				var dx: float = bruit(index * 31 + k * 7) * (ep_loc * 5.0 + 3.0)
				var dy: float = bruit(index * 17 + k * 13 + 5) * (ep_loc * 5.0 + 3.0)
				g_cercle(b + Vector3(dx, dy, 0.0), ep_loc * 0.5 + 0.4, true)
		5:
			if index % 3 == 0:
				g_ligne(a, b)
		6:
			var memo1: float = lw
			lw = clampf(ep_loc * (0.6 + v * 0.30), 0.2, 60.0)
			g_ligne(a, b)
			lw = memo1
		7:
			var memo2: float = lw
			lw = clampf(ep_loc * 4.0 / (1.0 + v * 0.55), 0.2, 60.0)
			g_ligne(a, b)
			lw = memo2
		8:
			var memo3: float = lw
			var c0: Color = lc
			var a_base: float = clampf(r.opacite, 0.02, 1.0)
			for k in range(3, 0, -1):
				lw = memo3 * float(k) * 1.9
				lc = _al(c0, a_base / float(k * k))
				g_ligne(a, b)
			lw = memo3
			lc = c0
			g_ligne(a, b)
		9:
			g_ligne(a, b)
			if index % 5 == 0:
				var s: float = ep_loc * 2.6 + 1.5
				var p1: Vector3 = Vector3(b.x, b.y - s, b.z)
				var p2: Vector3 = Vector3(b.x + s, b.y, b.z)
				var p3: Vector3 = Vector3(b.x, b.y + s, b.z)
				var p4: Vector3 = Vector3(b.x - s, b.y, b.z)
				g_ligne(p1, p2)
				g_ligne(p2, p3)
				g_ligne(p3, p4)
				g_ligne(p4, p1)
		11:
			var memoT: float = lw
			var coeur: Color = lc
			var alpha_t: float = clampf(r.opacite, 0.02, 1.0)
			for k in range(5, 0, -1):
				var f: float = float(k) / 5.0
				lw = memoT * 3.4 * f
				lc = _al(coeur.lerp(Color.WHITE, (1.0 - f) * 0.8), alpha_t)
				g_ligne(a, b)
			lw = memoT
			lc = coeur
		12:
			var dF: Vector3 = b - a
			var lF: float = Vector2(dF.x, dF.y).length()
			if lF < 0.001:
				g_ligne(a, b)
				return
			var nF: Vector3 = Vector3(-dF.y / lF, dF.x / lF, 0.0)
			var memoF: float = lw
			lw = memoF * 0.6
			for k in range(-3, 4):
				var e: Vector3 = nF * (float(k) * (memoF * 1.5 + 0.9))
				g_ligne(a + e, b + e)
			lw = memoF
		13:
			g_ligne(a, b)
			var pas_t: int = 2 if r.espacement < 2 else r.espacement
			if index % pas_t == 0:
				var dT: Vector3 = b - a
				var ang_t: float = atan2(dT.y, dT.x) + PI / 2.0
				var memoS: float = lw
				lw = 0.8 if memoS * 0.55 < 0.8 else memoS * 0.55
				symbole(r.symbole, b, ang_t, ep_loc * 2.4 + 4.5)
				lw = memoS
		14:
			var memoM: float = lw
			var cM: Color = lc
			lw = memoM * 0.7
			lc = _al(cM, clampf(r.opacite, 0.02, 1.0) * 0.32)
			g_ligne(a, b)
			lw = memoM
			lc = cM
			var pas_m: int = 2 if r.espacement < 2 else r.espacement
			if index % pas_m == 0:
				var dM: Vector3 = b - a
				chiffre((index * 7919 + 13) % 10, b, atan2(dM.y, dM.x) + PI / 2.0, ep_loc * 1.7 + 3.2)
		15:
			var memoV: float = lw
			var cV: Color = lc
			lw = memoV * 4.6
			lc = Color(0.027, 0.027, 0.051, 1.0)
			g_ligne(a, b)
			lw = memoV * 3.1
			lc = _al(cV, 0.95)
			g_ligne(a, b)
			lw = memoV * 1.0
			lc = _al(cV.lerp(Color.WHITE, 0.45), 0.47)
			g_ligne(a, b)
			lw = memoV
			lc = cV
		16:
			var coude: Vector3 = Vector3(b.x, a.y, a.z)
			g_ligne(a, coude)
			g_ligne(coude, b)
			if index % 6 == 0:
				g_cercle(b, ep_loc * 2.0 + 1.8, false)
				g_cercle(b, ep_loc * 0.7 + 0.5, true)
		17:
			var dH: Vector3 = b - a
			var lH: float = Vector2(dH.x, dH.y).length()
			if lH < 0.001:
				g_ligne(a, b)
				return
			var nH: Vector3 = Vector3(-dH.y / lH, dH.x / lH, 0.0)
			var amp_h: float = ep_loc * 3.5 + 3.0
			var e0: Vector3 = nH * (amp_h * sin(float(index) * 0.42))
			var e1: Vector3 = nH * (amp_h * sin(float(index + 1) * 0.42))
			g_ligne(a + e0, b + e1)
			g_ligne(a - e0, b - e1)
			if index % 3 == 0:
				var cH: Color = lc
				lc = _al(cH, clampf(r.opacite, 0.02, 1.0) * 0.45)
				g_ligne(b + e1, b - e1)
				lc = cH
		18:
			g_ligne(a, b)
			if index % 5 == 0:
				var dG: Vector3 = b - a
				var lG: float = Vector2(dG.x, dG.y).length()
				if lG > 0.001:
					var dir: Vector3 = Vector3(dG.x / lG, dG.y / lG, 0.0)
					var nG: Vector3 = Vector3(-dG.y / lG, dG.x / lG, 0.0)
					var lon: float = ep_loc * 4.0 + 4.0
					for sgn in [-1.0, 1.0]:
						var bout: Vector3 = b + (nG * (0.85 * float(sgn)) + dir * 0.55) * lon
						g_ligne(b, bout)
						g_ligne(bout, bout + (nG * (0.5 * float(sgn)) + dir * 0.5) * (lon * 0.5))
		19:
			var cC: Color = lc
			lc = _al(cC, clampf(r.opacite, 0.02, 1.0) * 0.16)
			g_ligne(a, b)
			lc = cC
			if index % 4 == 0:
				var tt: float = (bruit(index * 5 + 3) + 1.0) / 2.0
				g_cercle(b, ep_loc * (0.7 + 1.9 * tt) + 0.6, true)
		10:
			g_ligne(a, b)
			if index % 7 == 0:
				var dd: float = Vector2(b.x, b.y).length()
				g_cercle(b, clampf(dd * 0.035 + ep_loc, 1.0, 26.0), false)


# ------------------------------------------------------------ dispositions

func corde(b: Vector2, ca: float, sa: float, m: bool, ang_cible: float, alpha: float, base: Color) -> void:
	var p1: Vector3 = place(b, ca, sa, m)
	var p2: Vector3 = place(b, cos(ang_cible), sin(ang_cible), m)
	lc = _al(base, alpha * 0.34)
	g_ligne(p1, p2)


func dispose(a: Vector2, b: Vector2, ca: float, sa: float, m: bool, v: float, r: Reglages, g: Array, ang: float, pas: float, index: int, alpha: float, base: Color) -> void:
	var disp: int = int(g[1])
	match disp:
		0:
			decor(place(a, ca, sa, m), place(b, ca, sa, m), v, r, g, index)
		1:
			for k in range(3, 0, -1):
				var f: float = float(k) / 3.0
				lc = _al(base, alpha * f)
				pc = lc
				decor(place(a * f, ca, sa, m), place(b * f, ca, sa, m), v, r, g, index)
		2:
			for k in 3:
				var f2: float = 1.0 - float(k) * 0.22
				var d: float = float(k) * 0.20
				var cd: float = cos(d)
				var sd: float = sin(d)
				var a2: Vector2 = Vector2(a.x * cd - a.y * sd, a.x * sd + a.y * cd) * f2
				var b2: Vector2 = Vector2(b.x * cd - b.y * sd, b.x * sd + b.y * cd) * f2
				lc = _al(base, alpha * (1.0 - float(k) * 0.28))
				pc = lc
				decor(place(a2, ca, sa, m), place(b2, ca, sa, m), v, r, g, index)
		3:
			decor(place(a, ca, sa, m), place(b, ca, sa, m), v, r, g, index)
			var da: float = a.length()
			var db: float = b.length()
			var rr: float = rm * 0.55
			if da > 14.0 and db > 14.0:
				var ai: Vector2 = a * (rr * rr / (da * da))
				var bi: Vector2 = b * (rr * rr / (db * db))
				lc = _al(base, alpha * 0.5)
				pc = lc
				decor(place(ai, ca, sa, m), place(bi, ca, sa, m), v, r, g, index)
		4:
			decor(place(a, ca, sa, m), place(b, ca, sa, m), v, r, g, index)
			corde(b, ca, sa, m, ang + pas, alpha, base)
		5:
			decor(place(a, ca, sa, m), place(b, ca, sa, m), v, r, g, index)
			corde(b, ca, sa, m, ang + pas * 3.0, alpha, base)
		7:
			decor(place(a, ca, sa, m), place(b, ca, sa, m), v, r, g, index)
			corde(b, ca, sa, m, ang + PI, alpha, base)
		8, 9:
			var jumeau: bool = disp == 9
			var f3: float = clampf(r.reduction, 0.30, 0.95)
			var it: int = clampi(r.iterations, 2, 12)
			var dehors: float = rm * 2.4
			var bord: float = rm * 1.25
			var naissance: float = rm * 0.018
			var minuscule: float = rm * 0.0016
			var portee0: float = maxf(a.length(), b.length())
			for q in range(-4, it + 4):
				var ech: float = pow(f3, float(q))
				var portee: float = portee0 * ech
				if portee > dehors or portee < minuscule:
					continue
				var att: float = 1.0
				if portee > bord:
					att = clampf((dehors - portee) / (dehors - bord), 0.0, 1.0)
				if portee < naissance:
					att *= clampf((portee - minuscule) / (naissance - minuscule), 0.0, 1.0)
				if att <= 0.02:
					continue
				var tw: float = float(q) * r.torsion
				var ct: float = cos(tw)
				var st: float = sin(tw)
				var af: Vector2 = Vector2(a.x * ct - a.y * st, a.x * st + a.y * ct) * ech
				var bf: Vector2 = Vector2(b.x * ct - b.y * st, b.x * st + b.y * ct) * ech
				lc = _al(base, alpha * att)
				pc = lc
				var memo_ep: float = ep_loc
				ep_loc = memo_ep * clampf(0.35 + 0.65 * ech, 0.12, 3.0)
				lw = ep_loc
				decor(place(af, ca, sa, m), place(bf, ca, sa, m), v, r, g, index)
				if jumeau:
					decor(place(af, ca, sa, not m), place(bf, ca, sa, not m), v, r, g, index)
				ep_loc = memo_ep
				lw = memo_ep
		6:
			decor(place(a, ca, sa, m), place(b, ca, sa, m), v, r, g, index)
			lc = _al(base, alpha * 0.22)
			g_ligne(place(Vector2.ZERO, ca, sa, m), place(b, ca, sa, m))


func segment(a: Vector2, b: Vector2, v: float, r: Reglages, rang: int, index: int) -> void:
	var g: Array = Tables.GENRES[r.genre]
	var n: int = r.branches
	var pas: float = TAU / float(n)
	var miroir: bool = bool(g[3]) or r.miroir
	if r.reseau != 0:
		_pavage(a, b, v, r, rang, index)
		return
	for i in n:
		var ang: float = float(i) * pas
		var ca: float = cos(ang)
		var sa: float = sin(ang)
		var base: Color = couleur(r, i, rang, index, b, ang, v)
		optique(b, ca, sa, false)
		ep_loc = r.epaisseur
		var alpha: float = clampf(r.opacite * prof, 6.0 / 255.0, 1.0)
		var c: Color = teinter(base)
		lc = _al(c, alpha)
		lw = ep_loc
		pc = lc
		dispose(a, b, ca, sa, false, v, r, g, ang, pas, index, alpha, c)
		if miroir:
			optique(b, ca, sa, true)
			ep_loc = r.epaisseur
			var alpha_m: float = clampf(r.opacite * prof, 6.0 / 255.0, 1.0)
			var cm: Color = teinter(base)
			lc = _al(cm, alpha_m)
			lw = ep_loc
			pc = lc
			dispose(a, b, ca, sa, true, v, r, g, ang, pas, index, alpha_m, cm)


func _pavage(a: Vector2, b: Vector2, v: float, r: Reglages, rang: int, index: int) -> void:
	var g: Array = Tables.GENRES[r.genre]
	var res: int = r.reseau
	var hexa: bool = res == 3 or res == 4
	var rot: int = 3 if res == 3 else (6 if res == 4 else 1)
	var c: int = clampi(int(roundf(float(r.branches) / 8.0)), 1, 3)
	if rot > 1 and c > 2:
		c = 2
	var maille: float = rm / float(c)
	var pas_y: float = 0.866 if hexa else 1.0
	var ci: int = c + 1
	var cj: int = 0
	if res != 5:
		cj = clampi(int(ceilf(demi_h / (maille * pas_y))) + 1, 0, 8)
	var miroir_trait: bool = bool(g[3]) or r.miroir
	for i in range(-ci, ci + 1):
		for j in range(-cj, cj + 1):
			var dx: float = float(i) * maille
			var dy: float = float(j) * maille * pas_y
			if hexa and j % 2 != 0:
				dx += maille / 2.0
			var mx: bool = (res == 2 or res == 5) and i % 2 != 0
			var my: bool = res == 2 and j % 2 != 0
			var dec: Vector2 = Vector2(dx, dy)
			for k in rot:
				var ang: float = float(k) * TAU / float(rot)
				var ca: float = cos(ang)
				var sa: float = sin(ang)
				for rf in (2 if miroir_trait else 1):
					var sy: float = (-1.0 if my else 1.0) * (-1.0 if rf == 1 else 1.0)
					var sx: float = -1.0 if mx else 1.0
					var a0: Vector2 = Vector2(a.x * sx, a.y * sy)
					var b0: Vector2 = Vector2(b.x * sx, b.y * sy)
					var ta: Vector2 = Vector2(a0.x * ca - a0.y * sa, a0.x * sa + a0.y * ca) + dec
					var tb: Vector2 = Vector2(b0.x * ca - b0.y * sa, b0.x * sa + b0.y * ca) + dec
					optique(tb, 1.0, 0.0, false)
					ep_loc = r.epaisseur
					var base: Color = couleur(r, i * 3 + j * 5 + k, rang, index, tb, ang, v)
					var alpha: float = clampf(r.opacite * prof, 6.0 / 255.0, 1.0)
					lc = _al(teinter(base), alpha)
					lw = ep_loc
					pc = lc
					decor(place(ta, 1.0, 0.0, false), place(tb, 1.0, 0.0, false), v, r, g, index)


# ---------------------------------------------------------------- fractales

static func _echantillonner(source: PackedVector2Array, morceaux: int) -> PackedVector2Array:
	if source.size() < 2 or morceaux < 1:
		return source
	var cumul: PackedFloat32Array = PackedFloat32Array([0.0])
	var total: float = 0.0
	for i in range(1, source.size()):
		total += source[i].distance_to(source[i - 1])
		cumul.append(total)
	if total <= 0.0:
		return source
	var sortie: PackedVector2Array = PackedVector2Array([source[0]])
	var j: int = 1
	for k in range(1, morceaux + 1):
		var cible: float = total * float(k) / float(morceaux)
		while j < cumul.size() - 1 and cumul[j] < cible:
			j += 1
		var c0: float = cumul[j - 1]
		var c1: float = cumul[j]
		var u: float = 0.0 if (c1 - c0) < 1e-9 else (cible - c0) / (c1 - c0)
		sortie.append(source[j - 1].lerp(source[j], clampf(u, 0.0, 1.0)))
	return sortie


static func _generateur(r: Reglages, source: PackedVector2Array) -> PackedVector2Array:
	var m: int = clampi(r.motif, 0, Tables.NOMS_MOTIFS.size() - 1)
	if m > 0:
		var plat: Array = Tables.MOTIFS_GENERATEURS[m]
		var g: PackedVector2Array = PackedVector2Array()
		var i: int = 0
		while i + 1 < plat.size():
			g.append(Vector2(float(plat[i]), float(plat[i + 1])))
			i += 2
		return g
	var ech: PackedVector2Array = _echantillonner(source, clampi(r.segments_gen, 2, 9))
	if ech.size() < 3:
		return PackedVector2Array()
	var a: Vector2 = ech[0]
	var b: Vector2 = ech[ech.size() - 1]
	var dx: float = b.x - a.x
	var dy: float = b.y - a.y
	var l2: float = dx * dx + dy * dy
	if l2 < 1e-6:
		return PackedVector2Array()
	var out: PackedVector2Array = PackedVector2Array()
	for p in ech:
		var vx: float = p.x - a.x
		var vy: float = p.y - a.y
		out.append(Vector2((vx * dx + vy * dy) / l2, (-vx * dy + vy * dx) / l2))
	return out


static func construire_fractale(source: PackedVector2Array, r: Reglages) -> PackedVector2Array:
	if source.size() < 2:
		return source
	var gen: PackedVector2Array = _generateur(r, source)
	if gen.size() < 3:
		return source
	var alterne: bool = bool(Tables.MOTIFS_ALTERNES[clampi(r.motif, 0, 5)])
	var courbe: PackedVector2Array = PackedVector2Array([source[0], source[source.size() - 1]])
	var profondeur: int = clampi(r.recursion, 0, 7)
	for d in profondeur:
		var futur: int = (courbe.size() - 1) * (gen.size() - 1) + 1
		if futur > 40000:
			break
		var suivant: PackedVector2Array = PackedVector2Array([courbe[0]])
		for i in range(courbe.size() - 1):
			var p: Vector2 = courbe[i]
			var q: Vector2 = courbe[i + 1]
			var dx: float = q.x - p.x
			var dy: float = q.y - p.y
			var sens: float = -1.0 if (alterne and i % 2 == 1) else 1.0
			for k in range(1, gen.size()):
				var gx: float = gen[k].x
				var gy: float = gen[k].y * sens
				suivant.append(Vector2(p.x + gx * dx - gy * dy, p.y + gx * dy + gy * dx))
		courbe = suivant
	return courbe


static func preparer(t: TraitDessin) -> void:
	if t.fige and t.reglages.recursion > 0 and t.points.size() > 2:
		if not t.a_cache:
			var c: PackedVector2Array = construire_fractale(t.points, t.reglages)
			var vv: PackedFloat32Array = PackedFloat32Array([0.0])
			for i in range(1, c.size()):
				vv.append(c[i].distance_to(c[i - 1]))
			t.cache = c
			t.cache_vit = vv
			t.a_cache = true


static func points_effectifs(t: TraitDessin) -> PackedVector2Array:
	if t.fige and t.reglages.recursion > 0 and t.points.size() > 2 and t.a_cache:
		return t.cache
	return t.points


static func vitesses_effectives(t: TraitDessin) -> PackedFloat32Array:
	if t.fige and t.reglages.recursion > 0 and t.points.size() > 2 and t.a_cache:
		return t.cache_vit
	return t.vit


func dessine_plage(t: TraitDessin, debut: int, fin: int, pas: int) -> void:
	var pts: PackedVector2Array = points_effectifs(t)
	var vits: PackedFloat32Array = vitesses_effectives(t)
	var f: int = mini(fin, pts.size())
	var d: int = maxi(debut, 1)
	if vits.size() < pts.size():
		return
	if pas <= 1:
		for i in range(d, f):
			segment(pts[i - 1], pts[i], vits[i], t.reglages, t.rang, i)
		return
	var i2: int = d + pas - 1
	while i2 < f:
		segment(pts[i2 - pas], pts[i2], vits[i2], t.reglages, t.rang, i2)
		i2 += pas


static func cout_genre(g: Array) -> float:
	var c: float = 1.0
	match int(g[1]):
		1, 2:
			c *= 3.0
		4, 5, 7, 6, 3:
			c *= 2.0
		8:
			c *= 6.0
		9:
			c *= 12.0
	match int(g[2]):
		12:
			c *= 7.0
		11:
			c *= 5.0
		8:
			c *= 4.0
		15:
			c *= 3.0
		3, 17, 1, 14, 16, 4:
			c *= 2.0
	return c


static func cout_trait(t: TraitDessin) -> float:
	var r: Reglages = t.reglages
	var g: Array = Tables.GENRES[r.genre]
	var m: float = 2.0 if (bool(g[3]) or r.miroir) else 1.0
	var np: int = t.cache.size() if (t.a_cache and t.fige and r.recursion > 0) else t.points.size()
	return float(np) * float(r.branches) * m * cout_genre(g) * (1.0 if r.reseau == 0 else 6.0)
