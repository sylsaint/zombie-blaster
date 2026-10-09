class_name EnemyCatalog
extends RefCounted
## Loads enemy prototypes once. Hot paths read the cached resources.


const WALKER_PATH := "res://data/enemies/enm_walker_a.tres"
const RUNNER_PATH := "res://data/enemies/enm_runner_a.tres"
const ELITE_PATH := "res://data/enemies/enm_elite_brute.tres"
const BOSS_PATH := "res://data/enemies/boss_mutant.tres"
const STAGE_PATH := "res://data/stages/chapter1_combat.tres"

static var _walker: EnemyArchetype
static var _runner: EnemyArchetype
static var _elite: EnemyArchetype
static var _boss: EnemyArchetype
static var _stages: StageTable


static func walker() -> EnemyArchetype:
	if _walker == null:
		_walker = load(WALKER_PATH) as EnemyArchetype
	return _walker


static func runner() -> EnemyArchetype:
	if _runner == null:
		_runner = load(RUNNER_PATH) as EnemyArchetype
	return _runner


static func elite() -> EnemyArchetype:
	if _elite == null:
		_elite = load(ELITE_PATH) as EnemyArchetype
	return _elite


static func boss() -> EnemyArchetype:
	if _boss == null:
		_boss = load(BOSS_PATH) as EnemyArchetype
	return _boss


static func stages() -> StageTable:
	if _stages == null:
		_stages = load(STAGE_PATH) as StageTable
	return _stages


static func hit_points(arch: EnemyArchetype, stage: int) -> float:
	if arch.kind == EnemyArchetype.KIND_ELITE:
		return stages().elite_hp_for(stage)
	return arch.base_hp * stages().grunt_multiplier(stage)


static func place(pool: EnemyPool, arch: EnemyArchetype, stage: int, px: float, pz: float, variant: float = -1.0) -> int:
	var color := arch.color_variant if variant < 0.0 else variant
	return pool.spawn(
		arch.kind,
		px,
		pz,
		hit_points(arch, stage),
		arch.speed,
		arch.radius,
		color,
		arch.species,
		arch.weight,
		arch.xp,
		arch.gold,
		1 if arch.grants_offer else 0,
		arch.near_speed,
		arch.near_distance,
		arch.touch_damage,
		arch.touch_period,
		arch.slam_interval,
		arch.warn_time
	)
