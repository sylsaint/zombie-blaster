class_name LaneMotion
extends RefCounted
## Maps a horizontal screen drag into a lane X and keeps bodies inside the rails.
##
## One full viewport-width of drag covers the whole lane, so a swipe can
## cross from rail to rail on any phone aspect. The greybox player uses this;
## the squad anchor should keep using it instead of growing its own copy.
## Enemy centers use the same rail line, pulled in by their body radius.


## Greybox rail centerline. scenes/main.tscn places the rails at X = ±3.75.
const RAIL_X := 3.75
## BoxMesh size.x of those rails. The inner face is RAIL_X - RAIL_HALF.
const RAIL_HALF := 0.175
## Walker VAT aabb reaches ±0.58 m, past the 0.40 m collision radius.
const GRUNT_MESH_HALF := 0.61


static func apply_drag(current_x: float, screen_dx: float, viewport_width: float, lane_half_width: float) -> float:
	var half := maxf(lane_half_width, 0.0)
	if viewport_width <= 0.0:
		return clampf(current_x, -half, half)
	var world_dx := (screen_dx / viewport_width) * (half * 2.0)
	return clampf(current_x + world_dx, -half, half)


## Half-width a body may use so its edge stays on the inner face of the rail.
static func body_limit(radius: float) -> float:
	return maxf(RAIL_X - RAIL_HALF - maxf(radius, 0.0), 0.0)


## Grunt meshes swing wider than their collision radius. Elites and bosses
## already carry a radius that covers the body.
static func body_reach(radius: float, species: int) -> float:
	var reach := maxf(radius, 0.0)
	if species == EnemyPool.Species.WALKER or species == EnemyPool.Species.RUNNER:
		reach = maxf(reach, GRUNT_MESH_HALF)
	return reach


static func clamp_body_x(x: float, radius: float) -> float:
	var limit := body_limit(radius)
	return clampf(x, -limit, limit)
