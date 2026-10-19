extends RefCounted
## Lot D, zone B-COMPTAGE (js/zones/d-b-comptage.js) : la salle de comptage du cash, [20, 32] × [18, 30], au
## sous-sol. Trois tables inox à compteuse, piles de liasses et boîte de recette ouverte, sous leur réglette
## de travail ; la table de mise sous bande ; le rayonnage des boîtes de recette (mur sud) ; le bureau vitré
## du chef de comptage (angle nord-est) ; le chariot de fonds en cours de déchargement, la balance des pièces.
## Liaisons : la porte à hublot S03 vers l'épine (est), la porte blindée S05 vers le sas du coffre (nord).

const LOT_D := "res://communes/casino_minuit/zones/lot_d.gd"


static func construire(K) -> void:
	var D = load(LOT_D)
	var H: float = D.H
	K.zone_debut("B-COMPTAGE")
	K.zone.position.y = D.Y
	var b := {"x0": 20.0, "x1": 32.0, "z0": 18.0, "z1": 30.0}
	D.coque(K, b, H, {"east": [{"at": 24.0, "w": 1.6}], "north": [{"at": 26.0, "w": 1.4}]})
	var N := 18.212
	var Wx := 20.212
	var Ex := 31.788

	# --- les tables de comptage ---
	for t in [[23.0, 27.1, 1.0], [29.1, 27.1, 1.0], [22.6, 21.3, -1.0]]:
		_table(K, D, t[0], t[1], t[2])
	D.ecran(K, "ecranCompte", 23.95, 1.2, 26.72, 0, 0.46)
	D.ecran(K, "ecranCompte", 30.05, 1.2, 26.72, 0, 0.46)
	# La table de mise sous bande : les blocs filmés prêts à descendre au coffre.
	D.table_inox(K, 22.9, 24.3, 2.2, 1.0)
	for bb in [[-0.6, 0.48], [0.05, 0.36]]:
		D.bx(K, "billet", 0.52, bb[1], 0.38, 22.9 + bb[0], 0.9 + bb[1] / 2.0, 24.3)
		D.bx(K, "blanc", 0.03, bb[1] + 0.006, 0.39, 22.9 + bb[0], 0.9 + bb[1] / 2.0, 24.3)
	D.bx(K, "grisC", 0.5, 0.34, 0.44, 23.65, 1.07, 24.3)
	D.bx(K, "noir", 0.36, 0.1, 0.3, 23.65, 1.19, 24.3)
	D.bx(K, "billet", 1.08, 0.36, 0.54, 22.9, 0.415, 24.3)
	D.liasses(K, 22.3, 0.9, 24.62, 2, 2, 2, 0.2)
	D.bx(K, "grisF", 1.7, 0.06, 0.16, 22.9, 2.25, 24.3)
	D.bx(K, "neon", 1.6, 0.03, 0.1, 22.9, 2.21, 24.3)
	D.place(K, "d_comptage_debout", 22.9, 0.0, 25.1, 0.0)

	# --- le rayonnage des boîtes de recette (mur sud) ---
	var boites := func(r: Array, i: int, l: int, y: float, cx: float) -> void:
		if l == 3 and i % 3 == 1:
			return
		var n := (i * 7 + l * 3) % 4
		for k in 3:
			if k == n:
				continue
			var x := cx - 0.34 + k * 0.34
			D.rbx(K, r, "noir", 0.3, 0.22, 0.38, x, y + 0.11, 0.0)
			D.rbx(K, r, "rouge" if (i + l + k) % 5 == 0 else "jaune", 0.15, 0.08, 0.01, x, y + 0.13, -0.195)
	D.rayonnage(K, 25.6, 29.5, 0, 10, 1.1, 0.5, 2.3, 4, boites)

	# --- le bureau vitré du chef de comptage (angle nord-est) ---
	var gz := 21.5
	var gx := 28.2
	for s in [[gx, gz, 31.8, gz], [gx, 18.2, gx, 19.3], [gx, 20.5, gx, gz]]:
		var lg := Vector2(s[2] - s[0], s[3] - s[1]).length()
		var cx: float = (s[0] + s[2]) / 2.0
		var cz: float = (s[1] + s[3]) / 2.0
		var hor: bool = s[1] == s[3]
		D.bx(K, "grisF", lg if hor else 0.08, 0.9, 0.08 if hor else lg, cx, 0.45, cz)
		K.box("verre", lg if hor else 0.02, 1.4, 0.02 if hor else lg, cx, 1.6, cz)
		K.box("acier", lg if hor else 0.06, 0.05, 0.06 if hor else lg, cx, 2.32, cz)
		K.box("acier", lg if hor else 0.06, 0.04, 0.06 if hor else lg, cx, 0.91, cz)
		var n := maxi(1, int(round(lg / 1.2)))
		for i in n + 1:
			K.box("acier", 0.05, 2.3, 0.05, s[0] + (s[2] - s[0]) * i / n, 1.15, s[1] + (s[3] - s[1]) * i / n)
		K.segment(s[0], s[1], s[2], s[3], 0.05)
	D.table_inox(K, 30.2, 20.6, 1.8, 0.75, 0, 0.76, false)
	D.ecran(K, "ecranData", 29.85, 1.12, 20.85, PI, 0.52)
	D.ecran(K, "ecranCam", 30.5, 1.12, 20.85, PI, 0.52)
	D.bx(K, "blanc", 0.3, 0.02, 0.22, 30.8, 0.77, 20.4, 0.2)
	D.siege(K, 30.2, 19.75, PI, 0.48)
	D.place(K, "d_comptage", 30.2, 0.48, 19.75, PI)
	D.bx(K, "gris", 0.45, 1.3, 0.9, 31.5, 0.65, 18.9)
	for y in [1.05, 0.62, 0.2]:
		D.bx(K, "grisF", 0.02, 0.36, 0.8, 31.27, y, 18.9)
	K.obstacle(31.25, 31.8, 18.4, 19.4)
	D.affiche(K, "blanc", "bleu", 1.3, 0.98, 30.2, 1.7, N, 0)
	D.cy(K, "blanc", 0.18, 0.18, 0.02, 28.8, 2.6, N + 0.01, 16, PI / 2.0)

	# --- le chariot en déchargement, la balance des pièces et ses sacs ---
	D.chariot(K, 30.6, 22.75, PI / 2.0, "fonds")
	D.hachure_sol(K, 1.6, 0.1, 8, 30.6, 22.1)
	D.hachure_sol(K, 1.6, 0.1, 8, 30.6, 23.4)
	K.box("acier", 0.7, 0.1, 0.7, 20.75, 0.05, 24.6)
	K.box("acier", 0.06, 1.1, 0.06, 20.45, 0.55, 24.6)
	D.bx(K, "noir", 0.06, 0.2, 0.3, 20.47, 1.2, 24.6)
	D.bx(K, "ecranCompte", 0.006, 0.11, 0.26, 20.51, 1.2, 24.6)
	for s in [[20.75, 24.55, 0.22], [20.6, 25.5, 0.2], [20.95, 25.7, 0.18], [20.7, 26.0, 0.17]]:
		D.sp(K, "toile", s[2], s[0], s[2] * 0.8, s[1], 0.85)
	K.obstacle(20.2, 21.15, 24.2, 26.2, 0.0, 1.2)

	# --- signalétique ---
	D.pochoir(K, "COMPTAGE", Wx, 2.45, 23.2, PI / 2.0, 0.55)
	D.affiche(K, "affiche", "rouge", 0.9, 0.9, Wx, 1.6, 19.2, PI / 2.0)
	D.pochoir(K, "SAS", 24.6, 2.0, N, 0, 0.3)
	D.pochoir(K, "COFFRE", 26, 2.72, N, 0, 0.26)
	D.plaque(K, "deux", 27.35, 1.75, N, 0, 0.62)
	D.plaque(K, "rec", 27.35, 1.61, N, 0, 0.62)
	D.plaque(K, "video", Ex, 1.9, 26.2, -PI / 2.0, 0.7)
	D.extincteur(K, Ex, 25.6, -PI / 2.0)
	D.sortie(K, Ex, 2.6, 24, -PI / 2.0)
	D.ligne(K, "jaune", 31.75, 24, 26, 24, 0.1)
	D.ligne(K, "jaune", 26, 24.05, 26, 18.25, 0.1)

	# --- lumière ---
	D.neon(K, 26, 21.2)
	D.neon(K, 26, 26.2)
	D.neon(K, 30.2, 19.8, "x", 1.2)
	K.lumiere(25.8, 3.0, 24.6, Color("#dcebff"), 1.5, 13.0)
	D.reseaux(K, "x", 23.6, 20.4, 31.6)
	K.zone_fin()


