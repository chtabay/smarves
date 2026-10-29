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
		# « habillage » (socle 1.6) : une scène de la commune posée dans le stade du socle, autour de la pelouse.
		# « scene » (socle 1.8) : le stade de la commune tout entier, une scène dont le script hérite du stade du socle.
		# « modele » (socle 1.13) : le décor du stade, une brique de la bibliothèque (« stade-de-campagne@1 ») ou une
		# scène de la commune, sans héritage, branchée par le contrat d'ancres du stade (scripts/socle/ancres.gd).
		"champs": {"club": TYPE_STRING, "court": TYPE_STRING, "couleurs": TYPE_ARRAY, "stade": TYPE_STRING, "habillage": TYPE_STRING, "scene": TYPE_STRING, "modele": TYPE_STRING},
		"requis": ["club"],
		"unique": true,
		"relie": "le championnat de la Vienne : la commune a un club, qui y entre à la saison suivante (tout de suite si personne n'a encore joué)",
	},
	# Socle 1.9. Le basket sur les résultats réels (autoload Basket) : un club de la commune, dans une
	# pyramide de groupes de huit complétés par des figurants ; « nom » est le nom de la salle.
	# « scene » et « habillage » (socle 1.12) : comme pour le terrain, la salle de la commune tout entière (son
	# script hérite de scripts/village/salle_basket.gd), ou une scène posée dans la salle du socle.
	# « modele » (socle 1.14) : le décor de la salle, une brique de la bibliothèque (« salle-de-quartier@1 ») ou une
	# scène de la commune, branché par ses ancres (Ancres.SALLE) ; exclusif de « scene ».
	"gymnase": {
		"nom": "le gymnase",
		"champs": {"club": TYPE_STRING, "court": TYPE_STRING, "couleurs": TYPE_ARRAY, "habillage": TYPE_STRING, "scene": TYPE_STRING, "modele": TYPE_STRING},
		"requis": ["club"],
		"unique": true,
		"relie": "le championnat de basket de la Vienne : la commune a un club, qui prend la place d'un club figurant dès la journée suivante",
	},
	# Socle 1.1 (« guichet » : 1.2). Une salle de jeu meublée et tenue par le socle (scripts/socle/salle_jeu.gd) : la commune
	# nomme son tenancier et ses jeux, le socle pose les tables et fait tourner les jeux de Smarves.
	# « modele » (socle 1.22) : le décor de la salle, une brique de la bibliothèque (« bar-des-sports@1 ») ou une
	# scène de la commune, branché par ses ancres (Ancres.SALLE_JEU) à la place de la pièce du socle.
	# « paris » (socle 1.26) : le tenancier prend aussi les paris du championnat de la Vienne (autoload Paris), au
	# même comptoir que Josiane au café de Smarves.
	"salle_jeu": {
		"nom": "la salle de jeu",
		"champs": {"jeux": TYPE_ARRAY, "tenancier": TYPE_STRING, "graine": TYPE_FLOAT, "decor": TYPE_STRING,
			"repliques": TYPE_ARRAY, "enseigne": TYPE_STRING, "guichet": TYPE_BOOL, "modele": TYPE_STRING, "paris": TYPE_BOOL},
		"requis": ["jeux"],
		"unique": false,
		"relie": "rien : c'est un lieu de la commune, le lieu du manifeste de même id lui donne son seuil",
	},
	# Socle 1.4. Un commerce tenu par le socle (scripts/socle/commerce.gd) : la commune nomme son commerçant,
	# son genre (tenue, vehicule, meuble) et ses articles (scripts/socle/articles.gd), vendus comme au village.
	"commerce": {
		"nom": "le commerce",
		"champs": {"genre": TYPE_STRING, "articles": TYPE_ARRAY, "tenancier": TYPE_STRING, "graine": TYPE_FLOAT,
			"repliques": TYPE_ARRAY, "enseigne": TYPE_STRING},
		"requis": ["genre", "articles"],
		"unique": false,
		"relie": "rien : ses articles entrent au catalogue de Biens sous « <commune>/<id> »",
	},
	# Socle 1.27. Une charge d'agent de change tenue par le socle (scripts/socle/charge.gd) : la commune nomme son agent,
	# ses paroles et son enseigne ; c'est la bourse de Mme Vasseur (autoload Bourse), mêmes cours, mêmes positions.
	"charge": {
		"nom": "la charge d'agent de change",
		"champs": {"agent": TYPE_STRING, "graine": TYPE_FLOAT, "repliques": TYPE_ARRAY, "enseigne": TYPE_STRING},
		"requis": ["agent"],
		"unique": true,
		"relie": "la bourse à levier : les mêmes cours, tenus au serveur, et les positions du compte, d'une charge à l'autre",
	},
	# Socle 1.24. Une salle où l'on joue à deux (scripts/socle/salle_duo.gd) : la commune nomme ses variantes ;
	# l'appariement, les tarifs, la prime et la plaque sont tenus par le serveur, qui connaît la salle par son id.
	"salle_duo": {
		"nom": "la salle à deux",
		"champs": {"variantes": TYPE_ARRAY},
		"requis": ["variantes"],
		"unique": false,
		"relie": "rien : ses parties, ses tarifs et sa plaque sont tenus par le serveur (SalleDuo)",
	},
}

