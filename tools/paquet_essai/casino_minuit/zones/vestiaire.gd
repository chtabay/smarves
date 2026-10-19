extends RefCounted
## Lot D, zone B-VESTIAIRE (js/zones/d-b-vestiaire.js) : les vestiaires et la salle de pause du personnel,
## [20, 32] × [-16, -4], au sous-sol. À l'ouest les casiers (66 portes), les bancs, deux cabines de toilettes,
## le lavabo et le portant des uniformes ; à l'est, derrière une cloison (x = 26,4) percée au sud, la salle de
## pause : trois tables de quatre, la kitchenette et son réfrigérateur, les distributeurs, le canapé, la
## télévision. Liaison : la porte S09 vers l'épine (est).

const LOT_D := "res://communes/casino_minuit/zones/lot_d.gd"


static func construire(K) -> void:
	var D = load(LOT_D)
	var H: float = D.H
	K.zone_debut("B-VESTIAIRE")
	K.zone.position.y = D.Y
	var b := {"x0": 20.0, "x1": 32.0, "z0": -16.0, "z1": -4.0}
	D.coque(K, b, H, {"east": [{"at": -10.0, "w": 1.4}]})
	var N := -15.788
	var S := -4.212
	var Wx := 20.212
	var Ex := 31.788
	# La cloison entre le vestiaire et la salle de pause, passage au sud.
	K.box("beton", 0.12, H, 7.8, 26.4, H / 2.0, -12.1)
	K.solide(0.12, H, 7.8, 26.4, H / 2.0, -12.1)
	for s in [-1.0, 1.0]:
		D.bx(K, "vertLino", 0.008, 1.2, 7.8, 26.4 + s * 0.064, 0.6, -12.1)
		D.bx(K, "jaune", 0.01, 0.06, 7.8, 26.4 + s * 0.064, 1.23, -12.1)

	# --- le vestiaire : casiers, bancs, cabines, lavabo, portant ---
	D.casiers(K, Wx + 0.25, -9.4, PI / 2.0, 20)
	D.casiers(K, 23.65, -10.4, -PI / 2.0, 13)
	D.casiers(K, 24.15, -10.4, PI / 2.0, 13)
	D.casiers(K, 26.09, -11.6, -PI / 2.0, 10)
	# Deux portes entrouvertes, les effets personnels.
	D.bx(K, "casier", 0.38, 1.78, 0.02, 20.86, 1.02, -7.08, 0.5)
	D.bx(K, "casier", 0.38, 1.78, 0.02, 20.86, 1.02, -11.72, -0.6)
	D.bx(K, "bordeaux", 0.36, 0.5, 0.04, 20.6, 1.5, -7.2)
	D.bx(K, "blanc", 0.36, 0.5, 0.04, 20.6, 1.5, -11.6)
	for bc in [[22.1, -11.6, PI / 2.0], [22.1, -8.0, PI / 2.0], [24.9, -6.4, 0.0], [22.2, -6.4, PI]]:
		var r := [bc[0], bc[1], bc[2]]
		D.rbx(K, r, "bois", 1.5, 0.05, 0.36, 0, 0.45, 0)
		for dx in [-0.6, 0.6]:
			D.B().rbox(K, r, "acier", 0.04, 0.43, 0.3, dx, 0.215, 0)
		D.robstacle(K, r, -0.75, 0.75, -0.18, 0.18, 0.5)
	# Ceux qui se changent : debout devant les casiers, assis sur un banc.
	D.place(K, "d_vestiaire", 21.3, 0.0, -10.4, -PI / 2.0)
	D.place(K, "d_vestiaire", 21.3, 0.0, -6.3, -PI / 2.0 - 0.3)
	D.place(K, "d_vestiaire", 22.85, 0.0, -12.0, PI / 2.0)
	D.place(K, "d_vestiaire", 24.95, 0.0, -9.0, -PI / 2.0)
	D.place(K, "d_vestiaire_assis", 22.1, 0.47, -8.36, PI / 2.0)
	D.place(K, "d_vestiaire_assis", 24.54, 0.47, -6.4, 0.0)
	for i in 2:
		var x0 := 20.25 + i * 1.15
		var cx := x0 + 0.55
		D.bx(K, "grisC", 0.04, 2.0, 1.5, x0 + 1.1, 1.15, -15.05)
		if i == 0:
			D.bx(K, "grisC", 0.04, 2.0, 1.5, x0, 1.15, -15.05)
		D.bx(K, "blanc", 0.9, 1.9, 0.035, cx, 1.15, -14.3)
		D.bx(K, "ledR" if i else "ledV", 0.04, 0.04, 0.01, cx + 0.3, 1.1, -14.278)
		D.cy(K, "blanc", 0.19, 0.16, 0.4, cx, 0.2, -15.3, 10)
		D.bx(K, "blanc", 0.36, 0.38, 0.16, cx, 0.6, -15.66)
		K.segment(x0 + 1.1, -15.8, x0 + 1.1, -14.3, 0.03)
		K.segment(x0, -14.3, x0 + 1.1, -14.3, 0.03)
	K.segment(20.25, -15.8, 20.25, -14.3, 0.03)
	K.box("acier", 2.4, 0.04, 0.04, 21.4, 2.17, -14.3)
	D.bx(K, "blanc", 1.2, 0.14, 0.46, 23.7, 0.85, N + 0.24)
	D.bx(K, "grisC", 1.2, 0.78, 0.4, 23.7, 0.39, N + 0.21)
	K.box("acier", 0.03, 0.2, 0.03, 23.7, 1.0, N + 0.1)
	K.box("miroir", 1.1, 0.7, 0.012, 23.7, 1.6, N + 0.006)
	D.plaque(K, "mains", 23.7, 2.1, N, 0, 0.7)
	K.obstacle(23.1, 24.3, N, N + 0.48)
	K.box("acier", 2.6, 0.03, 0.03, 22.2, 1.75, S - 0.3)
	for x in [20.95, 23.45]:
		K.box("acier", 0.03, 1.75, 0.4, x, 0.875, S - 0.3)
	K.obstacle(20.9, 23.5, S - 0.55, S)
	var tenues := ["bordeaux", "bordeaux", "noir", "bordeaux", "blanc", "noir", "bordeaux", "bleuNuit", "blanc", "bordeaux", "noir", "bordeaux"]
	for i in tenues.size():
		D.bx(K, tenues[i], 0.06, 0.8 + (i % 3) * 0.1, 0.42, 21.1 + i * 0.2, 1.33 - (i % 3) * 0.05, S - 0.3)
	K.box("miroir", 0.6, 1.6, 0.012, 24.4, 1.3, S - 0.006)
	D.pochoir(K, "VESTIAIRES", 22.2, 2.6, S, PI, 0.3)

	# --- la salle de pause ---
	var assis := []
	for t in [[27.9, -12.8, ""], [30.7, -12.8, "vert"], [28.2, -10.0, ""]]:
		assis += D.table_pause(K, t[0], t[1], 0.0, t[2])
	for i in assis.size():
		if i % 4 != 3:
			var p: Array = assis[i]
			D.place(K, "d_pause", p[0].x, p[0].y, p[0].z, p[1])
	# La kitchenette (mur nord), le réfrigérateur.
	D.bx(K, "grisC", 3.6, 0.86, 0.6, 28.5, 0.43, N + 0.3)
	K.box("acier", 3.66, 0.04, 0.64, 28.5, 0.88, N + 0.31)
	D.bx(K, "grisC", 3.6, 0.6, 0.34, 28.5, 2.1, N + 0.17)
	for x in [27.0, 27.9, 28.8, 29.7]:
		D.bx(K, "gris", 0.02, 0.76, 0.01, x + 0.45, 0.43, N + 0.605)
	D.bx(K, "noir", 0.5, 0.3, 0.36, 27.2, 1.05, N + 0.26)
	D.bx(K, "rouge", 0.26, 0.38, 0.3, 28.1, 1.09, N + 0.24)
	D.bx(K, "ledA", 0.02, 0.02, 0.01, 28.18, 1.22, N + 0.395)
	D.bx(K, "blanc", 0.7, 1.9, 0.68, 31.35, 0.95, N + 0.36)
	K.box("acier", 0.03, 0.5, 0.03, 31.05, 1.25, N + 0.72)
	K.obstacle(26.7, 30.3, N, N + 0.62)
	K.obstacle(31.0, 31.8, N, N + 0.72)
	# Les distributeurs (mur est, au sud de la porte).
	D.bx(K, "bleuNuit", 0.78, 1.95, 0.95, 31.38, 0.975, -6.9)
	D.bx(K, "neon", 0.006, 1.2, 0.6, 30.985, 1.2, -7.0)
	for j in 5:
		for i in 4:
			D.bx(K, ["rouge", "jaune", "vert", "bleu"][(i + j) % 4], 0.01, 0.14, 0.1, 30.98, 0.8 + j * 0.22, -7.25 + i * 0.13)
	D.bx(K, "rouge", 0.74, 1.95, 0.8, 31.4, 0.975, -5.85)
	D.bx(K, "chaud", 0.01, 1.0, 0.6, 31.025, 1.25, -5.85)
	K.obstacle(30.98, 31.8, -7.4, -5.4)
	D.place(K, "d_pause_debout", 30.4, 0.0, -6.9, -PI / 2.0)
	# Le canapé (mur sud) et sa table basse, la télévision, l'affichage.
	D.bx(K, "bordeaux", 2.2, 0.3, 0.8, 28.3, 0.3, S - 0.42)
	D.bx(K, "bordeaux", 2.2, 0.5, 0.2, 28.3, 0.65, S - 0.1)
	for dx in [-1.15, 1.15]:
		D.bx(K, "bordeaux", 0.16, 0.5, 0.8, 28.3 + dx, 0.4, S - 0.42)
	D.bx(K, "noir", 2.3, 0.14, 0.76, 28.3, 0.07, S - 0.42)
	K.obstacle(27.1, 29.5, S - 0.84, S, 0.0, 0.8)
	D.place(K, "d_pause", 27.65, 0.46, S - 0.46, 0.0)
	D.place(K, "d_pause", 28.95, 0.46, S - 0.46, 0.0)
	D.bx(K, "bois", 1.0, 0.04, 0.5, 28.3, 0.4, -6.4)
	for l in [[-0.44, -0.2], [0.44, -0.2], [-0.44, 0.2], [0.44, 0.2]]:
		K.box("acier", 0.03, 0.38, 0.03, 28.3 + l[0], 0.19, -6.4 + l[1])
	K.obstacle(27.8, 28.8, -6.65, -6.15, 0.0, 0.45)
	D.cy(K, "blanc", 0.22, 0.22, 0.02, 29.6, 2.5, N + 0.01, 16, PI / 2.0)
	D.affiche(K, "affiche", "bleu", 1.4, 1.05, Ex, 1.6, -13.4, -PI / 2.0)
	D.affiche(K, "liege", "", 1.3, 0.98, 26.47, 1.6, -12.2, PI / 2.0)
	D.bx(K, "noir", 0.05, 0.62, 1.04, 26.49, 2.1, -14.6)
	D.bx(K, "ecranCompte", 0.006, 0.56, 0.98, 26.52, 2.1, -14.6)
	D.place(K, "d_pause_duos", 29.6, 0.0, -8.2, PI / 2.0)
	D.place(K, "d_pause_duos", 28.5, 0.0, -8.2, -PI / 2.0)
	D.pochoir(K, "PAUSE", 30.2, 2.6, S, PI, 0.36)
	D.extincteur(K, Ex, -11.5, -PI / 2.0)
	D.sortie(K, Ex, 2.62, -10, -PI / 2.0)
	D.bx(K, "vert", 0.4, 0.7, 0.4, 31.5, 0.35, -8.45)
	D.bx(K, "jaune", 0.4, 0.7, 0.4, 31.5, 0.35, -7.95)
	K.obstacle(31.3, 31.7, -8.65, -7.75, 0.0, 0.7)

	# --- lumière ---
	D.neon(K, 21.4, -10)
	D.neon(K, 25.1, -10.4)
	D.neon(K, 23.2, -5.8, "x")
	D.neon(K, 29.3, -12.6, "x")
	D.neon(K, 29.3, -7.4, "x")
	K.lumiere(28.6, 3.0, -10.4, Color("#e6efff"), 1.3, 12.0)
	K.lumiere(22.6, 3.0, -10.0, Color("#e6efff"), 1.0, 9.0)
	D.reseaux(K, "z", 31.2, -15.7, -4.3)
	K.zone_fin()
