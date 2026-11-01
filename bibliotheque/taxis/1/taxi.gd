extends Node3D
## Le taxi de la bibliothèque : la berline de l'atelier des véhicules (scripts/socle/taxi.gd), garée telle quelle ou
## à mettre en mouvement par la commune. On règle livree et options avant de l'ajouter à la scène ; elle se bâtit à
## son entrée dans l'arbre. Les roues sur un sol plat à y = 0, le centre à l'origine, l'avant vers +Z ; en mètres.
##   var t = load(Bibliotheque.scene("taxis@1", "decor")).instantiate()
##   t.livree = "jaune" ; t.options = {"commune": "Toulouse", "plaque": "TX-031-TL"}
##   add_child(t)
## Deux livrées : « bleu-nuit » (laque bleu nuit qui chatoie, le taxi de Smarves) et « jaune » (jaune d'or laqué,
## damier noir et blanc sous les glaces). Toutes deux portent le lumineux blanc « TAXI » et ses lampes de tarif.
## Les options, toutes facultatives : commune (« TAXI · <COMMUNE> » sur les portières arrière), plaque (le numéro,
## sinon celui de la livrée). Après la construction, le nœud porte ses métadonnées : livree, emprise (Vector2, la
## taille au sol), longueur.

## La livrée (voir noms()).
@export var livree := "bleu-nuit"
## Les options : commune, plaque.
@export var options := {}

var fait := false


func _ready() -> void:
	if fait:
		return
	fait = true
	if not livree in Taxi.LIVREES:
		livree = "bleu-nuit"
	var caisse := Node3D.new()
	caisse.name = "Taxi"
	add_child(caisse)
	Taxi.batir(caisse, str(options.get("commune", "")), Polices.texte(), livree, str(options.get("plaque", "")))
	# Un corps pour qu'on ne traverse pas la voiture garée.
	var corps := StaticBody3D.new()
	var forme := CollisionShape3D.new()
	var boite := BoxShape3D.new()
	boite.size = Vector3(Taxi.LARGE, 1.45, Taxi.LONG)
	forme.shape = boite
	forme.position.y = 0.725
	corps.add_child(forme)
	add_child(corps)
	set_meta("livree", livree)
	set_meta("emprise", Vector2(Taxi.LARGE, Taxi.LONG))
	set_meta("longueur", Taxi.LONG)


## Les livrées, sous le nom commun aux autres briques.
static func noms() -> Array:
	return Taxi.LIVREES.duplicate()