## Les jeux d'une salle de jeu, et ses décors (scripts/socle/salle_jeu.gd, JEUX et DECORS).
const JEUX := ["machine", "loto", "blackjack", "roulette", "craps", "baccara", "poker", "des", "roue", "courses"]
const DECORS := ["cafe", "salle", "cave"]

## Le genre de brique que nomme le champ « modele » de chaque type (socle 1.13 : le terrain ; 1.14 : le gymnase ;
## 1.22 : la salle de jeu), avec une brique d'exemple et ce qu'elle est, pour les messages.
const GENRE_DU_MODELE := {"terrain_foot": "stade", "gymnase": "salle", "salle_jeu": "salle_jeu"}
const EXEMPLE_DU_GENRE := {"stade": ["stade-de-campagne@1", "un stade"], "salle": ["salle-de-quartier@1", "une salle"],
	"salle_jeu": ["bar-des-sports@1", "une salle de jeu"], "etude": ["etude-de-notaire@1", "une étude"]}

## Les champs de toutes les structures. « noeud » est le nom du nœud de la scène qui la place (un
## Node3D de commune.tscn, cherché par son nom) ; « lot » est la porte du village qui y mène.
const COMMUNS := {"type": TYPE_STRING, "id": TYPE_STRING, "nom": TYPE_STRING, "noeud": TYPE_STRING, "lot": TYPE_STRING}


