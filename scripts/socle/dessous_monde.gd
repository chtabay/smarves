extends Node3D
## Le Dessous, le monde sous toutes les cartes (scenes/dessous.tscn ; le passage est dans
## scripts/socle/dessous.gd, autoload « Dessous »). Le même pour toutes les communes : il fait partie du socle.
##
## Le motif vient de la cosmologie indienne, où la terre repose sur des éléphants debout sur une tortue :
## un disque de terre et d'eau, posé sur le dos de quatre éléphants des points cardinaux (Airâvata à l'est,
## Vâmana au sud, Anjana à l'ouest, Sârvabhauma au nord), eux-mêmes debout sur la carapace d'Akoupara, la
## tortue qui nage dans les étoiles. La Lanterne, un petit soleil, en fait le tour : elle passe au-dessus du
## disque, puis dessous, et la nuit tombe sur l'île. L'océan déborde du bord du disque en une cascade.
##
## Au milieu de l'île, la Porte des Joints ramène là où l'on est tombé (Dessous.remonter). Le reste de l'île
## attend son contenu : quelques arbres, un banc au bord du monde.
##
## L'arrivée est mise en scène : on voit d'abord tout le monde de loin, la tortue, les éléphants et la
## Lanterne, puis la caméra descend vers le disque, une étoile filante y tombe, et c'est l'habitant. Une
## touche ou un clic passe la mise en scène. Pour les captures : `--plan=secondes` fige l'arrivée à cet
## instant (tools/capture_dessous.gd).
##
## Les mesures sont celles des communes : l'habitant mesure 0,7.

## Les crans de la caméra de dessus, comme le kit des communes : distance, tangage, champ.
const CRANS := [[9.0, -48.0, 34.0], [18.0, -51.0, 30.0], [32.0, -58.0, 30.0]]
## L'île où l'on marche (rayon), le disque entier (océan compris).
const ILE := 22.0
const DISQUE := 30.0
## Où l'on arrive, et la Porte des Joints en face.
const ARRIVEE := Vector3(0.0, 0.0, 3.0)
const PORTE := Vector3(0.0, 0.0, -4.0)
## La carapace d'Akoupara : son centre et ses demi-axes (largeur, hauteur, longueur).
const CARAPACE_Y := -44.0
const CARAPACE := Vector3(55.0, 22.0, 62.0)
## Les éléphants, à cette distance du centre, sous le disque.
const ELEPHANTS_R := 16.0
const ELEPHANTS := [["Airâvata", 90.0], ["Vâmana", 180.0], ["Anjana", 270.0], ["Sârvabhauma", 0.0]]
## La Lanterne : le centre de sa course, son rayon, sa période (secondes), l'angle de départ.
const LANTERNE_CENTRE := Vector3(0.0, -20.0, 0.0)
const LANTERNE_R := 120.0
const LANTERNE_TOUR := 300.0
const LANTERNE_DEPART := 62.0
## L'arrivée : la vue de loin, la descente, l'étoile qui tombe, la main rendue.
const T_LOIN := 3.6
const T_DESCENTE := 7.0
const T_ETOILE := 4.6
const T_FIN := 7.6

const OR := Color(0.96, 0.8, 0.45)

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
var _etoile: Node3D
var _eclat: OmniLight3D
var _titre: Label
var _sous_titre: Label
var _bandeau: Label
var _passer: Label
var _nageoires: Array = []
var _oreilles: Array = []
var _lieu := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--plan="):
			_figee = float(a.trim_prefix("--plan="))
	_lieu = str(Dessous.origine.get("lieu", "")) if Dessous.origine.has("lieu") else ""
	_ciel()
	_disque()
	_ile()
	_porte()
	for e in ELEPHANTS:
		_elephant(e[0], e[1])
	_tortue()
	_lanterne()
	_interface()
	_joueur()
	Sfx.musique("grands_espaces")
	_poser_plan(_figee if _figee >= 0.0 else 0.0)


# --- Le ciel et la lumière -----------------------------------------------------------------------------

