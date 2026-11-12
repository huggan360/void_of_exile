shader_type spatial;
// The Surface's ground cover and bushes (SurfaceFlora): vertex-coloured voxel
// plants that sway in the wind and lean away from whoever walks through them
// (`pushers`: world x, y, z and radius of the player, other players and
// enemies near the camera, set every frame on the client). They fade out by
// dithering toward fade_end so a chunk never pops.
render_mode cull_disabled, world_vertex_coords;

const int MAX_PUSHERS = 24;
uniform vec4 pushers[MAX_PUSHERS];
instance uniform float sway = 0.5;
instance uniform float height = 1.0;  // mesh units at the plant's top
instance uniform float fade_end = 45.0;
instance uniform float glow = 0.0;

varying vec3 tint;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	tint = INSTANCE_CUSTOM.rgb;
	vec3 root = MODEL_MATRIX[3].xyz;
	// The plant's own up: world up on the Surface, away from the centre on a planet.
	vec3 up = normalize(MODEL_MATRIX[1].xyz);
	float scale_y = length(MODEL_MATRIX[1].xyz);
	float t = clamp(dot(VERTEX - root, up) / max(height * scale_y, 0.01), 0.0, 1.0);
	float bend = t * t;
	// Wind: slow gusts rolling across the land plus a quick flutter.
	float gust = sin(TIME * 0.7 + root.x * 0.05 + root.z * 0.03) * 0.5 + 0.5;
	vec2 wind = vec2(sin(TIME * 1.8 + root.x * 0.4 + root.z * 0.3), cos(TIME * 1.5 + root.z * 0.37)) * (0.35 + gust * 0.65);
	vec3 offset = vec3(wind.x, 0.0, wind.y * 0.6) * 0.12 * sway * bend;
	offset -= up * dot(offset, up);
	// Lean away from characters walking through.
	for (int i = 0; i < MAX_PUSHERS; i++) {
		vec4 p = pushers[i];
		if (p.w <= 0.0) continue;
		vec3 away = root - p.xyz;
		float rise = dot(away, up);
		away -= up * rise;
		float d = length(away);
		float reach = p.w + 0.35;
		if (d < reach && abs(rise) < 2.5) {
			float k = 1.0 - d / reach;
			vec3 dir = d > 0.001 ? away / d : vec3(1.0, 0.0, 0.0);
			offset += dir * k * 0.55 * bend * (0.4 + sway);
			offset -= up * k * 0.3 * bend * height * scale_y * (0.3 + sway);
		}
	}
	VERTEX += offset;
}

// Overhead see-through: a soft round window around the character (GroundView
// sets see_through = screen x, y, radius in render pixels, the character's
// view depth). What stands in front of the character there dissolves with
// a fine dither toward the rim; shadows are untouched.
global uniform vec4 see_through;

// Interleaved gradient noise: a fine, even per-pixel dither.
float dither(vec2 p) {
	return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715))));
}

void cut_see_through(vec2 frag, float view_depth) {
	// Right against the lens (the camera inside a tree or wall): gone.
	if (see_through.z <= 0.0) return;  // only the ground camera (Surface, Tavern) sets it
	float keep_near = smoothstep(0.35, 1.1, view_depth);
	float keep = 1.0;
	if (view_depth < see_through.w - 0.8) {
		float d = length(frag - see_through.xy);
		keep = smoothstep(see_through.z * 0.35, see_through.z, d);
		keep = max(keep, smoothstep(see_through.w - 1.4, see_through.w - 0.8, view_depth));
	}
	keep = min(keep, keep_near);
	if (keep < 1.0 && dither(frag) > keep * keep * (3.0 - 2.0 * keep)) discard;
}

void fragment() {
	if (!IN_SHADOW_PASS) cut_see_through(FRAGCOORD.xy, -VERTEX.z);
	// Dither away near the end of the draw distance.
	float dist = length(VERTEX);
	float fade = clamp((fade_end - dist) / (fade_end * 0.22), 0.0, 1.0);
	if (hash3(vec3(floor(FRAGCOORD.xy), 1.7)) > fade) discard;
	vec3 color = srgb_to_linear(COLOR.rgb) * (tint == vec3(0.0) ? vec3(1.0) : tint);
	ALBEDO = glow > 0.0 ? color * 0.45 : color;
	EMISSION = color * glow;
	ROUGHNESS = 0.85;
	BACKLIGHT = vec3(0.25) * color;
}
