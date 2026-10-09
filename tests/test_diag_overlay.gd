extends GutTest


func test_diag_features_are_off_outside_the_control_exports() -> void:
	assert_false(OS.has_feature("diag_overlay"))
	assert_false(OS.has_feature("diag_nosafe"))


func test_logger_keeps_script_errors_and_drops_warnings() -> void:
	var captured := DiagLogger.new()
	captured._log_error("fn", "a.gd", 3, "code", "why", false, Logger.ERROR_TYPE_SCRIPT, [])
	captured._log_error("fn", "a.gd", 4, "warn", "why", false, Logger.ERROR_TYPE_WARNING, [])
	captured._log_error("fn", "a.gd", 5, "push", "why", false, Logger.ERROR_TYPE_ERROR, [])
	var lines := captured.snapshot()
	assert_eq(lines.size(), 2)
	assert_true(lines[0].contains("SCRIPT"))
	assert_true(lines[1].contains("ERROR"))
	for _i in 20:
		captured._log_error("fn", "a.gd", 6, "push", "why", false, Logger.ERROR_TYPE_ERROR, [])
	assert_eq(captured.snapshot().size(), 15)


func test_overlay_label_ignores_the_project_theme() -> void:
	var node = load("res://scripts/diag_overlay.gd").new()
	node.force = true
	add_child_autofree(node)
	var label := node.find_child("DiagLabel", true, false) as Label
	var layer := node.find_child("DiagLayer", true, false) as CanvasLayer
	assert_not_null(label)
	assert_not_null(layer)
	assert_eq(layer.layer, 128)
	assert_eq(label.theme_type_variation, &"")
	assert_eq(label.get_theme_font(&"font"), ThemeDB.fallback_font)
	assert_eq(label.get_theme_color(&"font_color"), Color.WHITE)
	assert_eq(label.get_theme_color(&"font_outline_color"), Color.BLACK)
	assert_gt(label.get_theme_constant(&"outline_size"), 0)
	assert_eq(label.mouse_filter, Control.MOUSE_FILTER_IGNORE)
	assert_true(label.text.contains("win="))
	assert_true(label.text.contains("vp="))
	assert_true(label.text.contains("safe="))
	assert_true(label.text.contains("scale="))
	assert_true(label.text.contains("dpi="))
	assert_true(label.text.contains("root="))
	assert_true(label.text.contains("menu="))
	assert_true(label.text.contains("renderer="))
	assert_true(label.text.contains("gpu="))
	assert_gt(label.size.x, 2.0)
	assert_gt(label.size.y, 2.0)


func test_campaign_flow_still_guards_when_nosafe_is_off() -> void:
	assert_false(OS.has_feature("diag_nosafe"))
	var flow := CampaignFlow.new()
	add_child_autofree(flow)
	assert_not_null(flow.get_node_or_null("UiVisibility"))
