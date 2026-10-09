class_name SaveStore
extends RefCounted
## Versioned profile under user://. A corrupt or older file returns a
## profile the game can boot; it never raises.


const VERSION := 1
const DEFAULT_PATH := "user://save.json"

var path: String = DEFAULT_PATH


func load_profile() -> PlayerProfile:
	var profile := PlayerProfile.new()
	if path.is_empty() or not FileAccess.file_exists(path):
		return profile
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return profile
	var text := file.get_as_text()
	file.close()
	return profile_from_text(text)


func save(profile: PlayerProfile) -> bool:
	if profile == null or path.is_empty():
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(to_dict(profile), "\t"))
	file.close()
	return true


func profile_from_text(text: String) -> PlayerProfile:
	var profile := PlayerProfile.new()
	if text.is_empty():
		return profile
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return profile
	return profile_from_dict(parsed)


func profile_from_dict(data: Dictionary) -> PlayerProfile:
	var profile := PlayerProfile.new()
	# Missing or older version still maps onto the fields we know.
	var _version := _as_int(data.get("version", 0), 0)
	profile.coins = maxi(_as_int(_first(data, ["coins", "gold"], 0), 0), 0)
	profile.parts = maxi(_as_int(_first(data, ["parts", "weapon_parts"], 0), 0), 0)
	profile.attack_level = clampi(
		_as_int(_first(data, ["attack_level", "attack"], 0), 0),
		0,
		WeaponMods.META_ATTACK_CAP
	)
	profile.unlocked_through = maxi(_as_int(_first(data, ["unlocked_through", "progress"], 1), 1), 1)
	_read_flags(_first(data, ["first_clear", "cleared"], []), profile, true)
	_read_flags(_first(data, ["three_star", "three_star_chest"], []), profile, false)
	return profile


func to_dict(profile: PlayerProfile) -> Dictionary:
	return {
		"version": VERSION,
		"coins": profile.coins,
		"parts": profile.parts,
		"attack_level": profile.attack_level,
		"unlocked_through": profile.unlocked_through,
		"first_clear": _flag_array(profile.first_clear),
		"three_star": _flag_array(profile.three_star),
	}


func _flag_array(flags: Array[bool]) -> Array:
	var out: Array = []
	for flag in flags:
		out.append(flag)
	return out


func _read_flags(value: Variant, profile: PlayerProfile, first_clear: bool) -> void:
	if typeof(value) == TYPE_ARRAY:
		var row: Array = value
		var i := 0
		while i < row.size():
			_write_flag(profile, i + 1, _as_bool(row[i]), first_clear)
			i += 1
		return
	if typeof(value) != TYPE_DICTIONARY:
		return
	var row_dict: Dictionary = value
	for key in row_dict.keys():
		var index := _as_int(key, -1)
		if index >= 1:
			_write_flag(profile, index, _as_bool(row_dict[key]), first_clear)


func _write_flag(profile: PlayerProfile, level_index: int, on: bool, first_clear: bool) -> void:
	if not on:
		profile._pad(level_index)
		return
	if first_clear:
		profile.mark_first_clear(level_index)
	else:
		profile.mark_three_star(level_index)


func _first(data: Dictionary, keys: Array, fallback: Variant) -> Variant:
	for key in keys:
		if data.has(key):
			return data[key]
	return fallback


func _as_int(value: Variant, fallback: int) -> int:
	match typeof(value):
		TYPE_INT:
			return int(value)
		TYPE_FLOAT:
			if is_nan(float(value)) or is_inf(float(value)):
				return fallback
			return int(value)
		TYPE_STRING:
			var text := str(value).strip_edges()
			if text.is_valid_int():
				return text.to_int()
			return fallback
		_:
			return fallback


func _as_bool(value: Variant) -> bool:
	match typeof(value):
		TYPE_BOOL:
			return bool(value)
		TYPE_INT, TYPE_FLOAT:
			return float(value) != 0.0
		TYPE_STRING:
			var text := str(value).strip_edges().to_lower()
			return text == "true" or text == "1"
		_:
			return false
