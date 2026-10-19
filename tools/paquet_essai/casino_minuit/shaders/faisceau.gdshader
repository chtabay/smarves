shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Casino Minuit, lots E et F : les faisceaux de lumière (projecteurs de ciel, lyres, poursuites), cônes additifs
// qui s'effacent vers leur bout (UV.y = 0 au bout, 1 à la source).
uniform vec3 couleur : source_color = vec3(0.56, 0.66, 0.78);
uniform float gain = 0.5;
void fragment() {
	float k = pow(UV.y, 1.6);
	ALBEDO = couleur * gain * k;
}
