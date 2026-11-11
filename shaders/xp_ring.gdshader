shader_type canvas_item;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float pulse : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec4 art = texture(TEXTURE, UV);
	vec2 p = UV * 2.0 - 1.0;
	float radius = length(p);
	float angle = mod(atan(p.x, -p.y) / 6.28318530718 + 1.0, 1.0);
	// The channel lies between the two inner silver bevels of the artwork.
	float channel = step(0.565, radius) * (1.0 - step(0.675, radius));
	float engraved_detail = step(0.48, dot(art.rgb, vec3(0.2126, 0.7152, 0.0722)));
	float filled = channel * step(angle, progress) * step(0.0001, progress) * (1.0 - engraved_detail);
	vec3 white = vec3(1.0);
	vec3 yellow = vec3(1.0, 0.83, 0.14);
	vec3 orange = vec3(1.0, 0.35, 0.035);
	vec3 xp = angle < 0.5 ? mix(white, yellow, angle * 2.0) : mix(yellow, orange, (angle - 0.5) * 2.0);
	float bevel = smoothstep(0.565, 0.58, radius) * (1.0 - smoothstep(0.66, 0.675, radius));
	xp *= mix(0.55, 1.0, bevel);
	art.rgb = mix(art.rgb, xp, filled);
	art.rgb = mix(art.rgb, vec3(1.0), channel * pulse * 0.45);
	COLOR = art;
}
