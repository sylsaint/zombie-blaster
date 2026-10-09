extends GutTest
## Boots the main scene, taps 开始 then 第 1 关, and runs the real level.


const _Clock := preload("res://scripts/game_clock.gd")


const RUN_SECONDS := 15.0
const FRAME_CAP := 8000


func test_level1_spawns_gates_squad_and_zombies() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main := packed.instantiate()
	add_child_autofree(main)
	await get_tree().process_frame
	var menu := main.get_node("UI/MainMenu") as MainMenu
	var play := menu.get_node("%Play") as Button
	assert_eq(play.text, "开始")
	assert_true(menu.visible)
	play.pressed.emit()
	await get_tree().process_frame
	var select := main.get_node("UI/LevelSelect") as LevelSelect
	var level_button := select.get_node("%Level1") as Button
	assert_false(level_button.disabled)
	assert_eq(level_button.text, "第 1 关")
	level_button.pressed.emit()

	var host := main.get_node("LevelHost") as LevelHost
	assert_not_null(host.session, "level 1 did not start")
	assert_eq(host.session.level.level_index, 1)
	_assert_opening(host.session.level)
	assert_false((main.get_node("Player/Body") as GeometryInstance3D).visible)
	assert_false((main.get_node("Player/BlobShadow") as GeometryInstance3D).visible)
	_assert_gates_match_level(host)
	_assert_drag_steers_the_squad(main, host)

	var add_gate := _first_add_gate(host.session.level)
	assert_not_null(add_gate, "level 1 has no add-soldier gate")
	var add_side := _add_side(add_gate)
	var squad := host.session.sim.squad
	var clock := get_node("/root/GameClock")
	var started := float(clock.gameplay_time)
	var prev_count := squad.count
	var prev_traveled := host.session.traveled
	var count_before := -1
	var count_after := -1
	var crossed := false
	var soldiers_seen := 0
	var enemies_seen := 0
	var spawned := 0
	# 15 s of gameplay through the same LevelHost._process the scene runs.
	# Stepping the clock keeps the run on game time instead of a stalled frame.
	var steps := int(round(RUN_SECONDS / 0.05))
	var frames := 0
	while frames < steps and frames < FRAME_CAP:
		_pin_add_side(squad, add_side)
		clock.advance(0.05)
		host._process(0.05)
		frames += 1
		if host.session == null or host.session.sim == null:
			break
		squad = host.session.sim.squad
		soldiers_seen = maxi(soldiers_seen, _visible(host.crowd.squad_body_mm))
		enemies_seen = maxi(enemies_seen, _enemy_instances(host.crowd))
		spawned = maxi(spawned, host.session.sim.enemies.kill_count + host.session.grunt_alive())
		var outside := _enemy_outside_lane(host.session.sim.enemies)
		assert_eq(outside, -1, _lane_miss_text(host.session.sim.enemies, outside))
		if not crossed and prev_traveled < add_gate.distance and host.session.traveled + 0.0001 >= add_gate.distance:
			count_before = prev_count
			count_after = squad.count
			crossed = true
		prev_count = squad.count
		prev_traveled = host.session.traveled
	assert_almost_eq(float(clock.gameplay_time) - started, RUN_SECONDS, 0.06, "clock did not advance %s s (%d steps)" % [RUN_SECONDS, frames])
	assert_true(crossed, "squad never reached the add gate at %.1f m (traveled %.2f, soldiers %d)" % [add_gate.distance, host.session.traveled, squad.count])
	assert_ne(count_after, count_before, "add gate did not change the soldier count (%d)" % count_before)
	assert_gt(count_after, count_before, "add gate lowered the squad from %d to %d" % [count_before, count_after])
	assert_gt(host.crowd.squad_body_mm.multimesh.instance_count, 0)
	assert_gt(host.crowd.squad_weapon_mm.multimesh.instance_count, 0)
	assert_gt(host.crowd.grunt_mm.multimesh.instance_count, 0)
	assert_gt(soldiers_seen, 0, "soldier MultiMesh never drew an instance")
	assert_gt(enemies_seen, 0, "enemy MultiMesh never drew an instance")
	assert_gt(spawned, 0, "no zombies spawned")
	assert_gt(squad.count, 0, "the squad was wiped before 15 s")
	assert_null(host.session.result)


