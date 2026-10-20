extends RefCounted
## Les figurants du lot A, sur le modèle du jeu web : le personnel à son poste (barmen, croupiers aux
## tables fermées, vigiles aux portes, une hôtesse), des clients au bar, aux mange-debout, autour de la
## fontaine, accoudés à la galerie, et des promeneurs qui font le tour du casino par le grand escalier.
## Tout est posé ici, en coordonnées du lot A (voir les zones) ; le jeu web les pilotait par des besoins,
## ici ils tiennent une place ou suivent un circuit. Ceux du lot B (l'ouest) sont posés aux places que
## leurs zones ont notées dans K.places, comme ceux des lots C (l'est) et D (les coulisses) ; ceux du dehors
## (lot E) et des salles du lot F sont rangés sous leurs nœuds (« Dehors », « Arene », « Concert »), que la
## scène montre et arrête selon où l'on est.


## Le tour du casino : la rotonde, l'est de l'atrium, la volée est, la galerie (nord, est, pont sud, ouest),
## la volée ouest, l'ouest de l'atrium, et retour à la fontaine.
const TOUR := [
	Vector3(3, 0, 26), Vector3(5.2, 0, 21), Vector3(3.2, 0, 15.5), Vector3(2.2, 0, 11), Vector3(6.8, 0, 6.5),
	Vector3(6.6, 0, -4.5), Vector3(9, 0, -9.5), Vector3(9, 0, -12), Vector3(9, 3, -18), Vector3(9, 3, -19.5),
	Vector3(9, 6, -25.5), Vector3(12, 6, -27.6), Vector3(16, 6, -27), Vector3(16, 6, 8), Vector3(14, 6, 10.5),
	Vector3(-14, 6, 10.5), Vector3(-16, 6, 8), Vector3(-16, 6, -27), Vector3(-12, 6, -27.6), Vector3(-9, 6, -25.5),
	Vector3(-9, 3, -19.5), Vector3(-9, 3, -18), Vector3(-9, 0, -12), Vector3(-9, 0, -9.5), Vector3(-6.6, 0, -4.5),
	Vector3(-6.8, 0, 6.5), Vector3(-2.2, 0, 11), Vector3(-3.2, 0, 15.5), Vector3(-5.2, 0, 21), Vector3(-3, 0, 26),
]


