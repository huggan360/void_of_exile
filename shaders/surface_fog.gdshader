shader_type fog;
// The Surface's fog of war as real volumetric fog (a FogVolume that follows
// the player; lit by the sun, lamps, lava and the torch like any fog). It
// only lives over the dark lands (each biome's fog colour and opacity come
// from region_map; the bright biomes carry none). Over unexplored ground it
// is a deep, rolling bank you cannot see through; once explored it thins to
// a low mist that drifts along the ground. Close to the player it clears.

uniform sampler2D explored_map : filter_linear, repeat_disable;
uniform sampler2D region_map : filter_linear, repeat_disable;
uniform sampler2D height_map : filter_linear, repeat_disable;
uniform sampler2D noise_map : filter_linear, repeat_enable;
uniform vec2 map_origin;
uniform float map_size = 256.0;
uniform vec2 player_pos;
uniform float reveal_radius = 12.0;
uniform float density = 0.14;
uniform float bank_height = 11.0;  // meters of fog over unexplored ground
uniform float mist_height = 2.2;   // and of the mist over explored ground

void fog() {
	vec3 w = WORLD_POSITION;
	vec2 uv = (w.xz - map_origin) / map_size;
	vec4 region = texture(region_map, uv);
	if (region.a < 0.01) {
		DENSITY = 0.0;
	} else {
		float explored = texture(explored_map, uv).r;
		float near = smoothstep(reveal_radius * 0.55, reveal_radius * 1.25, distance(w.xz, player_pos));
		float hidden = (1.0 - explored) * near;
		float ground = texture(height_map, uv).r;
		float top = mix(mist_height, bank_height, hidden);
		float above = w.y - ground;
		float layer = 1.0 - smoothstep(top * 0.35, top, above);
		vec2 drift = vec2(TIME * 0.35, TIME * 0.2);
		float n = texture(noise_map, (w.xz + drift) * 0.011).r;
		float n2 = texture(noise_map, (w.xz - drift * 1.7) * 0.037 + vec2(w.y * 0.03)).r;
		float billow = smoothstep(0.25, 0.85, n * 0.7 + n2 * 0.5);
		// Soft edges at the box sides so the volume never shows.
		vec3 edge = min(UVW, 1.0 - UVW);
		float box = smoothstep(0.0, 0.12, min(edge.x, edge.z));
		DENSITY = density * region.a * layer * box * mix(0.12 + billow * 0.25, 0.65 + billow * 0.9, hidden);
		ALBEDO = region.rgb + vec3(0.04);
	}
}
