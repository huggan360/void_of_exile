shader_type spatial;
// The Reach's sun: a sphere of churning plasma. Flowing cells of hot gas,
// bright filaments between them, darker at the limb, never fogged.
render_mode unshaded, fog_disabled, shadows_disabled, cull_back;
varying vec3 dir;
float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) { v += noise(p) * a; p = p * 2.03 + vec3(1.7, 9.2, 3.1); a *= 0.5; }
	return v;
}
void vertex() {
	dir = normalize(VERTEX);
}
void fragment() {
	float t = TIME * 0.05;
	// Domain-warped flow: cells boil and drift.
	vec3 p = dir * 4.0;
	vec3 warp = vec3(fbm(p + t), fbm(p + vec3(5.2, 1.3, 2.8) - t), fbm(p + vec3(2.1, 7.7, 4.4) + t * 0.7));
	float plasma = fbm(p * 1.6 + warp * 2.2 + t * 1.5);
	float cells = fbm(p * 9.0 + warp * 4.0 - t * 3.0);
	float filament = pow(1.0 - abs(cells - 0.5) * 2.0, 6.0);
	float limb = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	vec3 deep = vec3(0.9, 0.22, 0.04);
	vec3 hot = vec3(1.0, 0.62, 0.18);
	vec3 white = vec3(1.0, 0.95, 0.8);
	vec3 color = mix(deep, hot, smoothstep(0.3, 0.7, plasma));
	color = mix(color, white, filament * 0.35 + smoothstep(0.66, 0.88, plasma) * 0.3);
	color *= 0.55 + 0.75 * pow(limb, 0.45);
	ALBEDO = color;
	EMISSION = color * 2.2;
}
