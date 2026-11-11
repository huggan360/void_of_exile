shader_type canvas_item;
// The Surface on the star chart: the same oceans, meadows, deserts and snow
// as space_surface.gdshader, painted where the floor of Space lands on the
// chart (each pixel is projected back onto the plane y = surface_y).
// SpaceMap feeds the chart's view; dimmed so markers read on top of it.

uniform vec2 view_size = vec2(1600.0, 900.0);
uniform vec3 center = vec3(0.0);
uniform float yaw = 0.0;
uniform float tilt = 0.95;
uniform float zoom = 0.032;
uniform float surface_y = -14000.0;
uniform float radius = 46000.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int k = 0; k < 6; k++) { v += a * noise(p); p = p * 2.03 + vec2(17.1, 9.3); a *= 0.5; }
	return v;
}

void fragment() {
	vec2 px = UV * view_size - view_size * 0.5;
	float c = cos(tilt);
	if (abs(c) < 0.02) discard;  // edge-on: the floor is a line
	float rel_y = surface_y - center.y;
	vec2 rel = vec2(px.x / zoom, (px.y / zoom + rel_y * sin(tilt)) / c);
	// Undo the chart's turn.
	vec2 xz = center.xz + vec2(rel.x * cos(yaw) - rel.y * sin(yaw), rel.x * sin(yaw) + rel.y * cos(yaw));
	vec2 p = xz / 9000.0;
	float land = fbm(p);
	float temp = fbm(p * 0.6 + vec2(40.0, 3.0));
	vec3 ocean = mix(vec3(0.05, 0.16, 0.34), vec3(0.08, 0.32, 0.48), smoothstep(0.38, 0.48, land));
	vec3 meadow = mix(vec3(0.2, 0.42, 0.18), vec3(0.32, 0.5, 0.2), noise(p * 8.0));
	vec3 ground = mix(meadow, vec3(0.68, 0.56, 0.34), smoothstep(0.55, 0.7, temp));
	ground = mix(ground, vec3(0.86, 0.9, 0.95), smoothstep(0.62, 0.72, land) * 0.8);
	ground = mix(ground, vec3(0.25, 0.3, 0.2), smoothstep(0.66, 0.78, land) * 0.4);
	vec3 color = mix(ocean, ground, smoothstep(0.49, 0.51, land));
	float clouds = smoothstep(0.55, 0.8, fbm(p * 1.7));
	color = mix(color, vec3(0.95, 0.96, 1.0), clouds * 0.5);
	// Dimmed under the chart, fading into the dark past the edge of the Reach.
	float edge = 1.0 - smoothstep(radius * 0.8, radius, length(xz));
	COLOR = vec4(color * 0.55, 0.9 * edge);
}
