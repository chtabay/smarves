extends RefCounted
## La page « Aujourd'hui » du carnet (demande de Guillaume du 23 octobre 2026 : « repenser entièrement le
## carnet pour le rendre plus FM2004-like dans son effet addictif »). Comme la boîte de réception de Football
## Manager, elle dit en ouvrant le carnet ce qui attend une réponse, ce qui est arrivé, et où en sont les
## clubs qu'on suit. Rien n'est inventé ici : tout se lit dans Football, le courrier (Avis) et la bourse.
##
## - a_faire : ce qui attend le joueur, le plus pressé d'abord, chaque ligne avec son échéance et son bouton.
## - carte : un club suivi, en quelques lignes (son rang, sa forme, son prochain match, sa direction).

const DIRIGER := preload("res://scripts/socle/diriger.gd")


## « dans 2 j 4 h », « dans 3 h 20 », « dans 12 min », « maintenant ».
static func dans(quand: int, t: int) -> String:
	var d := quand - t
	if d <= 0:
		return "maintenant"
	if d < 3600:
		return "dans %d min" % maxi(1, d / 60)
	if d < 86400:
		var m := (d % 3600) / 60
		return "dans %d h" % (d / 3600) if m == 0 else "dans %d h %02d" % [d / 3600, m]
	var h := (d % 86400) / 3600
	return "dans %d j" % (d / 86400) if h == 0 else "dans %d j %d h" % [d / 86400, h]


## Les clubs qu'on suit : ceux dont on tient une part (les mêmes que le courrier).
static func clubs(f: Node, avis: Node) -> Array:
	var out: Array = avis._clubs_suivis(f)
	out.sort()
	return out


## Les clubs de football de Mes clubs : ceux dont on tient une part, puis ceux qu'on suit en supporter.
static func suivis(f: Node, avis: Node) -> Array:
	var out: Array = clubs(f, avis)
	var fans: Array = (avis.favoris("football") as Array).filter(func(c): return f.clubs.has(c) and not out.has(c))
	fans.sort()
	return out + fans


static func _nom(f: Node, club: String) -> String:
	return str((f.clubs.get(club, {}) as Dictionary).get("nom", club))


## Ce qui attend le joueur : [{genre, quand (l'échéance), titre, texte, avis (une décision de la semaine),
## lien (où mène le bouton), bouton}], le plus pressé d'abord. genre : « dilemme » (la décision de la semaine,
## pas encore tranchée), « compo » (la composition du prochain match n'est pas posée), « mercato » (ouvert, pas
## de recrue), « diriger » (on peut demander la direction d'un club qu'on suit pour la relève du lundi), « bourse »
## (un appel de marge) ; au basket (b), « consigne », « enchere », « marche » et « diriger » (a_faire_basket).
static func a_faire(f: Node, avis: Node, bourse: Node = null, b: Node = null) -> Array:
	var out: Array = []
	var foot: bool = f != null and not f.niveaux.is_empty()
	var t: int = f.maintenant() if f != null else 0
	for a in (avis.liste if foot else []):
		if str(a.get("genre", "")) != "dilemme":
			continue
		var ch: Array = avis.choix_de(a)
		if ch.is_empty() or not ch[0].ouvert or ch.any(func(c): return c.fait):
			continue
		out.append({"genre": "dilemme", "quand": int(f.coup_envoi(int(a.dilemme.s), int(a.dilemme.j))), "titre": str(a.titre),
			"texte": str(a.texte), "avis": a, "lien": {}, "bouton": ""})
	for club in (clubs(f, avis) if foot else []):
		if f.peut_decider(club):
			var r: Dictionary = f.prochain_match(club)
			if not r.is_empty() and not FootDilemmes.tactique_posee(f, club, int(r.s), int(r.j)):
				var adv: String = r.ext if r.dom == club else r.dom
				out.append({"genre": "compo", "quand": int(r.quand), "titre": "%s : la composition contre %s n'est pas posée" % [_nom(f, club), _nom(f, adv)],
					"texte": "Sans consigne, l'adjoint aligne l'équipe type en 4-4-2, mentalité équilibrée.", "lien": {"vers": "bureau", "club": club, "page": "tactique"},
					"bouton": "Préparer la tactique"})
			if f.mercato_ouvert(f.saison) and f.recrue(f.saison, club).is_empty():
				out.append({"genre": "mercato", "quand": int(f.coup_envoi(f.saison, 1)), "titre": "%s : le mercato est ouvert, et pas encore de recrue" % _nom(f, club),
					"texte": "Une recrue par club, jusqu'au premier coup d'envoi.", "lien": {"vers": "bureau", "club": club, "page": "recherche"},
					"bouton": "Chercher une recrue"})
		elif bool(DIRIGER.relevable(f, club).ok):
			out.append({"genre": "diriger", "quand": DIRIGER.prochaine_releve(f), "titre": "%s : vous pouvez en prendre la direction" % _nom(f, club),
				"texte": DIRIGER.phrase(f, club), "lien": {"vers": "notaire", "sport": "football", "club": club}, "bouton": "Le notaire"})
	if bourse != null:
		for p in bourse.ouvertes():
			if bourse.en_appel(p):
				out.append({"genre": "bourse", "quand": t, "titre": "Appel de marge : %s" % bourse.intitule(p),
					"texte": "Renflouer la garantie ou solder la position, à la charge.", "lien": {}, "bouton": ""})
	if b != null:
		out += a_faire_basket(b)
	var ordre := ["bourse", "dilemme", "compo", "consigne", "enchere", "mercato", "marche", "diriger"]
	out.sort_custom(func(a, b): return a.quand < b.quand if a.quand != b.quand else ordre.find(a.genre) < ordre.find(b.genre))
	return out


