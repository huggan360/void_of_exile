shader_type spatial;
render_mode unshaded, fog_disabled, shadows_disabled;
varying float edge_light;
varying float seed;
void vertex() {
	seed=float(INSTANCE_ID);
	vec3 p=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	float a=TIME*0.28;
	float tilt=0.35+sin(TIME*0.6)*0.18;
	p.xy=mat2(vec2(cos(a),sin(a)),vec2(-sin(a),cos(a)))*p.xy;
	p.xz=mat2(vec2(cos(tilt),sin(tilt)),vec2(-sin(tilt),cos(tilt)))*p.xz;
	p.y+=sin(TIME*1.3+seed*0.2)*0.025;
	edge_light=0.55+max(0.0,NORMAL.z)*0.45;
	POSITION=PROJECTION_MATRIX*VIEW_MATRIX*vec4(p,1.0);
}
void fragment() {
	float pulse=0.75+0.25*sin(TIME*2.0-seed*0.38);
	ALBEDO=COLOR.rgb*edge_light;
	EMISSION=COLOR.rgb*(0.8+pulse*1.4);
}
