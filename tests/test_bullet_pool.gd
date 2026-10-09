extends GutTest


func test_bullet_recycles_at_30m_and_the_pool_does_not_grow() -> void:
	var pool := BulletPool.new(8)
	var id := pool.try_spawn(0.0, 0.0, 0.0, -30.0, 10.0, 0, 30.0)
	assert_eq(id, 0)
	pool.integrate(0.5)
	pool.flush_retired()
	assert_true(pool.is_alive(id))
	assert_almost_eq(pool.z[id], -15.0, 0.001)
	pool.integrate(0.5)
	pool.flush_retired()
	assert_false(pool.is_alive(id))
	assert_eq(pool.live_count, 0)
	assert_eq(pool.capacity, 8)
	assert_eq(pool.x.size(), 8)


func test_spawn_fails_when_full_instead_of_resizing() -> void:
	var pool := BulletPool.new(4)
	var spawned := 0
	for _i in 12:
		var id := pool.try_spawn(0.0, 0.0, 0.0, 0.0, 1.0, 0, 100.0)
		if id >= 0:
			spawned += 1
	assert_eq(spawned, 4)
	assert_eq(pool.try_spawn(0.0, 0.0, 0.0, 0.0, 1.0, 0, 100.0), -1)
	assert_eq(pool.capacity, 4)
	assert_eq(pool.x.size(), 4)
	assert_eq(pool.damage.size(), 4)
	for i in pool.capacity:
		pool.deactivate(i)
	assert_eq(pool.live_count, 0)
	assert_ne(pool.try_spawn(1.0, 2.0, 0.0, -30.0, 5.0, 1, 30.0), -1)
	assert_eq(pool.capacity, 4)
