extends RefCounted
## Les figurants du lot A, sur le modèle du jeu web : le personnel à son poste (barmen, croupiers aux
## tables fermées, vigiles aux portes, une hôtesse), des clients au bar, aux mange-debout, autour de la
## fontaine, accoudés à la galerie, et des promeneurs qui font le tour du casino par le grand escalier.
## Tout est posé ici, en coordonnées du lot A (voir les zones) ; le jeu web les pilotait par des besoins,
## ici ils tiennent une place ou suivent un circuit.

const PERSONNAGES := "res://communes/casino_minuit/personnages.gd"

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


static func peupler(racine: Node3D) -> Node3D:
	var P = load(PERSONNAGES)
	var n := Node3D.new()
	n.name = "Figurants"
	racine.add_child(n)
	var g := 11
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
	return n


static func _poser(n: Node3D, role: String, graine: int, at: Vector3, geste: String):
	var f = load(PERSONNAGES).figurant(role, graine)
	f.position = at
	n.add_child(f)
	f.jouer(geste)
	return f
