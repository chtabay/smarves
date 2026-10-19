shader_type spatial;
render_mode unshaded;
// Casino Minuit : le Strip la nuit, peint derrière la porte d'entrée (le lot E viendra le remplacer).
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 uv = UV;
	float y = 1.0 - uv.y;
	vec3 c = mix(vec3(0.16, 0.08, 0.03), vec3(0.72, 0.31, 0.16), smoothstep(0.0, 0.2, y));
	c = mix(c, vec3(0.23, 0.10, 0.29), smoothstep(0.2, 0.45, y));
	c = mix(c, vec3(0.04, 0.04, 0.12), smoothstep(0.45, 1.0, y));
	float col = floor(uv.x * 22.0);
	float h = 0.18 + 0.45 * hash(vec2(col, 1.0));
	if (y > 0.15 && y < 0.15 + h) {
		c = vec3(0.07, 0.04, 0.09);
		vec2 w = vec2(fract(uv.x * 22.0 * 6.0), fract(y * 70.0));
		if (w.x > 0.3 && w.y > 0.35 && hash(floor(vec2(uv.x * 132.0, y * 70.0))) > 0.45) {
			float k = hash(floor(vec2(uv.x * 132.0, y * 70.0)) + 7.0);
			c = k > 0.85 ? vec3(1.0, 0.3, 0.55) : (k > 0.75 ? vec3(0.24, 0.88, 0.88) : vec3(1.0, 0.85, 0.66));
			c *= 0.8 + 0.2 * sin(TIME * 3.0 + k * 40.0);
		}
		if (abs(y - 0.15 - h) < 0.006) c = vec3(1.0, 0.76, 0.29);
	}
	if (y < 0.15) {
		c = vec3(0.1, 0.06, 0.04);
		float l = hash(vec2(floor(uv.x * 60.0 + TIME * (uv.y > 0.93 ? 4.0 : -3.0)), floor(y * 20.0)));
		if (l > 0.8 && fract(y * 20.0) < 0.3) c = (uv.y > 0.93) ? vec3(1.0, 0.89, 0.7) : vec3(1.0, 0.2, 0.28);
	}
	if (y > 0.5 && hash(floor(uv * vec2(300.0, 150.0))) > 0.996) c += vec3(0.8);
	ALBEDO = c;
}
