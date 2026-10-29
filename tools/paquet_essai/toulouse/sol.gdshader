shader_type spatial;
// Les sols de Toulouse, dessinés en coordonnées du monde (une unité du jeu vaut 2,4 m) : la brique de place
// posée en épi (motif 1), ou les pavés de pierre claire des rues, en rangs décalés (motif 0). La teinte de
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
	float epi = step(0.5, COLOR.a);
	vec3 col;
	float joint;
	vec2 cellule;
	if (epi > 0.5) {
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
	float j = smoothstep(0.0, 0.07, joint);
	col = mix(base * 0.62 + vec3(0.06), col, j);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.85, j);
	NORMAL_MAP = vec3(0.5, 0.5, 1.0) + vec3(0.0, (1.0 - j) * 0.25, 0.0);
}
