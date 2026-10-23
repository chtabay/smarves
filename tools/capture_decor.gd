extends SceneTree
## Les vues d'un décor de la bibliothèque, pour le regarder avant de l'accepter ou de l'employer : le décor posé
## sur un sol plat, sous un soleil de fin d'après-midi, vu de trois quarts depuis deux côtés et d'en haut.
## godot --path . -s tools/capture_decor.gd -- --ref=donjon-en-ruine@1 --capture=dossier/
##   --scene=res://…/x.tscn   un décor proposé par une commune, avant son entrée dans la bibliothèque
##   --nom=donjon              le début du nom des images (par défaut l'id de la brique ou de la scène)
## Écrit <nom>-1.png (sud-ouest), <nom>-2.png (nord-est) et <nom>-3.png (de haut). Sans carte graphique :
## xvfb-run avec --rendering-driver opengl3.

const VUES := [[-0.62, 0.32, 0.72], [0.7, 0.28, -0.65], [0.25, 0.92, 0.32]]


func _init() -> void:
	await process_frame
	var ref := ""
	var scene := ""
	var dossier := "user://"
	var nom := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ref="):
			ref = a.trim_prefix("--ref=")
		elif a.begins_with("--scene="):
			scene = a.trim_prefix("--scene=")
		elif a.begins_with("--capture="):
			dossier = a.trim_prefix("--capture=")
		elif a.begins_with("--nom="):
			nom = a.trim_prefix("--nom=")
	if scene == "" and ref != "":
		scene = Bibliotheque.scene(ref, "decor")
	if scene == "" or not ResourceLoader.exists(scene):
		printerr("Pas de décor pour « %s »" % (ref if ref != "" else scene))
		quit(1)
		return
	if nom == "":
		nom = ref.get_slice("@", 0) if ref != "" else scene.get_file().get_basename()
	if not dossier.ends_with("/"):
		dossier += "/"
	DirAccess.make_dir_recursive_absolute(dossier)
	root.size = Vector2i(1600, 1000)
	var monde := Node3D.new()
	root.add_child(monde)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_SKY
	var ciel := ProceduralSkyMaterial.new()
	ciel.sky_top_color = Color("#5f86b0")
	ciel.sky_horizon_color = Color("#e9c99a")
	ciel.ground_horizon_color = Color("#b9a98c")
	ciel.ground_bottom_color = Color("#6d6553")
	env.environment.sky = Sky.new()
	env.environment.sky.sky_material = ciel
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.environment.ambient_light_energy = 0.45
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	monde.add_child(env)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-34, -38, 0)
	soleil.light_color = Color("#ffe2b8")
	soleil.light_energy = 1.0
	soleil.shadow_enabled = true
	soleil.directional_shadow_max_distance = 400.0
	monde.add_child(soleil)
	var decor: Node3D = load(scene).instantiate()
	monde.add_child(decor)
	await process_frame
	var boite := AABB()
	var premiere := true
	for m in decor.find_children("*", "VisualInstance3D", true, false):
		if m is GeometryInstance3D:
			var b: AABB = m.global_transform * m.get_aabb()
			boite = b if premiere else boite.merge(b)
			premiere = false
	var sol := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(1, 1) * maxf(boite.size.x, boite.size.z) * 4.0
	sol.mesh = plan
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#7d7560")
	m.roughness = 1.0
	sol.material_override = m
	sol.position = Vector3(boite.get_center().x, -0.03, boite.get_center().z)
	monde.add_child(sol)
	var cam := Camera3D.new()
	cam.fov = 40
	cam.far = 2000
	monde.add_child(cam)
	var centre := boite.get_center()
	var rayon := boite.size.length() * 0.5
	var d := rayon / tan(deg_to_rad(cam.fov * 0.5)) * 1.05
	for i in VUES.size():
		var v: Vector3 = Vector3(VUES[i][0], VUES[i][1], VUES[i][2]).normalized()
		cam.look_at_from_position(centre + v * d, centre, Vector3.UP if absf(v.y) < 0.95 else Vector3.FORWARD)
		for _k in 20:
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(dossier + "%s-%d.png" % [nom, i + 1])
	print("Vues de %s : %s%s-1..%d.png (boîte %s)" % [scene, dossier, nom, VUES.size(), str(boite.size)])
	quit(0)
