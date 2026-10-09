class_name UiVisibility
extends Node
## Keeps the portrait menu inside the visible viewport, and replaces a theme
## that cannot draw with flat panels so the title and buttons stay on screen.
##
## The 3D stage is untextured meshes. Every menu pixel comes from the project
## theme: StyleBoxTexture nine-patches and a FontVariation. StyleBoxTexture
## draws nothing when its texture is null, and a Theme that loaded still
## replaces the engine default, so the canvas is blank while the stage
## renders. Desktop GL loads those resources. Android can fail the draw
## (system-font fallback walks /system/etc/fonts.xml; a late surface size
## can leave the root Control at 0x0 if size_changed was missed).


const TITLE_MARK := "高"
const REFIT_STABLE_FRAMES := 5
const REFIT_GIVE_UP_FRAMES := 180

var used_fallback: bool = false
var failure: String = ""

var _frames: int = 0
var _stable: int = 0
var _logged: bool = false


func _ready() -> void:
	var viewport := get_viewport()
	if viewport != null and not viewport.size_changed.is_connected(_on_viewport_size):
		viewport.size_changed.connect(_on_viewport_size)
	_apply_project_theme()
	_refit()


func _exit_tree() -> void:
	var viewport := get_viewport()
	if viewport != null and viewport.size_changed.is_connected(_on_viewport_size):
		viewport.size_changed.disconnect(_on_viewport_size)


func _process(_delta: float) -> void:
	_refit()
	_frames += 1
	if _menu_matches():
		_stable += 1
	else:
		_stable = 0
	if _stable >= REFIT_STABLE_FRAMES or _frames >= REFIT_GIVE_UP_FRAMES:
		set_process(false)
		_log()


func _on_viewport_size() -> void:
	_stable = 0
	_refit()
	if not is_processing():
		set_process(true)


static func theme_failure(theme: Theme) -> String:
	if theme == null:
		return "missing_theme"
	var style := theme.get_stylebox(&"panel", &"PanelContainer")
	if style == null:
		return "missing_panel"
	if style is StyleBoxTexture:
		var tex := (style as StyleBoxTexture).texture
		if tex == null or tex.get_width() <= 0 or tex.get_height() <= 0:
			return "null_texture"
	var font := theme.default_font
	if font == null or font.get_height(96) <= 0.0 or not font.has_char(TITLE_MARK.unicode_at(0)):
		return "font"
	return ""


static func theme_is_drawable(theme: Theme) -> bool:
	return theme_failure(theme).is_empty()


static func make_fallback(source: Theme) -> Theme:
	var theme := Theme.new()
	if source != null:
		theme = source.duplicate(true)
	var panel := _flat(Color(0.09, 0.11, 0.14, 0.94))
	var button := _flat(Color(0.96, 0.74, 0.28, 1.0))
	var button_types: Array[StringName] = [
		&"Button",
		&"PrimaryButton",
		&"SecondaryButton",
		&"UpgradeButton",
		&"LockedButton",
		&"SmallButton",
	]
	var states: Array[StringName] = [
		&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled", &"focus",
	]
	for type_name in button_types:
		for state in states:
			theme.set_stylebox(state, type_name, button)
	for type_name in [&"Panel", &"PanelContainer", &"RewardPanel", &"BannerPanel"]:
		theme.set_stylebox(&"panel", type_name, panel)
	theme.set_stylebox(&"background", &"ProgressBar", panel)
	theme.set_stylebox(&"fill", &"ProgressBar", button)
	theme.default_font = _title_font(source)
	var text_types: Array[StringName] = [
		&"Label", &"Button", &"Display", &"HeaderLabel", &"StatLabel",
		&"Body", &"BodyLabel", &"TitleLabel", &"FailTitleLabel",
		&"CaptionLabel", &"RewardLabel", &"RewardNoteLabel", &"BannerLabel",
	]
	for type_name in text_types:
		theme.set_constant(&"outline_size", type_name, 0)
		theme.set_constant(&"shadow_outline_size", type_name, 0)
	return theme


