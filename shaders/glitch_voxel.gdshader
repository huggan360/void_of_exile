shader_type spatial;
// Flash over voxels that were just exposed when a creature lost part of its
// shell: mostly white with a few colored ones, blinking like a glitch while
// `fade` runs from 1 to 0 and the real colors show through again.
render_mode unshaded, shadows_disabled, cull_back, depth_draw_never;

instance uniform float fade = 1.0;
uniform float brightness = 2.5;

varying vec3 local_pos;
varying vec3 local_normal;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
	VERTEX += NORMAL * 0.04;  // sit just above the real faces
}

void fragment() {
	vec3 voxel = floor(local_pos - local_normal * 0.5);
	float h = hash3(voxel);
	// Each voxel fades on its own schedule and blinks out now and then.
	float a = clamp(fade * 1.5 - h * 0.5, 0.0, 1.0);
	float blink = step(0.18, hash3(voxel + floor(TIME * 30.0) * 1.37));
	ALBEDO = srgb_to_linear(COLOR.rgb) * brightness;
	ALPHA = a * blink;
}
