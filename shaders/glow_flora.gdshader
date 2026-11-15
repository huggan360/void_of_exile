shader_type spatial;
// Glowing dungeon dressing (GlowFlora): voxels that blink and pass ripples of
// light between them. Instance color is the voxel's color; INSTANCE_CUSTOM:
// x = random seed, y = how much it glows (0 = stem or leaf, 1 = a bulb),
// z = blink rate (beats per second), w = resting glow.
#include "res://shaders/include/glow_ripple.gdshaderinc"

uniform float emission_scale = 2.4;
varying vec3 world;
varying vec4 custom;
varying vec3 local_pos;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	custom = INSTANCE_CUSTOM;
	local_pos = VERTEX;
}

void fragment() {
	vec3 p = floor(local_pos * 4.0);
	float grain = fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
	vec3 col = COLOR.rgb * (0.85 + grain * 0.2);
	ALBEDO = col * (1.0 - custom.y * 0.5);
	ROUGHNESS = 0.8;
	float lit = custom.w + glow_blink(custom.x, custom.z) + gr_level * 1.2;
	vec3 ripple = glow_ripples(world);
	// Ripples tint toward their own color but keep the plant's hue.
	EMISSION = custom.y * (col * lit + (col * 0.6 + ripple * 0.7) * length(ripple)) * emission_scale;
}
