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
	active_count += 1
	return id


func recycle(id: int) -> void:
	if id < 0 or id >= capacity:
		return
	if state[id] == State.FREE:
		return
	state[id] = State.FREE
	active_count -= 1
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
	for i in capacity:
		if state[i] == State.FREE:
			continue
		if flash_left[i] > 0.0:
			flash_left[i] = maxf(0.0, flash_left[i] - step)
		vat_frame[i] += step * 8.0
		if state[i] == State.DYING:
			dissolve_left[i] -= step
			if dissolve_left[i] <= 0.0:
				recycle(i)


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
	var n := 0
	for i in capacity:
		if state[i] != State.FREE and archetype[i] == kind:
			n += 1
	return n
