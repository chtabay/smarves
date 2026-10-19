shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;
// Casino Minuit : les fausses lumières du moteur web (K.Halos) : un disque additif par halo, tourné vers la caméra
// ou posé à plat (flaque de lumière au sol, sur un tapis), qui s'éteint dans le brouillard. Un MultiMesh par zone :
// INSTANCE_CUSTOM = (r, v, b, diamètre), la couleur porte déjà l'intensité ; COLOR.a = 1 pour une flaque.
uniform float gain = 1.0;
uniform float brume_pres = 16.0;
uniform float brume_loin = 95.0;
varying vec3 col;
void vertex() {
	float taille = INSTANCE_CUSTOM.a;
	vec3 centre = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec4 mv;
	if (COLOR.a > 0.5) {
		mv = MODELVIEW_MATRIX * vec4(VERTEX.x * taille, 0.0, -VERTEX.y * taille, 1.0);
	} else {
		mv = vec4(centre + vec3(VERTEX.xy * taille, min(taille * 0.3, 0.3)), 1.0);
	}
	float d = -mv.z;
	col = INSTANCE_CUSTOM.rgb * (1.0 - smoothstep(brume_pres, brume_loin, d));
	POSITION = PROJECTION_MATRIX * mv;
}
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float a = pow(max(0.0, 1.0 - d), 2.2);
	ALBEDO = col * a * gain;
}
