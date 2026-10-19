extends SceneTree
## Les communes « ailleurs » (socle 1.5) : godot --headless --path . -s tools/test_ailleurs.gd
## Le champ « ailleurs » et ses refus ; Casino Minuit (tools/paquet_essai/casino_minuit/), emballé ici,
## se greffe sans code INSEE ; on y vole depuis Poitiers-Biard, on y marche jusqu'à la galerie par le
## grand escalier, le stade de la Fortune s'ouvre à son seuil, habillé par Minuit, et son club entre au
## championnat ; la porte du Strip ouvre la carte, et le vol retour ramène à Smarves.

const SOURCE := "res://tools/paquet_essai/casino_minuit/"
const TMP := "user://test_ailleurs/"

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	_champ()
	var communes: Node = root.get_node("Communes")
	var carte: Node = root.get_node("Carte")
	DirAccess.make_dir_recursive_absolute(TMP)
	communes.dossier_greffes = TMP
	var pck := TMP + "casino_minuit.pck"
	var pk := PCKPacker.new()
	pk.pck_start(pck)
	_emballer(pk, SOURCE, SOURCE)
	pk.flush()
	check(communes.charger_pack(pck) == "casino_minuit", "Casino Minuit se greffe %s" % str(communes.refus))
	var c: Commune = communes.commune("casino_minuit")
	if c == null:
		_fin()
		return
	check(c.valide() and c.lointaine() and c.insee == "", "elle est valide, lointaine et sans code INSEE %s" % str(c.erreurs))
	check(c.ville() == "Las Vegas" and c.aeroport() == "McCarran", "elle est à Las Vegas, par McCarran")
	check(communes.lointaines() == ["casino_minuit"], "elle est la seule destination lointaine")
	check(communes.par_insee("") == null, "aucune commune ne répond au code INSEE vide")

	# L'aller : le vol depuis Poitiers-Biard pose dans la rotonde.
	carte.duree_vol = 0.2
	carte.voler("casino_minuit")
	await create_timer(1.6, true).timeout
	var s: Node = current_scene
	check(s != null and s.scene_file_path == str(c.data.scene), "le vol pose à Casino Minuit")
	check(communes.actuelle() == "casino_minuit", "on y est : %s" % communes.actuelle())
	if s == null or not (s.get("player") is CharacterBody3D):
		_fin()
		return
	var p: CharacterBody3D = s.player
	await create_timer(0.6, true).timeout
	check(p.is_on_floor() and absf(p.global_position.y) < 0.2, "l'arrivée est au sol de la rotonde (y %.2f)" % p.global_position.y)

	# Le carnet du socle s'ouvre ici comme partout (touche C), et se referme.
	var carnet: Node = root.get_node("Carnet")
	var touche := InputEventKey.new()
	touche.keycode = KEY_C
	touche.pressed = true
	Input.parse_input_event(touche)
	await process_frame
	await process_frame
	check(carnet.is_open(), "le carnet s'ouvre dans Casino Minuit")
	if carnet.is_open():
		carnet.toggle()
		await process_frame

	# Par la volée ouest du grand escalier, jusqu'à la galerie (y 6).
	p.global_position = Vector3(-9, 0.05, -11.0)
	p.rotation.y = 0.0
	p.velocity = Vector3.ZERO
	await create_timer(0.3, true).timeout
	p.auto_move = Vector3(0, 0, -1)
	await create_timer(6.0, true).timeout
	p.auto_move = Vector3.ZERO
	check(p.global_position.y > 5.6 and p.global_position.z < -24.5, "le grand escalier monte à la galerie (%.1f, %.1f, %.1f)" % [p.global_position.x, p.global_position.y, p.global_position.z])

	# Le lot B, l'ouest : ses salles sont bâties, peuplées, et la baie ouest de la galerie mène au jardin d'hiver.
	var manquantes := []
	for z in ["R-LOBBY", "R-SALON", "R-MACHINES", "R-POKER", "R-HL", "R-WC-O", "M-LOUNGE", "M-JARDIN", "M-WC"]:
		if s.get_node_or_null(z) == null:
			manquantes.append(z)
	check(manquantes.is_empty(), "les salles de l'ouest sont bâties %s" % str(manquantes))
	var places: Dictionary = s.K.places
	check(places.has("poker") and places.has("lounge_bar") and places.has("jardin_tour"), "elles notent les places de leurs figurants")
	var figurants: Node = s.get_node_or_null("Figurants")
	check(figurants != null and figurants.get_child_count() > 120, "le lot B a ses figurants (%d en tout)" % (figurants.get_child_count() if figurants else 0))
	p.global_position = Vector3(-16, 6.05, -19)
	p.rotation.y = 0.0
	p.velocity = Vector3.ZERO
	await create_timer(0.3, true).timeout
	p.auto_move = Vector3(-1, 0, 0)
	await create_timer(3.0, true).timeout
	p.auto_move = Vector3.ZERO
	check(p.global_position.x < -21.0 and p.global_position.y > 5.6, "la baie ouest de la galerie ouvre sur le jardin d'hiver (%.1f, %.1f, %.1f)" % [p.global_position.x, p.global_position.y, p.global_position.z])

	# Le club : son terrain est au registre, rattaché à Poitiers(-Biard) sur la carte.
	var terrain := {}
	for e in root.get_node("Registre").de_commune("casino_minuit"):
		if e.type == "terrain_foot":
			terrain = e
	check(not terrain.is_empty() and terrain.champs.get("club") == "Racing Club Minuit", "le Racing Club Minuit a son terrain au registre")
	check(not terrain.is_empty() and terrain.centre == Vienne.centre(CarteVienne.POITIERS_INSEE), "son terrain est placé à Poitiers sur la carte")
	var foot: Node = root.get_node("Football")
	foot.actualiser()
	var inscrit := false
	for id in foot.clubs:
		inscrit = inscrit or str(foot.clubs[id].get("commune", "")) == "casino_minuit"
	check(inscrit or foot.en_attente().has("casino_minuit"), "il entre au championnat de la Vienne")
	# Une obligation du club de Minuit compte au carnet, avec celles de l'Étoile (le carnet les prend toutes).
	var avant: Dictionary = foot.obligations_locales.duplicate(true)
	foot.obligations_locales["casino_minuit"] = [1]
	check(root.get_node("Carnet").call("_obligations").has("casino_minuit"), "une obligation du Racing Club Minuit compte au carnet")
	foot.obligations_locales = avant

	# Le stade de la Fortune : fermé sous son seuil, puis le stade du socle avec l'habillage de Minuit.
	var game: Node = root.get_node("Game")
	var gagne: int = game.won
	game.won = 0
	var porte: Node = s.find_child("stade", true, false)
	check(porte != null, "la porte du stade de la Fortune est une interaction")
	if porte != null:
		p.interact.emit(porte)
		await create_timer(0.3, true).timeout
		check(current_scene == s, "sous son seuil, le stade reste fermé")
		game.won = 5000
		p.interact.emit(porte)
		await create_timer(1.0, true).timeout
		var st: Node = current_scene
		check(st != null and st.scene_file_path == "res://scenes/stade.tscn", "au seuil, la porte ouvre le stade")
		check(st != null and st.get_node_or_null("Habillage") != null, "le stade porte l'habillage de Minuit")
		if st != null:
			check(st.call("_nom_club") == "Racing Club Minuit", "c'est le stade du Racing Club Minuit")
			var sortie_stade: Node = st.find_child("exit", true, false)
			if sortie_stade == null:
				for n in st.find_children("*", "Area3D", true, false):
					if n.get_meta("interact", "") == "exit":
						sortie_stade = n
			if sortie_stade != null:
				st.call("_on_interact", sortie_stade)
			await create_timer(1.0, true).timeout
			s = current_scene
			check(s != null and s.scene_file_path == str(c.data.scene), "la sortie du stade ramène au casino")
			if s != null and s.get("player") is CharacterBody3D:
				p = s.player
				check(p.global_position.distance_to(Vector3(12.6, 0.05, -17.0)) < 1.0, "devant la porte du stade (%.1f, %.1f)" % [p.global_position.x, p.global_position.z])
	game.won = gagne
	if s == null or not (s.get("player") is CharacterBody3D):
		_fin()
		return

	# La porte du Strip : la carte s'ouvre sur Las Vegas.
	var sortie: Node = s.find_child("sortie", true, false)
	check(sortie != null and sortie.get_meta("interact", "") == "sortie", "la porte du Strip est une interaction")
	if sortie != null:
		p.interact.emit(sortie)
		await process_frame
		check(carte.is_open(), "sortir sur le Strip ouvre la carte")
		carte.fermer()
		await create_timer(0.8, true).timeout

	# Le retour.
	carte.voler()
	await create_timer(2.0, true).timeout
	check(current_scene != null and current_scene.scene_file_path == str(communes.origine().data.scene), "le vol retour ramène à Smarves")
	check(communes.actuelle() == communes.ORIGINE, "on est rentré : %s" % communes.actuelle())
	_fin()


