class_name TraitDessin
extends RefCounted

var points: PackedVector2Array = PackedVector2Array()
var vit: PackedFloat32Array = PackedFloat32Array()
var reglages: Reglages
var rang: int = 0
var calque: int = 0
var fige: bool = false
var cache: PackedVector2Array = PackedVector2Array()
var cache_vit: PackedFloat32Array = PackedFloat32Array()
var a_cache: bool = false
var noeud: MeshInstance3D = null


func _init(r: Reglages, rg: int) -> void:
	reglages = r
	rang = rg


func ajouter(p: Vector2) -> void:
	if points.is_empty():
		vit.append(0.0)
	else:
		vit.append(p.distance_to(points[points.size() - 1]))
	points.append(p)


func oublier() -> void:
	a_cache = false
	cache = PackedVector2Array()
	cache_vit = PackedFloat32Array()
