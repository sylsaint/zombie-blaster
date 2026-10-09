class_name CombatSim
extends RefCounted
## Squad, bullets, and enemies on the gameplay clock. Hits go through the spatial hash.


const BULLET_RADIUS := 0.08

var clock: Node
var squad: SquadAnchor
var bullets: BulletPool
var enemies: EnemyPool
var hash: SpatialHash
var separation_enabled: bool = true
var auto_respawn: bool = false
var desired_grunt: int = 0
var desired_elite: int = 0
var desired_boss: int = 0
var respawn_near: float = 16.0
var respawn_far: float = 34.0
var lane_span: float = 2.4


func _init(game_clock: Node, enemy_capacity: int = 360, bullet_capacity: int = 64) -> void:
	clock = game_clock
	squad = SquadAnchor.new()
	bullets = BulletPool.new(bullet_capacity)
	enemies = EnemyPool.new(enemy_capacity)
	hash = SpatialHash.new(0.8)


func tick(gameplay_delta: float) -> void:
	var dt := maxf(gameplay_delta, 0.0)
	squad.tick(dt)
	_spawn_shots()
	_move_enemies(dt)
	if separation_enabled:
		_separate()
	_rebuild_hash()
	bullets.integrate(dt)
	_resolve_hits()
	bullets.flush_retired()
	enemies.tick_timers(dt)
	if auto_respawn:
		maintain_counts()


func maintain_counts() -> void:
	while enemies.count_kind(EnemyPool.Archetype.GRUNT) < desired_grunt:
		if _spawn_ahead(EnemyPool.Archetype.GRUNT) < 0:
			return
	while enemies.count_kind(EnemyPool.Archetype.ELITE) < desired_elite:
		if _spawn_ahead(EnemyPool.Archetype.ELITE) < 0:
			return
	while enemies.count_kind(EnemyPool.Archetype.BOSS) < desired_boss:
		if _spawn_ahead(EnemyPool.Archetype.BOSS) < 0:
			return


func spawn_at(kind: int, px: float, pz: float, hit_points: float, move_speed: float, body_radius: float, color_variant: float) -> int:
	return enemies.spawn(kind, px, pz, hit_points, move_speed, body_radius, color_variant)


func _spawn_ahead(kind: int) -> int:
	var px := randf_range(-lane_span, lane_span)
	var pz := squad.position.z - randf_range(respawn_near, respawn_far)
	match kind:
		EnemyPool.Archetype.ELITE:
			return enemies.spawn(kind, px, pz, 220.0, 1.1, EnemyPool.ELITE_RADIUS, randf_range(0.72, 0.95))
		EnemyPool.Archetype.BOSS:
			return enemies.spawn(kind, px, pz, 4000.0, 0.9, EnemyPool.BOSS_RADIUS, 0.5)
		_:
			return enemies.spawn(kind, px, pz, 20.0, 1.6, EnemyPool.GRUNT_RADIUS, randf_range(0.05, 0.45))


func _spawn_shots() -> void:
	for shot in squad.consume_shots():
		var origin: Vector3 = shot["origin"]
		var offsets: PackedFloat32Array = shot["offsets"]
		var pellets := offsets.size()
		var spread := float(shot["spread"])
		for i in pellets:
			var ang := 0.0
			if pellets > 1 and spread > 0.0:
				var t := float(i) / float(pellets - 1)
				ang = deg_to_rad(lerpf(-spread * 0.5, spread * 0.5, t))
			var dir := Vector3(sin(ang), 0.0, -cos(ang))
			var speed := float(shot["speed"])
			bullets.try_spawn(
				origin.x + offsets[i],
				origin.z,
				dir.x * speed,
				dir.z * speed,
				float(shot["damage"]),
				int(shot["pierce"]),
				float(shot["range"])
			)


