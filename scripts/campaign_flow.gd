class_name CampaignFlow
extends CanvasLayer
## Boots the menu, starts a level, and opens results off the gameplay clock.
## Never writes Engine.time_scale.


const DEFAULT_SAVE := "user://save.json"

var save_path: String = DEFAULT_SAVE
var store: SaveStore
var profile: PlayerProfile
var host: LevelHost
var menu_view: MainMenu
var select_view: LevelSelect
var results_view: ResultsScreen
var zero_gameplay_time: float = -1.0
var results_gameplay_time: float = -1.0

var _current_level: int = 1
var _presented: bool = false
var _wired: bool = false
var _shot_path: String = ""
var _shot_after: float = 6.0
var _shot_phase: int = 0
var _canvas_probe_started: bool = false
var _probe_hidden: Array = []
var _probe_env: Environment
var _probe_world: WorldEnvironment
var _probe_layer: CanvasLayer
var _census_wait: float = 0.0
var _menu_shot_path: String = ""
var _menu_shot_frames: int = 0


func _ready() -> void:
	process_priority = 10
	if host == null:
		var parent := get_parent()
		if parent != null:
			host = parent.get_node_or_null("LevelHost") as LevelHost
	if menu_view == null:
		menu_view = get_node_or_null("MainMenu") as MainMenu
	if select_view == null:
		select_view = get_node_or_null("LevelSelect") as LevelSelect
	if results_view == null:
		results_view = get_node_or_null("Results") as ResultsScreen
	_wire()
	store = SaveStore.new()
	store.path = save_path
	profile = store.load_profile()
	_show_menu()
	_arm_level1_shot()
	_arm_exported_smoke()


func _process(_delta: float) -> void:
	_tick_menu_shot()
	if host == null or host.session == null:
		return
	var session := host.session
	var now := _gameplay_time()
	if session.sim != null and session.sim.squad.count <= 0 and zero_gameplay_time < 0.0:
		zero_gameplay_time = now
	if session.result != null and not _presented:
		_present(session.result, now)
	_tick_level1_shot()
	_tick_smoke_census(_delta)


func begin_level(level_index: int) -> void:
	if host == null or profile == null:
		return
	if level_index < 1 or level_index > LevelCatalog.PATHS.size():
		return
	if not profile.is_unlocked(level_index):
		return
	_current_level = level_index
	_presented = false
	zero_gameplay_time = -1.0
	results_gameplay_time = -1.0
	_hide_screens()
	host.start_level(level_index, profile.attack_level)


func _present(result: RunResult, now: float) -> void:
	_presented = true
	var view := RewardRules.build(result, profile)
	RewardRules.apply(profile, view)
	if store != null:
		store.save(profile)
	results_gameplay_time = now
	if result.outcome == "lose" and zero_gameplay_time < 0.0:
		zero_gameplay_time = now
	if results_view != null:
		results_view.present(view)
	_refresh_meta()


func _arm_level1_shot() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--level1-shot="):
			_shot_path = arg.trim_prefix("--level1-shot=")
		elif arg.begins_with("--menu-shot="):
			_menu_shot_path = arg.trim_prefix("--menu-shot=")
	if _shot_path == "":
		return
	call_deferred("_play_level1_for_shot")


func _tick_menu_shot() -> void:
	if _menu_shot_path == "":
		return
	_menu_shot_frames += 1
	if _menu_shot_frames < 8:
		return
	_save_viewport_png(_menu_shot_path, "MENU_SHOT")
	_menu_shot_path = ""
	get_tree().quit()


func _play_level1_for_shot() -> void:
	if menu_view != null:
		var play := menu_view.get_node_or_null("%Play") as BaseButton
		if play != null:
			play.pressed.emit()
	if select_view != null:
		var level_button := select_view.get_node_or_null("%Level1") as BaseButton
		if level_button != null:
			level_button.pressed.emit()
	_pin_shot_lane()


func _pin_shot_lane() -> void:
	if host == null or host.session == null or host.session.sim == null:
		return
	# Left of center, on the level-1 add gate, with both gates still in frame.
	host.session.sim.squad.target_x = -1.6


