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
	carte.duree_vol = 0.2
	carte.voler("casino_minuit")
	await create_timer(1.6, true).timeout
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
		await create_timer(5.0, true).timeout
	pj.global_position = Vector3(-19.5, 0.1, 10.5)
	pj.rotation.y = -PI / 2.0
	pj.velocity = Vector3.ZERO
	await create_timer(0.5, true).timeout
	var cible_p: Node = pj.focus_target
	check(cible_p != null and str(cible_p.get_meta("interact", "")) == "ascenseur_panneau", "dans la cabine, le tableau de bord : %s" % (str(cible_p.get_meta("prompt", "")) if cible_p else "rien"))
	s._ascenseurs.utiliser(asc.get_node("elevator-ASC-A/Panneau"))
	await create_timer(5.0, true).timeout
	check(E.cur.level == 1.0 and E.state == "idle", "la cabine est montée (niveau %s, %s)" % [E.cur.level, E.state])
	check(absf(pj.global_position.y - 6.0) < 0.3, "le joueur est monté avec elle (y %.2f)" % pj.global_position.y)
	pj.auto_move = Vector3(0, 0, -1)
	await create_timer(1.5, true).timeout
	pj.auto_move = Vector3.ZERO
	check(pj.global_position.x > -17.9 and absf(pj.global_position.y - 6.0) < 0.3, "il sort à la mezzanine (%s)" % str(pj.global_position))
	pj.global_position = Vector3(0, 0.05, 26.0)
	await create_timer(0.3, true).timeout

	# Une embrouille entre deux clients : la sécurité intervient et l'affaire se termine.
	var i0: int = pnj.log_.interventions
	var f = pnj.spawn_fight()
	check(f != null, "une embrouille éclate entre deux clients")
	if f != null:
		var t := 0.0
		while t < 150.0 and not f.ended:
			pnj.simulate(5.0)
			t += 5.0
		check(f.ended, "elle se termine (%s, en %d s)" % [f.how, t])
		check(pnj.log_.interventions > i0, "la sécurité est intervenue (%d)" % (pnj.log_.interventions - i0))
	c = pnj.check()
	check(c.inObstacle.is_empty() and c.leaks.is_empty(), "rien de gardé à tort après la bagarre %s %s" % [str(c.inObstacle.slice(0, 2)), str(c.leaks.slice(0, 3))])

	# Le joueur frappe un client sous l'œil d'un vigile : recherché, poursuivi, arrêté, mis à l'amende.
	var p: CharacterBody3D = s.player
	var cible = null
	for n in pnj.clients:
		if n.level == 0 and n.seatState == null and n.nav == null and not n.down and n.fight == null and not pnj.is_staff_zone(n.x, n.z, n.level) and pnj.guard_sees(n.x, n.z, 0.0) != null and pnj.M.degagement(0.0, n.x + 0.8, n.z) > 0.35:
			cible = n
			break
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
		check(p.global_position.distance_to(Vector3(0, 0, 28)) < 4.0, "il est reconduit à l'entrée, les coulisses lui étant fermées (%s)" % str(p.global_position))
		await create_timer(4.5, true).timeout
		check(not pnj.P.busy and pnj.P.wanted == null and not p.frozen, "puis relâché")
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
