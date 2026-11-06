shader_type spatial;
render_mode cull_back;
uniform vec4 earth : source_color;
uniform vec4 bright : source_color;
uniform vec4 shade : source_color;
uniform vec4 magic : source_color;
uniform vec4 accent : source_color;
uniform float radius = 150.0;
uniform int biome = 0;
uniform vec3 pad_normal;
varying vec3 ground;
float hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}
float noise(vec3 p) {
	vec3 cell = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(cell), hash(cell + vec3(1,0,0)), f.x), mix(hash(cell + vec3(0,1,0)), hash(cell + vec3(1,1,0)), f.x), f.y), mix(mix(hash(cell + vec3(0,0,1)), hash(cell + vec3(1,0,1)), f.x), mix(hash(cell + vec3(0,1,1)), hash(cell + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() {
	vec3 direction = normalize(VERTEX);
	float arc = acos(clamp(dot(direction, pad_normal), -1.0, 1.0)) * radius;
	float hills = noise(direction * 15.0);
	float distant = smoothstep(205.0, 245.0, arc);
	VERTEX = direction * (1.0 + ((hills - 0.5) * 0.16 * smoothstep(15.0, 24.0, arc) + hills * 2.7 * distant) / radius);
	ground = direction * radius;
}
void fragment() {
	vec3 p = floor(ground * 0.65) / 0.65;
	vec3 n = normalize(ground);
	float broad = noise(n * 7.0 + float(biome) * 13.1);
	float fine = noise(p * 0.12);
	float pattern = broad * 0.7 + fine * 0.3;
	if (biome == 1) pattern = abs(sin(p.x * 0.035 + p.z * 0.045 + broad * 5.0)) * 0.65 + fine * 0.35;
	if (biome == 2) pattern = sin(n.y * 45.0 + broad * 7.0) * 0.17 + broad;
	if (biome == 3) pattern = broad * 0.8 + fine * 0.2;
	if (biome == 4) pattern = pow(abs(sin(p.x * 0.06 + p.y * 0.08) * sin(p.z * 0.07)), 0.3);
	if (biome == 5) pattern = broad * 0.65 + abs(sin(broad * 19.0)) * 0.2 + fine * 0.15;
	if (biome == 6) pattern = broad * 0.6 + sin(fine * 12.0) * 0.2 + 0.2;
	if (biome == 7) {
		float eye = length(vec2(n.x * 1.8, n.y * 0.85));
		pattern = 0.45 + sin(eye * 65.0 + atan(n.y, n.x) * 3.0 + broad * 5.0) * 0.24;
		pattern *= smoothstep(0.07, 0.22, eye);
	}
	float band = floor(clamp(pattern, 0.0, 0.99) * 6.0) / 5.0;
	vec3 color = mix(shade.rgb, earth.rgb, smoothstep(0.05, 0.65, band));
	color = mix(color, bright.rgb, smoothstep(0.55, 0.98, band) * 0.8);
	float vein = step(0.84, pattern) * step(0.52, fine);
	if (biome == 3) {
		// Shoals stay at the collision surface; the ocean shell sits below them.
		if (broad < 0.44) { discard; }
		color = mix(earth.rgb, accent.rgb, step(0.44, broad) * 0.9);
		color = mix(color, shade.rgb, step(0.60, broad) * 0.45);
	}
	color = mix(color, magic.rgb, vein * (biome == 4 ? 0.75 : 0.25));
	ALBEDO = color;
	ROUGHNESS = 0.94;
	EMISSION = magic.rgb * vein * (biome == 4 || biome == 6 ? 0.5 : 0.08);
}