func _ciel() -> void:
	var sh := Shader.new()
	sh.code = """shader_type sky;
// Les étoiles du Dessous : une poussière fixe, une bande laiteuse, et le ciel qui tourne lentement,
// comme si Akoupara nageait.
void sky() {
	float a = TIME * 0.004;
	vec3 d = vec3(EYEDIR.x * cos(a) - EYEDIR.z * sin(a), EYEDIR.y, EYEDIR.x * sin(a) + EYEDIR.z * cos(a));
	vec3 col = mix(vec3(0.006, 0.008, 0.022), vec3(0.03, 0.025, 0.07), 0.5 + 0.5 * d.y);
	float bande = exp(-pow(dot(d, normalize(vec3(0.35, 1.0, 0.25))) * 3.2, 2.0));
	col += vec3(0.06, 0.045, 0.1) * bande;
	for (int k = 0; k < 2; k++) {
		vec3 p = d * (170.0 + float(k) * 90.0);
		vec3 c = floor(p);
		float h = fract(sin(dot(c, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
		if (h > 0.982) {
			vec3 f = fract(p) - 0.5;
			float s = 1.0 - smoothstep(0.0, 0.22, length(f));
			float teinte = fract(h * 91.7);
			col += s * (h - 0.982) * 55.0 * mix(vec3(1.0, 0.85, 0.7), vec3(0.75, 0.85, 1.0), teinte);
		}
	}
	COLOR = col;
}
"""
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var sky := Sky.new()
	sky.sky_material = mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.42, 0.45, 0.62)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	soleil = DirectionalLight3D.new()
	soleil.name = "Soleil"
	soleil.light_color = Color(1.0, 0.9, 0.75)
	soleil.light_energy = 1.25
	soleil.shadow_enabled = true
	soleil.directional_shadow_max_distance = 260.0
	add_child(soleil)


# --- Le disque -------------------------------------------------------------------------------------------

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


func _cylindre(r_haut: float, r_bas: float, h: float, segments := 64) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_haut
	c.bottom_radius = r_bas
	c.height = h
	c.radial_segments = segments
	c.rings = 1
	return c


func _boule(r := 1.0, demi := false) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * (1.0 if demi else 2.0)
	s.is_hemisphere = demi
	s.radial_segments = 32
	s.rings = 16
	return s


