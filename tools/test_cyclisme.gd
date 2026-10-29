extends SceneTree
## Vérifie les courses cyclistes du socle sans affichage : godot --headless --path . -s tools/test_cyclisme.gd
## Le vocabulaire de la structure « course_velo », le calendrier, le peloton tiré de la graine, les chances et les
## cotes (gagnant, placé), le résultat commun rejoué à l'identique, le direct (position, en_direct), les paris et
## leur règlement, la marge de la maison sur deux cents éditions, l'agenda, le programme (CoursePanel) sur un
## ordinateur et sur un téléphone, et le peloton posé sur un parcours de repères (Peloton).

var fails := 0
var horloge := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	var cy: Node = root.get_node("Cyclisme")
	cy.dossier = ""
	cy.effacer()
	root.get_node("Football").regler_horloge(func(): return horloge)
	_vocabulaire()
	var e := _inscrire()
	_calendrier(cy, e)
	_moteur(cy, e)
	_paris(cy, e, game)
	_marge(cy, e)
	_agenda(e)
	await _programme(cy, e, game)
	await _peloton(cy, e)
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


## Le samedi 31 octobre 2026 à 10 h, en secondes locales.
static func samedi() -> int:
	return int(Time.get_unix_time_from_datetime_dict({"year": 2026, "month": 10, "day": 31, "hour": 10, "minute": 0, "second": 0}))


func _vocabulaire() -> void:
	var st: GDScript = load("res://scripts/socle/structures.gd")
	var bonne := {"type": "course_velo", "id": "gp", "nom": "Le Grand Prix", "parcours": ["A", "B", "C"], "distance": 2500.0,
		"tours": 8.0, "relief": "vallonne", "jour": "dimanche", "heure": 10.5, "coureurs": 12.0}
	check(st.verifier([bonne]).is_empty(), "une course cycliste se déclare %s" % str(st.verifier([bonne])))
	check(st.verifier([bonne, bonne.merged({"id": "autre"}, true)]).is_empty(), "  une commune peut en avoir plusieurs")
	var fautes := {"un parcours d'un seul repère": {"parcours": ["A"]}, "une distance trop courte": {"distance": 50.0},
		"un nombre de tours qui n'est pas entier": {"tours": 2.5}, "un relief inconnu": {"relief": "lunaire"},
		"un jour inconnu": {"jour": "octidi"}, "trop de coureurs": {"coureurs": 40.0}, "une heure de nuit": {"heure": 3.0}}
	for k in fautes:
		check(st.verifier([bonne.merged(fautes[k], true)]).size() == 1, "  %s est refusé" % k)
	var sans := bonne.duplicate()
	sans.erase("distance")
	check(not st.verifier([sans]).is_empty(), "  une course sans distance est refusée")


## Une course d'essai au registre, comme si une commune installée la déclarait.
func _inscrire() -> Dictionary:
	var e := {"cle": "essai_velo/gp", "commune": "essai_velo", "insee": "", "commune_nom": "Essai-sur-Selle", "centre": Vector2.ZERO,
		"installee": true, "type": "course_velo", "id": "gp", "nom": "Le Grand Prix d'essai", "noeud": "", "lot": "",
		"champs": {"parcours": ["R1", "R2", "R3", "R4"], "distance": 2000.0, "tours": 6.0, "relief": "vallonne", "jour": "samedi", "heure": 15.0, "coureurs": 12.0}}
	root.get_node("Registre").entrees.append(e)
	return e


func _calendrier(cy: Node, e: Dictionary) -> void:
	horloge = samedi()
	var d: int = cy.prochain_depart(e, horloge)
	check(d == samedi() + 5 * 3600, "le prochain départ : samedi à 15 h (%s)" % Time.get_datetime_string_from_unix_time(d))
	check(cy.departs(e, horloge, horloge + 21 * 86400).size() == 3, "  un départ par semaine")
	check(cy.duree(e) == int(round(12000.0 / cy.VITESSE)), "  12 km à 40 km/h : %d min" % (cy.duree(e) / 60))
	var dimanche := e.duplicate(true)
	dimanche.champs.jour = "dimanche"
	dimanche.champs.heure = 10.5
	check(cy.prochain_depart(dimanche, horloge) == samedi() + 86400 + 1800, "  une course du dimanche à 10 h 30")
	check(cy.edition(e, horloge) == d, "  avant le départ, on parle de l'édition qui vient")


