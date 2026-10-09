@tool
extends EditorPlugin
## Registers the glTF/glb post-import step. Headless `--import` runs it, so
## dropped soldier and weapon models pick up outline normals without a manual pass.


var _importer: EditorScenePostImportPlugin


func _enter_tree() -> void:
	_importer = preload("res://addons/outline_normals/post_import.gd").new()
	add_scene_post_import_plugin(_importer)


func _exit_tree() -> void:
	if _importer != null:
		remove_scene_post_import_plugin(_importer)
		_importer = null
