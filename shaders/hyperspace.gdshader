shader_type canvas_item;
// Jump to lightspeed, drawn over the whole screen: the view zooms in toward
// the middle and smears outward along the rays from the center, stars stretch
// into streaks, and it all flares toward white as `strength` goes 0 -> 1.
// Run strength 1 -> 0 to come back out of hyperspace.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform vec3 streak_color : source_color = vec3(0.8, 0.75, 1.0);

float hash(float n) {
	return fract(sin(n * 12.9898) * 43758.5453);
}

void fragment() {
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 d = SCREEN_UV - 0.5;
	float s = strength * strength;

	// Zoom in, and smear each pixel along its ray from the center.
	float zoom = 1.0 - 0.45 * s;
	vec3 acc = vec3(0.0);
	for (int i = 0; i < 20; i++) {
		float t = float(i) / 19.0;
		vec2 uv = 0.5 + d * zoom * (1.0 - t * 0.55 * s);
		acc += textureLod(screen_tex, uv, s * 3.5).rgb;
	}
	vec3 col = acc / 20.0;

	// Star streaks: thin radial lines that grow longer as we speed up.
	vec2 p = d * aspect;
	float r = length(p);
	float a = atan(p.y, p.x) / 6.2831853 + 0.5;
	float bin = floor(a * 420.0);
	float h = hash(bin);
	float start = 0.08 + hash(bin + 7.1) * 0.6;
	float len = 0.02 + s * (0.25 + h * 0.5);
	float line = step(0.72, h) * smoothstep(start, start + 0.01, r) * (1.0 - smoothstep(start + len - 0.01, start + len, r));
	float edge = 1.0 - abs(fract(a * 420.0) - 0.5) * 2.0;  // thin across the ray
	line *= smoothstep(0.3, 0.9, edge);
	vec3 streak = mix(streak_color, vec3(1.0), hash(bin + 3.3)) * line * smoothstep(0.0, 0.25, strength) * 1.6;

	// Purple tint, then a white flare at full speed.
	col = mix(col, col * vec3(0.8, 0.7, 1.15), s);
	col += streak;
	col = mix(col, vec3(0.95, 0.92, 1.0), smoothstep(0.75, 1.0, strength) * 0.85);
	COLOR = vec4(col, 1.0);
}
