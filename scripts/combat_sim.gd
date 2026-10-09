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
var stage: int = 1
var desired_walker: int = 0
var desired_runner: int = 0
var contact_enabled: bool = true
## Gate and skill losses share this switch. Stress leaves it on; a scripted
## firepower run can turn it off without changing the crowd tick.
var loss_enabled: bool = true
var gold: int = 0
## Mini-boss circle. Null on the stress crowd, so that path does not grow.
var boss_fight: BossFight
var defeated: bool = false
var defeat_count: int = 0
var profile: SimProfile
## Optional. Stress runs leave this null so the crowd tick stays unchanged.
var gates: GateRunner = null
var xp := XpTrack.new()
var drops := XpDropPool.new()
var skills := SkillLoadout.new()
var roller := CardRoller.new()
var warnings := GroundWarning.new()
var casualties := CasualtyPool.new()


func _init(game_clock: Node, enemy_capacity: int = 360, bullet_capacity: int = 64) -> void:
	clock = game_clock
	squad = SquadAnchor.new()
	bullets = BulletPool.new(bullet_capacity)
	enemies = EnemyPool.new(enemy_capacity)
	hash = SpatialHash.new(0.8)
	_hit_ids.resize(16)
	_hit_t.resize(16)


func tick(gameplay_delta: float) -> void:
	var t0 := Time.get_ticks_usec()
	if profile != null:
		hash.profile = profile
	var dt := maxf(gameplay_delta, 0.0)
	var ts := Time.get_ticks_usec()
	var gate_z_before := squad.position.z
	squad.tick(dt)
	if profile != null:
		profile.squad_us += int(Time.get_ticks_usec() - ts)
	_spawn_shots()
	_move_enemies(dt)
	_tick_slams(dt)
	if contact_enabled:
		_resolve_contact(dt)
	if separation_enabled:
		var tq := Time.get_ticks_usec()
		_separate()
		if profile != null:
			profile.hash_query_us += int(Time.get_ticks_usec() - tq)
	var tr := Time.get_ticks_usec()
	_rebuild_hash()
	if profile != null:
		profile.hash_rebuild_us += int(Time.get_ticks_usec() - tr)
	var tb := Time.get_ticks_usec()
	bullets.integrate(dt)
	if profile != null:
		profile.bullet_us += int(Time.get_ticks_usec() - tb)
	if gates != null:
		gates.absorb_bullets(bullets)
		gates.resolve_crossing(squad, gate_z_before, squad.position.z)
	_resolve_hits()
	tb = Time.get_ticks_usec()
	bullets.flush_retired()
	if profile != null:
		profile.bullet_us += int(Time.get_ticks_usec() - tb)
	enemies.tick_timers(dt)
	_collect_drops(dt)
	casualties.tick(dt)
	if auto_respawn:
		maintain_counts()
	if profile != null:
		profile.combat_us += int(Time.get_ticks_usec() - t0)


func maintain_counts() -> void:
	var walkers := desired_walker
	var runners := desired_runner
	if walkers <= 0 and runners <= 0:
		walkers = desired_grunt
	while enemies.count_species(EnemyPool.Species.WALKER) < walkers:
		if _spawn_archetype(EnemyCatalog.walker()) < 0:
			return
	while enemies.count_species(EnemyPool.Species.RUNNER) < runners:
		if _spawn_archetype(EnemyCatalog.runner()) < 0:
			return
	while enemies.count_kind(EnemyPool.Archetype.ELITE) < desired_elite:
		if _spawn_archetype(EnemyCatalog.elite()) < 0:
			return
	while enemies.count_kind(EnemyPool.Archetype.BOSS) < desired_boss:
		if _spawn_ahead(EnemyPool.Archetype.BOSS) < 0:
			return


func spawn_at(kind: int, px: float, pz: float, hit_points: float, move_speed: float, body_radius: float, color_variant: float) -> int:
	return enemies.spawn(kind, px, pz, hit_points, move_speed, body_radius, color_variant)


func _spawn_archetype(arch: EnemyArchetype) -> int:
	var px := randf_range(-lane_span, lane_span)
	var pz := squad.position.z - randf_range(respawn_near, respawn_far)
	var variant := clampf(arch.color_variant + randf_range(-0.04, 0.04), 0.0, 1.0)
	return EnemyCatalog.place(enemies, arch, stage, px, pz, variant)


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
		var muzzle := Vector2.ZERO
		if shot.has("muzzle"):
			muzzle = shot["muzzle"]
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
				origin.x + offsets[i] + muzzle.x,
				origin.z + muzzle.y,
				dir.x * speed,
				dir.z * speed,
				float(shot["damage"]),
				int(shot["pierce"]),
				float(shot["range"])
			)


func _move_enemies(dt: float) -> void:
	if dt <= 0.0:
		return
	_refresh_elite_speeds()
	var sz := squad.position.z
	var zs := enemies.z
	var speeds := enemies.speed
	var states := enemies.state
	var ids := enemies.active_ids
	var i := 0
	while i < enemies.active_n:
		var id := ids[i]
		if states[id] != EnemyPool.State.ALIVE:
			i += 1
			continue
		var dz := sz - zs[id]
		if absf(dz) < 0.05:
			i += 1
			continue
		zs[id] += signf(dz) * speeds[id] * dt
		# Passed the squad: drop them so the respawn path keeps the wave full.
		if zs[id] > sz + 1.5:
			enemies.recycle(id)
			continue
		i += 1


