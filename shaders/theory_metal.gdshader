shader_type spatial;
varying vec3 point;
varying vec3 world_normal;
vec3 linear_color(vec3 c) { return mix(pow((c+0.055)/1.055,vec3(2.4)),c/12.92,lessThan(c,vec3(0.04045))); }
void vertex() {
	point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
	vec3 tint=COLOR.rgb;
	float wood=step(tint.b*1.12,tint.g)*step(tint.g*1.15,tint.r)*(1.0-step(tint.r*0.76,tint.g));
	vec3 n=abs(world_normal);
	vec2 p=n.y>max(n.x,n.z) ? point.xz : (n.x>n.z ? point.yz : point.xy);
	float fade=(1.0-smoothstep(20.0,75.0,length(point-CAMERA_POSITION_WORLD)))*(1.0-smoothstep(0.4,1.4,length(fwidth(p*80.0))));
	float grain=sin(p.x*83.0+sin(p.y*2.0)*1.7)*0.065*wood;
	float tarnish=sin(point.x*4.1+sin(point.z*2.0))*sin(point.y*3.0)*0.045;
	ALBEDO=linear_color(tint)*(1.0+(grain+tarnish)*fade);
	METALLIC=mix(0.65,0.0,wood);
	ROUGHNESS=mix(0.42,0.88,wood);
}
