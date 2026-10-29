shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
// Le feuillage des platanes de la place, d'après celui de la végétation lyonnaise : la même couleur par sommet
// et le même souffle, mais un vert plus clair et une lumière qui traverse davantage les feuilles, pour que la
// voûte des platanes reste lumineuse et que son ombre sur la brique se lise comme une ombrière.
uniform float souffle = .08;
uniform float eclat = 1.3;
uniform vec3 jour = vec3(.08, .07, -.02);
void vertex() {
	vec3 monde = (MODEL_MATRIX * vec4(VERTEX, 1.)).xyz;
	float phase = monde.x * .31 + monde.z * .23;
	float vent = sin(TIME * .8 + phase) + sin(TIME * 1.37 + phase * 1.7) * .3;
	VERTEX.x += vent * souffle * COLOR.a;
	VERTEX.z += sin(TIME * .63 + phase) * souffle * .6 * COLOR.a;
}
void fragment() {
	ALBEDO = pow(clamp(COLOR.rgb * eclat + jour, 0., 1.), vec3(2.2));
	ROUGHNESS = .95;
	BACKLIGHT = ALBEDO * .8;
}
