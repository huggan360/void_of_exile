shader_type spatial;
// Glowing spell particles (motes, sparkles, flakes, leaves, bubbles), added
// onto the scene so they bloom. Not voxels on purpose: magic is the smooth
// thing in the world.
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

#include "res://shaders/spell_mote.gdshaderinc"

void fragment() {
	float body = mote_body(UV);
	vec3 col = mix(COLOR.rgb, vec3(1.0), clamp(body - 1.0 + core, 0.0, 1.0) * core);
	ALBEDO = col * energy * body;
	ALPHA = clamp(body, 0.0, 1.0) * COLOR.a;
}
