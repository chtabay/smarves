extends SceneTree
## Vérifie le classeur de cartes du carnet sans affichage : godot --headless --path . -s tools/test_cartes.gd
## Un sous-onglet par village, seulement les cartes possédées, rangées par genre ; le topo complet des
## parts d'un club de football et d'un club de basket (à soi, en vente, à d'autres joueurs) ; la carte en
## grand, ses flèches et ses gestes.

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
	biens.buy("adr_clain_5")
	game.credits = 500
	var album: Node = carnet.get("_album")

	# Les villages : la commune d'origine d'abord.
	var vs: Array = album.villages().map(func(x): return x.id)
	check(vs == ["smarves"], "un seul village tant qu'on ne possède rien ailleurs (%s)" % str(vs))

	# Seulement les cartes possédées, rangées par genre.
	var cartes: Array = album.cartes("smarves")
	var ids: Array = cartes.map(func(c): return c.id)
	check(ids == ["adr_clain_5", "dimanche", "premier_jeton"], "les biens possédés, par genre, le souvenir du casino en dernier (%s)" % str(ids))
	check(cartes.all(func(c): return c.etat == "moi"), "toutes à soi : ni carte en vente ni carte fermée pour les biens")
	check(cartes[0].genre_id == "maison" and cartes[1].genre_id == "tenue", "chaque carte a son genre : maison, garde-robe")

	# Les établissements : le topo complet de leurs parts, dans leur catégorie.
	var etabs: Array = album.etablissements("smarves")
	var noms: Array = etabs.map(func(e): return e.id)
	check(noms == ["smarvoise", "cotes"], "les établissements ouverts : le café et le moulin, pas encore le comité ni le casino (%s)" % str(noms))
	var sm: Array = etabs[0].cartes
	check(sm.size() == 5 and sm.map(func(c): return c.etat) == ["moi", "moi", "libre", "libre", "libre"], "la Smarvoise : cinq parts, deux à soi, trois en vente")
	check(sm[2].prix == biens.next_price("smarvoise") and sm[4].prix == biens.price_of("smarvoise", 4), "chaque part en vente a son prix")
	check(etabs[1].cartes.all(func(c): return c.etat == "libre"), "le moulin : rien à soi, tout en vente")

	# Le topo complet des parts de l'Étoile : neuf cartes, à soi, en vente, aux autres.
	foot.forcer_porteurs("vous:3+6,Lucien:9+1,Mathilde:5", "smarves")
	var cl: Array = album.clubs("smarves")
	check(cl.size() >= 1 and cl[0].sport == "football", "l'Étoile de Smarves a ses parts sous le village")
	if not cl.is_empty():
		var qui: Array = cl[0].cartes.map(func(c): return c.qui)
		check(qui == ["autre", "libre", "moi", "libre", "autre", "moi", "libre", "libre", "autre"], "neuf cartes : à soi, en vente, aux autres (%s)" % str(qui))
		check(cl[0].cartes[0].par == "Lucien" and cl[0].cartes[0].valeur == 500, "chaque carte dit sa valeur et son porteur")
		check(cl[0].cartes[2].dividende > 0, "et ce qu'elle verse par journée")
	# Un club de basket dans une autre commune où l'on tient une obligation : un deuxième village.
	basket.clubs["essai_basket"] = {"nom": "Basket-club d'essai", "court": "BCE", "couleurs": ["#7a1e2c", "#f4f1ea"], "commune": "essai_basket"}
	basket.bureau.obligations = [{"club": "essai_basket", "rang": 4, "par": "vous", "moi": true}, {"club": "essai_basket", "rang": 8, "par": "Lucien", "moi": false}]
	vs = album.villages().map(func(x): return x.id)
	check(vs == ["smarves", "essai_basket"], "une obligation ailleurs ouvre le sous-onglet de son village")
	var bc: Array = album.clubs("essai_basket")
	check(bc.size() == 1 and bc[0].cartes[3].qui == "moi" and bc[0].cartes[7].qui == "autre" and bc[0].cartes[0].qui == "libre", "le club de basket a son topo, carte par carte")
	check(bc.size() == 1 and (bc[0].cartes[0].couleurs[0] as Color).is_equal_approx(Color("#7a1e2c")), "aux couleurs du club")
	check(album.cartes("essai_basket").is_empty(), "pas de bien là-bas : seulement les parts du club")

	# Le classeur s'ouvre sur le village d'origine.
	carnet.toggle()
	carnet.ouvrir_onglet("cartes")
	await process_frame
	check(album.visible and not carnet.get("_spread").visible, "l'onglet « Mes cartes » remplace les deux pages par le classeur")
	check(album.village == "smarves" and _cartes(album).size() == 3 + 9 + 9, "à Smarves : trois biens, neuf parts d'établissement et les neuf parts de l'Étoile (%d)" % _cartes(album).size())
	album.saisir(_touche(KEY_DOWN))
	await process_frame
	check(album.village == "essai_basket" and _cartes(album).size() == 9, "↓ passe au village suivant : les neuf parts du club de basket")
	album.choisir_village("smarves")
	await process_frame
	(_cartes(album)[0] as Control).choisie.emit()
	await process_frame
	check(album.zoom_ouvert() and album.get("_index") == 0, "un clic montre la carte en grand")
	album.saisir(_touche(KEY_RIGHT))
	check(album.get("_index") == 1, "→ passe à la suivante")
	album.saisir(_touche(KEY_LEFT))
	album.saisir(_touche(KEY_LEFT))
	check(album.get("_index") == 20, "← depuis la première revient à la dernière")
	album.saisir(_touche(KEY_ESCAPE))
	check(not album.zoom_ouvert(), "Échap repose la carte")
	# Une tenue qu'on n'a pas sur soi se porte depuis sa carte.
	biens.worn = ""
	album.montrer(1)
	await process_frame
	var porter: Button = album.find_child("Geste_la_porter", true, false)
	check(porter != null, "le costume pas porté : « la porter »")
	if porter != null:
		porter.pressed.emit()
		check(biens.worn == "dimanche", "et il est porté")
	carnet.ouvrir_onglet("compte")
	check(not album.zoom_ouvert() and not album.visible, "changer d'onglet range la carte et le classeur")
	carnet.toggle()

	basket.clubs.erase("essai_basket")
	basket.bureau.obligations = []
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
