extends SceneTree
## La planche d'une brique de matières : chaque matière sur un bloc (dessus et deux faces), avec son nom, pour
## regarder une brique avant de l'accepter ou de l'employer :
## godot --path . -s tools/planche_matieres.gd -- --ref=matieres-de-minuit@1 --capture=planche.png
## Sans carte graphique : xvfb-run avec --rendering-driver opengl3.

const COLONNES := 5
const PAS := 3.2


func _init() -> void:
	await process_frame
	var ref := "matieres-de-minuit@1"
	var capture := "user://planche_matieres.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ref="):
			ref = a.trim_prefix("--ref=")
		elif a.begins_with("--capture="):
			capture = a.trim_prefix("--capture=")
	var noms := Bibliotheque.matieres(ref).keys()
	if noms.is_empty():
		printerr("Pas de matières pour « %s »" % ref)
		quit(1)
		return
	noms.sort()
	root.size = Vector2i(1600, 1000)
	var monde := Node3D.new()
	root.add_child(monde)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("#2a2730")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.6)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	monde.add_child(env)
	var soleil := DirectionalLight3D.new()
	soleil.rotation_degrees = Vector3(-50, 35, 0)
	soleil.light_energy = 1.3
	monde.add_child(soleil)
	var lignes := ceili(noms.size() / float(COLONNES))
	for i in noms.size():
		var bloc := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(2.4, 1.6, 2.4)
		bloc.mesh = b
		bloc.material_override = Bibliotheque.matiere(ref, noms[i])
		bloc.position = Vector3((i % COLONNES - (COLONNES - 1) / 2.0) * PAS, 0.8, (i / COLONNES - (lignes - 1) / 2.0) * PAS)
		monde.add_child(bloc)
		var l := Label3D.new()
		l.text = str(Bibliotheque.matieres(ref)[noms[i]].get("nom", noms[i]))
		l.font_size = 40
		l.outline_size = 10
		l.pixel_size = 0.006
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position = bloc.position + Vector3(0, 1.25, 0)
		monde.add_child(l)
	var cam := Camera3D.new()
	cam.fov = 45
	monde.add_child(cam)
	cam.look_at_from_position(Vector3(0, 13, 13.5), Vector3(0, 0, 0.6))
	for _i in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture)
	print("Planche de %s : %s (%d matières)" % [ref, capture, noms.size()])
	quit(0)
