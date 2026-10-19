extends RefCounted
## Lot D, zone R-ARRIERE (js/zones/d-r-arriere.js) : l'arrière-caisse, [27, 36] × [21, 30], au
## rez-de-chaussée, derrière la grille de la caisse. Les armoires à jetons vitrées (mur ouest), les deux
## coffres de jour (mur sud), la table de remplissage des racks, la compteuse à billets, le bureau du chef de
## caisse, le registre des mouvements, le chariot de fonds en attente. Portes : L14 vers la caisse (posée par
## minuit.gd, close sous le seuil des coulisses), L15 vers le couloir de service (est), ouverte.

const LOT_D := "res://communes/casino_minuit/zones/lot_d.gd"


static func construire(K) -> void:
	var D = load(LOT_D)
	var H: float = D.H
	K.zone_debut("R-ARRIERE")
	var b := {"x0": 27.0, "x1": 36.0, "z0": 21.0, "z1": 30.0}
	D.coque(K, b, H, {"north": [{"at": 31.5, "w": 1.2}], "east": [{"at": 24.0, "w": 1.4}]})
	D.porte(K, "L15")
	var N := 21.212
	var S := 29.788
	var Wx := 27.212
	var Ex := 35.788
	D.plaque(K, "perso", 31.5, 1.62, 20.775, PI, 0.5)

	# --- les armoires à jetons (mur ouest) : trois corps vitrés, cinq rayons de jetons ---
	var couleurs := ["rouge", "vert", "noir", "bleu", "violet", "orange", "blanc", "rose"]
	for z in [23.3, 25.0, 26.7]:
		D.bx(K, "grisF", 0.5, 2.15, 1.6, 27.47, 1.075, z)
		D.bx(K, "noir", 0.02, 1.9, 1.44, 27.725, 1.1, z)
		for j in 5:
			K.box("acier", 0.06, 0.02, 1.44, 27.74, 0.2 + j * 0.37, z)
			for k in 12:
				D.bx(K, couleurs[(k * 5 + j * 3) % 8], 0.012, 0.26, 0.1, 27.745, 0.36 + j * 0.37, z - 0.64 + k * 0.116)
		K.box("verre", 0.01, 1.94, 1.46, 27.76, 1.1, z)
	K.obstacle(27.2, 27.76, 22.5, 27.5)
	D.plaque(K, "jetons", Wx + 0.52, 2.32, 25.0, PI / 2.0, 0.9)

	# --- les coffres de jour (mur sud) ---
	for i in 2:
		var x: float = [29.2, 30.8][i]
		K.box("acier", 1.25, 1.7, 0.8, x, 0.95, 29.38)
		K.box("blindage", 1.05, 1.5, 0.04, x, 0.95, 28.965)
		D.bx(K, "grisF", 1.3, 0.1, 0.84, x, 0.05, 29.38)
		D.cy(K, "creme", 0.13, 0.13, 0.02, x - 0.18, 1.15, 28.94, 16, PI / 2.0)
		K.box("acier", 0.05, 0.34, 0.05, x + 0.28, 1.1, 28.92)
		D.bx(K, "ledR" if i else "ledV", 0.03, 0.03, 0.02, x - 0.18, 1.42, 28.94)
	K.obstacle(28.5, 31.5, 28.9, 29.8)
	D.plaque(K, "jour", 30, 2.2, S, PI, 0.9)
	for s in [[32.4, 29.3, 0.2], [32.75, 29.4, 0.17], [32.55, 29.05, 0.16], [33.0, 29.1, 0.18]]:
		D.sp(K, "toile", s[2], s[0], s[2] * 0.8, s[1], 0.85)
	var recettes := func(r: Array, _i: int, l: int, y: float, cx: float) -> void:
		if l == 3:
			D.rbx(K, r, "carton", 0.7, 0.3, 0.36, cx, y + 0.15, 0.0)
		else:
			for dx in [-0.2, 0.22]:
				D.rbx(K, r, "noir", 0.34, 0.2, 0.36, cx + dx, y + 0.1, 0.0)
				D.rbx(K, r, "jaune", 0.14, 0.07, 0.01, cx + dx, y + 0.12, -0.185)
	D.rayonnage(K, 34.5, 29.45, 0, 2, 1.0, 0.5, 2.1, 4, recettes)

	# --- poste 1 : la table de remplissage des racks (centre) ---
	D.table_inox(K, 30.2, 25.9, 2.0, 0.85)
	for dx in [-0.6, -0.2, 0.2]:
		D.bx(K, "noir", 0.34, 0.05, 0.5, 30.2 + dx, 0.925, 25.85)
		for k in 5:
			D.bx(K, couleurs[k], 0.05, 0.02, 0.44, 30.07 + dx + k * 0.065, 0.955, 25.85)
	D.bx(K, "grisC", 0.36, 0.26, 0.3, 30.95, 1.03, 25.8)
	D.siege(K, 30.2, 26.75, 0, 0.62, false)
	D.place(K, "d_arriere", 30.2, 0.62, 26.75, 0.0, 0.0)
	# Poste 2 : la compteuse à billets (mur est, au sud de L15).
	D.table_inox(K, 35.3, 27.4, 0.8, 1.9)
	D.bx(K, "grisC", 0.36, 0.3, 0.42, 35.35, 1.05, 27.9)
	D.bx(K, "grisF", 0.3, 0.12, 0.3, 35.33, 1.26, 27.9)
	D.ecran(K, "ecranCompte", 35.5, 1.25, 26.8, -PI / 2.0, 0.5)
	D.siege(K, 34.5, 27.4, -PI / 2.0, 0.62)
	D.place(K, "d_arriere", 34.5, 0.62, 27.4, -PI / 2.0, 0.0)
	# Poste 3 : le bureau du chef de caisse (mur nord, à l'ouest de L14).
	D.table_inox(K, 28.6, 21.7, 1.8, 0.75, 0, 0.76)
	D.ecran(K, "ecranData", 28.3, 1.12, 21.45, 0, 0.56)
	D.ecran(K, "ecranCam", 28.95, 1.12, 21.45, 0, 0.56)
	D.bx(K, "rouge", 0.12, 0.07, 0.2, 29.3, 0.795, 21.8)
	D.siege(K, 28.6, 22.45, 0, 0.48)
	D.place(K, "d_arriere", 28.6, 0.48, 22.45, 0.0, 0.0)

	# --- le registre des mouvements, le passe-jetons vers les guichets ---
	D.bx(K, "grisF", 0.5, 1.05, 0.36, 33.3, 0.525, 21.42)
	D.bx(K, "blanc", 0.4, 0.02, 0.28, 33.3, 1.07, 21.44)
	K.obstacle(33.05, 33.55, 21.2, 21.62, 0.0, 1.1)
	D.plaque(K, "registre", 33.3, 1.75, N, 0, 0.8)
	D.affiche(K, "blanc", "bleu", 1.3, 0.98, 34.7, 1.65, N, 0)
	K.box("acier", 0.9, 0.5, 0.06, 30.0, 1.15, N + 0.02)
	K.box("verre", 0.76, 0.36, 0.02, 30.0, 1.15, N + 0.045)
	D.place(K, "d_arriere_debout", 32.6, 0.0, 22.4, PI + 0.3, 0.0)

	# --- le chariot de fonds en attente, le marquage ---
	D.chariot(K, 33.9, 26.0, PI / 2.0, "fonds")
	D.ligne(K, "jaune", 31.5, 21.25, 31.5, 23.4, 0.1)
	D.ligne(K, "jaune", 31.45, 23.4, 35.75, 24, 0.1)
	D.hachure_sol(K, 1.5, 0.1, 8, 33.9, 25.25)
	D.hachure_sol(K, 1.5, 0.1, 8, 33.9, 26.75)

	# --- lumière, surveillance, sécurité ---
	D.neon(K, 30.2, 25.4, "x")
	D.neon(K, 33.6, 23.2, "x")
	D.neon(K, 33.6, 27.6, "x")
	D.neon(K, 28.8, 22.6, "x")
	K.lumiere(31.5, 3.0, 25.2, Color("#cfe4ff"), 1.3, 11.0)
	D.reseaux(K, "x", 28.3, 27.3, 35.7)
	D.dome(K, 30.2, H, 27.2)
	D.dome(K, 34.6, H, 22.2)
	D.plaque(K, "video", Ex, 1.9, 22.3, -PI / 2.0, 0.7)
	D.plaque(K, "deux", Ex, 1.76, 22.3, -PI / 2.0, 0.7)
	D.extincteur(K, Ex, 25.3, -PI / 2.0)
	D.affiche(K, "affiche", "rouge", 0.7, 0.7, Wx, 1.65, 28.4, PI / 2.0)
	D.cy(K, "blanc", 0.18, 0.18, 0.02, 31.5, 2.75, N + 0.01, 16, PI / 2.0)
	D.pochoir(K, "CAISSE", 31.5, 2.42, N, 0, 0.2)
	D.pochoir(K, "SERVICE", Ex, 2.5, 24, -PI / 2.0, 0.22)
	K.zone_fin()
