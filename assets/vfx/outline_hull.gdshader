shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, fog_disabled, ambient_light_disabled;

// Inverted hull. Flat-shaded meshes split normals, so extruding along NORMAL
// opens cracks. COLOR holds the smoothed normal packed as rgb * 0.5 + 0.5
// (see OutlineNormals). Squad, elites, and the boss use this pass. Grunts do not.

uniform float outline_width = 0.05;
uniform vec3 outline_color : source_color = vec3(0.102, 0.102, 0.122);

void vertex() {
	vec3 decoded = COLOR.rgb * 2.0 - 1.0;
	vec3 extrude = NORMAL;
	if (dot(decoded, decoded) > 0.0001) {
		extrude = normalize(decoded);
	}
	VERTEX += extrude * outline_width;
}

void fragment() {
	ALBEDO = outline_color;
}