## Un club suivi, pour sa carte : {club, nom, division, rang, taille, pts, joues, ecart_tete, ecart_relegation,
## forme (« VNDVV »), prochain {j, quand, domicile, adv, nom_adv, rang_adv} ou {}, objectif, confiance,
## dirige, direction (la phrase de DIRIGER)}, ou {} hors de la pyramide.
static func carte(f: Node, club: String) -> Dictionary:
	var place: Array = f.place_de(club)
	if place.is_empty():
		return {}
	var cl: Array = f.classement(f.saison, place[0], place[1])
	var rangs := {}
	for i in cl.size():
		rangs[cl[i].club] = i + 1
	var moi: Dictionary = cl[int(rangs[club]) - 1]
	var n := cl.size()
	var sauve: int = n - int(f.DESCENDENT)
	var out := {"club": club, "nom": _nom(f, club), "division": f.nom_division(place[0], place[1]), "rang": int(rangs[club]), "taille": n,
		"pts": int(moi.pts), "joues": int(moi.j), "ecart_tete": int(cl[0].pts) - int(moi.pts),
		"ecart_relegation": int(moi.pts) - int(cl[sauve].pts) if sauve >= 1 and sauve < n else 0,
		"forme": FootCourrier.forme(f, club), "objectif": FootCourrier.objectif(f, club), "confiance": FootCourrier.confiance(f, club),
		"dirige": bool(f.peut_decider(club)), "direction": DIRIGER.phrase(f, club), "prochain": {},
		"ouvert": (f.actionnaires(club) as Array).is_empty(), "parts": (f.mes_obligations(club) as Array).size()}
	var r: Dictionary = f.prochain_match(club)
	if not r.is_empty():
		var adv: String = r.ext if r.dom == club else r.dom
		out.prochain = {"j": int(r.j), "quand": int(r.quand), "domicile": r.dom == club, "adv": adv, "nom_adv": _nom(f, adv), "rang_adv": int(rangs.get(adv, 0))}
	return out


## La tactique du prochain match d'un club de football, à lire par tous (demande de Guillaume du 31 octobre
## 2026 : « je ne la vois pas dans mon carnet, pas plus en lecture qu'en écriture ») : {match (false entre deux
## saisons), etat (« aucune » : l'adjoint aligne l'équipe type ; « commune » : tenue au serveur ; « locale » :
## posée ici, pas encore envoyée), par (qui l'a posée, « » si on ne sait pas), formation, mentalite, pressing
## (leurs noms lisibles), lignes ([[poste, [noms]]], du gardien à l'attaque), decide (on peut la régler),
## qui (qui la règle : « vous », un nom, ou « » quand le bureau est ouvert à tous)}.
static func tactique(f: Node, club: String) -> Dictionary:
	var r: Dictionary = f.prochain_match(club)
	var out := {"match": not r.is_empty(), "etat": "aucune", "par": "", "decide": bool(f.peut_decider(club)) and not r.is_empty(), "qui": ""}
	var d: Dictionary = f.consigne({})
	if not r.is_empty():
		var c: Dictionary = f.consigne_de(int(r.s), int(r.j), club)
		d = c.consigne
		out.etat = str(c.etat)
		out.par = str(c.par)
	var dg: Dictionary = DIRIGER.dirigeant(f, club)
	if not dg.is_empty():
		out.qui = "vous" if bool(dg.get("moi", false)) else str(dg.get("nom", ""))
	var formation := str(d.get("formation", "4-4-2"))
	out.formation = formation
	out.mentalite = str(FootMatch.MENTALITES.get(str(d.get("mentalite", "equilibree")), FootMatch.MENTALITES.equilibree).nom)
	out.pressing = str(FootMatch.PRESSINGS.get(str(d.get("pressing", "normal")), FootMatch.PRESSINGS.normal).nom)
	# Le onze : celui qui est posé, complété par l'équipe type de l'adjoint là où rien ne l'est.
	var e: Dictionary = f.effectif(club, f.saison)
	var voulu: Array = d.get("compo", [])
	var onze: Array = FootMatch.compo_auto(e.keys(), e, formation, voulu.map(func(x): return str(x) if e.has(str(x)) else null)) if voulu.size() == 11 \
		else FootMatch.compo_auto(e.keys(), e, formation)
	var postes: Array = FootMatch.FORMATIONS.get(formation, FootMatch.FORMATIONS["4-4-2"])
	var lignes: Array = []
	for i in mini(onze.size(), postes.size()):
		var id = onze[i]
		var poste := str(postes[i][0])
		var nom := "?" if id == null or not e.has(str(id)) else str(e[str(id)].get("nom", ""))
		if lignes.is_empty() or str(lignes[-1][0]) != poste:
			lignes.append([poste, []])
		(lignes[-1][1] as Array).append(nom)
	out.lignes = lignes
	return out