func _tick_level1_shot() -> void:
	if _shot_path == "" or _shot_phase >= 2:
		return
	_pin_shot_lane()
	if _shot_phase == 0:
		if _gameplay_time() < _shot_after:
			return
		visible = false
		_shot_phase = 1
		return
	_save_level1_shot()
	_shot_phase = 2
	get_tree().quit()


func _save_level1_shot() -> void:
	_save_viewport_png(_shot_path, "LEVEL1_SHOT")


func _save_viewport_png(path: String, tag: String) -> void:
	var viewport := get_viewport()
	var texture := viewport.get_texture() if viewport != null else null
	var image: Image = texture.get_image() if texture != null else null
	if image == null:
		push_error("%s viewport was empty" % tag)
		return
	if path.begins_with("res://"):
		path = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := image.save_png(path)
	if err != OK:
		push_error("Could not save %s: %s" % [tag, error_string(err)])
		return
	print("%s %s" % [tag, path])


func _arm_exported_smoke() -> void:
	if not OS.get_cmdline_user_args().has("--smoke-exported"):
		return
	call_deferred("_run_exported_smoke")


func _run_exported_smoke() -> void:
	var play: Button = null
	if menu_view != null:
		play = menu_view.get_node_or_null("%Play") as Button
	if menu_view == null or not menu_view.visible or play == null or not play.visible or play.text != "开始":
		push_error("exported smoke: main menu is not visible")
		get_tree().quit(1)
		return
	print("SMOKE_MENU_OK")
	play.pressed.emit()
	var level_button: Button = null
	if select_view != null:
		level_button = select_view.get_node_or_null("%Level1") as Button
	if level_button == null or not level_button.visible or level_button.text != "第 1 关":
		push_error("exported smoke: level select did not show 第 1 关")
		get_tree().quit(1)
		return
	level_button.pressed.emit()
	if host == null or host.session == null or host.crowd == null:
		push_error("exported smoke: level 1 did not start")
		get_tree().quit(1)
		return
	var clock := get_node_or_null("/root/GameClock")
	if clock == null:
		push_error("exported smoke: GameClock is missing")
		get_tree().quit(1)
		return
	var walkers := 0
	var soldiers := 0
	var i := 0
	while i < 80:
		clock.advance(0.05)
		host._process(0.05)
		i += 1
		walkers = maxi(walkers, _visible_instances(host.crowd.grunt_mm))
		soldiers = maxi(soldiers, _visible_instances(host.crowd.squad_body_mm))
	if walkers <= 0 or soldiers <= 0:
		push_error("exported smoke: level 1 soldiers=%d walkers=%d" % [soldiers, walkers])
		get_tree().quit(1)
		return
	print("SMOKE_LEVEL1_OK")
	get_tree().quit(0)


func _visible_instances(node: MultiMeshInstance3D) -> int:
	if node == null or node.multimesh == null:
		return 0
	return node.multimesh.visible_instance_count


func _tick_smoke_census(delta: float) -> void:
	if not _wants_canvas_probe():
		return
	_census_wait -= delta
	if _census_wait > 0.0:
		return
	_census_wait = 1.0
	var gates := 0
	if host.gates != null:
		for child in host.gates.get_children():
			if child is MeshInstance3D and child.visible:
				gates += 1
	print(
		"LEVEL1_CENSUS soldiers=%d walkers=%d gates=%d time=%.2f"
		% [
			_visible_instances(host.crowd.squad_body_mm),
			_visible_instances(host.crowd.grunt_mm),
			gates,
			_gameplay_time(),
		]
	)


func _gameplay_time() -> float:
	var clock := get_node_or_null("/root/GameClock")
	if clock == null:
		return 0.0
	return float(clock.gameplay_time)


func _wire() -> void:
	if _wired:
		return
	_wired = true
	if menu_view != null:
		menu_view.play_pressed.connect(_show_select)
		menu_view.upgrade_pressed.connect(_on_upgrade)
	if select_view != null:
		select_view.level_pressed.connect(begin_level)
		select_view.back_pressed.connect(_show_menu)
		select_view.upgrade_pressed.connect(_on_upgrade)
	if results_view != null:
		results_view.retry_pressed.connect(_on_retry)
		results_view.next_pressed.connect(_on_next)
		results_view.back_pressed.connect(_show_select)


