#[compute]
#version 450

// Sun shafts, step 1 (SunShafts): at reduced resolution, keep only the open
// sky, weighted by how close each pixel looks toward the sun. Trees, roofs,
// asteroids and planets stay black, so the radial blur that follows streaks
// the sky's light past their edges.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0) uniform sampler2D depth_texture;
layout(rgba16f, set = 0, binding = 1) uniform restrict readonly image2D scene;
layout(rgba16f, set = 0, binding = 2) uniform restrict writeonly image2D mask;

layout(push_constant, std430) uniform Params {
	vec2 sun_uv;
	vec2 tan_scale;  // screen uv -> tangent of the view angle
	vec2 size;       // mask size
	vec2 full_size;  // scene size
	vec4 shape;      // x: glow radius (radians), y: brightest sky taken, z: reach (radians)
	vec4 unused;
} p;

void main() {
	ivec2 pixel = ivec2(gl_GlobalInvocationID.xy);
	if (pixel.x >= int(p.size.x) || pixel.y >= int(p.size.y)) {
		return;
	}
	vec2 uv = (vec2(pixel) + 0.5) / p.size;
	vec2 spread = 0.25 / p.size;
	vec3 light = vec3(0.0);
	for (int i = 0; i < 4; i++) {
		vec2 at = uv + spread * vec2((i & 1) == 0 ? -1.0 : 1.0, i < 2 ? -1.0 : 1.0);
		// Reverse-Z: open sky stays at the cleared far plane, 0.
		if (textureLod(depth_texture, at, 0.0).r <= 0.000001) {
			ivec2 texel = clamp(ivec2(at * p.full_size), ivec2(0), ivec2(p.full_size) - 1);
			light += min(imageLoad(scene, texel).rgb, vec3(p.shape.y));
		}
	}
	float angle = length((uv - p.sun_uv) * p.tan_scale);
	// A bright core round the sun with a long soft tail, so the rays still
	// fall into view when the sun itself is just off screen.
	float glow = 1.0 / (1.0 + angle * angle / (p.shape.x * p.shape.x));
	glow *= 1.0 - smoothstep(p.shape.z * 0.5, p.shape.z, angle);
	imageStore(mask, pixel, vec4(light * 0.25 * glow, 1.0));
}
