class_name VatClipset
extends RefCounted
## zb-vat-1 clip table loaded from assets/models/anim/<mesh>_vat.json.
## A missing json or EXR means the mesh stays on the static rest pose.


const CROSSFADE_FRAMES := 2.5
## Spec: playback 1.0 matches about 0.4 m/s. Faster walkers step faster.
const WALK_REF_SPEED := 0.4
const AABB_MARGIN := 0.05

var texture: Texture2D
var width: int = 0
var height: int = 0
var rows_per_frame: int = 1
var fps: float = 30.0
var walk_start: float = 0.0
var walk_count: float = 1.0
var hit_start: float = 0.0
var hit_count: float = 1.0
var death_start: float = 0.0
var death_count: float = 1.0
var anim_aabb: AABB = AABB()


static func for_model(mesh_path: String) -> VatClipset:
	if mesh_path.is_empty():
		return null
	var stem := mesh_path.get_file().get_basename()
	var json_path := "res://assets/models/anim/%s_vat.json" % stem
	if not FileAccess.file_exists(json_path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(json_path))
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	var data: Dictionary = parsed
	var tex_path := str(data.get("texture", ""))
	if tex_path.is_empty():
		return null
	if not tex_path.begins_with("res://"):
		tex_path = "res://" + tex_path
	if not ResourceLoader.exists(tex_path):
		return null
	var tex := load(tex_path) as Texture2D
	if tex == null:
		return null
	var clips: Dictionary = data.get("clips", {})
	if not clips.has("walk") or not clips.has("hit") or not clips.has("death"):
		return null
	var clip := VatClipset.new()
	clip.texture = tex
	clip.width = int(data.get("width", 0))
	clip.height = int(data.get("height", 0))
	clip.rows_per_frame = maxi(int(data.get("rows_per_frame", 1)), 1)
	clip.fps = float(data.get("fps", 30.0))
	clip.walk_start = _start(clips["walk"])
	clip.walk_count = _count(clips["walk"])
	clip.hit_start = _start(clips["hit"])
	clip.hit_count = _count(clips["hit"])
	clip.death_start = _start(clips["death"])
	clip.death_count = _count(clips["death"])
	clip.anim_aabb = _aabb(data.get("aabb", {}))
	return clip


func padded_aabb() -> AABB:
	return anim_aabb.grow(AABB_MARGIN)


func apply_to(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("vat_enabled", 1.0)
	mat.set_shader_parameter("vat_positions", texture)
	mat.set_shader_parameter("vat_rows_per_frame", float(rows_per_frame))
	mat.set_shader_parameter("vat_walk", Vector4(walk_start, walk_count, 1.0, 0.0))
	mat.set_shader_parameter("vat_hit", Vector4(hit_start, hit_count, 0.0, 0.0))
	mat.set_shader_parameter("vat_death", Vector4(death_start, death_count, 0.0, 0.0))
	mat.set_shader_parameter("wobble_enabled", 0.0)


static func _start(entry: Variant) -> float:
	return float((entry as Dictionary).get("start_row", 0))


static func _count(entry: Variant) -> float:
	return maxf(float((entry as Dictionary).get("frame_count", 1)), 1.0)


static func _aabb(entry: Variant) -> AABB:
	if typeof(entry) != TYPE_DICTIONARY:
		return AABB()
	var body: Dictionary = entry
	var lo: Array = body.get("min", [0.0, 0.0, 0.0])
	var hi: Array = body.get("max", [0.0, 0.0, 0.0])
	var mn := Vector3(float(lo[0]), float(lo[1]), float(lo[2]))
	var mx := Vector3(float(hi[0]), float(hi[1]), float(hi[2]))
	return AABB(mn, mx - mn)
