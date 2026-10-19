extends RefCounted
## Lot B, zone R-HL (js/zones/b-hl.js) : le salon des hautes limites. Rectangle [-26, -14] × [-30, -12],
## rez-de-chaussée ; une seule liaison, au nord de l'atrium (L19), gardée par un cordon de velours et un
## vigile (minuit.gd ouvre le cordon au seuil du lieu). Le salon le plus luxueux : plafond capitonné sous
## une résille d'or, murs de laque noire à panneaux capitonnés, mur d'onyx, paravent de laque à six
## feuilles derrière le seuil. Blackjack, deux baccaras, une roulette à la roue qui tourne : du décor.

const LOT_B := "res://communes/casino_minuit/zones/lot_b.gd"
const H := 5.4
const B := {"x0": -26.0, "x1": -14.0, "z0": -30.0, "z1": -12.0}
const OUV := {"south": [{"at": -16.0, "w": 3.0, "h": 3.0}], "north": [], "east": [], "west": []}
const BAC := [-75, -50, -25, 0, 25, 50, 75]
const ROUGES := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
const ROUE := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]


static func construire(K) -> void:
	var L = load(LOT_B)
	K.zone_debut("R-HL")

	# --- enveloppe : moquette « nuages », laque noire, plafond capitonné sous une résille d'or ---
	K.plan("moquette_b", B.x0, B.x1, B.z0, B.z1, 0)
	K.dalle(B.x0, B.x1, B.z0, B.z1)
	K.plan("capiton_rouge", B.x0, B.x1, B.z0, B.z1, H, false)
	for x in [-23.0, -20.0, -17.0]:
		K.box("or", 0.14, 0.12, 17.6, x, H - 0.06, -21)
	for z in [-27.0, -24.0, -21.0, -18.0, -15.0]:
		K.box("or", 11.6, 0.12, 0.14, -20, H - 0.06, z)
		for x in [-23.0, -20.0, -17.0]:
			L.octa(K, "or", K.xf(x, H - 0.16, z, 0, PI / 4.0, 0, 0.16, 0.14, 0.16))
	L.coque(K, B, H, "laque_noire", OUV)
	L.habille(K, B, H, OUV, {"socle": "marbre_noir", "pil": 3.6, "pil_mat": "laque_noire", "skip": {"north": [{"at": -20.0, "w": 8.0}]}})
	for z in [-27.3, -23.7, -20.1, -16.5]:
		L.panneau(K, -25.78, 2.75, z, PI / 2.0, 2.3, 2.6, "capiton_rouge", true)
		if z < -16:
			L.panneau(K, -14.22, 2.75, z, -PI / 2.0, 2.3, 2.6, "capiton_rouge", true)
	for x in [-24.1, -21.4]:
		L.panneau(K, x, 2.75, -12.22, PI, 2.1, 2.6, "capiton_rouge", true)

	# --- le mur d'onyx rétroéclairé et son inscription (mur nord) ---
	K.box("onyx", 7.4, 3.0, 0.02, -20, 2.75, -29.78)
	for q in [[7.6, 0.1, 0.0, 1.55], [7.6, 0.1, 0.0, -1.55], [0.1, 3.2, 3.75, 0.0], [0.1, 3.2, -3.75, 0.0]]:
		K.box("or", q[0], q[1], 0.1, -20 + q[2], 2.75 + q[3], -29.75)
	for x in [-22.5, -17.5]:
		K.box("treillis", 2.2, 3.0, 0.01, x, 2.75, -29.72)
	L.enseigne(K, "SALON HAUTES LIMITES", -20, 4.62, -29.72, 0, 6.4, 0.5, "or")
	K.urne(-24.9, -29.0, 1.3)
	K.urne(-15.1, -29.0, 1.3)

	# --- le paravent de laque à six feuilles, deux mètres derrière le seuil : une lune d'or, des grues ---
	for i in 6:
		var x := -14.72 - i * 0.9
		var z := -14.2 + (-0.12 if i % 2 else 0.12)
		var ry := -0.3 if i % 2 else 0.3
		K.box("laque_noire", 0.96, 3.0, 0.06, x, 1.56, z, ry)
		K.box("or", 0.98, 0.06, 0.08, x, 3.07, z, ry)
		K.box("or", 0.98, 0.06, 0.08, x, 0.06, z, ry)
		for s in [-1.0, 1.0]:
			K.box("or", 0.025, 3.0, 0.07, x + s * 0.47 * cos(ry), 1.56, z - s * 0.47 * sin(ry), ry)
		for f in [-1.0, 1.0]:
			var fx: float = x + f * 0.035 * sin(ry)
			var fz: float = z + f * 0.035 * cos(ry)
			# Les vagues d'or au pied, et sur deux feuilles la lune et une grue en vol.
			for k in 3:
				K.box("or_brosse", 0.84, 0.02, 0.005, fx, 0.45 + k * 0.12, fz, ry)
			if i == 1:
				K.put("or", L._disque(), K.xf(fx, 2.55, fz, PI / 2.0, ry, 0, 0.26, 0.004, 0.26))
			if i == 3 or i == 4:
				L.octa(K, "or_brosse", K.xf(fx, 1.9 + 0.3 * (i - 3), fz, 0, ry, 0.4 * f, 0.34, 0.07, 0.004))
	K.segment(-14.25, -14.2, -19.7, -14.2, 0.16)
	K.lanterne(-16, 3.3, -13.2, 0.7, H - 3.8)

	# --- le blackjack des hautes limites : une demi-lune au tapis rouge, le croupier côté nord ---
	var bx := -20.0
	var bz := -17.6
	K.anneau("feutre_hl", bx, bz, 0.0, 1.08, 0.93, PI / 2.0, 3.0 * PI / 2.0)
	K.arc("cuir_noir", bx, bz, 1.16, PI / 2.0, 3.0 * PI / 2.0, 0.84, 0.95, "out")
	K.anneau("cuir_noir", bx, bz, 1.06, 1.16, 0.95, PI / 2.0, 3.0 * PI / 2.0)
	K.box("bois_laque", 2.36, 0.12, 0.1, bx, 0.89, bz)
	K.cyl("laque_noire", 0.3, 0.45, 0.84, bx, 0.42, bz + 0.45, 12)
	K.obstacle(bx - 1.2, bx + 1.2, bz - 0.1, bz + 1.2, 0.0, 1.0)
	var bj := []
	for i in 5:
		var a := PI / 2.0 + (i + 1) * PI / 6.0
		var r := [bx + 1.62 * sin(a), bz - 1.62 * cos(a), PI - a]
		L.chaise(K, r, "capiton_rouge")
		bj.append([Vector3(r[0], 0.5, r[1]), r[2]])
	L.enseigne(K, "Mise min. 100", -21.75, 1.2, -18.0, 0, 0.5, 0.16, "plaque", "ambre", true)
	K.cyl("or", 0.015, 0.02, 1.1, -21.75, 0.55, -17.98, 5)
	K.places["hl_bj"] = {"sieges": bj, "croupier": [Vector3(bx, 0, bz - 0.6), PI]}

	# --- deux tables de baccara : croupiers côté mur, joueurs côté allée centrale ---
	var bac := []
	bac.append(L.table_jeu(K, -22.7, -21.9, PI / 2.0, {"a": 1.6, "b": 0.8, "angles": BAC, "felt": "feutre_hl", "rim": "cuir_noir", "chaise": "capiton_rouge"}))
	bac.append(L.table_jeu(K, -17.3, -21.9, -PI / 2.0, {"a": 1.6, "b": 0.8, "angles": BAC, "felt": "feutre_hl", "rim": "cuir_noir", "chaise": "capiton_rouge"}))
	K.places["hl_baccara"] = bac
	for x in [-22.7, -17.3]:
		L.lustre(K, x, 3.05, -21.9, H, 0.9, 12, 0.9)
	K.lumiere(-20, 3.0, -21.9, K.pal.lumiere, 1.6, 13.0)
	K.lumiere(-20, 2.9, -16.2, K.pal.lumiere, 1.4, 11.0)

	# --- la roulette : tapis, cylindre de bois et roue qui tourne, six tabourets, croupier au nord ---
	var g := [-20.0, -27.6, 0.0]
	var top := 0.82
	K.box("bois_laque", 2.9, 0.14, 1.6, -20, top - 0.07, -27.6)
	K.box("laque_noire", 2.7, 0.26, 1.4, -20, top - 0.27, -27.6)
	K.box("or", 2.94, 0.03, 1.64, -20, top - 0.15, -27.6)
	for q in [-1.1, 1.1]:
		K.cyl("laque_noire", 0.18, 0.26, top - 0.4, -20 + q, (top - 0.4) / 2.0, -27.6, 8)
	K.box("feutre_hl", 1.9, 0.01, 1.3, -19.58, top + 0.004, -27.6)
	# Le tableau des mises : trois rangées de douze cases, rouges et noires, le zéro vert.
	K.box("feutre", 0.12, 0.012, 0.6, -20.45, top + 0.01, -27.75)
	for n in range(1, 37):
		var col := (n - 1) / 3
		var row := 2 - (n - 1) % 3
		K.box("laque_rouge" if n in ROUGES else "laque_noire", 0.1, 0.012, 0.18, -20.33 + col * 0.11, top + 0.01, -27.95 + row * 0.2)
	K.cyl("bois_laque", 0.44, 0.4, 0.14, -20.95, top + 0.07, -27.6, 20)
	K.cyl("or", 0.46, 0.46, 0.02, -20.95, top + 0.15, -27.6, 20)
	K.obstacle(-21.47, -18.53, -28.42, -26.78, 0.0, 1.0)
	for q in [[-0.45, 1.22], [0.25, 1.22], [0.95, 1.22], [1.65, 1.22], [2.02, 0.36], [2.02, -0.36]]:
		L.tabouret(K, -20 + q[0], -27.6 + q[1], 0.72, "capiton_rouge")
	K.places["hl_roulette"] = {"sieges": [[Vector3(-20.45, 0.72, -26.38), 0.0], [Vector3(-19.05, 0.72, -26.38), 0.0], [Vector3(-17.98, 0.72, -27.24), PI / 2.0]],
		"croupier": [Vector3(-20.4, 0, -28.85), PI]}
	L.suspension(K, -19.6, -27.6, H, 2.3, 0.5)
	_roue(K, Vector3(-20.95, top + 0.165, -27.6))

	# --- deux salons de trois places ---
	var salons := []
	salons.append_array(L.salon(K, -14.85, -17.4, PI / 2.0, [{"k": "sofa", "x": 0.0, "z": 0.0, "f": 0.0, "n": 2}, {"k": "fauteuil", "x": -1.75, "z": -1.15, "f": -PI / 2.0}],
		{"mat": "capiton_rouge", "table": [-0.1, -1.4, 0.4], "lampe": true}))
	salons.append_array(L.salon(K, -25.15, -17.4, -PI / 2.0, [{"k": "sofa", "x": 0.0, "z": 0.0, "f": 0.0, "n": 2}, {"k": "fauteuil", "x": 1.75, "z": -1.15, "f": PI / 2.0}],
		{"mat": "capiton_rouge", "table": [0.1, -1.4, 0.4], "lampe": true}))
	K.places["hl_salons"] = salons
	K.zone_fin()


