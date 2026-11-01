shader_type spatial;
// Procedural voxel textures for terrain blocks.
//
// Every block face is a grid of `texels` x `texels` little voxel-pixels. Each
// texel is colored from the block's palette (color_a..color_e) by a `style`
// (grass, sand, cobble...). Texels are hashed from their world position, so
// no two blocks look alike and nothing visibly tiles. Blocks.gd defines each
// block's style and colors; add a new texture there by picking a style and
// a palette.

const int SPECKLE = 0;  // a/b/c mix, d = rare pebbles
const int GRASS = 1;    // a/b/c greens, d = flowers, e = dirt (sides)
const int SAND = 2;     // a/b grains, c = ripples, d = shells
const int COBBLE = 3;   // a/b stones, c = mortar cracks, e = speckle
const int CRACKED = 4;  // a/b ground, c = crack edges, d = glowing crack core
const int SNOW = 5;     // a/b snow, d = sparkle, e = rock (sides)
const int LAVA = 6;     // a = crust, b/c = hot flow (animated, glowing)
const int TILES = 7;    // a/b tiles, c = grout, e = speckle
const int BRICK = 8;    // a/b bricks, c = mortar
const int MOSS = 9;     // a/b/c moss, d = glowing spores, e = rock (sides)
const int CRYSTAL = 10; // a/b facets, c = glints (glowing)
const int ICE = 11;     // a/b ice, c = streaks

uniform int style = 0;
uniform vec3 color_a : source_color = vec3(0.5);
uniform vec3 color_b : source_color = vec3(0.45);
uniform vec3 color_c : source_color = vec3(0.4);
uniform vec3 color_d : source_color = vec3(0.6);
uniform vec3 color_e : source_color = vec3(0.35);
uniform float emission = 0.0;
uniform float roughness = 0.9;
uniform float texels = 16.0;
uniform float macro_variation = 0.08;  // large soft light/dark patches
uniform float edge_darkness = 0.14;    // darker block outlines

varying vec3 world_pos;
varying vec3 world_normal;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float hash2(vec2 p) {
	return hash3(vec3(p, 3.7));
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), f.x),
			mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), f.x), f.y);
}

