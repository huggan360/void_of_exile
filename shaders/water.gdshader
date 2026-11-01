shader_type spatial;
// Simple sea: shallow water is clear and turquoise with foam at the shoreline,
// deep water turns dark blue. Small moving ripples catch the light.
render_mode cull_disabled, shadows_disabled;

uniform vec3 shallow_color : source_color = vec3(0.28, 0.68, 0.72);
uniform vec3 deep_color : source_color = vec3(0.04, 0.2, 0.36);
uniform float clarity = 2.5;  // meters of water before it looks deep
uniform float foam_width = 0.3;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear;

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).x;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	behind.xyz /= behind.w;
	float thickness = max(0.0, VERTEX.z - behind.z);  // view-space distance through the water

	float t = clamp(thickness / clarity, 0.0, 1.0);
	vec3 color = mix(shallow_color, deep_color, t);
	float foam = 1.0 - smoothstep(0.0, foam_width, thickness);
	color = mix(color, vec3(0.92, 0.96, 1.0), foam * 0.7);

	vec3 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 ripple = vec2(sin(world.x * 1.7 + TIME * 1.3) + sin(world.z * 2.3 - TIME),
			cos(world.z * 1.9 + TIME * 1.1) + cos(world.x * 2.1 - TIME * 0.8));
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(ripple.x * 0.04, 0.0, ripple.y * 0.04, 0.0)).xyz);

	ALBEDO = color;
	ALPHA = mix(0.55, 0.92, t) + foam * 0.3;
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
}
