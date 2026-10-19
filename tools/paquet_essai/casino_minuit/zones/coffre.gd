extends RefCounted
## Lot D, zone B-COFFRE (js/zones/d-b-coffre.js) : le coffre, [2, 20] × [4, 24], au sous-sol, 4,4 m sous
## plafond. Murs et plafond blindés, sol époxy sombre ; l'allée centrale (z = 14) dans l'axe de la porte
## ronde, douze palettes de billets, les lingots sur trois plots et sur les rayonnages du mur nord, le mur
## de 416 coffrets (ouest), la cage à jetons (angle sud-est), le poste d'inventaire. Sa porte reste close
## (antichambre.gd) : le coffre est bâti, on ne le visite pas.

const LOT_D := "res://communes/casino_minuit/zones/lot_d.gd"
const H := 4.4


static func construire(K) -> void:
	var D = load(LOT_D)
	K.zone_debut("B-COFFRE")
	K.zone.position.y = D.Y
	var b := {"x0": 2.0, "x1": 20.0, "z0": 4.0, "z1": 24.0}
	D.coque(K, b, H, {"east": [{"at": 14.0, "w": 3.4, "h": 2.95}]}, {"sol": "sol_coffre", "mur": "blindage", "plafond": false})
	K.plan("blindage", 2, 20, 4, 24, H, false)
	var N := 4.212
	var S := 23.788
	var Wx := 2.212
	var Ex := 19.788
	# La face intérieure de la porte ronde : platine du mécanisme, douze pênes engagés.
	K.cyl("blindage", 1.55, 1.55, 0.1, 19.75, 1.2, 14, 36, 0, PI / 2.0)
	K.cyl("acier", 1.1, 1.1, 0.03, 19.68, 1.2, 14, 36, 0, PI / 2.0)
	for i in 12:
		var a := i * TAU / 12.0 + 0.26
		K.beam("acier", Vector3(19.66, 1.2 + sin(a) * 0.5, 14 + cos(a) * 0.5), Vector3(19.66, 1.2 + sin(a) * 1.4, 14 + cos(a) * 1.4), 0.05, 0.03)

	# --- charpente : poutres d'acier, nervures murales ---
	for x in [5.0, 8.0, 11.0, 14.0, 17.0]:
		K.box("acier", 0.22, 0.34, 19.6, x, H - 0.17, 14)
		K.box("acier", 0.22, H, 0.12, x, H / 2.0, N + 0.06)
		K.box("acier", 0.22, H, 0.12, x, H / 2.0, S - 0.06)
	for z in [9.0, 14.0, 19.0]:
		K.box("acier", 17.6, 0.2, 0.18, 11, H - 0.1, z)

	# --- palettes de billets : cinq et cinq le long de l'allée, deux au fond ---
	var hs := [1.2, 0.9, 0.45, 1.2, 1.05, 1.2, 1.2, 0.75, 1.2, 0.9]
	var xs := [6.0, 8.5, 11.0, 13.5, 16.0]
	for i in 5:
		_palette(K, D, xs[i], 10.5, 0.02 * (i % 3 - 1), hs[i])
		_palette(K, D, xs[i], 17.5, -0.02 * (i % 3 - 1), hs[i + 5])
	_palette(K, D, 3.9, 7.6, PI / 2.0, 1.2)
	_palette(K, D, 3.9, 20.4, PI / 2.0, 0.6)
	D.liasses(K, 11.0, 0.145 + 0.45, 10.5, 3, 4, 4, 0.1)
	D.liasses(K, 3.9, 0.145 + 0.6, 20.4, 2, 3, 3, PI / 2.0)
	# Le transpalette, près de la palette en cours de dépôt.
	var tp := [12.2, 12.3, 0.5]
	for dx in [-0.2, 0.2]:
		D.rbx(K, tp, "jaune", 0.16, 0.06, 1.15, dx, 0.09, 0)
	D.rbx(K, tp, "jaune", 0.56, 0.42, 0.22, 0, 0.3, 0.68)
	D.rbx(K, tp, "noir", 0.04, 0.9, 0.04, 0, 0.9, 0.78)
	K.rond(12.2, 12.3, 0.5)

	# --- les lingots : trois plots au fond de l'allée, les rayonnages du mur nord ---
	for p in [[5.3, 11.6], [4.7, 14.0], [5.3, 16.4]]:
		K.box("acier", 1.0, 0.62, 1.9, p[0], 0.31, p[1])
		K.box("blindage", 1.1, 0.06, 2.0, p[0], 0.65, p[1])
		D.bx(K, "bordeaux", 0.94, 0.012, 1.84, p[0], 0.686, p[1])
		_lingots(K, p[0], 0.692, p[1], [[3, 10], [2, 9], [2, 7], [1, 5]], PI / 2.0)
		K.obstacle(p[0] - 0.55, p[0] + 0.55, p[1] - 1.0, p[1] + 1.0, 0.0, 1.0)
	D.plaque(K, "lingots", 5.9, 0.4, 14, PI / 2.0, 0.9)
	var lingots := func(r: Array, i: int, l: int, y: float, cx: float) -> void:
		if (i + l) % 4 != 3 and l < 3:
			var q: Vector2 = D.B().loc(r, cx, 0.0)
			_lingots(K, q.x, y, q.y, [[3, 3], [3, 2], [2, 2]].slice(0, 3 - ((i + l) % 2)), 0.0)
	D.rayonnage(K, 9.5, N + 0.34, 0, 5, 1.2, 0.55, 2.5, 4, lingots)
	var sacs := func(r: Array, i: int, l: int, y: float, cx: float) -> void:
		if l < 2:
			var q: Vector2 = D.B().loc(r, cx - 0.28, 0.0)
			D.sp(K, "toile", 0.2, q.x, y + 0.17, q.y, 0.85)
			q = D.B().loc(r, cx + 0.2, 0.03)
			D.sp(K, "toile", 0.19, q.x, y + 0.16, q.y, 0.85)
		else:
			D.rbx(K, r, "grisF", 0.48, 0.24, 0.42, cx - 0.27, y + 0.12, 0.0)
			D.rbx(K, r, "jaune", 0.2, 0.08, 0.01, cx - 0.27, y + 0.13, 0.215)
			D.rbx(K, r, "grisF", 0.48, 0.24, 0.42, cx + 0.27, y + 0.12, 0.0)
			D.rbx(K, r, "rouge", 0.2, 0.08, 0.01, cx + 0.27, y + 0.13, 0.215)
	D.rayonnage(K, 15.9, N + 0.34, 0, 4, 1.2, 0.55, 2.5, 4, sacs)

	# --- le mur des coffrets (ouest) : 26 colonnes de 16, encadrées d'acier ---
	var x := Wx + 0.06
	D.bx(K, "grisC", 0.03, 2.46, 16.0, x, 1.55, 14)
	for j in 17:
		D.bx(K, "grisF", 0.036, 0.012, 16.0, x, 0.32 + j * 2.46 / 16.0, 14)
	for i in 27:
		D.bx(K, "grisF", 0.036, 2.46, 0.014, x, 1.55, 6.0 + i * 16.0 / 26.0)
	for j in 16:
		for i in 26:
			if (i * 7 + j * 3) % 5 == 0:
				D.bx(K, "jaune", 0.04, 0.03, 0.06, x, 0.32 + (j + 0.45) * 2.46 / 16.0, 6.0 + (i + 0.5) * 16.0 / 26.0)
	K.box("acier", 0.1, 0.12, 16.2, Wx + 0.05, 2.84, 14)
	K.box("acier", 0.14, 0.3, 16.2, Wx + 0.07, 0.16, 14)
	# L'échelle roulante, la table de consultation des coffrets.
	for dz in [-0.25, 0.25]:
		K.beam("acier", Vector3(3.3, 0, 18.6 + dz), Vector3(2.43, 2.84, 18.6 + dz), 0.04, 0.04)
	for i in range(1, 9):
		var t := i / 9.0
		K.box("acier", 0.05, 0.025, 0.5, 3.3 - 0.87 * t, 2.84 * t, 18.6)
	K.rond(3.05, 18.6, 0.35)
	D.table_inox(K, 4.1, 21.9, 1.5, 0.7, 0, 0.95, false)
	K.box("blindage", 0.5, 0.12, 0.3, 4.0, 1.01, 21.9)

	# --- la cage à jetons (angle sud-est) ---
	var ch := 2.6
	for g in [[14.4, 19.9, 16.4, 19.9], [17.7, 19.9, Ex, 19.9], [14.4, 19.9, 14.4, S]]:
		_grille(K, g[0], g[1], g[2], g[3], ch)
	D.plaque(K, "jetons", 15.4, 2.2, 19.87, PI, 0.9)
	var chips := func(r: Array, _i: int, _l: int, y: float, cx: float) -> void:
		D.rbx(K, r, "noir", 0.94, 0.26, 0.46, cx, y + 0.14, 0.0)
		for k in 8:
			D.rbx(K, r, ["rouge", "vert", "bleu", "violet", "orange", "blanc", "rose", "noir"][k], 0.1, 0.22, 0.01, cx - 0.4 + k * 0.115, y + 0.14, -0.235)
	D.rayonnage(K, 17.0, S - 0.32, 0, 5, 1.0, 0.52, 2.3, 5, chips)
	D.chariot(K, 15.5, 21.6, 0.3, "plateau", [["noir", 0.6, 0.06, 0.9, 0, 1.03, 0], ["rouge", 0.5, 0.05, 0.12, 0, 1.085, -0.3], ["vert", 0.5, 0.05, 0.12, 0, 1.085, -0.1], ["bleu", 0.5, 0.05, 0.12, 0, 1.085, 0.1], ["violet", 0.5, 0.05, 0.12, 0, 1.085, 0.3]])

	# --- le poste d'inventaire (angle nord-est) ---
	D.table_inox(K, 18.6, 6.6, 1.0, 1.8, 0, 0.95, false)
	D.ecran(K, "ecranCompte", 18.9, 1.3, 6.2, -PI / 2.0, 0.5)
	D.bx(K, "blanc", 0.3, 0.03, 0.42, 18.45, 0.965, 7.0, 0.1)

	# --- sol : l'allée balisée ---
	D.ligne(K, "jaune", 19.6, 12.75, 6.6, 12.75, 0.08)
	D.ligne(K, "jaune", 19.6, 15.25, 6.6, 15.25, 0.08)
	D.ligne(K, "jaune", 6.6, 12.75, 6.6, 15.25, 0.08)
	D.ligne(K, "rouge", 2.9, 5, 2.9, 23, 0.06)
	D.pochoir_sol(K, "COFFRE", 17.2, 14, PI / 2.0, 0.55)

	# --- lumière : suspensions sur l'allée et les rangées ---
	for p in [[16.5, 14.0], [11.0, 14.0], [6.5, 14.0], [8.5, 10.5], [13.5, 10.5], [8.5, 17.5], [13.5, 17.5], [17.0, 21.6], [16.5, 6.8]]:
		D.lampe(K, p[0], p[1], 3.35, H - 0.3)
	K.lumiere(12.5, 3.5, 14, Color("#fff1dc"), 1.6, 15.0)
	K.lumiere(5.4, 2.9, 14, Color("#ffe0a8"), 1.4, 10.0)
	for p in [[18.0, 11.0], [18.0, 17.0], [6.5, 9.0], [6.5, 19.0]]:
		D.dome(K, p[0], H - 0.34, p[1])
	D.plaque(K, "video", Ex, 1.9, 11.4, -PI / 2.0, 0.8)
	D.extincteur(K, Ex, 10.6, -PI / 2.0)
	K.zone_fin()


