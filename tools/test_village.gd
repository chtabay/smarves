extends SceneTree
## Vérifie les rues du village sans affichage : godot --headless --path . -s tools/test_village.gd
## Chaque emplacement est posé, chaque porte de vendeur mène à sa scène, le retour replace l'habitant
## devant la bonne porte, le véhicule se gare et les panneaux « Propriété » suivent les biens.

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	var biens: Node = root.get_node("Biens")
	game.saving_enabled = false
	game.welcomed = true
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(1.0).timeout
	var main: Node = current_scene
	var village: Node = main.get_node_or_null("Village")
	check(village != null, "le nœud Village est dans la scène principale")
	for id in ["notaire", "couture", "poste", "boucherie", "coiffure", "pizzeria", "epicerie", "fleurs", "bibliotheque", "lot_reserve", "brocante", "chambre_cafe", "maison_place", "garage", "pharmacie", "lot_bois", "ecole", "stade"]:
		check(village.lots.has(id) and village.lots[id].has("area"), "emplacement %s posé avec son entrée" % id)
	# La route est libre de bout en bout : du moulin au bois, en passant par la place.
	await physics_frame
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var probe := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.35
	probe.shape = ball
	var blocked := []
	var x := -80.0
	while x <= 80.0:
		# Au rond-point, on passe à côté du vieux chêne.
		var z: float = 6.4 if absf(x - village.BOIS.ROND_X) > 2.0 else 6.4 + village.BOIS.DRIVE_R
		probe.transform = Transform3D(Basis(), Vector3(x, 0.6, z))
		for hit in space.intersect_shape(probe, 4):
			if not (hit.collider is Area3D):
				blocked.append(snappedf(x, 0.5))
				break
		x += 0.5
	check(blocked.is_empty(), "la route est libre du moulin au bois %s" % ("" if blocked.is_empty() else str(blocked.slice(0, 8))))
	for id in village.SELLER_DOORS:
		if village.lots.has(id):
			check(ResourceLoader.exists(biens.SELLERS[id].scene), "la porte %s mène à %s" % [id, biens.SELLERS[id].scene])
	# Le véhicule garé et le panneau « Propriété ».
	biens.owned["maison_place"] = 1
	for it in biens.CATALOGUE:
		if it.kind == "vehicule" and it.model != "":
			biens.owned[it.id] = 1
			biens.driven = it.id
			break
	biens.changed.emit()
	await process_frame
	check(village._vehicle != null and village._vehicle.is_inside_tree(), "le véhicule conduit est garé sur la place")
	check(village._property_signs["maison_place"].visible, "le panneau Propriété paraît sur la maison de maître")
	# Entrer chez Maître Garnier, puis revenir devant sa porte.
	village.enter_seller("notaire")
	await create_timer(1.0).timeout
	check(current_scene.scene_file_path == biens.SELLERS.notaire.scene, "E à la porte de l'étude ouvre l'étude")
	game.return_point = "notaire"
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(1.0).timeout
	var door: Vector3 = current_scene.get_node("Village").lots.notaire.door
	var p: Vector3 = current_scene.player.global_position
	check(Vector2(p.x, p.z).distance_to(Vector2(door.x, door.z)) < 1.5, "au retour, l'habitant est devant l'étude (%.1f, %.1f)" % [p.x, p.z])
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
