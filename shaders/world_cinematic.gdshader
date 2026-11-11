shader_type canvas_item;
// Applied to the 3D scene before HUD layers: no blur or chromatic distortion.
uniform sampler2D scene : hint_screen_texture, filter_nearest;
uniform float strength : hint_range(0.0, 1.0) = 0.35;
void fragment() {
	vec3 color = texture(scene, SCREEN_UV).rgb;
	float lightness = dot(color, vec3(0.2126, 0.7152, 0.0722));
	float shadows = 1.0 - smoothstep(0.06, 0.48, lightness);
	// A very small teal bias in shade complements the practical amber lights.
	color += vec3(-0.008, 0.008, 0.007) * shadows * strength;
	vec2 p = SCREEN_UV * 2.0 - 1.0;
	float edge = smoothstep(0.35, 1.45, dot(p, p));
	color *= 1.0 - edge * 0.045 * strength;
	float grain = fract(sin(dot(floor(FRAGCOORD.xy) + floor(TIME * 12.0), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
	color += grain * 0.003 * strength;
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
