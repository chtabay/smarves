shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
// Les masses de feuillage : couleur en vertex color (sRGB), souffle du vent pondéré par l'alpha.
uniform float souffle = .14;
varying vec3 monde;
void vertex() {
 monde = (MODEL_MATRIX * vec4(VERTEX, 1.)).xyz;
 float phase = monde.x * .24 + monde.z * .19;
 float vent = sin(TIME * .72 + phase) + sin(TIME * 1.27 + phase * 1.63) * .31;
 VERTEX.x += vent * souffle * COLOR.a;
 VERTEX.z += sin(TIME * .59 + phase) * souffle * .55 * COLOR.a;
}
void fragment() {
 ALBEDO = pow(COLOR.rgb, vec3(2.05));
 ROUGHNESS = .92;
 BACKLIGHT = ALBEDO * .18;
}
