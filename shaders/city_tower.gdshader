shader_type spatial;
render_mode cull_back;
// Vesperis's buildings (MultiMesh unit shapes: boxes, cylinders, spheres, domes,
// cones, tori). Per instance: COLOR the base colour, INSTANCE_CUSTOM r seed,
// g reserved (windows are separate geometry), b material (1 = glows in COLOR; else
// b*10: 0 plaster, 1 bark, 2 shingles, 3 leaves, 4 stone, 5 water, 6 planks,
// 7 grass, 8 mushroom cap), a the wall mapping (1 brass trims, 2 round: wraps
// round the part).
// Nothing is flat: every surface is cut into small voxels whose tones vary,
// with the material's own pattern on top (bark grooves, shingle rows, bricks,
// leaf clumps). Framed windows use separate non-overlapping meshes.
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
	} else if (kind == 3) {
		// Broad leaf colour variation fades before it becomes subpixel noise.
		float shade = hash(floor(v * 0.1) + seed);
		c = base * (0.88 + shade * 0.18);
	} else if (kind == 7) {
		// Lawns are solid turf. Flowers are real meshes above this surface.
		c = base;
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
	float footprint = max(length(dFdx(w)), length(dFdy(w)));
	return mix(base, c, near * (1.0 - smoothstep(0.06, 0.22, footprint)));
}

void fragment() {
	vec3 base = lin(COLOR.rgb);
	float seed = custom.r * 97.0;
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float near = 1.0 - smoothstep(160.0, 600.0, dist);
	if (custom.b > 0.95) {
		ALBEDO = base * 0.4;
		EMISSION = base * (0.55);
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
		ALBEDO = color;
		EMISSION = glow + (kind == 5 ? base * 0.12 : vec3(0.0));
		ROUGHNESS = kind == 5 ? 0.15 : 0.82;
		METALLIC = kind == 5 ? 0.2 : 0.02;
	}
}
