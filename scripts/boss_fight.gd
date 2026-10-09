class_name BossFight
extends RefCounted
## Mini-boss (and the shared mutant skeleton) driven by gameplay time.
## Hit-stop goes through GameClock. This never writes Engine.time_scale.


const APPROACH_DISTANCE := 25.0
const HOLD_DISTANCE := 12.0
const APPROACH_SPEED := 1.6
const ALARM_TIME := 1.5
const OPENING_DELAY := 0.35
const STUN_TIME := 2.0
const TRANSITION_TIME := 1.5
const ENRAGE_TIME := 90.0
const PHASE2_RATIO := 0.60
const PHASE3_RATIO := 0.25
const SLAM_WARN := 1.0
const CHARGE_WARN := 1.2
const PERIOD_P1 := 3.5
const PERIOD_P2 := 3.0
const WEAK_HITSTOP_MS := 30.0
const WEAK_HITSTOP_GAP := 0.5
const FLASH_GAP := 0.1
const BOSS_FLASH := 0.05
const WEAK_SHAKE := 0.15
const PHASE_SHAKE := 0.7
const DEATH_SHAKE := 1.0
const PATROL_SPEED := 1.8
const PATROL_LIMIT := 2.2
const SLAM_RATIO := 0.25
const SLAM_MIN := 3
const CHARGE_RATIO := 0.35
const CHARGE_MIN := 5
const SLOW_FACTOR := 0.3
const SLOW_TIME := 0.6

enum Stage { APPROACH, FIGHT, DEAD }

var archetype: EnemyArchetype
var mini_boss: bool = true
var summon_enabled: bool = false
var display_name: String = "突变巨兽"
var hp: float = 0.0
var hp_max: float = 1.0
var x: float = 0.0
var z: float = 0.0
var center_x: float = 0.0
var center_z: float = 0.0
var collision_radius: float = 2.7
var elapsed: float = 0.0
var stage: int = Stage.APPROACH
var phase_index: int = 1
var enraged: bool = false
var invulnerable_left: float = 0.0
var stun_left: float = 0.0
var alarm_left: float = ALARM_TIME
var leaning: bool = false
var weakpoint_glow: bool = false
var flash_left: float = 0.0
var victorious: bool = false
var skill_hits: int = 0
var transition_count: int = 0
var summon_count: int = 0
var supply_pending: bool = false
var supply_add: int = 9
var last_safe_width: float = 0.0
var last_warning_duration: float = 0.0
var last_charge_body_hit: bool = false
var last_immune: bool = false
var pending_squad_loss: int = 0
var contact_timer: float = 0.0
var numbers := DamageNumbers.new()
var shake := ScreenShake.new()
var telegraph := SkillTelegraph.new()
var warning_kinds := PackedStringArray()
var warning_durations := PackedFloat32Array()
var warning_safe := PackedFloat32Array()
var clock: Node = null

var _squad_z: float = 0.0
var _next_skill_at: float = 0.0
var _skill_started_at: float = 0.0
var _skill_flip: int = 0
var _patrol_dir: float = 1.0
var _last_weak_stop_at: float = -999.0
var _last_flash_at: float = -999.0
var _contact_ready: float = 0.0


func start(arch: EnemyArchetype, squad_z: float, hit_points: float, is_mini: bool, allow_summon: bool) -> void:
	archetype = arch
	mini_boss = is_mini
	summon_enabled = allow_summon and not is_mini
	if arch != null and arch.display_name != "":
		display_name = arch.display_name
	hp_max = maxf(hit_points, 1.0)
	hp = hp_max
	collision_radius = arch.collision_radius if arch != null else 2.7
	_squad_z = squad_z
	x = 0.0
	z = squad_z - APPROACH_DISTANCE
	stage = Stage.APPROACH
	phase_index = 1
	elapsed = 0.0
	alarm_left = ALARM_TIME
	enraged = false
	victorious = false
	skill_hits = 0
	transition_count = 0
	summon_count = 0
	stun_left = 0.0
	invulnerable_left = 0.0
	leaning = false
	weakpoint_glow = false
	_refresh_center()


func skill_period() -> float:
	var base := PERIOD_P1 if phase_index <= 1 else PERIOD_P2
	if enraged:
		return base * 0.5
	return base


func accepts_damage() -> bool:
	return stage == Stage.FIGHT and invulnerable_left <= 0.0 and hp > 0.0


func can_receive_hit() -> bool:
	return stage == Stage.FIGHT and hp > 0.0


