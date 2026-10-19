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
	for id in ["notaire", "couture", "poste", "boucherie", "coiffure", "pizzeria", "epicerie", "fleurs", "bibliotheque", "lot_reserve", "brocante", "chambre_cafe", "maison_place", "maison_eglise", "garage", "pharmacie", "lot_bois", "ecole", "stade"]:
		check(village.lots.has(id) and village.lots[id].has("area"), "emplacement %s posé avec son entrée" % id)
	# Chaque maison des rues a sa porte, au nom de son adresse chez le notaire.
	var maisons: Array = load("res://scripts/adresses.gd").rues().filter(func(a): return a.genre == "maison")
	var portes := maisons.filter(func(a): return village.lots.has(a.item) and village.lots[a.item].has("area"))
	check(portes.size() == maisons.size(), "chaque maison des rues a sa porte (%d sur %d)" % [portes.size(), maisons.size()])
	var porte: Variant = village.lots.get("adr_clain_13", {}).get("area")
	check(porte != null and str(porte.get_meta("prompt", "")).contains("13, rue du Clain"), "la porte du 13, rue du Clain dit son adresse")
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
	# Aucune fente entre deux socles : le sol porte l'habitant de part et d'autre de chaque jointure.
	var holes := []
	for j in village.JOINTS_X:
		var jz := -8.0
		while jz <= 8.0:
			for jx in [j[0] - 0.05, (j[0] + j[1]) / 2.0, j[1] + 0.05]:
				if space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(jx, 0.5, jz), Vector3(jx, -3.0, jz))).is_empty():
					holes.append(Vector2(snappedf(jx, 0.05), snappedf(jz, 0.5)))
			jz += 0.5
	for j in village.JOINTS_Z:
		var cx: float = village.CHEMIN.X0
		while cx <= village.CHEMIN.X1:
			for z in [j[0] - 0.05, (j[0] + j[1]) / 2.0, j[1] + 0.05]:
				if space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(cx, 0.5, z), Vector3(cx, -3.0, z))).is_empty():
					holes.append(Vector2(snappedf(cx, 0.5), snappedf(z, 0.05)))
			cx += 0.5
	check(holes.is_empty(), "pas de fente entre les socles %s" % ("" if holes.is_empty() else str(holes.slice(0, 8))))
	# Les quartiers, pour le plan du Carnet.
	var spots := {"place": Vector3(0, 0, 0), "rue_du_clain": Vector3(-30, 0, 6), "route_du_bois": Vector3(30, 0, 6),
		"chemin_passelourdin": Vector3(-2, 0, -30), "moulin": Vector3(-70, 0, 0), "bois": Vector3(70, 0, 0), "rochers": Vector3(0, 0, -70)}
	for id in spots:
		check(village.zone_at(spots[id]) == id, "zone_at reconnaît %s" % id)
	check(village.CACHES.cabane_vigne.zone == village.zone_at(village.CACHES.cabane_vigne.pos), "la cabane de vigne est dans sa zone")
	check(village.current_zone == "place", "l'habitant commence sur la place (%s)" % village.current_zone)
	# Le chemin de Passelourdin : de la place, entre la mairie et l'église, jusqu'aux rochers.
	var route: Array = [Vector2(village.CHEMIN.LANE_X, -3.5)] + village.CHEMIN.PATH + [Vector2(0.0, -64.0), Vector2(-0.5, -65.5), Vector2(-0.5, -67.0)]
	blocked = []
	for i in route.size() - 1:
		var a: Vector2 = route[i]
		var b: Vector2 = route[i + 1]
		var n := int(ceil(a.distance_to(b) / 0.5))
		for k in n + 1:
			var q: Vector2 = a.lerp(b, float(k) / n)
			probe.transform = Transform3D(Basis(), Vector3(q.x, 0.6, q.y))
			for hit in space.intersect_shape(probe, 4):
				if not (hit.collider is Area3D):
					blocked.append(Vector2(snappedf(q.x, 0.5), snappedf(q.y, 0.5)))
					break
	check(blocked.is_empty(), "le chemin est libre de la place aux rochers %s" % ("" if blocked.is_empty() else str(blocked.slice(0, 8))))
	# L'allée entre les rangs mène à la porte de la cabane ; on ne traverse pas un rang.
	blocked = []
	for q in [Vector2(-2.5, -45.0), Vector2(-4.0, -45.0), Vector2(-5.5, -45.0), Vector2(-7.2, -45.0), Vector2(-7.2, -44.6)]:
		probe.transform = Transform3D(Basis(), Vector3(q.x, 0.6, q.y))
		for hit in space.intersect_shape(probe, 4):
			if not (hit.collider is Area3D):
				blocked.append(q)
				break
	check(blocked.is_empty(), "l'allée des vignes mène à la cabane %s" % str(blocked))
	ball.radius = 0.1
	probe.transform = Transform3D(Basis(), Vector3(-7.0, 0.3, -23.45))
	check(not space.intersect_shape(probe, 1).is_empty(), "un rang de vigne arrête l'habitant")
	ball.radius = 0.35
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
	# La cabane de vigne : la première fois qu'on pousse la porte, on repart avec l'affiche.
	biens.trouvailles.erase(village.CHEMIN.TROUVAILLE)
	var found := []
	village.cache_found.connect(func(id): found.append(id))
	village._chemin.fouiller()
	check(found == ["cabane_vigne"], "la cabane de vigne est signalée au Carnet comme lieu caché trouvé")
	check(biens.trouvailles.has(village.CHEMIN.TROUVAILLE), "la cabane de vigne donne l'affiche du loto de 1987")
	village._chemin.fouiller()
	check(biens.trouvailles.count(village.CHEMIN.TROUVAILLE) == 1, "l'affiche ne se prend qu'une fois")
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
