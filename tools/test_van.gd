extends SceneTree
## Le van des chasseurs de pépites et l'atelier des véhicules : godot --headless --path . -s tools/test_van.gd
## La caisse galbée a ses deux flancs (le profil rentré se triangule), la camionnette reste bleue sous le
## seuil, et passé le seuil la livrée remplace le Car Kit sans toucher à sa boîte de collision.

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	# Un profil simple à passages de roue, arêtes arrondies de 0,17 : deux flancs pleins.
	var p := PackedVector2Array([Vector2(-1.4, 0.24), Vector2(-1.36, 0.15)])
	for z: float in [-0.8, 0.8]:
		p.append_array(Carrosserie.arc(Vector2(z, 0.3), 0.385, 205.0, -25.0, 12))
	p.append_array([Vector2(1.4, 0.15), Vector2(1.4, 1.2), Vector2(-1.4, 1.2)])
	var m := Carrosserie.galbe(p, 1.42, 0.17)
	var bords := p.size() * 9 * 6
	check(m.surface_get_array_len(0) > bords, "la caisse galbée a ses flancs (%d sommets, %d pour le seul tour)" % [m.surface_get_array_len(0), bords])
	var box := m.get_aabb()
	check(is_equal_approx(box.size.x, 1.42) and box.position.y > 0.1, "la caisse fait la largeur demandée")

	var pepites: Node3D = load("res://scripts/village/pepites.gd").new()
	var car: Node3D = load("res://assets/kenney/cars/van.glb").instantiate()
	root.add_child(car)
	car.scale = Vector3.ONE * 0.55
	var body := StaticBody3D.new()
	car.add_child(body)
	root.add_child(pepites)
	game.won = 0
	pepites.setup(car, null)
	await process_frame
	check(not pepites.livree and car.find_child("Livree", true, false) == null, "sous le seuil, la camionnette de toujours")
	game.won = 2000
	await process_frame
	await process_frame
	var livree := car.find_child("Livree", true, false) as Node3D
	check(pepites.livree and livree != null, "au seuil, la livrée des chasseurs de pépites")
	var cachees := 0
	var kenney := 0
	for mi in car.find_children("*", "MeshInstance3D", true, false):
		if not livree.is_ancestor_of(mi):
			kenney += 1
			cachees += int(not (mi as MeshInstance3D).visible)
	check(kenney > 0 and cachees == kenney, "le Car Kit s'efface (%d/%d)" % [cachees, kenney])
	check(is_instance_valid(body) and body.get_parent() == car, "la boîte de collision reste")
	var labels := livree.find_children("*", "Label3D", true, false)
	var textes := labels.map(func(l): return (l as Label3D).text)
	check(livree.find_children("Medaillon*", "Node3D", true, false).size() == 2, "le médaillon sur les deux flancs")
	check("MMXX" in textes and "AS-020-VN" in textes, "le millésime et la plaque sont peints")
	# La livrée tient dans la boîte de la camionnette (à la galerie près).
	var b: AABB = pepites._local_aabb(car)
	check(b.size.z < 3.1 and b.size.x < 1.8 and b.size.y < 1.8, "la livrée garde la taille de la camionnette (%s)" % b.size)
	print("%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
