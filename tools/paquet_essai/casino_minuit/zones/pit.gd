extends RefCounted
## Lot C, zone R-PIT (js/zones/c-pit.js) : la grande fosse de tables [18, 36] × [-12, 12], rez-de-chaussée.
## Cinq tables de blackjack, deux roulettes et la roue de la fortune, en décor animé (les jeux ne sont pas
## encore jouables) ; le pupitre du chef de table au centre de l'ovale ; la gaine de l'ascenseur panoramique
## ASC-B et les deux escalators qui montent à la mezzanine (on les gravit à pied). Liaisons : colonnade
## ouverte vers l'atrium (ouest), baie à deux colonnes vers la caisse (sud), baie du foyer (nord), porte du
## personnel L25 (est), vers les coulisses : posée par minuit.gd, close sous le seuil du lieu.

const LOT_B := "res://communes/casino_minuit/zones/lot_b.gd"
const LOT_C := "res://communes/casino_minuit/zones/lot_c.gd"
const H := 5.4
const B := {"x0": 18.0, "x1": 36.0, "z0": -12.0, "z1": 12.0}
const OUV := {"west": false, "north": [{"at": 20.0, "w": 3.6, "h": 3.6}], "south": [{"at": 28.0, "w": 8.0, "h": 3.6}], "east": [{"at": 2.0, "w": 1.4, "h": 2.2}]}
const CX := 28.5
const CZ := 1.5
const RX := 5.4
const RZ := 8.9


