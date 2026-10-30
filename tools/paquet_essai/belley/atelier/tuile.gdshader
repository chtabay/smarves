shader_type spatial;
// La tuile de Belley : tuile plate ou romane en rangs qui descendent la pente, teintes de l'orange au brun
// selon l'âge, l'ombre du recouvrement à chaque rang. UV en mètres : x le long de l'égout, y le long de la
// pente (vers le bas). La couleur de base vient du sommet ; son alpha dit la forme (0 : plate, 1 : canal).
render_mode diffuse_burley, cull_disabled;

uniform float largeur = 0.22;
uniform float pureau = 0.17;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 p = vec2(UV.x / largeur, UV.y / pureau);
	float rang = floor(p.y);
	p.x += mod(rang, 2.0) * 0.5;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float h = h21(cell);
	vec3 teinte = COLOR.rgb * mix(0.84, 1.12, h) * mix(vec3(1.0), vec3(1.05, 0.93, 0.85), h21(cell + 4.1));
	float canal = COLOR.a;
	float bombe = mix(1.0, 0.6 + 0.4 * sin(f.x * 3.14159), canal);
	float recouvre = smoothstep(0.0, 0.22, f.y);
	float fente = mix(smoothstep(0.0, 0.06, min(f.x, 1.0 - f.x)), 1.0, canal);
	vec3 col = teinte * bombe * mix(0.62, 1.0, recouvre) * mix(0.75, 1.0, fente);
	col = mix(col, vec3(0.36, 0.40, 0.27), 0.18 * h21(cell + 9.3) * (1.0 - recouvre));
	float flou = smoothstep(0.06, 0.25, max(fwidth(p.x), fwidth(p.y)));
	col = mix(col, COLOR.rgb * 0.9, flou * 0.85);
	ALBEDO = col;
	ROUGHNESS = 0.82;
	NORMAL_MAP_DEPTH = 1.0 - flou;
	NORMAL_MAP = normalize(vec3(mix(0.0, cos(f.x * 3.14159) * 0.8, canal), (1.0 - recouvre) * 0.9, 1.0)) * 0.5 + 0.5;
}
