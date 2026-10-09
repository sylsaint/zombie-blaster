class_name WeaponMods
extends RefCounted
## Hooks for skill cards (#8) and the meta attack upgrade (#12).
## Gates write SquadAnchor.damage_bonus and rate_bonus. Cards add the same
## totals. Split projectiles are not spawned here.


const RAPID_STEP := 0.15
const DAMAGE_STEP := 0.20
const META_ATTACK_STEP := 0.08
const META_ATTACK_CAP := 30
const SPLIT_SPREAD_DEGREES := 30.0
const SPLIT_DAMAGE_SCALE := 0.5


static func meta_attack_bonus(levels: int) -> float:
	return META_ATTACK_STEP * float(clampi(levels, 0, META_ATTACK_CAP))


## 0 -> none, 1 -> 2, 2 -> 3, 3 -> 4 children, each at half damage.
static func split_child_count(level: int) -> int:
	match clampi(level, 0, 3):
		1:
			return 2
		2:
			return 3
		3:
			return 4
		_:
			return 0