## Une table de comptage (side = 1 : le compteur est au sud de la table et regarde au nord) : compteuse,
## boîte de recette ouverte, piles de liasses, réglette de travail suspendue, tabouret ; sa place.
static func _table(K, D, x: float, z: float, side: float) -> void:
	var H: float = D.H
	D.table_inox(K, x, z, 2.6, 1.1)
	var cz := z + side * 0.18
	D.bx(K, "grisC", 0.42, 0.28, 0.36, x + 0.75, 1.04, cz)
	D.bx(K, "grisF", 0.34, 0.14, 0.2, x + 0.75, 1.25, cz - side * 0.04)
	D.bx(K, "ecranCompte", 0.3, 0.12, 0.006, x + 0.75, 1.06, cz + side * 0.182)
	D.bx(K, "noir", 0.36, 0.22, 0.3, x - 1.0, 1.01, z - side * 0.2)
	D.bx(K, "jaune", 0.16, 0.08, 0.01, x - 1.0, 1.03, z - side * 0.2 + side * 0.152)
	K.box("acier", 0.5, 0.03, 0.36, x + 0.1, 0.915, z + side * 0.25)
	D.liasses(K, x - 0.35, 0.9, z - side * 0.15, 3, 4, 4)
	D.liasses(K, x + 0.2, 0.9, z - side * 0.25, 2, 6, 3)
	D.liasses(K, x + 0.1, 0.93, z + side * 0.25, 2, 1, 3, 0.1)
	D.bx(K, "grisF", 1.7, 0.06, 0.16, x, 2.25, z)
	D.bx(K, "neon", 1.6, 0.03, 0.1, x, 2.21, z)
	for dx in [-0.7, 0.7]:
		D.cy(K, "grisF", 0.008, 0.008, H - 2.28, x + dx, (H + 2.28) / 2.0, z, 4)
	D.dome(K, x + 1.0, H, z - side * 0.6)
	var f := 0.0 if side > 0 else PI
	D.siege(K, x, z + side * 0.9, f, 0.62, false)
	D.place(K, "d_comptage", x, 0.62, z + side * 0.9, f)
