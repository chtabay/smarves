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
	for n in ["StatueBigHeron", "ArretDuCar", "PanneauDuClub", "BureauDuClub", "EnseigneFacade", "Enceinte", "Foule", "RondCentral",
			"GrandHall", "Coursive", "MurDesPartenaires", "BureauDuPresident", "Parking"]:
		check(salle.get_node_or_null(n) != null, "la salle a son élément %s" % n)
	# La vitesse : la foule reste légère et le décor immobile est fondu (64 millions de triangles par image avant).
	var mm: MultiMesh = salle._foule.multimesh
	var tri_foule: int = mm.mesh.get_faces().size() / 3 * mm.instance_count
	check(tri_foule < 1500000, "la foule reste légère : %d triangles" % tri_foule)
	var dessines := salle.find_children("*", "MeshInstance3D", true, false).filter(func(m): return m.mesh != null and m.is_visible_in_tree()).size()
	check(dessines < 500, "le décor immobile est fondu : %d maillages à dessiner" % dessines)
	# La ville autour : l'avenue et ses immeubles, la couronne, les tours au loin, en quelques multimaillages.
	var ville: Node = salle.get_node_or_null("Ville")
	check(ville != null and ville.get_meta("immeubles", 0) > 200 and ville.find_children("*", "MultiMeshInstance3D", false, false).size() >= 4, "la salle est au cœur d'une ville : %d immeubles" % (ville.get_meta("immeubles", 0) if ville else 0))
	check(salle.find_children("Echoppe*", "Node3D", false, false).size() >= 12, "la coursive a ses échoppes derrière les gradins")
	check(salle.get_node("Parking").get_meta("voitures") > 20, "des voitures au parking : %d" % salle.get_node("Parking").get_meta("voitures"))
	# On passe à pied de l'arrêt du car au parquet : rien de solide sur le chemin (portes, enceinte, vomitoire).
	await physics_frame
	var espace: PhysicsDirectSpaceState3D = salle.get_world_3d().direct_space_state
	for y: float in [0.5, 1.5]:
		var q := PhysicsRayQueryParameters3D.create(Vector3(0, y, salle.ARRET_Z - 4.0), Vector3(0, y, 0.0))
		q.exclude = [salle.player.get_rid()]
		var touche := espace.intersect_ray(q)
		check(touche.is_empty(), "à %.1f m de haut, le chemin de l'arrêt au parquet est libre%s" % [y, "" if touche.is_empty() else " (bloqué à %s par %s)" % [str(touche.position), touche.collider.name]])
	# Les passages latéraux de l'enceinte mènent du grand hall à la coursive.
	for x: float in [-21.0, 21.0]:
		var q := PhysicsRayQueryParameters3D.create(Vector3(x, 1.0, salle.ENCEINTE_Z + 6.0), Vector3(x, 1.0, salle.ENCEINTE_Z - 3.0))
		check(espace.intersect_ray(q).is_empty(), "le passage de l'enceinte à x = %d est ouvert" % int(x))
	check(salle.player.position.z > 60.0, "on arrive à l'arrêt du car, sur le parvis")

	# La loge du président : du balcon du hall (en haut du grand escalier), on y entre à pied par la porte de
	# l'enceinte ; sa vitre donne sur le parquet, et l'on ne passe pas à travers.
	var balcon := Vector3(0, salle.LOGE_Y + 1.2, salle.ENCEINTE_Z + 2.5)
	var q_loge := PhysicsRayQueryParameters3D.create(balcon, Vector3(0, salle.LOGE_Y + 1.2, salle.BUREAU_POS.z))
	check(espace.intersect_ray(q_loge).is_empty(), "du balcon, la porte de l'enceinte s'ouvre sur la loge du président")
	var q_sol := PhysicsRayQueryParameters3D.create(salle.BUREAU_POS + Vector3(-2.5, 1.0, 0), salle.BUREAU_POS + Vector3(-2.5, -1.0, 0))
	check(not espace.intersect_ray(q_sol).is_empty(), "la loge a un plancher, au niveau du balcon")
	var q_vitre := PhysicsRayQueryParameters3D.create(salle.BUREAU_POS + Vector3(-3.0, 1.2, 0), Vector3(-3.0, salle.LOGE_Y + 1.2, 0))
	var vitre := espace.intersect_ray(q_vitre)
	check(not vitre.is_empty() and vitre.position.z > salle.LOGE_VITRE - 0.5, "la vitre de la loge retient le visiteur, face au parquet")
	var q_balcon := PhysicsRayQueryParameters3D.create(balcon, balcon + Vector3(0, -2.0, 0))
	check(not espace.intersect_ray(q_balcon).is_empty(), "le balcon des loges porte le visiteur")
	for n in ["AccueilDuClub", "LisseDeLaLoge", "VitreDeLaLoge", "EcranDeLaLogeSalle"]:
		check(salle.find_child(n, true, false) != null, "la salle a son élément %s" % n)
	var places_loge: Array = salle._places.filter(func(t: Transform3D): return t.origin.z > salle.LOGE_VITRE - 0.5 and absf(t.origin.x) < salle.LOGE_X)
	check(places_loge.is_empty(), "personne n'est assis dans la loge")
	check(salle._president.global_position.distance_to(salle.BUREAU_POS) < 8.0, "le président attend dans sa loge")

	# L'accueil du club : le bouton « Le club », la touche B et le comptoir du hall l'ouvrent ; il dit qui dirige,
	# les étapes pour diriger, et mène aux trois écrans.
	check(salle._bouton_club != null and salle._bouton_club.visible and salle._bouton_club.text.begins_with("Le club"), "le bouton « Le club » est à l'écran")
	var touche := InputEventKey.new()
	touche.physical_keycode = KEY_B
	touche.pressed = true
	salle._unhandled_input(touche)
	check(salle._ecran != null and salle._ecran.get_script().resource_path.ends_with("basket_club.gd") and not salle._bouton_club.visible, "la touche B ouvre l'accueil du club")
	var accueil_textes := _textes(salle._ecran)
	check(accueil_textes.has("Pour diriger le club") and accueil_textes.has("Prendre des parts du club") and accueil_textes.has("Recevoir l'effectif"), "l'accueil dit les étapes pour diriger le club")
	salle._ecran.suite = "bureau"
	salle._ecran.closed.emit()
	await process_frame
	check(salle._ecran != null and salle._ecran.get_script().resource_path.ends_with("basket_bureau.gd"), "de l'accueil, on passe au bureau du président")
	salle._ecran.closed.emit()
	await process_frame
	# De l'accueil, Inès appelle le notaire : les parts se signent chez lui, au téléphone.
	salle.open_club()
	check(salle._ecran.find_child("Aller_notaire", true, false) != null and salle._ecran.find_child("Aller_parts", true, false) == null, "l'accueil mène au notaire, plus aux parts")
	salle._ecran.suite = "notaire"
	salle._ecran.closed.emit()
	await process_frame
	var carnet: Node = root.get_node("Carnet")
	check(carnet.is_open() and carnet.gestion() != null and carnet.gestion().name == "Notaire", "le notaire s'ouvre au téléphone, dans le carnet")
	carnet.fermer_gestion()
	carnet.toggle()
	await process_frame
	var comptoir: Node = null
	for a in salle.find_children("*", "Area3D", true, false):
		if a.get_meta("interact", "") == "accueil":
			comptoir = a
	salle._on_interact(comptoir)
	check(salle._ecran != null and salle._ecran.get_script().resource_path.ends_with("basket_club.gd"), "le comptoir de l'accueil du hall ouvre l'accueil du club")
	salle._ecran.closed.emit()
	await process_frame
	check(salle._ecran == null and salle._bouton_club.visible and not salle.player.frozen, "l'accueil se ferme")

	# La porte des vestiaires mène au bureau du président ; sa porte ramène au parquet.
	var porte: Node = null
	for a in salle.find_children("*", "Area3D", true, false):
		if a.get_meta("interact", "") == "porte_bureau":
			porte = a
	salle._on_interact(porte)
	check(salle.player.global_position.distance_to(salle.BUREAU_POS) < 8.0, "la porte des vestiaires mène au bureau du président")
	check(salle._ecran_loge.text.contains(salle._court()), "le mur d'écrans du bureau répète le cube : %s" % salle._ecran_loge.text.replace("\n", " / "))
	var genres := salle.find_children("*", "Area3D", true, false).map(func(a): return a.get_meta("interact", ""))
	check("bureau" in genres and "tactique" in genres and "conseil" in genres and "partenaires" in genres and not "parts" in genres, "le grand bureau, le tableau tactique, la table du conseil, le mur des partenaires ; rien ne s'achète")
	salle.open_partenaires()
	check(salle._ecran != null and salle._ecran.get_script() != null and salle._ecran.get_script().resource_path.ends_with("basket_partenaires.gd") and salle._ecran.commune == "smarves"
		and salle._ecran.find_child("ChezLeNotaire", true, false) != null and salle._ecran.find_child("Prendre_1", true, false) == null, "le mur des partenaires s'ouvre, sans rien à acheter")
	salle._ecran.closed.emit()
	await process_frame
	salle.sortir_bureau()
	check(salle.player.global_position.z > -12.0 and salle.player.global_position.z < 0.0, "on redescend au parquet, devant la porte")
	# Le bureau et le panneau du club : les écrans du fil basket.
	salle.open_bureau()
	check(salle._ecran != null and salle._ecran.get_script() != null and salle._ecran.get_script().resource_path.ends_with("basket_bureau.gd") and salle._ecran.commune == "smarves", "le bureau du club : celui du fil basket")
	salle._ecran.closed.emit()
	await process_frame
	check(salle._ecran == null and not salle.player.frozen, "le bureau se ferme")
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
