extends SceneTree
## Vérifie « Mes clubs » et « Ma carrière » sans affichage : godot --headless --path . -s tools/test_mes_clubs.gd
## Une page par club suivi (ses tuiles, sa barre d'actions, le classement, les quatorze journées, l'effectif,
## les parts ; « Gérer » ouvre le bureau par-dessus le carnet),
## puis le calendrier ; la fortune notée semaine après semaine, sa courbe, sa variation ; le palmarès lu
## dans l'historique de la pyramide (la place finale de chaque club).

const TMP := "user://test_mes_clubs/"

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
	var carriere: GDScript = load("res://scripts/socle/carriere.gd")
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
	carriere.dossier = TMP
	carriere.effacer()
	t = foot.coup_envoi(1, 5) + 4 * 3600
	foot.regler_horloge(func(): return t)
	load("res://tools/essai.gd").greffer(root)
	foot.actualiser()
	var club := "smarves"

	# ---- sans club suivi : « Mes clubs » n'a que le calendrier
	check(carnet.pages_clubs().map(func(p): return p[0]) == ["tous", "comment", "calendrier"], "sans part, Mes clubs a « Tous les clubs », « Comment ça marche » et le calendrier")
	carnet.ouvrir_sur("clubs")
	await process_frame
	check(_textes(carnet.get("_left")).contains("Le football") and _textes(carnet.get("_right")).contains("Le basket"), "et il montre les deux championnats")
	check(carnet.get("_club_vu") == "tous" and carnet.get("_left").find_child("Club_football_" + club, true, false) != null, "« Tous les clubs » d'abord : l'Étoile y a sa ligne")
	# ---- comment ça marche : la règle des clubs, toujours là
	carnet.ouvrir_club("comment")
	await process_frame
	var regle := _textes(carnet.get("_left")) + _textes(carnet.get("_right"))
	check(regle.contains("SUIVRE UN CLUB") and regle.contains("LES PARTS") and regle.contains("QUI DIRIGE") and regle.contains("lundi à midi") and regle.contains("LA TACTIQUE (FOOTBALL)"),
		"« Comment ça marche » : suivre, les parts, qui dirige, la relève, la tactique")
	# ---- supporter : on ouvre l'Étoile depuis « Tous les clubs », on la suit sans part
	carnet.ouvrir_club("tous")
	await process_frame
	(carnet.get("_left").find_child("Club_football_" + club, true, false) as Button).pressed.emit()
	await process_frame
	check(carnet.get("_club_vu") == club and carnet.pages_clubs().map(func(p): return p[0]) == [club, "tous", "comment", "calendrier"], "un clic ouvre sa page, le temps de la lire")
	var tf := _textes(carnet.get("_left"))
	check(tf.contains("vous ne le suivez pas") and carnet.get("_left").find_child("Tactique_club", true, false) != null, "sa page dit qu'on ne le suit pas, et montre sa tactique")
	check(tf.contains("4-4-2") and tf.contains("mentalité équilibrée") and tf.contains("Gardien") and tf.contains("Attaque") and tf.contains("l'adjoint aligne l'équipe type"),
		"la tactique se lit : formation, mentalité, le onze ligne par ligne, qui l'a posée")
	(carnet.get("_left").find_child("Suivre", true, false) as Button).pressed.emit()
	await process_frame
	check(avis.suit("football", club) and _textes(carnet.get("_left")).contains("vous le suivez") and (carnet.get("_left").find_child("Suivre", true, false) as Button).text == "Ne plus suivre",
		"« Suivre ce club » : on le suit, sans part")
	# Ses nouvelles : les buteurs du match, le rendez-vous de la veille, le président qui change.
	var courrier: GDScript = load("res://scripts/socle/foot_courrier.gd")
	var m1: Dictionary = courrier.match_de(foot, club, 1, 1)
	var buts: String = courrier.buts(foot, club, 1, 1, m1)
	var score: Array = m1.score
	check((int(score[0]) + int(score[1]) == 0 and buts == "") or (buts.contains("'") and (buts.begins_with("Buts : ") or buts.begins_with("En face : "))), "les buteurs d'un match joué : %s" % buts)
	var t0 := t
	t = foot.coup_envoi(1, 6) - 3 * 3600
	check(avis.call("_veille", foot, club) and avis.liste.any(func(x): return str(x.id).begins_with("veille/1/6/" + club) and str(x.lien.vers) == "stade"), "la veille du match, le rendez-vous au stade")
	t = t0
	check(avis.call("_president", foot, club), "la première lecture note le président")
	foot.forcer_porteurs("Lucien:5", club)
	avis.call("_president", foot, club)
	check(avis.liste.any(func(x): return str(x.titre).begins_with("Lucien dirige désormais")), "un nouveau président : la nouvelle arrive au supporter")
	carnet.ouvrir_club(club)
	await process_frame
	var lf: Node = carnet.get("_left")
	check(lf.find_child("Action_Statistiques", true, false) != null and lf.find_child("Action_Voir_bureau", true, false) != null and lf.find_child("Action_Entrainement", true, false) == null
		and lf.find_child("Action_Mercato", true, false) == null, "le supporter a ses boutons : statistiques, voir le bureau, stade, notaire ; pas ceux du dirigeant")
	foot.forcer_porteurs("", club)
	carnet.ouvrir_club("tous")
	await process_frame
	check(carnet.pages_clubs().map(func(p): return p[0]) == [club, "tous", "comment", "calendrier"], "suivi, il reste dans Mes clubs")
	avis.suivre("football", club, false)
	check(carnet.pages_clubs().map(func(p): return p[0]) == ["tous", "comment", "calendrier"], "« Ne plus suivre » : il en sort")
	carnet.toggle()

	# ---- une part de l'Étoile : sa page
	foot.forcer_porteurs("vous:2", club)
	check(carnet.pages_clubs().map(func(p): return p[0]) == [club, "tous", "comment", "calendrier"], "une page pour l'Étoile, puis tous les clubs, la règle, le calendrier")
	carnet.ouvrir_club(club)
	await process_frame
	var g: Node = carnet.get("_left")
	var tg := _textes(g)
	var barre: Node = carnet.get("_onglets")
	check(carnet.get("_onglet") == "clubs" and barre.find_child("Page_calendrier", true, false) != null and (barre.find_child("Page_" + club, true, false) as Button).disabled, "sous « Mes clubs », dans la barre : l'Étoile (ouverte), le calendrier")
	check(g.find_child("Bandeau_club", true, false) != null, "la page s'ouvre sur un bandeau aux couleurs du club")
	var cl: Array = foot.classement(1, 0, 0)
	check(g.find_child("Classement", true, false) != null and tg.contains(foot.clubs[club].nom), "le classement du groupe")
	check(g.find_child("Tuiles", true, false) != null and tg.contains("RANG") and tg.contains("POINTS") and tg.contains("FORME"), "trois tuiles : le rang, les points, la forme")
	var actions: Node = g.find_child("Actions", true, false)
	check(actions != null and ["Gerer", "Tactique", "Entrainement", "Mercato", "Stade", "Notaire"].all(func(n): return actions.find_child("Action_" + n, true, false) != null)
		and (actions.find_child("Action_Gerer", true, false) as Button).icon != null, "la barre d'actions, chaque bouton son picto")
	var td := _textes(carnet.get("_right"))
	# Les journées en tableau : cinq colonnes (J, date, domicile ou extérieur, adversaire, résultat).
	var jg: GridContainer = carnet.get("_right").find_child("Journees", true, false)
	check(td.contains("JOURNÉES") and jg != null and jg.get_child_count() == 14 * 5 and td.contains("J1\n") and td.contains("J14\n"), "les quatorze journées, en face, en tableau")
	var cinq := true
	for i in 5:
		var res: Node = jg.get_child(i * 5 + 4)
		cinq = cinq and res.find_children("Forme_*", "", true, false).size() == 1 and RegEx.create_from_string("^\\d+-\\d+$").search(str(res.get_child(1).text)) != null
	var sixieme: Node = jg.get_child(5 * 5 + 4)
	check(cinq and sixieme.get_child_count() == 1 and str(sixieme.get_child(0).text).begins_with("dans "), "cinq journées jouées avec leur pastille et leur score, la sixième avec son compte à rebours")
	var d := _textes(carnet.get("_right"))
	check(carnet.get("_right").find_child("Effectif", true, false) != null and d.contains("Note") and d.contains("Moral"), "en face, l'effectif")
	check(d.contains("Vous en tenez 1, "), "les parts qu'on tient, en une ligne")
	check(tg.contains("vous dirigez") and g.find_child("Regler_tactique", true, false) != null and g.find_child("Suivre", true, false) == null,
		"on dirige : « Régler la tactique », et pas de « Suivre » (les parts suffisent)")
	# ---- Gérer : le bureau s'ouvre par-dessus le carnet, sur sa page ; Échap ramène au carnet.
	(actions.find_child("Action_Tactique", true, false) as Button).pressed.emit()
	await process_frame
	var bureau: Node = carnet.gestion().find_child("Bureau", true, false) if carnet.gestion() != null else null
	check(carnet.is_open() and bureau != null and bureau.get_script().get_global_name() == "Bureau" and bureau.club == club and bureau.page == "tactique", "Tactique ouvre le bureau du club sur la tactique, dans le carnet")
	if bureau != null:
		bureau.closed.emit()
	await process_frame
	check(carnet.is_open() and carnet.gestion() == null and carnet.get("_onglet") == "clubs", "refermé, on retrouve la page du club")
	# ---- Le notaire, par téléphone : le registre des obligations par-dessus le carnet.
	(carnet.get("_left").find_child("Action_Notaire", true, false) as Button).pressed.emit()
	await process_frame
	var reg: Node = carnet.gestion().find_child("Registre", true, false) if carnet.gestion() != null else null
	check(carnet.is_open() and reg != null and reg.get_script().get_global_name() == "FootObligations" and reg.club == club and carnet.gestion().find_child("AuTelephone", true, false) != null,
		"« Le notaire » ouvre le registre de l'Étoile, au téléphone, dans le carnet")
	if reg != null:
		reg.closed.emit()
	await process_frame
	check(carnet.is_open() and carnet.gestion() == null, "refermé, on retrouve la page du club")
	# Le bouton du registre, au bureau : le notaire prend sa place.
	carnet.gerer("football", club)
	await process_frame
	carnet.gestion().find_child("Bureau", true, false).obligations.emit()
	await process_frame
	await process_frame
	check(carnet.gestion() != null and carnet.gestion().name == "Notaire", "« Le registre des obligations » du bureau appelle le notaire")
	carnet.fermer_gestion()
	(barre.find_child("Page_calendrier", true, false) as Button).pressed.emit()
	await process_frame
	check(carnet.get("_club_vu") == "calendrier" and _textes(carnet.get("_left")).contains("Les journées de la saison"), "le sous-onglet du calendrier")
	carnet.toggle()

	# ---- Ma carrière : la fortune, semaine après semaine
	carriere.effacer()
	carriere.noter(1000, t - 14 * 86400, false)
	carriere.noter(1500, t - 7 * 86400, false)
	carriere.noter(1200, t - 7 * 86400 + 3600, false)
	check(carriere.courbe().size() == 2 and int(carriere.courbe()[1][1]) == 1200, "une valeur par semaine, la dernière vue l'emporte")
	check(carriere.variation(2000, t) == 800 and carriere.variation(2000, t - 15 * 86400) == null, "la variation depuis la semaine d'avant")
	game.credits = 2000
	carnet.ouvrir_sur("carriere")
	await process_frame
	var gauche := _textes(carnet.get("_left"))
	check(carriere.courbe().size() == 3, "ouvrir le carnet note la semaine")
	var variation: Label = carnet.get("_left").find_child("Variation", true, false)
	check(variation != null and variation.text.begins_with("+") and carnet.get("_left").find_child("Courbe", true, false) != null and gauche.contains("LA FORTUNE, SUR 3 SEMAINES"), "la variation et la courbe")
	check(_textes(carnet.get("_right")).contains("Aucune saison close") and gauche.contains("RECORDS"), "pas encore de palmarès ; les records")
	var cartes_droite: Array = carnet.get("_right").get_children().filter(func(n): return n is PanelContainer)
	check(not cartes_droite.is_empty() and cartes_droite[0].name == "Pensionnaire" and cartes_droite[0].find_child("Ouvrir_pensionnaire", true, false) != null, "le pensionnaire en tête de la page de droite, avec son bouton")
	carnet.ouvrir_onglet("compte")
	await process_frame
	check(carnet.get("_onglet") == "biens" and _textes(carnet.get("_left")).contains("Depuis la semaine dernière\n+"), "« compte » ouvre Mes biens, ses comptes et la variation")
	carnet.toggle()

	# ---- le palmarès : la saison close garde la place finale de chaque club
	t = foot.coup_envoi(2, 1) - 3600
	foot.actualiser()
	check(int(foot.saison) == 2 and (foot.historique[-1] as Dictionary).has("rangs"), "la saison 1 close garde les places finales")
	var p: Array = carriere.palmares(foot, club)
	var r: int = int(foot.historique[-1].rangs[club][2])
	check(p.size() == 1 and int(p[0].rang) == r and int(p[0].saison) == 1, "le palmarès de l'Étoile : %s en saison 1" % carriere.palmares(foot, club))
	check(r != 1 or str(p[0].titre) == "Champion", "premier de la Division 1 : champion")
	carnet.ouvrir_sur("carriere")
	await process_frame
	check(_textes(carnet.get("_right")).contains("Saison 1, %s : " % foot.clubs[club].nom), "le palmarès s'écrit dans Ma carrière")
	carnet.toggle()

	carriere.effacer()
	avis.effacer()
	foot.effacer()
	print("%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
