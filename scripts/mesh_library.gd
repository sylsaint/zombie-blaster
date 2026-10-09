class_name MeshLibrary
extends RefCounted
## Resolves a data-driven mesh path. A missing glb stays on the greybox fallback.
## Real drops: enm_walker.glb, enm_walker_lod1.glb, enm_runner.glb, enm_runner_lod1.glb.


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
