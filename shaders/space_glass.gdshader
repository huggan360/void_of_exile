shader_type spatial;
// The glass of a little space dome: clear in the middle, a soft rim, a
// bright highlight.
render_mode blend_mix, cull_back, depth_draw_never, specular_schlick_ggx;
void fragment() {
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = vec3(0.75, 0.95, 1.0);
	METALLIC = 0.0;
	ROUGHNESS = 0.05;
	SPECULAR = 1.0;
	ALPHA = 0.08 + rim * 0.55;
	EMISSION = vec3(0.6, 0.95, 1.0) * rim * 0.25;
}
