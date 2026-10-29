shader_type spatial;
// Ce qui est uni : enduits, bois peint, métal, verre sombre, asphalte. La couleur vient du sommet ; un grain
// très léger casse les aplats ; l'alpha du sommet est la rugosité (1 : mat, 0.2 : vernis, verre).
render_mode diffuse_burley;

varying vec3 monde;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float bruit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float g = bruit(monde.xy * 3.0 + monde.zz * 2.0) * 0.5 + bruit(monde.xz * 1.3) * 0.5;
	ALBEDO = pow(COLOR.rgb * (0.95 + 0.08 * g), vec3(2.2));
	ROUGHNESS = COLOR.a;
	METALLIC = 0.0;
}
