extends Node3D
## 300 grunts, 3 elites, and 1 boss walking into squad fire.
## Headless: run N frames, print STRESS_STATS, quit.


const GRUNTS := 300
const ELITES := 3
const BOSSES := 1

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
var _frame_ring := PackedFloat32Array()
var _frame_ring_i: int = 0
var _frame_ring_filled: bool = false
const _FRAME_RING := 4096
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


func _ready() -> void:
	_headless = DisplayServer.get_name() == "headless"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--frames="):
			_limit = int(arg.trim_prefix("--frames="))
	if _headless and _limit < 0:
		_limit = 120
	_camera = $ChaseCamera
	_ground = $Lane
	_label = $Overlay/Label
	_view = CrowdView.new()
	_view.name = "Crowd"
	add_child(_view)
	_view.setup()
	_sim = CombatSim.new(GameClock, 360, BulletPool.DEFAULT_CAPACITY)
	_sim.auto_respawn = true
	_sim.squad.count = 24
	_sim.squad.forward_speed = SquadAnchor.FORWARD_SPEED_DEFAULT
	var weapon := (load("res://data/weapons/pistol.tres") as WeaponStats).duplicate() as WeaponStats
	weapon.pierce = 3
	_sim.squad.weapon = weapon
	_sim.squad.rate_bonus = 2.0
	_sim.squad.set_cooldown(0.0)
	_sim.profile = _profile
	_view.profile = _profile
	# Crowd combat does not use the physics server. Leaving it on still steps an empty world.
	PhysicsServer3D.set_active(false)
	_fill(50, ELITES, BOSSES)
	_view.sync(_sim)
	_batches_50 = _view.logical_batch_count()
	_instances_50 = _view.visible_body_instances()
	_style_label()
	_phase = 0


func _process(delta: float) -> void:
	if _finished:
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
		_fill(GRUNTS, ELITES, BOSSES)
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
	_bench_frames += 1
	_bench_time += delta
	_push_frame_time(delta)
	var draws_now := _draw_calls()
	var draws3d_now := _draw_calls_3d()
	_draw_min = mini(_draw_min, draws_now)
	_draw_max = maxi(_draw_max, draws_now)
	_draw3d_min = mini(_draw3d_min, draws3d_now)
	_draw3d_max = maxi(_draw3d_max, draws3d_now)
	if _limit >= 0 and _bench_frames >= _limit:
		_finish()


func _fill(grunts: int, elites: int, bosses: int) -> void:
	_sim.desired_grunt = grunts
	_sim.desired_elite = elites
	_sim.desired_boss = bosses
	_clear_enemies()
	_spawn_grid(grunts, elites, bosses)
	_sim.maintain_counts()


func _clear_enemies() -> void:
	for i in _sim.enemies.capacity:
		if _sim.enemies.state[i] != EnemyPool.State.FREE:
			_sim.enemies.recycle(i)


func _spawn_grid(grunts: int, elites: int, bosses: int) -> void:
	var columns := 15
	var spacing_x := 0.36
	var spacing_z := 0.85
	var origin_z := _sim.squad.position.z - 8.0
	for i in grunts:
		var col := i % columns
		var row := int(i / columns)
		var px := (float(col) - float(columns - 1) * 0.5) * spacing_x
		var pz := origin_z - float(row) * spacing_z
		_sim.spawn_at(EnemyPool.Archetype.GRUNT, px, pz, 20.0, 1.6, EnemyPool.GRUNT_RADIUS, fposmod(float(i) * 0.17, 0.45))
	for i in elites:
		var px := lerpf(-1.6, 1.6, float(i) / float(maxi(elites - 1, 1)))
		_sim.spawn_at(EnemyPool.Archetype.ELITE, px, _sim.squad.position.z - 14.0, 180.0, 1.1, EnemyPool.ELITE_RADIUS, 0.8)
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
	var expected := _sim.desired_grunt + _sim.desired_elite + _sim.desired_boss
	if enemies != expected:
		push_error("Stress enemy count is %d, expected %d" % [enemies, expected])
	if _batches_50 != _batches_300 or _batches_50 <= 0:
		push_error("Draw batches changed with enemy count: %d vs %d" % [_batches_50, _batches_300])
	if _instances_300 <= _instances_50:
		push_error("Instance count did not grow from 50 to 300: %d vs %d" % [_instances_50, _instances_300])
	var stats := _stats_line(0.0)
	print(stats)
	if _limit >= 0:
		get_tree().quit()


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
		"敌人 %d    小队 %d（可见 %d）" % [_sim.enemies.active_count, _sim.squad.count, visible],
		"逻辑 %.2f ms    时钟 ×%.2f" % [_last_logic_ms(), float(GameClock.scale)],
	])


