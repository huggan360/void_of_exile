shader_type spatial;
render_mode cull_back;
// Vesperis streets on the whole sphere: the same equal-angle cube grid as
// CityLayout. Roads on the cell edges (dark, with glowing lane marks and
// crosswalks), warm paver sidewalks with a neon kerb, block courtyards.
uniform vec3 planet_center;
uniform float planet_radius = 1000.0;
uniform float cells = 28.0;
uniform float road = 6.0;
uniform float walk = 4.0;
uniform vec4 asphalt : source_color = vec4(0.11, 0.10, 0.15, 1.0);
uniform vec4 paver : source_color = vec4(0.36, 0.30, 0.38, 1.0);
uniform vec4 court : source_color = vec4(0.27, 0.23, 0.31, 1.0);
uniform vec4 lane_glow : source_color = vec4(1.0, 0.72, 0.42, 1.0);
uniform vec4 kerb_glow : source_color = vec4(0.42, 0.94, 0.88, 1.0);
varying vec3 world_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 dir = normalize(world_pos - planet_center);
	vec3 ad = abs(dir);
	vec3 n; vec3 a; vec3 b;
	if (ad.x >= ad.y && ad.x >= ad.z) { n = vec3(sign(dir.x), 0.0, 0.0); }
	else if (ad.y >= ad.z) { n = vec3(0.0, sign(dir.y), 0.0); }
	else { n = vec3(0.0, 0.0, sign(dir.z)); }
	a = vec3(n.y, n.z, n.x);
	b = cross(n, a);
	float d = dot(dir, n);
	vec2 uv = vec2(atan(dot(dir, a) / d), atan(dot(dir, b) / d)) * 4.0 / 3.14159265;
	vec2 g = (uv + 1.0) * 0.5 * cells;
	// Metres per cell along each axis (equal-angle: wider near the face middle).
	vec2 t = uv * 0.785398;
	vec2 m_per = planet_radius * 1.570796 / cells * vec2(cos(t.y), cos(t.x)) * 0.98;
	vec2 f = fract(g) - 0.5;
	vec2 edge = (0.5 - abs(f)) * m_per;  // metres to the nearest road centre line
	float to_road = min(edge.x, edge.y);
	vec3 color = court.rgb;
	float glow = 0.0;
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float detail = 1.0 - smoothstep(60.0, 260.0, dist);
	if (to_road < road) {
		color = asphalt.rgb * (0.9 + hash(floor(world_pos.xz * 2.0)) * 0.12 * detail);
		// Along which road are we? The one whose centre line is nearest.
		bool along_x = edge.y < edge.x;
		float across = along_x ? edge.y : edge.x;
		float run = along_x ? f.x * m_per.x : f.y * m_per.y;
		float other = along_x ? edge.x : edge.y;
		// Dashed glowing centre line and lane edges, crosswalks at the corners.
		float dash = step(0.5, fract(run / 4.0));
		if (other > road + walk + 1.0) {
			glow += (1.0 - smoothstep(0.08, 0.16, abs(across))) * dash * 1.2 * detail;
			glow += (1.0 - smoothstep(0.06, 0.12, abs(across - (road - 0.6)))) * 0.6 * detail;
		} else if (other > road && other < road + walk) {
			float stripe = step(0.5, fract(across / 1.2));
			color = mix(color, vec3(0.86, 0.80, 0.70), stripe * 0.85 * detail);
		}
	} else if (to_road < road + walk) {
		// Sidewalk pavers in a herringbone-ish brick with a glowing kerb.
		vec2 brick = vec2(edge.x, edge.y) / vec2(0.9, 0.45);
		vec2 bf = fract(brick + vec2(step(0.5, fract(brick.y * 0.5)) * 0.5, 0.0));
		float seam = 1.0 - smoothstep(0.0, 0.08, min(min(bf.x, 1.0 - bf.x), min(bf.y, 1.0 - bf.y)));
		color = paver.rgb * (0.92 + hash(floor(brick)) * 0.14) * (1.0 - seam * 0.25 * detail);
		glow += (1.0 - smoothstep(0.08, 0.2, to_road - road)) * 0.9;
		color = mix(color, kerb_glow.rgb, (1.0 - smoothstep(0.08, 0.2, to_road - road)) * 0.6);
	} else {
		vec2 tile = world_pos.xz / 2.0;
		float seam = 1.0 - smoothstep(0.0, 0.04, min(fract(tile.x), fract(tile.y)));
		color = court.rgb * (1.0 - seam * 0.2 * detail);
	}
	ALBEDO = color;
	ROUGHNESS = 0.7;
	vec3 glow_color = to_road < road ? lane_glow.rgb : kerb_glow.rgb;
	EMISSION = glow_color * glow * 0.9;
}