## La roue de la roulette : trente-sept cases en couronne, un moyeu d'or à croisillon ; elle tourne,
## ralentit, s'arrête et repart, un tour de quatorze secondes (comme dans le jeu web).
static func _roue(K, at: Vector3) -> void:
	var mats := {}
	for i in 37:
		var n: int = ROUE[i]
		var cle := "feutre" if n == 0 else ("laque_rouge" if n in ROUGES else "laque_noire")
		if not mats.has(cle):
			mats[cle] = SurfaceTool.new()
			mats[cle].begin(Mesh.PRIMITIVE_TRIANGLES)
		var a0 := i * TAU / 37.0
		var a1 := (i + 1) * TAU / 37.0
		var p := func(r: float, a: float) -> Vector3: return Vector3(r * cos(a), 0, r * sin(a))
		K._quad(mats[cle], p.call(0.22, a0), p.call(0.39, a0), p.call(0.39, a1), p.call(0.22, a1), Vector3.UP)
	var roue := Node3D.new()
	roue.name = "Roue"
	roue.position = at
	K.zone.add_child(roue)
	for cle in mats:
		var mi := MeshInstance3D.new()
		mi.mesh = mats[cle].commit()
		mi.material_override = K.mat(cle)
		roue.add_child(mi)
	var moyeu := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.2
	c.bottom_radius = 0.22
	c.height = 0.03
	moyeu.mesh = c
	moyeu.material_override = K.mat("bois_laque")
	roue.add_child(moyeu)
	for k in 2:
		var bras := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.36, 0.03, 0.03)
		bras.mesh = b
		bras.position.y = 0.05
		bras.rotation.y = k * PI / 2.0
		bras.material_override = K.mat("or")
		roue.add_child(bras)
	K.chaque_image(func(_dt, t):
		var ph := fmod(t, 14.0)
		roue.rotation.y = -(floorf(t / 14.0) * 2.1 + (9.0 * ph - 0.5 * ph * ph if ph < 9.0 else 40.5)))
