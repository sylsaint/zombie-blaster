class_name CasualtyPool
extends RefCounted
## Soldiers removed by contact play a short dissolve on their own MultiMesh.


const CAP := 8

var x := PackedFloat32Array()
var z := PackedFloat32Array()
var life := PackedFloat32Array()
var active := PackedInt32Array()
var live_count: int = 0


func _init() -> void:
	x.resize(CAP)
	z.resize(CAP)
	life.resize(CAP)
	active.resize(CAP)


func clear() -> void:
	active.fill(0)
	live_count = 0


func spawn_around(squad: SquadAnchor, loss: int) -> void:
	if loss <= 0:
		return
	var offsets := squad.displayed_offsets
	var n := mini(loss, CAP)
	var placed := 0
	var slot := 0
	while slot < CAP and placed < n:
		if active[slot] == 0:
			var idx := offsets.size() - 1 - placed
			var ox := 0.0
			var oz := 0.0
			if idx >= 0 and idx < offsets.size():
				ox = offsets[idx].x
				oz = offsets[idx].z
			x[slot] = squad.position.x + ox
			z[slot] = squad.position.z + oz
			life[slot] = EnemyPool.DISSOLVE_TIME
			active[slot] = 1
			live_count += 1
			placed += 1
		slot += 1


func tick(dt: float) -> void:
	if dt <= 0.0 or live_count <= 0:
		return
	var i := 0
	while i < CAP:
		if active[i] != 0:
			life[i] -= dt
			if life[i] <= 0.0:
				active[i] = 0
				live_count -= 1
		i += 1
