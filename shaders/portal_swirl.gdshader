shader_type spatial;
// Swirling portal surface, cut to the arch shape (straight sides + round top).
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec3 color_a : source_color = vec3(0.45, 0.25, 1.0);
uniform vec3 color_b : source_color = vec3(0.2, 0.85, 1.0);
uniform vec2 size = vec2(3.0, 5.5);
uniform float arch_start = 0.73;  // where the round top begins, 0..1 from the bottom
uniform float arch_radius = 0.5;  // relative to the width

void fragment() {
	// p: meters from the bottom center of the opening.
	vec2 p = vec2((UV.x - 0.5) * size.x, (1.0 - UV.y) * size.y);
	float arch_y = arch_start * size.y;
	float r_arch = arch_radius * size.x;
	if (p.y > arch_y && length(p - vec2(0.0, arch_y)) > r_arch) {
		discard;
	}
	vec2 c = p - vec2(0.0, size.y * 0.5);
	float r = length(c);
	float a = atan(c.y, c.x);
	float swirl = sin(a * 3.0 + r * 3.5 - TIME * 2.5) * 0.5 + 0.5;
	float rings = sin(r * 9.0 - TIME * 4.0) * 0.5 + 0.5;
	vec3 col = mix(color_a, color_b, swirl * 0.7 + rings * 0.3);
	float core = 1.0 - smoothstep(0.0, size.y * 0.5, r);
	ALBEDO = col * (1.2 + 2.0 * swirl * core + core);
	ALPHA = 0.88;
}
