extends SceneTree
## Les communes « ailleurs » (socle 1.5) : godot --headless --path . -s tools/test_ailleurs.gd
## Le champ « ailleurs » et ses refus ; Casino Minuit (tools/paquet_essai/casino_minuit/), emballé ici,
## se greffe sans code INSEE ; on y vole depuis Poitiers-Biard, on y marche jusqu'à la galerie par le
## grand escalier, les coulisses restent closes sous leur seuil puis mènent au sous-sol par l'escalier du
## personnel, le stade de la Fortune s'ouvre à son seuil, habillé par Minuit, et son club entre au
## championnat ; on sort à pied sur le Strip (lot E), l'arène et la salle de concert (lot F) restent closes
## sous leur seuil puis s'ouvrent ; le voiturier et la station de taxis ouvrent la carte, et le vol retour ramène
## à Smarves.

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
	# Le dedans est habité par les PNJ de l'original (pnj/pnj.gd ; leur vie : tools/test_minuit_vie.gd).
	var pnj = s.get("pnj")
	var gens: Array = pnj.all if pnj != null else []
	check(gens.size() > 90, "les PNJ de l'original peuplent le casino (%d)" % gens.size())
	p.global_position = Vector3(-16, 6.05, -19)
	p.rotation.y = 0.0
	p.velocity = Vector3.ZERO
	await create_timer(0.3, true).timeout
	p.auto_move = Vector3(-1, 0, 0)
	await create_timer(3.0, true).timeout
	p.auto_move = Vector3.ZERO
	check(p.global_position.x < -21.0 and p.global_position.y > 5.6, "la baie ouest de la galerie ouvre sur le jardin d'hiver (%.1f, %.1f, %.1f)" % [p.global_position.x, p.global_position.y, p.global_position.z])

	# Le lot C, l'est : ses salles sont bâties et peuplées ; de l'atrium on passe dans la fosse aux tables, et
	# l'escalator de la fosse se gravit jusqu'aux boutiques de la mezzanine.
	manquantes = []
	for z in ["R-FOYER", "R-PIT", "R-CAGE", "R-CLUB", "R-WC-E", "R-SPORTS", "M-RESTAURANT", "M-BOUTIQUES"]:
		if s.get_node_or_null(z) == null:
			manquantes.append(z)
	check(manquantes.is_empty(), "les salles de l'est sont bâties %s" % str(manquantes))
	check(places.has("pit_bj") and places.has("cage_caissiers") and places.has("resto_dineurs") and places.has("boutiques_tour"), "elles notent les places de leurs figurants")
	var est := 0
	for n in gens:
		if n.x > 18.5 and n.z < 28.0:
			est += 1
	check(est > 15, "on en voit à l'est (%d)" % est)
	p.global_position = Vector3(15.0, 0.05, -1.5)
	p.rotation.y = 0.0
	p.velocity = Vector3.ZERO
	await create_timer(0.3, true).timeout
	p.auto_move = Vector3(1, 0, 0)
	await create_timer(2.5, true).timeout
	p.auto_move = Vector3.ZERO
	check(p.global_position.x > 20.0 and absf(p.global_position.y) < 0.2, "la colonnade est de l'atrium ouvre sur la fosse (%.1f, %.1f, %.1f)" % [p.global_position.x, p.global_position.y, p.global_position.z])
	p.global_position = Vector3(22.0, 0.05, -11.15)
	p.velocity = Vector3.ZERO
	await create_timer(0.3, true).timeout
	p.auto_move = Vector3(1, 0, 0)
	await create_timer(5.5, true).timeout
	p.auto_move = Vector3.ZERO
	check(p.global_position.y > 5.6 and p.global_position.x > 31.8, "l'escalator monte aux boutiques (%.1f, %.1f, %.1f)" % [p.global_position.x, p.global_position.y, p.global_position.z])
	var caisse: Node = s.find_child("caisse", true, false)
	check(caisse != null, "la caisse est une interaction")
	if caisse != null:
		p.interact.emit(caisse)
		await process_frame
		check(str(s.get("_message").text).contains("1 jeton = 1 crédit"), "la caisse annonce le taux : %s" % s.get("_message").text)
	# Les tables de l'original sont jouables avec les jeux du socle ; celles sous housse restent fermées.
	check(s.find_child("table_poker-2", true, false) == null, "la table de poker sous housse n'est pas jouable")
	var bj: Node = s.find_child("table_bj-1", true, false)
	check(bj != null and str(bj.get_meta("prompt", "")).contains("blackjack"), "la table de blackjack de la fosse invite à s'asseoir")
	if bj != null:
		p.interact.emit(bj)
		await process_frame
		var pn: Control = s.get("_tables").get("_panneau")
		check(pn != null and p.frozen and str(pn.get_script().resource_path).ends_with("blackjack_panel.gd"),
			"s'asseoir au blackjack ouvre le panneau du socle")
		if pn != null:
			var gagne_avant: int = root.get_node("Game").won
			pn.played.emit(100, 250)
			check(root.get_node("Game").won == gagne_avant + 250, "un gain à la table compte au total gagné")
			pn.closed.emit()
			await process_frame
			check(not p.frozen and s.get("_tables").get("_panneau") == null, "se lever referme le jeu")
	# Le poker à plusieurs, sans réseau : une salle posée à la main (la vue de l'action « salle »).
	var tb = s.get("_tables")
	var salle := {"tables": [
		{"id": "minuit:poker-1", "nom": "Table 1", "joueurs": ["A", "B", "C", "D", "E", "F"], "libres": 0, "moi": false},
		{"id": "minuit:poker-3", "nom": "Table 2", "joueurs": ["G", "H"], "libres": 4, "moi": false},
		{"id": "minuit:poker-5", "nom": "Table 3", "joueurs": [], "libres": 6, "moi": false}],
		"attente": {"longueur": 0, "rang": null}}
	tb.essai_salle = salle
	check(s.find_child("salle_poker", true, false) != null, "la salle du poker s'ouvre au mur des tournois")
	var pk1: Node = s.find_child("table_poker-1", true, false)
	if pk1 != null:
		p.interact.emit(pk1)
		await process_frame
		check(tb.get("_panneau") == null and str(s.get("_message").text).contains("table 2 a 4 chaises"),
			"une table pleine renvoie à celle qui se remplit : %s" % s.get("_message").text)
	var pk3: Node = s.find_child("table_poker-3", true, false)
	if pk3 != null:
		p.interact.emit(pk3)
		await process_frame
		var pm: Control = tb.get("_panneau")
		check(pm != null and str(pm.get_script().resource_path).ends_with("poker_multi.gd") and pm.table_id == "minuit:poker-3"
			and str(pm.title).contains("table 2"), "la table 2 ouvre le poker à plusieurs du socle, sur sa table au serveur")
		if pm != null:
			check(pm.avec_table({"cave": 3000}) == {"cave": 3000, "table": "minuit:poker-3"}, "chaque demande nomme la table")
			pm.closed.emit()
			await process_frame
	# Toutes pleines : la salle s'ouvre, l'inscrit est appelé à la table dont les chaises couvrent son rang.
	var pleine := salle.duplicate(true)
	for t in pleine.tables:
		t.libres = 0
	tb.essai_salle = pleine
	if pk1 != null:
		p.interact.emit(pk1)
		await process_frame
		var sp: Control = tb.get("_panneau")
		check(sp != null and str(sp.get_script().resource_path).ends_with("salle_poker.gd") and sp.complete(pleine),
			"toutes les tables pleines : la salle et sa liste d'attente")
		if sp != null:
			var appel := pleine.duplicate(true)
			appel.attente = {"longueur": 2, "rang": 2}
			appel.tables[2].libres = 1
			check(sp.appelee(appel) == "", "une chaise pour deux inscrits : le second attend encore")
			appel.tables[1].libres = 2
			check(sp.appelee(appel) == "minuit:poker-3", "deux chaises : le second est appelé")
			sp.montrer(appel)
			await process_frame
			var pm2: Control = tb.get("_panneau")
			check(pm2 != null and pm2.table_id == "minuit:poker-3", "appelé, on s'assoit à sa table")
			if pm2 != null:
				pm2.closed.emit()
				await process_frame
	tb.essai_salle = {}
	check(not p.frozen and tb.get("_panneau") == null, "on se lève du poker")

	# Le lot D, les coulisses : ses salles sont bâties et peuplées ; sous le seuil du lieu, ses portes restent
	# closes ; au seuil, de la fosse on passe au couloir de service, et l'escalier du personnel descend à l'épine.
	manquantes = []
	for z in ["R-SERVICE", "R-ARRIERE", "ESC-STAFF", "B-COULOIR", "B-COMPTAGE", "B-ANTICHAMBRE", "B-COFFRE", "B-SECURITE",
			"B-ENTRETIEN", "B-VESTIAIRE", "B-CUISINE", "B-QUAI"]:
		if s.get_node_or_null(z) == null:
			manquantes.append(z)
	check(manquantes.is_empty(), "les coulisses sont bâties %s" % str(manquantes))
	check(places.has("d_secu") and places.has("d_comptage") and places.has("d_cuisine") and places.has("d_quai") and places.has("d_couloir_ronde"), "elles notent les places de leurs figurants")
	var coulisses := 0
	for n in gens:
		if n.kind == "staff" and pnj.is_staff_zone(n.x, n.z, n.level):
			coulisses += 1
	check(coulisses > 8, "le personnel travaille aux coulisses (%d)" % coulisses)
	var game: Node = root.get_node("Game")
	var gagne: int = game.won
	game.won = 0
	reload_current_scene()
	await create_timer(0.8, true).timeout
	s = current_scene
	p = s.player if s != null else null
	if p == null:
		game.won = gagne
		_fin()
		return
	var porte_c: Node = s.find_child("coulisses", true, false)
	check(porte_c != null, "sous son seuil, les portes des coulisses sont closes, avec leur invite")
	p.global_position = Vector3(34.6, 0.05, 2.0)
	p.velocity = Vector3.ZERO
	await create_timer(0.3, true).timeout
	p.auto_move = Vector3(1, 0, 0)
	await create_timer(1.5, true).timeout
	p.auto_move = Vector3.ZERO
	check(p.global_position.x < 35.9, "la porte du personnel de la fosse est close (x %.2f)" % p.global_position.x)
	if porte_c != null:
		p.interact.emit(porte_c)
		await process_frame
		check(str(s.get("_message").text).contains("coulisses") and str(s.get("_message").text).contains("60"), "elle annonce son seuil : %s" % s.get("_message").text)
	var coffre: Node = s.find_child("coffre", true, false)
	check(coffre != null, "la porte du coffre est une interaction")
	if coffre != null:
		p.interact.emit(coffre)
		await process_frame
		check(str(s.get("_message").text).contains("coffre"), "le coffre reste clos : %s" % s.get("_message").text)
	game.won = 60000
	reload_current_scene()
	await create_timer(0.8, true).timeout
	s = current_scene
	p = s.player if s != null else null
	if p == null:
		game.won = gagne
		_fin()
		return
	check(s.find_child("coulisses", true, false) == null, "au seuil, les portes des coulisses sont ouvertes")
	p.global_position = Vector3(34.6, 0.05, 2.0)
	p.velocity = Vector3.ZERO
	await create_timer(0.3, true).timeout
	p.auto_move = Vector3(1, 0, 0)
	await create_timer(2.0, true).timeout
	p.auto_move = Vector3.ZERO
	check(p.global_position.x > 36.5 and absf(p.global_position.y) < 0.2, "la porte L25 mène au couloir de service (%.1f, %.1f, %.1f)" % [p.global_position.x, p.global_position.y, p.global_position.z])
	# Du couloir de service, l'escalier du personnel : la volée est descend au demi-palier, la volée ouest à l'épine.
	p.global_position = Vector3(38.0, 0.05, 1.0)
	p.velocity = Vector3.ZERO
	await create_timer(0.3, true).timeout
	for etape in [[Vector3(0, 0, -1), 2.0], [Vector3(1, 0, 0), 0.3], [Vector3(0, 0, -1), 2.5], [Vector3(-1, 0, 0), 0.45], [Vector3(0, 0, 1), 3.0], [Vector3(-1, 0, 0), 1.5]]:
		p.auto_move = etape[0]
		await create_timer(etape[1], true).timeout
	p.auto_move = Vector3.ZERO
	check(p.global_position.x < 35.8 and p.global_position.y < -4.5, "l'escalier du personnel descend à l'épine du sous-sol (%.1f, %.1f, %.1f)" % [p.global_position.x, p.global_position.y, p.global_position.z])
	game.won = gagne

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
	gagne = game.won
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

	# Le lot E, dehors : ses zones sont bâties et peuplées ; on sort à pied par la porte-tambour sur le parvis, la
	# vue s'ouvre (le ciel, le lointain) et le dedans s'efface derrière soi.
	manquantes = []
	for z in ["X-STRIP", "X-FACADE", "X-FONTAINES", "X-BOULEVARD", "X-ENFACE", "F-ARENE", "F-ARENE-SALLE", "F-CONCERT", "F-CONCERT-SAS"]:
		if s.get_node_or_null(z) == null:
			manquantes.append(z)
	check(manquantes.is_empty(), "le dehors, l'arène et la salle de concert sont bâtis %s" % str(manquantes))
	places = s.K.places
	check(places.has("e_promenade_casino") and places.has("e_fontaines") and places.has("e_file_arene") and places.has("f_gradins") and places.has("f_musiciens"), "elles notent les places de leurs figurants")
	figurants = s.get_node_or_null("Figurants")
	var groupes := {}
	for g in ["Dehors", "Arene", "Concert"]:
		var n: Node = figurants.get_node_or_null(g) if figurants else null
		groupes[g] = n.get_child_count() if n else 0
	check(groupes.Dehors > 40 and groupes.Arene > 40 and groupes.Concert > 30, "dehors, à l'arène et au concert, des figurants %s" % str(groupes))
	p.global_position = Vector3(1.5, 0.05, 27.0)
	p.rotation.y = 0.0
	p.velocity = Vector3.ZERO
	await create_timer(0.3, true).timeout
	p.auto_move = Vector3(0, 0, 1)
	await create_timer(6.5, true).timeout
	p.auto_move = Vector3.ZERO
	await process_frame
	check(p.global_position.z > 46.0 and absf(p.global_position.y) < 0.2, "la porte-tambour mène au parvis et au trottoir du Strip (%.1f, %.1f, %.1f)" % [p.global_position.x, p.global_position.y, p.global_position.z])
	check(s.camera.far > 600.0 and not s.get_node("R-PIT").visible and s.get_node("X-FONTAINES").visible, "dehors, la vue porte loin et le dedans s'efface")
	var fontaines: Node = s.find_child("fontaines", true, false)
	check(fontaines != null, "le pupitre des fontaines est une interaction")
	if fontaines != null:
		p.interact.emit(fontaines)
		await process_frame
		await process_frame
		check(bool(fontaines.get_meta("etat").en_cours), "il lance le spectacle des fontaines : %s" % s.get("_message").text)

	# Le lot F : l'arène et Minuit Live restent closes sous leur seuil, s'ouvrent au-delà.
	gagne = game.won
	game.won = 0
	reload_current_scene()
	await create_timer(0.8, true).timeout
	s = current_scene
	p = s.player if s != null else null
	if p == null:
		game.won = gagne
		_fin()
		return
	for t in [["arene", Vector3(0.0, 0.05, 86.0), Vector3(0, 0, 1), "150"], ["concert", Vector3(16.05, 0.05, -27.4), Vector3(0, 0, -1), "90"]]:
		var lieu: Node = s.find_child(t[0], true, false)
		check(lieu != null, "sous son seuil, « %s » est close, avec son invite" % t[0])
		p.global_position = t[1]
		p.velocity = Vector3.ZERO
		await create_timer(0.3, true).timeout
		p.auto_move = t[2]
		await create_timer(2.5, true).timeout
		p.auto_move = Vector3.ZERO
		var dedans: bool = p.global_position.z > 90.2 if t[0] == "arene" else p.global_position.z < -30.3
		check(not dedans, "sa porte ne laisse pas passer (%.1f, %.1f)" % [p.global_position.x, p.global_position.z])
		if lieu != null:
			p.interact.emit(lieu)
			await process_frame
			check(str(s.get("_message").text).contains(t[3]), "elle annonce son seuil : %s" % s.get("_message").text)
	game.won = 150000
	reload_current_scene()
	await create_timer(0.8, true).timeout
	s = current_scene
	p = s.player if s != null else null
	if p == null:
		game.won = gagne
		_fin()
		return
	check(s.find_child("arene", true, false) == null and s.find_child("concert", true, false) == null, "au seuil, l'arène et la salle de concert sont ouvertes")
	for t in [["arene", Vector3(0.0, 0.05, 86.0), Vector3(0, 0, 1)], ["concert", Vector3(16.05, 0.05, -27.4), Vector3(0, 0, -1)]]:
		p.global_position = t[1]
		p.velocity = Vector3.ZERO
		await create_timer(0.3, true).timeout
		p.auto_move = t[2]
		await create_timer(3.0, true).timeout
		p.auto_move = Vector3.ZERO
		var dedans: bool = p.global_position.z > 94.0 if t[0] == "arene" else p.global_position.z < -32.0
		check(dedans and absf(p.global_position.y) < 0.2, "on entre dans « %s » (%.1f, %.1f, %.1f)" % [t[0], p.global_position.x, p.global_position.y, p.global_position.z])
		check(s.get_node("F-ARENE-SALLE" if t[0] == "arene" else "F-CONCERT").visible, "la salle se montre quand on y entre")
	var cloche: Node = s.find_child("cloche", true, false)
	check(cloche != null, "la cloche du chronométreur est une interaction")
	if cloche != null:
		p.interact.emit(cloche)
		await process_frame
		check(str(s.get("_message").text).begins_with("Ding"), "elle sonne : %s" % s.get("_message").text)
	game.won = gagne

	# Repartir : de dehors, le voiturier de la porte-cochère et la station de taxis ouvrent la carte de Las Vegas.
	p.global_position = Vector3(-9.6, 0.05, 36.0)
	p.velocity = Vector3.ZERO
	await create_timer(0.3, true).timeout
	check(s.find_child("sortie", true, false) != null and s.find_child("sortie", true, false).get_parent().name == "X-FACADE", "le voiturier est dehors, à la porte-cochère")
	var taxi: Node = s.find_child("taxi_aeroport", true, false)
	check(taxi != null and taxi.get_meta("interact", "") == "sortie", "la station de taxis d'en face mène aussi à l'aéroport")
	var sortie: Node = s.find_child("sortie", true, false)
	for borne in [taxi, sortie]:
		if borne != null:
			p.interact.emit(borne)
			await process_frame
			check(carte.is_open(), "« %s » ouvre la carte" % borne.get_meta("prompt", ""))
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
