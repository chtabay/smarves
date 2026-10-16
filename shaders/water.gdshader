shader_type spatial;
// Eau du Miosson et du bief : bleu sombre, petites vagues qui bougent, reflets.
uniform vec3 deep : source_color = vec3(0.04, 0.12, 0.2);
uniform vec3 shallow : source_color = vec3(0.12, 0.32, 0.4);
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz * 1.6 + vec2(TIME * 0.6, TIME * 0.15);
	float n = noise(p) * 0.6 + noise(p * 2.3 - TIME * 0.4) * 0.4;
	ALBEDO = mix(deep, shallow, n);
	float e = 0.02;
	NORMAL_MAP = normalize(vec3(noise(p + vec2(e, 0)) - n, noise(p + vec2(0, e)) - n, 0.08)) * 0.5 + 0.5;
	ROUGHNESS = 0.05;
	METALLIC = 0.1;
}
