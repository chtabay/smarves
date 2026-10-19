extends RefCounted
## Lot A, zone R-ATRIUM (js/zones/a-atrium.js) : le cœur du plateau, sous la nef. Rectangle [-18, 18] × [-12, 12] ;
## double hauteur (13 m) sur [-14, 14] × [-12, 9], plafond à 5,4 m sous la galerie (bandes ouest, est et sud).
## Le bar central « Le Minuit », le lustre « La Pluie d'or », la colonnade colossale. Les tables (deux craps, deux
## roulettes) sont pour l'instant du décor : on les ouvrira plus tard par des seuils.

const NEF := 13.0


static func construire(K) -> void:
	K.zone_debut("R-ATRIUM")

	# --- sols : marbre crème, croix de damier dans l'axe, deux tapis de jeu bordés d'or ---
	K.plan("marbre_creme", -18, 18, -12, 12, 0)
	K.dalle(-18, 18, -12, 12)
	K.plan("damier", -6.2, 6.2, -6, 6, 0.002)
	K.plan("damier", -3, 3, 6, 11.8, 0.002)
	K.plan("damier", -3, 3, -12, -6, 0.002)
	for r in [[-6.2, 6.2, -6.0, -6.0], [-6.2, 6.2, 6.0, 6.0], [-6.2, -6.2, -6.0, 6.0], [6.2, 6.2, -6.0, 6.0]]:
		K.seuil(r[0], r[2], r[1], r[3], 0.003)
	for sg in [-1.0, 1.0]:
		var a = sg * 6.9
		var b = sg * 12.4
		K.plan("moquette", minf(a, b), maxf(a, b), -11.2, 5.2, 0.004)

	# --- murs : sud (vers la rotonde, l'hôtel et le club), amorces nord ---
	K.mur(-18, 11.9, 18, 11.9, 5.4, 0, -1, [{"at": 4.0, "w": 5.0, "h": 4.6}, {"at": 18.0, "w": 6.0, "h": 5.0}, {"at": 32.0, "w": 5.0, "h": 4.6}], "pierre", 1.2, false)
	for x in [-14.0, 14.0]:
		K.arche(x, 12, 0, 5, 4.6)
		K.seuil(x - 2.5, 12, x + 2.5, 12)
		# L'hôtel et le club sont à construire : une grille fermée.
		K.box("laque_noire", 5.0, 4.0, 0.06, x, 2.0, 12.3)
		K.solide(5.0, 4.6, 0.3, x, 2.3, 12.3)
	K.texte("HÔTEL · RÉCEPTION", 3.4, 0.36, -14, 4.98, 11.78, PI)
	K.texte("CLUB MINUIT · CAISSE", 3.4, 0.36, 14, 4.98, 11.78, PI)
	K.texte("SORTIE", 2.2, 0.44, 0, 5.12, 11.76, PI, "neon", K.pal.or_clair)
	for sg in [-1.0, 1.0]:
		K.mur(sg * 17.9, 9, sg * 17.9, 12, 5.4, -sg, 0, [], "pierre", 1.2, false)
		K.mur(sg * 18, -11.9, sg * 14, -11.9, 5.4, 0, 1, [{"at": 2.0, "w": 3.0 if sg < 0 else 3.6, "h": 3.0 if sg < 0 else 3.6}], "pierre", 1.2, false)
	K.cadre(-16, -12, 0, 3, 3.0)
	K.texte("SALON HAUTES LIMITES", 3.0, 0.34, -16, 3.5, -11.78, 0)
	K.cadre(16, -12, 0, 3.6, 3.6)
	K.texte("THÉÂTRE · PARIS SPORTIFS", 3.2, 0.34, 16, 4.1, -11.78, 0)
	for x in [-16.0, 16.0]:
		K.box("laque_noire", 3.6, 3.6, 0.06, x, 1.8, -12.25)
		K.solide(3.6, 3.6, 0.3, x, 1.8, -12.3)
	# Le cordon de velours du seuil des hautes limites.
	for x in [-17.35, -14.65]:
		K.cyl("or", 0.17, 0.2, 0.04, x, 0.02, -11.3, 12)
		K.cyl("or", 0.025, 0.025, 1.0, x, 0.52, -11.3, 8)
		K.sph("or", 0.06, x, 1.05, -11.3)
	K.beam("coussin", Vector3(-17.35, 0.9, -11.3), Vector3(-14.65, 0.9, -11.3), 0.05, 0.05)
	K.obstacle(-17.5, -14.5, -11.5, -11.1)

	# --- colonnades ouvertes vers les machines et la fosse (x = ±18), fermées pour l'instant ---
	for sg in [-1.0, 1.0]:
		for z in [-9.0, -3.0, 3.0, 9.0]:
			K.colonne(sg * 18, z, 0.5, 4.9)
		K.box("pierre", 0.46, 0.5, 21, sg * 18, 5.15, -1.5)
		K.box("or", 0.52, 0.05, 21, sg * 18, 4.9, -1.5)
		K.seuil(sg * 18, -12, sg * 18, 9)
		# Au-delà, les salles des lots B et C : un rideau de velours tiré, pas encore de passage.
		K.box("coussin", 0.08, 4.9, 21, sg * 18.4, 2.45, -1.5)
		K.solide(0.3, 4.9, 21, sg * 18.3, 2.45, -1.5)

	# --- plafonds bas sous la galerie (5,4 m) et lanternes d'allée ---
	for r in [[-18.0, -14.0, -12.0, 12.0], [14.0, 18.0, -12.0, 12.0], [-14.0, 14.0, 9.0, 12.0]]:
		K.plan("plafond_bas", r[0], r[1], r[2], r[3], 5.4, false)
	for sg in [-1.0, 1.0]:
		K.box("gorge", 0.05, 0.05, 21, sg * 14.12, 5.36, -1.5)
		var i := 0
		for z in [-10.0, -6.0, -2.0, 2.0, 6.0]:
			K.lanterne(sg * 16, 3.25, z, 1.0, 1.45)
			i += 1
		K.lanterne(sg * 8.5, 3.3, 10.5, 1.0, 1.4)
	K.box("gorge", 28, 0.05, 0.05, 0, 5.36, 9.12)

	# --- colonnade colossale de la nef : 8 colonnes de 11 m, entablement de 11 à 12,5 m ---
	for sg in [-1.0, 1.0]:
		for z in [-9.0, -3.0, 3.0, 9.0]:
			K.colonne(sg * 13.3, z, 1.1, 11.0, true)
		K.entablement(sg * 13.3, -12, sg * 13.3, 9.95, 11, 1.1, "pierre_haute")
	K.entablement(-12.75, 9.4, 12.75, 9.4, 11, 1.1, "pierre_haute")

	# --- le bar central « Le Minuit » : deux comptoirs dos à dos, tour d'onyx, dais suspendu ---
	_bar(K)

	# --- le lustre « La Pluie d'or », à l'aplomb du bar ---
	_lustre(K)

	# --- les tables : décor fermé (on y jouera plus tard), et les mange-debout ---
	for x in [-10.5, 10.5]:
		_craps(K, x, 0.0)
		for z in [-0.8, 0.8]:
			_suspension(K, x, 2.45, z, 0.4, NEF - 2.61)
		K.lumiere(x, 2.3, 0, K.pal.lumiere, 1.6, 8.0)
	_roulette(K, -10.5, -8.0, PI / 2.0, -1.0)
	_roulette(K, 10.5, -8.0, -PI / 2.0, 1.0)
	for p in [[-10.5, 8.0], [10.5, 8.0], [-6.5, 9.5], [6.5, 9.5]]:
		_mange_debout(K, p[0], p[1])

	# --- lumière : le lustre et le bar ---
	K.lumiere(0, 8.2, 0, K.pal.lumiere, 2.6, 18.0)
	K.lumiere(0, 3.6, 0, K.pal.ambre_chaud, 1.8, 11.0)
	K.zone_fin()


