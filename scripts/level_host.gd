class_name LevelHost
extends Node
## Loads chapter-1 levels for the game scene. A run starts only from start_level,
## so the greybox boot stays quiet. Meta attack is the squad's existing input
## and is not folded into the gate or skill bonus.


var levels: Array[LevelData] = []
var session: LevelSession
var boss_view: BossView
var _running: bool = false


func _ready() -> void:
	levels = LevelCatalog.load_all()


func start_level(level_index: int, meta_attack_levels: int = 0) -> void:
	if boss_view != null and is_instance_valid(boss_view):
		boss_view.queue_free()
	boss_view = null
	var level := LevelCatalog.load_index(level_index)
	session = LevelSession.new()
	session.start(level, get_node("/root/GameClock"))
	session.sim.squad.meta_attack_levels = clampi(meta_attack_levels, 0, WeaponMods.META_ATTACK_CAP)
	_running = true


func _process(_delta: float) -> void:
	if not _running or session == null:
		return
	var clock := get_node("/root/GameClock")
	session.tick(float(clock.gameplay_delta))
	_sync_boss_view()
	if session.result != null:
		_running = false


func _sync_boss_view() -> void:
	if session.boss == null:
		return
	if boss_view == null:
		boss_view = BossView.new()
		boss_view.name = "BossView"
		add_child(boss_view)
		boss_view.setup(session.boss)
	boss_view.bind(session.boss)
	boss_view.sync()
