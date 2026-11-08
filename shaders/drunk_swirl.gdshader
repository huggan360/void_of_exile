shader_type canvas_item;
// Drunk: the view swirls and doubles a little, more with every drink.
uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform float strength = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r = length(c);
	float t = TIME;
	float angle = strength * 0.35 * sin(t * 0.9) * (1.0 - smoothstep(0.0, 0.75, r));
	c = mat2(vec2(cos(angle), -sin(angle)), vec2(sin(angle), cos(angle))) * c;
	vec2 wave = vec2(sin(uv.y * 9.0 + t * 1.7), cos(uv.x * 7.0 + t * 1.3)) * 0.006 * strength;
	vec2 swirl = c + 0.5 + wave;
	vec2 ghost = vec2(sin(t * 0.7), cos(t * 0.5)) * 0.012 * strength;
	vec3 color = mix(texture(screen, swirl).rgb, texture(screen, swirl + ghost).rgb, 0.35 * min(strength, 1.0));
	// A warm, soft vignette as it gets worse.
	color *= 1.0 - smoothstep(0.35, 0.9, r) * 0.3 * min(strength, 1.0);
	COLOR = vec4(color, 1.0);
}
