extends SceneTree
## Les remontées du forum Lasso du 31 octobre (fil « Corriger les bugs remontés par les joueurs LLM ») :
## godot --headless --path . -s tools/test_pilote_remontees.gd
## - « aller » vers une pièce par son nom (« Salle des Ambassadeurs ») ;
## - une main de blackjack en cours garde sa mise hors du solde envoyé (mise_engagee) ;
## - une parole de 400 caractères accentués tient dans l'état porté par Presences ;
## - une parole s'entend à 50 m (ENTENDRE), qu'on voie ou non celui qui parle.

var fails := 0
var P: Node


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func zone(v: Dictionary, texte: String) -> String:
	for z in v.get("zones", []):
		if str(z.invite).to_lower().contains(texte):
			return z.id
	return ""


func bouton(v: Dictionary, texte: String) -> String:
	for b in v.get("boutons", []):
		if str(b.texte).to_lower().contains(texte):
			return b.id
	return ""


func attendre_scene(nom: String, s: float) -> bool:
	var fin := Time.get_ticks_msec() + int(s * 1000)
	while Time.get_ticks_msec() < fin:
		await create_timer(0.2).timeout
		if current_scene and current_scene.scene_file_path.get_file().get_basename() == nom and P.joueur() != null:
			return true
	return false


func _init() -> void:
	create_timer(300.0).timeout.connect(func():
		print("ÉCHEC   trop long : l'essai s'arrête")
		quit(1))
	await process_frame
	P = root.get_node("Pilote")
	var G: Node = root.get_node("Game")
	G.saving_enabled = false
	G.credits = 5000
	G.won = 6000
	G.welcomed = true

	# Une parole entière part avec la position (elle ne partait plus au-delà de 256 octets).
	var Pr: Node = root.get_node("Presences")
	var longue := "é".repeat(Pr.PAROLE_LONGUE)
	check(JSON.stringify({"dit": longue, "k": 99999}).to_utf8_buffer().size() <= Pr.ETAT_MAX,
		"une parole de %d caractères accentués tient dans l'état porté" % Pr.PAROLE_LONGUE)

	change_scene_to_file("res://scenes/main.tscn")
	check(await attendre_scene("main", 20.0), "la place se charge")
	await create_timer(1.0).timeout
	# Une parole s'entend à 50 m, même d'un présent qu'on ne voit pas d'ici (a_portee faux).
	var ici: Vector3 = P.joueur().global_position
	for e in [["essai-pres", "Paulette", 40.0], ["essai-loin", "Marcel", 70.0]]:
		Pr.presents[e[0]] = {"nom": e[1], "tenue": "", "noeud": null, "points": [[0.0, ici + Vector3(e[2], 0, 0), 0.0, Vector2.ZERO]],
			"vu": -1000.0, "a_portee": false, "part": -1.0, "etat": {}}
		P._on_etat_change(e[0], {"dit": "Ohé !", "k": 1})
		Pr.presents.erase(e[0])
	var noms: Array = P.entendu.map(func(x): return x.nom)
	check(noms == ["Paulette"], "une parole s'entend à 40 m, pas à 70 m (%s)" % str(noms))
	P.entendu.clear()
	var r: Dictionary = await P.geste({"geste": "aller", "vers": "Salle des Ambassadeurs"})
	check(not r.ok and str(r.dit).contains("inconnue"), "sur la place, pas de Salle des Ambassadeurs : %s" % r.dit)
	await P.geste({"geste": "marcher", "vers": "nord", "metres": 2.0})
	var v: Dictionary = P.vue()
	r = await P.geste({"geste": "aller", "vers": zone(v, "casino")})
	await P.geste({"geste": "touche", "touche": "E"})
	check(await attendre_scene("casino", 30.0), "il entre au casino")
	await create_timer(1.5).timeout

	r = await P.geste({"geste": "aller", "vers": "Salle des Ambassadeurs"})
	check(r.ok and str(r.dit).contains("Ambassadeurs"), "« aller » vers la Salle des Ambassadeurs, par son nom : %s" % r.dit)
	check(P._dans_piece(P.joueur(), P._piece("salle des ambassadeurs")), "il y est")
	r = await P.geste({"geste": "aller", "vers": "la salle des jeux"})
	check(r.ok and str(r.dit).contains("Salle des jeux"), "puis vers la salle des jeux : %s" % r.dit)

	# Le blackjack : une main ouverte garde sa mise à part.
	v = P.vue()
	var bj := zone(v, "blackjack")
	check(bj != "", "le blackjack est dans la vue")
	r = await P.geste({"geste": "aller", "vers": bj})
	r = await P.geste({"geste": "touche", "touche": "E"})
	check(r.vue.assis, "assis au blackjack")
	var panneau: Node = null
	for n in get_nodes_in_group("mises_engagees"):
		if n.is_visible_in_tree():
			panneau = n
	check(panneau != null, "la table est du groupe « mises_engagees »")
	if panneau:
		var ouverte := false
		for essai in 12:
			var avant: int = G.credits
			r = await P.geste({"geste": "cliquer", "quoi": "distribuer"})
			if panneau.in_hand:
				ouverte = true
				check(panneau.mise_engagee() == avant - G.credits and panneau.mise_engagee() > 0,
					"main ouverte : la mise est engagée (%d), pas encore perdue" % panneau.mise_engagee())
				r = await P.geste({"geste": "cliquer", "quoi": "rester"})
				await create_timer(4.0).timeout
				check(not panneau.in_hand and panneau.mise_engagee() == 0, "main jouée : plus rien d'engagé")
				break
			await create_timer(4.0).timeout
		check(ouverte, "une main est restée ouverte pour l'essai")
	print("%d échec(s)" % fails)
	quit(1 if fails else 0)