func _move_enemies(dt: float) -> void:
	if dt <= 0.0:
		return
	var sz := squad.position.z
	for i in enemies.capacity:
		if enemies.state[i] != EnemyPool.State.ALIVE:
			continue
		var dz := sz - enemies.z[i]
		if absf(dz) < 0.05:
			continue
		enemies.z[i] += signf(dz) * enemies.speed[i] * dt
		# Passed the squad: drop them so the respawn path keeps the wave full.
		if enemies.z[i] > sz + 1.5:
			enemies.recycle(i)


func _separate() -> void:
	for i in enemies.capacity:
		if enemies.state[i] != EnemyPool.State.ALIVE:
			continue
		var reach := enemies.radius[i] * 2.2
		var ids := hash.query(enemies.x[i], enemies.z[i], reach + 0.2)
		var checks := 0
		for other in ids:
			if other == i or enemies.state[other] != EnemyPool.State.ALIVE:
				continue
			checks += 1
			if checks > 8:
				break
			var dx := enemies.x[i] - enemies.x[other]
			var dz := enemies.z[i] - enemies.z[other]
			var dist := sqrt(dx * dx + dz * dz)
			var min_d := enemies.radius[i] + enemies.radius[other]
			if dist >= min_d:
				continue
			if dist <= 0.0001:
				enemies.x[i] += 0.02
				continue
			var push := (min_d - dist) * 0.5
			enemies.x[i] += dx / dist * push
			enemies.z[i] += dz / dist * push


func _rebuild_hash() -> void:
	hash.clear()
	for i in enemies.capacity:
		if enemies.state[i] == EnemyPool.State.ALIVE:
			hash.insert(i, enemies.x[i], enemies.z[i], enemies.radius[i])


func _resolve_hits() -> void:
	var search := BULLET_RADIUS + EnemyPool.MAX_BODY_RADIUS
	for b in bullets.capacity:
		if bullets.alive[b] == 0:
			continue
		var ids := hash.query_segment(bullets.prev_x[b], bullets.prev_z[b], bullets.x[b], bullets.z[b], search)
		var hits: Array = []
		for id in ids:
			if id == bullets.last_hit[b]:
				continue
			if enemies.state[id] != EnemyPool.State.ALIVE:
				continue
			var limit := enemies.radius[id] + BULLET_RADIUS
			if not _segment_hits(bullets.prev_x[b], bullets.prev_z[b], bullets.x[b], bullets.z[b], enemies.x[id], enemies.z[id], limit):
				continue
			hits.append({"id": id, "t": _segment_t(bullets.prev_x[b], bullets.prev_z[b], bullets.x[b], bullets.z[b], enemies.x[id], enemies.z[id])})
		hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["t"]) < float(b["t"]))
		for hit in hits:
			if bullets.alive[b] == 0:
				break
			var id: int = hit["id"]
			var killed := enemies.hit(id, bullets.damage[b], bullets.vx[b], bullets.vz[b])
			bullets.last_hit[b] = id
			hash.move(id, enemies.x[id], enemies.z[id])
			if killed and enemies.archetype[id] == EnemyPool.Archetype.ELITE:
				clock.hit_stop(60.0)
			if bullets.pierce[b] > 0:
				bullets.pierce[b] -= 1
			else:
				bullets.deactivate(b)
				break


func _segment_hits(x0: float, z0: float, x1: float, z1: float, cx: float, cz: float, radius: float) -> bool:
	var t := _segment_t(x0, z0, x1, z1, cx, cz)
	var px := lerpf(x0, x1, t)
	var pz := lerpf(z0, z1, t)
	var dx := px - cx
	var dz := pz - cz
	return dx * dx + dz * dz <= radius * radius


func _segment_t(x0: float, z0: float, x1: float, z1: float, cx: float, cz: float) -> float:
	var dx := x1 - x0
	var dz := z1 - z0
	var len2 := dx * dx + dz * dz
	if len2 <= 0.0000001:
		return 0.0
	return clampf(((cx - x0) * dx + (cz - z0) * dz) / len2, 0.0, 1.0)
