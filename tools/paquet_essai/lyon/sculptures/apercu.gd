extends SceneTree
## L'aperçu des sculptures de Sathonay, sans la ville : trois vues de chaque pièce (face, trois quarts,
## profil) sous le soleil de la carte, pour juger le modelé avant de la poser.
##   xvfb-run godot --rendering-driver opengl3 --path . -s tools/paquet_essai/lyon/sculptures/apercu.gd -- <dossier de sortie>

const Sculpture := preload("res://tools/paquet_essai/lyon/sculptures/sculpture.gd")


func _initialize() -> void:
	var sortie: String = OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "user://"
	var racine := Node3D.new()
	root.add_child(racine)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#d9cbb2")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("#c8bda6")
	env.environment.ambient_light_energy = 0.4
	racine.add_child(env)
	var soleil := DirectionalLight3D.new()
	soleil.light_color = Color("#ffe1b0")
	soleil.light_energy = 1.25
	soleil.shadow_enabled = true
	racine.add_child(soleil)
	soleil.look_at_from_position(Vector3.ZERO, Vector3(0.6, -0.55, -0.5))
	var cam := Camera3D.new()
	racine.add_child(cam)
	cam.current = true
	cam.fov = 30.0
	var vues := []
	for nom in ["lion", "blandan"]:
		var mi := MeshInstance3D.new()
		mi.mesh = Sculpture.maillage("res://tools/paquet_essai/lyon/sculptures/%s.bin" % nom)
		mi.material_override = Sculpture.bronze(Color("#4d4a36"), Color("#66705a"))
		racine.add_child(mi)
		var c := Vector3(0, 0.5, 0) if nom == "lion" else Vector3(0, 1.4, 0)
		var d := 4.2 if nom == "lion" else 7.5
		for a in [0.0, 0.7, 1.57]:
			vues.append([mi, c, d, a, nom])
	for v in vues:
		for autre in vues:
			autre[0].visible = autre[0] == v[0]
		cam.look_at_from_position(v[1] + Vector3(sin(v[3]), 0.25, cos(v[3])) * v[2], v[1])
		for i in 3:
			await process_frame
		root.get_viewport().get_texture().get_image().save_png("%s/%s-%d.png" % [sortie, v[4], int(v[3] * 100)])
	quit()
