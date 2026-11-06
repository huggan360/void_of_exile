shader_type spatial;
render_mode specular_schlick_ggx;

uniform float emission_strength = 0.0;

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 0.78;
	METALLIC = 0.12;
	EMISSION = COLOR.rgb * emission_strength;
}
