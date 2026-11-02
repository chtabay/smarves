extends Node3D
## Le Dessous, le monde sous toutes les cartes (scenes/dessous.tscn ; le passage est dans
## scripts/socle/dessous.gd, autoload « Dessous »). Le même pour toutes les communes : il fait partie du socle.
##
## Le motif vient de la cosmologie indienne, où la terre repose sur des éléphants debout sur une tortue :
## un disque de terre et d'eau, posé sur le dos de quatre éléphants des points cardinaux (Airâvata, Vâmana,
## Anjana, Sârvabhauma), eux-mêmes debout sur la carapace d'Akoupara, la tortue qui nage dans les étoiles.
## La Lanterne, un petit soleil, en fait le tour : elle passe au-dessus du disque, puis dessous, et la nuit
## tombe. L'océan déborde du bord du disque en une cascade.
##
## Le disque est un petit pays (Guillaume, 2 novembre 2026 : « il faut qu'on ait l'impression que le monde est
## un petit pays comme la France, avec des reliefs, des côtes ») : des mers et des golfes, des caps qui vont
## jusqu'au bord, des chaînes de montagnes enneigées, le mont Meru au centre, la montagne d'or des récits
## indiens, des fleuves, des forêts, des champs en damier et des villages. Le relief est tiré d'un bruit fixe
## (hauteur()), le même à chaque passage.
##
## On arrive dans une clairière, au bord d'une plaine : c'est l'origine de la scène, le disque est décalé en
## CENTRE. La Porte des Joints y ramène là où l'on est tombé (Dessous.remonter).
##
## L'arrivée est mise en scène, sans un mot (« pas de texte ») : le monde entier de loin, puis la caméra passe
## le bord, survole le pays et le Meru, descend vers la clairière, et l'image se fond au noir avant de toucher
## le sol (« pas besoin de montrer l'atterrissage ») ; on rouvre les yeux dans la clairière. Une touche ou un
## clic passe la mise en scène. Pour les captures : `--plan=secondes` fige l'arrivée à cet instant
## (tools/capture_dessous.gd).
##
## L'habitant mesure 0,7, comme dans les communes : le disque fait 510 de rayon, plus de sept cents fois sa taille.

## Les crans de la caméra de dessus, comme le kit des communes : distance, tangage, champ.
const CRANS := [[9.0, -48.0, 34.0], [18.0, -51.0, 30.0], [32.0, -58.0, 30.0]]
## La clairière où l'on marche (rayon).
const ILE := 22.0
## L'échelle du monde : K fois le premier Dessous (un disque de 30).
const K := 17.0
## Le disque (rayon) et son épaisseur de roche, sous le niveau de la mer.
const DISQUE := 510.0
const EPAISSEUR := 68.0
## La clairière dans le disque (x, z depuis le centre), et sa hauteur au-dessus de la mer.
const CLAIRIERE := Vector2(150.0, 205.0)
const SOL_CLAIRIERE := 3.0
## Le centre du disque, au niveau de la mer, dans la scène (la clairière est à l'origine).
const CENTRE := Vector3(-150.0, -3.0, -205.0)
## Le mont Meru, au centre : sa hauteur et son rayon.
const MERU := 105.0
const MERU_R := 62.0
## Le maillage du relief : tant de carreaux d'un bord à l'autre.
const RESOLUTION := 280
## Où l'on arrive, et la Porte des Joints en face.
const ARRIVEE := Vector3(0.0, 0.0, 3.0)
const PORTE := Vector3(0.0, 0.0, -4.0)
## La carapace d'Akoupara : son centre (sous le disque) et ses demi-axes (largeur, hauteur, longueur).
const CARAPACE_Y := -748.0
const CARAPACE := Vector3(935.0, 374.0, 1054.0)
## Les éléphants, à cette distance du centre, sous le disque.
const ELEPHANTS_R := 272.0
const ELEPHANTS := ["Airâvata", "Vâmana", "Anjana", "Sârvabhauma"]
## La Lanterne : le centre de sa course (depuis le centre du disque), son rayon, sa période (secondes),
## l'angle de départ.
const LANTERNE_CENTRE := Vector3(0.0, -340.0, 0.0)
const LANTERNE_R := 2040.0
const LANTERNE_TOUR := 300.0
const LANTERNE_DEPART := 62.0
## L'arrivée : la vue de loin, le survol, le noir, la main rendue.
const T_LOIN := 4.2
const T_NOIR := 10.4
const T_FIN := 11.4

## Pour le jeu (vue, tactile) : l'habitant qu'on dirige et la caméra à crans.
var player: CharacterBody3D
var camera: Camera3D
## L'invite « E : … » (Tactile en fait un bouton).
var _prompt: Label
var porte: Area3D
var lanterne: Node3D
var soleil: DirectionalLight3D

var _t := 0.0
var _arrivee := 0.0
var _en_arrivee := true
var _figee := -1.0
var _plan: Camera3D
var _env: Environment
var _couronne: Node3D
var _matieres_nuages: Array = []
var _bandes: Array = []
var _noir: ColorRect
var _bruits := {}
var _nageoires: Array = []
var _jour := 1.0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--plan="):
			_figee = float(a.trim_prefix("--plan="))
	_ciel()
	_relief()
	_porteurs()
	_ile()
	_porte()
	_lanterne()
	_nuages()
	_interface()
	_joueur()
	Sfx.musique("titre")
	_poser_plan(_figee if _figee >= 0.0 else 0.0)


# --- Le ciel et la lumière -----------------------------------------------------------------------------

func _ciel() -> void:
	var sh := Shader.new()
	sh.code = """shader_type sky;
// Le ciel du Dessous : un fond d'encre, deux nébuleuses (violette et bleu canard), la bande laiteuse et ses
// lanes de poussière, trois couches d'étoiles qui scintillent, plus denses dans la bande. Il tourne
// lentement, comme si Akoupara nageait.
float h31(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}
float bruit(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h31(i), h31(i + vec3(1, 0, 0)), f.x), mix(h31(i + vec3(0, 1, 0)), h31(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(h31(i + vec3(0, 0, 1)), h31(i + vec3(1, 0, 1)), f.x), mix(h31(i + vec3(0, 1, 1)), h31(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}
float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * bruit(p);
		p = p * 2.03 + vec3(1.7, 9.2, 3.1);
		a *= 0.5;
	}
	return v;
}
void sky() {
	float r = TIME * 0.004;
	vec3 d = vec3(EYEDIR.x * cos(r) - EYEDIR.z * sin(r), EYEDIR.y, EYEDIR.x * sin(r) + EYEDIR.z * cos(r));
	vec3 col = mix(vec3(0.004, 0.005, 0.016), vec3(0.018, 0.016, 0.05), 0.5 + 0.5 * d.y);
	float n1 = fbm(d * 2.1 + vec3(3.1, 0.0, 0.0));
	float n2 = fbm(d * 2.9 + vec3(0.0, 7.3, 1.2));
	col += vec3(0.30, 0.08, 0.36) * smoothstep(0.5, 0.86, n1) * 0.6;
	col += vec3(0.04, 0.20, 0.32) * smoothstep(0.52, 0.9, n2) * 0.55;
	col += vec3(0.5, 0.25, 0.15) * pow(smoothstep(0.62, 0.95, n1 * n2 * 1.9), 2.0) * 0.4;
	float b = dot(d, normalize(vec3(0.35, 1.0, 0.25)));
	float bande = exp(-b * b * 8.0);
	float poussiere = fbm(d * 7.0);
	col += vec3(0.17, 0.14, 0.21) * bande * (0.35 + 0.9 * poussiere);
	col *= 1.0 - 0.6 * bande * smoothstep(0.52, 0.68, fbm(d * 11.0 + 4.0));
	for (int k = 0; k < 3; k++) {
		vec3 p = d * (150.0 + float(k) * 110.0);
		vec3 c = floor(p);
		float h = h31(c + float(k) * 13.0);
		float seuil = 0.975 - bande * 0.03 + float(k) * 0.006;
		if (h > seuil) {
			vec3 f = fract(p) - 0.5;
			float s = 1.0 - smoothstep(0.0, 0.2 - float(k) * 0.04, length(f));
			float teinte = fract(h * 91.7);
			float scint = 0.75 + 0.25 * sin(TIME * (1.5 + teinte * 3.0) + h * 400.0);
			col += s * scint * (h - seuil) * 70.0 * mix(vec3(1.0, 0.82, 0.62), vec3(0.7, 0.82, 1.0), teinte);
		}
	}
	COLOR = max(col, vec3(0.0));
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var sky := Sky.new()
	sky.sky_material = mat
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.4, 0.43, 0.66)
	_env.ambient_light_energy = 0.5
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_env.tonemap_mode = Environment.TONE_MAPPER_ACES
	_env.tonemap_exposure = 0.92
	_env.tonemap_white = 6.0
	_env.glow_enabled = true
	_env.glow_intensity = 0.85
	_env.glow_strength = 1.1
	_env.glow_bloom = 0.06
	_env.glow_hdr_threshold = 0.9
	_env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	for i in 7:
		_env.set_glow_level(i, 1.0 if i in [2, 3, 4, 5] else 0.0)
	_env.ssao_enabled = true
	_env.ssao_radius = 2.0
	_env.ssao_intensity = 1.6
	# La perspective aérienne : le lointain bleuit. Sa densité suit la caméra (_brume) : légère de loin, pour
	# voir tout le monde, plus dense au ras du pays, pour que les montagnes au loin s'estompent.
	_env.fog_enabled = true
	_env.fog_light_color = Color(0.32, 0.4, 0.6)
	_env.fog_density = 0.0001
	_env.fog_sky_affect = 0.0
	_env.adjustment_enabled = true
	_env.adjustment_contrast = 1.08
	_env.adjustment_saturation = 1.05
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	soleil = DirectionalLight3D.new()
	soleil.name = "Soleil"
	soleil.light_color = Color(1.0, 0.88, 0.7)
	soleil.light_energy = 1.25
	soleil.shadow_enabled = true
	soleil.shadow_blur = 1.5
	soleil.directional_shadow_max_distance = 3000.0
	add_child(soleil)
	# Une lumière de lune, bleue et faible, d'en face : les ombres ne sont jamais tout à fait noires.
	var contre := DirectionalLight3D.new()
	contre.name = "Contre"
	contre.light_color = Color(0.45, 0.55, 1.0)
	contre.light_energy = 0.22
	contre.rotation = Vector3(deg_to_rad(-35.0), deg_to_rad(200.0), 0.0)
	add_child(contre)


## La brume suit la caméra : presque rien vu de l'espace, un voile bleu au ras du pays.
func _brume() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var d := cam.global_position.distance_to(CENTRE)
	var haut := cam.global_position.y - CENTRE.y
	var pres := 1.0 - smoothstep(700.0, 2600.0, d)
	var ras := pres * (1.0 - smoothstep(60.0, 600.0, haut)) * smoothstep(-30.0, 10.0, haut)
	_env.fog_density = lerpf(0.00005, 0.0008, ras * 0.8 + 0.2 * pres)
	# De l'espace, la brume est la nuit bleue ; au ras du pays, un voile clair, doré au couchant.
	var clair := Color(0.08, 0.1, 0.2).lerp(Color(0.62, 0.68, 0.8), _jour)
	_env.fog_light_color = Color(0.06, 0.08, 0.18).lerp(clair, ras)


## Un matériau de nuage ou de brume : une boule de bruit douce, en face de la caméra, éclairée du côté de la
## Lanterne. `jour` (0 à 1) assombrit les nuages la nuit.
func _matiere_nuage(teinte: Color, opacite: float, plat := false) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, blend_mix;
uniform vec4 teinte : source_color = vec4(1.0);
uniform float opacite = 0.5;
uniform float jour = 1.0;
uniform float graine = 0.0;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float b(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y);
}
float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) { v += a * b(p); p *= 2.1; a *= 0.5; }
	return v;
}
%s
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float n = fbm(UV * 3.0 + graine + TIME * 0.01);
	float a = smoothstep(1.0, 0.25, r + (n - 0.5) * %s);
	float haut = %s;
	vec3 c = teinte.rgb * mix(0.55, 1.0, haut) * mix(0.3, 1.0, jour);
	ALBEDO = c;
	ALPHA = a * opacite * (1.0 - smoothstep(0.8, 1.0, r));
}
""" % ["" if plat else """void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}""", "1.3" if plat else "0.7", "0.6 + 0.4 * n" if plat else "clamp(0.5 - q.y * 0.5, 0.0, 1.0)"]
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("teinte", teinte)
	m.set_shader_parameter("opacite", opacite)
	return m


