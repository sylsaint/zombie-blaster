class_name SpatialHash
extends RefCounted
## Uniform grid for bullet queries and separation. Cell size is about one body diameter.
## Buckets are a fixed packed table: rebuilds and queries do not allocate.


const BUCKETS := 2048
const BUCKET_MASK := 2047

var cell_size: float = 0.8
var profile: SimProfile

var _generation: int = 1
var _head := PackedInt32Array()
var _stamp := PackedInt32Array()
var _next := PackedInt32Array()
var _px := PackedFloat32Array()
var _pz := PackedFloat32Array()
var _radius := PackedFloat32Array()
var _cx := PackedInt32Array()
var _cz := PackedInt32Array()
var _occ := PackedInt32Array()
var _live := PackedInt32Array()
var _live_index := PackedInt32Array()
var _live_n: int = 0
var _id_cap: int = 0
var _scratch := PackedInt32Array()
var _scratch_n: int = 0
var _seen := PackedInt32Array()
var _seen_gen: int = 1

const GW := 32
const GH := 96
const MAXC := 16

var _wcount := PackedInt32Array()
var _wslots := PackedInt32Array()
var _wtouched := PackedInt32Array()
var _wtouched_n: int = 0
var _wloc := PackedInt32Array()
var _wox: float = -12.0
var _woz: float = 0.0
var _window_on: bool = false


func _init(size: float = 0.8) -> void:
	cell_size = maxf(size, 0.05)
	_head.resize(BUCKETS)
	_stamp.resize(BUCKETS)
	_head.fill(-1)
	_grow_ids(31)
	_wcount.resize(GW * GH)
	_wslots.resize(GW * GH * MAXC)
	_wtouched.resize(GW * GH)
	_wloc.resize(512)
	_wloc.fill(-1)


func clear() -> void:
	_generation += 1
	if _generation >= 2147483647:
		_generation = 1
		_stamp.fill(0)
	for i in _live_n:
		var id := _live[i]
		_occ[id] = 0
		_live_index[id] = -1
	_live_n = 0


func has_id(id: int) -> bool:
	return id >= 0 and id < _id_cap and _occ[id] != 0


func insert(id: int, px: float, pz: float, radius: float) -> void:
	if id < 0:
		return
	remove(id)
	_grow_ids(id)
	var cx := _coord(px)
	var cz := _coord(pz)
	_px[id] = px
	_pz[id] = pz
	_radius[id] = radius
	_cx[id] = cx
	_cz[id] = cz
	_link(id, cx, cz)
	_occ[id] = 1
	_live[_live_n] = id
	_live_index[id] = _live_n
	_live_n += 1


func remove(id: int) -> void:
	if not has_id(id):
		return
	_unlink(id)
	_occ[id] = 0
	var li := _live_index[id]
	var last := _live_n - 1
	var moved := _live[last]
	_live[li] = moved
	_live_index[moved] = li
	_live_index[id] = -1
	_live_n = last


func move(id: int, px: float, pz: float) -> void:
	if not has_id(id):
		return
	var cx := _coord(px)
	var cz := _coord(pz)
	_px[id] = px
	_pz[id] = pz
	if cx == _cx[id] and cz == _cz[id]:
		return
	_unlink(id)
	_cx[id] = cx
	_cz[id] = cz
	_link(id, cx, cz)


## Ids whose stored center is within search_radius. The returned array is a copy.
func query(px: float, pz: float, search_radius: float) -> PackedInt32Array:
	collect_circle(px, pz, search_radius)
	return _copy_scratch()


func query_segment(x0: float, z0: float, x1: float, z1: float, search_radius: float) -> PackedInt32Array:
	collect_segment(x0, z0, x1, z1, search_radius)
	return _copy_scratch()


func collect_circle(px: float, pz: float, search_radius: float) -> int:
	var t0 := 0
	if profile != null:
		t0 = Time.get_ticks_usec()
	_scratch_n = 0
	_visit_circle(px, pz, search_radius, false)
	if profile != null:
		profile.hash_query_us += int(Time.get_ticks_usec() - t0)
	return _scratch_n


func collect_segment(x0: float, z0: float, x1: float, z1: float, search_radius: float) -> int:
	var t0 := 0
	if profile != null:
		t0 = Time.get_ticks_usec()
	_scratch_n = 0
	_seen_gen += 1
	if _seen_gen >= 2147483647:
		_seen_gen = 1
		_seen.fill(0)
	var dx := x1 - x0
	var dz := z1 - z0
	var length := sqrt(dx * dx + dz * dz)
	var steps := maxi(1, int(ceil(length / cell_size)))
	var step := 0
	while step <= steps:
		var t := float(step) / float(steps)
		_visit_circle(lerpf(x0, x1, t), lerpf(z0, z1, t), search_radius, true)
		step += 1
	if profile != null:
		profile.hash_query_us += int(Time.get_ticks_usec() - t0)
	return _scratch_n


