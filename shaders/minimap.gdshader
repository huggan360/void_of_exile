shader_type canvas_item;
// Round pixel-art minimap with a thin GUI-colored rim on a fixed pixel
// grid. The map itself is a picture of the world (one pixel per block,
// painted once as you explore) that simply slides and turns underneath:
// turning the camera turns the picture, so its pixels show at an angle.
// Unexplored ground is dark.

uniform sampler2D map_tex : filter_nearest;
uniform sampler2D explored_tex : filter_nearest;
uniform vec2 map_origin;      // world x/z of texel (0, 0)
uniform float map_size = 512.0;
uniform vec2 center;          // world x/z at the middle of the minimap
uniform float view_radius = 40.0;  // blocks from the middle to the map's edge
uniform float rotation = 0.0;
uniform float art_pixels = 70.0;   // pixel grid across the whole minimap
uniform vec3 unexplored : source_color = vec3(0.04, 0.045, 0.08);
uniform float map_edge = 0.954545;  // two art pixels reserved for the frame
#include "res://shaders/minimap_frame.gdshaderinc"

void fragment() {
	// Frame: snap to the minimap's own pixel grid, then work in -1..1.
	vec2 cell = (floor(UV * art_pixels) + 0.5) / art_pixels;
	vec2 p = cell * 2.0 - 1.0;
	vec2 p_smooth = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) {
		discard;
	}
	vec3 color;
	if (!minimap_rim(p, art_pixels, map_edge, color)) {
		float c = cos(rotation);
		float s = sin(rotation);
		vec2 q = p_smooth / map_edge;
		vec2 world = center + vec2(q.x * c - q.y * s, q.x * s + q.y * c) * view_radius;
		vec2 uv = (world - map_origin) / map_size;  // nearest filtering: one texel = one block
		color = texture(map_tex, uv).rgb;
		float explored = texture(explored_tex, uv).r;
		if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
			explored = 0.0;
		}
		color = mix(unexplored, color, step(0.35, explored));  // hard pixel edge to the dark
	}
	COLOR = vec4(color, 1.0);
}
