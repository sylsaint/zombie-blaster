extends GutTest

const _Clock := preload("res://scripts/game_clock.gd")


func test_xp_thresholds_follow_the_level_curve() -> void:
	assert_eq(XpTrack.requirement_for(1), 10)
	assert_eq(XpTrack.requirement_for(2), 18)
	assert_eq(XpTrack.requirement_for(3), 26)
	assert_eq(XpTrack.requirement_for(5), 42)
	var track := XpTrack.new()
	assert_eq(track.add(9), 0)
	assert_eq(track.xp, 9)
	assert_eq(track.pending, 0)
	assert_eq(track.add(1), 1)
	assert_eq(track.xp, 0)
	assert_eq(track.xp_ranks, 1)
	assert_eq(track.add(17), 0)
	assert_eq(track.xp, 17)
	assert_eq(track.add(1), 1)
	assert_eq(track.xp_ranks, 2)
	assert_eq(track.pending, 2)
	var ranks_before := track.xp_ranks
	var xp_before := track.xp
	track.grant_offer()
	assert_eq(track.pending, 3)
	assert_eq(track.xp_ranks, ranks_before)
	assert_eq(track.xp, xp_before)
	track.take_offer()
	assert_eq(track.pending, 2)


func test_walker_and_runner_kills_drop_xp_that_the_squad_collects() -> void:
	var clock = autofree(_Clock.new())
	var sim := CombatSim.new(clock, 8, 8)
	sim.contact_enabled = false
	sim.separation_enabled = false
	sim.squad.forward_speed = 0.0
	sim.squad.count = 1
	sim.squad.set_cooldown(10.0)
	var walker := EnemyCatalog.place(sim.enemies, EnemyCatalog.walker(), 1, 0.0, -1.2, 0.2)
	assert_true(sim.enemies.hit(walker, 999.0, 0.0, -1.0))
	sim._on_killed(walker)
	assert_eq(sim.drops.live_count, 1)
	assert_eq(sim.xp.xp, 0)
	sim.squad.position = Vector3(sim.drops.x[0], 0.0, sim.drops.z[0])
	sim.tick(0.05)
	assert_eq(sim.drops.live_count, 0)
	assert_eq(sim.xp.xp, 1)
	var runner := EnemyCatalog.place(sim.enemies, EnemyCatalog.runner(), 1, 2.0, -1.0, 0.4)
	for _i in sim.drops.capacity():
		assert_true(sim.drops.try_spawn(20.0, 20.0, 1))
	assert_eq(sim.drops.live_count, sim.drops.capacity())
	assert_false(sim.drops.try_spawn(0.0, 0.0, 1))
	sim._on_killed(runner)
	assert_eq(sim.xp.xp, 2)
	assert_eq(sim.drops.live_count, sim.drops.capacity())
	assert_eq(sim.drops.capacity(), XpDropPool.CAPACITY)


func test_card_roll_has_no_duplicates_and_respects_rules() -> void:
	var fresh := SkillLoadout.new()
	for seed_value in 1000:
		var roller := CardRoller.new()
		roller.set_seed(seed_value + 1)
		var offer := roller.roll(fresh, true)
		assert_eq(offer.size(), 3, "seed %d" % seed_value)
		var seen := {}
		var core := false
		for id in offer:
			assert_false(seen.has(id), "duplicate in seed %d" % seed_value)
			seen[id] = true
			assert_false(fresh.is_maxed(id))
			if fresh.is_core(id):
				core = true
		assert_true(core, "first offer missing a core card, seed %d" % seed_value)
	var left := CardRoller.new()
	var right := CardRoller.new()
	left.set_seed(42)
	right.set_seed(42)
	var offer_a := left.roll(SkillLoadout.new(), true)
	var offer_b := right.roll(SkillLoadout.new(), true)
	assert_eq(offer_a, offer_b)
	var capped := SkillLoadout.new()
	capped.level[SkillCard.RAPID] = capped.cards[SkillCard.RAPID].max_level
	for seed_value in 50:
		var roller := CardRoller.new()
		roller.set_seed(1000 + seed_value)
		var offer := roller.roll(capped, false)
		for id in offer:
			assert_ne(id, SkillCard.RAPID)
	capped.level[SkillCard.SPLIT] = 3
	capped.level[SkillCard.PIERCE] = 3
	capped.level[SkillCard.BURST] = 3
	var late := CardRoller.new()
	late.set_seed(7)
	var leftovers := late.roll(capped, true)
	assert_eq(leftovers.size(), 2)
	for id in leftovers:
		assert_false(capped.is_core(id))
		assert_ne(id, SkillCard.RAPID)
	var only := SkillLoadout.new()
	only.level[SkillCard.SPLIT] = 3
	only.level[SkillCard.PIERCE] = 3
	only.level[SkillCard.BURST] = 3
	only.level[SkillCard.RAPID] = 5
	only.level[SkillCard.POWER] = 5
	var lone := CardRoller.new()
	lone.set_seed(3)
	var one := lone.roll(only, true)
	assert_eq(one.size(), 1)
	assert_eq(one[0], SkillCard.REINFORCE)


