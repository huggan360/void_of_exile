shader_type sky;
uniform vec4 day_top : source_color = vec4(0.20,0.42,0.68,1.0);
uniform vec4 day_horizon : source_color = vec4(0.66,0.79,0.88,1.0);
uniform float ascent : hint_range(0.0,1.0) = 0.0;
float hash3(vec3 p) { return fract(sin(dot(p,vec3(17.17,57.31,113.79)))*43758.5453); }
void sky() {
	float height = smoothstep(-0.12,0.8,EYEDIR.y);
	vec3 daylight = mix(day_horizon.rgb,day_top.rgb,height);
	if (LIGHT0_ENABLED) {
		float sun = smoothstep(0.9988,0.9997,dot(EYEDIR,LIGHT0_DIRECTION));
		daylight += sun*LIGHT0_COLOR*1.7;
	}
	vec3 grid = EYEDIR*560.0;
	float star = pow(max(0.0,1.0-length(fract(grid)-vec3(0.5))*2.3),5.0)*step(0.991,hash3(floor(grid)));
	float nebula = pow(max(0.0,sin(EYEDIR.x*8.0+EYEDIR.z*4.0)*sin(EYEDIR.y*7.0+EYEDIR.x*2.0)),5.0);
	vec3 space = vec3(0.002,0.003,0.012)+nebula*vec3(0.028,0.011,0.065)+star*vec3(1.25,1.45,1.8);
	COLOR = mix(daylight,space,ascent);
}
