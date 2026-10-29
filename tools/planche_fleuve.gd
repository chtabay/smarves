extends SceneTree
## Les planches des fleuves (fleuves@1) et l'ambiance qu'on compose avec eux, sous le soleil d'été :
## godot --path . -s tools/planche_fleuve.gd -- --vue=rhone --capture=planche.png
##   --vue=modules     les huit modules, côte à côte (--nom=ponton : un seul, de près)
##   --vue=rhone       le Rhône large : une grève de galets au premier plan, le ponton et sa barque, l'île, la digue
##                     et la lône sur l'autre rive (--nom=bas : à hauteur d'homme sur la grève)
## Sans carte graphique : xvfb-run avec --rendering-driver opengl3.

const FLEUVES := "fleuves@1"
const NIVEAU := -1.4

var monde: Node3D


func _init() -> void:
	await process_frame
	var vue := "rhone"
	var capture := "user://planche_fleuve.png"
	var nom := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--vue="):
			vue = a.trim_prefix("--vue=")
		elif a.begins_with("--capture="):
			capture = a.trim_prefix("--capture=")
		elif a.begins_with("--nom="):
			nom = a.trim_prefix("--nom=")
	root.size = Vector2i(1920, 1080)
	monde = Node3D.new()
	root.add_child(monde)
	_ciel()
	var cam := Camera3D.new()
	cam.fov = 50
	cam.far = 2000
	monde.add_child(cam)
	match vue:
		"modules":
			_sol(Vector2(400, 300), Color("4c5a4e"), Vector3(0, -4.6, 0))
			if nom != "":
				var y := NIVEAU if nom == "barque" else 0.0
				var b := _pose(nom, Vector3(0, y, 0), 1, {"longueur": 20.0} if nom != "ile" else {})
				var e: Vector2 = b.get_meta("emprise")
				var r := maxf(e.x, e.y)
				cam.look_at_from_position(Vector3(r * 0.5, r * 0.4, r * 0.9), Vector3(0, 0, 0))
			else:
				var x := -80.0
				for n in ["fleuve", "berge_galets", "berge_roseaux", "digue", "lone"]:
					_pose(n, Vector3(x, 0, 0), 1, {"largeur": 24.0} if n == "fleuve" else {})
					_etiquette(Vector3(x, 0.5, 24.0), n)
					x += 32.0
				_pose("fleuve", Vector3(-20, 0, 60), 2, {"largeur": 30.0, "longueur": 60.0})
				_pose("ile", Vector3(-30, 0, 60), 1, {})
				_pose("ponton", Vector3(-5, 0, 40), 1, {})
				_pose("barque", Vector3(5, NIVEAU, 60), 2, {})
				_etiquette(Vector3(-30, 0.5, 72.0), "ile")
				_etiquette(Vector3(-5, 0.5, 36.0), "ponton")
				_etiquette(Vector3(5, 0.5, 66.0), "barque")
				cam.look_at_from_position(Vector3(-20, 60, 110), Vector3(-20, -2, 20))
		"rhone":
			_rhone()
			if nom == "bas":
				cam.fov = 60
				cam.look_at_from_position(Vector3(-16, 1.2, -56), Vector3(14, -0.5, -10))
			else:
				cam.fov = 55
				cam.look_at_from_position(Vector3(-30, 16, -80), Vector3(10, -2, 0))
	for _k in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture)
	print("Planche %s : %s" % [vue, capture])
	quit(0)


## Le Rhône large de 100 m : la grève de galets et le ponton sur la rive proche, l'île au milieu, la digue et
## l'entrée d'une lône sur la rive d'en face.
func _rhone() -> void:
	var w := 100.0
	var decal := w * 0.5 + 10.0 - 8.0
	for i in 8:
		var x := -70.0 + i * 20.0
		_pose("fleuve", Vector3(x, 0, 0), i + 1, {"largeur": w})
		_pose("berge_galets" if i % 3 != 2 else "berge_roseaux", Vector3(x, 0, -decal), i + 11, {})
		_pose("digue" if i < 5 else "berge_roseaux", Vector3(x, 0, decal), i + 21, {}, PI)
		# l'arrière des rives : un pré
		_sol(Vector2(20, 80), Color("8dbb4c"), Vector3(x, -0.02, -decal - 50))
		_sol(Vector2(20, 80), Color("8dbb4c"), Vector3(x, -0.02, decal + 50))
	for i in 3:
		_pose("lone", Vector3(30.0 + i * 20.0, 0, decal + 22.0), i + 31, {})
	_pose("ile", Vector3(20, 0, 8), 4, {"largeur": 40.0})
	_pose("ponton", Vector3(-8, 0, -decal - 4.6), 5, {})
	_pose("barque", Vector3(10, NIVEAU, -20), 6, {}, 0.6)


func _pose(module: String, p: Vector3, g: int, opt: Dictionary, lacet := 0.0) -> Node3D:
	var b: Node3D = load(Bibliotheque.scene(FLEUVES, "decor")).instantiate()
	b.module = module
	b.graine = g
	b.options = opt
	b.position = p
	b.rotation.y = lacet
	monde.add_child(b)
	return b


func _ciel() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_SKY
	var ciel := ProceduralSkyMaterial.new()
	ciel.sky_top_color = Color("#4f9fe0")
	ciel.sky_horizon_color = Color("#d6e8f0")
	ciel.ground_horizon_color = Color("#d6e8f0")
	ciel.ground_bottom_color = Color("#8c8a78")
	env.environment.sky = Sky.new()
	env.environment.sky.sky_material = ciel
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#b8c8d8")
	env.environment.ambient_light_energy = 0.3
	env.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.ssao_enabled = true
	monde.add_child(env)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-46, -38, 0)
	soleil.light_color = Color("#fff0d4")
	soleil.light_energy = 0.62
	soleil.shadow_enabled = true
	soleil.directional_shadow_max_distance = 250.0
	monde.add_child(soleil)


func _sol(taille: Vector2, couleur: Color, centre := Vector3.ZERO) -> void:
	var sol := MeshInstance3D.new()
	var plan := PlaneMesh.new()
	plan.size = taille
	sol.mesh = plan
	var m := StandardMaterial3D.new()
	m.albedo_color = couleur
	m.roughness = 1.0
	sol.material_override = m
	sol.position = centre
	monde.add_child(sol)


func _etiquette(p: Vector3, texte: String) -> void:
	var l := Label3D.new()
	l.text = texte.replace("_", " ")
	l.font_size = 96
	l.pixel_size = 0.03
	l.modulate = Color("#2a2a2a")
	l.rotation_degrees = Vector3(-55, 0, 0)
	l.no_depth_test = true
	l.position = p
	monde.add_child(l)
