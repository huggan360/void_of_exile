shader_type canvas_item;
void fragment() {
	vec2 p=(UV-0.5)*vec2(SCREEN_PIXEL_SIZE.y/SCREEN_PIXEL_SIZE.x,1.0);
	float halo=exp(-dot(p,p)*9.0);
	COLOR=vec4(vec3(0.003,0.006,0.016)+vec3(0.006,0.009,0.02)*halo,1.0);
}
