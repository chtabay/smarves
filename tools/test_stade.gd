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
	var foot: Node = root.get_node("Football")
	var registre: Node = root.get_node("Registre")
	game.saving_enabled = false
	game.welcomed = true
	foot.dossier = ""
	var t5: int = foot.coup_envoi(1, 5) + 3600
	foot.regler_horloge(func(): return t5)
	# Un deuxième club au championnat : la commune d'essai et son terrain.
	load("res://tools/essai.gd").greffer(root)
	foot.actualiser()

	var smarves: Commune = Commune.smarves()
	check(smarves.valide() and smarves.structures().size() == 1 and smarves.structures()[0].type == "terrain_foot", "Smarves déclare son terrain de football")
	var e: Dictionary = registre.structure("smarves/stade")
	check(not e.is_empty() and e.installee and e.champs.club == "L'Étoile de Smarves", "le stade municipal est au registre, installé")
	check(foot.clubs.has("smarves") and foot.clubs.smarves.nom == "L'Étoile de Smarves" and foot.clubs.smarves.court == "ESM", "l'Étoile de Smarves est dans la pyramide : %s" % str(foot.place_de("smarves")))
	check(foot.en_attente().is_empty() and foot.clubs.size() == 2 and foot.clubs.has("essai"), "deux clubs, l'Étoile et l'Union sportive d'essai : rien de fictif")
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

	# Le président Chauvin et sa causerie : un personnage qui parle du club et renvoie au bureau ; la consigne de la journée 6 se donne au moteur.
	var presidents: Array = stade.find_children("*", "Area3D", true, false).filter(func(a): return a.get_meta("interact", "") == "president")
	check(presidents.size() == 1 and str(presidents[0].get_meta("prompt")).contains("Chauvin"), "le président Chauvin est au bord de la pelouse")
	stade.open_causerie()
	await process_frame
	var causerie: PanelContainer = stade._causerie
	check(causerie != null and causerie.club == "smarves" and causerie.rencontre.j == 6, "la causerie parle du prochain match de l'Étoile : %s" % str(causerie.rencontre))
	var paroles: Array = causerie.paroles()
	check(paroles.size() == 3 and paroles[0].begins_with("« Après 5 journées") and paroles[1].begins_with("« Dimanche dernier") and paroles[2].contains("journée 6"), "le président dit le classement, le dernier match et le prochain : %s" % str(paroles))
	check(causerie.find_child("Bureau", true, false) != null and causerie.find_child("Choix_formation_4-3-3", true, false) == null, "il renvoie au bureau et ne pilote plus rien")
	check(foot.consigne_de(1, 6, "smarves").etat == "aucune", "pas encore de consigne")
	check(foot.decider(1, 6, "smarves", {"formation": "3-5-2", "mentalite": "offensive", "pressing": "haut"}), "la consigne de la journée 6 se donne au moteur (le bureau)")
	var cd: Dictionary = foot.consigne_de(1, 6, "smarves")
	check(cd.etat == "locale" and cd.consigne == {"formation": "3-5-2", "mentalite": "offensive", "pressing": "haut"}, "elle est posée, locale sans compte : %s" % str(cd))
	var direct: Dictionary = foot.rencontre_en_direct(1, 6, foot.prochain_match("smarves").dom, foot.prochain_match("smarves").ext)
	var mienne: Dictionary = direct.etat.equipes[0] if direct.etat.equipes[0].club == "smarves" else direct.etat.equipes[1]
	check(mienne.formation == "3-5-2" and mienne.mentalite == "offensive", "le match de dimanche se jouera avec : %s, %s" % [mienne.formation, mienne.mentalite])
	# Le siège du club : la porte ouvre le bureau, pleine page, d'où l'on gagne le registre des obligations.
	causerie.closed.emit()
	await process_frame
	var sieges: Array = stade.find_children("*", "Area3D", true, false).filter(func(a): return a.get_meta("interact", "") == "locaux")
	check(sieges.size() == 1 and str(sieges[0].get_meta("prompt")).contains("siège"), "le siège du club est au stade")
	stade.open_locaux()
	await process_frame
	var bureau: Control = stade._causerie
	check(bureau != null and bureau.get_script().get_global_name() == "Bureau" and bureau.club == "smarves", "le siège ouvre le bureau du club")
	check(bureau.find_child("Nav_tactique", true, false) != null and bureau.find_child("Nav_championnat", true, false) != null, "le bureau a sa barre de gauche : tactique, championnat")
	check(_textes(bureau).any(func(x): return str(x).contains("journée 6") or str(x).contains("Journée 6")), "le bureau dit le prochain match")
	bureau.obligations.emit()
	await process_frame
	await process_frame
	check(stade._causerie != null and stade._causerie != bureau and stade._causerie.find_child("Prendre_1", true, false) != null, "le registre des obligations s'ouvre depuis le bureau")
	stade._causerie.closed.emit()
	await process_frame
	check(stade._bandeau != null and stade._bandeau_score != null, "le bandeau du direct est en place")
	check(stade._causerie == null, "Échap referme le registre")
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

	# Le stade est une scène du socle : la commune d'essai, greffée, a son terrain ; son stade porte son
	# club, son sigle, ses couleurs et son nom, et la sortie ramène chez elle ; la pyramide, rebâtie sans
	# sauvegarde, lui donne son club tout de suite : on y suit son match et sa causerie.
	var communes: Node = root.get_node("Communes")
	check(communes.commune("essai") != null and load("res://tools/essai.gd").greffer(root) == "essai", "la commune d'essai est greffée avec son terrain")
	foot.actualiser()
	check(foot.clubs.has("essai") and foot.clubs.essai.court == "USE", "l'Union sportive d'essai a son club : %s" % str(foot.place_de("essai")))
	foot.regler_horloge(func(): return t5)
	load("res://scripts/village/stade.gd").prochaine_commune = "essai"
	change_scene_to_file("res://scenes/stade.tscn")
	await create_timer(1.5).timeout
	stade = current_scene
	check(stade.commune == "essai" and stade._club == "essai", "le stade est celui de la commune d'essai, et de son club")
	var enseignes: Array = stade.find_children("*", "Label3D", true, false).map(func(l): return l.text)
	check("UNION SPORTIVE D'ESSAI  ·  STADE D'ESSAI" in enseignes and "STADE D'ESSAI" in enseignes and "Le président" in enseignes, "la tribune, l'arche et le président portent les noms du terrain d'essai : %s" % str(enseignes.slice(0, 6)))
	sorties = stade.find_children("*", "Area3D", true, false).filter(func(a): return a.get_meta("interact", "") == "exit")
	check(sorties.size() == 1 and str(sorties[0].get_meta("prompt")) == "E : sortir du stade" and stade._lot() == "stade", "la sortie ramène à la porte du terrain d'essai")
	presidents = stade.find_children("*", "Area3D", true, false).filter(func(a): return a.get_meta("interact", "") == "president")
	check(presidents.size() == 1 and str(presidents[0].get_meta("prompt")) == "E : parler au président", "on parle au président, sans nom : %s" % str(presidents[0].get_meta("prompt") if presidents.size() == 1 else ""))
	check(stade._rencontre.j == 5 and stade._acteurs.size() == 22 and "essai" in [stade._rencontre.dom, stade._rencontre.ext], "on y regarde le match de l'Union sportive à la journée 5 : %s" % str(stade._rencontre))
	stade.open_causerie()
	await process_frame
	check(stade._causerie != null and stade._causerie.club == "essai", "la causerie du président est celle de l'Union sportive")
	stade._causerie.closed.emit()
	await process_frame
	stade._club = ""
	stade.open_causerie()
	await process_frame
	check(stade._causerie == null, "sans club dans la pyramide, pas de causerie : le président renvoie à la saison prochaine")
	check(stade._enseigne("L'Étoile de Smarves") == "ÉTOILE DE SMARVES" and stade._a("Le président Chauvin") == "au président Chauvin" and stade._a("Mme Rivière") == "à Mme Rivière", "les enseignes et les adresses se forment")

	# Un club seul dans sa division : pas de match, l'Étoile s'entraîne et le tableau dit qu'on attend un deuxième club.
	foot.niveaux = [[["smarves"]]]
	foot.clubs.erase("essai")
	foot.oublier_effectifs()
	load("res://scripts/village/stade.gd").prochaine_commune = "smarves"
	change_scene_to_file("res://scenes/stade.tscn")
	await create_timer(1.5).timeout
	stade = current_scene
	check(stade._rencontre.is_empty() and stade._etat.is_empty() and stade._horloge.text == "Entraînement", "seul au championnat, pas de match : l'entraînement")
	check(stade._affiche.text == "Le championnat attend un deuxième club." and stade._acteurs.size() == 11, "le tableau attend un deuxième club, onze joueurs trottinent : %s" % stade._affiche.text)
	stade.open_causerie()
	await process_frame
	check(stade._causerie != null and stade._causerie.paroles()[0].contains("seuls en Division 1"), "le président le dit aussi : %s" % str(stade._causerie.paroles()))
	stade._causerie.closed.emit()
	await process_frame
	stade.open_feuille()
	check(stade._causerie == null, "pas de feuille à lire")

	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
