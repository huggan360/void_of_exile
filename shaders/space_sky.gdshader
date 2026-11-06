shader_type sky;
render_mode use_half_res_pass;
uniform vec3 haven_green : source_color = vec3(0.12, 0.38, 0.26);
uniform vec3 haven_pink : source_color = vec3(0.42, 0.16, 0.32);
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
	float mist = pow(clamp(large * 0.65 + curl * 0.3 + fine * 0.05, 0.0, 1.0), 2.8);
	vec3 peaceful = mix(haven_green, haven_pink, smoothstep(0.38, 0.7, curl)) * mist * 1.1;
	vec3 gloam = mix(vec3(0.055, 0.006, 0.035), vec3(0.19, 0.018, 0.045), curl) * mist;
	vec3 background = mix(vec3(0.004, 0.002, 0.012) + gloam, vec3(0.008, 0.016, 0.025) + peaceful, haven);
	return background;
}
void sky() {
	vec3 ray = normalize(EYEDIR);
	if (AT_HALF_RES_PASS || AT_CUBEMAP_PASS) {
		COLOR = nebula(ray);
	} else {
		float haven = 1.0 - smoothstep(-0.65, 0.65, ray.z);
		float pinpoints = stars(ray, 330.0, 0.90) * 1.8 + stars(ray + vec3(0.23), 130.0, 0.985) * 3.5;
		vec3 star_color = mix(vec3(0.8, 0.9, 1.0), vec3(1.0, 0.79, 0.52), hash(floor(ray * 130.0)));
		COLOR = HALF_RES_COLOR.rgb + pinpoints * star_color * mix(0.35, 1.0, haven);
	}
}