func test_each_card_level_matches_the_table() -> void:
	var squad := SquadAnchor.new()
	squad.count = 5
	var loadout := SkillLoadout.new()
	for step in 3:
		loadout.apply(SkillCard.SPLIT, squad)
		assert_eq(squad.skill_split_count, step + 2)
		assert_almost_eq(squad.skill_split_ratio, 0.5, 0.001)
		assert_almost_eq(squad.skill_split_spread, 30.0, 0.001)
	loadout.apply(SkillCard.SPLIT, squad)
	assert_eq(loadout.card_level(SkillCard.SPLIT), 3)
	assert_eq(squad.skill_split_count, 4)
	for step in 3:
		loadout.apply(SkillCard.PIERCE, squad)
		assert_eq(squad.skill_pierce, step + 1)
	loadout.apply(SkillCard.PIERCE, squad)
	assert_eq(squad.skill_pierce, 3)
	for step in 3:
		loadout.apply(SkillCard.BURST, squad)
		assert_eq(squad.skill_extra_pellets, step + 1)
	squad.weapon = WeaponStats.pistol()
	squad.forward_speed = 0.0
	squad.set_cooldown(0.0)
	squad.tick(0.01)
	var shot: Dictionary = squad.pending_shots[0]
	assert_eq((shot["offsets"] as PackedFloat32Array).size(), 4)
	assert_eq(int(shot["pierce"]), 3)
	loadout = SkillLoadout.new()
	squad = SquadAnchor.new()
	squad.count = 5
	for step in 5:
		loadout.apply(SkillCard.RAPID, squad)
		assert_almost_eq(squad.skill_rate_bonus, 0.15 * float(step + 1), 0.0001)
		assert_almost_eq(squad.current_interval(), 0.4 / (1.0 + squad.skill_rate_bonus), 0.0001)
	loadout.apply(SkillCard.RAPID, squad)
	assert_eq(loadout.card_level(SkillCard.RAPID), 5)
	assert_almost_eq(squad.skill_rate_bonus, 0.75, 0.0001)
	for step in 5:
		loadout.apply(SkillCard.POWER, squad)
		assert_almost_eq(squad.skill_damage_bonus, 0.20 * float(step + 1), 0.0001)
	var expected := SquadAnchor.shot_damage(10.0, 5, 1.0)
	assert_almost_eq(SquadAnchor.shot_damage(10.0, 5, squad.total_damage_bonus()), expected, expected * 0.005)
	squad.count = 148
	loadout.apply(SkillCard.REINFORCE, squad)
	assert_eq(squad.count, 150)
	assert_true(squad.capped)
	assert_eq(squad.banner, "已满")
	loadout.apply(SkillCard.REINFORCE, squad)
	assert_eq(squad.count, 150)
	assert_eq(loadout.card_level(SkillCard.REINFORCE), 2)


func test_split_shots_use_the_pool_and_do_not_split_again() -> void:
	var clock = autofree(_Clock.new())
	var sim := CombatSim.new(clock, 4, 8)
	sim.contact_enabled = false
	sim.separation_enabled = false
	sim.squad.count = 1
	sim.squad.forward_speed = 0.0
	sim.squad.weapon = WeaponStats.pistol()
	sim.skills.apply(SkillCard.SPLIT, sim.squad)
	sim.squad.set_cooldown(0.0)
	var cap := sim.bullets.capacity
	var id := sim.spawn_at(EnemyPool.Archetype.GRUNT, 0.0, -0.4, 1000.0, 0.0, 0.4, 0.2)
	sim.tick(0.05)
	assert_lt(sim.enemies.hp[id], 1000.0)
	var splits := 0
	for i in cap:
		if sim.bullets.flags[i] & BulletPool.FLAG_SPLIT and sim.bullets.is_alive(i):
			splits += 1
			assert_almost_eq(sim.bullets.damage[i], 5.0, 0.05)
	assert_eq(splits, 2)
	assert_eq(sim.bullets.capacity, cap)
	assert_eq(sim.bullets.x.size(), cap)
	sim.tick(0.05)
	var splits_after := 0
	var alive := 0
	for i in cap:
		if sim.bullets.is_alive(i):
			alive += 1
			if sim.bullets.flags[i] & BulletPool.FLAG_SPLIT:
				splits_after += 1
	assert_eq(splits_after, 2)
	assert_lte(alive, cap)
	assert_eq(sim.bullets.capacity, cap)


