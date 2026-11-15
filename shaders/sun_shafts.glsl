#[compute]
#version 450

// Sun shafts, steps 2 and 3 (SunShafts). Mode 0 blurs the sky mask along
// lines toward the sun (two passes: a long one, then a short one that fills
// the gaps between its taps). Mode 1 adds the rays onto the scene, tinted
// by the sunlight, before glow and tone mapping.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D source;
layout(rgba16f, set = 0, binding = 1) uniform restrict image2D target;

layout(push_constant, std430) uniform Params {
	vec2 sun_uv;
	vec2 size;   // target size
	vec4 blur;   // x: share of the way to the sun, y: decay per tap, z: taps, w: mode
	vec4 tint;   // rgb: sunlight, a: strength
	vec4 unused;
} p;

// Interleaved gradient noise: a per-pixel start offset hides tap banding.
float noise(vec2 pixel) {
	return fract(52.9829189 * fract(dot(pixel, vec2(0.06711056, 0.00583715))));
}

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	if (pixel.x >= int(p.size.x) || pixel.y >= int(p.size.y)) {
		return;
	}
	vec2 uv = (vec2(pixel) + 0.5) / p.size;
	if (p.blur.w > 0.5) {
		vec4 color = imageLoad(target, pixel);
		color.rgb += textureLod(source, uv, 0.0).rgb * p.tint.rgb * p.tint.a;
		imageStore(target, pixel, color);
		return;
	}
	int taps = int(p.blur.z);
	vec2 step_uv = (p.sun_uv - uv) * p.blur.x / float(taps);
	vec2 at = uv + step_uv * noise(vec2(pixel));
	vec3 sum = vec3(0.0);
	float weight = 1.0;
	float total = 0.0;
	for (int i = 0; i < taps; i++) {
		sum += textureLod(source, at, 0.0).rgb * weight;
		total += weight;
		weight *= p.blur.y;
		at += step_uv;
	}
	imageStore(target, pixel, vec4(sum / total, 1.0));
}
