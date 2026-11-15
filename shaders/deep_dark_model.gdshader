shader_type spatial;
// Only the bright organs emit. Black bark and stone stay dark.
#include "res://shaders/include/glow_ripple.gdshaderinc"

global uniform vec4 see_through;
varying vec3 world;
varying float seed;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	seed = fract(sin(dot(MODEL_MATRIX[3].xz, vec2(12.9898, 78.233))) * 43758.5453);
}

float dither(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void fragment() {
	if (!IN_SHADOW_PASS && see_through.z > 0.0) {
		float depth = -VERTEX.z;
		float keep = 1.0;
		if (depth < see_through.w - 0.8) {
			keep = max(smoothstep(see_through.z * 0.35, see_through.z, length(FRAGCOORD.xy - see_through.xy)),
				smoothstep(see_through.w - 1.4, see_through.w - 0.8, depth));
		}
		if (dither(FRAGCOORD.xy) > min(keep, smoothstep(0.35, 1.1, depth))) discard;
	}
	vec3 color = mix(pow((COLOR.rgb + 0.055) / 1.055, vec3(2.4)), COLOR.rgb / 12.92, lessThan(COLOR.rgb, vec3(0.04045)));
	float mask = smoothstep(0.3, 0.65, max(COLOR.r, max(COLOR.g, COLOR.b)));
	vec3 ripple = glow_ripples(world);
	float resting = 0.65 + glow_blink(seed, 0.32) * 0.4;
	ALBEDO = color * (1.0 - mask * 0.5);
	EMISSION = mask * (color * (resting + gr_level) + ripple * 0.65) * 2.4;
	ROUGHNESS = 0.8;
}
