shader_type canvas_item;
uniform bool nexus_mode = false;
uniform bool map_ready = false;
uniform float planet_radius = 1000.0;
uniform float view_radius = 32.0;
uniform float atlas_span = 58.0;
uniform float art_pixels = 88.0;
uniform float map_edge = 0.9090909;
uniform vec3 view_origin = vec3(0.0);
uniform vec3 atlas_origin = vec3(0.0);
uniform vec3 view_up = vec3(0,1,0);
uniform vec3 view_right = vec3(1,0,0);
uniform vec3 view_back = vec3(0,0,1);
uniform vec3 atlas_up = vec3(0,1,0);
uniform vec3 atlas_right = vec3(1,0,0);
uniform vec3 atlas_back = vec3(0,0,1);
#include "res://shaders/minimap_frame.gdshaderinc"
void fragment() {
	vec2 cell = (floor(UV*art_pixels)+0.5)/art_pixels;
	vec2 p = cell*2.0-1.0;
	if (length(p)>1.0) discard;
	vec3 color;
	if (!minimap_rim(p,art_pixels,map_edge,color)) {
		if (!map_ready) {
			color = vec3(0.07,0.10,0.12);
		} else {
			vec2 offset = (UV*2.0-1.0)/map_edge*view_radius;
			vec3 local;
			if (nexus_mode) {
				local = view_origin-atlas_origin+view_right*offset.x+view_back*offset.y;
			} else {
				float angle = length(offset)/planet_radius;
				vec3 tangent = normalize(view_right*offset.x+view_back*offset.y+vec3(0.000001));
				vec3 direction = normalize(view_up*cos(angle)+tangent*sin(angle));
				vec3 radial = direction-atlas_up*dot(atlas_up,direction);
				float arc = atan(length(radial),clamp(dot(atlas_up,direction),-1.0,1.0));
				local = length(radial)>0.000001 ? normalize(radial)*arc*planet_radius : vec3(0.0);
			}
			vec2 coord = vec2(dot(local,atlas_right),dot(local,atlas_back))/atlas_span*0.5+0.5;
			color = texture(TEXTURE,clamp(coord,vec2(0.0),vec2(1.0))).rgb;
		}
	}
	COLOR = vec4(color,1.0);
}