func _separate() -> void:
	hash.separate_window(enemies.x, enemies.z, enemies.radius, enemies.state, enemies.active_ids, enemies.active_n, EnemyPool.State.ALIVE)


func _rebuild_hash() -> void:
	hash.rebuild_window(-12.0, squad.position.z - 60.0, enemies.active_ids, enemies.active_n, enemies.x, enemies.z, enemies.radius, enemies.state, EnemyPool.State.ALIVE)


func _resolve_hits() -> void:
	var search := BULLET_RADIUS + EnemyPool.MAX_BODY_RADIUS
	var alive := bullets.alive
	var b := 0
	while b < bullets.capacity:
		if alive[b] == 0:
			b += 1
			continue
		var found := hash.collect_segment_window(bullets.prev_x[b], bullets.prev_z[b], bullets.x[b], bullets.z[b], search)
		var hits := 0
		var s := 0
		while s < found:
			var id := hash.scratch_id(s)
			s += 1
			if id == bullets.last_hit[b]:
				continue
			if enemies.state[id] != EnemyPool.State.ALIVE:
				continue
			var limit := enemies.radius[id] + BULLET_RADIUS
			if not _segment_hits(bullets.prev_x[b], bullets.prev_z[b], bullets.x[b], bullets.z[b], enemies.x[id], enemies.z[id], limit):
				continue
			if hits >= _hit_ids.size():
				_hit_ids.resize(hits + 8)
				_hit_t.resize(hits + 8)
			_hit_ids[hits] = id
			_hit_t[hits] = _segment_t(bullets.prev_x[b], bullets.prev_z[b], bullets.x[b], bullets.z[b], enemies.x[id], enemies.z[id])
			hits += 1
		var i := 1
		while i < hits:
			var j := i
			while j > 0 and _hit_t[j] < _hit_t[j - 1]:
				var tmp_t := _hit_t[j - 1]
				_hit_t[j - 1] = _hit_t[j]
				_hit_t[j] = tmp_t
				var tmp_id := _hit_ids[j - 1]
				_hit_ids[j - 1] = _hit_ids[j]
				_hit_ids[j] = tmp_id
				j -= 1
			i += 1
		var h := 0
		while h < hits:
			if alive[b] == 0:
				break
			var id2 := _hit_ids[h]
			var killed := enemies.hit(id2, bullets.damage[b], bullets.vx[b], bullets.vz[b])
			bullets.last_hit[b] = id2
			hash.note_move_window(id2, enemies.x[id2], enemies.z[id2])
			if h == 0:
				_maybe_split(b, id2)
			if killed:
				if enemies.archetype[id2] == EnemyPool.Archetype.ELITE:
					clock.hit_stop(60.0)
				_on_killed(id2)
			if bullets.pierce[b] > 0:
				bullets.pierce[b] -= 1
			else:
				bullets.deactivate(b)
				break
			h += 1
		if alive[b] != 0 and boss_fight != null and boss_fight.can_receive_hit():
			var reach := boss_fight.collision_radius + BULLET_RADIUS
			if _segment_hits(bullets.prev_x[b], bullets.prev_z[b], bullets.x[b], bullets.z[b], boss_fight.center_x, boss_fight.center_z, reach):
				boss_fight.apply_damage(bullets.damage[b])
				if bullets.pierce[b] > 0:
					bullets.pierce[b] -= 1
				else:
					bullets.deactivate(b)
		b += 1


var _hit_ids := PackedInt32Array()
var _hit_t := PackedFloat32Array()


func _segment_hits(x0: float, z0: float, x1: float, z1: float, cx: float, cz: float, radius: float) -> bool:
	var t := _segment_t(x0, z0, x1, z1, cx, cz)
	var px := lerpf(x0, x1, t)
	var pz := lerpf(z0, z1, t)
	var dx := px - cx
	var dz := pz - cz
	return dx * dx + dz * dz <= radius * radius


func _refresh_elite_speeds() -> void:
	var sz := squad.position.z
	var ids := enemies.active_ids
	var i := 0
	while i < enemies.active_n:
		var id := ids[i]
		i += 1
		if enemies.species[id] != EnemyPool.Species.ELITE:
			continue
		if enemies.state[id] != EnemyPool.State.ALIVE:
			continue
		var cruise := enemies.cruise_speed[id]
		if cruise <= 0.0:
			continue
		var gap := sz - enemies.z[id]
		if enemies.near_distance[id] > 0.0 and gap <= enemies.near_distance[id] and gap > 0.0:
			enemies.speed[id] = enemies.near_speed[id]
		else:
			enemies.speed[id] = cruise


