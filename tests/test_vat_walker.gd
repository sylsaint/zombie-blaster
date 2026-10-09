extends GutTest

const _Clock := preload("res://scripts/game_clock.gd")


func test_missing_vat_falls_back_to_static() -> void:
	assert_null(VatClipset.for_model("res://assets/models/enm_runner.glb"))
	assert_null(VatClipset.for_model("res://assets/models/chr_soldier_a.glb"))
	assert_null(VatClipset.for_model(""))


func test_walker_clips_match_the_json() -> void:
	var high := VatClipset.for_model("res://assets/models/enm_walker.glb")
	var low := VatClipset.for_model("res://assets/models/enm_walker_lod1.glb")
	assert_not_null(high)
	assert_not_null(low)
	assert_eq(high.width, 267)
	assert_eq(high.height, 48)
	assert_eq(low.width, 116)
	assert_eq(low.height, 48)
	assert_almost_eq(high.fps, 30.0, 0.001)
	assert_almost_eq(low.fps, high.fps, 0.001)
	assert_almost_eq(high.walk_start, 0.0, 0.001)
	assert_almost_eq(high.walk_count, 24.0, 0.001)
	assert_almost_eq(high.hit_start, 24.0, 0.001)
	assert_almost_eq(high.hit_count, 8.0, 0.001)
	assert_almost_eq(high.death_start, 32.0, 0.001)
	assert_almost_eq(high.death_count, 16.0, 0.001)
	assert_almost_eq(low.walk_start, high.walk_start, 0.001)
	assert_almost_eq(low.hit_start, high.hit_start, 0.001)
	assert_almost_eq(low.death_start, high.death_start, 0.001)
	assert_almost_eq(low.walk_count, high.walk_count, 0.001)
	assert_gt(high.anim_aabb.position.z + high.anim_aabb.size.z, 1.89)
	assert_gt(low.anim_aabb.position.z + low.anim_aabb.size.z, 1.89)


func test_exr_imports_as_uncompressed_half_float() -> void:
	for path in [
		"res://assets/models/anim/enm_walker_vat.exr",
		"res://assets/models/anim/enm_walker_lod1_vat.exr",
	]:
		var tex := load(path) as Texture2D
		assert_not_null(tex, path)
		var image := tex.get_image()
		assert_not_null(image, path)
		assert_eq(image.get_format(), Image.FORMAT_RGBAH, path)
		assert_false(image.has_mipmaps(), path)
		var import_text := FileAccess.get_file_as_string(path + ".import")
		assert_true(import_text.contains("compress/mode=0"), path)
		assert_true(import_text.contains("mipmaps/generate=false"), path)
		assert_true(import_text.contains("process/hdr_clamp_exposure=false"), path)
		assert_true(import_text.contains("detect_3d/compress_to=0"), path)


func test_glb_import_keeps_authored_uv2() -> void:
	for path in [
		"res://assets/models/enm_walker.glb",
		"res://assets/models/enm_walker_lod1.glb",
	]:
		var import_text := FileAccess.get_file_as_string(path + ".import")
		assert_true(import_text.contains("meshes/light_baking=0"), path)
		assert_true(import_text.contains("meshes/generate_lods=false"), path)
		assert_true(import_text.contains("meshes/force_disable_compression=true"), path)
		assert_false(import_text.contains("meshes/light_baking=2"), path)
		var clip := VatClipset.for_model(path)
		var packed := load(path) as PackedScene
		var root := packed.instantiate()
		add_child_autofree(root)
		var mesh := _first_mesh(root)
		var uv2: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
		assert_gt(uv2.size(), 0, path)
		var width := float(clip.width)
		var i := 0
		while i < uv2.size():
			var col := int(floor(uv2[i].x * width + 0.0001))
			assert_gte(col, 0, "%s vertex %d" % [path, i])
			assert_lt(col, clip.width, "%s vertex %d" % [path, i])
			assert_almost_eq(uv2[i].x * width, float(col) + 0.5, 0.02, "%s vertex %d" % [path, i])
			assert_almost_eq(uv2[i].y, 0.5, 0.02, "%s vertex %d" % [path, i])
			i += 1


