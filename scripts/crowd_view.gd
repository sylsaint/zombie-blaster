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
var profile: SimProfile
var _buf_grunt := PackedFloat32Array()
var _buf_elite := PackedFloat32Array()
var _buf_boss := PackedFloat32Array()
var _buf_blob := PackedFloat32Array()
var _buf_bullet := PackedFloat32Array()
var _buf_squad := PackedFloat32Array()


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
	_buf_grunt = _make_buffer(grunt_mm)
	_buf_elite = _make_buffer(elite_mm)
	_buf_boss = _make_buffer(boss_mm)
	_buf_blob = _make_buffer(blob_mm)
	_buf_bullet = _make_buffer(bullet_mm)
	_buf_squad = _make_buffer(squad_mm)


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
	var t0 := Time.get_ticks_usec()
	var tw := Time.get_ticks_usec()
	var n_grunt := _write_kind(_buf_grunt, 16, sim, EnemyPool.Archetype.GRUNT, GRUNT_CAP, false)
	var n_elite := _write_kind(_buf_elite, 16, sim, EnemyPool.Archetype.ELITE, ELITE_CAP, true)
	var n_boss := _write_kind(_buf_boss, 16, sim, EnemyPool.Archetype.BOSS, BOSS_CAP, true)
	var n_blob := _write_blobs(sim)
	var n_bullet := _write_bullets(sim)
	var n_squad := _write_squad(sim)
	var t_upload := Time.get_ticks_usec()
	_commit(grunt_mm, _buf_grunt, n_grunt)
	_commit(elite_mm, _buf_elite, n_elite)
	_commit(boss_mm, _buf_boss, n_boss)
	_commit(blob_mm, _buf_blob, n_blob)
	_commit(bullet_mm, _buf_bullet, n_bullet)
	_commit(squad_mm, _buf_squad, n_squad)
	if profile != null:
		profile.view_write_us += int(t_upload - tw)
		profile.view_upload_us += int(Time.get_ticks_usec() - t_upload)
		profile.view_us += int(Time.get_ticks_usec() - t0)


func _write_kind(buf: PackedFloat32Array, stride: int, sim: CombatSim, kind: int, cap: int, flip: bool) -> int:
	var pool := sim.enemies
	var ids := pool.active_ids
	var states := pool.state
	var kinds := pool.archetype
	var xs := pool.x
	var zs := pool.z
	var flashes := pool.flash_left
	var dissolves := pool.dissolve_left
	var frames := pool.vat_frame
	var variants := pool.variant
	var n := 0
	var a := 0
	var xx := -1.0 if flip else 1.0
	var zz := -1.0 if flip else 1.0
	while a < pool.active_n and n < cap:
		var i := ids[a]
		a += 1
		if states[i] == EnemyPool.State.FREE or kinds[i] != kind:
			continue
		var o := n * stride
		buf[o + 0] = xx
		buf[o + 1] = 0.0
		buf[o + 2] = 0.0
		buf[o + 3] = xs[i]
		buf[o + 4] = 0.0
		buf[o + 5] = 1.0
		buf[o + 6] = 0.0
		buf[o + 7] = 0.0
		buf[o + 8] = 0.0
		buf[o + 9] = 0.0
		buf[o + 10] = zz
		buf[o + 11] = zs[i]
		buf[o + 12] = 1.0 if flashes[i] > 0.0 else 0.0
		var dissolve := 0.0
		if states[i] == EnemyPool.State.DYING:
			dissolve = clampf(1.0 - dissolves[i] / EnemyPool.DISSOLVE_TIME, 0.0, 1.0)
		buf[o + 13] = dissolve
		buf[o + 14] = fposmod(frames[i], 64.0) / 64.0
		buf[o + 15] = variants[i]
		n += 1
	return n


func _write_blobs(sim: CombatSim) -> int:
	var buf := _buf_blob
	var pool := sim.enemies
	var ids := pool.active_ids
	var xs := pool.x
	var zs := pool.z
	var rad := pool.radius
	var n := 0
	var a := 0
	while a < pool.active_n and n < BLOB_CAP:
		var i := ids[a]
		a += 1
		var diameter := rad[i] * 2.2
		var o := n * 12
		buf[o + 0] = diameter
		buf[o + 1] = 0.0
		buf[o + 2] = 0.0
		buf[o + 3] = xs[i]
		buf[o + 4] = 0.0
		buf[o + 5] = 1.0
		buf[o + 6] = 0.0
		buf[o + 7] = 0.04
		buf[o + 8] = 0.0
		buf[o + 9] = 0.0
		buf[o + 10] = diameter
		buf[o + 11] = zs[i]
		n += 1
	var anchor := sim.squad.position
	var offsets := sim.squad.displayed_offsets
	var s := 0
	while s < offsets.size() and n < BLOB_CAP:
		var o2 := n * 12
		buf[o2 + 0] = 0.7
		buf[o2 + 1] = 0.0
		buf[o2 + 2] = 0.0
		buf[o2 + 3] = anchor.x + offsets[s].x
		buf[o2 + 4] = 0.0
		buf[o2 + 5] = 1.0
		buf[o2 + 6] = 0.0
		buf[o2 + 7] = 0.04
		buf[o2 + 8] = 0.0
		buf[o2 + 9] = 0.0
		buf[o2 + 10] = 0.7
		buf[o2 + 11] = anchor.z + offsets[s].z
		n += 1
		s += 1
	return n


func _write_bullets(sim: CombatSim) -> int:
	var buf := _buf_bullet
	var pool := sim.bullets
	var n := 0
	var i := 0
	while i < pool.capacity and n < BULLET_CAP:
		if pool.alive[i] != 0:
			var o := n * 12
			buf[o + 0] = 1.0
			buf[o + 1] = 0.0
			buf[o + 2] = 0.0
			buf[o + 3] = pool.x[i]
			buf[o + 4] = 0.0
			buf[o + 5] = 1.0
			buf[o + 6] = 0.0
			buf[o + 7] = 1.05
			buf[o + 8] = 0.0
			buf[o + 9] = 0.0
			buf[o + 10] = 1.0
			buf[o + 11] = pool.z[i]
			n += 1
		i += 1
	return n


func _write_squad(sim: CombatSim) -> int:
	var buf := _buf_squad
	var offsets := sim.squad.displayed_offsets
	var n := mini(offsets.size(), SQUAD_CAP)
	var anchor := sim.squad.position
	var i := 0
	while i < n:
		var o := i * 12
		buf[o + 0] = 1.0
		buf[o + 1] = 0.0
		buf[o + 2] = 0.0
		buf[o + 3] = anchor.x + offsets[i].x
		buf[o + 4] = 0.0
		buf[o + 5] = 1.0
		buf[o + 6] = 0.0
		buf[o + 7] = 0.0
		buf[o + 8] = 0.0
		buf[o + 9] = 0.0
		buf[o + 10] = 1.0
		buf[o + 11] = anchor.z + offsets[i].z
		i += 1
	return n


func _commit(node: MultiMeshInstance3D, buf: PackedFloat32Array, count: int) -> void:
	var mm := node.multimesh
	mm.visible_instance_count = count
	mm.buffer = buf


func _make_buffer(node: MultiMeshInstance3D) -> PackedFloat32Array:
	var mm := node.multimesh
	var stride := 12
	if mm.use_colors:
		stride += 4
	if mm.use_custom_data:
		stride += 4
	var buf := PackedFloat32Array()
	buf.resize(mm.instance_count * stride)
	return buf


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
