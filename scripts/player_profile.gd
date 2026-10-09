class_name PlayerProfile
extends RefCounted
## Meta progress. Levels 1–3 are the M1 slice; flags grow with the index.


var coins: int = 0
var parts: int = 0
var attack_level: int = 0
var unlocked_through: int = 1
var first_clear: Array[bool] = []
var three_star: Array[bool] = []


func _init() -> void:
	_pad(3)


func is_unlocked(level_index: int) -> bool:
	return level_index >= 1 and level_index <= unlocked_through


func has_first_clear(level_index: int) -> bool:
	if level_index < 1 or level_index > first_clear.size():
		return false
	return first_clear[level_index - 1]


func mark_first_clear(level_index: int) -> void:
	_pad(level_index)
	first_clear[level_index - 1] = true


func has_three_star(level_index: int) -> bool:
	if level_index < 1 or level_index > three_star.size():
		return false
	return three_star[level_index - 1]


func mark_three_star(level_index: int) -> void:
	_pad(level_index)
	three_star[level_index - 1] = true


func note_clear(level_index: int) -> void:
	unlocked_through = maxi(unlocked_through, level_index + 1)


func _pad(level_index: int) -> void:
	var n := maxi(level_index, 0)
	while first_clear.size() < n:
		first_clear.append(false)
	while three_star.size() < n:
		three_star.append(false)
