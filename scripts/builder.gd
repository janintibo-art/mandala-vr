class_name Builder
extends RefCounted


static func vide() -> Dictionary:
	return {
		"v": PackedVector3Array(),
		"n": PackedVector3Array(),
		"uv": PackedVector2Array(),
		"c": PackedColorArray(),
		"i": PackedInt32Array(),
	}


static func fusionner(dst: Dictionary, src: Dictionary) -> void:
	var dv: PackedVector3Array = dst["v"]
	var dn: PackedVector3Array = dst["n"]
	var duv: PackedVector2Array = dst["uv"]
	var dc: PackedColorArray = dst["c"]
	var di: PackedInt32Array = dst["i"]
	var decalage: int = dv.size()
	dv.append_array(src["v"])
	dn.append_array(src["n"])
	duv.append_array(src["uv"])
	dc.append_array(src["c"])
	var si: PackedInt32Array = src["i"]
	for k in si.size():
		di.append(si[k] + decalage)


static func _quad(o: Dictionary, a: Vector3, b: Vector3, ca: Color, cb: Color, w: float) -> void:
	var d: Vector3 = b - a
	var l: float = d.length()
	if l < 0.00001:
		return
	d /= l
	var v: PackedVector3Array = o["v"]
	var nn: PackedVector3Array = o["n"]
	var uv: PackedVector2Array = o["uv"]
	var c: PackedColorArray = o["c"]
	var ix: PackedInt32Array = o["i"]
	var k: int = v.size()
	v.append(a)
	v.append(a)
	v.append(b)
	v.append(b)
	nn.append(d)
	nn.append(d)
	nn.append(d)
	nn.append(d)
	uv.append(Vector2(-1.0, w))
	uv.append(Vector2(1.0, w))
	uv.append(Vector2(-1.0, w))
	uv.append(Vector2(1.0, w))
	c.append(ca)
	c.append(ca)
	c.append(cb)
	c.append(cb)
	ix.append(k)
	ix.append(k + 1)
	ix.append(k + 2)
	ix.append(k + 2)
	ix.append(k + 1)
	ix.append(k + 3)


static func _anneau(u: float) -> int:
	if u < 0.34:
		return 0
	if u < 0.67:
		return 1
	return 2


static func construire(pts: PackedVector2Array, idx_trait: int, p: Dictionary, stride: int, t_debut: float = 0.0, t_total: float = -1.0) -> Array:
	var sorties: Array = [vide(), vide(), vide()]
	var m0: int = pts.size()
	if m0 < 2:
		return sorties
	var pas_ech: int = maxi(stride, 1)
	var base: PackedVector2Array = PackedVector2Array()
	var i: int = 0
	while i < m0:
		base.append(pts[i])
		i += pas_ech
	if (m0 - 1) % pas_ech != 0:
		base.append(pts[m0 - 1])
	var m: int = base.size()

	var n: int = int(p["n"])
	var genre: Dictionary = Tables.GENRES[int(p["genre"]) % Tables.GENRES.size()]
	var twist: float = float(genre["twist"])
	var miroir: bool = bool(genre["miroir"])
	var ond: float = float(genre["ond"])
	var copies: Array = genre["copies"]
	var rel: int = int(p["relief"])
	var mode: int = int(p["mode"])
	var pal: int = int(p["palette"])
	var larg: float = float(p["largeur"])
	var R: float = Tables.R_METRES
	var H: float = Tables.H_METRES
	var pas: float = TAU / float(n)
	var dep_branche: bool = (mode == 1 or mode == 4)

	var cum: PackedFloat32Array = PackedFloat32Array()
	cum.resize(m)
	var tot: float = 0.0
	cum[0] = 0.0
	for k in range(1, m):
		tot += base[k].distance_to(base[k - 1])
		cum[k] = tot
	var tref: float = t_total if t_total > 0.0 else maxf(tot, 0.0001)

	var nm: int = 2 if miroir else 1
	for ci in copies.size():
		var sc: float = float(copies[ci][0])
		var off: float = float(copies[ci][1])
		var d2: PackedFloat32Array = PackedFloat32Array()
		var cab: PackedFloat32Array = PackedFloat32Array()
		var sab: PackedFloat32Array = PackedFloat32Array()
		var zz: PackedFloat32Array = PackedFloat32Array()
		var gg: PackedFloat32Array = PackedFloat32Array()
		var iv: PackedFloat32Array = PackedFloat32Array()
		var tt: PackedFloat32Array = PackedFloat32Array()
		var cbase: PackedColorArray = PackedColorArray()
		d2.resize(m)
		cab.resize(m)
		sab.resize(m)
		zz.resize(m)
		gg.resize(m)
		iv.resize(m)
		tt.resize(m)
		cbase.resize(m)
		for k in m:
			var q: Vector2 = base[k] * sc
			var d: float = q.length()
			var a: float = 0.0
			if d > 0.00001:
				a = atan2(q.y, q.x)
			var dd: float = minf(d * (1.0 + ond * sin(d * 14.0)), 1.0)
			var ab: float = a + twist * d
			d2[k] = dd
			cab[k] = cos(ab)
			sab[k] = sin(ab)
			zz[k] = H * Tables.relief_z(rel, dd)
			var g: float = Tables.pente(rel, dd)
			gg[k] = g
			iv[k] = 1.0 / sqrt(g * g + 1.0)
			tt[k] = (t_debut + cum[k]) / tref
			if not dep_branche:
				var tc: float = 0.0
				match mode:
					0:
						tc = dd + float(ci) * 0.07
					2:
						tc = float(idx_trait) * 0.137 + float(ci) * 0.11
					3:
						tc = tt[k] + float(ci) * 0.2
					_:
						tc = float(ci) * 0.15
				cbase[k] = Tables.echantillon(pal, tc)
		var w: float = larg * (0.55 + 0.45 * sc)

		for mi in nm:
			var mf: bool = (mi == 1)
			for kb in n:
				var ang: float = float(kb) * pas + off * pas
				var cb: float = cos(ang)
				var sb: float = sin(ang)
				var pos_prec: Vector3 = Vector3.ZERO
				var col_prec: Color = Color.BLACK
				var u_prec: float = 0.0
				for k in m:
					var c: float
					var s: float
					if mf:
						c = cab[k] * cb + sab[k] * sb
						s = -sab[k] * cb + cab[k] * sb
					else:
						c = cab[k] * cb - sab[k] * sb
						s = sab[k] * cb + cab[k] * sb
					var dd2: float = d2[k]
					var pos: Vector3 = Vector3(R * dd2 * c, R * dd2 * s, zz[k])
					var col: Color
					if dep_branche:
						var ph: float = atan2(s, c) / TAU
						var tc2: float = 0.0
						if mode == 1:
							tc2 = ph + float(ci) * 0.07
						else:
							tc2 = dd2 * 0.6 + ph * 0.5 + float(ci) * 0.07
						col = Tables.echantillon(pal, tc2)
					else:
						col = cbase[k]
					var lum: float = Tables.luminosite(gg[k], iv[k], c, s)
					col = Color(col.r * lum, col.g * lum, col.b * lum, 1.0)
					if k > 0:
						var r: int = _anneau((u_prec + dd2) * 0.5)
						_quad(sorties[r], pos_prec, pos, col_prec, col, w)
					pos_prec = pos
					col_prec = col
					u_prec = dd2
	return sorties
