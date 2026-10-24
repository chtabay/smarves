extends SceneTree
## Capture de la page « Aujourd'hui » du carnet :
## godot --path . --resolution 1600x900 -s tools/capture_aujourdhui.gd -- --sortie=<dossier/>
## Images : aujourdhui.png (on dirige l'Étoile : la décision et la composition attendent), rien.png (tout est
## fait), intersaison.png (on ne dirige plus : ce qu'il manque), pastille.png (le carnet fermé, la pastille),
## message.png (un message ouvert à droite de la boîte).

const TMP := "user://capture_aujourdhui/"
var t := 0


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var sortie := "/tmp/aujourdhui/"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sortie="):
			sortie = arg.trim_prefix("--sortie=")
	DirAccess.make_dir_recursive_absolute(sortie)
	DirAccess.make_dir_recursive_absolute(TMP)
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	game.won = 4000
	var avis: Node = root.get_node("Avis")
	var foot: Node = root.get_node("Football")
	avis.dossier = TMP
	avis.effacer()
	foot.dossier = TMP
	foot.effacer()
	t = foot.coup_envoi(1, 3) + 26 * 3600
	foot.regler_horloge(func(): return t)
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(3.0).timeout
	load("res://tools/essai.gd").greffer(root)
	foot.actualiser()
	foot.forcer_porteurs("vous:3", "smarves")
	avis.verifier()
	avis.publier({"id": "capture/mot", "quand": t - 3 * 3600, "titre": "Un mot du président", "texte": "« Le groupe a besoin de sentir que vous croyez en lui. Dimanche, le stade sera plein. »"})
	avis.set("_file", [])
	var carnet: Node = root.get_node("Carnet")
	carnet._process(0.0)
	await _photo(sortie + "pastille.png")
	carnet.ouvrir_sur("boite")
	await _photo(sortie + "aujourdhui.png")
	# Le message du président, ouvert à droite.
	var lignes: Array = carnet.get("_left").find_children("Message*", "Button", true, false)
	if not lignes.is_empty():
		(lignes[0] as Button).pressed.emit()
		await _photo(sortie + "message.png")
	carnet.toggle()
	var a: Array = avis.liste.filter(func(x): return x.genre == "dilemme")
	if not a.is_empty():
		avis.trancher(a[0], "a")
	var c: Dictionary = (foot.consigne_de(1, 4, "smarves").consigne as Dictionary).duplicate(true)
	c.formation = "4-3-3"
	foot.decider(1, 4, "smarves", c)
	avis.tout_lu()
	carnet.ouvrir_sur("aujourdhui")
	await _photo(sortie + "rien.png")
	carnet.toggle()
	foot.forcer_porteurs("vous:1,Lucien:9", "smarves")
	t = foot.coup_envoi(1, 14) + 5 * 3600
	foot.oublier_effectifs()
	avis.verifier()
	avis.set("_file", [])
	carnet.ouvrir_sur("aujourdhui")
	await _photo(sortie + "intersaison.png")
	avis.effacer()
	foot.effacer()
	quit()


func _photo(chemin: String) -> void:
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(chemin)
