class_name EnemyPool
extends RefCounted
## Packed enemy state. Slots are recycled; the arrays never grow after prewarm.


enum Archetype { GRUNT, ELITE, BOSS }
enum State { FREE, ALIVE, DYING }

const FLASH_GRUNT := 0.060
const FLASH_ELITE := 0.080
const FLASH_BOSS := 0.050
const KNOCKBACK := 0.15
const DISSOLVE_TIME := 0.25
const GRUNT_RADIUS := 0.40
const ELITE_RADIUS := 0.70
const BOSS_RADIUS := 1.15
const MAX_BODY_RADIUS := 1.15

var capacity: int = 0
var x := PackedFloat32Array()
var z := PackedFloat32Array()
var radius := PackedFloat32Array()
var hp := PackedFloat32Array()
var hp_max := PackedFloat32Array()
var speed := PackedFloat32Array()
var archetype := PackedInt32Array()
var state := PackedInt32Array()
var flash_left := PackedFloat32Array()
var dissolve_left := PackedFloat32Array()
var variant := PackedFloat32Array()
var vat_frame := PackedFloat32Array()
var active_count: int = 0
var active_ids := PackedInt32Array()
var active_n: int = 0
var _active_index := PackedInt32Array()
var _kind_counts := PackedInt32Array()
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
	state.resize(capacity)
	flash_left.resize(capacity)
	dissolve_left.resize(capacity)
	variant.resize(capacity)
	vat_frame.resize(capacity)
	active_ids.resize(capacity)
	_active_index.resize(capacity)
	_active_index.fill(-1)
	_kind_counts.resize(3)
	_free.resize(capacity)
	for i in capacity:
		state[i] = State.FREE
		_free[i] = capacity - 1 - i


func spawn(kind: int, px: float, pz: float, hit_points: float, move_speed: float, body_radius: float, color_variant: float) -> int:
	if _free.is_empty():
		return -1
	var id: int = _free.pop_back()
	x[id] = px
	z[id] = pz
	radius[id] = body_radius
	hp[id] = hit_points
	hp_max[id] = hit_points
	speed[id] = move_speed
	archetype[id] = kind
	state[id] = State.ALIVE
	flash_left[id] = 0.0
	dissolve_left[id] = 0.0
	variant[id] = clampf(color_variant, 0.0, 1.0)
	vat_frame[id] = color_variant * 16.0
	active_ids[active_n] = id
	_active_index[id] = active_n
	active_n += 1
	active_count += 1
	_kind_counts[kind] += 1
	return id


func recycle(id: int) -> void:
	if id < 0 or id >= capacity:
		return
	if state[id] == State.FREE:
		return
	var kind := archetype[id]
	state[id] = State.FREE
	active_count -= 1
	_kind_counts[kind] -= 1
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
