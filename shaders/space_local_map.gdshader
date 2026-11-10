shader_type canvas_item;
uniform bool nexus_mode = false;
uniform bool map_ready = false;
uniform vec2 nexus_offset;
uniform vec2 nexus_right = vec2(1,0);
uniform vec2 nexus_back = vec2(0,1);
uniform float planet_radius = 1000.0;
uniform float view_radius = 120.0;
uniform float atlas_span = 220.0;
uniform vec3 view_up = vec3(0,1,0);
uniform vec3 view_right = vec3(1,0,0);
uniform vec3 view_back = vec3(0,0,1);
uniform vec3 atlas_up = vec3(0,1,0);
uniform vec3 atlas_right = vec3(1,0,0);
uniform vec3 atlas_back = vec3(0,0,1);
void fragment() {
	vec2 cell = (floor(UV*88.0)+0.5)/88.0;
	vec2 p = (cell-0.5)*2.0;
	if (length(p)>0.88) { COLOR=vec4(0); }
	else if (nexus_mode) {
		vec2 ground = p/0.86*view_radius-nexus_offset;
		vec2 world = nexus_right*ground.x+nexus_back*ground.y;
		float floor_mask = 1.0-step(47.0,length(ground));
		for (int k=0; k<6; k++) {
			float angle = float(k)*6.2831853/6.0;
			vec2 direction = vec2(sin(angle),cos(angle));
			float along = dot(world,direction);
			float across = abs(dot(world,vec2(direction.y,-direction.x)));
			floor_mask = max(floor_mask,step(30.0,along)*(1.0-step(62.0,along))*(1.0-step(2.5,across)));
		}
		COLOR=vec4(mix(vec3(0.06,0.09,0.11),vec3(0.38,0.43,0.34),floor_mask),1.0);
	} else if (!map_ready) { COLOR=vec4(0.12,0.17,0.18,1.0); }
	else {
		vec2 offset = p/0.86*view_radius;
		float angle = length(offset)/planet_radius;
		vec3 tangent = normalize(view_right*offset.x+view_back*offset.y+vec3(0.000001));
		vec3 direction = normalize(view_up*cos(angle)+tangent*sin(angle));
		float arc = acos(clamp(dot(atlas_up,direction),-1.0,1.0));
		vec3 local = direction-atlas_up*dot(atlas_up,direction);
		local = length(local)>0.000001 ? normalize(local)*arc*planet_radius : vec3(0);
		vec2 coord = vec2(dot(local,atlas_right),dot(local,atlas_back))/atlas_span*0.5+0.5;
		COLOR=texture(TEXTURE,clamp(coord,vec2(0),vec2(1)));
	}
}
