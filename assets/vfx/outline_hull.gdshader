shader_type spatial;
render_mode unshaded, cull_front, shadows_disabled, fog_disabled, ambient_light_disabled;

// Inverted hull. Flat-shaded meshes split normals, so extruding along NORMAL
// opens cracks. COLOR holds the smoothed normal packed as rgb * 0.5 + 0.5
// (see OutlineNormals). Squad, elites, and the boss use this pass.
// Walker VAT adds the same offset. Dying walkers discard: the baked COLOR
// is the rest pose, and a body on its back would extrude the wrong way.

#include "res://assets/vfx/vat_sample.gdshaderinc"

uniform float outline_width = 0.05;
uniform vec3 outline_color : source_color = vec3(0.102, 0.102, 0.122);

varying vec4 inst_custom;

void vertex() {
	inst_custom = INSTANCE_CUSTOM;
	vec3 decoded = COLOR.rgb * 2.0 - 1.0;
	vec3 extrude = NORMAL;
	if (dot(decoded, decoded) > 0.0001) {
		extrude = normalize(decoded);
	}
	if (vat_enabled > 0.5) {
		VERTEX += vat_offset(inst_custom, UV2);
	}
	VERTEX += extrude * outline_width;
}

void fragment() {
	// Clip 2 is death. The rest-pose hull normal is wrong once the body falls.
	if (vat_enabled > 0.5 && int(inst_custom.a + 0.5) % 8 == 2) {
		discard;
	}
	ALBEDO = outline_color;
}
