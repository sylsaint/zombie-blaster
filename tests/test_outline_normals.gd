extends GutTest


func test_colocated_vertices_share_one_smoothed_normal() -> void:
	var vertices := PackedVector3Array([
		Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.0, 0.0),
	])
	var normals := PackedVector3Array([
		Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(0, 1, 0),
	])
	var colors := OutlineNormals.smoothed_colors(vertices, normals)
	assert_true(colors[0].is_equal_approx(colors[1]))
	assert_true(colors[1].is_equal_approx(colors[2]))
	assert_false(colors[0].is_equal_approx(colors[3]))
	var decoded := OutlineNormals.decode_normal(colors[0])
	var expected := Vector3(1, 1, 1).normalized()
	assert_almost_eq(decoded.x, expected.x, 0.001)
	assert_almost_eq(decoded.y, expected.y, 0.001)
	assert_almost_eq(decoded.z, expected.z, 0.001)
	assert_almost_eq(decoded.length(), 1.0, 0.001)


func test_greybox_box_keeps_hard_normals_and_smooth_colors() -> void:
	var mesh := PlaceholderMeshes.weapon_mesh(1)
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var uv: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var uv2: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	assert_eq(colors.size(), vertices.size())
	assert_eq(uv.size(), vertices.size())
	assert_eq(uv2.size(), vertices.size())
	var expected := OutlineNormals.smoothed_colors(vertices, normals)
	var found_split := false
	var i := 0
	while i < vertices.size():
		assert_true(_color_within_8bit(colors[i], expected[i]), "vertex %d" % i)
		var j := i + 1
		while j < vertices.size():
			if vertices[i].distance_squared_to(vertices[j]) <= 0.0000001:
				assert_true(colors[i].is_equal_approx(colors[j]))
				if not normals[i].is_equal_approx(normals[j]):
					found_split = true
			j += 1
		i += 1
	assert_true(found_split)
	var shader := FileAccess.get_file_as_string("res://assets/vfx/outline_hull.gdshader")
	assert_true(shader.contains("COLOR.rgb * 2.0 - 1.0"))
	assert_true(shader.contains("cull_front"))


func test_imported_probe_matches_the_baker() -> void:
	var packed := load("res://assets/models/outline_probe.gltf") as PackedScene
	assert_not_null(packed)
	var root := packed.instantiate()
	add_child_autofree(root)
	var mesh := _find_mesh(root)
	assert_not_null(mesh)
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	assert_eq(colors.size(), vertices.size())
	var expected := OutlineNormals.smoothed_colors(vertices, normals)
	var i := 0
	while i < colors.size():
		assert_true(_color_within_8bit(colors[i], expected[i]), "vertex %d" % i)
		i += 1


## ArrayMesh stores COLOR as 8-bit. Truncation is at most one step of 1/255.
func _color_within_8bit(got: Color, expected: Color) -> bool:
	var step := 1.0 / 255.0
	return absf(got.r - expected.r) <= step \
		and absf(got.g - expected.g) <= step \
		and absf(got.b - expected.b) <= step \
		and absf(got.a - expected.a) <= step


func _find_mesh(node: Node) -> Mesh:
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		return (node as MeshInstance3D).mesh
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null