## dedans : les figurants de tout le casino (lots A à F) ; faux quand les PNJ de l'original (pnj/pnj.gd, pnj/vie.gd)
## l'habitent : aucun figurant alors.
static func peupler(racine: Node3D, dedans := true) -> Node3D:
	var P = Atelier.personnages()
	var n := Node3D.new()
	n.name = "Figurants"
	racine.add_child(n)
	var g := 11
	if not dedans:
		# les PNJ de l'original habitent aussi le dehors et le lot F (pnj/vie.gd : passants, musiciens, public,
		# boxeurs ; le personnel du dehors à ses postes) : plus de figurants ici
		return n
	# Les barmen, derrière les deux comptoirs du bar ; ils vont et viennent le long des bouteilles.
	for sg in [-1.0, 1.0]:
		g += 1
		var b = _poser(n, "barman", g, Vector3(-2.5, 0, sg * 2.45), "interact")
		b.suivre([Vector3(-2.8, 0, sg * 2.45), Vector3(2.8, 0, sg * 2.45)], 0, 0.6, 5.0, "interact")
		b.regarder(Vector3(b.position.x, 0, sg * 4.0))
	# Les clients au bar, sur les tabourets (x = -3,6 + 1,2 i, z = ±4,15), tournés vers le comptoir.
	for t in [[-1.0, 0], [-1.0, 2], [-1.0, 5], [1.0, 1], [1.0, 3], [1.0, 4], [1.0, 6]]:
		g += 1
		var x: float = -3.6 + t[1] * 1.2
		var c = _poser(n, "client", g, Vector3(x, 0.33, t[0] * 4.3), "sit_talk" if g % 3 == 0 else "sit")
		c.regarder(Vector3(x, 0, 0))
	# Les croupiers, aux tables fermées : un au bout de chaque craps, un derrière chaque roue.
	for x in [-10.5, 10.5]:
		g += 1
		_poser(n, "croupier", g, Vector3(x, 0, -2.4), "idle").regarder(Vector3(x, 0, 0))
		g += 1
		_poser(n, "croupier", g, Vector3(x, 0, -9.85), "arms" if g % 2 else "idle").regarder(Vector3(x, 0, -8))
	# Deux joueurs qui attendent l'ouverture du craps, accoudés à la rambarde.
	for p in [[-9.1, -0.6], [11.9, 0.6]]:
		g += 1
		_poser(n, "client", g, Vector3(p[0], 0, p[1]), "lean").regarder(Vector3(10.5 * signf(p[0]), 0, p[1]))
	# Les mange-debout : deux clients qui bavardent à chacun.
	for p in [[-10.5, 8.0], [10.5, 8.0], [-6.5, 9.5], [6.5, 9.5]]:
		for k in 2:
			g += 1
			var a: float = PI * k + 0.6 * g
			var c = _poser(n, "client", g, Vector3(p[0] + cos(a) * 0.75, 0, p[1] + sin(a) * 0.75), ["talk", "drink", "idle"][g % 3])
			c.regarder(Vector3(p[0], 0, p[1]))
	# Les vigiles : à la porte-tambour, à l'arche nord de la rotonde, au couloir du stade, au salon des hautes limites.
	for v in [[Vector3(-2.3, 0, 27.6), Vector3(0, 0, 21)], [Vector3(2.3, 0, 27.6), Vector3(0, 0, 21)],
			[Vector3(-3.4, 0, 12.9), Vector3(0, 0, 18)], [Vector3(12.9, 0, -14.3), Vector3(9, 0, -14.3)],
			[Vector3(-16, 0, -10.6), Vector3(-16, 0, -6)]]:
		g += 1
		_poser(n, "vigile", g, v[0], "arms").regarder(v[1])
	# L'hôtesse, devant la grille de la réception.
	g += 1
	_poser(n, "hotesse", g, Vector3(-14, 0, 10.8), "idle").regarder(Vector3(-12, 0, 6))
	# Autour de la fontaine de la Fortune : on la regarde, on téléphone, on fait un vœu.
	for k in 5:
		g += 1
		var a := 0.4 + k * TAU / 5.0
		var c = _poser(n, "client", g, Vector3(sin(a) * 4.1, 0, 21 - cos(a) * 4.1), ["idle", "phone", "clap", "talk", "idle"][k])
		c.regarder(Vector3(0, 0, 21))
	# À la galerie, accoudés au garde-corps de verre, au-dessus de la nef.
	for p in [[-14.4, -6.0, 1.0], [-14.4, 2.5, 1.0], [14.4, -12.0, -1.0], [14.4, 4.0, -1.0], [-4.0, 9.5, 0.0]]:
		g += 1
		var c = _poser(n, "client", g, Vector3(p[0], 6.0, p[1]), "lean")
		c.regarder(Vector3(p[0] + p[2] * 3.0, 6.0, p[1] - (3.0 if p[2] == 0.0 else 0.0)))
	# Les promeneurs : le tour du casino, dans un sens ou dans l'autre, à leur pas.
	var retour := TOUR.duplicate()
	retour.reverse()
	for k in 10:
		g += 1
		var c = P.figurant("client" if k % 4 != 3 else "serveur", g)
		n.add_child(c)
		var circuit: Array = TOUR if k % 2 == 0 else retour
		c.suivre(circuit, k * 3, 1.05 + 0.08 * (k % 4), 1.5 if k % 3 == 0 else 0.0)
	var K = racine.get("K")
	if K != null:
		_lot_b(n, K.places, g)
		_lot_c(n, K.places, g + 400)
		_lot_d(n, K.places, g + 800)
		_lot_e(n, K.places, g + 1200)
		_lot_f(n, K.places, g + 1600)
	return n


