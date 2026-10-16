shader_type spatial;
// Dallage en damier de marbre crème et noir, veiné, poli.
uniform float tile = 1.0;
uniform vec3 light_stone : source_color = vec3(0.93, 0.89, 0.82);
uniform vec3 dark_stone : source_color = vec3(0.07, 0.06, 0.07);
varying vec3 wpos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float v = 0.0; float a = 0.5; for (int i = 0; i < 5; i++) { v += a * noise(p); p *= 2.1; a *= 0.5; } return v; }

void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }

void fragment() {
	vec2 p = wpos.xz / tile;
	float c = mod(floor(p.x) + floor(p.y), 2.0);
	float vein = abs(sin((p.x + p.y) * 3.0 + fbm(p * 2.0) * 6.0));
	vein = smoothstep(0.0, 0.08, vein);
	vec3 base = mix(light_stone, dark_stone, c);
	vec3 vcol = mix(vec3(0.6, 0.55, 0.5), vec3(0.25, 0.25, 0.28), c);
	ALBEDO = mix(vcol, base, vein) * (0.92 + 0.08 * fbm(p * 6.0));
	vec2 g = abs(fract(p) - 0.5);
	float joint = step(0.49, max(g.x, g.y));
	ALBEDO = mix(ALBEDO, vec3(0.45, 0.4, 0.32), joint * 0.6);
	ROUGHNESS = 0.12 + joint * 0.5;
	SPECULAR = 0.6;
}
