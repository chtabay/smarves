extends SceneTree
## Capture de la décision de la semaine au Courrier du carnet (FootDilemmes) :
## godot --path . --resolution 1600x900 -s tools/capture_dilemme.gd -- --sortie=<dossier/>
## Images : decision.png (la décision à trancher, ses deux boutons), suite.png (le match joué, la suite).

const TMP := "user://capture_dilemme/"
var t := 0


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var sortie := "/tmp/dilemme/"
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
	t = foot.coup_envoi(1, 3) + 4 * 3600
	foot.regler_horloge(func(): return t)
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(3.0).timeout
	# Un deuxième club, pour que l'Étoile ait un adversaire : la commune d'essai et son terrain.
	load("res://tools/essai.gd").greffer(root)
	foot.actualiser()
	foot.forcer_porteurs("vous:3", "smarves")
	avis.verifier()
	avis.set("_file", [])
	var carnet: Node = root.get_node("Carnet")
	carnet.ouvrir_sur("courrier")
	await _photo(sortie + "decision.png")
	carnet.toggle()
	var a: Array = avis.liste.filter(func(x): return x.genre == "dilemme")
	if not a.is_empty():
		avis.trancher(a[0], "a")
	t = foot.coup_envoi(1, 4) + 4 * 3600
	foot.oublier_effectifs()
	avis.verifier()
	avis.set("_file", [])
	carnet.ouvrir_sur("courrier")
	await _photo(sortie + "suite.png")
	avis.effacer()
	foot.effacer()
	quit()


func _photo(chemin: String) -> void:
	await create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(chemin)