## Les nuages : des cumulus au-dessus du pays, qui jettent leur blancheur sur les plaines vues d'en haut ; une
## mer de nuages sur le dos d'Akoupara, où les éléphants ont de la brume jusqu'aux genoux, et des bancs plus
## loin sous la carapace. Ils dérivent lentement autour du monde.
func _nuages() -> void:
	_couronne = Node3D.new()
	_couronne.name = "Nuages"
	_couronne.position = CENTRE
	add_child(_couronne)
	var g := RandomNumberGenerator.new()
	g.seed = 31
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var nappe := PlaneMesh.new()
	nappe.size = Vector2(1, 1)
	var bancs := [
		# nombre, rayon min, rayon max, hauteur min, max, taille min, max, opacité min, max, teinte
		[70, 40.0, 480.0, 85.0, 110.0, 30.0, 85.0, 0.5, 0.85, Color(1.0, 0.99, 0.97)],
		[40, 410.0, 780.0, -460.0, -320.0, 150.0, 255.0, 0.25, 0.45, Color(0.95, 0.93, 1.0)],
		[34, 1190.0, 2720.0, -1275.0, -935.0, 680.0, 1360.0, 0.15, 0.3, Color(0.62, 0.66, 0.95)],
	]
	for b in bancs:
		for i in int(b[0]):
			var a := g.randf() * TAU
			var r := sqrt(g.randf_range(pow(b[1] / b[2], 2.0), 1.0)) * float(b[2])
			var p := Vector3(cos(a) * r, g.randf_range(b[3], b[4]), sin(a) * r)
			# Pas de nuage dans le ciel de la clairière : on la voit d'en haut, en jouant.
			if b[3] > 0.0 and Vector2(p.x, p.z).distance_to(CLAIRIERE) < 120.0:
				continue
			# Au-dessus du pays, des nappes à plat, comme vues d'avion ; dessous, des boules face à la caméra.
			var plat: bool = b[3] > 0.0
			var m := _matiere_nuage(b[9], g.randf_range(b[7], b[8]), plat)
			m.set_shader_parameter("graine", g.randf() * 50.0)
			_matieres_nuages.append(m)
			var taille := g.randf_range(b[5], b[6])
			var mi := _piece(_couronne, nappe if plat else quad, m, p, Vector3(0, g.randf() * TAU, 0),
				Vector3(taille, 1.0, taille * g.randf_range(0.5, 0.9)) if plat else Vector3.ONE * taille)
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# La brume de la cascade, tout autour du bord, et des lucioles d'or dans la clairière.
	var brume := CPUParticles3D.new()
	brume.name = "Brume"
	brume.amount = 320
	brume.lifetime = 6.0
	brume.preprocess = 6.0
	brume.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	brume.emission_ring_axis = Vector3.UP
	brume.emission_ring_radius = DISQUE + 22.0
	brume.emission_ring_inner_radius = DISQUE + 4.0
	brume.emission_ring_height = 20.0
	brume.position = CENTRE + Vector3(0, -EPAISSEUR, 0)
	brume.direction = Vector3(0, -1, 0)
	brume.spread = 25.0
	brume.gravity = Vector3(0, -10.0, 0)
	brume.initial_velocity_min = 5.0
	brume.initial_velocity_max = 20.0
	brume.scale_amount_min = 34.0
	brume.scale_amount_max = 76.0
	var courbe := Curve.new()
	courbe.add_point(Vector2(0, 0.3))
	courbe.add_point(Vector2(0.4, 1.0))
	courbe.add_point(Vector2(1, 1.4))
	brume.scale_amount_curve = courbe
	var rampe := Gradient.new()
	rampe.set_color(0, Color(1, 1, 1, 0.0))
	rampe.add_point(0.25, Color(0.92, 0.96, 1.0, 0.35))
	rampe.set_color(rampe.get_point_count() - 1, Color(0.85, 0.9, 1.0, 0.0))
	brume.color_ramp = rampe
	brume.mesh = _quad_doux(Color(1, 1, 1, 1))
	add_child(brume)
	var lucioles := CPUParticles3D.new()
	lucioles.name = "Lucioles"
	lucioles.amount = 70
	lucioles.lifetime = 6.0
	lucioles.preprocess = 6.0
	lucioles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	lucioles.emission_box_extents = Vector3(9.0, 0.6, 9.0)
	lucioles.position = ARRIVEE + Vector3(0, 0.8, -3.0)
	lucioles.gravity = Vector3(0, 0.03, 0)
	lucioles.initial_velocity_min = 0.02
	lucioles.initial_velocity_max = 0.12
	lucioles.spread = 180.0
	lucioles.scale_amount_min = 0.06
	lucioles.scale_amount_max = 0.12
	var feu := Gradient.new()
	feu.set_color(0, Color(1.0, 0.8, 0.4, 0.0))
	feu.add_point(0.5, Color(1.0, 0.85, 0.45, 1.0))
	feu.set_color(feu.get_point_count() - 1, Color(1.0, 0.7, 0.3, 0.0))
	lucioles.color_ramp = feu
	lucioles.mesh = _quad_doux(Color(1, 1, 1, 1), true)
	add_child(lucioles)


