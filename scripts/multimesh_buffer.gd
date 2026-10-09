class_name MultiMeshBuffer
extends RefCounted
## Packs TRANSFORM_3D rows plus INSTANCE_CUSTOM into MultiMesh.buffer.
## Layout matches Godot's RenderingServer: 12 basis/origin floats, then RGBA.


const STRIDE := 16


static func make_multimesh(mesh: Mesh, capacity: int, use_custom: bool) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = false
	mm.use_custom_data = use_custom
	mm.mesh = mesh
	mm.instance_count = capacity
	mm.visible_instance_count = 0
	return mm


static func upload(mm: MultiMesh, count: int, origins: PackedVector3Array, scales: PackedVector3Array, yaws: PackedFloat32Array, custom: PackedColorArray) -> void:
	var cap := mm.instance_count
	var visible := mini(count, cap)
	mm.visible_instance_count = visible
	if cap == 0:
		return
	var stride := 12
	if mm.use_colors:
		stride += 4
	if mm.use_custom_data:
		stride += 4
	var buf := PackedFloat32Array()
	buf.resize(cap * stride)
	for i in visible:
		var yaw := 0.0 if yaws.is_empty() else yaws[i]
		var scl := Vector3.ONE if scales.is_empty() else scales[i]
		var origin := origins[i]
		var basis := Basis.from_euler(Vector3(0.0, yaw, 0.0)).scaled(scl)
		var o := i * stride
		buf[o + 0] = basis.x.x
		buf[o + 1] = basis.y.x
		buf[o + 2] = basis.z.x
		buf[o + 3] = origin.x
		buf[o + 4] = basis.x.y
		buf[o + 5] = basis.y.y
		buf[o + 6] = basis.z.y
		buf[o + 7] = origin.y
		buf[o + 8] = basis.x.z
		buf[o + 9] = basis.y.z
		buf[o + 10] = basis.z.z
		buf[o + 11] = origin.z
		if mm.use_custom_data:
			var col := Color(0, 0, 0, 0) if custom.is_empty() else custom[i]
			var c := o + (16 if mm.use_colors else 12)
			buf[c + 0] = col.r
			buf[c + 1] = col.g
			buf[c + 2] = col.b
			buf[c + 3] = col.a
	mm.buffer = buf
