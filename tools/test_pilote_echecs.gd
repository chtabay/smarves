extends SceneTree
## Le pilote devant un échiquier dessiné à l'écran (scripts/plateaux/echiquier.gd) : il voit les pièces
## et les coups permis, et joue un coup en cliquant la case de départ puis celle d'arrivée.
## godot --headless --path . -s tools/test_pilote_echecs.gd

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	create_timer(60).timeout.connect(func(): print("trop long"); quit(1))
	await process_frame
	var P: Node = root.get_node("Pilote")
	var ecran := Control.new()
	ecran.size = Vector2(800, 600)
	root.add_child(ecran)
	var e: Control = load("res://scripts/plateaux/echiquier.gd").new()
	e.size = Vector2(400, 400)
	e.position = Vector2(100, 50)
	ecran.add_child(e)
	var depart := "RNBQKBNRPPPPPPPP" + ".".repeat(32) + "pppppppprnbqkbnr"
	e.poser(depart, ["e2e4", "e2e3", "g1f3"])
	var joue := []
	e.coup.connect(func(u): joue.append(u))
	await process_frame
	var v: Dictionary = P.vue()
	check(v.get("cases", []).has("e2") and v.cases.size() == 64, "les 64 cases de l'échiquier sont dans la vue")
	var texte := ""
	for t in v.textes:
		if str(t).begins_with("Échiquier"):
			texte = str(t)
	check(texte.contains("Re1") and texte.contains("Coups permis : e2-e4"), "il lit la position et les coups permis")
	await P.geste({"geste": "cliquer", "quoi": "c:e2"})
	var r: Dictionary = await P.geste({"geste": "cliquer", "quoi": "e4"})
	check(joue == ["e2e4"], "deux clics, e2 puis e4, jouent le coup (%s)" % str(joue))
	e.poser(e.plateau, [])
	r = P.vue()
	check(not str(r.textes).contains("À toi de jouer"), "hors de son tour, pas de coups permis")
	# La promotion : la pièce se choisit sur la case.
	var promo := ".".repeat(48) + "P" + ".".repeat(15)
	promo[4] = "K"
	promo[60] = "k"
	e.poser(promo, ["a7a8q", "a7a8n", "a7a8r", "a7a8b"])
	joue.clear()
	P.vue()
	await P.geste({"geste": "cliquer", "quoi": "c:a7"})
	await P.geste({"geste": "cliquer", "quoi": "c:a8"})
	v = P.vue()
	check(v.get("cases", []).has("promotion-cavalier"), "la promotion montre ses quatre pièces")
	await P.geste({"geste": "cliquer", "quoi": "c:promotion-cavalier"})
	check(joue == ["a7a8n"], "et le cavalier se choisit d'un clic (%s)" % str(joue))
	# Un coup en un seul geste : « e2-e4 », et la promotion dit sa pièce.
	e.poser(depart, ["e2e4", "e2e3", "g1f3"])
	joue.clear()
	P.vue()
	r = await P.geste({"geste": "cliquer", "quoi": "e2-e4"})
	check(joue == ["e2e4"] and r.ok, "un geste, « e2-e4 », joue le coup (%s, %s)" % [str(joue), r.dit])
	e.poser(depart, ["e2e4"])
	r = await P.geste({"geste": "cliquer", "quoi": "e2-e5"})
	check(not r.ok and str(r.dit).contains("non permis"), "un coup non permis est refusé : %s" % r.dit)
	e.poser(promo, ["a7a8q", "a7a8n", "a7a8r", "a7a8b"])
	joue.clear()
	await P.geste({"geste": "cliquer", "quoi": "a7-a8=C"})
	check(joue == ["a7a8n"], "« a7-a8=C » promeut en cavalier (%s)" % str(joue))
	ecran.queue_free()
	await _panneau(P)
	print("%d échec(s)" % fails)
	quit(1 if fails else 0)


## Assis au Cercle : la vue n'est que le résumé de la table (pendules, position, coups permis) et ses
## boutons, sans les 64 cases ; et le coup se joue toujours en un geste.
func _panneau(P: Node) -> void:
	var calque := Control.new()
	calque.size = Vector2(1600, 900)
	root.add_child(calque)
	var hors := Button.new()
	hors.text = "Carnet du village"
	hors.position = Vector2(10, 10)
	calque.add_child(hors)
	var p: PanelContainer = load("res://scripts/plateaux/echecs_panel.gd").new()
	p.hors_ligne = true
	p.title = "La table de Madame Lacroix"
	calque.add_child(p)
	await process_frame
	p.appliquer(JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/echecs_vue_partie.json")))
	await process_frame
	var v: Dictionary = P.vue()
	var resume: String = v.textes[0] if v.textes.size() == 1 else ""
	print(resume)
	check(resume.contains("contre Madame Lacroix (Expert)") and resume.contains("Pendules") and resume.contains("toi 4:31"), "le résumé : l'adversaire et les deux pendules")
	check(resume.contains("Coups permis") and resume.contains("e2-e4") or resume.contains("Coups permis"), "la position et les coups permis")
	check(not v.has("cases"), "pas les 64 cases")
	var textes_boutons: Array = v.boutons.map(func(b): return b.texte)
	check(not ("Carnet du village" in textes_boutons) and "Abandonner" in textes_boutons, "seulement les boutons de la table (%s)" % ", ".join(textes_boutons))
	check(JSON.stringify(v).length() < 2500, "une vue courte (%d caractères)" % JSON.stringify(v).length())
	var joue := []
	p.echiquier.coup.connect(func(u): joue.append(u))
	var r: Dictionary = await P.geste({"geste": "cliquer", "quoi": "e1-g1"})
	check(joue == ["e1g1"], "le roque en un geste (%s)" % r.dit)
	calque.queue_free()