func scratch_id(index: int) -> int:
	return _scratch[index]


func _copy_scratch() -> PackedInt32Array:
	var out := PackedInt32Array()
	out.resize(_scratch_n)
	var i := 0
	while i < _scratch_n:
		out[i] = _scratch[i]
		i += 1
	return out


func _visit_circle(px: float, pz: float, search_radius: float, unique: bool) -> void:
	var reach := maxf(search_radius, 0.0)
	var min_x := _coord(px - reach)
	var max_x := _coord(px + reach)
	var min_z := _coord(pz - reach)
	var max_z := _coord(pz + reach)
	var reach_sq := reach * reach
	var cx := min_x
	while cx <= max_x:
		var cz := min_z
		while cz <= max_z:
			var b := _bucket(cx, cz)
			if _stamp[b] == _generation:
				var cur := _head[b]
				while cur != -1:
					if _cx[cur] == cx and _cz[cur] == cz:
						var dx := _px[cur] - px
						var dz := _pz[cur] - pz
						if dx * dx + dz * dz <= reach_sq:
							_push_scratch(cur, unique)
					cur = _next[cur]
			cz += 1
		cx += 1


func _push_scratch(id: int, unique: bool) -> void:
	if unique:
		if id >= _seen.size():
			_seen.resize(id + 16)
		if _seen[id] == _seen_gen:
			return
		_seen[id] = _seen_gen
	if _scratch_n >= _scratch.size():
		_scratch.resize(_scratch_n + 16)
	_scratch[_scratch_n] = id
	_scratch_n += 1


func _link(id: int, cx: int, cz: int) -> void:
	var b := _bucket(cx, cz)
	if _stamp[b] != _generation:
		_head[b] = -1
		_stamp[b] = _generation
	_next[id] = _head[b]
	_head[b] = id


func _unlink(id: int) -> void:
	var b := _bucket(_cx[id], _cz[id])
	if _stamp[b] != _generation:
		return
	var prev := -1
	var cur := _head[b]
	while cur != -1:
		if cur == id:
			if prev == -1:
				_head[b] = _next[cur]
			else:
				_next[prev] = _next[cur]
			return
		prev = cur
		cur = _next[cur]


func _grow_ids(id: int) -> void:
	if id < _id_cap:
		return
	var n := maxi(_id_cap, 32)
	while n <= id:
		n *= 2
	var old := _id_cap
	_next.resize(n)
	_px.resize(n)
	_pz.resize(n)
	_radius.resize(n)
	_cx.resize(n)
	_cz.resize(n)
	_occ.resize(n)
	_live.resize(n)
	_live_index.resize(n)
	var i := old
	while i < n:
		_live_index[i] = -1
		_next[i] = -1
		i += 1
	_id_cap = n


func _coord(v: float) -> int:
	return floori(v / cell_size)


func _bucket(cx: int, cz: int) -> int:
	return (cx * 73856093 ^ cz * 19349663) & BUCKET_MASK


## Dense window used by the crowd. Origin is world-space; cells outside the window are ignored.
func rebuild_window(origin_x: float, origin_z: float, ids: PackedInt32Array, count: int, xs: PackedFloat32Array, zs: PackedFloat32Array, _radii: PackedFloat32Array, states: PackedInt32Array, alive_state: int) -> void:
	_wox = origin_x
	_woz = origin_z
	var t := 0
	while t < _wtouched_n:
		_wcount[_wtouched[t]] = 0
		t += 1
	_wtouched_n = 0
	var a := 0
	while a < count:
		var id := ids[a]
		a += 1
		if states[id] != alive_state:
			continue
		if id >= _wloc.size():
			var old_n := _wloc.size()
			_wloc.resize(id + 64)
			var fill_i := old_n
			while fill_i < _wloc.size():
				_wloc[fill_i] = -1
				fill_i += 1
		var c := _windex(xs[id], zs[id])
		_wloc[id] = c
		if c < 0:
			continue
		var k := _wcount[c]
		if k == 0:
			_wtouched[_wtouched_n] = c
			_wtouched_n += 1
		if k < MAXC:
			_wslots[c * MAXC + k] = id
			_wcount[c] = k + 1
	_window_on = true


