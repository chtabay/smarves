extends RefCounted
## Lot D, zone B-ENTRETIEN (js/zones/d-b-entretien.js) : la pièce où la sécurité conduit les fauteurs de
## trouble, [12, 20] × [-4, 4], au sous-sol. La table scellée et son anneau, le banc de l'interpellé face au
## miroir sans tain, la chaise de l'agent, une lampe unique ; la cellule de dégrisement à barreaux (angle
## nord-ouest), la toise et l'appareil photo, l'étagère des objets saisis, les classeurs, la fontaine.
## Liaison : la porte S08 vers la surveillance (est).

const LOT_D := "res://communes/casino_minuit/zones/lot_d.gd"


static func construire(K) -> void:
	var D = load(LOT_D)
	var H: float = D.H
	K.zone_debut("B-ENTRETIEN")
	K.zone.position.y = D.Y
	var b := {"x0": 12.0, "x1": 20.0, "z0": -4.0, "z1": 4.0}
	D.coque(K, b, H, {"east": [{"at": 0.0, "w": 1.0}]})
	var N := -3.788
	var S := 3.788
	var Wx := 12.212
	var Ex := 19.788

	# --- la table scellée, l'anneau, le banc, la chaise ---
	D.table_inox(K, 16.45, 0.9, 0.85, 1.7, 0, 0.76, false)
	K.box("acier", 0.04, 0.05, 0.5, 16.23, 0.79, 0.9)
	D.bx(K, "creme", 0.24, 0.02, 0.32, 16.7, 0.77, 0.7, 0.2)
	D.bx(K, "noir", 0.1, 0.03, 0.16, 16.75, 0.775, 1.25)
	D.bx(K, "ledR", 0.015, 0.012, 0.015, 16.75, 0.795, 1.2)
	D.cy(K, "blanc", 0.035, 0.03, 0.09, 16.25, 0.805, 1.45, 8)
	K.box("acier", 0.4, 0.05, 1.6, 14.77, 0.45, 0.9)
	for z in [0.25, 1.55]:
		K.box("acier", 0.34, 0.43, 0.05, 14.77, 0.215, z)
	K.box("acier", 0.04, 0.5, 1.6, 14.59, 0.72, 0.9)
	K.obstacle(14.57, 14.97, 0.1, 1.7, 0.0, 0.5)
	D.place(K, "d_interpelle", 14.8, 0.47, 0.5, -PI / 2.0)
	D.siege(K, 17.4, 0.9, PI / 2.0, 0.48)
	D.place(K, "d_entretien_agent", 17.4, 0.48, 0.9, PI / 2.0)
	D.place(K, "d_gardes", 18.8, 0.0, -0.9, PI / 2.0 + 0.6)

	# --- la lampe unique ---
	D.lampe(K, 16.45, 0.9, 2.05)
	K.lumiere(16.45, 1.95, 0.9, Color("#ffe2b8"), 1.6, 8.0)

	# --- le miroir sans tain (mur est, au nord de la porte) ---
	K.box("miroir", 0.012, 1.0, 1.9, Ex, 1.55, -2.3)
	for y in [1.03, 2.07]:
		K.box("acier", 0.05, 0.06, 2.0, Ex - 0.02, y, -2.3)
	for z in [-3.3, -1.3]:
		K.box("acier", 0.05, 1.1, 0.06, Ex - 0.02, 1.55, z)
	D.plaque(K, "rec", Ex, 2.35, -2.3, -PI / 2.0, 0.7)
	D.plaque(K, "video", Ex, 1.75, 1.4, -PI / 2.0, 0.7)

	# --- la cellule de dégrisement : barreaux, porte entrouverte, banc ---
	var x := 12.3
	while x <= 13.75:
		K.cyl("acier", 0.018, 0.018, 2.5, x, 1.25, -1.3, 6)
		x += 0.13
	for xx in [14.95, 15.08, 15.21]:
		K.cyl("acier", 0.018, 0.018, 2.5, xx, 1.25, -1.3, 6)
	var z := -3.7
	while z <= -1.3:
		K.cyl("acier", 0.018, 0.018, 2.5, 15.3, 1.25, z, 6)
		z += 0.13
	for y in [0.06, 1.25, 2.5]:
		K.box("acier", 1.55, 0.06, 0.05, 13.02, y, -1.3)
		K.box("acier", 0.4, 0.06, 0.05, 15.12, y, -1.3)
		K.box("acier", 0.05, 0.06, 2.45, 15.3, y, -2.5)
	K.box("acier", 3.1, 0.06, 0.05, 13.76, 2.5, -1.3)
	K.segment(12.2, -1.3, 13.8, -1.3, 0.04)
	K.segment(14.92, -1.3, 15.3, -1.3, 0.04)
	K.segment(15.3, -1.3, 15.3, -3.8, 0.04)
	# La porte de la cellule, entrouverte vers la pièce.
	var pc := [13.8, -1.3, -1.9]
	for i in 9:
		var q: Vector2 = D.B().loc(pc, i * 0.135, 0.0)
		K.cyl("acier", 0.018, 0.018, 2.4, q.x, 1.25, q.y, 6)
	for y in [0.08, 1.25, 2.42]:
		D.B().rbox(K, pc, "acier", 1.1, 0.06, 0.05, 0.55, y, 0.0)
	K.box("acier", 2.2, 0.05, 0.45, 13.5, 0.45, -3.52)
	for xx in [12.5, 14.5]:
		K.box("acier", 0.05, 0.43, 0.4, xx, 0.215, -3.52)
	K.obstacle(12.4, 14.6, -3.78, -3.3, 0.0, 0.5)
	D.hachure_sol(K, 3.2, 0.1, 16, 13.75, -1.05)
	D.neon(K, 13.6, -2.6, "x", 1.0)

	# --- la toise et l'appareil photo (mur sud) ---
	D.affiche(K, "blanc", "", 0.7, 1.4, 13.6, 1.5, S, PI)
	for k in 6:
		D.bx(K, "noir", 0.7, 0.01, 0.014, 13.6, 0.9 + k * 0.25, S - 0.008)
	D.bx(K, "grisF", 0.76, 0.03, 0.02, 13.6, 2.22, S - 0.01)
	for l in [[-0.18, -0.12], [0.18, -0.12], [0.0, 0.2]]:
		K.beam(D.c("noir"), Vector3(13.6, 1.35, 2.2), Vector3(13.6 + l[0], 0.0, 2.2 + l[1]), 0.02, 0.02)
	D.bx(K, "noir", 0.16, 0.12, 0.2, 13.6, 1.42, 2.22)
	D.cy(K, "noir", 0.04, 0.05, 0.08, 13.6, 1.42, 2.36, 8, PI / 2.0)
	K.rond(13.6, 2.2, 0.25)

	# --- l'étagère des objets saisis, les classeurs, la fontaine ---
	var saisis := func(r: Array, i: int, l: int, y: float, cx: float) -> void:
		match (i + l) % 3:
			0: D.carton(K, r, 0.5, 0.3, 0.36, cx, y + 0.15, 0.0)
			1:
				D.rbx(K, r, "grisC", 0.36, 0.14, 0.3, cx - 0.1, y + 0.07, 0.0)
				D.rbx(K, r, "rouge", 0.12, 0.05, 0.01, cx - 0.1, y + 0.08, -0.155)
			_:
				D.rbx(K, r, "noir", 0.3, 0.2, 0.3, cx, y + 0.1, 0.0)
	D.rayonnage(K, 17.8, S - 0.3, 0, 3, 0.95, 0.45, 2.0, 4, saisis)
	D.plaque(K, "saisis", 17.8, 2.3, S, PI, 0.9)
	for xx in [17.2, 17.75]:
		D.bx(K, "gris", 0.5, 1.3, 0.55, xx, 0.65, N + 0.29)
		for y in [0.25, 0.68, 1.1]:
			D.bx(K, "grisF", 0.44, 0.36, 0.02, xx, y, N + 0.575)
	K.obstacle(16.9, 18.05, N - 0.02, N + 0.6)
	D.bx(K, "blanc", 0.34, 1.0, 0.34, 19.3, 0.5, N + 0.2)
	D.cy(K, "bleu", 0.13, 0.13, 0.36, 19.3, 1.2, N + 0.2, 10)
	K.obstacle(19.1, 19.5, N, N + 0.4)
	D.affiche(K, "affiche", "rouge", 0.7, 0.7, 16.2, 1.7, N, 0)
	D.pochoir(K, "ENTRETIEN", Wx, 2.6, 1.6, PI / 2.0, 0.36)
	D.extincteur(K, Ex, 2.6, -PI / 2.0)
	D.dome(K, 19.3, H, 3.3)
	D.dome(K, 12.7, H, -3.3)
	D.reseaux(K, "z", 19.2, -3.7, 3.7)
	K.zone_fin()
