shader_type spatial;
// The edge of the Reach: a red ward of hexagons and running runes on the
// world sphere. It shows only near the camera and brightens the closer you
// come, so the border is felt before it is reached.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;
uniform float world_radius = 42000.0;
varying vec3 world_pos;
void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float hex(vec2 p) {
	p.x *= 1.1547;
	p.y += mod(floor(p.x), 2.0) * 0.5;
	p = abs(fract(p) - 0.5);
	return abs(max(p.x * 1.5 + p.y, p.y * 2.0) - 1.0);
}
void fragment() {
	float d = length(world_pos - CAMERA_POSITION_WORLD);
	float near = 1.0 - smoothstep(600.0, 7000.0, d);
	vec3 n = normalize(world_pos);
	vec2 uv = vec2(atan(n.z, n.x), asin(clamp(n.y, -1.0, 1.0))) * world_radius / 180.0;
	float lines = 1.0 - smoothstep(0.0, 0.06, hex(uv));
	float sweep = 0.5 + 0.5 * sin(uv.y * 0.35 - TIME * 1.6 + sin(uv.x * 0.2) * 2.0);
	float veil = 0.03 + lines * 0.75 + sweep * 0.06;
	ALBEDO = vec3(1.0, 0.12, 0.16) * veil * near;
}
