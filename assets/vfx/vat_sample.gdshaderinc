// zb-vat-1. UV2.x is the vertex column, UV2.y is the row block.
// RGB is a metres offset from the rest pose. A is unused.
// INSTANCE_CUSTOM.b is the clip start in gameplay seconds (full float).
// INSTANCE_CUSTOM.a packs the palette band and the clip id (band * 8 + clip).
// Clip 0 walks and loops, clip 1 is hit, clip 2 is death. Hit and death clamp.
// Walk-to-hit snaps. Flash, dissolve, and this start time already fill the
// custom buffer, so there is no channel left for a previous-clip start.
// game_time is GameClock.gameplay_time. Do not sample TIME: hit-stop keeps running it.

global uniform float game_time;

uniform sampler2D vat_positions : hint_default_black, filter_nearest, repeat_disable;
uniform float vat_enabled = 0.0;
uniform float vat_rows_per_frame = 1.0;
uniform float vat_clip_row[3];
uniform float vat_clip_count[3];
uniform float vat_clip_fps[3];
uniform float vat_clip_loop[3];

// Built-ins such as UV2 are not visible inside a function, so the caller passes them.
vec3 vat_sample(vec2 uv2, float start_row, float frame) {
	int col = int(uv2.x * float(textureSize(vat_positions, 0).x));
	int block = int(uv2.y);
	int row = int(start_row) + int(frame) * int(vat_rows_per_frame) + block;
	return texelFetch(vat_positions, ivec2(col, row), 0).rgb;
}

vec3 vat_offset(vec4 inst, vec2 uv2) {
	int clip = int(inst.a + 0.5) % 8;
	float row = vat_clip_row[0];
	float count = vat_clip_count[0];
	float fps = vat_clip_fps[0];
	float looped = vat_clip_loop[0];
	if (clip == 1) {
		row = vat_clip_row[1];
		count = vat_clip_count[1];
		fps = vat_clip_fps[1];
		looped = vat_clip_loop[1];
	} else if (clip == 2) {
		row = vat_clip_row[2];
		count = vat_clip_count[2];
		fps = vat_clip_fps[2];
		looped = vat_clip_loop[2];
	}
	count = max(count, 1.0);
	float frames = (game_time - inst.b) * fps;
	float frame = clamp(frames, 0.0, count - 1.0);
	if (looped > 0.5) {
		frame = mod(frames, count);
	}
	return vat_sample(uv2, row, floor(frame));
}
