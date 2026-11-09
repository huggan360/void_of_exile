// Vesperis's farmland layout, shared by the ground (city_ground) and mirrored
// exactly on the CPU by CityCountry.field() (integer hashing, so both agree
// on every field). p is a point on the ground relative to the planet's centre (m).

uvec3 farm_pcg(uvec3 v) {
	v = v * 1664525u + 1013904223u;
	v.x += v.y * v.z; v.y += v.z * v.x; v.z += v.x * v.y;
	v ^= v >> 16u;
	v.x += v.y * v.z; v.y += v.z * v.x; v.z += v.x * v.y;
	return v;
}

vec3 farm_hash3i(ivec3 c, int salt) {
	return vec3(farm_pcg(uvec3(c + ivec3(salt * 7919, salt * 104729, salt * 1299709)))) / 4294967295.0;
}

// The field round p: a 3D Voronoi over the sphere with wobbled borders, and
// neighbouring plots of the same crop often run together without a hedge.
// Returns (kind: 0 wheat, 1 green crop, 2 ploughed, 3 meadow; metres to the
// border; 1 if that border is a hedge; the field's own shade 0..1). id gets
// the field's hash (id.y is its row direction).
vec4 farm_field(vec3 p, out vec3 id) {
	vec3 w = p + vec3(sin(p.y * 0.031 + p.z * 0.017), sin(p.z * 0.027 + p.x * 0.021), sin(p.x * 0.029 + p.y * 0.019)) * 7.0
		+ vec3(sin(p.z * 0.11), sin(p.x * 0.13), sin(p.y * 0.12)) * 1.6;
	float size = 40.0;
	ivec3 g = ivec3(floor(w / size));
	float d1 = 1e9;
	float d2 = 1e9;
	ivec3 c1 = g;
	ivec3 c2 = g;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				ivec3 cell = g + ivec3(x, y, z);
				float d = distance(w, (vec3(cell) + 0.1 + 0.8 * farm_hash3i(cell, 0)) * size);
				if (d < d1) { d2 = d1; c2 = c1; d1 = d; c1 = cell; }
				else if (d < d2) { d2 = d; c2 = cell; }
			}
		}
	}
	id = farm_hash3i(c1, 1);
	vec3 id2 = farm_hash3i(c2, 1);
	// Plots of one farm share a crop: the crop follows a coarser cell.
	vec3 farm_id = farm_hash3i(ivec3(floor(w / 130.0)), 2);
	if (farm_hash3i(c1, 3).x < 0.55) id.x = farm_id.x;
	if (farm_hash3i(c2, 3).x < 0.55) id2.x = farm_id.x;
	float kind1 = id.x < 0.42 ? 0.0 : id.x < 0.64 ? 1.0 : id.x < 0.8 ? 2.0 : 3.0;
	float kind2 = id2.x < 0.42 ? 0.0 : id2.x < 0.64 ? 1.0 : id2.x < 0.8 ? 2.0 : 3.0;
	bool hedged = kind1 != kind2 || farm_hash3i(c1 + c2, 4).y < 0.35;
	return vec4(kind1, (d2 - d1) * 0.5, hedged ? 1.0 : 0.0, id.z);
}

// The rows a field is sown in: 0..1 across a 0.9 m row (at = the face's ground coordinates).
float farm_row(vec2 at, vec3 id) {
	float a = id.y * 3.14159;
	return fract(dot(at, vec2(-sin(a), cos(a))) / 0.9);
}
