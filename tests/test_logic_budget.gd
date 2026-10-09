extends GutTest

const _Clock := preload("res://scripts/game_clock.gd")


## Generous on purpose: a quiet VM is near 1 ms, and a busy CI host must not flake.
func test_crowd_tick_stays_under_budget() -> void:
	var clock = autofree(_Clock.new())
	var sim := CombatSim.new(clock, 360, 64)
	sim.separation_enabled = true
	sim.auto_respawn = true
	sim.desired_grunt = 300
	sim.desired_elite = 3
	sim.desired_boss = 1
	sim.squad.count = 24
	sim.squad.forward_speed = 4.0
	var weapon := WeaponStats.pistol()
	weapon.pierce = 3
	sim.squad.weapon = weapon
	sim.squad.rate_bonus = 2.0
	sim.squad.set_cooldown(0.0)
	var i := 0
	while i < 300:
		var col := i % 15
		var row := int(i / 15)
		sim.spawn_at(EnemyPool.Archetype.GRUNT, (float(col) - 7.0) * 0.36, -8.0 - float(row) * 0.85, 20.0, 1.6, 0.4, 0.2)
		i += 1
	sim.spawn_at(EnemyPool.Archetype.ELITE, -1.6, -14.0, 180.0, 1.1, 0.7, 0.8)
	sim.spawn_at(EnemyPool.Archetype.ELITE, 0.0, -14.0, 180.0, 1.1, 0.7, 0.8)
	sim.spawn_at(EnemyPool.Archetype.ELITE, 1.6, -14.0, 180.0, 1.1, 0.7, 0.8)
	sim.spawn_at(EnemyPool.Archetype.BOSS, 0.0, -22.0, 4000.0, 0.9, 1.15, 0.55)
	var warmup := 0
	while warmup < 8:
		sim.tick(0.016)
		warmup += 1
	var frames := 40
	var t0 := Time.get_ticks_usec()
	var f := 0
	while f < frames:
		sim.squad.target_x = sin(float(f) * 0.2) * 2.0
		sim.tick(0.016)
		f += 1
	var avg_ms := float(Time.get_ticks_usec() - t0) / float(frames) / 1000.0
	assert_lt(avg_ms, 20.0)
	assert_eq(sim.enemies.active_count, 304)
