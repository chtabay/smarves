shader_type spatial;
// Les habitants : couleur peinte par sommet (sRVB), rugosité dans UV.x, éclat dans UV.y.
// Un léger velours sur les bords donne l'air de figurines floquées, comme sur une maquette.

render_mode diffuse_lambert_wrap, specular_schlick_ggx;

uniform float velvet : hint_range(0.0, 1.0) = 0.05;
uniform float rim_amount : hint_range(0.0, 1.0) = 0.04;
// Plafond de l'albédo : les pelages blancs ou crème ne brûlent pas sous une lampe de table.
uniform float max_albedo : hint_range(0.5, 1.0) = 0.72;

vec3 to_linear(vec3 c) {
	return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, step(c, vec3(0.04045)));
}

void fragment() {
	vec3 c = to_linear(COLOR.rgb);
	float emit = UV.y;
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fres = pow(1.0 - facing, 2.5);
	float soft = step(0.55, UV.x);
	vec3 a = c * (1.0 + fres * velvet * soft);
	// On baisse la luminosité sans changer la teinte (un blanc crème reste crème).
	ALBEDO = a * min(1.0, max_albedo / max(max(a.r, a.g), max(a.b, 0.001)));
	ROUGHNESS = UV.x;
	SPECULAR = mix(0.5, 0.25, soft);
	RIM = rim_amount * soft;
	RIM_TINT = 0.7;
	EMISSION = c * emit * 1.6;
}
