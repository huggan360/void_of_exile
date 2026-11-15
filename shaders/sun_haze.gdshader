shader_type fog;
// VolumetricLight's sun haze: thin air hugging the ground round the player,
// thinning out with height and gathering a little in the valleys below. On
// its own it is barely there; where sunlight falls through leaves, roofs
// and gaps it lights up as beams, and lamps and fires glow in it. Slow
// drifting clumps keep the beams from looking like solid glass.

uniform sampler2D noise_map : filter_linear, repeat_enable;
uniform vec3 anchor;  // the player's feet
uniform vec3 up = vec3(0.0, 1.0, 0.0);
uniform float density = 0.012;
uniform float height = 8.0;  // meters over which it thins to a third
uniform vec3 tint : source_color = vec3(1.0, 0.97, 0.92);

void fog() {
	vec3 w = WORLD_POSITION;
	float above = dot(w - anchor, up);
	float layer = exp(-max(above, -height) / height);
	vec2 drift = vec2(TIME * 0.12, TIME * 0.05);
	float n = texture(noise_map, (w.xz + drift) * 0.016).r;
	float n2 = texture(noise_map, (w.xz - drift * 1.6) * 0.045 + vec2(w.y * 0.025)).r;
	float clumps = 0.45 + smoothstep(0.25, 0.8, n * 0.65 + n2 * 0.45);
	// Soft sides so the box never shows.
	vec3 edge = min(UVW, 1.0 - UVW);
	float box = smoothstep(0.0, 0.15, min(edge.x, edge.z)) * smoothstep(0.0, 0.1, edge.y);
	DENSITY = density * layer * clumps * box;
	ALBEDO = tint;
}
