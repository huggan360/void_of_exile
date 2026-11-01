shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec4 moss : source_color;
uniform vec4 ember : source_color;
uniform float fade = 1.0;

void fragment() {
	// Quantized coordinates keep the magical surface as crisp as the voxel world.
	vec2 p = (floor(UV * 96.0) + 0.5) / 96.0 * 2.0 - 1.0;
	float r = length(p);
	if (r > 0.99) discard;
	float a = atan(p.y, p.x);
	float spiral = sin(a * 5.0 + r * 19.0 - TIME * 2.8);
	float bands = step(0.52, spiral);
	float flecks = step(0.88, sin(a * 17.0 - r * 35.0 + TIME * 3.0));
	float rim = step(0.90, r) * (0.65 + 0.35 * step(0.0, sin(a * 14.0 + TIME * 2.0)));
	float inner = smoothstep(0.06, 0.65, r);
	vec3 dark = moss.rgb * vec3(0.045, 0.065, 0.07);
	vec3 col = mix(dark, moss.rgb * (0.22 + bands * 0.65), inner * (0.25 + bands * 0.60));
	col += ember.rgb * flecks * bands * inner * 0.35;
	col = mix(col, mix(moss.rgb, ember.rgb, step(0.2, sin(a * 3.0 - TIME))) * 1.15, rim);
	ALBEDO = col;
	EMISSION = col * (0.40 + 0.08 * sin(TIME * 2.0));
	ALPHA = fade * (0.92 + rim * 0.08);
}
