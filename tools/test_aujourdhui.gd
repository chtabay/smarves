extends SceneTree
## Vérifie la page « Aujourd'hui » du carnet sans affichage : godot --headless --path . -s tools/test_aujourdhui.gd
## Ce qui attend le joueur, le plus pressé d'abord, chaque ligne avec son bouton (la décision de la semaine
## s'y tranche) ; ce qui est arrivé ; une carte par club suivi ; la pastille qui compte les deux ; le carnet
## qui s'ouvre dessus quand quelque chose attend.

const TMP := "user://test_aujourdhui/"
var AUJ: GDScript

var fails := 0
var t := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _textes(n: Node) -> String:
	var out := ""
	if n is Label:
		out += (n as Label).text + "\n"
	if n is Button:
		out += (n as Button).text + "\n"
	for c in n.get_children():
		out += _textes(c)
	return out


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	AUJ = load("res://scripts/socle/aujourdhui.gd")
	var avis: Node = root.get_node("Avis")
	var foot: Node = root.get_node("Football")
	var carnet: Node = root.get_node("Carnet")
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	DirAccess.make_dir_recursive_absolute(TMP)
	avis.dossier = TMP
	avis.effacer()
	foot.dossier = TMP
	foot.effacer()

	# ---- le compte à rebours
	check(AUJ.dans(100 + 2 * 86400 + 4 * 3600, 100) == "dans 2 j 4 h" and AUJ.dans(100 + 3 * 3600 + 20 * 60, 100) == "dans 3 h 20" \
		and AUJ.dans(100 + 12 * 60, 100) == "dans 12 min" and AUJ.dans(100 + 86400, 100) == "dans 1 j" and AUJ.dans(50, 100) == "maintenant", "le compte à rebours s'écrit")

	# ---- sans club suivi : rien à faire, la page le dit
	t = foot.coup_envoi(1, 3) + 4 * 3600
	foot.regler_horloge(func(): return t)
	load("res://tools/essai.gd").greffer(root)
	foot.actualiser()
	var club := "smarves"
	check(carnet.a_faire().is_empty(), "sans part, rien à faire")
	carnet.ouvrir_sur("aujourdhui")
	await process_frame
	check(carnet.onglets()[0][0] == "boite" and carnet.get("_onglet") == "boite", "la boîte est la première rubrique, et « aujourdhui » y mène")
	check(_textes(carnet.get("_left")).contains("RIEN NE PRESSE.") and _textes(carnet.get("_right")).contains("Vous ne suivez aucun club"), "la page dit qu'il n'y a rien et qu'on ne suit aucun club")
	carnet.toggle()

	# ---- on dirige l'Étoile : la décision de la semaine et la composition attendent
	foot.forcer_porteurs("vous:3", club)
	avis.verifier()
	var liste: Array = carnet.a_faire()
	var genres: Array = liste.map(func(x): return x.genre)
	check(genres == ["dilemme", "compo"], "à faire : la décision de la semaine, puis la composition (%s)" % str(genres))
	avis.publier({"id": "essai/mot", "quand": t, "titre": "Un mot du président", "texte": ""})
	check(int(liste[0].quand) == foot.coup_envoi(1, 4) and str(liste[1].titre).contains("la composition contre"), "toutes deux avant le coup d'envoi de la journée 4 : %s" % str(liste[1].titre))
	carnet.toggle()
	await process_frame
	check(carnet.get("_onglet") == "boite", "quelque chose attend : le carnet s'ouvre sur la boîte")
	check(carnet.pastille_de("boite") == 3 and carnet.get("_onglets").find_child("Rubrique_boite", true, false).find_child("Pastille", true, false) != null, "la rubrique porte la pastille : deux choses à faire et un message")
	var gauche: Node = carnet.get("_left")
	var g := _textes(gauche)
	check(g.contains("À FAIRE (2)") and g.contains("avant le coup d'envoi, dans "), "la page compte deux choses à faire, avec leur échéance")
	check(gauche.find_child("Choix_a", true, false) != null and gauche.find_child("Choix_b", true, false) != null, "la décision a ses deux boutons sur la page")
	check(gauche.find_child("Faire_compo", true, false) != null and (gauche.find_child("Faire_compo", true, false) as Button).text.contains("Préparer la tactique"), "la composition, son bouton vers la tactique")
	var nouv: Array = gauche.find_children("Nouveau", "Label", true, false).map(func(l): return l.text)
	check(nouv.size() == 1 and str(nouv[0]).ends_with("Un mot du président") and g.contains("NOUVEAU (1)"), "depuis la dernière visite : le mot du président, la décision n'y est pas répétée (%s)" % str(nouv))
	var droite: Node = carnet.get("_right")
	var d := _textes(droite)
	var carte: Dictionary = AUJ.carte(foot, club)
	check(droite.find_child("Club_" + club, true, false) != null and d.contains(str(carte.nom) + "  ·  vous dirigez"), "la carte de l'Étoile, qu'on dirige")
	check(d.contains("%s sur %d, %d pt" % [AUJ.rang(int(carte.rang)), int(carte.taille), int(carte.pts)]) and d.contains(" en 3 matchs"), "son rang et ses points après trois journées")
	check(droite.find_children("Forme_*", "", true, false).size() == 3 and str(carte.forme).length() == 3, "sa forme : trois pastilles (%s)" % carte.forme)
	check(d.contains("Journée 4, ") and d.contains("Objectif : ") and d.contains("confiance "), "son prochain match, son objectif et la confiance")
	check(d.contains("PROCHAINS RENDEZ-VOUS"), "en bas, les prochains rendez-vous")

	# ---- trancher ici : la décision quitte la liste
	(gauche.find_child("Choix_a", true, false) as Button).pressed.emit()
	await process_frame
	check(FootDilemmes.choix_de(foot, club, 1, 4) == "a", "le bouton tranche la décision")
	check(carnet.a_faire().map(func(x): return x.genre) == ["compo"], "il ne reste que la composition")
	await process_frame
	check(_textes(carnet.get("_left")).contains("À FAIRE (1)"), "la page se redessine : une chose à faire")
	var ouvert: Node = carnet.get("_right")
	check(ouvert.find_child("Ouvert", true, false) != null and _textes(ouvert).contains("Vous avez choisi : ") and ouvert.find_child("Choix_b", true, false) != null, "à droite, la décision ouverte : le choix fait, et l'autre jusqu'au coup d'envoi")
	(ouvert.find_child("Retour", true, false) as Button).pressed.emit()
	await process_frame
	check(carnet.get("_right").find_child("Club_" + club, true, false) != null, "le retour ramène au résumé du jour")
	carnet.toggle()

	# ---- la pastille compte les deux
	check(carnet.texte_pastille(1, 3).begins_with("Boîte : une chose à faire · 3 nouvelles") and carnet.texte_pastille(0, 1).begins_with("Boîte : une nouvelle"), "la pastille : %s" % carnet.texte_pastille(1, 3))

	# ---- la composition posée : plus rien ; tout lu : le carnet garde son onglet
	var c: Dictionary = (foot.consigne_de(1, 4, club).consigne as Dictionary).duplicate(true)
	check(not FootDilemmes.tactique_posee(foot, club, 1, 4), "trancher la décision ne pose pas la tactique")
	c.formation = "4-3-3"
	check(foot.decider(1, 4, club, c), "on pose la consigne")
	check(carnet.a_faire().is_empty(), "plus rien à faire")
	carnet.ouvrir_sur("courrier")
	carnet.ouvrir_onglet("cartes")
	carnet.toggle()
	carnet.toggle()
	check(carnet.get("_onglet") == "cartes", "rien n'attend : le carnet se rouvre là où on l'a laissé")
	carnet.toggle()

	# ---- l'intersaison : un club suivi qu'on ne dirige pas
	foot.forcer_porteurs("vous:1,Lucien:9", club)
	t = foot.coup_envoi(1, 14) + 4 * 3600
	liste = carnet.a_faire()
	check(liste.size() == 1 and liste[0].genre == "diriger" and str(liste[0].texte).contains("Il vous manque"), "à l'intersaison, on ne dirige pas l'Étoile : %s" % (str(liste[0].texte) if not liste.is_empty() else "rien"))
	check(int(liste[0].quand) == foot.coup_envoi(2, 1) and str(liste[0].lien.vers) == "registre", "jusqu'au premier coup d'envoi de la saison 2, vers le registre")

	avis.effacer()
	foot.effacer()
	print("%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
