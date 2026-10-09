class_name PlaceholderMeshes
extends RefCounted
## Low-poly stand-ins. Grunt ~300 tris, elite <= 1500, boss <= 5000.


static func walker_lod() -> ArrayMesh:
	var builder := _Builder.new()
	builder.add_sphere(Vector3(0, 1.42, 0), 0.16, 5, 3)
	builder.add_cylinder(Vector3(0, 0.95, 0), 0.16, 0.5, 5, 1)
	builder.add_cylinder(Vector3(-0.26, 1.02, 0), 0.055, 0.42, 4, 1, Basis.from_euler(Vector3(0, 0, PI * 0.5)))
	builder.add_cylinder(Vector3(0.26, 1.02, 0), 0.055, 0.42, 4, 1, Basis.from_euler(Vector3(0, 0, PI * 0.5)))
	builder.add_cylinder(Vector3(-0.09, 0.34, 0), 0.07, 0.62, 4, 1)
	builder.add_cylinder(Vector3(0.09, 0.34, 0), 0.07, 0.62, 4, 1)
	return builder.commit()


static func runner() -> ArrayMesh:
	var builder := _Builder.new()
	var lean := Basis.from_euler(Vector3(-0.45, 0, 0))
	builder.add_sphere(Vector3(0, 1.55, 0.18), 0.14, 8, 4)
	builder.add_cylinder(Vector3(0, 1.05, 0.08), 0.12, 0.62, 8, 3, lean)
	builder.add_cylinder(Vector3(-0.22, 1.15, 0.2), 0.045, 0.48, 6, 2, Basis.from_euler(Vector3(0.4, 0, PI * 0.5)))
	builder.add_cylinder(Vector3(0.22, 1.15, 0.2), 0.045, 0.48, 6, 2, Basis.from_euler(Vector3(0.4, 0, -PI * 0.5)))
	builder.add_cylinder(Vector3(-0.08, 0.38, 0.05), 0.055, 0.72, 5, 3)
	builder.add_cylinder(Vector3(0.08, 0.38, -0.02), 0.055, 0.72, 5, 3)
	return builder.commit()


static func runner_lod() -> ArrayMesh:
	var builder := _Builder.new()
	builder.add_sphere(Vector3(0, 1.5, 0.16), 0.13, 5, 3)
	builder.add_cylinder(Vector3(0, 1.0, 0.08), 0.11, 0.55, 5, 1, Basis.from_euler(Vector3(-0.4, 0, 0)))
	builder.add_cylinder(Vector3(-0.2, 1.1, 0.16), 0.04, 0.4, 4, 1, Basis.from_euler(Vector3(0.3, 0, PI * 0.5)))
	builder.add_cylinder(Vector3(0.2, 1.1, 0.16), 0.04, 0.4, 4, 1, Basis.from_euler(Vector3(0.3, 0, -PI * 0.5)))
	builder.add_cylinder(Vector3(-0.07, 0.34, 0.04), 0.05, 0.64, 4, 1)
	builder.add_cylinder(Vector3(0.07, 0.34, 0.0), 0.05, 0.64, 4, 1)
	return builder.commit()


static func gem() -> ArrayMesh:
	var builder := _Builder.new()
	builder.add_box(Vector3(0, 0.35, 0), Vector3(0.28, 0.28, 0.28))
	return builder.commit()


static func ground_quad() -> ArrayMesh:
	var builder := _Builder.new()
	var i0 := builder.add_vert(Vector3(-0.5, 0, -0.5), Vector3.UP, Vector2(0, 0))
	var i1 := builder.add_vert(Vector3(0.5, 0, -0.5), Vector3.UP, Vector2(1, 0))
	var i2 := builder.add_vert(Vector3(-0.5, 0, 0.5), Vector3.UP, Vector2(0, 1))
	var i3 := builder.add_vert(Vector3(0.5, 0, 0.5), Vector3.UP, Vector2(1, 1))
	builder.add_tri(i0, i2, i1)
	builder.add_tri(i1, i2, i3)
	return builder.commit()


