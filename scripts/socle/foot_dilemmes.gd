class_name FootDilemmes
extends RefCounted
## Les décisions de la semaine (demande de Guillaume du 23 octobre 2026 au soir : ce qui rend un FM2004
## addictif, intégré à Smarves ; « une interface de notif dans le carnet serait pertinente ? »). Chaque
## journée, un club de football reçoit une situation de vestiaire à trancher entre deux choix ; son
## dirigeant la tranche au Courrier du carnet (autoload Avis), avant le coup d'envoi.
##
## - La situation et le joueur visé se tirent de la saison, de la journée et du club : tout le monde lit la
##   même pour le même club.
## - Le choix part avec la consigne du match (la clé « dilemme » : « a » ou « b », dans le détail de la
##   consigne au serveur), comme la tactique : celui qui dirige tranche pour tous.
## - Il touche le moral et la condition d'un joueur ou de tout l'effectif pour le match de la journée
##   (« maintenant »), parfois aussi pour celui d'après (« ensuite ») ; FootMatch.forme les fait peser sur
##   chaque compétence. L'effet est réel et modeste : quelques pour cent de forme.
## - Après le match, le Courrier en dit la suite. Sans réponse, rien ne change, et l'avis le dit.

## Qui la situation vise : « remplacant » (un joueur hors de l'équipe type), « capitaine » (le plus capé :
## le plus âgé des meilleurs), « jeune » (le plus jeune), « joueur » (n'importe qui), « equipe » (personne
## en particulier). {joueur} et {age} sont remplacés dans les textes.
const CATALOGUE := {
	"temps_de_jeu": {"cible": "remplacant",
		"titre": "{joueur} veut plus de temps de jeu",
		"texte": "Il est venu frapper à la porte du bureau : il s'entraîne bien et ne joue pas. Il attend une réponse avant dimanche.",
		"a": {"libelle": "Lui promettre sa chance", "maintenant": {"cible": {"moral": 25}},
			"suite": "{joueur}, à qui vous aviez promis sa chance, est arrivé remonté à bloc."},
		"b": {"libelle": "Le laisser à sa place", "maintenant": {"cible": {"moral": -25}, "equipe": {"moral": 5}},
			"suite": "{joueur} a mal pris d'être laissé à sa place ; le vestiaire, lui, a apprécié qu'on tienne la hiérarchie."}},
	"prime": {"cible": "capitaine",
		"titre": "{joueur}, le capitaine, demande une prime de victoire",
		"texte": "Au nom du vestiaire : une prime si l'on gagne dimanche. Le président laisse la décision au dirigeant.",
		"a": {"libelle": "Accorder la prime", "maintenant": {"equipe": {"moral": 15}}, "ensuite": {"equipe": {"moral": -8}},
			"suite": "La prime a motivé le groupe ; il faudra voir s'il ne la réclame pas chaque semaine."},
		"b": {"libelle": "Refuser : le maillot suffit", "maintenant": {"equipe": {"moral": -6}, "cible": {"moral": -6}},
			"suite": "Le refus de la prime a laissé quelques mines fermées dans le vestiaire."}},
	"presse": {"cible": "capitaine",
		"titre": "{joueur} critique la tactique dans le journal",
		"texte": "« On défend trop bas », a dit le capitaine au correspondant local. Le vestiaire attend de voir ce que vous allez faire.",
		"a": {"libelle": "Le recadrer devant le groupe", "maintenant": {"cible": {"moral": -20}, "equipe": {"moral": 6}},
			"suite": "{joueur}, recadré devant tout le monde, a joué la tête basse ; le groupe a resserré les rangs."},
		"b": {"libelle": "Lui donner raison publiquement", "maintenant": {"cible": {"moral": 15}, "equipe": {"moral": -6}},
			"suite": "{joueur} s'est senti soutenu ; certains, dans le vestiaire, ont trouvé que le capitaine décidait beaucoup."}},
	"retard": {"cible": "joueur",
		"titre": "{joueur} est arrivé en retard à l'entraînement",
		"texte": "Vingt minutes, sans prévenir. C'est la deuxième fois ce mois-ci, dit l'adjoint.",
		"a": {"libelle": "Une amende, devant tout le monde", "maintenant": {"cible": {"moral": -15}, "equipe": {"moral": 6}},
			"suite": "L'amende de {joueur} a fait son effet : tout le monde était à l'heure le reste de la semaine."},
		"b": {"libelle": "Fermer les yeux cette fois", "maintenant": {"cible": {"moral": 6}, "equipe": {"moral": -8}},
			"suite": "{joueur} s'en est bien tiré ; le vestiaire a remarqué qu'il n'y avait pas eu de sanction."}},
	"jeune": {"cible": "jeune",
		"titre": "Le jeune {joueur} demande à s'entraîner avec les titulaires",
		"texte": "{age} ans, et l'envie qui va avec. L'adjoint le trouve prêt ; les anciens, moins.",
		"a": {"libelle": "Oui, dès cette semaine", "maintenant": {"cible": {"moral": 25}, "equipe": {"moral": -3}},
			"suite": "{joueur} a passé la semaine avec les titulaires, et il n'a pas eu peur."},
		"b": {"libelle": "Pas encore", "maintenant": {"cible": {"moral": -15}},
			"suite": "{joueur} a ravalé sa déception ; il attendra son tour."}},
	"soiree": {"cible": "equipe",
		"titre": "Le groupe demande une soirée libre jeudi",
		"texte": "Les joueurs voudraient une soirée en ville avant le match. L'adjoint préférerait une mise au vert.",
		"a": {"libelle": "Accorder la soirée", "maintenant": {"equipe": {"moral": 15, "condition": -8}},
			"suite": "La soirée libre a fait du bien au moral ; un peu moins aux jambes."},
		"b": {"libelle": "Mise au vert", "maintenant": {"equipe": {"moral": -8}},
			"suite": "La mise au vert a été suivie sans enthousiasme, mais tout le monde était frais."}},
	"sponsor": {"cible": "equipe",
		"titre": "Un commerçant veut une séance photo mercredi",
		"texte": "La boulangerie de la place offre les maillots d'échauffement contre une matinée de photos et d'autographes.",
		"a": {"libelle": "Accepter la séance", "maintenant": {"equipe": {"moral": 8, "condition": -6}},
			"suite": "Les joueurs étaient fiers de leurs nouveaux maillots ; la matinée a manqué à l'entraînement."},
		"b": {"libelle": "Refuser : on s'entraîne", "maintenant": {"equipe": {"moral": -4}},
			"suite": "La boulangerie a fait grise mine ; l'entraînement, lui, a eu lieu."}},
	"supporters": {"cible": "equipe",
		"titre": "Les supporters veulent rencontrer l'équipe",
		"texte": "Le club des supporters propose un pot à la buvette après l'entraînement de vendredi.",
		"a": {"libelle": "Y envoyer tout le groupe", "maintenant": {"equipe": {"moral": 10, "condition": -3}}, "ensuite": {"equipe": {"moral": 5}},
			"suite": "Le pot à la buvette a soudé le club et ses supporters ; on en parle encore au village."},
		"b": {"libelle": "Seulement le capitaine", "maintenant": {"equipe": {"moral": -3}},
			"suite": "Les supporters auraient aimé voir tout le monde ; le capitaine a fait de son mieux."}},
}


