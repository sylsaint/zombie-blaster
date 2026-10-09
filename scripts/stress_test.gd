extends Node3D
## 180 walkers, 120 runners, 3 armored elites, and 1 boss.
## Headless: run N frames, print STRESS_STATS, quit.
## Contact stays off so the bench remains a shootout; GUT covers contact.
##
## Issue #17: shader compile, the first multimesh upload, and the first
## overlay glyphs land outside the 2 ms gameplay budget. Prewarm burns
## those in before the timed window. STRESS_STATS also records the slowest
## frame, spike indices, and the 1% low after dropping the first warmup frames.


const WALKERS := 180
const RUNNERS := 120
const ELITES := 3
const BOSSES := 1
const SPIKE_MS := 50.0
const SPIKE_CAP := 24
const _FRAME_RING := 4096

var _sim: CombatSim
var _view: CrowdView
var _label: Label
var _camera: Camera3D
var _ground: Node3D
var _limit: int = -1
var _headless: bool = false
var _phase: int = 0
var _gpu_draw_50: int = 0
var _gpu_draw_300: int = 0
var _batches_50: int = 0
var _batches_300: int = 0
var _instances_50: int = 0
var _instances_300: int = 0
var _bench_frames: int = 0
var _bench_time: float = 0.0
var _frame_times := PackedFloat32Array()
var _sort_scratch := PackedFloat32Array()
var _finished: bool = false
var _draw_min: int = 999999
var _draw_max: int = 0
var _draw3d_min: int = 999999
var _draw3d_max: int = 0
var _profile := SimProfile.new()
var _sample_combat := PackedInt32Array()
var _sample_squad := PackedInt32Array()
var _sample_rebuild := PackedInt32Array()
var _sample_query := PackedInt32Array()
var _sample_bullet := PackedInt32Array()
var _sample_view := PackedInt32Array()
var _sample_write := PackedInt32Array()
var _sample_upload := PackedInt32Array()
var _sample_overlay := PackedInt32Array()
var _sample_process := PackedInt32Array()
var _sample_logic := PackedInt32Array()
var _overlay_every := 8
var _cel: bool = false
var _rim: bool = false
var _outline: bool = false
var _prewarm_target: int = 45
var _prewarm_frames: int = 0
var _prewarm_max_ms: float = 0.0
var _prewarm_max_index: int = -1
var _prewarm_spike_count: int = 0
var _prewarm_spike_idx := PackedInt32Array()
var _prewarm_spike_ms := PackedFloat32Array()
var _frame_max_ms: float = 0.0
var _frame_max_index: int = -1
var _frame_max_logic_us: int = 0
var _spike_count: int = 0
var _spike_idx := PackedInt32Array()
var _spike_ms := PackedFloat32Array()
var _spike_logic := PackedFloat32Array()
var _warmup_skip: int = 30
var _sample_limit: int = 0
var _screenshot_path: String = ""
var _shot_ready: bool = false


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	_read_args()
	_spike_idx.resize(SPIKE_CAP)
	_spike_ms.resize(SPIKE_CAP)
	_spike_logic.resize(SPIKE_CAP)
	_prewarm_spike_idx.resize(SPIKE_CAP)
	_prewarm_spike_ms.resize(SPIKE_CAP)
	_sort_scratch.resize(64)
	_camera = $ChaseCamera
	_ground = $Lane
	_label = $Overlay/Label
	_view = CrowdView.new()
	_view.name = "Crowd"
	add_child(_view)
	_view.setup()
	_view.set_toon_flags(_cel, _rim, _outline)
	_sim = CombatSim.new(GameClock, 360, BulletPool.DEFAULT_CAPACITY)
	_sim.auto_respawn = true
	_sim.contact_enabled = false
	_sim.squad.count = 24
	_sim.squad.forward_speed = SquadAnchor.FORWARD_SPEED_DEFAULT
	var weapon := (load("res://data/weapons/pistol.tres") as WeaponStats).duplicate() as WeaponStats
	weapon.pierce = 3
	_sim.squad.weapon = weapon
	_sim.squad.rate_bonus = 2.0
	_sim.squad.set_cooldown(0.0)
	_sim.profile = _profile
	_view.profile = _profile
	PhysicsServer3D.set_active(false)
	var toast: Node = load("res://scenes/ui/loss_toast.tscn").instantiate()
	toast.name = "LossToast"
	$Overlay.add_child(toast)
	toast.bind_squad(_sim.squad)
	_fill_mix(30, 20, ELITES, BOSSES)
	_view.sync(_sim)
	_batches_50 = _view.logical_batch_count()
	_instances_50 = _view.visible_body_instances()
	_style_label()
	_build_toggles()
	var panel := $Overlay/Panel as ColorRect
	panel.offset_right = 760.0
	panel.offset_bottom = 520.0
	_label.offset_bottom = 300.0
	_phase = 0


