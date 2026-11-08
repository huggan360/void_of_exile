shader_type spatial;
render_mode unshaded, fog_disabled, cull_back;
// The Surface seen from Space: a world so big it is a floor of oceans,
// meadows, deserts and snow under drifting clouds, a thin blue glow of air
// toward the horizon. World-space patterns, so it stays put as you fly.
uniform vec3 sun_dir = vec3(-0.47, 0.32, -0.83);
uniform float surface_y = -14000.0;
varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int k = 0; k < 6; k++) { v += a * noise(p); p = p * 2.03 + vec2(17.1, 9.3); a *= 0.5; }
	return v;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_pos.xz / 9000.0;
	float land = fbm(p);
	float temp = fbm(p * 0.6 + vec2(40.0, 3.0));
	vec3 ocean = mix(vec3(0.05, 0.16, 0.34), vec3(0.08, 0.32, 0.48), smoothstep(0.38, 0.48, land));
	vec3 meadow = mix(vec3(0.2, 0.42, 0.18), vec3(0.32, 0.5, 0.2), noise(p * 8.0));
	vec3 desert = vec3(0.68, 0.56, 0.34);
	vec3 snow = vec3(0.86, 0.9, 0.95);
	vec3 ground = mix(meadow, desert, smoothstep(0.55, 0.7, temp));
	ground = mix(ground, snow, smoothstep(0.62, 0.72, land) * 0.8);
	ground = mix(ground, vec3(0.25, 0.3, 0.2), smoothstep(0.66, 0.78, land) * 0.4);
	vec3 color = mix(ocean, ground, smoothstep(0.49, 0.51, land));
	// Clouds drift slowly over everything.
	float clouds = smoothstep(0.52, 0.75, fbm(p * 1.7 + vec2(TIME * 0.004, TIME * 0.002)));
	color = mix(color, vec3(0.95, 0.96, 1.0), clouds * 0.8);
	// Daylight from the far sun, a little dimmer on the far side.
	float light = 0.55 + 0.45 * clamp(dot(normalize(sun_dir), vec3(0.0, 1.0, 0.0)) + 0.6, 0.0, 1.0);
	color *= light;
	// The air: haze grows with distance and at grazing angles, blue-white at the rim.
	vec3 to_eye = CAMERA_POSITION_WORLD - world_pos;
	float dist = length(to_eye);
	float graze = 1.0 - abs(normalize(to_eye).y);
	float haze = clamp(smoothstep(4000.0, 60000.0, dist) * 0.7 + pow(graze, 6.0) * 0.8, 0.0, 0.92);
	color = mix(color, vec3(0.45, 0.66, 0.95), haze);
	ALBEDO = color;
}
