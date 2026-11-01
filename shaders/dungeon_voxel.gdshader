shader_type spatial;
render_mode cull_disabled;
varying vec3 local_pos;
void vertex() {
	local_pos = VERTEX;
}
void fragment() {
	vec3 p = floor(local_pos * 24.0);
	float grain = fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
	ALBEDO = COLOR.rgb * (0.75 + grain * 0.35);
	ROUGHNESS = 0.95;
}
