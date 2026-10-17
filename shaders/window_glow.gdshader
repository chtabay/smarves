shader_type spatial;
// Fenêtres et vitrines du village, posées en MultiMesh : la couleur d'instance donne la lumière
// (alpha 0 = fenêtre éteinte), la donnée d'instance le dessin (x : 0 fenêtre à carreaux, 1 vitrine,
// 2 porte vitrée ; y : graine des rideaux).
#include "res://shaders/village_cutaway.gdshaderinc"
uniform float energy = 4.6;
varying vec3 cut_wpos;
varying vec4 glow;
varying vec4 custom;
float hash(float n) { return fract(sin(n) * 43758.5453); }
void vertex() {
	cut_wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	glow = COLOR;
	custom = INSTANCE_CUSTOM;
}
void fragment() {
	cutaway(cut_wpos, FRAGCOORD.xy);
	vec2 uv = UV;
	float kind = custom.x;
	float seed = custom.y;
	// Croisillons : six carreaux pour une fenêtre, trois grands pour une vitrine.
	float bars;
	if (kind < 0.5) {
		bars = step(abs(uv.x - 0.5), 0.035) + step(abs(fract(uv.y * 3.0) - 0.5), 0.5) * step(0.47, abs(fract(uv.y * 3.0) - 0.5));
	} else if (kind < 1.5) {
		bars = step(abs(fract(uv.x * 3.0) - 0.5), 0.5) * step(0.485, abs(fract(uv.x * 3.0) - 0.5)) + step(abs(uv.y - 0.78), 0.012);
	} else {
		bars = step(abs(uv.y - 0.65), 0.03);
	}
	float frame = step(0.46, abs(uv.x - 0.5)) + step(0.46, abs(uv.y - 0.5));
	bars = clamp(bars + frame, 0.0, 1.0);
	// Rideaux sur les côtés, et une lampe au fond qui chauffe le centre.
	float curtain = smoothstep(0.32, 0.18, abs(uv.x - 0.5)) ;
	float lamp = 1.0 - length((uv - vec2(0.5 + (hash(seed) - 0.5) * 0.4, 0.6)) * vec2(1.4, 1.0));
	vec3 light = glow.rgb * (0.55 + 0.6 * clamp(lamp, 0.0, 1.0)) * mix(0.75, 1.0, curtain);
	// Vitrine : des étagères en silhouette.
	if (kind > 0.5 && kind < 1.5) {
		float shelf = step(0.92, fract(uv.y * 4.0)) * step(uv.y, 0.75);
		light *= 1.0 - shelf * 0.6;
	}
	vec3 night = vec3(0.05, 0.07, 0.12) + vec3(0.06, 0.08, 0.14) * uv.y;
	vec3 col = mix(night, light, glow.a);
	vec3 wood = vec3(0.18, 0.13, 0.1);
	ALBEDO = mix(col * 0.25, wood, bars);
	EMISSION = col * energy * glow.a * (1.0 - bars);
	ROUGHNESS = mix(0.1, 0.7, bars);
	METALLIC = 0.0;
	SPECULAR = 0.8;
}
