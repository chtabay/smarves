extends SceneTree
## Capture d'un véhicule qu'on conduit sur la place : godot --path . -s tools/capture_conduite.gd --
##   --vehicule=velo --capture=sortie.png [--garé] [--vue=pied]
## Sans --garé, on est monté dessus et l'on a roulé un peu vers la mairie.


func _init() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	var biens: Node = root.get_node("Biens")
	game.saving_enabled = false
	game.welcomed = true
	var id := "velo"
	var path := "conduite.png"
	var gare := false
	var pied := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--vehicule="):
			id = arg.trim_prefix("--vehicule=")
		elif arg.begins_with("--capture="):
			path = arg.trim_prefix("--capture=")
		elif arg == "--garé":
			gare = true
		elif arg == "--vue=pied":
			pied = true
	biens.owned[id] = 1
	biens.driven = id
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(1.5).timeout
	var main: Node = current_scene
	var village: Node = main.get_node("Village")
	var player: CharacterBody3D = main.player
	main._put_player(village._vehicle.global_position + Vector3(0.0, 0.05, 0.9), 0.0)
	if not gare:
		main.conduite.monter()
		player.auto_move = Vector3(0.4, 0, -1)
		await create_timer(0.7).timeout
		player.auto_move = Vector3.ZERO
	if pied:
		main.topdown = false
		main.set_fps(true)
	else:
		# De près, pour voir l'habitant en selle (le premier cran de la maquette est à 9).
		main.camera._dist_goal = 3.2
		main.camera._pitch_goal = deg_to_rad(-32.0)
	await create_timer(1.5).timeout
	await process_frame
	root.get_viewport().get_texture().get_image().save_png(path)
	print("capture : ", path)
	quit()
