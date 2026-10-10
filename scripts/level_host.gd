class_name LevelHost
extends Node
## Loads chapter-1 levels for the game scene. A run starts only from start_level,
## so the greybox boot stays quiet. Meta attack is the squad's existing input
## and is not folded into the gate or skill bonus.
##
## The fight itself is the existing CombatSim. This node only presents it:
## CrowdView (the stress-scene MultiMeshes), GateView, and the chase camera.


const RAIL_X := 3.75
const MENU_SQUAD := 5

var levels: Array[LevelData] = []
var session: LevelSession
var boss_view: BossView
var crowd: CrowdView
var gates: GateView
var gate_groups: Array = []
var _running: bool = false
var _menu_lane: bool = false
var _menu_present_queued: bool = false
var _menu_no_squad_logged: bool = false


func _ready() -> void:
	levels = LevelCatalog.load_all()
	present_menu_lane()


func running() -> bool:
	return _running


func present_menu_lane() -> void:
	# Launch-crash control. CrowdView.setup loads the walker RGBA16F VAT and
	# compiles the vertex shader that texelFetch-es it. Skipping here leaves
	# that texture and those materials unloaded for the whole menu.
	if _cmdline_has("--menu-no-squad"):
		if not _menu_no_squad_logged:
			_menu_no_squad_logged = true
			print("MENU_NO_SQUAD")
		return
	var parent := get_parent()
	if parent == null or parent.get_node_or_null("Player") == null:
		return
	# Main is still entering the tree during the first _ready. Adding the
	# crowd then is refused, so the menu lane is built on the next idle frame.
	if not parent.is_node_ready():
		if not _menu_present_queued:
			_menu_present_queued = true
			present_menu_lane.call_deferred()
		return
	_menu_present_queued = false
	_menu_lane = true
	_hide_placeholder()
	_ensure_views()
	if boss_view != null and is_instance_valid(boss_view):
		boss_view.queue_free()
		boss_view = null
	if gates != null:
		gates.build([])
	if crowd != null:
		crowd.clear_draws()
	_restore_menu_frame()
	_sync_menu_squad()


func start_level(level_index: int, meta_attack_levels: int = 0) -> void:
	_menu_lane = false
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
	if _running and session != null:
		var clock := get_node("/root/GameClock")
		session.tick(float(clock.gameplay_delta))
		_sync_view()
		if session.result != null:
			_running = false
		return
	if _menu_lane:
		_sync_menu_squad()


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
	if crowd != null and is_instance_valid(crowd) and crowd.is_inside_tree():
		return
	var parent := get_parent()
	if parent == null:
		return
	if crowd != null and is_instance_valid(crowd):
		crowd.free()
	crowd = CrowdView.new()
	crowd.name = "Crowd"
	parent.add_child(crowd)
	if not crowd.is_inside_tree():
		crowd.free()
		crowd = null
		return
	crowd.setup()
	if gates != null and is_instance_valid(gates) and not gates.is_inside_tree():
		gates.free()
		gates = null
	if gates == null or not is_instance_valid(gates):
		gates = GateView.new()
		gates.name = "Gates"
		parent.add_child(gates)
		if not gates.is_inside_tree():
			gates.free()
			gates = null


func _present_gates(level: LevelData) -> void:
	gate_groups = groups_from_level(level)
	if gates != null:
		gates.build(gate_groups)


func _cmdline_has(needle: String) -> bool:
	for arg in OS.get_cmdline_user_args():
		if arg.contains(needle):
			return true
	for arg in OS.get_cmdline_args():
		if arg.contains(needle):
			return true
	return false


func _sync_menu_squad() -> void:
	if crowd == null:
		return
	crowd.show_idle_squad(_menu_points())


## The title panel covers the middle of the lane. The outer soldiers stand in the
## strips beside it; the middle one keeps the old capsule's spot.
func _menu_points() -> PackedVector3Array:
	var origin := _menu_origin()
	var side := 3.15
	var pts := PackedVector3Array()
	pts.append(Vector3(origin.x - side, 0.0, origin.z + 1.05))
	pts.append(Vector3(origin.x - side, 0.0, origin.z - 0.15))
	pts.append(Vector3(origin.x, 0.0, origin.z + 0.45))
	pts.append(Vector3(origin.x + side, 0.0, origin.z + 1.05))
	pts.append(Vector3(origin.x + side, 0.0, origin.z - 0.15))
	return pts


func _menu_origin() -> Vector3:
	var parent := get_parent()
	if parent == null:
		return Vector3.ZERO
	var player := parent.get_node_or_null("Player") as Node3D
	if player == null:
		return Vector3.ZERO
	return player.global_position


func _restore_menu_frame() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var camera := parent.get_node_or_null("ChaseCamera") as Camera3D
	if camera != null:
		camera.position = Vector3(0.0, 8.5, 12.0)
		camera.look_at(Vector3(0.0, 1.0, -18.0), Vector3.UP)
	for node_name in ["Ground", "CenterStripe", "RailLeft", "RailRight"]:
		var mesh := parent.get_node_or_null(node_name) as Node3D
		if mesh != null:
			mesh.position.z = -20.0


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
