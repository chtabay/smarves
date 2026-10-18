extends SceneTree
## Vérifie la salle de jeu du socle sans affichage : godot --headless --path . -s tools/test_salle_jeu.gd
## Le vocabulaire accepte une « salle_jeu » et refuse un jeu ou un décor inconnus ; une commune en pack
## (tools/fixtures/salle_jeu/) inscrit ses deux salles au registre ; le tripot s'ouvre, pose une table
## par jeu, chaque jeu ouvre son panneau et un gain s'encaisse ; le cercle reste fermé tant que le lieu
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
	check(s._salle.host == "Mme Rivière" and s._salle.name == "Le tripot de la gare", "la tenancière et le nom viennent du manifeste")
	for j in tables:
		s._jeu_ouvert = j
		s.open_game()
		await process_frame
		check(s._game != null and s._game.has_signal("played"), "le jeu « %s » ouvre son panneau" % j)
		if s._game:
			s._game.closed.emit()
			await process_frame
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
	check(current_scene != null and current_scene.scene_file_path == "res://communes/essai_salle/commune.tscn" and game.return_point == "place",
		"la porte ramène dans la commune, devant la porte de la salle")
	await _etude(game)
	await _commerces(game)
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
		check(current_scene != null and current_scene.scene_file_path == "res://communes/essai_salle/commune.tscn" and game.return_point == "place", "la porte de l'étude ramène dans la commune")
	biens.sell("essai_salle/buffet")


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


func _fin() -> void:
	print("\n%d échec(s)" % fails)
	quit(1 if fails else 0)
