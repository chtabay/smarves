extends SceneTree
## Deux joueurs sur le vrai canal Supabase Realtime (socle 1.23) :
## godot --headless --path . -s tools/test_presences_deux.gd
## Deux clients Presences, chacun avec sa scène, son habitant et sa propre connexion au canal, comme deux
## joueurs connectés au même lieu. La liste des présents, que la base donnerait (smarves_lieu_entrer),
## arrive à la main : l'essai ne touche ni au compte ni à la base. Sur un canal jetable tiré au hasard, on
## vérifie qu'ils se voient, que l'un suit l'autre quand il marche, qu'il disparaît hors de portée et
## revient, que les messages d'une commune passent dans les deux sens, puis qu'appariés dans un salon ils
## ne voient plus qu'eux, à 10 positions par seconde, avec le regard et l'état libre, et que le départ de
## l'un se voit tout de suite. Sans réseau, l'essai est sauté
## et le dit.

var PRESENCES: GDScript

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func attendre_que(f: Callable, s: float) -> bool:
	var t0 := Time.get_ticks_msec()
	while not f.call() and Time.get_ticks_msec() - t0 < s * 1000.0:
		await process_frame
	return f.call()


## Un joueur : sa scène, son habitant, son client Presences, sur le canal donné.
func joueur(nom: String, moi: String, canal: String, presents: Array) -> Dictionary:
	var scene := Node3D.new()
	scene.name = "Galerie_" + nom
	root.add_child(scene)
	var corps := Node3D.new()
	scene.add_child(corps)
	var p: Node = PRESENCES.new()
	p.name = "Presences_" + nom
	p.hors_ligne = true
	p.essai_canal = true
	root.add_child(p)
	p.entrer("essai", "galerie", scene, corps, 1.0)
	p.appliquer_vue({"canal": canal, "moi": moi, "cadence": 3, "presents": presents})
	var j := {"nom": nom, "scene": scene, "corps": corps, "p": p, "messages": []}
	p.message.connect(func(m, n, e, d): j.messages.append([n, e, d]))
	return j


func position_vue(chez: Dictionary, membre: String) -> Vector3:
	var x: Dictionary = chez.p.presents.get(membre, {})
	return x.points[-1][1] if x and not x.points.is_empty() else Vector3.INF


