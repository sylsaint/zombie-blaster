extends GutTest

const _Clock := preload("res://scripts/game_clock.gd")
const _Host := preload("res://scripts/level_host.gd")


func _clock():
	return autofree(_Clock.new())


func _session(level: LevelData) -> LevelSession:
	var session := LevelSession.new()
	session.start(level, _clock())
	return session


func _events(items: Array) -> Array[LevelEvent]:
	var out: Array[LevelEvent] = []
	for item in items:
		out.append(item)
	return out


func _has_gate(level: LevelData, kind: int) -> bool:
	for group in level.gate_groups():
		for gate in group.gates:
			if gate.kind == kind:
				return true
	return false


func _has_enemy(level: LevelData, enemy_id: String) -> bool:
	for event in level.events:
		if event.enemy_id == enemy_id:
			return true
	return false


func test_catalog_matches_the_chapter_table() -> void:
	var levels := LevelCatalog.load_all()
	assert_eq(levels.size(), 3)
	var expected := [
		{"grunts": 500, "gates": 5, "elites": 0, "finale": "elite", "finale_n": 1, "hp": 1.0, "elite_hp": 4800.0, "dps": 800.0, "star2": 20, "coins": 100, "parts": 5, "boss": 0.0, "add": 6},
		{"grunts": 540, "gates": 5, "elites": 1, "finale": "elite_wall", "finale_n": 2, "hp": 1.13, "elite_hp": 5700.0, "dps": 944.0, "star2": 26, "coins": 120, "parts": 5, "boss": 0.0, "add": 7},
		{"grunts": 580, "gates": 6, "elites": 1, "finale": "mini_boss", "finale_n": 0, "hp": 1.28, "elite_hp": 6700.0, "dps": 1114.0, "star2": 32, "coins": 140, "parts": 15, "boss": 27000.0, "add": 9},
	]
	var i := 0
	while i < levels.size():
		var level := levels[i]
		var row: Dictionary = expected[i]
		assert_eq(level.level_index, i + 1)
		assert_eq(level.grunt_total, int(row["grunts"]))
		assert_eq(level.grunt_spawn_total(), int(row["grunts"]), "level %d waves" % level.level_index)
		assert_eq(level.gate_group_count, int(row["gates"]))
		assert_eq(level.count_kind("gate_group"), int(row["gates"]))
		assert_eq(level.advance_elite_count, int(row["elites"]))
		assert_eq(level.advance_elite_total(), int(row["elites"]))
		assert_eq(level.finale, String(row["finale"]))
		assert_eq(level.finale_elite_count, int(row["finale_n"]))
		assert_almost_eq(level.hp_multiplier, float(row["hp"]), 0.001)
		assert_almost_eq(level.elite_hp, float(row["elite_hp"]), 0.1)
		assert_almost_eq(level.expected_dps, float(row["dps"]), 0.1)
		assert_eq(level.star2_headcount, int(row["star2"]))
		assert_eq(level.base_clear_coins, int(row["coins"]))
		assert_eq(level.first_clear_parts, int(row["parts"]))
		assert_almost_eq(level.boss_hp, float(row["boss"]), 0.1)
		assert_false(level.boss_summon)
		assert_eq(level.add_gate_amount(), int(row["add"]))
		assert_almost_eq(level.star_coin_multipliers[0], 1.0, 0.001)
		assert_almost_eq(level.star_coin_multipliers[1], 1.2, 0.001)
		assert_almost_eq(level.star_coin_multipliers[2], 1.5, 0.001)
		assert_almost_eq(level.three_star_chest_coin_multiplier, 2.0, 0.001)
		assert_eq(level.three_star_chest_parts, 5)
		assert_true(level.three_star_chest_paid_separately)
		assert_almost_eq(level.fail_coin_ratio, 0.30, 0.001)
		assert_true(level.has_buff_in_every_group(), "AC-GT-03 level %d" % level.level_index)
		assert_false(level.wave_inside_gate_clearance(), "AC-GT-04 level %d" % level.level_index)
		i += 1
	assert_false(_has_gate(levels[0], GateRules.MULTIPLY))
	assert_false(_has_gate(levels[0], GateRules.SUBTRACT))
	assert_false(_has_gate(levels[0], GateRules.FIRE_RATE))
	assert_false(_has_enemy(levels[0], "enm_runner_a"))
	assert_true(_has_gate(levels[1], GateRules.MULTIPLY))
	assert_true(_has_gate(levels[1], GateRules.SUBTRACT))
	assert_true(_has_enemy(levels[1], "enm_runner_a"))
	assert_eq(levels[1].count_kind("elite_wall"), 1)
	assert_true(_has_gate(levels[2], GateRules.FIRE_RATE))
	assert_true(_has_enemy(levels[2], "enm_runner_a"))
	assert_eq(levels[2].count_kind("boss"), 1)
	var tradeoff := false
	for group in levels[2].gate_groups():
		var saw_add := false
		var saw_weapon := false
		for gate in group.gates:
			if gate.kind == GateRules.ADD:
				saw_add = true
			if gate.kind == GateRules.WEAPON:
				saw_weapon = true
		if saw_add and saw_weapon:
			tradeoff = true
	assert_true(tradeoff, "level 3 has an add-versus-weapon gate")