## Les figurants du lot B, posés aux places que les zones ont notées (K.places, en coordonnées du monde) :
## croupiers aux tables ouvertes, joueurs aux machines et aux tables, le barman et ses clients au lounge,
## le pianiste et son public, des promeneurs au jardin d'hiver, le personnel du lobby et du change.
static func _lot_b(n: Node3D, pl: Dictionary, g: int) -> void:
	var P = Atelier.personnages()
	# Le poker : un croupier par table ouverte, cinq joueurs sur huit.
	for t in pl.get("poker", []):
		g += 1
		_tenir(n, "croupier", g, t.croupier, "idle")
		for i in t.sieges.size():
			if (i + g) % 8 < 5:
				g += 1
				_asseoir(n, g, t.sieges[i], "sit_talk" if g % 4 == 0 else "sit")
	# Les hautes limites : blackjack, baccara, roulette, chacun son croupier et quelques joueurs.
	var hl: Array = [pl.get("hl_bj"), pl.get("hl_roulette")]
	hl.append_array(pl.get("hl_baccara", []))
	for t in hl:
		if t == null:
			continue
		g += 1
		_tenir(n, "croupier", g, t.croupier, "arms" if g % 3 == 0 else "idle")
		for i in t.sieges.size():
			if (i + g) % 3 != 0:
				g += 1
				_asseoir(n, g, t.sieges[i], "sit")
	# Les machines : un joueur sur quatre, quelques-uns sur les bancs ; la caissière au change.
	var machines: Array = pl.get("machines", [])
	for i in machines.size():
		if (i * 7) % 4 == 1:
			g += 1
			_asseoir(n, g, machines[i], "sit")
	for p in pl.get("machines_change", []):
		g += 1
		_tenir(n, "hotesse", g, p, "idle")
	for p in pl.get("poker_pupitre", []):
		g += 1
		_tenir(n, "hotesse", g, p, "idle")
	# Le lobby : les réceptionnistes derrière leur comptoir, le concierge, des clients dans les salons.
	for p in pl.get("lobby_reception", []) + pl.get("lobby_concierge", []):
		g += 1
		_tenir(n, "hotesse" if g % 2 else "serveur", g, p, "idle")
	# Les salons (lobby, salon, hautes limites, lounge, jardin) : une place sur trois occupée.
	for cle in ["lobby_salons", "salon", "hl_salons", "lounge_salons", "jardin_salons", "machines_bancs", "poker_bancs", "jardin_bancs"]:
		var places: Array = pl.get(cle, [])
		for i in places.size():
			if (i + cle.length()) % 3 == 0:
				g += 1
				_asseoir(n, g, places[i], ["sit", "sit_talk", "sit"][g % 3])
	# Le lounge : le barman va et vient derrière le bar, des clients aux tabourets, le pianiste, le public.
	var bar: Dictionary = pl.get("lounge_bar", {})
	if bar.has("barman"):
		g += 1
		var b = _poser(n, "barman", g, bar.barman[0], "interact")
		b.suivre(bar.barman, 0, 0.6, 5.0, "interact")
		var tabourets: Array = bar.tabourets
		for i in tabourets.size():
			if i % 2 == 0:
				g += 1
				_asseoir(n, g, tabourets[i], "sit_talk" if g % 3 == 0 else "sit")
	for p in pl.get("lounge_piano", []):
		g += 1
		_asseoir(n, g, p, "sit", "barman")
	var public: Array = pl.get("lounge_jazz", [])
	for i in public.size():
		g += 1
		_tenir(n, "client", g, public[i], ["idle", "clap", "drink"][i % 3])
	# Un serveur fait la navette entre le bar du lounge et ses salons.
	if bar.has("barman"):
		g += 1
		var s = P.figurant("serveur", g)
		n.add_child(s)
		s.suivre([Vector3(-34.2, 6, -3), Vector3(-26.6, 6, -5.1), Vector3(-26.6, 6, 5.6), Vector3(-34.2, 6, 4)], 0, 0.9, 2.0)
	# Le jardin d'hiver : des promeneurs font le tour du bassin, à leur pas.
	var tour: Array = pl.get("jardin_tour", [])
	if not tour.is_empty():
		for k in 4:
			g += 1
			var c = P.figurant("client", g)
			n.add_child(c)
			c.suivre(tour, k * 3, 0.8 + 0.1 * (k % 3), 2.5 if k % 2 == 0 else 0.0)


## Un figurant debout à sa place [position, orientation].
static func _tenir(n: Node3D, role: String, graine: int, place: Array, geste: String):
	var f = _poser(n, role, graine, place[0], geste)
	f.rotation.y = place[1]
	return f


