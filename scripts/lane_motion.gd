class_name LaneMotion
extends RefCounted
## Maps a horizontal screen drag into a lane X and clamps it.
##
## One full viewport-width of drag covers the whole lane, so a swipe can
## cross from rail to rail on any phone aspect. The greybox player uses this;
## the future squad anchor should keep using it instead of growing its own copy.


static func apply_drag(current_x: float, screen_dx: float, viewport_width: float, lane_half_width: float) -> float:
	var half := maxf(lane_half_width, 0.0)
	if viewport_width <= 0.0:
		return clampf(current_x, -half, half)
	var world_dx := (screen_dx / viewport_width) * (half * 2.0)
	return clampf(current_x + world_dx, -half, half)
