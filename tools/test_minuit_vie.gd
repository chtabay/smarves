extends SceneTree
## La vie de Casino Minuit, fidèle à l'original (js/npc.js) : godot --headless --path . -s tools/test_minuit_vie.gd
## On vole à Minuit ; les PNJ peuplent le casino (clients, personnel à leurs postes), vivent quelques minutes
## sans finir dans un obstacle ni garder une place ou un point qu'ils ont quittés ; une embrouille forcée appelle
## la sécurité, qui emmène les deux ; le joueur qui frappe un client est recherché, poursuivi, arrêté et mis à
## l'amende.

const SOURCE := "res://tools/paquet_essai/casino_minuit/"
const TMP := "user://test_minuit_vie/"

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var communes: Node = root.get_node("Communes")
	var carte: Node = root.get_node("Carte")
	DirAccess.make_dir_recursive_absolute(TMP)
	communes.dossier_greffes = TMP
	var pck := TMP + "casino_minuit.pck"
	var pk := PCKPacker.new()
	pk.pck_start(pck)
	_emballer(pk, SOURCE, SOURCE)
	pk.flush()
	check(communes.charger_pack(pck) == "casino_minuit", "Casino Minuit se greffe %s" % str(communes.refus))
	# MINUIT_OUVERT=1 : tous les lieux ouverts (seuils franchis), les clients vont aussi au concert et à la boxe
	if OS.get_environment("MINUIT_OUVERT") != "":
		root.get_node("Game").won = 1000000000
	carte.duree_vol = 0.2
	carte.voler("casino_minuit")
	await create_timer(1.6, true).timeout
	# Le casino se bâtit derrière l'écran de chargement (socle 1.11) : on attend qu'il s'efface.
	while root.get_node("Chargement").actif():
		await process_frame
	var s: Node = current_scene
	var pnj = s.get("pnj") if s != null else null
	check(pnj != null, "le casino a ses PNJ")
	if pnj == null:
		_fin()
		return
	await create_timer(1.0, true).timeout
	var st: Dictionary = pnj.stats()
	print("        ", st)
	check(st.ready and st.clients > 40 and st.staff > 20, "clients et personnel sont là (%d clients, %d employés)" % [st.clients, st.staff])
	pnj.synchrone = true
	var t0 := Time.get_ticks_msec()
	pnj.simulate(120.0)
	var ms := Time.get_ticks_msec() - t0
	print("        deux minutes simulées en %d ms" % ms)
	st = pnj.stats()
	print("        ", st)
	var c: Dictionary = pnj.check()
	check(c.inObstacle.is_empty(), "aucun PNJ dans un obstacle %s" % str(c.inObstacle.slice(0, 3)))
	check(c.leaks.is_empty(), "aucune place ni point gardé à tort %s" % str(c.leaks.slice(0, 4)))

	# L'ascenseur ouest : on y entre au rez-de-chaussée, on monte à la mezzanine, on en sort.
	var asc: Node = s.get_node_or_null("Ascenseurs")
	check(asc != null and asc.get_node_or_null("elevator-ASC-A") != null, "les cabines des trois ascenseurs sont là")
	var E: Dictionary = pnj.elevators["ASC-A"]
	var pj: CharacterBody3D = s.player
	if E.cur.level != 0.0:
		pnj.elev_go(E, 0.0)
	var tw := 0.0
	while tw < 30.0 and not (E.cur.level == 0.0 and E.state == "idle"):
		# un PNJ a pu la rappeler entre-temps : on la redemande tant qu'elle n'est pas en bas
		if E.state == "idle" and E.pending == null:
			pnj.elev_go(E, 0.0)
		await create_timer(0.25, true).timeout
		tw += 0.25
	pj.global_position = Vector3(-19.5, 0.1, 10.5)
	pj.rotation.y = -PI / 2.0
	pj.velocity = Vector3.ZERO
	print("        cabine : niveau %s, %s, y %.2f, attendu %.1f s" % [E.cur.level, E.state, E.y, tw])
	await create_timer(0.5, true).timeout
	print("        puis : niveau %s, %s, y %.2f ; joueur y %.2f" % [E.cur.level, E.state, E.y, pj.global_position.y])
	var cible_p: Node = pj.focus_target
	check(cible_p != null and str(cible_p.get_meta("interact", "")) == "ascenseur_panneau", "dans la cabine, le tableau de bord : %s" % (str(cible_p.get_meta("prompt", "")) if cible_p else "rien"))
	s._ascenseurs.utiliser(asc.get_node("elevator-ASC-A/Panneau"))
	await create_timer(1.0, true).timeout
	tw = 0.0
	while tw < 20.0 and not (E.cur.level == 1.0 and E.state == "idle"):
		await create_timer(0.25, true).timeout
		tw += 0.25
	check(E.cur.level == 1.0 and E.state == "idle", "la cabine est montée (niveau %s, %s)" % [E.cur.level, E.state])
	check(absf(pj.global_position.y - 6.0) < 0.3, "le joueur est monté avec elle (y %.2f)" % pj.global_position.y)
	pj.auto_move = Vector3(0, 0, -1)
	await create_timer(1.5, true).timeout
	pj.auto_move = Vector3.ZERO
	check(pj.global_position.x > -17.9 and absf(pj.global_position.y - 6.0) < 0.3, "il sort à la mezzanine (%s)" % str(pj.global_position))
	pj.global_position = Vector3(0, 0.05, 26.0)
	await create_timer(0.3, true).timeout

	# Une embrouille entre deux clients : la sécurité intervient et l'affaire se termine. Un témoin peut aussi les
	# séparer avant l'arrivée des vigiles (comme dans l'original) : jusqu'à trois embrouilles pour voir la sécurité.
	var i0: int = pnj.log_.interventions
	for essai in 3:
		var f = pnj.spawn_fight()
		check(f != null, "une embrouille éclate entre deux clients")
		if f == null:
			break
		var t := 0.0
		while t < 150.0 and not f.ended:
			pnj.simulate(5.0)
			t += 5.0
		check(f.ended, "elle se termine (%s, en %d s)" % [f.how, t])
		if pnj.log_.interventions > i0:
			break
	check(pnj.log_.interventions > i0, "la sécurité est intervenue (%d)" % (pnj.log_.interventions - i0))
	c = pnj.check()
	check(c.inObstacle.is_empty() and c.leaks.is_empty(), "rien de gardé à tort après la bagarre %s %s" % [str(c.inObstacle.slice(0, 2)), str(c.leaks.slice(0, 3))])

	# Le joueur frappe un client sous l'œil d'un vigile : recherché, poursuivi, arrêté, mis à l'amende.
	var p: CharacterBody3D = s.player
	var cible = null
	for essai in 10:
		for n in pnj.clients:
			if n.level == 0 and n.seatState == null and n.nav == null and not n.down and n.fight == null and not (n.hostile and pnj.now - n.hostileT < 40) and not pnj.is_staff_zone(n.x, n.z, n.level) and pnj.guard_sees(n.x, n.z, 0.0) != null and pnj.M.degagement(0.0, n.x + 0.8, n.z) > 0.35:
				cible = n
				break
		if cible != null:
			break
		pnj.simulate(3.0)
	if cible == null:
		var cpt := [0, 0, 0, 0, 0]
		for n in pnj.clients:
			if n.level == 0 and n.seatState == null and not n.down:
				cpt[0] += 1
				if n.nav == null:
					cpt[1] += 1
					if not pnj.is_staff_zone(n.x, n.z, n.level):
						cpt[2] += 1
						if pnj.guard_sees(n.x, n.z, 0.0) != null:
							cpt[3] += 1
							if not (n.hostile and pnj.now - n.hostileT < 40):
								cpt[4] += 1
		print("        clients debout au rez-de-chaussée, à l'arrêt, en salle, vus d'un vigile, calmes : ", cpt, " ; joueur ", p.global_position)
	check(cible != null, "un client à portée d'un vigile")
	if cible != null:
		var game: Node = root.get_node("Game")
		game.credits = 5000
		p.global_position = Vector3(cible.x + 0.8, 0.05, cible.z)
		p.velocity = Vector3.ZERO
		pnj.simulate(0.1)
		pnj.player_hits(cible)
		check(pnj.P.wanted != null, "le joueur est recherché (%s)" % str(pnj.P.wanted))
		var amende: int = pnj.fine_of(pnj.P.wanted.sev) if pnj.P.wanted != null else 0
		var t := 0.0
		while t < 60.0 and not pnj.P.busy:
			pnj.simulate(0.5)
			t += 0.5
			await process_frame
		check(pnj.P.busy, "un vigile l'arrête (en %.1f s)" % t)
		await create_timer(3.0, true).timeout
		check(game.credits == 5000 - amende, "l'amende de %d est prélevée (reste %d)" % [amende, game.credits])
		if pnj._coulisses_ouvertes():
			var d: Dictionary = pnj.world.detain
			check(Vector2(p.global_position.x - d.x, p.global_position.z - d.z).length() < 4.0 and absf(p.global_position.y - pnj.M.niveau_y(d.level)) < 0.5, "il est conduit à la salle d'entretien, au sous-sol (%s)" % str(p.global_position))
		else:
			check(p.global_position.distance_to(Vector3(0, 0, 28)) < 4.0, "il est reconduit à l'entrée, les coulisses lui étant fermées (%s)" % str(p.global_position))
		await create_timer(4.5, true).timeout
		check(not pnj.P.busy and pnj.P.wanted == null and not p.frozen, "puis relâché")
	await _vie(s, pnj)
	_fin()


