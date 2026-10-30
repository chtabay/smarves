shader_type spatial;
// Les façades de la ville vues d'un peu loin : l'enduit et ses fenêtres à volets peints, dessinés au lieu d'être
// maillés. UV : x le long du mur, y depuis son pied (en mètres) ; UV2 : la longueur et la hauteur du mur ;
// COLOR : l'enduit (sRGB), son alpha la graine de la maison (le rythme, la couleur des volets).
render_mode diffuse_burley;

uniform float etage = 3.0;
uniform float rdc = 3.4;
uniform float travee = 3.3;

const vec3 VOLETS[6] = vec3[](vec3(0.49, 0.57, 0.55), vec3(0.56, 0.64, 0.70), vec3(0.62, 0.42, 0.30),
	vec3(0.80, 0.78, 0.70), vec3(0.42, 0.50, 0.40), vec3(0.55, 0.36, 0.33));

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = UV;
	float longueur = abs(UV2.x);
	// Les fenêtres maillées (atelier/fenetres.gd) : le shader ne les dessine plus que de loin, fondues.
	bool maillee = UV2.x < 0.0;
	float hauteur = UV2.y;
	float graine = COLOR.a * 255.0;
	vec3 col = COLOR.rgb;
	// Un grain d'enduit, des coulures sous les appuis.
	float g = h21(floor(uv * 6.0) + graine);
	col *= 0.96 + 0.05 * g;
	// Les travées réparties sur la longueur, une marge aux angles.
	float n = max(floor((longueur - 1.2) / travee), 0.0);
	float pas = n > 0.0 ? (longueur - 1.2) / n : 1.0;
	float i = floor((uv.x - 0.6) / pas);
	float fx = (uv.x - 0.6) - (i + 0.5) * pas;
	float niv = uv.y < rdc ? 0.0 : 1.0 + floor((uv.y - rdc) / etage);
	float fy = uv.y < rdc ? uv.y : uv.y - rdc - (niv - 1.0) * etage;
	float haut_niv = niv < 0.5 ? rdc : etage;
	bool dedans = n > 0.0 && i >= 0.0 && i < n && uv.y < hauteur - 0.9;
	float lf = 0.62;
	float hf = niv < 0.5 ? 1.15 : 0.85;
	float bas = niv < 0.5 ? 0.9 : 0.95;
	float fw = max(fwidth(uv.x), fwidth(uv.y));
	float fin = 1.0 - smoothstep(0.015, 0.05, fw);
	vec2 c = vec2(fx, fy - bas - hf);
	float porte = niv < 0.5 && h21(vec2(i, graine)) < 0.28 ? 1.0 : 0.0;
	if (porte > 0.5) {
		c = vec2(fx, fy - 1.15);
		hf = 1.15;
		bas = 0.0;
	}
	float vetu = step(abs(c.x), lf) * step(abs(c.y), hf);
	float cadre = step(abs(c.x), lf + 0.12) * step(abs(c.y), hf + 0.12) * (1.0 - vetu);
	float volet = step(abs(c.x), lf * 2.05) * step(lf, abs(c.x)) * step(abs(c.y), hf);
	vec3 v = VOLETS[int(mod(graine, 6.0))];
	float ouvert = h21(vec2(i * 3.1, niv + graine)) ;
	if (dedans && !maillee) {
		col = mix(col, vec3(0.93, 0.91, 0.86), cadre * mix(0.5, 1.0, fin));
		if (vetu > 0.5) {
			// La vitre sombre et sa croisée, ou le volet fermé, ou la porte de chêne.
			vec3 vitre = vec3(0.16, 0.19, 0.22) + 0.12 * smoothstep(0.0, hf, c.y);
			float croisee = 1.0 - step(0.05, abs(c.x)) * step(0.05, abs(c.y + hf * 0.25));
			vitre = mix(vitre, vec3(0.9, 0.9, 0.86), croisee * fin);
			if (ouvert < 0.25 && porte < 0.5) {
				float lame = step(0.5, fract(c.y * 9.0)) * fin;
				vitre = v * (0.85 + 0.15 * lame);
			}
			if (porte > 0.5) vitre = vec3(0.40, 0.28, 0.18) * (0.85 + 0.15 * step(0.5, fract(c.x * 3.0)));
			col = vitre;
		}
		if (volet > 0.5 && ouvert >= 0.25 && porte < 0.5) {
			float lame = step(0.5, fract(c.y * 9.0)) * fin;
			col = v * (0.82 + 0.18 * lame);
		}
		// L'appui de pierre.
		col = mix(col, vec3(0.92, 0.9, 0.84), step(abs(c.x), lf + 0.18) * step(abs(c.y + hf + 0.06), 0.06) * (1.0 - porte));
	}
	// De loin, le dessin des fenêtres se fond dans une teinte moyenne, sans moirer.
	float flou = smoothstep(0.25, 0.7, fw);
	if (maillee) flou = smoothstep(0.03, 0.06, fw);
	vec3 moyenne = COLOR.rgb * 0.96;
	// De loin, les fenêtres et leurs volets restent une trame plus sombre : le mur ne devient pas une boîte nue.
	if (dedans) moyenne = mix(moyenne, mix(vec3(0.2, 0.22, 0.25), v, 0.5), 0.6);
	col = mix(col, moyenne, flou);
	// Le soubassement et le bandeau d'égout.
	col *= uv.y < 0.6 ? 0.86 : 1.0;
	col = mix(col, vec3(0.93, 0.9, 0.84), step(hauteur - 0.35, uv.y));
	// L'ombre de contact que peint la planche (le rendu de compatibilité n'a pas d'occlusion ambiante) : sous le
	// débord du toit, sur 0,6 m, et au pied du mur, sur 0,4 m au-dessus du sol.
	float sous_toit = smoothstep(hauteur - 0.95, hauteur - 0.35, uv.y) * (1.0 - step(hauteur - 0.35, uv.y));
	float au_pied = 1.0 - smoothstep(0.4, 0.9, uv.y);
	col *= (1.0 - 0.36 * sous_toit) * (1.0 - 0.3 * au_pied);
	ALBEDO = col;
	ROUGHNESS = 0.9;
}
