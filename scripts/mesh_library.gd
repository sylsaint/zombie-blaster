class_name ModelResolver
extends RefCounted
## Resolves a data-driven mesh path. A missing glb stays on the greybox fallback.
## Real drops: chr_soldier_a/b/c, wpn_*, enm_walker, enm_walker_lod1, enm_runner,
## enm_runner_lod1, enm_elite_brute, boss_mutant (body + weakpoint).


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


## Picks the mesh whose node or material name matches. boss_mutant keeps the
## body and the weakpoint as two meshes so they can use different materials.
static func resolve_named(path: String, token: String, fallback: Mesh) -> Mesh:
	if path.is_empty() or not ResourceLoader.exists(path):
		return fallback
	var loaded: Resource = load(path)
	if not (loaded is PackedScene):
		return fallback
	var root := (loaded as PackedScene).instantiate()
	var found := _find_token(root, token)
	var copy := _detach(found)
	root.free()
	if copy == null:
		return fallback
	return copy


static func _find_mesh(resource: Resource) -> Mesh:
	if resource is Mesh:
		return resource as Mesh
	if resource is PackedScene:
		var root := (resource as PackedScene).instantiate()
		var found := _find_in_node(root)
		var copy := _detach(found)
		root.free()
		return copy
	return null


static func _detach(mesh: Mesh) -> Mesh:
	if mesh == null:
		return null
	return mesh.duplicate() as Mesh


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


static func _find_token(node: Node, token: String) -> Mesh:
	if node is MeshInstance3D:
		var mesh := (node as MeshInstance3D).mesh
		if mesh != null and _token_hit(node, mesh, token):
			return mesh
	for child in node.get_children():
		var nested := _find_token(child, token)
		if nested != null:
			return nested
	return null


static func _token_hit(node: Node, mesh: Mesh, token: String) -> bool:
	var node_name := String(node.name)
	if node_name == token or node_name.begins_with(token + "_") or node_name.begins_with(token + "-"):
		return true
	for surface in mesh.get_surface_count():
		var mat := mesh.surface_get_material(surface)
		if mat == null:
			continue
		var mat_name := String(mat.resource_name)
		if mat_name == token or mat_name == "mat_" + token:
			return true
	return false
