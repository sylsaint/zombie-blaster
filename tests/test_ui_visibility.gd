extends GutTest


func test_project_theme_is_drawable() -> void:
	var theme := load("res://assets/ui/game_theme.tres") as Theme
	assert_eq(UiVisibility.theme_failure(theme), "")
	assert_true(UiVisibility.theme_is_drawable(theme))


func test_null_panel_texture_is_not_drawable_and_fallback_is_flat() -> void:
	var broken := Theme.new()
	var box := StyleBoxTexture.new()
	broken.set_stylebox(&"panel", &"PanelContainer", box)
	broken.default_font = load("res://assets/ui/fonts/ZCOOLKuaiLe-Regular.ttf")
	assert_eq(UiVisibility.theme_failure(broken), "null_texture")
	var fallback := UiVisibility.make_fallback(broken)
	assert_true(fallback.get_stylebox(&"panel", &"PanelContainer") is StyleBoxFlat)
	assert_true(fallback.get_stylebox(&"normal", &"Button") is StyleBoxFlat)
	assert_true(fallback.default_font.has_char(("高").unicode_at(0)))
	assert_eq(fallback.get_constant(&"outline_size", &"Display"), 0)


func test_font_without_title_glyph_is_not_drawable() -> void:
	var theme := Theme.new()
	theme.set_stylebox(&"panel", &"PanelContainer", StyleBoxFlat.new())
	theme.default_font = FontFile.new()
	assert_eq(UiVisibility.theme_failure(theme), "font")


func test_refit_fills_a_zero_size_control() -> void:
	var layer := CanvasLayer.new()
	add_child_autofree(layer)
	var menu := Control.new()
	menu.size = Vector2.ZERO
	layer.add_child(menu)
	var rect := menu.get_viewport().get_visible_rect()
	assert_gt(rect.size.x, 2.0)
	assert_gt(rect.size.y, 2.0)
	UiVisibility.refit_control(menu)
	assert_almost_eq(menu.size.x, rect.size.x, 1.0)
	assert_almost_eq(menu.size.y, rect.size.y, 1.0)
	assert_eq(menu.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)


func test_drawable_project_theme_is_not_replaced() -> void:
	var layer := CanvasLayer.new()
	add_child_autofree(layer)
	var menu := Control.new()
	menu.name = "MainMenu"
	layer.add_child(menu)
	var guard := UiVisibility.new()
	layer.add_child(guard)
	assert_false(guard.used_fallback)
	assert_null(menu.theme)
	assert_eq(guard.failure, "")


func test_ui_fonts_do_not_walk_android_system_fallback() -> void:
	for path in [
		"res://assets/ui/fonts/ZCOOLKuaiLe-Regular.ttf.import",
		"res://assets/ui/fonts/NotoSansSC-Medium.otf.import",
	]:
		var text := FileAccess.get_file_as_string(path)
		assert_true(text.contains("allow_system_fallback=false"), path)
		assert_true(text.contains("\nsubpixel_positioning=0\n"), path)
