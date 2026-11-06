shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform vec4 fire_color : source_color = vec4(0.3, 1.0, 0.45, 1.0);
uniform float strength = 0.0;
uniform bool sparkle = false;

void vertex() {
	float pulse = sin(TIME * 9.0 + VERTEX.y * 7.0);
	VERTEX.xz *= 1.0 + pulse * 0.07;
	if (sparkle) {
		VERTEX.y -= mod(TIME * 1.8 + float(INSTANCE_ID) * 0.371, 1.0) * 20.0;
	}
}

void fragment() {
	float pulse = 0.9 + 0.1 * sin(TIME * 13.0 + UV.y * 19.0);
	ALBEDO = fire_color.rgb;
	EMISSION = fire_color.rgb * (1.7 + strength * 2.3) * pulse;
}