## Un figurant assis à sa place [position du siège, orientation] : le bassin un peu sous l'assise.
static func _asseoir(n: Node3D, graine: int, place: Array, geste: String, role := "client"):
	var p: Vector3 = place[0]
	return _tenir(n, role, graine, [p - Vector3(0, 0.43, 0), place[1]], geste)


static func _poser(n: Node3D, role: String, graine: int, at: Vector3, geste: String):
	var f = Atelier.personnages().figurant(role, graine)
	f.position = at
	n.add_child(f)
	f.jouer(geste)
	return f


## Les figurants du lot C (l'est), aux places notées par ses zones : croupiers et joueurs à la fosse, le chef
## de table à son pupitre, les caissiers derrière la grille et la file à la caisse, l'hôte et les vigiles du
## club, les parieurs devant le mur d'écrans, les dîneurs, serveurs et cuisiniers du Lucullus, les flâneurs et
## les vendeurs des boutiques, le public du foyer.
static func _lot_c(n: Node3D, pl: Dictionary, g: int) -> void:
	var P = Atelier.personnages()
	# La fosse : un croupier par table, les joueurs sur un tabouret sur deux ou trois.
	for t in pl.get("pit_bj", []) + pl.get("pit_roulettes", []):
		g += 1
		_tenir(n, "croupier", g, t.croupier, "arms" if g % 4 == 0 else "idle")
		for i in t.sieges.size():
			if (i + g) % 5 < 2 or (i + g) % 5 == 3:
				g += 1
				_asseoir(n, g, t.sieges[i], "sit_talk" if g % 5 == 0 else "sit")
	var roue: Dictionary = pl.get("pit_roue", {})
	if roue.has("croupier"):
		g += 1
		_tenir(n, "croupier", g, roue.croupier, "interact")
		for i in roue.sieges.size():
			if i % 2 == 1:
				g += 1
				_tenir(n, "client", g, roue.sieges[i], ["clap", "idle"][i % 2])
	var pupitre: Array = pl.get("pit_pupitre", [])
	if not pupitre.is_empty():
		g += 1
		_tenir(n, "croupier", g, pupitre[0], "arms")
	_debout(n, pl.get("pit_regards", []), g, 2, ["idle", "arms", "talk"])
	g += 20
	_debout(n, pl.get("pit_duos", []), g, 1, ["talk", "drink", "idle", "phone"])
	g += 20
	# La caisse : un caissier à chaque guichet, deux clients au comptoir, la file, le vigile.
	for p in pl.get("cage_caissiers", []):
		g += 1
		_tenir(n, "hotesse" if g % 2 else "serveur", g, p, "interact")
	var clients: Array = pl.get("cage_clients", [])
	for i in clients.size():
		if i % 2 == 0:
			g += 1
			_tenir(n, "client", g, clients[i], "interact")
	var file: Array = pl.get("cage_file", [])
	for i in mini(4, file.size()):
		g += 1
		_tenir(n, "client", g, file[i], ["idle", "phone", "idle", "arms"][i])
	_debout(n, pl.get("cage_duos", []), g, 1, ["talk", "talk"])
	g += 5
	for p in [pl.get("cage_vigile"), pl.get("pit_vigile")]:
		if p != null:
			g += 1
			_tenir(n, "vigile", g, p, "arms")
	# Le club Minuit : l'hôte à son comptoir, un client inscrit, un retrait au distributeur, les vigiles.
	if pl.has("club_hote"):
		g += 1
		_tenir(n, "hotesse", g, pl.club_hote, "talk")
	_debout(n, pl.get("club_comptoir", []), g, 2, ["talk"])
	g += 5
	_debout(n, pl.get("club_dab", []), g, 3, ["interact"])
	g += 5
	_debout(n, pl.get("club_bornes", []), g, 2, ["interact"])
	g += 5
	_debout(n, pl.get("club_duos", []), g, 1, ["talk", "drink"])
	g += 10
	for p in pl.get("club_vigiles", []):
		g += 1
		_tenir(n, "vigile", g, p, "arms")
	# Le foyer : les guichetiers de la billetterie, le public des affiches et des banquettes.
	for p in pl.get("foyer_guichetiers", []):
		g += 1
		_tenir(n, "hotesse", g, p, "idle")
	_debout(n, pl.get("foyer_affiches", []), g, 2, ["idle", "phone"])
	g += 5
	_debout(n, pl.get("foyer_duos", []), g, 1, ["talk", "talk"])
	g += 5
	# Les toilettes : quelqu'un se lave les mains.
	var vasques: Array = pl.get("wc_e_vasques", [])
	if not vasques.is_empty():
		g += 1
		_tenir(n, "client", g, vasques[1], "interact")
	# Les paris sportifs : les parieurs dans les fauteuils, les guichetiers, le barman et ses clients.
	var fauteuils: Array = pl.get("sports_fauteuils", [])
	for i in fauteuils.size():
		if (i * 5) % 7 < 3:
			g += 1
			_asseoir(n, g, fauteuils[i], ["sit", "sit_talk", "sit"][g % 3])
	for p in pl.get("sports_guichetiers", []):
		g += 1
		_tenir(n, "hotesse" if g % 2 else "serveur", g, p, "interact")
	_debout(n, pl.get("sports_guichets", []), g, 2, ["interact"])
	g += 5
	var bar: Dictionary = pl.get("sports_bar", {})
	if bar.has("barman"):
		g += 1
		var b = _poser(n, "barman", g, bar.barman[0], "interact")
		b.suivre(bar.barman, 0, 0.6, 5.0, "interact")
		var tabourets: Array = bar.tabourets
		for i in tabourets.size():
			if i % 2 == 1:
				g += 1
				_asseoir(n, g, tabourets[i], "sit_talk" if g % 3 == 0 else "sit")
	_debout(n, pl.get("sports_debout", []), g, 2, ["talk", "drink", "clap"])
	g += 10
	_debout(n, pl.get("sports_regards", []), g, 1, ["arms", "idle", "clap"])
	g += 10
	# Le Lucullus : les dîneurs, le maître d'hôtel, la brigade, trois serveurs entre la passe et les tables.
	var dineurs: Array = pl.get("resto_dineurs", [])
	for i in dineurs.size():
		if (i * 3) % 5 < 3:
			g += 1
			_asseoir(n, g, dineurs[i], "sit_talk" if g % 2 == 0 else "sit")
	if pl.has("resto_maitre"):
		g += 1
		_tenir(n, "serveur", g, pl.resto_maitre, "idle")
	for p in pl.get("resto_brigade", []):
		g += 1
		_tenir(n, "barman", g, p, "interact")
	if pl.has("resto_service"):
		var allees := [Vector3(34.2, 6, -22.45), Vector3(21.8, 6, -22.45), Vector3(21.8, 6, -18.35), Vector3(34.2, 6, -18.35)]
		for k in 3:
			g += 1
			var s = P.figurant("serveur", g)
			n.add_child(s)
			s.suivre(allees, k, 0.9, 2.0 + k)
	# Les boutiques : les vendeurs à leur comptoir, des flâneurs autour de la fontaine, aux vitrines, aux bancs.
	for p in pl.get("boutiques_vendeurs", []):
		g += 1
		_tenir(n, "hotesse", g, p, "idle")
	var tour: Array = pl.get("boutiques_tour", [])
	if not tour.is_empty():
		var retour := tour.duplicate()
		retour.reverse()
		for k in 5:
			g += 1
			var c = P.figurant("client", g)
			n.add_child(c)
			c.suivre(tour if k % 2 == 0 else retour, k * 2, 0.8 + 0.1 * (k % 3), 3.0 if k % 2 == 0 else 0.0)
	_debout(n, pl.get("boutiques_vitrines", []), g, 1, ["idle", "phone", "idle"])
	g += 10
	_debout(n, pl.get("boutiques_duos", []), g, 1, ["talk", "drink", "talk"])
	g += 10
	var bancs: Array = pl.get("boutiques_bancs", []) + pl.get("foyer_bancs", []) + pl.get("cage_bancs", []) + pl.get("club_salon", [])
	for i in bancs.size():
		if i % 3 == 0:
			g += 1
			_asseoir(n, g, bancs[i], ["sit", "sit_talk"][g % 2])


