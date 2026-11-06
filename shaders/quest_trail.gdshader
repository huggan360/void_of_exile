shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

// The mesh follows actual terrain. Tiny offsets suggest magic drifting along
// it, staying well inside the character-clearance envelope of the route.
void vertex() {
	float wave = sin(UV.x * 2.4 - TIME * 2.2);
	VERTEX.x += wave * 0.022;
	VERTEX.z += cos(UV.x * 1.7 - TIME * 1.9) * 0.022;
	VERTEX.y += wave * 0.014;
}

void fragment() {
	float thread = 1.0 - smoothstep(0.12, 0.5, abs(UV.y - 0.5));
	float streak = pow(max(0.0, sin(UV.x * 5.5 - TIME * 3.8)), 5.0);
	float faint = 0.14 + 0.72 * streak;
	ALBEDO = COLOR.rgb;
	EMISSION = COLOR.rgb * 0.35;
	ALPHA = COLOR.a * thread * faint;
}
