shader_type spatial;
// Warped space (shield bubble, warp rings): bends the world behind it like a
// lens, with thin crackling arcs of warped lightning sliding over it. Each
// spell sets its own tint and arc colors.
//
// Two optional deformations:
//  - brace (shield): a warp wave is hitting it from brace_dir's opposite side.
//    The bubble dents in where the wave meets it, streams back into a
//    teardrop downwind and shivers with ripples, like leaning into a gale.
//  - obstacle (rings): parts of the ring inside a shield bubble get pushed
//    out around it, so the wave visibly bends around the shield.
// Rings also have a strength per arc (use_arcs, see WarpWave): where they were
// weakened by another ring the tube thins and fades, and gaps open up.
render_mode unshaded, cull_back, shadows_disabled, depth_draw_never;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;  // fades the whole effect in/out
uniform float warp = 0.05;     // how strongly the background bends
uniform float pulse = 0.0;     // flashes when the shield absorbs a hit
uniform vec3 tint : source_color = vec3(0.65, 0.8, 1.0);
uniform vec3 arc_color : source_color = vec3(0.85, 0.92, 1.0);
uniform float rainbow = 0.55;  // how much the arcs shift through rainbow colors
uniform float darkness = 0.0;  // black-magic spells dim the world they bend
uniform float brace = 0.0;               // 0..1, how hard a wave is pushing
uniform vec3 brace_dir = vec3(0.0, 0.0, 1.0);  // which way the wave travels (local space)
uniform vec4 obstacle = vec4(0.0);       // xyz world center, w radius (0 = none)
uniform bool use_arcs = false;
uniform float ring_radius = 1.0;         // radius of the tube's center line
uniform float arc_strength[64];

varying vec3 local_pos;
varying float ring_strength;
varying float facing_wave;  // 0..1 on the side of the bubble facing the wave

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i), hash3(i + vec3(1, 0, 0)), f.x),
			mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
			mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
			mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

// Strength of the ring at this point, blended between neighbouring arcs.
float arc_at(vec3 p) {
	float f = fract(atan(p.z, p.x) / 6.2831853 + 1.0) * 64.0 - 0.5;
	int i = int(floor(f));
	float t = fract(f);
	return mix(arc_strength[(i + 64) % 64], arc_strength[(i + 65) % 64], t);
}

void vertex() {
	local_pos = VERTEX;
	facing_wave = 0.0;
	ring_strength = 1.0;
	if (use_arcs) {
		ring_strength = arc_at(VERTEX);
		// Pull the tube in toward its center line where the ring is weak.
		vec2 dir = normalize(VERTEX.xz + vec2(0.0001));
		vec3 center = vec3(dir.x * ring_radius, 0.0, dir.y * ring_radius);
		VERTEX = center + (VERTEX - center) * mix(0.15, 1.0, ring_strength);
	}
	if (brace > 0.001) {
		float r = length(VERTEX);
		vec3 n = VERTEX / max(r, 0.0001);
		float into = dot(n, -brace_dir);  // 1 = facing the wave, -1 = downwind
		float front = max(into, 0.0);
		float back = max(-into, 0.0);
		float side = 1.0 - into * into;
		vec3 push = brace_dir * r * brace;
		VERTEX += push * 0.6 * pow(front, 1.5);         // dented in where it hits
		VERTEX += push * 0.7 * pow(back, 1.5);          // streams out behind
		VERTEX -= (n - brace_dir * dot(n, brace_dir)) * r * brace * 0.2 * back;  // pinches into a teardrop
		VERTEX += n * r * brace * 0.06 * side * sin(into * 12.0 + TIME * 28.0);  // shivers flowing past
		facing_wave = front * brace;
	}
	if (obstacle.w > 0.0) {
		vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec2 d = world.xz - obstacle.xz;
		float l = length(d);
		float reach = obstacle.w * 1.35;
		if (l < reach) {
			float t = l / reach;
			world.xz = obstacle.xz + d / max(l, 0.0001) * mix(obstacle.w, reach, t * t);
			world.y += (1.0 - t) * 0.25 * obstacle.w;  // and rides up over it a little
			VERTEX = (inverse(MODEL_MATRIX) * vec4(world, 1.0)).xyz;
		}
	}
}

void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = pow(1.0 - facing, 2.2);
	vec3 p = normalize(local_pos) * 2.5;

	// Lensing: push the background outward, more at the rim, swirled by noise.
	float swirl = noise3(p + vec3(0.0, TIME * 0.7, TIME * 0.3)) - 0.5;
	vec2 offset = (NORMAL.xy * (0.4 + rim * 1.6) + vec2(swirl, -swirl)) * warp * intensity * (1.0 + facing_wave * 2.5);
	vec3 behind = textureLod(screen_tex, SCREEN_UV - offset, rim * 2.0).rgb;

	// Warped lightning: thin bright lines where a moving noise field crosses 0.5.
	float field = noise3(p * 1.8 + vec3(TIME * 1.1, -TIME * 0.6, TIME * 0.9));
	float arc = 1.0 - smoothstep(0.0, 0.025, abs(field - 0.5));
	arc *= step(0.35, noise3(p * 0.9 - TIME * 0.5));  // only some patches crackle at a time
	vec3 rainbow_col = 0.55 + 0.45 * cos(6.2831 * (vec3(0.0, 0.33, 0.67) + local_pos.y * 0.35 + TIME * 0.15));

	vec3 color = behind * (1.0 - darkness * (0.5 + rim * 0.4));
	color += tint * rim * (0.5 + pulse);
	color += mix(arc_color, rainbow_col, rainbow) * arc * (2.2 + pulse * 2.0 + facing_wave * 4.0);
	// The face meeting the wave glows hot, with crackling streaks blown back.
	float streak = 1.0 - smoothstep(0.0, 0.06, abs(noise3(p * vec3(4.0, 4.0, 4.0) + brace_dir * TIME * 9.0) - 0.5));
	color += (tint * 1.2 + arc_color * streak * 2.5) * facing_wave * (0.6 + rim);
	float fade = smoothstep(0.02, 0.35, ring_strength);
	ALBEDO = mix(behind, color, fade);
	ALPHA = intensity * fade;
}
