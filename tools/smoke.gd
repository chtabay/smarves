extends Node
## Parcours automatique de tout le jeu, pour la chasse aux bugs :
## godot --path . res://tools/smoke.tscn   (sans --headless : on mesure aussi les images par seconde)
## Ouvre chaque lieu du village et chaque table du casino, joue un coup, ferme, voyage dans les
## environs, redimensionne la fenêtre, et imprime un bilan. Les erreurs de Godot s'affichent dans la sortie.

var report: Array[String] = []


func _ready() -> void:
	# On survit aux changements de scène en se rattachant à la racine.
	await get_tree().process_frame
	var root := get_tree().root
	get_parent().remove_child(self)
	root.add_child(self)
	Game.saving_enabled = false
	Game.won = 2_000_000
	Game.staked = 2_000_000
	Game.credits = 1_000_000
	Game.welcomed = true
	get_tree().change_scene_to_file("res://scenes/main.tscn")
	await _wait(3.0)
	await _village()
	get_tree().change_scene_to_file("res://scenes/casino.tscn")
	await _wait(3.0)
	await _casino()
	await _shops()
	await _resize()
	print("\n=== BILAN DU PARCOURS ===")
	for r in report:
		print(r)
	get_tree().quit(0)


## Les vendeurs du village : chaque intérieur, sa vitrine, un achat, le carnet.
func _shops() -> void:
	for id in Biens.SELLERS:
		get_tree().change_scene_to_file(Biens.SELLERS[id].scene)
		await _wait(2.0)
		var shop := get_tree().current_scene
		shop.open_vitrine()
		await _wait(0.5)
		var bought := false
		for it in Biens.CATALOGUE:
			if it.seller == id and Biens.available(it.id):
				bought = Biens.buy(it.id)
				break
		report.append(("ok " if bought else "ÉCHEC ") + "vendeur : %s" % Biens.SELLERS[id].name)
		await _fps(Biens.SELLERS[id].name)
	# Chez soi : la chambre au-dessus du café, habitée, un emplacement meublé.
	Game.credits += 2000
	Biens.buy("chambre")
	Biens.habiter("chambre")
	Biens.enter("chambre")
	await _wait(2.0)
	var inside := get_tree().current_scene.scene_file_path == Biens.LOGEMENT_SCENE
	report.append(("ok " if inside else "ÉCHEC ") + "logement : la chambre au-dessus du café")
	await _fps("La chambre au-dessus du café")
	Carnet.toggle()
	await _wait(0.5)
	report.append(("ok " if Carnet.is_open() else "ÉCHEC ") + "le carnet s'ouvre")
	Carnet.toggle()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _fps(label: String, seconds := 3.0) -> void:
	var vp := get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp, true)
	var cpu := 0.0
	var gpu := 0.0
	var frames := 0
	var t := 0.0
	var worst := 0.0
	while t < seconds:
		await get_tree().process_frame
		var d := get_process_delta_time()
		t += d
		frames += 1
		worst = maxf(worst, d)
		cpu += RenderingServer.viewport_get_measured_render_time_cpu(vp) + RenderingServer.get_frame_setup_time_cpu()
		gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp)
	report.append("%-40s %5.1f images/s affichées · rendu GPU %.1f ms, CPU %.1f ms par image" % [label, frames / t, gpu / frames, cpu / frames])


func _play(p: Node) -> void:
	var path: String = p.get_script().resource_path.get_file()
	match path:
		"slot_machine.gd":
			p.spin()
		"roulette_panel.gd":
			p._place_bet("red")
			p.spin()
		"blackjack_panel.gd":
			p._start()
			await _wait(0.5)
			if p.in_hand:
				p._on_stand()
		"baccara_panel.gd":
			p._place("joueur")
			p._deal()
		"dice_panel.gd":
			p._place("n3")
			p._roll()
		"craps_panel.gd":
			p._place("pass")
			p._roll()
		"wheel_panel.gd":
			p._place("1")
			p._spin()
		"race_panel.gd":
			p._choose(0)
			p._run()
		"loto_panel.gd":
			p.picks.assign([1, 2, 3])
			p._draw_balls()
		"poker_panel.gd":
			p._new_hand()
			var guard := 0
			while p.in_hand and guard < 3000:
				guard += 1
				if p._waiting_player:
					p._on_call()
				await get_tree().process_frame
		"loan_panel.gd":
			p._borrow(500)
	await _wait(5.5)


