shader_type spatial;
render_mode unshaded, cull_disabled;
// Casino Minuit : l'eau claire des bassins du moteur web (K.M.water) : la texture des reflets, teintée de bleu
// glacier, en dalles de 1,5 m qui dérivent lentement, sans éclairage ni brouillard.
uniform sampler2D motif : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 teinte : source_color = vec3(0.62, 0.91, 1.0);
uniform float gain = 1.0;
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 d = vec2(TIME * 0.02 + sin(TIME * 0.31) * 0.03, TIME * 0.013 + cos(TIME * 0.23) * 0.03);
	ALBEDO = texture(motif, (wpos.xz / 1.5 + d) * vec2(1.0, -1.0)).rgb * teinte * gain;
}