static func grunt() -> ArrayMesh:
	var builder := _Builder.new()
	builder.add_sphere(Vector3(0, 1.48, 0), 0.18, 8, 5)
	builder.add_cylinder(Vector3(0, 0.98, 0), 0.18, 0.55, 8, 3)
	builder.add_cylinder(Vector3(-0.28, 1.05, 0), 0.06, 0.5, 6, 2, Basis.from_euler(Vector3(0, 0, PI * 0.5)))
	builder.add_cylinder(Vector3(0.28, 1.05, 0), 0.06, 0.5, 6, 2, Basis.from_euler(Vector3(0, 0, PI * 0.5)))
	builder.add_cylinder(Vector3(-0.1, 0.36, 0), 0.08, 0.7, 6, 3)
	builder.add_cylinder(Vector3(0.1, 0.36, 0), 0.08, 0.7, 6, 3)
	return builder.commit()


static func elite() -> ArrayMesh:
	var builder := _Builder.new()
	builder.add_sphere(Vector3(0, 2.05, 0), 0.28, 12, 8)
	builder.add_cylinder(Vector3(0, 1.25, 0), 0.38, 1.05, 16, 6)
	builder.add_sphere(Vector3(-0.42, 1.7, 0), 0.16, 8, 4)
	builder.add_sphere(Vector3(0.42, 1.7, 0), 0.16, 8, 4)
	builder.add_cylinder(Vector3(-0.55, 1.35, 0), 0.1, 0.7, 10, 4, Basis.from_euler(Vector3(0, 0, PI * 0.5)))
	builder.add_cylinder(Vector3(0.55, 1.35, 0), 0.1, 0.7, 10, 4, Basis.from_euler(Vector3(0, 0, PI * 0.5)))
	builder.add_cylinder(Vector3(-0.16, 0.5, 0), 0.12, 1.0, 10, 5)
	builder.add_cylinder(Vector3(0.16, 0.5, 0), 0.12, 1.0, 10, 5)
	return builder.commit()


static func boss() -> ArrayMesh:
	var builder := _Builder.new()
	builder.add_sphere(Vector3(0, 2.7, 0), 0.42, 16, 10)
	builder.add_cylinder(Vector3(0, 1.7, 0), 0.7, 1.5, 24, 8)
	builder.add_sphere(Vector3(0, 1.55, 0.15), 0.55, 20, 12)
	builder.add_sphere(Vector3(0, 2.35, -0.2), 0.36, 16, 10)
	builder.add_cylinder(Vector3(-0.95, 1.8, 0), 0.16, 1.1, 16, 6, Basis.from_euler(Vector3(0, 0, PI * 0.5)))
	builder.add_cylinder(Vector3(0.95, 1.8, 0), 0.16, 1.1, 16, 6, Basis.from_euler(Vector3(0, 0, PI * 0.5)))
	builder.add_sphere(Vector3(-1.45, 1.8, 0), 0.22, 10, 6)
	builder.add_sphere(Vector3(1.45, 1.8, 0), 0.22, 10, 6)
	builder.add_cylinder(Vector3(-0.28, 0.65, 0), 0.2, 1.3, 16, 6)
	builder.add_cylinder(Vector3(0.28, 0.65, 0), 0.2, 1.3, 16, 6)
	return builder.commit()


static func soldier() -> ArrayMesh:
	return soldier_body(1)


## Outfit tiers from the weapon table. Tier 1 matches the original greybox soldier.
static func soldier_body(tier: int) -> ArrayMesh:
	var builder := _Builder.new()
	var bulky := tier >= 2
	builder.add_sphere(Vector3(0, 1.35, 0), 0.16 if bulky else 0.14, 6, 4)
	builder.add_cylinder(Vector3(0, 0.95, 0), 0.16 if bulky else 0.14, 0.48 if bulky else 0.45, 6, 2)
	builder.add_cylinder(Vector3(-0.22, 1.0, 0), 0.05, 0.4, 5, 2, Basis.from_euler(Vector3(0, 0, PI * 0.5)))
	builder.add_cylinder(Vector3(0.22, 1.0, 0), 0.05, 0.4, 5, 2, Basis.from_euler(Vector3(0, 0, PI * 0.5)))
	builder.add_cylinder(Vector3(-0.08, 0.35, 0), 0.06, 0.6, 5, 2)
	builder.add_cylinder(Vector3(0.08, 0.35, 0), 0.06, 0.6, 5, 2)
	if tier >= 2:
		builder.add_box(Vector3(-0.28, 1.16, 0), Vector3(0.14, 0.08, 0.16))
		builder.add_box(Vector3(0.28, 1.16, 0), Vector3(0.14, 0.08, 0.16))
	if tier >= 3:
		builder.add_box(Vector3(0, 1.02, 0.1), Vector3(0.22, 0.26, 0.08))
	return builder.commit()


