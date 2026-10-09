extends Node
## Gameplay clock. Movement, VAT frames, bullets, flash, and dissolve read
## gameplay_delta. UI, tweens, and camera shake keep using the real delta.
## This never writes Engine.time_scale.


var scale: float = 1.0
var gameplay_delta: float = 0.0
var gameplay_time: float = 0.0
var real_time: float = 0.0

var _hit_stop_left: float = 0.0
var _slow_factor: float = 1.0
var _slow_left: float = 0.0
var _ramping: bool = false
var _ramp_from: float = 1.0
var _ramp_duration: float = 0.0
var _ramp_elapsed: float = 0.0


func _ready() -> void:
	# Lower priority runs first, so scenes can read this frame's gameplay_delta.
	process_priority = -128


func _process(delta: float) -> void:
	advance(delta)


func hit_stop(ms: float) -> void:
	var seconds := maxf(ms, 0.0) * 0.001
	if seconds > _hit_stop_left:
		_hit_stop_left = seconds
	if _hit_stop_left > 0.0:
		scale = 0.0


func hit_stop_remaining() -> float:
	return _hit_stop_left


func slow_motion(factor: float, duration: float) -> void:
	_slow_factor = factor
	_slow_left = maxf(duration, 0.0)
	if not _ramping and _hit_stop_left <= 0.0:
		scale = _motion_scale()


func ramp_to_zero(duration: float) -> void:
	var from := _motion_scale()
	_ramping = true
	_ramp_from = from
	_ramp_duration = maxf(duration, 0.0)
	_ramp_elapsed = 0.0
	scale = from


func restore() -> void:
	_ramping = false
	_ramp_elapsed = 0.0
	_ramp_duration = 0.0
	_ramp_from = 1.0
	_slow_left = 0.0
	_slow_factor = 1.0
	scale = 0.0 if _hit_stop_left > 0.0 else 1.0


## Steps the clock by a real-time delta and returns the gameplay delta.
func advance(real_delta: float) -> float:
	if real_delta < 0.0:
		real_delta = 0.0
	real_time += real_delta
	var left := real_delta
	if _hit_stop_left > 0.0 and left > 0.0:
		var frozen := minf(_hit_stop_left, left)
		_hit_stop_left -= frozen
		left -= frozen
	var produced := 0.0
	if left > 0.0:
		produced = _integrate_motion(left)
	gameplay_delta = produced
	gameplay_time += produced
	if _hit_stop_left > 0.0 and left <= 0.0:
		scale = 0.0
	else:
		scale = _motion_scale()
	return produced


func _motion_scale() -> float:
	if _ramping:
		if _ramp_duration <= 0.0:
			return 0.0
		var u := clampf(_ramp_elapsed / _ramp_duration, 0.0, 1.0)
		return _ramp_from * (1.0 - u)
	if _slow_left > 0.0:
		return _slow_factor
	return 1.0


func _integrate_motion(dt: float) -> float:
	if _ramping:
		var dur := _ramp_duration
		if dur <= 0.0:
			return 0.0
		var t0 := _ramp_elapsed
		var t1 := minf(t0 + dt, dur)
		var integral := _ramp_from * ((t1 - t0) - (t1 * t1 - t0 * t0) / (2.0 * dur))
		_ramp_elapsed = t1
		return maxf(integral, 0.0)
	if _slow_left > 0.0:
		var slow_dt := minf(dt, _slow_left)
		var rest := dt - slow_dt
		_slow_left -= slow_dt
		if _slow_left < 0.0000001:
			_slow_left = 0.0
		return slow_dt * _slow_factor + rest
	return dt
