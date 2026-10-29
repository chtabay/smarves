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
uniform float seuil_barre = 42.0;
uniform float roche_pente = 0.6;   // sous ce cos de pente, la roche apparaît
uniform float roche_pleine = 0.45;  // et couvre tout
uniform float loin = 0.0;           // 1 sur les lointains : moins de grain, plus de lavis

const vec3 PRE = vec3(0.49, 0.58, 0.29);
const vec3 PRE_SEC = vec3(0.59, 0.58, 0.34);
const vec3 FORET = vec3(0.20, 0.30, 0.13);
const vec3 FORET_CLAIR = vec3(0.33, 0.44, 0.18);
const vec3 HAIE = vec3(0.27, 0.38, 0.16);
const vec3 VIGNE = vec3(0.60, 0.55, 0.26);
const vec3 VERGER = vec3(0.44, 0.52, 0.24);
const vec3 LANDE = vec3(0.50, 0.50, 0.32);
const vec3 EAU = vec3(0.30, 0.44, 0.52);
const vec3 CIEL_REFLET = vec3(0.50, 0.63, 0.74);
const vec3 ROUTE = vec3(0.47, 0.46, 0.44);
const vec3 ROCHE = vec3(0.60, 0.59, 0.55);
const vec3 ROCHE_OMBRE = vec3(0.40, 0.40, 0.38);

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
vec3 roche(vec2 xz, float y, float g, float g2, float pres) {
	float h = dot(xz, vec2(0.71, 0.71));
	float couloir = fbm(vec2(h * 0.09, y * 0.012));
	float lave = smoothstep(0.35, 0.7, fbm(vec2(h * 0.03 + 5.0, y * 0.006)));
	float strate = mix(0.5, 0.5 + 0.5 * sin(y * 0.45 + g * 2.0), pres * 0.5);
	float vire = smoothstep(0.85, 0.95, 0.5 + 0.5 * sin(y * 0.09 + g2 * 2.5)) * pres;
	vec3 r = mix(ROCHE_OMBRE, ROCHE, 0.3 + 0.5 * couloir + 0.2 * strate);
	r = mix(r, r * vec3(1.04, 0.97, 0.86), lave * 0.6);
	// Les buis et les pins accrochés à la barre : des touffes sombres, plus serrées en pied de paroi.
	float touffe = smoothstep(0.55, 0.7, fbm(vec2(h * 0.06, y * 0.05) + 11.0));
	return mix(r, FORET, max(vire * 0.55, touffe * 0.7));
}

vec3 teinte(int c, vec2 xz, float y, float g, float g2, float pres) {
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
	} else if (c == 9) {
		// Les cours et les jardinets de la ville : surtout des pelouses et des potagers, une cour de gravier blond
		// par endroits ; vus d'en haut, des jardins, comme sur la planche, pas un terrain vague.
		vec3 gravier = vec3(0.78, 0.72, 0.60);
		vec3 jardin = mix(vec3(0.50, 0.62, 0.30), vec3(0.42, 0.55, 0.26), smoothstep(0.4, 0.7, fbm(xz * 0.2 + 5.0)));
		return mix(gravier, jardin, smoothstep(0.32, 0.42, g2)) * (0.93 + 0.12 * g);
	} else if (c == 10) {
		// La roche relevée sur le relief réel (tools/roche_reelle.py).
		return roche(xz, y, g, g2, pres);
	}
	return mix(PRE, PRE_SEC, g2 * 0.9) * (0.92 + 0.16 * g);
}

void fragment() {
	vec2 xz = monde.xz;
	float g = fbm(xz * mix(0.35, 0.02, loin));
	float g2 = fbm(xz * mix(0.08, 0.006, loin) + 7.0);
	float pres = 1.0 - smoothstep(600.0, 2500.0, distance(monde, CAMERA_POSITION_WORLD));
	vec3 col;
	float eau = 0.0;
	vec2 uv = (xz - cadre.xy) / (cadre.zw - cadre.xy);
	if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0) {
		// Le proche : une classe par point, le bord des zones tremble un peu, comme une lisière.
		vec2 j = vec2(fbm(xz * 0.05), fbm(xz * 0.05 + 17.0)) - 0.5;
		int c = classe(xz + j * 6.0);
		// Dans la ville, les rues sont maillées (places/ville.gd) : la couverture n'y dessine que les jardins.
		bool ville = abs(xz.x) < 790.0 && abs(xz.y) < 790.0;
		if (ville && (c == 8 || (c == 0 && length(xz - vec2(150.0, 250.0)) < 420.0))) c = 9;
		// Hors de la ville, les routes sont des rubans (places/routes.gd) : sous elles, l'herbe des bas-côtés.
		if (!ville && c == 8) c = 0;
		col = teinte(c, xz, monde.y, g, g2, pres);
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
			acc[k] = teinte(c, xz, monde.y, g, g2, pres);
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
		// Et seulement là où le maillage se redresse : la barre suit les courbes du versant, pas les cases.
		float raide = 1.0 - smoothstep(0.72, 0.9, normale.y + bord * 0.15);
		col = mix(col, roche(xz, monde.y, g, g2, pres), smoothstep(0.42, 0.5, rw * raide + bord * 0.3));
	}
	// Là où le maillage lui-même se redresse (une barre plus raide que la carte), la roche affleure aussi.
	float r = 1.0 - smoothstep(roche_pleine, roche_pente, normale.y + (g - 0.5) * 0.12);
	col = mix(col, roche(xz, monde.y, g, g2, pres), r * 0.8);
	// L'eau prend le ciel, d'autant plus qu'on la voit en rasant ; des rides plus claires la parcourent.
	float rasant = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	float ride = smoothstep(0.62, 0.8, fbm(vec2(xz.x * 0.08, xz.y * 0.5))) * pres;
	col = mix(col, CIEL_REFLET, eau * clamp(0.25 + 0.6 * rasant + 0.25 * ride, 0.0, 0.85));
	// La perspective atmosphérique de la note : les lointains passent au bleu gris, en trois plans.
	float k = 1.0 - exp(-distance(monde, CAMERA_POSITION_WORLD) / 9000.0);
	col = mix(col, vec3(0.58, 0.65, 0.68), k * 0.7);
	// Les teintes sont écrites en sRGB, comme la palette de la note ; le rendu de compatibilité ne convertit pas
	// sa sortie (mesuré : un albédo de 0,5 ressort à 0,5), on les lui donne donc telles quelles.
	ALBEDO = col;
	ROUGHNESS = 0.95;
}
