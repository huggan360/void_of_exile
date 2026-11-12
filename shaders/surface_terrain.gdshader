shader_type spatial;
// The Surface's terrain: 0.25 m voxels, all block types in one material.
//
// Each block type is a palette row (SurfaceBlocks builds `palette`: five
// colors, then style / emission / roughness), found from the face's atlas
// tile (the mesher writes tile x = 2 x block id). Every voxel takes one color
// from its palette by its style and a hash of its position, with a slight
// brightness jitter like the VOX models, so the ground reads as hand-placed
// voxels. Some styles draw a pattern across voxels in world space (cobbles,
// bricks, planks, rock strata). The mesher's ambient occlusion is in COLOR.

const int SPECKLE = 0;
const int GRASS = 1;
const int SAND = 2;
const int COBBLE = 3;
const int CRACKED = 4;
const int SNOW = 5;
const int LAVA = 6;
const int TILES = 7;
const int BRICK = 8;
const int MOSS = 9;
const int CRYSTAL = 10;
const int ICE = 11;
const int STRATA = 12;  // a/b/c layered rock bands, d = mineral flecks, e = moss on tops
const int PLANKS = 13;  // a/b boards, c = seams, d = nails
const int LEAVES = 14;  // a/b/c leaves, d = flowers

uniform sampler2D palette : filter_nearest;
uniform float atlas_width = 256.0;
uniform float voxel = 0.25;
uniform float jitter = 0.08;
uniform float edge_darkness = 0.1;

varying vec3 world_pos;
varying vec3 world_normal;
varying flat int block_id;

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
	for (int i = 0; i < 3; i++) {
		s += noise2(p) * a;
		p *= 2.03;
		a *= 0.5;
	}
	return s;
}

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

float cobble_edge(vec2 p, out vec2 stone_id) {
	vec2 g = floor(p);
	float d1 = 9.0;
	float d2 = 9.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 c = g + vec2(float(x), float(y));
			vec2 point = c + vec2(hash2(c), hash2(c + 9.1)) * 0.8 + 0.1;
			float d = length(p - point);
			if (d < d1) { d2 = d1; d1 = d; stone_id = c; }
			else if (d < d2) { d2 = d; }
		}
	}
	return d2 - d1;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	block_id = int(floor(UV.x * atlas_width * 0.5 + 0.25));
}

vec3 pal(int row) {
	return srgb_to_linear(texelFetch(palette, ivec2(block_id, row), 0).rgb);
}

