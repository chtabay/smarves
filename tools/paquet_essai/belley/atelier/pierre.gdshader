shader_type spatial;
// La pierre de taille de Belley : un calcaire clair en assises réglées, chaque bloc de sa teinte, des joints
// fins et creusés, les arêtes un peu plus claires, le pied des murs plus sombre (le rejaillissement, la
// mousse). Projeté en triplanaire depuis le monde : pas d'UV à poser. La teinte de base vient du sommet ;
// l'alpha du sommet dit la taille des assises (0 : moellons, 1 : grand appareil).
render_mode diffuse_burley;

uniform float assise = 0.42;      // la hauteur d'une assise, en mètres
uniform float bloc = 0.9;         // la longueur moyenne d'un bloc
uniform float joint = 0.018;      // la demi-largeur d'un joint
uniform vec3 joint_couleur : source_color = vec3(0.62, 0.58, 0.50);
instance uniform float sol = 0.0; // le y du pied des murs, pour la salissure (par bâtiment)
uniform float grain_force = 0.05;

varying vec3 monde;
varying vec3 nmonde;

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

// L'appareil sur un plan (u le long du mur, v vers le haut) : la teinte du bloc et la part de joint.
vec2 appareil(vec2 uv, float taille) {
	float a = assise * mix(0.7, 1.15, taille);
	float rang = floor(uv.y / a);
	float decal = h21(vec2(rang, 3.1)) * bloc;
	float l = bloc * mix(0.75, 1.5, h21(vec2(rang, 8.7))) * mix(0.8, 1.3, taille);
	float colonne = floor((uv.x + decal) / l);
	vec2 f = vec2(fract((uv.x + decal) / l) * l, fract(uv.y / a) * a);
	float bord = min(min(f.x, l - f.x), min(f.y, a - f.y));
	float j = 1.0 - smoothstep(joint * 0.6, joint * 1.6, bord);
	return vec2(h21(vec2(colonne, rang)), j);
}

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	nmonde = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(nmonde);
	vec2 uv = n.x > n.z ? monde.zy : monde.xy;
	if (n.y > 0.75) uv = monde.xz;
	vec2 b = appareil(uv, COLOR.a);
	float g = bruit(monde.xy * 9.0 + monde.zz * 7.0) * 0.6 + bruit(monde.zy * 2.3) * 0.4;
	vec3 base = COLOR.rgb;
	vec3 col = base * (0.94 + 0.12 * b.x) * (1.0 - grain_force + grain_force * 2.0 * g);
	// Les coulures de pluie : des traînées verticales, un peu grises, plus marquées en haut des murs.
	float coulure = bruit(vec2((monde.x + monde.z) * 1.7, monde.y * 0.12));
	col *= 1.0 - 0.07 * smoothstep(0.55, 0.85, coulure) * step(n.y, 0.75);
	float flou = smoothstep(0.025, 0.09, max(fwidth(uv.x), fwidth(uv.y)));
	col = mix(col, joint_couleur * base * 1.05, b.y * 0.5 * (1.0 - flou));
	col = mix(col, base * 0.97, flou * 0.8);
	// Le pied des murs : plus sombre sur le premier mètre.
	float pied = 1.0 - smoothstep(0.0, 1.2, monde.y - sol);
	col *= 1.0 - 0.3 * pied;
	ALBEDO = col;
	ROUGHNESS = 0.88;
}
