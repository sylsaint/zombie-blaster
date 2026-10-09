class_name GateRunner
extends RefCounted
## Next untriggered group only, walked forward when one tick crosses several.
## No Area3D. Bullet hits on shootable gates update the number before the
## squad collects the group, so a same-frame shot still counts.


var groups: Array = []
var next_index: int = 0
var grunt_hp: float = 20.0
var banner_count: int = 0
var banners := PackedStringArray()
var shootable_count: int = 0


func _init() -> void:
	banners.resize(8)


static func nearer_first(a: Variant, b: Variant) -> bool:
	return (a as GateGroup).z > (b as GateGroup).z


func set_groups(list: Array, squad_z: float) -> void:
	groups = list.duplicate()
	if groups.size() > 1:
		groups.sort_custom(Callable(GateRunner, "nearer_first"))
	next_index = 0
	var count := groups.size()
	while next_index < count and (groups[next_index] as GateGroup).z > squad_z:
		next_index += 1
	_recount_shootable()


func resolve_crossing(squad: SquadAnchor, prev_z: float, new_z: float) -> void:
	banner_count = 0
	if new_z >= prev_z:
		return
	while next_index < groups.size():
		var group := groups[next_index] as GateGroup
		if prev_z >= group.z and new_z < group.z:
			_trigger(squad, group)
			next_index += 1
		else:
			break


func absorb_bullets(bullets: BulletPool) -> void:
	if shootable_count <= 0 or bullets == null:
		return
	var step_hp := grunt_hp
	var b := 0
	while b < bullets.capacity:
		if bullets.alive[b] != 0:
			_absorb_segment(bullets.prev_x[b], bullets.prev_z[b], bullets.x[b], bullets.z[b], bullets.damage[b], step_hp)
		b += 1


func _trigger(squad: SquadAnchor, group: GateGroup) -> void:
	var index := GateRules.pick_span_index(group.spans, squad.position.x)
	if index >= 0:
		_note(GateRules.apply_span(squad, group.spans[index]))
	var s := 0
	while s < group.spans.size():
		var span := group.spans[s] as GateSpan
		if span != null:
			span.locked = true
		s += 1
	_recount_shootable()


func _absorb_segment(x0: float, z0: float, x1: float, z1: float, damage: float, step_hp: float) -> void:
	var g := 0
	while g < groups.size():
		var group := groups[g] as GateGroup
		if (z0 > group.z and z1 <= group.z) or (z0 < group.z and z1 >= group.z):
			var denom := z1 - z0
			var t := 0.0 if absf(denom) <= 0.0000001 else clampf((group.z - z0) / denom, 0.0, 1.0)
			var x := lerpf(x0, x1, t)
			var index := GateRules.pick_span_index(group.spans, x)
			if index >= 0:
				GateRules.apply_shot_damage(group.spans[index], damage, step_hp)
		g += 1


func _recount_shootable() -> void:
	var total := 0
	for group in groups:
		var gate := group as GateGroup
		for span in gate.spans:
			var leaf := span as GateSpan
			if leaf != null and leaf.shootable and not leaf.locked:
				total += 1
	shootable_count = total


func _note(text: String) -> void:
	if text == "" or banner_count >= banners.size():
		return
	banners[banner_count] = text
	banner_count += 1
