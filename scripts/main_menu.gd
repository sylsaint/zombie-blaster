class_name MainMenu
extends Control
## Portrait title screen. Upgrade numbers are filled in by CampaignFlow.


signal play_pressed
signal upgrade_pressed


func _ready() -> void:
	%Play.pressed.connect(func() -> void: play_pressed.emit())
	%Meta.upgrade_pressed.connect(func() -> void: upgrade_pressed.emit())


func show_meta(level: int, cap: int, bonus_percent: int, cost: int, can_buy: bool, coins: int, parts: int) -> void:
	%Meta.show_state(level, cap, bonus_percent, cost, can_buy, coins, parts)