func _on_upgrade() -> void:
	if profile == null:
		return
	if MetaUpgrade.try_buy(profile) and store != null:
		store.save(profile)
	_refresh_meta()


func _on_retry() -> void:
	begin_level(_current_level)


func _on_next() -> void:
	begin_level(_current_level + 1)


func _show_menu() -> void:
	if host != null:
		host.present_menu_lane()
	if menu_view != null:
		menu_view.visible = true
	if select_view != null:
		select_view.visible = false
	if results_view != null:
		results_view.visible = false
	_refresh_meta()
	# The Android release smoke looks for this in logcat. The canvas can fail
	# to draw while this still runs, so the screenshot check is separate.
	# _ready is before the first layout, so the button rect is printed next frame.
	print("MENU_READY")
	get_tree().process_frame.connect(_print_menu_layout, CONNECT_ONE_SHOT)
	# Only the CI x86_64 smoke APK passes this. The phone preset's extra_args stay empty.
	if not _canvas_probe_started and _wants_canvas_probe():
		_canvas_probe_started = true
		_run_canvas_probe()


func _wants_canvas_probe() -> bool:
	return _cmdline_has("--smoke-canvas")


func _smoke_present_name() -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--smoke-present="):
			return arg.trim_prefix("--smoke-present=")
	for arg in OS.get_cmdline_args():
		if arg.begins_with("--smoke-present="):
			return arg.trim_prefix("--smoke-present=")
	return ""


