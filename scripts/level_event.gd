class_name LevelEvent
extends Resource
## One Z-ordered level beat. `distance` is meters the squad has traveled.


@export var distance: float = 0.0
@export var kind: String = "wave"
@export var enemy_id: String = ""
@export var count: int = 0
@export var formation: String = "line"
@export var gates: Array[GateSpec]


func _init() -> void:
	gates = []