func _tick_slams(dt: float) -> void:
	if dt <= 0.0:
		return
	var diameter := SquadAnchor.formation_radius(squad.count) * 2.0
	var hits := warnings.tick(dt, squad.position.x, diameter)
	var n := 0
	while n < hits:
		_apply_loss(_slam_loss(squad.count))
		n += 1
	var ids := enemies.active_ids
	var i := 0
	while i < enemies.active_n:
		var id := ids[i]
		i += 1
		if enemies.state[id] != EnemyPool.State.ALIVE:
			continue
		if enemies.slam_interval[id] <= 0.0:
			continue
		if enemies.warning_slot[id] >= 0:
			if not warnings.is_active(enemies.warning_slot[id]):
				enemies.warning_slot[id] = -1
				enemies.slam_timer[id] = 0.0
			continue
		enemies.slam_timer[id] += dt
		var windup := enemies.slam_interval[id] - enemies.warn_time[id]
		if windup < 0.0:
			windup = 0.0
		if enemies.slam_timer[id] < windup:
			continue
		var slot := warnings.begin_half_lane(squad.position.x, enemies.warn_time[id], id)
		enemies.warning_slot[id] = slot
		enemies.slam_timer[id] = 0.0


func _resolve_contact(dt: float) -> void:
	if dt <= 0.0 or squad.count <= 0:
		return
	var ring := SquadAnchor.formation_radius(squad.count)
	var sx := squad.position.x
	var sz := squad.position.z
	var ids := enemies.active_ids
	var i := 0
	while i < enemies.active_n:
		var id := ids[i]
		i += 1
		if enemies.state[id] != EnemyPool.State.ALIVE:
			continue
		var dx := enemies.x[id] - sx
		var dz := enemies.z[id] - sz
		var limit := enemies.radius[id] + ring
		var overlapping := dx * dx + dz * dz <= limit * limit
		if enemies.archetype[id] == EnemyPool.Archetype.GRUNT:
			if not overlapping:
				continue
			if enemies.kill(id):
				_on_killed(id)
				_apply_loss(enemies.weight[id])
			continue
		if enemies.touch_period[id] <= 0.0:
			continue
		if not overlapping:
			enemies.contact_cd[id] = 0.0
			continue
		if enemies.contact_cd[id] > 0.0:
			enemies.contact_cd[id] -= dt
			if enemies.contact_cd[id] > 0.0:
				continue
		_apply_loss(enemies.touch_damage[id])
		enemies.contact_cd[id] = enemies.touch_period[id]


func _collect_drops(dt: float) -> void:
	var reach := SquadAnchor.formation_radius(squad.count) + 0.6
	var gained := drops.tick(dt, squad.position.x, squad.position.z, reach)
	if gained > 0:
		xp.add(gained)


func _on_killed(id: int) -> void:
	if enemies.gold[id] > 0:
		gold += enemies.gold[id]
	if enemies.grants_offer[id] != 0:
		xp.grant_offer()
		return
	var amount := enemies.xp_value[id]
	if amount <= 0:
		return
	if not drops.try_spawn(enemies.x[id], enemies.z[id], amount):
		xp.add(amount)


func _apply_loss(n: int) -> void:
	if not loss_enabled or n <= 0:
		return
	var loss := squad.apply_loss(n)
	if loss > 0:
		casualties.spawn_around(squad, loss)
	if squad.count == 0 and not defeated:
		defeated = true
		defeat_count += 1


static func _slam_loss(count: int) -> int:
	if count <= 0:
		return 0
	var scaled := int(round(float(count) * 0.2))
	return mini(count, maxi(3, scaled))


func _maybe_split(bullet: int, enemy_id: int) -> void:
	var shots := squad.skill_split_count
	if shots <= 1:
		return
	if bullets.flags[bullet] & BulletPool.FLAG_SPLIT:
		return
	var vx := bullets.vx[bullet]
	var vz := bullets.vz[bullet]
	var speed := sqrt(vx * vx + vz * vz)
	if speed < 0.001:
		return
	var ratio := squad.skill_split_ratio
	if ratio <= 0.0:
		ratio = 0.5
	var dmg := bullets.damage[bullet] * ratio
	var remain := maxf(bullets.max_range[bullet] - bullets.traveled[bullet], 4.0)
	var pierce := bullets.pierce[bullet]
	var half := deg_to_rad(squad.skill_split_spread)
	var i := 0
	while i < shots:
		var t := 0.0 if shots == 1 else float(i) / float(shots - 1)
		var ang := lerpf(-half, half, t)
		var c := cos(ang)
		var s := sin(ang)
		var rvx := vx * c - vz * s
		var rvz := vx * s + vz * c
		var child := bullets.try_spawn(
			enemies.x[enemy_id],
			enemies.z[enemy_id],
			rvx,
			rvz,
			dmg,
			pierce,
			remain,
			BulletPool.FLAG_SPLIT
		)
		if child >= 0:
			bullets.last_hit[child] = enemy_id
		i += 1


func _segment_t(x0: float, z0: float, x1: float, z1: float, cx: float, cz: float) -> float:
	var dx := x1 - x0
	var dz := z1 - z0
	var len2 := dx * dx + dz * dz
	if len2 <= 0.0000001:
		return 0.0
	return clampf(((cx - x0) * dx + (cz - z0) * dz) / len2, 0.0, 1.0)
