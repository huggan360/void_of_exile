shader_type spatial;
uniform vec4 water_color : source_color = vec4(0.32,0.77,0.91,1.0);
uniform float flow_speed = 1.0;
void vertex() {
	float id = float(INSTANCE_ID);
	float tier = mod(id,4.0);
	float angle = mod(floor(id/4.0),16.0)/16.0*6.2831853;
	float t = fract(TIME*flow_speed*0.7+floor(id/64.0)*0.25+mod(id,7.0)*0.017);
	float radius;
	float height;
	if (tier<0.5) { radius=t*1.8; height=6.0+2.4*t-4.0*t*t; }
	else if (tier<1.5) { radius=1.65+t*1.2; height=4.65+0.6*t-2.5*t*t; }
	else if (tier<2.5) { radius=3.05+t*1.1; height=2.75+0.3*t-2.1*t*t; }
	else { radius=4.3+t*0.6; height=0.82+sin(t*3.14159265)*0.25; }
	VERTEX += round(vec3(cos(angle)*radius,height,sin(angle)*radius)*8.0)/8.0;
}
void fragment() {
	ALBEDO=water_color.rgb;
	EMISSION=water_color.rgb*0.45;
	ROUGHNESS=1.0;
}
