shader_type spatial;
render_mode cull_disabled, shadows_disabled, depth_draw_never;
// Water pouring off the Tavern's lip: streaks rushing down, white at the top,
// thinning into mist toward the clouds below (UV.y 0 at the lip, 1 at the clouds).
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	float streak = hash(vec2(floor(uv.x * 14.0), 3.0));
	float flow = fract(uv.y * 6.0 - TIME * (1.6 + streak * 0.8) + streak * 7.0);
	float lines = smoothstep(0.0, 0.25, flow) * (1.0 - smoothstep(0.55, 1.0, flow));
	vec3 water = mix(vec3(0.42, 0.78, 0.92), vec3(0.95, 0.98, 1.0), lines * 0.6 + (1.0 - smoothstep(0.0, 0.08, uv.y)) * 0.8);
	float edge = smoothstep(0.0, 0.18, uv.x - floor(uv.x)) * smoothstep(0.0, 0.18, 1.0 - (uv.x - floor(uv.x)));
	ALBEDO = water;
	EMISSION = water * 0.25;
	ALPHA = (0.55 + lines * 0.35) * (1.0 - smoothstep(0.55, 1.0, uv.y)) * mix(0.6, 1.0, edge);
	ROUGHNESS = 0.1;
}
