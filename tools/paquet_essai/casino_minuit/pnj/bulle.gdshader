shader_type spatial;
// Le fond d'une bulle ou d'une étiquette de nom des PNJ (makeLabel, say dans js/npc.js) : le rectangle
// arrondi tracé sur le canvas de l'original, rempli puis cerné, avec la pointe sous la bulle. Toujours face
// à la caméra comme un Sprite de three.js ; ni brouillard, ni ombre, ni écriture de profondeur.
render_mode unshaded, fog_disabled, depth_draw_never, cull_disabled, shadows_disabled, blend_mix;

uniform vec2 canvas = vec2(512.0, 96.0);
// x0, y0, x1, y1 du rectangle, en pixels du canvas
uniform vec4 rect = vec4(10.0, 8.0, 502.0, 66.0);
uniform float rayon = 20.0;
uniform bool queue = false;
uniform vec4 fond : source_color = vec4(0.953, 0.918, 0.843, 0.95);
uniform vec4 trait_ : source_color = vec4(0.561, 0.424, 0.173, 1.0);
uniform float trait_px = 2.5;
uniform float opacite = 1.0;

void vertex() {
	// billboard : les axes de la vue, l'échelle du nœud
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0] * s.x, INV_VIEW_MATRIX[1] * s.y, INV_VIEW_MATRIX[2] * s.z, MODEL_MATRIX[3]);
	MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

float sd_rect(vec2 p, vec2 a, vec2 b, float r) {
	vec2 c = (a + b) * 0.5;
	vec2 h = (b - a) * 0.5 - vec2(r);
	vec2 q = abs(p - c) - h;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float sd_tri(vec2 p, vec2 p0, vec2 p1, vec2 p2) {
	vec2 e0 = p1 - p0, e1 = p2 - p1, e2 = p0 - p2;
	vec2 v0 = p - p0, v1 = p - p1, v2 = p - p2;
	vec2 pq0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
	vec2 pq1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
	vec2 pq2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
	float s = sign(e0.x * e2.y - e0.y * e2.x);
	vec2 d = min(min(vec2(dot(pq0, pq0), s * (v0.x * e0.y - v0.y * e0.x)),
		vec2(dot(pq1, pq1), s * (v1.x * e1.y - v1.y * e1.x))),
		vec2(dot(pq2, pq2), s * (v2.x * e2.y - v2.y * e2.x)));
	return -sqrt(d.x) * sign(d.y);
}

void fragment() {
	vec2 p = UV * canvas;
	float d = sd_rect(p, rect.xy, rect.zw, rayon);
	if (queue) {
		// la pointe (244,66)-(268,66)-(256,88), soudée au bas de la bulle
		d = min(d, sd_tri(p, vec2(244.0, rect.w - 1.0), vec2(268.0, rect.w - 1.0), vec2(256.0, 88.0)));
	}
	float aa = max(fwidth(d), 1e-4);
	float f = clamp(0.5 - d / aa, 0.0, 1.0);
	float s = clamp(0.5 - (abs(d) - trait_px * 0.5) / aa, 0.0, 1.0);
	float ta = s * trait_.a;
	float fa = f * fond.a * (1.0 - ta);
	float a = ta + fa;
	if (a < 0.002) {
		discard;
	}
	ALBEDO = (trait_.rgb * ta + fond.rgb * fa) / a;
	ALPHA = a * opacite;
}
