extends GutTest


func test_hit_flashes_and_knocks_back_then_clears() -> void:
	var pool := EnemyPool.new(4)
	var id := pool.spawn(EnemyPool.Archetype.GRUNT, 0.0, -5.0, 20.0, 1.6, 0.4, 0.2)
	var killed := pool.hit(id, 5.0, 0.0, -1.0)
	assert_false(killed)
	assert_almost_eq(pool.hp[id], 15.0, 0.001)
	assert_almost_eq(pool.z[id], -5.15, 0.001)
	assert_almost_eq(pool.flash_left[id], EnemyPool.FLASH_GRUNT, 0.0001)
	assert_eq(pool.flash_amount(id), 1.0)
	pool.tick_timers(0.059)
	assert_eq(pool.flash_amount(id), 1.0)
	pool.tick_timers(0.002)
	assert_eq(pool.flash_amount(id), 0.0)
	assert_eq(pool.state[id], EnemyPool.State.ALIVE)


func test_elite_flash_lasts_80_ms() -> void:
	var pool := EnemyPool.new(2)
	var id := pool.spawn(EnemyPool.Archetype.ELITE, 0.0, 0.0, 100.0, 1.0, 0.7, 0.8)
	pool.hit(id, 1.0, 1.0, 0.0)
	assert_almost_eq(pool.x[id], 0.15, 0.001)
	pool.tick_timers(0.079)
	assert_gt(pool.flash_left[id], 0.0)
	pool.tick_timers(0.002)
	assert_eq(pool.flash_amount(id), 0.0)


func test_death_dissolves_then_recycles_the_same_slot() -> void:
	var pool := EnemyPool.new(3)
	var cap := pool.capacity
	var id := pool.spawn(EnemyPool.Archetype.GRUNT, 1.0, 2.0, 20.0, 1.6, 0.4, 0.1)
	assert_true(pool.hit(id, 999.0, 0.0, -1.0))
	assert_eq(pool.state[id], EnemyPool.State.DYING)
	assert_almost_eq(pool.dissolve_amount(id), 0.0, 0.001)
	pool.tick_timers(0.24)
	assert_eq(pool.state[id], EnemyPool.State.DYING)
	assert_gt(pool.dissolve_amount(id), 0.9)
	pool.tick_timers(0.02)
	assert_eq(pool.state[id], EnemyPool.State.FREE)
	assert_eq(pool.active_count, 0)
	var reused := pool.spawn(EnemyPool.Archetype.GRUNT, 0.0, 0.0, 20.0, 1.6, 0.4, 0.3)
	assert_eq(reused, id)
	assert_eq(pool.capacity, cap)
	assert_eq(pool.hp.size(), cap)


func test_pool_does_not_grow_when_full() -> void:
	var pool := EnemyPool.new(5)
	for i in pool.capacity:
		assert_ne(pool.spawn(EnemyPool.Archetype.GRUNT, float(i), 0.0, 20.0, 1.6, 0.4, 0.2), -1)
	assert_eq(pool.spawn(EnemyPool.Archetype.GRUNT, 0.0, 0.0, 20.0, 1.6, 0.4, 0.2), -1)
	assert_eq(pool.capacity, 5)
	assert_eq(pool.x.size(), 5)
	assert_eq(pool.active_count, 5)


func test_dying_enemy_ignores_further_hits() -> void:
	var pool := EnemyPool.new(2)
	var id := pool.spawn(EnemyPool.Archetype.GRUNT, 0.0, 0.0, 10.0, 1.0, 0.4, 0.2)
	assert_true(pool.hit(id, 10.0, 0.0, -1.0))
	var z := pool.z[id]
	assert_false(pool.hit(id, 10.0, 0.0, -1.0))
	assert_almost_eq(pool.z[id], z, 0.0001)
