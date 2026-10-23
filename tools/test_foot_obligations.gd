extends SceneTree
## Vérifie le registre des obligations sans affichage : godot --headless --path . -s tools/test_foot_obligations.gd
## Neuf lignes, une par obligation ; on prend, on rend, on échange depuis la fenêtre ; les porteurs des autres
## se lisent ; la ligne d'état dit ce qu'on a et ce qui est dû.

var fails := 0
var t := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _textes(n: Node) -> Array:
	var out: Array = []
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		out += _textes(c)
	return out


func _init() -> void:
	await process_frame
	var foot: Node = root.get_node("Football")
	var game: Node = root.get_node("Game")
	foot.dossier = ""
	foot.effacer()
	game.saving_enabled = false
	game.credits = 6000
	foot.regler_horloge(func(): return t)
	t = foot.coup_envoi(1, 1) - 86400
	# Un deuxième club au championnat : la commune d'essai et son terrain.
	load("res://tools/essai.gd").greffer(root)
	foot.actualiser()
	var club: String = foot.clubs.keys()[0]
	foot.appliquer_obligations([{"club": club, "rang": 9, "par": "Lucien", "moi": false}])

	var fenetre: PanelContainer = load("res://scripts/socle/foot_obligations.gd").new()
	fenetre.club = club
	root.add_child(fenetre)
	await process_frame
	var textes := _textes(fenetre)
	check(textes.any(func(x): return x.begins_with("n° 1  ·  500 crédits")) and textes.any(func(x): return x.begins_with("n° 9  ·  7 500 crédits")), "les neuf obligations, de 500 à 7 500")
	check(textes.has("tenue par Lucien") and fenetre.find_children("Prendre_*", "Button", true, false).size() == 8, "la n° 9 est à Lucien, les huit autres se prennent")
	check(fenetre.find_child("Prendre_8", true, false).disabled and not fenetre.find_child("Prendre_7", true, false).disabled, "avec 6 000 crédits, la n° 8 (6 250) est hors de portée, pas la n° 7")
	check(textes.has("il manque %s" % game.fmt(250)), "et la fenêtre dit ce qui manque pour la n° 8")
	var pd: Label = fenetre.find_child("PourDiriger", true, false)
	check(pd != null and pd.text.contains("Il vous manque %s" % game.fmt(7500)) and pd.text.contains("plusieurs obligations"), "ce qui manque pour diriger : Lucien tient la plus grosse (%s)" % (pd.text if pd else ""))
	(fenetre.find_child("Prendre_3", true, false) as Button).pressed.emit()
	await process_frame
	check(game.credits == 4500 and foot.mes_obligations(club) == [3], "la n° 3 prise depuis la fenêtre : 1 500 débités")
	textes = _textes(fenetre)
	check(textes.has("à vous") and fenetre.find_child("Rendre_3", true, false) != null, "elle est à moi, et se rend")
	check(fenetre.find_child("Echanger_5", true, false) != null and fenetre.find_child("Echanger_2", true, false) == null, "une plus grosse s'échange depuis la n° 3, pas une plus petite")
	(fenetre.find_child("Echanger_5", true, false) as Button).pressed.emit()
	await process_frame
	check(game.credits == 3000 and foot.mes_obligations(club) == [5], "échangée contre la n° 5 pour 1 500 de plus")
	(fenetre.find_child("Rendre_5", true, false) as Button).pressed.emit()
	await process_frame
	check(game.credits == 5400 and foot.mes_obligations(club).is_empty(), "rendue à 80 % : 2 400")
	textes = _textes(fenetre)
	check(textes.any(func(x): return x.begins_with("Vous n'avez rien dans le club.")), "la ligne d'état sans obligation")
	fenetre.agir({"ok": false, "raison": "prise"})
	check(fenetre._ligne_etat.text == "Quelqu'un l'a prise avant vous.", "la fenêtre dit pourquoi ça coince")
	fenetre.queue_free()
	await process_frame

	print("obligations: %d échecs" % fails)
	quit(1 if fails > 0 else 0)
