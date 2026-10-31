extends SceneTree
## Vérifie le bureau du club sans affichage : godot --headless --path . -s tools/test_bureau.gd
## Chaque page s'ouvre (accueil, effectif, tactique, agenda, championnat, recherche, offres) ; la tactique
## place un joueur, échange deux postes, garde une consigne individuelle et envoie la composition à
## Football.decider ; Échap ferme le bureau.

const TMP := "user://test_bureau/"

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var foot: Node = root.get_node("Football")
	var m: Node = root.get_node("Mercato")
	DirAccess.make_dir_recursive_absolute(TMP)
	foot.dossier = TMP
	m.dossier = TMP
	foot.effacer()
	m.effacer()
	var t: int = foot.coup_envoi(1, 3) + 3 * 86400 + 6 * 3600
	foot.regler_horloge(func(): return t)
	# Le championnat veut deux clubs inscrits : la commune d'essai apporte le second.
	load("res://tools/essai.gd").greffer(root)
	foot.actualiser()
	var club := "smarves"
	foot.forcer_porteurs("vous:2", club)
	load("res://scripts/socle/foot_mercato.gd").demo(m, club)
	foot.renforts = m.renforts
	foot.oublier_effectifs()
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(centre)
	var b: Control = load("res://scripts/socle/bureau.gd").new()
	b.set("club", club)
	centre.add_child(b)
	await process_frame
	check(b.find_child("Nav_tactique", true, false) != null and b.find_child("Nav_offres", true, false) != null, "la barre de gauche montre les pages")
	# Les signaux de Football et du Mercato ne refont pas les boutons de la barre : un clic commencé
	# sur « Offres en cours » ou « Quitter » s'y termine.
	b.call("aller", "recherche")
	await process_frame
	var offres: Node = b.find_child("Nav_offres", true, false)
	var quitter: Node = b.find_child("Quitter", true, false)
	foot.change.emit()
	m.change.emit()
	await process_frame
	await process_frame
	check(is_instance_valid(offres) and offres.is_inside_tree() and b.find_child("Nav_offres", true, false) == offres
		and is_instance_valid(quitter) and quitter.is_inside_tree(), "la barre garde ses boutons quand le marché change")
	(offres as Button).pressed.emit()
	await process_frame
	check(b.get("page") == "offres" and b.find_child("Nav_offres", true, false) == offres, "« Offres en cours » ouvre la page des offres")
	for p in ["accueil", "effectif", "tactique", "agenda", "championnat", "recherche", "offres"]:
		b.call("aller", p)
		await process_frame
		check(b.get("page") == p and (b.get("_corps") as Node).get_child_count() > 0, "la page %s s'ouvre" % p)
	b.call("aller", "effectif")
	await process_frame
	var joueurs: Dictionary = b.call("_joueurs")
	check(joueurs.keys().filter(func(id): return str(id).contains("/m-")).size() == 2, "l'effectif compte les deux joueurs achetés au marché")
	check(b.find_child("Effectif", true, false) is GridContainer, "l'effectif est un tableau")
	b.set("tri_effectif", "note")
	b.call("_dessiner")
	await process_frame
	var em: Node = b.find_child("Mercato", true, false)
	check(em == null, "l'effectif n'emboîte pas le marché")
	b.call("_ouvrir_joueur", str(joueurs.keys().filter(func(id): return str(id).contains("/m-"))[0]))
	await process_frame
	em = b.find_child("Mercato", true, false)
	check(b.get("page") == "recherche" and em != null and em.get("page") == "fiche" and em.get("integre"), "un joueur acheté s'ouvre dans la fiche du marché, emboîtée")

	b.call("aller", "tactique")
	await process_frame
	var compo: Dictionary = b.get("compo")
	check(compo.onze.size() == 11 and compo.banc.size() == 7, "la tactique part de l'équipe type : onze et sept remplaçants")
	check(b.find_child("Terrain", true, false) != null and b.find_child("Case_10", true, false) != null, "le terrain montre les onze postes")
	var a = compo.onze[1]
	var c = compo.onze[2]
	b.call("placer", str(c), 1)
	check(compo.onze[1] == c and compo.onze[2] == a, "placer un titulaire sur un autre poste échange les deux")
	var remplacant: String = str(compo.banc[0])
	var sortant = compo.onze[0]
	b.call("placer", remplacant, 0)
	check(compo.onze[0] == remplacant and compo.banc.has(sortant), "un remplaçant posé sur un poste envoie le titulaire au banc")
	compo.ordres[str(compo.onze[5])] = "offensif"
	compo.mentalite = "offensive" if FootMatch.MENTALITES.has("offensive") else compo.mentalite
	b.call("valider")
	var r: Dictionary = foot.prochain_match(club)
	var d: Dictionary = foot.consigne_de(r.s, r.j, club)
	check(d.etat != "aucune" and d.consigne.mentalite == compo.mentalite, "la composition part au championnat (Football.decider)")
	b.set("compo", {})
	b.call("_dessiner")
	await process_frame
	check((b.get("compo") as Dictionary).mentalite == compo.mentalite, "la tactique relue garde la consigne posée")
	check(b.find_child("Lecture", true, false) == null and not (b.find_child("Mentalite", true, false) as OptionButton).disabled, "qui dirige règle la tactique, sans bandeau")
	# Un autre a mis davantage : la tactique se lit, ne se change plus.
	foot.forcer_porteurs("vous:1,Lucien:5", club)
	b.set("compo", {})
	b.call("aller", "tactique")
	await process_frame
	var lecture: Label = b.find_child("Lecture", true, false)
	check(lecture != null and lecture.text.begins_with("Lecture seule") and lecture.text.contains("Lucien dirige le club"), "sans la direction, un bandeau : lecture seule, et qui dirige")
	check((b.find_child("Mentalite", true, false) as OptionButton).disabled and (b.find_child("Valider", true, false) as Button).disabled and (b.find_child("EquipeType", true, false) as Button).disabled,
		"les listes, l'équipe type et la validation ne répondent plus")
	var avant: Array = ((b.get("compo") as Dictionary).onze as Array).duplicate()
	b.call("_cliquer_case", 0)
	b.call("_cliquer_joueur", str(avant[1]))
	check((b.get("compo") as Dictionary).onze == avant and (b.get("compo") as Dictionary).mentalite == compo.mentalite, "le terrain se regarde sans bouger, la consigne posée reste lisible")
	var tac: Dictionary = load("res://scripts/socle/aujourdhui.gd").tactique(foot, club)
	check(not bool(tac.decide) and tac.qui == "Lucien" and tac.etat != "aucune" and (tac.lignes as Array).size() == 4, "le résumé du carnet : la tactique posée, Lucien la règle, quatre lignes")
	foot.forcer_porteurs("vous:2", club)

	b.set("onglet_championnat", "buteurs")
	b.call("aller", "championnat")
	await process_frame
	check(b.find_child("Onglet_buteurs", true, false) != null, "le championnat a ses onglets")

	var ferme := [false]
	b.connect("closed", func(): ferme[0] = true)
	var ev := InputEventAction.new()
	ev.action = "ui_cancel"
	ev.pressed = true
	root.push_input(ev)
	await process_frame
	check(ferme[0], "Échap ferme le bureau")

	foot.effacer()
	m.effacer()
	print("\n%d échec%s" % [fails, "s" if fails > 1 else ""])
	quit(1 if fails > 0 else 0)