static func refit_control(control: Control) -> void:
	if control == null or not control.is_inside_tree():
		return
	var rect := control.get_viewport().get_visible_rect()
	if rect.size.x < 2.0 or rect.size.y < 2.0:
		return
	control.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if control.size.x < rect.size.x - 1.0 or control.size.y < rect.size.y - 1.0:
		control.position = rect.position
		control.size = rect.size


static func _flat(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(16)
	box.content_margin_left = 24.0
	box.content_margin_top = 16.0
	box.content_margin_right = 24.0
	box.content_margin_bottom = 16.0
	return box


static func _title_font(source: Theme) -> Font:
	var current: Font = source.default_font if source != null else null
	if _font_has_title(current):
		return current
	var bundled := load("res://assets/ui/fonts/ZCOOLKuaiLe-Regular.ttf") as Font
	if _font_has_title(bundled):
		return bundled
	var system := SystemFont.new()
	system.font_names = PackedStringArray(["Noto Sans CJK SC", "Noto Sans SC", "sans-serif"])
	return system


static func _font_has_title(font: Font) -> bool:
	if font == null:
		return false
	if font.get_height(96) <= 0.0:
		return false
	return font.has_char(TITLE_MARK.unicode_at(0))


func _apply_project_theme() -> void:
	var configured := str(ProjectSettings.get_setting("gui/theme/custom", ""))
	if configured.is_empty():
		failure = ""
		return
	var theme := load(configured) as Theme
	failure = theme_failure(theme)
	if failure.is_empty():
		return
	used_fallback = true
	var fallback := make_fallback(theme)
	var layer := get_parent()
	if layer == null:
		return
	for child in layer.get_children():
		if child is Control:
			(child as Control).theme = fallback
	push_error(
		"UI theme is not drawable (%s). Installed a flat fallback so the menu stays visible."
		% failure
	)


func _refit() -> void:
	var layer := get_parent()
	if layer == null:
		return
	for child in layer.get_children():
		if child is Control:
			refit_control(child)


func _menu() -> Control:
	var layer := get_parent()
	if layer == null:
		return null
	return layer.get_node_or_null("MainMenu") as Control


func _menu_matches() -> bool:
	var menu := _menu()
	if menu == null or not menu.is_inside_tree():
		return false
	var rect := menu.get_viewport().get_visible_rect()
	if rect.size.x < 2.0 or rect.size.y < 2.0:
		return false
	return absf(menu.size.x - rect.size.x) <= 1.0 and absf(menu.size.y - rect.size.y) <= 1.0


func _log() -> void:
	if _logged:
		return
	_logged = true
	var menu := _menu()
	var menu_size := Vector2.ZERO
	var rect := Rect2()
	if menu != null and menu.is_inside_tree():
		menu_size = menu.size
		rect = menu.get_viewport().get_visible_rect()
	var tex_size := Vector2i.ZERO
	var font_h := 0.0
	var configured := str(ProjectSettings.get_setting("gui/theme/custom", ""))
	if not configured.is_empty():
		var theme := load(configured) as Theme
		if theme != null:
			var style := theme.get_stylebox(&"panel", &"PanelContainer")
			if style is StyleBoxTexture and (style as StyleBoxTexture).texture != null:
				var tex := (style as StyleBoxTexture).texture
				tex_size = Vector2i(tex.get_width(), tex.get_height())
			if theme.default_font != null:
				font_h = theme.default_font.get_height(96)
	var safe := Rect2i()
	if DisplayServer.get_name() != "headless":
		safe = DisplayServer.get_display_safe_area()
	print(
		"UI_VIS fallback=%s reason=%s viewport=%s menu=%s tex=%s font_h=%.1f safe=%s"
		% [
			"true" if used_fallback else "false",
			failure if not failure.is_empty() else ("empty" if configured.is_empty() else "ok"),
			rect.size,
			menu_size,
			tex_size,
			font_h,
			safe,
		]
	)
