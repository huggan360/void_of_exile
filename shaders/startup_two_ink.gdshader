shader_type canvas_item;
// Keep the startup artwork to two inks, including texture edge pixels.
uniform vec3 ink : source_color = vec3(0.025, 0.025, 0.025);
uniform vec3 paper : source_color = vec3(0.93, 0.93, 0.93);
varying vec4 modulation;
void vertex() {
	modulation = COLOR;
}
void fragment() {
	vec4 art = texture(TEXTURE, UV);
	float lightness = dot(art.rgb, vec3(0.2126, 0.7152, 0.0722));
	COLOR = vec4(mix(ink, paper, step(0.45, lightness)), art.a) * modulation;
}
