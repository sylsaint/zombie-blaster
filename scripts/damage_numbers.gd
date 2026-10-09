class_name DamageNumbers
extends RefCounted
## Fixed ring of damage numbers. Spawning one never allocates.


const CAP := 20
const ORANGE := Color(1.0, 0.48, 0.05, 1.0)
const WHITE := Color(1.0, 1.0, 1.0, 1.0)
const YELLOW := Color(1.0, 0.86, 0.2, 1.0)
const LIFE := 0.6

var amount := PackedFloat32Array()
var life := PackedFloat32Array()
var color_id := PackedInt32Array()
var active_count: int = 0
var last_color: Color = WHITE
var last_amount: float = 0.0
var last_shown: bool = false
var _cursor: int = 0


func _init() -> void:
	amount.resize(CAP)
	life.resize(CAP)
	color_id.resize(CAP)


func push(value: float, color: Color) -> void:
	last_color = color
	last_amount = value
	last_shown = true
	amount[_cursor] = value
	life[_cursor] = LIFE
	color_id[_cursor] = _color_id(color)
	_cursor = (_cursor + 1) % CAP
	if active_count < CAP:
		active_count += 1


func tick(dt: float) -> void:
	var step := maxf(dt, 0.0)
	var alive := 0
	var i := 0
	while i < CAP:
		if life[i] > 0.0:
			life[i] = maxf(0.0, life[i] - step)
			if life[i] > 0.0:
				alive += 1
		i += 1
	active_count = alive


func color_at(slot: int) -> Color:
	return _color_from_id(color_id[slot])


func _color_id(color: Color) -> int:
	if color == ORANGE:
		return 1
	if color == YELLOW:
		return 2
	return 0


func _color_from_id(id: int) -> Color:
	if id == 1:
		return ORANGE
	if id == 2:
		return YELLOW
	return WHITE
