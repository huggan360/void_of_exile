shader_type spatial;
// A window of the walk-in ship room. While the ship's live view is on it
// shows what a window at this spot of the flying hull would see (the view is
// rendered from the matching place in the hull, so it lines up pixel for
// pixel); otherwise a quiet field of stars.
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform sampler2D view_tex : source_color, filter_linear;
uniform bool live = false;
uniform bool round_window = false;
uniform vec4 glass : source_color = vec4(0.75, 1.0, 0.9, 1.0);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	if (round_window && distance(UV, vec2(0.5)) > 0.5) discard;
	vec3 outside;
	if (live) {
		outside = texture(view_tex, SCREEN_UV).rgb;
	} else {
		vec2 grid = floor(UV * vec2(120.0, 64.0));
		outside = vec3(0.006, 0.01, 0.025) + vec3(0.85, 0.95, 0.75) * step(0.988, hash(grid));
	}
	// A faint glass sheen toward the frame.
	float edge = round_window ? smoothstep(0.32, 0.5, distance(UV, vec2(0.5))) : max(smoothstep(0.42, 0.5, abs(UV.x - 0.5)), smoothstep(0.4, 0.5, abs(UV.y - 0.5)));
	ALBEDO = mix(outside, glass.rgb * 0.35, edge * 0.25);
}