static func _bar(K) -> void:
	for sg in [-1.0, 1.0]:
		var zf = sg * 3.526
		# Les comptoirs : un meuble de laque, un plateau, la face d'onyx rétroéclairé entre des montants.
		K.box("laque_noire", 8.4, 1.0, 0.6, 0, 0.5, sg * 3.2)
		K.box("marbre_noir", 8.6, 0.06, 0.8, 0, 1.03, sg * 3.25)
		var px := -3.6
		while px <= 3.61:
			K.box("onyx", 1.06, 0.72, 0.02, px, 0.5, zf)
			px += 1.2
		px = -4.2
		while px <= 4.21:
			K.box("laque_noire", 0.14, 0.9, 0.05, px, 0.47, zf + sg * 0.005)
			px += 1.2
		K.box("gorge", 8.0, 0.04, 0.03, 0, 0.07, zf + sg * 0.01)
		K.box("or", 8.3, 0.035, 0.05, 0, 0.9, zf + sg * 0.02)
		K.box("onyx", 0.02, 0.72, 5.9, sg * 4.312, 0.5, 0)
		K.box("laque_noire", 0.62, 1.0, 6.3, sg * 4.1, 0.5, 0)
		K.box("marbre_noir", 0.7, 0.06, 6.5, sg * 4.1, 1.03, 0)
		# Les tabourets de bar, côté clients.
		for i in 7:
			var x := -3.6 + i * 1.2
			_tabouret(K, x, sg * 4.15, 0.78)
		# Derrière les comptoirs, la tour à bouteilles adossée à son âme d'onyx.
		for sy in [1.35, 1.85, 2.35]:
			K.box("onyx", 7.6, 0.44, 0.012, 0, sy + 0.2, sg * 0.236)
			K.box("laque_noire", 7.8, 0.03, 0.3, 0, sy, sg * 0.3)
			for i in 26:
				var bx := -3.6 + i * 0.29
				K.cyl(["ampoule", "lanterne", "gorge"][i % 3], 0.035, 0.035, 0.28, bx, sy + 0.16, sg * 0.36, 6)
		K.box("onyx", 0.02, 2.9, 0.5, sg * 4.012, 1.45, 0)
		K.box("laque_noire", 7.3, 0.28, 0.3, 0, 4.11, sg * 3.3)
	K.box("laque_noire", 8.0, 2.9, 0.4, 0, 1.45, 0)
	K.obstacle(-4.5, 4.5, -3.6, 3.6, 0.0, 1.2)
	K.box("onyx", 8.1, 0.55, 0.56, 0, 3.2, 0)
	K.box("or", 8.3, 0.06, 0.66, 0, 2.92, 0)
	K.box("or", 8.3, 0.06, 0.66, 0, 3.5, 0)
	K.box("gorge", 7.7, 0.62, 0.04, 0, 3.86, 0)
	K.box("or", 8.0, 0.05, 0.3, 0, 4.2, 0)
	K.box("laque_noire", 0.3, 0.3, 6.9, 0, 4.11, 0)
	# Le dais : un anneau ovale de 12 × 9 m en laque noire, une gorge dessous, huit tiges d'or, douze lanternes.
	K.bande("laque_noire", 0, 0, [6.25, 4.75, 3.95], [6.25, 4.75, 4.3], 0.0, TAU, "out", 0.0, 0.1)
	K.bande("laque_noire", 0, 0, [5.75, 4.25, 3.95], [5.75, 4.25, 4.3], 0.0, TAU, "in", 0.0, 0.1)
	K.bande("laque_noire", 0, 0, [5.75, 4.25, 4.3], [6.25, 4.75, 4.3], 0.0, TAU, "up", 0.0, 0.1)
	K.bande("gorge", 0, 0, [6.13, 4.63, 3.95], [5.87, 4.37, 3.95], 0.0, TAU, "down", 0.0, 0.1)
	K.bande("or", 0, 0, [6.27, 4.77, 4.24], [6.27, 4.77, 4.3], 0.0, TAU, "out", 0.0, 0.1)
	K.bande("or", 0, 0, [6.27, 4.77, 3.95], [6.27, 4.77, 4.0], 0.0, TAU, "out", 0.0, 0.1)
	for i in 8:
		var b := PI / 8.0 + i * PI / 4.0
		K.cyl("or", 0.028, 0.028, NEF - 4.3, 6.0 * sin(b), (NEF + 4.3) / 2.0, -4.5 * cos(b), 6)
	for i in 12:
		var b := PI / 12.0 + i * PI / 6.0
		K.lanterne(6.0 * sin(b), 3.36, -4.5 * cos(b), 0.55, 0.2)
	K.texte("LE MINUIT", 3.4, 0.62, 0, 4.72, 4.78, 0, "neon")
	K.texte("LE MINUIT", 3.4, 0.62, 0, 4.72, -4.78, PI, "neon")


