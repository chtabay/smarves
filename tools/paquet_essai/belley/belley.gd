extends Node3D
## Belley, capitale du Bugey (01034), à l'échelle réelle (en mètres) : x vers l'est, z vers le sud, depuis la
## place de la Victoire ; y = altitude − 200 m. La note d'intentions (INTENTIONS.md) dit ce qu'on y construit ;
## chaque zone a ses fichiers (relief/, puis les places, la colline, le Rhône).

const DOSSIER := "res://communes/belley/"
const TERRAIN := preload("res://communes/belley/relief/terrain.gd")
const CATHEDRALE := preload("res://communes/belley/places/cathedrale.gd")
const VILLE := preload("res://communes/belley/places/ville.gd")
const BANC := preload("res://communes/belley/places/banc.gd")
const PLACE := preload("res://communes/belley/places/place_cathedrale.gd")
const RELAIS := preload("res://communes/belley/places/relais.gd")
const VIE := preload("res://communes/belley/places/vie_place.gd")
const JARDINS := preload("res://communes/belley/places/jardins.gd")
const ROUTES := preload("res://communes/belley/places/routes.gd")
const BORDS := preload("res://communes/belley/places/bords_de_route.gd")
const MOBYLETTE := preload("res://communes/belley/places/mobylette.gd")

## Les crans de la caméra de dessus : distance, tangage, champ, du plus près au plus loin (à taille d'homme).
const CRANS := [[5.0, -38.0, 50.0], [9.0, -48.0, 50.0], [16.0, -58.0, 50.0]]

## La lumière de la note : fin septembre vers 16 h, le soleil au sud-ouest, à 28°, crème chaud.
const SOLEIL := {"hauteur": 28.0, "vient_de": 238.0, "couleur": Color("fff0dc"), "force": 0.65}

## Les trois scènes fortes et l'arrivée : [x, z, lacet en degrés (0 : regarde le nord, 90 : l'est)].
const REPERES := {
	"Arrivee": [40.0, -20.0, 135.0],
	# Dans la rue des Barons, au tronçon le plus serré (moins de 4 m de part et d'autre) : la place s'ouvre en
	# avançant (verdicts n° 18 et 19).
	"Vue1_Cathedrale": [119.0, 296.0, 113.5],
	# Sur l'épaule de la colline, à 527 m, d'où l'on voit le Rhône par-dessus la pente de 65 à 130° (revue finale
	# n° 1) : du premier repère (3784, 1578), une bosse à 600 m le cachait.
	"Vue2_Banc": [4200.0, 2160.0, 108.0],
	"Vue3_Relais": [7150.0, 640.0, 60.0],
}

var player: CharacterBody3D
var camera: Camera3D
var terrain: Node3D
## L'invite en bas de l'écran (places/mobylette.gd), que l'interface tactile lit aussi.
var _prompt: Label


func _ready() -> void:
	_ciel()
	_saturer_briques()
	terrain = TERRAIN.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.construire()
	_cathedrale()
	VILLE.new(hauteur).batir(self)
	PLACE.new(hauteur).batir(self)
	JARDINS.new(hauteur).batir(self)
	VIE.new(hauteur).batir(self)
	ROUTES.new(hauteur).batir(self)
	BORDS.new(hauteur).batir(self)
	RELAIS.new(hauteur).batir(self)
	var rb: Array = REPERES["Vue2_Banc"]
	BANC.new(hauteur).batir(self, rb[0], rb[1], rb[2])
	# Le relais et le banc, à 7 et 4 km de la ville, ne se dessinent que de près : vus d'ailleurs, ils ne sont
	# que quelques pixels, et comptaient en entier au budget du lieu (3 M de triangles pour 600 000).
	_portee($RelaisDesLones, 1600.0)
	_portee($BancAuReplat, 1200.0)
	var t0 := Time.get_ticks_msec()
	# Le sol aussi : ses carreaux ont une jupe (relief/terrain.gd), qui cache les fentes entre deux niveaux.
	for c in get_children():
		_niveaux_de_detail(c)
	print("niveaux de détail en ", Time.get_ticks_msec() - t0, " ms")
	# Les maisons du façadier au-delà du premier rang de la place passent plus tôt à leurs niveaux allégés.
	for m: MeshInstance3D in $Facadier.find_children("*", "MeshInstance3D", true, false):
		if Vector2(m.global_position.x, m.global_position.z).distance_to(VILLE.PRES_DE) > VILLE.FACADIERS_DETAILLES:
			m.lod_bias = 0.35
	_reperes()
	_joueur()
	add_child(MOBYLETTE.new(self))


## La cathédrale, posée sur le point le plus haut de son parvis.
func _cathedrale() -> void:
	var c := CATHEDRALE.new()
	var y := -INF
	for d in [Vector2(0, 0), Vector2(-10, 0), Vector2(10, 0)]:
		var a := deg_to_rad(CATHEDRALE.AXE_DEG)
		var p: Vector2 = CATHEDRALE.ORIGINE + Vector2(-sin(a), cos(a)) * d.x
		y = maxf(y, hauteur(p.x, p.y))
	c.batir(self, y + 0.9)


## Les maillages de Belley et des briques n'ont pas de niveaux de détail (une maison du façadier pèse jusqu'à
## 50 000 triangles) : on les leur calcule (ImporterMesh.generate_lods), pour que le lointain se dessine allégé.
func _niveaux_de_detail(n: Node) -> void:
	var faits := {}
	for mi: MeshInstance3D in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi.mesh as ArrayMesh
		if m == null:
			continue
		if not faits.has(m):
			var im := ImporterMesh.new()
			for s in m.get_surface_count():
				im.add_surface(m.surface_get_primitive_type(s), m.surface_get_arrays(s), [], {}, m.surface_get_material(s), m.surface_get_name(s))
			im.generate_lods(25.0, 60.0, [])
			faits[m] = im.get_mesh()
		mi.mesh = faits[m]


