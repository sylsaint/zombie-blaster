class_name ResultsScreen
extends Control
## Portrait results layout. Coin amounts arrive already judged.


signal retry_pressed
signal next_pressed
signal back_pressed


func _ready() -> void:
	%Retry.pressed.connect(func() -> void: retry_pressed.emit())
	%Next.pressed.connect(func() -> void: next_pressed.emit())
	%Back.pressed.connect(func() -> void: back_pressed.emit())
	visible = false


func present(view: Settlement) -> void:
	visible = true
	%Title.text = "胜利" if view.won else "失败"
	%StarClear.text = _mark(view.star_clear) + "通关"
	%StarSquad.text = _mark(view.star_squad) + "人数 %d / %d" % [view.headcount, view.star2_target]
	%StarHits.text = _mark(view.star_hits) + "关底受击 %d" % view.finale_skill_hits
	%ClearLine.text = view.clear_line
	%RunLine.text = view.run_line
	%TotalLine.text = view.total_line
	%PartsLine.text = view.parts_line
	%ChestLine.text = view.chest_line
	%Retry.disabled = not view.can_retry
	%Next.disabled = not view.can_next
	%Back.disabled = not view.can_back


func _mark(on: bool) -> String:
	if on:
		return "★  "
	return "☆  "
