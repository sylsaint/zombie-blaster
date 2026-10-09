class_name XpDropPool
extends RefCounted
## Fixed gem pool. A full pool grants the XP immediately so a kill is never lost.
## Tick does not allocate.


const CAPACITY := 48
const LIFE := 8.0
const MAGNET := 6.0
const PULL := 14.0

var x := PackedFloat32Array()
var z := PackedFloat32Array()
var phase := PackedFloat32Array()
var life := PackedFloat32Array()
var value := PackedInt32Array()
var alive := PackedInt32Array()
var live_count: int = 0
var _free := PackedInt32Array()
var _free_n: int = 0


func _init(cap: int = CAPACITY) -> void:
	var n := maxi(cap, 1)
	x.resize(n)
	z.resize(n)
	phase.resize(n)
	life.resize(n)
	value.resize(n)
	alive.resize(n)
	_free.resize(n)
	_free_n = n
	for i in n:
		_free[i] = n - 1 - i


func capacity() -> int:
	return alive.size()


func try_spawn(px: float, pz: float, amount: int) -> bool:
	if amount <= 0 or _free_n <= 0:
		return false
	_free_n -= 1
	var id := _free[_free_n]
	alive[id] = 1
	x[id] = px
	z[id] = pz
	phase[id] = px * 3.1
	life[id] = LIFE
	value[id] = amount
	live_count += 1
	return true


## Pulls nearby gems into the squad and returns the XP they granted.
func tick(dt: float, sx: float, sz: float, collect_radius: float) -> int:
	if dt <= 0.0 or live_count <= 0:
		return 0
	var gained := 0
	var reach := maxf(collect_radius, 0.35)
	var reach2 := reach * reach
	var magnet2 := MAGNET * MAGNET
	var i := 0
	var n := alive.size()
	while i < n:
		if alive[i] == 0:
			i += 1
			continue
		life[i] -= dt
		phase[i] += dt * 5.0
		var dx := sx - x[i]
		var dz := sz - z[i]
		var dist2 := dx * dx + dz * dz
		if dist2 <= reach2 or life[i] <= 0.0:
			gained += value[i]
			_release(i)
			i += 1
			continue
		if dist2 <= magnet2 and dist2 > 0.0001:
			var inv := 1.0 / sqrt(dist2)
			var step := PULL * dt
			x[i] += dx * inv * step
			z[i] += dz * inv * step
		i += 1
	return gained


func _release(id: int) -> void:
	if alive[id] == 0:
		return
	alive[id] = 0
	live_count -= 1
	_free[_free_n] = id
	_free_n += 1