## Les figurants du lot D (les coulisses), aux places notées par ses zones : les agents devant les écrans de
## la surveillance, au sas du coffre et à l'entretien (avec le client interpellé), les compteurs au comptage et à
## l'arrière-caisse, les cuisiniers, le chef et le plongeur, les livreurs au quai, les employés aux vestiaires,
## en pause et au couloir de service ; le rondier de l'épine, le croupier qui va prendre son service.
static func _lot_d(n: Node3D, pl: Dictionary, g: int) -> void:
	var P = Atelier.personnages()
	var assis := [["agent", "d_secu"], ["agent", "d_gardes_assis"], ["compteur", "d_comptage"], ["compteur", "d_arriere"],
		["employe", "d_vestiaire_assis"], ["employe", "d_pause"], ["employe", "d_service_assis"], ["agent", "d_sas_banc"],
		["agent", "d_entretien_agent"], ["client", "d_interpelle"]]
	for a in assis:
		var places: Array = pl.get(a[1], [])
		for i in places.size():
			if a[1] == "d_sas_banc" and i > 0:
				break
			g += 1
			_asseoir(n, g, places[i], ["sit", "sit_talk", "sit"][g % 3], a[0])
	var debout := [["agent", "d_secu_debout", ["arms", "idle"]], ["agent", "d_gardes", ["arms", "idle"]], ["compteur", "d_comptage_debout", ["interact"]], ["compteur", "d_arriere_debout", ["phone"]],
		["cuisinier", "d_cuisine", ["interact"]], ["cuisinier", "d_chef", ["arms"]], ["plongeur", "d_plonge", ["interact"]],
		["livreur", "d_quai", ["interact", "idle", "talk", "talk"]], ["employe", "d_vestiaire", ["idle", "interact", "phone"]],
		["employe", "d_pause_debout", ["drink"]], ["employe", "d_pause_duos", ["talk", "drink"]], ["employe", "d_service", ["idle", "interact"]]]
	for d in debout:
		var places: Array = pl.get(d[1], [])
		var gestes: Array = d[2]
		for i in places.size():
			g += 1
			_tenir(n, d[0], g, places[i], gestes[i % gestes.size()])
	# Le rondier, qui fait le tour de l'épine ; le croupier qui va de la pointeuse à la porte de la fosse.
	var ronde: Array = pl.get("d_couloir_ronde", [])
	if not ronde.is_empty():
		g += 1
		var r = P.figurant("agent", g)
		n.add_child(r)
		r.suivre(ronde, 0, 0.9, 2.0)
	var tour: Array = pl.get("d_service_tour", [])
	if not tour.is_empty():
		g += 1
		var c = P.figurant("croupier", g)
		n.add_child(c)
		c.suivre(tour, 0, 1.0, 3.0)


