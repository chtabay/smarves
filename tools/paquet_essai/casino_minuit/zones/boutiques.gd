extends RefCounted
## Lot C, zone M-BOUTIQUES (js/zones/c-boutiques.js) : la galerie marchande à ciel peint [18, 40] × [-12, 12],
## à la mezzanine (y = 6). Une place à fontaine sous une voûte en berceau peinte en ciel de crépuscule ; quatre
## façades (la joaillerie et la couture, ouvertes avec leur comptoir ; les parfums et le cabinet des curiosités,
## clos) et deux vitrines murales. Les deux boutiques ouvertes reçoivent au-delà du seuil du lieu : un cordon,
## posé par minuit.gd, barre leur porte jusque-là. L'arrivée des escalators (trémie bordée d'un garde-corps),
## l'arrêt haut de l'ascenseur ASC-B ; la gaine de service [36, 40] × [-12, -4] reste close (lot D).
## Liaisons : la galerie (ouest, colonnes du lot A), la baie du restaurant (nord).

const LOT_B := "res://communes/casino_minuit/zones/lot_b.gd"
const LOT_C := "res://communes/casino_minuit/zones/lot_c.gd"
const Y := 6.0
const H := 5.0
const YS := 3.3
const RISE := 1.7
const HALF := 11.8
const FX := 27.0
const FZ := -1.5
const HF := 3.55
const DW := 1.7


static func vy(z: float) -> float:
	return YS + RISE * sqrt(maxf(0.0, 1.0 - (z / HALF) * (z / HALF)))


