shader_type spatial;
// Le contour noir de la ligne claire : la coque retournée, poussée le long des normales.
// L'alpha de la couleur peinte dit si une pièce a un contour (1) ou non (0 : yeux, bouche, boutons).

render_mode unshaded, cull_front, depth_draw_opaque;

uniform float width : hint_range(0.0, 0.02) = 0.0035;
uniform vec4 ink : source_color = vec4(0.07, 0.05, 0.06, 1.0);

void vertex() {
	VERTEX += NORMAL * width * COLOR.a;
}

void fragment() {
	if (COLOR.a < 0.5) {
		discard;
	}
	ALBEDO = ink.rgb;
}
