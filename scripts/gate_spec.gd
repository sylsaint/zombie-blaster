class_name GateSpec
extends Resource
## One lane gate. `side` is left, right, or full.


@export var gate_type: String = "add"
@export var amount: float = 0.0
@export var side: String = "left"


func is_buff() -> bool:
	return gate_type == "add" or gate_type == "multiply" or gate_type == "weapon" or gate_type == "fire_rate"


func contains_x(squad_x: float) -> bool:
	if side == "full":
		return true
	if side == "left":
		return squad_x < 0.0
	return squad_x >= 0.0
