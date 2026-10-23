extends SceneTree
## Vérifie la salle de jeu du socle sans affichage : godot --headless --path . -s tools/test_salle_jeu.gd
## Le vocabulaire accepte une « salle_jeu » et refuse un jeu ou un décor inconnus ; une commune en pack
## (tools/fixtures/salle_jeu/) inscrit ses deux salles au registre ; le tripot s'ouvre, pose une table
## par jeu (celles du casino de Smarves, scripts/socle/tables.gd), on s'y assoit, chaque jeu ouvre son
## panneau et un gain s'encaisse ; le cercle reste fermé tant que le lieu
## du même id n'a pas atteint son seuil ; la porte ramène dans la commune. Son notaire met ses adresses au
## catalogue sous « essai_salle/<id> », financées par sa banque, et son étude ouvre son registre.

const ESSAI := "res://tools/fixtures/salle_jeu/"
const TMP := "user://test_salle_jeu/"

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var structures: GDScript = load("res://scripts/socle/structures.gd")
	var salle_jeu: GDScript = load("res://scripts/socle/salle_jeu.gd")
	var game: Node = root.get_node("Game")
	var communes: Node = root.get_node("Communes")
	var registre: Node = root.get_node("Registre")

	var bonne := {"type": "salle_jeu", "id": "tripot", "nom": "Le tripot", "jeux": ["machine", "poker"], "graine": 3.0}
	check(structures.verifier([bonne]).is_empty(), "une salle de jeu se déclare %s" % str(structures.verifier([bonne])))
	var e: PackedStringArray = structures.verifier([{"type": "salle_jeu", "id": "x", "nom": "X", "jeux": ["belote"], "decor": "grotte"}])
	check(e.size() == 2, "un jeu et un décor inconnus sont refusés %s" % str(e))
	check(not structures.verifier([{"type": "salle_jeu", "id": "x", "nom": "X", "jeux": []}]).is_empty(), "une salle sans jeu est refusée")
	check(structures.verifier([bonne, bonne.merged({"id": "autre"}, true)]).is_empty(), "une commune peut avoir plusieurs salles")
	for j in structures.JEUX:
		check(salle_jeu.JEUX.has(j), "le jeu « %s » a son panneau" % j)

	DirAccess.make_dir_recursive_absolute(TMP)
	var pck := TMP + "essai_salle.pck"
	var pk := PCKPacker.new()
	pk.pck_start(pck)
	pk.add_file("res://communes/essai_salle/commune.json", ESSAI + "commune.json")
	pk.add_file("res://communes/essai_salle/commune.tscn", ESSAI + "commune.tscn")
	pk.flush()
	communes.dossier_greffes = TMP
	check(communes.charger_pack(pck) == "essai_salle", "la commune d'essai se greffe avec ses salles %s" % str(communes.refus))
	check(registre.de_commune("essai_salle").filter(func(e): return e.type == "salle_jeu").size() == 2, "ses deux salles sont au registre")
	check(communes.ouvrir("essai_salle"), "le pack s'ouvre")

	game.won = 0
	check(not salle_jeu.ouverte("essai_salle", "cercle"), "le cercle est fermé sous son seuil (%d)" % salle_jeu.seuil("essai_salle", "cercle"))
	check(not salle_jeu.ouvrir("essai_salle", "cercle"), "  et ouvrir() le refuse")
	check(salle_jeu.ouverte("essai_salle", "tripot"), "le tripot, sans lieu du même id, est ouvert")
	check(not salle_jeu.ouverte("essai_salle", "inconnue"), "une salle inconnue ne s'ouvre pas")
	game.won = 40000
	check(salle_jeu.ouverte("essai_salle", "cercle"), "le cercle ouvre à 40 000 gagnés")
	game.won = 0

	check(salle_jeu.ouvrir("essai_salle", "tripot"), "le tripot s'ouvre")
	await process_frame
	await process_frame
	var s: Node = current_scene
	check(s != null and s.get("commune") == "essai_salle", "on est dans le tripot de la commune")
	if s == null:
		_fin()
		return
	var tables := []
	for a in s.find_children("*", "Area3D", true, false):
		if a.get_meta("interact", "") == "jeu":
			tables.append(str(a.get_meta("jeu")))
	check(tables.size() == 10, "une table ou une machine par jeu : %s" % ", ".join(tables))
	check(salle_jeu.table_serveur("essai_salle", "tripot") == "salle:essai_salle:tripot", "connecté, le poker du tripot se joue à plusieurs à sa table du serveur")
	# La table partagée d'une commune (Partage) : mêmes règles que le serveur, et rien ne bloque sans compte.
	check(Partage.refus("essai_salle", "plaque.sorties", [{"a": 1}]) == "", "une clé partagée bien formée passe")
	check(Partage.refus("Essai", "plaque") != "" and Partage.refus("essai_salle", "a b") != "", "une commune ou une clé mal formée est refusée")
	check(Partage.refus("essai_salle", "plaque", "x".repeat(Partage.OCTETS)) != "", "une valeur de plus de 4 Ko est refusée")
	var hors: Dictionary = await Partage.lire("essai_salle", "plaque")
	check(not hors.ok and hors.erreur != "", "sans compte, la lecture rend ok faux et une raison : %s" % hors.erreur)
	check(Partage.reponse({"code": 200, "corps": {"valeur": [1]}}) == {"ok": true, "valeur": [1], "erreur": ""}, "une réponse du serveur se lit")
	check(s._salle.host == "Mme Rivière" and s._salle.name == "Le tripot de la gare", "la tenancière et le nom viennent du manifeste")
	var tables3d: GDScript = load("res://scripts/socle/tables.gd")
	for j in tables:
		if tables3d.a_une_table(j):
			var t: Node = s._tables3d.get(j, null)
			check(t != null and t.get_script().resource_path == tables3d.MODELES[j], "le jeu « %s » a la table du casino (%s)" % [j, tables3d.MODELES[j].get_file()])
	check(s._panel_layer.get_parent().theme != null, "les panneaux sont habillés comme au casino")
	for j in tables:
		s._jeu_ouvert = j
		s.open_game()
		await process_frame
		check(s._game != null and s._game.has_signal("played"), "le jeu « %s » ouvre son panneau" % j)
		if tables3d.a_une_table(j) and s._game:
			check(s._assis == s._tables3d[j] and s._assis.active and s._game.get_parent() == s._panel_layer.get_parent(),
				"  on s'assoit à la table, le panneau en barre basse")
		if s._game:
			s._game.closed.emit()
			await process_frame
			check(s._assis == null, "  on se relève en refermant")
	var guichets := s.find_children("*", "Area3D", true, false).filter(func(a): return a.get_meta("interact", "") == "guichet")
	check(guichets.size() == 1, "le tripot a le guichet de la banque de la commune")
	if guichets.size() == 1:
		var brunet: int = game.debt_of(game.lender)
		var dette: int = game.debt_of("essai_salle")
		s._on_interact(guichets[0])
		await process_frame
		var pret: Node = s._game
		check(pret != null and pret.banque.get("nom", "") == "La Caisse de la gare", "le guichet est celui de la banque du manifeste")
		if pret:
			pret._borrow(500)
			check(game.debt_of("essai_salle") > dette and game.debt_of(game.lender) == brunet, "le prêt va au prêteur de la commune, pas à M. Brunet")
			check(pret._speech.text.contains("Caisse de la gare"), "le banquier dit les répliques de sa banque")
			pret.closed.emit()
			await process_frame
	var avant: int = game.credits
	s._on_played(10, 50)
	check(game.credits == avant + 50 and game.won >= 50, "un gain s'encaisse dans la bourse du socle")
	s._sortir()
	await process_frame
	await process_frame
	# Une commune en paquet s'ouvre derrière l'écran de chargement (socle 1.11).
	while root.get_node("Chargement").actif():
		await process_frame
	check(current_scene != null and current_scene.scene_file_path == "res://communes/essai_salle/commune.tscn" and game.return_point == "place",
		"la porte ramène dans la commune, devant la porte de la salle")
	await _etude(game)
	await _commerces(game)
	await _sorties()
	await _tarifs()
	await _sur_decors(game)
	_fin()


