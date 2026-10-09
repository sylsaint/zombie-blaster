extends GutTest

const _Clock := preload("res://scripts/game_clock.gd")

const _GRUNT_MULT := [1.0, 1.13, 1.28, 1.44, 1.63, 1.84, 2.08, 2.35, 2.66, 3.0]
const _ELITE_HP := [4800.0, 5700.0, 6700.0, 7900.0, 9300.0, 11000.0, 13000.0, 15300.0, 18000.0, 21300.0]


func test_enemy_resources_match_the_design_table() -> void:
	var stages := EnemyCatalog.stages()
	var walker := EnemyCatalog.walker()
	var runner := EnemyCatalog.runner()
	var elite := EnemyCatalog.elite()
	assert_eq(walker.id, "enm_walker_a")
	assert_almost_eq(walker.base_hp, 20.0, 0.001)
	assert_almost_eq(walker.speed, 1.6, 0.001)
	assert_eq(walker.weight, 1)
	assert_eq(walker.xp, 1)
	assert_eq(walker.mesh_high.get_file(), "enm_walker.glb")
	assert_eq(walker.mesh_low.get_file(), "enm_walker_lod1.glb")
	assert_eq(runner.id, "enm_runner_a")
	assert_almost_eq(runner.base_hp, 12.0, 0.001)
	assert_almost_eq(runner.speed, 3.5, 0.001)
	assert_eq(runner.weight, 1)
	assert_eq(runner.xp, 1)
	assert_eq(runner.mesh_high.get_file(), "enm_runner.glb")
	assert_eq(runner.mesh_low.get_file(), "enm_runner_lod1.glb")
	assert_eq(elite.id, "enm_elite_brute")
	assert_almost_eq(elite.radius, 1.2, 0.001)
	assert_almost_eq(elite.near_speed, 0.6, 0.001)
	assert_almost_eq(elite.near_distance, 10.0, 0.001)
	assert_eq(elite.touch_damage, 2)
	assert_almost_eq(elite.touch_period, 0.5, 0.001)
	assert_almost_eq(elite.slam_interval, 4.0, 0.001)
	assert_almost_eq(elite.warn_time, 1.0, 0.001)
	assert_eq(elite.gold, 20)
	assert_true(elite.grants_offer)
	assert_eq(elite.xp, 0)
	assert_eq(elite.mesh_high.get_file(), "enm_elite_brute.glb")
	for stage in 10:
		assert_almost_eq(stages.grunt_multiplier(stage + 1), _GRUNT_MULT[stage], 0.001)
		assert_almost_eq(stages.elite_hp_for(stage + 1), _ELITE_HP[stage], 0.1)
	var pool := EnemyPool.new(8)
	var walker_id := EnemyCatalog.place(pool, walker, 5, 0.0, 0.0, 0.2)
	assert_almost_eq(pool.hp[walker_id], 20.0 * 1.63, 0.02)
	assert_almost_eq(pool.speed[walker_id], 1.6, 0.001)
	assert_eq(pool.weight[walker_id], 1)
	assert_eq(pool.species[walker_id], EnemyPool.Species.WALKER)
	var runner_id := EnemyCatalog.place(pool, runner, 2, 1.0, 0.0, 0.4)
	assert_almost_eq(pool.hp[runner_id], 12.0 * 1.13, 0.02)
	assert_almost_eq(pool.speed[runner_id], 3.5, 0.001)
	assert_eq(pool.species[runner_id], EnemyPool.Species.RUNNER)
	for stage in [1, 2, 3]:
		var elite_id := EnemyCatalog.place(pool, elite, stage, 0.0, -2.0, 0.8)
		assert_almost_eq(pool.hp[elite_id], _ELITE_HP[stage - 1], 0.1)
		assert_almost_eq(pool.radius[elite_id], 1.2, 0.001)
		pool.recycle(elite_id)


func test_placeholder_lod_meshes_stay_inside_the_triangle_budget() -> void:
	var walker_high := PlaceholderMeshes.triangle_count(PlaceholderMeshes.grunt())
	var walker_low := PlaceholderMeshes.triangle_count(PlaceholderMeshes.walker_lod())
	var runner_high := PlaceholderMeshes.triangle_count(PlaceholderMeshes.runner())
	var runner_low := PlaceholderMeshes.triangle_count(PlaceholderMeshes.runner_lod())
	var elite := PlaceholderMeshes.triangle_count(PlaceholderMeshes.elite())
	assert_lte(walker_high, 450)
	assert_lte(runner_high, 450)
	assert_between(walker_high, 200, 450)
	assert_between(runner_high, 200, 450)
	assert_lte(walker_low, 200)
	assert_lte(runner_low, 200)
	assert_gt(walker_low, 40)
	assert_gt(runner_low, 40)
	assert_lte(elite, 1500)
	var mixed := 100 * walker_high + 80 * walker_low + 40 * runner_high + 80 * runner_low
	mixed += 3 * elite + PlaceholderMeshes.triangle_count(PlaceholderMeshes.boss())
	mixed += 40 * PlaceholderMeshes.triangle_count(PlaceholderMeshes.soldier())
	assert_lte(mixed, 150000)