func test_game_scene_loads_levels_without_starting() -> void:
	var host = _Host.new()
	add_child_autofree(host)
	if host.levels.is_empty():
		host._ready()
	assert_eq(host.levels.size(), 3)
	assert_null(host.session)
	var packed := load("res://scenes/main.tscn") as PackedScene
	var main := packed.instantiate()
	add_child_autofree(main)
	var scene_host = main.get_node("LevelHost")
	assert_ne(scene_host, null)
	if scene_host.levels.is_empty():
		scene_host._ready()
	assert_eq(scene_host.levels.size(), 3)
	assert_null(scene_host.session)


func test_wave_inside_clearance_waits_for_the_gate() -> void:
	var level := LevelData.new()
	level.level_index = 1
	level.hp_multiplier = 1.0
	var wave := LevelEvent.new()
	wave.distance = 10.0
	wave.kind = "wave"
	wave.enemy_id = "enm_walker_a"
	wave.count = 12
	wave.formation = "line"
	var gate := LevelEvent.new()
	gate.distance = 16.0
	gate.kind = "gate_group"
	var add := GateSpec.new()
	add.kind = GateRules.ADD
	add.amount = 6.0
	add.side = "left"
	var weapon := GateSpec.new()
	weapon.kind = GateRules.WEAPON
	weapon.amount = 1.0
	weapon.side = "right"
	var gates: Array[GateSpec] = [add, weapon]
	gate.gates = gates
	level.events = _events([wave, gate])
	assert_true(level.wave_inside_gate_clearance())
	var session := _session(level)
	session.incoming_damage = false
	session.freeze_build = true
	session.tick(3.0)
	assert_almost_eq(session.traveled, 12.0, 0.05)
	assert_eq(session.grunt_alive(), 0, "no grunt spawns inside the 8 m gate gap")
	assert_gt(session._q_n, 0)
	session.tick(1.2)
	assert_gt(session.traveled, 16.0)
	assert_gt(session.grunt_alive(), 0)


func test_boss_fight_stops_the_squad() -> void:
	var level := LevelCatalog.load_index(1)
	var advance := _session(level)
	var z0: float = advance.sim.squad.position.z
	advance.tick(0.5)
	var speed := (z0 - advance.sim.squad.position.z) / 0.5
	assert_almost_eq(speed, 4.0, 0.08)
	var boss_level := LevelData.new()
	boss_level.level_index = 3
	boss_level.boss_hp = 27000.0
	boss_level.boss_summon = false
	boss_level.hp_multiplier = 1.28
	var event := LevelEvent.new()
	event.distance = 0.0
	event.kind = "boss"
	event.enemy_id = "boss_mutant"
	boss_level.events = _events([event])
	var session := _session(boss_level)
	assert_almost_eq(session.sim.squad.forward_speed, 4.0, 0.001)
	session.tick(0.05)
	assert_eq(session.state, "finale")
	assert_almost_eq(session.sim.squad.forward_speed, 0.0, 0.001)
	assert_ne(session.boss, null)
	assert_false(session.boss.summon_enabled)
	assert_eq(session.boss.display_name, "突变巨兽")


func test_zero_headcount_fails_on_the_same_tick() -> void:
	var level := LevelCatalog.load_index(1)
	var session := _session(level)
	session.sim.squad.count = 0
	session.tick(0.02)
	assert_eq(session.state, "lose")
	assert_ne(session.result, null)
	assert_eq(session.result.outcome, "lose")
	assert_eq(session.result.headcount, 0)
	assert_eq(session.result.run_coins, 0)
	assert_eq(session.result.base_clear_coins, level.base_clear_coins)
	assert_eq(session.result.star2_headcount, level.star2_headcount)
	assert_eq(session.result.first_clear_parts, level.first_clear_parts)
	assert_almost_eq(session.result.three_star_chest_coin_multiplier, 2.0, 0.001)
	assert_eq(session.result.three_star_chest_parts, 5)
	assert_true(session.result.three_star_chest_paid_separately)
	assert_almost_eq(session.result.fail_coin_ratio, 0.30, 0.001)
	assert_eq(session.result.run_coins, 0, "chest coins are stored, not paid")


