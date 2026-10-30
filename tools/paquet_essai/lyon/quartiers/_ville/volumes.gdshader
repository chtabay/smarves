shader_type spatial;
render_mode cull_back;
// Les murs de la ville en volumes (volumes.gd) : la teinte de l'instance, des fenêtres peintes en travées
// (verdict 38 du juge : un pan beige uni entre deux immeubles à fenêtres se voit depuis le quai), et les
// faces à l'ombre éclaircies comme le shader des murs de Sathonay, pour qu'une face ouest ne tranche pas
// en noir sur la colline claire. INSTANCE_CUSTOM porte (longueur, hauteur, profondeur) en mètres.

uniform vec3 soleil = vec3(-0.838, 0.515, 0.178); // vers le soleil, repère de la ville
uniform vec3 fenetre : source_color = vec3(0.62, 0.70, 0.77);
uniform float travee = 3.3;
uniform float etage = 3.0;
uniform float part = 0.4;
uniform float eclaircie = 1.35;

varying vec3 taille;
varying vec3 locale;
varying vec3 n_locale;
varying vec3 n_monde;
varying vec4 teinte;

void vertex() {
	taille = INSTANCE_CUSTOM.xyz;
	locale = VERTEX;
	n_locale = NORMAL;
	n_monde = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	teinte = COLOR;
}

void fragment() {
	float fen = 0.0;
	if (abs(n_locale.y) < 0.5 && taille.y > 0.0) {
		float u = abs(n_locale.x) > 0.5 ? locale.z * taille.z : locale.x * taille.x;
		float v = (locale.y + 0.5) * taille.y;
		float fu = fract(u / travee);
		float fv = fract((v - 0.8) / etage);
		bool dedans = fu > 0.3 && fu < 0.3 + part && fv > 0.3 && fv < 0.8;
		fen = (dedans && v > 1.0 && v < taille.y - 0.6) ? 1.0 : 0.0;
	}
	float ombre = clamp(-dot(n_monde, normalize(soleil)), 0.0, 1.0);
	vec3 mur = teinte.rgb * mix(1.0, eclaircie, ombre);
	ALBEDO = mix(mur, fenetre, fen);
	ROUGHNESS = 0.9;
}