func _stats_line(frame_delta: float) -> String:
	var static_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
	var video_mb := Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0)
	var objects := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var draws := _draw_calls()
	var tris := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var frame_ms := (_bench_time / float(maxi(_bench_frames, 1))) * 1000.0
	if frame_delta > 0.0:
		frame_ms = frame_delta * 1000.0
	return "STRESS_STATS fps=%.2f fps_1pct_low=%.2f frame_ms=%.3f memory_static_mb=%.2f memory_video_mb=%.2f objects=%d draw_calls=%d draw_calls_min=%d draw_calls_max=%d draw3d_min=%d draw3d_max=%d triangles=%d enemies=%d batches_50=%d batches_300=%d instances_50=%d instances_300=%d gpu_draw_50=%d gpu_draw_300=%d logic_avg_ms=%.3f logic_p99_ms=%.3f process_avg_ms=%.3f process_p99_ms=%.3f combat_avg_ms=%.3f combat_p99_ms=%.3f squad_avg_ms=%.3f squad_p99_ms=%.3f hash_rebuild_avg_ms=%.3f hash_rebuild_p99_ms=%.3f hash_query_avg_ms=%.3f hash_query_p99_ms=%.3f bullet_avg_ms=%.3f bullet_p99_ms=%.3f view_avg_ms=%.3f view_p99_ms=%.3f view_write_avg_ms=%.3f view_write_p99_ms=%.3f view_upload_avg_ms=%.3f view_upload_p99_ms=%.3f overlay_avg_ms=%.3f overlay_p99_ms=%.3f debug_build=%d cores=%d" % [
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
		1 if OS.is_debug_build() else 0,
		OS.get_processor_count(),
	]


func _record_profile() -> void:
	_sample_combat.append(_profile.combat_us)
	_sample_squad.append(_profile.squad_us)
	_sample_rebuild.append(_profile.hash_rebuild_us)
	_sample_query.append(_profile.hash_query_us)
	_sample_bullet.append(_profile.bullet_us)
	_sample_view.append(_profile.view_us)
	_sample_write.append(_profile.view_write_us)
	_sample_upload.append(_profile.view_upload_us)
	_sample_overlay.append(_profile.overlay_us)
	_sample_process.append(_profile.process_us)
	_sample_logic.append(_profile.combat_us + _profile.view_us + _profile.overlay_us)


func _avg_ms(samples: PackedInt32Array) -> float:
	if samples.is_empty():
		return 0.0
	var sum := 0
	for v in samples:
		sum += v
	return float(sum) / float(samples.size()) / 1000.0


func _p99_ms(samples: PackedInt32Array) -> float:
	if samples.is_empty():
		return 0.0
	var copy := samples.duplicate()
	copy.sort()
	var idx := clampi(int(ceil(float(copy.size()) * 0.99)) - 1, 0, copy.size() - 1)
	return float(copy[idx]) / 1000.0


func _fps() -> float:
	if _bench_time <= 0.0001:
		return 0.0
	return float(_bench_frames) / _bench_time


func _push_frame_time(delta: float) -> void:
	if _frame_ring.size() != _FRAME_RING:
		_frame_ring.resize(_FRAME_RING)
	_frame_ring[_frame_ring_i] = delta
	_frame_ring_i += 1
	if _frame_ring_i >= _FRAME_RING:
		_frame_ring_i = 0
		_frame_ring_filled = true


func _one_percent_low() -> float:
	var count := _FRAME_RING if _frame_ring_filled else _frame_ring_i
	if count <= 0:
		return 0.0
	var sorted := PackedFloat32Array()
	sorted.resize(count)
	var i := 0
	while i < count:
		sorted[i] = _frame_ring[i]
		i += 1
	sorted.sort()
	var n := maxi(1, int(ceil(float(count) * 0.01)))
	var sum := 0.0
	var w := 0
	while w < n:
		sum += sorted[count - 1 - w]
		w += 1
	var worst := sum / float(n)
	if worst <= 0.0000001:
		return 0.0
	return 1.0 / worst


func _last_logic_ms() -> float:
	if _sample_logic.is_empty():
		return 0.0
	return float(_sample_logic[_sample_logic.size() - 1]) / 1000.0


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