## Un petit carré qui se tourne vers la caméra, au bord flou : brume, lucioles.
func _quad_doux(c: Color, lumineux := false) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(1, 1)
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, fog_disabled, %s;
uniform vec4 c : source_color = vec4(1.0);
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}
void fragment() {
	float r = length(UV * 2.0 - 1.0);
	float a = smoothstep(1.0, 0.0, r);
	ALBEDO = c.rgb * COLOR.rgb * %s;
	ALPHA = a * a * c.a * COLOR.a;
}
""" % ["blend_add" if lumineux else "blend_mix", "3.0" if lumineux else "1.0"]
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("c", c)
	q.material = m
	return q


# --- Les petites pièces ----------------------------------------------------------------------------------

func _mat(c: Color, rugueux := 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rugueux
	return m


func _piece(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, echelle := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = echelle
	parent.add_child(mi)
	return mi


func _boule(r := 1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 32
	s.rings = 16
	return s


# --- Le relief du pays ---------------------------------------------------------------------------------

func _bruit(nom: String, graine: int, frequence: float, octaves: int, arete := false) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = graine
	n.frequency = frequence
	n.fractal_type = FastNoiseLite.FRACTAL_RIDGED if arete else FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	_bruits[nom] = n
	return n


func _preparer_bruits() -> void:
	if not _bruits.is_empty():
		return
	_bruit("terre", 11, 0.0034, 5)
	_bruit("monts", 23, 0.005, 5, true)
	_bruit("chaines", 5, 0.0028, 3)
	_bruit("collines", 9, 0.02, 3)
	_bruit("fleuves", 3, 0.0042, 2)
	_bruit("humide", 41, 0.006, 3)
	_bruit("forets", 77, 0.011, 4)


## Ce qu'il y a en (x, z) du disque (depuis son centre) : la terre (> 0) ou la mer (< 0), et de combien.
func _continent(x: float, z: float) -> float:
	var r := Vector2(x, z).length() / DISQUE
	var c := (_bruits.terre as FastNoiseLite).get_noise_2d(x, z) * 1.3 + 0.12
	# La mer s'ouvre vers le bord, où elle déborde ; quelques caps vont pourtant jusqu'au vide.
	c -= 0.85 * smoothstep(0.7, 1.0, r)
	# Les terres hautes du milieu, autour du Meru.
	c += 0.8 * exp(-pow(r / 0.17, 2.0))
	# La clairière est sur la terre ferme, au bord d'une plaine.
	c = maxf(c, lerpf(0.32, -9.0, smoothstep(90.0, 170.0, Vector2(x, z).distance_to(CLAIRIERE))))
	return c


## La hauteur du pays en (x, z) du disque, au-dessus du niveau de la mer.
func hauteur(x: float, z: float) -> float:
	_preparer_bruits()
	var c := _continent(x, z)
	var h: float
	if c < 0.0:
		h = maxf(c * 70.0, -30.0)
	else:
		var terre := smoothstep(0.0, 0.4, c)
		h = 0.5 + c * 15.0 + (_bruits.collines as FastNoiseLite).get_noise_2d(x, z) * 4.0 * terre
		# Les chaînes de montagnes : des arêtes, là où le masque des chaînes le veut, loin des côtes.
		var m := ((_bruits.monts as FastNoiseLite).get_noise_2d(x, z) + 1.0) * 0.5
		var chaine := smoothstep(0.02, 0.38, (_bruits.chaines as FastNoiseLite).get_noise_2d(x, z))
		var loin := smoothstep(110.0, 230.0, Vector2(x, z).distance_to(CLAIRIERE))
		h += m * m * m * 72.0 * chaine * smoothstep(0.06, 0.45, c) * loin
		# Les fleuves : de longs méandres creusés dans les plaines, jusque sous le niveau de la mer.
		var rv := absf((_bruits.fleuves as FastNoiseLite).get_noise_2d(x, z))
		var lit := (1.0 - smoothstep(0.007, 0.022, rv)) * (1.0 - smoothstep(14.0, 26.0, h))
		h = lerpf(h, -0.9, lit)
	# Le Meru, la montagne d'or au milieu du monde.
	var dm := Vector2(x, z).length()
	var meru := exp(-pow(dm / MERU_R, 2.0))
	h += MERU * meru * (0.85 + 0.3 * ((_bruits.monts as FastNoiseLite).get_noise_2d(x * 2.0, z * 2.0) + 1.0) * 0.5)
	# La clairière, à plat.
	var w := 1.0 - smoothstep(28.0, 110.0, Vector2(x, z).distance_to(CLAIRIERE))
	return lerpf(h, SOL_CLAIRIERE - 0.04, w)


## La couleur du pays en un point de hauteur h, de pente `n` (sa normale) : les fonds marins, le sable, les
## prairies et les forêts, la roche, la neige, l'or du Meru. L'alpha dit où sont les champs (le shader les
## dessine en damier, avec des villages).
func _teinte(x: float, z: float, h: float, n: Vector3) -> Color:
	if h < 0.0:
		var d := -h
		if d < 1.5:
			return Color(0.3, 0.66, 0.62, 0.0)
		var fond := Color(0.3, 0.66, 0.62).lerp(Color(0.06, 0.2, 0.33), smoothstep(1.5, 12.0, d)).lerp(Color(0.03, 0.08, 0.18), smoothstep(12.0, 28.0, d))
		fond.a = 0.0
		return fond
	if h < 1.3:
		return Color(0.84, 0.77, 0.56, 0.0)
	var humide := (_bruits.humide as FastNoiseLite).get_noise_2d(x, z) * 0.5 + 0.5
	var c := Color(0.56, 0.58, 0.3).lerp(Color(0.24, 0.46, 0.18), smoothstep(0.3, 0.7, humide))
	var foret := smoothstep(0.08, 0.2, (_bruits.forets as FastNoiseLite).get_noise_2d(x, z)) * (1.0 - smoothstep(30.0, 42.0, h))
	c = c.lerp(Color(0.17, 0.33, 0.14), foret)
	var champs := (1.0 - foret) * smoothstep(2.0, 4.0, h) * (1.0 - smoothstep(12.0, 20.0, h)) * smoothstep(0.85, 0.95, n.y)
	champs *= smoothstep(130.0, 210.0, Vector2(x, z).distance_to(CLAIRIERE))
	# En montant : l'alpage, la roche aux pentes raides, la neige aux sommets.
	c = c.lerp(Color(0.4, 0.42, 0.3), smoothstep(22.0, 36.0, h))
	c = c.lerp(Color(0.46, 0.43, 0.41), (1.0 - smoothstep(0.62, 0.8, n.y)) * smoothstep(6.0, 16.0, h))
	c = c.lerp(Color(0.96, 0.97, 1.0), smoothstep(40.0, 50.0, h) * smoothstep(0.5, 0.7, n.y))
	# Le haut du Meru est d'or.
	var dm := Vector2(x, z).length()
	c = c.lerp(Color(0.93, 0.8, 0.5), smoothstep(MERU * 0.75, MERU * 1.0, h) * (1.0 - smoothstep(MERU_R * 0.4, MERU_R * 0.8, dm)))
	c.a = champs
	return c


## Le pays : un maillage carré posé sur le disque (les sommets du dehors ramenés sur le bord), sa falaise
## tout autour, le dessous de roche, la mer et la cascade où elle déborde.
func _relief() -> void:
	_preparer_bruits()
	var n := RESOLUTION
	var cote := n + 1
	var pas := 2.0 * DISQUE / n
	var pos := PackedVector3Array()
	pos.resize(cote * cote)
	var dedans := PackedByteArray()
	dedans.resize(cote * cote)
	for j in cote:
		for i in cote:
			var v := Vector2(-DISQUE + i * pas, -DISQUE + j * pas)
			dedans[j * cote + i] = 1 if v.length() <= DISQUE + pas * 0.75 else 0
			if v.length() > DISQUE:
				v = v.normalized() * DISQUE
			pos[j * cote + i] = Vector3(v.x, hauteur(v.x, v.y), v.y)
	var normales := PackedVector3Array()
	normales.resize(cote * cote)
	var couleurs := PackedColorArray()
	couleurs.resize(cote * cote)
	for j in cote:
		for i in cote:
			var k := j * cote + i
			var dx: Vector3 = pos[j * cote + mini(i + 1, n)] - pos[j * cote + maxi(i - 1, 0)]
			var dz: Vector3 = pos[mini(j + 1, n) * cote + i] - pos[maxi(j - 1, 0) * cote + i]
			var nn := dz.cross(dx)
			nn = nn.normalized() if nn.length_squared() > 0.000001 else Vector3.UP
			normales[k] = nn
			couleurs[k] = _teinte(pos[k].x, pos[k].z, pos[k].y, nn)
	var index := PackedInt32Array()
	for j in n:
		for i in n:
			var a := j * cote + i
			if dedans[a] == 0 and dedans[a + 1] == 0 and dedans[a + cote] == 0 and dedans[a + cote + 1] == 0:
				continue
			index.append_array([a, a + 1, a + cote, a + 1, a + cote + 1, a + cote])
	var tab := []
	tab.resize(Mesh.ARRAY_MAX)
	tab[Mesh.ARRAY_VERTEX] = pos
	tab[Mesh.ARRAY_NORMAL] = normales
	tab[Mesh.ARRAY_COLOR] = couleurs
	tab[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tab)
	var d := Node3D.new()
	d.name = "Disque"
	d.position = CENTRE
	add_child(d)
	var pays := _piece(d, mesh, _matiere_pays(), Vector3.ZERO)
	pays.name = "Pays"
	_falaise(d)
	_mer(d)
	# La clairière : un sol plat, à l'origine de la scène.
	var sol := StaticBody3D.new()
	sol.name = "Sol"
	var forme := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = ILE + 4.0
	cyl.height = 3.0
	forme.shape = cyl
	forme.position.y = -1.5
	sol.add_child(forme)
	add_child(sol)


## Le shader du pays : la couleur des sommets, un grain qui casse le maillage, et dans les plaines des champs
## en damier, bordés de haies, orientés par région, semés de villages aux toits rouges.
func _matiere_pays() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_back;
varying vec3 monde;
void vertex() { monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
float h21(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float b(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1, 0)), f.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), f.x), f.y);
}
vec3 lin(vec3 c) { return pow(c, vec3(2.2)); }
void fragment() {
	vec3 c = COLOR.rgb;
	vec2 p = monde.xz;
	float grain = b(p * 0.3) * 0.5 + b(p * 1.7) * 0.3 + b(p * 6.0) * 0.2;
	c *= 0.86 + 0.28 * grain;
	if (COLOR.a > 0.02) {
		float region = floor(b(p * 0.006) * 5.0);
		float ang = region * 0.55 + 0.3;
		vec2 q = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang))) * p;
		q /= vec2(4.2, 3.0);
		vec2 id = floor(q);
		vec2 f = fract(q);
		float r = h21(id + region * 17.0);
		vec3 champ = r < 0.28 ? vec3(0.74, 0.66, 0.34) : (r < 0.52 ? vec3(0.36, 0.52, 0.2) : (r < 0.7 ? vec3(0.5, 0.38, 0.25) : (r < 0.86 ? vec3(0.55, 0.64, 0.3) : vec3(0.66, 0.6, 0.42))));
		champ *= 0.9 + 0.2 * b(p * 0.9);
		float bord = min(min(f.x, 1.0 - f.x) * 4.2, min(f.y, 1.0 - f.y) * 3.0);
		champ = mix(vec3(0.2, 0.3, 0.14), champ, smoothstep(0.08, 0.3, bord));
		// Un village : quelques maisons serrées, les toits rouges et les murs clairs.
		if (h21(id * 1.37 + 4.1) > 0.965) {
			vec2 m = fract(q * vec2(5.0, 4.0));
			vec2 mid = floor(q * vec2(5.0, 4.0));
			float maison = step(0.45, h21(mid)) * step(0.2, m.x) * step(m.x, 0.8) * step(0.2, m.y) * step(m.y, 0.8);
			champ = mix(champ, mix(vec3(0.86, 0.82, 0.72), vec3(0.72, 0.32, 0.22), step(0.5, m.y)), maison);
		}
		// De loin, le damier se fond dans sa teinte moyenne (pas de moiré).
		vec2 fw = fwidth(q);
		champ = mix(champ, vec3(0.55, 0.56, 0.31), smoothstep(0.12, 0.5, max(fw.x, fw.y)));
		c = mix(c, champ, COLOR.a * 0.8);
	}
	ALBEDO = lin(c);
	ROUGHNESS = 0.95;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## La falaise du bord, des strates de roche, du haut du pays jusque sous le disque, et le dessous de roche
## sur lequel les éléphants portent le monde.
func _falaise(d: Node3D) -> void:
	var segments := 720
	var pos := PackedVector3Array()
	var norm := PackedVector3Array()
	var index := PackedInt32Array()
	for s in segments + 1:
		var a := TAU * s / segments
		var dir := Vector3(cos(a), 0, sin(a))
		var haut := hauteur(dir.x * DISQUE, dir.z * DISQUE)
		pos.append(dir * DISQUE + Vector3(0, haut, 0))
		pos.append(dir * (DISQUE - 6.0) + Vector3(0, -EPAISSEUR, 0))
		norm.append(dir)
		norm.append(dir)
		if s < segments:
			var k := s * 2
			index.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])
	var tab := []
	tab.resize(Mesh.ARRAY_MAX)
	tab[Mesh.ARRAY_VERTEX] = pos
	tab[Mesh.ARRAY_NORMAL] = norm
	tab[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tab)
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_disabled;
// Les strates de la roche du disque : des bandes ocre et brunes, ondulées.
varying vec3 local;
void vertex() { local = VERTEX; }
float h(float x) { return fract(sin(x * 91.7) * 43758.5453); }
void fragment() {
	float a = atan(local.z, local.x) * 80.0;
	float y = local.y + sin(a * 0.37) * 2.0 + sin(a * 0.11) * 4.0;
	float bande = floor(y / 5.0);
	float t = h(bande);
	vec3 c = mix(vec3(0.42, 0.31, 0.22), vec3(0.62, 0.5, 0.36), t);
	c = mix(c, vec3(0.25, 0.2, 0.17), smoothstep(0.85, 1.0, fract(y / 5.0)) * 0.6);
	ALBEDO = pow(c, vec3(2.2));
	ROUGHNESS = 0.95;
}
"""
	var roche := ShaderMaterial.new()
	roche.shader = sh
	var mi := _piece(d, mesh, roche, Vector3.ZERO)
	mi.name = "Falaise"
	var dessous := CylinderMesh.new()
	dessous.top_radius = DISQUE - 6.0
	dessous.bottom_radius = DISQUE * 0.55
	dessous.height = 30.0
	dessous.radial_segments = 128
	dessous.rings = 2
	_piece(d, dessous, _mat(Color(0.3, 0.23, 0.18)), Vector3(0, -EPAISSEUR - 15.0, 0))


