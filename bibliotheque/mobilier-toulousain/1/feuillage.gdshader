shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
// Le feuillage de la place du nord : couleur par sommet (sRGB), souffle du vent pondéré par l'alpha,
// une lumière qui traverse les feuilles pour garder le vert vif à contre-jour.
uniform float souffle = .08;
// le jour du ciel dans le feuillage : une lueur propre aux feuilles que l'ombre portée n'éteint pas, tirée vers un
// vert gris, pour que les massifs à l'ombre des platanes restent lisibles (vers #2E4A28) au lieu de tomber au noir
// (verdict de Saint-Georges v0.12) ; réglable objet par objet (option jour)
instance uniform float jour = 1.;
void vertex() {
 vec3 monde = (MODEL_MATRIX * vec4(VERTEX, 1.)).xyz;
 float phase = monde.x * .31 + monde.z * .23;
 float vent = sin(TIME * .8 + phase) + sin(TIME * 1.37 + phase * 1.7) * .3;
 VERTEX.x += vent * souffle * COLOR.a;
 VERTEX.z += sin(TIME * .63 + phase) * souffle * .6 * COLOR.a;
}
void fragment() {
 ALBEDO = pow(COLOR.rgb, vec3(2.2));
 ROUGHNESS = .95;
 BACKLIGHT = ALBEDO * .45;
 vec3 gris = vec3(dot(ALBEDO, vec3(.3, .59, .11)));
 EMISSION = mix(ALBEDO, gris, .55) * jour;
}
