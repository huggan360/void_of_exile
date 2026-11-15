shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float opening = 1.0;
uniform float flash = 0.0;
uniform vec4 earth : source_color = vec4(0.12, 0.09, 0.06, 1.0);
// Surface dungeon doors: a glow that turns slowly in the strata (0 = none).
uniform vec4 glow_color : source_color = vec4(1.0);
uniform float glow_amount = 0.0;
void fragment() {
	// Pixel-stepped lip and nested dark strata imply depth over the intact floor.
	vec2 p = floor((UV - 0.5) * 32.0) / 16.0;
	float edge = length(p * vec2(1.0, 1.08));
	float notch = sin(floor(atan(p.y, p.x) * 9.0) * 7.3) * 0.045;
	if (edge > opening * (0.93 + notch)) discard;
	float strata = floor(edge / max(opening, 0.001) * 7.0) / 7.0;
	vec3 col = mix(vec3(0.001, 0.002, 0.001), earth.rgb * 0.5, pow(strata, 4.0));
	if (glow_amount > 0.0) {
		// Arms of light spiral down into the dark.
		float a = atan(p.y, p.x);
		float arms = sin(a * 3.0 + strata * 9.0 - TIME * 1.6) * 0.5 + 0.5;
		float k = arms * (1.0 - strata) * glow_amount * (0.75 + 0.25 * sin(TIME * 2.1));
		col += glow_color.rgb * floor(k * 4.0) / 4.0;
	}
	ALBEDO = mix(col, vec3(1.0), flash);
}
