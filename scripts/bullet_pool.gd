class_name BulletPool
extends RefCounted
## Fixed packed-array bullet pool. Combat never resizes it.


const DEFAULT_CAPACITY := 64
const FLAG_SPLIT := 1

var capacity: int = DEFAULT_CAPACITY
var x := PackedFloat32Array()
var z := PackedFloat32Array()
var prev_x := PackedFloat32Array()
var prev_z := PackedFloat32Array()
var vx := PackedFloat32Array()
var vz := PackedFloat32Array()
var damage := PackedFloat32Array()
var traveled := PackedFloat32Array()
var max_range := PackedFloat32Array()
var pierce := PackedInt32Array()
var last_hit := PackedInt32Array()
var flags := PackedInt32Array()
var alive := PackedInt32Array()
var retire := PackedInt32Array()
var live_count: int = 0


func _init(cap: int = DEFAULT_CAPACITY) -> void:
	capacity = maxi(cap, 1)
	x.resize(capacity)
	z.resize(capacity)
	prev_x.resize(capacity)
	prev_z.resize(capacity)
	vx.resize(capacity)
	vz.resize(capacity)
	damage.resize(capacity)
	traveled.resize(capacity)
	max_range.resize(capacity)
	pierce.resize(capacity)
	last_hit.resize(capacity)
	flags.resize(capacity)
	alive.resize(capacity)
	retire.resize(capacity)
	for i in capacity:
		last_hit[i] = -1


func try_spawn(ox: float, oz: float, vel_x: float, vel_z: float, dmg: float, pierce_left: int, range_m: float, bullet_flags: int = 0) -> int:
	for i in capacity:
		if alive[i] == 0:
			alive[i] = 1
			retire[i] = 0
			x[i] = ox
			z[i] = oz
			prev_x[i] = ox
			prev_z[i] = oz
			vx[i] = vel_x
			vz[i] = vel_z
			damage[i] = dmg
			traveled[i] = 0.0
			max_range[i] = range_m
			pierce[i] = pierce_left
			last_hit[i] = -1
			flags[i] = bullet_flags
			live_count += 1
			return i
	return -1


func is_alive(index: int) -> bool:
	return index >= 0 and index < capacity and alive[index] != 0


func integrate(dt: float) -> void:
	var step := maxf(dt, 0.0)
	for i in capacity:
		retire[i] = 0
		if alive[i] == 0:
			continue
		prev_x[i] = x[i]
		prev_z[i] = z[i]
		var dx := vx[i] * step
		var dz := vz[i] * step
		x[i] += dx
		z[i] += dz
		traveled[i] += sqrt(dx * dx + dz * dz)
		if traveled[i] >= max_range[i]:
			var speed := sqrt(vx[i] * vx[i] + vz[i] * vz[i])
			var over := traveled[i] - max_range[i]
			if speed > 0.0001 and over > 0.0:
				var back := over / speed
				x[i] -= vx[i] * back
				z[i] -= vz[i] * back
			traveled[i] = max_range[i]
			retire[i] = 1


func deactivate(index: int) -> void:
	if index < 0 or index >= capacity:
		return
	if alive[index] == 0:
		return
	alive[index] = 0
	retire[index] = 0
	live_count -= 1


func flush_retired() -> void:
	for i in capacity:
		if alive[i] != 0 and retire[i] != 0:
			deactivate(i)
