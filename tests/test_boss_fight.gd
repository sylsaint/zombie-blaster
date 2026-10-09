extends GutTest

const _Clock := preload("res://scripts/game_clock.gd")


func _arch() -> EnemyArchetype:
	return load("res://data/enemies/boss_mutant.tres") as EnemyArchetype


func _clock():
	return autofree(_Clock.new())


func _fight(clock, hp: float = 27000.0) -> BossFight:
	var fight := BossFight.new()
	fight.clock = clock
	fight.supply_add = 9
	fight.start(_arch(), 0.0, hp, true, false)
	return fight


func _arrive(fight: BossFight) -> void:
	fight.tick(13.0 / BossFight.APPROACH_SPEED + 0.05, 0.0, 0.0, 20, 0.4)


func test_offset_circle_contacts_on_the_left_and_right() -> void:
	var arch := _arch()
	var center_x := arch.offset_x
	var center_z := arch.offset_z
	var radius := arch.collision_radius
	assert_almost_eq(radius, 2.7, 0.001)
	assert_almost_eq(center_x, 0.4, 0.001)
	assert_almost_eq(center_z, -0.6, 0.001)
	var left_inside := center_x - radius + 0.05
	var left_outside := center_x - radius - 0.08
	assert_true(arch.overlaps(0.0, 0.0, left_inside, center_z, 0.0), "left lip of the circle contacts")
	assert_false(arch.overlaps(0.0, 0.0, left_outside, center_z, 0.0), "just left of the circle does not")
	var past_mesh_left := -(arch.mesh_extent_left + 0.05)
	assert_true(past_mesh_left < -arch.mesh_extent_left)
	assert_true(arch.overlaps(0.0, 0.0, past_mesh_left, center_z, 0.0), "past the mesh's left extent still contacts")
	var right_inside := center_x + radius - 0.05
	var right_outside := center_x + radius + 0.08
	assert_true(arch.overlaps(0.0, 0.0, right_inside, center_z, 0.0), "right lip of the circle contacts")
	assert_false(arch.overlaps(0.0, 0.0, right_outside, center_z, 0.0), "just right of the circle does not")
	var past_mesh_right := arch.mesh_extent_right + 0.02
	assert_gt(past_mesh_right, arch.mesh_extent_right)
	assert_true(arch.overlaps(0.0, 0.0, past_mesh_right, center_z, 0.0), "past the mesh's right tip still contacts")
	var fight := _fight(_clock())
	_arrive(fight)
	fight.x = 0.0
	fight.z = 0.0
	fight._refresh_center()
	fight.tick(0.02, left_inside, fight.center_z, 30, 0.0)
	assert_eq(fight.take_squad_loss(), arch.contact_loss)
	fight.tick(0.02, left_outside, fight.center_z, 30, 0.0)
	assert_eq(fight.take_squad_loss(), 0)
	fight._contact_ready = 0.0
	fight.x = 0.0
	fight.z = 0.0
	fight._refresh_center()
	fight.tick(0.02, right_inside, fight.center_z, 30, 0.0)
	assert_eq(fight.take_squad_loss(), arch.contact_loss)
	fight._contact_ready = 0.0
	fight.x = 0.0
	fight.z = 0.0
	fight._refresh_center()
	fight.tick(0.02, right_outside, fight.center_z, 30, 0.0)
	assert_eq(fight.take_squad_loss(), 0)


