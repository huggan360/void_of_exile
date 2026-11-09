shader_type spatial;
render_mode cull_disabled;
// Vesperis's country roads (CityCountryArt): pixel-art asphalt on a 10 cm grid
// with white edge lines, a dashed centre line and a narrow gravel shoulder
// fraying into the grass. UV.x runs across the road (0..1), UV.y along it in metres.
varying vec3 world_pos;

float hash(vec2 q) { return fract(sin(dot(q, vec2(12.9898, 78.233))) * 43758.5453); }

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 px = floor(vec2(UV.x * 52.0, UV.y * 10.0));
	float n = hash(px);
	float across = abs(UV.x - 0.5) * 2.0;  // 0 in the middle, 1 at the edge
	vec3 c = mix(vec3(0.2, 0.19, 0.22), vec3(0.27, 0.26, 0.29), n);
	if (n > 0.96) c = vec3(0.34, 0.33, 0.36);
	float along = floor(UV.y * 10.0) / 10.0;
	// Dashed centre line, solid edge lines.
	if (across < 0.045 && fract(along / 6.0) < 0.5) c = vec3(0.9, 0.86, 0.72);
	if (abs(across - 0.8) < 0.045) c = vec3(0.88, 0.88, 0.86);
	// Gravel shoulder, ragged into the grass.
	if (across > 0.86) {
		c = mix(vec3(0.5, 0.45, 0.38), vec3(0.6, 0.55, 0.47), n);
		if (n < (across - 0.86) / 0.14) c = mix(vec3(0.33, 0.5, 0.25), vec3(0.41, 0.58, 0.3), hash(px + 7.0));
	}
	float detail = 1.0 - smoothstep(90.0, 300.0, length(world_pos - CAMERA_POSITION_WORLD));
	ALBEDO = mix(vec3(0.27, 0.26, 0.28), c, detail);
	ROUGHNESS = 0.9;
}
