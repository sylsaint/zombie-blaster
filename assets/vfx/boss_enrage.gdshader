shader_type spatial;
render_mode blend_mix, unshaded, cull_disabled, depth_draw_opaque, shadows_disabled, fog_disabled;

// Overlay tint. enrage 0 discards, so the artist's material stays untouched
// until the boss rages. Never swaps the body material.
uniform float enrage = 0.0;
uniform vec3 tint : source_color = vec3(0.92, 0.08, 0.06);

void fragment() {
	if (enrage <= 0.001) {
		discard;
	}
	ALBEDO = tint;
	ALPHA = clamp(enrage, 0.0, 1.0) * 0.72;
}