func test_charge_impact_uses_the_offset_circle_on_both_sides() -> void:
	var arch := _arch()
	var fight := _fight(_clock())
	_arrive(fight)
	fight._skill_flip = 1
	fight._next_skill_at = fight.elapsed
	fight.tick(0.02, 0.0, 0.0, 20, 0.0)
	assert_true(fight.telegraph.active)
	assert_eq(fight.telegraph.kind, "charge")
	var left_inside := arch.offset_x - arch.collision_radius + 0.05
	var left_outside := arch.offset_x - arch.collision_radius - 0.12
	fight.tick(BossFight.CHARGE_WARN, left_inside, 0.0, 20, 0.0)
	assert_false(fight.telegraph.active)
	assert_true(fight.last_charge_body_hit, "charge body reaches the left lip")
	assert_eq(fight.stun_left, BossFight.STUN_TIME)
	assert_true(fight.leaning)
	assert_true(fight.weakpoint_glow)
	var missed := _fight(_clock())
	_arrive(missed)
	missed._skill_flip = 1
	missed._next_skill_at = missed.elapsed
	missed.tick(0.02, 0.0, 0.0, 20, 0.0)
	missed.tick(BossFight.CHARGE_WARN, left_outside, 0.0, 20, 0.0)
	assert_false(missed.last_charge_body_hit, "charge body misses just left of the circle")
	var right := _fight(_clock())
	_arrive(right)
	right._skill_flip = 1
	right._next_skill_at = right.elapsed
	right.tick(0.02, 0.0, 0.0, 20, 0.0)
	var right_inside := arch.offset_x + arch.collision_radius - 0.05
	var right_outside := arch.offset_x + arch.collision_radius + 0.12
	right.tick(BossFight.CHARGE_WARN, right_inside, 0.0, 20, 0.0)
	assert_true(right.last_charge_body_hit, "charge body reaches the right lip")
	var right_miss := _fight(_clock())
	_arrive(right_miss)
	right_miss._skill_flip = 1
	right_miss._next_skill_at = right_miss.elapsed
	right_miss.tick(0.02, 0.0, 0.0, 20, 0.0)
	right_miss.tick(BossFight.CHARGE_WARN, right_outside, 0.0, 20, 0.0)
	assert_false(right_miss.last_charge_body_hit, "charge body misses just right of the circle")


func test_warnings_meet_the_table_and_leave_a_safe_lane() -> void:
	var fight := _fight(_clock())
	_arrive(fight)
	var count := 12
	var diameter := SquadAnchor.formation_radius(count) * 2.0
	var squad_x := 0.0
	var t := 0.0
	while fight.warning_durations.size() < 4 and t < 40.0:
		if fight.telegraph.active:
			squad_x = fight.telegraph.dodge_x(3.0)
		else:
			squad_x = 0.0
		fight.tick(0.05, squad_x, 0.0, count, diameter * 0.5)
		t += 0.05
	assert_gte(fight.warning_durations.size(), 4)
	var slam_min := 999.0
	var charge_min := 999.0
	var i := 0
	while i < fight.warning_durations.size():
		var kind := String(fight.warning_kinds[i])
		var duration: float = fight.warning_durations[i]
		var safe: float = fight.warning_safe[i]
		assert_gte(safe, diameter, "safe lane for %s" % kind)
		if kind == "slam":
			slam_min = minf(slam_min, duration)
			assert_gte(duration, 1.0)
		elif kind == "charge":
			charge_min = minf(charge_min, duration)
			assert_gte(duration, 1.2)
			assert_almost_eq(fight.telegraph.CHARGE_WIDTH, 2.5, 0.001)
		i += 1
	assert_gte(slam_min, 1.0)
	assert_gte(charge_min, 1.2)
	var elite := EliteCaster.new()
	elite.active = true
	elite.cooldown = 0.0
	elite.tick(0.05, 1.0, count)
	assert_true(elite.telegraph.active)
	elite.tick(1.0, 1.0, count)
	assert_eq(elite.warning_durations.size(), 1)
	assert_gte(float(elite.warning_durations[0]), 1.0)
	assert_gte(float(elite.warning_safe[0]), diameter)


func test_charge_band_costs_thirty_five_percent_and_stuns() -> void:
	var fight := _fight(_clock())
	_arrive(fight)
	fight._skill_flip = 1
	fight._next_skill_at = fight.elapsed
	fight.tick(0.02, 1.2, 0.0, 20, 0.4)
	assert_eq(fight.telegraph.kind, "charge")
	assert_almost_eq(fight.telegraph.aim_x, 1.2, 0.001)
	fight.tick(BossFight.CHARGE_WARN, 1.2, 0.0, 20, 0.4)
	var loss := fight.take_squad_loss()
	assert_eq(loss, SkillTelegraph.percent_loss(20, 0.35, 5))
	assert_gte(loss, 5)
	assert_almost_eq(fight.stun_left, 2.0, 0.02)
	var dodged := _fight(_clock())
	_arrive(dodged)
	dodged._skill_flip = 1
	dodged._next_skill_at = dodged.elapsed
	dodged.tick(0.02, 0.0, 0.0, 20, 0.4)
	dodged.tick(BossFight.CHARGE_WARN, 3.0, 0.0, 20, 0.4)
	assert_eq(dodged.skill_hits, 0)
	assert_eq(dodged.take_squad_loss(), 0)


