extends SceneTree
## Captures de l'agenda, le dimanche 18 octobre 2026 à 20 h, sur la place :
## godot --path . -s tools/capture_agenda.gd -- --capture-agenda --sortie=<fichier.png> --ecran=page|semaine [--base=600]
## (--capture-agenda tient la bienvenue fermée ; --base=600 imite un téléphone, comme Tactile.)

func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var sortie := "/tmp/agenda.png"
	var ecran := "semaine"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sortie="):
			sortie = arg.trim_prefix("--sortie=")
		elif arg.begins_with("--ecran="):
			ecran = arg.trim_prefix("--ecran=")
	var foot: Node = root.get_node("Football")
	DirAccess.make_dir_recursive_absolute("user://capture_agenda/")
	foot.dossier = "user://capture_agenda/"
	foot.effacer()
	var t := Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 10, "day": 18, "hour": 20, "minute": 0, "second": 0})
	foot.regler_horloge(func(): return t)
	foot.actualiser()
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(3.0).timeout
	var carnet: Node = root.get_node("Carnet")
	carnet.toggle()
	if ecran == "semaine":
		carnet.call("_show_sheet", true, "agenda")
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(sortie)
	foot.effacer()
	quit()
