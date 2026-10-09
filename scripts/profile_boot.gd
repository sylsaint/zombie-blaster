extends Node
## Exported profile builds set the feature tag "profile".
## Those builds open the stress scene instead of the game.


func _ready() -> void:
	if OS.has_feature("profile"):
		get_tree().call_deferred("change_scene_to_file", "res://scenes/debug/stress_test.tscn")
