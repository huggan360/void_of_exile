shader_type spatial;
// Black-magic particles: the same sprites as spell_mote, but they darken
// what's behind them instead of lighting it, with a faint colored edge.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled;

#include "res://shaders/spell_mote.gdshaderinc"

uniform vec3 edge : source_color = vec3(0.1, 0.2, 0.5);

void fragment() {
	float body = clamp(mote_body(UV), 0.0, 1.0);
	float rim = smoothstep(0.0, 0.35, body) * smoothstep(0.75, 0.35, body);
	ALBEDO = COLOR.rgb + edge * rim * energy * 0.5;
	ALPHA = smoothstep(0.0, 0.5, body) * COLOR.a;
}