static func _lustre(K) -> void:
	K.cyl("or", 0.07, 0.07, 2.4, 0, 13.6, 0, 8)
	K.sph("or", 0.22, 0, 12.5, 0)
	for c in [[2.6, 12.4], [1.8, 11.2], [1.0, 10.0]]:
		K.tore("or", c[0], 0.075, K.xf(0, c[1], 0), 44)
	for i in 8:
		var a := TAU * i / 8.0
		var s := sin(a)
		var co := cos(a)
		K.beam("or", Vector3(0.1 * s, 12.95, 0.1 * co), Vector3(2.6 * s, 12.4, 2.6 * co), 0.05, 0.05)
		K.beam("or", Vector3(2.6 * s, 12.4, 2.6 * co), Vector3(1.8 * s, 11.2, 1.8 * co), 0.045, 0.045)
		K.beam("or", Vector3(1.8 * s, 11.2, 1.8 * co), Vector3(1.0 * s, 10.0, 1.0 * co), 0.04, 0.04)
	for i in 24:
		var a := (i + 0.5) * TAU / 24.0
		K.lanterne(2.6 * sin(a), 11.85, 2.6 * cos(a), 0.36, 0.26)
	# 420 pendeloques en spirale, qui tournent lentement et scintillent par trentaines.
	var n := 420
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 1313
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var oct := PrismMesh.new()
	oct.size = Vector3(0.15, 0.3, 0.15)
	mm.mesh = oct
	mm.instance_count = n
	var base := []
	for i in n:
		var u := float(i) / (n - 1)
		var ang := u * 5.0 * TAU + (i % 3) * TAU / 3.0
		var r := maxf(0.05, 2.55 - 2.3 * u + (rnd.randf() - 0.5) * 0.3)
		var y := 12.1 - 4.55 * u + (rnd.randf() - 0.5) * 0.5
		var p := Vector3(r * sin(ang), y, r * cos(ang))
		base.append(p)
		mm.set_instance_transform(i, Transform3D(Basis(), p))
		var k := rnd.randf()
		mm.set_instance_color(i, Color("#FFE2B4") if k < 0.7 else (Color("#FFB347") if k < 0.9 else Color("#FF5A2A")))
	var mi := MultiMeshInstance3D.new()
	mi.name = "lustre_pendeloques"
	mi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.emission_enabled = true
	m.emission = Color("#FFD9A8")
	m.emission_energy_multiplier = 1.6
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	K.zone.add_child(mi)
	var lot := [-1]
	K.chaque_image(func(_dt, t):
		mi.rotation.y = t * 0.03
		var lt := int(t / 0.5)
		if lt != lot[0]:
			if lot[0] >= 0:
				for k in 30:
					mm.set_instance_transform((lot[0] * 37 + k * 13) % n, Transform3D(Basis(), base[(lot[0] * 37 + k * 13) % n]))
			lot[0] = lt % 100000
		for k in 30:
			var j: int = (lot[0] * 37 + k * 13) % n
			var s := 1.0 + 0.7 * absf(sin(t * 9.4 + k))
			mm.set_instance_transform(j, Transform3D(Basis.from_scale(Vector3(s, s, s)), base[j])))