## L'étude du notaire de la commune d'essai : ses adresses au catalogue, l'achat financé par sa banque.
func _etude(game: Node) -> void:
	var biens: Node = root.get_node("Biens")
	var etude: GDScript = load("res://scripts/socle/etude.gd")
	var buffet: Dictionary = biens.item("essai_salle/buffet")
	check(buffet.get("price", 0) == 9000 and buffet.get("commune", "") == "essai_salle", "les adresses du notaire entrent au catalogue sous « essai_salle/<id> »")
	check(not biens.item("maison_place").is_empty() and not biens.item("maison_place").has("commune"), "  celles de la commune d'origine gardent leur id")
	check(biens.item("partie/inconnu").get("price", -1) == 0, "  un bien d'une commune absente est gardé sans rien valoir")
	var brunet: int = game.debt_of(game.lender)
	var avant: int = game.debt_of("essai_salle")
	check(biens.buy("essai_salle/buffet", true, "essai_salle"), "on achète les murs du buffet à crédit")
	check(biens.count("essai_salle/buffet") == 1 and game.debt_of("essai_salle") > avant and game.debt_of(game.lender) == brunet, "  la dette va à la banque de la commune")
	check(etude.ouvrir("essai_salle"), "l'étude de la commune s'ouvre")
	await process_frame
	await process_frame
	var s: Node = current_scene
	check(s != null and s.get("commune") == "essai_salle" and s._salle.host == "Maître Lucas", "on est chez Maître Lucas")
	if s != null:
		s.open_registre()
		await process_frame
		var p: Node = s._game
		check(p != null and p.commune == "essai_salle" and p._c().data.id == "essai_salle", "le registre ouvert est celui de la commune")
		if p:
			check(p._map != null and p._map.registre.adresses.size() == 2, "  son plan porte ses deux adresses")
			p._on_picked("buffet")
			await process_frame
			p.closed.emit()
			await process_frame
		s._sortir()
		await process_frame
		await process_frame
		# Une commune en paquet s'ouvre derrière l'écran de chargement (socle 1.11).
		while root.get_node("Chargement").actif():
			await process_frame
		check(current_scene != null and current_scene.scene_file_path == "res://communes/essai_salle/commune.tscn" and game.return_point == "place", "la porte de l'étude ramène dans la commune")
	biens.sell("essai_salle/buffet")


