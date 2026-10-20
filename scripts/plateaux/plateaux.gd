class_name Plateaux
extends RefCounted
## La brique « plateaux » du socle (docs/COMMUNE.md, « Les échecs du Cercle ») : les échecs du casino de
## Smarves, prêtés aux communes, sans rien recopier. Trois pièces, chacune utilisable seule :
## - le panneau de la partie (scripts/plateaux/echecs_panel.gd) : l'échiquier à la manière de chess.com
##   (scripts/plateaux/echiquier.gd), les pendules, les réglages (cadence, couleurs, mise), la feuille
##   de partie et le bouton « Règles » ;
## - la table 3D (scripts/plateaux/table_echecs_3d.gd), qui montre la position en pièces tournées ;
## - la salle toute faite, le Cercle Philidor (scripts/socle/cercle.gd).
## Les règles, les robots, la pendule et les mises sont tenus par le serveur (fonction casino du dépôt
## chtabay/addict, smarves-plateaux.js) : une commune qui veut ses propres tables les y fait ajouter,
## comme pour le poker (« minuit:echecs-1 », par exemple), et les annonce ici par leur identifiant.
##
##   var p := Plateaux.panneau("cercle:echecs-1", "Échecs · Table 1")
##   p.closed.connect(p.queue_free)
##   calque.add_child(p)                 # un Control plein écran, habillé de Tables.theme()
##
##   Plateaux.cercle("smarves", "res://communes/la_mienne/scene.tscn", "devant-le-cercle")

const PANNEAU := preload("res://scripts/plateaux/echecs_panel.gd")
const TABLE := preload("res://scripts/plateaux/table_echecs_3d.gd")
const VERSION := "echecs@1"


## Le panneau d'une table d'échecs du serveur ; il s'assied en entrant dans la scène et se lève en
## émettant closed.
static func panneau(table_id: String, titre := "") -> PanelContainer:
	var p: PanelContainer = PANNEAU.new()
	p.table_id = table_id
	p.title = titre
	return p


## Une table d'échecs 3D (guéridon, échiquier, pièces) ; montrer(plateau) pose une position.
static func table() -> Node3D:
	return TABLE.new()


## Ouvre le Cercle d'un casino ; sa porte ramène à la scène `retour`, au point `point`.
static func cercle(casino := "smarves", retour := "res://scenes/casino.tscn", point := "cercle") -> void:
	Cercle.ouvrir(casino, retour, point)
