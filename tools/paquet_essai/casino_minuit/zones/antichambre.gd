extends RefCounted
## Lot D, zone B-ANTICHAMBRE (js/zones/d-b-antichambre.js) : le sas du coffre, [20, 32] × [10, 18], au
## sous-sol. Pièce maîtresse : la porte de coffre ronde (S06, mur ouest) dans son collier d'acier, disque de
## 3,56 m, douze pênes, volant à cinq branches, deux cadrans ; le moteur web l'ouvre à 100°, ici elle reste
## close (« coffre », minuit.gd) : le coffre ne se visite pas. Poste de garde (angle nord-est), le garde V8
## devant la porte, armoire forte, banc d'attente, gyrophare. Liaisons : la grille S04 vers l'épine (est),
## la porte blindée S05 vers le comptage (sud).

const LOT_D := "res://communes/casino_minuit/zones/lot_d.gd"
## La porte ronde : son centre (à 1,2 m du sol, sur le mur x = 20), le rayon de l'ouverture.
const CY := 1.2
const CZ := 14.0
const R := 1.6


static func construire(K) -> void:
	var D = load(LOT_D)
	var H: float = D.H
	K.zone_debut("B-ANTICHAMBRE")
	K.zone.position.y = D.Y
	var b := {"x0": 20.0, "x1": 32.0, "z0": 10.0, "z1": 18.0}
	D.coque(K, b, H, {"west": [{"at": 14.0, "w": 3.4, "h": 2.95}], "east": [{"at": 14.0, "w": 2.0, "h": 2.4}], "south": [{"at": 26.0, "w": 1.4}]})
	D.porte(K, "S05")
	var N := 10.212
	var S := 17.788
	var Wx := 20.212
	var Ex := 31.788

	# --- le collier et la porte ronde, close ---
	K.box("acier", 0.42, 2.95, 3.4, 20.0, 2.95 / 2.0, CZ)
	K.solide(0.5, 2.95, 3.4, 20.0, 2.95 / 2.0, CZ)
	K.tore("blindage", R + 0.19, 0.17, K.xf(20.27, CY, CZ, 0, 0, PI / 2.0), 40)
	for i in 18:
		var a := -0.55 + (PI + 1.1) * i / 17.0
		var y := CY + sin(a) * (R + 0.19)
		if y > 0.1:
			K.cyl("acier", 0.045, 0.045, 0.06, 20.4, y, CZ + cos(a) * (R + 0.19), 8, 0, PI / 2.0)
	# Le vantail : disque, cercle de rivets, platine, volant à cinq branches, deux cadrans, poignée.
	K.cyl("acier", 1.5, 1.5, 0.12, 20.27, CY, CZ, 40, 0, PI / 2.0)
	K.cyl("blindage", 1.3, 1.3, 0.03, 20.34, CY, CZ, 36, 0, PI / 2.0)
	for i in 24:
		var a := i * TAU / 24.0
		K.cyl("acier", 0.04, 0.04, 0.05, 20.35, CY + sin(a) * 1.4, CZ + cos(a) * 1.4, 8, 0, PI / 2.0)
	K.cyl("acier", 0.3, 0.34, 0.1, 20.38, CY, CZ, 16, 0, PI / 2.0)
	K.tore("acier", 0.62, 0.04, K.xf(20.62, CY, CZ, 0, 0, PI / 2.0), 32)
	for i in 5:
		var a := i * TAU / 5.0 + 0.3
		K.beam("acier", Vector3(20.62, CY, CZ), Vector3(20.62, CY + sin(a) * 0.62, CZ + cos(a) * 0.62), 0.05, 0.05)
		K.sph("acier", 0.07, 20.62, CY + sin(a) * 0.62, CZ + cos(a) * 0.62)
	K.cyl("acier", 0.12, 0.12, 0.34, 20.5, CY, CZ, 12, 0, PI / 2.0)
	K.cyl("acier", 0.16, 0.16, 0.05, 20.68, CY, CZ, 12, 0, PI / 2.0)
	for dz in [-0.78, 0.78]:
		D.cy(K, "creme", 0.18, 0.18, 0.02, 20.37, CY + 0.72, CZ + dz, 20, 0, PI / 2.0)
		K.cyl("acier", 0.06, 0.06, 0.06, 20.4, CY + 0.72, CZ + dz, 10, 0, PI / 2.0)
		D.bx(K, "noir", 0.012, 0.16, 0.012, 20.385, CY + 0.72, CZ + dz)
	K.box("acier", 0.06, 0.08, 0.7, 20.45, CY - 0.82, CZ)
	# La charnière, au nord : axe, platine murale.
	K.cyl("acier", 0.11, 0.11, 2.5, 20.4, 1.3, 12.05, 12)
	K.box("blindage", 0.24, 2.7, 0.5, 20.33, 1.35, 11.72)
	K.interaction("coffre", "La porte du coffre", 20.7, 1.3, CZ, Vector3(0.8, 2.6, 3.0))
	D.bx(K, "grisF", 0.7, 0.014, 2.1, 20.45, 0.007, CZ)
	D.pochoir(K, "COFFRE", Wx + 0.045, 3.17, CZ, PI / 2.0, 0.3)
	D.bx(K, "noir", 0.2, 0.05, 0.2, 20.4, 3.14, 16.2)
	D.cy(K, "ledR", 0.07, 0.08, 0.12, 20.4, 3.05, 16.2, 8)
	D.plaque(K, "acces", Wx, 1.85, 16.5, PI / 2.0, 0.7)
	D.plaque(K, "deux", Wx, 1.7, 16.5, PI / 2.0, 0.7)
	D.plaque(K, "video", Wx, 1.55, 16.5, PI / 2.0, 0.7)

	# --- poste de garde (angle nord-est) ---
	D.table_inox(K, 29.6, 11.8, 1.9, 0.8, 0, 0.78, false)
	D.bx(K, "grisF", 1.9, 0.7, 0.03, 29.6, 0.4, 12.19)
	D.ecran(K, "ecranCam", 29.2, 1.14, 12.05, PI, 0.56)
	D.ecran(K, "ecranData", 29.95, 1.14, 12.05, PI, 0.5)
	D.bx(K, "noir", 0.4, 0.02, 0.14, 29.5, 0.79, 11.65)
	D.bx(K, "rouge", 0.12, 0.07, 0.2, 30.35, 0.815, 11.7)
	D.siege(K, 29.6, 10.8, PI, 0.5)
	D.place(K, "d_gardes_assis", 29.6, 0.5, 10.8, PI)
	D.place(K, "d_gardes", 30.0, 0.0, 14.0, PI / 2.0)
	# Armoire à clés, râtelier des radios, armoire forte.
	D.bx(K, "gris", 0.7, 0.9, 0.14, 27.4, 1.5, N + 0.07)
	D.bx(K, "grisC", 0.64, 0.84, 0.006, 27.4, 1.5, N + 0.143)
	D.bx(K, "noir", 0.8, 0.06, 0.16, 25.9, 1.2, N + 0.08)
	for i in 4:
		D.bx(K, "noir", 0.07, 0.2, 0.05, 25.6 + i * 0.2, 1.33, N + 0.09)
		D.bx(K, "ledA" if i == 2 else "ledV", 0.015, 0.015, 0.01, 25.6 + i * 0.2, 1.26, N + 0.165)
	K.box("acier", 1.1, 2.0, 0.55, 22.4, 1.0, 17.5)
	K.box("blindage", 0.5, 1.8, 0.03, 22.14, 1.0, 17.21)
	K.box("blindage", 0.5, 1.8, 0.03, 22.66, 1.0, 17.21)
	K.obstacle(21.85, 22.95, 17.2, 17.8)
	# Le banc d'attente, contre le mur sud.
	K.box("acier", 2.0, 0.05, 0.42, 29.4, 0.45, 17.52)
	for dx in [-0.9, 0.0, 0.9]:
		K.box("acier", 0.05, 0.43, 0.38, 29.4 + dx, 0.215, 17.52)
	K.obstacle(28.4, 30.4, 17.3, 17.8, 0.0, 0.5)
	D.place(K, "d_sas_banc", 28.9, 0.47, 17.45, 0.0)
	D.place(K, "d_sas_banc", 29.9, 0.47, 17.45, 0.0)

	# --- sol : voie jaune, hachures devant la porte ---
	D.ligne(K, "jaune", 26, 17.75, 26, 14, 0.1)
	D.ligne(K, "jaune", 31.75, 14, 21.0, 14, 0.1)
	D.hachure_sol(K, 2.9, 0.12, 14, 21.7, 12.6)
	D.hachure_sol(K, 2.9, 0.12, 14, 21.7, 15.4)
	D.pochoir_sol(K, "COFFRE", 24.3, 14.6, PI / 2.0, 0.4)
	D.pochoir(K, "SAS", 24.6, 2.3, S, PI, 0.5)
	D.pochoir(K, "COMPTAGE", 26, 2.72, S, PI, 0.22)

	# --- lumière ---
	D.neon(K, 26, 14, "x")
	D.neon(K, 22.6, 10.75, "x", 1.2)
	D.neon(K, 29.6, 11.9, "x", 1.2)
	D.neon(K, 29.5, 16.2, "x", 1.2)
	D.lampe(K, 22.9, 14.1, 3.02, H, "neon")
	K.lumiere(23.4, 2.7, 14.4, Color("#e6f0ff"), 1.4, 11.0)
	D.reseaux(K, "x", 16.6, 21, 31.7)
	D.dome(K, 23.4, H, 16.8)
	D.dome(K, 31.2, H, 12.2)
	D.extincteur(K, Ex, 16.4, -PI / 2.0)
	D.sortie(K, Ex, 2.75, 14, -PI / 2.0)
	K.zone_fin()
