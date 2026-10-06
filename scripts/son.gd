class_name Son
extends Node
## Sons du telephone : ambiances (carillon, bourdon, vent, ruisseau, foret),
## notes quand on dessine (gammes), jingle de demarrage. Tout est synthetise.

const TAUX: int = 22050
const DUREE: float = 12.0
const FONDU: float = 0.4
const NOMS_AMBIANCES: Array = ["Silence", "Carillon", "Bourdon", "Vent", "Ruisseau", "Foret"]
const NOMS_GAMMES: Array = ["Muet", "Pentatonique", "Majeure", "Mineure", "Japonaise", "Orientale"]
const GAMMES: Array = [[], [0, 2, 4, 7, 9], [0, 2, 4, 5, 7, 9, 11], [0, 2, 3, 5, 7, 8, 10], [0, 1, 5, 7, 8], [0, 1, 4, 5, 7, 8, 11]]
const NB_NOTES: int = 16
const BASSE: float = 146.83

var volume: float = 0.6
var muet: bool = false
var ambiance: int = 0
var gamme: int = 0

var _fond: AudioStreamPlayer
var _bref: AudioStreamPlayer
var _voix: Array = []
var _cache: Dictionary = {}
var _note: AudioStreamWAV = null
var _thread: Thread = null
var _type_en_cours: int = -1
var _voix_suiv: int = 0
var _dernier_degre: int = -99
var _dernier_t: int = 0
var _jingle: AudioStreamWAV = null
var _note_thread: Thread = null


func _ready() -> void:
	_fond = AudioStreamPlayer.new()
	add_child(_fond)
	_bref = AudioStreamPlayer.new()
	add_child(_bref)
	for i in 6:
		var p: AudioStreamPlayer = AudioStreamPlayer.new()
		add_child(p)
		_voix.append(p)
	_note_thread = Thread.new()
	_note_thread.start(_fabriquer_note)


func _exit_tree() -> void:
	if _thread != null:
		_thread.wait_to_finish()
		_thread = null
	if _note_thread != null:
		_note_thread.wait_to_finish()
		_note_thread = null


func _db() -> float:
	return linear_to_db(maxf(volume, 0.0001))


func _process(_dt: float) -> void:
	if _thread != null and not _thread.is_alive():
		var res: Array = _thread.wait_to_finish()
		_thread = null
		var t: int = int(res[0])
		_cache[t] = _flux(res[1] as PackedByteArray, true)
		if t == ambiance:
			_jouer_fond()
	if _note_thread != null and not _note_thread.is_alive():
		var r2: Array = _note_thread.wait_to_finish()
		_note_thread = null
		_note = _flux(r2[0] as PackedByteArray, false)
		_jingle = _flux(r2[1] as PackedByteArray, false)


func _flux(octets: PackedByteArray, boucle: bool) -> AudioStreamWAV:
	var s: AudioStreamWAV = AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = TAUX
	s.stereo = false
	s.data = octets
	if boucle:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = octets.size() / 2
	return s


func demarrage() -> void:
	if muet or _jingle == null:
		return
	_bref.stream = _jingle
	_bref.volume_db = _db()
	_bref.play()


func choisir_ambiance(i: int) -> void:
	ambiance = i
	_fond.stop()
	if i == 0 or muet:
		return
	if _cache.has(i):
		_jouer_fond()
	elif _thread == null:
		_type_en_cours = i
		_thread = Thread.new()
		_thread.start(_generer_ambiance.bind(i))


func _jouer_fond() -> void:
	if ambiance == 0 or muet or not _cache.has(ambiance):
		return
	_fond.stream = _cache[ambiance]
	_fond.volume_db = _db()
	_fond.play()


func regler_volume(v: float) -> void:
	volume = v
	_fond.volume_db = _db()


func basculer_muet() -> void:
	muet = not muet
	if muet:
		_fond.stop()
		_bref.stop()
	else:
		_jouer_fond()


