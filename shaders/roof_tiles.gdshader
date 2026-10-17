shader_type spatial;
render_mode cull_disabled;
// Tuiles canal du Poitou : rangs de tuiles rondes qui descendent la pente, teintes ocre et rose variées.
// UV en mètres : x le long de l'égout, y le long de la pente. La couleur de base vient du sommet.
uniform float tile_w = 0.16;
uniform float tile_l = 0.26;
#include "res://shaders/village_cutaway.gdshaderinc"
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
varying vec3 cut_wpos;
void vertex() {
	cut_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	cutaway(cut_wpos, FRAGCOORD.xy);
	vec2 p = vec2(UV.x / tile_w, UV.y / tile_l);
	float col_i = floor(p.x);
	p.y += hash(vec2(col_i, 1.7)) * 0.4;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float h = hash(cell);
	// Le dos rond de la tuile, et l'ombre du recouvrement en haut de chaque tuile.
	float round_x = sin(f.x * 3.14159);
	float lap = smoothstep(0.0, 0.18, f.y);
	vec3 tint = COLOR.rgb * mix(0.82, 1.12, h) * mix(vec3(1.0), vec3(1.06, 0.92, 0.86), hash(cell + 4.1));
	vec3 col = tint * (0.55 + 0.45 * round_x) * mix(0.7, 1.0, lap);
	// Un peu de mousse et de lichen dans les creux.
	col = mix(col, vec3(0.42, 0.45, 0.3), (1.0 - round_x) * 0.25 * hash(cell + 9.3));
	ALBEDO = col;
	ROUGHNESS = 0.8;
	NORMAL_MAP = normalize(vec3(cos(f.x * 3.14159) * 0.9, (1.0 - lap) * 0.8, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.2;
}
