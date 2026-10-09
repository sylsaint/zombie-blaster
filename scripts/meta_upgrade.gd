class_name MetaUpgrade
extends RefCounted
## Attack upgrade. Damage is applied later through SquadAnchor.meta_attack_levels,
## not by writing the gate or skill bonus fields.


const COST_BASE := 50.0
const COST_GROWTH := 1.25
const COST_STEP := 10


static func cost_for_level(k: int) -> int:
	if k <= 0:
		return 0
	var raw := COST_BASE * pow(COST_GROWTH, float(k - 1))
	return int(floor(raw / float(COST_STEP) + 0.0000001)) * COST_STEP


static func next_cost(current_level: int) -> int:
	if current_level >= WeaponMods.META_ATTACK_CAP:
		return -1
	return cost_for_level(current_level + 1)


static func can_buy(profile: PlayerProfile) -> bool:
	var cost := next_cost(profile.attack_level)
	return cost >= 0 and profile.coins >= cost


static func try_buy(profile: PlayerProfile) -> bool:
	if not can_buy(profile):
		return false
	profile.coins -= next_cost(profile.attack_level)
	profile.attack_level += 1
	return true
