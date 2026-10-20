extends SceneTree
## Vérifie la salle de basket sans affichage : godot --headless --path . -s tools/test_salle_basket.gd
## Le Clain Garden est un lieu du manifeste de Smarves derrière son seuil ; le car de la place y descend ;
## la scène pose le parquet, les gradins et leur foule, le cube d'écrans, le bureau du club et l'arrêt du
## car ; un match chargé remplit la salle et s'écrit sur le cube ; le car ramène à l'arrêt de la place.

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _boutons(n: Node) -> Array:
	var out: Array = []
	if n is Button:
		out.append((n as Button).text)
	for c in n.get_children():
		out += _boutons(c)
	return out


func _textes(n: Node) -> Array:
	var out: Array = []
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		out += _textes(c)
	return out


func _init() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	game.welcomed = true

	var SB: GDScript = load("res://scripts/village/salle_basket.gd")
	var smarves: Commune = Commune.smarves()
	check(smarves.valide(), "le manifeste de Smarves reste valide : %s" % ", ".join(smarves.erreurs))
	var lieu: Dictionary = SB.lieu_de("smarves")
	check(not lieu.is_empty() and lieu.name == "Le Clain Garden" and lieu.seuil == 10000 and lieu.host == "M. Lacombe", "le Clain Garden est un lieu du manifeste, derrière 10 000 crédits gagnés")
	check(smarves.interieur("gymnase") == "res://scenes/salle_basket.tscn", "son intérieur est la scène de la salle")
	check(SB.desservie("smarves"), "le car s'arrête à la salle de Smarves")
	check(Lines.RUMORS.has("gymnase"), "les habitants en parlent")

	# L'écran du car, à la place : fermé sous le seuil, le bouton pour descendre au-dessus.
	var carte: Node = root.get_node("Carte")
	game.won = 0
	carte.ouvrir_car()
	await process_frame
	var textes := _textes(carte)
	check(not _boutons(carte).any(func(t): return t.begins_with("Descendre")) and textes.any(func(t): return t.contains("10 000")), "sous le seuil, le car dit ce qu'il manque pour descendre au Clain Garden")
	carte._cacher()
	root.get_tree().paused = false
	carte.set("_en_route", false)
	game.won = 10000
	carte.ouvrir_car()
	await process_frame
	var boutons := _boutons(carte)
	check(boutons.has("Descendre au Clain Garden  →"), "au seuil, le car propose de descendre au Clain Garden : %s" % str(boutons))
	carte.descendre_salle("smarves")
	await create_timer(1.5).timeout
	var salle: Node = current_scene
	check(salle != null and salle.scene_file_path == "res://scenes/salle_basket.tscn", "le car dépose au Clain Garden")
	check(not carte.is_open() and not paused, "la carte est fermée, le jeu repris")

	# La salle : le club de secours tant que le gymnase n'est pas déclaré, ses couleurs, ses écrans.
	check(salle.commune == "smarves" and salle._place_name() == "Le Clain Garden", "la salle de Smarves s'appelle le Clain Garden")
	check(salle._nom_club() != "" and salle._court() != "" and salle._couleurs().size() == 2, "le club, son sigle et ses couleurs : %s, %s" % [salle._nom_club(), salle._court()])
	check(salle._places.size() > 3000, "deux étages de gradins tout autour : %d places" % salle._places.size())
	check(salle._cube.size() == 4 and salle._cube[0].text.contains(salle._court()), "le cube d'écrans a quatre faces et annonce le club : %s" % salle._cube[0].text.replace("\n", " / "))
	check(salle._joueurs.size() == 5 and salle._ballon.visible, "sans match, cinq joueurs s'entraînent")
	var clairsemee: int = salle._foule.get_meta("prises")
	check(clairsemee > 0 and clairsemee < salle._places.size() / 4, "à l'entraînement, la salle est clairsemée : %d" % clairsemee)
	for n in ["StatueBigHeron", "ArretDuCar", "PanneauDuClub", "BureauDuClub", "EnseigneFacade", "MurDuHall", "Foule", "RondCentral"]:
		check(salle.get_node_or_null(n) != null, "la salle a son élément %s" % n)
	check(salle.player.position.z > 60.0, "on arrive à l'arrêt du car, sur le parvis")

	# Le bureau et le panneau du club : le président le dit tant que le fil basket ne les a pas faits.
	salle.open_bureau()
	check(salle._ecran != null and _textes(salle._ecran).any(func(t): return t.contains("M. Lacombe")), "le bureau du club : une affiche où le président répond, en attendant le bureau du fil basket")
	salle._game.closed.emit()
	await process_frame
	check(salle._ecran == null and not salle.player.frozen, "l'affiche se ferme")
	salle.open_panneau()
	check(salle._ecran != null and salle._ecran.get_script() != null and salle._ecran.get_script().resource_path.ends_with("basket_panneau.gd") and salle._ecran.commune == "smarves", "le panneau du club, à l'entrée : celui du championnat de basket")
	salle._ecran.closed.emit()
	await process_frame

	# Un match chargé : la salle se remplit, le cube et le bandeau disent le score.
	salle.charger_match({"dom": salle._nom_club(), "ext": "Les Aigles de Chauvigny", "score": [98, 94], "quarts": [[24, 22], [27, 25], [21, 26], [26, 21]], "fini": true})
	var comble: int = salle._foule.get_meta("prises")
	check(comble > salle._places.size() * 0.8, "un match : la salle est comble (%d places prises)" % comble)
	check(salle._cube[2].text.contains("98") and salle._cube[2].text.contains("94") and salle._cube_titre[0].text.begins_with("FIN"), "le cube donne le score final : %s" % salle._cube[2].text.replace("\n", " / "))
	check(salle._bandeau.visible and salle._bandeau_score.text.contains("Les Aigles de Chauvigny"), "le bandeau du direct dit le match")
	salle.afficher_fait("Trois points au buzzer !")
	check(salle._bandeau_fait.text == "Trois points au buzzer !", "un fait de match passe dans le bandeau")
	salle.charger_match({"dom": salle._nom_club(), "ext": "Les Aigles de Chauvigny", "quand": "samedi 20 h"})
	check(salle._cube_titre[0].text == "PROCHAIN MATCH" and salle._joueurs[0].visible, "un match à venir : le cube l'annonce, le club s'entraîne encore")
	salle.jouer_entrainement()
	check(salle._joueurs[0].visible and not salle._bandeau.visible, "retour à l'entraînement")

	# Le car ramène à la place de Smarves, à l'arrêt.
	salle.reprendre_le_car()
	await create_timer(1.5).timeout
	var main: Node = current_scene
	check(main != null and main.name == "Main", "le car ramène à la place de Smarves")
	if main and main.player:
		var arret: Vector3 = main.get_node("Village").ARRET[0]
		check(main.player.global_position.distance_to(arret) < 3.0, "on descend à l'arrêt du car : %s" % str(main.player.global_position))

	# Une salle ouverte par ouvrir(), avec son match.
	SB.ouvrir("smarves", {"dom": "Les Hérons du Clain", "ext": "Le Poitiers Basket", "score": [12, 9], "quarts": [[12, 9]]})
	await create_timer(1.5).timeout
	salle = current_scene
	check(salle != null and salle._cube_titre[0].text.begins_with("Q1") and salle._cube[0].text.contains("12"), "ouvrir(commune, match) charge le match à l'arrivée")

	print("\n%s" % ("TOUT EST BON" if fails == 0 else "%d ÉCHEC(S)" % fails))
	quit(1 if fails > 0 else 0)
