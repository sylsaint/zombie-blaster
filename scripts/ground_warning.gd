class_name GroundWarning
extends RefCounted
## Pooled ground telegraphs. Boss skills can reuse the same records.
## Each sample stores gameplay time from arming the quad to the hit frame.


const CAP := 8
const LANE_HALF := 3.75
const SAMPLE_CAP := 32

var active := PackedInt32Array()
var age := PackedFloat32Array()
var duration := PackedFloat32Array()
var x0 := PackedFloat32Array()
var x1 := PackedFloat32Array()
var safe_width := PackedFloat32Array()
var owner := PackedInt32Array()

var sample_n: int = 0
var _sample_cursor: int = 0
var samples := PackedFloat32Array()
var last_safe_width: float = 0.0
var last_safe_ok: bool = false
var impacts: int = 0


func _init() -> void:
	active.resize(CAP)
	age.resize(CAP)
	duration.resize(CAP)
	x0.resize(CAP)
	x1.resize(CAP)
	safe_width.resize(CAP)
	owner.resize(CAP)
	owner.fill(-1)
	samples.resize(SAMPLE_CAP)


static func safe_lane_width() -> float:
	return LANE_HALF


static func covers_squad(px: float) -> bool:
	return true if px >= -LANE_HALF and px <= LANE_HALF else false


static func squad_fits(formation_diameter: float) -> bool:
	return safe_lane_width() + 0.0001 >= formation_diameter


## Locks the half-lane the squad occupies right now. Returns -1 when the pool is full.
func begin_half_lane(squad_x: float, telegraph: float, owner_id: int = -1) -> int:
	var slot := -1
	var i := 0
	while i < CAP:
		if active[i] == 0:
			slot = i
			break
		i += 1
	if slot < 0:
		return -1
	var xmin: float
	var xmax: float
	if squad_x >= 0.0:
		xmin = 0.0
		xmax = LANE_HALF
	else:
		xmin = -LANE_HALF
		xmax = 0.0
	active[slot] = 1
	age[slot] = 0.0
	duration[slot] = maxf(telegraph, 0.0)
	x0[slot] = xmin
	x1[slot] = xmax
	safe_width[slot] = LANE_HALF
	owner[slot] = owner_id
	return slot


func is_active(slot: int) -> bool:
	return slot >= 0 and slot < CAP and active[slot] != 0


## Ages telegraphs. Impacts count zones whose locked X still contains the squad.
func tick(dt: float, squad_x: float, formation_diameter: float) -> int:
	impacts = 0
	if dt <= 0.0:
		return 0
	var i := 0
	while i < CAP:
		if active[i] == 0:
			i += 1
			continue
		age[i] += dt
		if age[i] + 0.0000001 < duration[i]:
			i += 1
			continue
		_record(age[i])
		last_safe_width = safe_width[i]
		last_safe_ok = last_safe_width + 0.0001 >= formation_diameter
		if squad_x >= x0[i] and squad_x <= x1[i]:
			impacts += 1
		active[i] = 0
		i += 1
	return impacts


func min_telegraph() -> float:
	if sample_n <= 0:
		return -1.0
	var m := samples[0]
	var i := 1
	while i < sample_n:
		m = minf(m, samples[i])
		i += 1
	return m


func active_count() -> int:
	var n := 0
	for flag in active:
		if flag != 0:
			n += 1
	return n


func _record(seconds: float) -> void:
	if sample_n < SAMPLE_CAP:
		samples[sample_n] = seconds
		sample_n += 1
		return
	samples[_sample_cursor] = seconds
	_sample_cursor = (_sample_cursor + 1) % SAMPLE_CAP
