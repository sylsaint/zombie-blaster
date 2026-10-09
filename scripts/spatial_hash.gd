class_name SpatialHash
extends RefCounted
## Uniform grid for bullet queries and separation. Cell size is about one body diameter.
## No Area3D, CharacterBody3D, or navigation.


var cell_size: float = 0.8
var _cells: Dictionary = {}
var _pos: Dictionary = {}


func _init(size: float = 0.8) -> void:
	cell_size = maxf(size, 0.05)


func clear() -> void:
	_cells.clear()
	_pos.clear()


func has_id(id: int) -> bool:
	return _pos.has(id)


func insert(id: int, px: float, pz: float, radius: float) -> void:
	remove(id)
	var key := _key(px, pz)
	if not _cells.has(key):
		_cells[key] = []
	(_cells[key] as Array).append(id)
	_pos[id] = Vector3(px, radius, pz)


func remove(id: int) -> void:
	if not _pos.has(id):
		return
	var p: Vector3 = _pos[id]
	var key := _key(p.x, p.z)
	if _cells.has(key):
		var bucket: Array = _cells[key]
		bucket.erase(id)
		if bucket.is_empty():
			_cells.erase(key)
	_pos.erase(id)


func move(id: int, px: float, pz: float) -> void:
	if not _pos.has(id):
		return
	var radius: float = (_pos[id] as Vector3).y
	var old_key := _key((_pos[id] as Vector3).x, (_pos[id] as Vector3).z)
	var new_key := _key(px, pz)
	_pos[id] = Vector3(px, radius, pz)
	if old_key == new_key:
		return
	if _cells.has(old_key):
		var bucket: Array = _cells[old_key]
		bucket.erase(id)
		if bucket.is_empty():
			_cells.erase(old_key)
	if not _cells.has(new_key):
		_cells[new_key] = []
	(_cells[new_key] as Array).append(id)


## Ids whose stored center is within search_radius, gathered from overlapped cells.
func query(px: float, pz: float, search_radius: float) -> PackedInt32Array:
	var result := PackedInt32Array()
	var reach := maxf(search_radius, 0.0)
	var min_x := _coord(px - reach)
	var max_x := _coord(px + reach)
	var min_z := _coord(pz - reach)
	var max_z := _coord(pz + reach)
	var reach_sq := reach * reach
	for cx in range(min_x, max_x + 1):
		for cz in range(min_z, max_z + 1):
			var key := Vector2i(cx, cz)
			if not _cells.has(key):
				continue
			var bucket: Array = _cells[key]
			for id in bucket:
				var p: Vector3 = _pos[id]
				var dx := p.x - px
				var dz := p.z - pz
				if dx * dx + dz * dz <= reach_sq:
					result.append(int(id))
	return result


func query_segment(x0: float, z0: float, x1: float, z1: float, search_radius: float) -> PackedInt32Array:
	var dx := x1 - x0
	var dz := z1 - z0
	var length := sqrt(dx * dx + dz * dz)
	var steps := maxi(1, int(ceil(length / cell_size)))
	var seen := {}
	var out := PackedInt32Array()
	for step in steps + 1:
		var t := float(step) / float(steps)
		var ids := query(lerpf(x0, x1, t), lerpf(z0, z1, t), search_radius)
		for id in ids:
			if seen.has(id):
				continue
			seen[id] = true
			out.append(id)
	return out


func _coord(v: float) -> int:
	return floori(v / cell_size)


func _key(px: float, pz: float) -> Vector2i:
	return Vector2i(_coord(px), _coord(pz))
