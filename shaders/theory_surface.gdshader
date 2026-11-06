shader_type spatial;
render_mode world_vertex_coords;
uniform vec4 impact = vec4(0.0,0.0,0.0,-1000.0);
uniform vec3 surface_up = vec3(0.0,1.0,0.0);
uniform float impact_age = 10.0;
uniform float instability = 0.0;
uniform float reveal = 0.0;
uniform bool sky = false;
uniform float ship_material = 0.0;
varying vec3 world_point;
varying float glow;
varying float seed;
varying float face;
varying float reacts;
varying vec3 world_normal;
float hash(float n) { return fract(sin(n*71.17+19.31)*43758.5453); }
vec3 linear_color(vec3 c) { return mix(pow((c+0.055)/1.055,vec3(2.4)),c/12.92,lessThan(c,vec3(0.04045))); }
void vertex() {
	bool swept_mesh=COLOR.a<0.9;
	vec3 center=swept_mesh ? VERTEX : MODEL_MATRIX[3].xyz;
	seed=swept_mesh ? fract(dot(COLOR.rgb,vec3(13.17,37.71,17.13))) : INSTANCE_CUSTOM.g;
	reacts=swept_mesh ? step(0.4,COLOR.a) : INSTANCE_CUSTOM.b;
	glow=swept_mesh ? max(0.0,(COLOR.a-reacts*0.45)*10.0) : INSTANCE_CUSTOM.r;
	float radius=distance(center,impact.xyz);
	float envelope=exp(-radius*0.20)*exp(-impact_age*1.5);
	float wave=sin(radius*6.0-impact_age*13.0)*envelope*0.24;
	VERTEX+=surface_up*wave*reacts;
	float broken=step(0.78,seed)*instability*INSTANCE_CUSTOM.a;
	VERTEX+=surface_up*(sin(TIME*0.7+seed*18.0)*0.18+reveal*(2.0+seed*5.0))*broken;
	world_point=VERTEX;
	world_normal=NORMAL;
	face=0.48+0.52*max(0.0,dot(NORMAL,normalize(vec3(0.3,0.85,0.4))));
}
void fragment() {
	float radius=distance(world_point,impact.xyz);
	float pulse=(1.0-smoothstep(0.1,1.0,impact_age))*exp(-radius*0.25);
	float blink=step(0.22,hash(floor(TIME*25.0)+seed*17.0));
	float glitch=step(0.62,seed)*blink*pulse*reacts;
	vec3 tint=COLOR.rgb;
	// Existing gameplay cabinets also receive wood/brass and crystal finishes.
	if (ship_material>0.5 && max(tint.r,max(tint.g,tint.b))>0.22 && tint.b>tint.r*1.04 && tint.b>tint.g*1.04) {
		tint=glow>0.4 ? vec3(0.48,0.88,0.57) : vec3(0.48,0.29,0.17)*mix(0.65,1.25,tint.g);
	}
	vec3 base=linear_color(tint);
	float wood=step(tint.b*1.12,tint.g)*step(tint.g*1.15,tint.r)*(1.0-step(tint.r*0.76,tint.g));
	wood*=1.0-step(0.4,glow);
	float brass=step(tint.g*1.12,tint.r)*step(tint.b*1.35,tint.g)*(1.0-wood)*(1.0-step(0.4,glow));
	if (!sky && wood>0.5) {
		vec3 n=abs(normalize(world_normal));
		// Project in metres, independent of the size of a voxel or swept cell.
		vec2 p=n.y>max(n.x,n.z) ? world_point.xz : (n.x>n.z ? world_point.yz : world_point.xy);
		float board=floor(p.x/0.48);
		vec2 grid=vec2(p.x/0.48,(p.y+hash(board)*2.7)/3.6);
		vec2 edge=min(fract(grid),1.0-fract(grid));
		vec2 aa=max(fwidth(grid),vec2(0.0001));
		vec2 joints=vec2(1.0)-smoothstep(vec2(0.008),vec2(0.018)+aa,edge);
		float seam=max(joints.x,joints.y);
		float detail=1.0-smoothstep(22.0,85.0,length(world_point-CAMERA_POSITION_WORLD));
		float grain_fade=detail*(1.0-smoothstep(0.35,1.2,length(fwidth(p*60.0))));
		float waviness=sin(p.y*1.6+board*3.1)*0.65+sin(p.y*4.0+board)*0.15;
		float grain=sin(p.x*105.0+waviness*3.0)*0.035+sin(p.x*39.0+waviness)*0.045;
		vec2 knot=vec2(fract(grid.x)-0.5,(fract(grid.y)-0.47)*4.0);
		float knot_ring=sin(length(knot*vec2(2.0,1.0))*45.0+waviness);
		float knots=(1.0-smoothstep(0.06,0.38,length(knot)))*knot_ring*0.08;
		base*=1.0-seam*0.27*detail+(grain+knots)*grain_fade+(hash(board)-0.5)*0.12;
		if (ship_material>1.5) {
			float cells=hash(floor(p.x*2.1)+floor(p.y*0.55)*73.0);
			float split=(1.0-smoothstep(0.012,0.035+fwidth(p.x),abs(sin(p.x*32.0+sin(p.y*2.0)*0.2))))*step(0.65,cells);
			base=mix(base,base*vec3(0.30,0.40,0.27),cells*0.35+split*detail*0.50);
		}
	} else if (!sky && glow>0.4) {
		// Broad mineral facets stay calm at range; emissive voxels carry the light.
		float facets=hash(floor(world_point.x*3.0)+floor(world_point.z*3.0)*17.0+floor(world_point.y*4.0)*71.0);
		base*=0.92+facets*0.12;
	}
	ALBEDO=mix(base,vec3(1.0),glitch);
	ROUGHNESS=mix(0.88,0.40,brass);
	METALLIC=brass*0.65;
	EMISSION=base*glow*1.4+vec3(glitch*1.8);
	if (sky) { EMISSION+=base*face*(glow<1.0 ? 0.75 : 1.2); ALBEDO=base*face; }
}