func test_slam_costs_twenty_five_percent() -> void:
	var fight := _fight(_clock())
	_arrive(fight)
	fight._next_skill_at = fight.elapsed
	fight.tick(0.02, 1.0, 0.0, 20, 0.4)
	assert_eq(fight.telegraph.kind, "slam")
	fight.tick(BossFight.SLAM_WARN, 1.0, 0.0, 20, 0.4)
	var loss := fight.take_squad_loss()
	assert_eq(loss, SkillTelegraph.percent_loss(20, 0.25, 3))
	assert_gte(loss, 3)


func test_mini_boss_has_one_transition_and_supply_gates() -> void:
	var fight := _fight(_clock(), 1000.0)
	_arrive(fight)
	fight.apply_damage(5000.0)
	assert_eq(fight.phase_index, 2)
	assert_eq(fight.transition_count, 1)
	assert_almost_eq(fight.hp, 600.0, 0.1)
	assert_almost_eq(fight.invulnerable_left, 1.5, 0.001)
	assert_true(fight.supply_pending)
	assert_eq(fight.supply_add, 9)
	assert_false(fight.summon_enabled)
	var hp := fight.hp
	fight.apply_damage(100.0)
	assert_true(fight.last_immune)
	assert_false(fight.numbers.last_shown)
	assert_almost_eq(fight.hp, hp, 0.01)
	assert_eq(fight.transition_count, 1)
	fight.tick(1.6, 0.0, 0.0, 20, 0.4)
	fight.apply_damage(400.0)
	assert_eq(fight.phase_index, 2)
	assert_eq(fight.transition_count, 1)
	assert_lt(fight.hp, 600.0)
	assert_gt(fight.hp, 0.0)
	assert_eq(fight.summon_count, 0)


func test_stun_doubles_damage_and_hit_stop_is_gated() -> void:
	var saved := Engine.time_scale
	var clock = _clock()
	var fight := _fight(clock, 5000.0)
	_arrive(fight)
	fight._next_skill_at = fight.elapsed + 100.0
	fight.stun_left = 2.0
	fight.weakpoint_glow = true
	var hp := fight.hp
	fight.apply_damage(10.0)
	assert_almost_eq(fight.hp, hp - 20.0, 0.01)
	assert_eq(fight.numbers.last_color, DamageNumbers.ORANGE)
	assert_true(fight.numbers.last_shown)
	assert_almost_eq(clock.hit_stop_remaining(), 0.03, 0.002)
	fight.apply_damage(10.0)
	assert_almost_eq(fight.hp, hp - 40.0, 0.01)
	assert_almost_eq(clock.hit_stop_remaining(), 0.03, 0.002, "a second hit inside 0.5 s does not stack hit-stop")
	clock.advance(0.03)
	fight.tick(0.49, 0.0, 0.0, 20, 0.4)
	var remaining: float = clock.hit_stop_remaining()
	fight.apply_damage(10.0)
	assert_almost_eq(clock.hit_stop_remaining(), remaining, 0.002)
	fight.tick(0.02, 0.0, 0.0, 20, 0.4)
	fight.apply_damage(10.0)
	assert_gt(clock.hit_stop_remaining(), 0.02)
	assert_eq(Engine.time_scale, saved)
	assert_eq(Engine.time_scale, 1.0)


func test_enrage_halves_the_interval_and_tints_the_shader() -> void:
	var fight := _fight(_clock())
	_arrive(fight)
	assert_false(fight.enraged)
	assert_almost_eq(fight.skill_period(), 3.5, 0.001)
	fight.tick(90.0, 0.0, 0.0, 20, 0.4)
	assert_true(fight.enraged)
	assert_almost_eq(fight.skill_period(), 1.75, 0.001)
	fight.phase_index = 2
	assert_almost_eq(fight.skill_period(), 1.5, 0.001)
	var view := BossView.new()
	add_child_autofree(view)
	view.setup(fight)
	view.sync()
	assert_almost_eq(view.enrage_amount(), 1.0, 0.001)
	assert_true(view.using_greybox or view.weakpoint != null)
	assert_ne(view.weakpoint, null)
	fight.enraged = false
	fight.weakpoint_glow = true
	fight.flash_left = 0.05
	fight.leaning = true
	view.sync()
	assert_almost_eq(view.enrage_amount(), 0.0, 0.001)
	assert_gt(view.weakpoint_emission(), 1.0)
	assert_gt(view.weakpoint_flash(), 0.5)
	assert_lt(view.lean_radians(), -0.2)


