shader_type spatial;
// Casino Minuit, lot F : la foule d'imposteurs des gradins, de la fosse et du balcon (F.crowd) — des silhouettes
// basses, peintes par instance (INSTANCE_CUSTOM.rgb : le haut, .a : le déphasage), qui se balancent et sautent
// sur le temps. COLOR.a = 1 pour le haut ; COLOR.rgb : la teinte des autres pièces.
uniform float tempo = 2.0;
uniform float saut = 0.0;
uniform float balance = 0.4;
varying vec3 teinte;
void vertex() {
	teinte = mix(COLOR.rgb, INSTANCE_CUSTOM.rgb, COLOR.a);
	float ph = INSTANCE_CUSTOM.a * 6.2831;
	float t = TIME * tempo + ph;
	float h = clamp(VERTEX.y / 1.7, 0.0, 1.0);
	VERTEX.x += sin(t * 0.5) * 0.06 * balance * h;
	VERTEX.y += max(0.0, sin(t * 3.1416)) * saut;
}
void fragment() {
	ALBEDO = teinte;
	ROUGHNESS = 0.85;
	// Une faible lueur propre : dans une salle noire, le public se devine même à contre-jour.
	EMISSION = teinte * 0.18;
}
