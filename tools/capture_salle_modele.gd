extends SceneTree
## Capture de la salle de basket de Smarves sur un décor de la bibliothèque (ou de la commune), pour vérifier
## une brique de salle : godot --path . -s tools/capture_salle_modele.gd -- --modele=salle-de-quartier@1
## --capture=sortie.png [--at=x,z,lacet,tangage[,y]] [--match]
## La scène de la salle prend la capture elle-même (salle_basket.gd, _maybe_capture).


func _init() -> void:
	await process_frame
	var modele := "salle-de-quartier@1"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--modele="):
			modele = arg.trim_prefix("--modele=")
	root.get_node("Game").welcomed = true
	root.get_node("Game").saving_enabled = false
	root.get_node("Registre").structure("smarves/gymnase").champs.modele = modele
	load("res://scripts/village/salle_basket.gd").prochaine_commune = "smarves"
	change_scene_to_file("res://scenes/salle_basket.tscn")
