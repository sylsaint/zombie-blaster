@tool
class_name OutlineNormals
extends RefCounted
## Smoothed normals for the inverted-hull outline.
## Hard-edged meshes split vertices so NORMAL cracks a hull. Vertices that
## share a position get the average of those normals, packed into COLOR
## as rgb = n * 0.5 + 0.5. The palette stays in UV. Models have no vertex
## colors of their own, so COLOR is only this outline normal.


const POSITION_QUANT := 10000.0


static func position_key(point: Vector3) -> Vector3i:
	return Vector3i(
		int(round(point.x * POSITION_QUANT)),
		int(round(point.y * POSITION_QUANT)),
		int(round(point.z * POSITION_QUANT))
	)


static func decode_normal(color: Color) -> Vector3:
	return Vector3(color.r * 2.0 - 1.0, color.g * 2.0 - 1.0, color.b * 2.0 - 1.0)


static func smoothed_colors(vertices: PackedVector3Array, normals: PackedVector3Array) -> PackedColorArray:
	var count := vertices.size()
	var colors := PackedColorArray()
	colors.resize(count)
	if count == 0 or normals.size() != count:
		return colors
	var sum := {}
	var i := 0
	while i < count:
		var key := position_key(vertices[i])
		if sum.has(key):
			sum[key] = (sum[key] as Vector3) + normals[i]
		else:
			sum[key] = normals[i]
		i += 1
	i = 0
	while i < count:
		var key: Vector3i = position_key(vertices[i])
		var acc: Vector3 = sum[key]
		if acc.length_squared() <= 0.0000001:
			acc = normals[i]
		else:
			acc = acc.normalized()
		var encoded := acc * 0.5 + Vector3(0.5, 0.5, 0.5)
		colors[i] = Color(encoded.x, encoded.y, encoded.z, 1.0)
		i += 1
	return colors


## Rewrites every surface so COLOR carries the smoothed normal. UV and UV2 stay.
static func bake_inplace(mesh: ArrayMesh) -> ArrayMesh:
	if mesh == null:
		return mesh
	var count := mesh.get_surface_count()
	if count == 0:
		return mesh
	var specs: Array = []
	for surface in count:
		var arrays: Array = mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		if vertices == null or normals == null or vertices.size() == 0 or normals.size() != vertices.size():
			return mesh
		arrays[Mesh.ARRAY_COLOR] = smoothed_colors(vertices, normals)
		specs.append({
			"prim": mesh.surface_get_primitive_type(surface),
			"arrays": arrays,
			"blends": mesh.surface_get_blend_shape_arrays(surface),
			"mat": mesh.surface_get_material(surface),
			"name": mesh.surface_get_name(surface),
		})
	mesh.clear_surfaces()
	for spec in specs:
		# Godot 4.7 exposes LOD index buffers only as a private ArrayMesh method,
		# so a COLOR rebuild cannot copy them. Imported meshes keep full geometry.
		# Godot stores COLOR as 8-bit. The hull shader normalizes after decode,
		# so that step is visually fine and there is no float color path.
		mesh.add_surface_from_arrays(spec["prim"], spec["arrays"], spec["blends"])
		var idx := mesh.get_surface_count() - 1
		mesh.surface_set_material(idx, spec["mat"])
		var surface_name := String(spec["name"])
		if surface_name != "":
			mesh.surface_set_name(idx, surface_name)
	return mesh