func test_kill_slows_the_game_clock_only() -> void:
	var saved := Engine.time_scale
	var clock = _clock()
	var fight := _fight(clock, 100.0)
	_arrive(fight)
	fight.phase_index = 2
	fight.transition_count = 1
	fight._next_skill_at = fight.elapsed + 100.0
	fight.apply_damage(100.0)
	assert_true(fight.victorious)
	assert_almost_eq(clock.scale, 0.3, 0.001)
	assert_almost_eq(clock.advance(0.2), 0.06, 0.001)
	assert_eq(Engine.time_scale, saved)
	assert_almost_eq(fight.shake.trauma, 1.0, 0.001)


func test_expected_dps_kills_the_mini_boss_in_the_window() -> void:
	var fight := _fight(_clock(), 27000.0)
	var elapsed := ExpectedSquad.simulate_boss(fight, 1114.0)
	assert_true(fight.victorious, "boss died, t=%.2f hp=%.1f" % [elapsed, fight.hp])
	assert_gte(elapsed, 30.0, "t=%.2f" % elapsed)
	assert_lte(elapsed, 45.0, "t=%.2f" % elapsed)


func test_greybox_fallback_exposes_a_weakpoint() -> void:
	var view := BossView.new()
	add_child_autofree(view)
	view.setup(null)
	assert_ne(view.weakpoint, null)
	if ModelResolver.boss_mesh_available():
		assert_false(view.using_greybox)
	else:
		assert_true(view.using_greybox)
		assert_eq(String(view.weakpoint.name), "weakpoint")


func test_bullets_hit_the_offset_circle_from_both_sides() -> void:
	var clock = _clock()
	var arch := _arch()
	var fight := _fight(clock)
	_arrive(fight)
	fight._next_skill_at = fight.elapsed + 100.0
	var sim := CombatSim.new(clock, 4, 4)
	sim.separation_enabled = false
	sim.boss_fight = fight
	sim.squad.forward_speed = 0.0
	sim.squad.count = 1
	sim.squad.weapon = WeaponStats.pistol()
	sim.squad.weapon.damage = 50.0
	var left := fight.center_x - fight.collision_radius + 0.15
	sim.squad.position = Vector3(left, 0.0, fight.center_z + 2.0)
	sim.squad.target_x = left
	sim.squad.set_cooldown(0.0)
	var hp := fight.hp
	sim.tick(0.1)
	assert_lt(fight.hp, hp, "bullet along the left lip hits")
	var missed := _fight(clock)
	_arrive(missed)
	missed._next_skill_at = missed.elapsed + 100.0
	sim.boss_fight = missed
	var outside := missed.center_x - missed.collision_radius - 0.4
	sim.squad.position = Vector3(outside, 0.0, missed.center_z + 2.0)
	sim.squad.target_x = outside
	sim.squad.set_cooldown(0.0)
	var hp2 := missed.hp
	sim.tick(0.1)
	assert_almost_eq(missed.hp, hp2, 0.01, "bullet just left of the circle misses")
	var right_fight := _fight(clock)
	_arrive(right_fight)
	right_fight._next_skill_at = right_fight.elapsed + 100.0
	sim.boss_fight = right_fight
	var right := right_fight.center_x + right_fight.collision_radius - 0.15
	sim.squad.position = Vector3(right, 0.0, right_fight.center_z + 2.0)
	sim.squad.target_x = right
	sim.squad.set_cooldown(0.0)
	var hp3 := right_fight.hp
	sim.tick(0.1)
	assert_lt(right_fight.hp, hp3, "bullet along the right lip hits")
	assert_eq(Engine.time_scale, 1.0)
	assert_gt(arch.collision_radius, 2.0)
