extends RefCounted
## Lot D, zone B-CUISINE (js/zones/d-b-cuisine.js) : la cuisine centrale, [20, 32] × [-30, -16], au
## sous-sol. L'îlot de cuisson dos à dos (x = 26, z de -27 à -20 : feux, planchas, bains-marie, fours) sous
## la grande hotte ; la préparation et la plonge le long du mur ouest ; les chambres froides et l'armoire
## (mur nord) ; le passe sous ses lampes chauffantes (mur sud). Quatre postes, le chef au passe.
## Liaison : les portes battantes S11 vers le quai (est), posées par le quai.

const LOT_D := "res://communes/casino_minuit/zones/lot_d.gd"
const Z0 := -27.0
const Z1 := -20.0


static func construire(K) -> void:
	var D = load(LOT_D)
	var H: float = D.H
	K.zone_debut("B-CUISINE")
	K.zone.position.y = D.Y
	var b := {"x0": 20.0, "x1": 32.0, "z0": -30.0, "z1": -16.0}
	D.coque(K, b, H, {"east": [{"at": -23.0, "w": 1.8}]}, {"soubassement": false})
	var N := -29.788
	var S := -16.212
	var Wx := 20.212
	var Ex := 31.788
	# La faïence blanche jusqu'à 1,8 m, sur les quatre murs.
	for w in [[Wx + 0.004, -23.0, 0.008, 13.6], [Ex - 0.004, -26.85, 0.008, 5.9], [Ex - 0.004, -19.15, 0.008, 5.9]]:
		D.bx(K, "blanc", w[2], 1.8, w[3], w[0], 0.9, w[1])
	for w in [[26.0, N + 0.004, 11.6], [26.0, S - 0.004, 11.6]]:
		D.bx(K, "blanc", w[2], 1.8, 0.008, w[0], 0.9, w[1])

	# --- l'îlot de cuisson ---
	var zm := (Z0 + Z1) / 2.0
	for s in [-1.0, 1.0]:
		var x: float = 26.0 + s * 0.42
		K.box("acier", 0.8, 0.88, Z1 - Z0, x, 0.44, zm)
		D.bx(K, "grisF", 0.82, 0.1, Z1 - Z0 + 0.02, x, 0.05, zm)
		for i in 7:
			var z := Z0 + 0.5 + i
			var genre := (i + (3 if s > 0 else 0)) % 7
			D.bx(K, "noir", 0.01, 0.42, 0.74, x + s * 0.405, 0.4, z)
			K.box("acier", 0.03, 0.03, 0.6, x + s * 0.43, 0.68, z)
			for dz in [-0.3, -0.1, 0.1, 0.3]:
				D.cy(K, "noir", 0.022, 0.022, 0.03, x + s * 0.415, 0.8, z + dz, 6, 0, PI / 2.0)
			if genre < 4:
				for k in 4:
					var bb: Array = [[-0.18, -0.22], [0.18, -0.22], [-0.18, 0.22], [0.18, 0.22]][k]
					D.cy(K, "noir", 0.13, 0.13, 0.02, x + bb[0], 0.89, z + bb[1], 10)
					if (i + k) % 3 != 1:
						D.cy(K, "flamme", 0.1, 0.1, 0.012, x + bb[0], 0.905, z + bb[1], 10)
				if genre % 2 == 0:
					K.cyl("acier", 0.17, 0.16, 0.24, x - 0.18, 1.03, z - 0.22, 12)
					K.box("acier", 0.44, 0.03, 0.04, x - 0.18, 1.1, z - 0.22)
				else:
					D.cy(K, "noir", 0.16, 0.14, 0.05, x + 0.18, 0.93, z + 0.22, 12)
					D.bx(K, "noir", 0.04, 0.03, 0.3, x + 0.18, 0.95, z + 0.5)
			elif genre == 4:
				D.bx(K, "grisF", 0.66, 0.03, 0.8, x, 0.895, z)
				D.bx(K, "orange", 0.2, 0.02, 0.14, x - 0.1, 0.92, z - 0.15)
				D.bx(K, "rose", 0.16, 0.02, 0.2, x + 0.12, 0.92, z + 0.12)
			elif genre == 5:
				D.bx(K, "noir", 0.6, 0.02, 0.8, x, 0.89, z)
				for dz in [-0.2, 0.2]:
					K.box("acier", 0.5, 0.14, 0.3, x, 0.93, z + dz)
					D.bx(K, "ledA", 0.44, 0.01, 0.24, x, 0.995, z + dz)
			else:
				K.box("acier", 0.7, 0.03, 0.9, x, 0.895, z)
				D.cy(K, "blanc", 0.14, 0.1, 0.03, x, 0.93, z - 0.2, 12)
				D.cy(K, "vert", 0.08, 0.08, 0.012, x, 0.95, z - 0.2, 8)
	K.box("acier", 0.36, 0.03, Z1 - Z0 - 0.4, 26, 1.45, zm)
	var z := Z0 + 0.3
	while z <= Z1 - 0.2:
		K.box("acier", 0.04, 0.58, 0.04, 26, 1.17, z)
		z += 1.6
	for i in 5:
		var zz: float = [-25.6, -24.9, -23.2, -22.4, -21.1][i]
		if i % 2:
			D.cy(K, "blanc", 0.13, 0.13, 0.1 + (i % 3) * 0.04, 26, 1.52, zz, 10)
		else:
			K.cyl("acier", 0.11, 0.1, 0.16, 26, 1.545, zz, 10)
	K.obstacle(25.15, 26.85, Z0 - 0.02, Z1 + 0.02, 0.0, 1.0)
	# La hotte.
	K.box("acier", 2.5, 0.5, Z1 - Z0 + 0.6, 26, 2.45, zm)
	K.box("acier", 2.1, 0.22, Z1 - Z0 + 0.2, 26, 2.1, zm)
	for s in [-1.0, 1.0]:
		D.bx(K, "grisF", 0.01, 0.28, Z1 - Z0, 26 + s * 1.055, 2.08, zm)
		D.bx(K, "neon", 0.05, 0.03, Z1 - Z0 - 0.4, 26 + s * 0.6, 1.975, zm)
	for zz in [-25.4, -21.6]:
		K.box("acier", 0.7, H - 2.7, 0.7, 26, (H + 2.7) / 2.0, zz)
	D.place(K, "d_cuisine", 24.75, 0.0, -25.5, -PI / 2.0)
	D.place(K, "d_cuisine", 27.25, 0.0, -22.0, PI / 2.0)
	D.place(K, "d_cuisine", 24.75, 0.0, -21.6, -PI / 2.0)

	# --- la préparation (mur ouest, nord) ---
	for k in 2:
		var zp: float = [-27.9, -25.3][k]
		D.table_inox(K, Wx + 0.45, zp, 0.85, 2.4)
		D.bx(K, "vert" if k else "rouge", 0.4, 0.025, 0.6, Wx + 0.5, 0.915, zp - 0.5)
		D.bx(K, "blanc", 0.4, 0.025, 0.55, Wx + 0.5, 0.915, zp + 0.45)
		K.cyl("acier", 0.17, 0.11, 0.12, Wx + 0.45, 0.96, zp + 0.95, 12)
		D.bx(K, "orange" if k else "vert", 0.16, 0.04, 0.2, Wx + 0.5, 0.95, zp - 0.5)
	K.box("acier", 0.34, 0.03, 4.9, Wx + 0.17, 1.75, -26.6)
	var bocaux := ["blanc", "rouge", "jaune", "blanc", "vert"]
	for i in 5:
		D.cy(K, bocaux[i], 0.1, 0.1, 0.22, Wx + 0.18, 1.875, [-28.6, -27.6, -26.2, -25.2, -24.6][i], 8)
	D.place(K, "d_cuisine", Wx + 1.25, 0.0, -25.5, PI / 2.0)

	# --- la plonge (mur ouest, sud) ---
	D.table_inox(K, Wx + 0.45, -19.4, 0.85, 3.6)
	for zz in [-20.4, -19.4]:
		D.bx(K, "grisF", 0.6, 0.02, 0.8, Wx + 0.45, 0.905, zz)
	K.beam("acier", Vector3(Wx + 0.12, 0.9, -19.9), Vector3(Wx + 0.12, 1.5, -19.9), 0.03, 0.03)
	K.beam("acier", Vector3(Wx + 0.12, 1.5, -19.9), Vector3(Wx + 0.45, 1.35, -19.9), 0.03, 0.03)
	D.bx(K, "grisC", 0.52, 0.12, 0.52, Wx + 0.45, 0.975, -18.3)
	for i in 6:
		D.cy(K, "blanc", 0.13, 0.13, 0.012, Wx + 0.45, 1.1, -18.5 + i * 0.07, 10, PI / 2.0 - 0.25)
	K.box("acier", 0.8, 1.5, 0.9, Wx + 0.42, 0.75, -22.2)
	D.bx(K, "noir", 0.01, 0.5, 0.7, Wx + 0.825, 1.1, -22.2)
	D.bx(K, "ledV", 0.01, 0.03, 0.08, Wx + 0.83, 1.42, -22.45)
	K.obstacle(Wx, Wx + 0.84, -22.65, -21.75)
	for i in 2:
		for k in 4:
			D.cy(K, "blanc", 0.13, 0.13, 0.02, Wx + 0.2 + i * 0.05, 0.93 + k * 0.022, [-18.0, -17.6][i], 10)
	D.pochoir(K, "PLONGE", Wx, 2.5, -19.4, PI / 2.0, 0.34)
	D.place(K, "d_plonge", Wx + 1.25, 0.0, -19.6, PI / 2.0)

	# --- les chambres froides et l'armoire (mur nord) ---
	for i in 2:
		var x: float = [22.0, 24.3][i]
		D.bx(K, "blanc", 1.5, 2.2, 0.1, x, 1.1, N + 0.05)
		D.bx(K, "grisC", 1.3, 2.05, 0.06, x, 1.08, N + 0.11)
		K.box("acier", 0.06, 0.5, 0.08, x + 0.5, 1.15, N + 0.17)
		D.bx(K, "noir", 0.4, 0.2, 0.06, x, 2.42, N + 0.03)
		D.bx(K, "ledV", 0.3, 0.12, 0.006, x, 2.42, N + 0.065)
		if i == 0:
			D.plaque(K, "froid", x + 1.15, 2.42, N, 0, 0.7)
	K.box("acier", 1.5, 2.0, 0.8, 27.2, 1.0, N + 0.4)
	K.box("blindage", 0.7, 1.8, 0.02, 26.83, 1.03, N + 0.805)
	K.box("blindage", 0.7, 1.8, 0.02, 27.57, 1.03, N + 0.805)
	K.obstacle(26.45, 27.95, N, N + 0.82)
	var reserve := func(r: Array, i: int, l: int, y: float, cx: float) -> void:
		if l == 0:
			D.carton(K, r, 0.7, 0.34, 0.4, cx, y + 0.17, 0.0)
		elif l == 3:
			var q: Vector2 = D.B().loc(r, cx - 0.2, 0.0)
			D.cy(K, "blanc", 0.14, 0.14, 0.3, q.x, y + 0.15, q.y, 10)
			q = D.B().loc(r, cx + 0.18, 0.0)
			D.cy(K, "bleu", 0.14, 0.14, 0.3, q.x, y + 0.15, q.y, 10)
		else:
			for k in 4:
				var q: Vector2 = D.B().loc(r, cx - 0.3 + k * 0.2, 0.02)
				D.cy(K, ["rouge", "jaune", "vert", "orange"][(i + l + k) % 4], 0.075, 0.075, 0.2, q.x, y + 0.1, q.y, 8)
	D.rayonnage(K, 29.8, N + 0.3, 0, 3, 1.0, 0.5, 2.2, 4, reserve)

	# --- le passe (mur sud) ---
	K.box("acier", 6.6, 0.9, 0.7, 25.6, 0.45, S - 0.35)
	K.box("acier", 6.6, 0.04, 0.36, 25.6, 1.42, S - 0.2)
	for x in [22.4, 24.5, 26.7, 28.8]:
		K.box("acier", 0.04, 0.5, 0.04, x, 1.17, S - 0.08)
	var garnitures := ["orange", "vert", "rose", "jaune"]
	for i in 4:
		var x: float = [23.2, 24.6, 26.0, 27.4][i]
		D.bx(K, "ledA", 0.5, 0.03, 0.14, x, 1.385, S - 0.26)
		D.cy(K, "blanc", 0.15, 0.11, 0.025, x - 0.15, 0.915, S - 0.38, 12)
		D.cy(K, garnitures[i], 0.08, 0.09, 0.03, x - 0.15, 0.94, S - 0.38, 8)
		if i % 2:
			D.cy(K, "blanc", 0.15, 0.11, 0.025, x + 0.25, 0.915, S - 0.32, 12)
	D.affiche(K, "blanc", "", 2.4, 0.6, 24.6, 1.85, S, PI)
	for i in 8:
		D.bx(K, "affiche", 0.22, 0.4, 0.01, 23.6 + i * 0.29, 1.82, S - 0.012)
	D.plaque(K, "passe", 27.8, 1.9, S, PI, 0.9)
	K.obstacle(22.3, 28.9, S - 0.7, S, 0.0, 1.0)
	D.place(K, "d_chef", 26.2, 0.0, S - 1.25, PI)

	# --- mur est : lave-mains, chariots, bacs de tri ---
	D.bx(K, "blanc", 0.36, 0.14, 0.44, Ex - 0.19, 0.85, -21.3)
	D.plaque(K, "mains", Ex, 1.6, -21.3, -PI / 2.0, 0.7)
	D.chariot(K, 31.25, -26.2, 0, "plateau", [["blanc", 0.6, 0.02, 0.9, 0, 1.005, 0], ["grisC", 0.24, 0.1, 0.24, -0.12, 1.07, -0.25], ["grisC", 0.24, 0.1, 0.24, 0.14, 1.07, 0.2], ["blanc", 0.6, 0.02, 0.9, 0, 0.585, 0], ["bleu", 0.4, 0.2, 0.4, 0, 0.7, 0.1]])
	D.chariot(K, 31.25, -28.2, 0.08, "plateau", [["carton", 0.5, 0.3, 0.5, 0, 1.15, 0.2], ["carton", 0.44, 0.24, 0.4, 0.03, 1.12, -0.3], ["bleu", 0.4, 0.28, 0.4, 0, 0.74, -0.2], ["bleu", 0.4, 0.28, 0.4, 0, 0.74, 0.25]])
	for bb in [["vert", -24.7], ["jaune", -25.2]]:
		D.bx(K, bb[0], 0.42, 0.8, 0.42, 31.5, 0.4, bb[1])
		D.bx(K, "grisF", 0.44, 0.04, 0.44, 31.5, 0.82, bb[1])
	K.obstacle(31.28, 31.72, -25.42, -24.48, 0.0, 0.85)
	D.extincteur(K, Ex, -19.9, -PI / 2.0)
	D.sortie(K, Ex, 2.62, -23, -PI / 2.0)
	D.bx(K, "grisF", 0.5, 0.26, 0.1, 29.8, 2.6, S - 0.05)
	D.bx(K, "violet", 0.42, 0.04, 0.02, 29.8, 2.6, S - 0.11)
	D.cy(K, "blanc", 0.22, 0.22, 0.02, 30.6, 2.5, N + 0.01, 16, PI / 2.0)
	D.pochoir(K, "CUISINE", Ex, 2.75, -18.6, -PI / 2.0, 0.3)
	# Le sol : siphons, le panneau « sol glissant », la bande bleue vers le quai.
	for p in [[23.4, -23.5], [28.6, -23.5], [23.4, -18.6]]:
		D.bx(K, "grisF", 0.4, 0.004, 0.4, p[0], 0.004, p[1])
	D.bx(K, "jaune", 0.3, 0.62, 0.02, 28.9, 0.3, -19.2, 0.4)
	D.bx(K, "jaune", 0.3, 0.62, 0.02, 28.82, 0.3, -19.02, 0.4)
	D.ligne(K, "bleu", 31.75, -23, 28.2, -23, 0.09)

	# --- lumière ---
	for p in [[22.6, -27.0], [22.6, -21.5], [29.4, -27.0], [29.4, -21.5]]:
		D.neon(K, p[0], p[1])
	D.neon(K, 25.6, -17.8, "x")
	K.lumiere(26.4, 3.0, -22.6, Color("#f2f4ff"), 1.5, 14.0)
	D.reseaux(K, "x", -18.9, 20.4, 31.6)
	D.dome(K, 31, H, -17)
	K.zone_fin()
