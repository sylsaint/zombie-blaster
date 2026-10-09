extends GutTest

const _Clock := preload("res://scripts/game_clock.gd")


func test_real_meshes_stay_inside_the_triangle_budget() -> void:
	assert_lte(_tris(SoldierVisuals.body_mesh(1)), 450)
	assert_lte(_tris(SoldierVisuals.body_mesh(2)), 450)
	assert_lte(_tris(SoldierVisuals.body_mesh(3)), 450)
	assert_lte(_tris(SoldierVisuals.weapon_mesh(1)), 120)
	assert_lte(_tris(SoldierVisuals.weapon_mesh(2)), 120)
	assert_lte(_tris(SoldierVisuals.weapon_mesh(3)), 120)
	assert_lte(_tris(SoldierVisuals.weapon_mesh(4)), 120)
	assert_lte(_tris(SoldierVisuals.weapon_mesh(5)), 120)
	var walker := EnemyCatalog.walker()
	var runner := EnemyCatalog.runner()
	var elite := EnemyCatalog.elite()
	var boss := EnemyCatalog.boss()
	assert_lte(_tris(ModelResolver.resolve(walker.mesh_high, PlaceholderMeshes.grunt())), 450)
	assert_lte(_tris(ModelResolver.resolve(walker.mesh_low, PlaceholderMeshes.walker_lod())), 200)
	assert_lte(_tris(ModelResolver.resolve(runner.mesh_high, PlaceholderMeshes.runner())), 450)
	assert_lte(_tris(ModelResolver.resolve(runner.mesh_low, PlaceholderMeshes.runner_lod())), 200)
	assert_lte(_tris(ModelResolver.resolve(elite.mesh_high, PlaceholderMeshes.elite())), 1500)
	var boss_node := ModelResolver.instantiate_boss()
	assert_not_null(boss_node)
	add_child_autofree(boss_node)
	var boss_tris := 0
	var weak_mesh: Mesh = null
	for mesh_node in _collect_mesh_nodes(boss_node):
		boss_tris += _tris(mesh_node.mesh)
		if String(mesh_node.name) == "weakpoint":
			weak_mesh = mesh_node.mesh
	assert_not_null(weak_mesh)
	assert_gt(_tris(weak_mesh), 0)
	assert_lte(boss_tris, 5000)
	var center := weak_mesh.get_aabb().get_center()
	assert_almost_eq(center.x, 0.03, 0.08)
	assert_almost_eq(center.y, 4.77, 0.08)
	assert_almost_eq(center.z, -0.44, 0.08)


func test_boss_data_records_the_art_collision_circle() -> void:
	var boss := EnemyCatalog.boss()
	assert_eq(boss.id, "boss_mutant")
	assert_eq(boss.kind, EnemyArchetype.KIND_BOSS)
	assert_eq(boss.mesh_high.get_file(), "boss_mutant.glb")
	assert_almost_eq(boss.radius, 2.7, 0.001)
	assert_almost_eq(boss.offset_x, 0.4, 0.001)
	assert_almost_eq(boss.offset_z, -0.6, 0.001)


func test_palette_material_is_shared_and_nearest() -> void:
	var view := CrowdView.new()
	add_child_autofree(view)
	view.setup()
	assert_false(view.walker_high_fallback)
	assert_false(view.walker_low_fallback)
	assert_false(view.runner_high_fallback)
	assert_false(view.runner_low_fallback)
	assert_false(view.boss_fallback)
	assert_false(view.toon.cel_enabled)
	assert_false(view.toon.rim_enabled)
	assert_false(view.toon.outline_enabled)
	assert_eq(view.runner_mm.material_override, view.shared_material)
	assert_eq(view.elite_mm.material_override, view.shared_material)
	assert_eq(view.boss_mm.material_override, view.shared_material)
	assert_null(view.get_node_or_null("BossWeakpoint"))
	assert_eq(view.squad_body_mm.material_override, view.shared_material)
	assert_eq(view.squad_weapon_mm.material_override, view.shared_material)
	assert_almost_eq(float(view.shared_material.get_shader_parameter("use_mesh_uv")), 1.0, 0.001)
	assert_almost_eq(float(view.shared_material.get_shader_parameter("wobble_enabled")), 0.0, 0.001)
	assert_almost_eq(float(view.shared_material.get_shader_parameter("vat_enabled")), 0.0, 0.001)
	assert_ne(view.walker_high_material, view.shared_material)
	assert_ne(view.walker_low_material, view.shared_material)
	assert_eq(view.grunt_mm.material_override, view.walker_high_material)
	assert_eq(view.walker_lod_mm.material_override, view.walker_low_material)
	assert_almost_eq(float(view.walker_high_material.get_shader_parameter("vat_enabled")), 1.0, 0.001)
	assert_almost_eq(float(view.walker_low_material.get_shader_parameter("vat_enabled")), 1.0, 0.001)
	var palette: Texture2D = view.shared_material.get_shader_parameter("palette")
	assert_eq(view.walker_high_material.get_shader_parameter("palette"), palette)
	assert_eq(view.walker_low_material.get_shader_parameter("palette"), palette)
	assert_eq(palette.resource_path, "res://assets/textures/palette.png")
	var shader := FileAccess.get_file_as_string("res://assets/vfx/crowd_instance.gdshader")
	assert_true(shader.contains("filter_nearest"))
	assert_true(shader.contains("use_mesh_uv"))
	assert_true(shader.contains("dFdx(vat_view_pos)"))
	var vat_src := FileAccess.get_file_as_string("res://assets/vfx/vat_sample.gdshaderinc")
	assert_true(vat_src.contains("texelFetch"))
	assert_true(vat_src.contains("global uniform float game_time"))
	var boss_view := BossView.new()
	add_child_autofree(boss_view)
	boss_view.setup(null)
	assert_false(boss_view.using_greybox)
	assert_eq(String(boss_view.weakpoint.name), "weakpoint")
	var weak_shader := FileAccess.get_file_as_string("res://assets/vfx/boss_weakpoint.gdshader")
	assert_true(weak_shader.contains("emission_strength"))
	assert_true(weak_shader.contains("flash"))
	assert_almost_eq(boss_view.weakpoint_emission(), 0.0, 0.001)
	assert_almost_eq(boss_view.weakpoint_flash(), 0.0, 0.001)


