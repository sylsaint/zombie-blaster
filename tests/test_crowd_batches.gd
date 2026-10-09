extends GutTest

const _Clock := preload("res://scripts/game_clock.gd")


func test_draw_batches_do_not_grow_from_50_to_300() -> void:
	var clock = autofree(_Clock.new())
	var sim := CombatSim.new(clock, 360, 8)
	sim.squad.set_cooldown(10.0)
	var view := CrowdView.new()
	add_child_autofree(view)
	view.setup()
	var material := view.shared_material
	var grunt_mat := view.grunt_mm.material_override
	for i in 50:
		sim.spawn_at(EnemyPool.Archetype.GRUNT, float(i % 10) * 0.5, -float(i / 10), 20.0, 0.0, 0.4, 0.2)
	view.sync(sim)
	var batches_50 := view.logical_batch_count()
	var instances_50 := view.visible_body_instances()
	for i in 250:
		sim.spawn_at(EnemyPool.Archetype.GRUNT, float(i % 15) * 0.4, -8.0 - float(i / 15), 20.0, 0.0, 0.4, 0.3)
	view.sync(sim)
	sim.enemies.hit(0, 1.0, 0.0, -1.0)
	view.sync(sim)
	assert_eq(instances_50, 50)
	assert_eq(view.visible_body_instances(), 300)
	assert_eq(view.logical_batch_count(), batches_50)
	assert_gt(batches_50, 0)
	assert_eq(view.shared_material, material)
	assert_eq(view.grunt_mm.material_override, grunt_mat)
	assert_eq(view.runner_mm.material_override, material)
	assert_eq(view.elite_mm.material_override, material)
	assert_eq(view.boss_mm.material_override, material)
	assert_eq(view.grunt_mm.multimesh.instance_count, CrowdView.GRUNT_CAP)
	assert_almost_eq(view._buf_grunt[3], 0.0, 0.001)
	assert_almost_eq(view._buf_grunt[16 + 3], 0.5, 0.001)
	assert_almost_eq(view._buf_grunt[12], 1.0, 0.001)


func test_placeholder_triangles_stay_inside_budget() -> void:
	var grunt := PlaceholderMeshes.triangle_count(PlaceholderMeshes.grunt())
	var elite := PlaceholderMeshes.triangle_count(PlaceholderMeshes.elite())
	var boss := PlaceholderMeshes.triangle_count(PlaceholderMeshes.boss())
	var soldier := PlaceholderMeshes.triangle_count(PlaceholderMeshes.soldier())
	assert_between(grunt, 250, 360)
	assert_lte(elite, 1500)
	assert_lte(boss, 5000)
	var on_screen := 300 * grunt + 3 * elite + 1 * boss + 40 * soldier
	assert_lte(on_screen, 150000)


func test_timers_follow_the_gameplay_clock() -> void:
	var clock = autofree(_Clock.new())
	var sim := CombatSim.new(clock, 4, 4)
	sim.separation_enabled = false
	sim.squad.forward_speed = 0.0
	sim.squad.set_cooldown(10.0)
	var id := sim.spawn_at(EnemyPool.Archetype.GRUNT, 0.0, -4.0, 50.0, 1.6, 0.4, 0.2)
	var z := sim.enemies.z[id]
	clock.hit_stop(60.0)
	sim.tick(clock.advance(0.06))
	assert_almost_eq(sim.enemies.z[id], z, 0.0001, "frozen clock does not move the crowd")
	sim.tick(clock.advance(0.05))
	assert_gt(sim.enemies.z[id], z, "after the freeze, grunts walk toward the squad")
