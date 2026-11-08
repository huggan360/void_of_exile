shader_type sky;
render_mode use_half_res_pass;
// Deep, dark space: thin veils of colour in the Haven, bruised dark toward
// the Gloam (+Z), sparse stars and the warm Haven sun with its halo.
uniform vec3 haven_green : source_color = vec3(0.06, 0.2, 0.14);
uniform vec3 haven_pink : source_color = vec3(0.22, 0.07, 0.17);
uniform vec3 sun_dir = vec3(-0.47, 0.32, -0.83);
// Inside a planet's air: its day sky replaces space (air_mix 0..1).
uniform float air_mix = 0.0;
uniform vec3 air_up = vec3(0.0, 1.0, 0.0);
uniform vec3 air_top : source_color = vec3(0.3, 0.6, 0.8);
uniform vec3 air_horizon : source_color = vec3(0.8, 0.9, 0.9);
float hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
float cloud(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(cell), hash(cell + vec3(1,0,0)), f.x), mix(hash(cell + vec3(0,1,0)), hash(cell + vec3(1,1,0)), f.x), f.y), mix(mix(hash(cell + vec3(0,0,1)), hash(cell + vec3(1,0,1)), f.x), mix(hash(cell + vec3(0,1,1)), hash(cell + vec3(1,1,1)), f.x), f.y), f.z);
}
float stars(vec3 ray, float density, float threshold) {
	vec3 p = ray * density;
	vec3 cell = floor(p);
	vec3 center = vec3(hash(cell), hash(cell + 17.0), hash(cell + 43.0));
	float star = 1.0 - smoothstep(0.025, 0.13, length(fract(p) - center));
	return star * step(threshold, hash(cell + 71.0));
}
vec3 nebula(vec3 ray) {
	float haven = 1.0 - smoothstep(-0.65, 0.65, ray.z);
	vec3 p = ray * vec3(3.0, 6.0, 3.0) + vec3(7.0, 3.0, -2.0);
	float large = cloud(p);
	float curl = cloud(p * 2.1 + large * 2.0);
	float fine = cloud(p * 5.0);
	float mist = pow(clamp(large * 0.65 + curl * 0.3 + fine * 0.05, 0.0, 1.0), 3.4);
	vec3 peaceful = mix(haven_green, haven_pink, smoothstep(0.38, 0.7, curl)) * mist;
	vec3 gloam = mix(vec3(0.03, 0.002, 0.02), vec3(0.11, 0.008, 0.03), curl) * mist;
	return mix(vec3(0.0015, 0.001, 0.005) + gloam, vec3(0.003, 0.006, 0.01) + peaceful, haven);
}
vec3 day_sky(vec3 ray, vec3 sun) {
	float elevation = dot(ray, air_up);
	vec3 sky = mix(air_horizon, air_top, smoothstep(-0.02, 0.55, elevation));
	sky = mix(sky, air_horizon * 0.55, smoothstep(0.0, -0.25, elevation));
	// Light falls off on the night side and warms toward the sun.
	float day = smoothstep(-0.2, 0.35, dot(sun, air_up));
	float toward = pow(max(dot(ray, sun), 0.0), 6.0);
	sky = mix(sky * 0.12, sky, day) + vec3(1.0, 0.75, 0.45) * toward * 0.35 * day;
	return sky;
}
void sky() {
	vec3 ray = normalize(EYEDIR);
	vec3 sun = normalize(sun_dir);
	float facing = max(dot(ray, sun), 0.0);
	// The sun itself is a real body now (SpaceBackdrop); the sky keeps a faint warm haze toward it.
	vec3 sunlight = vec3(1.0, 0.7, 0.45) * pow(facing, 40.0) * 0.1;
	if (AT_HALF_RES_PASS || AT_CUBEMAP_PASS) {
		COLOR = mix(nebula(ray), day_sky(ray, sun), air_mix) + sunlight * 0.3;
	} else {
		float haven = 1.0 - smoothstep(-0.65, 0.65, ray.z);
		float pinpoints = stars(ray, 330.0, 0.93) * 1.4 + stars(ray + vec3(0.23), 130.0, 0.988) * 3.0;
		vec3 star_color = mix(vec3(0.8, 0.9, 1.0), vec3(1.0, 0.79, 0.52), hash(floor(ray * 130.0)));
		float day = smoothstep(-0.2, 0.35, dot(sun, air_up)) * air_mix;
		COLOR = HALF_RES_COLOR.rgb + pinpoints * star_color * mix(0.3, 0.85, haven) * (1.0 - day) + sunlight;
	}
}
