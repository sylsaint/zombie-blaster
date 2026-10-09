class_name GateSpec
extends Resource
## One lane choice inside a level event. Kind values are GateRules' five M1 types.


@export var kind: int = GateRules.ADD
@export var amount: float = 0.0
@export var side: String = "left"


func is_buff() -> bool:
	return GateRules.is_benefit(kind, amount)


func contains_x(squad_x: float) -> bool:
	if side == "full":
		return true
	if side == "left":
		return squad_x < 0.0
	return squad_x >= 0.0
