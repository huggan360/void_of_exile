shader_type spatial;
render_mode cull_disabled;
uniform float clock = 0.0;
varying float mode;
varying float seed;
varying float fault;
varying vec3 world_point;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float lamp(float t,float s) {
	float period=7.5+mod(s,3.5);
	float phase=mod(t+s*3.17,period);
	if (phase<2.8) return sin(phase*51.0+s)+0.35*sin(phase*89.0)>0.87 ? 0.10 : 0.82+0.18*sin(phase*5.3+s);
	if (phase>period*0.62 && phase<period*0.62+0.85) return sin(phase*71.0+s)>0.45 ? 0.18 : 0.7;
	return 0.025;
}
void vertex() { world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; mode=INSTANCE_CUSTOM.r; seed=INSTANCE_CUSTOM.g; fault=INSTANCE_CUSTOM.b; }
void fragment() {
	vec2 q=UV*2.0-1.0;
	float detail=1.0-smoothstep(20.0,70.0,length(world_point-CAMERA_POSITION_WORLD));
	vec3 color=COLOR.rgb;
	float emission=0.0;
	float alpha=1.0;
	if (mode<0.5) {
		vec2 cells=UV*vec2(25,14);
		float aa=max(fwidth(cells.x),fwidth(cells.y));
		float hole=1.0-smoothstep(0.21-aa,0.27+aa,length(fract(cells)-0.5));
		float rim=smoothstep(0.0,0.035,min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y)));
		color=mix(color,color*(1.0-hole*0.93*detail),rim);
	} else if (mode<1.5) {
		float radius=length(q);
		if (radius>0.99) discard;
		float angle=atan(q.y,q.x);
		float tick=1.0-smoothstep(0.05,0.12+fwidth(angle*20.0),abs(sin(angle*20.0)));
		tick*=step(0.67,radius)*(1.0-step(0.89,radius));
		float a=-0.8+mod(seed,2.3);
		vec2 direction=vec2(cos(a),sin(a));
		float needle=(1.0-smoothstep(0.012,0.026+length(fwidth(q)),abs(q.x*direction.y-q.y*direction.x)))*step(-0.10,dot(q,direction))*(1.0-step(0.66,dot(q,direction)));
		color=mix(color,vec3(0.025),max(tick,needle));
		color=mix(color,vec3(0.52,0.17,0.30),step(0.87,radius)*(1.0-step(0.94,radius))*step(0.6,angle));
		color=mix(color,vec3(0.07),1.0-smoothstep(0.05,0.08,radius));
	} else if (mode<2.5) {
		float stripe=step(0.5,fract((UV.x+UV.y)*9.0));
		color=mix(vec3(0.015),color,stripe);
	} else if (mode<3.5) {
		float radius=length(q);
		float aa=max(length(fwidth(q)),0.002);
		float orbit=1.0-smoothstep(0.008,0.022+aa,min(abs(radius-0.72),abs(radius-0.4)));
		float rose=1.0-smoothstep(0.01,0.025+aa,min(abs(q.x+q.y),abs(q.x-q.y)));
		float stars=pow(hash(floor(UV*vec2(22.0,14.0))+seed),26.0);
		color*=0.06+orbit*0.45+rose*step(radius,0.45)*0.45+stars*0.8;
		emission=0.45;
	} else if (mode<4.5) {
		float edge=length(q)+hash(floor(UV*23.0+seed))*0.3;
		alpha=1.0-smoothstep(0.6,1.1,edge);
		color*=0.5+hash(floor(UV*80.0))*0.4;
	} else if (mode<5.5) {
		vec2 cells=fract(UV*vec2(11,7));
		float slots=step(0.20,cells.x)*step(cells.x,0.8)*step(0.2,cells.y)*step(cells.y,0.8);
		color*=0.25+slots*0.75;
	} else if (mode<6.5) {
		float gain=fault>0.5 ? lamp(clock,seed) : 1.0;
		float louvres=0.84+0.16*cos(q.x*3.14159)*cos(q.y*3.14159);
		color*=0.07+gain*0.93;
		emission=gain*2.4*louvres;
	} else if (mode<7.5) {
		// Parchment star chart, compass rose and constellations.
		float radius=length(q);
		float aa=max(length(fwidth(q)),0.002);
		float rings=1.0-smoothstep(0.008,0.018+aa,min(abs(radius-0.72),abs(radius-0.39)));
		float axes=1.0-smoothstep(0.006,0.015+aa,min(abs(q.x),abs(q.y)));
		vec2 star_grid=UV*vec2(8.0,6.0);
		vec2 cell=floor(star_grid);
		vec2 offset=vec2(hash(cell+seed),hash(cell+seed+19.7))*0.65+0.18;
		float stars=1.0-smoothstep(0.035,0.065+length(fwidth(star_grid)),length(fract(star_grid)-offset));
		float ink=max(stars,max(rings,axes*step(radius,0.85)));
		color=mix(color*0.83,vec3(0.14,0.20,0.16),ink*0.90*detail);
		emission=0.10;
	} else if (mode<8.5) {
		// Sparse web strands, visible in a flashlight, with transparent gaps.
		vec2 p=vec2(UV.x,UV.y*0.65);
		float angle=atan(p.y,p.x);
		float radius=length(p);
		float aa=max(length(fwidth(p)),0.002);
		float spokes=abs(sin(angle*8.0))*radius;
		float arcs=abs(sin(radius*48.0+sin(angle*8.0)*0.4))/48.0;
		alpha=detail*(1.0-smoothstep(0.002,0.005+aa,min(spokes,arcs)))*(1.0-smoothstep(0.65,1.05,radius))*0.65;
	} else {
		// Three slanted claw gouges and ragged resin edges.
		vec2 p=vec2(q.x+q.y*0.22,q.y);
		float claws=min(abs(p.x+0.40),min(abs(p.x),abs(p.x-0.40)));
		float aa=max(fwidth(p.x),0.002);
		alpha=detail*(1.0-smoothstep(0.025,0.065+aa,claws))*step(abs(p.y),0.82+hash(vec2(floor(p.x*9.0+seed),seed))*0.12);
		color=mix(color,vec3(0.28,0.33,0.16),step(0.045,claws)*0.35);
	}

	ALBEDO=color;
	ROUGHNESS=mode<1.5 ? 0.62 : 0.83;
	EMISSION=color*emission;
	ALPHA=alpha;
	ALPHA_SCISSOR_THRESHOLD=0.08;
}
