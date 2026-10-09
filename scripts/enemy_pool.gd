class_name EnemyPool
extends RefCounted
## Packed enemy state. Slots are recycled; the arrays never grow after prewarm.


enum Archetype { GRUNT, ELITE, BOSS }
enum Species { WALKER, RUNNER, ELITE, BOSS }
enum State { FREE, ALIVE, DYING }

const FLASH_GRUNT := 0.060
const FLASH_ELITE := 0.080
const FLASH_BOSS := 0.050
const KNOCKBACK := 0.15
const DISSOLVE_TIME := 0.25
const GRUNT_RADIUS := 0.40
const ELITE_RADIUS := 1.20
const BOSS_RADIUS := 1.15
const MAX_BODY_RADIUS := 1.20

var capacity: int = 0
var x := PackedFloat32Array()
var z := PackedFloat32Array()
var radius := PackedFloat32Array()
var hp := PackedFloat32Array()
var hp_max := PackedFloat32Array()
var speed := PackedFloat32Array()
var archetype := PackedInt32Array()
var species := PackedInt32Array()
var state := PackedInt32Array()
var flash_left := PackedFloat32Array()
var dissolve_left := PackedFloat32Array()
var variant := PackedFloat32Array()
var vat_frame := PackedFloat32Array()
var weight := PackedInt32Array()
var xp_value := PackedInt32Array()
var gold := PackedInt32Array()
var grants_offer := PackedInt32Array()
var cruise_speed := PackedFloat32Array()
var near_speed := PackedFloat32Array()
var near_distance := PackedFloat32Array()
var touch_damage := PackedInt32Array()
var touch_period := PackedFloat32Array()
var contact_cd := PackedFloat32Array()
var slam_interval := PackedFloat32Array()
var warn_time := PackedFloat32Array()
var slam_timer := PackedFloat32Array()
var warning_slot := PackedInt32Array()
var active_count: int = 0
var kill_count: int = 0
var active_ids := PackedInt32Array()
var active_n: int = 0
var _active_index := PackedInt32Array()
var _kind_counts := PackedInt32Array()
var _species_counts := PackedInt32Array()
var _free: Array[int] = []


func _init(cap: int = 320) -> void:
	capacity = maxi(cap, 1)
	x.resize(capacity)
	z.resize(capacity)
	radius.resize(capacity)
	hp.resize(capacity)
	hp_max.resize(capacity)
	speed.resize(capacity)
	archetype.resize(capacity)
	species.resize(capacity)
	state.resize(capacity)
	flash_left.resize(capacity)
	dissolve_left.resize(capacity)
	variant.resize(capacity)
	vat_frame.resize(capacity)
	weight.resize(capacity)
	xp_value.resize(capacity)
	gold.resize(capacity)
	grants_offer.resize(capacity)
	cruise_speed.resize(capacity)
	near_speed.resize(capacity)
	near_distance.resize(capacity)
	touch_damage.resize(capacity)
	touch_period.resize(capacity)
	contact_cd.resize(capacity)
	slam_interval.resize(capacity)
	warn_time.resize(capacity)
	slam_timer.resize(capacity)
	warning_slot.resize(capacity)
	warning_slot.fill(-1)
	active_ids.resize(capacity)
	_active_index.resize(capacity)
	_active_index.fill(-1)
	_kind_counts.resize(3)
	_species_counts.resize(4)
	_free.resize(capacity)
	for i in capacity:
		state[i] = State.FREE
		_free[i] = capacity - 1 - i


func spawn(
	kind: int,
	px: float,
	pz: float,
	hit_points: float,
	move_speed: float,
	body_radius: float,
	color_variant: float,
	species_id: int = -1,
	body_weight: int = -1,
	xp_amount: int = -1,
	gold_amount: int = -1,
	grant_offer: int = -1,
	near_speed_v: float = -1.0,
	near_distance_v: float = -1.0,
	touch_damage_v: int = -1,
	touch_period_v: float = -1.0,
	slam_interval_v: float = -1.0,
	warn_time_v: float = -1.0
) -> int:
	if _free.is_empty():
		return -1
	var id: int = _free.pop_back()
	var sp := species_id
	if sp < 0:
		sp = _default_species(kind)
	x[id] = px
	z[id] = pz
	radius[id] = body_radius
	hp[id] = hit_points
	hp_max[id] = hit_points
	speed[id] = move_speed
	cruise_speed[id] = move_speed
	archetype[id] = kind
	species[id] = sp
	state[id] = State.ALIVE
	flash_left[id] = 0.0
	dissolve_left[id] = 0.0
	variant[id] = clampf(color_variant, 0.0, 1.0)
	vat_frame[id] = color_variant * 16.0
	weight[id] = body_weight if body_weight >= 0 else _default_weight(sp)
	xp_value[id] = xp_amount if xp_amount >= 0 else _default_xp(sp)
	gold[id] = gold_amount if gold_amount >= 0 else (20 if sp == Species.ELITE else 0)
	grants_offer[id] = grant_offer if grant_offer >= 0 else (1 if sp == Species.ELITE else 0)
	if near_distance_v >= 0.0:
		near_distance[id] = near_distance_v
		near_speed[id] = near_speed_v if near_speed_v >= 0.0 else 0.0
	elif sp == Species.ELITE:
		near_distance[id] = 10.0
		near_speed[id] = 0.6
	else:
		near_distance[id] = 0.0
		near_speed[id] = 0.0
	if touch_period_v >= 0.0:
		touch_period[id] = touch_period_v
		touch_damage[id] = touch_damage_v if touch_damage_v >= 0 else weight[id]
	elif sp == Species.ELITE:
		touch_period[id] = 0.5
		touch_damage[id] = 2
	else:
		touch_period[id] = 0.0
		touch_damage[id] = weight[id]
	if slam_interval_v >= 0.0:
		slam_interval[id] = slam_interval_v
		warn_time[id] = warn_time_v if warn_time_v >= 0.0 else 0.0
	elif sp == Species.ELITE:
		slam_interval[id] = 4.0
		warn_time[id] = 1.0
	else:
		slam_interval[id] = 0.0
		warn_time[id] = 0.0
	contact_cd[id] = 0.0
	slam_timer[id] = 0.0
	warning_slot[id] = -1
	active_ids[active_n] = id
	_active_index[id] = active_n
	active_n += 1
	active_count += 1
	_kind_counts[kind] += 1
	_species_counts[sp] += 1
	return id


