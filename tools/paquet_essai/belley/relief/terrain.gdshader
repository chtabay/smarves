shader_type spatial;
// Le sol de Belley, du pied du joueur à l'horizon : la couverture réelle (BD TOPO : prés, bois, haies,
// vignes, vergers, eau, routes) donne la teinte ; la pente donne la roche. Les barres calcaires se lisent
// comme sur place : des bandeaux crème, rayés de strates horizontales, là où le versant se redresse, sous la
// forêt qui tient tout le reste. Pas de texture à charger : le grain vient d'un bruit calculé.
render_mode diffuse_burley, specular_disabled;

uniform sampler2D couverture : filter_nearest, repeat_disable;
uniform vec4 cadre = vec4(-1600.0, -2600.0, 8000.0, 2400.0);
uniform sampler2D couverture_loin : filter_nearest, repeat_disable;
uniform vec4 cadre_loin = vec4(-18000.0, -18000.0, 18000.0, 18000.0);
// Les pentes de la crête du Mont du Chat à 25 m (tools/roche_reelle.py --pente), 3 niveaux par degré.
uniform sampler2D pente_crete : filter_linear, repeat_disable;
uniform vec4 cadre_crete = vec4(8000.0, -6000.0, 13000.0, 15000.0);
uniform float seuil_barre = 50.0;
// La profondeur sous la crête (tools/sous_crete.py) : la hauteur qui sépare un point du plus haut à 300 m, un
// mètre par niveau ; sur le proche (relief.png, 15 m) et sur la crête (crete.png, 25 m).
uniform sampler2D sous_crete_proche : filter_linear, repeat_disable;
uniform vec4 cadre_sc_proche = vec4(-1600.0, -2600.0, 8000.0, 2400.0);
uniform sampler2D sous_crete_loin : filter_linear, repeat_disable;
uniform vec4 cadre_sc_loin = vec4(8000.0, -6000.0, 13000.0, 15000.0);
uniform float roche_pente = 0.6;   // sous ce cos de pente, la roche apparaît
uniform float roche_pleine = 0.45;  // et couvre tout
uniform float loin = 0.0;           // 1 sur les lointains : moins de grain, plus de lavis

// Plus verts depuis le verdict n° 25 (les verts du rendu à 86 de saturation contre 161 sur la planche) : vers
// #8FB03A, en gardant la marge du jeu sur l'illustration.
const vec3 PRE = vec3(0.49, 0.61, 0.23);
const vec3 PRE_SEC = vec3(0.60, 0.62, 0.31);
const vec3 FORET = vec3(0.20, 0.30, 0.13);
const vec3 FORET_CLAIR = vec3(0.33, 0.44, 0.18);
const vec3 HAIE = vec3(0.27, 0.38, 0.16);
const vec3 VIGNE = vec3(0.60, 0.55, 0.26);
const vec3 VERGER = vec3(0.44, 0.52, 0.24);
const vec3 LANDE = vec3(0.50, 0.50, 0.32);
// Un vert d'eau profond (visé #4E7A78 au rendu, verdict n° 32) : le bleu clair sortait en aplat, identique au ciel.
const vec3 EAU = vec3(0.19, 0.31, 0.31);
const vec3 CIEL_REFLET = vec3(0.44, 0.57, 0.64);
const vec3 ROUTE = vec3(0.53, 0.50, 0.47);
// Plus sourdes depuis le verdict n° 25 : les barres sortaient en taches blanches sur les crêtes de la vue d'ensemble.
const vec3 ROCHE = vec3(0.54, 0.53, 0.49);
const vec3 ROCHE_OMBRE = vec3(0.40, 0.40, 0.38);
const vec3 ROCHE_LOIN = vec3(0.55, 0.53, 0.47);
const vec3 OMBRE_BORD = vec3(0.43, 0.42, 0.37);  // le trait d'ombre sous le bord haut de la barre