## La salle de jeu et l'étude sur un décor de la bibliothèque (socle 1.22, champ « modele ») : le socle n'y bâtit
## rien, il branche ses ancres.
func _sur_decors(game: Node) -> void:
	var registre: Node = root.get_node("Registre")
	var tripot: Dictionary = registre.structure("essai_salle/tripot")
	var champs_avant: Dictionary = tripot.champs.duplicate(true)
	tripot.champs.modele = "bar-des-sports@1"
	tripot.champs.jeux = ["poker", "machine", "blackjack", "roulette", "craps"]
	check(load("res://scripts/socle/salle_jeu.gd").ouvrir("essai_salle", "tripot"), "le tripot s'ouvre sur le bar des sports")
	await process_frame
	await process_frame
	var s: Node = current_scene
	var modele: Node = s.get_node_or_null("Modele") if s else null
	check(modele != null and Ancres.verifier_genre(modele, "salle_jeu").is_empty(), "le décor est posé et tient le contrat de la salle de jeu")
	if modele:
		var jeux := s.find_children("*", "Area3D", true, false).filter(func(a): return a.get_meta("interact", "") == "jeu").map(func(a): return str(a.get_meta("jeu")))
		check(jeux == ["poker", "machine", "blackjack", "roulette"], "une table par ancre, dans l'ordre des jeux ; le cinquième n'a pas de place : %s" % str(jeux))
		var t1: Node3D = Ancres.trouver(modele, "Table1")
		var poker: Node3D = s._tables3d.get("poker", null)
		check(poker != null and poker.global_position.distance_to(t1.global_position) < 0.01 and absf(poker.global_rotation.y - t1.global_rotation.y) < 0.01,
			"la table de poker est à sa place et tournée comme son ancre")
		check(s._keeper != null and s._keeper.global_position.distance_to(Ancres.trouver(modele, "Comptoir").global_position) < 0.01, "la tenancière est au comptoir")
		var arrivee: Node3D = Ancres.trouver(modele, "Arrivee")
		var ecart := Vector2(s.player.global_position.x - arrivee.global_position.x, s.player.global_position.z - arrivee.global_position.z)
		check(ecart.length() < 0.3, "on entre par l'arrivée du décor (à %.2f m)" % ecart.length())
		var enseigne: Label3D = Ancres.trouver(modele, "Enseigne").get_child(0)
		check(enseigne.text == "A U   T R I P O T", "l'enseigne de la salle s'écrit au portique, en capitales espacées : « %s »" % enseigne.text)
		check(s.find_children("*", "Area3D", true, false).filter(func(a): return a.get_meta("interact", "") == "exit").size() == 1, "la sortie est à la porte du décor")
		s._jeu_ouvert = "poker"
		s._table_choisie = null
		s.open_game()
		await process_frame
		check(s._game != null and s._assis == poker, "on s'assoit à la table de poker du décor")
		if s._game:
			s._game.closed.emit()
			await process_frame
		s._sortir()
		await process_frame
		await process_frame
		while root.get_node("Chargement").actif():
			await process_frame
	tripot.champs = champs_avant

	var c: Commune = root.get_node("Communes").commune("essai_salle")
	c.data.notaire.modele = "etude-de-notaire@1"
	check(load("res://scripts/socle/etude.gd").ouvrir("essai_salle"), "l'étude s'ouvre sur l'étude de notaire")
	await process_frame
	await process_frame
	s = current_scene
	modele = s.get_node_or_null("Modele") if s else null
	check(modele != null and Ancres.verifier_genre(modele, "etude").is_empty(), "le décor est posé et tient le contrat de l'étude")
	if modele:
		var notaire: Node = s._keeper.get_child(0)
		check(s._keeper.global_position.distance_to(Ancres.trouver(modele, "Notaire").global_position) < 0.01 and notaire.pose == 2, "Maître Lucas est assis à son bureau")
		check((Ancres.trouver(modele, "Enseigne").get_child(0) as Label3D).text == "L'étude de Maître Lucas"
			and (Ancres.trouver(modele, "Plaque").get_child(0) as Label3D).text == "Maître Lucas", "l'enseigne et la plaque disent l'étude et le notaire")
		check(Ancres.trouver(modele, "Plan").find_children("*", "MeshInstance3D", false, false).size() >= 3, "le plan du registre est dessiné au mur")
		var accueil := s.find_children("*", "Area3D", true, false).filter(func(a): return a.get_meta("interact", "") == "registre")
		check(accueil.size() == 1, "l'accueil ouvre aussi le registre")
		if accueil.size() == 1:
			s._on_interact(accueil[0])
			await process_frame
			check(s._game != null and s._game.commune == "essai_salle", "  le registre de la commune")
			if s._game:
				s._game.closed.emit()
				await process_frame
		s._sortir()
		await process_frame
		await process_frame
		while root.get_node("Chargement").actif():
			await process_frame
	c.data.notaire.erase("modele")


