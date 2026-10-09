extends Label
## Red "-N" for a squad loss. The combat sim only stores the amount.


var squad: SquadAnchor
var _seen: int = -1


func bind_squad(anchor: SquadAnchor) -> void:
	squad = anchor
	_seen = -1 if anchor == null else anchor.loss_serial


func show_amount(amount: int) -> void:
	text = "-%d" % maxi(amount, 0)
	visible = amount > 0


func _process(_delta: float) -> void:
	if squad == null or squad.loss_serial == _seen:
		return
	_seen = squad.loss_serial
	show_amount(squad.last_loss)
