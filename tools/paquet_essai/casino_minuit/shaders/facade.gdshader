shader_type spatial;
render_mode unshaded;
// Casino Minuit, lot E : les façades nocturnes du Strip (l'atlas E.facades du moteur web), en un seul matériau.
// UV en mètres (u le long de la façade, v vers le haut) ; COLOR.rgb : la teinte du mur ; COLOR.a : le style,
// en dixièmes : 0 hôtel aux fenêtres chaudes, 1 tour de verre bleue, 2 tour dorée, 3 balcons, 4 devantures,
// 5 tour du Minuit (laque rouge sombre, meneaux d'or), 6 ardoise, 7 béton nu, 8 parking, 9 chapelle.
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	int st = int(floor(COLOR.a * 10.0 + 0.5));
	vec3 mur = COLOR.rgb;
	vec2 cell = vec2(3.0, 3.0);
	vec4 marge = vec4(0.16, 0.84, 0.2, 0.86);
	float lit = 0.45;
	vec3 chaud = vec3(1.0, 0.78, 0.5);
	vec3 sombre = vec3(0.05, 0.045, 0.07);
	if (st == 1) { cell = vec2(2.0, 3.0); marge = vec4(0.04, 0.96, 0.06, 0.96); lit = 0.16; chaud = vec3(0.7, 0.8, 0.95); sombre = vec3(0.04, 0.06, 0.1); }
	else if (st == 2) { cell = vec2(2.0, 3.0); marge = vec4(0.04, 0.96, 0.06, 0.96); lit = 0.42; sombre = vec3(0.12, 0.08, 0.03); }
	else if (st == 3) { marge = vec4(0.2, 0.8, 0.24, 0.88); lit = 0.5; }
	else if (st == 5) { cell = vec2(3.0, 3.0); marge = vec4(0.1, 0.9, 0.17, 0.86); lit = 0.55; chaud = vec3(1.0, 0.82, 0.55); }
	vec2 g = UV / cell;
	vec2 id = floor(g);
	vec2 f = fract(g);
	float r = hash(id + vec2(COLOR.r * 31.0, COLOR.g * 17.0));
	vec3 c = mur;
	bool fen = f.x > marge.x && f.x < marge.y && f.y > marge.z && f.y < marge.w;
	if (st == 4) {
		// Devantures : vitrines claires sous un bandeau d'enseigne, auvents rayés.
		float v = UV.y;
		vec2 b = vec2(UV.x / 12.0, 0.0);
		float k = hash(floor(b) + 3.0);
		vec3 vit = mix(vec3(1.0, 0.92, 0.78), vec3(0.85, 0.92, 1.0), step(0.5, k)) * (0.75 + 0.25 * (1.0 - v / 4.0));
		c = vec3(0.07, 0.06, 0.08);
		if (v > 0.3 && v < 3.9 && fract(UV.x / 3.0) > 0.06) c = vit;
		if (v > 3.9 && v < 4.6) c = mod(floor(UV.x * 2.0), 2.0) < 1.0 ? vec3(0.6, 0.06, 0.1) : vec3(0.85, 0.8, 0.7);
		if (v > 4.9) c = vec3(0.1, 0.08, 0.1);
	} else if (st == 6) {
		c = vec3(0.11, 0.12, 0.17) * (0.8 + 0.4 * hash(floor(UV * vec2(3.0, 4.0))));
	} else if (st == 7) {
		c = mur * (0.85 + 0.15 * hash(floor(UV * 0.5)));
	} else if (st == 8) {
		float v = fract(UV.y / 3.0);
		c = v < 0.3 ? vec3(0.23) : vec3(0.3, 0.2, 0.1) * (1.0 - v);
		if (v > 0.6 && hash(floor(vec2(UV.x / 2.5, UV.y / 3.0))) > 0.45) c = vec3(0.4, 0.06, 0.08);
	} else if (st == 9) {
		c = mur;
		float a = fract(UV.x / 4.0);
		if (a > 0.3 && a < 0.7 && UV.y > 0.8 && UV.y < 4.5 - 1.6 * pow(abs(a - 0.5) * 5.0, 2.0)) c = vec3(1.0, 0.85, 0.65);
	} else if (fen) {
		if (r < lit) {
			c = chaud * (0.75 + 0.35 * hash(id + 5.0)) * mix(1.15, 0.8, f.y);
			if (hash(id + 9.0) < 0.3 && f.x < 0.45) c *= 0.45;
		} else if (r < lit + 0.06) c = vec3(0.12, 0.14, 0.26);
		else c = sombre;
		if (st == 5 && abs(f.x - 0.5) < 0.02) c = vec3(0.4, 0.3, 0.12);
	} else if (st == 5) {
		c = (f.y < 0.12) ? vec3(0.23, 0.05, 0.08) : ((f.x < 0.06 || f.x > 0.94) ? vec3(0.56, 0.42, 0.17) : mur);
	} else if (st == 3 && f.y > 0.82 && f.y < 0.9) c = vec3(0.7, 0.68, 0.62);
	ALBEDO = c;
}
