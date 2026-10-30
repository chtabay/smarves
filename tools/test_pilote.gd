extends SceneTree
## Le pilote d'un pensionnaire (autoload Pilote) joue comme un joueur, sans réseau :
## godot --headless --path . -s tools/test_pilote.gd [-- --bavard]
## Sur la place, il voit la porte du casino, y marche, appuie sur E ; dedans, il va à la roulette,
## s'assoit, mise sur le rouge par un clic sur le tapis, lance la bille et se relève.

var fails := 0
var bavard := false
var P: Node


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func montrer(titre: String, v: Dictionary) -> void:
	if bavard:
		print("--- %s\n%s" % [titre, JSON.stringify(v, "  ")])


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
	bavard = "--bavard" in OS.get_cmdline_user_args()
	create_timer(400.0).timeout.connect(func():
		print("ÉCHEC   trop long : l'essai s'arrête")
		quit(1))
	await process_frame
	P = root.get_node("Pilote")
	var G: Node = root.get_node("Game")
	G.saving_enabled = false
	G.credits = 1000
	G.won = 0
	G.welcomed = true
	change_scene_to_file("res://scenes/main.tscn")
	check(await attendre_scene("main", 20.0), "la place se charge, avec son habitant")
	await create_timer(1.0).timeout

	var v: Dictionary = P.vue()
	montrer("place", v)
	check(v.lieu == "main" and not v.zones.is_empty(), "sur la place, des zones où appuyer sur E")
	print("choses vues sur la place : ", v.get("objets", []).map(func(o): return "%s (%s m, %s)" % [o.nom, o.metres, o.cote]))
	check(v.has("cap") and v.has("position") and v.autour.has("nord"), "sa position, son cap, et autour de lui vers les points cardinaux")
	var t_vue := Time.get_ticks_msec()
	P.vue()
	check(Time.get_ticks_msec() - t_vue < 400, "la vue se fait vite (%d ms)" % (Time.get_ticks_msec() - t_vue))
	var depart: Vector3 = P.joueur().global_position
	var m: Dictionary = await P.geste({"geste": "marcher", "vers": "nord", "metres": 2.0})
	var fait: Vector3 = P.joueur().global_position - depart
	check(fait.z < -1.0 and absf(fait.x) < 1.0, "marcher vers le nord, deux mètres : %s" % m.dit)
	v = m.vue
	var casino := zone(v, "casino")
	check(casino != "", "la porte du casino est dans la vue")
	var r: Dictionary = await P.geste({"geste": "aller", "vers": casino})
	montrer("devant le casino", r)
	check(r.ok and str(r.vue.devant).to_lower().contains("casino"), "il marche jusqu'à la porte : %s" % r.dit)
	r = await P.geste({"geste": "touche", "touche": "E"})
	check(await attendre_scene("casino", 30.0), "E : il entre au casino")
	await create_timer(1.5).timeout

	v = P.vue()
	montrer("casino", v)
	var roulette := zone(v, "roulette")
	check(roulette != "", "la roulette est dans la vue")
	r = await P.geste({"geste": "aller", "vers": roulette})
	check(r.ok and str(r.vue.devant).to_lower().contains("roulette"), "il va jusqu'à la table : %s" % r.dit)
	r = await P.geste({"geste": "touche", "touche": "E"})
	montrer("assis", r.vue)
	check(r.vue.assis and r.vue.get("cases", []).has("red"), "assis, il voit les cases du tapis")
	check(bouton(r.vue, "lancer") != "", "et le bouton pour lancer la bille")
	var avant: int = G.credits
	r = await P.geste({"geste": "cliquer", "quoi": "c:red"})
	check(G.credits < avant, "un clic sur le rouge pose un jeton (%d -> %d)" % [avant, G.credits])
	var mise: int = avant - G.credits
	r = await P.geste({"geste": "cliquer", "quoi": bouton(r.vue, "lancer")})
	r = await P.geste({"geste": "attendre", "secondes": 9})
	montrer("après le lancer", r.vue)
	var fini := false
	for t in r.vue.textes:
		if str(t).contains("encaissez") or str(t).contains("remercie"):
			fini = true
	check(fini, "la bille tombe, le résultat s'affiche")
	check(G.credits == avant - mise or G.credits == avant + mise, "le solde suit le coup (%d)" % G.credits)
	r = await P.geste({"geste": "touche", "touche": "Échap"})
	if r.vue.assis:
		r = await P.geste({"geste": "cliquer", "quoi": "quitter"})
	check(not r.vue.assis, "il se relève")
	# L'étage : une zone en haut de l'escalier d'honneur, que le chemin rejoint par les marches.
	v = P.vue()
	var haut := ""
	for z in v.zones:
		if str(z.cote).contains("au-dessus"):
			haut = z.id
			break
	check(haut != "", "une zone de l'étage est dans la vue")
	if haut != "":
		var y0: float = P.joueur().global_position.y
		r = await P.geste({"geste": "aller", "vers": haut})
		check(r.ok and P.joueur().global_position.y > y0 + 3.0, "il monte l'escalier jusqu'à elle : %s (%.1f m -> %.1f m)" % [r.dit, y0, P.joueur().global_position.y])
	r = await P.geste({"geste": "dire", "texte": "Bonne soirée à tous !"})
	check(r.ok and root.get_node("Presences").etat_libre.get("dit") == "Bonne soirée à tous !", "dire : la phrase part en bulle avec sa position")
	# L'image dit de quelle caméra elle vient : à pied, puis la caméra de dessus qui le suit.
	var j: CharacterBody3D = P.joueur()
	check(P.image_vue() == "oeil", "à pied : l'image est sa vue (oeil)")
	var cam := Camera3D.new()
	j.add_child(cam)
	j.follow_camera = cam
	check(P.image_vue() == "dessus", "caméra qui le suit : l'image est la vue de dessus")
	j.follow_camera = null
	cam.queue_free()
	var pres: Node = root.get_node("Presences")
	pres.presents["essai-voisin"] = {"nom": "Paulette", "tenue": "", "noeud": null, "points": [], "vu": -1000.0,
		"a_portee": true, "part": -1.0, "etat": {}}
	P._on_etat_change("essai-voisin", {"dit": "Bonjour Frick !", "k": 1})
	r = await P.geste({"geste": "regarder"})
	check(r.get("entendu", []).size() == 1 and r.entendu[0].nom == "Paulette", "il entend ce qu'on a dit près de lui depuis son dernier geste")
	r = await P.geste({"geste": "regarder"})
	check(not r.has("entendu"), "et ne l'entend qu'une fois")
	pres.presents.erase("essai-voisin")
	r = await P.geste({"geste": "cliquer", "quoi": "z1"})
	check(not r.ok, "on ne clique pas une zone de loin")
	# Un champ où l'on écrit (une petite annonce) : il se voit, et le texte s'y tape.
	var calque := CanvasLayer.new()
	root.add_child(calque)
	var champ := LineEdit.new()
	champ.placeholder_text = "Votre annonce"
	champ.position = Vector2(100, 100)
	champ.size = Vector2(300, 40)
	calque.add_child(champ)
	var soumis := [""]
	champ.text_submitted.connect(func(t: String): soumis[0] = t)
	await process_frame
	v = P.vue()
	check(v.get("champs", []).size() == 1 and v.champs[0].invite == "Votre annonce", "un champ à l'écran est dans la vue")
	r = await P.geste({"geste": "ecrire", "quoi": "annonce", "texte": "Cherche partenaire de belote"})
	check(r.ok and champ.text == "Cherche partenaire de belote", "écrire : le texte est dans le champ (%s)" % r.dit)
	r = await P.geste({"geste": "touche", "touche": "Entrée"})
	check(soumis[0] == "Cherche partenaire de belote", "Entrée l'envoie")
	champ.queue_free()
	# Le plan du notaire : chaque adresse se clique par son nom.
	var plan: Control = load("res://scripts/carte_biens.gd").new()
	plan.position = Vector2.ZERO
	plan.size = Vector2(1024, 576)
	calque.add_child(plan)
	await process_frame
	var choisi := [""]
	plan.picked.connect(func(id: String): choisi[0] = id)
	v = P.vue()
	var adresses: Array = plan.pilote_cases().keys()
	check(not adresses.is_empty() and v.get("cases", []).has(adresses[0]), "les adresses du plan sont des cases de la vue : %s" % ", ".join(adresses))
	if not adresses.is_empty():
		r = await P.geste({"geste": "cliquer", "quoi": str(adresses[0])})
		check(choisi[0] != "", "un clic sur « %s » ouvre sa fiche (%s)" % [adresses[0], choisi[0]])
	calque.queue_free()
	print("%d échec(s)" % fails)
	quit(1 if fails else 0)
