extends Node3D
## Horizontal drag. During a level it steers the squad; on the menu it slides the idle squad.

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
	var squad := _live_squad()
	if squad != null:
		squad.apply_drag(drag.relative.x, width)
	else:
		position.x = _LaneMotion.apply_drag(position.x, drag.relative.x, width, lane_half_width)
	get_viewport().set_input_as_handled()


func _live_squad() -> SquadAnchor:
	var parent := get_parent()
	if parent == null:
		return null
	var host := parent.get_node_or_null("LevelHost") as LevelHost
	if host == null or not host.running() or host.session == null or host.session.sim == null:
		return null
	return host.session.sim.squad