static func _suspension(K, x: float, y: float, z: float, r: float, cord: float) -> void:
	K.cyl("or", 0.009, 0.009, cord, x, y + 0.16 + cord / 2.0, z, 4)
	K.cyl("or", r * 0.25, r, 0.26, x, y + 0.05, z, 12)
	K.cyl("ampoule", r * 0.86, r * 0.86, 0.02, x, y - 0.075, z, 12)


static func _tabouret(K, x: float, z: float, h: float) -> void:
	K.cyl("or", 0.2, 0.22, 0.03, x, 0.015, z, 8)
	K.cyl("or", 0.028, 0.028, h - 0.08, x, (h - 0.08) / 2.0, z, 5)
	K.cyl("coussin", 0.19, 0.17, 0.08, x, h - 0.04, z, 10)


## Une table de craps (décor) : la cuve bordée de laque, le tapis vert, la rambarde d'or. Long axe le long de z.
static func _craps(K, x: float, z: float) -> void:
	K.box("laque_noire", 1.7, 0.8, 3.6, x, 0.4, z)
	K.box("bois_laque", 1.9, 0.14, 3.8, x, 0.87, z)
	K.box("feutre", 1.5, 0.02, 3.4, x, 0.9, z)
	K.box("or", 1.92, 0.04, 3.82, x, 0.95, z)
	for sg in [-1.0, 1.0]:
		K.box("laque_noire", 0.12, 0.12, 3.8, x + sg * 0.92, 1.0, z)
	K.texte("CRAPS · BIENTÔT", 1.4, 0.16, x, 0.92, z, 0)
	K.obstacle(x - 1.0, x + 1.0, z - 1.95, z + 1.95, 0.0, 1.0)
	for i in 6:
		_tabouret(K, x + (1.4 if i < 3 else -1.4), z - 1.2 + (i % 3) * 1.2, 0.72)


