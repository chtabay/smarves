extends Node3D
## La scène de départ d'une commune de la Vienne, telle que la donne le kit du portail des
## développeurs. Le jeu fournit à toute commune la vue de dessus et la vue à pied (Tab, ou le bouton
## « Vue » au doigt), les commandes tactiles et la carte de la Vienne (dézoomer, ou M) : il suffit
## que la scène expose `player` (un habitant fp_player.gd) et `camera` (une caméra orbit_camera.gd).
## Gardez ces deux noms. Le reste est à vous : remplacez le sol, posez vos rues, vos maisons et vos
## lieux ; tout ce que la commune apporte reste sous res://communes/<id>/.
##
## Les maisons, les arbres, les bancs et les figurants d'exemple viennent de l'atelier du socle (Atelier,
## scripts/socle/atelier.gd) : des ressources que le jeu prête à toutes les communes, sous des noms qui
## ne changent pas. Ils ne pèsent rien dans le paquet. Le catalogue : docs/COMMUNE.md, « L'atelier du
## socle ». Le contrat est dans docs/COMMUNE.md.

## Les crans de la caméra de dessus : distance, tangage, champ, du plus près au plus loin.
const CRANS := [[9.0, -48.0, 34.0], [18.0, -51.0, 30.0], [32.0, -58.0, 30.0]]

## Pour le jeu (vue, tactile, carte) : l'habitant qu'on dirige et la caméra à crans.
var player: CharacterBody3D
var camera: Camera3D


func _ready() -> void:
	_decor()
	_joueur()


## La place d'exemple, à remplacer par la vôtre : deux maisons de bourg, deux arbres, un banc et trois
## figurants (deux en conversation, un assis).
func _decor() -> void:
	# Repère d'une maison : l'origine au pied de la façade, au milieu ; +Z regarde la rue.
	Atelier.rue($Maisons, [
		[Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(-6, 0, 0)), {"w": 4.0, "d": 3.5, "floors": 2}],
		[Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(6, 0, 0)), {"w": 3.5, "d": 3.0, "floors": 2,
			"shop": {"name": "Le café", "color": Color(0.5, 0.16, 0.18), "ink": Color(1.0, 0.92, 0.7)}}],
	])
	# Les arbres d'automne de Smarves ; Atelier.modeles("nature") donne les autres.
	for a in [["nature/tree_oak_fall", -3.2], ["nature/tree_default_fall", 3.4]]:
		var arbre := Atelier.modele(a[0])
		arbre.position = Vector3(a[1], 0, -3.8)
		$Decor.add_child(arbre)
	var banc := Atelier.modele("ville/bench", 0.24)
	banc.position = Vector3(3.2, 0, 2.5)
	banc.rotation.y = -PI / 2.0
	$Decor.add_child(banc)
	for f in [[1, Vector3(-1.6, 0, -1.2), 0.9, "idle"], [2, Vector3(-0.9, 0, -1.6), -2.3, "idle"], [3, Vector3(3.2, 0.1, 2.5), -PI / 2.0, "sit"]]:
		var p := Atelier.figurant(f[0], f[3])
		p.position = f[1]
		p.rotation.y = f[2]
		$Decor.add_child(p)


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
