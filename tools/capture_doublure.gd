extends SceneTree
## Captures de la fiche « Ma doublure » du carnet, avec une fiche d'essai (rien ne part au serveur) :
## godot --path . -s tools/capture_doublure.gd -- --capture-agenda --compte-essai=a_jour --doublure-essai[=inscrite] --sortie=<fichier.png> [--base=600]
## (sans « =inscrite », le formulaire d'inscription ; avec, une doublure qui a déjà joué.)

func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var sortie := "/tmp/doublure.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sortie="):
			sortie = arg.trim_prefix("--sortie=")
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(3.0).timeout
	var carnet: Node = root.get_node("Carnet")
	carnet.toggle()
	carnet.call("_show_sheet", true, "doublure")
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(sortie)
	quit()
