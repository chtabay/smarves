extends SceneTree
## Planche de contact : godot --path . -s tools/sheet.gd -- dossier sortie.png [colonnes]
## Aligne tous les modèles d'un dossier avec leur nom, pour choisir les assets.

func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0]
	var out: String = args[1]
	var cols := int(args[2]) if args.size() > 2 else 6
	var files: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".glb") or f.ends_with(".gltf"):
			files.append(dir.path_join(f))
	files.sort()
	var root := Node3D.new()
	get_root().add_child(root)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.2, 0.22, 0.26)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.75)
	env.environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	var cell := 0.0
	var nodes: Array[Node3D] = []
	for f in files:
		var n: Node3D = load(f).instantiate()
		root.add_child(n)
		nodes.append(n)
		var aabb := _aabb(n)
		cell = maxf(cell, maxf(aabb.size.x, aabb.size.z))
	cell *= 1.25
	for i in nodes.size():
		var n := nodes[i]
		n.position = Vector3((i % cols) * cell, 0, (i / cols) * cell)
		var l := Label3D.new()
		l.text = files[i].get_file().get_basename()
		l.pixel_size = cell * 0.0012
		l.font_size = 48
		l.position = n.position + Vector3(0, 0.02, cell * 0.42)
		l.rotation_degrees.x = -60
		l.modulate = Color.WHITE
		root.add_child(l)
	var rows := ceili(nodes.size() / float(cols))
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(cols, rows) * cell * 0.85
	root.add_child(cam)
	var center := Vector3((cols - 1) * cell / 2.0, 0, (rows - 1) * cell / 2.0)
	cam.position = center + Vector3(0, 1, 1).normalized() * cell * 40
	cam.look_at(center)
	cam.far = cell * 200
	for k in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	get_root().get_texture().get_image().save_png(out)
	quit()


func _aabb(n: Node) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
