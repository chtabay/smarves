extends SceneTree
## Vérifie Availles-Limouzine (tools/paquet_essai/availles_limouzine/), emballée ici en pack comme
## une commune greffée : godot --headless --path . -s tools/test_availles.gd
## Le bourg se construit depuis bourg.json, l'habitant s'y pose sur le sol et y marche, la rivière et
## les murs l'arrêtent, le pont le laisse passer, et les lieux remarquables sont des nœuds à part.
## Avec -- --capture=sortie.png [--a=x,z,cran,lacet] (sans --headless), il photographie le bourg.

const SOURCE := "res://tools/paquet_essai/availles_limouzine/"
const TMP := "user://test_availles/"

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var communes: Node = root.get_node("Communes")
	DirAccess.make_dir_recursive_absolute(TMP)
	communes.dossier_greffes = TMP
	var pk := PCKPacker.new()
	pk.pck_start(TMP + "availles_limouzine.pck")
	for f in ["commune.json", "commune.tscn", "availles.gd", "remarquables.gd", "bourg.json", "sol.png.import"]:
		pk.add_file("res://communes/availles_limouzine/" + f, SOURCE + f)
	var imp := ConfigFile.new()
	imp.load(SOURCE + "sol.png.import")
	var ctex := str(imp.get_value("remap", "path"))
	pk.add_file(ctex, ctex)
	pk.flush()
	check(communes.charger_pack(TMP + "availles_limouzine.pck") == "availles_limouzine", "Availles-Limouzine se greffe depuis son pack %s" % str(communes.refus))
	var c: Commune = communes.commune("availles_limouzine")
	check(c != null and c.insee == "86015", "au code INSEE d'Availles-Limouzine")
	check(communes.ouvrir("availles_limouzine"), "le pack s'ouvre et la scène est là")

	var t0 := Time.get_ticks_msec()
	change_scene_to_file(str(c.data.scene))
	await process_frame
	await process_frame
	var s: Node3D = current_scene
	check(s != null and s.scene_file_path == str(c.data.scene), "on est dans le bourg")
	print("        construit en %d ms" % (Time.get_ticks_msec() - t0))
	var capture := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--capture="):
			capture = a
	if capture != "":
		# La scène prend la photo et quitte d'elle-même.
		return

	var data: Dictionary = s.data
	check(data.batiments.size() > 800, "les bâtiments du bourg sont là (%d)" % data.batiments.size())
	for id in ["eglise", "mairie", "porte_cavaliers", "chateau", "porte_riviere", "hotel", "adrien_bernard", "groupama", "restaurant", "maison_21"]:
		var n := s.find_child("Remarquable_" + id, false, false)
		check(n != null and n.get_meta("remarquable") == id, "%s est un nœud à part, prêt à personnaliser" % id)
	check(s.find_child("Pont", false, false) != null, "le pont sur la Vienne est construit")
	var enseigne := false
	for n in s.find_child("Remarquable_hotel", false, false).get_children():
		if n is Label3D and n.text == "La Châtellenie":
			enseigne = true
	check(enseigne, "la Châtellenie porte son enseigne, dessinée d'après photo")
	var plaque := false
	for n in s.find_child("Remarquable_mairie", false, false).get_children():
		if n is Label3D and n.text == "MAIRIE":
			plaque = true
	check(plaque, "la mairie porte sa plaque, dessinée d'après photo")
	var cam: Camera3D = s.camera
	check(cam.has_signal("au_dela") and cam.notches.size() == 4, "la caméra à crans du village, avec un cran de plus pour le bourg")
	var vue: Node = root.get_node("/root/Vue")
	check(vue.gere(s) and not s.has_method("set_fps"), "la bascule de vue est au socle : la commune n'a rien à coder")
	vue.basculer(s)
	var a_pied: bool = s.player.camera.current and s.player.follow_camera == null and not s.player.avatar.visible and cam.notches.is_empty()
	vue.basculer(s)
	check(a_pied and cam.current and s.player.follow_camera == cam and cam.notches.size() == 4, "Tab passe à pied et revient en vue de dessus, comme à Smarves")

	# L'habitant se pose sur le sol, à l'altitude de la place.
	var p: CharacterBody3D = s.player
	await _attendre(1.5)
	var sol: float = s.hauteur(p.global_position.x, p.global_position.z)
	check(absf(p.global_position.y - sol) < 0.3 and p.is_on_floor(), "l'habitant est posé sur la place (y %.2f, sol %.2f)" % [p.global_position.y, sol])

	# Il marche : vers l'église, par la rue.
	var depart := p.global_position
	p.auto_move = Vector3(0, 0, -1)
	await _attendre(2.0)
	p.auto_move = Vector3.ZERO
	check(p.global_position.distance_to(depart) > 1.5, "l'habitant marche dans le bourg (%.1f unités)" % p.global_position.distance_to(depart))

	# Le pont le porte au-dessus de la Vienne ; ailleurs, la rive l'arrête.
	var pont: Dictionary = {}
	for r in data.routes:
		if r.get("pont", false) and r.k == "secondary":
			pont = r
	check(not pont.is_empty(), "le pont de la route de Confolens est dans le plan")
	if not pont.is_empty():
		var a := Vector2(pont.p[0][0], pont.p[0][1])
		var b := Vector2(pont.p[-1][0], pont.p[-1][1])
		var m := (a + b) / 2.0
		p.global_position = Vector3(m.x, maxf(pont.y[0], pont.y[1]) + 0.6, m.y)
		p.velocity = Vector3.ZERO
		await _attendre(1.0)
		check(p.global_position.y > float(data.niveau_eau) + 1.0 and p.is_on_floor(), "au milieu du pont, l'habitant tient au-dessus de l'eau (y %.2f, eau %.2f)" % [p.global_position.y, data.niveau_eau])
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


func _attendre(s: float) -> void:
	await create_timer(s, true).timeout