## Weapon meshes sit in soldier local space so they share the body transform.
static func weapon_mesh(tier: int) -> ArrayMesh:
	var builder := _Builder.new()
	var along_z := Basis.from_euler(Vector3(PI * 0.5, 0.0, 0.0))
	match clampi(tier, 1, 5):
		1:
			builder.add_box(Vector3(0.28, 1.02, -0.16), Vector3(0.06, 0.1, 0.26))
		2:
			builder.add_box(Vector3(0.26, 1.05, -0.3), Vector3(0.05, 0.07, 0.62))
			builder.add_box(Vector3(0.26, 0.98, -0.08), Vector3(0.04, 0.12, 0.08))
		3:
			builder.add_box(Vector3(0.26, 1.02, -0.2), Vector3(0.1, 0.1, 0.36))
			builder.add_box(Vector3(0.2, 1.02, -0.36), Vector3(0.04, 0.04, 0.18))
			builder.add_box(Vector3(0.32, 1.02, -0.36), Vector3(0.04, 0.04, 0.18))
		4:
			builder.add_box(Vector3(0.24, 1.02, -0.32), Vector3(0.08, 0.08, 0.55))
			builder.add_cylinder(Vector3(0.24, 1.02, -0.62), 0.045, 0.4, 6, 1, along_z)
		_:
			builder.add_cylinder(Vector3(0.22, 1.06, -0.28), 0.07, 0.55, 6, 1, along_z)
			builder.add_box(Vector3(0.22, 0.94, -0.06), Vector3(0.06, 0.16, 0.1))
	return builder.commit()


static func bullet() -> ArrayMesh:
	var builder := _Builder.new()
	builder.add_box(Vector3(0, 0, 0), Vector3(0.12, 0.12, 0.42))
	return builder.commit()


static func blob() -> ArrayMesh:
	var builder := _Builder.new()
	# Unit quad in the XY plane. The instance transform lays it on the ground.
	var i0 := builder.add_vert(Vector3(-0.5, -0.5, 0), Vector3(0, 0, 1), Vector2(0, 0))
	var i1 := builder.add_vert(Vector3(0.5, -0.5, 0), Vector3(0, 0, 1), Vector2(1, 0))
	var i2 := builder.add_vert(Vector3(-0.5, 0.5, 0), Vector3(0, 0, 1), Vector2(0, 1))
	var i3 := builder.add_vert(Vector3(0.5, 0.5, 0), Vector3(0, 0, 1), Vector2(1, 1))
	builder.add_tri(i0, i2, i1)
	builder.add_tri(i1, i2, i3)
	return builder.commit()


static func triangle_count(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var total := 0
	for surface in mesh.get_surface_count():
		var indexes: PackedInt32Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_INDEX]
		if indexes != null:
			total += indexes.size() / 3
	return total