func test_lod_keeps_the_nearest_hundred_on_the_high_mesh() -> void:
	var pool := EnemyPool.new(160)
	for i in 120:
		pool.spawn(EnemyPool.Archetype.GRUNT, 0.0, -float(i), 20.0, 1.6, 0.4, 0.2)
	var lod := CrowdLod.new(pool.capacity)
	lod.classify(pool.active_ids, pool.active_n, pool.species, pool.state, pool.x, pool.z, 0.0, 0.0)
	assert_true(lod.is_high(0))
	assert_false(lod.is_high(119))
	var highs := 0
	for i in 120:
		if lod.is_high(i):
			highs += 1
	assert_eq(highs, CrowdLod.HIGH_BUDGET)
	var view := CrowdView.new()
	add_child_autofree(view)
	view.setup()
	assert_true(view.walker_high_fallback)
	assert_true(view.walker_low_fallback)
	assert_true(view.runner_high_fallback)
	assert_true(view.runner_low_fallback)
	assert_eq(view.grunt_mm.material_override, view.shared_material)
	assert_eq(view.walker_lod_mm.material_override, view.shared_material)
	assert_eq(view.runner_mm.material_override, view.shared_material)
	assert_eq(view.runner_lod_mm.material_override, view.shared_material)
	var clock = autofree(_Clock.new())
	var sim := CombatSim.new(clock, 200, 4)
	sim.squad.set_cooldown(10.0)
	for i in 120:
		var species := EnemyPool.Species.RUNNER if i % 2 == 0 else EnemyPool.Species.WALKER
		sim.enemies.spawn(EnemyPool.Archetype.GRUNT, 0.0, -float(i) * 0.5, 20.0, 1.6, 0.4, 0.2, species, 1, 1)
	var batches := view.logical_batch_count()
	view.sync(sim)
	var high := view.grunt_mm.multimesh.visible_instance_count + view.runner_mm.multimesh.visible_instance_count
	var low := view.walker_lod_mm.multimesh.visible_instance_count + view.runner_lod_mm.multimesh.visible_instance_count
	assert_eq(high, 100)
	assert_eq(low, 20)
	assert_eq(view.visible_body_instances(), 120)
	for _i in 40:
		sim.enemies.spawn(EnemyPool.Archetype.GRUNT, 1.0, -80.0, 20.0, 1.6, 0.4, 0.2)
	view.sync(sim)
	assert_eq(view.logical_batch_count(), batches)
	assert_eq(view.grunt_mm.multimesh.visible_instance_count + view.runner_mm.multimesh.visible_instance_count, 100)
	assert_eq(view.visible_body_instances(), 160)


func test_grunt_contact_kills_and_wipes_once() -> void:
	var clock = autofree(_Clock.new())
	var sim := CombatSim.new(clock, 4, 2)
	sim.separation_enabled = false
	sim.squad.forward_speed = 0.0
	sim.squad.set_cooldown(10.0)
	sim.squad.count = 6
	var id := EnemyCatalog.place(sim.enemies, EnemyCatalog.walker(), 1, 0.0, 0.0, 0.2)
	sim.tick(0.0)
	assert_eq(sim.enemies.state[id], EnemyPool.State.ALIVE)
	assert_eq(sim.squad.count, 6)
	sim.tick(0.05)
	assert_eq(sim.enemies.state[id], EnemyPool.State.DYING)
	assert_eq(sim.squad.count, 5)
	assert_eq(sim.xp.xp, 1)
	assert_eq(sim.defeat_count, 0)
	sim.squad.count = 1
	EnemyCatalog.place(sim.enemies, EnemyCatalog.walker(), 1, 0.0, 0.0, 0.2)
	EnemyCatalog.place(sim.enemies, EnemyCatalog.walker(), 1, 0.05, 0.0, 0.2)
	sim.tick(0.05)
	assert_eq(sim.squad.count, 0)
	assert_eq(sim.defeat_count, 1)
	sim.tick(0.05)
	assert_eq(sim.squad.count, 0)
	assert_eq(sim.defeat_count, 1)


