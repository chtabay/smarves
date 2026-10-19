extends RefCounted
## Lot D, zone B-SECURITE (js/zones/d-b-securite.js) : la salle de surveillance, [20, 32] × [-4, 10], au
## sous-sol, dans une pénombre bleutée. Le mur de neuf moniteurs (mur ouest) et sa console, six pupitres
## d'opérateurs en deux rangées face au mur, la table tactique au plan du casino, la baie de serveurs (mur
## nord), la vitre sans tain sur la salle d'entretien, le tableau des tournées et les radios (mur sud). Le moteur
## web y rendait en direct les caméras du casino ; ici les écrans luisent de leurs teintes.
## Liaisons : la porte blindée S07 vers l'épine (est), la porte S08 de la salle d'entretien (ouest).

const LOT_D := "res://communes/casino_minuit/zones/lot_d.gd"
const TEINTES := ["ecranCam", "ecranCam", "ecranData", "ecranCam", "ecranPlan", "ecranCam", "ecranCam", "ecranCompte", "ecranCam"]


static func construire(K) -> void:
	var D = load(LOT_D)
	var H: float = D.H
	K.zone_debut("B-SECURITE")
	K.zone.position.y = D.Y
	var b := {"x0": 20.0, "x1": 32.0, "z0": -4.0, "z1": 10.0}
	D.coque(K, b, H, {"east": [{"at": 3.0, "w": 1.2}], "west": [{"at": 0.0, "w": 1.0}]})
	D.porte(K, "S08")
	var N := -3.788
	var S := 9.788
	var Wx := 20.212
	var Ex := 31.788

	# --- le mur de moniteurs : 3 × 3 écrans de 1,2 m, châssis, console basse ---
	K.box("acier", 0.1, 2.5, 4.1, Wx + 0.01, 1.95, 5.2)
	for r in 3:
		for k in 3:
			var z := 5.2 + (k - 1) * 1.27
			var y := 1.95 + (r - 1) * 0.745
			D.bx(K, "noir", 0.04, 0.715, 1.24, Wx + 0.08, y, z)
			D.bx(K, TEINTES[r * 3 + k] if r * 3 + k != 6 else "ecran", 0.006, 0.675, 1.2, Wx + 0.103, y, z)
			# Une silhouette de salle sur chaque vue : le pied d'une table, une allée.
			D.bx(K, "noir", 0.008, 0.08, 0.5, Wx + 0.108, y - 0.18, z + 0.1 * (k - 1))
	for z in [3.12, 7.28]:
		K.box("acier", 0.16, 2.5, 0.08, Wx + 0.08, 1.95, z)
	for y in [0.7, 3.2]:
		K.box("acier", 0.16, 0.08, 4.24, Wx + 0.08, y, 5.2)
	D.plaque(K, "direct", Wx + 0.165, 3.2, 4.0, PI / 2.0, 0.7)
	D.bx(K, "ledR", 0.03, 0.05, 0.05, Wx + 0.17, 3.2, 3.4)
	D.bx(K, "grisF", 0.5, 0.62, 4.2, Wx + 0.25, 0.31, 5.2)
	K.obstacle(20.2, 20.72, 3.1, 7.3)
	for i in 14:
		D.bx(K, "ledA" if i % 5 == 2 else ("ledR" if i % 7 == 3 else "ledV"), 0.02, 0.02, 0.03, Wx + 0.505, 0.45, 3.4 + i * 0.28)

	# --- six pupitres, deux rangées de trois, face au mur ---
	var n := 0
	for x in [23.7, 26.7]:
		for z in [2.9, 5.2, 7.5]:
			n += 1
			var on := n <= 4
			D.bx(K, "grisF", 0.8, 0.05, 1.8, x, 0.735, z)
			D.bx(K, "noir", 0.04, 0.71, 1.7, x - 0.36, 0.355, z)
			for dz in [-0.86, 0.86]:
				D.bx(K, "grisF", 0.76, 0.71, 0.04, x, 0.355, z + dz)
			D.bx(K, "grisF", 0.3, 0.3, 1.8, x - 0.25, 0.93, z)
			for e in [[-0.5, 0], [0.15, 1]]:
				D.bx(K, "noir", 0.03, 0.4, 0.6, x - 0.3, 1.24, z + e[0])
				D.bx(K, TEINTES[(n + e[1]) % 9] if on else "noir", 0.006, 0.34, 0.54, x - 0.283, 1.24, z + e[0])
				D.bx(K, "noir", 0.04, 0.3, 0.05, x - 0.33, 0.92, z + e[0])
			D.bx(K, "noir", 0.14, 0.02, 0.42, x + 0.08, 0.77, z - 0.2)
			D.sp(K, "rouge", 0.025, x + 0.12, 0.87, z + 0.42)
			if n % 2:
				D.cy(K, "blanc", 0.04, 0.035, 0.09, x + 0.2, 0.805, z + 0.7, 8)
			K.obstacle(x - 0.4, x + 0.4, z - 0.9, z + 0.9, 0.0, 1.0)
			D.siege(K, x + 0.72, z, PI / 2.0, 0.5)
			if on:
				D.place(K, "d_secu", x + 0.72, 0.5, z, PI / 2.0)

	# --- la table tactique, au plan du casino ---
	K.box("acier", 1.5, 0.06, 1.0, 29.6, 0.95, 7.2)
	D.bx(K, "noir", 0.5, 0.9, 0.5, 29.6, 0.46, 7.2)
	D.bx(K, "ecranPlan", 1.36, 0.006, 0.86, 29.6, 0.985, 7.2)
	for l in [[-0.3, 0.6, 0.02], [0.2, 0.02, 0.5], [0.0, 0.9, 0.02]]:
		D.bx(K, "noir", l[1], 0.008, l[2] if l[2] > 0.1 else 0.03, 29.6 + l[0], 0.99, 7.2 + l[0] * 0.5)
	K.obstacle(28.85, 30.35, 6.7, 7.7, 0.0, 1.0)
	D.place(K, "d_secu_debout", 29.6, 0.0, 8.2, 0.0)
	D.place(K, "d_secu_debout", 28.5, 0.0, 5.2, PI / 2.0)

	# --- la baie de serveurs (mur nord) ---
	for i in 5:
		var x := 22.2 + i * 0.65
		D.bx(K, "noir", 0.6, 2.05, 0.8, x, 1.025, N + 0.42)
		D.bx(K, "grisF", 0.52, 1.9, 0.006, x, 1.05, N + 0.823)
		for k in 7:
			D.bx(K, "ledA" if (i * 3 + k) % 6 == 0 else ("ledR" if (i + k) % 9 == 4 else "ledV"), 0.03, 0.015, 0.01, x - 0.18 + ((k * 7 + i) % 4) * 0.09, 0.35 + k * 0.24, N + 0.83)
	K.obstacle(21.9, 25.1, N - 0.02, N + 0.84)
	D.reseaux(K, "x", N + 0.5, 21, 31.6, H - 0.26, false)
	D.pochoir(K, "LOCAL TECHNIQUE", 28.6, 2.0, N, 0, 0.2)

	# --- la vitre sans tain sur la salle d'entretien (mur ouest, au nord de S08) ---
	K.box("aplat#1A2630", 0.012, 1.0, 1.9, Wx, 1.55, -2.3)
	for y in [1.03, 2.07]:
		K.box("acier", 0.05, 0.06, 2.0, Wx + 0.02, y, -2.3)
	for z in [-3.3, -1.3]:
		K.box("acier", 0.05, 1.1, 0.06, Wx + 0.02, 1.55, z)
	D.bx(K, "grisF", 0.4, 0.04, 1.6, Wx + 0.2, 0.95, -2.3)
	D.bx(K, "noir", 0.14, 0.1, 0.22, Wx + 0.2, 1.02, -2.7)
	D.plaque(K, "rec", Wx, 2.35, -2.3, PI / 2.0, 0.7)

	# --- mur sud : tournées de fonds, planning, radios, coin café ---
	D.affiche(K, "blanc", "bleu", 1.7, 1.28, 23.2, 1.65, S, PI)
	D.affiche(K, "affiche", "bleu", 1.3, 0.98, 25.2, 1.65, S, PI)
	D.affiche(K, "affiche", "vert", 0.6, 0.6, 26.6, 1.65, S, PI)
	D.bx(K, "noir", 1.0, 0.06, 0.18, 21.2, 1.15, S - 0.09)
	for i in 5:
		D.bx(K, "noir", 0.07, 0.2, 0.05, 20.8 + i * 0.2, 1.28, S - 0.1)
	D.table_inox(K, 29.7, 9.4, 1.6, 0.6)
	D.bx(K, "noir", 0.3, 0.36, 0.3, 29.3, 1.08, 9.45)
	D.cy(K, "blanc", 0.04, 0.035, 0.09, 29.8, 0.945, 9.35, 8)
	D.bx(K, "rose", 0.24, 0.07, 0.24, 30.25, 0.935, 9.4)

	# --- mur est ---
	D.cy(K, "blanc", 0.2, 0.2, 0.02, Ex - 0.01, 2.6, 6, 16, 0, PI / 2.0)
	D.plaque(K, "rec", Ex, 1.8, 4.4, -PI / 2.0, 0.7)
	D.plaque(K, "badge", Ex, 1.66, 4.4, -PI / 2.0, 0.7)
	D.extincteur(K, Ex, 1.5, -PI / 2.0)
	D.sortie(K, Ex, 2.62, 3, -PI / 2.0)
	D.bx(K, "gris", 0.5, 1.9, 0.9, 31.5, 0.95, -1.4)
	K.obstacle(31.25, 31.8, -1.85, -0.95)
	D.pochoir(K, "SURVEILLANCE", Ex, 2.9, 7.6, -PI / 2.0, 0.3)

	# --- lumière : pénombre bleutée ---
	D.neon(K, 29.6, 2.5, "x", 1.2)
	D.neon(K, 29.6, 8.6, "x", 1.2)
	K.lumiere(23.6, 2.6, 5.2, Color("#8fbfff"), 1.1, 11.0)
	D.dome(K, 30.8, H, 9)
	K.zone_fin()
