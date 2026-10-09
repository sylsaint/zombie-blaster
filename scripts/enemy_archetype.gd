class_name EnemyArchetype
extends Resource
## One enemy prototype. Stage HP multipliers live on StageTable.
## Mesh paths are filenames the art drop replaces; missing files use greybox meshes.


const KIND_GRUNT := 0
const KIND_ELITE := 1
const KIND_BOSS := 2

@export var id: String = ""
@export var display_name: String = ""
@export var kind: int = KIND_GRUNT
@export var species: int = 0
@export var base_hp: float = 20.0
@export var speed: float = 1.6
@export var near_speed: float = 0.0
@export var near_distance: float = 0.0
@export var weight: int = 1
@export var radius: float = 0.4
@export var xp: int = 1
@export var gold: int = 0
@export var grants_offer: bool = false
@export var touch_damage: int = 1
@export var touch_period: float = 0.0
@export var slam_interval: float = 0.0
@export var warn_time: float = 0.0
@export var color_variant: float = 0.2
@export var mesh_high: String = ""
@export var mesh_low: String = ""
@export var visual_scale: float = 1.0
## Gameplay circle is not always on the mesh origin. The mutant's body is offset.
@export var offset_x: float = 0.0
@export var offset_z: float = 0.0
## Visual reach from the actor origin. Contact uses the offset circle, not these.
@export var mesh_extent_right: float = 0.0
@export var mesh_extent_left: float = 0.0
@export var mesh_extent_forward: float = 0.0


func collision_center(origin_x: float, origin_z: float) -> Vector2:
	return Vector2(origin_x + offset_x, origin_z + offset_z)


## True when the offset circle overlaps a point, or a circle of extra_radius.
func overlaps(origin_x: float, origin_z: float, px: float, pz: float, extra_radius: float = 0.0) -> bool:
	var center := collision_center(origin_x, origin_z)
	var dx := center.x - px
	var dz := center.y - pz
	var reach := radius + extra_radius
	return dx * dx + dz * dz <= reach * reach