func body_hits(squad_x: float, squad_z: float, squad_radius: float) -> bool:
	if archetype == null:
		return false
	return archetype.overlaps(x, z, squad_x, squad_z, squad_radius)


## Charge impact evaluated with the offset circle at the dash pose.
func charge_body_hits(impact_x: float, impact_z: float, squad_x: float, squad_z: float, squad_radius: float) -> bool:
	if archetype == null:
		return false
	return archetype.overlaps(impact_x, impact_z, squad_x, squad_z, squad_radius)


func apply_damage(amount: float) -> void:
	last_immune = false
	numbers.last_shown = false
	if stage != Stage.FIGHT or hp <= 0.0:
		return
	if invulnerable_left > 0.0 or amount <= 0.0:
		last_immune = true
		return
	var stunned := stun_left > 0.0
	var mult := 2.0 if stunned else 1.0
	var dealt := amount * mult
	var next := hp - dealt
	if _should_phase(next):
		var floor_hp := hp_max * _next_threshold()
		var applied := maxf(hp - floor_hp, 0.0)
		hp = floor_hp
		_show_number(applied, stunned)
		_on_hit_feedback(stunned)
		_begin_transition()
		return
	hp = next
	_show_number(dealt, stunned)
	_on_hit_feedback(stunned)
	if hp <= 0.0:
		_die()


func tick(dt: float, squad_x: float, squad_z: float, squad_count: int, squad_radius: float, real_dt: float = -1.0) -> void:
	var step := maxf(dt, 0.0)
	elapsed += step
	alarm_left = maxf(0.0, alarm_left - step)
	flash_left = maxf(0.0, flash_left - step)
	numbers.tick(step)
	var shake_dt := step if real_dt < 0.0 else maxf(real_dt, 0.0)
	shake.tick(shake_dt)
	_squad_z = squad_z
	if stage == Stage.DEAD:
		_refresh_center()
		return
	if not enraged and elapsed >= ENRAGE_TIME:
		enraged = true
	if stage == Stage.APPROACH:
		_tick_approach(step)
		return
	if invulnerable_left > 0.0:
		invulnerable_left = maxf(0.0, invulnerable_left - step)
		stun_left = 0.0
		leaning = false
		weakpoint_glow = false
		if telegraph.active:
			telegraph.active = false
		_hold_line(step)
		_refresh_center()
		return
	_tick_stun(step)
	_tick_contact(step, squad_x, squad_z, squad_count, squad_radius)
	_tick_skills(step, squad_x, squad_count, squad_radius)
	if stun_left <= 0.0 and not telegraph.active:
		_patrol(step)
	_refresh_center()


func take_squad_loss() -> int:
	var loss := pending_squad_loss
	pending_squad_loss = 0
	return loss


func _tick_approach(step: float) -> void:
	var dest := _squad_z - HOLD_DISTANCE
	z = move_toward(z, dest, APPROACH_SPEED * step)
	x = 0.0
	if absf(z - dest) <= 0.02:
		z = dest
		stage = Stage.FIGHT
		_next_skill_at = elapsed + OPENING_DELAY
	_refresh_center()


func _tick_stun(step: float) -> void:
	if stun_left <= 0.0:
		leaning = false
		weakpoint_glow = false
		return
	stun_left = maxf(0.0, stun_left - step)
	leaning = true
	weakpoint_glow = true
	if stun_left <= 0.0:
		leaning = false
		weakpoint_glow = false
		z = _squad_z - HOLD_DISTANCE


func _tick_contact(step: float, squad_x: float, squad_z: float, squad_count: int, squad_radius: float) -> void:
	_contact_ready -= step
	if not body_hits(squad_x, squad_z, squad_radius):
		return
	if _contact_ready > 0.0:
		return
	var loss := 2
	if archetype != null:
		loss = archetype.contact_loss
	pending_squad_loss += mini(loss, squad_count)
	var interval := 0.5
	if archetype != null:
		interval = archetype.contact_interval
	_contact_ready = interval


func _tick_skills(step: float, squad_x: float, squad_count: int, squad_radius: float) -> void:
	if telegraph.active:
		if telegraph.tick(step):
			_resolve_skill(squad_x, squad_count, squad_radius)
		return
	if stun_left > 0.0 or invulnerable_left > 0.0:
		return
	if elapsed + 0.0000001 < _next_skill_at:
		return
	_begin_skill(squad_x)


func _begin_skill(squad_x: float) -> void:
	_skill_started_at = elapsed
	var charge := _skill_flip % 2 == 1
	_skill_flip += 1
	if charge:
		telegraph.start_charge(squad_x, CHARGE_WARN)
	else:
		telegraph.start_slam(squad_x, SLAM_WARN)