func _process(delta: float) -> void:
	if _finished:
		_save_screenshot()
		return
	if _phase == 0:
		var warmup := float(GameClock.gameplay_delta)
		_sim.tick(warmup)
		_view.sync(_sim)
		_follow_camera()
		_phase = 1
		return
	if _phase == 1:
		_gpu_draw_50 = _draw_calls()
		_fill_mix(WALKERS, RUNNERS, ELITES, BOSSES)
		_view.sync(_sim)
		_batches_300 = _view.logical_batch_count()
		_instances_300 = _view.visible_body_instances()
		_follow_camera()
		_phase = 2
		return
	if _phase == 2:
		_gpu_draw_300 = _draw_calls()
		_phase = 3
		return
	if _phase == 3:
		if _prewarm_frames < _prewarm_target:
			_run_prewarm_frame(delta)
			return
		_prepare_bench_samples()
		_phase = 4
		return
	var process_start := Time.get_ticks_usec()
	_profile.reset_frame()
	var gameplay := float(GameClock.gameplay_delta)
	_sim.squad.target_x = sin(GameClock.gameplay_time * 0.65) * 2.0
	_sim.tick(gameplay)
	_view.sync(_sim)
	_follow_camera()
	var overlay_start := Time.get_ticks_usec()
	if _bench_frames % _overlay_every == 0:
		_label.text = _overlay_text(delta)
	_profile.overlay_us = int(Time.get_ticks_usec() - overlay_start)
	_profile.process_us = int(Time.get_ticks_usec() - process_start)
	_record_profile()
	_note_frame(delta)
	_bench_frames += 1
	_bench_time += delta
	var draws_now := _draw_calls()
	var draws3d_now := _draw_calls_3d()
	_draw_min = mini(_draw_min, draws_now)
	_draw_max = maxi(_draw_max, draws_now)
	_draw3d_min = mini(_draw3d_min, draws3d_now)
	_draw3d_max = maxi(_draw3d_max, draws3d_now)
	if _limit >= 0 and _bench_frames >= _limit:
		_finish()


func _read_args() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			_limit = int(arg.trim_prefix("--frames="))
		elif arg.begins_with("--screenshot="):
			_screenshot_path = arg.trim_prefix("--screenshot=")
		elif arg.begins_with("--prewarm="):
			_prewarm_target = int(arg.trim_prefix("--prewarm="))
		elif arg.begins_with("--warmup-skip="):
			_warmup_skip = int(arg.trim_prefix("--warmup-skip="))
		elif arg == "--cel" or arg == "--cel=1":
			_cel = true
		elif arg == "--cel=0":
			_cel = false
		elif arg == "--rim" or arg == "--rim=1":
			_rim = true
		elif arg == "--rim=0":
			_rim = false
		elif arg == "--outline" or arg == "--outline=1":
			_outline = true
		elif arg == "--outline=0":
			_outline = false
	if _headless and _limit < 0:
		_limit = 120


func _build_toggles() -> void:
	var names: PackedStringArray = PackedStringArray(["卡通着色", "边缘光", "倒模描边"])
	var keys: PackedStringArray = PackedStringArray(["cel", "rim", "outline"])
	var pressed: Array[bool] = [_cel, _rim, _outline]
	var i := 0
	while i < names.size():
		var box := CheckBox.new()
		box.text = names[i]
		box.position = Vector2(32.0, 312.0 + float(i) * 48.0)
		box.size = Vector2(420.0, 44.0)
		box.add_theme_font_size_override("font_size", 26)
		box.add_theme_color_override("font_color", Color(0.95, 0.97, 0.98))
		box.add_theme_color_override("font_hover_color", Color(1, 1, 1))
		box.toggled.connect(_on_toon_box.bind(keys[i]))
		box.button_pressed = pressed[i]
		$Overlay.add_child(box)
		i += 1