func _assert_gates_match_level(host: LevelHost) -> void:
	var level := host.session.level
	var configured := level.gate_groups()
	assert_eq(configured.size(), level.gate_group_count)
	assert_gt(configured.size(), 0)
	assert_eq(host.gate_groups.size(), configured.size())
	var expected_spans := 0
	var i := 0
	while i < configured.size():
		var event := configured[i]
		var group := host.gate_groups[i] as GateGroup
		assert_not_null(group)
		assert_almost_eq(group.z, -event.distance, 0.001)
		assert_eq(group.spans.size(), event.gates.size())
		var s := 0
		while s < event.gates.size():
			var spec := event.gates[s] as GateSpec
			var span := group.spans[s] as GateSpan
			var built := LevelHost.span_for_spec(spec)
			assert_eq(span.kind, spec.kind)
			assert_almost_eq(span.amount, spec.amount, 0.001)
			assert_almost_eq(span.x_min, built.x_min, 0.001)
			assert_almost_eq(span.x_max, built.x_max, 0.001)
			expected_spans += 1
			s += 1
		i += 1
	var meshes := 0
	var labels := 0
	for child in host.gates.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			meshes += 1
		elif child is Label3D and (child as Label3D).visible:
			labels += 1
			assert_ne((child as Label3D).text, "")
	assert_eq(meshes, expected_spans)
	assert_eq(labels, expected_spans)


func _assert_drag_steers_the_squad(main: Node, host: LevelHost) -> void:
	var squad := host.session.sim.squad
	var before := squad.target_x
	var width := main.get_viewport().get_visible_rect().size.x
	assert_gt(width, 0.0)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(width * 0.5, 400.0)
	drag.relative = Vector2(width * 0.25, 0.0)
	drag.velocity = drag.relative
	main.get_viewport().push_input(drag)
	assert_gt(squad.target_x, before, "drag did not move the squad")


func _pin_add_side(squad: SquadAnchor, side: String) -> void:
	if side == "right":
		squad.target_x = SquadAnchor.LANE_HALF_WIDTH
	elif side == "full":
		squad.target_x = 0.0
	else:
		squad.target_x = -SquadAnchor.LANE_HALF_WIDTH


func _first_add_gate(level: LevelData) -> LevelEvent:
	for event in level.sorted_events():
		if event.kind != "gate_group":
			continue
		if _add_side(event) != "":
			return event
	return null


func _add_side(event: LevelEvent) -> String:
	for spec in event.gates:
		var gate := spec as GateSpec
		if gate != null and gate.kind == GateRules.ADD:
			return gate.side
	return ""


func _enemy_outside_lane(enemies: EnemyPool) -> int:
	var a := 0
	while a < enemies.active_n:
		var id := enemies.active_ids[a]
		a += 1
		if enemies.state[id] == EnemyPool.State.FREE:
			continue
		var limit := LaneMotion.body_limit(LaneMotion.body_reach(enemies.radius[id], enemies.species[id]))
		if absf(enemies.x[id]) > limit + 0.0001:
			return id
	return -1


func _lane_miss_text(enemies: EnemyPool, id: int) -> String:
	if id < 0:
		return ""
	var limit := LaneMotion.body_limit(LaneMotion.body_reach(enemies.radius[id], enemies.species[id]))
	return "enemy %d x=%.3f radius=%.3f left the lane (limit ±%.3f)" % [id, enemies.x[id], enemies.radius[id], limit]


func _visible(node: MultiMeshInstance3D) -> int:
	if node == null or node.multimesh == null:
		return 0
	return node.multimesh.visible_instance_count


func test_level1_idle_and_add_gates_report_distance() -> void:
	var level := LevelCatalog.load_index(1)
	_assert_opening(level)
	var idle := _reach(level, false)
	var adds := _reach(level, true)
	print("LEVEL1_REACH no_input=%.2f add_gates=%.2f" % [idle["distance"], adds["distance"]])
	var gate_d: float = _opening_gate(level).distance
	var elite_d := 0.0
	for event in level.sorted_events():
		if event.kind == "finale_elite":
			elite_d = event.distance
			break
	assert_true(bool(idle["past_gate"]), "zero input died at %.2f m, before the first gate at %.1f m" % [idle["distance"], gate_d])
	assert_gt(float(idle["distance"]), gate_d)
	# The last step can land a fraction under the authored distance.
	assert_gte(float(adds["distance"]), elite_d - 0.05, "add-soldier route stopped at %.2f m, short of the elite at %.1f m" % [adds["distance"], elite_d])
	assert_eq(String(adds["state"]), "finale")
	assert_gt(int(adds["count"]), 0)
	assert_eq(int(adds["weapon"]), 1, "add-only route took a weapon gate")