func _emballer(pk: PCKPacker, dossier: String, racine: String) -> void:
	var d := DirAccess.open(dossier)
	for f in d.get_files():
		if not f.ends_with(".uid"):
			pk.add_file("res://communes/casino_minuit/" + (dossier + f).trim_prefix(racine), dossier + f)
	for sous in d.get_directories():
		_emballer(pk, dossier + sous + "/", racine)


func _fin() -> void:
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


## La vague « vie » (js/npc-vie.js) : les passants du Strip, le concert des Lyres, le combat de l'arène.
func _vie(s: Node, pnj) -> void:
	var vie = pnj.vie
	check(vie != null and vie.venues.has("strip") and vie.venues.has("concert") and vie.venues.has("arene"), "la vie a ses trois lieux %s" % (str(vie.venues.keys()) if vie else "—"))
	if vie == null or vie.venues.size() < 3:
		return
	var pil = s.K.places.pilotes
	var p: CharacterBody3D = s.player

	# le Strip : des passants tout autour du joueur, sur les trottoirs ; aux fontaines, ils s'arrêtent regarder
	await _aller(p, Vector3(0, 0.05, 40))
	var V: Dictionary = vie.venues.strip
	_pas(pil, pnj, 20.0)
	var vus: Array = V.extras.filter(func(n): return not n.hidden)
	check(V.on and vus.size() >= 18, "le Strip a ses passants (%d sur %d)" % [vus.size(), V.extras.size()])
	var hors: Array = vus.filter(func(n): return pnj.M.degagement(0.0, n.x, n.z) < 0.2 and n.vs.s != "cross")
	check(hors.is_empty(), "aucun passant dans un obstacle %s" % str(hors.map(func(n): return [n.x, n.z, n.vs.s]).slice(0, 3)))
	var F: Dictionary = s.K.places.e_fontaines_etat
	F.debut = F.t
	await create_timer(0.5, true).timeout
	_pas(pil, pnj, 25.0)
	check(vie.stat.fountainWatch > 0, "aux fontaines, des passants s'arrêtent regarder (%d)" % vie.stat.fountainWatch)

	# le concert : les Lyres sur scène, le public danse ; à l'entracte il souffle, au morceau suivant il repart
	await _aller(p, Vector3(22, 0.05, -40))
	V = vie.venues.concert
	_pas(pil, pnj, 4.0)
	var mus: Array = V.musicians.filter(func(n): return not n.hidden)
	var dans: Array = V.dancers.filter(func(n): return not n.hidden and n.vs.s == "dance")
	check(V.on and mus.size() == V.musicians.size() and mus.size() >= 5, "les musiciens sont sur scène (%d)" % mus.size())
	check(dans.size() >= 15, "le public danse (%d)" % dans.size())
	var CO: Dictionary = pil.concert
	CO.songTime = CO.song.duree - 0.1
	var idx: int = CO.index
	_pas(pil, pnj, 1.0)
	check(CO.state == "entracte", "le morceau se termine : entracte")
	_pas(pil, pnj, 10.0)
	check(CO.state == "morceau" and CO.index == (idx + 1) % 5, "puis le morceau suivant : %s" % CO.song.titre)
	_pas(pil, pnj, 6.0)
	dans = V.dancers.filter(func(n): return not n.hidden and n.vs.s == "dance")
	check(dans.size() >= 8, "le public danse de nouveau (%d)" % dans.size())

	# l'arène : la cloche lance le round, les boxeurs échangent, un knock-down, le compte, la décision
	await _aller(p, Vector3(0, 0.05, 119))
	V = vie.venues.arene
	_pas(pil, pnj, 3.0)
	check(V.on and not V.rouge.hidden and not V.bleu.hidden and not V.ref.hidden, "les boxeurs et l'arbitre sont sur le ring")
	var AR: Dictionary = pil.arene
	if AR.state != "round":
		pil.bell("joueur")
	_pas(pil, pnj, 30.0)
	check(AR.state == "round" and vie.stat.coups > 5, "le round : les boxeurs échangent (%d coups, %d touchés)" % [vie.stat.coups, vie.stat.touches])
	var kd0: int = vie.stat.knockdowns
	check(vie.test_knockdown() and V.kd != null, "un knock-down : l'arbitre compte")
	_pas(pil, pnj, 20.0)
	check(vie.stat.knockdowns > kd0 and V.kd == null, "le boxeur se relève")
	AR.round = AR.rounds
	pil.bell("joueur")
	_pas(pil, pnj, 8.0)
	check(AR.state == "fin" and V.winner != "", "fin du combat : décision pour le coin %s" % V.winner)
	var sp: Array = V.spectators.filter(func(n): return not n.hidden)
	check(sp.size() >= 15, "le public de l'arène est là (%d)" % sp.size())
	# la foule de fond : de près, des figurants prennent la place des silhouettes, et la leur rendent de loin
	var it = null
	for x in V.swap.list:
		if x.level == 0.0 and Vector2(x.x, x.z - 127.0).length() > 8.0:
			it = x
			break
	check(it != null, "l'arène a sa foule de fond (%d silhouettes)" % V.swap.list.size())
	if it != null:
		var sw0: int = vie.stat.swaps
		await _aller(p, Vector3(it.x + 1.5, pnj.M.niveau_y(0.0) + 0.05 + it.y, it.z + 1.5))
		_pas(pil, pnj, 1.0)
		var cm: Camera3D = s.get_viewport().get_camera_3d()
		var pris: Array = V.swap.list.filter(func(x): return x.npc != null)
		var loin: Array = pris.filter(func(x): return Vector3(x.x, x.y, x.z).distance_to(cm.global_position) > vie.CFG.proxyOut + 2.0)
		check(vie.stat.swaps > sw0 and pris.size() > 0 and loin.is_empty() and pris.all(func(x): return not x.npc.hidden), "de près, des figurants prennent la place des silhouettes (%d, tous à portée)" % pris.size())
		await _aller(p, Vector3(0, 0.05, 20))
		_pas(pil, pnj, 1.0)
		check(V.swap.active == 0 and V.swap.list.all(func(x): return x.npc == null), "de loin, les silhouettes reviennent")
	print("        ", vie.stats())
	var fb := {}
	for k in pnj.log_.failBy:
		if "concert" in k or "boxe" in k or "spot" in k or "use" in k:
			fb[k] = pnj.log_.failBy[k]
	print("        échecs de chemin : ", fb)
	if pnj.lieux_fermes.has("concert"):
		check(not fb.keys().any(func(k): return k.begins_with("concert")), "concert fermé : aucun client n'essaie d'y aller")
	else:
		check(int(vie.stat.arrivals.get("client concert", 0)) > 0 or int(vie.stats().clients.get("concert", 0)) > 0, "concert ouvert : des clients y vont danser %s" % str(vie.stats().clients))
	var c: Dictionary = pnj.check()
	check(c.leaks.is_empty(), "rien de gardé à tort après la vie %s" % str(c.leaks.slice(0, 4)))


## Les pilotes (concert, combat) et les PNJ ensemble, par pas d'un quart de seconde.
func _pas(pil, pnj, d: float) -> void:
	var t := 0.0
	while t < d:
		pil.pas(0.25)
		pnj.simulate(0.25)
		t += 0.25


func _aller(p: CharacterBody3D, at: Vector3) -> void:
	p.global_position = at
	p.velocity = Vector3.ZERO
	for i in 6:
		await process_frame