func test_elite_armor_slow_contact_slam_and_flash() -> void:
	var clock = autofree(_Clock.new())
	var sim := CombatSim.new(clock, 4, 4)
	sim.contact_enabled = false
	sim.separation_enabled = false
	sim.squad.forward_speed = 0.0
	sim.squad.set_cooldown(10.0)
	var moving := EnemyCatalog.place(sim.enemies, EnemyCatalog.elite(), 1, 0.0, -12.0, 0.8)
	var z0 := sim.enemies.z[moving]
	sim.tick(0.1)
	assert_almost_eq(sim.enemies.z[moving], z0 + 0.12, 0.02)
	sim.enemies.z[moving] = -5.0
	z0 = sim.enemies.z[moving]
	sim.tick(0.1)
	assert_almost_eq(sim.enemies.speed[moving], 0.6, 0.001)
	assert_almost_eq(sim.enemies.z[moving], z0 + 0.06, 0.02)
	sim.enemies.recycle(moving)

	sim.contact_enabled = true
	sim.squad.count = 10
	var touching := EnemyCatalog.place(sim.enemies, EnemyCatalog.elite(), 1, 0.0, 0.0, 0.8)
	sim.enemies.cruise_speed[touching] = 0.0
	sim.enemies.speed[touching] = 0.0
	sim.enemies.slam_interval[touching] = 0.0
	sim.tick(0.016)
	assert_eq(sim.squad.count, 8)
	assert_eq(sim.enemies.state[touching], EnemyPool.State.ALIVE)
	sim.tick(0.48)
	assert_eq(sim.squad.count, 8)
	sim.tick(0.03)
	assert_eq(sim.squad.count, 6)
	assert_eq(sim.enemies.state[touching], EnemyPool.State.ALIVE)
	var dealt := sim.enemies.hp[touching]
	sim.enemies.hit(touching, 100.0, 0.0, -1.0)
	assert_almost_eq(sim.enemies.hp[touching], dealt - 100.0, 0.001)
	assert_almost_eq(sim.enemies.flash_left[touching], EnemyPool.FLASH_ELITE, 0.0001)

	var view := CrowdView.new()
	add_child_autofree(view)
	view.setup()
	view.sync(sim)
	assert_eq(view.elite_mm.material_override, view.shared_material)
	assert_almost_eq(view._buf_elite[12], 1.0, 0.001)
	assert_gt(view.bar_mm.multimesh.visible_instance_count, 0)
	sim.enemies.recycle(touching)

	sim.squad.count = 20
	sim.squad.position.x = 1.0
	sim.squad.target_x = 1.0
	var slammer := EnemyCatalog.place(sim.enemies, EnemyCatalog.elite(), 2, 0.0, -8.0, 0.8)
	assert_almost_eq(sim.enemies.hp[slammer], 5700.0, 0.1)
	sim.enemies.cruise_speed[slammer] = 0.0
	sim.enemies.speed[slammer] = 0.0
	sim.enemies.slam_timer[slammer] = 3.0 - 0.01
	sim.tick(0.02)
	var slot := sim.enemies.warning_slot[slammer]
	assert_true(sim.warnings.is_active(slot))
	assert_almost_eq(sim.warnings.age[slot], 0.0, 0.001)
	assert_almost_eq(sim.warnings.x0[slot], 0.0, 0.001)
	assert_almost_eq(sim.warnings.x1[slot], 3.75, 0.001)
	assert_eq(sim.squad.count, 20)
	sim.tick(0.5)
	assert_true(sim.warnings.is_active(slot))
	assert_eq(sim.squad.count, 20)
	sim.tick(0.5)
	assert_false(sim.warnings.is_active(slot))
	assert_gte(sim.warnings.min_telegraph(), 1.0)
	assert_true(sim.warnings.last_safe_ok)
	assert_almost_eq(sim.warnings.last_safe_width, 3.75, 0.001)
	assert_eq(sim.squad.count, 16)
	var dodge := EnemyCatalog.place(sim.enemies, EnemyCatalog.elite(), 1, 0.0, -9.0, 0.8)
	sim.enemies.cruise_speed[dodge] = 0.0
	sim.enemies.speed[dodge] = 0.0
	sim.squad.position.x = 1.2
	sim.squad.target_x = 1.2
	sim.squad.count = 20
	sim.enemies.slam_timer[dodge] = 2.99
	sim.tick(0.02)
	sim.squad.position.x = -2.0
	sim.squad.target_x = -2.0
	var before := sim.squad.count
	sim.tick(1.0)
	assert_eq(sim.squad.count, before)
	assert_gte(sim.warnings.min_telegraph(), 1.0)
	var killed := EnemyCatalog.place(sim.enemies, EnemyCatalog.elite(), 1, 3.0, -6.0, 0.8)
	sim.enemies.hp[killed] = 1.0
	assert_true(sim.enemies.hit(killed, 5.0, 0.0, -1.0))
	sim._on_killed(killed)
	clock.hit_stop(60.0)
	assert_eq(sim.gold, 20)
	assert_eq(sim.xp.pending, 1)
	assert_eq(sim.xp.xp, sim.xp.xp)
	assert_gt(clock.hit_stop_remaining(), 0.05)
	assert_eq(Engine.time_scale, 1.0)
