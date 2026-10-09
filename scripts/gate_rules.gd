class_name GateRules
extends RefCounted
## Pure gate math. Divide (÷2) is M2 and is ignored on purpose.


const ADD := 1
const MULTIPLY := 2
const SUBTRACT := 3
const WEAPON := 4
const FIRE_RATE := 5
const DIVIDE := 6
const CAP := 150
const M1_MAX_WEAPON_TIER := 2
const FIRE_RATE_STEP := 0.15
const MAXED_WEAPON_DAMAGE := 0.20
const CLEARANCE_METERS := 8.0
const SHOOT_HP_STEPS := 3.0

const CYAN := Color("4cc9f0")
const PINK := Color("ef476f")
const GOLD := Color("f2c14e")


static func is_benefit(kind: int, amount: float) -> bool:
	match kind:
		ADD:
			return amount > 0.0
		MULTIPLY:
			return amount > 1.0
		WEAPON, FIRE_RATE:
			return true
		_:
			return false


static func group_has_benefit(group: GateGroup) -> bool:
	if group == null:
		return false
	for span in group.spans:
		var gate := span as GateSpan
		if gate != null and is_benefit(gate.resolved_kind(), gate.resolved_amount()):
			return true
	return false


static func validate_group_resources(root: String = "res://data") -> PackedStringArray:
	var errors := PackedStringArray()
	_scan(root, errors)
	return errors


static func add_amount_for_level(level: int) -> int:
	return int(round(4.0 + 1.5 * float(level)))


static func group_count_for_level(level: int) -> int:
	return mini(9, 5 + int(floor(float(level) / 3.0)))


## True when a grunt spawn sits in the 8 m the squad walks before the gate.
static func spawn_blocks_gate(spawn_z: float, gate_z: float, clearance: float = CLEARANCE_METERS) -> bool:
	return spawn_z > gate_z and spawn_z <= gate_z + clearance


static func clearance_ok(groups: Array, spawn_zs: PackedFloat32Array, clearance: float = CLEARANCE_METERS) -> bool:
	for group in groups:
		var gate_z: float = (group as GateGroup).z
		var i := 0
		while i < spawn_zs.size():
			if spawn_blocks_gate(spawn_zs[i], gate_z, clearance):
				return false
			i += 1
	return true


## Boundary belongs to the span with the greater x_min, so x = 0 hits one gate.
static func pick_span_index(spans: Array, x: float) -> int:
	var best := -1
	var best_min := -1.0e20
	var i := 0
	while i < spans.size():
		var span := spans[i] as GateSpan
		if span != null and x >= span.x_min and x <= span.x_max and span.x_min >= best_min:
			best = i
			best_min = span.x_min
		i += 1
	return best


static func apply_span(squad: SquadAnchor, span: GateSpan) -> String:
	if span == null:
		return ""
	var amount := int(round(span.resolved_amount()))
	match span.resolved_kind():
		ADD:
			return apply_add(squad, amount)
		MULTIPLY:
			return apply_mul(squad, amount)
		SUBTRACT:
			return apply_sub(squad, amount)
		WEAPON:
			return apply_weapon(squad)
		FIRE_RATE:
			return apply_fire_rate(squad)
		_:
			return ""


static func apply_add(squad: SquadAnchor, n: int) -> String:
	if n <= 0:
		return ""
	if squad.count >= CAP or squad.count + n > CAP:
		if squad.count < CAP:
			squad.count = CAP
		return "已满"
	squad.count += n
	return "+%d" % n


static func apply_mul(squad: SquadAnchor, n: int) -> String:
	if n <= 1:
		return ""
	if squad.count >= CAP:
		return "已满"
	var next := squad.count * n
	if next > CAP:
		squad.count = CAP
		return "已满"
	squad.count = next
	return "×%d" % n


static func apply_sub(squad: SquadAnchor, n: int) -> String:
	if n <= 0:
		return ""
	squad.count = maxi(squad.count - n, 0)
	return "−%d" % n


static func apply_weapon(squad: SquadAnchor) -> String:
	var tier := 1
	if squad.weapon != null:
		tier = maxi(squad.weapon.tier, 1)
	if tier < M1_MAX_WEAPON_TIER:
		squad.equip_tier(tier + 1)
		return "武器+1"
	squad.damage_bonus += MAXED_WEAPON_DAMAGE
	return "伤害+20%"


static func apply_fire_rate(squad: SquadAnchor) -> String:
	squad.rate_bonus += FIRE_RATE_STEP
	return "射速+15%"


## Every grunt_hp * 3 damage, the shootable number goes up by 1. Remainder is kept.
static func apply_shot_damage(span: GateSpan, damage: float, grunt_hp: float) -> int:
	if span == null or not span.shootable or span.locked or damage <= 0.0:
		return 0
	var step := grunt_hp * SHOOT_HP_STEPS
	if step <= 0.0:
		return 0
	span.damage_bank += damage
	var steps := 0
	while span.damage_bank + 0.0001 >= step:
		span.damage_bank -= step
		steps += 1
	if span.damage_bank < 0.0:
		span.damage_bank = 0.0
	if steps > 0:
		span.value += float(steps)
		span.visual_dirty = true
	return steps


static func color_for(span: GateSpan) -> Color:
	if span == null:
		return PINK
	if span.shootable and span.value <= 0.0:
		return PINK
	match span.resolved_kind():
		ADD, MULTIPLY:
			return CYAN
		SUBTRACT:
			return PINK
		WEAPON, FIRE_RATE:
			return GOLD
		_:
			return PINK


static func label_for(span: GateSpan) -> String:
	if span == null:
		return ""
	if span.shootable:
		var shown := int(round(span.value))
		if shown > 0:
			return "+%d" % shown
		return "−%d" % absi(shown)
	match span.kind:
		ADD:
			return "+%d" % int(round(span.amount))
		MULTIPLY:
			return "×%d" % int(round(span.amount))
		SUBTRACT:
			return "−%d" % int(round(span.amount))
		WEAPON:
			return "武器+1"
		FIRE_RATE:
			return "射速+15%"
		_:
			return ""


static func _scan(dir_path: String, errors: PackedStringArray) -> void:
	var directory := DirAccess.open(dir_path)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var path := dir_path.path_join(entry)
			if directory.current_is_dir():
				_scan(path, errors)
			elif entry.ends_with(".tres") or entry.ends_with(".res"):
				var res: Resource = load(path)
				if res is GateGroup and not group_has_benefit(res as GateGroup):
					errors.append(path)
		entry = directory.get_next()
	directory.list_dir_end()