func jouer_note(u: float, force: float) -> void:
	if gamme <= 0 or muet or _note == null:
		return
	var v: float = clampf(u, 0.0, 1.0)
	var degre: int = int(round((1.0 - v) * float(NB_NOTES - 1)))
	var maintenant: int = Time.get_ticks_msec()
	if degre == _dernier_degre and maintenant - _dernier_t < 320:
		return
	if maintenant - _dernier_t < 85:
		return
	_dernier_degre = degre
	_dernier_t = maintenant
	var demi: Array = GAMMES[gamme]
	var oct: int = degre / demi.size()
	var k: int = degre % demi.size()
	var semi: float = float(int(demi[k]) + 12 * oct)
	var p: AudioStreamPlayer = _voix[_voix_suiv]
	_voix_suiv = (_voix_suiv + 1) % _voix.size()
	p.stream = _note
	p.pitch_scale = pow(2.0, semi / 12.0)
	p.volume_db = linear_to_db(clampf(volume * (0.35 + clampf(force, 0.0, 1.0) * 0.65), 0.0001, 1.0))
	p.play()


func reinitialiser() -> void:
	_dernier_degre = -99


# ---------------------------------------------------------------- synthese

class Alea:
	var e: int = 1

	func _init(g: int) -> void:
		e = g

	func suivant() -> float:
		e = (e * 1103515245 + 12345) & 0x7FFFFFFF
		return float(e) / 2147483647.0

	func centre() -> float:
		return suivant() * 2.0 - 1.0


static func _vers_wav(x: PackedFloat32Array, n: int) -> PackedByteArray:
	var crete: float = 0.0
	for i in n:
		var a: float = absf(x[i])
		if a > crete:
			crete = a
	var gain: float = 0.0 if crete < 1e-9 else 0.78 / crete
	var o: PackedByteArray = PackedByteArray()
	o.resize(n * 2)
	for i in n:
		var v: int = clampi(int(roundf(x[i] * gain * 32000.0)), -32767, 32767)
		o.encode_s16(i * 2, v)
	return o


static func _cloche(x: PackedFloat32Array, debut: int, f: float, duree: float, gain: float) -> void:
	var parts: Array = [1.0, 2.0, 2.76, 5.4, 8.9]
	var poids: Array = [1.0, 0.55, 0.38, 0.22, 0.12]
	var n: int = int(roundf(duree * float(TAUX)))
	var decs: Array = []
	var etat: Array = []
	var ws: Array = []
	for k in 5:
		decs.append(exp(-(1.6 + float(k) * 1.4) / float(TAUX)))
		etat.append(1.0)
		ws.append(TAU * f * float(parts[k]) / float(TAUX))
	for i in n:
		var j: int = debut + i
		if j >= x.size():
			break
		var s: float = 0.0
		for k in 5:
			s += float(poids[k]) * float(etat[k]) * sin(float(ws[k]) * float(i))
			etat[k] = float(etat[k]) * float(decs[k])
		var attaque: float = minf(float(i) / float(TAUX) / 0.004, 1.0)
		x[j] += s * gain * attaque


static func _sifflement(x: PackedFloat32Array, debut: int, f0: float, f1: float, duree: float, gain: float) -> void:
	var n: int = int(roundf(duree * float(TAUX)))
	var phase: float = 0.0
	for i in n:
		var j: int = debut + i
		if j >= x.size():
			break
		var u: float = float(i) / float(n)
		var f: float = f0 + (f1 - f0) * u + sin(u * PI * 6.0) * 90.0
		phase += TAU * f / float(TAUX)
		var env: float = sin(PI * u) * sin(PI * u)
		x[j] += sin(phase) * env * gain


static func _carillon(total: int) -> PackedFloat32Array:
	var x: PackedFloat32Array = PackedFloat32Array()
	x.resize(total)
	var a: Alea = Alea.new(20260909)
	var gamme_c: Array = [1.0, 1.125, 1.25, 1.5, 1.6667, 2.0, 2.25, 2.5]
	var t: float = 0.2
	while t < DUREE - 2.6:
		var f: float = 293.66 * float(gamme_c[int(floorf(a.suivant() * 8.0)) % 8])
		_cloche(x, int(roundf(t * float(TAUX))), f, 2.4, 0.35 + a.suivant() * 0.35)
		t += 0.7 + a.suivant() * 1.9
	return x


