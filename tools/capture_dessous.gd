extends SceneTree
## Le Dessous en images (scenes/dessous.tscn, scripts/socle/dessous_monde.gd) :
## xvfb-run godot --path . --rendering-driver opengl3 -s tools/capture_dessous.gd -- --sortie=dossier/
## L'arrivée figée à quatre instants (de loin, la descente, l'étoile, la main rendue), puis trois vues libres :
## sous le disque (les éléphants sur la carapace), la Porte des Joints de près, et le monde de nuit.

const PLANS := {"1-de-loin": 1.6, "2-la-descente": 5.2, "3-l-etoile-tombe": 6.4, "4-a-l-arrivee": 9.0}


func _init() -> void:
	var sortie := "user://"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.trim_prefix("--sortie=")
	DirAccess.make_dir_recursive_absolute(sortie)
	await process_frame
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	game.welcomed = true
	root.size = Vector2i(1600, 900)
	change_scene_to_file("res://scenes/dessous.tscn")
	await process_frame
	await process_frame
	var s: Node3D = current_scene
	for nom: String in PLANS:
		s.set("_figee", PLANS[nom])
		await _photo(sortie, nom)
	s.set("_figee", -1.0)
	s.call("_finir_arrivee")
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	var cam := Camera3D.new()
	cam.far = 1500.0
	root.add_child(cam)
	cam.make_current()
	var vues := {
		"5-sous-le-disque": [Vector3(70, -18, 55), Vector3(0, -14, 0), 50.0, 0.0],
		"6-la-porte-des-joints": [Vector3(1.6, 1.4, 1.2), Vector3(0, 1.0, -4.0), 50.0, 0.0],
		"7-de-nuit": [Vector3(-180, 40, 160), Vector3(0, -24, 0), 45.0, 170.0],
	}
	for nom: String in vues:
		var v: Array = vues[nom]
		s.set("_t", v[3])
		cam.fov = v[2]
		cam.look_at_from_position(v[0], v[1])
		await _photo(sortie, nom)
	quit()


func _photo(sortie: String, nom: String) -> void:
	for _k in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	var f := sortie.path_join("%s.png" % nom)
	root.get_texture().get_image().save_png(f)
	print("capture : ", f)
