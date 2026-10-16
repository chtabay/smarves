shader_type spatial;
// Béton peint d'un zèbre : rayures noires et blanches ondulées, légèrement brillantes.
uniform float freq = 9.0;
varying vec3 lpos;
void vertex() { lpos = VERTEX; }
void fragment() {
	float wave = sin(lpos.y * 14.0) * 0.04 + sin(lpos.z * 9.0) * 0.03;
	float s = step(0.5, fract((lpos.x + wave) * freq + lpos.y * 2.0));
	ALBEDO = mix(vec3(0.05), vec3(0.95, 0.94, 0.9), s);
	ROUGHNESS = 0.35;
}
