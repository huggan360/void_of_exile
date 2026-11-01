shader_type canvas_item;
// Behind menus: the game underneath, blurred and darkened, with a vignette.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float blur = 3.0;  // mip level to sample (bigger = blurrier)
uniform float dim = 0.55;  // how much darker
uniform vec3 tint : source_color = vec3(0.12, 0.06, 0.25);

void fragment() {
	vec3 col = vec3(0.0);
	vec2 o = SCREEN_PIXEL_SIZE * exp2(blur);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			col += textureLod(screen_tex, SCREEN_UV + vec2(float(x), float(y)) * o, blur).rgb;
		}
	}
	col /= 9.0;
	float vignette = smoothstep(0.9, 0.3, length(SCREEN_UV - 0.5));
	col = mix(col * (1.0 - dim), tint, 0.25) * (0.6 + 0.4 * vignette);
	COLOR = vec4(col, 1.0);
}
