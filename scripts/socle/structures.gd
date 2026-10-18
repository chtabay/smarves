class_name Structures
extends RefCounted
## Le vocabulaire des structures : ce qu'une commune peut avoir qui compte pour les autres communes
## (une gare, un arrêt de car, un terrain de football). Le socle définit les types, leurs champs et
## leur comportement ; une commune ne fait que déclarer les siennes dans le champ « structures » de
## son manifeste, et les poser dans sa scène (un nœud nommé, voir « noeud »). Aucune commune ne parle
## à une autre : tout passe par le registre (autoload Registre), tenu par le socle. La notice est dans
## docs/COMMUNE.md, section « Les structures ».

## Les types connus de ce socle (Commune.SOCLE). Un type ajouté plus tard fait monter le socle : un
## paquet qui s'en sert le demande par « socle_min », et un socle plus ancien le refuse proprement.
##   nom : comment le jeu le dit ; champs : les champs propres au type, avec leur type JSON ;
##   requis : ceux qui ne peuvent pas manquer ; unique : une seule par commune ;
##   relie : ce que le type fait des structures des autres communes (le comportement, au socle).
const TYPES := {
	"gare": {
		"nom": "la gare",
		"champs": {"quai": TYPE_STRING},
		"requis": [],
		"unique": true,
		"relie": "toutes les gares de la Vienne : le train va de l'une à l'autre",
	},
	"arret_car": {
		"nom": "l'arrêt de car",
		"champs": {"abri": TYPE_STRING},
		"requis": [],
		"unique": true,
		"relie": "tous les arrêts du car départemental : on va d'un arrêt à l'autre",
	},
	"terrain_foot": {
		"nom": "le terrain de football",
		"champs": {"club": TYPE_STRING, "court": TYPE_STRING, "couleurs": TYPE_ARRAY, "stade": TYPE_STRING},
		"requis": ["club"],
		"unique": true,
		"relie": "le championnat de la Vienne : la commune a un club, qui y entre à la saison suivante",
	},
	# Socle 1.1. Une salle de jeu meublée et tenue par le socle (scripts/socle/salle_jeu.gd) : la commune
	# nomme son tenancier et ses jeux, le socle pose les tables et fait tourner les jeux de Smarves.
	"salle_jeu": {
		"nom": "la salle de jeu",
		"champs": {"jeux": TYPE_ARRAY, "tenancier": TYPE_STRING, "graine": TYPE_FLOAT, "decor": TYPE_STRING,
			"repliques": TYPE_ARRAY, "enseigne": TYPE_STRING},
		"requis": ["jeux"],
		"unique": false,
		"relie": "rien : c'est un lieu de la commune, le lieu du manifeste de même id lui donne son seuil",
	},
}

## Les jeux d'une salle de jeu, et ses décors (scripts/socle/salle_jeu.gd, JEUX et DECORS).
const JEUX := ["machine", "loto", "blackjack", "roulette", "craps", "baccara", "poker", "des", "roue", "courses"]
const DECORS := ["cafe", "salle", "cave"]

## Les champs de toutes les structures. « noeud » est le nom du nœud de la scène qui la place (un
## Node3D de commune.tscn, cherché par son nom) ; « lot » est la porte du village qui y mène.
const COMMUNS := {"type": TYPE_STRING, "id": TYPE_STRING, "nom": TYPE_STRING, "noeud": TYPE_STRING, "lot": TYPE_STRING}


## Les erreurs d'un champ « structures » (absent : aucune). Rendues dans la langue du rapport du
## portail, une phrase par faute.
static func verifier(liste: Variant) -> PackedStringArray:
	var erreurs := PackedStringArray()
	if liste == null:
		return erreurs
	if typeof(liste) != TYPE_ARRAY:
		erreurs.append("« structures » doit être une liste")
		return erreurs
	var ids := {}
	var types := {}
	for s in liste:
		if typeof(s) != TYPE_DICTIONARY:
			erreurs.append("structure illisible : %s" % str(s))
			continue
		var t := str(s.get("type", ""))
		var id := str(s.get("id", ""))
		if not TYPES.has(t):
			erreurs.append("type de structure inconnu : « %s » (connus : %s)" % [t, ", ".join(TYPES.keys())])
			continue
		if not id.is_valid_identifier() or id != id.to_lower():
			erreurs.append("structure %s : id invalide « %s » (minuscules, chiffres, _)" % [t, id])
		elif ids.has(id):
			erreurs.append("structure en double : %s" % id)
		ids[id] = true
		if str(s.get("nom", "")).strip_edges() == "":
			erreurs.append("structure %s : il lui faut un nom" % id)
		if TYPES[t].unique and types.has(t):
			erreurs.append("une seule structure « %s » par commune" % t)
		types[t] = true
		var champs: Dictionary = TYPES[t].champs
		for k in TYPES[t].requis:
			if typeof(s.get(k)) == TYPE_ARRAY:
				if (s[k] as Array).is_empty():
					erreurs.append("structure %s : « %s » est vide" % [id, k])
			elif str(s.get(k, "")).strip_edges() == "":
				erreurs.append("structure %s : champ manquant « %s »" % [id, k])
		for k in s:
			var attendu = COMMUNS.get(k, champs.get(k))
			if attendu == null:
				erreurs.append("structure %s : champ inconnu « %s »" % [id, k])
			elif typeof(s[k]) != attendu:
				erreurs.append("structure %s : « %s » n'a pas le bon type" % [id, k])
		if t == "terrain_foot" and s.has("couleurs") and typeof(s.couleurs) == TYPE_ARRAY:
			if s.couleurs.size() != 2 or s.couleurs.any(func(c): return typeof(c) != TYPE_STRING or not Color.html_is_valid(c)):
				erreurs.append("structure %s : « couleurs » donne deux couleurs (« #1b3c8c »)" % id)
		if t == "salle_jeu":
			if typeof(s.get("jeux")) == TYPE_ARRAY:
				for j in s.jeux:
					if not str(j) in JEUX:
						erreurs.append("structure %s : jeu inconnu « %s » (connus : %s)" % [id, str(j), ", ".join(JEUX)])
			if s.has("decor") and typeof(s.decor) == TYPE_STRING and not s.decor in DECORS:
				erreurs.append("structure %s : décor inconnu « %s » (%s)" % [id, s.decor, ", ".join(DECORS)])
			if typeof(s.get("repliques")) == TYPE_ARRAY and s.repliques.any(func(r): return typeof(r) != TYPE_STRING):
				erreurs.append("structure %s : « repliques » est une liste de phrases" % id)
	return erreurs


## Les structures valides d'une liste, une par une : celles d'une entrée de catalogue, où une faute
## ne doit rien empêcher (le portail les a déjà vérifiées ; c'est une ceinture).
static func nettoyer(liste: Variant) -> Array:
	var out := []
	if typeof(liste) != TYPE_ARRAY:
		return out
	var types := {}
	for s in liste:
		if verifier([s]).is_empty() and not (TYPES[s.type].unique and types.has(s.type)):
			types[s.type] = true
			out.append(s.duplicate(true))
	return out


## Comment le jeu dit ce type (« la gare »), ou le type lui-même s'il est inconnu.
static func nom_du_type(t: String) -> String:
	return str(TYPES.get(t, {}).get("nom", t))
