shader_type canvas_item;
varying vec4 modulation;
void vertex() { modulation = COLOR; }
void fragment() {
	vec4 art = texture(TEXTURE, UV);
	float value = dot(art.rgb, vec3(0.2126, 0.7152, 0.0722));
	// Fixed screen-space dots retain engraving, removing the generated grey haze.
	vec2 dot_cell = floor(FRAGCOORD.xy / 1.5);
	float threshold = fract(sin(dot(dot_cell, vec2(12.9898, 78.233))) * 43758.5453);
	float ink = step(threshold, smoothstep(0.16, 0.92, value));
	COLOR = vec4(vec3(0.95), art.a * ink) * modulation;
}
