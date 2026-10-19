shader_type spatial;
// Casino Minuit : la rosace de mosaïque du sol de la rotonde (disque de rayon 1 en UV centrées).
uniform vec3 creme : source_color = vec3(0.91, 0.87, 0.80);
uniform vec3 noir : source_color = vec3(0.09, 0.08, 0.10);
uniform vec3 rosso : source_color = vec3(0.36, 0.16, 0.14);
uniform vec3 brun : source_color = vec3(0.23, 0.16, 0.15);
uniform vec3 orc : source_color = vec3(0.85, 0.64, 0.25);
void fragment() {
	vec2 q = (UV - 0.5) * 2.0;
	float r = length(q) * 505.0;
	float a = atan(q.x, -q.y);
	if (r > 505.0) discard;
	vec3 c = creme;
	if (r > 470.0) c = noir;
	else if (r > 452.0) c = orc;
	else if (r > 380.0) {
		c = rosso;
		float k = fract(a / TAU * 48.0);
		float d = abs(k - 0.5) * 2.0;
		float rr = abs(r - 416.0) / 30.0;
		if (d * 0.47 + rr * 0.53 < 0.5) c = (mod(floor(a / TAU * 48.0), 2.0) < 1.0) ? noir : creme;
	} else if (r > 368.0) c = orc;
	else if (r > 70.0) {
		float k = fract(a / TAU * 16.0 + 0.5) - 0.5;
		float w = sin(clamp((r - 120.0) / 246.0, 0.0, 1.0) * 3.1416) * 0.36;
		if (r > 120.0 && abs(k) < w) {
			c = mod(floor(a / TAU * 16.0 + 0.5), 2.0) < 1.0 ? rosso : brun;
			if (abs(abs(k) - w) < 0.012 || (abs(k) < 0.006 && r > 150.0 && r < 340.0)) c = orc;
		}
		float k8 = fract(a / TAU * 8.0) - 0.5;
		float lo = 1.0 - abs(r - 145.0) / 105.0;
		if (lo > 0.0 && abs(k8) < lo * 0.09) c = mod(floor(a / TAU * 8.0), 2.0) < 1.0 ? orc : noir;
	} else if (r > 60.0) c = orc;
	else c = noir;
	ALBEDO = c;
	ROUGHNESS = c == orc ? 0.3 : 0.25;
	METALLIC = c == orc ? 0.6 : 0.0;
	SPECULAR = 0.5;
}
