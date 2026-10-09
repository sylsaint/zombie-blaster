extends GutTest

const Stress := preload("res://scripts/stress_test.gd")


func test_profile_record_keeps_timestamp_model_and_screen_numbers() -> void:
	var record: Dictionary = Stress.profile_record(
		2.06, 3.1, 33.3, 28.4, 12, 4500, 54.0, "2026-10-09T09:05:00Z", "Helio G85", 3, 4096.0, 1800.0
	)
	var parsed: Variant = JSON.parse_string(JSON.stringify(record))
	assert_typeof(parsed, TYPE_DICTIONARY)
	assert_eq(parsed["timestamp"], "2026-10-09T09:05:00Z")
	assert_eq(parsed["device_model"], "Helio G85")
	assert_eq(int(parsed["run"]), 3)
	assert_almost_eq(float(parsed["logic_avg_ms"]), 2.06, 0.001)
	assert_almost_eq(float(parsed["logic_p99_ms"]), 3.1, 0.001)
	assert_almost_eq(float(parsed["frame_avg_ms"]), 33.3, 0.001)
	assert_almost_eq(float(parsed["fps_1pct_low"]), 28.4, 0.001)
	assert_eq(int(parsed["draw_calls"]), 12)
	assert_eq(int(parsed["triangles"]), 4500)
	assert_almost_eq(float(parsed["memory_static_mb"]), 54.0, 0.001)
	assert_almost_eq(float(parsed["device_physical_mb"]), 4096.0, 0.001)
	assert_almost_eq(float(parsed["device_available_mb"]), 1800.0, 0.001)
	var screen := Stress.profile_screen_text(record)
	assert_string_contains(screen, "run 3")
	assert_string_contains(screen, "logic avg")
	assert_string_contains(screen, "logic p99")
	assert_string_contains(screen, "frame avg")
	assert_string_contains(screen, "1% low")
	assert_string_contains(screen, "draws")
	assert_string_contains(screen, "tris")
	assert_string_contains(screen, "Godot static (not PSS)")
	assert_string_contains(screen, "device RAM")
	assert_string_contains(screen, "16.7")
	assert_string_contains(screen, "frame avg 只作参考")
	assert_string_contains(screen, "2.06")
	assert_string_contains(screen, "3.10")


func test_profile_screen_omits_device_ram_when_the_engine_has_no_numbers() -> void:
	var record: Dictionary = Stress.profile_record(
		1.0, 2.0, 16.7, 30.0, 4, 100, 40.0, "2026-10-09T09:05:00Z", "phone", 1, -1.0, -1.0
	)
	var screen := Stress.profile_screen_text(record)
	assert_false(screen.contains("device RAM"))
	assert_string_contains(screen, "Godot static (not PSS)")
