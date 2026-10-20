extends SceneTree
## Mesure ce que la salle de basket coûte au rendu : godot --path . -s tools/mesure_salle_basket.gd [-- --at=x,z,lacet]
## Compte les nœuds, les maillages, les matériaux et maillages distincts, les lumières (et leurs ombres), les
## textes 3D et les figurants ; avec un affichage, donne aussi les appels de dessin et les images par seconde.

func _compter(n: Node, c: Dictionary) -> void:
	c.noeuds += 1
	if n is MeshInstance3D:
		c.maillages += 1
		var mi := n as MeshInstance3D
		c.mats[mi.material_override] = true
		c.meshes[mi.mesh] = true
		if mi.mesh and mi.is_visible_in_tree():
			var tris := mi.mesh.get_faces().size() / 3
			c.tris += tris
			var cle := mi.mesh.get_class()
			c.par_genre[cle] = c.par_genre.get(cle, 0) + tris
	elif n is MultiMeshInstance3D:
		c.multi += 1
		var mm := (n as MultiMeshInstance3D).multimesh
		if mm and mm.mesh:
			var tris := mm.mesh.get_faces().size() / 3 * mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.mesh.get_faces().size() / 3 * mm.instance_count
			c.tris += tris
			c.par_genre["foule"] = tris
	if n is Light3D:
		c.lumieres += 1
		if (n as Light3D).shadow_enabled:
			c.ombres += 1
	if n is Label3D:
		c.textes += 1
	if n is CollisionShape3D:
		c.collisions += 1
	if n is Skeleton3D:
		c.squelettes += 1
	for k in n.get_children():
		_compter(k, c)


func _init() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	game.welcomed = true
	var t0 := Time.get_ticks_msec()
	var scene := "res://scenes/salle_basket.tscn"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			scene = a.trim_prefix("--scene=")
	change_scene_to_file(scene)
	await process_frame
	await process_frame
	var salle := current_scene
	var t1 := Time.get_ticks_msec()
	var c := {"noeuds": 0, "maillages": 0, "multi": 0, "lumieres": 0, "ombres": 0, "textes": 0, "collisions": 0, "squelettes": 0, "mats": {}, "meshes": {}, "tris": 0, "par_genre": {}}
	_compter(salle, c)
	print("chargement %d ms" % (t1 - t0))
	print("noeuds %d · maillages %d (matériaux distincts %d, maillages distincts %d) · multimaillages %d" % [c.noeuds, c.maillages, c.mats.size(), c.meshes.size(), c.multi])
	print("triangles de la scène %d · par genre %s" % [c.tris, str(c.par_genre)])
	print("lumières %d (dont %d avec ombres) · textes 3D %d · collisions %d · squelettes %d" % [c.lumieres, c.ombres, c.textes, c.collisions, c.squelettes])
	if DisplayServer.get_name() != "headless":
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--at="):
				var v := a.trim_prefix("--at=").split_floats(",")
				salle.player.position = Vector3(v[0], 0, v[1])
				salle.player.rotation.y = deg_to_rad(v[2])
		for i in 20:
			await process_frame
		var debut := Time.get_ticks_usec()
		var images := 30
		for i in images:
			await process_frame
		var duree := (Time.get_ticks_usec() - debut) / 1000000.0
		print("appels de dessin %d · objets %d · primitives %d" % [
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)])
		print("%.1f images/s (logiciel, lavapipe)" % (images / duree))
	quit()
