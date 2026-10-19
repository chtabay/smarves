shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
// Casino Minuit, lot E : les guirlandes d'ampoules « chenillard » des marquises (E.bulbs) — une ampoule tous les
// 30 cm le long de UV.x (en mètres), allumées tour à tour.
void fragment() {
	float i = floor(UV.x / 0.3);
	vec2 q = vec2(fract(UV.x / 0.3) - 0.5, UV.y - 0.5) * 2.0;
	float d = length(q);
	int k = int(mod(i + floor(TIME * 6.0), 4.0));
	float b = k == 0 ? 1.0 : (k == 1 ? 0.35 : (k == 2 ? 0.75 : 0.25));
	float a = pow(max(0.0, 1.0 - d), 1.6);
	ALBEDO = mix(vec3(1.0, 0.55, 0.16), vec3(1.0, 0.98, 0.9), smoothstep(0.5, 1.0, a)) * a * b * 2.6;
}
