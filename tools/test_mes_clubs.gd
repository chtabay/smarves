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
	check(carnet.pages_clubs().map(func(p): return p[0]) == ["calendrier"], "sans part, Mes clubs n'a que le calendrier")
	carnet.ouvrir_sur("clubs")
	await process_frame
	check(_textes(carnet.get("_left")).contains("Le football") and _textes(carnet.get("_right")).contains("Le basket"), "et il montre les deux championnats")
	carnet.toggle()

	# ---- une part de l'Étoile : sa page
	foot.forcer_porteurs("vous:2", club)
	check(carnet.pages_clubs().map(func(p): return p[0]) == [club, "calendrier"], "une page pour l'Étoile, puis le calendrier")
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
	check(td.contains("JOURNÉES") and td.contains("J1  ") and td.contains("J14  "), "les quatorze journées, en face")
	var lignes: Array = Array(td.split("\n")).filter(func(l): return RegEx.create_from_string("^J\\d+  ").search(l) != null)
	var scores := RegEx.create_from_string("^J\\d+  .+  [VND] \\d+-\\d+ ")
	check(lignes.slice(0, 5).all(func(l): return scores.search(l) != null) and str(lignes[5]).begins_with("J6  ") and str(lignes[5]).contains("  ·  dans "), "cinq journées jouées avec leur score, la sixième avec son compte à rebours (%s)" % str(lignes.slice(4, 6)))
	var d := _textes(carnet.get("_right"))
	check(carnet.get("_right").find_child("Effectif", true, false) != null and d.contains("Note") and d.contains("Moral"), "en face, l'effectif")
	check(d.contains("Vous en tenez 1, "), "les parts qu'on tient, en une ligne")
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
