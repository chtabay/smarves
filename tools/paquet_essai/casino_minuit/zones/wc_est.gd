extends RefCounted
## Lot C, zone R-WC-E (js/zones/c-wc-e.js) : les toilettes est [20, 27] × [21, 30], rez-de-chaussée, 3,4 m sous
## plafond. La porte depuis le club (ouest) et sa chicane, quatre vasques sous miroir (mur nord), six cabines
## le long du mur est (une seule ouverte), une console au mur sud.

const LOT_B := "res://communes/casino_minuit/zones/lot_b.gd"
const LOT_C := "res://communes/casino_minuit/zones/lot_c.gd"
const H := 3.4
const B := {"x0": 20.0, "x1": 27.0, "z0": 21.0, "z1": 30.0}
const OUV := {"west": [{"at": 25.5, "w": 1.6, "h": 2.3}]}


static func construire(K) -> void:
	var LB = load(LOT_B)
	var L = load(LOT_C)
	K.zone_debut("R-WC-E")
	L.sol(K, "damier", B.x0, B.x1, B.z0, B.z1)
	L.plafond(K, "plafond_bas", B.x0, B.x1, B.z0, B.z1, H)
	LB.coque(K, B, H, "marbre_creme", OUV)
	var reg := {"base": "marbre_noir", "bh": 1.1, "h": H, "applique": false}
	L.registres(K, 20.2, 21.2, 20.2, 29.8, _avec(reg, {"n": [1.0, 0.0], "skip": [[3.5, 5.1]]}))
	L.registres(K, 20.2, 29.8, 26.8, 29.8, _avec(reg, {"n": [0.0, -1.0]}))
	L.registres(K, 20.2, 21.2, 26.8, 21.2, _avec(reg, {"n": [0.0, 1.0], "bh": 0.0}))
	# La chicane : on ne voit rien depuis le club.
	K.box("laque_noire", 0.14, 2.5, 2.7, 21.75, 1.25, 25.5)
	K.box("or", 0.2, 0.05, 2.76, 21.75, 2.52, 25.5)
	K.box("or", 0.2, 0.08, 2.76, 21.75, 0.04, 25.5)
	K.box("treillis", 0.02, 1.4, 2.2, 21.6, 1.5, 25.5)
	K.box("gorge", 0.02, 1.4, 2.2, 21.672, 1.5, 25.5)
	K.obstacle(21.58, 21.84, 24.15, 26.85, 0.0, 2.5)
	# Quatre vasques sous miroir, mur nord.
	K.box("marbre_noir", 3.7, 0.1, 0.6, 23.1, 0.86, 21.5)
	K.box("laque_noire", 3.5, 0.76, 0.5, 23.1, 0.4, 21.47)
	K.box("miroir", 3.5, 1.3, 0.03, 23.1, 1.85, 21.22)
	for y in [2.53, 1.17]:
		K.box("or", 3.62, 0.05, 0.06, 23.1, y, 21.24)
	K.box("gorge", 3.5, 0.06, 0.05, 23.1, 2.62, 21.25)
	K.obstacle(21.25, 24.95, 21.2, 21.8, 0.0, 1.0)
	var vasques := []
	for x in [21.9, 22.7, 23.5, 24.3]:
		K.cyl("porcelaine", 0.2, 0.15, 0.09, x, 0.94, 21.52, 14)
		K.cyl("or", 0.016, 0.016, 0.2, x, 1.0, 21.3, 6)
		K.box("or", 0.03, 0.03, 0.16, x, 1.1, 21.37)
		vasques.append([Vector3(x, 0, 22.12), 0.0])
	K.places["wc_e_vasques"] = vasques
	# Six cabines, mur est : cloisons laquées, cuvettes, portes (une ouverte, voyant vert).
	var X0 := 25.3
	var X1 := 26.8
	var Z0 := 22.0
	var W := 1.2
	for k in 7:
		var z := Z0 + W * k
		K.box("laque_noire", X1 - X0, 2.0, 0.05, (X0 + X1) / 2.0, 1.15, z)
		K.segment(X0, z, X1, z, 0.04, 0.0, 2.1)
	K.box("or", 0.07, 0.06, W * 6 + 0.05, X0, 2.18, Z0 + W * 3)
	for i in 6:
		var zc := Z0 + W * (i + 0.5)
		var ouverte := i == 4
		for s in [-1.0, 1.0]:
			K.box("laque_noire", 0.05, 2.0, 0.24, X0, 1.15, zc + s * 0.48)
			K.segment(X0, zc + s * 0.36, X0, zc + s * 0.6, 0.04, 0.0, 2.1)
		if ouverte:
			K.box("laque_rouge", 0.68, 1.85, 0.04, X0 + 0.36, 1.12, zc - 0.33, 0.12)
		else:
			K.box("laque_rouge", 0.04, 1.85, 0.7, X0, 1.12, zc)
			K.segment(X0, zc - 0.35, X0, zc + 0.35, 0.04, 0.0, 2.1)
		K.box("neon_vert" if ouverte else "neon_rouge", 0.02, 0.05, 0.1, X0 - 0.03, 1.15, zc + 0.27)
		K.cyl("porcelaine", 0.2, 0.15, 0.4, 26.35, 0.2, zc, 12)
		K.box("porcelaine", 0.18, 0.5, 0.42, 26.68, 0.62, zc)
	# Le mur sud : console, miroir, plantes.
	K.box("miroir", 2.2, 1.6, 0.03, 23, 1.95, 29.78)
	for y in [2.78, 1.12]:
		K.box("or", 2.32, 0.05, 0.06, 23, y, 29.76)
	K.box("marbre_noir", 1.6, 0.06, 0.4, 23, 0.9, 29.58)
	for x in [22.3, 23.7]:
		K.box("or", 0.06, 0.88, 0.06, x, 0.44, 29.58)
	K.obstacle(22.2, 23.8, 29.38, 29.8, 0.0, 1.0)
	LB.topiaire(K, 20.75, 29.25, 1.8)
	LB.topiaire(K, 20.75, 21.8, 1.8)
	# Le plafond lumineux : trois dalles de verre opalin.
	for z in [23.0, 25.5, 28.0]:
		K.box("ampoule", 2.4, 0.03, 1.1, 23.4, H - 0.05, z)
		K.box("or", 2.56, 0.05, 1.26, 23.4, H - 0.02, z)
	K.lumiere(23.4, 2.9, 25.5, Color("#FFE8C8"), 1.2, 11.0)
	K.zone_fin()


static func _avec(a: Dictionary, b: Dictionary) -> Dictionary:
	var o := a.duplicate()
	o.merge(b, true)
	return o
