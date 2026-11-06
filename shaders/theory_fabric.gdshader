shader_type spatial;
render_mode cull_disabled;
uniform bool torn = false;
void fragment() {
	if (!FRONT_FACING) NORMAL = -NORMAL;
	vec2 threads = UV * vec2(720.0, 1000.0);
	float detail = 1.0 - smoothstep(0.4, 1.4, max(fwidth(threads.x), fwidth(threads.y)));
	float weave = sin(threads.x * 6.28318) * sin(threads.y * 6.28318) * 0.035 * detail;
	float fold = 0.94 + 0.06 * cos(UV.x * 25.13274);
	float hem = smoothstep(0.008,0.02,min(UV.x,1.0-UV.x)) * (1.0-smoothstep(0.955,0.98,UV.y));
	vec3 clean = mix(vec3(0.65,0.31,0.39),vec3(0.86,0.67,0.40),step(0.84,fract(UV.x*8.0)));
	vec3 worn = vec3(0.19, 0.16, 0.12);
	float stain = smoothstep(0.4, 0.8, sin(UV.x * 12.0 + sin(UV.y * 6.0)) * 0.5 + UV.y * 0.65);
	ALBEDO = (torn ? mix(worn, vec3(0.035,0.045,0.028), stain * 0.65) : clean) * (1.0 + weave) * fold * mix(0.92,1.0,hem);
	ROUGHNESS = 0.96;
	SPECULAR = 0.12;
}
