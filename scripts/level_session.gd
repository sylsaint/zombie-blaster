class_name LevelSession
extends RefCounted
## One run of a level resource: advance, finale, then a result event.
## Reward payout is left to the results screen.


const GRUNT_CAP := 250
const SPAWN_AHEAD := 35.0
const QUEUE_CAP := 32
const ELITE_SLOTS := 8
const SUPPLY_SPEED := 6.0
const SQUAD_CAP := 150

var level: LevelData
var sim: CombatSim
var boss: BossFight
var state: String = "start"
var traveled: float = 0.0
var run_coins: int = 0
var result: RunResult
var incoming_damage: bool = true
var lock_headcount: bool = false
var freeze_build: bool = false
var weapon_level: int = 1
var supply_active: bool = false
var last_gate_capped: bool = false

var _events: Array[LevelEvent] = []
var _done := PackedByteArray()
var _cursor: int = 0
var _q_count := PackedInt32Array()
var _q_kind := PackedInt32Array()
var _q_form := PackedInt32Array()
var _q_until := PackedFloat32Array()
var _q_n: int = 0
var _spawn_x := PackedFloat32Array()
var _spawn_zoff := PackedFloat32Array()
var _casters: Array[EliteCaster] = []
var _elite_ids := PackedInt32Array()
var _elite_on := PackedByteArray()
var _elite_paid := PackedByteArray()
var _elite_finale := PackedByteArray()
var _elite_n: int = 0
var _finale_left: int = 0
var _supply_z := PackedFloat32Array()
var _supply_x := PackedFloat32Array()
var _supply_kind := PackedInt32Array()
var _supply_on := PackedByteArray()
var _locked_count: int = 0
var _walker: EnemyArchetype
var _runner: EnemyArchetype
var _elite: EnemyArchetype
var _boss_arch: EnemyArchetype


func _init() -> void:
	_q_count.resize(QUEUE_CAP)
	_q_kind.resize(QUEUE_CAP)
	_q_form.resize(QUEUE_CAP)
	_q_until.resize(QUEUE_CAP)
	_spawn_x.resize(60)
	_spawn_zoff.resize(60)
	_elite_ids.resize(ELITE_SLOTS)
	_elite_on.resize(ELITE_SLOTS)
	_elite_paid.resize(ELITE_SLOTS)
	_elite_finale.resize(ELITE_SLOTS)
	_supply_z.resize(2)
	_supply_x.resize(2)
	_supply_kind.resize(2)
	_supply_on.resize(2)
	var i := 0
	while i < ELITE_SLOTS:
		_casters.append(EliteCaster.new())
		i += 1


func start(level_data: LevelData, game_clock: Node) -> void:
	level = level_data
	sim = CombatSim.new(game_clock, 320, BulletPool.DEFAULT_CAPACITY)
	sim.squad.count = 5
	sim.squad.forward_speed = SquadAnchor.FORWARD_SPEED_DEFAULT
	sim.squad.weapon = WeaponStats.pistol()
	sim.squad.set_cooldown(0.2)
	sim.separation_enabled = true
	_walker = load("res://data/enemies/walker.tres") as EnemyArchetype
	_runner = load("res://data/enemies/runner.tres") as EnemyArchetype
	_elite = load("res://data/enemies/elite_brute.tres") as EnemyArchetype
	_boss_arch = load("res://data/enemies/boss_mutant.tres") as EnemyArchetype
	_events = level.sorted_events()
	_done.resize(_events.size())
	_done.fill(0)
	_cursor = 0
	_q_n = 0
	_elite_n = 0
	_finale_left = 0
	traveled = 0.0
	run_coins = 0
	state = "advance"
	result = null
	boss = null
	weapon_level = 1
	supply_active = false
	_locked_count = sim.squad.count


func tick(dt: float) -> void:
	if state == "win" or state == "lose":
		return
	var step := maxf(dt, 0.0)
	if lock_headcount:
		sim.squad.count = _locked_count
	if boss != null:
		sim.boss_fight = boss
	sim.tick(step)
	traveled = -sim.squad.position.z
	_trigger_events()
	_drain_queue()
	_tick_elites(step)
	_tick_boss(step)
	_tick_supply(step)
	_contact_grunts()
	_pay_elite_coins()
	if lock_headcount:
		sim.squad.count = _locked_count
	_check_end()