## Les commerces de la commune d'essai : leurs articles au catalogue, la vitrine, l'achat, et ce que le
## socle refuse dans un article.
func _commerces(game: Node) -> void:
	var biens: Node = root.get_node("Biens")
	var structures: GDScript = load("res://scripts/socle/structures.gd")
	var commerce: GDScript = load("res://scripts/socle/commerce.gd")
	var veste: Dictionary = biens.item("essai_salle/veste_chef")
	check(veste.get("kind", "") == "tenue" and veste.get("seller", "") == "commerce" and veste.get("commerce", "") == "essai_salle/mercerie",
		"les articles des commerces entrent au catalogue sous « essai_salle/<id> »")
	check(veste.get("color", Color.WHITE).is_equal_approx(Color.html("#1d3b6e")) and veste.get("charge", 0) == 3, "  une tenue a sa couleur et ses charges")
	check(biens.item("essai_salle/taxi").get("model", "").ends_with("car_taxi.gltf"), "  un véhicule a son modèle")
	check(biens.item("essai_salle/horloge_gare").get("slot", "") == "mur" and biens.item("essai_salle/horloge_gare").get("max", 0) == 2, "  un meuble a son emplacement")
	var brunet: int = game.debt_of(game.lender)
	check(biens.buy("essai_salle/veste_chef", true, "essai_salle"), "on achète la veste à crédit")
	check(biens.worn == "essai_salle/veste_chef" and game.debt_of(game.lender) == brunet, "  on la porte, et la dette va à la banque de la commune")
	check(commerce.ouvrir("essai_salle", "mercerie"), "la mercerie s'ouvre")
	check(not commerce.ouvrir("essai_salle", "boulangerie"), "  un commerce qui n'existe pas ne s'ouvre pas")
	await process_frame
	await process_frame
	var s: Node = current_scene
	check(s != null and s.get("commune") == "essai_salle" and s._salle.host == "Mme Aubin", "on est chez Mme Aubin")
	if s != null:
		s.open_vitrine()
		await process_frame
		var p: Node = s._game
		check(p != null and p.boutique == "mercerie" and p._list.get_child_count() == 2, "la vitrine montre les deux articles de la mercerie, pas ceux du garage")
		if p:
			p.closed.emit()
			await process_frame
		s._sortir()
		await process_frame
		await process_frame
		# Une commune en paquet s'ouvre derrière l'écran de chargement (socle 1.11).
		while root.get_node("Chargement").actif():
			await process_frame
		check(game.return_point == "place", "la porte de la boutique ramène devant elle")
	biens.sell("essai_salle/veste_chef")
	var fautes: PackedStringArray = structures.verifier([
		{"type": "commerce", "id": "a", "nom": "A", "genre": "epicerie", "articles": [{"id": "x", "nom": "X", "prix": 10}]},
		{"type": "commerce", "id": "b", "nom": "B", "genre": "meuble", "articles": [{"id": "x", "nom": "X", "prix": 0, "taille": 2},
			{"nom": "sans id"}, {"id": "y", "nom": "Y", "prix": 5, "emplacement": "plafond", "couleur": "bleu"}]}])
	check(Array(fautes) == ["structure a : genre inconnu « epicerie » (tenue, vehicule, meuble)",
		"structure b : article x en double", "structure b : article x : champ inconnu « taille »", "structure b : article x n'a pas de prix",
		"structure b : article x : un meuble a besoin d'un modele", "structure b : un article sans id", "structure b : article y : couleur « #rrggbb »",
		"structure b : article y : un meuble a besoin d'un modele", "structure b : article y : emplacement inconnu « plafond » (lit, sol, grand, mur, petit, jardin)"],
		"un article mal écrit est refusé, phrase par phrase : %s" % [fautes])


