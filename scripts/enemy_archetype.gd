class_name EnemyArchetype
extends Resource
## One enemy type. Collision is a circle around a local center offset so an
## asymmetric mesh does not have to be centered on the actor origin.


@export var enemy_id: String = ""
@export var display_name: String = ""
@export var kind: int = 0
@export var base_hp: float = 20.0
@export var move_speed: float = 1.6
@export var weight: int = 1
@export var contact_loss: int = 1
@export var contact_interval: float = 0.5
@export var collision_radius: float = 0.4
@export var offset_x: float = 0.0
@export var offset_z: float = 0.0
## Visual mesh extents from the actor origin, in meters. Gameplay uses the
## offset circle, not these extents.
@export var mesh_extent_right: float = 0.0
@export var mesh_extent_left: float = 0.0
@export var mesh_extent_forward: float = 0.0
@export var mesh_path: String = ""


func collision_center(origin_x: float, origin_z: float) -> Vector2:
	return Vector2(origin_x + offset_x, origin_z + offset_z)


## True when the offset circle overlaps a point (or a circle of extra_radius).
func overlaps(origin_x: float, origin_z: float, px: float, pz: float, extra_radius: float = 0.0) -> bool:
	var center := collision_center(origin_x, origin_z)
	var dx := center.x - px
	var dz := center.y - pz
	var reach := collision_radius + extra_radius
	return dx * dx + dz * dz <= reach * reach