func _disque() -> void:
	var d := Node3D.new()
	d.name = "Disque"
	add_child(d)
	# Le socle de terre et de roche, qui s'amincit dessous : on le voit du dos des éléphants.
	_piece(d, _cylindre(DISQUE, DISQUE - 3.0, 3.0, 96), _mat(Color(0.36, 0.27, 0.2)), Vector3(0, -1.6, 0))
	_piece(d, _cylindre(DISQUE - 3.0, 8.0, 2.0, 96), _mat(Color(0.3, 0.23, 0.18)), Vector3(0, -4.1, 0))
	# L'océan, qui fait le tour de l'île jusqu'au bord.
	var mer := _mat(Color(0.12, 0.32, 0.5), 0.15)
	mer.metallic = 0.25
	_piece(d, _cylindre(DISQUE - 0.02, DISQUE - 0.02, 0.2, 96), mer, Vector3(0, -0.2, 0))
	# La plage, puis l'herbe de l'île.
	_piece(d, _cylindre(ILE + 1.1, ILE + 1.6, 0.3, 96), _mat(Color(0.86, 0.77, 0.56)), Vector3(0, -0.15, 0))
	_piece(d, _cylindre(ILE, ILE + 0.6, 0.3, 96), _mat(Color(0.33, 0.52, 0.25)), Vector3(0, -0.12, 0))
	var sol := StaticBody3D.new()
	sol.name = "Sol"
	var forme := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = ILE
	cyl.height = 3.0
	forme.shape = cyl
	forme.position.y = -1.53
	sol.add_child(forme)
	d.add_child(sol)
	# La cascade : l'océan déborde tout autour du disque et se perd dans le vide.
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
void fragment() {
	float v = UV.y;
	float filet = fract(UV.x * 120.0 + sin(UV.x * 377.0) * 0.4);
	float flot = fract(v * 2.5 - TIME * 0.45 + sin(UV.x * 211.0) * 0.6);
	float ecume = smoothstep(0.55, 1.0, flot) * (0.6 + 0.4 * smoothstep(0.2, 0.5, filet));
	ALBEDO = mix(vec3(0.35, 0.6, 0.85), vec3(0.95, 0.98, 1.0), ecume * 0.7);
	ALPHA = pow(1.0 - v, 2.2) * (0.25 + 0.55 * ecume);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	var chute := _cylindre(DISQUE + 0.05, DISQUE + 5.0, 8.0, 96)
	chute.cap_top = false
	chute.cap_bottom = false
	var mi := _piece(d, chute, m, Vector3(0, -4.2, 0))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _ile() -> void:
	var ile := Node3D.new()
	ile.name = "Ile"
	add_child(ile)
	# Quelques arbres, à l'écart du chemin entre l'arrivée et la Porte.
	var arbres := [["tree_oak", Vector3(-6.5, 0, -2.0)], ["tree_default", Vector3(7.0, 0, -5.5)],
		["tree_fat", Vector3(-11.0, 0, 7.0)], ["tree_cone", Vector3(12.5, 0, 6.0)], ["tree_detailed", Vector3(-3.5, 0, -13.0)],
		["tree_oak_fall", Vector3(9.5, 0, -14.0)], ["tree_default", Vector3(-15.5, 0, -6.5)], ["tree_cone", Vector3(16.0, 0, -2.0)],
		["tree_fat_fall", Vector3(3.0, 0, 14.5)], ["tree_detailed", Vector3(-8.0, 0, 15.5)]]
	var g := RandomNumberGenerator.new()
	g.seed = 7
	for a in arbres:
		var n := Atelier.modele("nature/" + a[0], g.randf_range(2.0, 2.9))
		if n == null:
			continue
		n.position = a[1]
		n.rotation.y = g.randf() * TAU
		ile.add_child(n)
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
	_banc(ile, Vector3(0, 0, ILE - 1.2), 0.0)


## Le banc au bord du monde, tourné vers le vide.
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
	_piece(p, orne, _mat(OR, 0.35), Vector3(0, 2.34, 0))
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


# --- Les éléphants -------------------------------------------------------------------------------------------

## Un des quatre éléphants, debout sur la carapace, le dos sous le disque, la tête vers son point cardinal.
## Bâti en unités d'éléphant (le garrot à 1,0), puis mis à l'échelle pour toucher le disque.
func _elephant(nom: String, cap_deg: float) -> void:
	var cap := deg_to_rad(cap_deg)
	var dir := Vector3(sin(cap), 0, cos(cap))
	var pos := dir * ELEPHANTS_R
	var pied_y := _carapace_y(pos.x, pos.z)
	var haut := 1.48
	var echelle := (-4.0 - pied_y) / haut
	var e := Node3D.new()
	e.name = nom.replace("â", "a")
	e.position = Vector3(pos.x, pied_y, pos.z)
	e.rotation.y = cap
	e.scale = Vector3.ONE * echelle
	add_child(e)
	var peau := _mat(Color(0.47, 0.45, 0.47))
	var peau_sombre := _mat(Color(0.38, 0.36, 0.38))
	var ivoire := _mat(Color(0.93, 0.9, 0.8), 0.5)
	var rouge := _mat(Color(0.62, 0.08, 0.12), 0.7)
	var or_ := _mat(OR, 0.3)
	or_.metallic = 0.8
	_piece(e, _boule(0.5), peau, Vector3(0, 1.02, 0), Vector3.ZERO, Vector3(0.86, 0.78, 1.28))
	for x in [-0.25, 0.25]:
		for z in [-0.4, 0.38]:
			_piece(e, _cylindre(0.13, 0.155, 0.72, 16), peau_sombre, Vector3(x, 0.36, z))
			_piece(e, _cylindre(0.16, 0.165, 0.06, 16), ivoire, Vector3(x, 0.03, z))
	# La tête, les oreilles qui battent, la trompe en crosse et les défenses.
	_piece(e, _boule(0.33), peau, Vector3(0, 1.28, 0.74))
	for s in [-1.0, 1.0]:
		var o := Node3D.new()
		o.position = Vector3(0.24 * s, 1.36, 0.66)
		e.add_child(o)
		_piece(o, _boule(1.0), peau_sombre, Vector3(0.1 * s, -0.08, -0.05), Vector3.ZERO, Vector3(0.06, 0.36, 0.3))
		_oreilles.append([o, s])
		_piece(e, _cylindre(0.012, 0.04, 0.42, 10), ivoire, Vector3(0.13 * s, 1.0, 1.02), Vector3(deg_to_rad(-62), 0, deg_to_rad(-12 * s)))
	var trompe := [Vector3(0, 1.2, 1.0), Vector3(0, 0.98, 1.1), Vector3(0, 0.74, 1.13), Vector3(0, 0.52, 1.12), Vector3(0, 0.36, 1.2), Vector3(0, 0.32, 1.32)]
	for i in trompe.size() - 1:
		var a: Vector3 = trompe[i]
		var b: Vector3 = trompe[i + 1]
		var r := lerpf(0.11, 0.05, float(i) / (trompe.size() - 2))
		var seg := MeshInstance3D.new()
		seg.mesh = _cylindre(r * 0.9, r, a.distance_to(b) + 0.03, 12)
		seg.material_override = peau
		e.add_child(seg)
		seg.position = (a + b) * 0.5
		var axe := (b - a).normalized()
		seg.basis = Basis(Quaternion(Vector3.UP, axe))
	for s in [-1.0, 1.0]:
		_piece(e, _boule(0.04), _mat(Color(0.08, 0.06, 0.05), 0.4), Vector3(0.19 * s, 1.38, 0.97))
	_piece(e, _cylindre(0.015, 0.03, 0.5, 8), peau, Vector3(0, 0.82, -0.66), Vector3(deg_to_rad(25), 0, 0))
	# Le caparaçon rouge bordé d'or, et la selle d'or sur laquelle le disque repose.
	var drap := BoxMesh.new()
	drap.size = Vector3(0.9, 0.46, 0.74)
	_piece(e, drap, rouge, Vector3(0, 1.17, -0.02))
	var galon := BoxMesh.new()
	galon.size = Vector3(0.92, 0.05, 0.76)
	_piece(e, galon, or_, Vector3(0, 0.95, -0.02))
	_piece(e, _cylindre(0.36, 0.42, 0.1, 24), or_, Vector3(0, 1.44, 0))
	var front := BoxMesh.new()
	front.size = Vector3(0.22, 0.24, 0.03)
	_piece(e, front, rouge, Vector3(0, 1.4, 1.03), Vector3(deg_to_rad(-20), 0, 0))


## La hauteur du dessus de la carapace en (x, z).
func _carapace_y(x: float, z: float) -> float:
	var k := 1.0 - pow(x / CARAPACE.x, 2.0) - pow(z / CARAPACE.z, 2.0)
	return CARAPACE_Y + CARAPACE.y * sqrt(maxf(k, 0.0))


# --- Akoupara -----------------------------------------------------------------------------------------

func _tortue() -> void:
	var t := Node3D.new()
	t.name = "Akoupara"
	add_child(t)
	var sh := Shader.new()
	sh.code = """shader_type spatial;
// Les écailles de la carapace : un pavage d'hexagones vu de dessus, cernés de sombre, chacun sa teinte.
uniform vec3 fond : source_color = vec3(0.17, 0.24, 0.13);
uniform vec3 clair : source_color = vec3(0.36, 0.38, 0.2);
varying vec3 monde;
void vertex() { monde = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
vec2 hex(vec2 p) {
	vec2 r = vec2(1.0, 1.732);
	vec2 h = r * 0.5;
	vec2 a = mod(p, r) - h;
	vec2 b = mod(p - h, r) - h;
	return dot(a, a) < dot(b, b) ? a : b;
}
void fragment() {
	vec2 p = monde.xz / 13.0;
	vec2 g = hex(p);
	vec2 id = p - g;
	float n = fract(sin(dot(floor(id * 4.0), vec2(12.9898, 78.233))) * 43758.5453);
	// La distance au bord d'un hexagone (pointe en haut), le bord étant à 0,5.
	float bord = max(dot(abs(g), vec2(0.5, 0.866)), abs(g.x));
	float trait = smoothstep(0.43, 0.49, bord);
	vec3 c = mix(fond, clair, n * 0.6 + 0.2 * smoothstep(0.0, 0.4, bord));
	ALBEDO = mix(c, vec3(0.1, 0.09, 0.05), trait);
	ROUGHNESS = 0.65;
}
"""
	var ecailles := ShaderMaterial.new()
	ecailles.shader = sh
	var peau := _mat(Color(0.42, 0.47, 0.32))
	var ventre := _mat(Color(0.68, 0.62, 0.42))
	_piece(t, _boule(1.0, true), ecailles, Vector3(0, CARAPACE_Y, 0), Vector3.ZERO, CARAPACE)
	_piece(t, _boule(1.0), ventre, Vector3(0, CARAPACE_Y, 0), Vector3.ZERO, Vector3(CARAPACE.x * 0.96, 8.0, CARAPACE.z * 0.96))
	# Le cou et la tête, vers l'avant (+Z), les yeux ouverts sur les étoiles.
	_piece(t, _boule(1.0), peau, Vector3(0, CARAPACE_Y - 2.0, CARAPACE.z - 2.0), Vector3(deg_to_rad(-8), 0, 0), Vector3(9.0, 7.5, 14.0))
	_piece(t, _boule(1.0), peau, Vector3(0, CARAPACE_Y - 0.5, CARAPACE.z + 13.0), Vector3.ZERO, Vector3(10.0, 8.5, 12.0))
	for s in [-1.0, 1.0]:
		_piece(t, _boule(1.6), _mat(Color(0.95, 0.88, 0.6), 0.3), Vector3(5.6 * s, CARAPACE_Y + 2.6, CARAPACE.z + 19.0))
		_piece(t, _boule(0.9), _mat(Color(0.05, 0.04, 0.03), 0.2), Vector3(6.4 * s, CARAPACE_Y + 2.8, CARAPACE.z + 20.0))
	# Les nageoires, qui rament lentement.
	var nageoires := [[Vector3(44, -6, 30), Vector3(26, 2.6, 11), 28.0], [Vector3(-44, -6, 30), Vector3(26, 2.6, 11), -28.0],
		[Vector3(40, -6, -40), Vector3(17, 2.2, 9), -25.0], [Vector3(-40, -6, -40), Vector3(17, 2.2, 9), 25.0]]
	for i in nageoires.size():
		var n: Array = nageoires[i]
		var pivot := Node3D.new()
		var cote := signf((n[0] as Vector3).x)
		pivot.position = Vector3((n[0] as Vector3).x * 0.72, CARAPACE_Y + (n[0] as Vector3).y, (n[0] as Vector3).z)
		pivot.rotation.y = deg_to_rad(n[2])
		t.add_child(pivot)
		_piece(pivot, _boule(1.0), peau, Vector3(cote * (n[1] as Vector3).x * 0.55, 0, 0), Vector3.ZERO, n[1])
		_nageoires.append([pivot, cote, 0.0 if i < 2 else PI * 0.5])
	_piece(t, _cylindre(0.5, 4.0, 14.0, 16), peau, Vector3(0, CARAPACE_Y - 3.0, -CARAPACE.z - 4.0), Vector3(deg_to_rad(-80), 0, 0))


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
	var mi := _piece(lanterne, _boule(5.0), coeur, Vector3.ZERO)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var halo := StandardMaterial3D.new()
	halo.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo.albedo_color = Color(1.0, 0.82, 0.45, 0.16)
	halo.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi = _piece(lanterne, _boule(9.0), halo, Vector3.ZERO)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var o := OmniLight3D.new()
	o.light_color = Color(1.0, 0.75, 0.45)
	o.light_energy = 3.0
	o.omni_range = 70.0
	lanterne.add_child(o)


## La Lanterne au temps `t` : elle passe au-dessus du disque puis dessous, dans un plan qui tourne
## lentement, et la lumière du jour vient d'elle.
func _poser_lanterne(t: float) -> void:
	var a := deg_to_rad(LANTERNE_DEPART) + t * TAU / LANTERNE_TOUR
	var plan := deg_to_rad(35.0) + t * 0.01
	var p := LANTERNE_CENTRE + Basis(Vector3.UP, plan) * Vector3(cos(a) * LANTERNE_R, sin(a) * LANTERNE_R * 0.8, 0.0)
	lanterne.position = p
	if not p.is_equal_approx(Vector3.ZERO):
		soleil.look_at_from_position(p, Vector3.ZERO, Vector3.UP if absf(p.normalized().y) < 0.98 else Vector3.FORWARD)
	# Le jour sur l'île quand elle est au-dessus, une lueur dessous.
	soleil.light_energy = lerpf(0.25, 1.3, smoothstep(-0.15, 0.25, p.normalized().y))


# --- L'habitant, la caméra, l'interface -----------------------------------------------------------------

func _joueur() -> void:
	camera = Camera3D.new()
	camera.set_script(load("res://scripts/orbit_camera.gd"))
	camera.far = 1200.0
	add_child(camera)
	player = load("res://scripts/fp_player.gd").new()
	player.eye = 0.6
	player.body_height = 0.7
	player.radius = 0.14
	player.speed = 1.5
	player.reach = 2.4
	add_child(player)
	player.camera.far = 1200.0
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
	_plan.far = 1500.0
	_plan.fov = 42.0
	add_child(_plan)
	_plan.make_current()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# L'étoile filante : l'habitant qui tombe du ciel sur le disque.
	_etoile = Node3D.new()
	_etoile.name = "Etoile"
	add_child(_etoile)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.92, 0.7)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.85, 0.55)
	m.emission_energy_multiplier = 8.0
	_piece(_etoile, _boule(0.28), m, Vector3.ZERO)
	var traine := StandardMaterial3D.new()
	traine.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	traine.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	traine.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	traine.albedo_color = Color(1.0, 0.75, 0.4, 0.45)
	_piece(_etoile, _cylindre(0.22, 0.0, 6.0, 12), traine, Vector3(0, 3.0, 0))
	_eclat = OmniLight3D.new()
	_eclat.light_color = Color(1.0, 0.85, 0.6)
	_eclat.omni_range = 6.0
	_eclat.light_energy = 0.0
	_eclat.position = ARRIVEE + Vector3(0, 0.6, 0)
	add_child(_eclat)


