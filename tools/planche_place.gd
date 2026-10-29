extends SceneTree
## Les planches des briques de la place du nord (arbres-de-place@1, mobilier-de-place@1, facadier-des-flandres@1),
## sous un ciel d'été franc, et la place qu'on bâtit avec les trois :
## godot --path . -s tools/planche_place.gd -- --vue=arbres --capture=planche.png
##   --vue=arbres     les cinq espèces sur trois graines, au pied nu, en grille et en bordure
##   --vue=mobilier   chaque objet du mobilier, avec son nom
##   --vue=facadier   les six pignons sur deux graines, en rangée
##   --vue=detail     la même rangée vue en enfilade, pour lire le relief des façades
##   --vue=place      une place entière : façades tout autour, arbres, fontaine, marché, terrasse
##   --vue=rue        la place au ras du pavé, à hauteur d'œil
## Sans carte graphique : xvfb-run avec --rendering-driver opengl3.

const ARBRES := "arbres-de-place@1"
const MOBILIER := "mobilier-de-place@1"
const FACADIER := "facadier-des-flandres@1"

var monde: Node3D


func _init() -> void:
	await process_frame
	var vue := "place"
	var capture := "user://planche_place.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--vue="):
			vue = a.trim_prefix("--vue=")
		elif a.begins_with("--capture="):
			capture = a.trim_prefix("--capture=")
	root.size = Vector2i(1920, 1080)
	monde = Node3D.new()
	root.add_child(monde)
	_ciel()
	var cam := Camera3D.new()
	cam.fov = 45
	cam.far = 1500
	monde.add_child(cam)
	match vue:
		"arbres":
			_sol(Vector2(90, 50), Color("cdb98f"))
			var x := -28.0
			for esp in load(Bibliotheque.scene(ARBRES, "decor")).instantiate().especes():
				for g in 2:
					_arbre(Vector3(x + g * 6.0, 0, 0), esp, g + 1, {"pied": ["bordure", "grille"][g]})
				_etiquette(Vector3(x + 3.0, 0.3, 3.5), esp)
				x += 12.5
			cam.look_at_from_position(Vector3(0, 7, 48), Vector3(0, 4.2, 0))
		"mobilier":
			_sol(Vector2(60, 40), Color("cdb98f"))
			var objets: Array = load(Bibliotheque.scene(MOBILIER, "decor")).instantiate().objets()
			# la fontaine à gauche, les autres en grille de quatre sur trois
			_objet(Vector3(-9.5, 0, 0), objets[0], 1)
			_etiquette(Vector3(-9.5, 0.3, 5.4), objets[0], 0.007)
			for i in range(1, objets.size()):
				var k := i - 1
				var p := Vector3((k % 4) * 4.4 - 1.0, 0, floorf(k / 4.0) * 4.8 - 4.8)
				_objet(p, objets[i], i + 3)
				_etiquette(p + Vector3(0, 0.3, 1.9), objets[i], 0.0045)
			cam.look_at_from_position(Vector3(0.5, 16, 21), Vector3(0.5, 0.4, 0.4))
		"facadier", "detail":
			_sol(Vector2(90, 60), Color("cdb98f"))
			var types: Array = load(Bibliotheque.scene(FACADIER, "decor")).instantiate().types()
			for rang in 2:
				var x := -30.0
				for t in types:
					var m := _maison(Vector3(x, 0, rang * -22.0), 0.0, t, rang * 10 + types.find(t) + 1, {})
					var w: float = m.get_meta("w")
					m.position.x += w * 0.5
					if rang == 0 and vue == "facadier":
						_etiquette(Vector3(x + w * 0.5, 0.05, 2.5), t)
					x += w + 0.4
			if vue == "facadier":
				cam.look_at_from_position(Vector3(-2, 14, 46), Vector3(-2, 8, -8))
			else:
				cam.fov = 50
				cam.look_at_from_position(Vector3(-34, 3.0, 9), Vector3(-14, 7.5, -1))
		"place", "rue":
			_place()
			if vue == "place":
				cam.look_at_from_position(Vector3(0, 21, 34), Vector3(0, 2, -4))
			else:
				cam.fov = 60
				cam.look_at_from_position(Vector3(-3, 1.7, 15), Vector3(2, 4.5, -12))
	for _k in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture)
	print("Planche %s : %s" % [vue, capture])
	quit(0)


func _ciel() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_SKY
	var ciel := ProceduralSkyMaterial.new()
	ciel.sky_top_color = Color("#4f9fe0")
	ciel.sky_horizon_color = Color("#cfe6f2")
	ciel.ground_horizon_color = Color("#cfe6f2")
	ciel.ground_bottom_color = Color("#8c8a78")
	env.environment.sky = Sky.new()
	env.environment.sky.sky_material = ciel
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#b8c8d8")
	env.environment.ambient_light_energy = 0.3
	env.environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment.ssao_enabled = true
	env.environment.ssao_intensity = 1.4
	monde.add_child(env)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-48, -32, 0)
	soleil.light_color = Color("#fff3dc")
	soleil.light_energy = 0.6
	soleil.shadow_enabled = true
	soleil.directional_shadow_max_distance = 160.0
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
	sol.position = centre + Vector3(0, -0.01, 0)
	monde.add_child(sol)