## Des clients debout à une place sur pas, chacun son geste.
static func _debout(n: Node3D, places: Array, g: int, pas: int, gestes: Array) -> void:
	for i in places.size():
		if i % pas == 0:
			g += 1
			_tenir(n, "client", g, places[i], gestes[g % gestes.size()])


## Un groupe de figurants, sous les figurants (la scène le cache et l'arrête quand on est loin).
static func _groupe(n: Node3D, nom: String) -> Node3D:
	var d := Node3D.new()
	d.name = nom
	n.add_child(d)
	return d


## Les figurants du dehors (lot E), aux places notées par ses zones : les promeneurs sur les deux trottoirs, les
## portiers et les voituriers de la porte-cochère, des clients qui bavardent sous la marquise, le public des
## fontaines, l'attente aux abribus et à la station de taxis, la file de l'arène et son videur, les badauds devant
## l'écran géant, le vendeur de hot-dogs et ses clients, quelques-uns sur les bancs.
static func _lot_e(n: Node3D, pl: Dictionary, g: int) -> void:
	var P = Atelier.personnages()
	var d := _groupe(n, "Dehors")
	for cle in ["e_promenade_casino", "e_promenade_enface"]:
		var tour: Array = pl.get(cle, [])
		if tour.is_empty():
			continue
		var nb := 12 if cle == "e_promenade_casino" else 9
		for k in nb:
			g += 1
			var c = P.figurant("client", g)
			d.add_child(c)
			c.suivre(tour, (k * tour.size()) / nb, 1.0 + 0.1 * (k % 4), 2.0 if k % 5 == 0 else 0.0, "phone" if k % 2 else "idle")
	for p in pl.get("e_portiers", []):
		g += 1
		_tenir(d, "portier", g, p, "arms" if g % 2 else "idle")
	var voit: Array = pl.get("e_voiturier", [])
	if not voit.is_empty():
		g += 1
		_tenir(d, "voiturier", g, voit[0], "interact")
	if voit.size() > 1:
		# Le second voiturier va et vient entre son pupitre et les voitures garées sous la porte-cochère.
		g += 1
		var v = P.figurant("voiturier", g)
		d.add_child(v)
		var a: Vector3 = voit[1][0]
		v.suivre([a, a + Vector3(0, 0, 3.6), a + Vector3(6.0, 0, 3.6), a + Vector3(6.0, 0, 0)], 0, 1.2, 3.0, "idle")
	_debout(d, pl.get("e_cochere", []), g, 1, ["talk", "phone", "talk", "drink"])
	g += 10
	_debout(d, pl.get("e_fontaines", []), g, 3, ["idle", "phone", "clap", "idle"])
	g += 40
	for cle in ["e_bus_casino", "e_bus_enface", "e_taxi_enface"]:
		var sieges: Array = pl.get(cle, [])
		for i in sieges.size():
			if i % 2 == 0:
				g += 1
				_asseoir(d, g, sieges[i], "sit")
		_debout(d, pl.get(cle + "_attente", []), g, 2, ["phone", "idle", "arms"])
		g += 10
	_debout(d, pl.get("e_file_arene", []), g, 1, ["idle", "phone", "talk", "arms", "idle", "drink"])
	g += 10
	for p in pl.get("e_videur_arene", []):
		g += 1
		_tenir(d, "vigile", g, p, "arms")
	_debout(d, pl.get("e_ecran_arene", []), g, 2, ["idle", "clap"])
	g += 10
	_debout(d, pl.get("e_bavards_enface", []), g, 1, ["talk", "drink"])
	g += 10
	var hd: Array = pl.get("e_hotdog", [])
	for i in hd.size():
		g += 1
		_tenir(d, "serveur" if i == 0 else "client", g, hd[i], "interact" if i == 0 else ["drink", "idle"][i % 2])
	var bancs: Array = pl.get("e_bancs_terrasse", []) + pl.get("e_bancs_enface", [])
	for i in bancs.size():
		if i % 3 == 0:
			g += 1
			_asseoir(d, g, bancs[i], ["sit", "sit_talk"][g % 2])


