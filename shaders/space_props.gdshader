shader_type spatial;
render_mode cull_back;
varying float radiance;
void vertex() {
	radiance = INSTANCE_CUSTOM.r;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.84;
	EMISSION = COLOR.rgb * radiance;
}
