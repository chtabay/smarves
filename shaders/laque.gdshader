shader_type spatial;
// La laque des véhicules (scripts/socle/carrosserie.gd) : une peinture vernie qui reflète une rue de nuit
// simulée (sol sombre, ligne chaude des vitrines et des réverbères à l'horizon, ciel bleu nuit, une lueur
// de lune), pour briller pareil avec tous les rendus, y compris le web et les téléphones, sans sonde de
// reflets. En bord de forme, la teinte tourne vers `reflet` (le chatoiement) ; des paillettes s'allument
// selon l'angle de vue. `metal` à 1 en fait un chrome (teinte blanche) ou un or (teinte dorée).
// Sous `coupe_y` (en hauteur dans le repère du véhicule), la caisse prend `teinte_bas` : la livrée deux tons.

uniform vec4 teinte : source_color = vec4(0.02, 0.02, 0.03, 1.0);
uniform vec4 teinte_bas : source_color = vec4(0.02, 0.02, 0.03, 1.0);
uniform float coupe_y = -100.0;
uniform vec4 reflet : source_color = vec4(0.9, 0.62, 0.32, 1.0);
uniform float chatoiement = 0.35;
uniform float vernis = 0.8;
uniform float paillettes = 0.0;
uniform vec4 paillette_teinte : source_color = vec4(1.0, 0.82, 0.5, 1.0);
uniform float metal = 0.0;
uniform float rugosite = 0.22;
uniform float lumiere = 0.0;

varying vec3 lpos;
varying vec3 wpos;

void vertex() {
	lpos = VERTEX;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash3(vec3 p) {
	return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453);
}

// La rue de nuit que la laque reflète, vue dans la direction r (repère du monde).
vec3 rue(vec3 r) {
	float y = r.y;
	vec3 c = mix(vec3(0.09, 0.06, 0.07), vec3(0.07, 0.09, 0.24), smoothstep(-0.2, 0.3, y));
	float az = atan(r.x, r.z);
	float vitrines = 0.5 + 0.5 * sin(az * 5.0 + 1.3) * sin(az * 3.0 - 0.4);
	float horizon = exp(-pow((y - 0.03) / 0.075, 2.0));
	c += vec3(1.0, 0.6, 0.28) * horizon * (0.35 + 1.1 * vitrines * vitrines);
	// Un liseré clair plus haut : le bord des toits contre le ciel.
	c += vec3(0.25, 0.3, 0.5) * exp(-pow((y - 0.32) / 0.05, 2.0)) * 0.5;
	c += vec3(0.5, 0.55, 0.75) * pow(max(dot(r, normalize(vec3(-0.45, 0.75, 0.35))), 0.0), 40.0) * 2.0;
	// Le halo de la lune, large : le pavillon et le capot luisent vus d'en haut.
	c += vec3(0.3, 0.32, 0.45) * pow(max(dot(r, normalize(vec3(-0.45, 0.75, 0.35))), 0.0), 6.0) * 0.6;
	return c;
}

void fragment() {
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 r = reflect(-v, n);
	// La rue reflétée est proche : plus le point est haut, plus il voit bas dans le reflet. Sur une
	// surface plane (un flanc, une vitre), la ligne des vitrines devient une bande, pas un aplat.
	r = normalize(r - vec3(0.0, (wpos.y - 0.45) * 0.9, 0.0));
	float ndv = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float bord = pow(1.0 - ndv, 2.0);
	float fresnel = 0.12 + 0.88 * pow(1.0 - ndv, 5.0);
	vec3 base = lpos.y < coupe_y ? teinte_bas.rgb : teinte.rgb;
	// Le chatoiement : la teinte tourne vers le reflet quand la forme fuit le regard.
	vec3 couleur = mix(base, base * 0.5 + reflet.rgb * 0.5, bord * chatoiement);
	vec3 env = rue(r);
	vec3 brillance;
	if (metal > 0.5) {
		brillance = env * base * 1.6 + env * 0.25;
		ALBEDO = base * 0.35;
		METALLIC = 1.0;
	} else {
		brillance = env * fresnel * vernis * 1.4;
		ALBEDO = couleur;
		METALLIC = 0.15;
	}
	// Les paillettes : une cellule sur cent s'allume, et change avec l'angle de vue.
	vec3 cell = floor(wpos * 220.0);
	float p = step(0.99, hash3(cell + floor(v * 4.0) * 17.0));
	brillance += paillette_teinte.rgb * p * paillettes * (0.12 + 0.6 * bord);
	ROUGHNESS = rugosite;
	SPECULAR = 0.6;
	EMISSION = brillance + base * lumiere;
}
