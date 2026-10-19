shader_type spatial;
render_mode cull_disabled;
// Casino Minuit : un treillage d'or en losanges, ajouré (les vides laissent voir le panneau derrière).
uniform vec3 couleur : source_color = vec3(0.85, 0.64, 0.25);
uniform float pas = 0.3;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float u = (wpos.x + wpos.z) / pas;
	float v = wpos.y / pas;
	float a = abs(fract(u + v) - 0.5);
	float b = abs(fract(u - v) - 0.5);
	float trait = max(step(0.44, a), step(0.44, b));
	if (trait < 0.5) discard;
	ALBEDO = couleur;
	METALLIC = 0.8;
	ROUGHNESS = 0.35;
}
