shader_type spatial;
render_mode unshaded;
// Casino Minuit, lots E et F : les écrans LED (E.led du moteur web), animés ici par le calcul plutôt que par un
// atlas de diapositives. UV de 0 à 1 ; COLOR.r : la palette (huitièmes), COLOR.g : le déphasage, COLOR.b : la
// largeur de l'écran sur sa hauteur, sur dix. Trame de diodes, diapositives qui se succèdent en balayage.
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec3 teinte(int p, float k) {
	vec3 a = vec3(1.0, 0.2, 0.25); vec3 b = vec3(1.0, 0.76, 0.29);
	if (p == 1) { a = vec3(0.24, 0.88, 0.88); b = vec3(1.0, 0.3, 0.55); }
	else if (p == 2) { a = vec3(0.35, 0.1, 0.55); b = vec3(1.0, 0.55, 0.2); }
	else if (p == 3) { a = vec3(0.1, 0.25, 0.9); b = vec3(0.95, 0.95, 1.0); }
	else if (p == 4) { a = vec3(0.55, 0.05, 0.1); b = vec3(0.85, 0.64, 0.25); }
	else if (p == 5) { a = vec3(0.05, 0.3, 0.45); b = vec3(0.75, 0.92, 1.0); }
	else if (p == 6) { a = vec3(0.9, 0.3, 0.55); b = vec3(0.3, 0.05, 0.2); }
	return mix(a, b, k);
}
vec3 diapo(int p, int n, vec2 uv, float t) {
	int m = n % 4;
	if (m == 0) {
		float k = 0.5 + 0.5 * sin(uv.x * 6.0 - t * 2.0 + uv.y * 3.0);
		return teinte(p, k) * (0.4 + 0.6 * smoothstep(0.0, 1.0, uv.y));
	} else if (m == 1) {
		float d = length((uv - 0.5) * vec2(2.0, 1.0));
		return teinte(p, step(0.5, fract(d * 4.0 - t * 0.8))) * (1.0 - 0.6 * d);
	} else if (m == 2) {
		float b = step(0.5, fract(uv.x * 5.0 + t * 0.6));
		vec3 c = teinte(p, b) * 0.35;
		if (abs(uv.y - 0.5) < 0.18) c = teinte(p, 1.0 - b) * 1.1;
		return c;
	}
	float s = step(0.92, hash(floor(uv * vec2(24.0, 12.0)) + floor(t * 3.0)));
	return mix(teinte(p, 0.0) * 0.3, teinte(p, 1.0), s + 0.3 * (1.0 - uv.y));
}
void fragment() {
	int p = int(floor(COLOR.r * 8.0 + 0.5));
	float ph = COLOR.g * 10.0;
	float ar = max(COLOR.b * 10.0, 0.1);
	float t = TIME + ph;
	float per = 5.5;
	float k = floor(t / per);
	float f = fract(t / per);
	float w = smoothstep(0.86, 1.0, f) * 1.2 - 0.1;
	float edge = UV.x + (UV.y - 0.5) * 0.15;
	vec3 c = edge < w ? diapo(p, int(k) + 1, UV, t) : diapo(p, int(k), UV, t);
	if (w > 0.0 && w < 1.1 && abs(edge - w) < 0.01) c += vec3(0.9, 0.8, 0.6);
	vec2 res = vec2(60.0 * ar, 60.0);
	vec2 g = fract(UV * res) - 0.5;
	float dotm = 1.0 - smoothstep(0.28, 0.5, length(g));
	c *= 1.4 * (0.45 + 0.85 * dotm);
	ALBEDO = c;
}
