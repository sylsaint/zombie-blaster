// zb-vat-1. UV2.x is the vertex column, UV2.y is the row block.
// RGB is a metres offset from the rest pose. A is unused.
// INSTANCE_CUSTOM.b packs the walk frame in mod 64 and the hit frame above it.
// INSTANCE_CUSTOM.a is the walk-to-hit blend (0..1), -1 while walking,
// or -2 minus the death frame while dying.

uniform sampler2D vat_positions : hint_default_black, filter_nearest, repeat_disable;
uniform float vat_enabled = 0.0;
uniform float vat_rows_per_frame = 1.0;
uniform vec4 vat_walk = vec4(0.0, 24.0, 1.0, 0.0);
uniform vec4 vat_hit = vec4(24.0, 8.0, 0.0, 0.0);
uniform vec4 vat_death = vec4(32.0, 16.0, 0.0, 0.0);

// Built-ins such as UV2 are not visible inside a function, so the caller passes them.
vec3 vat_sample(vec2 uv2, float start_row, float frame) {
	int col = int(uv2.x * float(textureSize(vat_positions, 0).x));
	int block = int(uv2.y);
	int row = int(start_row) + int(frame) * int(vat_rows_per_frame) + block;
	return texelFetch(vat_positions, ivec2(col, row), 0).rgb;
}

vec3 vat_offset(vec4 inst, vec2 uv2) {
	float walk_frame = mod(inst.b, 64.0);
	float hit_frame = floor(inst.b / 64.0);
	float tag = inst.a;
	if (tag < -1.5) {
		float death_frame = clamp(-tag - 2.0, 0.0, max(vat_death.y - 1.0, 0.0));
		return vat_sample(uv2, vat_death.x, death_frame);
	}
	if (tag < 0.0) {
		return vat_sample(uv2, vat_walk.x, walk_frame);
	}
	vec3 walking = vat_sample(uv2, vat_walk.x, walk_frame);
	vec3 struck = vat_sample(uv2, vat_hit.x, hit_frame);
	return mix(walking, struck, clamp(tag, 0.0, 1.0));
}
