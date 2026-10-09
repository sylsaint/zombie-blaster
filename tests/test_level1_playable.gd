extends GutTest
## Boots the main scene, taps 开始 then 第 1 关, and runs the real level.


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


func _visible(node: MultiMeshInstance3D) -> int:
	if node == null or node.multimesh == null:
		return 0
	return node.multimesh.visible_instance_count


func _enemy_instances(crowd: CrowdView) -> int:
	var total := 0
	for node in [crowd.grunt_mm, crowd.walker_lod_mm, crowd.runner_mm, crowd.runner_lod_mm]:
		total += _visible(node)
	return total
