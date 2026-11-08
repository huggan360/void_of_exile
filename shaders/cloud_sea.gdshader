shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
// The sea of clouds under the Tavern: soft billows drifting slowly, warm
// light on top, thinning toward the far horizon.
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int k = 0; k < 5; k++) { v += a * noise(p); p *= 2.07; a *= 0.5; }
	return v;
}
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = world_pos.xz / 60.0 + vec2(TIME * 0.01, TIME * 0.004);
	float billow = fbm(p);
	float shade = smoothstep(0.25, 0.85, billow);
	vec3 color = mix(vec3(0.78, 0.8, 0.95), vec3(1.0, 0.95, 0.9), shade);
	color = mix(color, vec3(1.0, 0.86, 0.8), smoothstep(0.7, 0.95, billow) * 0.4);
	float far = smoothstep(500.0, 1900.0, length(world_pos.xz - CAMERA_POSITION_WORLD.xz));
	ALBEDO = mix(color, vec3(0.86, 0.9, 1.0), far * 0.6);
}
