shader_type spatial;
render_mode blend_mix;
// Casino Minuit : l'eau des bassins, sarcelle sombre, reflets mouvants.
uniform vec3 fond : source_color = vec3(0.10, 0.36, 0.36);
uniform vec3 clair : source_color = vec3(0.35, 0.70, 0.66);
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz * 2.2 + vec2(TIME * 0.35, TIME * 0.2);
	float n = noise(p) * 0.6 + noise(p * 2.7 - TIME * 0.5) * 0.4;
	ALBEDO = mix(fond, clair, n * n);
	float e = 0.03;
	NORMAL_MAP = normalize(vec3(noise(p + vec2(e, 0)) - n, noise(p + vec2(0, e)) - n, 0.1)) * 0.5 + 0.5;
	ROUGHNESS = 0.04;
	METALLIC = 0.2;
	EMISSION = clair * 0.12 * n;
	ALPHA = 0.88;
}