func progress_ratio() -> float:
	if level == null:
		return 0.0
	if boss != null or state == "win":
		return 1.0
	var end := level.finale_distance()
	if end <= 0.0001:
		return 0.0
	return clampf(traveled / end, 0.0, 1.0)


func grunt_alive() -> int:
	if sim == null:
		return 0
	return sim.enemies.count_kind(EnemyPool.Archetype.GRUNT)


func _trigger_events() -> void:
	while _cursor < _events.size():
		var event := _events[_cursor]
		if _done[_cursor] != 0:
			_cursor += 1
			continue
		if event.distance > traveled + 0.0001:
			return
		_done[_cursor] = 1
		_cursor += 1
		_fire_event(event)


func _fire_event(event: LevelEvent) -> void:
	match event.kind:
		"wave":
			_enqueue_wave(event)
		"gate_group":
			_trigger_gate(event)
		"elite":
			_spawn_elite(event, false)
		"finale_elite":
			_spawn_elite(event, true)
			state = "finale"
		"elite_wall":
			_spawn_elite(event, true)
			state = "finale"
		"boss":
			_begin_boss()


func _enqueue_wave(event: LevelEvent) -> void:
	var kind := 0
	if event.enemy_id == "enm_runner_a":
		kind = 1
	var form := 0 if event.formation != "wedge" else 1
	var until := _defer_until(event.distance)
	var left := event.count
	while left > 0 and _q_n < QUEUE_CAP:
		var batch := mini(left, 60)
		_q_count[_q_n] = batch
		_q_kind[_q_n] = kind
		_q_form[_q_n] = form
		_q_until[_q_n] = until
		_q_n += 1
		left -= batch


func _defer_until(distance: float) -> float:
	var until := 0.0
	for event in _events:
		if event.kind != "gate_group":
			continue
		var gap := event.distance - distance
		if gap > 0.0 and gap < LevelData.GATE_CLEARANCE:
			until = maxf(until, event.distance)
	return until


func _drain_queue() -> void:
	var index := 0
	while index < _q_n:
		if _q_until[index] > traveled + 0.0001:
			index += 1
			continue
		var room := GRUNT_CAP - grunt_alive()
		if room <= 0:
			return
		var batch := mini(_q_count[index], room)
		_spawn_grunts(_q_kind[index], _q_form[index], batch)
		_q_count[index] -= batch
		if _q_count[index] <= 0:
			_q_n -= 1
			var j := index
			while j < _q_n:
				_q_count[j] = _q_count[j + 1]
				_q_kind[j] = _q_kind[j + 1]
				_q_form[j] = _q_form[j + 1]
				_q_until[j] = _q_until[j + 1]
				j += 1
			continue
		return


func _spawn_grunts(kind: int, form: int, count: int) -> void:
	var arch := _runner if kind == 1 else _walker
	if arch == null:
		return
	var n := mini(count, _spawn_x.size())
	_fill_formation(n, form == 1)
	var base_z := sim.squad.position.z - SPAWN_AHEAD
	var hp := arch.base_hp * level.hp_multiplier
	var i := 0
	while i < n:
		sim.enemies.spawn(
			EnemyPool.Archetype.GRUNT,
			_spawn_x[i],
			base_z + _spawn_zoff[i],
			hp,
			arch.move_speed,
			arch.collision_radius,
			0.2 if kind == 0 else 0.55,
			arch.offset_x,
			arch.offset_z
		)
		i += 1


func _fill_formation(n: int, wedge: bool) -> void:
	if n <= 0:
		return
	if n == 1:
		_spawn_x[0] = 0.0
		_spawn_zoff[0] = 0.0
		return
	var span := 4.6
	var i := 0
	while i < n:
		var t := float(i) / float(n - 1)
		_spawn_x[i] = lerpf(-span * 0.5, span * 0.5, t)
		if wedge:
			_spawn_zoff[i] = (1.0 - absf(t - 0.5) * 2.0) * 3.0
		else:
			_spawn_zoff[i] = 0.0
		i += 1