## Les figurants du lot F. L'arène : le personnel (billetterie, contrôle, bar, placeurs, vigiles), la file aux
## tourniquets, le public du hall, les boxeurs, l'arbitre, les soigneurs, les juges, les invités du bord de ring
## et le premier rang des gradins. Minuit Live : les musiciens sur scène, la régie, les vigiles de la fosse, le
## bar et la boutique, les ouvreurs du sas, les danseurs de la fosse, le premier rang des gradins ; au foyer, la
## file devant les portes.
static func _lot_f(n: Node3D, pl: Dictionary, g: int) -> void:
	var a := _groupe(n, "Arene")
	for p in pl.get("f_billetterie", []):
		g += 1
		_tenir(a, "hotesse", g, p, "interact")
	_debout(a, pl.get("f_billetterie_file", []), g, 2, ["interact", "phone"])
	g += 10
	for p in pl.get("f_controle", []):
		g += 1
		_tenir(a, "vigile", g, p, "idle")
	_debout(a, pl.get("f_controle_file", []), g, 2, ["idle", "phone", "talk"])
	g += 10
	_debout(a, pl.get("f_vitrine", []) + pl.get("f_affiches", []), g, 1, ["idle", "phone", "idle"])
	g += 10
	_debout(a, pl.get("f_hall_duos", []), g, 1, ["talk", "drink"])
	g += 10
	var bar: Dictionary = pl.get("f_bar", {})
	if bar.has("barman"):
		g += 1
		var b = _poser(a, "barman", g, bar.barman[0], "interact")
		b.suivre(bar.barman, 0, 0.6, 5.0, "interact")
		var tabourets: Array = bar.tabourets
		for i in tabourets.size():
			if i % 2 == 0:
				g += 1
				_asseoir(a, g, tabourets[i], "sit_talk" if g % 3 == 0 else "sit")
	var banc: Array = pl.get("f_hall_banc", [])
	if not banc.is_empty():
		g += 1
		_asseoir(a, g, banc[0], "sit")
	for p in pl.get("f_placeurs", []):
		g += 1
		_tenir(a, "hotesse", g, p, "idle")
	for p in pl.get("f_vigiles_ring", []):
		g += 1
		_tenir(a, "vigile", g, p, "arms")
	_debout(a, pl.get("f_arene_debout", []), g, 1, ["clap", "idle", "arms"])
	g += 10
	var ring: Dictionary = pl.get("f_ring", {})
	if ring.has("rouge"):
		g += 1
		_tenir(a, "boxeur_rouge", g, ring.rouge, "arms")
		g += 1
		_tenir(a, "boxeur_bleu", g, ring.bleu, "arms")
		g += 1
		_tenir(a, "arbitre", g, ring.arbitre, "idle")
		for p in ring.soigneurs:
			g += 1
			_tenir(a, "employe", g, p, "idle")
	for p in pl.get("f_juges", []):
		g += 1
		_asseoir(a, g, p, "sit", "agent")
	var invites: Array = pl.get("f_invites", [])
	for i in invites.size():
		if (i * 7) % 5 < 2:
			g += 1
			_asseoir(a, g, invites[i], ["sit", "sit_talk", "sit"][g % 3])
	var gradins: Array = pl.get("f_gradins", [])
	for i in gradins.size():
		if (i * 5) % 7 < 2:
			g += 1
			_asseoir(a, g, gradins[i], "sit")
	# Minuit Live.
	var c := _groupe(n, "Concert")
	var mus: Dictionary = pl.get("f_musiciens", {})
	var gestes := {"chant": "clap", "guitare": "interact", "basse": "interact", "batterie": "sit", "claviers": "interact"}
	for nom in mus:
		g += 1
		if nom == "batterie":
			var pb: Array = mus[nom]
			_asseoir(c, g, [pb[0] + Vector3(0, 0.45, 0), pb[1]], "sit", "musicien")
		else:
			_tenir(c, "musicien", g, mus[nom], gestes[nom])
	for p in pl.get("f_regie", []):
		g += 1
		_tenir(c, "technicien", g, p, "interact")
	for p in pl.get("f_vigiles_fosse", []):
		g += 1
		_tenir(c, "vigile", g, p, "arms")
	for p in pl.get("f_ouvreurs", []):
		g += 1
		_tenir(c, "hotesse", g, p, "idle")
	var cbar: Dictionary = pl.get("f_concert_bar", {})
	if cbar.has("barman"):
		g += 1
		var b = _poser(c, "barman", g, cbar.barman[0], "interact")
		b.suivre(cbar.barman, 0, 0.6, 4.0, "interact")
		var tabourets: Array = cbar.tabourets
		for i in tabourets.size():
			if i % 2 == 1:
				g += 1
				_asseoir(c, g, tabourets[i], "sit_talk" if g % 3 == 0 else "sit")
	var bout: Dictionary = pl.get("f_concert_boutique", {})
	if bout.has("vendeur"):
		g += 1
		_tenir(c, "hotesse", g, bout.vendeur, "idle")
		_debout(c, bout.clients, g, 1, ["interact"])
		g += 5
	_debout(c, pl.get("f_concert_duos", []), g, 1, ["talk", "drink"])
	g += 10
	_debout(c, pl.get("f_concert_danse", []), g, 4, ["clap", "clap", "idle"])
	g += 40
	_debout(c, pl.get("f_concert_regards", []), g, 1, ["clap", "drink", "idle"])
	g += 10
	var cg: Array = pl.get("f_concert_gradins", [])
	for i in cg.size():
		if (i * 3) % 7 < 2:
			g += 1
			_asseoir(c, g, cg[i], "sit")
	# Au foyer, devant les portes : la file des spectateurs (dans le dedans du casino).
	for i in 5:
		g += 1
		_tenir(n, "client", g, [Vector3(16.0 + (i % 2) * 0.4, 0, -28.2 + i * 0.85), 0.0], ["idle", "phone", "talk", "idle", "arms"][i])
