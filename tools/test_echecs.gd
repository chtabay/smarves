extends SceneTree
## Vérifie les échecs du Cercle sans réseau : godot --headless --path . -s tools/test_echecs.gd
## L'échiquier (le coup au clic, la promotion, le roque et la prise en passant affichés tout de suite),
## le panneau sur des vues du serveur (réglages, mise, partie, fin), la table 3D, les règles, le seuil
## du Cercle au manifeste et la façade de la brique.

const ECHIQUIER := preload("res://scripts/plateaux/echiquier.gd")
const DEPART := "RNBQKBNRPPPPPPPP" + "................................" + "pppppppprnbqkbnr"

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	_echiquier()
	await _panneau()
	_table()
	_divers()
	print("%d échec(s)" % fails)
	quit(1 if fails else 0)


func _echiquier() -> void:
	var e: Control = ECHIQUIER.new()
	e.size = Vector2(480, 480)
	root.add_child(e)
	var joues := []
	e.coup.connect(func(u): joues.append(u))
	e.poser(DEPART, ["e2e4", "e2e3", "g1f3"])
	check(e.case_sous(e._rect(12).get_center()) == 12, "la case sous le pointeur est celle qu'on dessine (e2)")
	e._essayer(12, 28)
	check(joues == ["e2e4"], "un coup permis part au serveur")
	check(e.plateau[28] == "P" and e.plateau[12] == ".", "le coup s'affiche avant la réponse")
	check(e.legaux.is_empty(), "plus de coup permis en attendant la réponse")
	e.poser(DEPART, ["e2e4"])
	e._essayer(12, 20)
	check(joues.size() == 1, "un coup non permis ne part pas")
	e.retourne = true
	check(e.case_sous(e._rect(52).get_center()) == 52, "retourné, les noirs en bas : la case reste la bonne")
	check(e._rect(0).position.y < e._rect(56).position.y, "retourné, a1 est en haut")
	var p := ".".repeat(48) + "P......." + "....K..k"
	e.retourne = false
	e.poser(p, ["a7a8q", "a7a8r", "a7a8b", "a7a8n"])
	e._essayer(48, 56)
	check(not e._promo.is_empty() and joues.size() == 1, "la promotion demande la pièce")
	e._promo = {}
	e._jouer(48, 56, "n")
	check(joues[-1] == "a7a8n" and e.plateau[56] == "N", "la promotion en cavalier")
	var r: String = ECHIQUIER.appliquer("R...K..R" + ".".repeat(56), "e1g1")
	check(r.substr(0, 8) == "R....RK.", "le petit roque déplace la tour")
	var ep := ".".repeat(32) + "...pP..." + ".".repeat(24)
	var apres: String = ECHIQUIER.appliquer(ep, "e5d6")
	check(apres[43] == "P" and apres[35] == ".", "la prise en passant retire le pion")
	e.queue_free()


func _panneau() -> void:
	var calque := Control.new()
	calque.size = Vector2(1600, 900)
	root.add_child(calque)
	var p: PanelContainer = load("res://scripts/plateaux/echecs_panel.gd").new()
	p.hors_ligne = true
	p.title = "Échecs contre Madame Lacroix"
	calque.add_child(p)
	await process_frame
	p.appliquer(JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/echecs_vue_reglage.json")))
	await process_frame
	check(p.echiquier.retourne, "les noirs pour soi : l'échiquier se retourne")
	check(p._etat.text.contains("cadence"), "les réglages à deux sont annoncés")
	var textes := []
	for b in p._reglage.find_children("*", "Button", true, false):
		textes.append(b.text)
	check("5 min" in textes and "Les noirs" in textes and "Pour l'honneur" in textes, "cadences, couleurs et mises sont proposées")
	var mise_choisie := false
	for b in p._reglage.find_children("*", "Button", true, false):
		if b.text == root.get_node("Game").fmt(250) and b.button_pressed:
			mise_choisie = true
	check(mise_choisie, "la mise proposée est cochée")
	var gain := false
	for l in p._reglage.find_children("*", "Label", true, false):
		if l.text.contains("les deux mises"):
			gain = true
	check(gain, "à deux, le gagnant prend les deux mises")
	p.appliquer(JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/echecs_vue_partie.json")))
	await process_frame
	check(not p.echiquier.retourne, "les blancs pour soi : l'échiquier à l'endroit")
	check(p._haut.nom.text.contains("Expert") and not p._haut.nom.text.contains("1500"), "le robot dit sa force en mots, pas son Elo")
	check(p._bas.temps.text == "4:31", "la pendule du joueur (4:31)")
	check(p._etat.text.contains("À vous"), "c'est au joueur")
	check(p._feuille.text.contains("3.") and p._feuille.text.contains("f1-c4"), "la feuille de partie")
	check(p.echiquier.legaux.has("e1g1"), "les coups permis viennent du serveur")
	var v: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/echecs_vue_partie.json"))
	v.phase = "fin"
	v.partie.fin = {"gagnant": "blancs", "raison": "mat"}
	v.partie.pendule.court = null
	p.appliquer(v)
	await process_frame
	check(p._etat.text.begins_with("Vous gagnez"), "la victoire est annoncée")
	var revanche := false
	for b in p._gestes.find_children("*", "Button", true, false):
		revanche = revanche or b.text == "Revanche"
	check(revanche, "la revanche est proposée")
	calque.queue_free()


func _table() -> void:
	var t: Node3D = load("res://scripts/plateaux/plateaux.gd").table()
	root.add_child(t)
	check(t._pieces.get_child_count() == 32, "la table 3D pose les 32 pièces du départ")
	t.montrer("....k..." + ".".repeat(48) + "....K...")
	check(t._pieces.get_child_count() >= 2, "la table 3D suit la position")
	t.queue_free()


func _divers() -> void:
	check(load("res://scripts/jeux/regles.gd").texte("echecs").contains("pendule"), "les règles des échecs")
	check(load("res://scripts/jeux/regles.gd").NOMS.has("echecs"), "le nom du jeu en tête des règles")
	var cercle := false
	for l in load("res://scripts/socle/commune.gd").smarves().salles("casino"):
		cercle = cercle or (l.id == "cercle" and int(l.seuil) > 0)
	check(cercle, "le Cercle a son seuil dans le manifeste")
	check(load("res://scripts/plateaux/plateaux.gd").panneau("cercle:echecs-1").table_id == "cercle:echecs-1", "la façade de la brique")
	check(ResourceLoader.exists("res://scenes/cercle.tscn"), "la scène du Cercle")
