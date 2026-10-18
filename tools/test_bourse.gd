extends SceneTree
## Vérifie la bourse sans réseau : godot --headless --path . -s tools/test_bourse.gd
## Les heures des places (été, hiver), les séances et les rendez-vous de l'agenda, l'argent qui revient
## d'une position (seul le bénéfice compte dans le total gagné), les écritures de la cote, et la fenêtre
## construite d'après une cote d'essai, sur un ordinateur et sur un téléphone.

var BOURSE: GDScript
var PANEL: GDScript

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	BOURSE = load("res://scripts/socle/bourse.gd")
	PANEL = load("res://scripts/socle/bourse_panel.gd")
	root.get_node("Game").saving_enabled = false
	_heures()
	_seances()
	_argent()
	_ecritures()
	await _fenetre()
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


func _heures() -> void:
	# Le lundi 19 octobre 2026 à midi UTC : Paris en heure d'été (UTC+2), New York aussi (UTC−4).
	var lundi := 1792411200
	check(BOURSE.decalage("cac40", lundi) == 2, "Paris en octobre : UTC+2")
	check(BOURSE.decalage("sp500", lundi) == -4, "New York en octobre : UTC−4")
	check(BOURSE.decalage("nikkei", lundi) == 9, "Tokyo : UTC+9, sans heure d'été")
	# Le lundi 2 novembre 2026 : Paris est passé à l'heure d'hiver (25 octobre), New York pas encore (1er novembre, si).
	var novembre := 1793620800
	check(BOURSE.decalage("cac40", novembre) == 1, "Paris en novembre : UTC+1")
	check(BOURSE.decalage("sp500", novembre) == -5, "New York après le 1er novembre : UTC−5")
	check(BOURSE.decalage("sp500", 1792843200) == -4, "New York le samedi 24 octobre : encore UTC−4")
	# La clôture de Paris le lundi 19 : 17 h 35 à Paris, 15 h 35 UTC ; celle de New York, 20 h UTC.
	check(BOURSE.heure_de_place("cac40", lundi, [17, 35]) == 1792424100, "clôture de Paris le 19 octobre à 15 h 35 UTC")
	check(BOURSE.heure_de_place("sp500", lundi, [16, 0]) == 1792440000, "clôture de New York le 19 octobre à 20 h UTC")
	check(BOURSE.heure_de_place("nikkei", lundi, [15, 30]) == 1792391400, "clôture de Tokyo le 19 octobre à 6 h 30 UTC")


func _seances() -> void:
	# Du samedi 17 au samedi 24 octobre 2026 : cinq ouvertures et cinq clôtures à Paris, pas une le week-end.
	var de := 1792195200
	var a := de + 7 * 86400
	var s: Array = BOURSE.seances("cac40", de, a)
	check(s.size() == 10, "dix séances à Paris dans la semaine (%d)" % s.size())
	check(s[0].quoi == "ouverture" and s[0].quand == 1792393200, "la première : lundi 9 h à Paris")
	check(s[s.size() - 1].quoi == "cloture" and s[s.size() - 1].quand == 1792769700, "la dernière : vendredi 17 h 35")
	var o: Array = BOURSE.seances("or", de, a)
	check(o[0].quoi == "ouverture" and o[0].quand == 1792360800, "l'or rouvre le dimanche à 18 h à New York")
	# L'agenda : rien avant le seuil ; puis, sans position, les cinq séances de Paris.
	var b: Node = root.get_node("Bourse")
	var game: Node = root.get_node("Game")
	b.donnees = {"positions": []}
	game.won = 0
	check(b.rendez_vous(de, a).is_empty(), "avant le seuil, la bourse n'inscrit rien à l'agenda")
	game.won = 7000
	var rv: Array = b.rendez_vous(de, a)
	check(rv.size() == 5 and rv.all(func(r): return r.activite == "bourse" and r.titre.begins_with("La séance")), "l'agenda : cinq séances de Paris (%d)" % rv.size())
	var bias := int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	check(rv[0].quand == 1792393200 + bias and rv[0].duree == 8 * 3600 + 35 * 60, "la séance du lundi : de 9 h à 17 h 35")
	b.donnees = {"positions": [{"id": 1, "indice": "nikkei", "issue": null}]}
	rv = b.rendez_vous(de, a)
	check(rv.size() == 10, "avec une position à Tokyo, ses cinq clôtures s'y ajoutent (%d)" % rv.size())
	check(rv.any(func(r): return r.titre.begins_with("Clôture de Tokyo")), "« Clôture de Tokyo » dans l'agenda")
	var agenda: Node = root.get_node("Agenda")
	check(agenda.entre(de + bias, a + bias).any(func(r): return r.activite == "bourse"), "l'Agenda lit la bourse")
	b.donnees = {}
	game.won = 0


