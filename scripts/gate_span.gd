class_name GateSpan
extends Resource
## One leaf of a gate group. x is inclusive on both ends; the picker breaks ties.


@export var kind: int = 1
@export var amount: float = 1.0
@export var x_min: float = -3.75
@export var x_max: float = 3.75
@export var shootable: bool = false
## Signed number painted on a shootable gate. Negative plays as subtract.
@export var value: float = 0.0

var damage_bank: float = 0.0
var locked: bool = false
var visual_dirty: bool = true


func resolved_kind() -> int:
	if shootable:
		if value > 0.0:
			return GateRules.ADD
		return GateRules.SUBTRACT
	return kind


func resolved_amount() -> float:
	if shootable:
		return absf(value)
	return amount