varying vec3 monde;
varying vec3 normale;

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

int classe(vec2 xz) {
	vec2 uv = (xz - cadre.xy) / (cadre.zw - cadre.xy);
	if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
		return int(texture(couverture, uv).r * 255.0 + 0.5);
	}
	vec2 uvl = (xz - cadre_loin.xy) / (cadre_loin.zw - cadre_loin.xy);
	return int(texture(couverture_loin, uvl).r * 255.0 + 0.5);
}

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	normale = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Les bancs calcaires : des strates horizontales, des vires où la forêt s'accroche ; les strates fines
// s'effacent avec la distance (sinon elles moirent en rayures).
// Sur le Mont du Chat, la barre se lit d'abord par ses couloirs : des traînées verticales, grises et ocre, que
// l'eau a lavées ; les strates n'y sont qu'un fil, et les vires portent des buis et des pins.
vec3 roche(vec2 xz, float y, float g, float g2, float pres, float pr) {
	float h = dot(xz, vec2(0.71, 0.71));
	float couloir = fbm(vec2(h * 0.09, y * 0.012));
	float lave = smoothstep(0.35, 0.7, fbm(vec2(h * 0.03 + 5.0, y * 0.006)));
	float strate = mix(0.5, 0.5 + 0.5 * sin(y * 0.45 + g * 2.0), pres * 0.5);
	float vire = smoothstep(0.85, 0.95, 0.5 + 0.5 * sin(y * 0.09 + g2 * 2.5)) * pres;
	vec3 r = mix(ROCHE_OMBRE, ROCHE, 0.3 + 0.5 * couloir + 0.2 * strate);
	r = mix(r, r * vec3(1.04, 0.97, 0.86), lave * 0.6);
	// Les buis et les pins accrochés à la barre : des touffes sombres, plus serrées en pied de paroi.
	float touffe = smoothstep(0.55, 0.7, fbm(vec2(h * 0.06, y * 0.05) + 11.0));
	r = mix(r, FORET, max(vire * 0.55, touffe * 0.7));
	// De loin, comme sur la planche, la barre est un bandeau crème qui suit les courbes de niveau : des bancs
	// horizontaux clairs, séparés de vires plus sombres où s'accroche la forêt ; plus de traînées verticales.
	float banc = fbm(vec2(h * 0.004, y * 0.07) + 21.0);
	float vire_loin = smoothstep(0.7, 0.85, 0.5 + 0.5 * sin(y * 0.11 + banc * 4.0));
	vec3 bandeau = mix(ROCHE_LOIN, ROCHE_LOIN * vec3(0.86, 0.85, 0.82), smoothstep(0.35, 0.65, banc));
	bandeau = mix(bandeau, mix(bandeau, FORET * 1.3, 0.6), vire_loin * 0.5);
	// Les couloirs verticaux que l'eau a lavés : des traînées sombres qui font la paroi, par contraste.
	float couloir_loin = smoothstep(0.66, 0.72, fbm(vec2(h * 0.07 + fbm(vec2(h * 0.01, y * 0.02)) * 3.0, y * 0.006) + 41.0));
	bandeau = mix(bandeau, ROCHE_OMBRE * 0.85, couloir_loin * 0.55);
	// Les couloirs gris ne se lisent qu'au pied de la barre (moins de 300 m) ; au-delà, le bandeau crème.
	return mix(bandeau, r, pr);
}

