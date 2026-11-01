shader_type spatial;
render_mode unshaded, cull_disabled;
void vertex() {
	VERTEX.x += sin(TIME * 3.0 + VERTEX.y * 0.7) * 0.15;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * (1.8 + sin(TIME * 5.0 + VERTEX.x) * 0.25);
}
