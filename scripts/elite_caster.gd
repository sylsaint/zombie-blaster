class_name EliteCaster
extends RefCounted
## Armored brute slam. Warning length and half-lane zone match enemies.md.


const PERIOD := 4.0
const WARN := 1.0
const RATIO := 0.20
const MINIMUM := 3

var telegraph := SkillTelegraph.new()
var cooldown: float = PERIOD
var pending_loss: int = 0
var skill_hits: int = 0
var warning_durations := PackedFloat32Array()
var warning_safe := PackedFloat32Array()
var active: bool = false


func tick(dt: float, squad_x: float, squad_count: int) -> void:
	if not active:
		return
	if telegraph.active:
		if telegraph.tick(dt):
			warning_durations.append(telegraph.elapsed)
			warning_safe.append(telegraph.safe_width())
			if telegraph.contains_squad(squad_x):
				pending_loss += SkillTelegraph.percent_loss(squad_count, RATIO, MINIMUM)
				skill_hits += 1
		return
	cooldown -= maxf(dt, 0.0)
	if cooldown <= 0.0:
		telegraph.start_slam(squad_x, WARN)
		cooldown = PERIOD


func take_loss() -> int:
	var loss := pending_loss
	pending_loss = 0
	return loss
