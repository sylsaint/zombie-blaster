class_name LevelData
extends Resource
## Authored level. Rewards are stored for the results screen; this resource
## does not pay them out.


const GATE_CLEARANCE := 8.0

@export var level_index: int = 1
@export var chapter: int = 1
@export var title: String = ""
@export var hp_multiplier: float = 1.0
@export var grunt_total: int = 0
@export var gate_group_count: int = 0
@export var advance_elite_count: int = 0
@export var elite_hp: float = 4800.0
@export var finale: String = "elite"
@export var finale_elite_count: int = 0
@export var boss_hp: float = 0.0
@export var boss_summon: bool = false
@export var expected_dps: float = 800.0
@export var star2_headcount: int = 20
@export var base_clear_coins: int = 100
@export var star_coin_multipliers: PackedFloat32Array
@export var first_clear_parts: int = 5
## First three-star chest, paid separately from the clear payout.
@export var three_star_chest_coin_multiplier: float = 2.0
@export var three_star_chest_parts: int = 5
@export var three_star_chest_paid_separately: bool = true
@export var fail_coin_ratio: float = 0.30
@export var events: Array[LevelEvent]


func _init() -> void:
	events = []
	if star_coin_multipliers.is_empty():
		star_coin_multipliers = PackedFloat32Array([1.0, 1.2, 1.5])


func sorted_events() -> Array[LevelEvent]:
	var copy: Array[LevelEvent] = []
	for event in events:
		copy.append(event)
	copy.sort_custom(func(a: LevelEvent, b: LevelEvent) -> bool: return a.distance < b.distance)
	return copy


func grunt_spawn_total() -> int:
	var total := 0
	for event in events:
		if event.kind == "wave":
			total += event.count
	return total


func count_kind(kind: String) -> int:
	var total := 0
	for event in events:
		if event.kind == kind:
			total += 1
	return total


func advance_elite_total() -> int:
	var total := 0
	for event in events:
		if event.kind == "elite":
			total += maxi(event.count, 1)
	return total


func finale_distance() -> float:
	var best := 0.0
	for event in events:
		if event.distance > best:
			best = event.distance
	return best


func gate_groups() -> Array[LevelEvent]:
	var found: Array[LevelEvent] = []
	for event in events:
		if event.kind == "gate_group":
			found.append(event)
	return found


func has_buff_in_every_group() -> bool:
	for group in gate_groups():
		var buff := false
		for gate in group.gates:
			if gate.is_buff():
				buff = true
				break
		if not buff:
			return false
	return true


func wave_inside_gate_clearance() -> bool:
	var gates := gate_groups()
	for event in events:
		if event.kind != "wave":
			continue
		for gate in gates:
			var gap := gate.distance - event.distance
			if gap > 0.0 and gap < GATE_CLEARANCE:
				return true
	return false


func add_gate_amount() -> int:
	return int(round(4.0 + 1.5 * float(level_index)))