func _moteur(cy: Node, e: Dictionary) -> void:
	var d: int = cy.prochain_depart(e, samedi())
	var r: Array = cy.engages(e, d)
	check(r.size() == 12 and r == cy.engages(e, d + 7 * 86400), "douze engagés, le même peloton toute l'année")
	var noms := {}
	for x in r:
		noms[x.nom] = true
	check(noms.size() == 12, "  douze noms différents")
	var ch: Dictionary = cy.chances(e, d)
	var p: Array = ch.gagnant
	var somme := 0.0
	for x in p:
		somme += x
	check(absf(somme - 1.0) < 1e-6, "les chances de gagner, tirées de trois cents courses rejouées, font 1")
	check(cy.pronostic(e, d) == ch, "  le pronostic est le même chez tout le monde")
	var pl: Array = ch.place
	var somme_pl := 0.0
	var plus := true
	for i in pl.size():
		somme_pl += pl[i]
		plus = plus and pl[i] >= p[i] - 1e-9
	check(absf(somme_pl - 3.0) < 0.1 and plus, "les chances d'être placé font 3, chacune au-dessus de celle de gagner (%.4f)" % somme_pl)
	var c: Dictionary = cy.cotes(e, d)
	var favori := 0
	for i in p.size():
		if p[i] > p[favori]:
			favori = i
	var mini_cote := 999.0
	for num in c:
		mini_cote = minf(mini_cote, c[num].gagnant)
	check(c[int(r[favori].num)].gagnant == mini_cote and c.values().all(func(x): return x.gagnant >= 1.05 and x.place >= 1.05 and x.place <= x.gagnant),
		"le favori a la plus petite cote ; toutes au-dessus de 1,05, la place sous le gagnant")
	var a: Dictionary = cy.calculer(e, d)
	check(a == cy.calculer(e, d), "le résultat d'une édition se rejoue à l'identique")
	check(a.ordre.size() + a.abandons.size() == 12, "  chacun arrive ou abandonne")
	var croissant := true
	for i in range(1, a.ordre.size()):
		croissant = croissant and a.temps[a.ordre[i]] >= a.temps[a.ordre[i - 1]]
	check(croissant, "  le classement suit les temps")
	var vainqueur: float = a.temps[a.ordre[0]]
	check(absf(vainqueur / cy.duree(e) - 1.0) < 0.15, "  le vainqueur roule à 40 km/h, à 15 %% près (%d s pour %d)" % [int(vainqueur), cy.duree(e)])
	var differents := 0
	for k in 4:
		if cy.calculer(e, d + (k + 1) * 7 * 86400).ordre != a.ordre:
			differents += 1
	check(differents >= 3, "  une autre édition, un autre classement")
	check(cy.position(e, d, int(a.ordre[0]), d) == 0.0 and cy.position(e, d, int(a.ordre[0]), d + vainqueur + 1) == 12000.0,
		"le vainqueur part de zéro et finit ses 12 km")
	var mi: float = cy.position(e, d, int(a.ordre[0]), d + vainqueur / 2.0)
	check(mi > 4000.0 and mi < 8000.0, "  à mi-course, il est à mi-parcours (%d m)" % int(mi))
	check(cy.en_direct(e, d - 60).etat == "avant", "avant le départ : « avant »")
	var dir: Dictionary = cy.en_direct(e, d + int(vainqueur / 2.0))
	check(dir.etat == "course" and dir.tour >= 3 and dir.tour <= 4 and dir.classement.size() == 12 - a.abandons.keys().filter(func(x): return a.abandons[x] <= 3).size(),
		"  à mi-course : « course », tour %d sur %d" % [int(dir.tour), int(dir.tours)])
	var fin: Dictionary = cy.en_direct(e, cy.fin(e, d) + 1)
	check(fin.etat == "arrivee" and int(fin.tete) == int(a.ordre[0]), "  après le dernier : « arrivee », le vainqueur en tête")


