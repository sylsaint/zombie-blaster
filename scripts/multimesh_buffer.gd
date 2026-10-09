class_name MultiMeshBuffer
extends RefCounted
## Creates a MultiMesh whose buffer is one bulk upload per frame.
## Layout matches Godot's RenderingServer: 12 basis/origin floats, then RGBA.
## CrowdView fills that buffer in place. Do not call set_instance_transform per body.


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
