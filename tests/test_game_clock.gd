extends GutTest

const _Clock := preload("res://scripts/game_clock.gd")


func test_hit_stop_freezes_sixty_ms_without_touching_time_scale() -> void:
	var saved := Engine.time_scale
	var clock = autofree(_Clock.new())
	clock.hit_stop(60.0)
	assert_almost_eq(clock.advance(0.06), 0.0, 0.00001, "60 ms of real time stays frozen")
	assert_almost_eq(clock.hit_stop_remaining(), 0.0, 0.00001)
	assert_almost_eq(clock.advance(0.01), 0.01, 0.00001, "gameplay resumes after the freeze")
	assert_eq(Engine.time_scale, saved)


func test_hit_stop_is_within_one_frame_and_ui_keeps_real_delta() -> void:
	var clock = autofree(_Clock.new())
	var frame := 1.0 / 60.0
	clock.hit_stop(60.0)
	var gameplay := 0.0
	var ui := 0.0
	for _i in 3:
		ui += frame
		gameplay += clock.advance(frame)
	assert_almost_eq(gameplay, 0.0, 0.00001, "three 60 fps frames (50 ms) stay inside the freeze")
	assert_almost_eq(ui, 0.05, 0.0001, "UI accumulator uses the real deltas")
	var ui_frame := frame
	var partial: float = clock.advance(frame)
	assert_almost_eq(partial, frame - 0.01, 0.001, "the frame that crosses 60 ms is only partly frozen")
	assert_gt(ui_frame, partial)
	assert_eq(Engine.time_scale, 1.0)


func test_partial_frame_after_hit_stop_still_produces_gameplay_time() -> void:
	var clock = autofree(_Clock.new())
	clock.hit_stop(60.0)
	assert_almost_eq(clock.advance(0.1), 0.04, 0.0001)


func test_ramp_to_zero_reaches_zero_in_0_15s_and_restores() -> void:
	var clock = autofree(_Clock.new())
	clock.ramp_to_zero(0.15)
	assert_almost_eq(clock.scale, 1.0, 0.0001)
	var frame := 1.0 / 60.0
	for _i in 9:
		clock.advance(frame)
	assert_almost_eq(clock.scale, 0.0, 0.001, "nine frames is 0.15 s")
	assert_almost_eq(clock.gameplay_delta, 0.0, 0.001)
	clock.restore()
	assert_almost_eq(clock.scale, 1.0, 0.0001)
	assert_almost_eq(clock.advance(frame), frame, 0.0001)
	assert_eq(Engine.time_scale, 1.0)


func test_ramp_midpoint_is_half_scale() -> void:
	var clock = autofree(_Clock.new())
	clock.ramp_to_zero(0.15)
	clock.advance(0.075)
	assert_almost_eq(clock.scale, 0.5, 0.02)
	assert_gt(clock.gameplay_delta, 0.0)
	assert_lt(clock.gameplay_delta, 0.075)


func test_hit_stop_does_not_consume_the_ramp() -> void:
	var clock = autofree(_Clock.new())
	clock.ramp_to_zero(0.15)
	clock.advance(0.05)
	clock.hit_stop(60.0)
	assert_almost_eq(clock.advance(0.06), 0.0, 0.00001)
	clock.advance(0.01)
	assert_almost_eq(clock.scale, 1.0 - 0.06 / 0.15, 0.02)


func test_slow_motion_scales_gameplay_time_only() -> void:
	var saved := Engine.time_scale
	var clock = autofree(_Clock.new())
	clock.slow_motion(0.3, 0.6)
	assert_almost_eq(clock.advance(0.2), 0.06, 0.0001)
	assert_almost_eq(clock.scale, 0.3, 0.0001)
	assert_almost_eq(clock.advance(0.5), 0.22, 0.001)
	assert_almost_eq(clock.scale, 1.0, 0.0001)
	assert_eq(Engine.time_scale, saved)
