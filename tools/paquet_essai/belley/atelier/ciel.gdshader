shader_type sky;
// Le ciel de Belley, comme sur les planches : un bleu qui pâlit et se réchauffe vers l'horizon, et deux ou trois
// nuages plats d'été, posés bas sur un plan (verdict n° 20 : un bleu uni). Les teintes sont écrites telles quelles
// (le rendu de compatibilité ne convertit pas sa sortie).

uniform vec3 haut : source_color = vec3(0.42, 0.62, 0.84);
uniform vec3 horizon : source_color = vec3(0.90, 0.88, 0.80);
uniform vec3 sol_horizon : source_color = vec3(0.79, 0.78, 0.72);
uniform vec3 sol_bas : source_color = vec3(0.49, 0.49, 0.42);
uniform vec3 nuage : source_color = vec3(0.98, 0.97, 0.94);
uniform vec3 nuage_ombre : source_color = vec3(0.80, 0.82, 0.86);

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 4; k++) {
		v += a * bruit(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	if (d.y < 0.0) {
		COLOR = mix(sol_horizon, sol_bas, smoothstep(0.0, 0.4, -d.y));
	} else {
		vec3 col = mix(horizon, haut, pow(smoothstep(0.0, 0.55, d.y), 0.7));
		// Les nuages : sur un plan, à l'est et au nord surtout ; peu nombreux, au bord net, le dessous plus gris.
		vec2 p = d.xz / (d.y + 0.12) * 1.6;
		float n = fbm(p * 0.9 + vec2(3.0, 7.0));
		float masse = smoothstep(0.6, 0.68, n) * smoothstep(0.03, 0.12, d.y) * (1.0 - smoothstep(0.35, 0.6, d.y));
		masse *= smoothstep(0.35, 0.55, fbm(p * 0.25 + 11.0));
		float dessous = smoothstep(0.6, 0.75, fbm(p * 0.9 + vec2(3.0, 7.3)));
		vec3 c = mix(nuage_ombre, nuage, dessous);
		COLOR = mix(col, c, masse);
	}
}
