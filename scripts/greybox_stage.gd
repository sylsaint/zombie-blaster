extends Node3D
## Places the rear-top camera and an unshadowed sun. No gameplay.


func _ready() -> void:
	var camera := $ChaseCamera as Camera3D
	camera.look_at(Vector3(0.0, 1.0, -18.0), Vector3.UP)
	var sun := $Sun as DirectionalLight3D
	sun.rotation_degrees = Vector3(-55.0, -25.0, 0.0)
	sun.shadow_enabled = false
