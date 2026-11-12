shader_type spatial;
// A waterfall curtain: white water streaming down, thinner and bluer at the
// edges of the stream, foamy where it lands. UV.y runs 0 (lip) to 1 (foot);
// UV2.x is the drop in meters so the streaks keep their size on any fall.
render_mode cull_disabled, shadows_disabled, depth_draw_never;

uniform vec3 water_color : source_color = vec3(0.55, 0.75, 0.82);
uniform vec3 foam_color : source_color = vec3(0.95, 0.98, 1.0);

varying vec3 world;
varying float drop;

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x), mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	drop = UV2.x;
}

void fragment() {
	float across = world.x + world.z;
	float down = UV.y * drop;
	// Voxel-sized streaks falling fast.
	vec2 cell = floor(vec2(across * 4.0, (down - TIME * 3.2) * 4.0));
	float streak = hash2(vec2(cell.x, floor(cell.y / 3.0)));
	float n = noise2(vec2(across * 2.0, down * 1.2 - TIME * 2.5));
	float white = smoothstep(0.35, 0.8, streak * 0.6 + n * 0.5) + smoothstep(0.65, 1.0, UV.y) * 0.8;
	ALBEDO = mix(water_color, foam_color, clamp(white, 0.0, 1.0));
	EMISSION = ALBEDO * 0.08;
	ALPHA = clamp(0.55 + white * 0.4, 0.0, 0.95);
	ROUGHNESS = 0.2;
}
