class_name ToonLook
extends RefCounted
## Three independent switches. Gameplay leaves all of them off.
## Cel and rim share the crowd/squad material. The hull is a second pass
## on squad, elites, and the boss only.


var cel_enabled: bool = false
var rim_enabled: bool = false
var outline_enabled: bool = false
var crowd_material: ShaderMaterial
var squad_material: ShaderMaterial
var outline_material: ShaderMaterial

var _base_shader: Shader
var _toon_shader: Shader
var _ramp: Texture2D
var _outline_nodes: Array[MultiMeshInstance3D] = []


func setup() -> void:
	_base_shader = load("res://assets/vfx/crowd_instance.gdshader")
	_toon_shader = load("res://assets/vfx/crowd_toon.gdshader")
	_ramp = _make_ramp()
	crowd_material = ShaderMaterial.new()
	crowd_material.shader = _base_shader
	squad_material = ShaderMaterial.new()
	squad_material.shader = _base_shader
	squad_material.set_shader_parameter("use_uniform_color", 1.0)
	squad_material.set_shader_parameter("uniform_color", Color(0.184, 0.435, 0.816))
	squad_material.set_shader_parameter("wobble_enabled", 0.0)
	outline_material = ShaderMaterial.new()
	outline_material.shader = load("res://assets/vfx/outline_hull.gdshader")
	outline_material.set_shader_parameter("outline_width", 0.05)
	outline_material.set_shader_parameter("outline_color", Color(0.102, 0.102, 0.122))
	apply()


func bind_outlines(nodes: Array) -> void:
	_outline_nodes.clear()
	for node in nodes:
		if node is MultiMeshInstance3D:
			_outline_nodes.append(node)
	apply()


func apply() -> void:
	var shader := _toon_shader if cel_enabled else _base_shader
	var rim := 1.0 if rim_enabled else 0.0
	for mat in [crowd_material, squad_material]:
		if mat == null:
			continue
		if mat.shader != shader:
			mat.shader = shader
		mat.set_shader_parameter("rim_enabled", rim)
		if cel_enabled:
			mat.set_shader_parameter("cel_ramp", _ramp)
	for node in _outline_nodes:
		node.visible = outline_enabled


func _make_ramp() -> Texture2D:
	var image := Image.create(3, 1, false, Image.FORMAT_RGBA8)
	image.set_pixel(0, 0, Color(0.35, 0.35, 0.35, 1.0))
	image.set_pixel(1, 0, Color(0.68, 0.68, 0.68, 1.0))
	image.set_pixel(2, 0, Color(1.0, 1.0, 1.0, 1.0))
	return ImageTexture.create_from_image(image)
