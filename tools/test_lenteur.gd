extends SceneTree
## Vérifie les remèdes à la lenteur sans affichage : godot --headless --path . -s tools/test_lenteur.gd
## « Jouer » reprend le village de l'écran titre dans l'état d'une arrivée sur la place ; la qualité de
## l'image règle les environnements et la cadence, et la qualité haute rend les choix des lieux ; les
## ambiances calculées en tâche de fond sont celles d'avant, échantillon pour échantillon ; la place
## quittée pour un lieu revient sans se rebâtir, sauf si la partie a changé ce qu'elle montre ; ce qu'un
## script fabrique se range sur l'appareil (Memo) ; le budget d'un lieu se mesure (Budget) ; les objets
## lointains sont simplifiés et reçoivent leurs niveaux de détail (Lointain).

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
	# Les figurines du casino naissent avec leurs niveaux de détail (CritterMesh, socle 1.16).
	var figurines := 0
	var a_niveaux := 0
	for mi in current_scene.find_children("*", "MeshInstance3D", true, false):
		if mi.mesh is ArrayMesh and mi.mesh.get_surface_count() > 0 and mi.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_BONES:
			figurines += 1
			if RenderingServer.mesh_get_surface(mi.mesh.get_rid(), 0).has("lods"):
				a_niveaux += 1
	_verifier(figurines > 0 and a_niveaux == figurines, "les figurines du casino ont leurs niveaux de détail (%d sur %d)" % [a_niveaux, figurines])
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

	# Le lieu construit une fois, puis sauvegardé : ce qu'un script fabrique est rangé sur l'appareil.
	var appels := [0]
	var fabrique := func():
		appels[0] += 1
		return {"n": appels[0], "v": PackedVector3Array([Vector3.ONE])}
	var dossier := "user://cache/essai_lenteur/"
	if DirAccess.dir_exists_absolute(dossier):
		for d in DirAccess.get_directories_at(dossier):
			for f in DirAccess.get_files_at(dossier + d):
				DirAccess.remove_absolute(dossier + d + "/" + f)
			DirAccess.remove_absolute(dossier + d)
	Memo._versions.erase("essai_lenteur")
	var a = Memo.valeur("essai_lenteur", "res://tools/test_lenteur.gd", ["clé", 1], fabrique)
	var b = Memo.valeur("essai_lenteur", "res://tools/test_lenteur.gd", ["clé", 1], fabrique)
	_verifier(appels[0] == 1 and a == b and b.v[0] == Vector3.ONE, "une valeur se fabrique une fois, puis se relit du fichier")
	Memo.valeur("essai_lenteur", "res://tools/test_lenteur.gd", ["clé", 2], fabrique)
	_verifier(appels[0] == 2, "une autre clé se fabrique")
	var version: String = DirAccess.get_directories_at(dossier)[0]
	Memo._versions.erase("essai_lenteur")
	Memo.valeur("essai_lenteur", "res://tools/mesure_lenteur.gd", ["clé", 1], fabrique)
	var versions := DirAccess.get_directories_at(dossier)
	_verifier(appels[0] == 3 and versions.size() == 1 and versions[0] != version, "un script qui change refabrique et efface la version d'avant")
	var pixels := [0]
	var peindre := func():
		pixels[0] += 1
		var img := Image.create(4, 2, false, Image.FORMAT_RGB8)
		img.set_pixel(3, 1, Color.RED)
		img.generate_mipmaps()
		return img
	var t1 := Memo.image("essai_lenteur", "res://tools/mesure_lenteur.gd", "image", peindre)
	Memo.oublier()
	var t2 := Memo.image("essai_lenteur", "res://tools/mesure_lenteur.gd", "image", peindre)
	_verifier(pixels[0] == 1 and t1 != t2 and t2.get_image().get_pixel(3, 1) == Color.RED and t2.get_image().has_mipmaps(), "une image peinte se relit avec ses pixels et ses mipmaps")
	var bruit := NoiseTexture2D.new()
	bruit.width = 16
	bruit.height = 16
	bruit.noise = FastNoiseLite.new()
	var premiere := Memo.bruit("essai_lenteur", "res://tools/mesure_lenteur.gd", "bruit", bruit)
	for i in 3:
		await process_frame
	Memo.oublier()
	var seconde := Memo.bruit("essai_lenteur", "res://tools/mesure_lenteur.gd", "bruit", bruit)
	_verifier(premiere == bruit and seconde is ImageTexture and seconde.get_image().get_data() == bruit.get_image().get_data(), "une texture de bruit sert telle quelle la première fois, puis se relit, pixel pour pixel")
	# Le casino se lit d'avance depuis la place : ses scripts sont déjà là quand on y entre.
	for i in 30:
		if ResourceLoader.has_cached("res://scenes/casino.tscn"):
			break
		await create_timer(0.1).timeout
	_verifier(ResourceLoader.has_cached("res://scenes/casino.tscn") and ResourceLoader.has_cached("res://scripts/casino_interior.gd"), "le casino et ses scripts sont lus d'avance depuis la place")

	# Le budget par lieu : la mesure d'une scène, et ce qui dépasse les seuils.
	var lieu := Node3D.new()
	lieu.set_meta("sans_lointain", true)
	var perle := MeshInstance3D.new()
	perle.mesh = SphereMesh.new()
	perle.mesh.radius = 0.03
	perle.mesh.height = 0.06
	perle.scale = Vector3.ONE * 0.5
	lieu.add_child(perle)
	var lampe := OmniLight3D.new()
	lampe.shadow_enabled = true
	lieu.add_child(lampe)
	lieu.add_child(Label3D.new())
	var gros := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radial_segments = 128
	sphere.rings = 64
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, sphere.get_mesh_arrays())
	gros.mesh = am
	lieu.add_child(gros)
	root.add_child(lieu)
	await process_frame
	var tri_perle := Budget._triangles(perle.mesh, {})
	var tri_gros := Budget._triangles(am, {})
	var mesure := Budget.mesurer(lieu)
	_verifier(mesure.triangles == tri_perle + tri_gros and mesure.lumieres == 1 and mesure.ombres == 1 and mesure.etiquettes == 1 and mesure.noeuds == 5, "la mesure d'un lieu compte triangles, lampes, ombres, étiquettes et nœuds")
	var dep := Budget.depassements(mesure, {"triangles": 1000, "ombres": 0, "noeuds": 100})
	_verifier(dep.size() == 2 and dep[0].begins_with("%s triangles" % Budget._nombre(mesure.triangles)) and dep[1].begins_with("1 lampes à ombres"), "ce qui dépasse les seuils est dit, dans l'ordre des seuils : %s" % " ; ".join(dep))
	_verifier(Budget.depassements(mesure).is_empty() and Budget.resume(mesure).begins_with("%s triangles, " % Budget._nombre(mesure.triangles)), "un petit lieu tient dans les seuils du socle ; son résumé commence par ses triangles")
	# Les objets lointains : une perle de 1,5 cm (sphère 64 × 32) ne garde que douze segments ; un
	# maillage de seize mille triangles reçoit ses niveaux dans un fil, puis remplace l'ancien.
	Lointain.appliquer(lieu)
	_verifier(perle.mesh.radial_segments == 12 and perle.mesh.rings == 6 and Budget.mesurer(lieu).triangles < mesure.triangles, "une petite primitive est ramenée aux segments de sa taille vue (%d × %d)" % [perle.mesh.radial_segments, perle.mesh.rings])
	var nouveaux := 0
	for i in 600:
		await process_frame
		if not Lointain.en_travail():
			break
	var lods: Array = RenderingServer.mesh_get_surface(gros.mesh.get_rid(), 0).get("lods", []) if gros.mesh is ArrayMesh else []
	_verifier(gros.mesh != am and not Lointain.en_travail() and lods.size() >= 2 and Budget._triangles(gros.mesh, {}) == tri_gros, "un gros maillage reçoit ses niveaux de détail (%d) et garde ses triangles de près" % lods.size())
	_verifier(Lointain.niveaux(lieu) == 0, "un maillage à niveaux n'est pas repris")
	# Chargement l'applique de lui-même à chaque scène 3D qui arrive, sauf à celles qui le refusent.
	var autre := Node3D.new()
	var bille := MeshInstance3D.new()
	bille.mesh = SphereMesh.new()
	bille.mesh.radius = 0.01
	autre.add_child(bille)
	root.add_child(autre)
	await process_frame
	await process_frame
	_verifier(bille.mesh.radial_segments == 12 and perle.mesh.radial_segments == 12, "une scène qui arrive dans l'arbre est simplifiée sans rien demander")
	lieu.queue_free()
	autre.queue_free()

	print("%d échec(s)" % echecs)
	quit(1 if echecs else 0)
