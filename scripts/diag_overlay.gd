extends Node
## Top-level diagnostic for the diag_overlay export. Other builds free this autoload.
## The label does not use the project theme: explicit engine font, white fill, black outline.


const FONT_SIZE := 32
const OUTLINE := 8

var force := false
var logger: DiagLogger

var _layer: CanvasLayer
var _label: Label
var _bg: ColorRect
var _frames: int = 0
var _log_tail: PackedStringArray = PackedStringArray()


func _init() -> void:
	if OS.has_feature("diag_overlay"):
		logger = DiagLogger.new()
		OS.add_logger(logger)


func _ready() -> void:
	if not force and not OS.has_feature("diag_overlay"):
		queue_free()
		return
	_attach()


func _attach() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "DiagLayer"
	_layer.layer = 128
	add_child(_layer)
	_bg = ColorRect.new()
	_bg.name = "DiagBackdrop"
	_bg.color = Color(0, 0, 0, 0.72)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_bg)
	_label = Label.new()
	_label.name = "DiagLabel"
	_style_label(_label)
	_layer.add_child(_label)
	_refresh()


func _style_label(label: Label) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		var system := SystemFont.new()
		system.font_names = PackedStringArray(["sans-serif"])
		font = system
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = FONT_SIZE
	label.theme = theme
	label.theme_type_variation = &""
	label.add_theme_font_override(&"font", font)
	label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	label.add_theme_color_override(&"font_color", Color.WHITE)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", OUTLINE)
	label.add_theme_constant_override(&"shadow_outline_size", 0)
	label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	label.modulate = Color.WHITE


func _process(_delta: float) -> void:
	_frames += 1
	if _frames % 60 == 1:
		_log_tail = _tail_log()
	_refresh()


func _refresh() -> void:
	if _label == null:
		return
	_label.text = _text()
	_place()


func _place() -> void:
	var win := Vector2(DisplayServer.window_get_size())
	var visible := Rect2()
	var vp := get_viewport()
	if vp != null:
		visible = vp.get_visible_rect()
	var size := visible.size
	if size.x < 2.0 or size.y < 2.0:
		size = win
	if size.x < 2.0 or size.y < 2.0:
		size = Vector2(1080, 1920)
	_label.position = Vector2(12, 12)
	_label.size = Vector2(maxf(size.x - 24.0, 2.0), maxf(size.y - 24.0, 2.0))
	var text_h := _label.get_minimum_size().y
	_bg.position = Vector2.ZERO
	_bg.size = Vector2(size.x, minf(text_h + 24.0, size.y))


func _text() -> String:
	var vp := get_viewport()
	var visible := Rect2()
	var canvas := "none"
	if vp != null:
		visible = vp.get_visible_rect()
		var xf := vp.get_canvas_transform()
		var scale := xf.get_scale()
		canvas = "o(%.1f,%.1f) s(%.3f,%.3f)" % [xf.origin.x, xf.origin.y, scale.x, scale.y]
	var win := DisplayServer.window_get_size()
	var root := _root_control()
	var menu := _menu()
	var root_line := "missing"
	if root != null:
		root_line = "%s vis=%s rect=%s" % [root.name, root.visible, _rect(root.get_rect())]
	var menu_line := "missing"
	if menu != null:
		menu_line = "%s vis=%s g=%s mod=%s" % [menu.name, menu.visible, _rect(menu.get_global_rect()), menu.modulate]
	var lines: PackedStringArray = PackedStringArray()
	lines.append("win=%s" % win)
	lines.append("vp=%s" % visible)
	lines.append("safe=%s" % _safe())
	lines.append("scale=%s dpi=%s screen=%s ori=%s" % [
		DisplayServer.screen_get_scale(),
		DisplayServer.screen_get_dpi(),
		DisplayServer.screen_get_size(),
		int(DisplayServer.screen_get_orientation()),
	])
	lines.append("canvas=%s" % canvas)
	lines.append("root=%s" % root_line)
	lines.append("menu=%s" % menu_line)
	lines.append("renderer=%s gpu=%s" % [_renderer(), _gpu()])
	lines.append("errors:")
	var errors := _errors()
	if errors.is_empty():
		lines.append("(none)")
	else:
		for entry in errors:
			lines.append(entry)
	return "\n".join(lines)


func _safe() -> String:
	if DisplayServer.get_name() == "headless":
		return "headless"
	return str(DisplayServer.get_display_safe_area())


func _renderer() -> String:
	return str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))


func _gpu() -> String:
	if RenderingServer.has_method("get_video_adapter_name"):
		return RenderingServer.get_video_adapter_name()
	return ""


func _errors() -> PackedStringArray:
	if logger != null:
		var captured := logger.snapshot()
		if not captured.is_empty():
			return captured
	return _log_tail


func _tail_log() -> PackedStringArray:
	var path := "user://logs/godot.log"
	if not FileAccess.file_exists(path):
		return PackedStringArray()
	var handle := FileAccess.open(path, FileAccess.READ)
	if handle == null:
		return PackedStringArray()
	var length := handle.get_length()
	handle.seek(maxi(0, length - 4096))
	var chunk := handle.get_as_text()
	handle.close()
	var out: PackedStringArray = PackedStringArray()
	for raw in chunk.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty():
			continue
		if "ERROR" in line or "SCRIPT ERROR" in line:
			out.append(line)
	while out.size() > 15:
		out.remove_at(0)
	return out


func _root_control() -> Control:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return null
	return _first_control(tree.current_scene)


func _first_control(node: Node) -> Control:
	if node is Control:
		return node
	for child in node.get_children():
		var found := _first_control(child)
		if found != null:
			return found
	return null


func _menu() -> Control:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.get_node_or_null("UI/MainMenu") as Control


func _rect(rect: Rect2) -> String:
	return "(%.0f,%.0f %.0fx%.0f)" % [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