func _paris(cy: Node, e: Dictionary, game: Node) -> void:
	horloge = samedi()
	var d: int = cy.prochain_depart(e, horloge)
	var res: Dictionary = cy.resultat(e, d)
	game.credits = 1000
	var avant_won: int = game.won
	var gagnant: Dictionary = cy.parier(e, d, int(res.ordre[0]), "gagnant", 100)
	var place: Dictionary = cy.parier(e, d, int(res.ordre[2]), "place", 50)
	var perdu: Dictionary = cy.parier(e, d, int(res.ordre[-1]), "gagnant", 20)
	check(gagnant.ok and place.ok and perdu.ok and game.credits == 830, "trois tickets avant le départ, les mises partent tout de suite")
	check(cy.parier(e, d, 99, "gagnant", 10).raison == "inconnu" and cy.parier(e, d, 1, "tiercé", 10).raison == "inconnu", "  un dossard ou un pari inconnu est refusé")
	check(cy.parier(e, d, 1, "gagnant", 0).raison == "mise", "  une mise nulle est refusée")
	horloge = d + 1
	check(cy.parier(e, d, 1, "gagnant", 10).raison == "ferme", "  après le départ, les paris sont fermés")
	horloge = cy.fin(e, d) + 60
	check(cy.regler().is_empty(), "  rien ne se règle avant dix minutes après le dernier coureur")
	horloge = cy.fin(e, d) + cy.REGLEMENT + 1
	var regles: Array = cy.regler()
	var attendu := int(round(100 * gagnant.ticket.cote)) + int(round(50 * place.ticket.cote))
	check(regles.size() == 3 and game.credits == 830 + attendu and game.won == avant_won + attendu,
		"le règlement : le gagnant et le placé paient (%d), le perdant non" % attendu)
	check(gagnant.ticket.etat == "gagne" and place.ticket.etat == "gagne" and perdu.ticket.etat == "perdu", "  chacun son état")
	check(cy.non_vus().size() == 3 and cy.non_vus().is_empty(), "  le tenancier en parle une fois")
	check(cy.bilan().tickets == 3 and cy.bilan().mise == 170 and cy.bilan().gagne == attendu, "  le bilan depuis le début")


## Sur cent vingt éditions, parier un crédit gagnant sur chaque coureur rend moins qu'on mise : la maison garde sa
## marge, sans tout prendre.
func _marge(cy: Node, e: Dictionary) -> void:
	var d: int = cy.prochain_depart(e, samedi())
	var mise := 0.0
	var rendu := 0.0
	var favori_gagne := 0
	var p_favori := 0.0
	for k in 120:
		var dk := d + k * 7 * 86400
		var c: Dictionary = cy.cotes(e, dk)
		var res: Dictionary = cy.calculer(e, dk)
		mise += c.size()
		if not res.ordre.is_empty():
			rendu += c[int(res.ordre[0])].gagnant
		var p: Array = cy.chances(e, dk).gagnant
		var f := 0
		for i in p.size():
			if p[i] > p[f]:
				f = i
		p_favori += p[f]
		if not res.ordre.is_empty() and int(res.ordre[0]) == f + 1:
			favori_gagne += 1
	var taux := rendu / mise
	check(taux > 0.65 and taux < 1.05, "parier sur tous rend %.0f %% des mises sur cent vingt éditions (la marge garde 12 %%)" % (taux * 100.0))
	check(absf(favori_gagne / 120.0 - p_favori / 120.0) < 0.12, "  le favori gagne ce que disent ses chances (%.0f %% pour %.0f %%)" % [favori_gagne / 1.2, p_favori / 1.2])


func _agenda(e: Dictionary) -> void:
	horloge = samedi()
	var agenda: Node = root.get_node("Agenda")
	var rv: Array = agenda.semaine(horloge).filter(func(x): return x.activite == "cyclisme")
	# De samedi matin au dimanche de la semaine suivante : deux samedis.
	check(rv.size() == 2 and rv[0].quand == samedi() + 5 * 3600 and rv[0].titre == "Le Grand Prix d'essai" and rv[0].lieu == "Essai-sur-Selle",
		"l'agenda de la semaine porte le départ de la course")


