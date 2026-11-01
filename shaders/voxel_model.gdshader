shader_type spatial;
// Vertex-colored voxel models (characters, obstacles, props). Each voxel gets
// a slight random brightness/warmth shift so surfaces look hand-painted and
// alive instead of flat. With glow_strength > 0 the colors also emit light.

uniform float jitter = 0.07;
uniform float glow_strength = 0.0;
instance uniform float glow_boost = 0.0;  // extra glow on one model (a boss about to burst)

varying vec3 local_pos;
varying vec3 local_normal;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	// Models are built in voxel units, so flooring gives the voxel this pixel belongs to.
	vec3 voxel = floor(local_pos - local_normal * 0.5);
	float h = hash3(voxel) - 0.5;
	float warm = hash3(voxel + 11.7) - 0.5;
	vec3 color = srgb_to_linear(COLOR.rgb);
	color *= 1.0 + h * 2.0 * jitter;
	color *= vec3(1.0 + warm * jitter * 0.6, 1.0, 1.0 - warm * jitter * 0.6);
	ALBEDO = glow_strength > 0.0 ? color * 0.4 : color;
	EMISSION = color * (glow_strength + glow_boost);
	ROUGHNESS = glow_strength > 0.0 ? 0.4 : 0.85;
}
