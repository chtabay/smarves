extends SceneTree
## Vérifie le coin des communes greffées sans affichage : godot --headless --path . -s tools/test_coin.gd
## Le cartouche dit où l'on est (département et commune, ou ville et pays au loin), ses deux boutons gardent
## leurs mots (le pilote des pensionnaires les cherche par leur texte), chacun a son picto, la carte a sa
## touche ; il tient sur une ligne, au-dessus de ce que les paquets posent à y = 74 ; ses boutons font ce
## qu'ils disent ; et l'habit des boutons sans style n'est mis sur la fenêtre que dans une commune.

const COIN := preload("res://scripts/socle/coin.gd")

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	root.size = Vector2i(1600, 900)
	var appels := {"rentrer": 0, "carte": 0}
	var coin: COIN = COIN.new(func(): appels.rentrer += 1, func(): appels.carte += 1)
	root.add_child(coin)

	var lyon := Commune.lire("res://tools/paquet_essai/lyon/commune.json")
	coin.poser(lyon)
	await process_frame
	await process_frame
	check(coin._nom.text == "Lyon", "le cartouche dit la commune : %s" % coin._nom.text)
	check(coin._departement.text == "RHÔNE" and coin._departement.visible, "et son département en capitales : %s" % coin._departement.text)
	check(coin._rentrer.text == "Revenir à Smarves" and coin._rentrer.icon != null, "le premier bouton rentre à Smarves, avec son picto")
	check(coin._carte.text == "La carte" and coin._carte.icon != null, "le second ouvre la carte, avec son picto")
	var touche: Control = coin._carte.get_node_or_null("Touche")
	check(touche != null and (touche.get_child(0) as Label).text == "M", "la touche M est dessinée sur le bouton de la carte")
	if touche != null:
		var r := coin._carte.get_global_rect().grow(1)
		check(r.encloses(touche.get_global_rect()), "et tient dans le bouton : %s dans %s" % [touche.get_global_rect(), r])
	var plaque: Control = coin.get_node("Plaque")
	var bas := plaque.get_global_rect().end.y
	check(bas > 30.0 and bas <= 70.0, "le cartouche tient sur une ligne, au-dessus de y = 74 : il finit à %d" % bas)
	check(coin._rentrer.get_global_rect().end.x <= coin._carte.get_global_rect().position.x, "les deux boutons sont côte à côte")

	coin._rentrer.pressed.emit()
	coin._carte.pressed.emit()
	check(appels.rentrer == 1 and appels.carte == 1, "chaque bouton fait ce qu'il dit")

	var minuit := Commune.lire("res://tools/paquet_essai/casino_minuit/commune.json")
	coin.poser(minuit)
	check(coin._nom.text == "Casino Minuit", "au loin, le nom de la destination : %s" % coin._nom.text)
	check(coin._departement.text == "LAS VEGAS  ·  ÉTATS-UNIS", "au-dessus, sa ville et son pays : %s" % coin._departement.text)
	check(coin._rentrer.text == "Reprendre l'avion" and coin._rentrer.icon != null, "et l'on rentre en avion, avec son picto")

	coin.poser(null)
	check(coin._nom.text == "" and not coin._departement.visible, "sans commune connue, le cartouche ne dit rien de faux")

	# L'habit des boutons sans style : sur la fenêtre dans une commune, retiré au retour.
	var communes = root.get_node("Communes")
	communes._bouton_retour(true)
	check(root.theme == COIN.habit(), "dans une commune, la fenêtre porte l'habit des boutons")
	var nu := Button.new()
	nu.text = "Un bouton de paquet"
	root.add_child(nu)
	await process_frame
	check(nu.get_theme_color("font_color") == COIN.TEINTES.OR, "un bouton sans style y prend l'or du jeu")
	var fond := nu.get_theme_stylebox("normal") as StyleBoxFlat
	check(fond != null and fond.border_color.is_equal_approx(Color(COIN.TEINTES.LAITON, 0.6)), "et son filet laiton")
	communes._bouton_retour(false)
	check(root.theme == null and not communes._retour.visible, "de retour à Smarves, le coin et l'habit s'en vont")

	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
