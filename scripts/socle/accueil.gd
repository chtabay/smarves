extends RefCounted
## Les blocs de l'accueil (demande de Guillaume du 24 octobre 2026 : « cet encart de droite pourrait être
## dédié à mettre le joueur dans l'action »). L'encart « Ce soir à Smarves » de l'écran titre les dessine ;
## le mode léger sur téléphone les reprendra tels quels. Chaque bloc est une donnée, sans nœud d'interface,
## lue dans les autoloads qu'on lui passe (les tests en passent d'autres) :
##
## - banque : les crédits, la fortune nette, la dette chez M. Brunet ;
## - depuis : ce que la partie a fait sans le joueur (le courrier non lu, résumé : dividendes, matchs) ;
## - a_faire : les premières lignes de la page « Aujourd'hui » du carnet, chacune avec son lien ;
## - courrier : les titres des derniers avis non lus ;
## - village : qui est passé, et le prochain rendez-vous (Voisinage, lu sans compte) ;
## - etat : la ligne de la barre du bas (le jeu et les villes), façon Steam pendant un téléchargement.

const AUJOURDHUI := preload("res://scripts/socle/aujourdhui.gd")
const VOISINAGE := preload("res://scripts/socle/voisinage.gd")


## {credits, fortune, dette, gagne}.
static func banque(game: Node, biens: Node) -> Dictionary:
	return {"credits": int(game.credits), "fortune": int(game.credits) + int(biens.value()) - int(game.debt),
		"dette": int(game.debt), "gagne": int(game.won)}


## Les biens possédés, comptés par famille : {total, maisons (maisons et murs), parts (parts et obligations
## de club), objets (tenues, véhicules, meubles), texte (« 2 maisons · 5 parts », « aucun bien »)}.
static func biens(b: Node) -> Dictionary:
	var n := {"maisons": 0, "parts": 0, "objets": 0}
	for id in b.owned:
		var k := int(b.count(id))
		if k <= 0:
			continue
		var famille: String = {"maison": "maisons", "murs": "maisons", "part": "parts", "club": "parts"}.get(str(b.item(id).get("kind", "")), "objets")
		n[famille] += k
	var mots := {"maisons": ["maison", "maisons"], "parts": ["part", "parts"], "objets": ["objet", "objets"]}
	var morceaux: Array[String] = []
	for f in ["maisons", "parts", "objets"]:
		if n[f] > 0:
			morceaux.append("%d %s" % [n[f], mots[f][0 if n[f] == 1 else 1]])
	n.total = n.maisons + n.parts + n.objets
	n.texte = " · ".join(morceaux) if not morceaux.is_empty() else "aucun bien"
	return n


## Ce qui est arrivé sans le joueur : {dividendes (crédits), matchs, autres, texte}. texte est vide quand
## rien n'attend : la ligne disparaît plutôt que de dire « rien ».
static func depuis(avis: Node) -> Dictionary:
	var dividendes := 0
	var matchs := 0
	var autres := 0
	for a in avis.non_lus():
		match str(a.get("genre", "")):
			"dividende":
				dividendes += int(a.get("montant", 0))
			"match":
				matchs += 1
			_:
				autres += 1
	var morceaux: Array[String] = []
	if dividendes > 0:
		morceaux.append("+%s de dividendes" % Game.fmt(dividendes))
	if matchs > 0:
		morceaux.append("un match joué" if matchs == 1 else "%d matchs joués" % matchs)
	if autres > 0 and morceaux.is_empty():
		morceaux.append("une nouvelle" if autres == 1 else "%d nouvelles" % autres)
	return {"dividendes": dividendes, "matchs": matchs, "autres": autres, "texte": " · ".join(morceaux)}


## Les n premières choses à faire : [{titre, quand (« dans 3 h »), lien (pour Avis.aller)}].
static func a_faire(liste: Array, t: int, n := 3) -> Array:
	var out: Array = []
	for x in liste.slice(0, n):
		var l = x.get("lien", {})
		var a: Dictionary = x.get("avis", {}) if x.get("avis") is Dictionary else {}
		if not a.is_empty():
			l = a.get("lien", {})
		if not l is Dictionary or (l as Dictionary).is_empty():
			l = {"vers": "carnet", "onglet": "aujourdhui"}
		out.append({"titre": str(x.get("titre", "")), "quand": AUJOURDHUI.dans(int(x.get("quand", t)), t), "lien": l,
			"avis": a})
	return out


## Les titres des n derniers avis non lus (les décisions sont déjà dans « À faire ») : [{titre, avis}].
static func courrier(avis: Node, n := 2) -> Array:
	var out: Array = []
	for a in avis.non_lus():
		if str(a.get("genre", "")) == "dilemme":
			continue
		out.append({"titre": str(a.get("titre", "")), "avis": a})
		if out.size() >= n:
			break
	return out


