// Light that ripples and blinks through glowing things (GlowRipples writes these).
//
// A ripple is a ring of light that leaves `origin` at `start` and grows at
// `speed` m/s until it fades out at `range`. Flat ripples (shape.w = 1) measure
// along the ground only, so a ring sweeping out from a room's middle climbs
// whole walls at once. gr_level lights everything (1 = all of it shines).
uniform vec4 gr_origin[16];  // xyz, start time
uniform vec4 gr_color[16];  // rgb, strength
uniform vec4 gr_shape[16];  // speed, width, range, flat
uniform int gr_count = 0;
uniform float gr_now = 0.0;
uniform float gr_level = 0.0;

vec3 glow_ripples(vec3 p) {
	vec3 sum = vec3(0.0);
	for (int i = 0; i < gr_count; i++) {
		vec4 o = gr_origin[i];
		vec4 s = gr_shape[i];
		float age = gr_now - o.w;
		float r = age * s.x;
		if (age < 0.0 || r > s.z + s.y * 2.0) continue;
		vec3 d3 = p - o.xyz;
		float d = s.w > 0.5 ? length(d3.xz) : length(d3);
		float k = (d - r) / s.y;
		// A bright leading edge with a softer glow left behind it.
		float front = exp(-k * k) + (k < 0.0 ? exp(k * 0.8) * 0.25 : 0.0);
		float fade = 1.0 - smoothstep(s.z * 0.55, s.z + s.y, r);
		sum += gr_color[i].rgb * gr_color[i].a * front * fade;
	}
	return sum;
}

// A slow random heartbeat per object: mostly dim, now and then a soft blink.
float glow_blink(float seed, float rate) {
	float t = gr_now * rate + seed * 17.0;
	float beat = fract(t);
	float pick = fract(sin(floor(t) * 12.9898 + seed * 78.233) * 43758.5453);
	return pick > 0.55 ? sin(beat * 3.14159) * (pick - 0.55) * 2.2 : 0.0;
}
