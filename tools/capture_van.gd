extends SceneTree
## Le van des chasseurs de pépites (scripts/village/pepites.gd) sur la placette de la rue du Clain, en jeu :
## xvfb-run godot --path . --rendering-driver opengl3 -s tools/capture_van.gd -- --sortie=dossier/ [--won=0]
## Six vues à la même lumière que le jeu : trois-quarts avant, flanc, trois-quarts arrière, à hauteur d'homme
## au cran le plus proche de la vue de dessus et de face ; l'interface est masquée. --won=0 montre la camionnette bleue d'avant le seuil.

const VUES := {
	"1-trois-quarts-avant": [Vector3(1.55, 0.95, 2.25), Vector3(0.0, 0.32, 0.25)],
	"2-flanc": [Vector3(2.7, 0.55, 0.0), Vector3(0.0, 0.38, 0.0)],
	"3-trois-quarts-arriere": [Vector3(-1.5, 1.0, -2.3), Vector3(0.0, 0.3, -0.2)],
	"4-a-hauteur-d-homme": [Vector3(2.2, 1.55, 3.4), Vector3(0.0, 0.35, 0.0)],
	# Le cran le plus proche de la vue de dessus du jeu (Village.CAMERA_NOTCHES) : 7 m, 42° de tangage.
	"6-face": [Vector3(0.35, 0.55, 2.6), Vector3(0.0, 0.32, 0.6)],
	"5-vue-de-dessus": [Vector3(0.0, 4.68, 5.2), Vector3(0.0, 0.0, 0.0), 34.0],
}


func _init() -> void:
	var sortie := "user://"
	var won := 5000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.trim_prefix("--sortie=")
		elif a.begins_with("--won="):
			won = int(a.trim_prefix("--won="))
	await process_frame
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	game.welcomed = true
	root.size = Vector2i(1600, 900)
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(2.0).timeout
	game.won = won
	for _k in 30:
		await process_frame
	var van := root.find_child("VanDesPepites", true, false) as Node3D
	var car: Node3D = van.get("van") if van else null
	if car == null:
		push_error("Pas de van sur la placette")
		quit(1)
		return
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	var cam := Camera3D.new()
	cam.fov = 40
	cam.near = 0.05
	root.add_child(cam)
	var at := car.global_position
	var basis := Basis(Vector3.UP, car.global_rotation.y)
	for nom: String in VUES:
		var v: Array = VUES[nom]
		cam.make_current()
		cam.fov = v[2] if v.size() > 2 else 40.0
		cam.look_at_from_position(at + basis * (v[0] as Vector3), at + basis * (v[1] as Vector3))
		for _k in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		var f := sortie.path_join("%s%s.png" % [nom, "" if won >= 2000 else "-avant-le-seuil"])
		root.get_texture().get_image().save_png(f)
		print("Van : ", f)
	quit(0)
