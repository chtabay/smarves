shader_type spatial;
render_mode unshaded, cull_front;
// Casino Minuit : la coupole peinte de la rotonde, vue de dessous. UV.y = 0 à la naissance, 1 à l'oculus :
// trois rangs de caissons en trompe-l'œil en bas, ciel de nuit peint en haut, dans la pénombre.
uniform float sombre = 0.42;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	float u = UV.x * 16.0;
	float v = UV.y;
	vec3 c;
	if (v < 0.5) {
		float row = floor(v / 0.165);
		float fv = fract(v / 0.165);
		float fu = fract(u);
		vec2 d = abs(vec2(fu, fv) - 0.5);
		float m = max(d.x, d.y);
		c = mix(vec3(0.43, 0.35, 0.24), vec3(0.66, 0.58, 0.42), fu * 0.5 + fv * 0.5);
		if (m > 0.44) c = vec3(0.85, 0.8, 0.71);
		else if (m > 0.36 && m < 0.39) c = vec3(0.56, 0.42, 0.17);
		if (length(vec2(fu, fv) - 0.5) < 0.06 - row * 0.01) c = vec3(0.85, 0.64, 0.25);
		if (v > 0.485) c = vec3(0.85, 0.64, 0.25);
	} else {
		float t = (v - 0.5) / 0.5;
		c = mix(vec3(0.42, 0.24, 0.32), vec3(0.06, 0.07, 0.16), t);
		vec2 g = vec2(UV.x * 220.0, v * 60.0);
		float s = hash(floor(g));
		if (s > 0.985) c += vec3(1.0, 0.95, 0.85) * (s - 0.985) * 40.0 * (0.6 + 0.4 * sin(TIME * 2.0 + s * 50.0));
	}
	ALBEDO = c * sombre;
}