static func construire(K) -> void:
	var LB = load(LOT_B)
	var L = load(LOT_C)
	var E: Dictionary = L.ESC
	K.zone_debut("M-BOUTIQUES")
	K.zone.position.y = Y
	var trous := [{"x0": E.x0, "x1": E.x1, "z0": -12.0, "z1": -9.0}, {"x0": 18.0, "x1": 21.0, "z0": 9.0, "z1": 12.0}, {"x0": 36.0, "x1": 40.0, "z0": -12.0, "z1": -4.0}]
	# Les boutiques closes : leur sol se voit, on n'y marche pas.
	var closes := [{"x0": 28.3, "x1": 40.0, "z0": 6.2, "z1": 12.0}, {"x0": 35.2, "x1": 40.0, "z0": 1.15, "z1": 6.2}]

	# --- enveloppe : sol de marbre, place en mosaïque, voûte en berceau « ciel » ---
	L.sol(K, "marbre_creme", 18, 40, -12, 12, 0.0, trous + closes)
	K.plan("marbre_creme", 28.3, 40, 6.2, 12, 0)
	K.plan("marbre_creme", 35.2, 40, 1.15, 6.2, 0)
	K.disque("mosaique", FX, FZ, 4.4, 0.006, 40)
	K.tore("or", 4.4, 0.03, K.xf(FX, 0.01, FZ), 56)
	for r in [[18.0, 35.0, -9.0, -8.75], [18.0, 35.0, 5.75, 6.0]]:
		K.plan("damier", r[0], r[1], r[2], r[3], 0.005)
	LB.voute(K, "ciel_nuit", 18.2, 39.8, -HALF, HALF, YS, RISE, 28)
	var ouest := func(a: float) -> float: return vy(a)
	var haut := func(_a: float) -> float: return H
	# Les murs (pas de coque : les gaines les découpent).
	K.mur(18.1, -12, 18.1, -6, H, 1, 0, [], "pierre", 0.0, false)
	K.mur(18.1, 6, 18.1, 9, H, 1, 0, [], "pierre", 0.0, false)
	K.mur(18, -11.9, 36, -11.9, H, 0, 1, [{"at": 2.0, "w": 3.0, "h": 3.2}], "pierre", 0.0, false)
	K.mur(18, 11.9, 40, 11.9, H, 0, -1, [], "pierre", 0.0, false)
	K.mur(39.9, -4, 39.9, 12, H, -1, 0, [], "pierre", 0.0, false)
	K.mur(35.9, -12, 35.9, -3.8, H, -1, 0, [], "pierre", 0.0, false)
	K.mur(36, -3.9, 40, -3.9, H, 0, 1, [], "pierre", 0.0, false)
	L.voile(K, "pierre", "x", 18.1, -6, 6, ouest, haut, {"n": 12})
	# La porte du personnel de la gaine de service, close.
	K.box("laque_noire", 1.2, 2.2, 0.04, 38, 1.1, -3.78)
	LB.enseigne(K, "RÉSERVÉ AU PERSONNEL", 38, 2.45, -3.76, 0, 0.9, 0.16, "plaque")
	# La corniche de naissance de la voûte, les soubassements.
	L.registres(K, 18.2, -11.8, 35.8, -11.8, {"n": [0.0, 1.0], "h": YS + 0.06, "base": "pierre_sombre", "bh": 0.7, "corniche_mat": "pierre", "gorge": false, "applique": false, "skip": [[0.3, 3.3]]})
	L.registres(K, 21, 11.8, 39.8, 11.8, {"n": [0.0, -1.0], "h": YS + 0.06, "base": "pierre_sombre", "bh": 0.7, "corniche_mat": "pierre", "gorge": false, "applique": false})
	# La baie du restaurant.
	L.baie(K, {"axe": "z", "at": -12.0, "c": 20.0, "w": 3.0, "h": 3.2, "mat": "marbre_noir"})
	K.texte("LE LUCULLUS", 2.6, 0.45, 20, 3.95, -11.74, 0, "neon", K.pal.or_clair)
	K.texte("RESTAURANT", 1.5, 0.18, 20, 4.42, -11.74, 0)

	# --- les gaines : l'ascenseur ASC-B (arrêt haut), la trémie des escalators ---
	L.gaine_b(K, H, 0.0, "Mezzanine")
	K.garde_corps(E.x0, -9, E.x1, -9)
	K.garde_corps(E.x0, -11.8, E.x0, -9)
	for z in [-10.475, -9.15]:
		K.segment(E.x1, z, E.x1 + 0.75, z, 0.08, 0.0, 1.1)
	LB.enseigne(K, "Casino · Tables  ↓", 33.5, 2.6, -11.74, 0, 1.5, 0.36, "plaque")

	# --- les façades ---
	var vendeurs := []
	_facade(K, L, LB, {"id": "joaillerie", "ax": "z", "at": 6.1, "a0": 21.3, "a1": 28.2, "out": -1.0, "nom": "MAISON AURÉLIA · JOAILLIER", "open": true, "fronton": true, "kind": "bijoux", "fond": "velours"})
	_facade(K, L, LB, {"id": "parfums", "ax": "z", "at": 6.1, "a0": 28.4, "a1": 35.0, "out": -1.0, "nom": "PARFUMS DE MINUIT", "kind": "parfums", "store": "bordeaux", "fond": "creme"})
	_facade(K, L, LB, {"id": "couture", "ax": "x", "at": 35.1, "a0": -3.7, "a1": 1.05, "out": -1.0, "nom": "VIA ROMA · COUTURE", "open": true, "kind": "couture", "store": "vert_jardin", "fond": "creme"})
	_facade(K, L, LB, {"id": "cadeaux", "ax": "x", "at": 35.1, "a0": 1.25, "a1": 5.9, "out": -1.0, "nom": "LE CABINET DES CURIOSITÉS", "fronton": true, "kind": "cadeaux", "fond": "velours"})
	# Les cloisons et les plafonds des boutiques, le bloc d'angle fermé.
	for w in [[21.3, 6.2, 21.3, 11.8, 1.0, 0.0], [28.3, 6.2, 28.3, 11.8, -1.0, 0.0], [35.1, 6.2, 35.1, 11.8, 1.0, 0.0], [35.2, 1.15, 39.8, 1.15, 0.0, -1.0], [35.2, 6.0, 39.8, 6.0, 0.0, 1.0]]:
		K.mur(w[0], w[1], w[2], w[3], 3.5, w[4], w[5], [], "pierre", 0.0, false)
	K.plan("pierre", 21.3, 35.1, 6.2, 11.8, YS, false)
	K.plan("pierre", 35.2, 39.8, -3.8, 6.0, YS, false)
	K.plan("pierre_sombre", 21.2, 35.2, 6.0, 11.8, 3.56)
	K.plan("pierre_sombre", 35.0, 39.8, -3.8, 11.8, 3.56)
	K.box("pierre", 0.3, 3.55, 0.3, 35.1, 1.775, 6.05)
	K.solide(0.3, 3.55, 0.3, 35.1, 1.775, 6.05)

	# La joaillerie (ouverte) : comptoir-vitrine, présentoirs sous cloche, miroir.
	K.plan("moquette_b", 22, 27.6, 6.9, 11.2, 0.006)
	K.box("laque_noire", 3.4, 0.9, 0.55, 24.75, 0.45, 10.4)
	K.box("gorge", 3.1, 0.5, 0.02, 24.75, 0.5, 10.118)
	K.box("or", 3.44, 0.03, 0.03, 24.75, 0.86, 10.115)
	K.box("vitrine", 3.4, 0.22, 0.55, 24.75, 1.01, 10.4)
	K.box("or", 3.46, 0.03, 0.6, 24.75, 1.13, 10.4)
	for i in 5:
		K.tore("or", 0.07, 0.012, K.xf(23.45 + i * 0.65, 0.93, 10.4), 10)
		K.sph("statue_or", 0.03, 23.45 + i * 0.65, 0.95, 10.45)
	K.obstacle(23.03, 26.47, 10.1, 10.7, 0.0, 1.2)
	for p in [[22.6, 8.2], [26.9, 8.2]]:
		K.cyl("laque_noire", 0.24, 0.28, 1.0, p[0], 0.5, p[1], 10)
		K.cyl("vitrine", 0.22, 0.22, 0.4, p[0], 1.2, p[1], 10)
		K.cyl("capiton_rouge", 0.1, 0.13, 0.16, p[0], 1.08, p[1], 8)
		K.sph("statue_or", 0.07, p[0], 1.22, p[1])
		K.rond(p[0], p[1], 0.3, 0.0, 1.4)
	K.box("miroir", 4.4, 1.5, 0.03, 24.75, 2.0, 11.76)
	for y in [2.78, 1.22]:
		K.box("or", 4.5, 0.05, 0.06, 24.75, y, 11.75)
	K.interaction("boutiques", "Le comptoir du joaillier", 24.75, 1.2, 9.8, Vector3(3.4, 2.2, 0.8))
	vendeurs.append([Vector3(24.75, Y, 11.15), 0.0])
	K.lumiere(24.75, 2.8, 9, Color("#FFE8C8"), 1.6, 10.0)
	# La couture (ouverte) : comptoir, portants, mannequins.
	K.plan("moquette_b", 35.7, 39.4, -3.3, 0.7, 0.006)
	K.box("laque_noire", 0.46, 0.95, 2.2, 38.12, 0.475, -1.4)
	K.box("marbre_noir", 0.54, 0.05, 2.3, 38.12, 0.975, -1.4)
	K.box("gorge", 0.02, 0.03, 2.0, 37.88, 0.12, -1.4)
	K.obstacle(37.88, 38.36, -2.55, -0.25, 0.0, 1.2)
	for p in [[-3.35, 5], [0.7, 6]]:
		var x0 := 35.75
		var x1: float = x0 + p[1] * 0.24 + 0.2
		K.cyl("or", 0.015, 0.015, x1 - x0, (x0 + x1) / 2.0, 1.75, p[0], 5, 0, PI / 2.0)
		for x in [x0, x1]:
			K.cyl("or", 0.015, 0.015, 1.75, x, 0.875, p[0], 5)
		for i in p[1]:
			K.box(["laque_rouge", "tissu_bleu", "or", "laque_noire", "creme"][i % 5], 0.05, 0.9, 0.5, x0 + 0.2 + i * 0.24, 1.25, p[0])
	for m in [[36.6, -1.4], [36.9, -0.3]]:
		_mannequin(K, m[0], m[1], "tissu_bleu" if m[1] < -1.0 else "laque_rouge")
	K.interaction("boutiques", "Le comptoir du couturier", 37.6, 1.2, -1.4, Vector3(0.8, 2.2, 2.2))
	vendeurs.append([Vector3(39.05, Y, -1.4), PI / 2.0])
	K.lumiere(37.3, 2.8, -1.4, Color("#FFE8C8"), 1.4, 9.0)
	K.places["boutiques_vendeurs"] = vendeurs
	# Deux vitrines murales : l'horloger (mur de la gaine de service) et le fleuriste (mur ouest).
	_murale(K, 35.8, -7.6, 5.4, -1.0, "CHRONOS · HORLOGER", "horloges")
	_murale(K, 18.2, 7.5, 2.6, 1.0, "FLORA", "fleurs")

	# --- la place : fontaine de la Roue, quatre bancs, réverbères, arbres ---
	K.cyl("marbre_creme", 1.6, 1.65, 0.5, FX, 0.25, FZ, 32)
	K.tore("or", 1.6, 0.04, K.xf(FX, 0.5, FZ), 32)
	K.disque("eau", FX, FZ, 1.45, 0.46, 32)
	K.rond(FX, FZ, 1.7, 0.0, 1.0)
	K.statue(FX, FZ, 1.25, 1.35, PI / 2.0, "statue_or", "roue")
	var jets := []
	for i in 8:
		var a := i * TAU / 8.0
		jets.append({"x": FX + sin(a) * 1.15, "z": FZ + cos(a) * 1.15, "h": 0.9, "r": 0.03})
	K.jets(jets, 0.46, func(i: int, t: float) -> float: return 0.6 + 0.4 * sin(t * 1.3 + i * 0.8))
	var bancs := []
	for a in [PI / 4.0, 3.0 * PI / 4.0, 5.0 * PI / 4.0, 7.0 * PI / 4.0]:
		bancs.append_array(_monte_tout(L.banc(K, FX + sin(a) * 3.5, FZ + cos(a) * 3.5, a, 2, {"dossier": false})))
	K.places["boutiques_bancs"] = bancs
	for p in [[22.3, -6.2], [31.7, -6.2], [22.3, 3.4], [31.7, 3.4]]:
		K.cyl("laque_noire", 0.05, 0.08, 2.9, p[0], 1.45, p[1], 8)
		K.cyl("laque_noire", 0.16, 0.2, 0.3, p[0], 0.15, p[1], 8)
		K.box("laque_noire", 0.9, 0.04, 0.04, p[0], 2.75, p[1])
		for d in [-0.45, 0.45]:
			K.sph("ampoule", 0.14, p[0] + d, 2.62, p[1])
			K.cyl("or", 0.05, 0.1, 0.08, p[0] + d, 2.78, p[1], 6)
		K.rond(p[0], p[1], 0.14)
	LB.palmier(K, 19.2, -8.1, {"seed": 1, "pot": "marbre_creme"})
	LB.topiaire(K, 34.55, 5.55, 2.2, "marbre_creme")
	LB.palmier(K, 19.4, 5.3, {"seed": 2, "pot": "marbre_creme"})
	LB.topiaire(K, 33.9, -4.6, 2.2, "marbre_creme")
	LB.palmier(K, 21.7, 8.6, {"seed": 4, "pot": "marbre_creme"})
	K.lumiere(FX, 3.6, FZ, Color("#FFF2DC"), 1.6, 18.0)
	K.lumiere(22.3, 2.6, -6.2, Color("#FFE2B4"), 0.8, 8.0)
	K.lumiere(31.7, 2.6, 3.4, Color("#FFE2B4"), 0.8, 8.0)
	# Le tour de la place, que suivent les flâneurs ; les vitrines où ils s'arrêtent ; les bavards.
	var tour := []
	for i in 12:
		var a := i * TAU / 12.0
		tour.append(Vector3(FX + sin(a) * 5.4, Y, FZ + cos(a) * 5.0))
	K.places["boutiques_tour"] = tour
	K.places["boutiques_vitrines"] = [[Vector3(23.0, Y, 4.85), PI], [Vector3(31.7, Y, 4.85), PI], [Vector3(33.85, Y, 3.6), -PI / 2.0], [Vector3(34.1, Y, -9.0), -PI / 2.0], [Vector3(19.9, Y, 7.5), PI / 2.0]]
	var duos := []
	for d in [[22.6, -1.2, 0.8], [31.4, 1.1, 2.2], [20.2, -7.2, 1.5], [33.4, -6.6, 0.3]]:
		var dx: float = sin(d[2]) * 0.55
		var dz: float = cos(d[2]) * 0.55
		duos.append([Vector3(d[0] - dx, Y, d[1] - dz), d[2] + PI])
		duos.append([Vector3(d[0] + dx, Y, d[1] + dz), d[2]])
	K.places["boutiques_duos"] = duos
	K.zone_fin()


