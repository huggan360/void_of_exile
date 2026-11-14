shader_type canvas_item;
// The look of a cutscene (FilmLook): drawn over the 3D scene only, under the
// letterbox and the captions. `mono` drains the colour, `old` turns the frame
// into a worn reel on an old television: flicker, scan lines, dust,
// scratches and a rounded, darkened tube. All zero = the scene untouched.
uniform sampler2D scene : hint_screen_texture, filter_linear;
uniform float vignette : hint_range(0.0, 1.0) = 0.35;
uniform float grain : hint_range(0.0, 1.0) = 0.25;
uniform float mono : hint_range(0.0, 1.0) = 0.0;
uniform float old : hint_range(0.0, 1.0) = 0.0;
uniform float warmth : hint_range(-1.0, 1.0) = 0.0;
uniform float contrast : hint_range(0.5, 1.6) = 1.04;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float frame = floor(TIME * 18.0);
	// The tube bulges a little. The picture itself never moves.
	vec2 centered = uv * 2.0 - 1.0;
	centered *= 1.0 + old * 0.035 * dot(centered, centered);
	uv = centered * 0.5 + 0.5;
	vec3 color = texture(scene, uv).rgb;
	// Old optics are soft: a few taps of blur.
	if (old > 0.01) {
		vec2 px = SCREEN_PIXEL_SIZE * 1.6 * old;
		vec3 soft = texture(scene, uv + vec2(px.x, 0.0)).rgb + texture(scene, uv - vec2(px.x, 0.0)).rgb
			+ texture(scene, uv + vec2(0.0, px.y)).rgb + texture(scene, uv - vec2(0.0, px.y)).rgb;
		color = mix(color, soft * 0.25, 0.55 * old);
	}
	color = (color - 0.5) * contrast + 0.5;
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	// Silver-gelatin black and white: deep blacks, a faint warm paper white.
	vec3 silver = vec3(luma) * vec3(1.02, 1.0, 0.95);
	silver = mix(silver, smoothstep(0.02, 0.98, silver), 0.5);
	color = mix(color, silver, mono);
	color += vec3(0.02, 0.006, -0.018) * warmth;
	// A slow breath of the projector lamp (smooth, never a per-frame jump), scan lines of the set.
	color *= 1.0 - old * 0.03 * (0.5 + 0.5 * sin(TIME * 5.3) * sin(TIME * 1.7));
	color *= 1.0 - old * 0.07 * (0.5 + 0.5 * sin(SCREEN_UV.y / SCREEN_PIXEL_SIZE.y * 1.6));
	// Dust specks and the odd vertical scratch.
	float speck = step(0.9993, hash(floor(SCREEN_UV / SCREEN_PIXEL_SIZE / 2.0) + frame * 13.0));
	color = mix(color, vec3(hash(vec2(frame, 3.0)) > 0.5 ? 0.92 : 0.05), speck * old);
	float scratch_x = hash(vec2(floor(TIME * 3.0), 5.0));
	float scratch = (1.0 - smoothstep(0.0, 0.0012, abs(SCREEN_UV.x - scratch_x))) * step(0.6, hash(vec2(floor(TIME * 3.0), 6.0)));
	color = mix(color, vec3(0.85), scratch * old * 0.5);
	// Grain, then the vignette (and the dark rounded corners of the tube).
	float noise = hash(floor(FRAGCOORD.xy) + frame * 31.0) - 0.5;
	color += noise * (0.035 * grain + 0.07 * old);
	float edge = dot(centered, centered);
	color *= 1.0 - smoothstep(0.25, 2.0, edge) * (0.55 * vignette + 0.35 * old);
	vec2 corner = abs(centered) - vec2(0.9);
	float tube = length(max(corner, 0.0)) / 0.1;
	color *= 1.0 - old * smoothstep(0.6, 1.0, tube);
	if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) color = vec3(0.0);
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
