shader_type spatial;
render_mode diffuse_burley, specular_disabled, shadows_disabled, fog_disabled, cull_back;

// Boss crystal. Separate from the crowd material so stun glow and hit flash
// can change this pass later without breaking MultiMesh batching.
// emission_strength and flash are the hooks. Idle stays a soft glow.

uniform sampler2D palette : source_color, filter_nearest, repeat_disable;
uniform float emission_strength = 0.85;
uniform vec3 emission_color : source_color = vec3(1.0, 0.62, 0.18);
uniform float flash = 0.0;

void fragment() {
	vec3 albedo = texture(palette, UV).rgb;
	float hit = clamp(flash, 0.0, 1.0);
	ALBEDO = mix(albedo, vec3(1.0), hit);
	EMISSION = emission_color * albedo * emission_strength * (1.0 + hit * 3.0);
	ROUGHNESS = 0.45;
}
