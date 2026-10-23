extends SceneTree
## Vérifie les décisions de la semaine sans affichage : godot --headless --path . -s tools/test_dilemmes.gd
## La situation se tire de la saison, de la journée et du club (la même partout) ; le choix part avec la
## consigne ; il touche le moral et la condition du match ; le Courrier l'apporte, le tranche de ses deux
## boutons, puis en dit la suite une fois le match joué.

const TMP := "user://test_dilemmes/"

var fails := 0
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
	var carnet: Node = root.get_node("Carnet")
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	DirAccess.make_dir_recursive_absolute(TMP)
	avis.dossier = TMP
	avis.effacer()
	foot.dossier = TMP
	foot.effacer()
	t = foot.coup_envoi(1, 1) - 86400
	foot.regler_horloge(func(): return t)
	load("res://tools/essai.gd").greffer(root)
	foot.actualiser()
	var club := "smarves"
	foot.forcer_porteurs("vous:2", club)
	check(foot.peut_decider(club), "seul porteur, on dirige l'Étoile")

	# ---- la situation : la même partout, un catalogue varié
	var d: Dictionary = FootDilemmes.du_jour(foot, club, 1, 1)
	check(not d.is_empty() and FootDilemmes.CATALOGUE.has(d.cle) and str(d.titre) != "" and str(d.a.libelle) != "" and str(d.b.libelle) != "", "la journée 1 a sa situation : %s" % str(d.get("titre", "")))
	check(FootDilemmes.du_jour(foot, club, 1, 1) == d, "tirée deux fois, c'est la même")
	var vues := {}
	for j in range(1, 15):
		vues[FootDilemmes.du_jour(foot, club, 1, j).cle] = true
	check(vues.size() >= 4, "sur quatorze journées, au moins quatre situations différentes (%d)" % vues.size())
	check(not "{joueur}" in str(d.titre) and not "{joueur}" in str(d.a.suite), "le nom du joueur est écrit")
	check(FootDilemmes.du_jour(foot, club, 1, 0).is_empty() and FootDilemmes.du_jour(foot, club, 1, 15).is_empty(), "rien hors des quatorze journées")

	# ---- trancher : le choix part avec la consigne, et touche l'effectif du match
	var cru: Dictionary = foot._effectif_cru(club, 1)
	var avant: Dictionary = foot.effectif(club, 1, 1).duplicate(true)
	check(FootDilemmes.choix_de(foot, club, 1, 1) == "", "pas encore tranché")
	check(FootDilemmes.choisir(foot, club, 1, 1, "a"), "on tranche « %s »" % d.a.libelle)
	check(str(foot.consigne_de(1, 1, club).consigne.get("dilemme", "")) == "a" and FootDilemmes.choix_de(foot, club, 1, 1) == "a", "le choix est dans la consigne du match")
	var apres: Dictionary = foot.effectif(club, 1, 1)
	var bouge := false
	for id in apres:
		if avant.has(id) and (int(apres[id].moral) != int(avant[id].moral) or int(apres[id].condition) != int(avant[id].condition)):
			bouge = true
	check(bouge, "le moral ou la condition de l'effectif du match a bougé")
	check(cru == foot._effectif_cru(club, 1), "l'effectif de la saison, lui, ne bouge pas")
	check(not FootDilemmes.choisir(foot, club, 1, 1, "c"), "un choix qui n'existe pas est refusé")
	# Une situation qui vise un joueur : son moral bouge comme le dit le catalogue.
	var visee := {}
	var jv := 0
	for j in range(1, 15):
		var x: Dictionary = FootDilemmes.du_jour(foot, club, 1, j)
		if str(x.cible) != "" and (x.a.maintenant as Dictionary).has("cible"):
			visee = x
			jv = j
			break
	if not visee.is_empty():
		var e0: int = int(foot.effectif(club, 1, jv)[visee.cible].moral)
		FootDilemmes.choisir(foot, club, 1, jv, "a")
		var e1: int = int(foot.effectif(club, 1, jv)[visee.cible].moral)
		var attendu: int = int(visee.a.maintenant.cible.get("moral", 0)) + int((visee.a.maintenant as Dictionary).get("equipe", {}).get("moral", 0))
		check(e1 == clampi(e0 + attendu, 0, 100), "journée %d, %s : le moral de %s passe de %d à %d" % [jv, visee.cle, visee.joueur, e0, e1])

	# ---- le Courrier : l'avis, ses deux boutons
	foot.decisions.erase("1/1/%s" % club)
	foot.locales.erase("1/1/%s" % club)
	foot.oublier_effectifs()
	avis.verifier()
	var di: Array = avis.liste.filter(func(x): return x.genre == "dilemme")
	check(di.size() == 1 and di[0].id == "dilemme/1/1/%s" % club and str(di[0].titre).ends_with(d.titre), "la décision de la journée 1 est au courrier : %s" % (str(di[0].titre) if not di.is_empty() else "rien"))
	var boutons: Array = avis.choix_de(di[0])
	check(boutons.size() == 2 and boutons.all(func(b): return b.ouvert and not b.fait), "deux choix, ouverts")
	carnet.ouvrir_sur("courrier")
	await process_frame
	var bb: Button = carnet.get("_left").find_child("Choix_b", true, false)
	check(bb != null and bb.text.contains(str(d.b.libelle)), "le carnet montre les deux boutons")
	bb.pressed.emit()
	await process_frame
	check(FootDilemmes.choix_de(foot, club, 1, 1) == "b", "le bouton tranche « %s »" % d.b.libelle)
	await process_frame
	var pages: Array = [carnet.get("_left"), carnet.get("_right")]
	check(pages.all(func(p): return p.find_children("Choix_b*", "", true, false).is_empty()) and pages.any(func(p): return not p.find_children("Choix_a*", "", true, false).is_empty()), "le choix fait n'a plus de bouton, l'autre reste jusqu'au coup d'envoi")
	carnet.toggle()
	await process_frame
	avis.verifier()
	check(avis.liste.filter(func(x): return x.genre == "dilemme").size() == 1, "relire ne republie pas la décision")

	# ---- après le match : la suite, et la décision suivante
	t = foot.coup_envoi(1, 1) + 3 * 3600 + 60
	foot.oublier_effectifs()
	avis.verifier()
	var su: Array = avis.liste.filter(func(x): return x.genre == "suite")
	check(su.size() == 1 and str(su[0].texte).begins_with(str(d.b.suite)) and str(su[0].titre).contains(str(d.b.libelle)), "la suite est au courrier : %s" % (str(su[0].texte) if not su.is_empty() else "rien"))
	check(avis.liste.any(func(x): return x.id == "dilemme/1/2/%s" % club), "la décision de la journée 2 arrive")
	check(not avis.choix_de(avis.liste.filter(func(x): return x.id == "dilemme/1/1/%s" % club)[0])[0].ouvert, "celle de la journée 1 est fermée")
	# La journée 2 sans réponse : la suite le dit.
	t = foot.coup_envoi(1, 2) + 3 * 3600 + 60
	avis.verifier()
	var su2: Array = avis.liste.filter(func(x): return x.id == "suite/1/2/%s" % club)
	check(su2.size() == 1 and str(su2[0].texte).begins_with("Personne n'a tranché"), "sans réponse, la suite le dit")
	# Sans direction, pas de décision.
	foot.forcer_porteurs("vous:1,Lucien:9", club)
	t = foot.coup_envoi(1, 3) + 3 * 3600 + 60
	avis.verifier()
	check(not avis.deja("dilemme/1/4/%s" % club), "on ne dirige plus : pas de décision à prendre")

	avis.effacer()
	foot.effacer()
	print("%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
