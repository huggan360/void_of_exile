shader_type spatial;
render_mode cull_back;
// Vesperis's buildings (MultiMesh unit shapes: boxes, cylinders, spheres, domes,
// cones, tori). Per instance: COLOR the base colour, INSTANCE_CUSTOM r seed,
// g window density (0 = none), b the material (1 = glows in COLOR; else
// b*10: 0 plaster, 1 bark, 2 shingles, 3 leaves, 4 stone, 5 water, 6 planks,
// 7 grass, 8 mushroom cap), a the wall mapping (1 brass trims, 2 round: wraps
// round the part).
// Nothing is flat: every surface is cut into small voxels whose tones vary,
// with the material's own pattern on top (bark grooves, shingle rows, bricks,
// leaf clumps), and lit arched windows in lantern amber, rose, teal and mint.
varying vec3 local_m;
varying vec3 local_n;
varying vec3 scale_m;
varying vec4 custom;
varying vec3 world_pos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
vec3 lin(vec3 c) { return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045))); }

void vertex() {
	scale_m = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	local_m = VERTEX * scale_m;
	local_n = NORMAL;
	custom = INSTANCE_CUSTOM;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// The surface pattern of material `kind` at wall coordinates w (m) and the voxel id v.
vec3 material(int kind, vec3 base, vec2 w, vec3 v, float seed, float near) {
	float tone = hash(v + seed);
	vec3 c = base * (0.9 + tone * 0.18);
	if (kind == 1) {
		// Bark: deep grooves running up, a little wavy.
		float col = floor((w.x + floor(w.y / 1.6) * 0.2) / 0.35);
		float groove = step(hash(vec3(col, seed, 1.0)), 0.32);
		c *= mix(1.0, 0.62, groove * near);
		c *= 0.92 + 0.12 * hash(vec3(col, floor(w.y / 0.7), seed));
	} else if (kind == 2) {
		// Shingles: staggered rows, each with a dark lower lip.
		float row = floor(w.y / 0.45);
		float x = w.x / 0.6 + mod(row, 2.0) * 0.5;
		float id = hash(vec3(floor(x), row, seed));
		c = base * (0.82 + id * 0.3);
		c *= mix(1.0, 0.68, step(fract(w.y / 0.45), 0.2) * near);
		c *= mix(1.0, 0.8, step(fract(x), 0.08) * near);
	} else if (kind == 3 || kind == 7) {
		// Leaves and grass: clumps of light and shade, now and then a flower.
		float size = kind == 3 ? 0.55 : 0.3;
		vec3 clump = floor(v * 0.25 / size);
		float shade = hash(clump + seed);
		c = base * (0.72 + shade * 0.5);
		float bloom = hash(v + seed * 3.0);
		if (bloom > 0.975) c = mix(lin(vec3(1.0, 0.62, 0.8)), lin(vec3(1.0, 0.88, 0.5)), step(0.9875, bloom));
	} else if (kind == 4) {
		// Stone blocks with mortar.
		float row = floor(w.y / 0.5);
		float x = w.x / 1.0 + mod(row, 2.0) * 0.5;
		c = base * (0.8 + hash(vec3(floor(x), row, seed)) * 0.32);
		float mortar = max(step(fract(w.y / 0.5), 0.12), step(fract(x), 0.06));
		c = mix(c, base * 0.5, mortar * near);
	} else if (kind == 5) {
		// Water: slow pixel ripples.
		float ripple = sin(floor(w.x * 4.0) * 0.6 + TIME * 1.2) * sin(floor(w.y * 4.0) * 0.5 - TIME * 0.9);
		c = base * (0.85 + 0.2 * step(0.75, ripple));
	} else if (kind == 6) {
		// Planks.
		float row = floor(w.y / 0.3);
		float x = w.x / 2.2 + hash(vec3(row, seed, 6.0));
		c = base * (0.82 + hash(vec3(floor(x), row, seed)) * 0.3);
		c *= mix(1.0, 0.7, max(step(fract(w.y / 0.3), 0.15), step(fract(x), 0.03)) * near);
	} else if (kind == 8) {
		c = base * (0.85 + tone * 0.25);
	}
	return c;
}

void fragment() {
	vec3 base = lin(COLOR.rgb);
	float seed = custom.r * 97.0;
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float near = 1.0 - smoothstep(160.0, 600.0, dist);
	if (custom.b > 0.95) {
		ALBEDO = base * 0.4;
		EMISSION = base * (0.55 + 0.06 * sin(TIME * 2.0 + seed));
		ROUGHNESS = 0.5;
	} else {
		int kind = int(custom.b * 10.0 + 0.5);
		float up = local_m.y + scale_m.y * 0.5;  // metres above the part's base
		bool side = abs(local_n.y) < 0.5;
		bool round = custom.a > 1.5;
		// Wall coordinates: along the face (boxes) or round the part, and up.
		float along = abs(local_n.x) > abs(local_n.z) ? local_m.z : local_m.x;
		if (round) along = atan(local_m.x, local_m.z) * max(scale_m.x, scale_m.z) * 0.5;
		vec2 w = side || round ? vec2(along, up) : local_m.xz;
		float grain = kind == 7 ? 0.2 : 0.3;
		vec3 v = floor(local_m / grain);
		vec3 color = material(kind, base, w, v, seed, near);
		vec3 glow = vec3(0.0);
		if (side && custom.g > 0.01) {
			vec2 cell = vec2(along / 2.6, up / 3.6);
			vec2 id = floor(cell);
			vec2 f = fract(cell);
			// Arched windows: a box below, a round top, a cross of mullions.
			float box = step(0.28, f.x) * step(f.x, 0.72) * step(0.22, f.y) * step(f.y, 0.6);
			float arch = step(length((f - vec2(0.5, 0.6)) * vec2(1.0, 1.25)), 0.22) * step(0.6, f.y);
			float frame = max(box, arch);
			float bar = step(abs(f.x - 0.5), 0.025) + step(abs(f.y - 0.5), 0.02);
			frame *= 1.0 - clamp(bar, 0.0, 1.0) * near;
			float lit = step(1.0 - custom.g, hash(vec3(id, seed)));
			float pick = hash(vec3(id.yx, seed + 3.0));
			vec3 lamp = pick < 0.55 ? vec3(1.0, 0.68, 0.36) : pick < 0.72 ? vec3(1.0, 0.45, 0.72) : pick < 0.88 ? vec3(0.35, 0.92, 0.88) : vec3(0.6, 1.0, 0.62);
			float flick = 1.0 - step(0.985, hash(vec3(id, floor(TIME * 3.0)))) * step(0.9, pick);
			// Far away the grid melts into an even glow so it never shimmers.
			float glass = mix(custom.g * 0.4, frame, near);
			color = mix(color, color * 0.3, glass);
			glow = lamp * glass * mix(custom.g * 0.6, lit * flick, near) * 0.45;
			// A frame round each window.
			float rim = max(step(0.24, f.x) * step(f.x, 0.76) * step(0.18, f.y) * step(f.y, 0.86), 0.0) * (1.0 - frame);
			rim *= step(length((f - vec2(0.5, 0.6)) * vec2(1.0, 1.25)), 0.27) + step(f.y, 0.6);
			color = mix(color, color * 0.72, clamp(rim, 0.0, 1.0) * near * 0.6);
			if (custom.a > 0.5 && custom.a < 1.5) {
				float band = 1.0 - smoothstep(0.0, 0.08, abs(fract(up / 14.4) - 0.04));
				color = mix(color, lin(vec3(0.85, 0.62, 0.32)), band * near);
			}
		} else if (!side && !round && kind == 0) {
			// Flat roofs: darker, with a soft glow at the rim.
			vec2 p = local_m.xz;
			vec2 rim = scale_m.xz * 0.5 - abs(p);
			float edge = 1.0 - smoothstep(0.0, 0.6, min(rim.x, rim.y));
			color *= 0.7;
			glow = lin(vec3(1.0, 0.6, 0.85)) * edge * 0.18 * step(0.5, local_n.y);
		}
		ALBEDO = color;
		EMISSION = glow + (kind == 5 ? base * 0.12 : vec3(0.0));
		ROUGHNESS = kind == 5 ? 0.15 : 0.82;
		METALLIC = kind == 5 ? 0.2 : 0.02;
	}
}
