extends SceneTree
## Captures de la fiche « Mon pensionnaire » du carnet, avec une fiche d'essai (rien ne part au serveur) :
## godot --path . -s tools/capture_pensionnaire.gd -- --capture-agenda --compte-essai=a_jour --pensionnaire-essai[=inscrit] --sortie=<fichier.png> [--base=600]
## (sans « =inscrit », le renvoi vers Lasso où il se crée ; avec, un pensionnaire qui a déjà joué.)

func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var sortie := "/tmp/pensionnaire.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sortie="):
			sortie = arg.trim_prefix("--sortie=")
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(3.0).timeout
	var carnet: Node = root.get_node("Carnet")
	carnet.toggle()
	carnet.call("_show_sheet", true, "pensionnaire")
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(sortie)
	quit()
