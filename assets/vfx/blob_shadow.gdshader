shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_opaque, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float alpha = smoothstep(1.0, 0.35, dot(p, p)) * 0.5;
	ALBEDO = vec3(0.02, 0.02, 0.025);
	ALPHA = alpha;
}
