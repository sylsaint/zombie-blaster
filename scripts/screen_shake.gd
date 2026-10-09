class_name ScreenShake
extends RefCounted
## Trauma shake. Decays on real time so a hit-stop does not freeze the camera.


var trauma: float = 0.0
var enabled: bool = true


func add(amount: float) -> void:
	if not enabled:
		return
	trauma = minf(trauma + maxf(amount, 0.0), 1.0)


func tick(real_dt: float) -> void:
	trauma = maxf(0.0, trauma - 1.5 * maxf(real_dt, 0.0))


func offset_meters() -> float:
	if not enabled:
		return 0.0
	return trauma * trauma * 0.35