## Le village : {passes (les noms des autres joueurs passés, sans doublon), rendez_vous {quoi, ou, quand,
## dans} ou {}, texte}. Le rendez-vous se lit sans réseau ; les passages, une fois le voisinage lu.
static func village(voisinage: Node, maintenant := -1) -> Dictionary:
	var noms: Array = []
	var passages: Dictionary = voisinage.passages() if voisinage != null else {}
	for lieu in passages:
		for nom in passages[lieu]:
			if not noms.has(nom):
				noms.append(nom)
	var t := maintenant if maintenant >= 0 else int(Time.get_unix_time_from_system()) + VOISINAGE._decalage()
	var rv: Array = VOISINAGE.prochains_rendez_vous(t)
	var prochain: Dictionary = {}
	if not rv.is_empty():
		prochain = (rv[0] as Dictionary).duplicate()
		prochain.dans = AUJOURDHUI.dans(int(prochain.quand), t)
	var morceaux: Array[String] = []
	if not noms.is_empty():
		morceaux.append(("%s est passé" % noms[0]) if noms.size() == 1 else "%d joueurs passés" % noms.size())
	if not prochain.is_empty():
		morceaux.append("%s %s" % [_court(str(prochain.quoi)), prochain.dans])
	var texte := " · ".join(morceaux)
	return {"passes": noms, "rendez_vous": prochain, "texte": texte.left(1).to_upper() + texte.substr(1)}


## « La partie de poker du vendredi » devient « poker du vendredi ».
static func _court(quoi: String) -> String:
	return quoi.trim_prefix("La partie de ").trim_prefix("la partie de ")


## La ligne de la barre du bas : {texte, teinte (« ok », « or », « rouge », « doux »), en_cours (l'id de la
## ville qui se télécharge, ou « »), geste [nom, Callable] ou []}. Le plus pressé gagne : une nouvelle
## version du jeu, puis un téléchargement, puis un échec, puis les villes à mettre à jour, puis « À jour ».
static func etat(version: Node, communes: Node) -> Dictionary:
	var faire: Array = communes.a_faire()
	var de := func(etats: Array) -> Array: return faire.filter(func(id): return communes.etat(id) in etats)
	var nom := func(id: String) -> String:
		var c = communes.commune(id)
		return str(communes.au_catalogue(id).get("nom", c.nom if c else id))
	var installees: int = communes.installees().size()
	# Smarves seule : « À jour » suffit ; avec des villes greffées, on les compte.
	var villes := "  ·  %d villes" % (installees + 1) if installees > 0 else ""
	if version.disponible():
		return {"texte": "Nouvelle version de Smarves", "teinte": "or", "en_cours": "",
			"geste": ["Installer", version.telecharger] if not version.telechargement_ouvert else []}
	var en_cours: Array = de.call(["telechargement", "attente"])
	if not en_cours.is_empty():
		var id: String = en_cours[0]
		var k: float = communes.progression(id)
		var reste := "" if en_cours.size() == 1 else "  ·  +%d" % (en_cours.size() - 1)
		return {"texte": "%s%s%s" % [nom.call(id), "  %d %%" % roundi(k * 100.0) if k > 0.0 else "", reste], "teinte": "doux",
			"en_cours": id, "geste": []}
	var echecs: Array = de.call(["echec"])
	if not echecs.is_empty():
		return {"texte": "%s : téléchargement à reprendre" % nom.call(echecs[0]), "teinte": "rouge", "en_cours": "",
			"geste": ["Réessayer", communes.tout_mettre_a_jour]}
	var maj: Array = de.call(["mise_a_jour"])
	if not maj.is_empty():
		return {"texte": "%d ville%s à mettre à jour" % [maj.size(), "s" if maj.size() > 1 else ""], "teinte": "or", "en_cours": "",
			"geste": ["Mettre à jour", communes.tout_mettre_a_jour]}
	var relancer: Array = de.call(["a_relancer"])
	if not relancer.is_empty():
		return {"texte": "Prêt au prochain lancement", "teinte": "or", "en_cours": "",
			"geste": ["Relancer", communes.relancer] if communes.peut_relancer() else []}
	if version.etat == "hors_ligne":
		return {"texte": "Hors ligne%s" % villes, "teinte": "doux", "en_cours": "", "geste": []}
	return {"texte": "✓ À jour%s" % villes, "teinte": "ok", "en_cours": "", "geste": []}


## Le compte, en un nom pour la barre : « Le Duke · partie gardée au compte », ou « Sans compte ».
static func compte(c: Node) -> String:
	if c.etat == "deconnecte" or c.nom == "":
		return "Partie sur cet appareil"
	return "%s  ·  %s" % [c.nom, {"a_jour": "partie gardée au compte", "envoi": "envoi au compte…", "verification": "lecture du compte…",
		"hors_ligne": "hors ligne", "expire": "connexion expirée", "choix": "deux parties à départager",
		"connexion": "connexion…", "erreur": "connexion refusée"}.get(c.etat, "partie gardée au compte")]
