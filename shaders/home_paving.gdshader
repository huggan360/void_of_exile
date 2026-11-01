shader_type spatial;
uniform vec4 stone_color : source_color = vec4(0.51, 0.48, 0.40, 1.0);
varying vec3 world_pos;
void vertex() { world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
 vec2 p = world_pos.xz * 3.0;
 p.x += mod(floor(p.y), 2.0) * 0.5;
 vec2 cell = floor(p);
 vec2 f = fract(p);
 float seam = step(0.055, f.x) * step(0.055, f.y);
 float noise = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
 ALBEDO = stone_color.rgb * mix(0.64, 0.92 + noise * 0.16, seam);
 ROUGHNESS = 0.95;
}
