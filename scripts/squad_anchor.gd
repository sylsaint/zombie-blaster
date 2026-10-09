class_name SquadAnchor
extends RefCounted
## One anchor for the squad. Soldiers are visual offsets, not bodies.
## Bullets spawn on the anchor. Headcount scales damage and spread, not pellet count.


const FORWARD_SPEED_DEFAULT := 4.0
const LATERAL_SPEED_CAP := 14.0
const VISIBLE_CAP := 40
const LANE_HALF_WIDTH := 3.0
const FORMATION_TWEEN := 0.25

var count: int = 5
var forward_speed: float = FORWARD_SPEED_DEFAULT
var position := Vector3.ZERO
var target_x: float = 0.0
var damage_bonus: float = 0.0
var rate_bonus: float = 0.0
## Skill-card and meta hooks. Zero keeps the M1 pistol path unchanged.
var extra_shots: int = 0
var bonus_pierce: int = 0
var split_level: int = 0
var meta_attack_levels: int = 0
var weapon: WeaponStats
var lane_half_width: float = LANE_HALF_WIDTH
var displayed_offsets := PackedVector3Array()
var pending_shots: Array = []

var _cooldown: float = 0.4
var _spread_cursor: int = 0
var _form_count: int = -1
var _form := PackedVector3Array()


func _init() -> void:
	weapon = WeaponStats.pistol()
	_cooldown = weapon.interval


static func formation_radius(n: int) -> float:
	return minf(0.35 * sqrt(float(maxi(n, 0))), 2.4)


static func visible_count_for(n: int) -> int:
	return clampi(n, 0, VISIBLE_CAP)


func visible_count() -> int:
	return visible_count_for(count)


static func shot_damage(weapon_damage: float, n: int, bonus: float) -> float:
	return weapon_damage * pow(float(maxi(n, 0)), 0.7) * (1.0 + bonus)


static func shot_interval(weapon_interval: float, bonus: float) -> float:
	var denom := 1.0 + bonus
	if denom <= 0.0001:
		return weapon_interval
	return weapon_interval / denom


static func trajectory_width(n: int) -> float:
	if n <= 20:
		return 0.0
	return formation_radius(n) * 2.0


## Lateral spawn offsets. Pellet count is the weapon's, never the headcount.
static func lateral_offsets(pellets: int, n: int, cursor: int = 0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	if pellets <= 0:
		return out
	out.resize(pellets)
	var width := trajectory_width(n)
	if pellets == 1:
		if width <= 0.0:
			out[0] = 0.0
		else:
			var steps := 7
			var t := float(posmod(cursor, steps)) / float(steps - 1)
			out[0] = lerpf(-width * 0.5, width * 0.5, t)
		return out
	var half := width * 0.5
	for i in pellets:
		var t := float(i) / float(pellets - 1)
		out[i] = lerpf(-half, half, t)
	return out


static func formation_offsets(n: int) -> PackedVector3Array:
	var visible := visible_count_for(n)
	var radius := formation_radius(n)
	var out := PackedVector3Array()
	out.resize(visible)
	if visible == 0:
		return out
	if visible == 1:
		out[0] = Vector3.ZERO
		return out
	var golden := PI * (3.0 - sqrt(5.0))
	for i in visible:
		var r := radius * sqrt((float(i) + 0.5) / float(visible))
		var ang := float(i) * golden
		out[i] = Vector3(cos(ang) * r, 0.0, sin(ang) * r)
	return out


func current_interval() -> float:
	if weapon == null:
		return 0.4
	return shot_interval(weapon.interval, rate_bonus)


func total_damage_bonus() -> float:
	return damage_bonus + WeaponMods.meta_attack_bonus(meta_attack_levels)


func outfit_tier() -> int:
	if weapon == null or weapon.outfit_tier <= 0:
		return 1
	return weapon.outfit_tier


func weapon_tier() -> int:
	if weapon == null or weapon.tier <= 0:
		return 1
	return weapon.tier


func equip_tier(level: int) -> void:
	weapon = WeaponCatalog.tier(level)


func set_cooldown(seconds: float) -> void:
	_cooldown = seconds


func apply_drag(screen_dx: float, viewport_width: float) -> void:
	target_x = LaneMotion.apply_drag(target_x, screen_dx, viewport_width, lane_half_width)


func consume_shots() -> Array:
	var shots := pending_shots
	pending_shots = []
	return shots


func tick(gameplay_delta: float) -> void:
	var dt := maxf(gameplay_delta, 0.0)
	target_x = clampf(target_x, -lane_half_width, lane_half_width)
	var max_step := LATERAL_SPEED_CAP * dt
	position.x = move_toward(position.x, target_x, max_step)
	position.x = clampf(position.x, -lane_half_width, lane_half_width)
	position.z -= forward_speed * dt
	_tween_formation(dt)
	if count <= 0 or weapon == null:
		return
	_cooldown -= dt
	var interval := maxf(current_interval(), 0.001)
	var guard := 0
	while _cooldown <= 0.0 and guard < 8:
		_emit_shot()
		_cooldown += interval
		guard += 1


func _tween_formation(dt: float) -> void:
	if _form_count != count:
		_form = formation_offsets(count)
		_form_count = count
		if displayed_offsets.size() != _form.size():
			var next := PackedVector3Array()
			next.resize(_form.size())
			var keep := mini(displayed_offsets.size(), next.size())
			var k := 0
			while k < keep:
				next[k] = displayed_offsets[k]
				k += 1
			displayed_offsets = next
	# Cross the widest formation inside the 0.25 s blend window.
	var step := (4.8 / FORMATION_TWEEN) * dt
	var i := 0
	while i < _form.size():
		displayed_offsets[i] = displayed_offsets[i].move_toward(_form[i], step)
		i += 1


func _emit_shot() -> void:
	var pellets := weapon.pellets + extra_shots
	var offsets := lateral_offsets(pellets, count, _spread_cursor)
	_spread_cursor += 1
	pending_shots.append({
		"damage": shot_damage(weapon.damage, count, total_damage_bonus()),
		"speed": weapon.bullet_speed,
		"range": weapon.bullet_range,
		"pierce": weapon.pierce + bonus_pierce,
		"spread": weapon.spread_degrees,
		"offsets": offsets,
		"origin": position,
		"split_level": split_level,
		"split_count": WeaponMods.split_child_count(split_level),
	})