func _resolve_skill(squad_x: float, squad_count: int, squad_radius: float) -> void:
	last_warning_duration = telegraph.elapsed
	last_safe_width = telegraph.safe_width()
	warning_kinds.append(telegraph.kind)
	warning_durations.append(telegraph.elapsed)
	warning_safe.append(telegraph.safe_width())
	var hit := telegraph.contains_squad(squad_x)
	if telegraph.kind == "charge":
		var impact_x := clampf(telegraph.aim_x, -PATROL_LIMIT, PATROL_LIMIT)
		var oz := 0.0 if archetype == null else archetype.offset_z
		# Put the offset-circle center on the squad's Z so the dash uses the full radius.
		var impact_z := _squad_z - oz
		x = impact_x
		z = impact_z
		last_charge_body_hit = charge_body_hits(impact_x, impact_z, squad_x, _squad_z, squad_radius)
		stun_left = STUN_TIME
		leaning = true
		weakpoint_glow = true
		if hit:
			pending_squad_loss += SkillTelegraph.percent_loss(squad_count, CHARGE_RATIO, CHARGE_MIN)
			skill_hits += 1
	elif hit:
		pending_squad_loss += SkillTelegraph.percent_loss(squad_count, SLAM_RATIO, SLAM_MIN)
		skill_hits += 1
	var earliest := _skill_started_at + skill_period()
	if stun_left > 0.0:
		earliest = maxf(earliest, elapsed + stun_left)
	_next_skill_at = earliest


func _should_phase(next_hp: float) -> bool:
	if stage != Stage.FIGHT or invulnerable_left > 0.0:
		return false
	if phase_index == 1 and next_hp <= hp_max * PHASE2_RATIO:
		return true
	if not mini_boss and phase_index == 2 and next_hp <= hp_max * PHASE3_RATIO:
		return true
	return false


func _next_threshold() -> float:
	if phase_index == 1:
		return PHASE2_RATIO
	return PHASE3_RATIO


func _begin_transition() -> void:
	phase_index += 1
	transition_count += 1
	invulnerable_left = TRANSITION_TIME
	stun_left = 0.0
	leaning = false
	weakpoint_glow = false
	if telegraph.active:
		telegraph.active = false
	supply_pending = true
	shake.add(PHASE_SHAKE)
	_next_skill_at = elapsed + TRANSITION_TIME + 0.2
	if summon_enabled and phase_index >= 2:
		summon_count += 30


func _on_hit_feedback(stunned: bool) -> void:
	if elapsed - _last_flash_at >= FLASH_GAP - 0.0001:
		flash_left = BOSS_FLASH
		_last_flash_at = elapsed
	if not stunned:
		return
	shake.add(WEAK_SHAKE)
	if clock == null:
		return
	if elapsed - _last_weak_stop_at < WEAK_HITSTOP_GAP - 0.0001:
		return
	clock.hit_stop(WEAK_HITSTOP_MS)
	_last_weak_stop_at = elapsed


func _show_number(dealt: float, stunned: bool) -> void:
	if dealt <= 0.0:
		numbers.last_shown = false
		return
	var color := DamageNumbers.ORANGE if stunned else DamageNumbers.WHITE
	numbers.push(dealt, color)


func _die() -> void:
	hp = 0.0
	stage = Stage.DEAD
	victorious = true
	stun_left = 0.0
	leaning = false
	weakpoint_glow = false
	if telegraph.active:
		telegraph.active = false
	shake.add(DEATH_SHAKE)
	if clock != null:
		clock.slow_motion(SLOW_FACTOR, SLOW_TIME)


func _hold_line(step: float) -> void:
	var dest := _squad_z - HOLD_DISTANCE
	z = move_toward(z, dest, APPROACH_SPEED * step)


func _patrol(step: float) -> void:
	x += _patrol_dir * PATROL_SPEED * step
	if x >= PATROL_LIMIT:
		x = PATROL_LIMIT
		_patrol_dir = -1.0
	elif x <= -PATROL_LIMIT:
		x = -PATROL_LIMIT
		_patrol_dir = 1.0
	z = _squad_z - HOLD_DISTANCE


func _refresh_center() -> void:
	var ox := 0.0
	var oz := 0.0
	if archetype != null:
		ox = archetype.offset_x
		oz = archetype.offset_z
		collision_radius = archetype.collision_radius
	center_x = x + ox
	center_z = z + oz
