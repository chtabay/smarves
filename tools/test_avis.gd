extends SceneTree
## Vérifie le courrier du joueur (autoload Avis) sans affichage : godot --headless --path . -s tools/test_avis.gd
## Un avis se publie une fois (même id, rien de plus) ; le discret va au courrier sans fiche ; les fiches qui
## arrivent ensemble se fondent en une ; le réglage du menu filtre ; le courrier voit de lui-même le match
## joué d'un club dont on tient une part, une obligation prise par un autre, la direction perdue, la
## composition pas posée la veille ; les dividendes et les tickets y arrivent ; l'onglet du carnet compte
## les non lus et les marque lus quand on le quitte.

const TMP := "user://test_avis/"

var fails := 0
## L'horloge de Football : un membre, que la fonction lit à chaque appel (un local serait copié).
var t := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var avis: Node = root.get_node("Avis")
	var foot: Node = root.get_node("Football")
	var paris: Node = root.get_node("Paris")
	var carnet: Node = root.get_node("Carnet")
	var settings: Node = root.get_node("Settings")
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	DirAccess.make_dir_recursive_absolute(TMP)
	avis.dossier = TMP
	avis.effacer()
	foot.dossier = TMP
	foot.effacer()
	paris.effacer()
	var fiches: Array = []
	avis.fiche.connect(func(texte, a): fiches.append([texte, a]))

	# Publier : une fois par id, le plus récent d'abord.
	check(avis.publier({"id": "a", "quand": 100, "titre": "Premier", "genre": "ticket"}), "un avis se publie")
	check(not avis.publier({"id": "a", "quand": 200, "titre": "Encore"}), "le même id ne se publie pas deux fois")
	avis.publier({"id": "b", "quand": 300, "titre": "Second", "genre": "match", "lien": {"vers": "bureau", "club": "smarves", "page": "championnat"}})
	avis.publier({"id": "c", "quand": 50, "titre": "Discret", "genre": "biens", "importance": "discrete"})
	check(avis.liste.map(func(x): return x.id) == ["b", "a", "c"], "le plus récent d'abord : %s" % str(avis.liste.map(func(x): return x.id)))
	check(avis.non_lus().size() == 3, "trois non lus")

	# La fiche : les deux qui font glisser se fondent en une ; le discret n'y est pas.
	var texte: String = avis.montrer_file()
	check(fiches.size() == 1 and texte.begins_with("2 nouvelles") and "Un ticket réglé, un match" in texte and not "biens" in texte, "deux avis ensemble, une seule fiche : %s" % texte.replace("\n", " / "))
	check((fiches[0][1] as Dictionary).is_empty() and "→ Lire le courrier (3)" in texte, "la fiche qui résume mène au courrier")
	avis.publier({"id": "d", "titre": "Seul", "texte": "Journée 7.", "genre": "match", "lien": {"vers": "bureau", "club": "smarves", "page": "championnat"}})
	texte = avis.montrer_file()
	check(texte == "Seul\nJournée 7.\n→ Le classement" and fiches[-1][1].id == "d", "un avis seul : son titre, son texte et son bouton (%s)" % texte.replace("\n", " / "))
	settings.fiches = "important"
	avis.publier({"id": "e", "titre": "Normal"})
	check(avis.montrer_file() == "", "« l'important » : un avis normal ne fait pas de fiche")
	avis.publier({"id": "f", "titre": "Fort", "importance": "forte"})
	check(avis.montrer_file() == "Fort", "« l'important » : un avis fort, si")
	settings.fiches = "aucune"
	avis.publier({"id": "g", "titre": "Fort aussi", "importance": "forte"})
	check(avis.montrer_file() == "" and avis.deja("g"), "« aucune » : pas de fiche, mais l'avis est au courrier")
	settings.fiches = "toutes"
	avis.tout_lu()
	check(avis.non_lus().is_empty(), "tout lu")
	check(avis.peut_aller({"vers": "bureau"}) and avis.nom_du_lien({"vers": "registre"}) == "Le registre des parts", "les liens ont leur nom")

	# Le carnet : l'onglet Courrier compte les non lus, et les marque lus quand on le quitte.
	avis.publier({"id": "h", "titre": "Nouveau", "texte": "Un mot.", "lien": {"vers": "carnet", "onglet": "compte"}})
	var onglet: Array = carnet.onglets().filter(func(o): return o[0] == "courrier")
	check(not onglet.is_empty() and onglet[0][1] == "Courrier (1)", "l'intercalaire dit le nombre de non lus : %s" % str(onglet))
	carnet.ouvrir_sur("courrier")
	await process_frame
	var gauche: Node = carnet.get("_left")
	var titres: Array = gauche.find_children("Avis", "Label", true, false).map(func(l): return l.text)
	check(carnet.is_open() and titres == ["Nouveau"], "la page de gauche montre le nouveau : %s" % str(titres))
	carnet.ouvrir_onglet("compte")
	check(avis.non_lus().is_empty(), "quitter l'onglet marque le courrier lu")
	carnet.toggle()
	await process_frame
	avis.effacer()

	# Football : deux clubs, une part de l'Étoile, la journée 3 jouée.
	t = foot.coup_envoi(1, 3) + 3 * 3600
	foot.regler_horloge(func(): return t)
	load("res://tools/essai.gd").greffer(root)
	foot.actualiser()
	var club := "smarves"
	foot.forcer_porteurs("vous:2", club)
	foot.dividendes[club] = {"s": 1, "j": 2}
	avis.verifier()
	check(avis.liste.is_empty(), "la première lecture ne refait pas l'histoire de la saison")
	check(str(avis.suivi.matchs.get(club, "")) == "1/3", "elle note où l'on en est : %s" % str(avis.suivi.get("matchs")))

	# Une semaine plus tard, la journée 4 est jouée : un avis, qui mène au classement.
	t = foot.coup_envoi(1, 4) + 3 * 3600
	avis.verifier()
	var m: Array = avis.liste.filter(func(x): return x.genre == "match")
	check(m.size() == 1 and m[0].id == "match/1/4/smarves" and m[0].lien == {"vers": "bureau", "club": club, "page": "championnat"}, "le match de la journée 4 est au courrier : %s" % (str(m[0].titre) if not m.is_empty() else "rien"))
	check(not m.is_empty() and str(m[0].titre).begins_with("L'Étoile") and "du groupe" in str(m[0].texte), "« %s » « %s »" % [m[0].titre if not m.is_empty() else "", m[0].texte if not m.is_empty() else ""])
	avis.verifier()
	check(avis.liste.filter(func(x): return x.genre == "match").size() == 1, "relire ne republie pas le match")

	# Les dividendes de Football passent par le courrier.
	foot.tic()
	var d: Array = avis.liste.filter(func(x): return x.genre == "dividende")
	check(d.size() == 1 and int(d[0].montant) > 0 and "Journées 3 à 4" in str(d[0].texte), "les dividendes des journées 3 et 4, un avis : %s" % (str(d[0].titre) if not d.is_empty() else "rien"))

	# Lucien prend deux obligations et passe devant : deux avis, et la direction perdue.
	check(foot.peut_decider(club), "seul porteur, on dirige")
	foot.forcer_porteurs("vous:2,Lucien:5+6", club)
	avis.verifier()
	var p: Array = avis.liste.filter(func(x): return x.genre == "parts")
	check(p.size() == 2 and p.all(func(x): return str(x.titre).begins_with("Lucien a pris l'obligation n° ") and x.importance == "forte" and x.lien.vers == "registre"), "deux parts prises par Lucien : %s" % str(p.map(func(x): return x.titre)))
	var dir: Array = avis.liste.filter(func(x): return x.genre == "direction")
	check(dir.size() == 1 and str(dir[0].titre).begins_with("Vous ne dirigez plus") and "Lucien" in str(dir[0].texte), "la direction perdue : %s" % (str(dir[0].texte) if not dir.is_empty() else "rien"))
	foot.forcer_porteurs("vous:2+9", club)
	avis.verifier()
	dir = avis.liste.filter(func(x): return x.genre == "direction")
	check(dir.size() == 2 and str(dir[0].titre).begins_with("Vous dirigez désormais"), "puis reprise : « %s »" % (str(dir[0].titre) if not dir.is_empty() else ""))

	# La veille du match, la composition n'est pas posée : un rappel, qui mène à la tactique.
	t = foot.coup_envoi(1, 5) - 6 * 3600
	avis.verifier()
	var r: Array = avis.liste.filter(func(x): return x.genre == "rappel")
	check(r.size() == 1 and r[0].lien.page == "tactique" and "aujourd'hui" in str(r[0].texte), "le rappel de la composition : %s" % (str(r[0].texte) if not r.is_empty() else "rien"))

	# Un ticket réglé : gagné, il fait glisser la fiche ; perdu, il va au courrier.
	game.credits = 1000
	var j5: Array = foot.journee(1, 0, 0, 5)
	var choix := {"%s|%s" % [j5[0].dom, j5[0].ext]: "1"}
	paris.parier(1, 5, 0, 0, choix, 50)
	t = foot.coup_envoi(1, 5) + 3 * 3600
	paris.tic()
	var tk: Array = avis.liste.filter(func(x): return x.genre == "ticket")
	check(tk.size() == 1 and str(tk[0].titre).begins_with("Ticket de la journée 5") and (tk[0].importance == "discrete") == str(tk[0].titre).ends_with("perdu"), "le ticket réglé : %s (%s)" % [tk[0].titre if not tk.is_empty() else "rien", tk[0].importance if not tk.is_empty() else ""])

	# Ce qui est gardé se relit.
	avis.sauver()
	var n: int = avis.liste.size()
	avis.liste = []
	avis.suivi = {}
	avis.charger()
	check(avis.liste.size() == n and avis.suivi.has("matchs"), "le courrier se relit de son fichier (%d avis)" % n)

	avis.effacer()
	foot.effacer()
	paris.effacer()
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
