class_name BossView
extends Node3D
## One boss character. Authored glb when present, greybox otherwise.
## Weak-point glow targets a `weakpoint` child, else surface 1, else the greybox hump.


const LEAN_RAD := -0.55
const GLOW_ON := 3.5

var using_greybox: bool = true
var fight: BossFight
var weakpoint: GeometryInstance3D
var weak_surface: int = -1
var body_meshes: Array[MeshInstance3D] = []
var _enrage_mat: ShaderMaterial
var _weak_mat: ShaderMaterial
var _ready_done: bool = false


func setup(boss_fight: BossFight = null) -> void:
	fight = boss_fight
	if _ready_done:
		return
	_ready_done = true
	_enrage_mat = ShaderMaterial.new()
	_enrage_mat.shader = load("res://assets/vfx/boss_enrage.gdshader")
	_enrage_mat.set_shader_parameter("enrage", 0.0)
	_weak_mat = ShaderMaterial.new()
	_weak_mat.shader = load("res://assets/vfx/boss_weakpoint.gdshader")
	_weak_mat.set_shader_parameter("emission_strength", 0.0)
	_weak_mat.set_shader_parameter("flash", 0.0)
	var authored := ModelResolver.instantiate_boss()
	if authored != null:
		using_greybox = false
		authored.name = "BossModel"
		add_child(authored)
	else:
		using_greybox = true
		add_child(_make_greybox())
	_collect_bodies(self)
	_bind_weakpoint()
	for mesh in body_meshes:
		if mesh == weakpoint and weak_surface < 0:
			continue
		mesh.material_overlay = _enrage_mat


func bind(boss_fight: BossFight) -> void:
	fight = boss_fight


func sync() -> void:
	if fight == null:
		return
	position = Vector3(fight.x, 0.0, fight.z)
	var lean := LEAN_RAD if fight.leaning else 0.0
	rotation.x = lean
	var enrage := 1.0 if fight.enraged else 0.0
	_enrage_mat.set_shader_parameter("enrage", enrage)
	var flashing := 1.0 if fight.flash_left > 0.0 else 0.0
	var glow := GLOW_ON if fight.weakpoint_glow else 0.0
	_weak_mat.set_shader_parameter("flash", flashing)
	_weak_mat.set_shader_parameter("emission_strength", glow)


func enrage_amount() -> float:
	return float(_enrage_mat.get_shader_parameter("enrage"))


func weakpoint_emission() -> float:
	return float(_weak_mat.get_shader_parameter("emission_strength"))


func weakpoint_flash() -> float:
	return float(_weak_mat.get_shader_parameter("flash"))


func lean_radians() -> float:
	return rotation.x


func _make_greybox() -> Node3D:
	var root := Node3D.new()
	root.name = "BossModel"
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = PlaceholderMeshes.boss()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.49, 0.12, 0.14)
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = 0.85
	body.material_override = mat
	body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body)
	var hump := MeshInstance3D.new()
	hump.name = "weakpoint"
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.28, 0.42)
	hump.mesh = box
	hump.position = Vector3(0.0, 2.85, -0.35)
	hump.material_override = _weak_mat
	hump.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(hump)
	return root


func _collect_bodies(node: Node) -> void:
	if node is MeshInstance3D and node != weakpoint:
		body_meshes.append(node as MeshInstance3D)
	for child in node.get_children():
		_collect_bodies(child)


func _bind_weakpoint() -> void:
	var named := _find_named(self, "weakpoint")
	if named is MeshInstance3D:
		weakpoint = named
		(named as MeshInstance3D).material_override = _weak_mat
		weak_surface = -1
		return
	for mesh in body_meshes:
		if mesh.mesh != null and mesh.mesh.get_surface_count() >= 2:
			weakpoint = mesh
			weak_surface = 1
			mesh.set_surface_override_material(1, _weak_mat)
			return
	var hump := _make_greybox_hump()
	add_child(hump)
	weakpoint = hump
	weak_surface = -1


func _make_greybox_hump() -> MeshInstance3D:
	var hump := MeshInstance3D.new()
	hump.name = "weakpoint"
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.28, 0.42)
	hump.mesh = box
	hump.position = Vector3(0.0, 2.85, -0.35)
	hump.material_override = _weak_mat
	hump.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return hump


func _find_named(node: Node, wanted: String) -> Node:
	if String(node.name) == wanted:
		return node
	for child in node.get_children():
		var found := _find_named(child, wanted)
		if found != null:
			return found
	return null