func _on_toon_box(pressed: bool, key: String) -> void:
	match key:
		"cel":
			_cel = pressed
		"rim":
			_rim = pressed
		"outline":
			_outline = pressed
	if _view != null:
		_view.set_toon_flags(_cel, _rim, _outline)


func _run_prewarm_frame(delta: float) -> void:
	if _prewarm_frames == 0:
		_label.text = _overlay_text(delta)
	var gameplay := float(GameClock.gameplay_delta)
	_sim.squad.target_x = sin(GameClock.gameplay_time * 0.65) * 2.0
	_sim.tick(gameplay)
	_view.sync(_sim)
	_follow_camera()
	var ms := delta * 1000.0
	if ms >= _prewarm_max_ms:
		_prewarm_max_ms = ms
		_prewarm_max_index = _prewarm_frames
	if ms >= SPIKE_MS and _prewarm_spike_count < SPIKE_CAP:
		_prewarm_spike_idx[_prewarm_spike_count] = _prewarm_frames
		_prewarm_spike_ms[_prewarm_spike_count] = ms
		_prewarm_spike_count += 1
	_prewarm_frames += 1


func _prepare_bench_samples() -> void:
	_sample_limit = _limit if _limit > 0 else _FRAME_RING
	_resize_samples(_sample_limit)
	if _sort_scratch.size() < _sample_limit:
		_sort_scratch.resize(_sample_limit)
	if _frame_times.size() < _sample_limit:
		_frame_times.resize(_sample_limit)


func _resize_samples(n: int) -> void:
	_sample_combat.resize(n)
	_sample_squad.resize(n)
	_sample_rebuild.resize(n)
	_sample_query.resize(n)
	_sample_bullet.resize(n)
	_sample_view.resize(n)
	_sample_write.resize(n)
	_sample_upload.resize(n)
	_sample_overlay.resize(n)
	_sample_process.resize(n)
	_sample_logic.resize(n)


func _fill_mix(walkers: int, runners: int, elites: int, bosses: int) -> void:
	_sim.desired_walker = walkers
	_sim.desired_runner = runners
	_sim.desired_grunt = 0
	_sim.desired_elite = elites
	_sim.desired_boss = bosses
	_clear_enemies()
	_spawn_grid(walkers, runners, elites, bosses)
	_sim.maintain_counts()


func _clear_enemies() -> void:
	for i in _sim.enemies.capacity:
		if _sim.enemies.state[i] != EnemyPool.State.FREE:
			_sim.enemies.recycle(i)


func _spawn_grid(walkers: int, runners: int, elites: int, bosses: int) -> void:
	var columns := 15
	var spacing_x := 0.36
	var spacing_z := 0.85
	var origin_z := _sim.squad.position.z - 8.0
	var total := walkers + runners
	var walkers_left := walkers
	var runners_left := runners
	var walker := EnemyCatalog.walker()
	var runner := EnemyCatalog.runner()
	for slot in total:
		var use_runner := false
		if walkers_left <= 0:
			use_runner = true
		elif runners_left > 0 and slot % 5 >= 3:
			use_runner = true
		var col := slot % columns
		var row := int(slot / columns)
		var px := (float(col) - float(columns - 1) * 0.5) * spacing_x
		var pz := origin_z - float(row) * spacing_z
		var variant := fposmod(float(slot) * 0.17, 0.28)
		if use_runner:
			runners_left -= 1
			EnemyCatalog.place(_sim.enemies, runner, _sim.stage, px, pz, 0.32 + variant)
		else:
			walkers_left -= 1
			EnemyCatalog.place(_sim.enemies, walker, _sim.stage, px, pz, 0.05 + variant)
	var elite := EnemyCatalog.elite()
	for i in elites:
		var px := lerpf(-1.6, 1.6, float(i) / float(maxi(elites - 1, 1)))
		EnemyCatalog.place(_sim.enemies, elite, _sim.stage, px, _sim.squad.position.z - 14.0, 0.78 + float(i) * 0.04)
	if bosses > 0:
		_sim.spawn_at(EnemyPool.Archetype.BOSS, 0.0, _sim.squad.position.z - 22.0, 4000.0, 0.9, EnemyPool.BOSS_RADIUS, 0.55)


