shader_type spatial;
render_mode unshaded, fog_disabled, cull_front, shadows_disabled;
// Casino Minuit, lot E : le ciel du Strip la nuit (e-0-commun.js, E.sky) — dégradé du halo urbain au zénith,
// étoiles, lune au sud-ouest, montagnes et silhouette de la ville au loin sur l'horizon. La sphère suit la caméra.
varying vec3 dir;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { dir = VERTEX; }
void fragment() {
	vec3 d = normalize(dir);
	float h = d.y;
	float az = atan(d.x, d.z);
	vec3 c = mix(vec3(0.30, 0.15, 0.20), vec3(0.09, 0.06, 0.16), smoothstep(0.0, 0.12, h));
	c = mix(c, vec3(0.025, 0.03, 0.08), smoothstep(0.12, 0.45, h));
	c = mix(c, vec3(0.008, 0.01, 0.03), smoothstep(0.45, 1.0, h));
	// Les étoiles, plus nombreuses vers le zénith.
	vec2 sp = vec2(az * 90.0, h * 140.0);
	vec2 si = floor(sp);
	float s = hash(si);
	float e = step(0.985, s) * smoothstep(0.35, 0.0, length(fract(sp) - 0.5)) * smoothstep(0.1, 0.4, h);
	c += vec3(0.9, 0.9, 1.0) * e * (0.6 + 0.4 * sin(TIME * (1.0 + s * 4.0) + s * 50.0));
	// La lune, au sud-ouest au-dessus des hôtels d'en face.
	vec3 ld = normalize(vec3(-0.55, 0.42, 0.72));
	float m = dot(d, ld);
	c += vec3(1.0, 0.97, 0.88) * smoothstep(0.99955, 0.9997, m) * 1.4;
	c += vec3(1.0, 0.95, 0.85) * 0.12 * smoothstep(0.985, 0.9995, m);
	// Les montagnes au loin.
	float mont = 0.035 + 0.025 * sin(az * 3.0 + 1.0) + 0.015 * sin(az * 7.0 + 2.0) + 0.008 * sin(az * 13.0);
	if (h < mont) c = vec3(0.06, 0.045, 0.08);
	// La ville au loin : silhouettes d'immeubles, fenêtres, néons.
	float col = floor(az * 70.0);
	float bh = 0.004 + 0.05 * pow(hash(vec2(col, 3.0)), 2.0);
	if (h < bh && h > -0.02) {
		c = vec3(0.045, 0.04, 0.07);
		vec2 w = vec2(az * 900.0, h * 900.0);
		if (hash(floor(w)) > 0.7 && fract(w.x) > 0.3 && fract(w.y) > 0.3) c = vec3(1.0, 0.8, 0.55) * 0.8;
		if (abs(h - bh) < 0.0015 && hash(vec2(col, 9.0)) > 0.6) c = mix(vec3(1.0, 0.3, 0.55), vec3(0.25, 0.9, 0.9), hash(vec2(col, 5.0))) * 1.5;
	}
	if (h < -0.02) c = vec3(0.05, 0.035, 0.04);
	ALBEDO = c;
}