// Les cours et les jardins de la ville, et les prés pris dans le bourg : un parcellaire de jardins de 10 à
// 18 m, chacun pelouse, potager à planches ou cour de gravier blond, bordés de haies sombres et de murets clairs ;
// vus d'en haut, des jardins comme sur la planche, pas des aplats de terrain vague (verdict n° 3).
vec3 jardins(vec2 xz, float g) {
	// Le parcellaire n'est pas une grille : les lanières suivent la rue, chacune de sa profondeur (7 à 13 m), et
	// se recoupent en jardins de 6 à 16 m ; un bruit tord les limites d'un bon mètre (verdict n° 10 : le damier).
	vec2 w = vec2(fbm(xz * 0.08 + 2.0), fbm(xz * 0.08 + 19.0)) - 0.5;
	float a = 0.52 + (fbm(xz * 0.004) - 0.5) * 0.6;
	vec2 q = mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a))) * xz + w * 3.0;
	float rangee = floor(q.y / 10.0);
	float prof = mix(7.0, 13.0, h21(vec2(rangee, 4.1)));
	float y0 = rangee * 10.0;
	float fy = q.y - y0;
	if (fy > prof) { rangee += 0.5; fy -= prof; prof = 10.0 - prof; }
	float long_ = mix(6.0, 12.0, h21(vec2(rangee, 8.3)));
	float xq = q.x + h21(vec2(rangee, 2.7)) * long_;
	vec2 cel = vec2(floor(xq / long_), rangee);
	vec2 f = vec2(xq - cel.x * long_, fy);
	vec2 taille = vec2(long_, prof);
	float h = h21(cel);
	// La pelouse des jardins vers #5F9A30 (verdict n° 25).
	vec3 pelouse = mix(vec3(0.40, 0.56, 0.24), vec3(0.37, 0.53, 0.22), h21(cel + 3.1)) * (0.93 + 0.12 * fbm(xz * 0.4));
	vec3 potager = mix(vec3(0.48, 0.41, 0.31), vec3(0.37, 0.47, 0.26), smoothstep(0.35, 0.65, fract(f.y / 1.3)));
	vec3 gravier = vec3(0.70, 0.65, 0.55) * (0.95 + 0.08 * fbm(xz * 2.0));
	// Le verger : des fruitiers à peu près alignés, chacun de sa taille.
	vec2 qa = f / 3.2;
	vec2 ia = floor(qa);
	vec2 ca = ia + 0.5 + (vec2(h21(ia + cel), h21(ia + cel + 7.7)) - 0.5) * 0.5;
	float ra = mix(0.25, 0.42, h21(ia + cel + 3.3));
	// Les fruitiers sont en volume (places/jardins.gd) : au sol, seulement l'herbe plus drue du verger.
	vec3 verger = pelouse * vec3(0.92, 0.96, 0.9);
	vec3 col = h < 0.34 ? pelouse : (h < 0.56 ? potager : (h < 0.63 ? gravier : verger));
	// Des massifs et des arbustes en fond de jardin, contre la haie.
	float massif = smoothstep(0.6, 0.72, fbm(xz * 0.3 + 7.0)) * (1.0 - smoothstep(1.5, 3.5, f.y));
	col = mix(col, col * 0.85, massif * 0.5);
	// La limite : une haie sur certains côtés seulement, d'épaisseur variable, ou un simple changement d'herbe.
	float e = mix(0.5, 1.2, fbm(xz * 0.3 + 11.0));
	float bx = min(f.x, taille.x - f.x);
	float by = min(f.y, taille.y - f.y);
	float haie = max((1.0 - smoothstep(e, e + 0.3, bx)) * step(0.4, h21(cel + 9.0)), (1.0 - smoothstep(e, e + 0.3, by)) * step(0.3, h21(cel + 12.0)));
	col = mix(col, col * 0.7, (1.0 - smoothstep(e + 0.3, e + 1.6, f.y)) * 0.7);
	// Les limites sont en volume (places/jardins.gd) : au sol, seulement un liseré d'herbe plus sombre.
	col = mix(col, col * 0.85, haie * 0.5);
	col = mix(col, vec3(dot(col, vec3(0.33))) * vec3(1.02, 1.0, 0.92), 0.22);
	return col * (0.95 + 0.08 * g);
}