func _follow_camera() -> void:
	var anchor := _sim.squad.position
	_camera.position = Vector3(0.0, 8.5, anchor.z + 12.0)
	_camera.look_at(Vector3(0.0, 1.0, anchor.z - 16.0), Vector3.UP)
	_ground.position.z = anchor.z - 20.0


func _finish() -> void:
	if _finished:
		return
	_finished = true
	var enemies := _sim.enemies.active_count
	var expected := _sim.desired_walker + _sim.desired_runner + _sim.desired_elite + _sim.desired_boss
	if enemies != expected:
		push_error("Stress enemy count is %d, expected %d" % [enemies, expected])
	if _sim.enemies.count_species(EnemyPool.Species.WALKER) != WALKERS:
		push_error("Expected %d walkers" % WALKERS)
	if _sim.enemies.count_species(EnemyPool.Species.RUNNER) != RUNNERS:
		push_error("Expected %d runners" % RUNNERS)
	if _batches_50 != _batches_300 or _batches_50 <= 0:
		push_error("Draw batches changed with enemy count: %d vs %d" % [_batches_50, _batches_300])
	if _instances_300 <= _instances_50:
		push_error("Instance count did not grow from 50 to 300: %d vs %d" % [_instances_50, _instances_300])
	_print_spikes()
	print(_stats_line(0.0))
	if _screenshot_path != "":
		return
	if _limit >= 0:
		get_tree().quit()


func _save_screenshot() -> void:
	if _screenshot_path == "":
		return
	if not _shot_ready:
		var overlay := get_node_or_null("Overlay")
		if overlay != null:
			overlay.visible = false
		_shot_ready = true
		return
	var image := get_viewport().get_texture().get_image()
	var path := _screenshot_path
	if path.begins_with("res://"):
		path = ProjectSettings.globalize_path(path)
	image.save_png(path)
	print("STRESS_SCREENSHOT %s" % path)
	_screenshot_path = ""
	get_tree().quit()


func _print_spikes() -> void:
	print("STRESS_PREWARM frames=%d max_ms=%.3f max_index=%d spike_count=%d" % [
		_prewarm_frames, _prewarm_max_ms, _prewarm_max_index, _prewarm_spike_count
	])
	var i := 0
	while i < _prewarm_spike_count:
		print("STRESS_PREWARM_SPIKE index=%d frame_ms=%.3f" % [_prewarm_spike_idx[i], _prewarm_spike_ms[i]])
		i += 1
	i = 0
	while i < _spike_count:
		print("STRESS_SPIKE index=%d frame_ms=%.3f logic_ms=%.3f" % [_spike_idx[i], _spike_ms[i], _spike_logic[i]])
		i += 1


func _overlay_text(frame_delta: float) -> String:
	var fps := _fps()
	var low := _one_percent_low()
	var frame_ms := frame_delta * 1000.0
	var static_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
	var video_mb := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0)
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var draws := _draw_calls()
	var tris := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var visible := _sim.squad.visible_count()
	return "\n".join([
		"FPS %.1f    1%% low %.1f" % [fps, low],
		"帧时间 %.2f ms" % frame_ms,
		"内存 静态 %.1f MB / 显存 %.1f MB / 对象 %d" % [static_mb, video_mb, objects],
		"绘制 %d    三角形 %d" % [draws, tris],
		"敌人 %d（走 %d / 跑 %d）    小队 %d（可见 %d）" % [_sim.enemies.active_count, _sim.enemies.count_species(EnemyPool.Species.WALKER), _sim.enemies.count_species(EnemyPool.Species.RUNNER), _sim.squad.count, visible],
		"逻辑 %.2f ms    时钟 ×%.2f" % [_last_logic_ms(), float(GameClock.scale)],
		"卡通 %s  边缘光 %s  描边 %s" % [_on_off(_cel), _on_off(_rim), _on_off(_outline)],
	])


func _on_off(flag: bool) -> String:
	return "开" if flag else "关"


