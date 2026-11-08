shader_type spatial;
// The gloria of a far planet: a soft glow that stays visible through the dark
// fog of space, fading away as the ship comes close enough to see the world.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, fog_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.5, 1.0, 0.8, 1.0);
uniform float planet_radius = 600.0;
uniform float strength = 0.6;

void vertex() {
	// Face the camera.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0), vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0), vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0), vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float distance_to = length(CAMERA_POSITION_WORLD - NODE_POSITION_WORLD);
	float far = smoothstep(planet_radius * 5.0, planet_radius * 16.0, distance_to);
	float glow = pow(max(1.0 - r, 0.0), 2.6);
	ALBEDO = tint.rgb * glow * strength * far;
}
