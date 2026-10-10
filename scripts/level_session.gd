class_name LevelSession
extends RefCounted
## One run of a level resource: advance, finale, then a result event.
## Reward payout is left to the results screen.


const GRUNT_CAP := 250
const SPAWN_AHEAD := 35.0
const QUEUE_CAP := 32
const ELITE_SLOTS := 8
const SUPPLY_SPEED := 6.0
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
var _finale_skill_hits: int = 0
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
	sim.squad.weapon = WeaponCatalog.tier(1)
	sim.squad.set_cooldown(0.2)
	sim.separation_enabled = true
	_walker = EnemyCatalog.walker()
	_runner = EnemyCatalog.runner()
	_elite = EnemyCatalog.elite()
	_boss_arch = load("res://data/enemies/boss_mutant.tres") as EnemyArchetype
	_events = level.sorted_events()
	_done.resize(_events.size())
	_done.fill(0)
	_cursor = 0
	_q_n = 0
	_elite_n = 0
	_finale_left = 0
	_finale_skill_hits = 0
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
	var hurt := incoming_damage and not lock_headcount
	sim.contact_enabled = hurt
	sim.loss_enabled = hurt
	if boss != null:
		sim.boss_fight = boss
	sim.tick(step)
	if state == "finale" and boss == null:
		_finale_skill_hits += sim.warnings.impacts
	traveled = -sim.squad.position.z
	_trigger_events()
	_drain_queue()
	_tick_elites(step)
	_tick_boss(step)
	_tick_supply(step)
	run_coins = sim.gold
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


func _spawn_from(arch: EnemyArchetype, px: float, pz: float, hit_points: float, variant: float) -> int:
	if arch == null:
		return -1
	return sim.enemies.spawn(
		arch.kind,
		LaneMotion.clamp_body_x(px, LaneMotion.body_reach(arch.radius, arch.species)),
		pz,
		hit_points,
		arch.speed,
		arch.radius,
		variant,
		arch.species,
		arch.weight,
		arch.xp,
		arch.gold,
		1 if arch.grants_offer else 0,
		arch.near_speed,
		arch.near_distance,
		arch.touch_damage,
		arch.touch_period,
		arch.slam_interval,
		arch.warn_time
	)


func _spawn_grunts(kind: int, form: int, count: int) -> void:
	var arch := _runner if kind == 1 else _walker
	if arch == null:
		return
	var n := mini(count, _spawn_x.size())
	_fill_formation(n, form == 1, LaneMotion.body_reach(arch.radius, arch.species))
	var base_z := sim.squad.position.z - SPAWN_AHEAD
	var hp := arch.base_hp * level.hp_multiplier
	var i := 0
	while i < n:
		_spawn_from(arch, _spawn_x[i], base_z + _spawn_zoff[i], hp, arch.color_variant)
		i += 1


func _fill_formation(n: int, wedge: bool, radius: float) -> void:
	if n <= 0:
		return
	if n == 1:
		_spawn_x[0] = 0.0
		_spawn_zoff[0] = 0.0
		return
	var limit := LaneMotion.body_limit(radius)
	var span := minf(4.6, limit * 2.0)
	var i := 0
	while i < n:
		var t := float(i) / float(n - 1)
		_spawn_x[i] = LaneMotion.clamp_body_x(lerpf(-span * 0.5, span * 0.5, t), radius)
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
		var elite_radius := _elite.radius if _elite != null else EnemyPool.ELITE_RADIUS
		var elite_species := _elite.species if _elite != null else EnemyPool.Species.ELITE
		var px := LaneMotion.clamp_body_x(lerpf(-1.4, 1.4, t), LaneMotion.body_reach(elite_radius, elite_species))
		var id := _spawn_from(_elite, px, sim.squad.position.z - 10.0, level.elite_hp, _elite.color_variant if _elite != null else 0.85)
		if id < 0:
			return
		var slot := _elite_n
		_elite_ids[slot] = id
		_elite_on[slot] = 1
		_elite_paid[slot] = 0
		_elite_finale[slot] = 1 if finale else 0
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
				var added := GateRules.apply_add(sim.squad, level.add_gate_amount())
				last_gate_capped = added == "已满"
			else:
				GateRules.apply_weapon(sim.squad)
				sim.squad.set_cooldown(0.0)
				weapon_level = sim.squad.weapon_tier()
			_supply_on[i] = 0
		elif _supply_z[i] > sim.squad.position.z + 2.0:
			_supply_on[i] = 0
		i += 1
	if not any:
		supply_active = false


func _tick_elites(_step: float) -> void:
	var i := 0
	while i < _elite_n:
		if _elite_on[i] == 0:
			i += 1
			continue
		var id := _elite_ids[i]
		if sim.enemies.state[id] != EnemyPool.State.ALIVE:
			_elite_on[i] = 0
			if _elite_finale[i] != 0:
				_finale_left = maxi(_finale_left - 1, 0)
			i += 1
			continue
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
	var span := GateSpan.new()
	span.kind = chosen.kind
	span.amount = chosen.amount
	var label := GateRules.apply_span(sim.squad, span)
	last_gate_capped = label == "已满"
	if chosen.kind == GateRules.WEAPON:
		sim.squad.set_cooldown(0.0)
	weapon_level = sim.squad.weapon_tier()
	if lock_headcount:
		_locked_count = sim.squad.count


func _lose_soldiers(n: int) -> void:
	if n <= 0:
		return
	sim.squad.count = maxi(sim.squad.count - n, 0)


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
		hits = _finale_skill_hits
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