func _cmdline_has(needle: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.contains(needle):
			return true
	for arg in OS.get_cmdline_args():
		if arg.contains(needle):
			return true
	return false


func _run_canvas_probe() -> void:
	_print_canvas_settings()
	var present := _smoke_present_name()
	if present != "":
		# Presentation variants only need the menu frame. The 3-way probe stays
		# for a smoke APK that passes --smoke-canvas without a present name.
		await _capture_canvas_variant(present, "user://menu_engine.png", 8.0)
		print("MENU_CANVAS_DONE")
		return
	await _capture_canvas_variant("menu", "user://menu_engine.png", 12.0)
	_disable_lane_for_probe()
	await _capture_canvas_variant("no3d", "user://menu_engine_no3d.png", 12.0)
	_add_plain_canvas_for_probe()
	await _capture_canvas_variant("plain", "user://menu_engine_plain.png", 12.0)
	_restore_after_canvas_probe()
	print("MENU_CANVAS_DONE")


func _print_canvas_settings() -> void:
	var keys := [
		"rendering/viewport/hdr_2d",
		"rendering/viewport/transparent_background",
		"rendering/scaling_3d/mode",
		"rendering/scaling_3d/scale",
		"rendering/anti_aliasing/quality/msaa_2d",
		"rendering/anti_aliasing/quality/msaa_3d",
		"rendering/anti_aliasing/quality/use_debanding",
		"display/window/frame_pacing/android/enable_frame_pacing",
		"display/window/vsync/vsync_mode",
		"rendering/gl_compatibility/driver",
		"rendering/gl_compatibility/driver.android",
		"rendering/gl_compatibility/fallback_to_angle",
		"rendering/gl_compatibility/fallback_to_gles",
		"rendering/gl_compatibility/fallback_to_native",
		"rendering/driver/threads/thread_model",
	]
	var parts: PackedStringArray = []
	for key in keys:
		if ProjectSettings.has_setting(key):
			parts.append("%s=%s" % [key, ProjectSettings.get_setting(key)])
		else:
			parts.append("%s=MISSING" % key)
	var subs := get_tree().root.find_children("*", "SubViewport", true, false)
	var in_sub := get_viewport() != get_tree().root.get_viewport()
	print(
		"MENU_SETTINGS %s subviewports=%d main_in_subviewport=%s user_dir=%s"
		% [" ".join(parts), subs.size(), in_sub, OS.get_user_data_dir()]
	)
	print("MENU_CMDLINE %s" % " ".join(OS.get_cmdline_args()))


func _capture_canvas_variant(variant_name: String, user_path: String, hold_sec: float) -> void:
	# process_frame runs before the draw. Two post-draw frames is the rendered image.
	for _i in 2:
		await RenderingServer.frame_post_draw
	var viewport := get_viewport()
	var texture := viewport.get_texture() if viewport != null else null
	var image: Image = texture.get_image() if texture != null else null
	if image == null or image.get_width() <= 0:
		print("MENU_ENGINE name=%s ratio=missing save=empty file=%s" % [variant_name, user_path])
		await get_tree().create_timer(hold_sec).timeout
		return
	var err := image.save_png(user_path)
	var ratio := _menu_pixel_ratio(image)
	var file_path := ProjectSettings.globalize_path(user_path)
	print(
		"MENU_ENGINE name=%s ratio=%.4f size=%dx%d play=%s file=%s save=%s"
		% [
			variant_name,
			ratio,
			image.get_width(),
			image.get_height(),
			_pixel_text(image, 540, 1698),
			file_path,
			err,
		]
	)
	# Hold this frame so both captures see the same presented menu.
	await get_tree().create_timer(hold_sec).timeout


func _menu_pixel_ratio(image: Image) -> float:
	var sample := image
	if image.get_format() != Image.FORMAT_RGBA8 and image.get_format() != Image.FORMAT_RGB8:
		sample = image.duplicate()
		sample.convert(Image.FORMAT_RGBA8)
	var data := sample.get_data()
	var channels := 4 if sample.get_format() == Image.FORMAT_RGBA8 else 3
	var total := sample.get_width() * sample.get_height()
	if total <= 0 or channels <= 0:
		return 0.0
	var menu := 0
	var i := 0
	while i + 2 < data.size():
		var r := int(data[i])
		var g := int(data[i + 1])
		var b := int(data[i + 2])
		if r >= 210 and g >= 160 and b >= 90 and b <= 210 and (r - b) >= 30 and (g - b) >= 15 and r + 10 >= g:
			menu += 1
		i += channels
	return float(menu) / float(total)


func _pixel_text(image: Image, x: int, y: int) -> String:
	x = clampi(x, 0, image.get_width() - 1)
	y = clampi(y, 0, image.get_height() - 1)
	var color := image.get_pixel(x, y)
	return "%d,%d:%d,%d,%d" % [
		x,
		y,
		int(round(color.r * 255.0)),
		int(round(color.g * 255.0)),
		int(round(color.b * 255.0)),
	]


func _disable_lane_for_probe() -> void:
	var root := get_parent()
	if root == null:
		return
	_probe_world = root.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if _probe_world != null:
		_probe_env = _probe_world.environment
		_probe_world.environment = null
	for node in root.find_children("*", "VisualInstance3D", true, false):
		if node.visible:
			node.visible = false
			_probe_hidden.append(node)
	for node in root.find_children("*", "Light3D", true, false):
		if node.visible:
			node.visible = false
			_probe_hidden.append(node)


func _add_plain_canvas_for_probe() -> void:
	var layer := CanvasLayer.new()
	layer.name = "PlainProbe"
	layer.layer = 100
	get_tree().root.add_child(layer)
	var rect := ColorRect.new()
	rect.name = "PlainFill"
	rect.color = Color8(255, 221, 161)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.theme = Theme.new()
	layer.add_child(rect)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.set_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	label.text = "PLAIN"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.theme = Theme.new()
	label.add_theme_color_override("font_color", Color(0, 0, 0, 1))
	label.add_theme_font_size_override("font_size", 72)
	label.position = Vector2(64, 64)
	rect.add_child(label)
	_probe_layer = layer


func _restore_after_canvas_probe() -> void:
	if _probe_layer != null and is_instance_valid(_probe_layer):
		_probe_layer.queue_free()
	_probe_layer = null
	for node in _probe_hidden:
		if is_instance_valid(node):
			node.visible = true
	_probe_hidden.clear()
	if _probe_world != null and is_instance_valid(_probe_world):
		_probe_world.environment = _probe_env


func _print_menu_layout() -> void:
	var play_rect := Rect2()
	var menu_visible := false
	if menu_view != null:
		menu_visible = menu_view.visible
		var play := menu_view.get_node_or_null("%Play") as Control
		if play != null:
			play_rect = play.get_global_rect()
	print(
		"MENU_LAYOUT visible=%s rect=%s viewport=%s play_x=%.1f play_y=%.1f play_w=%.1f play_h=%.1f"
		% [
			menu_visible,
			play_rect,
			get_viewport().get_visible_rect(),
			play_rect.position.x,
			play_rect.position.y,
			play_rect.size.x,
			play_rect.size.y,
		]
	)
	_print_safe_area()


func _show_select() -> void:
	if menu_view != null:
		menu_view.visible = false
	if select_view != null:
		select_view.visible = true
	if results_view != null:
		results_view.visible = false
	_refresh_meta()
	if _wants_canvas_probe():
		get_tree().process_frame.connect(_print_select_layout, CONNECT_ONE_SHOT)


func _print_select_layout() -> void:
	var button: Control = null
	if select_view != null:
		button = select_view.get_node_or_null("%Level1") as Control
	if button == null:
		print("MENU_SELECT missing")
		return
	var rect := button.get_global_rect()
	print(
		"MENU_SELECT level_x=%.1f level_y=%.1f level_w=%.1f level_h=%.1f"
		% [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
	)


func _print_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var window_size := DisplayServer.window_get_size()
	var screen_size := DisplayServer.screen_get_size()
	var cutout_text := ""
	var index := 0
	for raw in DisplayServer.get_display_cutouts():
		var rect := Rect2(raw)
		cutout_text += " cutout%d=%d,%d,%d,%d" % [
			index,
			int(rect.position.x),
			int(rect.position.y),
			int(rect.size.x),
			int(rect.size.y),
		]
		index += 1
	print(
		"MENU_SAFE safe_x=%d safe_y=%d safe_w=%d safe_h=%d cutouts=%d window=%dx%d screen=%dx%d%s"
		% [
			safe.position.x,
			safe.position.y,
			safe.size.x,
			safe.size.y,
			index,
			window_size.x,
			window_size.y,
			screen_size.x,
			screen_size.y,
			cutout_text,
		]
	)
	var top := _topmost_content_control()
	if top == null:
		print("MENU_TOP missing")
	else:
		var top_rect := top.get_global_rect()
		print(
			"MENU_TOP name=%s y=%.1f h=%.1f x=%.1f w=%.1f"
			% [top.name, top_rect.position.y, top_rect.size.y, top_rect.position.x, top_rect.size.x]
		)
	var title: Control = null
	if menu_view != null:
		title = menu_view.get_node_or_null("%Title") as Control
	if title != null and title.is_visible_in_tree():
		var title_rect := title.get_global_rect()
		print("MENU_TITLE name=%s y=%.1f h=%.1f" % [title.name, title_rect.position.y, title_rect.size.y])


func _topmost_content_control() -> Control:
	if menu_view == null:
		return null
	var viewport_size := get_viewport().get_visible_rect().size
	var best: Control = null
	var best_y := 1.0e20
	var stack: Array[Node] = []
	stack.append(menu_view)
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		for child in node.get_children():
			stack.append(child)
		var control := node as Control
		if control == null or not control.is_visible_in_tree():
			continue
		var rect := control.get_global_rect()
		if rect.size.x < 8.0 or rect.size.y < 8.0:
			continue
		if viewport_size.x > 0.0 and viewport_size.y > 0.0:
			if rect.size.x >= viewport_size.x * 0.95 and rect.size.y >= viewport_size.y * 0.95:
				continue
		if rect.position.y < best_y:
			best_y = rect.position.y
			best = control
	return best


func _hide_screens() -> void:
	if menu_view != null:
		menu_view.visible = false
	if select_view != null:
		select_view.visible = false
	if results_view != null:
		results_view.visible = false


func _refresh_meta() -> void:
	if profile == null:
		return
	var level := profile.attack_level
	var cost := MetaUpgrade.next_cost(level)
	var can_buy := MetaUpgrade.can_buy(profile)
	var bonus := roundi(WeaponMods.meta_attack_bonus(level) * 100.0)
	var cap := WeaponMods.META_ATTACK_CAP
	if menu_view != null:
		menu_view.show_meta(level, cap, bonus, cost, can_buy, profile.coins, profile.parts)
	if select_view != null:
		select_view.show_meta(level, cap, bonus, cost, can_buy, profile.coins, profile.parts)
		select_view.show_levels(profile.unlocked_through)
