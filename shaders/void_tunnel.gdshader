shader_type canvas_item;
// The loading screen: a dark tunnel of chunky voxel pixels spiralling in
// toward the middle, mostly purple and white with the odd strange color.
// Cells are laid out in log-polar space, so they stay square and get
// smaller toward the far end of the tunnel; each one is drawn as a small
// pixel-snapped block with a gap around it.

uniform float pixel_size = 5.0;  // screen pixels per art pixel
uniform float speed = 1.0;
uniform float rays = 72.0;  // cells around the tunnel

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 px = floor(FRAGCOORD.xy / pixel_size) * pixel_size + pixel_size * 0.5;
	vec2 d = (px - res * 0.5) / res.y;
	float r = length(d) + 0.0001;
	float a = atan(d.y, d.x) / 6.2831853;

	// Square cells: one turn of angle is as long as `rays` steps of log radius.
	float t = TIME * speed;
	float depth = -log(r) * rays / 6.2831853 + t * 9.0;  // slides inward
	float spin = a * rays + depth * 0.35 + t * 1.5;  // and twists into a spiral
	vec2 cell = floor(vec2(spin, depth));
	vec2 inside = fract(vec2(spin, depth));
	float block = step(0.22, inside.x) * step(inside.x, 0.78) * step(0.22, inside.y) * step(inside.y, 0.78);
	float h = hash(cell);
	float pick = hash(cell + 17.3);
	float on = step(0.78, h) * block;

	vec3 voxel = vec3(0.56, 0.3, 1.0);  // purple
	if (pick > 0.55) voxel = vec3(0.92, 0.9, 1.0);  // white
	if (pick > 0.86) voxel = vec3(0.35, 0.9, 1.0);  // odd ones: cyan,
	if (pick > 0.92) voxel = vec3(1.0, 0.4, 0.75);  // pink,
	if (pick > 0.97) voxel = vec3(1.0, 0.85, 0.3);  // gold
	float twinkle = 0.65 + 0.35 * sin(t * 6.0 + h * 40.0);

	// A clear dark core for the loader, brightening outward.
	float fade = smoothstep(0.13, 0.32, r) * (0.55 + 0.45 * smoothstep(0.3, 0.8, r));
	vec3 bg = vec3(0.025, 0.015, 0.06) + vec3(0.14, 0.06, 0.3) * exp(-pow((r - 0.2) * 7.0, 2.0)) * 0.45;
	COLOR = vec4(bg + voxel * on * fade * twinkle, 1.0);
}