static func _monte_tout(liste: Array) -> Array:
	var out := []
	for p in liste:
		out.append([p[0] + Vector3(0, Y, 0), p[1]])
	return out


## Une façade de boutique (L.facade) : trumeaux de pierre, deux vitrines garnies, bandeau d'enseigne,
## corniche, fronton ou urnes, porte ouverte (passage libre) ou close (vantaux laqués). o : id, ax (« z » :
## façade le long de x sur le plan z = at ; « x »), at, a0, a1, out (±1 : côté de la place), nom, open,
## fronton, store, fond, kind.
static func _facade(K, L, LB, o: Dictionary) -> void:
	var z: bool = o.ax == "z"
	var at: float = o.at
	var out: float = o.out
	var a0: float = o.a0
	var a1: float = o.a1
	var lg := a1 - a0
	var mid := (a0 + a1) / 2.0
	var ry := (0.0 if out > 0.0 else PI) if z else out * PI / 2.0
	var bx := func(m: String, la: float, h: float, ld: float, a: float, y: float, d: float):
		if z:
			K.box(m, la, h, ld, a, y, at + out * d)
		else:
			K.box(m, ld, h, la, at + out * d, y, a)
	var pt := func(a: float, d: float) -> Vector2: return Vector2(a, at + out * d) if z else Vector2(at + out * d, a)
	var plein := func(b0: float, b1: float):
		var p: Vector2 = pt.call(b0, -0.14)
		var q: Vector2 = pt.call(b1, 0.14)
		K.obstacle(minf(p.x, q.x), maxf(p.x, q.x), minf(p.y, q.y), maxf(p.y, q.y), 0.0, HF)
	for a in [a0 + 0.25, a1 - 0.25]:
		bx.call("pierre", 0.5, HF, 0.3, a, HF / 2.0, 0.0)
		bx.call("marbre_creme", 0.36, 2.6, 0.08, a, 1.3, 0.17)
		for y in [2.62, 0.05]:
			bx.call("or", 0.44, 0.1, 0.12, a, y, 0.18)
	for a in [mid - DW / 2.0 - 0.15, mid + DW / 2.0 + 0.15]:
		bx.call("pierre", 0.3, 2.6, 0.26, a, 1.3, 0.0)
	var wv := (lg - 1.0 - DW - 0.6) / 2.0
	var vit := [a0 + 0.5 + wv / 2.0, a1 - 0.5 - wv / 2.0]
	for k in 2:
		var a: float = vit[k]
		bx.call("pierre_sombre", wv, 0.7, 0.26, a, 0.35, 0.0)
		bx.call("or", wv, 0.04, 0.3, a, 0.72, 0.0)
		bx.call("vitrine", wv, 1.86, 0.03, a, 1.67, 0.02)
		bx.call("or", wv, 0.04, 0.08, a, 2.58, 0.04)
		bx.call(o.get("fond", "velours"), wv, 1.9, 0.04, a, 1.67, -0.95)
		bx.call("gorge", wv - 0.2, 0.03, 0.03, a, 2.55, -0.9)
		bx.call("laque_noire", wv - 0.3, 0.2, 0.5, a, 0.82, -0.5)
		bx.call("laque_noire", wv - 0.9, 0.2, 0.3, a, 1.02, -0.6)
		for i in 3:
			var p: Vector2 = pt.call(a + (i - 1) * wv * 0.3, -0.5 - (0.1 if i == 1 else 0.0))
			var y := 1.12 if i == 1 else 0.92
			match o.kind:
				"bijoux":
					K.cyl("satin", 0.06, 0.13, 0.3, p.x, y + 0.15, p.y, 8)
					K.sph("statue_or", 0.035, p.x, y + 0.34, p.y)
					K.tore("or", 0.07, 0.012, K.xf(p.x, y + 0.24, p.y, PI / 2.6, ry), 10)
				"couture":
					_mannequin(K, p.x, p.y, ["laque_rouge", "tissu_bleu", "or"][(i + k) % 3], y)
				"parfums":
					K.box(["neon_ambre", "lotus", "ampoule"][(i + k) % 3], 0.14, 0.2 + i * 0.05, 0.08, p.x, y + 0.1 + i * 0.025, p.y, ry)
					K.cyl("or", 0.025, 0.025, 0.06, p.x, y + 0.24 + i * 0.05, p.y, 6)
				_:
					K.box(["laque_rouge", "or", "tissu_bleu"][(i + k) % 3], 0.3, 0.2, 0.22, p.x, y + 0.1, p.y, ry + 0.3)
					K.box("or", 0.32, 0.03, 0.05, p.x, y + 0.1, p.y, ry + 0.3)
		plein.call(a - wv / 2.0, a + wv / 2.0)
		if o.has("store"):
			var sp: Vector2 = pt.call(a, 0.5)
			K.box(o.store, wv + 0.1 if z else 0.95, 0.04, 0.95 if z else wv + 0.1, sp.x, 2.88, sp.y)
	bx.call("pierre", lg, 0.62, 0.3, mid, 2.91, 0.0)
	bx.call("or", lg + 0.1, 0.06, 0.42, mid, 3.25, 0.04)
	bx.call("pierre", lg + 0.16, 0.12, 0.5, mid, 3.33, 0.06)
	bx.call("pierre", lg, HF - 3.39, 0.3, mid, (HF + 3.39) / 2.0, 0.0)
	bx.call("ardoise", lg - 1.2, 0.36, 0.03, mid, 2.92, 0.16)
	var np: Vector2 = pt.call(mid, 0.18)
	K.texte(o.nom, minf(lg - 1.6, 4.2), 0.22, np.x, 2.92, np.y, ry)
	if o.get("fronton", false):
		var m2 := mid
		var lg2 := lg
		L.voile(K, "pierre", o.ax, at, mid - lg * 0.36, mid + lg * 0.36, func(_a: float) -> float: return HF,
			func(a: float) -> float: return HF + maxf(0.0, 0.75 * (1.0 - absf(a - m2) / (lg2 * 0.36))), {"n": 2, "t": 0.3, "dessus": true})
		var kp: Vector2 = pt.call(mid, 0.16)
		K.cyl("or", 0.16, 0.16, 0.03, kp.x, HF + 0.3, kp.y, 12, PI / 2.0 if z else 0.0, 0.0 if z else PI / 2.0)
	else:
		for a in [a0 + 0.25, mid, a1 - 0.25]:
			var p: Vector2 = pt.call(a, 0.0)
			K.cyl("marbre_creme", 0.14, 0.1, 0.4, p.x, HF + 0.2, p.y, 10)
			K.sph("marbre_creme", 0.12, p.x, HF + 0.45, p.y)
	plein.call(a0, a0 + 0.5)
	plein.call(a1 - 0.5, a1)
	plein.call(mid - DW / 2.0 - 0.3, mid - DW / 2.0)
	plein.call(mid + DW / 2.0, mid + DW / 2.0 + 0.3)
	bx.call("or", DW, 0.05, 0.3, mid, 2.575, 0.0)
	if o.get("open", false):
		var p: Vector2 = pt.call(mid - DW / 2.0, 0.0)
		var q: Vector2 = pt.call(mid + DW / 2.0, 0.0)
		K.seuil(p.x, p.y, q.x, q.y, 0.005)
	else:
		for s in [-1.0, 1.0]:
			bx.call("laque_noire", DW / 2.0 - 0.02, 2.5, 0.06, mid + s * DW / 4.0, 1.25, 0.0)
			bx.call("vitrine", DW / 2.0 - 0.3, 1.3, 0.07, mid + s * DW / 4.0, 1.6, 0.0)
			bx.call("or", 0.03, 0.4, 0.1, mid + s * 0.08, 1.1, 0.03)
		plein.call(mid - DW / 2.0, mid + DW / 2.0)
		var fp: Vector2 = pt.call(mid, 0.05)
		K.texte("Fermé · à demain", 0.42, 0.09, fp.x, 1.55, fp.y, ry)