static func construire(K) -> void:
	var LB = load(LOT_B)
	var L = load(LOT_C)
	var E: Dictionary = L.ESC
	K.zone_debut("R-PIT")
	var gaine := {"x0": 18.0, "x1": 21.0, "z0": 9.0, "z1": 12.0}
	var tremie := {"x0": E.x0, "x1": E.x1, "z0": -12.0, "z1": -9.0}

	# --- enveloppe ---
	L.sol(K, "moquette", B.x0, B.x1, B.z0, B.z1, 0.0, [gaine])
	L.plafond(K, "plafond_bas", B.x0, B.x1, B.z0, B.z1, H, [gaine, tremie])
	LB.coque(K, B, H, "laque_rouge", OUV)
	# La fosse ovale : un tapis cerclé d'or, une couronne laquée au plafond.
	_ellipse(K, "moquette_b", CX, CZ, RX, RZ, 0.006)
	K.tore("or", 1.0, 0.012, K.xf(CX, 0.012, CZ, 0, 0, 0, RX, 2.0, RZ), 72)
	K.tore("laque_noire", 1.0, 0.05, K.xf(CX, 4.5, CZ, 0, 0, 0, RX - 0.3, 5.0, RZ - 0.3), 72)
	K.tore("gorge", 1.0, 0.012, K.xf(CX, 4.36, CZ, 0, 0, 0, RX - 0.62, 3.0, RZ - 0.62), 72)
	K.tore("or", 1.0, 0.012, K.xf(CX, 4.76, CZ, 0, 0, 0, RX - 0.02, 3.0, RZ - 0.02), 72)
	for i in 12:
		var a := i * TAU / 12.0 + 0.26
		K.cyl("or", 0.012, 0.012, 0.75, CX + cos(a) * (RX - 0.3), 5.02, CZ + sin(a) * (RZ - 0.3), 5)
	# Registres : mur est à claustras rétroéclairés entre pilastres, mur sud, bout du mur nord.
	L.registres(K, 35.8, -11.8, 35.8, 11.8, {"n": [-1.0, 0.0], "base": "laque_noire", "skip": [[13.1, 14.5]], "pil": [2.3, 7.05, 11.8, 16.55, 21.3], "pil_mat": "laque_noire"})
	for p in [[-7.12, 3.9], [-2.38, 3.9], [7.12, 3.9]]:
		K.box("gorge", 0.02, 2.3, p[1], 35.74, 2.45, p[0])
		K.box("treillis", 0.02, 2.3, p[1], 35.7, 2.45, p[0])
		for y in [3.63, 1.27]:
			K.box("or", 0.08, 0.05, p[1] + 0.1, 35.72, y, p[0])
	L.registres(K, 21, 11.8, 35.8, 11.8, {"n": [0.0, -1.0], "base": "laque_noire", "skip": [[3.0, 11.0]], "pil": [1.5, 12.9], "pil_mat": "laque_noire"})
	L.registres(K, 33.3, -11.8, 35.8, -11.8, {"n": [0.0, 1.0], "base": "laque_noire", "pil": [1.25], "pil_mat": "laque_noire"})
	K.box("laque_rouge", 8.6, 0.62, 0.2, 27.5, H + 0.3, -11.9)
	# L'encadrement de la porte du personnel (mur est) ; la porte elle-même est posée par minuit.gd.
	K.box("or", 0.04, 2.4, 0.06, 35.84, 1.2, 1.24)
	K.box("or", 0.04, 2.4, 0.06, 35.84, 1.2, 2.76)
	K.box("or", 0.04, 0.06, 1.58, 35.84, 2.4, 2.0)
	LB.enseigne(K, "RÉSERVÉ AU PERSONNEL", 35.8, 2.6, 2.0, -PI / 2.0, 0.9, 0.16, "plaque")
	# La baie à deux colonnes vers la caisse, la baie du foyer.
	L.baie(K, {"axe": "z", "at": 12.0, "c": 28.0, "w": 8.0, "h": 3.6})
	for x in [26.67, 29.33]:
		L.colonne(K, x, 12, 0.44, 3.6)
	LB.enseigne(K, "CAISSE", 28, 4.5, 11.74, PI, 3.0, 0.75, "neon", "ambre")
	L.baie(K, {"axe": "z", "at": -12.0, "c": 20.0, "w": 3.6, "h": 3.6})
	LB.enseigne(K, "Théâtre · Paris sportifs", 20, 4.35, -11.74, 0, 2.0, 0.4, "plaque")

	# --- l'ascenseur panoramique ASC-B ---
	L.gaine_b(K, H)
	K.box("laque_noire", 3.0, 0.6, 0.2, 19.5, H + 0.3, 9.1)

	# --- les tables : cinq blackjack, deux roulettes, la roue de la fortune ---
	var bj := []
	var regards := []
	var tables := [[26.4, -4.35, -1.0], [26.4, -0.45, -1.0], [26.4, 3.45, -1.0], [30.6, -0.45, 1.0], [30.6, 3.45, 1.0]]
	for i in tables.size():
		var t: Array = tables[i]
		bj.append(L.blackjack(K, t[0], t[1], t[2] * PI / 2.0))
		L.plaque(K, "BJ %d · Mise min. %d" % [i + 1, 25 if i == 4 else 10], t[0] + t[2] * 2.75, t[1] - 1.55, t[2] * PI / 2.0)
		LB.suspension(K, t[0] + t[2] * 0.3, t[1], H, 2.3, 0.5)
		for dz in [-0.9, 0.9]:
			regards.append(_regard(t[0] + t[2] * 3.15, t[1] + dz, t[0], t[1]))
	K.places["pit_bj"] = bj
	var roulettes := []
	roulettes.append(L.roulette(K, 30.6, -4.5, PI / 2.0, 1.0))
	L.plaque(K, "Roulette 3 · Mise min. 5", 33.35, -6.2, PI / 2.0)
	roulettes.append(L.roulette(K, 26.4, 7.5, -PI / 2.0, 1.0))
	L.plaque(K, "Roulette 4 · Mise min. 5", 23.65, 9.2, -PI / 2.0)
	for r in [[30.6, -4.5, 1.0], [26.4, 7.5, -1.0]]:
		LB.suspension(K, r[0], r[1], H, 2.3, 0.5)
		for dz in [-0.9, 0.9]:
			regards.append(_regard(r[0] + r[2] * 3.0, r[1] + dz, r[0], r[1]))
	K.places["pit_roulettes"] = roulettes
	K.places["pit_roue"] = _roue_fortune(K, L, LB)
	for dz in [-0.9, 0.9]:
		regards.append(_regard(33.6, 7.5 + dz, 30.2, 7.5))
	K.places["pit_regards"] = regards

	# Le pupitre du chef de table, au centre de la fosse.
	K.box("laque_noire", 0.7, 1.08, 1.3, 28.5, 0.54, 1.5)
	K.box("or", 0.78, 0.04, 1.38, 28.5, 1.1, 1.5)
	K.box("or", 0.74, 0.06, 1.34, 28.5, 0.03, 1.5)
	for x in [28.14, 28.86]:
		K.box("laque_rouge", 0.02, 0.6, 0.9, x, 0.6, 1.5)
	K.cyl("or", 0.015, 0.015, 0.3, 28.5, 1.27, 1.5, 6)
	K.box("jeton_vert", 0.16, 0.08, 0.4, 28.5, 1.45, 1.5)
	K.box("ampoule", 0.12, 0.01, 0.34, 28.5, 1.405, 1.5)
	K.box("ecran", 0.3, 0.22, 0.03, 28.5, 1.25, 1.02)
	for z in [0.84, 2.16]:
		K.texte("CHEF DE TABLE", 0.5, 0.08, 28.5, 0.75, z + (0.005 if z > 1.5 else -0.005), 0.0 if z > 1.5 else PI)
	K.obstacle(28.13, 28.87, 0.84, 2.16, 0.0, 1.2)
	K.places["pit_pupitre"] = [[Vector3(27.72, 0, 1.5), -PI / 2.0], [Vector3(29.28, 0, 1.5), PI / 2.0]]
	# Les cordons qui ferment les deux bouts de la fosse.
	L.potelets(K, [[26.3, -6.5], [28.5, -6.5], [30.7, -6.5]])
	L.potelets(K, [[26.3, 9.55], [28.5, 9.55], [30.7, 9.55]])
	# Les enseignes néon suspendues au-dessus de la fosse, une par direction d'arrivée.
	_pendue(K, LB, "BLACKJACK", "rouge", 23.6, 3.85, -0.45, -PI / 2.0, 4.4)
	_pendue(K, LB, "ROULETTE", "rouge", 28.5, 3.85, -7.3, PI, 3.6)
	_pendue(K, LB, "ROUE DE LA FORTUNE", "ambre", 28.5, 3.85, 10.5, 0.0, 4.6)

	# --- les escalators (deux voies) : tapis qui défilent, limons, dessous fermé ---
	var kk: float = E.rise / (E.x1 - E.x0)
	var sens := [1.0, -1.0]
	for i in 2:
		var z: float = E.voies[i]
		K.beam("laque_noire", Vector3(E.x0, 0.0, z), Vector3(E.x1, E.rise, z), E.w, 0.04)
		L.marches(K, E.x0, 0.0, E.x1, E.rise, z, E.w * 0.96, sens[i])
		L.rampe_x(K, E.x0, 0.0, E.x1, E.rise, z, E.w)
		for q in [[E.x0 - 0.2, 0.008], [E.x1 + 0.2, E.rise + 0.008]]:
			K.box("or", 0.5, 0.012, E.w, q[0], q[1], z)
	for lm in E.limons:
		var z: float = lm[0]
		var w: float = lm[1]
		K.beam("laque_noire", Vector3(E.x0, 0.06, z), Vector3(E.x1, E.rise + 0.06, z), w, 0.34)
		K.beam("verre", Vector3(E.x0, 0.62, z), Vector3(E.x1, E.rise + 0.62, z), 0.025, 0.78)
		K.beam("laque_rouge", Vector3(E.x0, 1.06, z), Vector3(E.x1, E.rise + 1.06, z), 0.09, 0.07)
		L.pente_solide(K, E.x0, 0.0, E.x1, E.rise, z, maxf(w, 0.12), 1.15)
		for d in [[E.x0 - 0.75, E.x0, 0.0], [E.x1, E.x1 + 0.75, E.rise]]:
			var xa: float = d[0]
			var xb: float = d[1]
			var y: float = d[2]
			K.box("laque_noire", xb - xa, 0.26, w, (xa + xb) / 2.0, y + 0.13, z)
			K.box("verre", xb - xa, 0.74, 0.025, (xa + xb) / 2.0, y + 0.63, z)
			K.box("laque_rouge", xb - xa + 0.06, 0.07, 0.09, (xa + xb) / 2.0, y + 1.035, z)
			K.cyl("or", 0.05, 0.05, 1.04, xb if y > 0.0 else xa, y + 0.52, z, 8)
			if y == 0.0 and z != -11.725:
				K.segment(xa, z, xb, z, 0.08, 0.0, 1.1)
	K.beam("gorge", Vector3(E.x0 + 0.2, -0.06, -8.99), Vector3(E.x1 - 0.7, E.rise * (E.x1 - 0.7 - E.x0 - 0.2) / (E.x1 - E.x0) - 0.06, -8.99), 0.02, 0.05)
	# Le dessous fermé : jouée laquée, claustras rétroéclairés sous la partie haute.
	var x0: float = E.x0
	var x1: float = E.x1
	L.voile(K, "laque_noire", "z", -9.1, x0, 33.3, func(_a: float) -> float: return 0.0,
		func(a: float) -> float: return minf(H, maxf(0.0, (minf(a, x1) - x0) * kk - 0.14)), {"n": 40})
	K.box("laque_noire", 0.2, H, 3.0, 33.2, H / 2.0, -10.5)
	for p in [[28.6, 1.7, 2.3], [30.6, 1.7, 3.6], [32.45, 1.4, 3.9]]:
		K.box("gorge", p[1], p[2], 0.02, p[0], 0.45 + p[2] / 2.0, -8.985)
		K.box("treillis", p[1], p[2], 0.02, p[0], 0.45 + p[2] / 2.0, -8.94)
		for y in [0.42, 0.48 + p[2]]:
			K.box("or", p[1] + 0.1, 0.05, 0.08, p[0], y, -8.96)
	K.obstacle(E.x0, 33.3, -9.2, -8.9, 0.0, H)
	K.obstacle(E.x1, 33.3, -12, -8.9, 0.0, H)
	# Le mur nord derrière les escalators : panneaux de satin noir à filets d'or, bandeau parallèle à la pente.
	for i in 6:
		var x := 22.85 + i * 1.92
		K.box("satin", 1.7, H + 0.6, 0.04, x, (H + 0.6) / 2.0, -11.78)
		for s in [-1.0, 1.0]:
			K.box("or", 0.03, H + 0.6, 0.05, x + s * 0.89, (H + 0.6) / 2.0, -11.775)
	K.beam("gorge", Vector3(E.x0 + 0.3, 2.0, -11.74), Vector3(E.x1 - 0.2, 2.0 + (E.x1 - E.x0 - 0.5) * kk, -11.74), 0.03, 0.06)
	# La rive de la dalle autour de la trémie (y 5,4 → 6).
	K.box("laque_noire", 0.24, 0.62, 3.0, E.x0 - 0.1, H + 0.3, -10.5)
	K.box("laque_noire", E.x1 - E.x0 + 0.2, 0.62, 0.22, (E.x0 + E.x1) / 2.0, H + 0.3, -8.92)
	K.box("gorge", E.x1 - E.x0, 0.04, 0.04, (E.x0 + E.x1) / 2.0, H - 0.03, -8.8)
	K.box("laque_noire", 0.06, 1.3, 2.9, E.x0 - 0.2, 4.5, -10.45)
	LB.enseigne(K, "MEZZANINE", E.x0 - 0.235, 4.72, -10.45, -PI / 2.0, 2.5, 0.55, "neon", "ambre")
	LB.enseigne(K, "Restaurant · Boutiques  ↗", E.x0 - 0.235, 4.2, -10.45, -PI / 2.0, 1.9, 0.38, "plaque")

	# --- lumière : lanternes rouges sur les allées, trois lumières ---
	for z in [-5.5, -1.5, 2.5, 6.5]:
		K.lanterne(21.6, 3.2, z, 1.0, 1.5)
	for z in [-7.2, -2.6, 6.6, 10.6]:
		K.lanterne(34.2, 3.2, z, 1.0, 1.5)
	K.lumiere(28.5, 3.6, 1.5, K.pal.lumiere, 1.6, 15.0)
	K.lumiere(22.4, 3.3, 1.0, K.pal.lumiere, 1.1, 13.0)
	K.lumiere(28.5, 3.4, -6.9, K.pal.lumiere, 1.1, 13.0)
	LB.palmier(K, 35.15, -11.15, {"seed": 7})
	LB.palmier(K, 35.1, 11.1, {"seed": 19})
	LB.topiaire(K, 21.6, 8.45, 2.0)
	K.places["pit_duos"] = _duos([[20.4, -4.6, 0.4], [20.6, 4.8, 2.4], [33.9, -0.6, 1.6], [22.9, 10.6, 1.1]])
	K.places["pit_vigile"] = [Vector3(35.0, 0, 3.5), PI / 2.0]
	K.zone_fin()


