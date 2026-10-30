extends SceneTree
## Les planches du matériel de course cycliste (course-cycliste@1) et l'arrivée d'étape qu'on compose avec lui :
## godot --path . -s tools/planche_course.gd -- --vue=arrivee --capture=planche.png
##   --vue=materiel    les onze objets, côte à côte (--nom=velo : un seul, de près)
##   --vue=arrivee     l'arrivée dans la grand-rue d'un bourg du Bugey : la flamme rouge au loin, les barrières, la
##                     banderole et les fanions, l'arche au-dessus de la ligne, le podium et l'estrade du speaker
##                     (--nom=bas : à hauteur d'homme derrière les barrières)
## Sans carte graphique : xvfb-run avec --rendering-driver opengl3.

const COURSE := "course-cycliste@1"
const FACADIER := "facadier-du-bugey@1"

var monde: Node3D


func _init() -> void:
	await process_frame
	var vue := "arrivee"
	var capture := "user://planche_course.png"
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
	cam.far = 1500
	monde.add_child(cam)
	match vue:
		"materiel":
			_sol(Vector2(300, 200), Color("bfae8a"))
			if nom != "":
				var b := _objet(nom, Vector3.ZERO, 1, {})
				var e: Vector2 = b.get_meta("emprise")
				var r := maxf(maxf(e.x, e.y), 1.6)
				cam.look_at_from_position(Vector3(r * 0.6, r * 0.45 + 0.5, r * 1.1), Vector3(0, r * 0.25, 0))
			else:
				var places := [["arche", Vector3(-22, 0, -8)], ["flamme_rouge", Vector3(-8, 0, -8)], ["banderole", Vector3(6, 0, -8)], ["fanions", Vector3(20, 0, -8)],
					["ligne", Vector3(-22, 0, 4)], ["barrieres", Vector3(-8, 0, 4)], ["podium", Vector3(4, 0, 4)], ["estrade", Vector3(13, 0, 4)],
					["velo", Vector3(-16, 0, 13)], ["ratelier", Vector3(-6, 0, 13)], ["panneau_km", Vector3(4, 0, 13)]]
				for pl in places:
					var opt := {"largeur": 10.0} if pl[0] in ["arche", "flamme_rouge", "banderole", "fanions", "ligne", "barrieres"] else {}
					_objet(pl[0], pl[1], 2, opt)
					_etiquette(pl[1] + Vector3(0, 0.3, 2.6), pl[0])
				cam.look_at_from_position(Vector3(0, 26, 44), Vector3(0, 1.5, 2))
		"banderole":
			# la banderole du Grand Prix : le texte d'office, taille_texte à 0,55 m, puis « ajuste »
			_sol(Vector2(300, 200), Color("bfae8a"))
			_objet("banderole", Vector3(-11, 0, 0), 2, {"largeur": 9.5, "texte": "GRAND PRIX DE LA LOUVE"})
			_objet("banderole", Vector3(0, 0, 0), 2, {"largeur": 9.5, "texte": "GRAND PRIX DE LA LOUVE", "taille_texte": 0.55})
			_objet("banderole", Vector3(11, 0, 0), 2, {"largeur": 9.5, "texte": "GRAND PRIX DE LA LOUVE", "taille_texte": "ajuste"})
			cam.look_at_from_position(Vector3(0, 3.5, 22), Vector3(0, 4.2, 0))
		"arrivee":
			_arrivee()
			if nom == "bas":
				cam.fov = 58
				cam.look_at_from_position(Vector3(3.6, 1.6, 11), Vector3(-1.5, 2.8, -8))
			else:
				cam.fov = 55
				cam.look_at_from_position(Vector3(1.5, 13, 30), Vector3(-0.5, 2, -10))
	for _k in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture)
	print("Planche %s : %s" % [vue, capture])
	quit(0)


## La grand-rue large de 10 m, file vers −Z ; les coureurs arrivent de −Z vers +Z, la ligne en z = 0.
func _arrivee() -> void:
	_sol(Vector2(400, 400), Color("9ea464"), Vector3(0, -0.02, -60))
	_sol(Vector2(10, 220), Color("55565a"), Vector3(0, -0.01, -60))
	for cote in [-1.0, 1.0]:
		_sol(Vector2(3, 220), Color("cdbf9e"), Vector3(cote * 6.5, 0.0, -60))
		var x: float = cote * 8.0
		var types := ["r2", "r1", "village", "bourgeoise", "r2", "redents", "r1", "r2"]
		var z := 12.0
		var i := 0
		while z > -120.0:
			var m: Node3D = load(Bibliotheque.scene(FACADIER, "decor")).instantiate()
			m.type = types[(i + (3 if cote > 0 else 0)) % types.size()]
			m.graine = i * 7 + (11 if cote > 0 else 3)
			m.rotation.y = -cote * PI * 0.5
			monde.add_child(m)
			var w: float = m.get_meta("w")
			m.position = Vector3(x, 0, z - w * 0.5)
			z -= w
			i += 1
	_objet("ligne", Vector3(0, 0, 0), 1, {"largeur": 10.0})
	_objet("arche", Vector3(0, 0, 0.4), 1, {"largeur": 11.0, "couleur": "f2c600"})
	_objet("banderole", Vector3(0, 0, -30), 2, {"largeur": 10.6, "texte": "BELLEY — ARRIVÉE D'ÉTAPE", "couleur": "1f4fa0"})
	_objet("fanions", Vector3(0, 0, -18), 3, {"largeur": 10.6})
	_objet("fanions", Vector3(0, 0, -45), 4, {"largeur": 10.6})
	_objet("flamme_rouge", Vector3(0, 0, -90), 1, {"largeur": 10.6})
	_objet("panneau_km", Vector3(5.6, 0, -60), 1, {"texte": "500 M"})
	for cote in [-1.0, 1.0]:
		for k in 6:
			var b := _objet("barrieres", Vector3(cote * 5.15, 0, -6.0 - k * 10.5), k + 1, {"largeur": 10.4, "texte": "CRÉDIT DU BUGEY"})
			b.rotation.y = PI * 0.5
	var p := _objet("podium", Vector3(-6.5, 0, 6.0), 1, {"couleur": "d22a2a", "texte": "GRAND PRIX DE BELLEY"})
	p.rotation.y = PI * 0.5
	var e := _objet("estrade", Vector3(6.6, 0, 6.5), 1, {"couleur": "1f4fa0"})
	e.rotation.y = -PI * 0.5
	var r := _objet("ratelier", Vector3(6.4, 0, -3.0), 2, {"velos": 4})
	r.rotation.y = -PI * 0.5


func _objet(nom: String, p: Vector3, g: int, opt: Dictionary) -> Node3D:
	var b: Node3D = load(Bibliotheque.scene(COURSE, "decor")).instantiate()
	b.objet = nom
	b.graine = g
	b.options = opt
	b.position = p
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
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.ssao_enabled = true
	monde.add_child(env)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-46, -38, 0)
	soleil.light_color = Color("#fff0d4")
	soleil.light_energy = 0.62
	soleil.shadow_enabled = true
	soleil.directional_shadow_max_distance = 200.0
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
	l.pixel_size = 0.012
	l.modulate = Color("#2a2a2a")
	l.rotation_degrees = Vector3(-55, 0, 0)
	l.no_depth_test = true
	l.position = p
	monde.add_child(l)
