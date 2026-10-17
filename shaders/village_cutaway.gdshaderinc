// Coupe de maquette : quand les maisons du premier plan cachent l'habitant qu'on dirige, on perce
// un trou en pointillé dans tout ce qui se trouve entre la caméra et lui (murs, toits, vitres).
// Le script du village met à jour cut_from (caméra) et cut_to (habitant) à chaque image.
uniform vec3 cut_from = vec3(0.0);
uniform vec3 cut_to = vec3(0.0);
uniform float cut_radius = 2.3;
uniform float cut_on = 0.0;

// Tramage ordonné 4 × 4 : le trou se lit comme un pointillé régulier, pas comme du bruit.
float cut_bayer(vec2 frag) {
	ivec2 q = ivec2(mod(frag, 4.0));
	int i = q.x + q.y * 4;
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[i]) + 0.5) / 16.0;
}

void cutaway(vec3 p, vec2 frag) {
	if (cut_on < 0.5) {
		return;
	}
	vec3 ab = cut_to - cut_from;
	float t = clamp(dot(p - cut_from, ab) / max(dot(ab, ab), 0.001), 0.0, 1.0);
	float d = length(p - (cut_from + ab * t));
	// Rien près de l'habitant ni au ras du sol : on ne coupe que ce qui est devant, en hauteur.
	float k = smoothstep(cut_radius, cut_radius * 0.55, d) * smoothstep(0.93, 0.8, t) * smoothstep(0.25, 0.6, p.y);
	if (k > 0.02 && k > cut_bayer(floor(frag))) {
		discard;
	}
}