## Une table de roulette (décor) : la cuvette, la roue qui tourne, six tabourets.
static func _roulette(K, x: float, z: float, rot: float, q: float) -> void:
	var c := cos(rot)
	var s := sin(rot)
	var loc := func(lx: float, lz: float) -> Vector2: return Vector2(x + c * lx + s * lz, z - s * lx + c * lz)
	K.box("laque_noire", 2.9, 0.14, 1.6, x, 0.79, z, rot)
	K.box("or", 2.94, 0.03, 1.64, x, 0.73, z, rot)
	K.box("laque_noire", 2.5, 0.5, 1.2, x, 0.47, z, rot)
	K.box("feutre", 2.76, 0.01, 1.46, x, 0.866, z, rot)
	var cu: Vector2 = loc.call(-0.92 * q, 0.0)
	K.cyl("laque_noire", 0.46, 0.4, 0.13, cu.x, 0.93, cu.y, 24)
	K.tore("or", 0.44, 0.03, K.xf(cu.x, 1.0, cu.y), 28)
	var roue := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.4
	cm.bottom_radius = 0.4
	cm.height = 0.02
	cm.radial_segments = 37
	roue.mesh = cm
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color("#B3121F")
	rm.metallic = 0.3
	rm.roughness = 0.3
	roue.material_override = rm
	roue.position = Vector3(cu.x, 1.0, cu.y)
	K.zone.add_child(roue)
	for i in 4:
		K.put("or", K._box_mesh(0.7, 0.03, 0.04), K.xf(cu.x, 1.02, cu.y, 0, i * PI / 4.0, 0))
	K.cyl("or", 0.03, 0.05, 0.16, cu.x, 1.06, cu.y, 8)
	var vitesse := 1.1 * q
	K.chaque_image(func(_dt, t): roue.rotation.y = t * vitesse)
	K.obstacle(x - (0.82 if absf(s) > 0.5 else 1.5), x + (0.82 if absf(s) > 0.5 else 1.5), z - (1.5 if absf(s) > 0.5 else 0.82), z + (1.5 if absf(s) > 0.5 else 0.82), 0.0, 1.0)
	for p in [[-0.25, 1.25], [0.45, 1.25], [1.15, 1.25], [1.95, 0.0], [1.15, -1.25], [0.45, -1.25]]:
		var t: Vector2 = loc.call(p[0] * q, p[1])
		_tabouret(K, t.x, t.y, 0.72)
	_suspension(K, x, 2.5, z, 0.46, NEF - 2.66)


## Un mange-debout : guéridon haut de laque noire sur un pied d'or, une petite lampe.
static func _mange_debout(K, x: float, z: float) -> void:
	K.cyl("laque_noire", 0.4, 0.4, 0.05, x, 1.1, z, 16)
	K.cyl("or", 0.035, 0.045, 1.05, x, 0.55, z, 8)
	K.cyl("or", 0.3, 0.34, 0.04, x, 0.02, z, 16)
	K.cyl("or", 0.42, 0.42, 0.02, x, 1.065, z, 16)
	K.cyl("ampoule", 0.03, 0.04, 0.09, x, 1.17, z, 6)
	K.rond(x, z, 0.42, 0.0, 1.1)