func test_import_bakes_outline_normals_into_vertex_color() -> void:
	for path in [
		"res://assets/models/chr_soldier_a.glb",
		"res://assets/models/wpn_pistol.glb",
		"res://assets/models/enm_walker.glb",
		"res://assets/models/enm_walker_lod1.glb",
		"res://assets/models/enm_elite_brute.glb",
		"res://assets/models/boss_mutant.glb",
	]:
		var packed := load(path) as PackedScene
		assert_not_null(packed, path)
		var root := packed.instantiate()
		add_child_autofree(root)
		var meshes := _collect_meshes(root)
		assert_gt(meshes.size(), 0, path)
		for mesh in meshes:
			_assert_outline_baked(mesh, path)
			_assert_one_triangle_stays_flat(mesh, path)


func test_weapons_share_the_soldier_transform_and_bullets_leave_the_muzzle() -> void:
	var clock = autofree(_Clock.new())
	var sim := CombatSim.new(clock, 4, 4)
	sim.separation_enabled = false
	sim.contact_enabled = false
	sim.squad.count = 3
	sim.squad.forward_speed = 0.0
	sim.squad.position = Vector3(1.5, 0.0, -6.0)
	sim.squad.weapon = WeaponCatalog.tier(2)
	sim.squad.set_cooldown(10.0)
	sim.tick(0.0)
	var view := CrowdView.new()
	add_child_autofree(view)
	view.setup()
	view.sync(sim)
	assert_eq(view.squad_body_mm.multimesh.visible_instance_count, 3)
	assert_eq(view.squad_weapon_mm.multimesh.visible_instance_count, 3)
	assert_almost_eq(view._buf_squad[3], view._buf_weapon[3], 0.0001)
	assert_almost_eq(view._buf_squad[7], view._buf_weapon[7], 0.0001)
	assert_almost_eq(view._buf_squad[11], view._buf_weapon[11], 0.0001)
	sim.squad.set_cooldown(0.0)
	sim.tick(0.0)
	var muzzle: Vector3 = sim.squad.weapon.muzzle_offset
	var found := false
	var i := 0
	while i < sim.bullets.capacity:
		if sim.bullets.alive[i] != 0:
			found = true
			assert_almost_eq(sim.bullets.x[i], sim.squad.position.x + muzzle.x, 0.001)
			assert_almost_eq(sim.bullets.y[i], sim.squad.position.y + muzzle.y, 0.001)
			assert_almost_eq(sim.bullets.z[i], sim.squad.position.z + muzzle.z, 0.001)
			assert_gt(sim.bullets.y[i], 0.4)
		i += 1
	assert_true(found)
	view.sync(sim)
	assert_almost_eq(view._buf_bullet[7], sim.squad.position.y + muzzle.y, 0.001)


func _tris(mesh: Mesh) -> int:
	return PlaceholderMeshes.triangle_count(mesh)


func _assert_outline_baked(mesh: Mesh, path: String) -> void:
	for surface in mesh.get_surface_count():
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		assert_eq(colors.size(), vertices.size(), "%s surface %d" % [path, surface])
		var expected := OutlineNormals.smoothed_colors(vertices, normals)
		var i := 0
		while i < colors.size():
			assert_true(_color_within_8bit(colors[i], expected[i]), "%s vertex %d" % [path, i])
			i += 1


func _assert_one_triangle_stays_flat(mesh: Mesh, path: String) -> void:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indexes: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	assert_gte(indexes.size(), 3, path)
	var i0 := indexes[0]
	var i1 := indexes[1]
	var i2 := indexes[2]
	var face := (vertices[i1] - vertices[i0]).cross(vertices[i2] - vertices[i0])
	if face.length_squared() <= 0.0000001:
		return
	face = face.normalized()
	# glTF is counter-clockwise. Godot stores clockwise front faces, so the
	# right-handed cross product points opposite the imported normal.
	assert_gt(absf(normals[i0].dot(face)), 0.99, path)
	assert_gt(absf(normals[i1].dot(face)), 0.99, path)
	assert_gt(absf(normals[i2].dot(face)), 0.99, path)
	assert_gt(absf(normals[i0].dot(normals[i1])), 0.99, path)
	assert_gt(absf(normals[i1].dot(normals[i2])), 0.99, path)


func _collect_mesh_nodes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		found.append(node as MeshInstance3D)
	for child in node.get_children():
		found.append_array(_collect_mesh_nodes(child))
	return found


func _collect_meshes(node: Node) -> Array:
	var found: Array = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		found.append((node as MeshInstance3D).mesh)
	for child in node.get_children():
		found.append_array(_collect_meshes(child))
	return found


func _color_within_8bit(got: Color, expected: Color) -> bool:
	var step := 1.0 / 255.0
	return absf(got.r - expected.r) <= step \
		and absf(got.g - expected.g) <= step \
		and absf(got.b - expected.b) <= step \
		and absf(got.a - expected.a) <= step
