shader_type spatial;
render_mode cull_back;
// Voxel blocks in vertex colours; alpha is how much a block glows (crystal
// ore), with a slow shimmer.
varying float glow;
void vertex() {
	glow = COLOR.a;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = mix(0.95, 0.35, glow);
	EMISSION = COLOR.rgb * glow * (0.75 + 0.25 * sin(TIME * 1.7 + FRAGCOORD.x * 0.002));
}
