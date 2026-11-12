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

// Per-instance detail bands for big batches (PlanetFlora): an instance whose
// root is outside [lod_band.x, lod_band.y) metres from lod_eye (the player's
// camera, also for its shadows) collapses to nothing, so one batch can hold
// the full model near the crew and its coarse copy further out.
global uniform vec3 lod_eye;
instance uniform vec2 lod_band = vec2(-1.0, 1e9);

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
	if (lod_band.x >= 0.0) {
		float d = distance(MODEL_MATRIX[3].xyz, lod_eye);
		if (d < lod_band.x || d >= lod_band.y) VERTEX = vec3(0.0);
	}
}

// Overhead see-through: a soft round window around the character (GroundView
// sets see_through = screen x, y, radius in render pixels, the character's
// view depth). What stands in front of the character there dissolves with
// a fine dither toward the rim; shadows are untouched.
global uniform vec4 see_through;

// Interleaved gradient noise: a fine, even per-pixel dither.
float dither(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void cut_see_through(vec2 frag, float view_depth) {
	// Right against the lens (the camera inside a tree or wall): gone.
	if (see_through.z <= 0.0) return;  // only the ground camera (Surface, Tavern) sets it
	float keep_near = smoothstep(0.35, 1.1, view_depth);
	float keep = 1.0;
	if (view_depth < see_through.w - 0.8) {
		float d = length(frag - see_through.xy);
		keep = smoothstep(see_through.z * 0.35, see_through.z, d);
		keep = max(keep, smoothstep(see_through.w - 1.4, see_through.w - 0.8, view_depth));
	}
	keep = min(keep, keep_near);
	if (keep < 1.0 && dither(frag) > keep * keep * (3.0 - 2.0 * keep)) discard;
}

void fragment() {
	if (!IN_SHADOW_PASS) cut_see_through(FRAGCOORD.xy, -VERTEX.z);
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
