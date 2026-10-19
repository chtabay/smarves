extends RefCounted
## Lot B, zone M-JARDIN (js/zones/b-jardin.js) : le jardin d'hiver. Rectangle [-40, -18] × [-30, -12] à la
## mezzanine (y = 6), ouvert sur la galerie par l'arche de 6 m (M03) et sur le lounge (M07). Pièces
## maîtresses : la verrière en berceau à nervures d'or sur un ciel de nuit, le bassin aux nénuphars (statue,
## jets, carpes), la pergola à treillage de l'ouest. Huit bancs, deux salons sous la pergola, douze arbres.

const LOT_B := "res://communes/casino_minuit/zones/lot_b.gd"
const Y := 6.0
const H := 5.0
const Y0 := 4.2
const FLECHE := 2.6
const B := {"x0": -40.0, "x1": -18.0, "z0": -30.0, "z1": -12.0}
const OUV := {"east": [{"at": -19.0, "w": 6.0, "h": 4.2}], "south": [{"at": -29.0, "w": 4.0, "h": 3.2}], "north": [], "west": []}
const PX := -29.0
const PZ := -21.0


static func construire(K) -> void:
	var L = load(LOT_B)
	K.zone_debut("M-JARDIN")
	K.zone.position.y = Y

	# --- enveloppe : dallage et mosaïque, murs de pierre à treillages, haies basses ---
	K.plan("dallage", B.x0, B.x1, B.z0, B.z1, 0)
	K.dalle(B.x0, B.x1, B.z0, B.z1)
	K.plan("mosaique", -33.4, -24.6, -24.4, -17.6, 0.005)
	L.coque(K, B, Y0 + FLECHE, "pierre", OUV)
	L.habille(K, B, H, OUV, {"socle": "feuille_sombre", "socle_h": 0.85, "socle_d": 0.34, "cimaise": false, "corniche": false, "pil": 4.4,
		"skip": {"west": [{"at": -21.0, "w": 13.0}]}})
	var treillage := func(x: float, z: float, ry: float, w: float):
		var sx := sin(ry)
		var cz := cos(ry)
		K.box("vert_jardin", w, 2.5, 0.03, x + sx * 0.02, 2.5, z + cz * 0.02, ry)
		K.box("treillis", w, 2.5, 0.01, x + sx * 0.07, 2.5, z + cz * 0.07, ry)
		K.box("or", w + 0.1, 0.06, 0.06, x + sx * 0.06, 3.78, z + cz * 0.06, ry)
		K.box("or", w + 0.1, 0.06, 0.06, x + sx * 0.06, 1.22, z + cz * 0.06, ry)
	for x in [-37.6, -33.2, -28.8, -24.4, -20.2]:
		treillage.call(x, -29.8, 0.0, 2.6)
	for x in [-37.6, -33.6, -24.6, -20.2]:
		treillage.call(x, -12.2, PI, 2.6)
	for z in [-27.4, -14.2]:
		treillage.call(-18.2, z, -PI / 2.0, 2.6)
	for z in [-25.2, -21.0, -16.8]:
		treillage.call(-39.8, z, PI / 2.0, 3.2)

	# --- la verrière : un berceau de ciel nocturne, neuf nervures d'or, des pannes, les tympans en éventail ---
	L.voute(K, "ciel_nuit", B.x0, B.x1, B.z0, B.z1, Y0, FLECHE, 14)
	var nervure = K._arc_or(8.72, 9.0, 0.12, 16)
	for i in 9:
		K.put("or", nervure, K.xf(-39.9 + i * 2.725, Y0, -21, 0, PI / 2.0, 0, 1, FLECHE / 9.0, 1))
	for d in [30.0, 60.0, 90.0, 120.0, 150.0]:
		var a := deg_to_rad(d)
		K.box("or", 22, 0.07, 0.07, -29, Y0 + FLECHE * sin(a) * 0.985, -21 - 8.87 * cos(a))
	for z in [-29.74, -12.26]:
		K.box("or", 22, 0.3, 0.12, -29, Y0 - 0.02, z)
		K.box("gorge", 21.6, 0.04, 0.04, -29, Y0 - 0.2, z + (0.08 if z < -20 else -0.08))
	for q in [[-39.78, PI / 2.0], [-18.22, -PI / 2.0]]:
		_tympan(K, q[0], q[1])
		K.box("or", 0.12, 0.3, 17.6, q[0] + sin(q[1]) * 0.04, Y0 - 0.02, -21)

	# --- le bassin aux nénuphars, 6 × 4 m : margelle, statue à l'amphore, jets, nénuphars, lotus, carpes ---
	for q in [[6.8, 0.4, 0.0, -2.2], [6.8, 0.4, 0.0, 2.2], [0.4, 4.0, -3.2, 0.0], [0.4, 4.0, 3.2, 0.0]]:
		K.box("marbre_creme", q[0], 0.45, q[1], PX + q[2], 0.225, PZ + q[3])
		K.box("or", q[0], 0.03, q[1] + 0.04, PX + q[2], 0.33, PZ + q[3])
	K.plan("eau", PX - 3, PX + 3, PZ - 2, PZ + 2, 0.36)
	K.obstacle(PX - 3.42, PX + 3.42, PZ - 2.42, PZ + 2.42, 0.0, 1.0)
	K.statue(PX, PZ, 1.8, 0.95, PI / 2.0, "marbre_creme", "amphore")
	K.cyl("or", 0.7, 0.7, 0.06, PX, 0.4, PZ, 10)
	var jets := []
	var pos := [[-1.9, -1.1], [1.9, -1.1], [-1.9, 1.1], [1.9, 1.1], [-2.5, 0.0], [2.5, 0.0]]
	for i in pos.size():
		jets.append({"x": PX + pos[i][0], "z": PZ + pos[i][1], "h": 1.1 if i < 4 else 1.7, "r": 0.045})
	K.jets(jets, 0.36, func(i, t): return 0.6 + 0.4 * sin(t * 1.3 + i * 1.1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 404
	for i in 26:
		var x := PX - 2.7 + rng.randf() * 5.4
		var z := PZ - 1.75 + rng.randf() * 3.5
		var s := 0.16 + rng.randf() * 0.2
		if Vector2(x - PX, z - PZ).length() < 0.9:
			continue
		L.disque(K, "feuille" if i % 3 else "feuille_sombre", x, 0.372 + (i % 4) * 0.001, z, s, 0.004, s)
		if i % 4 == 0:
			L.octa(K, "lotus", K.xf(x, 0.43, z, 0, rng.randf() * 3.0, 0, 0.1, 0.07, 0.1))
			L.octa(K, "ampoule", K.xf(x, 0.47, z, 0, 0, 0, 0.035, 0.035, 0.035))
	_carpes(K)
	K.lumiere(PX, 3.2, PZ + 0.8, Color("#FFF1D8"), 1.3, 15.0)

	# --- huit bancs de marbre : quatre autour du bassin, deux au mur nord, deux au mur est ---
	var bancs := []
	for q in [[PX, PZ - 3.8, PI], [PX, PZ + 3.8, 0.0], [-22.4, -12.75, 0.0], [PX + 4.95, PZ, PI / 2.0], [-26.6, -29.3, PI], [-22.2, -29.3, PI], [-18.75, -25.4, PI / 2.0], [-18.75, -14.3, PI / 2.0]]:
		for p in L.salon(K, q[0], q[1], q[2], [{"k": "banc", "x": 0.0, "z": 0.0, "f": 0.0, "n": 2, "w": 1.7}]):
			bancs.append([p[0] + Vector3(0, Y, 0), p[1]])
	K.places["jardin_bancs"] = bancs

	# --- la pergola (ouest) : huit poteaux, pannes, chevrons, glycine, lanternes ; deux salons de quatre fauteuils ---
	for x in [-38.9, -34.5]:
		for z in [-26.6, -22.9, -19.1, -15.4]:
			K.box("marbre_creme", 0.26, 3.0, 0.26, x, 1.5, z)
			K.box("or", 0.34, 0.08, 0.34, x, 3.0, z)
			K.box("or", 0.34, 0.1, 0.34, x, 0.05, z)
			K.rond(x, z, 0.2)
		K.box("bois_clair", 0.16, 0.2, 12.4, x, 3.14, -21)
	for i in 12:
		K.box("bois_clair", 5.4, 0.14, 0.09, -36.7, 3.3, -26.8 + i * 1.055)
	var rr := RandomNumberGenerator.new()
	rr.seed = 12
	for i in 22:
		var x := -38.95 + rr.randf() * 0.5 if i % 2 else -34.75 + rr.randf() * 0.5
		var z := -26.8 + rr.randf() * 11.6
		var s := 0.3 + rr.randf() * 0.22
		L.boule(K, "feuille" if i % 3 else "feuille_sombre", K.xf(x, 3.2 + rr.randf() * 0.14, z, 0, rr.randf() * 3.0, 0, s * 1.3, s * 0.42, s * 1.6))
		if i % 2 == 0:
			L.octa(K, "lotus", K.xf(x, 2.86 - rr.randf() * 0.12, z + 0.1, 0, 0, 0, 0.07, 0.24, 0.07))
			L.octa(K, "lotus", K.xf(x + 0.16, 2.94, z - 0.2, 0, 0, 0, 0.055, 0.17, 0.055))
	for z in [-25.0, -21.0, -17.0]:
		K.lanterne(-36.7, 2.42, z, 0.5, 0.45)
	var salons := []
	var quatre := [{"k": "fauteuil", "x": 0.0, "z": 1.3, "f": 0.0}, {"k": "fauteuil", "x": 0.0, "z": -1.3, "f": PI}, {"k": "fauteuil", "x": 1.3, "z": 0.0, "f": PI / 2.0}, {"k": "fauteuil", "x": -1.3, "z": 0.0, "f": -PI / 2.0}]
	for q in [[-36.7, -23.6, 0.0], [-36.7, -18.2, PI / 4.0]]:
		for p in L.salon(K, q[0], q[1], q[2], quatre, {"mat": "cuir_vert", "table": [0.0, 0.0, 0.5], "table_mat": "marbre_creme", "lampe": true}):
			salons.append([p[0] + Vector3(0, Y, 0), p[1]])
	K.places["jardin_salons"] = salons
	K.lumiere(-36.7, 2.5, -20.9, K.pal.lumiere, 1.2, 12.0)

	# --- douze arbres en pots : topiaires autour du bassin et près des baies, palmiers dans les angles ---
	var topiaires := [[PX - 4.1, PZ - 3.0], [PX + 4.1, PZ - 3.0], [PX - 4.1, PZ + 3.0], [PX + 4.1, PZ + 3.0], [-18.85, -22.9], [-18.85, -15.1], [-31.9, -12.75], [-26.1, -12.75]]
	for i in topiaires.size():
		L.topiaire(K, topiaires[i][0], topiaires[i][1], 2.3 if i < 4 else 2.6)
	var palmiers := [[-39.1, -29.1], [-18.95, -29.1], [-39.1, -12.9], [-30.6, -29.2]]
	for i in palmiers.size():
		L.palmier(K, palmiers[i][0], palmiers[i][1], {"h": 3.6 + (i % 2) * 0.4, "seed": 30 + i, "pot": "terre"})
	# Les promenades du jardin : le tour du bassin, par les bancs et la pergola.
	K.places["jardin_tour"] = [Vector3(-18.6, Y, -19.0), Vector3(-23.5, Y, -19.0), Vector3(-24.6, Y, -25.8), Vector3(-29.0, Y, -26.2), Vector3(-33.6, Y, -25.6),
		Vector3(-33.0, Y, -16.0), Vector3(-29.0, Y, -15.6), Vector3(-29.0, Y, -12.6), Vector3(-29.0, Y, -15.6), Vector3(-24.6, Y, -16.2), Vector3(-23.5, Y, -19.0)]
	K.zone_fin()


## Un tympan en éventail au bout de la verrière : un demi-disque de ciel, des rayons d'or, deux arcs.
static func _tympan(K, x: float, ry: float) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 14
	for i in n:
		var a := PI * i / n
		var b := PI * (i + 1) / n
		K._tri(st, Vector3.ZERO, Vector3(-9.0 * cos(b), FLECHE * sin(b), 0), Vector3(-9.0 * cos(a), FLECHE * sin(a), 0), Vector3(0, 0, 1), Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
	K.put("ciel_nuit", st.commit(), K.xf(x, Y0, -21, 0, ry))
	var sx := sin(ry)
	for k in range(1, 8):
		var a := k * PI / 8.0
		K.beam("or", Vector3(x + sx * 0.03, Y0, -21), Vector3(x + sx * 0.03, Y0 + FLECHE * sin(a), -21 + 8.9 * cos(a)), 0.06, 0.06)
	K.put("or", K._arc_or(2.6, 2.75, 0.08, 12), K.xf(x + sx * 0.04, Y0, -21, 0, ry, 0, 1, FLECHE / 9.0 * 1.6, 1))
	K.put("or", K._arc_or(5.6, 5.74, 0.08, 14), K.xf(x + sx * 0.04, Y0, -21, 0, ry, 0, 1, FLECHE / 9.0 * 1.25, 1))


## Les carpes du bassin : huit poissons qui tournent en ellipses, dans un sens ou dans l'autre.
static func _carpes(K) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var s := SphereMesh.new()
	s.radius = 1.0
	s.height = 2.0
	s.radial_segments = 4
	s.rings = 2
	mm.mesh = s
	mm.instance_count = 8
	var mi := MultiMeshInstance3D.new()
	mi.name = "Carpes"
	mi.multimesh = mm
	mi.material_override = K.mat("lueur#FF7A1A")
	K.zone.add_child(mi)
	K.chaque_image(func(_dt, t):
		for i in 8:
			var w := (0.22 + (i % 3) * 0.07) * (1.0 if i % 2 else -1.0)
			var a: float = t * w + i * 2.1
			var rx := 1.3 + (i % 4) * 0.38
			var rz := 0.8 + (i % 3) * 0.3
			var b := Basis(Vector3.UP, -a - (0.0 if w > 0.0 else PI)) * Basis.from_scale(Vector3(0.055, 0.035, 0.16))
			mm.set_instance_transform(i, Transform3D(b, Vector3(PX + cos(a) * rx, 0.368, PZ + sin(a) * rz))))