func test_pierce_card_lets_one_bullet_hit_two_enemies() -> void:
	var clock = autofree(_Clock.new())
	var sim := CombatSim.new(clock, 4, 4)
	sim.contact_enabled = false
	sim.separation_enabled = false
	sim.squad.count = 1
	sim.squad.forward_speed = 0.0
	sim.squad.weapon = WeaponStats.pistol()
	sim.skills.apply(SkillCard.PIERCE, sim.squad)
	sim.squad.set_cooldown(0.0)
	var first := sim.spawn_at(EnemyPool.Archetype.GRUNT, 0.0, -0.8, 100.0, 0.0, 0.45, 0.2)
	var second := sim.spawn_at(EnemyPool.Archetype.GRUNT, 0.0, -1.8, 100.0, 0.0, 0.45, 0.2)
	sim.tick(0.1)
	assert_lt(sim.enemies.hp[first], 100.0)
	assert_lt(sim.enemies.hp[second], 100.0)


func test_card_choice_ramps_the_game_clock_and_does_not_pause_the_tree() -> void:
	var clock = autofree(_Clock.new())
	var sim := CombatSim.new(clock, 4, 4)
	sim.roller.set_seed(5)
	sim.xp.add(10)
	var director := LevelUpDirector.new()
	add_child_autofree(director)
	director.setup(sim, clock)
	var view: Node = load("res://scenes/ui/card_select.tscn").instantiate()
	add_child_autofree(view)
	assert_gte((view.get_node("%Card0") as Control).custom_minimum_size.y, 300.0)
	assert_gte((view.get_node("%Card1") as Control).custom_minimum_size.y, 300.0)
	assert_gte((view.get_node("%Card2") as Control).custom_minimum_size.y, 300.0)
	director._process(0.0)
	assert_eq(director.phase, LevelUpDirector.PHASE_RAMPING)
	var frame := 1.0 / 60.0
	for _i in 9:
		clock.advance(frame)
		director._process(frame)
	assert_eq(director.phase, LevelUpDirector.PHASE_SHOWING)
	assert_almost_eq(clock.scale, 0.0, 0.02)
	assert_false(get_tree().paused)
	assert_eq(Engine.time_scale, 1.0)
	var offer := director.current_offer()
	assert_eq(offer.size(), 3)
	var seen := {}
	var core := false
	for id in offer:
		assert_false(seen.has(id))
		seen[id] = true
		if sim.skills.is_core(id):
			core = true
	assert_true(core)
	assert_true(director.card_view().visible)
	var picked: int = offer[0]
	director.card_view().get_node("%Card0").pressed.emit()
	assert_eq(sim.skills.card_level(picked), 1)
	assert_eq(director.phase, LevelUpDirector.PHASE_IDLE)
	assert_almost_eq(clock.scale, 1.0, 0.001)
	assert_eq(Engine.time_scale, 1.0)
	assert_false(get_tree().paused)


func test_queued_offers_open_one_at_a_time_and_survive_hit_stop() -> void:
	var clock = autofree(_Clock.new())
	var sim := CombatSim.new(clock, 4, 4)
	sim.roller.set_seed(9)
	sim.xp.add(28)
	assert_eq(sim.xp.pending, 2)
	var director := LevelUpDirector.new()
	add_child_autofree(director)
	director.setup(sim, clock)
	director._process(0.0)
	for _i in 9:
		clock.advance(1.0 / 60.0)
		director._process(0.0)
	assert_eq(director.phase, LevelUpDirector.PHASE_SHOWING)
	director.choose(0)
	assert_eq(sim.xp.pending, 1)
	assert_eq(director.phase, LevelUpDirector.PHASE_SHOWING)
	assert_almost_eq(clock.scale, 0.0, 0.02)
	assert_eq(director.current_offer().size(), 3)
	director.choose(1)
	assert_eq(sim.xp.pending, 0)
	assert_eq(director.phase, LevelUpDirector.PHASE_IDLE)
	assert_almost_eq(clock.scale, 1.0, 0.001)
	clock.hit_stop(60.0)
	sim.xp.grant_offer()
	director._process(0.0)
	assert_eq(director.phase, LevelUpDirector.PHASE_RAMPING)
	clock.advance(0.06)
	director._process(0.0)
	assert_eq(director.phase, LevelUpDirector.PHASE_RAMPING)
	clock.advance(0.15)
	director._process(0.0)
	assert_eq(director.phase, LevelUpDirector.PHASE_SHOWING)
	director.choose(0)
	assert_almost_eq(clock.scale, 1.0, 0.001)
	assert_almost_eq(clock.hit_stop_remaining(), 0.0, 0.0001)
	assert_eq(Engine.time_scale, 1.0)


func test_loss_toast_shows_a_red_minus_n() -> void:
	var toast = add_child_autofree(load("res://scenes/ui/loss_toast.tscn").instantiate())
	toast.show_amount(4)
	assert_eq(toast.text, "-4")
	assert_true(toast.visible)
	assert_gt(toast.get_theme_color("font_color").r, 0.8)
	assert_lt(toast.get_theme_color("font_color").g, 0.4)