func _stats_line(frame_delta: float) -> String:
	var static_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
	var video_mb := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0)
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var draws := _draw_calls()
	var tris := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var frame_ms := (_bench_time / float(maxi(_bench_frames, 1))) * 1000.0
	if frame_delta > 0.0:
		frame_ms = frame_delta * 1000.0
	var max_logic := float(_frame_max_logic_us) / 1000.0
	return "STRESS_STATS fps=%.2f fps_1pct_low=%.2f frame_ms=%.3f memory_static_mb=%.2f memory_video_mb=%.2f objects=%d draw_calls=%d draw_calls_min=%d draw_calls_max=%d draw3d_min=%d draw3d_max=%d triangles=%d enemies=%d batches_50=%d batches_300=%d instances_50=%d instances_300=%d gpu_draw_50=%d gpu_draw_300=%d logic_avg_ms=%.3f logic_p99_ms=%.3f process_avg_ms=%.3f process_p99_ms=%.3f combat_avg_ms=%.3f combat_p99_ms=%.3f squad_avg_ms=%.3f squad_p99_ms=%.3f hash_rebuild_avg_ms=%.3f hash_rebuild_p99_ms=%.3f hash_query_avg_ms=%.3f hash_query_p99_ms=%.3f bullet_avg_ms=%.3f bullet_p99_ms=%.3f view_avg_ms=%.3f view_p99_ms=%.3f view_write_avg_ms=%.3f view_write_p99_ms=%.3f view_upload_avg_ms=%.3f view_upload_p99_ms=%.3f overlay_avg_ms=%.3f overlay_p99_ms=%.3f body_tris=%d walkers=%d runners=%d elites=%d debug_build=%d cores=%d frame_max_ms=%.3f frame_max_index=%d frame_max_logic_ms=%.3f spike_count=%d warmup_skip=%d fps_1pct_low_ex_warmup=%.2f prewarm_frames=%d prewarm_max_ms=%.3f prewarm_max_index=%d prewarm_spike_count=%d cel=%d rim=%d outline=%d" % [
		_fps(),
		_one_percent_low(),
		frame_ms,
		static_mb,
		video_mb,
		objects,
		draws,
		_draw_min,
		_draw_max,
		_draw3d_min,
		_draw3d_max,
		tris,
		_sim.enemies.active_count,
		_batches_50,
		_batches_300,
		_instances_50,
		_instances_300,
		_gpu_draw_50,
		_gpu_draw_300,
		_avg_ms(_sample_logic),
		_p99_ms(_sample_logic),
		_avg_ms(_sample_process),
		_p99_ms(_sample_process),
		_avg_ms(_sample_combat),
		_p99_ms(_sample_combat),
		_avg_ms(_sample_squad),
		_p99_ms(_sample_squad),
		_avg_ms(_sample_rebuild),
		_p99_ms(_sample_rebuild),
		_avg_ms(_sample_query),
		_p99_ms(_sample_query),
		_avg_ms(_sample_bullet),
		_p99_ms(_sample_bullet),
		_avg_ms(_sample_view),
		_p99_ms(_sample_view),
		_avg_ms(_sample_write),
		_p99_ms(_sample_write),
		_avg_ms(_sample_upload),
		_p99_ms(_sample_upload),
		_avg_ms(_sample_overlay),
		_p99_ms(_sample_overlay),
		_view.body_triangles(),
		_sim.enemies.count_species(EnemyPool.Species.WALKER),
		_sim.enemies.count_species(EnemyPool.Species.RUNNER),
		_sim.enemies.count_species(EnemyPool.Species.ELITE),
		1 if OS.is_debug_build() else 0,
		OS.get_processor_count(),
		_frame_max_ms,
		_frame_max_index,
		max_logic,
		_spike_count,
		_warmup_skip,
		_one_percent_low_excluding(_warmup_skip),
		_prewarm_frames,
		_prewarm_max_ms,
		_prewarm_max_index,
		_prewarm_spike_count,
		1 if _cel else 0,
		1 if _rim else 0,
		1 if _outline else 0,
	]


func _record_profile() -> void:
	if _sample_limit <= 0:
		return
	var i := _bench_frames % _sample_limit
	_sample_combat[i] = _profile.combat_us
	_sample_squad[i] = _profile.squad_us
	_sample_rebuild[i] = _profile.hash_rebuild_us
	_sample_query[i] = _profile.hash_query_us
	_sample_bullet[i] = _profile.bullet_us
	_sample_view[i] = _profile.view_us
	_sample_write[i] = _profile.view_write_us
	_sample_upload[i] = _profile.view_upload_us
	_sample_overlay[i] = _profile.overlay_us
	_sample_process[i] = _profile.process_us
	_sample_logic[i] = _profile.combat_us + _profile.view_us + _profile.overlay_us


