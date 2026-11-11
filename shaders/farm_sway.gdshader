shader_type spatial;
// Vesperis's voxel crops, grass, bushes and trees (CountryFlora), coloured
// like every voxel model (voxel_model.gdshader). Plants with `sway` move in
// the wind and lean away from whoever walks through them (pushers).

uniform vec3 planet_center;
instance uniform float tile_visibility = 1.0;
instance uniform float detail_near = 0.0;
instance uniform float detail_far_start = 48.0;
instance uniform float detail_far_end = 72.0;
uniform float height = 1.0;  // the plant's top in mesh units
uniform float sway = 0.0;  // how far a top leans (m)
uniform vec4 pushers[8];  // xyz world position, w reach (m)
varying vec3 local_pos;
varying vec3 local_normal;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.71, 0.113, 0.419));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

vec3 srgb_to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045)));
}

void vertex() {
	local_pos = VERTEX;
	local_normal = NORMAL;
	vec3 plant_base = MODEL_MATRIX[3].xyz;
	float distance_to_eye = length(plant_base - CAMERA_POSITION_WORLD);
	float coverage = 1.0 - smoothstep(detail_far_start, detail_far_end, distance_to_eye);
	if (detail_near > 0.0) coverage *= smoothstep(detail_near, detail_near + 20.0, distance_to_eye);
	float visibility = coverage * tile_visibility;
	// Fully faded plants collapse to a point (vertex shaders can't return early).
	if (visibility <= 0.001) {
		VERTEX = vec3(0.0);
	}
	VERTEX.y *= visibility;
	if (sway > 0.0 && visibility > 0.001) {
		vec3 base = MODEL_MATRIX[3].xyz;
		vec3 displacement = vec3(0.0);
		vec3 up = normalize(base - planet_center);
		float t = clamp(VERTEX.y / height, 0.0, 1.0);
		float bend = t * t;
		vec3 side = normalize(cross(up, vec3(0.31, 0.77, 0.55)));
		displacement += side * sin(TIME * 1.6 + dot(base, vec3(0.13, 0.17, 0.11))) * sway * 0.16 * bend;
		for (int k = 0; k < 8; k++) {
			vec4 who = pushers[k];
			if (who.w <= 0.0) continue;
			vec3 d = base - who.xyz;
			d -= up * dot(d, up);
			float dist = length(d);
			if (dist < who.w) {
				float push = (who.w - dist) / who.w;
				displacement += normalize(d + side * 0.001) * push * 0.8 * bend * sway;
				displacement -= up * push * 0.4 * bend * sway;
			}
		}
		// These instances have orthogonal scaled bases. Transform the offset
		// directly, avoiding a matrix inverse and a world-position round trip.
		vec3 x = MODEL_MATRIX[0].xyz;
		vec3 y = MODEL_MATRIX[1].xyz;
		vec3 z = MODEL_MATRIX[2].xyz;
		VERTEX += vec3(dot(displacement,x)/max(dot(x,x),0.000001),
			dot(displacement,y)/max(dot(y,y),0.000001),dot(displacement,z)/max(dot(z,z),0.000001));
	}
}

void fragment() {
	vec3 voxel = floor(local_pos - local_normal * 0.5);
	float h = hash3(voxel) - 0.5;
	float warm = hash3(voxel + 11.7) - 0.5;
	vec3 color = srgb_to_linear(COLOR.rgb);
	color *= 1.0 + h * 0.14;
	color *= vec3(1.0 + warm * 0.04, 1.0, 1.0 - warm * 0.04);
	ALBEDO = color;
	ROUGHNESS = 0.85;
}
