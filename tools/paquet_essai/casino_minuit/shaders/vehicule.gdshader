shader_type spatial;
// Casino Minuit, lot E : les voitures du boulevard, toutes d'un matériau. COLOR.rgb : la teinte de la pièce,
// COLOR.a = 1 pour la carrosserie, peinte de la couleur de l'instance (INSTANCE_CUSTOM.rgb) ; UV.x : la lueur
// propre de la pièce (phares, feux, lumineux du taxi), UV.y : son poli.
varying vec3 teinte;
varying float lueur;
varying float poli;
void vertex() {
	teinte = mix(COLOR.rgb, INSTANCE_CUSTOM.rgb, COLOR.a);
	lueur = UV.x;
	poli = UV.y;
}
void fragment() {
	ALBEDO = teinte;
	ROUGHNESS = mix(0.75, 0.2, poli);
	METALLIC = 0.4 * poli;
	EMISSION = teinte * lueur * 3.0;
}
