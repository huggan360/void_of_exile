shader_type spatial;
// Fire particles: bright, unlit voxels colored by the particle color ramp.
render_mode unshaded, shadows_disabled, cull_back;

uniform float brightness = 4.0;  // > 1 so the glow/bloom picks them up

void fragment() {
	ALBEDO = COLOR.rgb * brightness;
	ALPHA = COLOR.a;
}
