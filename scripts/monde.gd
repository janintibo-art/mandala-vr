class_name Monde
extends Node3D
## Decor immersif : ciel procedural autour de toi + poussiere lumineuse.

const NOMS: Array = ["Aucun", "Nuit etoilee", "Nebuleuse", "Aurore boreale", "Abysses", "Crepuscule", "Code", "Cathedrale"]

# haut, bas, etoiles, neb, n1, n2, aurore, pluie, rayons, horizon, couleur horizon, poussiere(couleur, alpha, derive, taille)
const DEF: Array = [
	{},
	{"haut": Color(0.0, 0.0, 0.025), "bas": Color(0.015, 0.02, 0.06), "etoiles": 1.0, "p": [Color(0.7, 0.8, 1.0), 0.5, Vector3(0, 0.02, 0), 1.0]},
	{"haut": Color(0.01, 0.0, 0.04), "bas": Color(0.02, 0.01, 0.07), "etoiles": 0.8, "neb": 1.0, "n1": Color(0.55, 0.1, 0.65), "n2": Color(0.1, 0.35, 0.8), "p": [Color(0.9, 0.7, 1.0), 0.5, Vector3(0, 0.03, 0), 1.0]},
	{"haut": Color(0.0, 0.015, 0.04), "bas": Color(0.0, 0.03, 0.05), "etoiles": 0.7, "aurore": 1.0, "p": [Color(0.5, 1.0, 0.8), 0.4, Vector3(0, 0.04, 0), 0.9]},
	{"haut": Color(0.0, 0.03, 0.08), "bas": Color(0.0, 0.14, 0.22), "etoiles": 0.0, "p": [Color(0.5, 0.9, 1.0), 0.9, Vector3(0, 0.25, 0), 1.3]},
	{"haut": Color(0.08, 0.04, 0.22), "bas": Color(0.55, 0.2, 0.25), "etoiles": 0.35, "horizon": 0.9, "hcol": Color(1.0, 0.45, 0.2), "p": [Color(1.0, 0.8, 0.6), 0.4, Vector3(0, 0.02, 0), 0.9]},
	{"haut": Color(0.0, 0.02, 0.0), "bas": Color(0.0, 0.05, 0.02), "etoiles": 0.0, "pluie": 1.0, "p": [Color(0.3, 1.0, 0.5), 0.5, Vector3(0, -0.4, 0), 0.8]},
	{"haut": Color(0.03, 0.01, 0.06), "bas": Color(0.16, 0.08, 0.03), "etoiles": 0.3, "rayons": 1.0, "horizon": 0.4, "hcol": Color(0.9, 0.55, 0.2), "p": [Color(1.0, 0.85, 0.5), 0.6, Vector3(0, 0.03, 0), 1.2]},
]

var camera: Node3D = null
var courant: int = 0
var ciel: MeshInstance3D
var poussiere: MeshInstance3D
var m_ciel: ShaderMaterial
var m_pous: ShaderMaterial


func _ready() -> void:
	ciel = MeshInstance3D.new()
	var sp: SphereMesh = SphereMesh.new()
	sp.radius = 200.0
	sp.height = 400.0
	sp.radial_segments = 40
	sp.rings = 20
	ciel.mesh = sp
	m_ciel = ShaderMaterial.new()
	m_ciel.shader = load("res://shaders/ciel.gdshader")
	m_ciel.render_priority = -100
	ciel.material_override = m_ciel
	ciel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ciel.top_level = true
	ciel.extra_cull_margin = 1000.0
	add_child(ciel)

	poussiere = MeshInstance3D.new()
	poussiere.mesh = _mesh_poussiere(650)
	m_pous = ShaderMaterial.new()
	m_pous.shader = load("res://shaders/poussiere.gdshader")
	poussiere.material_override = m_pous
	poussiere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	poussiere.extra_cull_margin = 1000.0
	poussiere.top_level = true
	add_child(poussiere)
	appliquer(0)


func _mesh_poussiere(n: int) -> ArrayMesh:
	var r: RandomNumberGenerator = RandomNumberGenerator.new()
	r.seed = 4242
	var v: PackedVector3Array = PackedVector3Array()
	var uv: PackedVector2Array = PackedVector2Array()
	var uv2: PackedVector2Array = PackedVector2Array()
	var c: PackedColorArray = PackedColorArray()
	var idx: PackedInt32Array = PackedInt32Array()
	for i in n:
		var s: Vector3 = Vector3(r.randf(), r.randf(), r.randf())
		var taille: float = 0.5 + r.randf() * 1.5
		var vit: float = 0.4 + r.randf() * 1.2
		var lum: float = 0.35 + r.randf() * 0.65
		var k: int = v.size()
		for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
			v.append(s)
			uv.append(q)
			uv2.append(Vector2(taille, vit))
			c.append(Color(lum, lum, lum, 1.0))
		idx.append_array(PackedInt32Array([k, k + 1, k + 2, k + 2, k + 1, k + 3]))
	var a: Array = []
	a.resize(Mesh.ARRAY_MAX)
	a[Mesh.ARRAY_VERTEX] = v
	a[Mesh.ARRAY_TEX_UV] = uv
	a[Mesh.ARRAY_TEX_UV2] = uv2
	a[Mesh.ARRAY_COLOR] = c
	a[Mesh.ARRAY_INDEX] = idx
	var m: ArrayMesh = ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a)
	m.custom_aabb = AABB(Vector3(-1000, -1000, -1000), Vector3(2000, 2000, 2000))
	return m


func actif() -> bool:
	return courant > 0


func appliquer(i: int) -> void:
	courant = clampi(i, 0, DEF.size() - 1)
	var d: Dictionary = DEF[courant]
	ciel.visible = courant > 0
	poussiere.visible = courant > 0
	if courant == 0:
		return
	m_ciel.set_shader_parameter("haut", d.get("haut", Color.BLACK))
	m_ciel.set_shader_parameter("bas", d.get("bas", Color.BLACK))
	m_ciel.set_shader_parameter("etoiles", float(d.get("etoiles", 0.0)))
	m_ciel.set_shader_parameter("neb", float(d.get("neb", 0.0)))
	m_ciel.set_shader_parameter("neb1", d.get("n1", Color(0.5, 0.1, 0.6)))
	m_ciel.set_shader_parameter("neb2", d.get("n2", Color(0.1, 0.3, 0.7)))
	m_ciel.set_shader_parameter("aurore", float(d.get("aurore", 0.0)))
	m_ciel.set_shader_parameter("pluie", float(d.get("pluie", 0.0)))
	m_ciel.set_shader_parameter("rayons", float(d.get("rayons", 0.0)))
	m_ciel.set_shader_parameter("horizon", float(d.get("horizon", 0.0)))
	m_ciel.set_shader_parameter("horizon_col", d.get("hcol", Color(1, 0.5, 0.3)))
	var p: Array = d["p"]
	var col: Color = p[0]
	m_pous.set_shader_parameter("couleur", Color(col.r, col.g, col.b, float(p[1])))
	m_pous.set_shader_parameter("deriv", p[2])
	m_pous.set_shader_parameter("taille", 0.03 * float(p[3]))


func _process(_dt: float) -> void:
	if camera == null or courant == 0:
		return
	ciel.global_position = camera.global_position
	poussiere.global_position = Vector3.ZERO