// La profondeur sous la crête, en mètres (999 hors des cartes).
float sous_crete(vec2 xz) {
	vec2 u = (xz - cadre_sc_proche.xy) / (cadre_sc_proche.zw - cadre_sc_proche.xy);
	if (u.x >= 0.0 && u.y >= 0.0 && u.x <= 1.0 && u.y <= 1.0) return texture(sous_crete_proche, u).r * 255.0;
	u = (xz - cadre_sc_loin.xy) / (cadre_sc_loin.zw - cadre_sc_loin.xy);
	if (u.x >= 0.0 && u.y >= 0.0 && u.x <= 1.0 && u.y <= 1.0) return texture(sous_crete_loin, u).r * 255.0;
	return 999.0;
}

// La barre de la rive savoyarde, collée à la crête : de 60 m sous le haut du versant (un bord net, 2 à 4 m) à
// 120 m (un pied effiloché), découpée par la forêt (verdict n° 9).
float barre(vec2 xz, float d) {
	float n = fbm(xz * 0.02 + 5.0) - 0.5;
	float haut = smoothstep(57.0, 60.0, d + n * 6.0);
	float pied = 1.0 - smoothstep(76.0, 79.0, d + (fbm(xz * 0.06 + 13.0) - 0.5) * 16.0);
	return haut * pied * smoothstep(0.405, 0.415, fbm(xz * 0.012 + 31.0) + (fbm(xz * 0.08 + 3.0) - 0.5) * 0.03);
}

vec3 teinte(int c, vec2 xz, float y, float g, float g2, float pres, float pr) {
	if (c == 1 || c == 2) {
		// La canopée : des houppiers clairs sur un fond sombre.
		float houppier = smoothstep(0.35, 0.75, fbm(xz * mix(0.22, 0.03, loin)));
		vec3 col = mix(FORET, FORET_CLAIR, houppier * 0.8 + g2 * 0.3);
		return c == 2 ? mix(col, PRE, 0.25) : col;
	} else if (c == 3) {
		return HAIE;
	} else if (c == 4) {
		float rang = 0.5 + 0.5 * sin((xz.x * 0.7 + xz.y * 0.7) * 2.6);
		return mix(VIGNE * 0.8, VIGNE, mix(0.5, rang, pres)) * (0.9 + 0.2 * g);
	} else if (c == 5) {
		return VERGER;
	} else if (c == 6) {
		return LANDE;
	} else if (c == 7) {
		return EAU;
	} else if (c == 8) {
		return ROUTE;
	} else if (c == 9 || (c == 0 && length(xz) < 650.0)) {
		return jardins(xz, g);
	} else if (c == 10) {
		// La roche relevée sur le relief réel (tools/roche_reelle.py).
		return roche(xz, y, g, g2, pres, pr);
	}
	// Un pré plus sourd et moins uni : vu de haut, la nappe claire levait la médiane du relais (verdict n° 28).
	// Par parcelles (verdict n° 31, la recette du banc) : chaque champ d'une centaine de mètres a son état, fauché
	// en paille, regain plus sombre ou pré ; dedans, des taches blondes lentes.
	vec2 r = mat2(vec2(0.94, 0.34), vec2(-0.34, 0.94)) * xz;
	float champ = h21(floor(r / vec2(120.0, 85.0)));
	vec3 pre = mix(PRE, PRE_SEC, g2 * 0.9);
	pre = mix(pre, vec3(0.60, 0.58, 0.34), step(0.74, champ) * 0.85);
	pre = mix(pre, PRE * 0.82, step(champ, 0.22));
	pre = mix(pre, vec3(0.58, 0.57, 0.33), smoothstep(0.55, 0.75, fbm(xz * 0.03 + 21.0)) * 0.45);
	return pre * (0.86 + 0.26 * g);
}

