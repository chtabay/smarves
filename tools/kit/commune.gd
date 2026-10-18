extends Node3D
## La scène de départ d'une commune de la Vienne, telle que la donne le kit du portail des
## développeurs. Le jeu fournit à toute commune la vue de dessus et la vue à pied (Tab, ou le bouton
## « Vue » au doigt), les commandes tactiles et la carte de la Vienne (dézoomer, ou M) : il suffit
## que la scène expose `player` (un habitant fp_player.gd) et `camera` (une caméra orbit_camera.gd).
## Gardez ces deux noms. Le reste est à vous : remplacez le sol, posez vos rues, vos maisons et vos
## lieux ; tout ce que la commune apporte reste sous res://communes/<id>/.
##
## Les maisons d'exemple sont les façades du Poitou de Smarves (res://scripts/village/facades.gd),
## que le jeu prête à toutes les communes. Le contrat est dans docs/COMMUNE.md.

const FACADES := preload("res://scripts/village/facades.gd")
## Les crans de la caméra de dessus : distance, tangage, champ, du plus près au plus loin.
const CRANS := [[9.0, -48.0, 34.0], [18.0, -51.0, 30.0], [32.0, -58.0, 30.0]]

## Pour le jeu (vue, tactile, carte) : l'habitant qu'on dirige et la caméra à crans.
var player: CharacterBody3D
var camera: Camera3D


func _ready() -> void:
	_facades()
	_joueur()


## Deux maisons de bourg de part et d'autre de la place, à remplacer par les vôtres.
func _facades() -> void:
	var mats := _materiaux()
	var f = FACADES.new($Maisons, Polices.texte(), 1)
	# Repère d'une maison : l'origine au pied de la façade, au milieu ; +Z regarde la rue.
	f.house(Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(-6, 0, 0)), {"w": 4.0, "d": 3.5, "floors": 2})
	f.house(Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(6, 0, 0)), {"w": 3.5, "d": 3.0, "floors": 2,
		"shop": {"name": "Le café", "color": Color(0.5, 0.16, 0.18), "ink": Color(1.0, 0.92, 0.7)}})
	f.commit(mats, mats.glass, "Maisons")


## Les matières du village de Smarves : la teinte vient du sommet, le grain des nuanceurs du jeu.
func _materiaux() -> Dictionary:
	var stone: Shader = load("res://shaders/village_stone.gdshader")
	var wall := ShaderMaterial.new()
	wall.shader = stone
	var trim := ShaderMaterial.new()
	trim.shader = stone
	var roof := ShaderMaterial.new()
	roof.shader = load("res://shaders/roof_tiles.gdshader")
	var glass := ShaderMaterial.new()
	glass.shader = load("res://shaders/window_glow.gdshader")
	glass.set_shader_parameter("energy", 1.6)
	return {"wall": wall, "trim": trim, "roof": roof, "glass": glass}


## L'habitant de Smarves et la caméra à crans du village, posés sur le repère « Arrivee ».
func _joueur() -> void:
	camera = Camera3D.new()
	camera.set_script(load("res://scripts/orbit_camera.gd"))
	camera.far = 400.0
	add_child(camera)
	player = load("res://scripts/fp_player.gd").new()
	player.eye = 0.6
	player.body_height = 0.7
	player.radius = 0.14
	player.speed = 1.5
	player.reach = 2.4
	add_child(player)
	var me: Node3D = load("res://scripts/critter.gd").new()
	me.look = Cast.player(Biens.worn)
	me.walk_speed = 1.0
	me.run_speed = 1.9
	me.rotation.y = PI
	player.add_child(me)
	player.avatar = me
	player.global_transform = $Arrivee.global_transform
	camera.make_current()
	player.follow_camera = camera
	camera.au_dela.connect(func(): Carte.ouvrir())
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera.target = player.global_position + Vector3(0, 0.3, 0)
	camera.set("_target_goal", camera.target)
	camera.use_notches(CRANS, 1)