float fbm2(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += noise2(p) * a;
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

// Distance to the nearest edge between cobblestones (cells ~5 texels big).
float cobble_edge(vec2 p, out vec2 stone_id) {
	vec2 g = floor(p);
	float d1 = 9.0;
	float d2 = 9.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = g + vec2(float(x), float(y));
			vec2 point = c + vec2(hash2(c), hash2(c + 9.1)) * 0.8 + 0.1;
			float d = length(p - point);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				stone_id = c;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	return d2 - d1;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = world_normal;
	vec3 an = abs(n);
	vec3 cell = floor(world_pos - n * 0.5);
	vec3 f = world_pos - cell;
	bool top = n.y > 0.5;
	bool side = an.y < 0.5;
	// Face coordinates: on side faces, uv.y runs from the block's bottom (0) to top (1).
	vec2 uv = top || n.y < -0.5 ? f.xz : (an.x > 0.5 ? f.zy : f.xy);
	vec2 face_world = top || n.y < -0.5 ? world_pos.xz : (an.x > 0.5 ? world_pos.zy : world_pos.xy);
	vec2 t = floor(uv * texels);
	// Texel id unique in the world, and a texel-snapped position (pixel look).
	vec3 tw = floor(world_pos * texels - n * 0.5);
	vec2 q = (floor(face_world * texels) + 0.5) / texels;
	float r = hash3(tw);
	float r2 = hash3(tw + 17.31);
	float column = hash2(vec2(tw.x, tw.z) + cell.y * 3.1);  // per vertical texel column
	float from_top = texels - 1.0 - t.y;  // texel rows below the top edge (sides)

	vec3 col = color_a;
	float glow = 0.0;

	if (style == SPECKLE) {
		col = r < 0.55 ? color_a : (r < 0.9 ? color_b : color_c);
		if (r2 < 0.03) col = color_d;
	} else if (style == GRASS || style == MOSS || style == SNOW) {
		vec3 surface = r < 0.45 ? color_a : (r < 0.85 ? color_b : color_c);
		if (style == SNOW) {
			surface = mix(color_a, color_b, step(0.55, fbm2(q * 1.3)));
			if (r2 < 0.012) { surface = color_d; glow = 0.6; }
		} else if (style == GRASS && r2 < 0.012) {
			surface = color_d;  // flowers
		} else if (style == MOSS && r2 < 0.018) {
			surface = color_d;  // glowing spores
			glow = 1.0;
		}
		vec3 under = r < 0.6 ? color_e : color_e * 0.85;
		if (top) {
			col = surface;
		} else if (side) {
			float fringe = 2.0 + floor(column * 3.0);  // ragged overhang
			col = from_top < fringe ? surface : under;
			if (from_top >= fringe) glow = 0.0;
		} else {
			col = under;
			glow = 0.0;
		}
	} else if (style == SAND) {
		col = r < 0.5 ? color_a : color_b;
		float ripple = sin((q.x * 0.7 + q.y * 0.4) * 6.0 + fbm2(q * 0.3) * 6.0);
		if (top && ripple > 0.7) col = mix(col, color_c, 0.7);
		if (r2 < 0.008) col = color_d;
	} else if (style == COBBLE) {
		vec2 stone;
		float e = cobble_edge(face_world * texels / 5.0, stone);
		col = hash2(stone + cell.xz) < 0.5 ? color_a : color_b;
		if (r2 < 0.08) col = color_e;
		if (e < 0.18) col = color_c;
	} else if (style == CRACKED) {
		col = r < 0.6 ? color_a : color_b;
		// Long thin cracks, only in some patches of ground.
		float patch = fbm2(q * 0.18 + 7.0);
		float crack = abs(fbm2(q * 0.8) - 0.5);
		if (patch > 0.52 && crack < 0.025) col = color_c;
		if (patch > 0.56 && crack < 0.01) { col = color_d; glow = 1.0; }
	} else if (style == LAVA) {
		vec2 flow_p = q * 0.7 + vec2(TIME * 0.06, TIME * 0.035);
		float flow = fbm2(flow_p);
		float crust = fbm2(q * 1.5 - TIME * 0.02);
		col = mix(color_b, color_c, smoothstep(0.45, 0.8, flow));
		glow = 1.0 + 0.25 * sin(TIME * 2.0 + flow * 12.0);
		if (crust > 0.63) { col = color_a; glow = 0.15; }
	} else if (style == TILES) {
		vec2 tile = floor(t / 8.0);
		col = hash3(cell + vec3(tile, 0.0) * 7.0) < 0.5 ? color_a : color_b;
		if (r2 < 0.05) col = color_e;
		if (mod(t.x, 8.0) == 0.0 || mod(t.y, 8.0) == 0.0) col = color_c;
	} else if (style == BRICK) {
		if (side) {
			float row = floor(t.y / 4.0);
			float shift = mod(row, 2.0) * 4.0;
			float brick = floor((t.x + shift) / 8.0);
			col = hash3(cell + vec3(row, brick, 0.0) * 5.0) < 0.5 ? color_a : color_b;
			if (mod(t.y, 4.0) == 0.0 || mod(t.x + shift, 8.0) == 0.0) col = color_c;
		} else {
			col = r < 0.5 ? color_a : color_b;
		}
	} else if (style == CRYSTAL) {
		float band = floor(fbm2(q * 2.0) * 4.0) / 3.0;
		col = mix(color_a, color_b, band);
		glow = 0.8 + band * 0.4;
		if (r2 < 0.05) { col = color_c; glow = 1.6; }
	} else if (style == ICE) {
		col = r < 0.5 ? color_a : color_b;
		if (fract((uv.x + uv.y) * 2.5 + column * 0.15) < 0.07) col = color_c;
	}

	vec2 to_edge = min(uv, 1.0 - uv);
	float edge = 1.0 - smoothstep(0.0, 1.5 / texels, min(to_edge.x, to_edge.y));
	float macro = (fbm2(world_pos.xz * 0.05) - 0.5) * 2.0 * macro_variation;
	vec3 ao = srgb_to_linear(COLOR.rgb);  // ambient occlusion baked by the mesher
	ALBEDO = col * (1.0 + macro) * (1.0 - edge_darkness * edge) * ao;
	EMISSION = col * glow * emission;
	ROUGHNESS = roughness;
}