func _spawn_elite(event: LevelEvent, finale: bool) -> void:
	var n := maxi(event.count, 1)
	var i := 0
	while i < n and _elite_n < ELITE_SLOTS:
		var t := 0.5 if n == 1 else float(i) / float(n - 1)
		var px := lerpf(-1.4, 1.4, t)
		var id := sim.enemies.spawn(
			EnemyPool.Archetype.ELITE,
			px,
			sim.squad.position.z - 10.0,
			level.elite_hp,
			0.6,
			_elite.collision_radius if _elite != null else 0.7,
			0.85,
			_elite.offset_x if _elite != null else 0.0,
			_elite.offset_z if _elite != null else 0.0
		)
		if id < 0:
			return
		var slot := _elite_n
		_elite_ids[slot] = id
		_elite_on[slot] = 1
		_elite_paid[slot] = 0
		_elite_finale[slot] = 1 if finale else 0
		_casters[slot].active = true
		_casters[slot].cooldown = EliteCaster.PERIOD
		_elite_n += 1
		if finale:
			_finale_left += 1
		i += 1


func _begin_boss() -> void:
	state = "finale"
	sim.squad.forward_speed = 0.0
	boss = BossFight.new()
	boss.clock = sim.clock
	boss.supply_add = level.add_gate_amount()
	var allow_summon := level.boss_summon
	boss.start(_boss_arch, sim.squad.position.z, level.boss_hp, true, allow_summon)
	sim.boss_fight = boss


func _tick_boss(step: float) -> void:
	if boss == null or boss.victorious:
		return
	var radius := SquadAnchor.formation_radius(sim.squad.count)
	boss.tick(step, sim.squad.position.x, sim.squad.position.z, sim.squad.count, radius, step)
	if boss.supply_pending:
		boss.supply_pending = false
		_launch_supply()
	if incoming_damage and not lock_headcount:
		_lose_soldiers(boss.take_squad_loss())
	else:
		boss.take_squad_loss()
	if boss.victorious:
		state = "win"
		_finish("win")


func _launch_supply() -> void:
	supply_active = true
	_supply_on[0] = 1
	_supply_on[1] = 1
	_supply_z[0] = boss.z - 3.0
	_supply_z[1] = boss.z - 3.0
	_supply_x[0] = -1.8
	_supply_x[1] = 1.8
	_supply_kind[0] = 0
	_supply_kind[1] = 1


func _tick_supply(step: float) -> void:
	if not supply_active:
		return
	var any := false
	var i := 0
	while i < 2:
		if _supply_on[i] == 0:
			i += 1
			continue
		any = true
		_supply_z[i] += SUPPLY_SPEED * step
		if _supply_z[i] >= sim.squad.position.z and absf(sim.squad.position.x - _supply_x[i]) <= 3.75:
			if _supply_kind[i] == 0:
				_add_soldiers(level.add_gate_amount())
			else:
				_weapon_plus()
			_supply_on[i] = 0
		elif _supply_z[i] > sim.squad.position.z + 2.0:
			_supply_on[i] = 0
		i += 1
	if not any:
		supply_active = false


func _tick_elites(step: float) -> void:
	var i := 0
	while i < _elite_n:
		if _elite_on[i] == 0:
			i += 1
			continue
		var id := _elite_ids[i]
		if sim.enemies.state[id] != EnemyPool.State.ALIVE:
			_elite_on[i] = 0
			_casters[i].active = false
			if _elite_finale[i] != 0:
				_finale_left = maxi(_finale_left - 1, 0)
			i += 1
			continue
		_casters[i].tick(step, sim.squad.position.x, sim.squad.count)
		if incoming_damage and not lock_headcount:
			_lose_soldiers(_casters[i].take_loss())
		else:
			_casters[i].take_loss()
		i += 1