void fragment() {
	vec2 xz = monde.xz;
	float g = fbm(xz * mix(0.35, 0.02, loin));
	float g2 = fbm(xz * mix(0.08, 0.006, loin) + 7.0);
	float pres = 1.0 - smoothstep(600.0, 2500.0, distance(monde, CAMERA_POSITION_WORLD));
	float pr = 1.0 - smoothstep(150.0, 450.0, distance(monde, CAMERA_POSITION_WORLD));
	float dsc = sous_crete(xz);
	float roc = 0.0;
	vec3 col;
	float eau = 0.0;
	vec2 uv = (xz - cadre.xy) / (cadre.zw - cadre.xy);
	if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
		// Le proche : une classe par point, le bord des zones tremble un peu, comme une lisière.
		vec2 j = vec2(fbm(xz * 0.05), fbm(xz * 0.05 + 17.0)) - 0.5;
		// Le relevé est à 5 m : on déplace la lecture de deux à trois cases par un bruit à deux échelles, pour que les
		// lisières ne fassent plus de marches d'escalier sur les versants (verdict n° 10).
		vec2 j2 = vec2(fbm(xz * 0.17 + 3.0), fbm(xz * 0.17 + 29.0)) - 0.5;
		int c = classe(xz + j * 18.0 + j2 * 7.0);
		// Dans la ville, les rues sont maillées (places/ville.gd) : la couverture n'y dessine que les jardins.
		bool ville = abs(xz.x) < 790.0 && abs(xz.y) < 790.0;
		// Les prés, les bosquets, les vergers et les landes pris dans le bourg sont des jardins, pas un parc (verdict n° 11).
		if (ville && (c == 8 || ((c == 0 || c == 2 || c == 5 || c == 6) && length(xz - vec2(150.0, 250.0)) < 420.0))) c = 9;
		// Hors de la ville, les routes sont des rubans (places/routes.gd) : sous elles, l'herbe des bas-côtés.
		if (!ville && c == 8) c = 0;
		col = teinte(c, xz, monde.y, g, g2, pres, pr);
		if (c == 10 && xz.x > 7300.0) {
			// La roche relevée de la rive savoyarde : collée à la crête, découpée par la forêt (verdict n° 9).
			float m = barre(xz, dsc);
			roc = max(roc, m);
			col = mix(teinte(1, xz, monde.y, g, g2, pres, pr), col, m);
		}
		// La roche relevée de ce côté-ci (le Molard, les côtes au-dessus du bourg) : comptée comme roche, pour que
		// les lointains la fondent (verdict n° 25 : les taches blanches de la vue d'ensemble étaient elle).
		if (c == 10 && xz.x <= 7300.0) roc = max(roc, 1.0);
		eau = c == 7 ? 1.0 : 0.0;
	} else {
		// Le lointain : les teintes des quatre cases voisines, fondues (la carte a 37,5 m au pas).
		vec2 taille = vec2(textureSize(couverture_loin, 0));
		vec2 f = (xz - cadre_loin.xy) / (cadre_loin.zw - cadre_loin.xy) * taille - 0.5;
		vec2 i0 = floor(f);
		vec2 t = f - i0;
		vec3 acc[4];
		float rw = 0.0;
		for (int k = 0; k < 4; k++) {
			vec2 o = vec2(float(k % 2), float(k / 2));
			int c = int(texelFetch(couverture_loin, ivec2(clamp(i0 + o, vec2(0.0), taille - 1.0)), 0).r * 255.0 + 0.5);
			if (c == 8) c = 0;
			// La roche n'est pas fondue avec ses voisines : elle a un bord net, posé plus bas.
			float wk = (k % 2 == 0 ? 1.0 - t.x : t.x) * (k / 2 == 0 ? 1.0 - t.y : t.y);
			if (c == 10) {
				rw += wk;
				c = 1;
			}
			acc[k] = teinte(c, xz, monde.y, g, g2, pres, pr);
			float e = c == 7 ? 1.0 : 0.0;
			eau += e * (k % 2 == 0 ? 1.0 - t.x : t.x) * (k / 2 == 0 ? 1.0 - t.y : t.y);
		}
		col = mix(mix(acc[0], acc[1], t.x), mix(acc[2], acc[3], t.x), t.y);
		float bord = (fbm(xz * 0.03 + 3.0) - 0.5) + (fbm(xz * 0.11 + 9.0) - 0.5) * 0.8;
		// Sur la crête, la barre suit la pente relevée à 25 m, au fil des courbes : un bandeau, pas des cases.
		vec2 uc = (xz - cadre_crete.xy) / (cadre_crete.zw - cadre_crete.xy);
		if (uc.x >= 0.0 && uc.y >= 0.0 && uc.x <= 1.0 && uc.y <= 1.0) {
			float pente = texture(pente_crete, uc).r * 255.0 / 3.0;
			rw = smoothstep(seuil_barre - 2.0, seuil_barre + 2.0, pente + bord * 8.0);
		}
		// La barre ne couronne que le haut du versant, et la forêt la découpe en tronçons (verdict n° 9).
		if (dsc < 900.0) rw *= barre(xz, dsc);
		// Hors des cartes de crête (le Colombier, les lointains), la roche se fond à moitié dans la forêt : plus de
		// taches blanches sur les crêtes lointaines (verdict n° 11).
		else rw *= 0.55;
		// Et seulement là où le maillage se redresse : la barre suit les courbes du versant, pas les cases.
		float raide = 1.0 - smoothstep(0.78, 0.84, normale.y + bord * 0.15);
		float wr = smoothstep(0.47, 0.5, rw * raide + bord * 0.3);
		roc = max(roc, wr);
		col = mix(col, roche(xz, monde.y, g, g2, pres, pr), wr);
	}
	// Là où le maillage lui-même se redresse (une barre plus raide que la carte), la roche affleure aussi.
	float r = 1.0 - smoothstep(roche_pleine, roche_pente, normale.y + (g - 0.5) * 0.12);
	// Sur la rive savoyarde, comme la barre relevée : en haut du versant seulement, découpée par la forêt
	// (verdicts n° 5 et 6) ; le talus raide du bord du Rhône reste boisé. Les falaises du Bugey ne changent pas.
	if (xz.x > 7300.0) r = smoothstep(0.45, 0.55, r) * barre(xz, dsc);
	col = mix(col, roche(xz, monde.y, g, g2, pres, pr), r * 0.8);
	// Sur la rive savoyarde, le trait d'ombre sous le bord haut, et la face tournée contre le soleil plus sombre
	// que la forêt : c'est le contraste qui fait la paroi, pas la blancheur.
	if (xz.x > 7300.0) {
		roc = max(roc, r);
		// Les éboulis au pied de la barre : un cône de pierraille grise, moucheté, qui mord sur la forêt.
		float pierraille = smoothstep(74.0, 80.0, dsc) * (1.0 - smoothstep(84.0, 98.0, dsc + (fbm(xz * 0.05 + 7.0) - 0.5) * 20.0));
		pierraille *= smoothstep(0.405, 0.415, fbm(xz * 0.012 + 31.0) + (fbm(xz * 0.08 + 3.0) - 0.5) * 0.03) * step(0.45, h21(floor(xz * 0.6)));
		col = mix(col, mix(ROCHE, ROCHE_OMBRE, h21(floor(xz * 0.6) + 1.7)), pierraille * 0.55 * (1.0 - smoothstep(0.85, 0.95, normale.y)));
		float trait = smoothstep(57.0, 59.0, dsc) * (1.0 - smoothstep(61.0, 65.0, dsc));
		col = mix(col, OMBRE_BORD, roc * trait * 0.85);
		float contre = 1.0 - smoothstep(-0.1, 0.35, dot(normale, normalize(vec3(-0.75, 0.47, 0.47))));
		col = mix(col, col * 0.55, roc * contre);
		// Une face sur deux à l'ombre, au gris de la planche (#A9A391 au rendu).
		col = mix(col, vec3(0.40, 0.39, 0.35), roc * smoothstep(0.42, 0.5, fbm(xz * 0.01 + 51.0)));
	}
	// Au-delà de 500 m, les barres des collines voisines sortaient en taches blanches sur le pré (verdicts n° 21
	// à 25) : elles s'y fondent dans le vert gris du versant. Pas sur la rive savoyarde, dont
	// les falaises sont le sujet de la vue du relais.
	float mi_loin = smoothstep(500.0, 2500.0, distance(monde, CAMERA_POSITION_WORLD));
	col = mix(col, vec3(0.44, 0.49, 0.37), roc * mi_loin * 0.75 * (1.0 - step(7300.0, xz.x)));
	// Sous 500 m, les classes de roche du relevé ne sont que des aplats gris sans arête sur le versant (verdict
	// n° 33) : elles s'effacent sous le pré. Pas sur la rive savoyarde, dont les falaises sont un sujet.
	float pres_roc = roc * (1.0 - smoothstep(350.0, 600.0, distance(monde, CAMERA_POSITION_WORLD))) * (1.0 - step(7300.0, xz.x));
	col = mix(col, mix(PRE, PRE_SEC, g2 * 0.9) * (0.86 + 0.26 * g), pres_roc);
	// Dès 800 m, le pré perd son vert lumineux (visée #7FA050 au rendu, verdict n° 29) : moins saturé, un peu plus
	// sombre, avant que la brume de 2 km ne le bleuisse.
	float moyen = smoothstep(500.0, 1300.0, distance(monde, CAMERA_POSITION_WORLD)) * (1.0 - eau);
	col = mix(col, mix(vec3(dot(col, vec3(0.3, 0.59, 0.11))), col, 0.6) * 0.9, moyen);
	// L'eau prend le ciel, d'autant plus qu'on la voit en rasant ; des rides plus claires la parcourent.
	float rasant = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float ride = smoothstep(0.62, 0.8, fbm(vec2(xz.x * 0.08, xz.y * 0.5))) * pres;
	// Le ciel s'y reflète en bandes, le long des rides, plus qu'en nappe.
	col = mix(col, CIEL_REFLET, eau * clamp(0.08 + 0.35 * rasant * smoothstep(0.3, 0.7, fbm(vec2(xz.x * 0.02, xz.y * 0.15))) + 0.3 * ride, 0.0, 0.6));
	// La perspective atmosphérique de la note : les lointains passent au bleu gris, en trois plans.
	float k = 1.0 - exp(-distance(monde, CAMERA_POSITION_WORLD) / 9000.0);
	col = mix(col, vec3(0.50, 0.57, 0.60), k * 0.7);
	// Au-delà de 8 km, la brume noie encore les barres claires : plus de taches blanches sur la crête lointaine.
	// Bleu-gris, pas blanc : la Dent du Chat sortait en névé depuis le banc (revue finale n° 1, visée #93A6AE).
	// Les lointains passent au bleu-gris de la planche (#93A6AE) dès 2 km : la crête du Chat, vue du banc, restait verte (verdict n° 28).
	col = mix(col, vec3(0.38, 0.45, 0.50), smoothstep(1500.0, 8000.0, distance(monde, CAMERA_POSITION_WORLD)) * (0.85 + 0.1 * roc));
	// Au-delà de 5 km, un cran plus sombre : l'arête de la crête du Chat au soleil sortait pâle (#C2D2D3, verdict n° 30).
	col *= mix(1.0, 0.84, smoothstep(5000.0, 10000.0, distance(monde, CAMERA_POSITION_WORLD)));
	// Les teintes sont écrites en sRGB, comme la palette de la note ; le rendu de compatibilité ne convertit pas
	// sa sortie (mesuré : un albédo de 0,5 ressort à 0,5), on les lui donne donc telles quelles.
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
