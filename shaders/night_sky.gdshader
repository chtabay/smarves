shader_type sky;
// Ciel de nuit sur le Poitou : dégradé bleu nuit, lueur violette à l'horizon, étoiles et lune.
uniform vec3 top : source_color = vec3(0.01, 0.015, 0.05);
uniform vec3 horizon : source_color = vec3(0.12, 0.07, 0.16);
uniform vec3 moon_dir = vec3(-0.4, 0.55, -0.73);

float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

void sky() {
	vec3 d = EYEDIR;
	float h = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(horizon, top, pow(h, 0.45));
	// Étoiles : une grille sur la sphère, une étoile sur quelques cellules, qui scintille.
	vec3 cell = floor(d * 140.0);
	float r = hash(cell);
	if (r > 0.985 && d.y > 0.05) {
		vec3 c = (cell + 0.5) / 140.0;
		float dist = length(d - normalize(c));
		float twinkle = 0.6 + 0.4 * sin(TIME * (1.0 + r * 4.0) + r * 50.0);
		col += vec3(1.0, 0.95, 0.85) * smoothstep(0.006, 0.0, dist) * twinkle * 2.0;
	}
	// La lune et son halo.
	float m = dot(d, normalize(moon_dir));
	col += vec3(1.0, 0.95, 0.8) * smoothstep(0.9993, 0.9996, m) * 3.0;
	col += vec3(0.3, 0.35, 0.5) * pow(max(m, 0.0), 60.0) * 0.6;
	if (d.y < 0.0) col = mix(horizon, vec3(0.0), clamp(-d.y * 4.0, 0.0, 1.0));
	COLOR = col;
}
