extends GutTest

const _Clock := preload("res://scripts/game_clock.gd")


func test_bullet_hit_damages_flashes_and_does_not_grow_pools() -> void:
	var clock = autofree(_Clock.new())
	var sim := CombatSim.new(clock, 8, 8)
	sim.separation_enabled = false
	sim.contact_enabled = false
	sim.squad.count = 1
	sim.squad.forward_speed = 0.0
	sim.squad.weapon = WeaponStats.pistol()
	sim.squad.set_cooldown(0.0)
	var id := sim.spawn_at(EnemyPool.Archetype.GRUNT, 0.0, -0.3, 100.0, 0.0, 0.4, 0.2)
	var enemy_cap := sim.enemies.capacity
	var bullet_cap := sim.bullets.capacity
	sim.tick(0.02)
	assert_lt(sim.enemies.hp[id], 100.0)
	assert_gt(sim.enemies.flash_left[id], 0.0)
	assert_almost_eq(sim.enemies.z[id], -0.45, 0.02)
	assert_eq(sim.enemies.capacity, enemy_cap)
	assert_eq(sim.bullets.capacity, bullet_cap)
	assert_eq(sim.bullets.x.size(), bullet_cap)
	assert_eq(clock.hit_stop_remaining(), 0.0)


func test_elite_death_requests_hit_stop_grunt_death_does_not() -> void:
	var clock = autofree(_Clock.new())
	var sim := CombatSim.new(clock, 4, 4)
	sim.separation_enabled = false
	sim.squad.count = 1
	sim.squad.forward_speed = 0.0
	var weapon := WeaponStats.pistol()
	weapon.damage = 1000.0
	sim.squad.weapon = weapon
	sim.squad.set_cooldown(0.0)
	var grunt := sim.spawn_at(EnemyPool.Archetype.GRUNT, 0.0, -2.0, 5.0, 0.0, 0.4, 0.2)
	sim.tick(0.1)
	assert_eq(sim.enemies.state[grunt], EnemyPool.State.DYING)
	assert_eq(clock.hit_stop_remaining(), 0.0)
	sim.squad.set_cooldown(0.0)
	var elite := sim.spawn_at(EnemyPool.Archetype.ELITE, 0.0, -2.0, 5.0, 0.0, 0.7, 0.8)
	sim.tick(0.1)
	assert_eq(sim.enemies.state[elite], EnemyPool.State.DYING)
	assert_gt(clock.hit_stop_remaining(), 0.05)
	var ui := 0.016
	var gameplay: float = clock.advance(0.016)
	assert_almost_eq(gameplay, 0.0, 0.0001)
	assert_gt(ui, gameplay)
	assert_eq(Engine.time_scale, 1.0)


func test_separation_pushes_overlapping_grunts_apart() -> void:
	var clock = autofree(_Clock.new())
	var sim := CombatSim.new(clock, 8, 4)
	sim.separation_enabled = true
	sim.squad.forward_speed = 0.0
	sim.squad.set_cooldown(10.0)
	var a := sim.spawn_at(EnemyPool.Archetype.GRUNT, 0.0, -5.0, 20.0, 0.0, 0.4, 0.2)
	var b := sim.spawn_at(EnemyPool.Archetype.GRUNT, 0.1, -5.0, 20.0, 0.0, 0.4, 0.2)
	sim.tick(0.0)
	sim.tick(0.0)
	var dx: float = absf(sim.enemies.x[a] - sim.enemies.x[b])
	assert_gt(dx, 0.2)


func test_respawn_reuses_slots_and_keeps_the_count() -> void:
	var clock = autofree(_Clock.new())
	var sim := CombatSim.new(clock, 6, 4)
	sim.separation_enabled = false
	sim.auto_respawn = true
	sim.desired_grunt = 2
	sim.squad.forward_speed = 0.0
	sim.squad.set_cooldown(10.0)
	var cap := sim.enemies.capacity
	sim.spawn_at(EnemyPool.Archetype.GRUNT, 0.0, -3.0, 5.0, 0.0, 0.4, 0.2)
	sim.spawn_at(EnemyPool.Archetype.GRUNT, 1.0, -3.0, 5.0, 0.0, 0.4, 0.2)
	sim.enemies.hit(0, 999.0, 0.0, -1.0)
	sim.tick(EnemyPool.DISSOLVE_TIME)
	assert_eq(sim.enemies.count_kind(EnemyPool.Archetype.GRUNT), 2)
	assert_eq(sim.enemies.capacity, cap)
	assert_eq(sim.enemies.active_count, 2)
