extends SceneTree
## Vérifie qu'on roule dans le village sans affichage : godot --headless --path . -s tools/test_conduite.gd
## On monte sur le vélo garé (E), on va plus vite qu'à pied, assis sur la selle ; V fait descendre et
## le vélo reste là où on l'a laissé, même après être rentré dans une boutique. Au volant de la 2 CV,
## l'habitant disparaît dans la voiture et le corps s'élargit ; une porte prise en roulant fait garer
## devant ; un véhicule repris sous nous remet à pied.

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


## Avance tout droit une seconde et rend la distance parcourue.
func rouler(player: CharacterBody3D) -> float:
	var depart := player.global_position
	player.auto_move = Vector3(0, 0, -1)
	await create_timer(1.0).timeout
	player.auto_move = Vector3.ZERO
	await physics_frame
	var d := player.global_position - depart
	return Vector2(d.x, d.z).length()


func _init() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	var biens: Node = root.get_node("Biens")
	game.saving_enabled = false
	game.welcomed = true
	for it in biens.CATALOGUE:
		if it.kind == "vehicule":
			check(it.has("vitesse") and float(it.vitesse) > 1.0, "%s a sa vitesse" % it.name)
			check(biens.build_vehicle(it.id) != null, "%s se dessine ou se charge" % it.name)
	check(biens.deux_roues("velo") and biens.deux_roues("moto") and not biens.deux_roues("deux_cv"), "vélo et moto sont des deux-roues, la 2 CV non")
	check(biens.selle("velo") > 0.1 and biens.selle("moto") > 0.1, "vélo et moto ont une selle")
	biens.owned["velo"] = 1
	biens.driven = "velo"
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(1.0).timeout
	var main: Node = current_scene
	var village: Node = main.get_node("Village")
	var player: CharacterBody3D = main.player
	var conduite: Node = main.conduite
	check(conduite != null, "la place a sa conduite")
	check(village._vehicle != null and village._vehicle_id == "velo", "le vélo est garé sur la place")
	var area: Area3D = village._vehicle.get_node_or_null("Monter")
	check(area != null and str(area.get_meta("prompt", "")) == "E : monter sur le vélo de facteur", "le vélo garé dit « E : monter sur le vélo de facteur »")
	# À pied d'abord, pour comparer.
	main._put_player(Vector3(0, 0.05, 4.6), 0.0)
	await physics_frame
	var a_pied: float = await rouler(player)
	# On monte : E sur le vélo.
	main._put_player(village._vehicle.global_position + Vector3(0, 0.05, 0.6), 0.0)
	await physics_frame
	main._on_player_interact(area)
	check(conduite.monte == "velo", "E sur le vélo garé fait monter dessus")
	check(village._vehicle.get_parent() == player, "le vélo suit l'habitant")
	check(player.assis and player.avatar.pose == 2, "au guidon, l'habitant est assis")
	check(player.avatar.position.y > 0.05, "assis sur la selle, pas dans le sol (%.2f)" % player.avatar.position.y)
	await physics_frame
	await physics_frame
	main._update_prompt()
	check(main._prompt.visible and main._prompt.text == "V : descendre du vélo de facteur", "l'invite dit comment descendre (%s)" % main._prompt.text)
	main._put_player(Vector3(0, 0.05, 4.6), 0.0)
	await physics_frame
	var a_velo: float = await rouler(player)
	check(a_velo > a_pied * 1.6, "à vélo on va plus vite qu'à pied (%.1f contre %.1f)" % [a_velo, a_pied])
	# V : on descend, le vélo reste là.
	var ici := player.global_position
	var v := InputEventKey.new()
	v.physical_keycode = KEY_V
	v.keycode = KEY_V
	v.pressed = true
	conduite._unhandled_input(v)
	check(conduite.monte == "", "V fait descendre")
	check(village._vehicle.get_parent() == village, "le vélo reste dans la rue")
	var garee: Vector3 = village._vehicle.global_position
	check(Vector2(garee.x, garee.z).distance_to(Vector2(ici.x, ici.z)) < 0.2, "le vélo est garé là où l'on est descendu")
	check(not player.assis and is_equal_approx(player.speed, 1.5) and is_equal_approx(player.radius, 0.14), "à pied, l'habitant retrouve son pas et sa taille")
	check(not (area.get_node("CollisionShape3D") as CollisionShape3D).disabled, "on peut remonter sur le vélo garé")
	# La place rebâtie (retour du casino) : le vélo est toujours où on l'a laissé.
	game.return_point = "casino"
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(1.0).timeout
	main = current_scene
	village = main.get_node("Village")
	player = main.player
	conduite = main.conduite
	var p2: Vector3 = village._vehicle.global_position
	check(Vector2(p2.x, p2.z).distance_to(Vector2(garee.x, garee.z)) < 0.05, "la place rebâtie, le vélo est resté où on l'a laissé")
	# La 2 CV : on monte dedans.
	biens.owned["deux_cv"] = 1
	biens.driven = "deux_cv"
	biens.changed.emit()
	await process_frame
	check(village._vehicle_id == "deux_cv" and village._vehicle.global_position.distance_to(village.PARKING[0]) < 0.05, "la 2 CV se gare à sa place sur la place")
	area = village._vehicle.get_node("Monter")
	check(str(area.get_meta("prompt")) == "E : prendre la 2 CV", "la 2 CV garée dit « E : prendre la 2 CV »")
	main._put_player(village._vehicle.global_position + Vector3(0, 0.05, 0.9), 0.0)
	await physics_frame
	conduite.monter()
	check(conduite.monte == "deux_cv" and not player.avatar.visible, "au volant, l'habitant est dans la voiture")
	check(player.radius > 0.25, "au volant, le corps prend la largeur de la voiture")
	main.topdown = false
	main.set_fps(true)
	check(not village._vehicle.visible, "à pied (première personne), la carrosserie ne bouche pas la vue")
	main.topdown = true
	main.set_fps(true)
	check(village._vehicle.visible and not player.avatar.visible, "revenu en vue de dessus, on voit la voiture et pas l'habitant")
	# Une porte prise en roulant : on se gare devant d'abord.
	var porte := Area3D.new()
	var entre := []
	porte.set_meta("action", func(): entre.append(conduite.monte))
	main._on_player_interact(porte)
	porte.free()
	check(entre == [""] and village._vehicle.get_parent() == village, "on gare la 2 CV avant de prendre une porte")
	check(player.avatar.visible, "descendu, l'habitant reparaît")
	# Repris par M. Brunet sous nous : on repart à pied.
	conduite.monter()
	biens.owned.erase("deux_cv")
	biens.driven = "velo"
	biens.changed.emit()
	await process_frame
	check(conduite.monte == "" and is_equal_approx(player.speed, 1.5), "la voiture reprise, on repart à pied")
	check(village._vehicle_id == "velo" and village._vehicle.get_parent() == village, "le vélo revient dans la rue")
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
