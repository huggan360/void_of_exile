shader_type spatial;
// A Vesperis town street (CityPlanet._streets): UV is the town's plane in
// metres, UV2.x the distance across from the street's middle, UV2.y the
// carriageway's half width. The cobbled road is laid over the sidewalks, both
// in plane-aligned pixel textures, so where two streets meet they run on as one.
uniform bool road = true;
uniform sampler2D cobble_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D slab_tex : source_color, filter_nearest, repeat_enable;
uniform sampler2D kerb_tex : source_color, filter_nearest, repeat_enable;

varying vec2 across;

vec3 tex_at(sampler2D t, vec2 metres) {
	vec2 px = floor(metres * 10.0) + 0.5;
	return texture(t, px / vec2(textureSize(t, 0))).rgb;
}

void vertex() {
	across = UV2;
}

void fragment() {
	vec3 color;
	float a = abs(across.x);
	if (road) {
		color = tex_at(cobble_tex, UV);
		// A darker gutter along each edge.
		color *= mix(1.0, 0.82, smoothstep(across.y - 0.6, across.y, a));
	} else if (a < across.y + 0.3) {
		color = tex_at(kerb_tex, vec2(UV.x + UV.y, a));
	} else {
		color = tex_at(slab_tex, UV);
	}
	float dist = length(VERTEX);
	vec3 far_color = road ? vec3(0.42, 0.38, 0.34) : vec3(0.6, 0.57, 0.52);
	ALBEDO = mix(far_color, color, 1.0 - smoothstep(90.0, 300.0, dist));
	ROUGHNESS = 0.9;
}
