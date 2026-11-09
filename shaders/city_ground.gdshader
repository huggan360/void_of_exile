shader_type spatial;
render_mode cull_back;
// Vesperis's streets on the whole sphere, from CityRoads.texture(): the nudged
// corners, the bent streets between them, diagonals and roundabouts. Asphalt
// with pixel road paint (dashed middle, edge lines, zebra crossings, the ring's
// lane), concrete sidewalk slabs laid along the street with a kerb of pale
// stones, cobbled courtyards and grassy roundabout islands. Everything is
// sampled on a 10 cm pixel grid so it reads as pixel art up close, and melts
// into flat colour far away. Also drawn on the raised sidewalks (CityPlanet),
// whose side faces get the kerb stones.
uniform vec3 planet_center;
uniform float planet_radius = 1000.0;
uniform float cells = 28.0;
uniform float road = 4.5;
uniform float walk = 3.5;
uniform float ring = 6.0;
uniform float kerb_height = 0.16;
uniform sampler2D roads : filter_nearest;
uniform sampler2D asphalt_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D slab_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D kerb_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D cobble_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D grass_tex : source_color, filter_nearest, repeat_enable;
varying vec3 world_pos;
varying vec3 world_normal;

int N() { return int(cells + 0.5); }
vec4 fetch(int face, ivec2 n, int k) { return texelFetch(roads, ivec2(n.x * 4 + k, face * (N() + 1) + n.y), 0); }

// Distance along the ground (the radial part removed) from p to q.
vec3 flat_v(vec3 p, vec3 q, vec3 up) { vec3 v = p - q; return v - up * dot(v, up); }

// One street (a, bend m, b; unit directions): keeps the nearest.
// info: x along (m from a), y distance to the nearer end, z that end's island (m).
void street(vec3 p, vec3 up, vec4 a, vec3 m, vec4 b, inout float best, inout vec3 info) {
	vec3 A = a.xyz * planet_radius;
	vec3 M = m * planet_radius;
	vec3 B = b.xyz * planet_radius;
	float l0 = length(M - A);
	float l1 = length(B - M);
	float t0 = clamp(dot(p - A, M - A) / max(l0 * l0, 0.0001), 0.0, 1.0);
	float t1 = clamp(dot(p - M, B - M) / max(l1 * l1, 0.0001), 0.0, 1.0);
	float d0 = length(flat_v(p, mix(A, M, t0), up));
	float d1 = length(flat_v(p, mix(M, B, t1), up));
	float d = min(d0, d1);
	if (d < best) {
		best = d;
		float along = d0 < d1 ? t0 * l0 : l0 + t1 * l1;
		float total = l0 + l1;
		info = along < total - along ? vec3(along, along, a.w) : vec3(along, total - along, b.w);
	}
}

