shader_type canvas_item;
// The original log-polar pixel vortex, with a darker field, chunkier blocks,
// a slower turn and a cyan, violet and gold palette.

uniform float pixel_size = 6.0;  // hard-edged screen pixels per voxel
uniform float speed = 0.72;
uniform float rays = 68.0;  // cells around the tunnel

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = floor(FRAGCOORD.xy / pixel_size) * pixel_size + pixel_size * 0.5;
	vec2 d = (px - res * 0.5) / res.y;
	float r = length(d) + 0.0001;
	float a = atan(d.y, d.x) / 6.2831853;

	// Keep the old inward-flowing tunnel, but step it at eight frames per second.
	float t = floor(TIME * 8.0) / 8.0 * speed;
	float depth = -log(r) * rays / 6.2831853 + t * 7.0;
	float spin = a * rays + depth * 0.24 + t * 0.78;
	vec2 cell = floor(vec2(spin, depth));
	vec2 inside = fract(vec2(spin, depth));
	float block = step(0.16, inside.x) * step(inside.x, 0.84)
		* step(0.16, inside.y) * step(inside.y, 0.84);
	float h = hash(cell);
	float pick = hash(cell + 17.3);
	float on = step(0.66, h) * block;

	vec3 voxel = vec3(0.42, 0.13, 0.98);  // violet
	if (pick > 0.45) voxel = vec3(0.04, 0.68, 1.0);  // bright cyan
	if (pick > 0.78) voxel = vec3(0.11, 0.3, 0.92);  // deep blue
	if (pick > 0.955) voxel = vec3(1.0, 0.67, 0.18);  // gold sparks

	// Discrete depth bands keep the center dark without a soft gradient.
	float band = floor(clamp(r * 9.0, 0.0, 7.0));
	float depth_color = 0.42 + 0.58 * band / 7.0;
	float tunnel = step(0.12, r) * step(r, 0.88);
	float flicker = mix(0.78, 1.0, step(0.5, fract(t * 1.6 + h * 3.0)));
	vec3 bg = vec3(0.003, 0.006, 0.016);
	COLOR = vec4(bg + voxel * on * tunnel * depth_color * flicker, 1.0);
}
