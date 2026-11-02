extends SceneTree
## Vérifie le passage au Dessous (scripts/socle/dessous.gd, autoload Dessous) sur Ligugé, emballée ici en pack :
## godot --headless --path . -s tools/test_dessous.gd
## L'habitant qu'on déplace d'un coup plus bas ne passe pas ; celui qui tombe par un trou loin sous le sol arrive
## au Dessous, la Porte des Joints le ramène à Ligugé, sur son sol ferme, dans la scène gardée telle quelle.

const LIGUGE := "res://tools/paquet_essai/liguge/"
const TMP := "user://test_dessous/"

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func attendre(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame


func _init() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	game.welcomed = true
	var communes: Node = root.get_node("Communes")
	var dessous: Node = root.get_node("Dessous")
	DirAccess.make_dir_recursive_absolute(TMP)
	communes.dossier_greffes = TMP
	var pk := PCKPacker.new()
	pk.pck_start(TMP + "liguge.pck")
	for f in ["commune.json", "commune.tscn", "liguge.gd"]:
		pk.add_file("res://communes/liguge/" + f, LIGUGE + f)
	pk.flush()
	check(communes.charger_pack(TMP + "liguge.pck") == "liguge", "Ligugé se greffe depuis son pack")
	check(communes.ouvrir("liguge"), "le pack s'ouvre")
	var c: Commune = communes.commune("liguge")
	change_scene_to_file(str(c.data.scene))
	await attendre(40)
	var s: Node3D = current_scene
	var p: CharacterBody3D = s.player
	check(p.is_on_floor(), "l'habitant est posé au sol à Ligugé")
	var sol := p.global_position

	# Un déplacement d'un coup plus bas, sur rien, puis remonté aussitôt : pas de passage.
	p.global_position = sol + Vector3(0, -40, 0)
	await attendre(3)
	p.global_position = sol + Vector3(0, 0.05, 0)
	p.velocity = Vector3.ZERO
	await attendre(20)
	check(current_scene == s, "un saut de quelques images sous le sol ne fait pas passer au Dessous")

	# La vraie chute : le sol s'ouvre sous l'habitant (sa collision coupée), il tombe.
	await attendre(40)
	var ferme: Vector3 = dessous.sol_ferme().origin
	p.collision_mask = 0
	var t := 0
	while current_scene == s and t < 600:
		await attendre(1)
		t += 1
	await attendre(10)
	check(current_scene != null and current_scene.scene_file_path == dessous.SCENE, "tombé loin sous Ligugé, on arrive au Dessous (%d images)" % t)
	check(dessous.origine.get("lieu", "") == "Ligugé", "le Dessous sait d'où l'on vient (%s)" % dessous.origine.get("lieu", ""))
	check(is_instance_valid(s) and not s.is_inside_tree() or not s.visible, "Ligugé est gardée, cachée")
	p.collision_mask = 1
	var monde: Node3D = current_scene
	check(monde.player != null and monde.player.frozen, "l'arrivée est mise en scène, l'habitant attend")
	check(monde.get_node_or_null("Akoupara") != null and monde.get_node_or_null("Lanterne") != null, "Akoupara et la Lanterne sont là")
	var n := 0
	for e in ["Airavata", "Vamana", "Anjana", "Sarvabhauma"]:
		if monde.get_node_or_null(e) != null:
			n += 1
	check(n == 4, "les quatre éléphants portent le disque (%d)" % n)
	monde.call("_finir_arrivee")
	await attendre(30)
	check(not monde.player.frozen and monde.player.is_on_floor(), "l'habitant a la main, posé sur l'île")
	# Il marche jusqu'à la Porte des Joints.
	monde.player.global_position = monde.PORTE + Vector3(0, 0.05, 1.2)
	monde.player.rotation.y = 0.0
	await attendre(6)
	check(monde.player.focus_target == monde.porte, "la Porte des Joints est sous la main")
	check(monde._prompt.visible and monde._prompt.text.begins_with("E : "), "l'invite dit « %s »" % monde._prompt.text)
	monde.player.interact.emit(monde.porte)
	t = 0
	while (current_scene == monde or dessous.get("_en_cours")) and t < 600:
		await attendre(1)
		t += 1
	await attendre(5)
	check(current_scene == s, "la Porte ramène à Ligugé, la scène gardée telle quelle")
	check(p.global_position.distance_to(ferme) < 0.5, "sur le sol ferme d'avant la chute (%.2f)" % p.global_position.distance_to(ferme))
	await attendre(30)
	check(p.is_on_floor() and current_scene == s, "l'habitant tient sur le sol de Ligugé")
	check(dessous.origine.is_empty(), "le Dessous a tout rendu")
	_fin()


func _fin() -> void:
	print("%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
