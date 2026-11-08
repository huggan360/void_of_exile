shader_type spatial;
// Beer in a glass: the liquid stops at a surface that tilts with the
// slosh; the inside back faces above the cut read as the foamy top.
render_mode cull_disabled;
uniform float fill = 1.0;
uniform vec2 tilt = vec2(0.0);
uniform float height = 0.3;
varying vec3 local;
void vertex() {
	local = VERTEX;
}
void fragment() {
	float surface = (fill - 0.5) * height + dot(local.xz, tilt);
	if (local.y > surface) discard;
	float foam = smoothstep(surface - 0.035, surface - 0.015, local.y);
	vec3 beer = mix(vec3(0.85, 0.48, 0.08), vec3(1.0, 0.7, 0.2), smoothstep(-height * 0.5, height * 0.5, local.y));
	float bubble = step(0.97, fract(sin(dot(floor(local * vec3(140.0, 60.0 - TIME * 8.0, 140.0)), vec3(12.9, 78.2, 37.7))) * 43758.5));
	vec3 color = FRONT_FACING ? mix(beer + bubble * 0.3, vec3(1.0, 0.97, 0.88), foam) : vec3(1.0, 0.96, 0.86);
	ALBEDO = color;
	ROUGHNESS = 0.3;
	EMISSION = beer * 0.08;
}
