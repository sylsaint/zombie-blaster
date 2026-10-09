class_name CrowdView
extends Node3D
## One MultiMesh per body mesh, plus blobs, bullets, and the squad.
## Instance count changes do not add nodes or materials.


const GRUNT_CAP := 320
const ELITE_CAP := 8
const BOSS_CAP := 2
const BULLET_CAP := 64
const SQUAD_CAP := 40
const BLOB_CAP := 380

var shared_material: ShaderMaterial
var grunt_mm: MultiMeshInstance3D
var elite_mm: MultiMeshInstance3D
var boss_mm: MultiMeshInstance3D
var blob_mm: MultiMeshInstance3D
var bullet_mm: MultiMeshInstance3D
var squad_mm: MultiMeshInstance3D

var _grunt_mesh: ArrayMesh
var _elite_mesh: ArrayMesh
var _boss_mesh: ArrayMesh
var _soldier_mesh: ArrayMesh


func setup() -> void:
	if shared_material != null:
		return
	_grunt_mesh = PlaceholderMeshes.grunt()
	_elite_mesh = PlaceholderMeshes.elite()
	_boss_mesh = PlaceholderMeshes.boss()
	_soldier_mesh = PlaceholderMeshes.soldier()
	shared_material = _make_material()
	var bullet_mat := StandardMaterial3D.new()
	bullet_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bullet_mat.albedo_color = Color(1.0, 0.86, 0.25)
	bullet_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	var squad_mat := StandardMaterial3D.new()
	squad_mat.albedo_color = Color(0.32, 0.55, 0.86)
	squad_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	squad_mat.roughness = 0.85
	var blob_mat := ShaderMaterial.new()
	blob_mat.shader = load("res://assets/vfx/blob_shadow_clip.gdshader")

	grunt_mm = _add_body("Grunts", _grunt_mesh, GRUNT_CAP, shared_material)
	elite_mm = _add_body("Elites", _elite_mesh, ELITE_CAP, shared_material)
	boss_mm = _add_body("Boss", _boss_mesh, BOSS_CAP, shared_material)
	blob_mm = _add_plain("Blobs", PlaceholderMeshes.blob(), BLOB_CAP, blob_mat, false)
	bullet_mm = _add_plain("Bullets", PlaceholderMeshes.bullet(), BULLET_CAP, bullet_mat, false)
	squad_mm = _add_plain("Squad", _soldier_mesh, SQUAD_CAP, squad_mat, false)


func logical_batch_count() -> int:
	var n := 0
	for child in get_children():
		if child is MultiMeshInstance3D:
			n += 1
	return n


func visible_body_instances() -> int:
	var n := 0
	for node in [grunt_mm, elite_mm, boss_mm]:
		if node and node.multimesh:
			n += node.multimesh.visible_instance_count
	return n


func sync(sim: CombatSim) -> void:
	_upload_kind(grunt_mm, sim, EnemyPool.Archetype.GRUNT, GRUNT_CAP, 0.0)
	_upload_kind(elite_mm, sim, EnemyPool.Archetype.ELITE, ELITE_CAP, PI)
	_upload_kind(boss_mm, sim, EnemyPool.Archetype.BOSS, BOSS_CAP, PI)
	_upload_blobs(sim)
	_upload_bullets(sim)
	_upload_squad(sim)


func _upload_kind(node: MultiMeshInstance3D, sim: CombatSim, kind: int, cap: int, yaw: float) -> void:
	var origins := PackedVector3Array()
	var scales := PackedVector3Array()
	var yaws := PackedFloat32Array()
	var custom := PackedColorArray()
	origins.resize(cap)
	scales.resize(cap)
	yaws.resize(cap)
	custom.resize(cap)
	var n := 0
	var pool := sim.enemies
	for i in pool.capacity:
		if n >= cap:
			break
		if pool.state[i] == EnemyPool.State.FREE or pool.archetype[i] != kind:
			continue
		origins[n] = Vector3(pool.x[i], 0.0, pool.z[i])
		scales[n] = Vector3.ONE
		yaws[n] = yaw
		var frame := fposmod(pool.vat_frame[i], 64.0) / 64.0
		custom[n] = Color(pool.flash_amount(i), pool.dissolve_amount(i), frame, pool.variant[i])
		n += 1
	MultiMeshBuffer.upload(node.multimesh, n, origins, scales, yaws, custom)


