class_name SkillTelegraph
extends RefCounted
## Ground warning shared by elite and boss skills.
## Duration is measured from start to the resolution frame.


const LANE_LEFT := -3.75
const LANE_RIGHT := 3.75
const LANE_WIDTH := 7.5
const CHARGE_WIDTH := 2.5
const SLAM_HALF := 3.75

var kind: String = ""
var duration: float = 0.0
var elapsed: float = 0.0
var aim_x: float = 0.0
var active: bool = false
var half_width: float = 0.0


static func percent_loss(count: int, ratio: float, minimum: int) -> int:
	if count <= 0:
		return 0
	var scaled := int(round(float(count) * ratio))
	return mini(count, maxi(scaled, minimum))


func start_slam(squad_x: float, warn_seconds: float) -> void:
	kind = "slam"
	duration = warn_seconds
	elapsed = 0.0
	aim_x = squad_x
	half_width = SLAM_HALF
	active = true


func start_charge(squad_x: float, warn_seconds: float) -> void:
	kind = "charge"
	duration = warn_seconds
	elapsed = 0.0
	aim_x = squad_x
	half_width = CHARGE_WIDTH * 0.5
	active = true


## Advances the warning. Returns true on the frame it resolves.
func tick(dt: float) -> bool:
	if not active:
		return false
	elapsed += maxf(dt, 0.0)
	if elapsed + 0.0000001 < duration:
		return false
	active = false
	return true


func contains_squad(squad_x: float) -> bool:
	if kind == "charge":
		return absf(squad_x - aim_x) <= half_width + 0.0001
	if aim_x >= 0.0:
		return squad_x >= 0.0
	return squad_x < 0.0


## Width of lane that is outside the danger zone at resolution.
func safe_width() -> float:
	if kind == "slam":
		return SLAM_HALF
	var left := aim_x - half_width
	var right := aim_x + half_width
	var covered := minf(right, LANE_RIGHT) - maxf(left, LANE_LEFT)
	return LANE_WIDTH - maxf(covered, 0.0)


## A lane X outside this warning, clamped to the squad's playable inset.
func dodge_x(lane_limit: float) -> float:
	if kind == "charge":
		var side := -1.0 if aim_x >= 0.0 else 1.0
		return clampf(aim_x + side * (half_width + 0.8), -lane_limit, lane_limit)
	if aim_x >= 0.0:
		return -minf(2.0, lane_limit)
	return minf(2.0, lane_limit)
