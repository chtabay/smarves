shader_type spatial;
// Le contour noir de la ligne claire : la coque retournée, poussée le long des normales.
// L'épaisseur se compte en pixels d'écran (rapportés à une hauteur de 1080), pas en unités du monde :
// un contour en unités devient plus fin qu'un pixel dès que le personnage s'éloigne.
// L'alpha de la couleur peinte dit si une pièce a un contour (1) ou non (0 : yeux, bouche, boutons).

render_mode unshaded, cull_front, depth_draw_opaque, shadows_disabled;

uniform float px : hint_range(0.0, 8.0) = 2.5;
// Au plus près, le contour ne dépasse pas cette épaisseur dans le monde (un gros plan reste fin).
uniform float max_width = 0.02;
uniform vec4 ink : source_color = vec4(0.07, 0.05, 0.06, 1.0);

void vertex() {
	vec4 clip = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	vec3 n_view = normalize(MODELVIEW_NORMAL_MATRIX * NORMAL);
	vec2 dir = (PROJECTION_MATRIX * vec4(n_view, 0.0)).xy;
	float len = length(dir);
	if (len > 1e-5) {
		dir /= len;
		// Décalage en NDC pour px pixels, multiplié par w pour rester constant à l'écran.
		float ndc = px * (VIEWPORT_SIZE.y / 1080.0) * 2.0 / VIEWPORT_SIZE.y;
		// Plafond : la même épaisseur en unités du monde, projetée.
		float cap = max_width * abs(PROJECTION_MATRIX[1][1]) / max(clip.w, 1e-4);
		clip.xy += dir * min(ndc, cap) * clip.w * COLOR.a;
	}
	POSITION = clip;
}

void fragment() {
	if (COLOR.a < 0.5) {
		discard;
	}
	ALBEDO = ink.rgb;
}
