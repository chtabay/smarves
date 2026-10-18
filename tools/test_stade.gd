extends SceneTree
## Vérifie le stade municipal sans affichage : godot --headless --path . -s tools/test_stade.gd
## Smarves déclare son terrain : son club est au registre et dans la pyramide ; le lieu « stade » est au
## manifeste derrière son seuil ; la scène du stade pose les vingt-deux joueurs et joue le match minute par
## minute jusqu'au score de la feuille.

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	var foot: Node = root.get_node("Football")
	var registre: Node = root.get_node("Registre")
	game.saving_enabled = false
	game.welcomed = true
	foot.dossier = ""
	var t5: int = foot.coup_envoi(1, 5) + 3600
	foot.regler_horloge(func(): return t5)
	foot.actualiser()

	var smarves: Commune = Commune.smarves()
	check(smarves.valide() and smarves.structures().size() == 1 and smarves.structures()[0].type == "terrain_foot", "Smarves déclare son terrain de football")
	var e: Dictionary = registre.structure("smarves/stade")
	check(not e.is_empty() and e.installee and e.champs.club == "L'Étoile de Smarves", "le stade municipal est au registre, installé")
	check(foot.clubs.has("smarves") and foot.clubs.smarves.nom == "L'Étoile de Smarves" and foot.clubs.smarves.court == "ESM", "l'Étoile de Smarves est dans la pyramide : %s" % str(foot.place_de("smarves")))
	check(foot.en_attente().is_empty() and foot.clubs.size() == 8, "huit clubs, dont l'Étoile et sept invités")
	var lieu: Dictionary = {}
	for p in smarves.lieux():
		if p.id == "stade":
			lieu = p
	check(not lieu.is_empty() and lieu.seuil == 3000 and smarves.interieur("stade") == "res://scenes/stade.tscn", "le stade est un lieu du manifeste, derrière son seuil")
	check(Lines.RUMORS.has("stade"), "les habitants en parlent")

	# La scène du stade, le match de la journée 5.
	game.won = 3000
	change_scene_to_file("res://scenes/stade.tscn")
	await create_timer(1.5).timeout
	var stade: Node = current_scene
	check(stade != null and stade.get_script().resource_path.ends_with("stade.gd"), "la scène du stade se charge")
	check(stade._rencontre.j == 5 and stade._rencontre.joue and ("smarves" in [stade._rencontre.dom, stade._rencontre.ext]), "on joue le match de l'Étoile à la journée 5 : %s" % str(stade._rencontre))
	check(stade._acteurs.size() == 22, "vingt-deux joueurs sur la pelouse : %d" % stade._acteurs.size())
	check(stade._supporters.size() > 10, "la tribune a ses supporters")
	var sorties: Array = stade.find_children("*", "Area3D", true, false).filter(func(a): return a.get_meta("interact", "") == "exit")
	check(sorties.size() == 1 and str(sorties[0].get_meta("prompt")).contains("route du Bois"), "on ressort sur la route du Bois")
	# À 16 h, une heure après le coup d'envoi, le match est à la mi-temps (45 minutes jouées, le quart d'heure court).
	check(stade._etat.pause == "mi-temps" and stade._etat.minute >= 45 and stade._etat.periode == 1, "une heure après le coup d'envoi, c'est la mi-temps : %d'" % stade._etat.minute)
	check(stade._horloge.text.begins_with("Journée 5"), "le tableau d'affichage suit le match : %s" % stade._horloge.text)
	# Les scènes d'une minute : une occasion se joue en plusieurs temps, le ballon et son porteur bougent.
	var n_scenes := 0
	for k in 30:
		if stade._etat.fini:
			break
		stade._minute()
		if stade._etat.evenements[-1].type in ["but", "arret", "rate", "poteau"]:
			n_scenes = stade._scenes.size()
			break
	check(n_scenes >= 2, "une occasion donne plusieurs scènes : %d" % n_scenes)
	if n_scenes >= 2:
		var premiere: Dictionary = stade._scenes[0]
		stade._jouer_scenes(0.1)
		check(stade._cible_ballon == premiere.ballon and (premiere.porteur == null or stade._cibles[premiere.porteur].distance_to(premiere.ballon) < 1.0), "la première scène lance le ballon et son porteur")
		stade._jouer_scenes(premiere.duree + 0.1)
		check(stade._scenes.size() == n_scenes - 1 and stade._scenes[0].lancee, "au bout de sa durée, la scène suivante prend le relais")
		stade._scenes.clear()

	# Le match avancé d'un coup : le score du stade est celui de la feuille.
	var n := 0
	while not stade._etat.fini and n < 200:
		stade._minute()
		n += 1
	var officiel: Array = foot.resultat(stade._rencontre.s, stade._rencontre.j, stade._rencontre.dom, stade._rencontre.ext)
	check(stade._etat.fini and stade._etat.score == officiel, "le match du stade finit sur le score officiel : %s" % str(stade._etat.score))
	check(stade._score.text.contains("%d - %d" % [officiel[0], officiel[1]]), "le tableau d'affichage le dit : %s" % stade._score.text)
	for id in stade._acteurs:
		check(stade._acteurs[id].position.length() < 60.0, "le joueur %s reste dans le stade" % id) if stade._acteurs[id].position.length() >= 60.0 else null

	# Le président Chauvin et sa causerie : les consignes de l'Étoile pour la journée 6.
	var presidents: Array = stade.find_children("*", "Area3D", true, false).filter(func(a): return a.get_meta("interact", "") == "president")
	check(presidents.size() == 1 and str(presidents[0].get_meta("prompt")).contains("Chauvin"), "le président Chauvin est au bord de la pelouse")
	stade.open_causerie()
	await process_frame
	var causerie: PanelContainer = stade._causerie
	check(causerie != null and causerie.club == "smarves" and causerie.rencontre.j == 6, "la causerie parle du prochain match de l'Étoile : %s" % str(causerie.rencontre))
	check(causerie.find_child("Choix_formation_4-3-3", true, false) != null and causerie.find_child("Choix_pressing_haut", true, false) != null, "formations, mentalités et pressings au choix")
	check(foot.consigne_de(1, 6, "smarves").etat == "aucune", "pas encore de consigne")
	causerie._choix = {"formation": "3-5-2", "mentalite": "offensive", "pressing": "haut"}
	check(causerie.donner(), "le président prend la consigne")
	var cd: Dictionary = foot.consigne_de(1, 6, "smarves")
	check(cd.etat == "locale" and cd.consigne == {"formation": "3-5-2", "mentalite": "offensive", "pressing": "haut"}, "elle est posée, locale sans compte : %s" % str(cd))
	check(causerie._ligne_etat.text.contains("cet appareil"), "la fenêtre dit qu'elle reste sur cet appareil : %s" % causerie._ligne_etat.text)
	var direct: Dictionary = foot.rencontre_en_direct(1, 6, foot.prochain_match("smarves").dom, foot.prochain_match("smarves").ext)
	var mienne: Dictionary = direct.etat.equipes[0] if direct.etat.equipes[0].club == "smarves" else direct.etat.equipes[1]
	check(mienne.formation == "3-5-2" and mienne.mentalite == "offensive", "le match de dimanche se jouera avec : %s, %s" % [mienne.formation, mienne.mentalite])
	causerie.closed.emit()
	await process_frame
	check(stade._causerie == null, "Échap referme la causerie")
	foot.decisions = {}
	foot.locales = {}

	# Quatre heures après le coup d'envoi : le match est fini, le tableau garde le score, la feuille se lit.
	var t4: int = foot.coup_envoi(1, 5) + 4 * 3600
	foot.regler_horloge(func(): return t4)
	change_scene_to_file("res://scenes/stade.tscn")
	await create_timer(1.5).timeout
	stade = current_scene
	check(stade._etat.is_empty() and not stade._resultat.is_empty() and stade._resultat.fini, "après le match, l'Étoile s'entraîne et le résultat est gardé")
	check(stade._score.text.contains("%d - %d" % [officiel[0], officiel[1]]) and stade._horloge.text.contains("terminé"), "le tableau d'affichage garde le score : %s" % stade._score.text)
	check(stade._affiche.text.contains("Prochain coup d'envoi"), "et annonce le prochain coup d'envoi : %s" % stade._affiche.text)
	stade.open_feuille()
	await process_frame
	check(stade._causerie != null and stade._causerie.find_child("Recit", true, false) != null, "E devant le tableau ouvre la feuille du match")
	stade._causerie.closed.emit()
	await process_frame
	# Dix minutes après le coup d'envoi : on arrive en cours de match, à la dixième minute.
	var t10: int = foot.coup_envoi(1, 5) + 600
	foot.regler_horloge(func(): return t10)
	change_scene_to_file("res://scenes/stade.tscn")
	await create_timer(1.5).timeout
	stade = current_scene
	check(not stade._etat.is_empty() and stade._etat.minute == 11 and not stade._etat.fini, "dix minutes après le coup d'envoi, le match en est à la %d' en direct" % stade._etat.minute)

	# Avant la première journée : l'entraînement.
	var t0: int = foot.coup_envoi(1, 1) - 86400
	foot.regler_horloge(func(): return t0)
	change_scene_to_file("res://scenes/stade.tscn")
	await create_timer(1.5).timeout
	stade = current_scene
	check(not stade._rencontre.joue and stade._etat.is_empty() and stade._horloge.text == "Entraînement", "avant la saison, l'Étoile s'entraîne")
	check(stade._affiche.text.contains("dimanche 25 octobre"), "le tableau donne le premier coup d'envoi : %s" % stade._affiche.text)

	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
