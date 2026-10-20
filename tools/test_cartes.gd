extends SceneTree
## Vérifie le classeur de cartes du carnet sans affichage : godot --headless --path . -s tools/test_cartes.gd
## Les familles (parts, quartiers du notaire, clubs, garde-robe, garage, brocante, souvenirs), l'état de
## chaque carte (à soi, à acquérir, fermée), la carte de parts d'un club de football et d'un club de basket
## (à soi, aux autres, libres), le filtre « seulement les miennes », la carte en grand et ses flèches.

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	var biens: Node = root.get_node("Biens")
	var carnet: Node = root.get_node("Carnet")
	var foot: Node = root.get_node("Football")
	var basket: Node = root.get_node("Basket")
	game.saving_enabled = false
	DirAccess.make_dir_recursive_absolute("user://test_cartes/")
	foot.dossier = "user://test_cartes/"
	foot.effacer()
	var t := Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 10, "day": 18, "hour": 20, "minute": 0, "second": 0})
	foot.regler_horloge(func(): return t)
	foot.actualiser()
	game.won = 2000
	game.credits = 100000
	biens.buy("smarvoise")
	biens.buy("smarvoise")
	biens.buy("dimanche")
	game.credits = 500
	var album: Node = carnet.get("_album")

	# Les familles, dans l'ordre du classeur.
	var ids: Array = album.familles().map(func(f): return f.id)
	check(ids[0] == "parts" and ids.has("q:place") and ids.has("q:rue_du_clain") and ids.has("clubs"), "les familles : les parts, puis les quartiers du notaire, puis les clubs (%s)" % str(ids))
	check(ids.slice(-5) == ["clubs", "tenue", "vehicule", "meuble", "souvenirs"] or ids.find("souvenirs") > ids.find("meuble"), "garde-robe, garage, brocante et souvenirs ferment le classeur")

	var cartes: Array = album.cartes()
	var par_id := {}
	for c in cartes:
		par_id[c.id] = c
	check(not par_id.has("etoile"), "le lot des obligations du notaire n'est pas une carte : le club a la sienne")
	var sm: Dictionary = par_id.smarvoise
	check(sm.etat == "moi" and sm.n == 2 and sm.max == 5 and sm.famille == "parts", "deux parts de la Smarvoise : la carte est à soi, 2 sur 5")
	check(sm.prix == biens.next_price("smarvoise"), "son prix est celui du prochain exemplaire")
	check(par_id.cotes.etat == "libre", "la table du Moulin, seuil atteint, est à acquérir")
	check(par_id.comite.etat == "fermee" and par_id.comite.seuil == 8000, "le comité des fêtes, à 8 000 gagnés, est encore fermé")
	check(par_id.chambre.famille == "q:place" and par_id.adr_clain_5.famille == "q:rue_du_clain", "les murs vont au quartier de leur adresse")
	check(par_id.adr_mairie.icone == "public" and par_id.adr_boucherie.icone == "murs", "un bâtiment public n'a pas le dessin d'une boutique")
	check(par_id.dimanche.famille == "tenue" and par_id.dimanche.etat == "moi", "le costume du dimanche est à la garde-robe")
	check(par_id.ds.rang == 2 and par_id.maison_place.rang == 3 and par_id.lampe_salon.rang == 0, "le rang suit le prix : bronze, argent, or, prestige")
	check(par_id.has("premier_jeton") and par_id.premier_jeton.famille == "souvenirs", "les souvenirs ont leurs cartes")

	# La carte de parts de l'Étoile : deux à soi, trois aux autres, quatre libres.
	foot.forcer_porteurs("vous:3+6,Lucien:9+1,Mathilde:5", "smarves")
	var etoile: Dictionary = {}
	for c in album.cartes():
		if c.id == "football:smarves":
			etoile = c
	check(not etoile.is_empty() and etoile.famille == "clubs", "l'Étoile de Smarves a sa carte de parts")
	if not etoile.is_empty():
		var qui: Array = etoile.cases.map(func(c): return c.qui)
		check(qui == ["autre", "libre", "moi", "libre", "autre", "moi", "libre", "libre", "autre"], "ses neuf cases : à soi, aux autres, libres (%s)" % str(qui))
		check(etoile.cases[0].par == "Lucien" and etoile.etat == "moi" and etoile.n == 2, "chaque case dit son porteur, et la carte est à soi")
		check(not etoile.dirige and str(etoile.actionnaires[0].nom) == "Lucien", "Lucien a mis le plus : c'est lui qui dirige")
	# Un club de basket inscrit, une obligation à soi et une à un autre.
	basket.clubs["essai_basket"] = {"nom": "Basket-club d'essai", "court": "BCE", "couleurs": ["#7a1e2c", "#f4f1ea"], "commune": "essai_basket"}
	basket.bureau.obligations = [{"club": "essai_basket", "rang": 4, "par": "vous", "moi": true}, {"club": "essai_basket", "rang": 8, "par": "Lucien", "moi": false}]
	var bc: Dictionary = {}
	for c in album.cartes():
		if c.id == "basket:essai_basket":
			bc = c
	check(not bc.is_empty() and bc.cases[3].qui == "moi" and bc.cases[7].qui == "autre" and bc.cases[0].qui == "libre", "un club de basket a sa carte de parts, case par case")
	check(not bc.is_empty() and bc.couleurs[0].is_equal_approx(Color("#7a1e2c")), "aux couleurs du club")
	basket.clubs.erase("essai_basket")
	basket.bureau.obligations = []

	# Le classeur s'ouvre, se filtre, et montre une carte en grand.
	carnet.toggle()
	carnet.ouvrir_onglet("cartes")
	await process_frame
	check(album.visible and not carnet.get("_spread").visible, "l'onglet « Mes cartes » remplace les deux pages par le classeur")
	var n_toutes := _cartes(album).size()
	check(n_toutes == album.cartes().size(), "toutes les cartes sont au classeur (%d)" % n_toutes)
	album.choisir_famille("parts")
	await process_frame
	check(_cartes(album).size() == 5, "la famille des parts : cinq cartes")
	album.choisir_famille("")
	album.miennes = true
	album.remplir()
	await process_frame
	var miennes := _cartes(album)
	check(miennes.all(func(v): return v.donnees.etat == "moi") and miennes.size() == 3, "seulement les miennes : les cartes à soi (%d)" % miennes.size())
	album.miennes = false
	album.choisir_famille("parts")
	await process_frame
	(_cartes(album)[0] as Control).choisie.emit()
	await process_frame
	check(album.zoom_ouvert() and album.get("_index") == 0, "un clic montre la carte en grand")
	album.saisir(_touche(KEY_RIGHT))
	check(album.get("_index") == 1, "→ passe à la suivante")
	album.saisir(_touche(KEY_LEFT))
	album.saisir(_touche(KEY_LEFT))
	check(album.get("_index") == 4, "← depuis la première revient à la dernière")
	album.saisir(_touche(KEY_ESCAPE))
	check(not album.zoom_ouvert(), "Échap repose la carte")
	album.saisir(_touche(KEY_DOWN))
	check(album.famille != "parts", "↓ passe à la famille suivante")
	# Une tenue qu'on n'a pas sur soi se porte depuis sa carte.
	album.choisir_famille("tenue")
	await process_frame
	var i: int = album.get("_affichees").map(func(e): return e.carte.id).find("dimanche")
	biens.worn = ""
	album.montrer(i)
	await process_frame
	var porter: Button = album.find_child("Geste_La_porter", true, false)
	check(porter != null, "le costume pas porté : « La porter »")
	if porter != null:
		porter.pressed.emit()
		check(biens.worn == "dimanche", "et il est porté")
	carnet.ouvrir_onglet("compte")
	check(not album.zoom_ouvert() and not album.visible, "changer d'onglet range la carte et le classeur")
	carnet.toggle()

	foot.effacer()
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


func _cartes(album: Node) -> Array:
	return album.find_children("Carte_*", "", true, false).filter(func(c): return not c.is_queued_for_deletion() and c.get("fixe") == false)


func _touche(code: Key) -> InputEvent:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e
