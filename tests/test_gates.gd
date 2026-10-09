extends GutTest

const _Clock := preload("res://scripts/game_clock.gd")


func test_add_multiply_subtract_and_the_cap() -> void:
	var squad := SquadAnchor.new()
	squad.count = 10
	assert_eq(GateRules.apply_add(squad, 6), "+6")
	assert_eq(squad.count, 16)
	assert_eq(GateRules.apply_mul(squad, 2), "×2")
	assert_eq(squad.count, 32)
	assert_eq(GateRules.apply_sub(squad, 5), "−5")
	assert_eq(squad.count, 27)
	squad.count = 3
	GateRules.apply_sub(squad, 10)
	assert_eq(squad.count, 0)
	squad.count = 140
	assert_eq(GateRules.apply_add(squad, 10), "+10")
	assert_eq(squad.count, 150)
	assert_eq(GateRules.apply_add(squad, 4), "已满")
	assert_eq(squad.count, 150)
	assert_eq(GateRules.apply_mul(squad, 2), "已满")
	assert_eq(squad.count, 150)


func test_ed06_multiply_at_149_caps_and_says_full() -> void:
	var squad := SquadAnchor.new()
	squad.count = 149
	assert_eq(GateRules.apply_mul(squad, 2), "已满")
	assert_eq(squad.count, 150)
	squad.count = 50
	assert_eq(GateRules.apply_mul(squad, 3), "×3")
	assert_eq(squad.count, 150)


func test_divide_is_not_applied() -> void:
	var squad := SquadAnchor.new()
	squad.count = 10
	var span := _span(GateRules.DIVIDE, 2.0, -3.75, 3.75)
	assert_eq(GateRules.apply_span(squad, span), "")
	assert_eq(squad.count, 10)
	assert_false(GateRules.is_benefit(GateRules.DIVIDE, 2.0))


func test_fire_rate_stacks_additively_without_a_cap() -> void:
	var squad := SquadAnchor.new()
	var i := 0
	while i < 8:
		assert_eq(GateRules.apply_fire_rate(squad), "射速+15%")
		i += 1
	assert_almost_eq(squad.rate_bonus, 0.15 * 8.0, 0.0001)
	assert_almost_eq(squad.current_interval(), 0.4 / (1.0 + 0.15 * 8.0), 0.0001)


func test_weapon_gate_stops_at_m1_max_then_adds_damage() -> void:
	var squad := SquadAnchor.new()
	assert_eq(squad.weapon_tier(), 1)
	assert_eq(GateRules.apply_weapon(squad), "武器+1")
	assert_eq(squad.weapon_tier(), 2)
	assert_eq(squad.outfit_tier(), 2)
	assert_eq(squad.weapon.weapon_name, "步枪")
	assert_almost_eq(squad.weapon.damage, 12.0, 0.001)
	assert_almost_eq(squad.weapon.interval, 0.2, 0.001)
	squad.damage_bonus = 0.1
	assert_eq(GateRules.apply_weapon(squad), "伤害+20%")
	assert_eq(squad.weapon_tier(), 2)
	assert_almost_eq(squad.damage_bonus, 0.3, 0.0001)
	assert_eq(GateRules.apply_weapon(squad), "伤害+20%")
	assert_almost_eq(squad.damage_bonus, 0.5, 0.0001)
	assert_lt(squad.weapon_tier(), 3)


func test_one_span_per_group_and_the_shared_edge() -> void:
	var squad := SquadAnchor.new()
	squad.count = 10
	squad.forward_speed = 0.0
	squad.set_cooldown(10.0)
	squad.position.x = 0.0
	squad.target_x = 0.0
	var left := _span(GateRules.ADD, 1.0, -3.75, 0.0)
	var right := _span(GateRules.ADD, 10.0, 0.0, 3.75)
	var group := _group(-1.0, [left, right])
	var runner := GateRunner.new()
	runner.set_groups([group], squad.position.z)
	_cross(runner, squad, 4.0)
	assert_eq(squad.count, 20, "x = 0 belongs to the right span only")
	assert_eq(runner.banner_count, 1)
	assert_eq(runner.banners[0], "+10")
	var again := squad.count
	_cross(runner, squad, 4.0)
	assert_eq(squad.count, again, "a group does not trigger twice")