## La situation d'un club pour une journée : {cle, cible (l'id du joueur visé, « » pour l'équipe), joueur
## (« Prénom Nom »), titre, texte, a, b} ; {} hors des journées ou sans effectif.
static func du_jour(f: Node, club: String, s: int, j: int) -> Dictionary:
	if j < 1 or j > int(f.JOURNEES) or not f.clubs.has(club):
		return {}
	var cru: Dictionary = f._effectif_cru(club, s)
	if cru.is_empty():
		return {}
	var h := Hasard.depuis(Hasard.graine("dilemme/%d/%d/%s" % [s, j, club]))
	var cles: Array = CATALOGUE.keys()
	cles.sort()
	var cle: String = h.choix(cles)
	var d: Dictionary = CATALOGUE[cle]
	var id := _cible(cru, str(d.cible), h)
	var j_: Dictionary = cru.get(id, {})
	var nom := "%s %s" % [j_.get("prenom", ""), j_.get("nom", "")] if not j_.is_empty() else ""
	var age := str(j_.get("age", ""))
	var out := {"cle": cle, "cible": id, "joueur": nom, "titre": _remplir(str(d.titre), nom, age), "texte": _remplir(str(d.texte), nom, age)}
	for c in ["a", "b"]:
		var x: Dictionary = (d[c] as Dictionary).duplicate(true)
		x.suite = _remplir(str(x.suite), nom, age)
		out[c] = x
	return out


