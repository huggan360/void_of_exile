shader_type spatial;
render_mode world_vertex_coords, fog_disabled, cull_back;
uniform mat4 capture_camera;
uniform vec3 focus;
uniform float progress : hint_range(0.0,1.0) = 0.0;
uniform bool assembling = false;
uniform float handoff : hint_range(0.0,1.0) = 0.0;
varying vec3 tile_color;
varying float tile_seed;
varying float tile_phase;
varying float tile_glow;
varying float face_shade;
float hash(float n) { return fract(sin(n*127.1+311.7)*43758.5453); }
vec3 linear_color(vec3 c) { return mix(pow((c+0.055)/1.055,vec3(2.4)),c/12.92,lessThan(c,vec3(0.04045))); }
mat3 rotation(vec3 a,float angle) {
	float c=cos(angle),s=sin(angle),t=1.0-c;
	return mat3(vec3(t*a.x*a.x+c,t*a.x*a.y+s*a.z,t*a.x*a.z-s*a.y),
		vec3(t*a.x*a.y-s*a.z,t*a.y*a.y+c,t*a.y*a.z+s*a.x),
		vec3(t*a.x*a.z+s*a.y,t*a.y*a.z-s*a.x,t*a.z*a.z+c));
}
void vertex() {
	vec3 target=MODEL_MATRIX[3].xyz;
	vec3 local=VERTEX-target;
	float seed=INSTANCE_CUSTOM.r;
	// Small world-space patches peel first; the tear then spreads across the
	// scene. Adjacent voxels share the main delay, with a little edge fraying.
	float delay=assembling ? INSTANCE_CUSTOM.a*0.13+INSTANCE_CUSTOM.g*0.09
		: 0.06+pow(INSTANCE_CUSTOM.a,0.75)*0.60+INSTANCE_CUSTOM.g*0.035;
	float p=clamp((progress-delay)/((assembling ? 0.87 : 1.0)-delay),0.0,1.0);
	tile_phase=p;
	tile_seed=seed;
	tile_color=COLOR.rgb;
	tile_glow=INSTANCE_CUSTOM.b;
	vec3 back=capture_camera[2].xyz;
	vec3 right=capture_camera[0].xyz;
	vec3 up=capture_camera[1].xyz;
	vec3 axis=normalize(vec3(hash(seed+1.0),hash(seed+2.0),hash(seed+4.0))-0.5);
	float spin=(seed-0.5)*10.0;
	vec3 center=target;
	float angle=0.0;
	float size=1.0;
	if (assembling) {
		float a=hash(seed+9.0)*6.2831853;
		vec3 start=capture_camera[3].xyz+back*(4.0+seed*14.0)+(right*cos(a)+up*sin(a))*(3.0+hash(seed+11.0)*20.0);
		float flight=smoothstep(0.0,1.0,p);
		center=mix(start,target,flight)+up*sin(p*3.14159265)*(2.0+seed*5.0);
		angle=spin*pow(1.0-p,1.5);
		size=mix(0.78,1.0,smoothstep(0.72,1.0,p));
	} else {
		vec3 radial=target-focus;
		radial.y=0.0;
		vec3 out_dir=normalize(radial+right*0.01);
		float lift=pow(p,1.6);
		center+=out_dir*lift*(4.0+seed*16.0)+vec3(0,1,0)*lift*(8.0+hash(seed+3.0)*22.0);
		center+=back*pow(p,2.6)*(8.0+seed*20.0);
		center+=right*sin(p*3.14159265)*(seed-0.5)*3.0;
		angle=spin*smoothstep(0.02,0.8,p);
		size=mix(1.0,0.78,smoothstep(0.0,0.18,p))*(1.0-smoothstep(0.8,1.0,p));
	}
	mat3 turn=rotation(axis,angle);
	VERTEX=center+turn*local*size;
	NORMAL=normalize(turn*NORMAL);
	// Keep the same readable voxel face contrast in sunlit and dark realms.
	face_shade=0.38+0.62*max(0.0,dot(NORMAL,normalize(vec3(0.4,0.85,0.3))));
}
void fragment() {
	if (tile_seed<handoff) discard;
	float moving=smoothstep(0.01,0.12,tile_phase)*(1.0-smoothstep(0.8,1.0,tile_phase));
	// Clear, held white pulses like enemy hurt voxels, with rare chromatic ones.
	float blink=step(0.38,hash(floor(TIME*9.0)+tile_seed*417.0));
	float white=step(0.92,tile_seed)*blink*moving;
	vec3 flash=vec3(1.0);
	if (tile_seed>0.994) flash=vec3(0.25,0.95,1.0);
	else if (tile_seed>0.990) flash=vec3(1.0,0.3,0.85);
	vec3 base=linear_color(tile_color);
	ALBEDO=mix(base*face_shade,flash,white);
	ROUGHNESS=0.72;
	SPECULAR=0.32;
	EMISSION=base*tile_glow*1.4+flash*white*1.15;
}
