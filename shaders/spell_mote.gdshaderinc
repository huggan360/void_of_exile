// Shared by spell_mote (glowing, added onto the scene) and spell_mote_dark
// (black magic, drawn over it): camera-facing sprites in the particle's color.

uniform int shape = 0;        // 0 dot, 1 four-point star, 2 snowflake, 3 leaf, 4 bubble, 5 shard
uniform float energy = 2.0;   // brightness (above 1 blooms with glow on)
uniform float core = 0.6;     // how much of the middle turns white-hot

void vertex() {
	// Face the camera, spinning by the particle's own angle.
	mat4 world = mat4(normalize(INV_VIEW_MATRIX[0]), normalize(INV_VIEW_MATRIX[1]), normalize(INV_VIEW_MATRIX[2]), MODEL_MATRIX[3]);
	float a = INSTANCE_CUSTOM.x;
	world = world * mat4(vec4(cos(a), -sin(a), 0.0, 0.0), vec4(sin(a), cos(a), 0.0, 0.0), vec4(0.0, 0.0, 1.0, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * world;
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

float star(vec2 p, float arms, float sharp) {
	float r = length(p);
	float ang = atan(p.y, p.x);
	float spikes = pow(abs(cos(ang * arms * 0.5)), sharp);
	return clamp(1.0 - r / mix(0.12, 1.0, spikes), 0.0, 1.0);
}

// How much of the sprite covers this pixel (can go a little above 1 in the core).
float mote_body(vec2 uv) {
	vec2 p = (uv - 0.5) * 2.0;
	float r = length(p);
	float glow = pow(max(0.0, 1.0 - r), 2.0);
	if (shape == 1) {
		return pow(star(p, 4.0, 18.0), 1.5) + glow * 0.5;
	} else if (shape == 2) {
		return pow(star(p, 6.0, 30.0), 1.2) + smoothstep(0.35, 0.25, r) * 0.4 + glow * 0.3;
	} else if (shape == 3) {
		// An ivy leaf: three lobes and a pale vein down the middle.
		float ang = atan(p.x, p.y);
		float lobes = 0.55 + 0.35 * pow(abs(cos(ang * 1.5)), 2.0);
		float leaf = smoothstep(lobes, lobes - 0.12, r);
		float vein = smoothstep(0.08, 0.0, abs(p.x)) * step(p.y, 0.6) * leaf;
		return leaf * 0.8 + vein * 0.6 + glow * 0.25;
	} else if (shape == 4) {
		return smoothstep(0.08, 0.0, abs(r - 0.7)) + smoothstep(0.25, 0.0, length(p - vec2(-0.3, 0.3))) * 0.8 + glow * 0.15;
	} else if (shape == 5) {
		float d = abs(p.x) * 3.5 + abs(p.y);
		return smoothstep(1.0, 0.6, d) + glow * 0.3;
	}
	return glow;
}
