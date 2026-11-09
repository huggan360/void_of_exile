shader_type spatial;
render_mode cull_back;
// Shardfield rock: banded stone in the instance tone with glowing crystal
// seams (vertex alpha) in teal or pink, chosen per rock.
varying float seam;
varying vec3 rock_pos;
varying float pick;
float hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
void vertex() {
	seam = COLOR.a;
	rock_pos = VERTEX;
	pick = INSTANCE_CUSTOM.r;
}
void fragment() {
	float bands = floor((rock_pos.y + sin(rock_pos.x * 3.0) * 0.2) * 6.0);
	vec3 stone = COLOR.rgb * (0.42 + hash(vec3(bands)) * 0.16);
	vec3 crystal = mix(vec3(0.45, 0.95, 0.82), vec3(0.95, 0.6, 0.85), step(0.5, pick));
	// Far away a rock is a few pixels: glowing seams there only flicker into
	// a bright shimmer, so they fade to plain stone with distance.
	float near_glow = 1.0 - smoothstep(1200.0, 3500.0, length(VERTEX));
	float lit = seam * near_glow;
	ALBEDO = mix(stone, crystal, lit * 0.7);
	ROUGHNESS = mix(0.95, 0.3, lit);
	EMISSION = crystal * lit * 0.8;
}
