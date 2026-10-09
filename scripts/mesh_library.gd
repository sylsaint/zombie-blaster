class_name ModelResolver
extends RefCounted
## Resolves a data-driven mesh path. A missing glb stays on the greybox fallback.
## Real drops: enm_walker.glb, enm_walker_lod1.glb, enm_runner.glb, enm_runner_lod1.glb.


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
		node.free()
	return null


static func resolve(path: String, fallback: Mesh) -> Mesh:
	if fallback == null:
		return null
	if path.is_empty() or not ResourceLoader.exists(path):
		return fallback
	var loaded: Resource = load(path)
	var found := _find_mesh(loaded)
	if found == null:
		return fallback
	return found


static func _find_mesh(resource: Resource) -> Mesh:
	if resource is Mesh:
		return resource as Mesh
	if resource is PackedScene:
		var root := (resource as PackedScene).instantiate()
		var found := _find_in_node(root)
		root.free()
		return found
	return null


static func _find_in_node(node: Node) -> Mesh:
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null:
			return mesh
	if node is MultiMeshInstance3D:
		var multi := (node as MultiMeshInstance3D).multimesh
		if multi != null and multi.mesh != null:
			return multi.mesh
	for child in node.get_children():
		var nested := _find_in_node(child)
		if nested != null:
			return nested
	return null