func _note_frame(delta: float) -> void:
	if _frame_times.size() == 0:
		return
	var ms := delta * 1000.0
	var slot := _bench_frames % _frame_times.size()
	_frame_times[slot] = delta
	if _frame_max_index < 0 or ms >= _frame_max_ms:
		_frame_max_ms = ms
		_frame_max_index = _bench_frames
		_frame_max_logic_us = _profile.combat_us + _profile.view_us + _profile.overlay_us
	if ms >= SPIKE_MS and _spike_count < SPIKE_CAP:
		_spike_idx[_spike_count] = _bench_frames
		_spike_ms[_spike_count] = ms
		_spike_logic[_spike_count] = float(_profile.combat_us + _profile.view_us + _profile.overlay_us) / 1000.0
		_spike_count += 1


func _used_samples() -> int:
	if _sample_limit <= 0:
		return 0
	return mini(_bench_frames, _sample_limit)


func _avg_ms(samples: PackedInt32Array) -> float:
	var n := _used_samples()
	if n <= 0:
		return 0.0
	var sum := 0
	var i := 0
	while i < n:
		sum += samples[i]
		i += 1
	return float(sum) / float(n) / 1000.0


func _p99_ms(samples: PackedInt32Array) -> float:
	var n := _used_samples()
	if n <= 0:
		return 0.0
	var copy := PackedInt32Array()
	copy.resize(n)
	var i := 0
	while i < n:
		copy[i] = samples[i]
		i += 1
	copy.sort()
	var idx := clampi(int(ceil(float(n) * 0.99)) - 1, 0, n - 1)
	return float(copy[idx]) / 1000.0


func _fps() -> float:
	if _bench_time <= 0.0001:
		return 0.0
	return float(_bench_frames) / _bench_time


func _one_percent_low() -> float:
	var count := _bench_frames
	if _frame_times.size() > 0:
		count = mini(count, _frame_times.size())
	return _one_percent_low_range(0, count)


func _one_percent_low_excluding(skip: int) -> float:
	var count := _bench_frames
	if _frame_times.size() > 0:
		count = mini(count, _frame_times.size())
	var start := mini(maxi(skip, 0), count)
	return _one_percent_low_range(start, count - start)


func _one_percent_low_range(start: int, count: int) -> float:
	if count <= 0 or _frame_times.size() == 0:
		return 0.0
	if _sort_scratch.size() < count:
		_sort_scratch.resize(count)
	var i := 0
	while i < count:
		_sort_scratch[i] = _frame_times[start + i]
		i += 1
	_sort_prefix(count)
	var worst_n := maxi(1, int(ceil(float(count) * 0.01)))
	var sum := 0.0
	var w := 0
	while w < worst_n:
		sum += _sort_scratch[count - 1 - w]
		w += 1
	var worst := sum / float(worst_n)
	if worst <= 0.0000001:
		return 0.0
	return 1.0 / worst


func _sort_prefix(n: int) -> void:
	if n <= 1:
		return
	var start := n >> 1
	while start > 0:
		start -= 1
		_sift(start, n)
	var end := n
	while end > 1:
		end -= 1
		var tmp := _sort_scratch[0]
		_sort_scratch[0] = _sort_scratch[end]
		_sort_scratch[end] = tmp
		_sift(0, end)


func _sift(root: int, n: int) -> void:
	while true:
		var child := root * 2 + 1
		if child >= n:
			return
		if child + 1 < n and _sort_scratch[child] < _sort_scratch[child + 1]:
			child += 1
		if _sort_scratch[root] >= _sort_scratch[child]:
			return
		var tmp := _sort_scratch[root]
		_sort_scratch[root] = _sort_scratch[child]
		_sort_scratch[child] = tmp
		root = child


func _last_logic_ms() -> float:
	var n := _used_samples()
	if n <= 0:
		return 0.0
	return float(_sample_logic[n - 1]) / 1000.0


func _draw_calls() -> int:
	return int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))


func _draw_calls_3d() -> int:
	var vp := get_viewport().get_viewport_rid()
	return RenderingServer.viewport_get_render_info(
		vp,
		RenderingServer.VIEWPORT_RENDER_INFO_TYPE_VISIBLE,
		RenderingServer.VIEWPORT_RENDER_INFO_DRAW_CALLS_IN_FRAME
	)


func _style_label() -> void:
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", Color(0.95, 0.97, 0.98))
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 8)
