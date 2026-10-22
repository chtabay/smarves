extends SceneTree
## Vérifie les remèdes à la lenteur sans affichage : godot --headless --path . -s tools/test_lenteur.gd
## « Jouer » reprend le village de l'écran titre dans l'état d'une arrivée sur la place ; la qualité de
## l'image règle les environnements et la cadence, et la qualité haute rend les choix des lieux ; les
## ambiances calculées en tâche de fond sont celles d'avant, échantillon pour échantillon ; la place
## quittée pour un lieu revient sans se rebâtir, sauf si la partie a changé ce qu'elle montre.

var echecs := 0


func _verifier(ok: bool, quoi: String) -> void:
	print(("ok " if ok else "ÉCHEC ") + quoi)
	if not ok:
		echecs += 1


func _calques_visibles(n: Node) -> int:
	var k := 0
	for c in n.get_children():
		if c is CanvasLayer and c.visible:
			k += 1
	return k


func _init() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	var settings: Node = root.get_node("Settings")
	var sfx: Node = root.get_node("Sfx")
	game.saving_enabled = false
	game.welcomed = true

	# La place chargée d'un bloc, pour comparer.
	change_scene_to_file("res://scenes/main.tscn")
	for i in 3:
		await process_frame
	var calques: int = _calques_visibles(current_scene)
	var habitants := current_scene.find_children("*", "CharacterBody3D", true, false).size()

	# L'écran titre, puis Jouer.
	change_scene_to_file("res://scenes/title.tscn")
	for i in 3:
		await process_frame
	var titre := current_scene
	var village: Node = titre.village
	_verifier(village.has_meta("vitrine") and village.player == null and _calques_visibles(village) == 0, "le village de l'écran titre est en vitrine, sans habitant ni interface")
	titre._play()
	for i in 3:
		await process_frame
	var place := current_scene
	_verifier(place == village, "Jouer garde le village de l'écran titre au lieu de le rebâtir")
	_verifier(not is_instance_valid(titre), "l'écran titre est libéré")
	_verifier(place.scene_file_path == "res://scenes/main.tscn" and not place.has_meta("vitrine"), "la place est la scène en cours, hors vitrine")
	_verifier(place.player != null and place.player.is_inside_tree() and place.fps, "l'habitant qu'on dirige est posé")
	_verifier(_calques_visibles(place) == calques, "l'interface est celle d'une arrivée sur la place (%d calques)" % calques)
	_verifier(place.find_children("*", "CharacterBody3D", true, false).size() == habitants, "autant d'habitants qu'une place chargée d'un bloc")
	_verifier(get_root().get_camera_3d() != null and place.camera.is_inside_tree(), "une caméra neuve est la caméra en cours")
	var v: Node = place.get_node("Village")
	var n := 0
	for c in v.zone_entered.get_connections():
		if c.callable.get_method() == "_on_zone_entered":
			n += 1
	_verifier(n <= 1, "le carnet n'écoute qu'une fois les zones du village")
	_verifier(place.is_processing_unhandled_input(), "la place écoute de nouveau le clavier")

	# La qualité de l'image.
	var we: WorldEnvironment = place.find_children("*", "WorldEnvironment", true, false)[0]
	settings.qualite = "legere"
	settings.appliquer_qualite()
	_verifier(not we.environment.sdfgi_enabled and not we.environment.volumetric_fog_enabled and Engine.max_fps == 30, "qualité légère : sans éclairage indirect ni brouillard, 30 images/s")
	_verifier(root.scaling_3d_scale < 1.0 and root.msaa_3d == Viewport.MSAA_DISABLED, "qualité légère : rendu 3D réduit, sans anticrénelage")
	settings.qualite = "haute"
	settings.appliquer_qualite()
	_verifier(we.environment.sdfgi_enabled and we.environment.ssil_enabled and we.environment.volumetric_fog_enabled and Engine.max_fps == 60, "qualité haute : la place retrouve tous ses effets, 60 images/s")
	_verifier(root.scaling_3d_scale == 1.0 and root.msaa_3d == ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d"), "qualité haute : les réglages du projet")
	settings.qualite = "equilibree"
	settings.appliquer_qualite()
	_verifier(we.environment.sdfgi_enabled and we.environment.volumetric_fog_enabled, "qualité équilibrée : les mêmes effets")
	change_scene_to_file("res://scenes/casino.tscn")
	for i in 3:
		await process_frame
	var env: Environment = current_scene.find_children("*", "WorldEnvironment", true, false)[0].environment
	_verifier(env.ssr_enabled and env.ssr_max_steps == 24, "qualité équilibrée : un lieu chargé ensuite est réglé dès son arrivée (reflets du casino à 24 pas)")
	settings.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_verifier(Engine.max_fps == 10, "fenêtre en arrière-plan : 10 images/s")
	settings.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	_verifier(Engine.max_fps == 60, "fenêtre au premier plan : 60 images/s")

	# Les ambiances : les mêmes échantillons qu'un calcul sur le fil principal.
	for kind in ["village", "casino"]:
		var boucle: AudioStreamWAV = sfx._loops[kind]
		_verifier(boucle.data == sfx._render_data(kind) and boucle.loop_end == int(sfx.RATE * 16.0), "ambiance %s : identique au calcul d'avant" % kind)

	# La place gardée pendant une visite.
	change_scene_to_file("res://scenes/main.tscn")
	for i in 3:
		await process_frame
	var chargement: Node = root.get_node("Chargement")
	var la_place := current_scene
	var calques_place := _calques_visibles(la_place)
	chargement.lieu("res://scenes/casino.tscn")
	for i in 3:
		await process_frame
	_verifier(current_scene != la_place and is_instance_valid(la_place) and la_place.is_inside_tree(), "au casino, la place reste gardée dans l'arbre")
	_verifier(not la_place.visible and la_place.process_mode == Node.PROCESS_MODE_DISABLED and _calques_visibles(la_place) == 0, "la place gardée est cachée et à l'arrêt, son interface aussi")
	_verifier(root.find_children("*", "WorldEnvironment", true, false).size() == 1, "un seul environnement dans l'arbre pendant la visite")
	var t0 := Time.get_ticks_usec()
	chargement.changer("res://scenes/main.tscn")
	await process_frame
	var duree := (Time.get_ticks_usec() - t0) / 1000
	_verifier(current_scene == la_place and la_place.visible and la_place.can_process(), "le retour rend la même place, visible et en marche (%d ms)" % duree)
	_verifier(_calques_visibles(la_place) == calques_place and root.find_children("*", "WorldEnvironment", true, false).size() == 1, "son interface et son environnement reviennent")
	_verifier(root.get_node("Sfx").ambience == "village" and root.get_viewport().get_camera_3d() != null and root.get_viewport().get_camera_3d().is_inside_tree(), "l'ambiance du village et une caméra de la place")
	# Un achat pendant la visite change la place (véhicule, panneaux) : elle se rebâtit.
	chargement.lieu("res://scenes/casino.tscn")
	for i in 3:
		await process_frame
	var biens: Node = root.get_node("Biens")
	game.credits = 10_000_000
	var achete := false
	for it in biens.CATALOGUE:
		if biens.available(it.id) and biens.buy(it.id):
			achete = true
			break
	_verifier(achete, "un achat pendant la visite")
	chargement.changer("res://scenes/main.tscn")
	for i in 3:
		await process_frame
	_verifier(current_scene != la_place and not is_instance_valid(la_place), "après un achat, la place se rebâtit et l'ancienne est libérée")
	# Deux changements sans retour : la place gardée est libérée.
	la_place = current_scene
	chargement.lieu("res://scenes/casino.tscn")
	for i in 3:
		await process_frame
	change_scene_to_file("res://scenes/cafe.tscn")
	for i in 3:
		await process_frame
	_verifier(not is_instance_valid(la_place), "deux lieux plus loin, la place gardée est libérée")

	print("%d échec(s)" % echecs)
	quit(1 if echecs else 0)