func _interface() -> void:
	var ui := CanvasLayer.new()
	ui.name = "Interface"
	add_child(ui)
	var boite := VBoxContainer.new()
	boite.set_anchors_preset(Control.PRESET_TOP_WIDE)
	boite.offset_top = 70
	boite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boite.add_theme_constant_override("separation", 8)
	ui.add_child(boite)
	_titre = _mot(54, OR, Polices.titre())
	_titre.text = "LE DESSOUS"
	boite.add_child(_titre)
	_sous_titre = _mot(19, Color(0.82, 0.84, 0.92), Polices.texte())
	_sous_titre.text = "Sous toutes les cartes, Akoupara nage dans les étoiles."
	boite.add_child(_sous_titre)
	_bandeau = _mot(18, Color(0.95, 0.93, 0.88), Polices.texte())
	_bandeau.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bandeau.offset_top = -150
	_bandeau.offset_bottom = -80
	_bandeau.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bandeau.text = ("Vous êtes tombé à travers %s. Quatre éléphants portent ce monde ;\nla Porte des Joints vous y ramènera." % _lieu) if _lieu != "" \
		else "Quatre éléphants portent ce monde ;\nla Porte des Joints vous ramènera à la surface."
	_bandeau.modulate.a = 0.0
	ui.add_child(_bandeau)
	_passer = _mot(14, Color(0.7, 0.72, 0.8), Polices.texte())
	_passer.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_passer.offset_left = -330
	_passer.offset_top = -44
	_passer.offset_right = -24
	_passer.offset_bottom = -18
	_passer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_passer.text = "Une touche ou un clic : passer"
	ui.add_child(_passer)
	_prompt = _mot(20, Color(1, 1, 1), Polices.gras())
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