func recycle(id: int) -> void:
	if id < 0 or id >= capacity:
		return
	if state[id] == State.FREE:
		return
	var kind := archetype[id]
	var sp := species[id]
	state[id] = State.FREE
	active_count -= 1
	_kind_counts[kind] -= 1
	_species_counts[sp] -= 1
	var li := _active_index[id]
	var last := active_n - 1
	var moved := active_ids[last]
	active_ids[li] = moved
	_active_index[moved] = li
	_active_index[id] = -1
	active_n = last
	_free.append(id)


## Applies damage, flash, and knockback. Returns true when this hit starts death.
func hit(id: int, amount: float, dir_x: float, dir_z: float) -> bool:
	if id < 0 or id >= capacity:
		return false
	if state[id] != State.ALIVE:
		return false
	hp[id] -= amount
	flash_left[id] = flash_duration(archetype[id])
	var len := sqrt(dir_x * dir_x + dir_z * dir_z)
	if len < 0.0001:
		dir_x = 0.0
		dir_z = -1.0
		len = 1.0
	x[id] += dir_x / len * KNOCKBACK
	z[id] += dir_z / len * KNOCKBACK
	if hp[id] > 0.0:
		return false
	hp[id] = 0.0
	state[id] = State.DYING
	dissolve_left[id] = DISSOLVE_TIME
	kill_count += 1
	return true


## Contact kills skip knockback. Returns true only on the transition into death.
func kill(id: int) -> bool:
	if id < 0 or id >= capacity:
		return false
	if state[id] != State.ALIVE:
		return false
	hp[id] = 0.0
	state[id] = State.DYING
	dissolve_left[id] = DISSOLVE_TIME
	flash_left[id] = flash_duration(archetype[id])
	kill_count += 1
	return true


func tick_timers(dt: float) -> void:
	var step := maxf(dt, 0.0)
	var flashes := flash_left
	var frames := vat_frame
	var dissolves := dissolve_left
	var states := state
	var i := 0
	while i < active_n:
		var id := active_ids[i]
		if flashes[id] > 0.0:
			flashes[id] = maxf(0.0, flashes[id] - step)
		frames[id] += step * 8.0
		if states[id] == State.DYING:
			dissolves[id] -= step
			if dissolves[id] <= 0.0:
				recycle(id)
				continue
		i += 1


func flash_amount(id: int) -> float:
	if flash_left[id] > 0.0:
		return 1.0
	return 0.0


func dissolve_amount(id: int) -> float:
	if state[id] != State.DYING:
		return 0.0
	return clampf(1.0 - dissolve_left[id] / DISSOLVE_TIME, 0.0, 1.0)


static func flash_duration(kind: int) -> float:
	if kind == Archetype.ELITE:
		return FLASH_ELITE
	if kind == Archetype.BOSS:
		return FLASH_BOSS
	return FLASH_GRUNT


func count_kind(kind: int) -> int:
	if kind < 0 or kind >= _kind_counts.size():
		return 0
	return _kind_counts[kind]


func count_species(sp: int) -> int:
	if sp < 0 or sp >= _species_counts.size():
		return 0
	return _species_counts[sp]


func _default_species(kind: int) -> int:
	if kind == Archetype.ELITE:
		return Species.ELITE
	if kind == Archetype.BOSS:
		return Species.BOSS
	return Species.WALKER


func _default_weight(sp: int) -> int:
	if sp == Species.ELITE:
		return 2
	if sp == Species.BOSS:
		return 0
	return 1


func _default_xp(sp: int) -> int:
	if sp == Species.WALKER or sp == Species.RUNNER:
		return 1
	return 0