func test_supply_gates_grant_soldiers_and_a_rifle() -> void:
	var boss_level := LevelData.new()
	boss_level.level_index = 3
	boss_level.boss_hp = 27000.0
	boss_level.boss_summon = false
	var event := LevelEvent.new()
	event.distance = 0.0
	event.kind = "boss"
	boss_level.events = _events([event])
	var session := _session(boss_level)
	session.incoming_damage = false
	session.tick(0.05)
	var before := session.sim.squad.count
	session.boss.supply_pending = true
	session.boss.z = session.sim.squad.position.z - 0.5
	session.sim.squad.position.x = 0.0
	session.sim.squad.target_x = 0.0
	var steps := 0
	while session.weapon_level < 2 and steps < 40:
		session.tick(0.05)
		steps += 1
	assert_true(steps < 40, "supply gates reached the squad")
	assert_gte(session.sim.squad.count, before + boss_level.add_gate_amount())
	assert_eq(session.weapon_level, 2)
	assert_eq(session.sim.squad.weapon.weapon_name, "步枪")
	assert_almost_eq(session.sim.squad.weapon.damage, 12.0, 0.001)
	assert_almost_eq(session.sim.squad.weapon.interval, 0.2, 0.001)


func test_expected_dps_kills_elites_in_five_to_eight_seconds() -> void:
	var levels := LevelCatalog.load_all()
	for level in levels:
		var clock = _clock()
		var sim := CombatSim.new(clock, 4, 8)
		sim.separation_enabled = false
		sim.contact_enabled = false
		sim.loss_enabled = false
		sim.squad.forward_speed = 0.0
		ExpectedSquad.configure(sim.squad, level.expected_dps)
		# One body on the firing line. Count 48 spreads pellets across the lane
		# and would miss a single elite; the expected DPS is what lands on it.
		sim.squad.count = 1
		sim.squad.weapon.damage = ExpectedSquad.SHOT
		sim.squad.forward_speed = 0.0
		var realized := ExpectedSquad.realized_dps(sim.squad)
		assert_almost_eq(realized, level.expected_dps, level.expected_dps * 0.01)
		var id := sim.spawn_at(EnemyPool.Archetype.ELITE, 0.0, -1.5, level.elite_hp, 0.0, 0.7, 0.85)
		sim.enemies.slam_interval[id] = 0.0
		sim.enemies.speed[id] = 0.0
		sim.enemies.cruise_speed[id] = 0.0
		var t := 0.0
		while sim.enemies.state[id] == EnemyPool.State.ALIVE and t < 12.0:
			sim.tick(0.01)
			if sim.enemies.state[id] == EnemyPool.State.ALIVE:
				sim.enemies.x[id] = 0.0
				sim.enemies.z[id] = -1.5
			t += 0.01
		assert_eq(sim.enemies.state[id], EnemyPool.State.DYING, "level %d elite still up at %.2f" % [level.level_index, t])
		assert_gte(t, 5.0, "level %d elite died at %.2f" % [level.level_index, t])
		assert_lte(t, 8.0, "level %d elite died at %.2f" % [level.level_index, t])


func test_midrun_kill_rate_holds_for_the_first_three_levels() -> void:
	var levels := LevelCatalog.load_all()
	for level in levels:
		var session := _session(level)
		session.incoming_damage = false
		session.freeze_build = true
		session.sim.separation_enabled = false
		ExpectedSquad.configure(session.sim.squad, level.expected_dps)
		var counts: Array[int] = []
		var acc := 0.0
		var previous := 0
		var guard := 0
		while session.state == "advance" and guard < 4000:
			session.tick(0.05)
			acc += 0.05
			guard += 1
			if acc + 0.0001 < 1.0:
				continue
			var kills: int = session.sim.enemies.kill_count
			counts.append(kills - previous)
			previous = kills
			acc -= 1.0
		assert_gte(counts.size(), 15, "level %d advance samples" % level.level_index)
		var start := int(float(counts.size()) * 0.4)
		var peak := 0
		var best := 0
		var i := start
		while i < counts.size():
			peak = maxi(peak, counts[i])
			if i + 10 <= counts.size():
				var window := 0
				var j := 0
				while j < 10:
					window += counts[i + j]
					j += 1
				best = maxi(best, window)
			i += 1
		var rate := float(best) / 10.0
		assert_gte(peak, 20, "level %d peak %d / 1 s" % [level.level_index, peak])
		assert_gte(rate, 8.0, "level %d best 10 s rate %.2f" % [level.level_index, rate])
