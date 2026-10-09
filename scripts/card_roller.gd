class_name CardRoller
extends RefCounted
## Seeded draw of three distinct cards. The first offer includes a core card.


var rng := RandomNumberGenerator.new()


func set_seed(seed_value: int) -> void:
	rng.seed = seed_value


func roll(loadout: SkillLoadout, first_offer: bool) -> PackedInt32Array:
	var avail := PackedInt32Array()
	var i := 0
	while i < SkillLoadout.COUNT:
		if not loadout.is_maxed(i):
			avail.append(i)
		i += 1
	var result := PackedInt32Array()
	if avail.is_empty():
		return result
	if first_offer:
		var cores := PackedInt32Array()
		for id in avail:
			if loadout.is_core(id):
				cores.append(id)
		if not cores.is_empty():
			var pick: int = cores[rng.randi() % cores.size()]
			result.append(pick)
			_erase(avail, pick)
	while result.size() < 3 and not avail.is_empty():
		var idx := rng.randi() % avail.size()
		result.append(avail[idx])
		_erase_at(avail, idx)
	return result


func _erase(ids: PackedInt32Array, value: int) -> void:
	var i := 0
	while i < ids.size():
		if ids[i] == value:
			_erase_at(ids, i)
			return
		i += 1


func _erase_at(ids: PackedInt32Array, index: int) -> void:
	var last := ids.size() - 1
	ids[index] = ids[last]
	ids.resize(last)