void fragment() {
	vec4 info = texelFetch(palette, ivec2(block_id, 5), 0);
	int style = int(info.r * 255.0 + 0.5);
	float emission = info.g * 8.0;
	vec3 ca = pal(0);
	vec3 cb = pal(1);
	vec3 cc = pal(2);
	vec3 cd = pal(3);
	vec3 ce = pal(4);

	vec3 n = world_normal;
	vec3 an = abs(n);
	bool top = n.y > 0.5;
	bool side = an.y < 0.5;
	// The voxel this pixel belongs to, and where in it (0..1 on the face).
	vec3 cell = floor(world_pos / voxel - n * 0.5);
	vec3 f = world_pos / voxel - cell;
	vec2 uv = top || n.y < -0.5 ? f.xz : (an.x > 0.5 ? f.zy : f.xy);
	vec2 face_world = top || n.y < -0.5 ? world_pos.xz : (an.x > 0.5 ? world_pos.zy : world_pos.xy);
	float r = hash3(cell);
	float r2 = hash3(cell + 17.31);
	// Two texels per voxel side for a little grain.
	vec2 sub = floor(uv * 2.0);
	float rs = hash3(cell * 2.0 + vec3(sub, 0.5));
	float patch = fbm2(world_pos.xz * 0.11);

	vec3 col = ca;
	float glow = 0.0;

	if (style == SPECKLE) {
		col = r < 0.5 ? ca : (r < 0.86 ? cb : cc);
		if (r2 < 0.03) col = cd;
	} else if (style == GRASS || style == MOSS || style == SNOW || style == LEAVES) {
		// Patches of lighter and darker grass, a flower voxel now and then.
		float p = r * 0.6 + patch * 0.8;
		vec3 surface = p < 0.62 ? ca : (p < 0.92 ? cb : cc);
		if (style == SNOW) {
			surface = mix(ca, cb, step(0.6, fbm2(world_pos.xz * 0.7) + r * 0.2));
			if (r2 < 0.02) { surface = cd; glow = 0.5; }
		} else if ((style == GRASS || style == LEAVES) && r2 < 0.02) {
			surface = cd;
		} else if (style == MOSS && r2 < 0.02) {
			surface = cd;
			glow = 1.0;
		}
		if (top || style == LEAVES) {
			col = surface;
		} else if (side) {
			// Grass hangs a ragged fringe over the side of its voxel.
			float fringe = 0.45 + hash2(vec2(cell.x + cell.z * 7.0, floor(uv.x * 2.0))) * 0.45;
			col = uv.y > 1.0 - fringe ? surface : ce;
			if (uv.y <= 1.0 - fringe) glow = 0.0;
		} else {
			col = ce;
			glow = 0.0;
		}
	} else if (style == SAND) {
		col = rs < 0.5 ? ca : cb;
		float ripple = sin((world_pos.x * 0.9 + world_pos.z * 0.5) * 3.0 + fbm2(world_pos.xz * 0.3) * 6.0);
		if (top && ripple > 0.75) col = mix(col, cc, 0.6);
		if (r2 < 0.01) col = cd;
	} else if (style == COBBLE) {
		vec2 stone;
		float e = cobble_edge(face_world * 2.6, stone);
		float s = hash2(stone);
		col = s < 0.45 ? ca : (s < 0.85 ? cb : ce);
		if (e < 0.1) col = cc;
		col *= 0.92 + 0.16 * hash2(stone + 3.3);
	} else if (style == CRACKED) {
		col = r < 0.6 ? ca : cb;
		float crack = abs(fbm2(world_pos.xz * 0.9) - 0.5);
		if (patch > 0.5 && crack < 0.03) col = cc;
		if (patch > 0.55 && crack < 0.012) { col = cd; glow = 1.0; }
	} else if (style == LAVA) {
		vec2 q = world_pos.xz;
		float flow = fbm2(q * 0.45 + vec2(TIME * 0.05, TIME * 0.03));
		float crust = fbm2(q * 0.9 - TIME * 0.015);
		col = mix(cb, cc, smoothstep(0.4, 0.8, flow));
		glow = 1.0 + 0.3 * sin(TIME * 2.0 + flow * 12.0);
		if (crust > 0.62) { col = ca; glow = 0.12; }
	} else if (style == TILES) {
		vec2 tile = floor(face_world * 2.0);
		col = hash2(tile) < 0.5 ? ca : cb;
		vec2 g = fract(face_world * 2.0);
		if (g.x < 0.08 || g.y < 0.08) col = cc;
		if (r2 < 0.04) col = ce;
	} else if (style == BRICK) {
		if (side) {
			float row = floor(world_pos.y * 4.0);
			float shift = mod(row, 2.0) * 0.25;
			float along = an.x > 0.5 ? world_pos.z : world_pos.x;
			float brick = floor((along + shift) * 2.0);
			col = hash2(vec2(row, brick)) < 0.5 ? ca : cb;
			if (fract(world_pos.y * 4.0) < 0.12 || fract((along + shift) * 2.0) < 0.06) col = cc;
		} else {
			col = r < 0.5 ? ca : cb;
		}
	} else if (style == CRYSTAL) {
		float band = floor(fbm2(world_pos.xz * 2.0 + world_pos.y) * 4.0) / 3.0;
		col = mix(ca, cb, band);
		glow = 0.8 + band * 0.4;
		if (r2 < 0.06) { col = cc; glow = 1.6; }
	} else if (style == ICE) {
		col = r < 0.5 ? ca : cb;
		if (fract((world_pos.x + world_pos.z) * 1.3 + world_pos.y * 0.7) < 0.06) col = cc;
	} else if (style == STRATA) {
		// Layered rock: bands a few voxels thick that wander a little.
		float y = world_pos.y + fbm2(world_pos.xz * 0.08) * 2.5;
		float band = hash2(vec2(floor(y * 1.3), 4.1));
		col = band < 0.4 ? ca : (band < 0.8 ? cb : cc);
		col *= 0.93 + 0.14 * r;
		if (r2 < 0.025) col = cd;
		if (top && patch + r * 0.3 > 0.72) col = ce;  // moss settles on ledges
	} else if (style == PLANKS) {
		float along = an.x > 0.5 ? world_pos.z : world_pos.x;
		float across = an.x > 0.5 ? world_pos.x : world_pos.z;
		if (top) {
			// Boards run along x; a seam every voxel across them.
			float board = floor(world_pos.z * 4.0);
			col = hash2(vec2(board, floor(world_pos.x * 0.7 + board * 0.37))) < 0.5 ? ca : cb;
			if (fract(world_pos.z * 4.0) < 0.1) col = cc;
			if (fract(world_pos.x * 0.7 + board * 0.37) < 0.03) col = cc;
		} else {
			col = r < 0.5 ? ca : cb;
			if (fract(world_pos.y * 4.0) < 0.1) col = cc;
		}
	}

	// Per-voxel brightness and warmth, like the VOX models.
	float h = r2 - 0.5;
	float warm = hash3(cell + 5.1) - 0.5;
	col *= 1.0 + h * 2.0 * jitter;
	col *= vec3(1.0 + warm * jitter * 0.5, 1.0, 1.0 - warm * jitter * 0.5);
	vec2 to_edge = min(uv, 1.0 - uv);
	float edge = 1.0 - smoothstep(0.0, 0.12, min(to_edge.x, to_edge.y));
	vec3 ao = srgb_to_linear(COLOR.rgb);
	ALBEDO = col * (1.0 - edge_darkness * edge) * ao;
	EMISSION = col * glow * emission;
	ROUGHNESS = info.b;
}
