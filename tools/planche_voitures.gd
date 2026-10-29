extends SceneTree
## Les planches des voitures des années 1980 (voitures-des-annees-80@1) :
## godot --path . -s tools/planche_voitures.gd -- --vue=rue --capture=planche.png
##   --vue=garage   les six voitures côte à côte (--nom=suiveuse : une seule, de près)
##   --vue=rue      la grand-rue d'un bourg du Bugey, les voitures garées le long des trottoirs et la suiveuse qui
##                  attend devant la ligne d'arrivée (--nom=bas : à hauteur d'homme sur le trottoir)
## Sans carte graphique : xvfb-run avec --rendering-driver opengl3.

const VOITURES := "voitures-des-annees-80@1"
const COURSE := "course-cycliste@1"
const FACADIER := "facadier-du-bugey@1"

var monde: Node3D


func _init() -> void:
	await process_frame
	var vue := "rue"
	var capture := "user://planche_voitures.png"
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
		"garage":
			_sol(Vector2(300, 200), Color("8f8f8a"))
			if nom != "":
				var v := _voiture(nom, Vector3.ZERO, 1, {"texte": "VÉLO CLUB BELLEY"} if nom == "suiveuse" else {})
				var l: float = v.get_meta("longueur")
				cam.look_at_from_position(Vector3(l * 0.75, l * 0.42, l * 0.85), Vector3(0, 0.8, 0))
			else:
				var i := 0
				var teintes := ["c8102e", "8fb3c9", "6b1d24", "b7ab8f", "efe9dc"]
				for n in ["citadine", "compacte", "berline", "break", "fourgonnette", "suiveuse"]:
					var p := Vector3(-13.75 + i * 5.5, 0, 0)
					var v := _voiture(n, p, i + 2, {"texte": "VÉLO CLUB BELLEY"} if n == "suiveuse" else {"couleur": teintes[i]})
					v.rotation.y = PI * 0.22
					_etiquette(p + Vector3(0, 0.3, 3.4), n)
					i += 1
				cam.fov = 44
				cam.look_at_from_position(Vector3(0, 9, 22), Vector3(0, 0.8, 0.8))
		"rue":
			_rue()
			if nom == "bas":
				cam.fov = 55
				cam.look_at_from_position(Vector3(6.6, 1.65, 9), Vector3(0.5, 1.4, -12))
			else:
				cam.fov = 55
				cam.look_at_from_position(Vector3(1.5, 10, 30), Vector3(-0.5, 1, -6))
	for _k in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture)
	print("Planche %s : %s" % [vue, capture])
	quit(0)


## La grand-rue large de 10 m, file vers −Z, ses deux trottoirs ; les voitures garées le long, la ligne en z = 0.
func _rue() -> void:
	_sol(Vector2(400, 400), Color("9ea464"), Vector3(0, -0.02, -60))
	_sol(Vector2(10, 220), Color("55565a"), Vector3(0, -0.01, -60))
	for cote in [-1.0, 1.0]:
		_sol(Vector2(3, 220), Color("cdbf9e"), Vector3(cote * 6.5, 0.0, -60))
		var x: float = cote * 8.0
		var types := ["r2", "r1", "village", "bourgeoise", "r2", "redents", "r1", "r2"]
		var z := 26.0
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
	# les voitures garées le long des trottoirs, l'avant dans le sens de la circulation
	var garees := ["berline", "citadine", "break", "fourgonnette", "compacte", "citadine", "berline", "compacte", "break", "citadine"]
	for cote in [-1.0, 1.0]:
		var z := 22.0 if cote > 0 else 18.0
		var k := 0 if cote > 0 else 5
		while z > -70.0:
			var n: String = garees[k % garees.size()]
			var v := _voiture(n, Vector3.ZERO, k * 3 + (1 if cote > 0 else 2), {})
			var l: float = v.get_meta("longueur")
			v.rotation.y = 0.0 if cote > 0 else PI
			v.position = Vector3(cote * 4.05, 0, z - l * 0.5)
			z -= l + 1.1 + float(k % 3) * 0.6
			if k % 4 == 3:
				z -= 6.0
			k += 1
	# la suiveuse qui attend, phares allumés, à quelques mètres de la ligne ; la ligne et l'arche derrière elle
	_voiture("suiveuse", Vector3(0.6, 0, -8.0), 1, {"texte": "VÉLO CLUB BELLEY", "phares": true}).rotation.y = 0.0
	var ligne: Node3D = load(Bibliotheque.scene(COURSE, "decor")).instantiate()
	ligne.objet = "ligne"
	ligne.options = {"largeur": 10.0}
	monde.add_child(ligne)
	var arche: Node3D = load(Bibliotheque.scene(COURSE, "decor")).instantiate()
	arche.options = {"largeur": 11.0, "couleur": "f2c600"}
	arche.position = Vector3(0, 0, 0.4)
	monde.add_child(arche)


func _voiture(nom: String, p: Vector3, g: int, opt: Dictionary) -> Node3D:
	var v: Node3D = load(Bibliotheque.scene(VOITURES, "decor")).instantiate()
	v.voiture = nom
	v.graine = g
	v.options = opt
	v.position = p
	monde.add_child(v)
	return v


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
	l.pixel_size = 0.008
	l.modulate = Color("#2a2a2a")
	l.rotation_degrees = Vector3(-55, 0, 0)
	l.no_depth_test = true
	l.position = p
	monde.add_child(l)
