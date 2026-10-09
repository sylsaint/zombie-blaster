class_name SkillLoadout
extends RefCounted
## Levels for the six M1 cards. Push copies the totals onto the squad.


const COUNT := 6

var level := PackedInt32Array()
var cards: Array[SkillCard] = []


static var _cached: Array[SkillCard] = []


static func card_paths() -> PackedStringArray:
	return PackedStringArray([
		"res://data/skills/split_shot.tres",
		"res://data/skills/pierce.tres",
		"res://data/skills/burst.tres",
		"res://data/skills/rapid.tres",
		"res://data/skills/power.tres",
		"res://data/skills/reinforce.tres",
	])


static func load_cards() -> Array[SkillCard]:
	if _cached.is_empty():
		var paths := card_paths()
		for path in paths:
			_cached.append(load(path) as SkillCard)
	return _cached


func _init() -> void:
	level.resize(COUNT)
	cards = load_cards()


func card_level(id: int) -> int:
	if id < 0 or id >= COUNT:
		return 0
	return level[id]


func is_maxed(id: int) -> bool:
	if id < 0 or id >= COUNT:
		return true
	var cap := cards[id].max_level
	if cap < 0:
		return false
	return level[id] >= cap


func is_core(id: int) -> bool:
	if id < 0 or id >= COUNT:
		return false
	return cards[id].core


func apply(id: int, squad: SquadAnchor) -> void:
	if squad == null or is_maxed(id):
		return
	level[id] += 1
	if id == SkillCard.REINFORCE:
		squad.add_soldiers(int(cards[id].magnitude))
	push_to(squad)


func push_to(squad: SquadAnchor) -> void:
	if squad == null:
		return
	squad.skill_damage_bonus = cards[SkillCard.POWER].magnitude * float(level[SkillCard.POWER])
	squad.skill_rate_bonus = cards[SkillCard.RAPID].magnitude * float(level[SkillCard.RAPID])
	squad.skill_pierce = int(cards[SkillCard.PIERCE].magnitude) * level[SkillCard.PIERCE]
	squad.skill_extra_pellets = int(cards[SkillCard.BURST].magnitude) * level[SkillCard.BURST]
	var split_level := level[SkillCard.SPLIT]
	squad.skill_split_count = 0 if split_level <= 0 else split_level + 1
	squad.skill_split_ratio = cards[SkillCard.SPLIT].magnitude
	squad.skill_split_spread = cards[SkillCard.SPLIT].spread_degrees


func split_shots_for_level(split_level: int) -> int:
	if split_level <= 0:
		return 0
	return split_level + 1
