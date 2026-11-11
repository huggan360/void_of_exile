// Shared pixel rim for the Tavern and all Space maps.
uniform vec3 frame_color : source_color = vec3(0.11, 0.12, 0.2);
uniform vec3 outline_color : source_color = vec3(0.03, 0.03, 0.06);
uniform sampler2D frame_tex : filter_nearest, repeat_enable;
uniform vec3 brass_color : source_color = vec3(0.90, 0.72, 0.42);
bool minimap_rim(vec2 p, float pixels, float edge, out vec3 color) {
	float radius = length(p);
	if (radius > 1.0 - 2.0 / pixels) {
		color = outline_color;
	} else if (radius > 1.0 - 4.0 / pixels) {
		float angle = atan(p.y, p.x) / 6.2831853;
		color = texture(frame_tex, vec2(fract(angle * 5.0), 0.5)).rgb * (p.y < 0.0 ? 1.0 : 0.70);
	} else if (radius > 1.0 - 6.0 / pixels) {
		color = brass_color * (p.y < 0.0 ? 0.88 : 0.56);
	} else if (radius > edge) {
		color = outline_color;
	} else {
		color = vec3(0.0);
		return false;
	}
	return true;
}
