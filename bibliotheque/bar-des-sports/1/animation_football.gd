extends Node3D
## Séquence dessinée d'ambiance, sans lien avec les rencontres ou les scores réels.
## Un seul quad sans lumière, texture, requête réseau ni mise à jour GDScript par image.
## Le parent porte en permanence l'étiquette « ANIMATION D'AMBIANCE ».

const CODE_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, fog_disabled;

uniform vec4 equipe_a : source_color = vec4(0.94, 0.70, 0.22, 1.0);
uniform vec4 equipe_b : source_color = vec4(0.34, 0.63, 0.91, 1.0);
uniform float decalage = 0.0;
uniform float sens = 1.0;
uniform float temps_test = -1.0;

float segment(vec2 p, vec2 a, vec2 b) {
	vec2 ab = b - a;
	return length(p - a - ab * clamp(dot(p - a, ab) / max(dot(ab, ab), 0.00001), 0.0, 1.0));
}
float cadre(vec2 p, vec2 demi) {
	vec2 d = abs(p) - demi;
	return abs(length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0));
}
float trait(float d, float largeur, float aa) {
	return 1.0 - smoothstep(largeur, largeur + aa, d);
}
vec2 formation(int i) {
	if (i == 0) return vec2(-0.855, 0.0);
	if (i == 1) return vec2(-0.57, -0.27);
	if (i == 2) return vec2(-0.55, 0.27);
	if (i == 3) return vec2(-0.25, -0.34);
	if (i == 4) return vec2(-0.16, 0.21);
	if (i == 5) return vec2(0.12, -0.18);
	if (i == 6) return vec2(0.12, 0.33);
	return vec2(0.32, 0.02);
}
vec2 joueur(int i, int equipe, float t) {
	vec2 p = formation(i);
	float attaque = smoothstep(0.0, 12.7, t);
	float repos = 1.0 - smoothstep(15.6, 17.9, t);
	float mouvement = attaque * repos;
	if (equipe == 1) {
		p.x = -p.x;
		p.y = -p.y;
	}
	if (i == 0) {
		p.y += 0.035 * sin(t * 0.75);
		if (equipe == 1) {
			// Le gardien accompagne le tir et se couche vers le ballon.
			float plongeon = smoothstep(12.7, 13.45, t) * (1.0 - smoothstep(15.7, 17.5, t));
			p += vec2(0.026, -0.095) * plongeon;
		}
	} else {
		p.x += mouvement * (equipe == 0 ? 0.22 : 0.135);
		p.y += 0.018 * sin(t * 0.9 + float(i) * 2.1 + float(equipe));
		p.x += 0.012 * sin(t * 1.25 + float(i) * 1.4);
		if (equipe == 0 && i == 7) p.x += mouvement * 0.13;
		if (equipe == 0 && i == 5) p.y -= mouvement * 0.075;
	}
	return p;
}
vec2 dribble(int i, float t) {
	return joueur(i, 0, t) + vec2(0.029 + 0.005 * sin(t * 8.0), -0.007);
}
vec2 ballon(float t) {
	if (t < 3.0) return dribble(4, t);
	if (t < 3.75) return mix(dribble(4, t), dribble(3, t), smoothstep(3.0, 3.75, t));
	if (t < 5.8) return dribble(3, t);
	if (t < 6.65) return mix(dribble(3, t), dribble(6, t), smoothstep(5.8, 6.65, t));
	if (t < 9.8) return dribble(6, t);
	if (t < 10.45) return mix(dribble(6, t), dribble(7, t), smoothstep(9.8, 10.45, t));
	if (t < 12.7) return dribble(7, t);
	if (t < 13.45) return mix(dribble(7, t), vec2(0.959, -0.08), smoothstep(12.7, 13.45, t));
	return vec2(0.959 - 0.012 * smoothstep(13.45, 14.1, t), -0.08);
}

