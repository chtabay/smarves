extends Node
## Le registre des structures (autoload « Registre ») : les gares, les arrêts de car, les terrains de
## football de toutes les communes connues du jeu. Il est tenu par le socle, jamais par les paquets :
## il se reconstruit à partir des communes inscrites (Communes, installées chez le joueur) et du
## catalogue du portail (publiées, installées ou non), à chaque inscription et à chaque lecture du
## catalogue. Une commune ne lit jamais une autre commune : elle demande au registre. Le vocabulaire
## est dans Structures (scripts/socle/structures.gd), la notice dans docs/COMMUNE.md.

## Le registre vient d'être reconstruit (une commune inscrite, le catalogue lu).
signal change

## Une entrée par structure, dans l'ordre des communes (Smarves d'abord, puis les inscrites, puis
## celles du catalogue seulement) :
##   cle (« <commune>/<id> »), commune, insee, commune_nom, centre (longitude, latitude ; Poitiers pour une commune « ailleurs », qui part de Poitiers-Biard), installee
##   (la commune est chez le joueur, on peut y aller), type, id, nom, et les champs du type tels que
##   le manifeste les donne (club, couleurs…), sous « champs ».
var entrees: Array = []


func _ready() -> void:
	Communes.inscrite.connect(func(_id): reconstruire())
	Communes.catalogue_lu.connect(reconstruire)
	reconstruire()


func reconstruire() -> void:
	var vu := {}
	var out := []
	for id in Communes.ordre:
		var c: Commune = Communes.communes[id]
		vu[id] = true
		for s in c.structures():
			out.append(_entree(id, c.insee, c.nom, s, true))
	for e in Communes.catalogue:
		if vu.has(e.id):
			continue
		vu[e.id] = true
		for s in e.get("structures", []):
			out.append(_entree(e.id, e.insee, e.nom, s, false))
	entrees = out
	change.emit()


func _entree(commune: String, insee: String, nom: String, s: Dictionary, installee: bool) -> Dictionary:
	var champs := {}
	for k in s:
		if not Structures.COMMUNS.has(k):
			champs[k] = s[k]
	return {"cle": "%s/%s" % [commune, s.id], "commune": commune, "insee": insee, "commune_nom": nom,
		"centre": Vienne.centre(insee if insee != "" else CarteVienne.POITIERS_INSEE), "installee": installee, "type": str(s.type), "id": str(s.id),
		"nom": str(s.nom), "noeud": str(s.get("noeud", "")), "lot": str(s.get("lot", "")), "champs": champs}


## Toutes les structures de ce type (« gare », « terrain_foot »…) ; installees : seulement celles des
## communes installées, où l'on peut aller.
func de_type(type: String, installees := false) -> Array:
	return entrees.filter(func(e): return e.type == type and (e.installee or not installees))


## Les structures d'une commune.
func de_commune(commune: String) -> Array:
	return entrees.filter(func(e): return e.commune == commune)


## Une structure par sa clé (« liguge/gare »), ou {}.
func structure(cle: String) -> Dictionary:
	for e in entrees:
		if e.cle == cle:
			return e
	return {}


## Ce que cette structure relie, d'après son type : les autres structures du même type ailleurs (la
## gare mène aux autres gares, l'arrêt aux autres arrêts), les plus proches d'abord. Le terrain de
## football ne relie rien directement : c'est le championnat qui lit les terrains.
func relies(cle: String, installees := false) -> Array:
	var e := structure(cle)
	if e.is_empty() or e.type == "terrain_foot":
		return []
	var out := de_type(e.type, installees).filter(func(x): return x.commune != e.commune)
	out.sort_custom(func(a, b): return a.centre.distance_squared_to(e.centre) < b.centre.distance_squared_to(e.centre))
	return out


## Le nœud qui place la structure dans la scène de sa commune (champ « noeud »), ou null.
func noeud(scene: Node, e: Dictionary) -> Node:
	if scene == null or e.get("noeud", "") == "":
		return null
	return scene.find_child(e.noeud, true, false)