func _contact_grunts() -> void:
	if not incoming_damage or lock_headcount:
		return
	var pool := sim.enemies
	var radius := SquadAnchor.formation_radius(sim.squad.count)
	var sx := sim.squad.position.x
	var sz := sim.squad.position.z
	var i := 0
	while i < pool.active_n:
		var id := pool.active_ids[i]
		i += 1
		if pool.state[id] != EnemyPool.State.ALIVE:
			continue
		if pool.archetype[id] != EnemyPool.Archetype.GRUNT:
			continue
		var dx := pool.x[id] - sx
		var dz := pool.z[id] - sz
		var reach := pool.radius[id] + radius
		if dx * dx + dz * dz > reach * reach:
			continue
		var weight := 1
		pool.hit(id, 99999.0, 0.0, 1.0)
		_lose_soldiers(weight)


func _pay_elite_coins() -> void:
	var i := 0
	while i < _elite_n:
		if _elite_paid[i] != 0:
			i += 1
			continue
		var id := _elite_ids[i]
		if sim.enemies.state[id] == EnemyPool.State.DYING or sim.enemies.state[id] == EnemyPool.State.FREE:
			if sim.enemies.hp[id] <= 0.0 or sim.enemies.state[id] == EnemyPool.State.DYING:
				_elite_paid[i] = 1
				run_coins += 20
		i += 1


func _trigger_gate(event: LevelEvent) -> void:
	if freeze_build:
		return
	var chosen: GateSpec = null
	var squad_x := sim.squad.position.x
	for gate in event.gates:
		if gate.side != "full" and gate.contains_x(squad_x):
			chosen = gate
			break
	if chosen == null:
		for gate in event.gates:
			if gate.side == "full":
				chosen = gate
				break
	if chosen == null:
		return
	match chosen.gate_type:
		"add":
			_add_soldiers(int(chosen.amount))
		"multiply":
			_set_count(sim.squad.count * int(chosen.amount))
		"subtract":
			_lose_soldiers(int(chosen.amount))
		"weapon":
			_weapon_plus()
		"fire_rate":
			sim.squad.rate_bonus += chosen.amount


func _add_soldiers(n: int) -> void:
	_set_count(sim.squad.count + n)


func _set_count(n: int) -> void:
	last_gate_capped = n > SQUAD_CAP
	sim.squad.count = clampi(n, 0, SQUAD_CAP)
	if lock_headcount:
		_locked_count = sim.squad.count


func _lose_soldiers(n: int) -> void:
	if n <= 0:
		return
	sim.squad.count = maxi(sim.squad.count - n, 0)


func _weapon_plus() -> void:
	weapon_level += 1
	if weapon_level == 2:
		var rifle := sim.squad.weapon.duplicate() as WeaponStats
		rifle.weapon_name = "步枪"
		rifle.damage = 12.0
		rifle.interval = 0.2
		sim.squad.weapon = rifle
		sim.squad.set_cooldown(0.0)
		return
	sim.squad.damage_bonus += 0.20


func _check_end() -> void:
	if state == "win" or state == "lose":
		return
	if sim.squad.count <= 0:
		sim.squad.count = 0
		_finish("lose")
		return
	if state == "finale" and boss == null and _finale_left <= 0 and _elite_n > 0:
		_finish("win")


func _finish(outcome: String) -> void:
	if result != null:
		return
	state = "win" if outcome == "win" else "lose"
	var hits := 0
	if boss != null:
		hits = boss.skill_hits
	else:
		var i := 0
		while i < _elite_n:
			if _elite_finale[i] != 0:
				hits += _casters[i].skill_hits
			i += 1
	result = RunResult.new()
	result.outcome = state
	result.level_index = level.level_index
	result.headcount = sim.squad.count
	result.finale_skill_hits = hits
	result.progress = 1.0 if state == "win" else progress_ratio()
	result.run_coins = run_coins
	result.base_clear_coins = level.base_clear_coins
	result.star2_headcount = level.star2_headcount
	result.first_clear_parts = level.first_clear_parts
	result.three_star_chest_coin_multiplier = level.three_star_chest_coin_multiplier
	result.three_star_chest_parts = level.three_star_chest_parts
	result.three_star_chest_paid_separately = level.three_star_chest_paid_separately
	result.fail_coin_ratio = level.fail_coin_ratio
	result.star_coin_multipliers = level.star_coin_multipliers
