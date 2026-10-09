shader_type spatial;
render_mode diffuse_burley, specular_disabled, shadows_disabled, cull_back, fog_disabled;

uniform vec4 albedo : source_color = vec4(1.0, 0.45, 0.08, 1.0);
uniform float emission_strength = 0.0;
uniform float flash = 0.0;
uniform vec3 emission_color : source_color = vec3(1.0, 0.42, 0.05);
uniform vec3 flash_color : source_color = vec3(1.0, 0.96, 0.9);

void fragment() {
	ALBEDO = mix(albedo.rgb, flash_color, clamp(flash, 0.0, 1.0));
	EMISSION = emission_color * emission_strength;
}
