class_name SaveStore
extends RefCounted
## Versioned profile under user://.
##
## A good write lands in save.json.tmp, the previous good file moves to
## save.json.bak, then the temp file takes the real name. A crash can leave
## the temp file behind; the next load ignores it. An empty, truncated, or
## invalid save falls back to the backup, or to a new profile, and never
## copies the bad bytes onto that backup. An older version is migrated on
## the next good write. A newer version is left on disk untouched.


const VERSION := 1
const DEFAULT_PATH := "user://save.json"
const TMP_SUFFIX := ".tmp"
const BAK_SUFFIX := ".bak"

var path: String = DEFAULT_PATH
## A newer file is on disk. save() must not replace it or its backup.
var preserve_file: bool = false


func load_profile() -> PlayerProfile:
	preserve_file = false
	if path.is_empty():
		return PlayerProfile.new()
	if FileAccess.file_exists(path):
		var parsed := _parse(_read(path))
		if parsed["ok"]:
			if int(parsed["version"]) > VERSION:
				preserve_file = true
				return PlayerProfile.new()
			return profile_from_dict(parsed["data"])
		return _load_backup_or_fresh()
	return _load_backup_or_fresh()


func save(profile: PlayerProfile) -> bool:
	if profile == null or path.is_empty() or preserve_file:
		return false
	var payload := JSON.stringify(to_dict(profile), "\t")
	var tmp := path + TMP_SUFFIX
	var file := FileAccess.open(tmp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(payload)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		return false
	if FileAccess.file_exists(path):
		var current := _parse(_read(path))
		if current["ok"] and int(current["version"]) <= VERSION:
			if _rename(path, path + BAK_SUFFIX) != OK:
				return false
		elif _remove(path) != OK:
			return false
	if _rename(tmp, path) != OK:
		return false
	return true


func profile_from_text(text: String) -> PlayerProfile:
	var parsed := _parse(text)
	if not parsed["ok"] or int(parsed["version"]) > VERSION:
		return PlayerProfile.new()
	return profile_from_dict(parsed["data"])


func profile_from_dict(data: Dictionary) -> PlayerProfile:
	var profile := PlayerProfile.new()
	# Older versions reuse the same fields, including the earlier key names.
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


func _load_backup_or_fresh() -> PlayerProfile:
	var bak := path + BAK_SUFFIX
	if path.is_empty() or not FileAccess.file_exists(bak):
		return PlayerProfile.new()
	var parsed := _parse(_read(bak))
	if not parsed["ok"]:
		return PlayerProfile.new()
	if int(parsed["version"]) > VERSION:
		preserve_file = true
		return PlayerProfile.new()
	return profile_from_dict(parsed["data"])


func _parse(text: String) -> Dictionary:
	if text.strip_edges().is_empty():
		return {"ok": false, "version": 0, "data": {}}
	var json := JSON.new()
	if json.parse(text) != OK:
		return {"ok": false, "version": 0, "data": {}}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {"ok": false, "version": 0, "data": {}}
	var data: Dictionary = json.data
	var version := _as_int(data.get("version", 0), 0)
	return {"ok": true, "version": version, "data": data}


func _read(file_path: String) -> String:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _rename(from_path: String, to_path: String) -> Error:
	var dir := DirAccess.open(from_path.get_base_dir())
	if dir == null:
		return ERR_CANT_OPEN
	if from_path.get_base_dir() != to_path.get_base_dir():
		return ERR_INVALID_PARAMETER
	if dir.file_exists(to_path.get_file()):
		var removed := dir.remove(to_path.get_file())
		if removed != OK:
			return removed
	return dir.rename(from_path.get_file(), to_path.get_file())


func _remove(file_path: String) -> Error:
	var dir := DirAccess.open(file_path.get_base_dir())
	if dir == null:
		return ERR_CANT_OPEN
	if not dir.file_exists(file_path.get_file()):
		return OK
	return dir.remove(file_path.get_file())


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
