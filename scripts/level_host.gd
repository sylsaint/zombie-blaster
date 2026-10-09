class_name LevelHost
extends Node
## Loads chapter-1 levels for the game scene. A run starts only from start_level,
## so the greybox boot stays quiet. Meta attack is the squad's existing input
## and is not folded into the gate or skill bonus.
##
## The fight itself is the existing CombatSim. This node only presents it:
## CrowdView (the stress-scene MultiMeshes), GateView, and the chase camera.


const RAIL_X := 3.75

var levels: Array[LevelData] = []
var session: LevelSession
var boss_view: BossView
var crowd: CrowdView
var gates: GateView
var gate_groups: Array = []
var _running: bool = false


func _ready() -> void:
	levels = LevelCatalog.load_all()


func running() -> bool:
	return _running


func start_level(level_index: int, meta_attack_levels: int = 0) -> void:
	if boss_view != null and is_instance_valid(boss_view):
		boss_view.queue_free()
	boss_view = null
	var level := LevelCatalog.load_index(level_index)
	session = LevelSession.new()
	session.start(level, get_node("/root/GameClock"))
	session.sim.squad.meta_attack_levels = clampi(meta_attack_levels, 0, WeaponMods.META_ATTACK_CAP)
	_ensure_views()
	_hide_placeholder()
	_present_gates(level)
	_running = true
	_sync_view()


func _process(_delta: float) -> void:
	if not _running or session == null:
		return
	var clock := get_node("/root/GameClock")
	session.tick(float(clock.gameplay_delta))
	_sync_view()
	if session.result != null:
		_running = false


static func groups_from_level(level: LevelData) -> Array:
	var groups: Array = []
	if level == null:
		return groups
	for event in level.sorted_events():
		if event.kind != "gate_group":
			continue
		var group := GateGroup.new()
		group.z = -event.distance
		for spec in event.gates:
			group.spans.append(span_for_spec(spec))
		groups.append(group)
	return groups


static func span_for_spec(spec: GateSpec) -> GateSpan:
	var span := GateSpan.new()
	if spec == null:
		return span
	span.kind = spec.kind
	span.amount = spec.amount
	# Same half-lane split GateSpec.contains_x uses. x = 0 belongs to the right gate.
	if spec.side == "full":
		span.x_min = -RAIL_X
		span.x_max = RAIL_X
	elif spec.side == "left":
		span.x_min = -RAIL_X
		span.x_max = 0.0
	else:
		span.x_min = 0.0
		span.x_max = RAIL_X
	return span


func _ensure_views() -> void:
	if crowd != null and is_instance_valid(crowd):
		return
	var parent := get_parent()
	if parent == null:
		return
	crowd = CrowdView.new()
	crowd.name = "Crowd"
	parent.add_child(crowd)
	crowd.setup()
	gates = GateView.new()
	gates.name = "Gates"
	parent.add_child(gates)


func _present_gates(level: LevelData) -> void:
	gate_groups = groups_from_level(level)
	if gates != null:
		gates.build(gate_groups)


func _hide_placeholder() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var player := parent.get_node_or_null("Player")
	if player == null:
		return
	for child_name in ["Body", "BlobShadow"]:
		var mesh := player.get_node_or_null(child_name) as GeometryInstance3D
		if mesh != null:
			mesh.visible = false


func _sync_view() -> void:
	if session == null or session.sim == null:
		return
	if crowd != null:
		crowd.sync(session.sim)
	if gates != null:
		gates.refresh()
	_follow_squad()
	_sync_boss_view()


func _follow_squad() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var anchor := session.sim.squad.position
	var camera := parent.get_node_or_null("ChaseCamera") as Camera3D
	if camera != null:
		camera.position = Vector3(0.0, 8.5, anchor.z + 12.0)
		camera.look_at(Vector3(0.0, 1.0, anchor.z - 16.0), Vector3.UP)
	for node_name in ["Ground", "CenterStripe", "RailLeft", "RailRight"]:
		var mesh := parent.get_node_or_null(node_name) as Node3D
		if mesh != null:
			mesh.position.z = anchor.z - 20.0


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