func _mot(taille: int, couleur: Color, police: Font) -> Label:
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	if police:
		l.add_theme_font_override("font", police)
	return l


# --- L'arrivée -------------------------------------------------------------------------------------------

## La mise en scène de l'arrivée au temps `t` (voir l'en-tête) : la caméra, l'étoile, les textes.
func _poser_plan(t: float) -> void:
	_arrivee = t
	var centre := Vector3(0, -24, 0)
	var vise := ARRIVEE + Vector3(0, 0.3, 0)
	var fin := vise + Vector3(0, sin(deg_to_rad(51.0)), cos(deg_to_rad(51.0))) * 18.0
	# De loin : un lent tour autour du monde entier.
	var tour := deg_to_rad(28.0) + t * 0.06
	var loin := centre + Vector3(sin(tour) * 250.0, 45.0, cos(tour) * 250.0)
	if t < T_LOIN:
		_plan.look_at_from_position(loin, centre)
	else:
		var u := smoothstep(0.0, 1.0, clampf((t - T_LOIN) / (T_DESCENTE - T_LOIN), 0.0, 1.0))
		# Une courbe qui passe au-dessus du bord du disque plutôt qu'à travers lui.
		var milieu := Vector3(loin.x * 0.35, 60.0, loin.z * 0.35)
		var p := loin.lerp(milieu, u).lerp(milieu.lerp(fin, u), u)
		_plan.look_at_from_position(p, centre.lerp(vise, smoothstep(0.0, 1.0, u * 1.3)))
		_plan.fov = lerpf(42.0, 30.0, u)
	# Les textes : le titre de loin, le bandeau à l'arrivée.
	_titre.modulate.a = clampf(t / 0.8, 0.0, 1.0) * clampf((T_DESCENTE - 1.0 - t) / 1.0, 0.0, 1.0)
	_sous_titre.modulate.a = clampf((t - 0.8) / 0.8, 0.0, 1.0) * clampf((T_DESCENTE - 1.0 - t) / 1.0, 0.0, 1.0)
	_bandeau.modulate.a = clampf((t - T_FIN + 0.4) / 0.6, 0.0, 1.0) * clampf((T_FIN + 9.0 - t) / 1.2, 0.0, 1.0)
	_passer.visible = t < T_FIN
	# L'étoile qui tombe, l'éclat à l'arrivée, puis l'habitant.
	var v := clampf((t - T_ETOILE) / (T_DESCENTE - 0.2 - T_ETOILE), 0.0, 1.0)
	_etoile.visible = t > T_ETOILE and v < 1.0
	var haut := ARRIVEE + Vector3(4.0, 42.0, -8.0)
	_etoile.position = haut.lerp(ARRIVEE + Vector3(0, 0.3, 0), v * v)
	var sens := (haut - ARRIVEE).normalized()
	_etoile.basis = Basis(Quaternion(Vector3.UP, sens))
	var e := clampf((t - (T_DESCENTE - 0.2)) / 1.4, 0.0, 1.0)
	_eclat.light_energy = 6.0 * (1.0 - e) * (1.0 if t > T_DESCENTE - 0.2 else 0.0)
	player.visible = t >= T_DESCENTE - 0.2
	player.frozen = t < T_FIN
	_poser_lanterne(_t)


