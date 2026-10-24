extends SceneTree
## Vérifie « Mes clubs » et « Ma carrière » sans affichage : godot --headless --path . -s tools/test_mes_clubs.gd
## Une page par club suivi (le classement, sa ligne soulignée, les quatorze journées, l'effectif, les parts),
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
	check(tg.contains("Les quatorze journées") and tg.contains("J1  ") and tg.contains("J14  "), "les quatorze journées")
	var lignes: Array = Array(tg.split("\n")).filter(func(l): return RegEx.create_from_string("^J\\d+  ").search(l) != null)
	var scores := RegEx.create_from_string("^J\\d+  .+  [VND] \\d+-\\d+ ")
	check(lignes.slice(0, 5).all(func(l): return scores.search(l) != null) and str(lignes[5]).begins_with("J6  ") and str(lignes[5]).contains("  ·  dans "), "cinq journées jouées avec leur score, la sixième avec son compte à rebours (%s)" % str(lignes.slice(4, 6)))
	var d := _textes(carnet.get("_right"))
	check(carnet.get("_right").find_child("Effectif", true, false) != null and d.contains("Note") and d.contains("Moral"), "en face, l'effectif")
	check(d.contains("Vous en tenez 1, ") and d.contains("le registre des parts"), "les parts qu'on tient, et le registre")
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