class _Builder:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()

	func add_vert(p: Vector3, n: Vector3, tex: Vector2 = Vector2.ZERO) -> int:
		vertices.append(p)
		normals.append(n.normalized() if n.length_squared() > 0.0 else Vector3.UP)
		uv.append(tex)
		return vertices.size() - 1

	func add_tri(a: int, b: int, c: int) -> void:
		indices.append(a)
		indices.append(b)
		indices.append(c)

	func add_box(center: Vector3, size: Vector3) -> void:
		var hx := size.x * 0.5
		var hy := size.y * 0.5
		var hz := size.z * 0.5
		var faces := [
			[Vector3(0, 0, 1), Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz), Vector3(-hx, hy, hz), Vector3(hx, hy, hz)],
			[Vector3(0, 0, -1), Vector3(hx, -hy, -hz), Vector3(-hx, -hy, -hz), Vector3(hx, hy, -hz), Vector3(-hx, hy, -hz)],
			[Vector3(1, 0, 0), Vector3(hx, -hy, hz), Vector3(hx, -hy, -hz), Vector3(hx, hy, hz), Vector3(hx, hy, -hz)],
			[Vector3(-1, 0, 0), Vector3(-hx, -hy, -hz), Vector3(-hx, -hy, hz), Vector3(-hx, hy, -hz), Vector3(-hx, hy, hz)],
			[Vector3(0, 1, 0), Vector3(-hx, hy, hz), Vector3(hx, hy, hz), Vector3(-hx, hy, -hz), Vector3(hx, hy, -hz)],
			[Vector3(0, -1, 0), Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz)],
		]
		for face in faces:
			var n: Vector3 = face[0]
			var a := add_vert(center + face[1], n, Vector2(0, 0))
			var b := add_vert(center + face[2], n, Vector2(1, 0))
			var c := add_vert(center + face[3], n, Vector2(0, 1))
			var d := add_vert(center + face[4], n, Vector2(1, 1))
			add_tri(a, c, b)
			add_tri(b, c, d)

	func add_sphere(center: Vector3, radius: float, segments: int, rings: int) -> void:
		var seg := maxi(segments, 3)
		var ring := maxi(rings, 2)
		var north := add_vert(center + Vector3(0, radius, 0), Vector3.UP, Vector2(0.5, 0))
		var ring_start := vertices.size()
		for lat in range(1, ring):
			var v := float(lat) / float(ring)
			var phi := v * PI
			for lon in seg:
				var u := float(lon) / float(seg)
				var theta := u * TAU
				var n := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta))
				add_vert(center + n * radius, n, Vector2(u, v))
		var south := add_vert(center + Vector3(0, -radius, 0), Vector3.DOWN, Vector2(0.5, 1))
		for lon in seg:
			var b := ring_start + lon
			var c := ring_start + (lon + 1) % seg
			add_tri(north, c, b)
		var bands := ring - 2
		for lat in bands:
			for lon in seg:
				var i0 := ring_start + lat * seg + lon
				var i1 := ring_start + lat * seg + (lon + 1) % seg
				var i2 := ring_start + (lat + 1) * seg + lon
				var i3 := ring_start + (lat + 1) * seg + (lon + 1) % seg
				add_tri(i0, i2, i1)
				add_tri(i1, i2, i3)
		var last := ring_start + (ring - 2) * seg
		for lon in seg:
			var b := last + lon
			var c := last + (lon + 1) % seg
			add_tri(south, b, c)

	func add_cylinder(center: Vector3, radius: float, height: float, segments: int, stacks: int, orient: Basis = Basis.IDENTITY) -> void:
		var seg := maxi(segments, 3)
		var stack := maxi(stacks, 1)
		var start := vertices.size()
		for s in stack + 1:
			var t := float(s) / float(stack)
			var y := -height * 0.5 + t * height
			for lon in seg:
				var theta := TAU * float(lon) / float(seg)
				var n := Vector3(cos(theta), 0, sin(theta))
				var local := Vector3(n.x * radius, y, n.z * radius)
				add_vert(center + orient * local, orient * n, Vector2(float(lon) / float(seg), t))
		for s in stack:
			for lon in seg:
				var i0 := start + s * seg + lon
				var i1 := start + s * seg + (lon + 1) % seg
				var i2 := start + (s + 1) * seg + lon
				var i3 := start + (s + 1) * seg + (lon + 1) % seg
				add_tri(i0, i2, i1)
				add_tri(i1, i2, i3)
		var bottom := add_vert(center + orient * Vector3(0, -height * 0.5, 0), orient * Vector3.DOWN)
		var top := add_vert(center + orient * Vector3(0, height * 0.5, 0), orient * Vector3.UP)
		for lon in seg:
			var b0 := start + lon
			var b1 := start + (lon + 1) % seg
			add_tri(bottom, b1, b0)
			var t0 := start + stack * seg + lon
			var t1 := start + stack * seg + (lon + 1) % seg
			add_tri(top, t0, t1)

	func commit() -> ArrayMesh:
		var uv2 := PackedVector2Array()
		uv2.resize(vertices.size())
		var count := maxi(vertices.size(), 1)
		for i in vertices.size():
			uv2[i] = Vector2((float(i) + 0.5) / float(count), 0.0)
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TEX_UV] = uv
		arrays[Mesh.ARRAY_TEX_UV2] = uv2
		arrays[Mesh.ARRAY_INDEX] = indices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		return OutlineNormals.bake_inplace(mesh)
