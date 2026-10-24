extends SceneTree
## Capture du menu des réglages, ouvert sur la place :
## godot --path . --resolution 1333x600 -s tools/capture_reglages.gd -- --capture-agenda --sortie=<fichier.png> [--tactile --base=600]
## (--capture-agenda tient la bienvenue fermée ; --tactile --base=600 et --resolution 1333x600 imitent un
## téléphone en paysage, 600x1333 en portrait ; --bas fait défiler le menu jusqu'en bas ; --bienvenue, sans
## --capture-agenda, garde la bienvenue à l'écran au lieu des réglages.)

func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var sortie := "/tmp/reglages.png"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--sortie="):
			sortie = arg.trim_prefix("--sortie=")
	root.get_node("Game").saving_enabled = false
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(3.0).timeout
	var reglages: Node = root.get_node("Settings")
	if "--bienvenue" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(sortie)
		quit()
		return
	reglages.toggle()
	await create_timer(0.5).timeout
	if "--bas" in OS.get_cmdline_user_args():
		var defile: ScrollContainer = reglages.get("_defile")
		defile.scroll_vertical = 100000
		await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(sortie)
	quit()