## Chaque lieu, ouvert par la touche E devant sa porte, et quitté par la touche E sur sa sortie : la
## commune revient telle qu'on l'a laissée (Chargement.lieu), et la touche de la sortie ne fait pas rentrer
## l'habitant resté devant la porte (retour de l'auteur de Chauvigny, octobre 2026).
func _sorties() -> void:
	var lieux := {
		"le tripot": func(): return load("res://scripts/socle/salle_jeu.gd").ouvrir("essai_salle", "tripot"),
		"l'étude": func(): return load("res://scripts/socle/etude.gd").ouvrir("essai_salle"),
		"la mercerie": func(): return load("res://scripts/socle/commerce.gd").ouvrir("essai_salle", "mercerie"),
		"la maison achetée chez le notaire": func(): return root.get_node("Biens").enter("essai_salle/maison_gare"),
	}
	var biens: Node = root.get_node("Biens")
	check(biens.buy("essai_salle/maison_gare", true, "essai_salle") and biens.logements.has("essai_salle/maison_gare"), "on achète la maison du chef de gare")
	for nom in lieux:
		var commune: Node = current_scene
		if commune == null or commune.scene_file_path != "res://communes/essai_salle/commune.tscn":
			check(false, "on part de la commune pour entrer dans %s" % nom)
			return
		# L'habitant de la commune, en vue de dessus, devant la porte du lieu.
		var cam := Camera3D.new()
		commune.add_child(cam)
		var habitant: CharacterBody3D = load("res://scripts/fp_player.gd").new()
		habitant.follow_camera = cam
		commune.add_child(habitant)
		var porte := Area3D.new()
		porte.set_meta("interact", "porte")
		commune.add_child(porte)
		var entrees := [0]
		habitant.interact.connect(func(t: Node):
			if t == porte:
				entrees[0] += 1
				lieux[nom].call())
		habitant.focus_target = porte
		_touche_e()
		await process_frame
		await process_frame
		var s: Node = current_scene
		check(entrees[0] == 1 and s != null and s != commune and s.get("player") != null, "la touche E devant la porte fait entrer dans %s" % nom)
		if s == null or s == commune or s.get("player") == null:
			return
		var sortie: Node = null
		for a in s.find_children("*", "Area3D", true, false):
			if a.get_meta("interact", "") == "exit":
				sortie = a
		s.player.focus_target = sortie
		_touche_e()
		await process_frame
		await process_frame
		while root.get_node("Chargement").actif():
			await process_frame
		check(current_scene == commune and entrees[0] == 1, "  la touche E sur la sortie rend la commune gardée, sans y faire rentrer (%d entrée(s))" % entrees[0])
		if current_scene != commune:
			return
		for n in [habitant, porte, cam]:
			n.free()
	biens.sell("essai_salle/maison_gare")


