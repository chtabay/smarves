shader_type spatial;
// Pierre et bois peint des maisons du bourg : la teinte vient du sommet (une seule matière pour toute
// la rue), un grain de calcaire projeté en triplanaire par-dessus, et la coupe de maquette.
#include "res://shaders/village_cutaway.gdshaderinc"
uniform sampler2D grain : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float grain_scale = 0.8;
uniform float grain_strength = 1.0;
uniform float rough = 0.9;
varying vec3 wpos;
varying vec3 wnorm;
void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	cutaway(wpos, FRAGCOORD.xy);
	vec3 bl = pow(abs(wnorm), vec3(4.0));
	bl /= (bl.x + bl.y + bl.z);
	vec3 p = wpos * grain_scale;
	float g = texture(grain, p.zy).r * bl.x + texture(grain, p.xz).r * bl.y + texture(grain, p.xy).r * bl.z;
	ALBEDO = COLOR.rgb * mix(1.0, g, grain_strength);
	ROUGHNESS = rough;
}
