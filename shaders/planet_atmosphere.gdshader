shader_type spatial;
// A planet's air, drawn on the inside of a shell around it so it works from
// orbit and from the ground: light scattered along the view ray through the
// shell, stopped by the planet and by the scene depth. Not fogged, so the
// glow of distant worlds still reaches across dark space.
render_mode unshaded, blend_mix, cull_front, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;

uniform vec4 sky : source_color = vec4(0.5, 0.9, 0.8, 1.0);
uniform vec4 dusk : source_color = vec4(1.0, 0.6, 0.4, 1.0);
uniform float planet_radius = 600.0;
uniform float atmo_radius = 720.0;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform float strength = 1.0;
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 sphere(vec3 o, vec3 d, float r) {
	float b = dot(o, d);
	float c = dot(o, o) - r * r;
	float h = b * b - c;
	if (h < 0.0) return vec2(-1.0, -2.0);
	h = sqrt(h);
	return vec2(-b - h, -b + h);
}

void fragment() {
	vec3 center = NODE_POSITION_WORLD;
	vec3 eye = CAMERA_POSITION_WORLD;
	vec3 d = normalize(world_pos - eye);
	vec3 o = eye - center;
	vec2 shell = sphere(o, d, atmo_radius);
	float t0 = max(shell.x, 0.0);
	float t1 = shell.y;
	vec2 ground = sphere(o, d, planet_radius);
	if (ground.x > 0.0) t1 = min(t1, ground.x);
	// Terrain and props inside the air stop the ray too.
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	float scene = length(view.xyz / view.w);
	t1 = min(t1, scene);
	if (t1 <= t0) discard;
	float thick = atmo_radius - planet_radius;
	float scale_h = thick * 0.2;
	float dt = (t1 - t0) / 10.0;
	float optical = 0.0;
	float lit = 0.0;
	float warm = 0.0;
	for (int i = 0; i < 10; i++) {
		vec3 p = o + d * (t0 + (float(i) + 0.5) * dt);
		float h = max(length(p) - planet_radius, 0.0);
		float density = exp(-h / scale_h) * dt;
		float sun = dot(normalize(p), sun_dir);
		optical += density;
		lit += density * smoothstep(-0.28, 0.35, sun);
		warm += density * exp(-pow(sun * 4.0, 2.0));
	}
	float k = optical / thick;
	// Clear looking straight down, glowing at the limb where the path is long.
	float alpha = 1.0 - exp(-k * k * 4.0);
	vec3 color = mix(sky.rgb, dusk.rgb, clamp(warm / max(optical, 0.001), 0.0, 1.0) * 0.7);
	color *= 0.15 + 0.9 * lit / max(optical, 0.001);
	ALBEDO = color;
	ALPHA = clamp(alpha * strength, 0.0, 0.8);
}
