shader_type spatial;
// A small pixel health bar over a brood ship: always faces the camera and
// keeps the same size on screen, framed, with the lost part flashing white.
render_mode unshaded, cull_disabled, depth_draw_never, depth_test_disabled, fog_disabled, shadows_disabled;
uniform float fill = 1.0;
uniform float ghost = 1.0;
uniform vec4 tint : source_color = vec4(1.0, 0.25, 0.35, 1.0);
uniform float screen_size = 0.011;
void vertex() {
	vec4 center = MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0);
	float scale = -center.z * screen_size;
	VERTEX = (center.xyz + vec3(VERTEX.x * 6.0, VERTEX.y, 0.0) * scale);
	POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
}
void fragment() {
	vec2 px = floor(UV * vec2(60.0, 10.0));
	bool frame = px.x < 1.0 || px.x > 58.0 || px.y < 1.0 || px.y > 8.0;
	float x = (px.x - 1.0) / 57.0;
	vec3 color = vec3(0.04, 0.03, 0.06);
	if (x < ghost) color = vec3(1.0);
	if (x < fill) color = mix(tint.rgb, tint.rgb * 1.4, step(px.y, 2.0));
	if (frame) color = vec3(0.02);
	ALBEDO = color;
	ALPHA = 0.95;
}
