shader_type spatial;
// A planet's seas and lakes (SpacePlanet): the Surface's water wrapped round
// a sphere. What lies under it shows through, bent by the ripples and tinted
// by its depth (clear shallows, deep pools); ripples are two normal maps
// drifting with the wind, laid on the sphere from three sides (triplanar, in
// planet space) so they never stretch; foam gathers softly along the shores.
render_mode cull_back, shadows_disabled;

uniform vec3 shallow_color : source_color = vec3(0.26, 0.62, 0.6);
uniform vec3 deep_color : source_color = vec3(0.03, 0.18, 0.28);
uniform vec3 foam_color : source_color = vec3(0.92, 0.96, 1.0);
uniform float clarity = 2.4;      // meters until the water looks deep
uniform float refraction = 0.04;
uniform float bank_foam = 0.4;    // meters of water depth where shore foam shows
uniform float scale = 0.16;       // ripple tiles per meter
uniform float glow = 0.0;         // magic water (ghost pools, spore lakes) glows a little
uniform sampler2D normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear;

varying vec3 local;
varying vec3 blend;

void vertex() {
	local = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - NODE_POSITION_WORLD;  // the planet's centre
	vec3 n = normalize(local);
	blend = pow(abs(n), vec3(4.0));
	blend /= dot(blend, vec3(1.0));
	// A slow swell along the radius.
	float swell = (sin(local.x * 0.31 + TIME * 0.8) + sin(local.z * 0.23 - TIME * 0.6) + sin(local.y * 0.27 + TIME * 0.7)) * 0.025;
	VERTEX += NORMAL * swell;
}

float depth_behind(vec2 uv, vec3 vertex, mat4 inv_projection) {
	float depth = texture(depth_texture, uv).x;
	vec4 behind = inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	behind.xyz /= behind.w;
	return max(0.0, vertex.z - behind.z);
}

vec3 tri(sampler2D tex, vec3 p, vec2 drift) {
	return texture(tex, p.yz + drift).rgb * blend.x + texture(tex, p.xz + drift).rgb * blend.y + texture(tex, p.xy + drift).rgb * blend.z;
}

void fragment() {
	vec3 p = local * scale;
	vec2 wind = vec2(0.22, 0.1);
	float offset = tri(foam_noise, local * 0.05, vec2(0.0)).r;
	float t0 = fract(TIME * 0.22 + offset);
	float t1 = fract(t0 + 0.5);
	float w0 = 1.0 - abs(t0 * 2.0 - 1.0);
	vec3 na = mix(tri(normal_a, p, -wind * t1 * 0.12 + vec2(0.37, 0.71)), tri(normal_a, p, -wind * t0 * 0.12), w0);
	vec3 nb = tri(normal_b, p * 2.7, -wind * TIME * 0.03);
	vec3 n = normalize(mix(na, nb, 0.35) * 2.0 - 1.0) * 0.5 + 0.5;
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = 0.45;

	// See through, bent by the ripples.
	float thick = depth_behind(SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX);
	vec2 bend = (n.xy * 2.0 - 1.0) * refraction * clamp(thick, 0.0, 1.0);
	vec3 under = texture(screen_texture, SCREEN_UV + bend).rgb;
	float t = clamp(thick / clarity, 0.0, 1.0);
	vec3 water = mix(shallow_color, deep_color, t);
	vec3 color = mix(under * mix(vec3(1.0), shallow_color * 1.5, 0.5), water, smoothstep(0.0, 1.0, t * 0.85 + 0.12));

	// Soft foam along the shores, drifting.
	float streaks = mix(tri(foam_noise, p * 1.6, -wind * t1 * 0.2 + vec2(0.21, 0.63)).r, tri(foam_noise, p * 1.6, -wind * t0 * 0.2).r, w0);
	float edge = (1.0 - smoothstep(0.0, bank_foam, thick)) * smoothstep(0.35, 0.7, streaks + 0.15);
	float foam = clamp(edge * 0.7, 0.0, 0.85);
	color = mix(color, foam_color, foam);

	ALBEDO = color;
	EMISSION = shallow_color * glow * (0.6 + 0.4 * streaks);
	ROUGHNESS = mix(0.03, 0.3, foam);
	SPECULAR = 0.6;
	ALPHA = clamp(smoothstep(0.0, 0.06, thick) + foam, 0.0, 1.0);
}
