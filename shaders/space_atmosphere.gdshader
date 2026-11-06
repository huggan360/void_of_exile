shader_type spatial;
render_mode unshaded, blend_add, cull_back, depth_draw_never, shadows_disabled;
uniform vec4 tint : source_color = vec4(0.3, 0.9, 0.7, 1.0);
uniform float strength = 0.25;
void fragment() {
	float rim = pow(1.0 - max(dot(normalize(NORMAL), normalize(VIEW)), 0.0), 3.5);
	ALBEDO = tint.rgb * strength;
	ALPHA = rim * 0.6;
}
