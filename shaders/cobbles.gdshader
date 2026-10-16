shader_type spatial;
// Pavés de calcaire de la place : pierres arrondies en rangs décalés, joints sombres, teintes variées.
uniform vec3 stone_a : source_color = vec3(0.62, 0.56, 0.48);
uniform vec3 stone_b : source_color = vec3(0.48, 0.44, 0.4);
uniform vec3 joint : source_color = vec3(0.3, 0.26, 0.22);
uniform float size = 0.22;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz / size;
	float row = floor(p.y);
	p.x += mod(row, 2.0) * 0.5;
	vec2 cell = floor(p);
	vec2 f = fract(p) - 0.5;
	f += (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.06;
	float h = hash(cell);
	// Pierre arrondie : distance au bord d'un rectangle aux coins ronds.
	vec2 q = abs(f) - vec2(0.27, 0.27);
	float d = length(max(q, 0.0)) - 0.15 + noise(wpos.xz * 30.0) * 0.03;
	float stone = smoothstep(0.04, -0.02, d);
	float bump = clamp(-d * 6.0, 0.0, 1.0);
	vec3 tint = mix(stone_a, stone_b, h) * mix(vec3(1.0), vec3(1.05, 0.95, 0.9), hash(cell + 1.3));
	vec3 col = tint * (0.8 + 0.3 * noise(wpos.xz * 14.0));
	col = mix(joint, col, stone);
	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.55 + h * 0.3, stone);
	// Relief : la pierre bombe vers son centre.
	vec2 g = vec2(f.x, f.y) * bump * 0.9;
	NORMAL_MAP = normalize(vec3(g.x, g.y, 1.0)) * 0.5 + 0.5;
	NORMAL_MAP_DEPTH = 1.5 * stone;
}