func separate_window(xs: PackedFloat32Array, zs: PackedFloat32Array, rad: PackedFloat32Array, states: PackedInt32Array, ids: PackedInt32Array, count: int, alive_state: int) -> void:
	if not _window_on:
		return
	var a := 0
	while a < count:
		var i := ids[a]
		a += 1
		if states[i] != alive_state:
			continue
		var c := _windex(xs[i], zs[i])
		if c < 0:
			continue
		var cx := c % GW
		var cz := int(c / GW)
		var checks := 0
		var oz := cz - 1
		while oz <= cz + 1 and checks <= 8:
			var ox := cx - 1
			while ox <= cx + 1 and checks <= 8:
				if ox >= 0 and oz >= 0 and ox < GW and oz < GH:
					var nc := ox + oz * GW
					var cnt := _wcount[nc]
					var base := nc * MAXC
					var k := 0
					while k < cnt and checks <= 8:
						var other := _wslots[base + k]
						k += 1
						if other == i or states[other] != alive_state:
							continue
						checks += 1
						if checks > 8:
							break
						var dx := xs[i] - xs[other]
						var dz := zs[i] - zs[other]
						var dist := sqrt(dx * dx + dz * dz)
						var min_d := rad[i] + rad[other]
						if dist >= min_d:
							continue
						if dist <= 0.0001:
							xs[i] += 0.02
							continue
						var push := (min_d - dist) * 0.5
						xs[i] += dx / dist * push
						zs[i] += dz / dist * push
				ox += 1
			oz += 1


func collect_segment_window(x0: float, z0: float, x1: float, z1: float, search_radius: float) -> int:
	var t0 := 0
	if profile != null:
		t0 = Time.get_ticks_usec()
	_scratch_n = 0
	if not _window_on:
		if profile != null:
			profile.hash_query_us += int(Time.get_ticks_usec() - t0)
		return 0
	_seen_gen += 1
	if _seen_gen >= 2147483647:
		_seen_gen = 1
		_seen.fill(0)
	var dx := x1 - x0
	var dz := z1 - z0
	var length := sqrt(dx * dx + dz * dz)
	var steps := maxi(1, int(ceil(length / cell_size)))
	var step := 0
	while step <= steps:
		var t := float(step) / float(steps)
		_visit_window(lerpf(x0, x1, t), lerpf(z0, z1, t), search_radius)
		step += 1
	if profile != null:
		profile.hash_query_us += int(Time.get_ticks_usec() - t0)
	return _scratch_n


func note_move_window(id: int, px: float, pz: float) -> void:
	if not _window_on or id < 0 or id >= _wloc.size():
		return
	var old := _wloc[id]
	var new_c := _windex(px, pz)
	if old == new_c:
		return
	if old >= 0:
		var cnt := _wcount[old]
		var base := old * MAXC
		var k := 0
		while k < cnt:
			if _wslots[base + k] == id:
				var last := cnt - 1
				_wslots[base + k] = _wslots[base + last]
				_wcount[old] = last
				break
			k += 1
	_wloc[id] = new_c
	if new_c < 0:
		return
	var k2 := _wcount[new_c]
	if k2 == 0:
		_wtouched[_wtouched_n] = new_c
		_wtouched_n += 1
	if k2 < MAXC:
		_wslots[new_c * MAXC + k2] = id
		_wcount[new_c] = k2 + 1


func _windex(px: float, pz: float) -> int:
	var cx := floori((px - _wox) / cell_size)
	var cz := floori((pz - _woz) / cell_size)
	if cx < 0 or cz < 0 or cx >= GW or cz >= GH:
		return -1
	return cx + cz * GW


func _visit_window(px: float, pz: float, search_radius: float) -> void:
	var reach := maxf(search_radius, 0.0)
	var min_x := floori((px - reach - _wox) / cell_size)
	var max_x := floori((px + reach - _wox) / cell_size)
	var min_z := floori((pz - reach - _woz) / cell_size)
	var max_z := floori((pz + reach - _woz) / cell_size)
	if min_x < 0:
		min_x = 0
	if min_z < 0:
		min_z = 0
	if max_x >= GW:
		max_x = GW - 1
	if max_z >= GH:
		max_z = GH - 1
	var cx := min_x
	while cx <= max_x:
		var cz := min_z
		while cz <= max_z:
			var c := cx + cz * GW
			var cnt := _wcount[c]
			var base := c * MAXC
			var k := 0
			while k < cnt:
				_push_scratch(_wslots[base + k], true)
				k += 1
			cz += 1
		cx += 1
