class_name MetaPanel
extends VBoxContainer
## Attack upgrade readout. Cost and level come from CampaignFlow.


signal upgrade_pressed


func _ready() -> void:
	%Upgrade.pressed.connect(func() -> void: upgrade_pressed.emit())


func show_state(level: int, cap: int, bonus_percent: int, cost: int, can_buy: bool, coins: int, parts: int) -> void:
	%Attack.text = "攻击力  %d / %d    伤害 +%d%%" % [level, cap, bonus_percent]
	%Wallet.text = "金币  %d    零件  %d" % [coins, parts]
	if cost < 0:
		%Upgrade.text = "攻击力已满"
		%Upgrade.disabled = true
	else:
		%Upgrade.text = "升级攻击力  %d" % cost
		%Upgrade.disabled = not can_buy
