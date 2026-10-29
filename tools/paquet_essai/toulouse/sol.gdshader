shader_type spatial;
// Les sols de Toulouse, dessinés en coordonnées du monde (une unité du jeu vaut 2,4 m) : les grands pavés carrés
// brun rose de la place (alpha du sommet 1), le filet de pierre blanche qui la borde (alpha 0,5), ou les pavés de
// pierre claire des rues, en rangs décalés (alpha 0). La teinte de
// base vient du sommet ; chaque brique, chaque pavé tire sa nuance.
uniform float unite = 2.4;
varying vec3 monde;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz * unite;
}

void fragment() {
	vec2 p = monde.xz;
	vec3 base = COLOR.rgb;
	float epi = step(0.75, COLOR.a);
	float filet = step(0.25, COLOR.a) * (1.0 - epi);
	vec3 col;
	float joint;
	vec2 cellule;
	if (filet > 0.5) {
		// Le filet de pierre blanche qui borde la place.
		vec2 b = p / vec2(0.6, 0.3);
		cellule = floor(b);
		vec2 g = fract(b);
		joint = min(min(g.x, 1.0 - g.x) * 2.0, min(g.y, 1.0 - g.y));
	} else if (epi > 0.5) {
		// Les grands pavés carrés de la place, 26 cm, en rangs droits décalés d'un demi-pavé (image cible de
		// Guillaume, 29 octobre).
		vec2 b = p / vec2(0.26, 0.26);
		float rang = floor(b.y);
		b.x += mod(rang, 2.0) * 0.5;
		cellule = floor(b);
		vec2 g = fract(b);
		joint = min(min(g.x, 1.0 - g.x), min(g.y, 1.0 - g.y));
	} else if (false) {
		// L'épi : des briques de 22 × 5,5 cm, alternées à 90° par blocs, tournées de 45°.
		vec2 q = mat2(vec2(0.7071, -0.7071), vec2(0.7071, 0.7071)) * p;
		vec2 b = q / vec2(0.22, 0.22);
		vec2 bloc = floor(b);
		float sens = mod(bloc.x + bloc.y, 2.0);
		vec2 f = fract(b);
		if (sens > 0.5) f = f.yx;
		float rang = floor(f.y * 4.0);
		vec2 g = vec2(f.x, fract(f.y * 4.0));
		cellule = bloc * 7.0 + vec2(rang, sens);
		joint = min(min(g.x, 1.0 - g.x) * 4.0, min(g.y, 1.0 - g.y)) ;
	} else {
		// Les pavés : 30 × 18 cm, rangs décalés d'un demi-pavé.
		vec2 b = p / vec2(0.30, 0.18);
		float rang = floor(b.y);
		b.x += mod(rang, 2.0) * 0.5;
		cellule = floor(b);
		vec2 g = fract(b);
		joint = min(min(g.x, 1.0 - g.x) * 1.66, min(g.y, 1.0 - g.y));
	}
	float h = hash(cellule);
	col = base * mix(0.82, 1.12, h) * mix(vec3(1.0), vec3(1.05, 0.95, 0.9), hash(cellule + 3.7));
	if (epi > 0.5) {
		// Les pavés de la place : brun rose, ocre et brique mêlés, chacun sa nuance.
		vec3 t = mix(vec3(1.0), mix(vec3(1.12, 0.98, 0.82), vec3(0.88, 0.8, 0.82), hash(cellule + 9.1)), 0.7);
		col = base * mix(0.74, 1.16, h) * t;
	}
	if (filet > 0.5) {
		col = base * mix(0.95, 1.03, h);
	}
	float j = smoothstep(0.0, 0.07, joint);
	col = mix(base * 0.62 + vec3(0.06), col, j);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.85, j);
	NORMAL_MAP = vec3(0.5, 0.5, 1.0) + vec3(0.0, (1.0 - j) * 0.25, 0.0);
}
