shader_type spatial;
// Casino Minuit : marbre veiné en coordonnées monde (les dalles se raccordent d'un morceau à l'autre).
uniform vec3 fond : source_color = vec3(0.91, 0.87, 0.80);
uniform vec3 veine : source_color = vec3(0.72, 0.62, 0.48);
uniform float echelle = 0.6;
uniform float poli = 0.18;
uniform float lueur = 0.0;
varying vec3 wpos;
varying vec3 wnrm;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.07; a *= 0.5; } return v; }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	vec3 n = abs(wnrm);
	vec2 p = (n.y > 0.6 ? wpos.xz : (n.x > n.z ? wpos.zy : wpos.xy)) * echelle;
	float v = abs(sin((p.x * 0.7 + p.y) * 2.2 + fbm(p * 1.7) * 7.0));
	v = 1.0 - smoothstep(0.0, 0.12, v);
	vec3 c = mix(fond, veine, v * 0.85) * (0.93 + 0.07 * fbm(p * 5.0));
	ALBEDO = c;
	ROUGHNESS = poli + v * 0.2;
	SPECULAR = 0.55;
	EMISSION = c * lueur;
}
