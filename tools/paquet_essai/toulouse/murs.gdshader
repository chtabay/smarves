shader_type spatial;
render_mode cull_disabled;
// Les murs des îlots qu'on ne voit que de loin ou en second plan : la brique foraine (alpha du sommet à 1)
// ou l'enduit pâle (alpha à 0), percés de fenêtres à volets par étage. UV : x le long du mur, y la hauteur,
// en mètres ; UV2.x : la hauteur du mur, en mètres, pour la génoise.
uniform vec3 volet = vec3(0.62, 0.67, 0.58);
uniform vec3 pierre = vec3(0.93, 0.89, 0.82);
uniform vec3 vitre = vec3(0.17, 0.2, 0.24);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void fragment() {
	vec2 p = UV;
	float haut = UV2.x;
	vec3 base = COLOR.rgb;
	float brique = COLOR.a;
	vec3 col = base;
	if (brique > 0.5) {
		vec2 b = p / vec2(0.42, 0.075);
		float rang = floor(b.y);
		b.x += mod(rang, 2.0) * 0.5;
		vec2 c = floor(b);
		vec2 g = fract(b);
		float h = hash(c);
		col = base * mix(0.8, 1.12, h);
		col = mix(col, base * 0.62, step(0.86, hash(c + 1.3)) * 0.6);
		float j = smoothstep(0.0, 0.08, min(min(g.x, 1.0 - g.x) * 5.6, min(g.y, 1.0 - g.y)));
		col = mix(vec3(0.86, 0.8, 0.7), col, j);
	} else {
		col = base * mix(0.94, 1.03, hash(floor(p * 3.0)));
	}
	// Les étages : rez-de-chaussée de 4,2 m, puis 3,3 m ; une travée tous les 3 m.
	float trav = fract(p.x / 3.0);
	float idx = floor(p.x / 3.0);
	if (p.y < 4.2) {
		float baie = step(0.18, trav) * step(trav, 0.82) * step(0.25, p.y) * step(p.y, 3.3);
		col = mix(col, vitre * 1.3, baie);
		col = mix(col, pierre * 0.9, step(3.3, p.y) * step(p.y, 3.55));
	} else if (p.y < haut - 0.9) {
		float e = mod(p.y - 4.2, 3.3);
		float f = step(0.38, trav) * step(trav, 0.62) * step(0.75, e) * step(e, 2.55);
		float cadre = step(0.35, trav) * step(trav, 0.65) * step(0.68, e) * step(e, 2.62);
		float vg = step(0.2, trav) * step(trav, 0.36) * step(0.75, e) * step(e, 2.55);
		float vd = step(0.64, trav) * step(trav, 0.8) * step(0.75, e) * step(e, 2.55);
		float ouvert = step(0.4, hash(vec2(idx, floor((p.y - 4.2) / 3.3))));
		col = mix(col, pierre, cadre);
		col = mix(col, vitre, f);
		vec3 v = volet * (0.9 + 0.2 * hash(vec2(idx, 7.0)));
		col = mix(col, v * (1.0 - 0.25 * step(0.5, fract(e * 9.0))), (vg + vd) * ouvert);
		col = mix(col, v, f * (1.0 - ouvert));
	}
	// La génoise : trois rangs de tuiles sous l'égout, une ombre franche dessous.
	float sous = haut - p.y;
	col = mix(col, col * 0.55, smoothstep(0.9, 0.5, sous) * step(0.36, sous));
	col = mix(col, vec3(0.78, 0.42, 0.26) * (0.8 + 0.3 * step(0.5, fract(p.x / 0.16))), step(sous, 0.36));
	ALBEDO = col;
	ROUGHNESS = 0.9;
}