func test_a_miss_still_consumes_the_group() -> void:
	var squad := SquadAnchor.new()
	squad.count = 7
	squad.forward_speed = 0.0
	squad.position.x = 0.0
	squad.target_x = 0.0
	var group := _group(-1.0, [
		_span(GateRules.ADD, 5.0, -3.75, -1.0),
		_span(GateRules.ADD, 5.0, 1.0, 3.75),
	])
	var nxt := _group(-3.0, [_span(GateRules.ADD, 2.0, -3.75, 3.75)])
	var runner := GateRunner.new()
	runner.set_groups([nxt, group], 0.0)
	_cross(runner, squad, 4.0)
	assert_eq(squad.count, 9)


func test_two_weapon_gates_in_one_tick_use_the_final_tier() -> void:
	var squad := SquadAnchor.new()
	squad.forward_speed = 0.0
	squad.position.x = 0.0
	squad.target_x = 0.0
	var runner := GateRunner.new()
	runner.set_groups([
		_group(-1.0, [_span(GateRules.WEAPON, 1.0, -3.75, 3.75)]),
		_group(-2.0, [_span(GateRules.WEAPON, 1.0, -3.75, 3.75)]),
	], 0.0)
	_cross(runner, squad, 8.0)
	assert_eq(runner.banner_count, 2)
	assert_eq(runner.banners[0], "武器+1")
	assert_eq(runner.banners[1], "伤害+20%")
	assert_eq(squad.weapon_tier(), 2)
	assert_eq(squad.outfit_tier(), 2)
	assert_almost_eq(squad.damage_bonus, 0.2, 0.0001)


func test_groups_need_one_benefit_and_clearance() -> void:
	var bad := _group(-8.0, [
		_span(GateRules.SUBTRACT, 4.0, -3.75, 0.0),
		_span(GateRules.SUBTRACT, 4.0, 0.0, 3.75),
	])
	assert_false(GateRules.group_has_benefit(bad))
	var good := _group(-8.0, [
		_span(GateRules.SUBTRACT, 4.0, -3.75, 0.0),
		_span(GateRules.WEAPON, 1.0, 0.0, 3.75),
	])
	assert_true(GateRules.group_has_benefit(good))
	var shootable := _span(GateRules.SUBTRACT, 10.0, -3.75, 3.75)
	shootable.shootable = true
	shootable.value = -10.0
	assert_false(GateRules.group_has_benefit(_group(-4.0, [shootable])))
	shootable.value = 4.0
	assert_true(GateRules.group_has_benefit(_group(-4.0, [shootable])))
	assert_eq(GateRules.validate_group_resources("res://data").size(), 0)
	assert_eq(GateRules.add_amount_for_level(1), int(round(4.0 + 1.5)))
	assert_eq(GateRules.group_count_for_level(1), 5)
	assert_eq(GateRules.group_count_for_level(3), 6)
	assert_eq(GateRules.group_count_for_level(30), 9)
	var spawns := PackedFloat32Array([-19.0, -12.0, -11.9, -20.0, -40.0])
	assert_true(GateRules.spawn_blocks_gate(-19.0, -20.0))
	assert_true(GateRules.spawn_blocks_gate(-12.0, -20.0))
	assert_false(GateRules.spawn_blocks_gate(-11.9, -20.0))
	assert_false(GateRules.spawn_blocks_gate(-20.0, -20.0))
	assert_false(GateRules.spawn_blocks_gate(-40.0, -20.0))
	var gate := [_group(-20.0, [_span(GateRules.ADD, 4.0, -3.75, 3.75)])]
	assert_false(GateRules.clearance_ok(gate, PackedFloat32Array([-19.0])))
	assert_false(GateRules.clearance_ok(gate, PackedFloat32Array([-12.0])))
	assert_true(GateRules.clearance_ok(gate, PackedFloat32Array([-40.0, -11.9, -20.0])))
	assert_eq(spawns.size(), 5)