func _upload_blobs(sim: CombatSim) -> void:
	var origins := PackedVector3Array()
	var scales := PackedVector3Array()
	var yaws := PackedFloat32Array()
	origins.resize(BLOB_CAP)
	scales.resize(BLOB_CAP)
	yaws.resize(BLOB_CAP)
	var n := 0
	var pool := sim.enemies
	for i in pool.capacity:
		if n >= BLOB_CAP:
			break
		if pool.state[i] == EnemyPool.State.FREE:
			continue
		var diameter := pool.radius[i] * 2.2
		origins[n] = Vector3(pool.x[i], 0.04, pool.z[i])
		scales[n] = Vector3(diameter, 1.0, diameter)
		yaws[n] = 0.0
		n += 1
	for offset in sim.squad.displayed_offsets:
		if n >= BLOB_CAP:
			break
		origins[n] = Vector3(sim.squad.position.x + offset.x, 0.04, sim.squad.position.z + offset.z)
		scales[n] = Vector3(0.7, 1.0, 0.7)
		yaws[n] = 0.0
		n += 1
	MultiMeshBuffer.upload(blob_mm.multimesh, n, origins, scales, yaws, PackedColorArray())


func _upload_bullets(sim: CombatSim) -> void:
	var origins := PackedVector3Array()
	var scales := PackedVector3Array()
	var yaws := PackedFloat32Array()
	origins.resize(BULLET_CAP)
	scales.resize(BULLET_CAP)
	yaws.resize(BULLET_CAP)
	var n := 0
	var pool := sim.bullets
	for i in pool.capacity:
		if pool.alive[i] == 0:
			continue
		if n >= BULLET_CAP:
			break
		origins[n] = Vector3(pool.x[i], 1.05, pool.z[i])
		scales[n] = Vector3.ONE
		yaws[n] = 0.0
		n += 1
	MultiMeshBuffer.upload(bullet_mm.multimesh, n, origins, scales, yaws, PackedColorArray())


func _upload_squad(sim: CombatSim) -> void:
	var offsets := sim.squad.displayed_offsets
	var n := mini(offsets.size(), SQUAD_CAP)
	var origins := PackedVector3Array()
	var scales := PackedVector3Array()
	var yaws := PackedFloat32Array()
	origins.resize(SQUAD_CAP)
	scales.resize(SQUAD_CAP)
	yaws.resize(SQUAD_CAP)
	for i in n:
		origins[i] = Vector3(sim.squad.position.x + offsets[i].x, 0.0, sim.squad.position.z + offsets[i].z)
		scales[i] = Vector3.ONE
		yaws[i] = 0.0
	MultiMeshBuffer.upload(squad_mm.multimesh, n, origins, scales, yaws, PackedColorArray())


func _make_material() -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/vfx/crowd_instance.gdshader")
	var image := Image.create(8, 1, false, Image.FORMAT_RGBA8)
	var colors := [
		Color(0.42, 0.5, 0.3),
		Color(0.36, 0.42, 0.26),
		Color(0.5, 0.4, 0.28),
		Color(0.33, 0.36, 0.24),
		Color(0.45, 0.22, 0.2),
		Color(0.55, 0.18, 0.16),
		Color(0.32, 0.16, 0.18),
		Color(0.62, 0.24, 0.16),
	]
	for i in colors.size():
		image.set_pixel(i, 0, colors[i])
	var tex := ImageTexture.create_from_image(image)
	mat.set_shader_parameter("palette", tex)
	mat.set_shader_parameter("vat_enabled", 0.0)
	mat.set_shader_parameter("vat_frame_count", 1.0)
	return mat


func _add_body(node_name: String, mesh: Mesh, capacity: int, mat: Material) -> MultiMeshInstance3D:
	return _add_plain(node_name, mesh, capacity, mat, true)


func _add_plain(node_name: String, mesh: Mesh, capacity: int, mat: Material, custom: bool) -> MultiMeshInstance3D:
	var inst := MultiMeshInstance3D.new()
	inst.name = node_name
	inst.multimesh = MultiMeshBuffer.make_multimesh(mesh, capacity, custom)
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	inst.custom_aabb = AABB(Vector3(-80.0, -5.0, -8000.0), Vector3(160.0, 20.0, 16000.0))
	add_child(inst)
	return inst