func _village() -> void:
	var main := get_tree().current_scene
	await _fps("Village, vue d'ensemble")
	for place in main.PLACES:
		var id: String = place.id
		if id == "casino":
			continue
		var scene := Commune.smarves().interieur(id)
		if scene == "":
			# Le prêt de M. Brunet s'ouvre sur la place.
			var before: int = main._panels.get_child_count()
			main._list_enter(id)
			await _wait(1.2)
			if main._panels.get_child_count() <= before:
				report.append("ÉCHEC village : aucun panneau pour %s" % id)
				continue
			var panel: Node = main._panels.get_child(main._panels.get_child_count() - 1)
			await _play(panel)
			panel.closed.emit()
			await _wait(0.6)
			report.append("ok village : %s" % place.name)
			continue
		# Les jeux du village se jouent dans leur salle : on entre, on joue, on ressort.
		main._list_enter(id)
		await _wait(3.0)
		var salle := get_tree().current_scene
		if salle.scene_file_path != scene:
			report.append("ÉCHEC village : on n'entre pas dans la salle de %s" % id)
			get_tree().change_scene_to_file("res://scenes/main.tscn")
			await _wait(3.0)
			main = get_tree().current_scene
			continue
		await _fps(place.name)
		salle.open_game()
		await _wait(0.6)
		await _play(salle._game)
		salle._game.closed.emit()
		await _wait(0.4)
		for a in salle.find_children("*", "Area3D", true, false):
			if a.get_meta("interact", "") == "exit":
				salle._on_interact(a)
				break
		await _wait(3.0)
		main = get_tree().current_scene
		# Un lieu sans porte au village (la salle de basket, où l'on va en car) ramène à l'arrêt du car.
		var village: Node = main.get_node("Village")
		var devant: Vector3 = village.door_spawn(id)[0] if village.has_door(id) else village.ARRET[0] + Vector3(0, 0.05, 1.4)
		var back: bool = main.scene_file_path == "res://scenes/main.tscn" and main.player.global_position.distance_to(devant) < 0.5
		report.append(("ok " if back else "ÉCHEC ") + "village : %s, et l'on ressort devant sa porte" % place.name)
	for a in ["bois", "moulin", "passelourdin"]:
		main.travel(a)
		await _wait(1.5)
		await _fps("Environs : " + a)
	main.travel("place")
	await _wait(1.0)


func _casino() -> void:
	var casino := get_tree().current_scene
	await _fps("Casino, entrée")
	var seen := {}
	for area in casino.find_children("*", "Area3D", true, false):
		var kind := str(area.get_meta("interact", ""))
		if kind in ["", "talk", "exit", "reception"] or seen.has(kind):
			continue
		seen[kind] = true
		casino.player.global_position = area.global_position + Vector3(0, 0, 1.5)
		await _wait(0.4)
		casino._on_interact(area)
		await _wait(0.8)
		var p: Node = casino._active_panel
		if p == null:
			report.append("ok casino : %s (sans panneau)" % kind)
			continue
		await _play(p)
		await _fps("Casino, table " + kind, 1.5)
		p.closed.emit()
		await _wait(0.5)
		report.append("ok casino : %s" % kind)
	casino.player.global_position = Vector3(0, 6.2, 0)
	await _wait(1.0)
	await _fps("Casino, Galerie de la Verrière")


func _resize() -> void:
	for size in [Vector2i(1024, 600), Vector2i(1920, 1080), Vector2i(1600, 900)]:
		DisplayServer.window_set_size(size)
		await _wait(1.0)
		var path := "user://smoke_%dx%d.png" % [size.x, size.y]
		get_viewport().get_texture().get_image().save_png(path)
		report.append("capture %s : %s" % [str(size), ProjectSettings.globalize_path(path)])