## « 3e » ; « 1er ».
static func rang(r: int) -> String:
	return "1er" if r == 1 else "%de" % r


# ---------------------------------------------------------------- le basket

## Les clubs de basket qu'on suit : ceux dont on tient une part.
static func clubs_basket(b: Node) -> Array:
	var out: Array = b.clubs.keys().filter(func(c): return not (b.mes_obligations(c) as Array).is_empty())
	out.sort()
	return out


## Les clubs de basket de Mes clubs : ceux dont on tient une part, puis ceux qu'on suit en supporter.
static func suivis_basket(b: Node, avis: Node) -> Array:
	var out: Array = clubs_basket(b)
	var fans: Array = (avis.favoris("basket") as Array).filter(func(c): return b.clubs.has(c) and not out.has(c))
	fans.sort()
	return out + fans


## Le match d'un club de basket à une journée : {dom, adv (l'id de l'adversaire), score ([pour, contre], vide
## s'il n'est pas joué), quand}, ou {}. Sans cliché gardé, rien ne se joue ici.
static func match_basket(b: Node, club: String, s: int, j: int) -> Dictionary:
	var ici: Array = b.place_de(club)
	if ici.is_empty() or j < 1 or j > int(b.JOURNEES):
		return {}
	for paire in b.rencontres(j):
		if not int(ici[2]) in paire:
			continue
		var k: int = 0 if int(paire[0]) == int(ici[2]) else 1
		var adv: String = b.titulaire(ici[0], ici[1], int(paire[1 - k]), j)
		var quand: int = b.coup_envoi(s, j)
		var score: Array = []
		if int(b.maintenant()) >= quand and not b.cliches.is_empty():
			var m: Dictionary = b.rencontre(s, ici[0], ici[1], j, paire[0], paire[1])
			score = [int(m.score[k]), int(m.score[1 - k])]
		return {"dom": k == 0, "adv": adv, "score": score, "quand": quand}
	return {}


## La forme d'un club de basket : ses cinq derniers résultats de la saison (« VDVVD »).
static func forme_basket(b: Node, club: String, n := 5) -> String:
	var out := ""
	for j in range(1, int(b.journee_jouee()) + 1):
		var m := match_basket(b, club, b.saison, j)
		if not m.is_empty() and not (m.score as Array).is_empty():
			out += "V" if int(m.score[0]) > int(m.score[1]) else "D"
	return out.right(n)


## Un club de basket suivi, pour sa carte : les mêmes clés que carte(), plus consigne (celle du prochain
## match), sport « basket ».
static func carte_basket(b: Node, club: String) -> Dictionary:
	var ici: Array = b.place_de(club)
	if ici.is_empty():
		return {}
	var cl: Array = b.classement(b.saison, ici[0], ici[1])
	var rangs := {}
	for i in cl.size():
		rangs[cl[i].club] = i + 1
	var moi: Dictionary = cl[int(rangs.get(club, cl.size())) - 1]
	var n := cl.size()
	var sauve: int = n - int(b.DESCENDENT)
	var out := {"sport": "basket", "club": club, "nom": str(b.fiche(club).nom), "division": b.nom_division(ici[0], ici[1]), "rang": int(rangs.get(club, 0)),
		"taille": n, "pts": int(moi.pts), "joues": int(moi.j), "ecart_tete": int(cl[0].pts) - int(moi.pts),
		"ecart_relegation": int(moi.pts) - int(cl[sauve].pts) if sauve >= 1 and sauve < n else 0,
		"forme": forme_basket(b, club), "objectif": {}, "confiance": {}, "dirige": bool(b.peut_decider(club)),
		"ouvert": (b.actionnaires(club) as Array).is_empty(), "parts": (b.mes_obligations(club) as Array).size(),
		"direction": DIRIGER.phrase(b, club), "prochain": {}, "consigne": ""}
	var jj: int = b.journee_jouee()
	if jj < int(b.JOURNEES) and int(b.maintenant()) < int(b.coup_envoi(b.saison, int(b.JOURNEES))):
		var m := match_basket(b, club, b.saison, jj + 1)
		if not m.is_empty():
			out.prochain = {"j": jj + 1, "quand": int(m.quand), "domicile": bool(m.dom), "adv": m.adv, "nom_adv": str(b.fiche(m.adv).nom), "rang_adv": int(rangs.get(m.adv, 0))}
			out.consigne = b.consigne_de(b.saison, jj + 1, club)
	return out


