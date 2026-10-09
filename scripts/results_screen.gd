class_name ResultsScreen
extends Control
## Portrait results layout. Coin amounts arrive already judged.


const STAR_FILLED := preload("res://assets/ui/icons/icon_star_filled.png")
const STAR_EMPTY := preload("res://assets/ui/icons/icon_star_empty.png")

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
	# A loss has no stars to show. The squad row would only read "0 / 20".
	_set_star(%StarClearRow, %StarClear, view.won, view.star_clear, "通关")
	_set_star(%StarSquadRow, %StarSquad, view.won, view.star_squad, "人数 %d / %d" % [view.headcount, view.star2_target])
	_set_star(%StarHitsRow, %StarHits, view.won, view.star_hits, "关底受击 %d" % view.finale_skill_hits)
	%ClearLine.visible = view.show_clear_line
	%ClearLine.text = view.clear_line
	%RunLine.text = view.run_line
	%TotalLine.text = view.total_line
	%PartsLine.visible = view.show_parts_line
	%PartsLine.text = view.parts_line
	%ChestLine.visible = view.show_chest_line
	%ChestLine.text = view.chest_line
	%Retry.disabled = not view.can_retry
	%Next.disabled = not view.can_next
	%Back.disabled = not view.can_back


func _set_star(row: HBoxContainer, label: Label, show_row: bool, filled: bool, caption: String) -> void:
	row.visible = show_row
	if not show_row:
		label.text = ""
		return
	label.text = caption
	var icon := row.get_node("Icon") as TextureRect
	icon.texture = STAR_FILLED if filled else STAR_EMPTY
