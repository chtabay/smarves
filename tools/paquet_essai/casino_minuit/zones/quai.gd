extends RefCounted
## Lot D, zone B-QUAI (js/zones/d-b-quai.js) : le quai de livraison, [32, 40] × [-30, -16], au sous-sol,
## en béton brut. Au mur nord (S12), la baie A où un camion « Frais du jour » est à quai, arrière fermé dans
## son sas d'étanchéité, et la baie B au rideau métallique baissé ; les feux de quai. Palettes de cartons, de
## fûts et de casiers, la cage à linge, le transpalette, les bennes, le poste de réception et sa bascule.
## Liaisons : l'épine (sud, sous les lanières), les portes battantes S11 de la cuisine (ouest).

const LOT_D := "res://communes/casino_minuit/zones/lot_d.gd"


static func construire(K) -> void:
	var D = load(LOT_D)
	var H: float = D.H
	K.zone_debut("B-QUAI")
	K.zone.position.y = D.Y
	var b := {"x0": 32.0, "x1": 40.0, "z0": -30.0, "z1": -16.0}
	D.coque(K, b, H, {"south": [{"at": 34.0, "w": 4.0, "h": H}], "west": [{"at": -23.0, "w": 1.8}], "north": [{"at": 36.0, "w": 6.0, "h": 3.1}]}, {"mur": "brut", "soubassement": false})
	D.porte(K, "S11")
	var S := -16.212
	var Wx := 32.212
	var Ex := 39.788
	# Le soubassement peint et son filet jaune.
	for bb in [[Wx + 0.004, -27.5, 4.6], [Wx + 0.004, -19.2, 5.8], [Ex - 0.004, -23.0, 13.6]]:
		D.bx(K, "vertLino", 0.008, 1.2, bb[2], bb[0], 0.6, bb[1])
		D.bx(K, "jaune", 0.01, 0.06, bb[2], bb[0], 1.23, bb[1])
	D.bx(K, "vertLino", 3.6, 1.2, 0.008, 38, 0.6, S - 0.004)
	D.bx(K, "jaune", 3.6, 0.06, 0.01, 38, 1.23, S - 0.004)

	# --- S12 : les deux baies du mur nord ---
	K.obstacle(33, 39, -30, -29.6, 0.0, 3.1)
	D.bx(K, "noir", 6, 3.1, 0.04, 36, 1.55, -29.96)
	K.box("acier", 0.26, 3.1, 0.4, 36, 1.55, -29.79)
	# Baie A : l'arrière du camion à quai, son sas de caoutchouc, le pont de liaison.
	D.bx(K, "blanc", 2.56, 2.72, 0.5, 34.44, 1.6, -29.72)
	D.bx(K, "grisC", 2.5, 2.3, 0.01, 34.44, 1.68, -29.465)
	for x in [33.85, 35.03]:
		D.bx(K, "gris", 1.12, 2.0, 0.012, x, 1.68, -29.46)
	for x in [33.84, 34.3, 34.58, 35.04]:
		D.bx(K, "grisF", 0.05, 2.0, 0.016, x, 1.68, -29.455)
	K.texte("FRAIS DU JOUR", 2.0, 0.22, 34.44, 2.55, -29.45, 0, "grave", Color(D.SW.rouge))
	for x in [33.6, 35.28]:
		D.bx(K, "rouge", 0.26, 0.12, 0.01, x, 0.66, -29.45)
	D.bx(K, "grisF", 2.6, 0.26, 0.56, 34.44, 0.37, -29.7)
	for bb in [[33.08, 0.2], [35.8, 0.2]]:
		D.bx(K, "caout", bb[1], 3.1, 0.34, bb[0], 1.55, -29.66)
	D.bx(K, "caout", 2.9, 0.22, 0.34, 34.44, 3.0, -29.66)
	K.box("acier", 2.6, 0.03, 1.5, 34.44, 0.02, -28.75)
	D.hachure_sol(K, 2.6, 0.12, 12, 34.44, -28.06)
	D.bx(K, "grisF", 2.9, 0.34, 0.36, 34.44, 3.27, -29.62)
	# Baie B : le rideau baissé.
	for i in 15:
		K.box("acier", 2.86, 0.19, 0.035, 37.56, 0.3 + i * 0.195, -29.62)
		D.bx(K, "grisF", 2.86, 0.012, 0.04, 37.56, 0.2 + i * 0.195, -29.6)
	for x in [36.2, 38.92]:
		K.box("acier", 0.1, 3.1, 0.12, x, 1.55, -29.6)
	D.bx(K, "grisF", 2.9, 0.34, 0.36, 37.56, 3.27, -29.62)
	D.bx(K, "jaune", 0.14, 0.22, 0.08, 39.25, 1.3, -29.74)
	D.bx(K, "ledR", 0.04, 0.04, 0.02, 39.25, 1.36, -29.69)
	D.bx(K, "ledV", 0.04, 0.04, 0.02, 39.25, 1.26, -29.69)
	# Les feux de quai.
	D.bx(K, "noir", 0.16, 0.5, 0.1, 36, 2.36, -29.52)
	D.cy(K, "ledV", 0.05, 0.05, 0.03, 36, 2.48, -29.46, 8, PI / 2.0)
	D.cy(K, "grisF", 0.05, 0.05, 0.03, 36, 2.24, -29.46, 8, PI / 2.0)
	D.pochoir(K, "LIVRAISONS", 37.6, 3.26, -29.43, 0, 0.2)

	# --- les marchandises (côté est) ---
	var r: Array = D.palette(K, 39.0, -17.4, PI / 2.0)
	for k in 7:
		var cc: Array = [[-0.3, 0, -0.22], [0.3, 0, -0.22], [-0.3, 0, 0.24], [0.3, 0, 0.24], [-0.28, 0.42, -0.2], [0.3, 0.42, 0.2], [0, 0.84, 0]][k]
		D.carton(K, r, 0.56, 0.42, 0.44, cc[0], 0.355 + cc[1], cc[2], 0.06 if k % 3 == 0 else 0.0)
	r = D.palette(K, 39.0, -19.2, PI / 2.0)
	for dx in [-0.36, 0.0, 0.36]:
		for dz in [-0.25, 0.25]:
			var q: Vector2 = D.B().loc(r, dx, dz)
			K.cyl("acier", 0.19, 0.19, 0.5, q.x, 0.395, q.y, 12)
			D.cy(K, "noir", 0.03, 0.03, 0.03, q.x, 0.66, q.y, 6)
	r = D.palette(K, 39.0, -21.0, PI / 2.0)
	for k in 4:
		for j in 2:
			if k == 3 and j == 1:
				continue
			D.rbx(K, r, "rouge" if k % 2 else "bleu", 0.42, 0.28, 0.42, [-0.3, 0.3][j], 0.285 + k * 0.29, 0)
	r = D.palette(K, 37.6, -17.4, PI / 2.0)
	D.rbx(K, r, "blanc", 1.0, 0.9, 0.8, 0, 0.595, 0)
	D.rbx(K, r, "bleu", 1.02, 0.08, 0.82, 0, 0.5, 0)
	D.rbx(K, r, "bleu", 1.02, 0.08, 0.82, 0, 0.9, 0)
	D.chariot(K, 36.4, -17.5, PI / 2.0, "fonds")
	var tp := [36.9, -25.6, -0.4]
	for dx in [-0.2, 0.2]:
		D.rbx(K, tp, "jaune", 0.16, 0.06, 1.15, dx, 0.09, 0)
	D.rbx(K, tp, "jaune", 0.56, 0.42, 0.22, 0, 0.3, 0.68)
	D.rbx(K, tp, "noir", 0.04, 0.9, 0.04, 0, 0.9, 0.78)
	D.carton(K, tp, 0.5, 0.4, 0.5, 0, 0.32, -0.2, 0.1)
	K.rond(36.9, -25.6, 0.55)

	# --- les bennes (mur ouest, au nord de S11) ---
	for bb in [["vert", -26.2], ["bleu", -27.9]]:
		D.bx(K, bb[0], 0.9, 1.0, 1.4, 32.72, 0.62, bb[1])
		D.bx(K, "grisF", 0.96, 0.06, 1.46, 32.72, 1.15, bb[1])
		for w in [[-0.3, -0.5], [0.3, -0.5], [-0.3, 0.5], [0.3, 0.5]]:
			D.cy(K, "caout", 0.07, 0.07, 0.05, 32.72 + w[0], 0.07, bb[1] + w[1], 8, 0, PI / 2.0)
	K.obstacle(32.2, 33.2, -28.65, -25.45, 0.0, 1.2)

	# --- le poste de réception (mur est) ---
	D.table_inox(K, 39.35, -24.4, 0.7, 1.4, 0, 1.05)
	D.ecran(K, "ecranData", 39.55, 1.36, -24.1, -PI / 2.0, 0.44)
	D.bx(K, "bois", 0.24, 0.02, 0.34, 39.25, 1.07, -24.8, 0.2)
	D.plaque(K, "reception", Ex, 2.1, -24.4, -PI / 2.0, 1.0)
	K.box("acier", 0.9, 0.08, 0.9, 38.9, 0.04, -26.6)
	K.box("acier", 0.06, 1.2, 0.06, 39.4, 0.6, -26.6)
	D.bx(K, "noir", 0.06, 0.2, 0.3, 39.38, 1.3, -26.6)
	K.obstacle(38.45, 39.45, -27.05, -26.15, 0.0, 0.3)
	# Les livreurs : au poste de réception, au déchargement du camion, à la pause cigarette.
	D.place(K, "d_quai", 38.55, 0.0, -24.4, -PI / 2.0)
	D.place(K, "d_quai", 34.44, 0.0, -27.5, 0.0)
	D.place(K, "d_quai", 37.2, 0.0, -28.5, -PI / 2.0)
	D.place(K, "d_quai", 38.3, 0.0, -28.5, PI / 2.0)

	# --- les murs ---
	D.extincteur(K, Ex, -22.6, -PI / 2.0)
	D.armoire(K, Ex, -20.2, -PI / 2.0)
	D.affiche(K, "affiche", "vert", 0.6, 0.6, Ex, 1.75, -28.4, -PI / 2.0)
	D.plaque(K, "chariots", Wx, 2.0, -20.4, PI / 2.0, 1.0)
	D.plaque(K, "fumer", Ex, 2.0, -27.4, -PI / 2.0, 0.8)
	D.cy(K, "rouge", 0.3, 0.3, 0.12, Wx + 0.07, 1.5, -18.4, 14, 0, PI / 2.0)
	D.pochoir(K, "QUAI", Wx, 2.75, -19.6, PI / 2.0, 0.5)
	D.pochoir(K, "CUISINE", Wx, 2.72, -23, PI / 2.0, 0.24)
	D.sortie(K, 34, 3.05, S - 0.02, PI)

	# --- le sol ---
	D.pochoir_sol(K, "QUAI", 35.6, -21.4, 0, 1.1)
	D.ligne(K, "bleu", 34.2, -16.2, 34.2, -23, 0.09)
	D.ligne(K, "bleu", 34.25, -23, 32.3, -23, 0.09)
	D.ligne(K, "blanc", 33.0, -16.4, 33.0, -21.7, 0.07)
	D.ligne(K, "blanc", 35.4, -16.4, 35.4, -24.6, 0.07)
	D.hachure_sol(K, 3.0, 0.1, 15, 38.3, -22.2)
	D.hachure_sol(K, 3.0, 0.1, 15, 38.3, -16.5)

	# --- plafond, lumière ---
	D.reseaux(K, "z", 39.2, -29.4, -16.4)
	for p in [[34.4, -19.0], [34.4, -25.5], [37.8, -22.2], [37.8, -27.6]]:
		D.neon(K, p[0], p[1], "x")
	K.lumiere(35.8, 3.0, -24.2, Color("#dcebff"), 1.5, 14.0)
	D.dome(K, 33, H, -17)
	K.zone_fin()