## Un mannequin de couture : robe, buste, tête de plâtre.
static func _mannequin(K, x: float, z: float, robe: String, y := 0.0) -> void:
	K.cyl(robe, 0.08, 0.2, 0.62, x, y + 0.5, z, 8)
	K.cyl("marbre_creme", 0.1, 0.08, 0.3, x, y + 0.96, z, 8)
	K.sph("marbre_creme", 0.09, x, y + 1.22, z, 1.2)
	K.cyl("laque_noire", 0.012, 0.012, 0.2, x, y + 0.1, z, 4)
	if y == 0.0:
		K.cyl("laque_noire", 0.16, 0.18, 0.03, x, 0.015, z, 10)
		K.rond(x, z, 0.22, 0.0, 1.4)


## Une vitrine murale (L.murale) contre le mur x, centrée en zc, de largeur w ; out : côté de la place.
static func _murale(K, x: float, zc: float, w: float, out: float, nom: String, genre: String) -> void:
	K.box("laque_noire", 0.5, 2.3, w, x + out * 0.25, 1.75, zc)
	K.box("gorge", 0.02, 1.9, w - 0.3, x + out * 0.44, 1.75, zc)
	K.box("vitrine", 0.03, 2.0, w - 0.2, x + out * 0.52, 1.75, zc)
	for y in [0.56, 2.94]:
		K.box("or", 0.6, 0.07, w + 0.1, x + out * 0.28, y, zc)
	K.box("pierre_sombre", 0.56, 0.52, w, x + out * 0.28, 0.26, zc)
	for s in [-1.0, 1.0]:
		K.box("or", 0.56, 2.3, 0.06, x + out * 0.28, 1.75, zc + s * w / 2.0)
	K.texte(nom, minf(w - 0.4, 3.6), 0.22, x + out * 0.58, 3.3, zc, out * PI / 2.0)
	K.obstacle(minf(x, x + out * 0.56), maxf(x, x + out * 0.56), zc - w / 2.0, zc + w / 2.0, 0.0, 3.0)
	var xx := x + out * 0.4
	if genre == "horloges":
		for i in 5:
			for j in 3:
				var z := zc - 2.0 + i * 1.0
				var y := 1.05 + j * 0.62
				K.cyl("or" if j % 2 else "acier", 0.13, 0.13, 0.03, xx, y, z, 12, 0, PI / 2.0)
				K.cyl("creme", 0.1, 0.1, 0.035, xx + out * 0.005, y, z, 12, 0, PI / 2.0)
				K.box("laque_noire", 0.04, 0.09, 0.012, xx + out * 0.03, y + 0.035, z)
	else:
		for i in 4:
			var z := zc - 0.9 + i * 0.6
			K.cyl("or", 0.09, 0.06, 0.24, xx, 0.92, z, 8)
			K.sph("feuille_sombre", 0.13, xx, 1.16, z)
			K.sph(["laque_rouge", "or", "lotus", "creme"][i], 0.08, xx, 1.3, z + 0.03)
			K.cyl("or", 0.07, 0.05, 0.2, xx, 1.85, z + 0.1, 8)
			K.sph(["creme", "laque_rouge", "or", "lotus"][i], 0.1, xx, 2.05, z + 0.1)
