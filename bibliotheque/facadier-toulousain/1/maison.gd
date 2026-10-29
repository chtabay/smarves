extends Node3D
## Une maison du façadier toulousain, posée telle quelle : on règle type, graine et options avant de l'ajouter
## à la scène, elle se bâtit à son entrée dans l'arbre. Repère : façade vers +Z, origine au pied de la façade,
## au milieu, le corps vers −Z ; en mètres (une commune à l'échelle du village de Smarves, 1 unité = 2,4 m, la
## pose à l'échelle 1/2,4).
##   var m = load(Bibliotheque.scene("facadier-toulousain@1", "decor")).instantiate()
##   m.type = "cafe" ; m.graine = 4 ; m.options = {"enseigne": "CAFÉ DES ARCADES", "brique": "saumon"}
##   add_child(m)
## Après la construction, les métadonnées de la maison (type, graine, w, d, hauteur) sont recopiées sur ce
## nœud : une commune y lit la largeur réelle pour aligner la suivante.
const F := preload("res://bibliotheque/facadier-toulousain/1/facadier.gd")

## Les treize bâtisses : atelier, etroite, moyenne, immeuble, angle, arcades, cafe, commerce, restaurant, hotel,
## lafage, wilson, colombages.
@export var type := "moyenne"
## La graine : deux maisons de même type et de graines différentes ne se ressemblent pas.
@export var graine := 1
## Les options du façadier, toutes facultatives : voir l'en-tête de facadier.gd.
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
