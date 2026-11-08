shader_type spatial;
// The sun's corona: a flickering crown of rays and a soft glow, facing the
// camera, seen across the whole Reach.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform float inner = 0.33;
float hash(float n) { return fract(sin(n) * 43758.5453); }
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}
void fragment() {
	vec2 c = UV - 0.5;
	float r = length(c) * 2.0;
	float a = atan(c.y, c.x);
	float rays = 0.0;
	for (int i = 0; i < 3; i++) {
		float k = float(i) * 7.0 + 3.0;
		rays += pow(0.5 + 0.5 * sin(a * k + TIME * (0.2 + float(i) * 0.13) + sin(a * 3.0 + TIME * 0.3) * 2.0), 6.0);
	}
	float falloff = smoothstep(1.0, inner, r);
	float glow = pow(falloff, 2.5);
	float crown = rays * pow(falloff, 4.0) * smoothstep(inner * 0.9, inner * 1.1, r);
	ALBEDO = vec3(1.0, 0.55, 0.18) * (glow * 0.9 + crown * 0.7);
}