func _init() -> void:
	await process_frame
	PRESENCES = load("res://scripts/socle/presences.gd")
	var canal := "smarves:essai:galerie:%d" % (randi() % 1000000000)
	var liste := [{"membre": "aaaa11", "nom": "Ernestine", "tenue": "smoking"}, {"membre": "bbbb22", "nom": "Gaston", "tenue": ""}]
	var a := joueur("A", "aaaa11", canal, liste)
	var b := joueur("B", "bbbb22", canal, liste)
	var rejoints := await attendre_que(func(): return a.p._tr.est_rejoint and b.p._tr.est_rejoint, 15.0)
	if not rejoints:
		print("sauté   le vrai canal ne répond pas (pas de réseau ?)")
		quit(0)
		return
	check(true, "deux joueurs ont rejoint le canal de la galerie")

	# A marche : B le voit arriver et le suit.
	a.corps.position = Vector3(4, 0, 2)
	var t0 := Time.get_ticks_msec()
	var vu := await attendre_que(func(): return position_vue(b, "aaaa11").distance_to(Vector3(4, 0, 2)) < 0.05, 5.0)
	check(vu, "B reçoit la position de A (%d ms)" % (Time.get_ticks_msec() - t0))
	await attendre_que(func(): return is_instance_valid(b.p.presents.aaaa11.noeud), 2.0)
	var sil: Node3D = b.p.presents.aaaa11.noeud
	check(is_instance_valid(sil) and sil.visible and sil.get_parent() == b.scene, "la silhouette d'Ernestine est dans la scène de B")
	for i in 15:
		a.corps.position.x += 0.2
		await create_timer(0.1).timeout
	var arrivee: Vector3 = a.corps.position
	await attendre_que(func(): return sil.global_position.distance_to(arrivee) < 0.05, 3.0)
	check(sil.global_position.distance_to(arrivee) < 0.05, "elle suit A quand il marche, jusqu'à sa position d'arrivée")

	# Et dans l'autre sens.
	b.corps.position = Vector3(-3, 0, 1)
	vu = await attendre_que(func(): return position_vue(a, "bbbb22").distance_to(Vector3(-3, 0, 1)) < 0.05, 5.0)
	check(vu, "A voit B aussi")
	await attendre_que(func(): return a.p.autour().size() == 1, 2.0)
	var autour: Array = a.p.autour()
	check(autour.size() == 1 and autour[0].nom == "Gaston", "autour() chez A : Gaston, à portée")

	# Hors de portée, puis de retour.
	a.corps.position = Vector3(300, 0, 0)
	var parti := await attendre_que(func(): return not b.p.presents.aaaa11.a_portee, 5.0)
	check(parti and not sil.visible, "A s'éloigne au-delà de la portée : B ne le voit plus")
	a.corps.position = Vector3(2, 0, 0)
	var revenu := await attendre_que(func(): return b.p.presents.aaaa11.a_portee and b.p.presents.aaaa11.noeud.visible, 5.0)
	check(revenu, "il revient à portée : B le revoit")

	# Les messages de la commune, dans les deux sens.
	check(a.p.envoyer("pret", {"salle": "lab1"}), "A dit qu'il est prêt")
	var recu := await attendre_que(func(): return not b.messages.is_empty(), 5.0)
	check(recu and b.messages[0] == ["Ernestine", "pret", {"salle": "lab1"}], "B reçoit le message, signé du nom de A")
	b.p.envoyer("geste", {"action": "nord", "n": 1})
	recu = await attendre_que(func(): return not a.messages.is_empty(), 5.0)
	check(recu and a.messages[0][0] == "Gaston" and a.messages[0][2].action == "nord", "A reçoit le geste de B")
	check(a.messages.size() == 1 and b.messages.size() == 1, "pas d'écho chez soi")

	# Un troisième joueur dans la galerie ; A et B s'apparient et passent dans leur salon.
	var liste3 := liste + [{"membre": "cccc33", "nom": "Lucienne", "tenue": ""}]
	var c := joueur("C", "cccc33", canal, liste3)
	for j in [a, b]:
		j.p.appliquer_vue({"canal": canal, "moi": j.p.moi, "cadence": 3, "presents": liste3})
	await attendre_que(func(): return c.p._tr.est_rejoint, 15.0)
	c.corps.position = Vector3(1, 0, 1)
	await attendre_que(func(): return a.p.presents.cccc33.a_portee, 5.0)
	check(a.p.presents.cccc33.a_portee, "dans la loge, A voit aussi Lucienne")
	var arrives := []
	var partis := []
	b.p.arrive.connect(func(m, n): arrives.append(n))
	b.p.parti.connect(func(m, n): partis.append(n))
	a.p.salon("lab1_42")
	b.p.salon("lab1_42")
	await attendre_que(func(): return a.p._tr.est_rejoint and b.p._tr.est_rejoint, 15.0)
	a.corps.position = Vector3(0.5, 0, 0.5)
	await attendre_que(func(): return b.p.presents.aaaa11.a_portee, 5.0)
	check(b.p.presents.aaaa11.a_portee and "Ernestine" in arrives, "dans le salon, B retrouve A (signal arrive)")
	c.corps.position = Vector3(2, 0, 2)
	await create_timer(1.5).timeout
	check(not b.p.presents.cccc33.a_portee and not a.p.presents.cccc33.a_portee, "mais plus Lucienne, restée dans la loge")
	check(not c.p.presents.aaaa11.a_portee or c.p.presents.aaaa11.part >= 0.0, "et Lucienne ne voit plus A")

	# À 10 positions par seconde, avec le regard et l'état libre.
	var n0: int = b.p.presents.aaaa11.points.size()
	var t1 := Time.get_ticks_msec()
	var recues := 0
	var dernier: float = b.p.presents.aaaa11.vu
	while Time.get_ticks_msec() - t1 < 2000:
		a.corps.position.x += 0.02
		await process_frame
		if b.p.presents.aaaa11.vu != dernier:
			dernier = b.p.presents.aaaa11.vu
			recues += 1
	check(recues >= 14, "dans le salon, environ 10 positions par seconde (%d en 2 s)" % recues)
	var etats := []
	b.p.etat_change.connect(func(m, e): etats.append(e))
	a.p.etat_libre = {"lampe": true, "cle": "rouge"}
	await attendre_que(func(): return not etats.is_empty(), 3.0)
	check(etats.size() >= 1 and etats[-1] == {"lampe": true, "cle": "rouge"}, "B reçoit l'état libre de A (lampe, clé)")
	await create_timer(0.4).timeout
	var ou: Dictionary = b.p.etat_de("aaaa11")
	check(ou.get("etat", {}).get("cle", "") == "rouge" and ou.has("regard"), "etat_de() : position, regard et état")

	# A s'en va : B le voit encore un instant, puis plus.
	a.p.salon("")
	await attendre_que(func(): return "Ernestine" in partis, 3.0)
	check("Ernestine" in partis and is_instance_valid(b.p.presents.aaaa11.noeud) and b.p.presents.aaaa11.noeud.visible,
		"A quitte le salon : B le sait tout de suite et le voit encore à sa place")
	await create_timer(3.3).timeout
	check(not b.p.presents.aaaa11.a_portee, "puis il s'éclipse")

	for j in [a, b, c]:
		j.scene.queue_free()
	await process_frame
	await process_frame
	check(not a.p._tr.est_rejoint and not b.p._tr.est_rejoint and not c.p._tr.est_rejoint, "quitter la scène ferme le canal")
	print("%s : %d échec(s)" % ["test_presences_deux", fails])
	quit(1 if fails else 0)
