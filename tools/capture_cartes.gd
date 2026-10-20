extends SceneTree
## Captures du classeur de cartes du carnet (onglet « Mes cartes »), sur la place, avec quelques biens,
## des obligations de l'Étoile tenues par vous et par deux autres joueurs, et le club de basket :
## godot --path . -s tools/capture_cartes.gd -- --sortie=<dossier/> [--base=600]
## (village.png, etablissements.png, clubs.png, zoom-club.png, zoom-part.png ; --base=600 imite un
## téléphone, comme Tactile.)

func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var sortie := "/tmp/cartes/"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sortie="):
			sortie = arg.trim_prefix("--sortie=")
	DirAccess.make_dir_recursive_absolute(sortie)
	var foot: Node = root.get_node("Football")
	DirAccess.make_dir_recursive_absolute("user://capture_cartes/")
	foot.dossier = "user://capture_cartes/"
	foot.effacer()
	var t := Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 10, "day": 18, "hour": 20, "minute": 0, "second": 0})
	foot.regler_horloge(func(): return t)
	foot.actualiser()
	var game: Node = root.get_node("Game")
	var biens: Node = root.get_node("Biens")
	game.saving_enabled = false
	game.won = 12000
	game.credits = 400000
	for id in ["smarvoise", "smarvoise", "smarvoise", "cotes", "fournil", "casino", "chambre", "maison", "adr_clain_5",
			"adr_boucherie", "dimanche", "trois_pieces", "mobylette", "deux_cv", "lampe_salon", "fauteuil_club"]:
		biens.buy(id)
	biens.wear("trois_pieces")
	biens.wear("deux_cv")
	if not biens.trouvailles.has("premier_jeton"):
		biens.trouvailles.append("premier_jeton")
	game.credits = 6400
	foot.forcer_porteurs("vous:3+6,Lucien:9+1,Mathilde:5", "smarves")
	var basket: Node = root.get_node("Basket")
	if basket.clubs.has("smarves"):
		basket.bureau.obligations = [{"club": "smarves", "rang": 4, "par": "vous", "moi": true},
			{"club": "smarves", "rang": 8, "par": "Lucien", "moi": false}]
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(3.0).timeout
	var carnet: Node = root.get_node("Carnet")
	carnet.toggle()
	carnet.ouvrir_onglet("cartes")
	var album: Node = carnet.get("_album")
	await _photo(sortie + "village.png")
	var defile: ScrollContainer = album.get("_defile")
	defile.scroll_vertical = 560
	await _photo(sortie + "etablissements.png")
	defile.scroll_vertical = 100000
	await _photo(sortie + "clubs.png")
	var n: int = album.get("_affichees").size()
	album.montrer(n - 4)
	await _photo(sortie + "zoom-club.png")
	album.fermer_zoom()
	var i: int = album.get("_affichees").map(func(c): return c.id).find("part:smarvoise:4")
	album.montrer(i)
	await _photo(sortie + "zoom-part.png")
	album.fermer_zoom()
	foot.effacer()
	quit()


func _photo(chemin: String) -> void:
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(chemin)
