shader_type spatial;
// Tenture murale damassée : fond profond, motif en médaillons ton sur ton, rayures fines.
uniform vec3 base_col : source_color = vec3(0.28, 0.04, 0.07);
uniform vec3 motif_col : source_color = vec3(0.42, 0.09, 0.12);
uniform vec3 stripe_col : source_color = vec3(0.6, 0.42, 0.18);
uniform float scale = 0.7;
varying vec3 wpos;
varying vec3 wnorm;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	float u = abs(wnorm.x) > 0.5 ? wpos.z : wpos.x;
	vec2 p = vec2(u, wpos.y) / scale;
	vec2 cell = fract(p) - 0.5;
	cell.x *= 1.6;
	float r = length(cell);
	float a = atan(cell.y, cell.x);
	float m = smoothstep(0.32, 0.3, r + 0.06 * cos(a * 6.0)) * (1.0 - smoothstep(0.12, 0.1, r)) ;
	m += smoothstep(0.08, 0.06, r);
	float stripe = smoothstep(0.015, 0.0, abs(fract(u / (scale * 1.0)) - 0.0)) ;
	vec3 col = mix(base_col, motif_col, clamp(m, 0.0, 1.0));
	col = mix(col, stripe_col, stripe * 0.6);
	ALBEDO = col;
	ROUGHNESS = 0.8;
}