func _programme(cy: Node, e: Dictionary, game: Node) -> void:
	cy.effacer()
	game.credits = 1000
	for taille in [Vector2i(1600, 900), Vector2i(1067, 600)]:
		root.size = taille
		horloge = samedi()
		var p: Node = load("res://scripts/socle/course_panel.gd").de("essai_velo", "gp")
		root.add_child(p)
		await process_frame
		check(p.find_children("Choix_*", "Button", true, false).size() == 24, "%d × %d : douze coureurs, gagnant et placé chacun" % [taille.x, taille.y])
		check(p.teneur == "Le directeur de course", "  sans lieu, c'est le directeur de course qui prend les paris")
		(p.find_child("Choix_3_place", true, false) as Button).pressed.emit()
		await process_frame
		check(p.choix == {"num": 3, "genre": "place"}, "  on coche le n° 3 placé")
		var avant: int = game.credits
		check(p.jouer() and game.credits == avant - 20, "  le ticket est joué")
		horloge = cy.prochain_depart(e, samedi()) + 900
		p.remplir(p._colonne)
		await process_frame
		check(p.find_children("Choix_*", "Button", true, false).is_empty() and p.find_child("Jouer", true, false) == null, "  pendant la course, plus de paris")
		var lu := false
		for l in p.find_children("*", "Label", true, false):
			if (l as Label).text.begins_with("En course"):
				lu = true
		check(lu, "  la fenêtre dit où en est la course")
		p.queue_free()
		await process_frame
		cy.effacer()


## Un parcours de quatre repères en carré, et le peloton posé dessus.
func _peloton(cy: Node, e: Dictionary) -> void:
	var scene := Node3D.new()
	scene.name = "Scene"
	root.add_child(scene)
	# 2 000 m en quatre côtés : 500 m chacun, soit 208,3 unités.
	var peloton: GDScript = load("res://scripts/socle/peloton.gd")
	var cote: float = 500.0 / peloton.METRES_PAR_UNITE
	var coins := [Vector3(0, 0, 0), Vector3(cote, 0, 0), Vector3(cote, 0, cote), Vector3(0, 0, cote)]
	for i in 4:
		var m := Marker3D.new()
		m.name = "R%d" % (i + 1)
		m.position = coins[i]
		scene.add_child(m)
	var p: Node = peloton.poser(scene, "essai_velo", "gp")
	check(p != null and absf(p.longueur() - 2000.0) < 0.5, "le peloton trace le parcours fermé : %d m" % (int(p.longueur()) if p else 0))
	if p == null:
		return
	var d: int = cy.prochain_depart(e, samedi())
	p.horloge = func(): return horloge
	horloge = d - 3 * 3600
	p.actualiser()
	check(p._coureurs.is_empty() or p._coureurs.values().all(func(c): return not c.visible), "  trois heures avant : personne")
	horloge = d - 600
	p.actualiser()
	check(p._coureurs.size() == 12 and p._coureurs.values().all(func(c): return c.visible and c.global_position.x < 0.01), "  dix minutes avant : douze coureurs alignés derrière la ligne")
	check(p._bandeau.visible and p._bandeau.text.contains("départ dans 10 min"), "  le bandeau compte les minutes : %s" % p._bandeau.text)
	horloge = d + 600
	p.actualiser()
	var sur_la_route := true
	for c in p._coureurs.values():
		if not c.visible:
			continue
		var q: Vector3 = c.global_position
		# Sur un côté du carré, à la largeur du peloton près.
		var bord := minf(minf(absf(q.x), absf(q.x - cote)), minf(absf(q.z), absf(q.z - cote)))
		sur_la_route = sur_la_route and bord < 2.0
	check(sur_la_route, "  en course, chacun roule sur le parcours")
	check(p._bandeau.text.contains("tour "), "  le bandeau : %s" % p._bandeau.text)
	horloge = cy.fin(e, d) + 30
	p.actualiser()
	check(p._bandeau.text.contains("vainqueur"), "  à l'arrivée : %s" % p._bandeau.text)
	scene.queue_free()
	await process_frame
