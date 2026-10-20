extends SceneTree
## Vérifie le classeur de cartes du carnet sans affichage : godot --headless --path . -s tools/test_cartes.gd
## Les villages empilés, chacun avec ses trois rubriques : les biens possédés, rangés par genre ; les clubs
## dont on tient une obligation et les établissements dont on tient une part, avec leur topo complet (à soi,
## en vente, à d'autres joueurs) ; la carte en grand, ses flèches et ses gestes ; les cartes rappelées dans
## les onglets de village ; les cartes d'un seul club, à son entrée.

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

	# Les établissements : seulement ceux dont on tient une part, avec le topo complet.
	var etabs: Array = album.etablissements("smarves")
	var noms: Array = etabs.map(func(e): return e.id)
	check(noms == ["smarvoise"], "seulement les établissements dont on tient une part : la Smarvoise, pas le moulin (%s)" % str(noms))
	var sm: Array = etabs[0].cartes if not etabs.is_empty() else []
	check(sm.size() == 5 and sm.map(func(c): return c.etat) == ["moi", "moi", "libre", "libre", "libre"], "la Smarvoise : cinq parts, deux à soi, trois en vente")
	check(sm.size() == 5 and sm[2].prix == biens.next_price("smarvoise") and sm[4].prix == biens.price_of("smarvoise", 4), "chaque part en vente a son prix")

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

	# Le classeur : les villages empilés, chacun avec ses trois rubriques.
	carnet.toggle()
	carnet.ouvrir_onglet("cartes")
	await process_frame
	await process_frame
	check(album.visible and not carnet.get("_spread").visible, "l'onglet « Mes cartes » remplace les deux pages par le classeur")
	check(album.find_child("Village_smarves", true, false) != null and album.find_child("Village_essai_basket", true, false) != null, "les deux villages, l'un sous l'autre")
	check(_cartes(album).size() == 3 + 9 + 5 + 9, "trois biens, l'Étoile, la Smarvoise à Smarves, puis le club de basket (%d)" % _cartes(album).size())
	check(_textes(album).count("Mes biens") == 2 and _textes(album).count("Mes clubs sportifs") == 2 and _textes(album).count("Mes établissements") == 2, "trois rubriques par village")
	check(album.village == "smarves", "on commence en haut, à Smarves")
	album.saisir(_touche(KEY_DOWN))
	await process_frame
	check(album.village == "essai_basket" and carnet.get("_album").get("_defile").scroll_vertical > 0, "↓ saute au village suivant")
	album.choisir_village("smarves")
	await process_frame
	(_cartes(album)[0] as Control).choisie.emit()
	await process_frame
	check(album.zoom_ouvert() and album.get("_index") == 0, "un clic montre la carte en grand")
	album.saisir(_touche(KEY_RIGHT))
	check(album.get("_index") == 1, "→ passe à la suivante")
	album.saisir(_touche(KEY_LEFT))
	album.saisir(_touche(KEY_LEFT))
	check(album.get("_index") == 25, "← depuis la première revient à la dernière")
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
	album.fermer_zoom()

	# Les onglets de village rappellent les cartes qu'on y tient.
	check(carnet.onglets().any(func(o): return o[0] == "essai_basket"), "un village où l'on tient des cartes a son onglet")
	carnet.ouvrir_onglet("smarves")
	await process_frame
	var vig := _vignettes(carnet)
	check(vig.size() == 6 and _textes(carnet).has("+ 1 autre"), "à Smarves, les cartes qu'on tient, en petit : six, puis « + 1 autre » (%d)" % vig.size())
	check(_textes(carnet).any(func(t): return t.contains("Maître Garnier, à l'étude")), "et le chemin de l'étude pour acheter autre chose")
	carnet.ouvrir_onglet("essai_basket")
	await process_frame
	vig = _vignettes(carnet)
	check(vig.size() == 1, "au village du club de basket, son obligation (%d)" % vig.size())
	if not vig.is_empty():
		(vig[0] as Control).choisie.emit()
		await process_frame
		await process_frame
		check(carnet.get("_onglet") == "cartes" and album.zoom_ouvert() and str(album.get("_affichees")[album.get("_index")].id) == "basket:essai_basket:4", "un clic sur une vignette ouvre le classeur sur la carte")
		album.fermer_zoom()
	carnet.ouvrir_onglet("compte")
	check(not album.zoom_ouvert() and not album.visible, "changer d'onglet range la carte et le classeur")
	carnet.toggle()

	# À l'entrée du club : les cartes de ce club seulement.
	var hote := Control.new()
	var parent := Control.new()
	root.add_child(parent)
	parent.add_child(hote)
	var vitrine: Control = album.ouvrir_club(hote, "football", "smarves")
	await process_frame
	check(_cartes(vitrine).size() == 9, "à l'entrée de l'Étoile, ses neuf obligations en cartes (%d)" % _cartes(vitrine).size())
	vitrine._input(_touche(KEY_ESCAPE))
	await process_frame
	check(not is_instance_valid(vitrine) or vitrine.is_queued_for_deletion(), "Échap les repose")
	parent.queue_free()

	basket.clubs.erase("essai_basket")
	basket.bureau.obligations = []
	foot.effacer()
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


func _cartes(album: Node) -> Array:
	return album.find_children("Carte_*", "", true, false).filter(func(c): return not c.is_queued_for_deletion() and c.get("fixe") == false)


func _vignettes(carnet: Node) -> Array:
	return carnet.find_children("Vignette_*", "", true, false).filter(func(c): return not c.is_queued_for_deletion() and c.is_visible_in_tree())


func _textes(n: Node) -> Array:
	return n.find_children("*", "Label", true, false).filter(func(l): return not l.is_queued_for_deletion()).map(func(l): return l.text)


func _touche(code: Key) -> InputEvent:
	var e := InputEventKey.new()
	e.keycode = code
	e.physical_keycode = code
	e.pressed = true
	return e
