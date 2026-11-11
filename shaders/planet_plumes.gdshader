shader_type spatial;
// A planet's air streaming out into space, like a slow solar storm: a soft
// corona round the limb with drifting streamers in its sky and dusk colours,
// brightest on the sun side. A quad turned toward the camera's position (not
// its view direction, so it never tilts at the screen's edges), scale = the
// planet's radius x `span`; the planet hides it where it stands in front.
// The streamers are drawn in world space, so looking around never turns them.
// Fades out as you come close, where the atmosphere shell takes over.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec4 sky : source_color = vec4(0.5, 0.9, 0.8, 1.0);
uniform vec4 dusk : source_color = vec4(1.0, 0.6, 0.4, 1.0);
uniform float planet_radius = 600.0;
uniform float span = 7.0;  // the quad's width in planet radii
uniform float strength = 0.4;
uniform float seed = 0.0;
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);

float air_hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float air_noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(air_hash(i), air_hash(i + vec3(1, 0, 0)), f.x), mix(air_hash(i + vec3(0, 1, 0)), air_hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(air_hash(i + vec3(0, 0, 1)), air_hash(i + vec3(1, 0, 1)), f.x), mix(air_hash(i + vec3(0, 1, 1)), air_hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float air_fbm(vec3 p) {
	float total = 0.0;
	float amp = 0.55;
	for (int i = 0; i < 4; i++) {
		total += air_noise(p) * amp;
		p = p * 2.03 + vec3(1.7, 9.2, 4.1);
		amp *= 0.5;
	}
	return total;
}

varying vec3 axis_x;
varying vec3 axis_y;

void vertex() {
	// Turn toward where the camera is, with a steady up (world up, or x when
	// looking straight down on the planet), keeping the node's scale.
	vec3 center = MODEL_MATRIX[3].xyz;
	vec3 facing = normalize(CAMERA_POSITION_WORLD - center);
	vec3 ref = abs(facing.y) < 0.97 ? vec3(0.0, 1.0, 0.0) : vec3(1.0, 0.0, 0.0);
	axis_x = normalize(cross(ref, facing));
	axis_y = cross(facing, axis_x);
	float size = length(MODEL_MATRIX[0].xyz);
	mat4 world = mat4(vec4(axis_x * size, 0.0), vec4(axis_y * size, 0.0), vec4(facing * size, 0.0), vec4(center, 1.0));
	MODELVIEW_MATRIX = VIEW_MATRIX * world;
}

void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(1.0, -1.0) * span;  // in planet radii, y up
	float r = length(p);
	if (r < 0.92 || r > span * 0.5) discard;
	float distance_to = length(CAMERA_POSITION_WORLD - NODE_POSITION_WORLD);
	float shown = smoothstep(planet_radius * 1.6, planet_radius * 3.2, distance_to);
	if (shown <= 0.001) discard;
	vec2 dir = p / r;
	vec3 world_dir = normalize(axis_x * dir.x + axis_y * dir.y);  // out from the planet, in space
	float t = TIME * 0.035;
	// Streamers: noise round the limb in world space (no seam, steady as you
	// look around), drawn outward.
	vec3 q = world_dir * 2.6 + vec3(r * 0.55 - t * 1.6 + seed);
	float streak = air_fbm(q + vec3(0.0, 0.0, seed * 3.1));
	float fine = air_fbm(world_dir * 7.0 + vec3(r * 1.4 - t * 3.0 + seed * 1.7));
	float plume = smoothstep(0.42, 0.78, streak) * (0.55 + 0.6 * fine);
	float sun = 0.55 + 0.45 * dot(world_dir, normalize(sun_dir));
	float limb = exp(-(r - 1.0) * 3.2);  // the bright haze hugging the air
	float reach = exp(-(r - 1.0) * 0.85);  // the storm's long fall-off
	float a = (limb * 0.55 + plume * reach * 1.15) * sun;
	// Soft edges: fade in just outside the planet and at the quad's rim.
	a *= smoothstep(0.92, 1.05, r) * (1.0 - smoothstep(span * 0.38, span * 0.5, r));
	vec3 color = mix(sky.rgb, dusk.rgb, clamp(plume * 0.8 + (1.0 - sun) * 0.3, 0.0, 1.0));
	ALBEDO = color * a * strength * shown;
}
