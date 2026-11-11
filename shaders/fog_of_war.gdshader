shader_type spatial;
// Fog of war as a soft volume, drawn in one full-screen pass. Unexplored land
// is covered by a layer of fog that hugs the terrain (a heightmap of the
// world, so it climbs mountains and fills valleys). Each pixel marches back
// from the surface it sees toward the camera through that layer, so the fog
// has depth, rolling tops and parallax instead of being painted on the
// ground. Wherever the visible surface itself is unexplored the fog is fully
// opaque: nothing shows through. Explored land, and a soft circle around the
// player, carry no fog at all, so it never films over what you can see.
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D explored_map : filter_linear, repeat_disable;
uniform sampler2D height_map : filter_linear, repeat_disable;
uniform sampler2D noise_map : filter_linear, repeat_enable;
uniform vec2 map_origin;
uniform float map_size = 256.0;
uniform vec2 player_pos;
uniform float reveal_radius = 12.0;
uniform vec3 fog_color : source_color = vec3(0.1);
uniform float fog_opacity : hint_range(0.0, 1.0) = 1.0;
// Fog color (rgb) and opacity (a) of the land underneath, per region (see FogOfWar).
uniform sampler2D region_map : source_color, filter_linear, repeat_disable;
uniform bool use_region_map = false;
uniform bool use_height_map = false;
uniform float flat_ground = 0.0;
uniform float layer_height = 9.0;   // meters of fog above unexplored ground
uniform float density = 0.55;       // extinction per meter inside the layer
uniform float march_distance = 70.0;
uniform float drift = 0.6;          // how fast the fog rolls (m/s)

const int STEPS = 22;

vec2 map_uv(vec2 xz) {
	return (xz - map_origin) / map_size;
}

float revealed(vec2 xz) {
	vec2 uv = map_uv(xz);
	float explored = texture(explored_map, uv).r;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		explored = 0.0; // outside the realm stays hidden
	}
	float near_player = 1.0 - smoothstep(reveal_radius * 0.55, reveal_radius * 1.05, distance(xz, player_pos));
	return max(explored, near_player);
}

float ground(vec2 xz) {
	return use_height_map ? texture(height_map, map_uv(xz)).r : flat_ground;
}

// Two layers of drifting noise, offset by height, for slowly rolling fog.
float billow(vec3 p) {
	float a = texture(noise_map, p.xz * 0.018 + vec2(TIME * drift * 0.011, TIME * drift * 0.006)).r;
	float b = texture(noise_map, p.xz * 0.047 + vec2(p.y * 0.03 - TIME * drift * 0.017, TIME * drift * 0.013)).r;
	return a * 0.65 + b * 0.35;
}

// Fog density at a point: only above unexplored ground, thinning toward a
// rolling top. As land is revealed the layer sinks into the ground.
float fog_at(vec3 p, out float hidden) {
	hidden = 1.0 - revealed(p.xz);
	if (hidden <= 0.001) {
		return 0.0;
	}
	float n = billow(p);
	float top = layer_height * hidden * (0.55 + 0.9 * n);
	float above = p.y - ground(p.xz);
	return hidden * (1.0 - smoothstep(top * 0.35, top, above)) * (0.55 + 0.9 * n);
}

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0); // cover the whole screen
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).x;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	view.xyz /= view.w;
	vec3 surface = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 ray = surface - cam;
	float total = length(ray);
	vec3 dir = ray / max(total, 0.001);
	bool sky = total > 900.0;
	if (sky) {
		// Sky or open sea: treat it as far, unexplored distance.
		surface = cam + dir * 900.0;
		total = 900.0;
	}

	vec4 region = vec4(fog_color, fog_opacity);
	if (use_region_map) {
		region = texture(region_map, clamp(map_uv(surface.xz), vec2(0.0), vec2(1.0)));
	}

	// Solid cover: an unexplored surface is never visible through the fog.
	float surface_hidden = 1.0 - revealed(surface.xz);
	float solid = smoothstep(0.15, 0.85, surface_hidden);
	// Looking up at the sky there is no land to cover: the point "900 m away"
	// is high in the air, and covering it would paint the region map (like
	// the minimap) across the sky. Only at the horizon and below does it count.
	if (sky) {
		solid *= 1.0 - smoothstep(-0.02, 0.06, dir.y);
	}

	// March from the surface back toward the camera through the fog layer,
	// with a per-pixel jitter so the steps never show as bands.
	float span = min(total, march_distance);
	float step_len = span / float(STEPS);
	float jitter = fract(sin(dot(SCREEN_UV * 4096.0, vec2(12.9898, 78.233))) * 43758.5453);
	float optical = 0.0;
	float lit = 0.0;
	for (int i = 0; i < STEPS; i++) {
		float t = (float(i) + jitter) * step_len;
		vec3 p = surface - dir * t;
		float hidden;
		float d = fog_at(p, hidden);
		if (d > 0.0) {
			optical += d * density * step_len;
			// Higher fog catches more light: brighter rolling tops.
			lit += d * step_len * clamp((p.y - ground(p.xz)) / max(layer_height, 0.1), 0.0, 1.0);
		}
		if (optical > 6.0) {
			break;
		}
	}
	float veil = 1.0 - exp(-optical);
	float alpha = max(veil, solid) * region.a;
	float shade = 0.82 + 0.3 * clamp(lit / max(optical / density, 0.001), 0.0, 1.0) + 0.12 * (billow(surface) - 0.5);
	ALBEDO = region.rgb * shade;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
