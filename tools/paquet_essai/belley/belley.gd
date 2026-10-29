extends Node3D
## Belley, capitale du Bugey (01034), à l'échelle réelle (en mètres) : x vers l'est, z vers le sud, depuis la
## place de la Victoire ; y = altitude − 200 m. La note d'intentions (INTENTIONS.md) dit ce qu'on y construit ;
## chaque zone a ses fichiers (relief/, puis les places, la colline, le Rhône).

const DOSSIER := "res://communes/belley/"
const TERRAIN := preload("res://communes/belley/relief/terrain.gd")
const CATHEDRALE := preload("res://communes/belley/places/cathedrale.gd")
const VILLE := preload("res://communes/belley/places/ville.gd")
const PLACE := preload("res://communes/belley/places/place_cathedrale.gd")
const RELAIS := preload("res://communes/belley/places/relais.gd")
const ROUTES := preload("res://communes/belley/places/routes.gd")

## Les crans de la caméra de dessus : distance, tangage, champ, du plus près au plus loin (à taille d'homme).
const CRANS := [[5.0, -38.0, 50.0], [9.0, -48.0, 50.0], [16.0, -58.0, 50.0]]

## La lumière de la note : fin septembre vers 16 h, le soleil au sud-ouest, à 28°, crème chaud.
const SOLEIL := {"hauteur": 28.0, "vient_de": 238.0, "couleur": Color("fff0dc"), "force": 0.55}

## Les trois scènes fortes et l'arrivée : [x, z, lacet en degrés (0 : regarde le nord, 90 : l'est)].
const REPERES := {
	"Arrivee": [40.0, -20.0, 135.0],
	"Vue1_Cathedrale": [165.0, 318.0, 120.0],
	"Vue2_Banc": [3784.0, 1578.0, 100.0],
	"Vue3_Relais": [7150.0, 640.0, 60.0],
}

var player: CharacterBody3D
var camera: Camera3D
var terrain: Node3D


func _ready() -> void:
	_ciel()
	terrain = TERRAIN.new()
	terrain.name = "Terrain"
	add_child(terrain)
	terrain.construire()
	_cathedrale()
	VILLE.new(hauteur).batir(self)
	PLACE.new(hauteur).batir(self)
	ROUTES.new(hauteur).batir(self)
	RELAIS.new(hauteur).batir(self)
	_reperes()
	_joueur()


## La cathédrale, posée sur le point le plus haut de son parvis.
func _cathedrale() -> void:
	var c := CATHEDRALE.new()
	var y := -INF
	for d in [Vector2(0, 0), Vector2(-10, 0), Vector2(10, 0)]:
		var a := deg_to_rad(CATHEDRALE.AXE_DEG)
		var p: Vector2 = CATHEDRALE.ORIGINE + Vector2(-sin(a), cos(a)) * d.x
		y = maxf(y, hauteur(p.x, p.y))
	c.batir(self, y + 0.9)


func hauteur(x: float, z: float) -> float:
	return terrain.sol(x, z)


func _ciel() -> void:
	var ciel := ProceduralSkyMaterial.new()
	ciel.sky_top_color = Color("6c9fd6")
	ciel.sky_horizon_color = Color("d9dcd2")
	ciel.sky_curve = 0.12
	ciel.ground_horizon_color = Color("c9c8b8")
	ciel.ground_bottom_color = Color("7d7c6a")
	ciel.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = ciel
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	# Des ombres chaudes, comme sur la planche : une part de lumière ambiante crème, une part de ciel.
	env.ambient_light_color = Color("e2dccf")
	env.ambient_light_sky_contribution = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# La brume de distance : les crêtes à 15 km passent au bleu gris, sans disparaître.
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	env.fog_light_color = Color("a9b7c4")
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
	soleil.shadow_opacity = 0.6
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