static func _remplir(t: String, nom: String, age: String) -> String:
	return t.replace("{joueur}", nom).replace("{age}", age)


## Le joueur que vise la situation, dans l'effectif cru de la saison (les ids triés, pour que le tirage soit
## le même partout).
static func _cible(cru: Dictionary, cible: String, h: Hasard) -> String:
	if cible == "equipe":
		return ""
	var ids: Array = cru.keys()
	ids.sort()
	var par_note := ids.duplicate()
	par_note.sort_custom(func(a, b): return int(cru[a].note) > int(cru[b].note) if int(cru[a].note) != int(cru[b].note) else str(a) < str(b))
	match cible:
		"remplacant":
			var banc := par_note.slice(11) if par_note.size() > 11 else par_note
			return str(h.choix(banc))
		"capitaine":
			var tete := par_note.slice(0, mini(11, par_note.size()))
			tete.sort_custom(func(a, b): return int(cru[a].age) > int(cru[b].age) if int(cru[a].age) != int(cru[b].age) else str(a) < str(b))
			return str(tete[0])
		"jeune":
			var jeunes := ids.duplicate()
			jeunes.sort_custom(func(a, b): return int(cru[a].age) < int(cru[b].age) if int(cru[a].age) != int(cru[b].age) else str(a) < str(b))
			return str(jeunes[0])
	return str(h.choix(ids))


## Le choix fait pour une journée : « a », « b », ou « » (pas tranché).
static func choix_de(f: Node, club: String, s: int, j: int) -> String:
	var c := str((f.decisions.get("%d/%d/%s" % [s, j, club], {}) as Dictionary).get("dilemme", ""))
	return c if c in ["a", "b"] else ""


## Tranche la situation d'une journée : la consigne du match, telle qu'elle est, avec le choix. Faux si
## le match est joué ou si l'on ne dirige pas le club (Football.decider).
static func choisir(f: Node, club: String, s: int, j: int, choix: String) -> bool:
	if not choix in ["a", "b"] or du_jour(f, club, s, j).is_empty():
		return false
	var c: Dictionary = (f.consigne_de(s, j, club).consigne as Dictionary).duplicate(true)
	c["dilemme"] = choix
	return f.decider(s, j, club, c)


## Ce que les situations font à l'effectif d'un club pour le match de la journée j : celle de la journée
## (« maintenant ») et celle d'avant (« ensuite »). [{cible (id, « » pour tous), moral, condition}].
static func effets(f: Node, club: String, s: int, j: int) -> Array:
	var out: Array = []
	for x in [[j, "maintenant"], [j - 1, "ensuite"]]:
		var choix := choix_de(f, club, s, int(x[0]))
		if choix == "":
			continue
		var d := du_jour(f, club, s, int(x[0]))
		if d.is_empty():
			continue
		var e: Dictionary = (d[choix] as Dictionary).get(x[1], {})
		if e.has("cible") and str(d.cible) != "":
			out.append({"cible": str(d.cible), "moral": int(e.cible.get("moral", 0)), "condition": int(e.cible.get("condition", 0))})
		if e.has("equipe"):
			out.append({"cible": "", "moral": int(e.equipe.get("moral", 0)), "condition": int(e.equipe.get("condition", 0))})
	return out


## Applique les effets à un effectif (sur place) : moral et condition bornés entre 0 et 100.
static func appliquer(effectif: Dictionary, liste: Array) -> void:
	for e in liste:
		for id in effectif:
			if str(e.cible) != "" and str(id) != str(e.cible):
				continue
			var p: Dictionary = effectif[id]
			p.moral = clampi(int(p.get("moral", 70)) + int(e.moral), 0, 100)
			p.condition = clampi(int(p.get("condition", 100)) + int(e.condition), 0, 100)


## La tactique d'une journée est posée : une consigne existe, et elle dit autre chose que la consigne par
## défaut (trancher la décision de la semaine enregistre la consigne telle qu'elle est, sans la poser).
static func tactique_posee(f: Node, club: String, s: int, j: int) -> bool:
	var c: Dictionary = f.consigne_de(s, j, club)
	if str(c.etat) == "aucune":
		return false
	var x: Dictionary = (c.consigne as Dictionary).duplicate()
	x.erase("dilemme")
	return x != f.consigne({})
