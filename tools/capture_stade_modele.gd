extends SceneTree
## Capture du stade de la commune d'essai sur un décor de la bibliothèque (ou de la commune), pour vérifier
## une brique de stade : godot --path . -s tools/capture_stade_modele.gd -- --modele=stade-de-campagne@1
## --capture=sortie.png [--at=x,z,lacet,tangage] [--journee=n --minute=m] [--attendre=s]
## La scène du stade prend la capture elle-même (stade.gd, _maybe_capture).


func _init() -> void:
	await process_frame
	var modele := "stade-de-campagne@1"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--modele="):
			modele = arg.trim_prefix("--modele=")
	root.get_node("Game").welcomed = true
	root.get_node("Game").saving_enabled = false
	load("res://tools/essai.gd").greffer(root)
	root.get_node("Football").actualiser()
	root.get_node("Registre").structure("essai/stade").champs.modele = modele
	load("res://scripts/village/stade.gd").prochaine_commune = "essai"
	change_scene_to_file("res://scenes/stade.tscn")
