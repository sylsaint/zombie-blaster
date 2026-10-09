extends GutTest

const _LaneMotion := preload("res://scripts/lane_motion.gd")


func test_full_width_drag_crosses_the_lane() -> void:
	var next: float = _LaneMotion.apply_drag(0.0, 50.0, 200.0, 4.0)
	assert_almost_eq(next, 2.0, 0.0001)


func test_drag_clamps_at_the_rail() -> void:
	var next: float = _LaneMotion.apply_drag(3.5, 100.0, 200.0, 4.0)
	assert_almost_eq(next, 4.0, 0.0001)
	var back: float = _LaneMotion.apply_drag(1.0, -200.0, 200.0, 4.0)
	assert_almost_eq(back, -4.0, 0.0001)


func test_zero_viewport_only_clamps() -> void:
	var next: float = _LaneMotion.apply_drag(9.0, 10.0, 0.0, 4.0)
	assert_almost_eq(next, 4.0, 0.0001)
