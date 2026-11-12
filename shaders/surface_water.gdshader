shader_type spatial;
// The Surface's water: rivers, lakes and the sea. Smooth, not voxel.
//
// What lies under the water shows through, bent by the ripples and tinted by
// its depth (clear green-blue shallows, deep blue pools). The surface detail
// is a flow map: two layers of normal maps scrolled along the current (vertex
// colour: rg = direction, b = speed) in two phases that cross-fade with a
// noise offset, so a river keeps running without its waves stretching or
// pulsing. Foam streaks ride the current, thicken on fast water and gather
// softly along the banks. Lakes and the sea (no current) drift with the wind.
render_mode cull_disabled, shadows_disabled;

uniform vec3 shallow_color : source_color = vec3(0.26, 0.62, 0.6);
uniform vec3 deep_color : source_color = vec3(0.03, 0.18, 0.28);
uniform vec3 foam_color : source_color = vec3(0.92, 0.96, 1.0);
uniform float clarity = 2.0;      // meters until the water looks deep
uniform float refraction = 0.04;
uniform float bank_foam = 0.35;   // meters of water depth where bank foam shows
uniform bool use_flow = true;
uniform vec2 wind = vec2(0.22, 0.1);
uniform float scale = 0.18;       // ripple tiles per meter
uniform sampler2D normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, filter_linear;

varying vec2 flow;  // direction with the speed folded in at the corners
varying float speed;
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	flow = use_flow ? COLOR.rg * 2.0 - 1.0 : vec2(0.0);
	speed = use_flow ? COLOR.b : 0.0;
	if (!use_flow) {
		VERTEX.y += (sin(world.x * 0.31 + TIME * 0.8) + sin(world.z * 0.23 - TIME * 0.6)) * 0.03;
	}
}

float depth_behind(vec2 uv, vec3 vertex, mat4 inv_projection) {
	float depth = texture(depth_texture, uv).x;
	vec4 behind = inv_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	behind.xyz /= behind.w;
	return max(0.0, vertex.z - behind.z);
}

void fragment() {
	// Running and still water blend smoothly (no line where the current ends).
	float k = smoothstep(0.02, 0.3, length(flow) * (0.4 + speed));
	vec2 dir = mix(wind, length(flow) > 0.001 ? normalize(flow) : wind, k);
	float rate = mix(0.12, 0.35 + speed * 1.4, k);
	// Two phases half a cycle apart; the noise offset hides the cross-fade.
	float offset = texture(foam_noise, world.xz * 0.05).r;
	float t0 = fract(TIME * 0.22 + offset);
	float t1 = fract(t0 + 0.5);
	float w0 = 1.0 - abs(t0 * 2.0 - 1.0);
	vec2 uv = world.xz * scale;
	vec2 shift0 = -dir * t0 * rate;
	vec2 shift1 = -dir * t1 * rate;
	vec3 na = mix(texture(normal_a, uv + shift1 + vec2(0.37, 0.71)).rgb, texture(normal_a, uv + shift0).rgb, w0);
	vec3 nb = texture(normal_b, uv * 2.7 - dir * TIME * 0.05 * (0.5 + rate)).rgb;
	vec3 n = normalize(mix(na, nb, 0.35) * 2.0 - 1.0) * 0.5 + 0.5;
	NORMAL_MAP = n;
	NORMAL_MAP_DEPTH = mix(0.45, 0.5 + speed * 0.7, k);

	// See through, bent by the ripples.
	float thick = depth_behind(SCREEN_UV, VERTEX, INV_PROJECTION_MATRIX);
	vec2 bend = (n.xy * 2.0 - 1.0) * refraction * clamp(thick, 0.0, 1.0);
	vec3 under = texture(screen_texture, SCREEN_UV + bend).rgb;
	float t = clamp(thick / clarity, 0.0, 1.0);
	vec3 water = mix(shallow_color, deep_color, t);
	vec3 color = mix(under * mix(vec3(1.0), shallow_color * 1.5, 0.5), water, smoothstep(0.0, 1.0, t * 0.85 + 0.12));

	// Foam streaks carried by the current, and soft foam at the banks.
	float streaks = mix(texture(foam_noise, uv * 1.6 + shift1 * 1.6 + vec2(0.21, 0.63)).r,
			texture(foam_noise, uv * 1.6 + shift0 * 1.6).r, w0);
	float along = smoothstep(0.62 - speed * 0.22, 0.85, streaks) * k * (0.25 + speed * 0.75);
	float edge = (1.0 - smoothstep(0.0, bank_foam, thick)) * smoothstep(0.35, 0.7, streaks + 0.15);
	float foam = clamp(along * 0.8 + edge * 0.7, 0.0, 0.85);
	color = mix(color, foam_color, foam);

	ALBEDO = color;
	ROUGHNESS = mix(0.03, 0.3, foam);
	SPECULAR = 0.6;
	ALPHA = clamp(smoothstep(0.0, 0.06, thick) + foam, 0.0, 1.0);  // soft edges where it meets the shore
}
