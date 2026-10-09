@tool
extends EditorScenePostImportPlugin
## Runs on every imported scene. Hard-edged glb meshes get smoothed outline
## normals in COLOR before the packed scene is saved.


const _Normals = preload("res://scripts/outline_normals.gd")


func _get_import_options(_path: String) -> void:
	add_import_option("outline_normals/enabled", true)


func _get_option_visibility(_path: String, _for_animation: bool, _option: String) -> bool:
	return true


func _post_process(scene: Node) -> void:
	if get_option_value("outline_normals/enabled") == false:
		return
	var seen := {}
	_walk(scene, seen)


func _walk(node: Node, seen: Dictionary) -> void:
	if node is MeshInstance3D:
		var mesh_node := node as MeshInstance3D
		var mesh := mesh_node.mesh
		if mesh is ArrayMesh:
			var mesh_id := mesh.get_instance_id()
			if not seen.has(mesh_id):
				seen[mesh_id] = true
				_Normals.bake_inplace(mesh as ArrayMesh)
	for child in node.get_children():
		_walk(child, seen)
