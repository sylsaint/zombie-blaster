class_name LevelSelect
extends Control
## Levels 1–3. Locked rows stay on screen so the next unlock is visible.


signal level_pressed(index: int)
signal back_pressed
signal upgrade_pressed


func _ready() -> void:
	%Level1.pressed.connect(func() -> void: level_pressed.emit(1))
	%Level2.pressed.connect(func() -> void: level_pressed.emit(2))
	%Level3.pressed.connect(func() -> void: level_pressed.emit(3))
	%Back.pressed.connect(func() -> void: back_pressed.emit())
	%Meta.upgrade_pressed.connect(func() -> void: upgrade_pressed.emit())


func show_levels(unlocked_through: int) -> void:
	_set_level(%Level1, 1, unlocked_through)
	_set_level(%Level2, 2, unlocked_through)
	_set_level(%Level3, 3, unlocked_through)


func show_meta(level: int, cap: int, bonus_percent: int, cost: int, can_buy: bool, coins: int, parts: int) -> void:
	%Meta.show_state(level, cap, bonus_percent, cost, can_buy, coins, parts)


func level_button(index: int) -> Button:
	return get_node("%Level%d" % index) as Button


func _set_level(button: Button, index: int, unlocked_through: int) -> void:
	var open := index <= unlocked_through
	button.disabled = not open
	if open:
		button.text = "第 %d 关" % index
	else:
		button.text = "第 %d 关  未解锁" % index
