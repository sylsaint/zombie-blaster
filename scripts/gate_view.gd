class_name GateView
extends Node3D
## A handful of MeshInstance3D gates. Not part of the crowd batch.


const LABEL_FONT := preload("res://assets/ui/fonts/NotoSansSC-Medium.otf")

var _spans: Array[GateSpan] = []
var _materials: Array[StandardMaterial3D] = []
var _labels: Array[Label3D] = []
var _unit: BoxMesh


func build(list: Array) -> void:
	for child in get_children():
		child.free()
	_spans.clear()
	_materials.clear()
	_labels.clear()
	if _unit == null:
		_unit = BoxMesh.new()
	for group in list:
		var gate := group as GateGroup
		if gate == null:
			continue
		for span in gate.spans:
			var leaf := span as GateSpan
			if leaf == null:
				continue
			_add_span(gate, leaf)


func refresh() -> void:
	var i := 0
	while i < _spans.size():
		var span := _spans[i]
		if span.visual_dirty:
			_materials[i].albedo_color = GateRules.color_for(span)
			_labels[i].text = GateRules.label_for(span)
			span.visual_dirty = false
		i += 1


func _add_span(group: GateGroup, span: GateSpan) -> void:
	var width := maxf(span.x_max - span.x_min, 0.2)
	var center := (span.x_min + span.x_max) * 0.5
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.albedo_color = GateRules.color_for(span)
	var mesh_node := MeshInstance3D.new()
	mesh_node.mesh = _unit
	mesh_node.material_override = mat
	mesh_node.position = Vector3(center, 1.1, group.z)
	mesh_node.scale = Vector3(width, 2.2, 0.25)
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh_node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(mesh_node)
	var label := Label3D.new()
	label.text = GateRules.label_for(span)
	label.font = LABEL_FONT
	label.position = mesh_node.position + Vector3(0.0, 1.35, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 64
	label.outline_size = 12
	label.modulate = Color(0.97, 0.96, 0.93)
	label.outline_modulate = Color(0.102, 0.102, 0.122)
	add_child(label)
	span.visual_dirty = false
	_spans.append(span)
	_materials.append(mat)
	_labels.append(label)
