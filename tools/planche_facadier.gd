extends SceneTree
## La planche du façadier du Poitou : ses dix types côte à côte, sur trois graines (une rangée par graine,
## chacune avec sa palette de quartier), pour regarder la brique avant de l'accepter ou de l'employer :
## godot --path . -s tools/planche_facadier.gd -- --ref=facadier-du-poitou@1 --capture=planche.png
##   --scene=res://…/maison.tscn   une maison proposée par une commune, avant son entrée dans la bibliothèque
##   --rang=0                      une seule rangée, vue de plus près (0, 1 ou 2)
## Sans carte graphique : xvfb-run avec --rendering-driver opengl3.

const PAS := 12.5
const RANGS := [[11, "cite"], [205, "basse"], [3071, "quai"]]


func _init() -> void:
	await process_frame
	var ref := "facadier-du-poitou@1"
	var scene := ""
	var capture := "user://planche_facadier.png"
	var seul := -1
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ref="):
			ref = a.trim_prefix("--ref=")
		elif a.begins_with("--scene="):
			scene = a.trim_prefix("--scene=")
		elif a.begins_with("--capture="):
			capture = a.trim_prefix("--capture=")
		elif a.begins_with("--rang="):
			seul = int(a.trim_prefix("--rang="))
	if scene == "":
		scene = Bibliotheque.scene(ref, "decor")
	if scene == "" or not ResourceLoader.exists(scene):
		printerr("Pas de maison pour « %s »" % ref)
		quit(1)
		return
	var paquet: PackedScene = load(scene)
	var types: Array = paquet.instantiate().get_script().types()
	root.size = Vector2i(2400, 1200) if seul < 0 else Vector2i(2400, 900)
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
	soleil.rotation_degrees = Vector3(-32, 28, 0)
	soleil.light_color = Color("#ffe2b8")
	soleil.light_energy = 0.95
	soleil.shadow_enabled = true
	monde.add_child(soleil)
	var sol := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = Vector2(PAS * types.size() + 40, 120)
	sol.mesh = plan
	var m := StandardMaterial3D.new()
	m.albedo_color = Color("#6f6858")
	m.roughness = 1.0
	sol.material_override = m
	sol.position = Vector3(0, -0.02, -20)
	monde.add_child(sol)
	var rangs := RANGS if seul < 0 else [RANGS[clampi(seul, 0, RANGS.size() - 1)]]
	for j in rangs.size():
		for i in types.size():
			var maison: Node3D = paquet.instantiate()
			maison.type = types[i]
			maison.graine = int(rangs[j][0]) + i
			maison.options = {"quartier": rangs[j][1], "lumiere": 0.25}
			maison.position = Vector3((i - (types.size() - 1) / 2.0) * PAS, 0, -j * 16.0)
			monde.add_child(maison)
			if j == 0:
				var l := Label3D.new()
				l.text = types[i]
				l.font_size = 64
				l.outline_size = 14
				l.pixel_size = 0.015
				l.position = maison.position + Vector3(0, 0.9, 5.5)
				monde.add_child(l)
	var cam := Camera3D.new()
	cam.fov = 26 if seul < 0 else 21
	cam.far = 800
	monde.add_child(cam)
	if seul < 0:
		cam.look_at_from_position(Vector3(0, 26, 150), Vector3(0, 6, -14))
	else:
		cam.look_at_from_position(Vector3(0, 12, 132), Vector3(0, 5.5, 0))
	for _i in 40:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture)
	print("Planche du façadier (%s) : %s (%d types)" % [scene, capture, types.size()])
	quit(0)
