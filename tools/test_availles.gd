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
	for f in ["commune.json", "commune.tscn", "availles.gd", "remarquables.gd", "eglise.gd", "abords.gd", "bourg.json", "zones.json", "sol.png.import"]:
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
	# La touche elle-même, par le chemin des entrées : rien ne doit l'avaler avant le socle.
	var touche := InputEventKey.new()
	touche.keycode = KEY_TAB
	touche.physical_keycode = KEY_TAB
	touche.pressed = true
	Input.parse_input_event(touche)
	await process_frame
	await process_frame
	var par_touche: bool = s.player.camera.current and s.player.follow_camera == null
	touche = InputEventKey.new()
	touche.keycode = KEY_TAB
	touche.physical_keycode = KEY_TAB
	touche.pressed = true
	Input.parse_input_event(touche)
	await process_frame
	await process_frame
	check(par_touche and cam.current and s.player.follow_camera == cam, "la touche Tab elle-même arrive au socle et bascule (à pied : %s, retour : %s)" % [par_touche, cam.current])

	# L'habitant se pose sur le sol, à l'altitude de la place.
	var p: CharacterBody3D = s.player
	await _attendre(1.5)
	var sol: float = s.hauteur(p.global_position.x, p.global_position.z)
	check(absf(p.global_position.y - sol) < 0.3 and p.is_on_floor(), "l'habitant est posé sur la place (y %.2f, sol %.2f)" % [p.global_position.y, sol])

	# Le panneau d'affichage de la mairie : le socle le pose au point d'arrivée, la commune n'a rien fait.
	var tableau: Node = root.get_node("/root/Tableau")
	var panneau: Node3D = s.find_child("PanneauDuSocle", true, false)
	var loin: float = panneau.global_position.distance_to(p.global_position) if panneau else -1.0
	check(panneau != null and loin > 1.0 and loin < 4.0, "le panneau d'affichage est posé près de l'arrivée (%.1f m)" % loin)
	if panneau != null:
		var zone: Area3D = null
		for n in panneau.get_children():
			if n is Area3D:
				zone = n
		check(zone != null and str(zone.get_meta("prompt", "")).begins_with("E :"), "avec sa zone où appuyer sur E")
		p.interact.emit(zone)
		await process_frame
		check(tableau.is_open() and str(tableau._en_tete()).contains("A V A I L L E S"), "E l'ouvre, au nom de la commune")
		tableau.fermer()
		await process_frame
		# Avec un voisinage (la mise en scène des captures) : les amis et le rendez-vous relevé dans un mot (docs/AMIS.md).
		var voisinage: Node = root.get_node("/root/Voisinage")
		voisinage._mise_en_scene()
		p.interact.emit(zone)
		await process_frame
		var textes := _textes(tableau)
		check(tableau.is_open() and textes.any(func(t): return t == "VOS AMIS") and textes.any(func(t): return t.begins_with("Bastien")),
			"le panneau dit les amis du joueur")
		check(textes.any(func(t): return t.begins_with("Proposé par Bastien, demain à")), "et le rendez-vous relevé dans le mot de Bastien")
		check(textes.any(func(t): return t.begins_with("Bastien, à la mairie")), "le mot laissé à la mairie se lit au livre d'or")
		tableau.fermer()
		voisinage.donnees = {}
		voisinage.etat = ""
		await process_frame

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
		# Et il y monte depuis chaque rive : la culée raccorde le tablier au sol, sans marche.
		vue.basculer(s)  # à pied : la marche suit le corps, pas la caméra
		for sens in [[a, b, "de la rive droite"], [b, a, "de la rive gauche"]]:
			var d3: Vector2 = (sens[1] - sens[0]).normalized()
			var rive: Vector2 = sens[0] - d3 * 2.5
			p.global_position = Vector3(rive.x, s.hauteur(rive.x, rive.y) + 0.3, rive.y)
			p.velocity = Vector3.ZERO
			p.rotation.y = atan2(-d3.x, -d3.y)
			await _attendre(0.5)
			p.auto_move = Vector3(0, 0, -1)
			await _attendre(5.0)
			p.auto_move = Vector3.ZERO
			var avance: float = (Vector2(p.global_position.x, p.global_position.z) - rive).dot(d3)
			check(avance > 5.0 and p.global_position.y > float(data.niveau_eau) + 1.0, "l'habitant monte sur le pont %s (%.1f unités, y %.2f)" % [sens[2], avance, p.global_position.y])
		vue.basculer(s)

	# Le stade municipal, rive gauche : le nœud de la structure, et son entrée qui ouvre le stade du socle.
	var terrain := s.find_child("Stade", false, false)
	check(terrain != null and terrain.find_child("Pelouse", false, false) != null, "le terrain de football est dessiné, nœud « Stade » de la structure terrain_foot")
	var entree: Node = terrain.find_child("Entree", false, false) if terrain else null
	check(entree is Area3D and entree.get_meta("interact") == "stade" and entree.has_meta("prompt"), "l'entrée du stade est une zone à E, avec son invite")
	check(root.get_node("Registre").structure("availles_limouzine/stade").get("noeud", "") == "Stade", "le registre connaît le nœud du terrain")
	if entree:
		s._interagir(entree)
		await process_frame
		await process_frame
		await process_frame
		check(current_scene != null and current_scene.scene_file_path.ends_with("stade.tscn"), "E sur l'entrée ouvre le stade du socle (%s)" % (current_scene.scene_file_path if current_scene else "rien"))
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


func _attendre(s: float) -> void:
	await create_timer(s, true).timeout


static func _textes(n: Node) -> Array:
	var out := []
	if n is Label:
		out.append(str(n.text))
	for c in n.get_children():
		out.append_array(_textes(c))
	return out
