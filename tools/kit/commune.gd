extends Node3D
## La scène de départ d'une commune de la Vienne, telle que la donne le kit du portail des
## développeurs. Le jeu fournit à toute commune la vue de dessus et la vue à pied (Tab, ou le bouton
## « Vue » au doigt), les commandes tactiles et la carte de la Vienne (dézoomer, ou M) : il suffit
## que la scène expose `player` (un habitant fp_player.gd) et `camera` (une caméra orbit_camera.gd).
## Gardez ces deux noms. Le reste est à vous : remplacez le sol, posez vos rues, vos maisons et vos
## lieux ; tout ce que la commune apporte reste sous res://communes/<id>/.
##
## Le kit ne pose aucun décor : un lieu se compose d'après sa note d'intentions (INTENTIONS.md, à côté de
## ce fichier), pas en partant d'une placette type. Lire docs/CONCEPTION.md avant le premier modèle. Les
## repères Vue1_…, Vue2_…, Vue3_… marquent les trois scènes fortes de la note : déplacez-les, renommez-les
## (Vue1_Belvedere), ajoutez-en aux coudes du chemin, puis tools/parcours_commune.gd pose l'habitant sur
## chacun, les photographie à hauteur de joueur et vérifie qu'on va de l'un à l'autre à pied.
## Le contrat est dans docs/COMMUNE.md.

## Les crans de la caméra de dessus : distance, tangage, champ, du plus près au plus loin.
const CRANS := [[9.0, -48.0, 34.0], [18.0, -51.0, 30.0], [32.0, -58.0, 30.0]]

## La lumière de départ, à régler d'après la note d'intentions (« Lumière et caméras ») : la hauteur du
## soleil en degrés, la direction d'où il vient (0 = nord, vers -Z ; 90 = est, vers +X ; 247 =
## ouest-sud-ouest) et sa couleur. Ici, une fin d'après-midi d'été.
const SOLEIL := {"hauteur": 27.0, "vient_de": 247.0, "couleur": Color(1.0, 0.95, 0.86)}

## Pour le jeu (vue, tactile, carte) : l'habitant qu'on dirige et la caméra à crans.
var player: CharacterBody3D
var camera: Camera3D


func _ready() -> void:
	_lumiere()
	_maquette()
	_joueur()


func _lumiere() -> void:
	var h := deg_to_rad(SOLEIL.hauteur)
	var a := deg_to_rad(SOLEIL.vient_de)
	$Soleil.look_at_from_position(Vector3.ZERO, Vector3(-sin(a) * cos(h), -sin(h), cos(a) * cos(h)))
	$Soleil.light_color = SOLEIL.couleur


## La maquette traversable : d'abord le relief, les parcours, les accès et les points de vue, éprouvés
## avec l'habitant et la caméra du jeu (CONCEPTION.md, « La méthode de travail »), puis le bâti. Ce que
## le socle prête sans rien peser dans le paquet (docs/COMMUNE.md, « L'atelier du socle ») :
##   Atelier.rue($Maquette, [[Transform3D(...), {"w": 4.0, "d": 3.5, "floors": 2}]])   des maisons à façades
##   Atelier.modele("nature/tree_oak_fall")   un modèle ; Atelier.modeles("nature") liste une famille
##   Atelier.personnage("livreur", 7)   un habitant qui joue un rôle ; Atelier.figurant(1, "sit") un figurant
##   Bibliotheque.matiere("matieres-de-minuit@1", "marbre_noir")   une matière de la bibliothèque commune
## Le vrai plan du bourg : python3 -I tools/bourg_reel.py <id>.
func _maquette() -> void:
	pass


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
	me.look = Cast.moi()
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