func test_mesh_custom_aabb_covers_the_death_fall() -> void:
	var view := CrowdView.new()
	add_child_autofree(view)
	view.setup()
	for node in [view.grunt_mm, view.walker_lod_mm]:
		var box: AABB = (node.multimesh.mesh as ArrayMesh).custom_aabb
		var end := box.position + box.size
		assert_lte(box.position.z, -0.5)
		assert_gte(end.z, 1.9)
		assert_gte(end.y, 1.6)
	# The crowd node stays one lane-sized cull box. The mesh box is the pose.
	assert_gt(view.grunt_mm.custom_aabb.size.z, 1000.0)


func test_phase_offset_hit_crossfade_and_death_tag() -> void:
	var clock = autofree(_Clock.new())
	var sim := CombatSim.new(clock, 8, 4)
	sim.separation_enabled = false
	sim.contact_enabled = false
	sim.squad.forward_speed = 0.0
	sim.squad.set_cooldown(10.0)
	var a := sim.enemies.spawn(EnemyPool.Archetype.GRUNT, 0.0, -4.0, 30.0, 1.6, 0.4, 0.2, EnemyPool.Species.WALKER, 1, 1)
	var b := sim.enemies.spawn(EnemyPool.Archetype.GRUNT, 1.0, -4.0, 30.0, 1.6, 0.4, 0.2, EnemyPool.Species.WALKER, 1, 1)
	assert_false(is_equal_approx(sim.enemies.vat_phase[a], sim.enemies.vat_phase[b]))
	var view := CrowdView.new()
	add_child_autofree(view)
	view.setup()
	view.sync(sim)
	assert_eq(view.grunt_mm.multimesh.visible_instance_count, 2)
	assert_almost_eq(view._buf_grunt[15], -1.0, 0.001)
	assert_almost_eq(view._buf_grunt[31], -1.0, 0.001)
	assert_false(is_equal_approx(view._buf_grunt[14], view._buf_grunt[30]))
	sim.enemies.hit(a, 1.0, 0.0, -1.0)
	sim.enemies.tick_timers(0.05)
	view.sync(sim)
	var blend: float = view._buf_grunt[15]
	assert_gt(blend, 0.0)
	assert_lt(blend, 1.0)
	assert_almost_eq(blend, (0.05 * 30.0) / VatClipset.CROSSFADE_FRAMES, 0.02)
	sim.enemies.hit(a, 999.0, 0.0, -1.0)
	view.sync(sim)
	assert_lt(view._buf_grunt[15], -1.5)
	var outline := FileAccess.get_file_as_string("res://assets/vfx/outline_hull.gdshader")
	assert_true(outline.contains("vat_offset"))
	assert_true(outline.contains("inst_custom.a < -1.5"))
	assert_not_null(view.outline_walker)
	assert_not_null(view.outline_walker_lod)
	assert_null(view.get_node_or_null("OutlineGrunts"))


func test_runner_stays_on_the_static_material() -> void:
	var view := CrowdView.new()
	add_child_autofree(view)
	view.setup()
	assert_eq(view.runner_mm.material_override, view.shared_material)
	assert_eq(view.elite_mm.material_override, view.shared_material)
	assert_eq(view.boss_mm.material_override, view.shared_material)
	assert_almost_eq(float(view.shared_material.get_shader_parameter("vat_enabled")), 0.0, 0.001)


func _first_mesh(node: Node) -> ArrayMesh:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh is ArrayMesh:
		return (node as MeshInstance3D).mesh as ArrayMesh
	for child in node.get_children():
		var found := _first_mesh(child)
		if found != null:
			return found
	return null
