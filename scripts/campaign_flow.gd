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
	if host == null or host.session == null:
		return
	var session := host.session
	var now := _gameplay_time()
	if session.sim != null and session.sim.squad.count <= 0 and zero_gameplay_time < 0.0:
		zero_gameplay_time = now
	if session.result != null and not _presented:
		_present(session.result, now)
	_tick_level1_shot()


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
	if _shot_path == "":
		return
	call_deferred("_play_level1_for_shot")


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
	var viewport := get_viewport()
	var texture := viewport.get_texture() if viewport != null else null
	var image: Image = texture.get_image() if texture != null else null
	if image == null:
		push_error("Level 1 screenshot viewport was empty")
		return
	var path := _shot_path
	if path.begins_with("res://"):
		path = ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := image.save_png(path)
	if err != OK:
		push_error("Could not save level 1 screenshot: %s" % error_string(err))
		return
	print("LEVEL1_SHOT %s" % path)


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
	if menu_view != null:
		menu_view.visible = true
	if select_view != null:
		select_view.visible = false
	if results_view != null:
		results_view.visible = false
	_refresh_meta()


func _show_select() -> void:
	if menu_view != null:
		menu_view.visible = false
	if select_view != null:
		select_view.visible = true
	if results_view != null:
		results_view.visible = false
	_refresh_meta()


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
