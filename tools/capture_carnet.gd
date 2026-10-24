extends SceneTree
## Captures du carnet à onglets, le dimanche 18 octobre 2026 à 20 h, sur la place, avec quelques biens,
## une dette, un ticket au comptoir et une commune d'essai qui tient ses compteurs :
## godot --path . -s tools/capture_carnet.gd -- --capture-agenda --sortie=<dossier/> [--base=600]
## (une image par page : biens.png, cartes.png, carriere.png, villages.png (neuf villages au carnet, puis
## villages_filtre.png, la liste filtrée), smarves.png, essai.png, vienne.png ; --capture-agenda tient la
## bienvenue fermée ; --base=600 imite un téléphone, comme Tactile.)

func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var sortie := "/tmp/carnet/"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sortie="):
			sortie = arg.trim_prefix("--sortie=")
	DirAccess.make_dir_recursive_absolute(sortie)
	var foot: Node = root.get_node("Football")
	DirAccess.make_dir_recursive_absolute("user://capture_carnet/")
	foot.dossier = "user://capture_carnet/"
	foot.effacer()
	var t := Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 10, "day": 18, "hour": 20, "minute": 0, "second": 0})
	foot.regler_horloge(func(): return t)
	foot.actualiser()
	var game: Node = root.get_node("Game")
	var biens: Node = root.get_node("Biens")
	game.saving_enabled = false
	game.credits = 6400
	game.won = 9800
	game.staked = 21500
	biens.buy("smarvoise")
	biens.buy("smarvoise")
	biens.buy("chambre")
	game.debts = {"smarves": 1850}
	var paris: Node = root.get_node("Paris")
	paris.dossier = "user://capture_carnet/"
	paris.tickets = [{"s": 1, "j": 1, "n": 0, "g": 0, "choix": {"a|b": "1", "c|d": "N"}, "mise": 50, "cote": 5.12, "etat": "ouvert", "gain": 0, "quand": t}]
	# Une commune d'essai, passée hier, qui a noté ses compteurs.
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/commune_essai/commune.json"))
	m.nom = "Ligugé"
	m.carnet = [
		{"id": "parts_moulin", "libelle": "Parts du moulin de Ligugé", "genre": "nombre", "rubrique": "Mes affaires"},
		{"id": "caisse", "libelle": "Laissé à la caisse du café", "genre": "credits", "rubrique": "Mes affaires"},
		{"id": "carte_peche", "libelle": "Carte de pêche au Clain", "genre": "case", "rubrique": "Au village"},
		{"id": "surnom", "libelle": "Au club de pétanque", "genre": "texte", "rubrique": "Au village"},
	]
	var c := Commune.depuis_texte(JSON.stringify(m), "user://communes/essai/commune.json", "user://essai.pck")
	root.get_node("Communes").inscrire(c)
	game.carnet = {"essai": {"nom": "Ligugé", "compteurs": m.carnet, "vu": t - 86400 - 3 * 3600,
		"valeurs": {"parts_moulin": 3, "caisse": 420, "carte_peche": true, "surnom": "le pointeur du dimanche"}}}
	# Sept autres villages visités, désinstallés depuis : la liste en compte neuf.
	var autres := ["Vouneuil-sous-Biard", "Iteuil", "Fontaine-le-Comte", "Croutelle", "Nouaillé-Maupertuis", "Mignaloux-Beauvoir", "Saint-Benoît"]
	for i in autres.size():
		game.carnet["v%d" % i] = {"nom": autres[i], "compteurs": [{"id": "fete", "libelle": "La fête du village", "genre": "case"}, {"id": "mise", "libelle": "Misé ici", "genre": "credits"}],
			"vu": t - (i + 2) * 86400, "valeurs": {"fete": i % 2 == 0, "mise": 100 * (i + 1)}}
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(3.0).timeout
	var carnet: Node = root.get_node("Carnet")
	carnet.toggle()
	for onglet in ["biens", "cartes", "carriere", "villages", "smarves", "essai", "vienne"]:
		carnet.ouvrir_onglet(onglet)
		await create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(sortie + onglet + ".png")
		if onglet == "villages":
			var champ: LineEdit = carnet.get("_left").find_child("Recherche", true, false)
			champ.text = "vou"
			champ.text_changed.emit("vou")
			await create_timer(0.5).timeout
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(sortie + "villages_filtre.png")
			carnet.set("_recherche", "")
	foot.effacer()
	paris.tickets = []
	quit()
