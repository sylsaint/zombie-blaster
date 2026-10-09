class_name StageTable
extends Resource
## Chapter 1 combat numbers from docs/design/progression.md.
## Index 0 is stage 1.


@export var grunt_hp_multiplier: PackedFloat32Array = PackedFloat32Array()
@export var elite_hp: PackedFloat32Array = PackedFloat32Array()


func grunt_multiplier(stage: int) -> float:
	if grunt_hp_multiplier.is_empty():
		return 1.0
	var idx := clampi(stage, 1, grunt_hp_multiplier.size()) - 1
	return grunt_hp_multiplier[idx]


func elite_hp_for(stage: int) -> float:
	if elite_hp.is_empty():
		return 4800.0
	var idx := clampi(stage, 1, elite_hp.size()) - 1
	return elite_hp[idx]