## Les tarifs d'une table de commune : le tapis du poker dit les blindes configurées, la plaque du
## blackjack les mises configurées, et des mises incohérentes sont refusées.
func _tarifs() -> void:
	var tables: GDScript = load("res://scripts/socle/tables.gd")
	var scene := Node3D.new()
	root.add_child(scene)
	var poker: Node3D = tables.table("poker")
	scene.add_child(poker)
	var pp: PanelContainer = tables.panneau("poker")
	check(pp.configurer_blindes(5, 10, 200), "des blindes de 5/10 s'acceptent")
	poker.attach(pp)
	check(poker.ligne_tapis.begins_with("BLINDES 5 / 10"), "le tapis du poker dit les blindes de la table : %s" % poker.ligne_tapis)
	var bj: Node3D = tables.table("blackjack")
	scene.add_child(bj)
	var bp: PanelContainer = tables.panneau("blackjack")
	check(not bp.configurer_mises([10, 5]) and not bp.configurer_mises([0, 5]) and not bp.configurer_mises([5]), "des mises en désordre, nulles ou seules sont refusées")
	check(bp.configurer_mises([2, 4, 10, 20]) and bp.BETS == [2, 4, 10, 20], "le blackjack prend les mises de la salle")
	bj.attach(bp)
	check(bj._plaque.text == "Mise\n2 à 20", "la plaque du blackjack dit les mises de la table : %s" % bj._plaque.text.replace("\n", " "))
	var rp: PanelContainer = tables.panneau("roulette")
	check(rp.configurer_mises([1, 2, 5, 10]) and rp.CHIPS == [1, 2, 5, 10], "la roulette prend les jetons de la salle")
	for n in [pp, bp, rp]:
		n.free()
	scene.queue_free()
	await process_frame


## Une pression de la touche E, comme la reçoit le jeu.
func _touche_e() -> void:
	var e := InputEventKey.new()
	e.physical_keycode = KEY_E
	e.keycode = KEY_E
	e.pressed = true
	root.push_input(e)
	var r := e.duplicate()
	r.pressed = false
	root.push_input(r)


func _fin() -> void:
	print("\n%d échec(s)" % fails)
	quit(1 if fails else 0)