func _etiquette(p: Vector3, texte: String, taille := 0.012) -> void:
	var l := Label3D.new()
	l.text = {"etal": "étal", "jardiniere": "jardinière"}.get(texte, texte)
	l.font_size = 96
	l.pixel_size = taille
	l.modulate = Color("#2a2a2a")
	l.outline_size = 0
	l.rotation_degrees = Vector3(-55, 0, 0)
	l.no_depth_test = true
	l.position = p
	monde.add_child(l)


func _arbre(p: Vector3, esp: String, g: int, opt := {}) -> Node3D:
	var a: Node3D = load(Bibliotheque.scene(ARBRES, "decor")).instantiate()
	a.espece = esp
	a.graine = g
	a.options = opt
	a.position = p
	monde.add_child(a)
	return a


func _objet(p: Vector3, nom: String, g: int, lacet := 0.0, opt := {}) -> Node3D:
	var o: Node3D = load(Bibliotheque.scene(MOBILIER, "decor")).instantiate()
	o.objet = nom
	o.graine = g
	o.options = opt
	o.position = p
	o.rotation.y = lacet
	monde.add_child(o)
	return o


func _maison(p: Vector3, lacet: float, t: String, g: int, opt: Dictionary) -> Node3D:
	var m: Node3D = load(Bibliotheque.scene(FACADIER, "decor")).instantiate()
	m.type = t
	m.graine = g
	m.options = opt
	m.position = p
	m.rotation.y = lacet
	monde.add_child(m)
	return m


## Une rangée de maisons le long d'un côté : de a vers b, façades tournées vers le centre (lacet).
func _rangee(a: Vector3, b: Vector3, lacet: float, graine: int, passage := -1) -> void:
	var types: Array = load(Bibliotheque.scene(FACADIER, "decor")).instantiate().types()
	var dir := (b - a).normalized()
	var long := (b - a).length()
	var fait := 0.0
	var i := 0
	var r := RandomNumberGenerator.new()
	r.seed = graine
	while fait < long - 4.0:
		var w := minf(r.randf_range(6.5, 9.0), long - fait)
		var opt := {"w": w}
		if i == passage:
			opt["rdc"] = "passage"
		var m := _maison(Vector3.ZERO, lacet, types[r.randi() % types.size()], graine * 31 + i, opt)
		var wr: float = m.get_meta("w")
		m.position = a + dir * (fait + wr * 0.5)
		fait += wr
		i += 1


func _place() -> void:
	# le pavé de la place et la chaussée devant les maisons
	_sol(Vector2(46, 40), Color("d9c29a"))
	_sol(Vector2(140, 140), Color("b9a988"), Vector3(0, -0.02, 0))
	# les façades tout autour, tournées vers la place
	_rangee(Vector3(-21, 0, -18), Vector3(21, 0, -18), 0.0, 3, 3)
	_rangee(Vector3(-21, 0, 16), Vector3(-21, 0, -18), PI * 0.5, 5)
	_rangee(Vector3(21, 0, -18), Vector3(21, 0, 16), -PI * 0.5, 7, 1)
	# au centre, la fontaine et sa statue
	_objet(Vector3(0, 0, -3), "fontaine", 1)
	# les arbres, en couronne sur la place et en rangée devant les maisons
	var n := 0
	for p in [Vector3(-13, 0, 6), Vector3(13, 0, 6), Vector3(-15, 0, 12), Vector3(15, 0, 12), Vector3(-10, 0, 14), Vector3(10, 0, 14)]:
		_arbre(p, "tilleul", 20 + n, {"pied": "bordure"})
		n += 1
	for p in [Vector3(-12, 0, -13), Vector3(12, 0, -13), Vector3(0, 0, -14.5)]:
		_arbre(p, "bouleau", 40 + n, {"pied": "grille"})
		n += 1
	for p in [Vector3(-17, 0, -6), Vector3(17, 0, -4)]:
		_arbre(p, "boule", 60 + n, {"pied": "grille"})
		n += 1
	# le mobilier
	_objet(Vector3(-6, 0, 8), "lampadaire", 2)
	_objet(Vector3(6, 0, 8), "lampadaire", 3)
	_objet(Vector3(-7.5, 0, 4), "banc", 4, PI * 0.5)
	_objet(Vector3(7.5, 0, 4), "banc", 5, -PI * 0.5)
	_objet(Vector3(-4, 0, -9), "banc", 6)
	_objet(Vector3(11, 0, -6), "etal", 7, -PI * 0.5)
	_objet(Vector3(10, 0, -10), "caisses", 8, 0.4)
	_objet(Vector3(13.2, 0, -9.5), "tonneaux", 9)
	_objet(Vector3(4.5, 0, 10.5), "charrette", 10, 0.6)
	_objet(Vector3(-15.5, 0, -12.5), "terrasse", 11)
	_objet(Vector3(-12, 0, -16.2), "jardiniere", 12)
	_objet(Vector3(-8, 0, -16.2), "jardiniere", 13)
	_objet(Vector3(-16, 0, 1), "massif", 14, PI * 0.5)
	_objet(Vector3(16, 0, 1), "massif", 15, -PI * 0.5)
	_objet(Vector3(-9, 0, 10), "corbeille", 16)
	_objet(Vector3(8.5, 0, -1), "poteau", 17, -0.5)
	_objet(Vector3(-3.5, 0, -15.5), "pot", 18)
	_objet(Vector3(3.5, 0, -15.5), "pot", 19)
