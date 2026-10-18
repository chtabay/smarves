extends SceneTree
## Vérifie le tableau du dimanche sans affichage : godot --headless --path . -s tools/test_foot_tableau.gd
## La fenêtre se remplit depuis une pyramide fondée sur place (sans toucher au fichier du joueur), avant
## la première journée puis en pleine saison ; elle suit la Division 1 tant que Smarves n'a pas de club,
## et dit à Smarves qu'il lui manque un terrain ; les dates sont en français.

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var foot: Node = root.get_node("Football")
	foot.dossier = ""
	# La veille du premier coup d'envoi.
	var t0: int = foot.coup_envoi(1, 1) - 86400
	foot.regler_horloge(func(): return t0)
	foot.actualiser()
	check(not foot.niveaux.is_empty(), "la pyramide se fonde pour la fenêtre")
	check(FootTableau.date(foot.coup_envoi(1, 1)) == "dimanche 25 octobre", "la date s'écrit en français : %s" % FootTableau.date(foot.coup_envoi(1, 1)))
	check(FootTableau.date(foot.coup_envoi(1, 1) + 8 * 86400) == "lundi 2 novembre", "le lundi suivant aussi")

	var fenetre := FootTableau.new()
	root.add_child(fenetre)
	await process_frame
	var textes := _textes(fenetre)
	check(fenetre.division == [0, 0], "sans club à Smarves, la fenêtre suit la Division 1 : %s" % str(fenetre.division))
	check("Division 1" in textes and "Pas encore de match cette saison" in textes, "avant la première journée : le classement vierge et l'annonce")
	check("Journée 1, à venir" in textes, "la prochaine journée est affichée")
	check(textes.has("Coup d'envoi : dimanche 25 octobre, à 15 h."), "le coup d'envoi est au tableau : %s" % textes.filter(func(x): return x.begins_with("Coup")))
	check(textes.any(func(x): return x.begins_with("Smarves n'a pas encore de club")), "Smarves sait qu'il lui manque un terrain")
	check(textes.any(func(x): return x.contains("8 clubs en une division")), "la pyramide se résume")
	var fermes := [0]
	fenetre.closed.connect(func(): fermes[0] += 1)
	for c in fenetre.find_children("*", "Button", true, false):
		c.pressed.emit()
	check(fermes[0] == 1, "le bouton repose la craie")
	fenetre.free()

	# Au milieu de la saison : la journée 5 vient de se jouer.
	var t5: int = foot.coup_envoi(1, 5) + 3600
	foot.regler_horloge(func(): return t5)
	fenetre = FootTableau.new()
	root.add_child(fenetre)
	await process_frame
	textes = _textes(fenetre)
	check("Journée 5, dimanche dernier" in textes and "Journée 6, à venir" in textes, "en saison : la dernière journée et la prochaine")
	check(textes.any(func(x): return x.contains("journée 5 sur 14")), "la période dit où l'on en est")
	var scores := textes.filter(func(x): return x.length() <= 5 and x.contains(" - "))
	check(scores.size() == 4, "quatre scores pour la journée jouée : %s" % str(scores))
	var classement: Array = foot.classement(1, 0, 0)
	check(textes.has(str(classement[0].pts)) and classement[0].j == 5, "le classement compte cinq journées")
	fenetre.free()

	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


func _textes(n: Node) -> Array:
	var out: Array = []
	for l in n.find_children("*", "Label", true, false):
		out.append(l.text)
	return out
