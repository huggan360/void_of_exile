shader_type spatial;
render_mode cull_back;
// Vesperis towers (MultiMesh unit boxes and cylinders). Per instance: COLOR the
// facade, INSTANCE_CUSTOM r seed, g window density (0 = none), b neon (1 = the
// whole part glows in COLOR), a trims (brass bands every few floors).
// Windows are lit in warm lantern amber, rose, teal and mint, a few flicker.
varying vec3 local_m;
varying vec3 local_n;
varying vec3 scale_m;
varying vec4 custom;
varying vec3 world_pos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
vec3 lin(vec3 c) { return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045))); }

void vertex() {
	scale_m = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	local_m = VERTEX * scale_m;
	local_n = NORMAL;
	custom = INSTANCE_CUSTOM;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 base = lin(COLOR.rgb);
	float seed = custom.r * 97.0;
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	if (custom.b > 0.5) {
		ALBEDO = base * 0.4;
		EMISSION = base * (0.55 + 0.06 * sin(TIME * 2.0 + seed));
		ROUGHNESS = 0.5;
	} else {
		float up = local_m.y + scale_m.y * 0.5;  // metres above the part's base
		vec3 color = base;
		vec3 glow = vec3(0.0);
		bool side = abs(local_n.y) < 0.5;
		if (side && custom.g > 0.01) {
			// Facade coordinate along the wall (boxes) or around (cylinders).
			float along = abs(local_n.x) > abs(local_n.z) ? local_m.z : local_m.x;
			if (custom.a > 1.5) along = atan(local_m.x, local_m.z) * scale_m.x * 0.5;
			vec2 cell = vec2(along / 2.6, up / 3.6);
			vec2 id = floor(cell);
			vec2 f = fract(cell);
			float frame = step(0.24, f.x) * step(f.x, 0.76) * step(0.3, f.y) * step(f.y, 0.8);
			float lit = step(1.0 - custom.g, hash(vec3(id, seed)));
			float pick = hash(vec3(id.yx, seed + 3.0));
			vec3 lamp = pick < 0.55 ? vec3(1.0, 0.68, 0.36) : pick < 0.72 ? vec3(1.0, 0.45, 0.72) : pick < 0.88 ? vec3(0.35, 0.92, 0.88) : vec3(0.6, 1.0, 0.62);
			float flick = 1.0 - step(0.985, hash(vec3(id, floor(TIME * 3.0)))) * step(0.9, pick);
			// Far away the grid melts into an even glow so it never shimmers.
			float near = 1.0 - smoothstep(180.0, 700.0, dist);
			float glass = mix(custom.g * 0.55, frame, near);
			color = mix(color, color * 0.35, glass);
			glow = lamp * glass * mix(custom.g * 0.6, lit * flick, near) * 0.48;
			// Brass trims every few floors, mullions between windows.
			if (custom.a > 0.5 && custom.a < 1.5) {
				float band = 1.0 - smoothstep(0.0, 0.08, abs(fract(up / 14.4) - 0.04));
				color = mix(color, lin(vec3(0.85, 0.62, 0.32)), band * near);
			}
		} else if (!side) {
			// Roofs: dark panels with a soft glow at the rim.
			vec2 p = local_m.xz;
			vec2 rim = scale_m.xz * 0.5 - abs(p);
			float edge = 1.0 - smoothstep(0.0, 0.6, min(rim.x, rim.y));
			color = base * 0.6;
			glow = lin(vec3(1.0, 0.6, 0.85)) * edge * 0.25 * step(0.5, local_n.y);
		}
		ALBEDO = color;
		EMISSION = glow;
		ROUGHNESS = 0.78;
		METALLIC = 0.05;
	}
}