## La consigne d'une journée a été posée pour elle (et non reprise de la journée d'avant).
static func consigne_posee_basket(b: Node, club: String, s: int, j: int) -> bool:
	return (b.bureau.get("consignes", []) as Array).any(func(c): return int(c.saison) == s and int(c.journee) == j and str(c.club) == club)


## Ce qui attend au basket : « consigne » (le match est dans moins de deux jours, la consigne n'est pas
## posée pour lui), « enchere » (une enchère dépassée, avant la clôture du jeudi), « marche » (le marché
## ferme dans moins de deux jours, sans enchère de notre part), « diriger » (la relève).
static func a_faire_basket(b: Node) -> Array:
	var out: Array = []
	if b == null or b.niveaux.is_empty():
		return out
	var t: int = b.maintenant()
	var s: int = b.saison
	for club in clubs_basket(b):
		var nom := str(b.fiche(club).nom)
		var notaire := {"vers": "notaire", "sport": "basket", "club": club}
		var bureau := {"vers": "gerer", "sport": "basket", "club": club, "page": "equipe"}
		var marche := {"vers": "gerer", "sport": "basket", "club": club, "page": "marche"}
		if b.peut_decider(club):
			var c := carte_basket(b, club)
			var p: Dictionary = c.prochain
			if not p.is_empty() and int(p.quand) - t < 2 * 86400 and not consigne_posee_basket(b, club, s, int(p.j)):
				out.append({"genre": "consigne", "quand": int(p.quand), "titre": "%s : la consigne contre %s n'est pas posée" % [nom, p.nom_adv],
					"texte": "Sans consigne, l'entraîneur garde « %s ». Titulaires ou rotation, au bureau du club." % c.consigne, "lien": bureau, "bouton": "Poser la consigne"})
			var j: int = b.journee_du_marche()
			var ici: Array = b.place_de(club)
			if j > 0 and b.tirage_fait(club):
				var mes: Array = (b.bureau.get("encheres", []) as Array).filter(func(o): return bool(o.get("moi", false)) and int(o.saison) == s and int(o.journee) == j and str(o.club) == club)
				var depassees := {}
				for o in mes:
					var lot: Array = b.offres_du_lot(s, j, ici[0], ici[1], str(o.joueur))
					if not lot.is_empty() and not bool(lot[0].get("moi", false)):
						depassees[str(o.joueur)] = int(lot[0].montant)
				var cl: Dictionary = b.cliche(b.id_cliche(s, j - 1))
				for code in depassees:
					var qui := str((cl.get("joueurs", {}) as Dictionary).get(code, {}).get("nom", code))
					out.append({"genre": "enchere", "quand": int(b.cloture(s, j)), "titre": "%s : votre enchère sur %s est dépassée" % [nom, qui],
						"texte": "La meilleure offre est à %s crédits. Le marché ferme jeudi à 22 h." % Game.fmt(int(depassees[code])), "lien": marche, "bouton": "Le marché"})
				if mes.is_empty() and int(b.cloture(s, j)) - t < 2 * 86400:
					out.append({"genre": "marche", "quand": int(b.cloture(s, j)), "titre": "%s : le marché ferme jeudi à 22 h" % nom,
						"texte": "Aucune enchère de votre part pour la journée %d. Les joueurs libres sont au marché du club." % j, "lien": marche, "bouton": "Le marché"})
		elif bool(DIRIGER.relevable(b, club).ok):
			out.append({"genre": "diriger", "quand": DIRIGER.prochaine_releve(b), "titre": "%s : vous pouvez en prendre la direction" % nom,
				"texte": DIRIGER.phrase(b, club), "lien": notaire, "bouton": "Le notaire"})
	return out
