class_name Ancres
extends RefCounted
## Les contrats d'ancres (socle 1.13 ; la salle, 1.14) : ce qu'un décor doit montrer pour que le socle y branche son
## comportement. Une ancre est un nœud 3D nommé (un Marker3D, le plus souvent), n'importe où sous la racine du
## décor ; le socle y pose ce qui est à lui (le club, son match, sa gestion) et rien d'autre. Le décor ne
## connaît ni le club ni le championnat ; le socle ne connaît du décor que ses ancres.
##
## Orientation : l'axe +Z d'une ancre regarde le visiteur (c'est la face lisible d'un Label3D, et la direction
## où regarde un personnage posé dessus). Le mode d'emploi est dans docs/BIBLIOTHEQUE.md.

## Le stade : ce que le socle branche sur n'importe quel stade, qu'il vienne de la bibliothèque ou d'une
## commune, sans que son script hérite de scripts/village/stade.gd.
##   requis : sans elle, le décor est refusé et le stade du socle prend sa place.
const STADE := {
	"Pelouse": {"requis": true, "role": "le centre du terrain : le socle y trace la pelouse de 36 × 22 (longueur selon x), ses buts, ses bancs et sa main courante, et y joue le match. Elle est à l'origine du décor, sans rotation."},
	"Arrivee": {"requis": true, "role": "où le visiteur paraît en entrant, tourné vers son +Z"},
	"Sortie": {"requis": true, "role": "la porte du retour : le socle y met la sortie vers la commune"},
	"Tableau": {"requis": true, "role": "le tableau d'affichage : le socle y écrit le score, la minute et l'affiche, et y pend la feuille du dernier match"},
	"President": {"requis": true, "role": "où se tient le président du club : le socle y pose le personnage et sa causerie"},
	"Bureau": {"requis": true, "role": "le bureau du président : la gestion du club (effectif, tactique, mercato, obligations)"},
	"Panneau": {"requis": true, "role": "le panneau du club : le classement, le prochain match et le registre des obligations"},
	"TribuneClub": {"requis": false, "role": "le fronton de la tribune du club : le socle y écrit le nom du club et du stade, à ses couleurs"},
	"Buvette": {"requis": false, "role": "la buvette : le socle y fait parler la tenancière"},
}

## Ce qu'un décor de stade peut faire de plus (socle 1.18), s'il en a la méthode ; aucune n'est requise. Le
## décor connaît alors le stade : c'est le cas d'un décor de commune qui vit (Casino Minuit, le stade de la
## Fortune), pas d'une brique de la bibliothèque, qui se suffit de ses ancres.
const CROCHETS := {
	"nuit": "nuit(stade) : la nuit du stade (le ciel, la lune, les projecteurs), à la place de celle du socle",
	"brancher": "brancher(stade) : appelé une fois le stade posé (le terrain, le président, le match, le visiteur)",
	"interagir": "interagir(cle, cible) -> bool : chaque interaction passe d'abord par le décor ; vrai s'il l'a prise",
}

## La salle de basket (socle 1.14) : ce que le socle branche sur n'importe quelle salle, de la bibliothèque ou
## d'une commune, sans que son script hérite de scripts/village/salle_basket.gd.
const SALLE := {
	"Parquet": {"requis": true, "role": "le rond central : le socle y pose le parquet de 28 × 15 (longueur selon x) et ses abords, les paniers, les bancs, la table de marque, et y fait jouer le club. Elle est à l'origine du décor, sans rotation."},
	"Arrivee": {"requis": true, "role": "où le visiteur paraît en entrant, tourné vers son +Z"},
	"Sortie": {"requis": true, "role": "l'arrêt du car : le socle y met le retour vers la commune"},
	"Cube": {"requis": true, "role": "le centre du cube d'écrans, au-dessus du parquet : le socle y pend le score sur quatre faces"},
	"President": {"requis": true, "role": "où se tient le président du club : le socle y pose le personnage et sa causerie"},
	"Bureau": {"requis": true, "role": "le bureau du président : la gestion de l'équipe"},
	"Panneau": {"requis": true, "role": "le panneau du club : le classement, le prochain match et l'effectif"},
	"Parts": {"requis": true, "role": "le tableau des parts du club : les porteurs et l'achat de parts"},
	"Fronton": {"requis": false, "role": "l'enseigne de la salle : le socle y écrit le nom du club et de la salle, à ses couleurs"},
}

## Les contrats par genre de brique, et l'ancre qui doit être à l'origine du décor.
const CONTRATS := {"stade": STADE, "salle": SALLE}
const ORIGINES := {"stade": "Pelouse", "salle": "Parquet"}

## La tolérance sur la place de la pelouse (en unités du jeu, et en radians).
const ECART := 0.05


## Une ancre du décor, cherchée par son nom sous la racine, ou null.
static func trouver(racine: Node, nom: String) -> Node3D:
	if racine == null:
		return null
	if racine.name == nom and racine is Node3D:
		return racine
	return racine.find_child(nom, true, false) as Node3D


## Les fautes d'un décor de stade au regard du contrat (aucune : il se branche).
static func verifier_stade(racine: Node) -> PackedStringArray:
	return verifier_genre(racine, "stade")


## Les fautes d'un décor de salle de basket au regard du contrat.
static func verifier_salle(racine: Node) -> PackedStringArray:
	return verifier_genre(racine, "salle")


## Les fautes d'un décor au regard du contrat de son genre (« stade », « salle ») : les ancres requises, et
## celle du terrain à l'origine du décor, sans rotation.
static func verifier_genre(racine: Node, genre: String) -> PackedStringArray:
	var erreurs := verifier(racine, CONTRATS[genre])
	var nom: String = ORIGINES[genre]
	var p := trouver(racine, nom)
	if p != null and racine is Node3D:
		var t: Transform3D = (racine as Node3D).global_transform.affine_inverse() * p.global_transform if p.is_inside_tree() else _relatif(racine as Node3D, p)
		if t.origin.length() > ECART or t.basis.get_euler().length() > ECART:
			erreurs.append("l'ancre « %s » doit être à l'origine du décor, sans rotation" % nom)
	return erreurs


## Les ancres requises d'un contrat qui manquent sous la racine, une phrase par ancre.
static func verifier(racine: Node, contrat: Dictionary) -> PackedStringArray:
	var erreurs := PackedStringArray()
	for nom in contrat:
		if contrat[nom].requis and trouver(racine, nom) == null:
			erreurs.append("il manque l'ancre « %s » (%s)" % [nom, contrat[nom].role])
	return erreurs


## La place d'un nœud par rapport à la racine, hors de l'arbre.
static func _relatif(racine: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != racine:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t
