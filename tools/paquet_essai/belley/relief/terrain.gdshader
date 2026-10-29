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
uniform float roche_pente = 0.72;   // sous ce cos de pente, la roche apparaît
uniform float roche_pleine = 0.55;  // et couvre tout
uniform float loin = 0.0;           // 1 sur les lointains : moins de grain, plus de lavis

const vec3 PRE = vec3(0.56, 0.64, 0.32);
const vec3 PRE_SEC = vec3(0.66, 0.64, 0.38);
const vec3 FORET = vec3(0.20, 0.30, 0.13);
const vec3 FORET_CLAIR = vec3(0.33, 0.44, 0.18);
const vec3 HAIE = vec3(0.27, 0.38, 0.16);
const vec3 VIGNE = vec3(0.60, 0.55, 0.26);
const vec3 VERGER = vec3(0.44, 0.52, 0.24);
const vec3 LANDE = vec3(0.50, 0.50, 0.32);
const vec3 EAU = vec3(0.20, 0.36, 0.38);
const vec3 ROUTE = vec3(0.47, 0.46, 0.44);
const vec3 ROCHE = vec3(0.84, 0.81, 0.72);
const vec3 ROCHE_OMBRE = vec3(0.62, 0.59, 0.52);

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

void fragment() {
	vec2 xz = monde.xz;
	// Le bord des zones tremble un peu, comme une lisière.
	vec2 j = vec2(fbm(xz * 0.05), fbm(xz * 0.05 + 17.0)) - 0.5;
	int c = classe(xz + j * mix(6.0, 40.0, loin));
	// Dans la ville, les rues sont maillées (places/ville.gd) : la couverture n'y dessine que les jardins.
	bool ville = abs(xz.x) < 790.0 && abs(xz.y) < 790.0;
	if (ville && (c == 8 || (c == 0 && length(xz - vec2(150.0, 250.0)) < 420.0))) c = 9;
	float g = fbm(xz * mix(0.35, 0.02, loin));
	float g2 = fbm(xz * mix(0.08, 0.006, loin) + 7.0);
	vec3 col;
	if (c == 1 || c == 2) {
		// La canopée : des houppiers clairs sur un fond sombre.
		float houppier = smoothstep(0.35, 0.75, fbm(xz * mix(0.22, 0.03, loin)));
		col = mix(FORET, FORET_CLAIR, houppier * 0.8 + g2 * 0.3);
		if (c == 2) col = mix(col, PRE, 0.25);
	} else if (c == 3) {
		col = HAIE;
	} else if (c == 4) {
		float rang = 0.5 + 0.5 * sin((xz.x * 0.7 + xz.y * 0.7) * 2.6);
		col = mix(VIGNE * 0.8, VIGNE, rang) * (0.9 + 0.2 * g);
	} else if (c == 5) {
		col = VERGER;
	} else if (c == 6) {
		col = LANDE;
	} else if (c == 7) {
		col = EAU;
	} else if (c == 8) {
		col = ROUTE;
	} else if (c == 9) {
		// Les cours et les jardinets de la ville : gravier clair, herbe par plaques.
		col = mix(vec3(0.72, 0.69, 0.61), PRE, smoothstep(0.45, 0.7, g2)) * (0.93 + 0.12 * g);
	} else {
		col = mix(PRE, PRE_SEC, g2 * 0.9) * (0.92 + 0.16 * g);
	}
	// La roche : là où le versant se redresse, et plus haut, là où la forêt s'éclaircit.
	float pente = normale.y;
	float r = 1.0 - smoothstep(roche_pleine, roche_pente, pente + (g - 0.5) * 0.12);
	if (r > 0.0 && c != 7) {
		// Les bancs calcaires : des strates horizontales, des vires où la forêt s'accroche.
		// Les strates fines s'effacent avec la distance (sinon elles moirent en rayures).
		float pres = 1.0 - smoothstep(600.0, 2500.0, distance(monde, CAMERA_POSITION_WORLD));
		float strate = mix(0.5, 0.5 + 0.5 * sin(monde.y * 0.55 + g * 3.0), pres);
		float vire = smoothstep(0.72, 0.9, 0.5 + 0.5 * sin(monde.y * 0.11 + g2 * 2.0));
		vec3 roche = mix(ROCHE_OMBRE, ROCHE, 0.45 + 0.55 * strate) * (0.92 + 0.14 * g);
		roche = mix(roche, FORET, vire * 0.8);
		col = mix(col, roche, r * ((c == 1 || c == 2) ? 0.85 : 1.0));
	}
	// Les teintes sont écrites en sRGB, comme la palette de la note.
	ALBEDO = pow(col, vec3(2.2));
	ROUGHNESS = 0.95;
}