## Un tapis elliptique à plat (la fosse ovale).
static func _ellipse(K, nom_mat: String, cx: float, cz: float, rx: float, rz: float, y: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 56
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var p0 := Vector3(cx + rx * sin(a0), y, cz - rz * cos(a0))
		var p1 := Vector3(cx + rx * sin(a1), y, cz - rz * cos(a1))
		var c := Vector3(cx, y, cz)
		K._tri(st, c, p0, p1, Vector3.UP, Vector2(c.x, c.z) / 2.0, Vector2(p0.x, p0.z) / 2.0, Vector2(p1.x, p1.z) / 2.0)
	K.put(nom_mat, st.commit())


## Une place debout qui regarde une table : [Vector3, f] tourné vers (lx, lz).
static func _regard(x: float, z: float, lx: float, lz: float) -> Array:
	return [Vector3(x, 0, z), atan2(-(lx - x), -(lz - z))]


## Une enseigne néon pendue au plafond par deux tiges, lisible des deux côtés.
static func _pendue(K, LB, t: String, couleur: String, x: float, y: float, z: float, ry: float, w: float) -> void:
	var ux := cos(ry)
	var uz := -sin(ry)
	K.box("laque_noire", w + 0.3, 0.95, 0.08, x, y, z, ry)
	for s in [-1.0, 1.0]:
		K.box("or", w + 0.4, 0.05, 0.12, x, y + s * 0.5, z, ry)
		K.cyl("or", 0.012, 0.012, H - y - 0.5, x + ux * s * w * 0.4, (H + y + 0.5) / 2.0, z + uz * s * w * 0.4, 5)
	var nx := sin(ry) * 0.05
	var nz := cos(ry) * 0.05
	LB.enseigne(K, t, x + nx, y, z + nz, ry, w * 0.95, 0.62, "neon", couleur)
	LB.enseigne(K, t, x - nx, y, z - nz, ry + PI, w * 0.95, 0.62, "neon", couleur)


## La roue de la fortune, pièce maîtresse : un disque vertical de 2 m à 54 secteurs, face à l'est, son
## comptoir de mises. Rend {sieges, croupier}.
static func _roue_fortune(K, L, LB) -> Dictionary:
	var g := [30.6, 7.5, PI / 2.0]
	LB.rbox(K, g, "laque_noire", 0.34, 0.95, 0.34, 0, 0.475, -0.56)
	LB.rbox(K, g, "or", 0.4, 0.05, 0.4, 0, 0.95, -0.56)
	LB.rbox(K, g, "laque_noire", 1.5, 0.12, 0.7, 0, 0.06, -0.56)
	LB.rbox(K, g, "or", 1.56, 0.03, 0.76, 0, 0.13, -0.56)
	var c: Vector2 = LB.loc(g, 0, -0.5)
	var dos: Vector2 = LB.loc(g, 0, -0.4)
	# Le disque tourne : un nœud à part (L.roue, dressé), ses secteurs de six couleurs.
	L.roue(K, c.x, 1.98, c.y, PI / 2.0, 1.0, 0.08, ["creme", "or", "creme", "laque_rouge", "creme", "or", "feutre", "bleu_nuit", "laque_noire"], 54, 0.35, false)
	K.tore("or", 1.03, 0.045, K.xf(c.x, 1.98, c.y, 0, 0, PI / 2.0), 54)
	K.cyl("laque_noire", 1.16, 1.16, 0.06, dos.x, 1.98, dos.y, 36, 0, PI / 2.0)
	for i in 18:
		var a := i * TAU / 18.0
		for lz in [-0.45, -0.62]:
			var p: Vector2 = LB.loc(g, cos(a) * 1.13, lz)
			K.sph("ampoule", 0.045, p.x, 1.98 + sin(a) * 1.13, p.y)
	var fl: Vector2 = LB.loc(g, 0, -0.44)
	K.box("laque_rouge", 0.05, 0.22, 0.07, fl.x, 3.02, fl.y)
	LB.rbox(K, g, "laque_noire", 1.9, 0.92, 0.5, 0, 0.46, 0.32)
	LB.rbox(K, g, "marbre_noir", 2.0, 0.05, 0.6, 0, 0.945, 0.32)
	LB.rbox(K, g, "gorge", 1.9, 0.03, 0.02, 0, 0.12, 0.575)
	LB.rbox(K, g, "or", 1.9, 0.03, 0.03, 0, 0.86, 0.578)
	LB.rbox(K, g, "feutre", 1.9, 0.01, 0.5, 0, 0.975, 0.32)
	var vals := ["1", "2", "5", "10", "20", "40"]
	for i in vals.size():
		var p: Vector2 = LB.loc(g, -0.79 + i * 0.316, 0.32)
		var l: Label3D = K.texte(vals[i], 0.2, 0.12, p.x, 0.982, p.y, PI / 2.0)
		l.rotation = Vector3(-PI / 2.0, PI / 2.0, 0)
	LB.rsolide(K, g, 2.1, 1.0, 1.57, 0, -0.165)
	LB.suspension(K, 31.0, 7.5, H, 2.3, 0.5)
	L.plaque(K, "Roue de la fortune · Mise min. 1", 33.3, 9.1, PI / 2.0)
	var sieges := []
	for i in 4:
		var p: Vector2 = LB.loc(g, -0.9 + i * 0.6, 1.02)
		sieges.append([Vector3(p.x, 0, p.y), PI / 2.0])
	var cr: Vector2 = LB.loc(g, 1.45, -0.1)
	return {"sieges": sieges, "croupier": [Vector3(cr.x, 0, cr.y), -PI / 2.0]}


static func _duos(liste: Array) -> Array:
	var out := []
	for d in liste:
		var dx: float = sin(d[2]) * 0.55
		var dz: float = cos(d[2]) * 0.55
		out.append([Vector3(d[0] - dx, 0, d[1] - dz), d[2] + PI])
		out.append([Vector3(d[0] + dx, 0, d[1] + dz), d[2]])
	return out
