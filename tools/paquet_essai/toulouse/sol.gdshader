shader_type spatial;
// Les sols de Toulouse, dessinés en coordonnées du monde (une unité du jeu vaut 2,4 m) : les grands pavés carrés
// brun rose de la place (alpha du sommet 1), le filet de pierre blanche qui la borde (alpha 0,5), ou les pavés de
// pierre claire des rues, en rangs décalés (alpha 0). La teinte de
// base vient du sommet ; chaque brique, chaque pavé tire sa nuance.
uniform float unite = 2.4;
varying vec3 monde;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

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
		// Les pavés carrés d'argile de la place, 25 cm, en grille droite, un peu irréguliers (photo de la
		// fontaine, Guillaume, 29 octobre) : chaque pavé légèrement de travers, le joint fin et de même ton.
		vec2 b = p / vec2(0.25, 0.25);
		cellule = floor(b);
		vec2 g = fract(b) + (vec2(hash(cellule + 1.3), hash(cellule + 5.9)) - 0.5) * 0.06;
		joint = min(min(g.x, 1.0 - g.x), min(g.y, 1.0 - g.y)) * mix(0.8, 1.2, hash(cellule + 2.2));
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
		// Les pavés d'argile : une nuance douce d'un pavé à l'autre, et le chiné de la terre cuite dans chacun.
		vec3 t = mix(vec3(1.0), mix(vec3(1.06, 0.99, 0.92), vec3(0.95, 0.92, 0.94), hash(cellule + 9.1)), 0.5);
		float chine = bruit(p * 22.0) * 0.6 + bruit(p * 6.0 + 17.0) * 0.4;
		col = base * mix(0.92, 1.05, h) * t * mix(0.94, 1.05, chine);
	}
	if (filet > 0.5) {
		col = base * mix(0.95, 1.03, h);
	}
	float j = smoothstep(0.0, 0.07, joint);
	if (epi > 0.5) {
		j = smoothstep(0.0, 0.035, joint);
		col = mix(base * 0.84 + vec3(0.03), col, j);
	} else {
		col = mix(base * 0.62 + vec3(0.06), col, j);
	}
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.85, j);
	NORMAL_MAP = vec3(0.5, 0.5, 1.0) + vec3(0.0, (1.0 - j) * 0.25, 0.0);
}