static func _bourdon(total: int) -> PackedFloat32Array:
	var x: PackedFloat32Array = PackedFloat32Array()
	x.resize(total)
	var f0: float = 4.0 / DUREE * 22.0
	var rap: Array = [1.0, 1.5, 2.0, 3.0, 4.0]
	var poids: Array = [1.0, 0.6, 0.42, 0.2, 0.12]
	for k in 5:
		var f: float = f0 * float(rap[k])
		var fl: float = float(2 + k) / DUREE
		var w1: float = TAU * f / float(TAUX)
		var w2: float = TAU * (f + 0.5 / DUREE) / float(TAUX)
		var wl: float = TAU * fl / float(TAUX)
		for i in total:
			var lfo: float = 0.72 + 0.28 * sin(wl * float(i) + float(k))
			x[i] += float(poids[k]) * lfo * (sin(w1 * float(i)) + 0.35 * sin(w2 * float(i)))
	return x


static func _souffle(total: int, coupure: float, gain_am: float, f_am: float, graine: int, aigus: float) -> PackedFloat32Array:
	var x: PackedFloat32Array = PackedFloat32Array()
	x.resize(total)
	var a: Alea = Alea.new(graine)
	var b1: float = 0.0
	var b2: float = 0.0
	var c2: float = clampf(coupure * 1.8, 0.01, 0.9)
	for i in total:
		var blanc: float = a.centre()
		b1 += (blanc - b1) * coupure
		b2 += (b1 - b2) * c2
		var t: float = float(i) / float(TAUX)
		var am: float = 1.0 - gain_am + gain_am * (0.5 + 0.5 * sin(TAU * f_am * t))
		x[i] = (b2 * 6.0 + blanc * aigus) * am
	return x


static func _foret(total: int) -> PackedFloat32Array:
	var x: PackedFloat32Array = _souffle(total, 0.02, 0.45, 0.09, 4242, 0.02)
	for i in total:
		x[i] *= 0.55
	var a: Alea = Alea.new(77123)
	var t: float = 0.6
	while t < DUREE - 2.2:
		var phrases: int = 2 + int(floorf(a.suivant() * 3.0))
		var haut: float = 2400.0 + a.suivant() * 1600.0
		var u: float = t
		for k in phrases:
			_sifflement(x, int(roundf(u * float(TAUX))), haut, haut + 700.0 - a.suivant() * 1500.0, 0.07 + a.suivant() * 0.07, 0.22 + a.suivant() * 0.18)
			u += 0.09 + a.suivant() * 0.1
		t += 1.4 + a.suivant() * 3.4
	return x


static func _generer_ambiance(type: int) -> Array:
	var n: int = int(roundf(DUREE * float(TAUX)))
	var fondu: int = int(roundf(FONDU * float(TAUX)))
	var total: int = n + fondu
	var x: PackedFloat32Array
	match type:
		1:
			x = _carillon(total)
		2:
			x = _bourdon(total)
		3:
			x = _souffle(total, 0.014, 0.5, 0.06, 991, 0.01)
		4:
			x = _souffle(total, 0.22, 0.35, 1.9, 5150, 0.09)
		_:
			x = _foret(total)
	for i in fondu:
		var u: float = float(i) / float(fondu)
		x[i] = x[i] * u + x[n + i] * (1.0 - u)
	return [type, _vers_wav(x, n)]


func _fabriquer_note() -> Array:
	var n: int = int(roundf(1.5 * float(TAUX)))
	var x: PackedFloat32Array = PackedFloat32Array()
	x.resize(n)
	_cloche(x, 0, BASSE, 1.45, 0.9)
	var note: PackedByteArray = _vers_wav(x, n)
	var n2: int = int(roundf(1.9 * float(TAUX)))
	var y: PackedFloat32Array = PackedFloat32Array()
	y.resize(n2)
	var montee: Array = [293.66, 369.99, 440.0, 587.33, 739.99]
	for k in 5:
		_cloche(y, int(roundf(float(k) * 0.115 * float(TAUX))), float(montee[k]), 1.7, 0.55 - float(k) * 0.05)
	return [note, _vers_wav(y, n2)]