func test_shootable_gate_steps_and_changes_color() -> void:
	var span := _span(GateRules.SUBTRACT, 10.0, -3.75, 3.75)
	span.shootable = true
	span.value = -10.0
	assert_eq(GateRules.color_for(span), GateRules.PINK)
	assert_eq(GateRules.apply_shot_damage(span, 59.0, 20.0), 0)
	assert_almost_eq(span.value, -10.0, 0.001)
	assert_eq(GateRules.apply_shot_damage(span, 1.0, 20.0), 1)
	assert_almost_eq(span.value, -9.0, 0.001)
	assert_eq(GateRules.apply_shot_damage(span, 180.0, 20.0), 3)
	assert_almost_eq(span.value, -6.0, 0.001)
	span.value = -1.0
	span.damage_bank = 0.0
	assert_eq(GateRules.apply_shot_damage(span, 60.0, 20.0), 1)
	assert_almost_eq(span.value, 0.0, 0.001)
	assert_eq(GateRules.color_for(span), GateRules.PINK)
	assert_eq(GateRules.apply_shot_damage(span, 60.0, 20.0), 1)
	assert_almost_eq(span.value, 1.0, 0.001)
	assert_eq(GateRules.color_for(span), GateRules.CYAN)
	assert_eq(span.resolved_kind(), GateRules.ADD)
	var squad := SquadAnchor.new()
	squad.count = 5
	assert_eq(GateRules.apply_span(squad, span), "+1")
	assert_eq(squad.count, 6)


func test_bullet_updates_a_shootable_gate_before_the_squad_collects_it() -> void:
	var clock = autofree(_Clock.new())
	var sim := CombatSim.new(clock, 4, 4)
	sim.separation_enabled = false
	sim.squad.forward_speed = 0.0
	sim.squad.set_cooldown(10.0)
	var span := _span(GateRules.SUBTRACT, 1.0, -3.75, 3.75)
	span.shootable = true
	span.value = -1.0
	var group := _group(-5.0, [span])
	var runner := GateRunner.new()
	runner.grunt_hp = 20.0
	runner.set_groups([group], sim.squad.position.z)
	sim.gates = runner
	sim.bullets.try_spawn(0.0, -4.0, 0.0, -30.0, 60.0, 0, 30.0)
	sim.tick(0.1)
	assert_almost_eq(span.value, 0.0, 0.001)
	assert_false(span.locked)
	sim.squad.forward_speed = 40.0
	sim.bullets.try_spawn(0.0, -4.2, 0.0, -30.0, 60.0, 0, 30.0)
	sim.tick(0.2)
	assert_true(span.locked)
	assert_almost_eq(span.value, 1.0, 0.001)
	assert_eq(sim.squad.count, 6)


func test_gate_meshes_use_the_palette_colors() -> void:
	var add := _span(GateRules.ADD, 4.0, -3.75, 0.0)
	var sub := _span(GateRules.SUBTRACT, 4.0, 0.0, 3.75)
	var rate := _span(GateRules.FIRE_RATE, 0.15, -3.75, 3.75)
	var view := GateView.new()
	add_child_autofree(view)
	view.build([
		_group(-6.0, [add, sub]),
		_group(-12.0, [rate]),
	])
	assert_eq(view.get_child_count(), 6)
	assert_eq((view.get_child(0) as MeshInstance3D).material_override.albedo_color, GateRules.CYAN)
	assert_eq((view.get_child(2) as MeshInstance3D).material_override.albedo_color, GateRules.PINK)
	assert_eq((view.get_child(4) as MeshInstance3D).material_override.albedo_color, GateRules.GOLD)
	assert_eq((view.get_child(1) as Label3D).text, "+4")
	sub.shootable = true
	sub.value = -4.0
	sub.visual_dirty = true
	view.refresh()
	assert_eq((view.get_child(2) as MeshInstance3D).material_override.albedo_color, GateRules.PINK)
	sub.value = 5.0
	sub.visual_dirty = true
	view.refresh()
	assert_eq((view.get_child(2) as MeshInstance3D).material_override.albedo_color, GateRules.CYAN)
	assert_eq((view.get_child(3) as Label3D).text, "+5")


func _span(kind: int, amount: float, x_min: float, x_max: float) -> GateSpan:
	var span := GateSpan.new()
	span.kind = kind
	span.amount = amount
	span.x_min = x_min
	span.x_max = x_max
	return span


func _group(z: float, spans: Array) -> GateGroup:
	var group := GateGroup.new()
	group.z = z
	for span in spans:
		group.spans.append(span)
	return group


func _cross(runner: GateRunner, squad: SquadAnchor, distance: float) -> void:
	var before := squad.position.z
	squad.position.z = before - distance
	runner.resolve_crossing(squad, before, squad.position.z)
