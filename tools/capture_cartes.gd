extends SceneTree
## Captures du classeur de cartes du carnet (onglet « Mes cartes »), sur la place, avec quelques biens,
## des obligations de l'Étoile tenues par vous et par deux autres joueurs, le club de basket, et Casino
## Minuit (le paquet d'essai, greffé comme dans capture_dome_minuit.gd) :
## godot --path . -s tools/capture_cartes.gd -- --sortie=<dossier/> [--base=600]
## (village.png, etablissements.png, minuit.png, zoom-part.png, onglet-smarves.png, onglet-minuit.png,
## club.png ; --base=600 imite un téléphone, comme Tactile.)

const MINUIT := "res://tools/paquet_essai/casino_minuit/"
const TMP := "user://capture_cartes/"

func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var sortie := "/tmp/cartes/"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sortie="):
			sortie = arg.trim_prefix("--sortie=")
	DirAccess.make_dir_recursive_absolute(sortie)
	var foot: Node = root.get_node("Football")
	DirAccess.make_dir_recursive_absolute(TMP)
	var communes: Node = root.get_node("Communes")
	communes.dossier_greffes = TMP
	var pk := PCKPacker.new()
	pk.pck_start(TMP + "casino_minuit.pck")
	_emballer(pk, MINUIT, MINUIT)
	pk.flush()
	print("Casino Minuit : ", communes.charger_pack(TMP + "casino_minuit.pck"))
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
	if not basket.clubs.has("casino_minuit"):
		basket.clubs["casino_minuit"] = {"nom": "Minuit Kings", "court": "MK", "couleurs": ["#1b1035", "#e8b84a"], "commune": "casino_minuit"}
	basket.bureau.obligations = [{"club": "casino_minuit", "rang": 4, "par": "vous", "moi": true},
		{"club": "casino_minuit", "rang": 8, "par": "Lucien", "moi": false}, {"club": "casino_minuit", "rang": 2, "par": "Mathilde", "moi": false}]
	for it in biens.catalogue():
		if str(it.get("commune", "")) == "casino_minuit":
			print("bien de Casino Minuit : ", it.id)
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(3.0).timeout
	var carnet: Node = root.get_node("Carnet")
	carnet.toggle()
	carnet.ouvrir_onglet("cartes")
	var album: Node = carnet.get("_album")
	await _photo(sortie + "village.png")
	var defile: ScrollContainer = album.get("_defile")
	defile.scroll_vertical = 900
	await _photo(sortie + "etablissements.png")
	album.choisir_village("casino_minuit")
	await _photo(sortie + "minuit.png")
	var i: int = album.get("_affichees").map(func(c): return c.id).find("part:smarvoise:4")
	album.montrer(i)
	await _photo(sortie + "zoom-part.png")
	album.fermer_zoom()
	carnet.ouvrir_onglet("smarves")
	await _photo(sortie + "onglet-smarves.png")
	carnet.ouvrir_onglet("casino_minuit")
	await _photo(sortie + "onglet-minuit.png")
	carnet.toggle()
	# À l'entrée du stade : le panneau du club, puis ses cartes.
	var hote := Control.new()
	var calque := CanvasLayer.new()
	calque.layer = 50
	root.add_child(calque)
	calque.add_child(hote)
	hote.set_anchors_preset(Control.PRESET_FULL_RECT)
	album.ouvrir_club(hote, "football", "smarves")
	await _photo(sortie + "club.png")
	foot.effacer()
	quit()


func _photo(chemin: String) -> void:
	await create_timer(0.8).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(chemin)


func _emballer(pk: PCKPacker, dossier: String, racine: String) -> void:
	var d := DirAccess.open(dossier)
	for f in d.get_files():
		if not f.ends_with(".uid"):
			pk.add_file("res://communes/casino_minuit/" + (dossier + f).trim_prefix(racine), dossier + f)
	for sous in d.get_directories():
		_emballer(pk, dossier + sous + "/", racine)
