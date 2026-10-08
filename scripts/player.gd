extends Node3D
## Greybox squad stand-in. Horizontal drag moves X; Z stays put until levels exist.

const _LaneMotion := preload("res://scripts/lane_motion.gd")

@export var lane_half_width: float = 3.0

@onready var _blob: MeshInstance3D = $BlobShadow


func _ready() -> void:
	# QuadMesh stands in the XY plane. Lay it on the ground as a blob shadow.
	# Decal nodes are unsupported on the Compatibility renderer.
	_blob.rotation_degrees = Vector3(-90.0, 0.0, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventScreenDrag:
		return
	var drag := event as InputEventScreenDrag
	if drag.index != 0:
		return
	var width := get_viewport().get_visible_rect().size.x
	position.x = _LaneMotion.apply_drag(position.x, drag.relative.x, width, lane_half_width)
	get_viewport().set_input_as_handled()
