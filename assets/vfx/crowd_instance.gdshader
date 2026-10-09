shader_type spatial;
render_mode diffuse_burley, specular_disabled, shadows_disabled, fog_disabled, cull_back;

// INSTANCE_CUSTOM: R flash, G dissolve, B VAT frame (0-1), A palette variant.
// One shared material. Flash and dissolve never allocate a new one.
// VAT samples a position texture by the vertex id stored in UV2. With VAT off,
// the same channel drives a cheap vertex wobble. No Skeleton3D.

varying vec4 inst_custom;

uniform sampler2D palette : source_color, filter_nearest, repeat_disable;
uniform sampler2D vat_positions : hint_default_black, filter_nearest, repeat_disable;
uniform float vat_enabled = 0.0;
uniform float vat_frame_count = 1.0;
uniform vec3 flash_color : source_color = vec3(1.0, 0.96, 0.9);
uniform float rim_enabled = 0.0;
uniform vec3 rim_color : source_color = vec3(0.82, 0.92, 1.0);
uniform float rim_power = 2.5;
uniform float use_uniform_color = 0.0;
uniform vec3 uniform_color : source_color = vec3(0.184, 0.435, 0.816);
uniform float wobble_enabled = 1.0;

void vertex() {
	inst_custom = INSTANCE_CUSTOM;
	if (vat_enabled > 0.5) {
		float frame = clamp(inst_custom.b, 0.0, 1.0) * max(vat_frame_count - 1.0, 0.0);
		float v = (frame + 0.5) / max(vat_frame_count, 1.0);
		vec3 baked = texture(vat_positions, vec2(UV2.x, v)).rgb;
		VERTEX = baked;
	} else if (wobble_enabled > 0.5) {
		float phase = inst_custom.b * 6.2831853 * 4.0;
		VERTEX.x += sin(phase + VERTEX.y * 5.0) * 0.03;
		VERTEX.z += cos(phase * 0.5 + VERTEX.y * 3.0) * 0.02;
	}
}

void fragment() {
	float flash = clamp(inst_custom.r, 0.0, 1.0);
	float dissolve = clamp(inst_custom.g, 0.0, 1.0);
	float variant = clamp(inst_custom.a, 0.0, 1.0);
	float dither = fract(sin(dot(FRAGCOORD.xy, vec2(12.9898, 78.233))) * 43758.5453);
	if (dissolve > 0.001 && dither < dissolve) {
		discard;
	}
	vec3 albedo = texture(palette, vec2(variant, 0.5)).rgb;
	if (use_uniform_color > 0.5) {
		albedo = uniform_color;
	}
	ALBEDO = mix(albedo, flash_color, flash);
	ROUGHNESS = 0.9;
	if (rim_enabled > 0.5) {
		float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
		float fresnel = pow(1.0 - facing, rim_power);
		EMISSION += rim_color * fresnel;
	}
}
