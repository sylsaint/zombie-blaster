class_name ModelResolver
extends RefCounted
## Loads an authored mesh when it exists and leaves a hole for the greybox
## fallback otherwise. Model files are owned by the art pass.


const BOSS_MESH_PATH := "res://assets/models/boss_mutant.glb"


static func boss_mesh_available() -> bool:
	return ResourceLoader.exists(BOSS_MESH_PATH)


static func instantiate_boss() -> Node3D:
	if not boss_mesh_available():
		return null
	var packed: Resource = load(BOSS_MESH_PATH)
	if packed == null or not (packed is PackedScene):
		return null
	var node := (packed as PackedScene).instantiate()
	if node is Node3D:
		return node as Node3D
	if node != null:
		node.queue_free()
	return null
