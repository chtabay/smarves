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
	create_timer(240.0).timeout.connect(func():
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
	r = await P.geste({"geste": "cliquer", "quoi": "z1"})
	check(not r.ok, "on ne clique pas une zone de loin")
	print("%d échec(s)" % fails)
	quit(1 if fails else 0)
