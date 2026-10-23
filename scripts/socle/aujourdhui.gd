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


static func _nom(f: Node, club: String) -> String:
	return str((f.clubs.get(club, {}) as Dictionary).get("nom", club))


## Ce qui attend le joueur : [{genre, quand (l'échéance), titre, texte, avis (une décision de la semaine),
## lien (où mène le bouton), bouton}], le plus pressé d'abord. genre : « dilemme » (la décision de la semaine,
## pas encore tranchée), « compo » (la composition du prochain match n'est pas posée), « mercato » (ouvert, pas
## de recrue), « diriger » (l'intersaison est ouverte et l'on ne dirige pas un club qu'on suit), « bourse »
## (un appel de marge).
static func a_faire(f: Node, avis: Node, bourse: Node = null) -> Array:
	var out: Array = []
	if f == null or f.niveaux.is_empty():
		return out
	var t: int = f.maintenant()
	for a in avis.liste:
		if str(a.get("genre", "")) != "dilemme":
			continue
		var ch: Array = avis.choix_de(a)
		if ch.is_empty() or not ch[0].ouvert or ch.any(func(c): return c.fait):
			continue
		out.append({"genre": "dilemme", "quand": int(f.coup_envoi(int(a.dilemme.s), int(a.dilemme.j))), "titre": str(a.titre),
			"texte": str(a.texte), "avis": a, "lien": {}, "bouton": ""})
	for club in clubs(f, avis):
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
		elif DIRIGER.en_intersaison(f):
			var e: Dictionary = DIRIGER.etat(f, club)
			if str(e.ailleurs) == "" and not bool(e.dirige):
				out.append({"genre": "diriger", "quand": int(DIRIGER.intersaison(f)[1]), "titre": "%s : l'intersaison est ouverte, vous ne dirigez pas" % _nom(f, club),
					"texte": DIRIGER.phrase(f, club), "lien": {"vers": "registre", "club": club}, "bouton": "Le registre des parts"})
	if bourse != null:
		for p in bourse.ouvertes():
			if bourse.en_appel(p):
				out.append({"genre": "bourse", "quand": t, "titre": "Appel de marge : %s" % bourse.intitule(p),
					"texte": "Renflouer la garantie ou solder la position, à la charge.", "lien": {}, "bouton": ""})
	var ordre := ["bourse", "dilemme", "compo", "mercato", "diriger"]
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
		"dirige": bool(f.peut_decider(club)), "direction": DIRIGER.phrase(f, club), "prochain": {}}
	var r: Dictionary = f.prochain_match(club)
	if not r.is_empty():
		var adv: String = r.ext if r.dom == club else r.dom
		out.prochain = {"j": int(r.j), "quand": int(r.quand), "domicile": r.dom == club, "adv": adv, "nom_adv": _nom(f, adv), "rang_adv": int(rangs.get(adv, 0))}
	return out


## « 3e » ; « 1er ».
static func rang(r: int) -> String:
	return "1er" if r == 1 else "%de" % r
