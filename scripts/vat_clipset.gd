class_name VatClipset
extends RefCounted
## zb-vat-1 clip table loaded from assets/models/anim/<mesh>_vat.json.
## A missing json or EXR means the mesh stays on the static rest pose.


const CLIP_WALK := 0
const CLIP_HIT := 1
const CLIP_DEATH := 2
## Spec: playback 1.0 matches about 0.4 m/s. The shared walk clip uses the
## walker archetype speed. Instances do not carry their own playback rate.
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
var walk_loop: bool = true
var hit_loop: bool = false
var death_loop: bool = false
var anim_aabb: AABB = AABB()

static var _walker: VatClipset


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
	clip.walk_loop = _loop(clips["walk"], true)
	clip.hit_loop = _loop(clips["hit"], false)
	clip.death_loop = _loop(clips["death"], false)
	clip.anim_aabb = _aabb(data.get("aabb", {}))
	return clip


static func walker_clip() -> VatClipset:
	if _walker == null:
		_walker = for_model("res://assets/models/enm_walker.glb")
	return _walker


## Seconds of hit playback before the pool snaps back to the phased walk.
static func hit_seconds() -> float:
	var clip := walker_clip()
	if clip == null:
		return 8.0 / 30.0
	return clip.hit_count / maxf(clip.fps, 1.0)


## Walk fps shared by every walker material. Matches walk_origin().
static func walk_play_fps() -> float:
	var clip := walker_clip()
	var base := 30.0 if clip == null else clip.fps
	var speed := 1.6
	var arch := EnemyCatalog.walker()
	if arch != null:
		speed = arch.speed
	return base * clampf(speed / WALK_REF_SPEED, 0.25, 6.0)


## Negative start bakes the phase into (game_time - start) * walk_play_fps.
static func walk_origin(phase: float) -> float:
	var clip := walker_clip()
	var count := 24.0 if clip == null else clip.walk_count
	return -phase * count / maxf(walk_play_fps(), 0.001)


## variant is a 0..1 palette UV. Eight bands keep it next to the clip id.
static func pack_clip(variant: float, clip_id: int) -> float:
	var band := clampi(int(round(clampf(variant, 0.0, 1.0) * 7.0)), 0, 7)
	return float(band * 8 + clampi(clip_id, 0, 7))


func padded_aabb() -> AABB:
	return anim_aabb.grow(AABB_MARGIN)


func apply_to(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("vat_enabled", 1.0)
	mat.set_shader_parameter("vat_positions", texture)
	mat.set_shader_parameter("vat_rows_per_frame", float(rows_per_frame))
	mat.set_shader_parameter("vat_clip_row", PackedFloat32Array([walk_start, hit_start, death_start]))
	mat.set_shader_parameter("vat_clip_count", PackedFloat32Array([walk_count, hit_count, death_count]))
	mat.set_shader_parameter("vat_clip_fps", PackedFloat32Array([walk_play_fps(), fps, fps]))
	mat.set_shader_parameter("vat_clip_loop", PackedFloat32Array([
		1.0 if walk_loop else 0.0,
		1.0 if hit_loop else 0.0,
		1.0 if death_loop else 0.0,
	]))
	mat.set_shader_parameter("wobble_enabled", 0.0)


static func _start(entry: Variant) -> float:
	return float((entry as Dictionary).get("start_row", 0))


static func _count(entry: Variant) -> float:
	return maxf(float((entry as Dictionary).get("frame_count", 1)), 1.0)


static func _loop(entry: Variant, fallback: bool) -> bool:
	var body: Dictionary = entry
	if not body.has("loop"):
		return fallback
	return body["loop"] == true


static func _aabb(entry: Variant) -> AABB:
	if typeof(entry) != TYPE_DICTIONARY:
		return AABB()
	var body: Dictionary = entry
	var lo: Array = body.get("min", [0.0, 0.0, 0.0])
	var hi: Array = body.get("max", [0.0, 0.0, 0.0])
	var mn := Vector3(float(lo[0]), float(lo[1]), float(lo[2]))
	var mx := Vector3(float(hi[0]), float(hi[1]), float(hi[2]))
	return AABB(mn, mx - mn)