vec3 tex_at(sampler2D t, vec2 metres) {
	vec2 px = floor(metres * 10.0) + 0.5;
	return texture(t, px / vec2(textureSize(t, 0))).rgb;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 up = normalize(world_pos - planet_center);
	vec3 ad = abs(up);
	vec3 n;
	int face;
	if (ad.x >= ad.y && ad.x >= ad.z) { n = vec3(sign(up.x), 0.0, 0.0); face = up.x > 0.0 ? 0 : 1; }
	else if (ad.y >= ad.z) { n = vec3(0.0, sign(up.y), 0.0); face = up.y > 0.0 ? 2 : 3; }
	else { n = vec3(0.0, 0.0, sign(up.z)); face = up.z > 0.0 ? 4 : 5; }
	vec3 ax = vec3(n.y, n.z, n.x);
	vec3 bx = cross(n, ax);
	float dn = dot(up, n);
	vec2 uv = vec2(atan(dot(up, ax) / dn), atan(dot(up, bx) / dn)) * 4.0 / 3.14159265;
	vec2 g = (uv + 1.0) * 0.5 * cells;
	int count = N();
	ivec2 c = clamp(ivec2(floor(g)), ivec2(0), ivec2(count - 1));
	vec3 p = up * planet_radius;
	float best = 1e9;
	vec3 info = vec3(0.0, 1e9, 0.0);
	// Streets along v on this cell's two sides, along u on its two rows, diagonals round about.
	for (int li = 0; li < 2; li++) {
		for (int r = -1; r <= 1; r++) {
			ivec2 a = ivec2(c.x + li, c.y + r);
			if (a.y >= 0 && a.y < count) {
				vec4 m = fetch(face, a, 2);
				if (m.a > 0.5) street(p, up, fetch(face, a, 0), m.xyz, fetch(face, a + ivec2(0, 1), 0), best, info);
			}
			ivec2 h = ivec2(c.x + r, c.y + li);
			if (h.x >= 0 && h.x < count) {
				vec4 m = fetch(face, h, 1);
				if (m.a > 0.5) street(p, up, fetch(face, h, 0), m.xyz, fetch(face, h + ivec2(1, 0), 0), best, info);
			}
		}
	}
	for (int dj = -1; dj <= 1; dj++) {
		for (int di = -1; di <= 1; di++) {
			ivec2 a = c + ivec2(di, dj);
			if (a.x < 0 || a.y < 0 || a.x >= count || a.y >= count) continue;
			vec4 dm = fetch(face, a, 3);
			if (dm.a < 0.5) continue;
			if (dm.a < 1.5) street(p, up, fetch(face, a, 0), dm.xyz, fetch(face, a + ivec2(1, 1), 0), best, info);
			else street(p, up, fetch(face, a + ivec2(1, 0), 0), dm.xyz, fetch(face, a + ivec2(0, 1), 0), best, info);
		}
	}
	// Roundabouts: the ring is carriageway, the island grass.
	float island = -1.0;
	vec2 ring_at = vec2(0.0);
	for (int dj = 0; dj <= 1; dj++) {
		for (int di = 0; di <= 1; di++) {
			vec4 a = fetch(face, c + ivec2(di, dj), 0);
			if (a.w <= 0.0) continue;
			vec3 v = flat_v(p, a.xyz * planet_radius, up);
			float d = length(v);
			float as_road = d - (a.w + ring) + road;
			if (as_road < best) {
				best = as_road;
				info = vec3(atan(dot(v, bx), dot(v, ax)) * d, 1e9, 0.0);
				ring_at = vec2(d, a.w);
			}
			if (d < a.w) { island = d; ring_at = vec2(d, a.w); }
		}
	}
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(90.0, 300.0, dist);
	float height = length(world_pos - planet_center) - planet_radius;
	bool side = dot(world_normal, up) < 0.6;
	vec3 color;
	float glow = 0.0;
	vec3 glow_color = vec3(1.0, 0.78, 0.45);
	vec2 q = floor(vec2(info.x, best) * 10.0) / 10.0 + 0.05;  // the pixel grid along/across the street
	if (side) {
		// A kerb's face: pale stones.
		color = tex_at(kerb_tex, vec2(info.x, 0.9 + kerb_height - height));
		color *= 0.85;
	} else if (island >= 0.0) {
		vec2 at = vec2(dot(p, ax), dot(p, bx));
		color = island > ring_at.y - 0.4 ? tex_at(kerb_tex, vec2(atan(dot(p, bx), dot(p, ax)) * 40.0, 0.3)) : tex_at(grass_tex, at);
	} else if (best < road) {
		vec2 at = vec2(dot(p, ax), dot(p, bx));
		color = tex_at(asphalt_tex, at);
		float paint = 0.0;
		float lane = 0.0;
		float zebra_from = info.z > 0.0 ? info.z + ring + 0.8 : road + 0.6;
		if (ring_at.x > 0.0 && info.y > 1e8) {
			// On a roundabout's ring: a dashed lane and a line round the island.
			float mid = ring_at.y + ring * 0.5;
			lane = step(abs(floor(ring_at.x * 10.0) / 10.0 + 0.05 - mid), 0.1) * step(0.5, fract(q.x / 2.0));
			paint = step(abs(floor(ring_at.x * 10.0) / 10.0 + 0.05 - (ring_at.y + 0.35)), 0.1);
		} else if (info.y < zebra_from) {
			// Inside the junction: bare asphalt.
		} else if (info.y < zebra_from + 3.0) {
			paint = step(0.5, fract(q.y / 0.7)) * step(q.y, road - 0.6);
		} else {
			lane = step(q.y, 0.1) * step(0.5, fract(q.x / 3.0));
			paint = step(abs(q.y - (road - 0.45)), 0.1);
		}
		color = mix(color, vec3(0.78, 0.76, 0.8), paint * 0.9);
		color = mix(color, vec3(0.86, 0.66, 0.3), lane * 0.9);
		glow = lane * 0.35 + paint * 0.05;
	} else if (best < road + walk) {
		float across = best - road;
		if (across < 0.3) {
			color = tex_at(kerb_tex, vec2(info.x, across + 1.2));
		} else {
			color = tex_at(slab_tex, vec2(info.x, across - 0.3));
		}
	} else {
		color = tex_at(cobble_tex, vec2(dot(p, ax), dot(p, bx)));
	}
	// Far away the pixels give way to their average so nothing shimmers.
	vec3 far_color = best < road ? vec3(0.17, 0.15, 0.2) : best < road + walk ? vec3(0.55, 0.52, 0.57) : vec3(0.45, 0.4, 0.46);
	if (island >= 0.0) far_color = vec3(0.24, 0.4, 0.27);
	color = mix(far_color, color, detail);
	ALBEDO = color;
	ROUGHNESS = 0.85;
	EMISSION = glow_color * glow * detail;
}
