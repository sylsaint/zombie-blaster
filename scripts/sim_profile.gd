class_name SimProfile
extends RefCounted
## Per-frame microsecond counters. Stress test samples these for avg and p99.


var squad_us: int = 0
var hash_rebuild_us: int = 0
var hash_query_us: int = 0
var bullet_us: int = 0
var combat_us: int = 0
var view_write_us: int = 0
var view_upload_us: int = 0
var view_us: int = 0
var overlay_us: int = 0
var process_us: int = 0


func reset_frame() -> void:
	squad_us = 0
	hash_rebuild_us = 0
	hash_query_us = 0
	bullet_us = 0
	combat_us = 0
	view_write_us = 0
	view_upload_us = 0
	view_us = 0
	overlay_us = 0
	process_us = 0
