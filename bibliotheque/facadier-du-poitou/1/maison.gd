extends Node3D
## Une maison du façadier du Poitou, posée telle quelle : on règle type, graine et options avant de l'ajouter
## à la scène, elle se bâtit à son entrée dans l'arbre. Repère du façadier : façade vers +Z, origine au pied
## de la façade, au milieu ; en mètres (une commune à l'échelle du village, 1 unité = 2,4 m, la pose à
## l'échelle 1/2,4).
##   var m = load(Bibliotheque.scene("facadier-du-poitou@1", "decor")).instantiate()
##   m.type = "notable" ; m.graine = 12 ; m.options = {"w": 8.0, "quartier": "basse"}
##   add_child(m)
## Après la construction, les métadonnées de la maison (type, graine, w, d, faite, porte, vegetal, traces)
## sont recopiées sur ce nœud : une commune y lit la largeur réelle pour aligner la suivante.
const F := preload("res://bibliotheque/facadier-du-poitou/1/facadier.gd")

## Les dix types : medievale, echoppe, balet, vigneron, notable, tailleur, grange, quai, ouvriere, forte.
@export var type := "medievale"
## La graine : deux maisons de même type et de graines différentes ne se ressemblent pas.
@export var graine := 1
## Les options du façadier, toutes facultatives : w et d (largeur et profondeur, en mètres), niveaux,
## quartier (la palette des menuiseries : cite, basse, quai, montee), pente (le dénivelé sous la façade, de
## gauche à droite), lumiere (la part des fenêtres allumées, 0 à 1), histoire (les traces imposées : une
## liste, ou false), vegetal (vigne, lierre, glycine, rosier, jardinieres, treille : un nom, une liste, true
## ou false), porte (la position de la porte en x).
@export var options := {}

var maison: Node3D


func _ready() -> void:
	if maison != null:
		return
	maison = F.maison(self, Vector3.ZERO, type, graine, options)
	for k in maison.get_meta_list():
		set_meta(k, maison.get_meta(k))


## Les types du façadier, pour une commune qui les tire au hasard.
static func types() -> Array:
	return F.TYPES.duplicate()
