shader_type spatial;
render_mode cull_back;
// Planet ground: painted vertex colours (PlanetPalette) with a fine,
// stepped detail pattern and glowing magic veins (vertex alpha).
uniform vec4 magic : source_color = vec4(0.5, 1.0, 0.7, 1.0);
uniform float detail_scale = 0.2;
varying vec3 local_pos;
varying float glow;

float hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void vertex() {
	local_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	glow = COLOR.a;
}

void fragment() {
	// Chunky texel speckle that stays put on the ground.
	vec3 cell = floor(local_pos * detail_scale * 4.0);
	float speck = hash(cell);
	// Painted colours sit a little deeper than the palette so worlds keep
	// their colour under full sun and the sky's ambient light.
	vec3 color = COLOR.rgb * (0.74 + speck * 0.14);
	float pulse = 0.75 + 0.25 * sin(TIME * 1.3 + speck * 6.28);
	ALBEDO = color;
	ROUGHNESS = 0.92;
	EMISSION = magic.rgb * glow * 0.9 * pulse;
}