## Une palette de billets (le bloc de liasses, son cerclage, l'étiquette d'inventaire), de hauteur hc.
static func _palette(K, D, x: float, z: float, ry: float, hc: float) -> void:
	var r: Array = D.palette(K, x, z, ry)
	D.rbx(K, r, "billet", 1.08, hc, 0.88, 0, 0.145 + hc / 2.0, 0)
	for k in int(round(hc / 0.15)):
		D.rbx(K, r, "creme", 1.1, 0.012, 0.9, 0, 0.145 + (k + 0.5) * hc / round(hc / 0.15), 0)
	for dx in [-0.3, 0.3]:
		D.rbx(K, r, "blanc", 0.035, hc + 0.004, 0.9, dx, 0.145 + hc / 2.0, 0)
	D.rbx(K, r, "jaune", 0.2, 0.14, 0.004, 0.36, 0.145 + minf(hc - 0.1, 0.45), 0.446)


## Un tas de lingots en gradins : couches [[n le long de x, n le long de z]], tourné de ry.
static func _lingots(K, x: float, y: float, z: float, couches: Array, ry: float) -> void:
	for j in couches.size():
		var l: Array = couches[j]
		for i in l[0]:
			for k in l[1]:
				var lx: float = (i - (l[0] - 1) / 2.0) * 0.265
				var lz: float = (k - (l[1] - 1) / 2.0) * 0.125
				K.box("or", 0.25, 0.07, 0.11, x + lx * cos(ry) + lz * sin(ry), y + 0.035 + j * 0.072, z - lx * sin(ry) + lz * cos(ry), ry)


## Un pan de grillage de la cage à jetons, de (x0, z0) à (x1, z1) : barreaux, lisses, collision.
static func _grille(K, x0: float, z0: float, x1: float, z1: float, ch: float) -> void:
	var l := Vector2(x1 - x0, z1 - z0).length()
	var n := maxi(1, int(round(l / 0.16)))
	for i in n + 1:
		var t := float(i) / n
		K.box("acier", 0.02, ch, 0.02, x0 + (x1 - x0) * t, ch / 2.0, z0 + (z1 - z0) * t)
	for y in [0.05, 1.3, ch]:
		K.beam("acier", Vector3(x0, y, z0), Vector3(x1, y, z1), 0.06, 0.06)
	K.segment(x0, z0, x1, z1, 0.05, 0.0, ch)
