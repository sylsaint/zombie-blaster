class_name LevelUpDirector
extends Node
## Ramps GameClock to 0, then shows one offer at a time.
## Never writes Engine.time_scale and never pauses the tree.


const RAMP_SEC := 0.15
const PHASE_IDLE := 0
const PHASE_RAMPING := 1
const PHASE_SHOWING := 2

var phase: int = PHASE_IDLE
var sim: CombatSim
var clock: Node
var _layer: CanvasLayer
var _view: Node
var _offer := PackedInt32Array()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(combat: CombatSim, game_clock: Node) -> void:
	sim = combat
	clock = game_clock
	if _layer != null:
		return
	_layer = CanvasLayer.new()
	_layer.layer = 30
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var view: Node = load("res://scenes/ui/card_select.tscn").instantiate()
	view.process_mode = Node.PROCESS_MODE_ALWAYS
	view.connect("card_picked", _on_pick)
	(view as Control).set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view = view
	_layer.add_child(_view)
	add_child(_layer)


func card_view() -> Control:
	return _view as Control


func current_offer() -> PackedInt32Array:
	return _offer


func choose(index: int) -> void:
	_on_pick(index)


func _process(_delta: float) -> void:
	if sim == null or clock == null or phase == PHASE_SHOWING:
		return
	if phase == PHASE_IDLE and sim.xp.pending > 0:
		clock.ramp_to_zero(RAMP_SEC)
		phase = PHASE_RAMPING
	if phase == PHASE_RAMPING and clock.ramp_complete() and clock.hit_stop_remaining() <= 0.0:
		_open()


func _open() -> void:
	while true:
		var first := sim.xp.offers_opened == 0
		_offer = sim.roller.roll(sim.skills, first)
		sim.xp.offers_opened += 1
		if not _offer.is_empty():
			break
		sim.xp.take_offer()
		if sim.xp.pending <= 0:
			_close()
			return
	phase = PHASE_SHOWING
	var titles := PackedStringArray()
	var details := PackedStringArray()
	titles.resize(_offer.size())
	details.resize(_offer.size())
	var i := 0
	while i < _offer.size():
		var id := _offer[i]
		var card := sim.skills.cards[id]
		var level := sim.skills.card_level(id)
		titles[i] = _heading(card, level)
		details[i] = _detail(card, level)
		i += 1
	_view.present(titles, details)


func _on_pick(index: int) -> void:
	if phase != PHASE_SHOWING:
		return
	if index < 0 or index >= _offer.size():
		return
	sim.skills.apply(_offer[index], sim.squad)
	sim.xp.take_offer()
	if sim.xp.pending > 0:
		_open()
		return
	_close()


func _close() -> void:
	if _view != null:
		_view.dismiss()
	if clock != null:
		clock.restore()
	phase = PHASE_IDLE
	_offer = PackedInt32Array()


func _heading(card: SkillCard, level: int) -> String:
	if card.max_level < 0:
		return "%s\n立刻 +%d 人" % [card.title, int(round(card.magnitude))]
	return "%s\nLv %d / %d" % [card.title, level, card.max_level]


func _detail(card: SkillCard, level: int) -> String:
	var nxt := level + 1
	match card.effect_id:
		SkillCard.SPLIT:
			return "下一级命中分裂 %d 发\n各 %d%% 伤害，±%d°" % [nxt + 1, int(round(card.magnitude * 100.0)), int(round(card.spread_degrees))]
		SkillCard.PIERCE:
			return "下一级穿透 +%d\n当前 +%d" % [int(card.magnitude), int(card.magnitude) * level]
		SkillCard.BURST:
			return "下一级每次发射 +%d\n当前额外 %d 发" % [int(card.magnitude), int(card.magnitude) * level]
		SkillCard.RAPID:
			var step := int(round(card.magnitude * 100.0))
			return "下一级射速 +%d%%\n当前 +%d%%" % [step, step * level]
		SkillCard.POWER:
			var power := int(round(card.magnitude * 100.0))
			return "下一级伤害 +%d%%\n当前 +%d%%" % [power, power * level]
		_:
			return card.blurb
