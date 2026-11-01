extends SceneTree
## Le taxi qui passe sur la grand-rue de Smarves (Main.moving_cars[0]), arrêté pour la photo sur la placette
## de la rue du Clain (la grand-rue est trop étroite pour y reculer), à la lumière du jeu :
## xvfb-run godot --path . --rendering-driver opengl3 -s tools/capture_taxi.gd -- --sortie=dossier/
## Six vues à la même lumière que le jeu ; l'interface est masquée. --livree=jaune : dans la livrée jaune.

const VUES := {
	"1-trois-quarts-avant": [Vector3(1.6, 1.0, 2.4), Vector3(0.0, 0.3, 0.2)],
	"2-flanc": [Vector3(2.2, 0.55, 0.0), Vector3(0.0, 0.33, 0.0), 46.0],
	"3-trois-quarts-arriere": [Vector3(-1.6, 1.0, -2.4), Vector3(0.0, 0.3, -0.2)],
	"4-a-hauteur-d-homme": [Vector3(2.3, 1.6, 3.5), Vector3(0.0, 0.35, 0.0)],
	"5-vue-de-dessus": [Vector3(0.0, 4.68, 5.2), Vector3(0.0, 0.0, 0.0), 34.0],
	"6-face": [Vector3(0.35, 0.6, 2.8), Vector3(0.0, 0.32, 0.6)],
}


func _init() -> void:
	var sortie := "user://"
	var livree := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.trim_prefix("--sortie=")
		elif a.begins_with("--livree="):
			livree = a.trim_prefix("--livree=")
	await process_frame
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	game.welcomed = true
	root.size = Vector2i(1600, 900)
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(2.0).timeout
	var main: Node = current_scene
	var cars: Array = main.get("moving_cars")
	var car: Node3D = cars[0]
	cars.remove_at(0)
	car.position = Vector3(-50.5, car.position.y + 0.06, 11.0)
	car.rotation.y = 0.0
	# --livree=jaune : la même berline, rebâtie dans une autre livrée (Taxi.LIVREES).
	if livree != "":
		var caisse: Node3D = car.find_child("Taxi", true, false)
		for k in caisse.get_children():
			k.free()
		Taxi.batir(caisse, "Smarves", Polices.texte(), livree)
	for c in root.find_children("*", "CanvasLayer", true, false):
		(c as CanvasLayer).visible = false
	var cam := Camera3D.new()
	cam.near = 0.05
	root.add_child(cam)
	await process_frame
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
		var f := sortie.path_join("%s.png" % nom)
		root.get_texture().get_image().save_png(f)
		print("Taxi : ", f)
	quit(0)
