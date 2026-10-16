shader_type spatial;
// Moquette de casino : bordeaux profond, treillis de losanges et fleurons dorés.
uniform vec3 base_col : source_color = vec3(0.32, 0.03, 0.06);
uniform vec3 motif_col : source_color = vec3(0.5, 0.33, 0.12);
uniform vec3 deep_col : source_color = vec3(0.12, 0.02, 0.05);
uniform float scale = 1.2;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz / scale;
	vec2 d = vec2(p.x + p.y, p.x - p.y);
	vec2 f = abs(fract(d) - 0.5);
	float lattice = smoothstep(0.47, 0.49, max(f.x, f.y));
	vec2 c = fract(p) - 0.5;
	float r = length(c);
	float petals = 0.5 + 0.5 * cos(atan(c.y, c.x) * 8.0);
	float flower = smoothstep(0.17, 0.15, r - petals * 0.05) * smoothstep(0.03, 0.05, r);
	float inner = smoothstep(0.32, 0.3, max(abs(c.x) + abs(c.y), 0.0)) - smoothstep(0.3, 0.28, abs(c.x) + abs(c.y));
	vec3 col = mix(base_col, deep_col, smoothstep(0.0, 0.5, r) * 0.6);
	col = mix(col, motif_col, max(max(lattice, flower * 0.9), inner * 0.5));
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.1;
}
