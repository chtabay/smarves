shader_type spatial;
render_mode unshaded, cull_back;
// Casino Minuit (variante lumineuse, sans éclairage : l'onyx rétroéclairé) : une texture de la DA du moteur web (moquettes, damier, bois, velours, capiton, caissons, marbres),
// posée en dalles de taille réelle dans le repère de la zone : vue d'en haut ou d'en bas, en (x, z) ; vue de côté,
// en (horizontale, -y), le bas de l'image au sol (galon du velours, plinthe du bois). Les maillages fusionnés n'ont
// pas d'UV utiles : la projection les remplace, nette (pas de fondu entre les trois plans).
uniform sampler2D motif : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 dalle = vec2(2.0, 2.0);
uniform vec2 origine = vec2(0.0);
uniform vec3 teinte : source_color = vec3(1.0);
uniform float rugosite = 0.9;
uniform float metal = 0.0;
uniform float speculaire = 0.5;
uniform float lueur = 0.0;
uniform float gain = 1.0;
uniform float contraste = 1.0;
varying vec3 lpos;
varying vec3 lnor;
void vertex() {
	lpos = VERTEX;
	lnor = NORMAL;
}
void fragment() {
	vec3 n = abs(lnor);
	vec2 uv;
	if (n.y >= max(n.x, n.z)) {
		uv = (lpos.xz - origine) / dalle;
	} else if (n.x >= n.z) {
		uv = vec2(lpos.z, -lpos.y) / dalle;
	} else {
		uv = vec2(lpos.x, -lpos.y) / dalle;
	}
	vec3 t = texture(motif, vec2(uv.x, -uv.y)).rgb;
	vec3 moyenne = textureLod(motif, vec2(0.5), 12.0).rgb;
	vec3 c = mix(moyenne, t, contraste) * teinte;
	ALBEDO = c * gain;
}
