extends SceneTree
## Capture du choix de l'allure à l'arrivée, sur une partie neuve (scripts/socle/arrivee_panel.gd) :
## godot --path . -s tools/capture_arrivee.gd -- --sortie=<fichier.png> [--visage=4 --tenue=4]

func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var sortie := "/tmp/arrivee.png"
	var visage := 0
	var tenue := 0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sortie="):
			sortie = arg.trim_prefix("--sortie=")
		elif arg.begins_with("--visage="):
			visage = int(arg.trim_prefix("--visage="))
		elif arg.begins_with("--tenue="):
			tenue = int(arg.trim_prefix("--tenue="))
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	game.welcomed = false
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(3.0).timeout
	var panneau: Node = current_scene.find_child("Arrivee", true, false)
	if panneau == null:
		push_error("Le choix de l'arrivée ne s'est pas ouvert.")
		quit(1)
		return
	panneau.choisir_visage(visage)
	panneau.choisir_tenue(tenue)
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(sortie)
	quit()