## Le champ « ailleurs » : ce qu'il accepte, ce qu'il refuse.
func _champ() -> void:
	var bon := {"insee": "", "socle_min": "1.5", "ailleurs": {"ville": "Las Vegas", "pays": "États-Unis", "aeroport": "McCarran", "vol": "MN 1203"}}
	check(Commune.verifier_ailleurs(bon).is_empty(), "un « ailleurs » complet est accepté")
	check(Commune.verifier_ailleurs({"socle_min": "1.5", "ailleurs": {"ville": "Macao"}}).is_empty(), "la ville suffit")
	check(not Commune.verifier_ailleurs({"socle_min": "1.5", "ailleurs": "Las Vegas"}).is_empty(), "un « ailleurs » qui n'est pas un objet est refusé")
	check(not Commune.verifier_ailleurs({"socle_min": "1.5", "ailleurs": {"pays": "Chine"}}).is_empty(), "un « ailleurs » sans ville est refusé")
	check(not Commune.verifier_ailleurs({"socle_min": "1.4", "ailleurs": {"ville": "Macao"}}).is_empty(), "un « ailleurs » sous le socle 1.5 est refusé")
	check(not Commune.verifier_ailleurs({"insee": "86263", "socle_min": "1.5", "ailleurs": {"ville": "Macao"}}).is_empty(), "un « ailleurs » avec un code INSEE est refusé")
	check(not Commune.verifier_ailleurs({"socle_min": "1.5", "ailleurs": {"ville": "Macao", "fuseau": 8}}).is_empty(), "un champ inconnu est refusé")
	check(not Commune.verifier_ailleurs({"socle_min": "1.5", "ailleurs": {"ville": 3}}).is_empty(), "un champ mal typé est refusé")


func _emballer(pk: PCKPacker, dossier: String, racine: String) -> void:
	var d := DirAccess.open(dossier)
	for f in d.get_files():
		if not f.ends_with(".uid"):
			pk.add_file("res://communes/casino_minuit/" + (dossier + f).trim_prefix(racine), dossier + f)
	for sous in d.get_directories():
		_emballer(pk, dossier + sous + "/", racine)


func _fin() -> void:
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
