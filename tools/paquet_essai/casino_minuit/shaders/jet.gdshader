shader_type spatial;
render_mode blend_add, unshaded, cull_disabled, depth_draw_never;
// Casino Minuit : l'eau qui jaillit ou qui tombe, des filets qui défilent.
uniform vec3 teinte : source_color = vec3(0.62, 0.78, 0.82);
uniform float vitesse = 1.6;
uniform float force = 0.55;
float hash(float x) { return fract(sin(x * 91.7) * 43758.5); }
void fragment() {
	float col = floor(UV.x * 18.0);
	float f = fract(UV.y * 2.0 - TIME * vitesse * (0.8 + 0.4 * hash(col)) + hash(col + 3.0));
	float a = smoothstep(0.0, 0.3, f) * (1.0 - smoothstep(0.6, 1.0, f));
	ALBEDO = teinte * (0.4 + 0.6 * a) * force;
}