func _portee(n: Node, fin: float) -> void:
	for g: GeometryInstance3D in n.find_children("*", "GeometryInstance3D", true, false):
		if g.visibility_range_end <= 0.0 or g.visibility_range_end > fin:
			g.visibility_range_end = fin
			g.visibility_range_end_margin = 100.0


func hauteur(x: float, z: float) -> float:
	return terrain.sol(x, z)


## Les briques de Belley prennent un matériau « dur » à saturation sélective (atelier/sature.gdshader, verdict
## n° 24) : on le pose dans leur cache de matériaux avant qu'elles ne bâtissent.
func _saturer_briques() -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://communes/belley/atelier/sature.gdshader")
	for brique in ["facadier-du-bugey", "mobilier-du-bugey"]:
		var outils: GDScript = load("res://bibliotheque/%s/1/outils.gd" % brique)
		outils._materiaux[0] = m


func _ciel() -> void:
	var ciel := ShaderMaterial.new()
	ciel.shader = load("res://communes/belley/atelier/ciel.gdshader")
	var sky := Sky.new()
	sky.sky_material = ciel
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.4
	# Des ombres chaudes, comme sur la planche : une part de lumière ambiante crème, une part de ciel.
	env.ambient_light_color = Color("e2dccf")
	env.ambient_light_sky_contribution = 0.6
	# Linéaire : en ACES (blanc 1,6), le rendu de compatibilité délave tout, mesuré (verdict n° 21). Un soleil
	# plus bas assombrissait la vue d'ensemble (verdict n° 22) : la lumière garde sa force, et les façades en plein
	# soleil prennent un enduit plus sourd (ville.gd). La saturation est celle de la planche (verdict n° 23), au prix
	# d'un rouge un peu écrêté sur ces façades.
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# L'étalonnage des planches : un peu plus saturé, un peu plus contrasté (mesuré : le rendu de compatibilité l'honore).
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.1
	# Une courbe de tons qui relève les demi-teintes sans toucher aux blancs (gamma 0,88) : la médiane de la vue
	# d'ensemble remonte vers celle de la planche (147) sans rallumer l'écrêtage des façades (verdict n° 22).
	var courbe := Gradient.new()
	courbe.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR
	courbe.remove_point(1)
	courbe.set_color(0, Color.BLACK)
	for k in range(1, 17):
		var x := k / 16.0
		var y := pow(x, 0.88)
		courbe.add_point(x, Color(y, y, y))
	var lut := GradientTexture1D.new()
	lut.gradient = courbe
	lut.width = 256
	env.adjustment_color_correction = lut
	# La brume de distance : les crêtes à 15 km passent au bleu gris, sans disparaître.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	# Bleu-gris : les lointains à 11 km sortaient blancs (revue finale n° 1, visée #93A6AE).
	env.fog_light_color = Color("93a6ae")
	env.fog_density = 0.00005
	env.fog_aerial_perspective = 0.2
	env.fog_sky_affect = 0.0
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var soleil := DirectionalLight3D.new()
	soleil.name = "Soleil"
	add_child(soleil)
	var h := deg_to_rad(SOLEIL.hauteur)
	var a := deg_to_rad(SOLEIL.vient_de)
	soleil.look_at_from_position(Vector3.ZERO, Vector3(-sin(a) * cos(h), -sin(h), cos(a) * cos(h)))
	soleil.light_color = SOLEIL.couleur
	soleil.light_energy = SOLEIL.force
	soleil.shadow_enabled = true
	soleil.directional_shadow_max_distance = 220.0
	# Des ombres de dessin animé : franches mais pas noires, le bord adouci.
	soleil.shadow_opacity = 0.95
	soleil.shadow_blur = 1.5


func _reperes() -> void:
	for nom in REPERES:
		var r: Array = REPERES[nom]
		var m: Node3D = get_node(nom)
		m.position = Vector3(r[0], hauteur(r[0], r[1]) + 0.05, r[1])
		# Le -Z du repère regarde ce qu'on doit voir : un lacet de 0 regarde le nord (-Z).
		m.rotation.y = -deg_to_rad(r[2])


## L'habitant à taille d'homme et la caméra à crans, sur le repère « Arrivee ».
func _joueur() -> void:
	camera = Camera3D.new()
	camera.set_script(load("res://scripts/orbit_camera.gd"))
	camera.far = 40000.0
	camera.near = 0.1
	add_child(camera)
	player = load("res://scripts/fp_player.gd").new()
	player.eye = 1.6
	player.body_height = 1.7
	player.radius = 0.3
	player.speed = 3.2
	player.reach = 2.6
	add_child(player)
	player.camera.far = 40000.0
	var me: Node3D = load("res://scripts/critter.gd").new()
	me.look = Cast.moi()
	me.walk_speed = 2.4
	me.run_speed = 4.4
	me.scale = Vector3.ONE * 2.4
	me.rotation.y = PI
	player.add_child(me)
	player.avatar = me
	player.global_transform = $Arrivee.global_transform
	camera.make_current()
	player.follow_camera = camera
	camera.au_dela.connect(func(): Carte.ouvrir())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera.target = player.global_position + Vector3(0, 1.0, 0)
	camera.set("_target_goal", camera.target)
	camera.use_notches(CRANS, 1)