void fragment() {
	float horloge = temps_test < 0.0 ? TIME : temps_test;
	float t = mod(horloge + decalage, 18.0);
	vec2 p = vec2((UV.x - 0.5) * 2.0 * sens, (0.5 - UV.y) * 1.20);
	float aa = max(fwidth(p.x), fwidth(p.y));
	// Projection de télévision : terrain complet et légère compression de sa profondeur.
	float terrain = 1.0 - smoothstep(0.0, aa, max(abs(p.x) - 0.90, abs(p.y) - 0.48));
	vec3 couleur = vec3(0.035, 0.065, 0.085);
	float bande = mod(floor((p.x + 0.90) / (1.8 / 14.0)), 2.0);
	vec3 pelouse = mix(vec3(0.085, 0.285, 0.12), vec3(0.13, 0.365, 0.17), bande);
	pelouse += 0.009 * sin(p.x * 180.0) * sin(p.y * 200.0) / (1.0 + aa * 300.0);
	couleur = mix(couleur, pelouse, terrain);
	// Périphérie sobre : pas de pointillés de sièges qui produisent du moiré à distance.
	float tribune = smoothstep(0.55, 0.59, abs(p.y));
	couleur = mix(couleur, vec3(0.055, 0.085, 0.105), tribune);
	float barriere = trait(abs(abs(p.y) - 0.52), 0.009, aa) * step(abs(p.x), 0.98);
	couleur = mix(couleur, vec3(0.12, 0.29, 0.31), barriere);
	// Touches, ligne médiane, surfaces, rond central et points de réparation.
	float ligne = cadre(p, vec2(0.90, 0.48));
	ligne = min(ligne, segment(p, vec2(0.0, -0.48), vec2(0.0, 0.48)));
	ligne = min(ligne, abs(length(p) - 0.13));
	ligne = min(ligne, length(p) - 0.0035);
	for (int cote = 0; cote < 2; cote++) {
		float signe = cote == 0 ? -1.0 : 1.0;
		vec2 q = vec2(p.x * signe, p.y);
		ligne = min(ligne, segment(q, vec2(0.64, -0.295), vec2(0.64, 0.295)));
		ligne = min(ligne, segment(q, vec2(0.64, -0.295), vec2(0.90, -0.295)));
		ligne = min(ligne, segment(q, vec2(0.64, 0.295), vec2(0.90, 0.295)));
		ligne = min(ligne, segment(q, vec2(0.81, -0.135), vec2(0.81, 0.135)));
		ligne = min(ligne, segment(q, vec2(0.81, -0.135), vec2(0.90, -0.135)));
		ligne = min(ligne, segment(q, vec2(0.81, 0.135), vec2(0.90, 0.135)));
		ligne = min(ligne, length(q - vec2(0.73, 0.0)) - 0.0035);
		if (q.x < 0.64) ligne = min(ligne, abs(length(q - vec2(0.73, 0.0)) - 0.13));
		for (int coin = 0; coin < 2; coin++) {
			float y = coin == 0 ? -0.48 : 0.48;
			if (q.x < 0.90 && abs(p.y) < 0.48) ligne = min(ligne, abs(length(q - vec2(0.90, y)) - 0.037));
		}
		float filet = step(0.90, q.x) * step(q.x, 0.975) * step(abs(q.y), 0.104);
		vec2 maille = abs(fract((q - vec2(0.90, -0.104)) * vec2(150.0, 105.0)) - 0.5);
		float treillis = step(0.38, max(maille.x, maille.y));
		couleur = mix(couleur, vec3(0.38, 0.43, 0.40), filet * (0.22 + treillis * 0.42));
		float but = min(segment(q, vec2(0.90, -0.104), vec2(0.975, -0.104)), segment(q, vec2(0.90, 0.104), vec2(0.975, 0.104)));
		but = min(but, segment(q, vec2(0.975, -0.104), vec2(0.975, 0.104)));
		couleur = mix(couleur, vec3(0.77, 0.80, 0.71), trait(but, 0.0035, aa));
	}
	couleur = mix(couleur, vec3(0.71, 0.78, 0.60), trait(ligne, 0.0028, aa) * 0.90);
	// Seize joueurs. Silhouette en pastille lisible, liseré et orientation du corps.
	vec2 balle = ballon(t);
	for (int equipe = 0; equipe < 2; equipe++) {
		for (int i = 0; i < 8; i++) {
			vec2 centre = joueur(i, equipe, t);
			vec2 dp = (p - centre) * vec2(1.0, 0.675);
			vec2 direction = normalize((balle - centre) * vec2(1.0, 0.675) + vec2(0.0001, 0.0));
			float ombre = trait(length(dp - vec2(0.008, -0.010)), 0.022, aa * 1.5);
			couleur = mix(couleur, vec3(0.025, 0.07, 0.04), ombre * 0.58);
			float corps = length(dp * vec2(1.0, 0.88));
			couleur = mix(couleur, vec3(0.80, 0.82, 0.69), trait(corps, 0.020, aa));
			vec3 maillot = equipe == 0 ? equipe_a.rgb : equipe_b.rgb;
			if (i == 0) maillot = equipe == 0 ? vec3(0.79, 0.39, 0.20) : vec3(0.48, 0.34, 0.70);
			couleur = mix(couleur, maillot, trait(corps, 0.016, aa));
			float tete = trait(length(dp - direction * 0.009), 0.0065, aa);
			couleur = mix(couleur, vec3(0.83, 0.69, 0.49), tete);
		}
	}
	// Le ballon reste lié au porteur, puis à une passe et enfin au tir vers le but.
	vec2 db = (p - balle) * vec2(1.0, 0.675);
	couleur = mix(couleur, vec3(0.02, 0.05, 0.025), trait(length(db - vec2(0.006, -0.006)), 0.013, aa));
	couleur = mix(couleur, vec3(0.94, 0.88, 0.69), trait(length(db), 0.010, aa));
	couleur = mix(couleur, vec3(0.15, 0.18, 0.14), trait(length(db - vec2(0.0015, 0.0015)), 0.003, aa));
	// Fondu de boucle bref, avec le terrain conservé : aucun flash blanc ni faux résultat.
	float fondu = smoothstep(0.0, 0.5, t) * (1.0 - smoothstep(16.8, 18.0, t));
	float vignette = 1.0 - 0.12 * dot(UV - 0.5, UV - 0.5);
	ALBEDO = couleur * mix(0.30, 1.0, fondu) * vignette;
}
"""

static var _shader: Shader
var _matiere: ShaderMaterial
var _construit := false

func construire(canal: String, couleur_a: Color, couleur_b: Color, variante: int = 0) -> void:
	if _construit: return
	_construit = true
	name = "AnimationFootball_" + canal
	set_meta("animation_ambiance", true)
	set_meta("donnees_sportives", false)
	set_meta("duree_boucle_secondes", 18.0)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = CODE_SHADER
	_matiere = ShaderMaterial.new()
	_matiere.shader = _shader
	_matiere.set_shader_parameter("equipe_a", couleur_a)
	_matiere.set_shader_parameter("equipe_b", couleur_b)
	_matiere.set_shader_parameter("decalage", float(posmod(variante, 3)) * 5.8)
	_matiere.set_shader_parameter("sens", -1.0 if posmod(variante, 2) == 1 else 1.0)
	var dalle := MeshInstance3D.new()
	dalle.name = "SequenceDessinee"
	var quad := QuadMesh.new()
	quad.size = Vector2(2.96, 1.10)
	dalle.mesh = quad
	dalle.material_override = _matiere
	# Laisse une vraie séparation avec le bandeau des rencontres sous le terrain.
	dalle.position = Vector3(0.0, -0.015, 0.114)
	dalle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dalle)
	set_process(false)

## Permet de comparer des captures déterministes sans simulation ni réseau.
## Une valeur négative rend immédiatement la main à l'horloge du shader.
func fixer_temps_pour_test(secondes: float) -> void:
	if _matiere != null:
		_matiere.set_shader_parameter("temps_test", secondes)
