shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled, depth_draw_opaque;

// Hard disc so crowd shadows stay in the opaque pipeline. Not a Decal.

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	if (dot(p, p) > 1.0) {
		discard;
	}
	ALBEDO = vec3(0.02, 0.02, 0.03);
	ALPHA = 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
}