## Passe la mise en scène : la main est à l'habitant, la caméra à crans le suit.
func _finir_arrivee() -> void:
	if not _en_arrivee:
		return
	_en_arrivee = false
	_poser_plan(maxf(_arrivee, T_FIN))
	player.visible = true
	player.frozen = false
	_etoile.visible = false
	camera.make_current()


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
		# Le bandeau d'arrivée s'efface tout seul.
		_bandeau.modulate.a = clampf((T_FIN + 9.0 - _arrivee) / 1.2, 0.0, 1.0)
	for n in _nageoires:
		(n[0] as Node3D).rotation.z = n[1] * sin(_t * 0.7 + n[2]) * 0.22
	for o in _oreilles:
		(o[0] as Node3D).rotation.y = o[1] * (0.15 + 0.12 * sin(_t * 1.3 + o[1]))
	if player != null and player.follow_camera == camera:
		camera.set("_target_goal", player.global_position + Vector3(0, 0.3, 0))
	_prompt.visible = not _en_arrivee and player != null and player.focus_target == porte


func _physics_process(_delta: float) -> void:
	if player == null:
		return
	# L'île est bordée par l'océan : on ne s'avance pas au-delà de la plage. Et si l'on passe malgré tout
	# à travers le disque, on retombe à l'arrivée.
	var h := Vector2(player.global_position.x, player.global_position.z)
	if h.length() > ILE - 0.6:
		h = h.normalized() * (ILE - 0.6)
		player.global_position = Vector3(h.x, player.global_position.y, h.y)
	if player.global_position.y < -6.0:
		player.global_position = ARRIVEE
		player.velocity = Vector3.ZERO