func _assert_opening(level: LevelData) -> void:
	var gate := _opening_gate(level)
	assert_not_null(gate)
	assert_almost_eq(gate.distance, 15.0, 0.001, "first gate group")
	var left: GateSpec = null
	var right: GateSpec = null
	for spec in gate.gates:
		var item := spec as GateSpec
		if item == null:
			continue
		if item.side == "left":
			left = item
		elif item.side == "right":
			right = item
	assert_not_null(right)
	assert_not_null(left)
	assert_eq(right.kind, GateRules.ADD, "x = 0 is the right gate, so that side adds soldiers")
	assert_almost_eq(right.amount, float(level.add_gate_amount()), 0.001)
	assert_eq(left.kind, GateRules.WEAPON)
	assert_almost_eq(left.amount, 1.0, 0.001)
	var first_wave: LevelEvent = null
	var saw_eight := false
	for event in level.sorted_events():
		if event.kind != "wave":
			continue
		if absf(event.distance - 8.0) <= 0.001:
			saw_eight = true
		if first_wave == null:
			first_wave = event
	assert_false(saw_eight, "the 8 m wave should be gone")
	assert_not_null(first_wave)
	assert_gt(first_wave.distance, gate.distance, "first wave must come after the first gate")
	assert_almost_eq(first_wave.distance, 20.0, 0.001, "former 20 m wave")
	assert_eq(first_wave.count, 15, "former 20 m wave, halved from 30")
	assert_false(level.wave_inside_gate_clearance(), "AC-GT-04")
	var second := _gate_at(level, 1)
	assert_not_null(second)
	assert_almost_eq(second.distance, 48.0, 0.001, "second add gate sits before the 60 m wave")


func _opening_gate(level: LevelData) -> LevelEvent:
	return _gate_at(level, 0)


func _gate_at(level: LevelData, index: int) -> LevelEvent:
	var n := 0
	for event in level.sorted_events():
		if event.kind != "gate_group":
			continue
		if n == index:
			return event
		n += 1
	return null


func _reach(level: LevelData, pick_add: bool) -> Dictionary:
	var session := LevelSession.new()
	session.start(level, autofree(_Clock.new()))
	var gate_d: float = _opening_gate(level).distance
	var elite_d := level.finale_distance()
	var past := false
	var step := 0.05
	var guard := 0
	while guard < 4000 and session.state != "win" and session.state != "lose":
		if pick_add:
			_steer_add(session)
		session.tick(step)
		guard += 1
		if session.traveled > gate_d + 0.05 and session.sim.squad.count > 0:
			past = true
		if session.state == "finale" and session.traveled + 0.001 >= elite_d:
			break
	return {
		"distance": session.traveled,
		"state": session.state,
		"count": session.sim.squad.count,
		"weapon": session.weapon_level,
		"past_gate": past,
	}


func _steer_add(session: LevelSession) -> void:
	var side := ""
	for event in session.level.sorted_events():
		if event.kind != "gate_group" or event.distance + 0.001 < session.traveled:
			continue
		for spec in event.gates:
			var gate := spec as GateSpec
			if gate != null and gate.kind == GateRules.ADD:
				side = gate.side
				break
		break
	var squad := session.sim.squad
	if side == "left":
		squad.target_x = -SquadAnchor.LANE_HALF_WIDTH
	elif side == "right":
		squad.target_x = SquadAnchor.LANE_HALF_WIDTH
	else:
		squad.target_x = 0.0


func _enemy_instances(crowd: CrowdView) -> int:
	var total := 0
	for node in [crowd.grunt_mm, crowd.walker_lod_mm, crowd.runner_mm, crowd.runner_lod_mm]:
		total += _visible(node)
	return total
