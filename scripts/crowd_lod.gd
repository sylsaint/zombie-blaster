class_name CrowdLod
extends RefCounted
## Nearest HIGH_BUDGET grunts use the high mesh. Everyone else uses the low mesh.
## Elites and the boss are not part of this budget; they have their own meshes.


const HIGH_BUDGET := 100

var capacity: int = 0
var _dist := PackedFloat32Array()
var _order := PackedInt32Array()
var _high := PackedInt32Array()


func _init(cap: int = 320) -> void:
	capacity = maxi(cap, 1)
	_dist.resize(capacity)
	_order.resize(capacity)
	_high.resize(capacity)


func classify(ids: PackedInt32Array, active_n: int, species: PackedInt32Array, states: PackedInt32Array, xs: PackedFloat32Array, zs: PackedFloat32Array, squad_x: float, squad_z: float) -> void:
	_high.fill(0)
	var n := 0
	var a := 0
	while a < active_n:
		var id := ids[a]
		a += 1
		if id < 0 or id >= capacity:
			continue
		if states[id] == EnemyPool.State.FREE:
			continue
		var sp := species[id]
		if sp != EnemyPool.Species.WALKER and sp != EnemyPool.Species.RUNNER:
			continue
		var dx := xs[id] - squad_x
		var dz := zs[id] - squad_z
		_dist[n] = dx * dx + dz * dz
		_order[n] = id
		n += 1
		if n >= capacity:
			break
	var keep := mini(HIGH_BUDGET, n)
	_select_nearest(n, keep)
	var i := 0
	while i < keep:
		_high[_order[i]] = 1
		i += 1


func is_high(id: int) -> bool:
	if id < 0 or id >= capacity:
		return false
	return _high[id] != 0


func _select_nearest(n: int, keep: int) -> void:
	if keep <= 0 or keep >= n:
		return
	var i := 0
	while i < keep:
		var best := i
		var j := i + 1
		while j < n:
			if _dist[j] < _dist[best]:
				best = j
			j += 1
		_swap(i, best)
		i += 1


func _swap(a: int, b: int) -> void:
	if a == b:
		return
	var dist := _dist[a]
	_dist[a] = _dist[b]
	_dist[b] = dist
	var id := _order[a]
	_order[a] = _order[b]
	_order[b] = id
