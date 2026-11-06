shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 nebula_color : source_color = vec4(0.11, 0.26, 0.24, 1.0);
uniform bool round_window = false;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	if (round_window && distance(UV, vec2(0.5)) > 0.5) {
		discard;
	}
	vec2 uv = UV + vec2(TIME * 0.0018, TIME * 0.0004);
	vec2 grid = floor(uv * vec2(120.0, 64.0));
	vec2 pixel = fract(uv * vec2(120.0, 64.0));
	float seed = hash(grid);
	float star = step(0.986, seed) * step(0.26, pixel.x) * step(pixel.x, 0.72)
		* step(0.28, pixel.y) * step(pixel.y, 0.76);
	float shimmer = 0.7 + 0.3 * sin(TIME * 1.1 + seed * 93.0);
	float cloud = pow(0.5 + 0.5 * sin(uv.x * 13.0 + sin(uv.y * 9.0)), 3.0);
	vec3 space = vec3(0.008, 0.012, 0.032) + nebula_color.rgb * cloud * 0.22;
	ALBEDO = space;
	EMISSION = space + vec3(0.85, 0.96, 0.7) * star * shimmer * 2.2;
}