func _argent() -> void:
	var game: Node = root.get_node("Game")
	game.credits = 1000
	game.won = 5000
	game.staked = 0
	check(BOURSE.cout(1000) == 1010, "ouvrir 1 000 coûte 1 010 (1 % de courtage)")
	check(BOURSE.courtage(100) == 1, "le courtage d'une petite marge : 1 crédit")
	# Une position soldée en bénéfice : 1 500 rendus sur 1 000 engagés.
	BOURSE.crediter(1500, 1000)
	check(game.credits == 2500, "les 1 500 rentrent dans les crédits")
	check(game.won == 5500, "seul le bénéfice (500) compte dans le total gagné")
	# Une position soldée à perte : 400 rendus sur 1 000. Rien au total gagné.
	BOURSE.crediter(400, 1000)
	check(game.credits == 2900 and game.won == 5500, "une perte ne touche pas au total gagné")
	BOURSE.crediter(0, 1000)
	check(game.credits == 2900, "une position liquidée sans reste ne rend rien")
	check(absf(BOURSE.seuil_liquidation(50) + 0.016) < 0.0001, "au levier 50, liquidée à −1,6 %")
	check(absf(BOURSE.seuil_liquidation(10) + 0.08) < 0.0001, "au levier 10, à −8 %")
	var appel := {"issue": null, "entree": 7800.0, "valeur": 450, "garantie": 1000}
	check(BOURSE.en_appel(appel), "sous la moitié de la garantie : l'appel de marge")
	appel.valeur = 600
	check(not BOURSE.en_appel(appel), "au-dessus : pas d'appel")
	check(BOURSE.intitule({"indice": "cac40", "sens": -1, "levier": 25}) == "CAC 40 à la baisse, levier 25", "l'intitulé d'une position")


func _ecritures() -> void:
	check(PANEL.nombre(7956.7) == "7 956,7", "un cours : 7 956,7")
	check(PANEL.nombre(65324.29) == "65 324,3", "le Nikkei : 65 324,3")
	check(PANEL.pourcent(0.01244) == "+1,24 %", "une hausse : +1,24 %")
	check(PANEL.pourcent(-0.0031) == "−0,31 %", "une baisse : −0,31 %")
	check(PANEL.jour("2026-10-16") == "16 oct.", "un jour : 16 oct.")
	var cours := {"cours": [["2026-10-14", 100.0], ["2026-10-15", 102.0], ["2026-10-16", 101.0]]}
	check(absf(BOURSE.variation(cours, 1) - (101.0 / 102.0 - 1.0)) < 1e-6, "la variation de la séance")
	check(absf(BOURSE.variation(cours, 5)) < 1e-9, "pas assez de séances pour la semaine : 0")


func _fenetre() -> void:
	var b: Node = root.get_node("Bourse")
	b._essai = true
	b._mise_en_scene()
	var game: Node = root.get_node("Game")
	game.credits = 20000
	for taille in [Vector2i(1600, 900), Vector2i(1067, 600)]:
		root.size = taille
		await process_frame
		var p: PanelContainer = PANEL.new()
		root.add_child(p)
		await process_frame
		var boutons := p.find_children("Ordre_*", "Button", true, false)
		check(boutons.size() == 4, "%d × %d : quatre valeurs à la cote, chacune son guichet" % [taille.x, taille.y])
		check(p.find_children("Solder_*", "Button", true, false).size() == 3, "trois positions ouvertes, chacune son solde")
		check(p.find_children("Renflouer_*", "Button", true, false).size() == 2, "les deux exécutées se renflouent")
		var appel := false
		for l in p.find_children("*", "Label", true, false):
			if (l as Label).text.begins_with("Appel de marge"):
				appel = true
		check(appel, "la position du Nikkei est en appel de marge")
		p.ouvrir_ordre("cac40")
		await process_frame
		check(p.find_children("Passer", "Button", true, false).size() == 1, "le guichet des ordres s'ouvre")
		var avant: int = game.credits
		await p.passer()
		check(game.credits == avant - 1010 and b.ouvertes().size() == 4, "un ordre de 1 000 au levier 25 : 1 010 crédits, une position de plus")
		if taille.x < 1300:
			var r := Rect2(Vector2.ZERO, Vector2(taille))
			check(r.encloses(p.get_global_rect()), "sur un téléphone, la fenêtre tient dans l'écran")
		p.queue_free()
		b._mise_en_scene()
		await process_frame
