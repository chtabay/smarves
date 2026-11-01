extends SceneTree
## La planche des taxis de la bibliothèque (taxis@1) : les deux livrées côte à côte, sur un pavé gris, sous la lune.
## Elle sert d'aperçu à la brique :
## xvfb-run godot --path . --rendering-driver opengl3 -s tools/planche_taxis.gd -- --capture=bibliotheque/taxis/1/apercu.png
##   --largeur=2000 --hauteur=800 : la taille de l'image (1920 × 1080 par défaut). L'aperçu en est recadré de
##   (300, 150) à (1700, 710) et ramené à 1000 × 400.

const TAXIS := "taxis@1"

var monde: Node3D


func _init() -> void:
	await process_frame
	var capture := "user://planche_taxis.png"
	var taille := Vector2i(1920, 1080)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			capture = a.trim_prefix("--capture=")
		elif a.begins_with("--largeur="):
			taille.x = int(a.trim_prefix("--largeur="))
		elif a.begins_with("--hauteur="):
			taille.y = int(a.trim_prefix("--hauteur="))
	root.size = taille
	monde = Node3D.new()
	root.add_child(monde)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#1c2236")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#b8c0d8")
	env.environment.ambient_light_energy = 0.45
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	monde.add_child(env)
	var lune := DirectionalLight3D.new()
	lune.rotation_degrees = Vector3(-50, -35, 0)
	lune.light_color = Color("#fff2dc")
	lune.light_energy = 0.9
	lune.shadow_enabled = true
	monde.add_child(lune)
	var sol := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(60, 60)
	sol.mesh = plan
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#6c6a66")
	m.roughness = 0.9
	sol.material_override = m
	monde.add_child(sol)
	var i := 0
	for livree: String in load(Bibliotheque.scene(TAXIS, "decor")).instantiate().call("noms"):
		var t: Node3D = load(Bibliotheque.scene(TAXIS, "decor")).instantiate()
		t.livree = livree
		t.options = {"commune": "Smarves"}
		t.position = Vector3(-2.7 + i * 5.4, 0, 0)
		t.rotation_degrees.y = 60.0 + i * 60.0
		monde.add_child(t)
		i += 1
	var cam := Camera3D.new()
	cam.fov = 38
	monde.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 3.2, 10.5), Vector3(0.0, 0.55, 0))
	for _k in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture)
	print("Planche des taxis : ", capture)
	quit(0)