## La mer, au niveau 0 du disque : profonde et sombre au large, transparente sur les hauts-fonds (le fond
## colorié du pays se voit à travers), avec une houle qui accroche la Lanterne. Et la cascade : l'océan qui
## déborde du bord, là où la mer touche le vide.
func _mer(d: Node3D) -> void:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
varying vec3 monde;
void vertex() { monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = monde.xz;
	float t = TIME;
	// La houle s'efface de loin, où elle ne ferait que scintiller en grille.
	float loin = 1.0 - smoothstep(0.4, 3.0, length(fwidth(p)));
	vec2 g = vec2(cos(p.x * 0.31 + t * 1.3) * 0.5 + cos(p.x * 0.11 + p.y * 0.07 - t * 0.7),
		cos(p.y * 0.27 - t * 1.1) * 0.5 + cos(p.y * 0.13 - p.x * 0.05 + t * 0.6)) * 0.035 * loin;
	vec3 n = normalize(vec3(g.x, 1.0, g.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = vec3(0.02, 0.1, 0.2);
	ROUGHNESS = mix(0.25, 0.08, loin);
	SPECULAR = 0.7;
	ALPHA = mix(0.42, 0.92, fres);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var mer := CylinderMesh.new()
	mer.top_radius = DISQUE - 0.3
	mer.bottom_radius = DISQUE - 0.3
	mer.height = 0.02
	mer.radial_segments = 256
	mer.rings = 1
	mer.cap_bottom = false
	var mi := _piece(d, mer, m, Vector3.ZERO)
	mi.name = "Mer"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# La cascade : une couronne qui part du bord et s'évase en tombant, effacée là où la terre touche le bord.
	var segments := 360
	var pos := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var index := PackedInt32Array()
	for s in segments + 1:
		var a := TAU * s / segments
		var dir := Vector3(cos(a), 0, sin(a))
		var eau := 1.0 - smoothstep(-0.6, 0.4, hauteur(dir.x * DISQUE, dir.z * DISQUE))
		pos.append(dir * (DISQUE + 0.4))
		pos.append(dir * (DISQUE + 70.0) + Vector3(0, -EPAISSEUR * 2.2, 0))
		uv.append(Vector2(float(s) / segments, 0.0))
		uv.append(Vector2(float(s) / segments, 1.0))
		col.append(Color(1, 1, 1, eau))
		col.append(Color(1, 1, 1, eau))
		if s < segments:
			var k := s * 2
			index.append_array([k, k + 1, k + 2, k + 1, k + 3, k + 2])
	var tab := []
	tab.resize(Mesh.ARRAY_MAX)
	tab[Mesh.ARRAY_VERTEX] = pos
	tab[Mesh.ARRAY_TEX_UV] = uv
	tab[Mesh.ARRAY_COLOR] = col
	tab[Mesh.ARRAY_INDEX] = index
	var chute := ArrayMesh.new()
	chute.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tab)
	var shc := Shader.new()
	shc.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
void fragment() {
	float v = UV.y;
	float x = UV.x * 360.0;
	float filet = 0.5 + 0.25 * sin(x * 1.7) + 0.25 * sin(x * 0.63 + 1.3);
	float flot = 0.5 + 0.5 * sin(v * 18.0 - TIME * 2.2 + sin(x * 0.9) * 2.0);
	float ecume = flot * filet;
	ALBEDO = mix(vec3(0.3, 0.55, 0.8), vec3(0.95, 0.98, 1.0), ecume * 0.7 + (1.0 - v) * 0.2);
	ALPHA = COLOR.a * pow(1.0 - v, 1.8) * (0.3 + 0.45 * ecume);
}
"""
	var mc := ShaderMaterial.new()
	mc.shader = shc
	var mic := _piece(d, chute, mc, Vector3.ZERO)
	mic.name = "Cascade"
	mic.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


# --- Les porteurs : les quatre éléphants et Akoupara --------------------------------------------------------

## Les quatre éléphants (_elephant) et Akoupara (_tortue), à l'échelle du pays : la tortue sous le disque, les
## éléphants aux diagonales, tête vers le dehors, les pieds un peu enfoncés dans la carapace, la selle d'or
## sous la roche du disque.
func _porteurs() -> void:
	_tortue()
	for i in ELEPHANTS.size():
		var a := TAU * i / ELEPHANTS.size() + PI * 0.25
		var pieds := _carapace_y(cos(a) * ELEPHANTS_R, sin(a) * ELEPHANTS_R) - 10.0
		_elephant(i, CENTRE + Vector3(cos(a) * ELEPHANTS_R, pieds, sin(a) * ELEPHANTS_R), atan2(cos(a), sin(a)),
			-EPAISSEUR - pieds)


## Les éléphants des points cardinaux, parés comme pour une fête : Airâvata, l'éléphant blanc, puis Vâmana,
## Anjana et Sârvabhauma. Leur peau, leur caparaçon et ses broderies, la frontière d'or.
const PARURES := [
	[Color(0.86, 0.84, 0.8), Color(0.62, 0.08, 0.1)],
	[Color(0.47, 0.45, 0.46), Color(0.85, 0.45, 0.08)],
	[Color(0.42, 0.41, 0.43), Color(0.1, 0.16, 0.5)],
	[Color(0.5, 0.47, 0.45), Color(0.08, 0.38, 0.22)],
]


## Un éléphant porteur, bâti en unités d'éléphant (le dessus de la selle à 1,0, la tête vers +Z), puis mis à
## l'échelle `H` : le corps en trois masses (épaules, ventre, croupe), des pattes en colonnes qui se resserrent
## au genou, des pieds aux ongles d'ivoire, la tête au front bombé, de grandes oreilles qui battent, une
## trompe articulée qui se balance et s'enroule, des défenses courbes, la queue. Paré d'un caparaçon brodé
## d'or et frangé, d'un frontal d'or, et d'une selle d'or où repose le disque.
func _elephant(i: int, pos: Vector3, lacet: float, H: float) -> void:
	var e := Node3D.new()
	e.name = str(ELEPHANTS[i]).replace("â", "a")
	e.position = pos
	e.rotation.y = lacet
	e.scale = Vector3.ONE * H
	add_child(e)
	var parure: Array = PARURES[i]
	var peau := _matiere_peau_elephant(parure[0], H)
	var ivoire := _mat(Color(0.93, 0.88, 0.76), 0.35)
	var or_ := _mat(Color(0.95, 0.74, 0.32), 0.3)
	or_.metallic = 0.85
	var drap := _matiere_caparacon(parure[1])
	# Le corps : les épaules plus hautes que la croupe, le ventre rond.
	_piece(e, _boule(1.0), peau, Vector3(0, 0.74, 0.2), Vector3.ZERO, Vector3(0.29, 0.29, 0.27))
	_piece(e, _boule(1.0), peau, Vector3(0, 0.68, -0.02), Vector3.ZERO, Vector3(0.3, 0.27, 0.36))
	_piece(e, _boule(1.0), peau, Vector3(0, 0.7, -0.26), Vector3.ZERO, Vector3(0.27, 0.26, 0.24))
	# Les pattes : la cuisse, la jambe, le pied rond et ses trois ongles.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var q := Vector3(sx * 0.16, 0, 0.27 if sz > 0.0 else -0.28)
			_piece(e, _cylindre_plein(0.115, 0.085, 0.32), peau, q + Vector3(0, 0.5, 0))
			_piece(e, _boule(1.0), peau, q + Vector3(0, 0.33, 0), Vector3.ZERO, Vector3(0.09, 0.06, 0.09))
			_piece(e, _cylindre_plein(0.082, 0.095, 0.3), peau, q + Vector3(0, 0.17, 0))
			_piece(e, _cylindre_plein(0.098, 0.105, 0.04), peau, q + Vector3(0, 0.02, 0))
			for k in 3:
				var a := (k - 1) * 0.55
				_piece(e, _boule(1.0), ivoire, q + Vector3(sin(a) * 0.09, 0.022, cos(a) * 0.09), Vector3.ZERO, Vector3(0.026, 0.02, 0.016))
	# La tête et le front bombé, les yeux.
	var tete := Vector3(0, 0.84, 0.5)
	_piece(e, _boule(1.0), peau, tete, Vector3(deg_to_rad(15), 0, 0), Vector3(0.18, 0.21, 0.17))
	_piece(e, _boule(1.0), peau, tete + Vector3(0, 0.11, 0.03), Vector3.ZERO, Vector3(0.14, 0.09, 0.12))
	var noir := _mat(Color(0.03, 0.02, 0.02), 0.1)
	for sx in [-1.0, 1.0]:
		_piece(e, _boule(1.0), noir, tete + Vector3(sx * 0.13, 0.03, 0.1), Vector3.ZERO, Vector3(0.018, 0.016, 0.016))
	# Les oreilles : de grands voiles, un peu plus sombres, qui battent.
	for sx in [-1.0, 1.0]:
		var o := Node3D.new()
		o.position = tete + Vector3(sx * 0.15, 0.06, -0.04)
		e.add_child(o)
		_piece(o, _boule(1.0), peau, Vector3(sx * 0.06, -0.07, -0.12), Vector3(0, sx * 0.45, 0), Vector3(0.022, 0.25, 0.2))
		_nageoires.append([o, sx, float(i) * 1.7, "oreille"])
	# Le frontal d'or, le drap rouge sous lui.
	_piece(e, _boule(1.0), drap, tete + Vector3(0, 0.08, 0.12), Vector3(deg_to_rad(-25), 0, 0), Vector3(0.08, 0.1, 0.025))
	_piece(e, _boule(1.0), or_, tete + Vector3(0, 0.1, 0.15), Vector3(deg_to_rad(-25), 0, 0), Vector3(0.06, 0.08, 0.02))
	# La trompe : neuf anneaux sur des articulations en chaîne, qui pend, se balance et s'enroule au bout.
	var joint := Node3D.new()
	joint.position = tete + Vector3(0, -0.06, 0.16)
	e.add_child(joint)
	var n := 9
	for k in n:
		var r0 := lerpf(0.07, 0.026, float(k) / n)
		var r1 := lerpf(0.07, 0.026, float(k + 1) / n)
		_piece(joint, _cylindre_plein(r0, r1, 0.075), peau, Vector3(0, -0.035, 0))
		_nageoires.append([joint, float(k) / n, float(i) * 2.3, "trompe"])
		var suivant := Node3D.new()
		suivant.position = Vector3(0, -0.07, 0)
		joint.add_child(suivant)
		joint = suivant
	# Les défenses : deux arcs d'ivoire qui partent sous les yeux et se relèvent.
	for sx in [-1.0, 1.0]:
		var d0 := tete + Vector3(sx * 0.07, -0.1, 0.12)
		var pts := [d0, d0 + Vector3(sx * 0.015, -0.07, 0.05), d0 + Vector3(sx * 0.025, -0.1, 0.12), d0 + Vector3(sx * 0.03, -0.08, 0.19)]
		for k in pts.size() - 1:
			var a: Vector3 = pts[k]
			var b: Vector3 = pts[k + 1]
			var seg := _piece(e, _cylindre_plein(lerpf(0.022, 0.008, (k + 1) / 3.0), lerpf(0.022, 0.008, k / 3.0), a.distance_to(b) + 0.01), ivoire, (a + b) * 0.5)
			seg.basis = Basis(Quaternion(Vector3.UP, (b - a).normalized()))
		# L'anneau d'or au pied de la défense.
		_piece(e, _cylindre_plein(0.026, 0.026, 0.015), or_, d0 + Vector3(sx * 0.005, -0.02, 0.02), Vector3(deg_to_rad(-40), 0, 0))
	# La queue et sa houppe.
	var queue := Node3D.new()
	queue.position = Vector3(0, 0.8, -0.48)
	e.add_child(queue)
	_piece(queue, _cylindre_plein(0.018, 0.01, 0.3), peau, Vector3(0, -0.15, -0.02))
	_piece(queue, _boule(1.0), _mat(Color(0.12, 0.1, 0.09)), Vector3(0, -0.31, -0.02), Vector3.ZERO, Vector3(0.022, 0.04, 0.022))
	_nageoires.append([queue, 1.0, float(i), "queue"])
	# Le caparaçon : le drap posé sur le dos, qui tombe sur les flancs, frangé de pompons d'or.
	var capa := CylinderMesh.new()
	capa.top_radius = 0.33
	capa.bottom_radius = 0.36
	capa.height = 0.36
	capa.radial_segments = 48
	_piece(e, capa, drap, Vector3(0, 0.8, -0.02), Vector3.ZERO, Vector3(1.0, 1.0, 1.25))
	for k in 28:
		var a := TAU * k / 28.0
		_piece(e, _boule(1.0), or_, Vector3(cos(a) * 0.36, 0.6, sin(a) * 0.45 - 0.02), Vector3.ZERO, Vector3(0.016, 0.026, 0.016))
	# La selle d'or : un plateau ciselé sur un tambour, où repose le disque.
	_piece(e, _cylindre_plein(0.3, 0.33, 0.04), or_, Vector3(0, 0.99, -0.02))
	_piece(e, _cylindre_plein(0.26, 0.3, 0.05), or_, Vector3(0, 0.955, -0.02))
	_piece(e, _cylindre_plein(0.34, 0.3, 0.02), drap, Vector3(0, 0.925, -0.02))


## La peau d'un éléphant : grise (ou d'ivoire pour Airâvata), ridée de plis horizontaux et de craquelures, plus
## sombre dans les creux. Les rides sont à l'échelle de l'éléphant (`H`), pas du monde.
func _matiere_peau_elephant(teinte: Color, H: float) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
uniform vec3 teinte : source_color;
uniform float echelle = 1.0;
varying vec3 p;
varying vec3 n_monde;
void vertex() {
	p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz / echelle;
	n_monde = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
vec2 h22(vec2 q) { return fract(sin(vec2(dot(q, vec2(127.1, 311.7)), dot(q, vec2(269.5, 183.3)))) * 43758.5453); }
float craquelure(vec2 q) {
	vec2 i = floor(q);
	vec2 f = fract(q);
	float f1 = 9.0;
	float f2 = 9.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			float d = length(g + h22(i + g) - f);
			if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) { f2 = d; }
		}
	}
	return f2 - f1;
}
void fragment() {
	vec3 a = abs(n_monde);
	vec2 q = (a.y > a.x && a.y > a.z) ? p.xz : (a.x > a.z ? p.zy : p.xy);
	float plis = sin(p.y * 140.0 + sin(q.x * 23.0) * 2.0) * 0.5 + 0.5;
	plis = mix(plis, sin(p.y * 330.0 + sin(q.x * 51.0) * 2.0) * 0.5 + 0.5, 0.4);
	float c = craquelure(q * 120.0);
	vec3 col = teinte * (0.78 + 0.22 * plis);
	col *= mix(0.8, 1.0, smoothstep(0.02, 0.15, c));
	col *= mix(0.75, 1.0, smoothstep(-0.6, 0.4, n_monde.y));
	ALBEDO = col;
	ROUGHNESS = 0.85;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("teinte", teinte)
	m.set_shader_parameter("echelle", H)
	return m


## Le caparaçon : un drap de couleur, deux galons d'or en bas, des losanges brodés d'or entre eux, et des
## rosaces sur le dos.
func _matiere_caparacon(teinte: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode cull_disabled;
uniform vec3 teinte : source_color;
varying vec3 l;
void vertex() { l = VERTEX; }
void fragment() {
	vec3 col = teinte;
	float y = l.y;
	float a = atan(l.z, l.x);
	float metal = 0.0;
	// Les galons d'or près du bas, et la frise de losanges entre eux.
	float galon = step(abs(y + 0.15), 0.012) + step(abs(y + 0.07), 0.008);
	vec2 q = vec2(a * 6.0, (y + 0.11) * 30.0);
	float losange = step(abs(fract(q.x) - 0.5) + abs(q.y), 0.42) * step(abs(y + 0.11), 0.03);
	// Les rosaces sur le dessus.
	float r = length(l.xz);
	float rosace = step(0.5, sin(r * 70.0) * 0.5 + 0.5) * step(r, 0.12) * step(0.17, y);
	float or_ = clamp(galon + losange + rosace, 0.0, 1.0);
	col = mix(col, vec3(0.95, 0.72, 0.3), or_);
	ALBEDO = col;
	METALLIC = or_ * 0.8;
	ROUGHNESS = mix(0.8, 0.3, or_);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("teinte", teinte)
	return m


## Le dessus de la carapace en (x, z) depuis le centre du disque (hauteur depuis le centre du disque).
func _carapace_y(x: float, z: float) -> float:
	var k := 1.0 - pow(x / CARAPACE.x, 2.0) - pow(z / CARAPACE.z, 2.0)
	return CARAPACE_Y + CARAPACE.y * sqrt(maxf(k, 0.0))


## Akoupara, la tortue qui nage dans les étoiles, la tête vers +Z. La carapace est un dôme d'écailles : une
## rangée d'écailles du dos sur la crête, quatre de chaque côté, la couronne des marginales au bord, chacune
## un peu bombée, cernée d'un sillon sombre, striée de ses cernes de croissance, de l'olive au brun et à
## l'ambre. Dessous, le plastron clair. La peau est grenue d'écailles fines, plus claire au ventre. Les
## nageoires de devant, longues comme des ailes, rament lentement ; celles de derrière gouvernent.
func _tortue() -> void:
	var A := CARAPACE
	var t := Node3D.new()
	t.name = "Akoupara"
	t.position = CENTRE + Vector3(0, CARAPACE_Y, 0)
	add_child(t)
	# La carapace : une demi-sphère unité, mise à l'échelle des demi-axes, sculptée par son shader.
	var dome := SphereMesh.new()
	dome.radius = 1.0
	dome.height = 1.0
	dome.is_hemisphere = true
	dome.radial_segments = 160
	dome.rings = 64
	var sh := Shader.new()
	sh.code = """shader_type spatial;
// Les écailles de la carapace, vues de dessus : un diagramme de Voronoï sur des centres posés comme sur une
// vraie tortue (cinq vertébrales, quatre costales de chaque côté), et la couronne des marginales au bord.
const vec2 C[13] = { vec2(0.0, -0.66), vec2(0.0, -0.33), vec2(0.0, 0.0), vec2(0.0, 0.33), vec2(0.0, 0.64),
	vec2(-0.47, -0.5), vec2(-0.5, -0.17), vec2(-0.5, 0.17), vec2(-0.46, 0.5),
	vec2(0.47, -0.5), vec2(0.5, -0.17), vec2(0.5, 0.17), vec2(0.46, 0.5) };
varying vec3 dir;
float h11(float x) { return fract(sin(x * 127.1) * 43758.5453); }
// x : la distance au centre de l'écaille, y : la distance au sillon, z : l'identifiant de l'écaille.
vec3 ecaille(vec3 d) {
	vec2 p = d.xz;
	if (d.y < 0.24) {
		float n = 28.0;
		float a = atan(d.z, d.x) / 6.2831853 * n;
		float f = fract(a);
		float bord = min(min(f, 1.0 - f) * 0.9, (0.24 - d.y) * 3.0);
		return vec3(abs(f - 0.5), min(bord, max(d.y, 0.0) * 4.0 + 0.02), 20.0 + floor(a));
	}
	float f1 = 9.0;
	float f2 = 9.0;
	float id = 0.0;
	for (int i = 0; i < 13; i++) {
		float l = length(p - C[i]);
		if (l < f1) { f2 = f1; f1 = l; id = float(i); }
		else if (l < f2) { f2 = l; }
	}
	float sillon = min((f2 - f1) * 0.5, (d.y - 0.24) * 2.5);
	return vec3(f1, sillon, id);
}
void vertex() {
	dir = normalize(VERTEX);
	vec3 e = ecaille(dir);
	// Chaque écaille est un peu bombée, le sillon creusé ; la crête du dos se relève à peine.
	float bombe = smoothstep(0.0, 0.1, e.y) * 0.022 - 0.012 + 0.012 * exp(-dir.x * dir.x * 40.0) * dir.y;
	VERTEX += dir * bombe;
}
void fragment() {
	vec3 e = ecaille(dir);
	float t = h11(e.z + 3.0);
	vec3 olive = vec3(0.33, 0.36, 0.17);
	vec3 brun = vec3(0.4, 0.3, 0.15);
	vec3 ambre = vec3(0.7, 0.52, 0.22);
	vec3 c = mix(olive, brun, t);
	// L'ambre rayonne du centre de chaque écaille, en flammèches.
	float a = atan(dir.z, dir.x);
	float flamme = smoothstep(0.55, 1.0, sin(a * 23.0 + e.z * 5.0) * 0.5 + 0.5) * smoothstep(0.25, 0.02, e.x);
	c = mix(c, ambre, 0.35 * smoothstep(0.22, 0.0, e.x) + 0.3 * flamme);
	// Les cernes de croissance, parallèles au sillon.
	float cerne = smoothstep(0.8, 1.0, sin(e.y * 110.0) * 0.5 + 0.5) * smoothstep(0.02, 0.05, e.y);
	c *= 1.0 - 0.12 * cerne;
	// Le sillon, sombre.
	c = mix(vec3(0.05, 0.04, 0.025), c, smoothstep(0.008, 0.03, e.y));
	// Le bord de chaque écaille s'assombrit un peu avant le sillon.
	c *= 0.8 + 0.2 * smoothstep(0.03, 0.09, e.y);
	ALBEDO = pow(c, vec3(1.4));
	ROUGHNESS = mix(0.4, 0.75, smoothstep(0.008, 0.04, e.y));
	SPECULAR = 0.4;
}
"""
	var ecailles := ShaderMaterial.new()
	ecailles.shader = sh
	_piece(t, dome, ecailles, Vector3.ZERO, Vector3.ZERO, A)
	# Le plastron, clair et plat, sous la carapace.
	var plastron := _mat(Color(0.5, 0.44, 0.3), 0.8)
	_piece(t, _boule(1.0), plastron, Vector3(0, -A.y * 0.04, 0), Vector3.ZERO, Vector3(A.x * 0.93, A.y * 0.24, A.z * 0.93))
	var peau := _matiere_peau()
	# Le cou et la tête, tendus vers l'avant, un peu levés vers les étoiles ; le bec de corne, les yeux.
	var cou := Node3D.new()
	cou.position = Vector3(0, -A.y * 0.08, A.z * 0.86)
	t.add_child(cou)
	_nageoires.append([cou, 0.0, 0.0, "tete"])
	_piece(cou, _boule(1.0), peau, Vector3(0, 0, A.x * 0.12), Vector3(deg_to_rad(-12), 0, 0), Vector3(A.x * 0.15, A.x * 0.12, A.x * 0.24))
	var tete := Vector3(0, A.x * 0.07, A.x * 0.38)
	_piece(cou, _boule(1.0), peau, tete, Vector3(deg_to_rad(-8), 0, 0), Vector3(A.x * 0.15, A.x * 0.12, A.x * 0.19))
	var corne := _mat(Color(0.2, 0.17, 0.12), 0.35)
	_piece(cou, _boule(1.0), corne, tete + Vector3(0, -A.x * 0.035, A.x * 0.15), Vector3(deg_to_rad(15), 0, 0), Vector3(A.x * 0.08, A.x * 0.05, A.x * 0.07))
	var oeil := _mat(Color(0.03, 0.025, 0.02), 0.08)
	var iris := StandardMaterial3D.new()
	iris.albedo_color = Color(0.85, 0.6, 0.2)
	iris.emission_enabled = true
	iris.emission = Color(0.9, 0.55, 0.15)
	iris.emission_energy_multiplier = 0.6
	for sx in [-1.0, 1.0]:
		var o := tete + Vector3(sx * A.x * 0.115, A.x * 0.035, A.x * 0.07)
		_piece(cou, _boule(1.0), iris, o, Vector3.ZERO, Vector3.ONE * A.x * 0.03)
		_piece(cou, _boule(1.0), oeil, o + Vector3(sx * A.x * 0.012, 0, A.x * 0.004), Vector3.ZERO, Vector3.ONE * A.x * 0.022)
		# Le pli de la paupière.
		_piece(cou, _boule(1.0), peau, o + Vector3(sx * A.x * 0.004, A.x * 0.02, 0), Vector3(0, 0, sx * 0.3), Vector3(A.x * 0.04, A.x * 0.012, A.x * 0.04))
	# Les nageoires : de longues pales devant, plus courtes derrière, chacune sur son pivot qui rame.
	for sx in [-1.0, 1.0]:
		for avant in [true, false]:
			var pivot := Node3D.new()
			pivot.position = Vector3(sx * A.x * (0.78 if avant else 0.68), -A.y * 0.12, A.z * (0.48 if avant else -0.66))
			pivot.rotation.y = sx * (0.5 if avant else 1.2)
			t.add_child(pivot)
			var L := A.x * (0.85 if avant else 0.38)
			var largeur := A.x * (0.22 if avant else 0.18)
			# La pale s'affine vers le bout : deux masses, l'épaule et la main.
			_piece(pivot, _boule(1.0), peau, Vector3(sx * L * 0.3, 0, 0), Vector3.ZERO, Vector3(L * 0.36, A.x * 0.05, largeur * 0.9))
			_piece(pivot, _boule(1.0), peau, Vector3(sx * L * 0.72, -A.x * 0.01, -largeur * 0.12), Vector3(0, sx * 0.12, 0), Vector3(L * 0.34, A.x * 0.03, largeur * 0.62))
			_nageoires.append([pivot, sx, 0.0 if avant else PI * 0.6, "avant" if avant else "arriere"])
	# La queue, courte et pointue.
	var queue := _cylindre_plein(A.x * 0.06, A.x * 0.005, A.x * 0.22)
	_piece(t, queue, peau, Vector3(0, -A.y * 0.12, -A.z * 1.02), Vector3(deg_to_rad(-100), 0, 0))


## La peau d'Akoupara : un grain d'écailles fines (un Voronoï), olive et gris, plus claire et plus jaune dessous.
func _matiere_peau() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
varying vec3 monde;
varying vec3 n_monde;
void vertex() {
	monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	n_monde = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
vec2 h22(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
vec2 voronoi(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float f1 = 9.0;
	float f2 = 9.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 g = vec2(float(x), float(y));
			float d = length(g + h22(i + g) - f);
			if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) { f2 = d; }
		}
	}
	return vec2(f1, f2 - f1);
}
void fragment() {
	vec3 a = abs(n_monde);
	vec2 p = (a.y > a.x && a.y > a.z) ? monde.xz : (a.x > a.z ? monde.yz : monde.xy);
	vec2 v = voronoi(p / 9.0);
	vec3 dessus = vec3(0.3, 0.33, 0.24);
	vec3 dessous = vec3(0.66, 0.6, 0.4);
	vec3 c = mix(dessous, dessus, smoothstep(-0.4, 0.3, n_monde.y));
	c *= 0.85 + 0.25 * v.x;
	c = mix(c * 0.45, c, smoothstep(0.02, 0.12, v.y));
	ALBEDO = pow(c, vec3(1.6));
	ROUGHNESS = 0.7;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _cylindre_plein(r_haut: float, r_bas: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_haut
	c.bottom_radius = r_bas
	c.height = h
	c.radial_segments = 24
	return c



# --- La clairière ----------------------------------------------------------------------------------------

func _ile() -> void:
	var ile := Node3D.new()
	ile.name = "Ile"
	add_child(ile)
	# Quelques arbres, à l'écart du chemin entre l'arrivée et la Porte, et la lisière tout autour.
	var arbres := [["tree_oak", Vector3(-6.5, 0, -2.0)], ["tree_default", Vector3(7.0, 0, -5.5)],
		["tree_fat", Vector3(-11.0, 0, 7.0)], ["tree_cone", Vector3(12.5, 0, 6.0)], ["tree_detailed", Vector3(-3.5, 0, -13.0)],
		["tree_oak_fall", Vector3(9.5, 0, -14.0)], ["tree_default", Vector3(-15.5, 0, -6.5)], ["tree_cone", Vector3(16.0, 0, -2.0)],
		["tree_fat_fall", Vector3(3.0, 0, 14.5)], ["tree_detailed", Vector3(-8.0, 0, 15.5)]]
	var g := RandomNumberGenerator.new()
	g.seed = 7
	var noms := ["tree_oak", "tree_default", "tree_fat", "tree_cone", "tree_detailed", "tree_oak_fall"]
	for i in 70:
		var ang := g.randf() * TAU
		var r := g.randf_range(ILE + 3.0, 75.0)
		var p := Vector3(cos(ang) * r, 0, sin(ang) * r)
		var y := hauteur(p.x - CENTRE.x, p.z - CENTRE.z) + CENTRE.y
		if y < 0.6 + CENTRE.y + 0.5:
			continue
		arbres.append([noms[i % noms.size()], Vector3(p.x, y - 0.1, p.z), true])
	for a in arbres:
		var n := Atelier.modele("nature/" + a[0], g.randf_range(2.0, 2.9) * (1.3 if a.size() > 2 else 1.0))
		if n == null:
			continue
		n.position = a[1]
		n.rotation.y = g.randf() * TAU
		ile.add_child(n)
		if a.size() > 2:
			continue
		var tronc := StaticBody3D.new()
		var f := CollisionShape3D.new()
		var c := CylinderShape3D.new()
		c.radius = 0.18
		c.height = 1.6
		f.shape = c
		f.position.y = 0.8
		tronc.add_child(f)
		tronc.position = a[1]
		ile.add_child(tronc)
	for i in 26:
		var nom: String = ["flower_redA", "flower_yellowA", "flower_purpleA", "plant_bush", "grass_large", "plant_bushSmall"][i % 6]
		var n := Atelier.modele("nature/" + nom, 0.35 if nom.begins_with("flower") or nom.begins_with("grass") else 0.6)
		if n == null:
			continue
		var ang := g.randf() * TAU
		var r := g.randf_range(5.0, ILE - 1.5)
		n.position = Vector3(cos(ang) * r, 0, sin(ang) * r)
		n.rotation.y = g.randf() * TAU
		ile.add_child(n)
	# Le banc, tourné vers le Meru.
	var vers := Vector3(CENTRE.x, 0, CENTRE.z).normalized()
	_banc(ile, vers * (ILE - 2.0), atan2(vers.x, vers.z) + PI)


func _banc(parent: Node3D, pos: Vector3, cap: float) -> void:
	var b := Node3D.new()
	b.name = "Banc"
	b.position = pos
	b.rotation.y = cap
	parent.add_child(b)
	var bois := _mat(Color(0.45, 0.3, 0.18))
	var fer := _mat(Color(0.15, 0.15, 0.16), 0.5)
	var planche := BoxMesh.new()
	planche.size = Vector3(1.2, 0.04, 0.12)
	for k in 3:
		_piece(b, planche, bois, Vector3(0, 0.26, -0.14 + 0.14 * k))
	for k in 2:
		_piece(b, planche, bois, Vector3(0, 0.42 + 0.12 * k, -0.24), Vector3(-0.25, 0, 0))
	var pied := BoxMesh.new()
	pied.size = Vector3(0.05, 0.26, 0.36)
	for x in [-0.5, 0.5]:
		_piece(b, pied, fer, Vector3(x, 0.13, 0))


## La Porte des Joints : deux piliers de pierre, un linteau, et entre eux un tourbillon d'or et de violet.
func _porte() -> void:
	var p := Node3D.new()
	p.name = "PorteDesJoints"
	p.position = PORTE
	add_child(p)
	var pierre := _mat(Color(0.62, 0.58, 0.52))
	var pilier := BoxMesh.new()
	pilier.size = Vector3(0.32, 2.0, 0.32)
	var linteau := BoxMesh.new()
	linteau.size = Vector3(2.05, 0.28, 0.44)
	var marche := BoxMesh.new()
	marche.size = Vector3(2.2, 0.08, 1.0)
	_piece(p, marche, pierre, Vector3(0, 0.0, 0))
	var corps := StaticBody3D.new()
	p.add_child(corps)
	for x in [-0.78, 0.78]:
		_piece(p, pilier, pierre, Vector3(x, 1.0, 0))
		var f := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = pilier.size
		f.shape = b
		f.position = Vector3(x, 1.0, 0)
		corps.add_child(f)
	_piece(p, linteau, pierre, Vector3(0, 2.12, 0))
	var orne := BoxMesh.new()
	orne.size = Vector3(0.5, 0.18, 0.46)
	_piece(p, orne, _mat(Color(0.96, 0.8, 0.45), 0.35), Vector3(0, 2.34, 0))
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	q.x *= 0.62;
	float r = length(q);
	float a = atan(q.y, q.x);
	float s = sin(a * 3.0 + r * 11.0 - TIME * 2.4) * 0.5 + 0.5;
	float bord = smoothstep(1.0, 0.55, r);
	vec3 c = mix(vec3(0.36, 0.14, 0.78), vec3(1.0, 0.78, 0.38), s);
	ALBEDO = c * bord * (0.55 + 0.7 * s);
	ALPHA = bord;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var voile := QuadMesh.new()
	voile.size = Vector2(1.24, 1.92)
	var mi := _piece(p, voile, m, Vector3(0, 1.0, 0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lueur := OmniLight3D.new()
	lueur.light_color = Color(0.8, 0.6, 1.0)
	lueur.light_energy = 1.4
	lueur.omni_range = 4.0
	lueur.position = Vector3(0, 1.0, 0.4)
	p.add_child(lueur)
	porte = Area3D.new()
	porte.name = "Porte"
	porte.set_meta("interact", "porte_des_joints")
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(1.6, 2.0, 1.0)
	f.shape = b
	porte.add_child(f)
	porte.position = Vector3(0, 1.0, 0)
	p.add_child(porte)


# --- La Lanterne ---------------------------------------------------------------------------------------

func _lanterne() -> void:
	lanterne = Node3D.new()
	lanterne.name = "Lanterne"
	add_child(lanterne)
	var coeur := StandardMaterial3D.new()
	coeur.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	coeur.albedo_color = Color(1.0, 0.86, 0.5)
	coeur.emission_enabled = true
	coeur.emission = Color(1.0, 0.75, 0.35)
	coeur.emission_energy_multiplier = 6.0
	var mi := _piece(lanterne, _boule(5.0 * K), coeur, Vector3.ZERO)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var halo := StandardMaterial3D.new()
	halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.albedo_color = Color(1.0, 0.82, 0.45, 0.16)
	halo.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi = _piece(lanterne, _boule(9.0 * K), halo, Vector3.ZERO)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# La couronne : des rayons qui tournent lentement autour du cœur, toujours face à la caméra.
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled, blend_add, fog_disabled;
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0, 0, 0), vec4(0, length(MODEL_MATRIX[1].xyz), 0, 0), vec4(0, 0, length(MODEL_MATRIX[2].xyz), 0), vec4(0, 0, 0, 1));
}
void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	float r = length(q);
	float a = atan(q.y, q.x);
	float rayons = pow(abs(sin(a * 7.0 + TIME * 0.15)), 18.0) * 0.6 + pow(abs(sin(a * 11.0 - TIME * 0.1)), 30.0) * 0.4;
	float halo = exp(-r * 4.5) * 1.4 + rayons * exp(-r * 2.6) * 0.9;
	ALBEDO = vec3(1.0, 0.72, 0.38) * halo * smoothstep(1.0, 0.7, r);
}
"""
	var couronne := ShaderMaterial.new()
	couronne.shader = sh
	var q := QuadMesh.new()
	q.size = Vector2(70, 70) * K
	mi = _piece(lanterne, q, couronne, Vector3.ZERO)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## La Lanterne au temps `t` : elle passe au-dessus du disque puis dessous, dans un plan qui tourne
## lentement, et la lumière du jour vient d'elle.
func _poser_lanterne(t: float) -> void:
	var a := deg_to_rad(LANTERNE_DEPART) + t * TAU / LANTERNE_TOUR
	var plan := deg_to_rad(35.0) + t * 0.01
	var rel := LANTERNE_CENTRE + Basis(Vector3.UP, plan) * Vector3(cos(a) * LANTERNE_R, sin(a) * LANTERNE_R * 0.8, 0.0)
	lanterne.position = CENTRE + rel
	soleil.look_at_from_position(lanterne.position, CENTRE, Vector3.UP if absf(rel.normalized().y) < 0.98 else Vector3.FORWARD)
	# Le jour sur le pays quand elle est au-dessus, une lueur dessous.
	var jour := smoothstep(-0.15, 0.25, rel.normalized().y)
	soleil.light_energy = lerpf(0.25, 1.3, jour)
	# Au ras de l'horizon, la lumière se dore ; en plein jour, elle blanchit.
	soleil.light_color = Color(1.0, 0.62, 0.38).lerp(Color(1.0, 0.92, 0.8), smoothstep(0.1, 0.6, rel.normalized().y))
	_jour = jour
	for m in _matieres_nuages:
		m.set_shader_parameter("jour", jour)


# --- L'habitant, la caméra, l'interface -----------------------------------------------------------------

func _joueur() -> void:
	camera = Camera3D.new()
	camera.set_script(load("res://scripts/orbit_camera.gd"))
	camera.far = 8000.0
	add_child(camera)
	player = load("res://scripts/fp_player.gd").new()
	player.eye = 0.6
	player.body_height = 0.7
	player.radius = 0.14
	player.speed = 1.5
	player.reach = 2.4
	add_child(player)
	player.camera.far = 8000.0
	var me: Node3D = load("res://scripts/critter.gd").new()
	me.look = Cast.moi()
	me.walk_speed = 1.0
	me.run_speed = 1.9
	me.rotation.y = PI
	player.add_child(me)
	player.avatar = me
	player.global_position = ARRIVEE
	player.rotation.y = 0.0
	player.follow_camera = camera
	player.interact.connect(_sur_action)
	camera.target = ARRIVEE + Vector3(0, 0.3, 0)
	camera.set("_target_goal", camera.target)
	camera.use_notches(CRANS, 1)
	_plan = Camera3D.new()
	_plan.name = "Plan"
	_plan.far = 12000.0
	_plan.near = 0.5
	_plan.fov = 42.0
	add_child(_plan)
	_plan.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## L'interface, sans un mot pendant l'arrivée : les bandes noires du cinéma et le noir de la fin. Puis
## l'invite de la Porte.
func _interface() -> void:
	var ui := CanvasLayer.new()
	ui.name = "Interface"
	add_child(ui)
	for haut in [true, false]:
		var bande := ColorRect.new()
		bande.color = Color(0, 0, 0)
		bande.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bande.set_anchors_preset(Control.PRESET_TOP_WIDE if haut else Control.PRESET_BOTTOM_WIDE)
		ui.add_child(bande)
		_bandes.append([bande, haut])
	_noir = ColorRect.new()
	_noir.color = Color(0, 0, 0)
	_noir.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_noir.set_anchors_preset(Control.PRESET_FULL_RECT)
	_noir.modulate.a = 0.0
	ui.add_child(_noir)
	_prompt = Label.new()
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt.add_theme_font_size_override("font_size", 20)
	_prompt.add_theme_color_override("font_color", Color(1, 1, 1))
	if Polices.gras():
		_prompt.add_theme_font_override("font", Polices.gras())
	_prompt.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt.offset_left = -300
	_prompt.offset_right = 300
	_prompt.offset_top = -120
	_prompt.offset_bottom = -90
	_prompt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_prompt.add_theme_constant_override("outline_size", 6)
	_prompt.text = "E : remonter par la Porte des Joints"
	_prompt.visible = false
	ui.add_child(_prompt)


# --- L'arrivée -------------------------------------------------------------------------------------------

## La mise en scène de l'arrivée au temps `t` (voir l'en-tête).
func _poser_plan(t: float) -> void:
	_arrivee = t
	# La direction du centre vers la clairière : on vient de l'autre côté du monde, on passe sur le Meru.
	var u := Vector3(-CENTRE.x, 0, -CENTRE.z).normalized()
	var cote := u.cross(Vector3.UP)
	var vue := CENTRE + Vector3(0, -380.0, 0)
	# De loin : le monde entier, la caméra qui tourne lentement en s'approchant.
	var depart := atan2(-u.x, -u.z) + 0.75
	var tour := depart - minf(t, T_LOIN) * 0.05
	var loin := vue + Vector3(sin(tour), 0.0, cos(tour)) * (4300.0 - minf(t, T_LOIN) * 110.0) + Vector3(0, 1250.0, 0)
	var pos: Vector3
	var cible: Vector3
	if t < T_LOIN:
		pos = loin
		cible = vue + Vector3(sin(t * 0.7) * 20.0, sin(t * 0.53) * 15.0, 0)
		_plan.fov = 42.0
	else:
		# Le survol : par-dessus le bord, au-dessus du pays, sur le Meru, puis vers la clairière, de plus en
		# plus bas. Une courbe de Catmull-Rom.
		var u2 := clampf((t - T_LOIN) / (T_FIN - T_LOIN), 0.0, 1.0)
		var s := u2 * u2 * (3.0 - 2.0 * u2) * 0.35 + u2 * 0.65
		var points := [loin,
			CENTRE - u * 1.5 * DISQUE + cote * 300.0 + Vector3(0, 620.0, 0),
			CENTRE - u * 0.7 * DISQUE + cote * 120.0 + Vector3(0, 300.0, 0),
			CENTRE + u * 0.05 * DISQUE - cote * 60.0 + Vector3(0, 210.0, 0),
			-u * 170.0 - cote * 30.0 + Vector3(0, 70.0, 0),
			-u * 40.0 + Vector3(0, 18.0, 0)]
		var cibles := [vue,
			CENTRE + u * 0.1 * DISQUE,
			CENTRE + u * 0.2 * DISQUE + Vector3(0, 40.0, 0),
			u * 40.0,
			Vector3(0, 0, 0),
			Vector3(0, 0, 0)]
		pos = _catmull(points, s)
		cible = _catmull(cibles, s)
		_plan.fov = lerpf(42.0, 50.0, smoothstep(0.3, 0.9, s))
	_plan.look_at_from_position(pos, cible)
	# Les bandes du cinéma, et le noir de la fin, avant de toucher le sol.
	var haut := get_viewport().get_visible_rect().size.y * 0.11 * clampf(t / 0.8, 0.0, 1.0)
	for b in _bandes:
		if b[1]:
			b[0].offset_bottom = haut
		else:
			b[0].offset_top = -haut
	_noir.modulate.a = clampf((t - T_NOIR) / (T_FIN - T_NOIR - 0.15), 0.0, 1.0)
	player.visible = false
	player.frozen = true
	_poser_lanterne(_t)
	_brume()


## Un point de la courbe de Catmull-Rom qui passe par `pts`, à `u` de 0 (le premier) à 1 (le dernier).
static func _catmull(pts: Array, u: float) -> Vector3:
	var n := pts.size() - 1
	var x := clampf(u, 0.0, 1.0) * n
	var i := mini(int(x), n - 1)
	var f := x - i
	var p0: Vector3 = pts[maxi(i - 1, 0)]
	var p1: Vector3 = pts[i]
	var p2: Vector3 = pts[i + 1]
	var p3: Vector3 = pts[mini(i + 2, n)]
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * f + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * f * f + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * f * f * f)


## Passe la mise en scène : on rouvre les yeux dans la clairière, la main est à l'habitant, la caméra à crans
## le suit.
func _finir_arrivee() -> void:
	if not _en_arrivee:
		return
	_en_arrivee = false
	_arrivee = maxf(_arrivee, T_FIN)
	for b in _bandes:
		b[0].visible = false
	player.visible = true
	player.frozen = false
	soleil.directional_shadow_max_distance = 160.0
	camera.make_current()
	_noir.modulate.a = 1.0
	create_tween().tween_property(_noir, "modulate:a", 0.0, 1.4).set_delay(0.2)


func _unhandled_input(event: InputEvent) -> void:
	if not _en_arrivee or _figee >= 0.0 or _arrivee < 0.4:
		return
	var touche: bool = event is InputEventKey and event.pressed and not event.echo
	var clic: bool = (event is InputEventMouseButton or event is InputEventScreenTouch) and event.pressed
	if touche or clic:
		_finir_arrivee()
		get_viewport().set_input_as_handled()


func _sur_action(cible: Node) -> void:
	if cible == porte and not _en_arrivee:
		Dessous.remonter()


func _process(delta: float) -> void:
	_t += delta
	if _figee >= 0.0:
		_poser_plan(_figee)
	elif _en_arrivee:
		_poser_plan(_arrivee + delta)
		if _arrivee >= T_FIN:
			_finir_arrivee()
	else:
		_arrivee += delta
		_poser_lanterne(_t)
		_brume()
	if _couronne != null:
		_couronne.rotation.y = _t * 0.004
	# Akoupara rame : les nageoires de devant battent lentement, celles de derrière suivent ; la tête oscille.
	for n in _nageoires:
		var pivot: Node3D = n[0]
		var ph: float = _t * 0.45 + n[2]
		match n[3]:
			"avant":
				pivot.rotation.z = n[1] * (sin(ph) * 0.32 - 0.05)
				pivot.rotation.x = cos(ph) * 0.18
			"arriere":
				pivot.rotation.z = n[1] * sin(ph) * 0.15
			"tete":
				pivot.rotation = Vector3(sin(_t * 0.21) * 0.05 - 0.06, sin(_t * 0.13) * 0.08, 0)
			# Les éléphants : les oreilles battent, la trompe se balance et s'enroule au bout, la queue fouette.
			"oreille":
				pivot.rotation.y = n[1] * (0.12 + 0.22 * maxf(sin(_t * 0.9 + n[2]), 0.0))
			"trompe":
				var k: float = n[1]
				pivot.rotation.x = -(0.05 + k * k * (0.55 + 0.25 * sin(_t * 0.5 + n[2])))
				pivot.rotation.z = sin(_t * 0.35 + n[2] - k * 1.5) * 0.06
			"queue":
				pivot.rotation.z = sin(_t * 1.1 + n[2]) * 0.25
	if player != null and player.follow_camera == camera:
		camera.set("_target_goal", player.global_position + Vector3(0, 0.3, 0))
	_prompt.visible = not _en_arrivee and player != null and player.focus_target == porte


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	# La clairière est bordée par la lisière : on ne s'avance pas au-delà. Et si l'on passe malgré tout
	# à travers le sol, on retombe à l'arrivée.
	var h := Vector2(player.global_position.x, player.global_position.z)
	if h.length() > ILE - 0.6:
		h = h.normalized() * (ILE - 0.6)
		player.global_position = Vector3(h.x, player.global_position.y, h.y)
	if player.global_position.y < -6.0:
		player.global_position = ARRIVEE
		player.velocity = Vector3.ZERO