## Les fautes d'un champ « modele » qui doit nommer un décor de ce genre : une brique de la bibliothèque, ou une
## scène de la commune (res://communes/<id>/….tscn). Le notaire s'en sert aussi (genre « etude »).
static func verifier_modele(m: String, genre: String) -> PackedStringArray:
	var erreurs := PackedStringArray()
	var exemple: Array = EXEMPLE_DU_GENRE[genre]
	if Bibliotheque.est_reference(m):
		if Bibliotheque.brique(m).is_empty():
			erreurs.append("« %s » n'est pas dans la bibliothèque (connues : %s)" % [m, ", ".join(Bibliotheque.references(genre))])
		elif Bibliotheque.scene(m, genre) == "":
			erreurs.append("« %s » n'est pas %s, ou demande un socle plus récent" % [m, exemple[1]])
	elif not m.begins_with("res://communes/") or not m.ends_with(".tscn"):
		erreurs.append("« modele » est une brique de la bibliothèque (« %s ») ou une scène de la commune (res://communes/<id>/….tscn)" % exemple[0])
	return erreurs


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
	var articles := {}
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
			if (s[k] as Array).is_empty() if typeof(s.get(k)) == TYPE_ARRAY else str(s.get(k, "")).strip_edges() == "":
				erreurs.append("structure %s : champ manquant « %s »" % [id, k])
		for k in s:
			var attendu = COMMUNS.get(k, champs.get(k))
			if attendu == null:
				erreurs.append("structure %s : champ inconnu « %s »" % [id, k])
			elif typeof(s[k]) != attendu:
				erreurs.append("structure %s : « %s » n'a pas le bon type" % [id, k])
		if t in ["terrain_foot", "gymnase"] and s.has("couleurs") and typeof(s.couleurs) == TYPE_ARRAY:
			if s.couleurs.size() != 2 or s.couleurs.any(func(c): return typeof(c) != TYPE_STRING or not Color.html_is_valid(c)):
				erreurs.append("structure %s : « couleurs » donne deux couleurs (« #1b3c8c »)" % id)
		if t in ["terrain_foot", "gymnase"] and typeof(s.get("habillage")) == TYPE_STRING:
			var h: String = s.habillage
			if not h.begins_with("res://communes/") or not h.ends_with(".tscn"):
				erreurs.append("structure %s : « habillage » est une scène de la commune (res://communes/<id>/….tscn)" % id)
		if t in ["terrain_foot", "gymnase"] and typeof(s.get("scene")) == TYPE_STRING:
			var sc: String = s.scene
			if not sc.begins_with("res://communes/") or not sc.ends_with(".tscn"):
				erreurs.append("structure %s : « scene » est une scène de la commune (res://communes/<id>/….tscn)" % id)
		if t in GENRE_DU_MODELE and typeof(s.get("modele")) == TYPE_STRING:
			if s.has("scene"):
				erreurs.append("structure %s : « scene » ou « modele », pas les deux" % id)
			for faute in verifier_modele(str(s.modele), GENRE_DU_MODELE[t]):
				erreurs.append("structure %s : %s" % [id, faute])
		if t == "salle_jeu":
			if typeof(s.get("jeux")) == TYPE_ARRAY:
				for j in s.jeux:
					# « <commune>:<nom> » (socle 1.12) : un jeu que la commune inscrit elle-même (Tables.inscrire).
					if not str(j) in JEUX and not _jeu_de_commune(str(j)):
						erreurs.append("structure %s : jeu inconnu « %s »" % [id, str(j)])
			if s.has("decor") and typeof(s.decor) == TYPE_STRING and not s.decor in DECORS:
				erreurs.append("structure %s : décor inconnu « %s »" % [id, s.decor])
		if t == "salle_duo":
			if typeof(s.get("variantes")) == TYPE_ARRAY and s.variantes.any(func(v): return typeof(v) != TYPE_STRING or RegEx.create_from_string("^[a-z0-9_]{1,24}$").search(v) == null):
				erreurs.append("structure %s : chaque variante est un id de 1 à 24 caractères (a-z, 0-9, « _ »)" % id)
		if t in ["salle_jeu", "commerce", "charge"] and typeof(s.get("repliques")) == TYPE_ARRAY and s.repliques.any(func(r): return typeof(r) != TYPE_STRING):
			erreurs.append("structure %s : « repliques » est une liste de phrases" % id)
		if t == "commerce":
			erreurs.append_array(load("res://scripts/socle/articles.gd").verifier(s, articles))
	return erreurs


## Les structures valides d'une liste, une par une : celles d'une entrée de catalogue, où une faute
## ne doit rien empêcher (le portail les a déjà vérifiées ; c'est une ceinture).
## « cloue:bonneteau » : le nom d'un jeu qu'une commune inscrit (Tables.inscrire), « <commune>:<nom> ».
static func _jeu_de_commune(j: String) -> bool:
	var m := j.split(":")
	return m.size() == 2 and m[0].is_valid_identifier() and m[1].is_valid_identifier() and j == j.to_lower()


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
