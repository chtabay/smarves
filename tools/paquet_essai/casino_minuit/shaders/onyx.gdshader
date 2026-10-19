shader_type spatial;
// Casino Minuit : onyx rétroéclairé, ambre veiné, qui respire à peine.
uniform vec3 teinte : source_color = vec3(0.61, 0.49, 0.38);
uniform float lueur = 1.1;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.1; a *= 0.5; } return v; }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = (wpos.xy + wpos.zy) * 1.3;
	float b = fbm(p + vec2(fbm(p * 0.7) * 2.0, 0.0));
	float band = 0.5 + 0.5 * sin(b * 12.0);
	vec3 c = mix(teinte * 0.55, vec3(1.0, 0.78, 0.48), band * 0.7);
	ALBEDO = c * 0.4;
	EMISSION = c * lueur * (0.92 + 0.08 * sin(TIME * 0.6));
	ROUGHNESS = 0.15;
}
