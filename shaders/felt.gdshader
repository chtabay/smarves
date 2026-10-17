shader_type spatial;
// Feutre de table : laine grainée, léger lustre rasant, et tapis imprimé par-dessus (encre un peu moins mate).

uniform vec3 felt_col : source_color = vec3(0.035, 0.29, 0.16);
uniform sampler2D layout_tex : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform bool use_layout = false;
// Taille du tapis en mètres, pour que le grain garde la même finesse quelle que soit la table.
uniform vec2 size_m = vec2(2.0, 1.0);
uniform float sheen = 0.35;
uniform float vignette = 0.35;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * size_m;
	// Fibres fines (s'effacent au loin pour ne pas scintiller), nuages de teinte plus larges.
	float fine_fade = clamp(1.0 - length(fwidth(p * 900.0)) * 0.6, 0.0, 1.0);
	float fibres = (vnoise(p * 900.0) - 0.5) * fine_fade + (vnoise(p * 310.0 + 7.0) - 0.5) * 0.6;
	float clouds = vnoise(p * 6.0) * 0.6 + vnoise(p * 17.0) * 0.4;
	vec3 col = felt_col * (0.86 + 0.16 * clouds + 0.14 * fibres);
	// Les bords du tapis s'assombrissent un peu, comme sous la main courante.
	vec2 e = min(UV, 1.0 - UV) * size_m;
	float edge = smoothstep(0.0, 0.18, min(e.x, e.y));
	col *= mix(1.0 - vignette, 1.0, edge);
	float ink = 0.0;
	if (use_layout) {
		vec4 l = texture(layout_tex, UV);
		ink = l.a;
		col = mix(col, l.rgb * (0.95 + 0.08 * fibres), l.a * 0.94);
	}
	ALBEDO = col;
	ROUGHNESS = mix(0.97, 0.7, ink);
	SPECULAR = 0.25;
	RIM = sheen * (1.0 - ink);
	RIM_TINT = 0.7;
	NORMAL_MAP = normalize(vec3(0.5 + fibres * 0.12, 0.5 + (vnoise(p * 900.0 + 3.0) - 0.5) * 0.12 * fine_fade, 1.0));
}
