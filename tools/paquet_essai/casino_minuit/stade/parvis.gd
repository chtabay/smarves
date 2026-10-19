extends RefCounted
## Le parvis du stade de la Fortune, au sud de la façade (z < -35,5) : le tapis rouge de la station de taxis à la
## porte de verre, ses colonnes de flammes, les deux bassins des fontaines dansantes, la statue de Jackpot, le chat
## noir en smoking, haut de vingt mètres sur sa pile de jetons, les projecteurs qui fouillent le ciel, et autour le
## Strip la nuit et la tour du casino Minuit, d'où l'on vient en taxi.
## Les cotes : la porte à z = -35,5 ; les fontaines de z = -42 à -62 ; Jackpot à z = -70, que le tapis contourne ;
## la station à z = -86.

const LOT_E := "res://communes/casino_minuit/zones/lot_e.gd"

const Z_PORTE := -35.5
const Z_JACKPOT := -70.0
const Z_TAXI := -86.0
## Là où le taxi vous dépose : sous l'auvent de la station, face au stade.
const ARRIVEE := Vector3(0, 0.05, -83.5)


## Tout le parvis ; rend ce qui s'anime : {"yeux": [les yeux de Jackpot], "faisceaux": [pivots], "flammes": [...]}.
static func construire(K) -> Dictionary:
	var E = load(LOT_E)
	var out := {}
	K.zone_debut("FORTUNE-PARVIS")
	_sol(K)
	_tapis(K, out)
	_fontaines(K)
	out.yeux = _jackpot(K)
	_station(K, E)
	E.palmiers(K, _palmiers())
	K.zone_fin()
	K.zone_debut("FORTUNE-CIEL")
	out.faisceaux = _projecteurs(K, E)
	K.zone_fin()
	K.zone_debut("FORTUNE-STRIP")
	_strip(K, E)
	K.zone_fin()
	return out


## Le sol : l'asphalte partout, le marbre noir du parvis, les bordures d'or ; et la dalle où l'on marche.
static func _sol(K) -> void:
	K.plan("asphalte", -160, 160, -170, 70, -0.02)
	K.dalle(-160, 160, -170, 70, 0.0)
	K.plan("marbre_noir", -36, 36, -92, Z_PORTE, 0.0)
	for x in [-36.0, 36.0]:
		K.box("or", 0.3, 0.12, 92.0 + Z_PORTE, x, 0.06, (-92.0 + Z_PORTE) / 2.0)
	K.box("or", 72.3, 0.12, 0.3, 0, 0.06, -92.0)
	# La ronde des taxis, devant la station : l'allée d'asphalte, sa ligne jaune.
	K.plan("trottoir", -36, 36, -92, -89, 0.01)
	K.box("jaune", 60.0, 0.02, 0.15, 0, 0.02, -95.5)


## Le tapis rouge de la station à la porte : il s'ouvre en deux autour de Jackpot et se rejoint entre les
## fontaines ; sa bordure d'or, ses cordons, et de part et d'autre les colonnes de flammes.
static func _tapis(K, out: Dictionary) -> void:
	var E = load(LOT_E)
	# [x0, x1, z0, z1] : l'allée de la station, le tour de la statue (deux bras et leurs traverses), l'allée des fontaines.
	var zs := Z_JACKPOT - 9.0
	var zn := Z_JACKPOT + 7.0
	var pans := [[-3.0, 3.0, Z_TAXI + 1.0, zs], [-11.0, 11.0, zs - 2.4, zs], [-11.0, -8.6, zs, zn], [8.6, 11.0, zs, zn],
		[-11.0, 11.0, zn, zn + 2.4], [-3.0, 3.0, zn + 2.4, Z_PORTE - 0.2]]
	for q in pans:
		K.plan("tapis_rouge", q[0], q[1], q[2], q[3], 0.03)
	for x in [-3.0, 3.0]:
		K.box("or", 0.12, 0.05, zs - 2.4 - Z_TAXI - 1.0, x, 0.04, (Z_TAXI + 1.0 + zs - 2.4) / 2.0)
		K.box("or", 0.12, 0.05, Z_PORTE - zn - 2.4, x, 0.04, (zn + 2.4 + Z_PORTE) / 2.0)
	for x in [-11.0, 11.0]:
		K.box("or", 0.12, 0.05, zn - zs + 4.8, x, 0.04, (zs + zn) / 2.0)
	var pas := []
	for i in 8:
		pas.append(zn + 3.6 + i * 3.4)
	E.cordons(K, -3.6, pas, "z", false)
	E.cordons(K, 3.6, pas, "z", false)
	var feux := []
	for z in [-58.0, -50.0, -42.0, Z_TAXI + 3.5]:
		feux.append(Vector2(-5.2, z))
		feux.append(Vector2(5.2, z))
	for z in [zs + 2.0, zn - 2.0]:
		feux.append(Vector2(-12.6, z))
		feux.append(Vector2(12.6, z))
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0.9, 0.28, 0.04, 0.55)
	var coeur := m.duplicate()
	coeur.albedo_color = Color(0.7, 0.42, 0.08, 0.45)
	var flammes := []
	for p in feux:
		K.cyl("laque_noire", 0.55, 0.75, 1.2, p.x, 0.6, p.y, 12)
		K.cyl("or", 0.7, 0.62, 0.2, p.x, 1.3, p.y, 16)
		K.rond(p.x, p.y, 0.75, 0.0, 1.4)
		for k in 2:
			var f := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.02
			c.bottom_radius = 0.5 if k == 0 else 0.28
			c.height = 1.0
			c.radial_segments = 10
			c.cap_top = false
			c.cap_bottom = false
			f.mesh = c
			f.material_override = m if k == 0 else coeur
			f.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			f.position = Vector3(p.x, 1.4, p.y)
			K.zone.add_child(f)
			flammes.append(f)
	out.flammes = flammes
	K.lumiere(-5.2, 3.0, -50.0, Color("#FF9A40"), 1.6, 14.0)
	K.lumiere(5.2, 3.0, -50.0, Color("#FF9A40"), 1.6, 14.0)
	K.chaque_image(func(_dt, t):
		for i in flammes.size():
			var f: MeshInstance3D = flammes[i]
			var h := (2.0 if i % 2 == 0 else 1.3) + 0.7 * sin(t * 7.0 + i * 1.7) + 0.35 * sin(t * 13.0 + i)
			f.scale = Vector3(1.0 + 0.12 * sin(t * 9.0 + i), h, 1.0 + 0.12 * cos(t * 8.0 + i))
			f.position.y = 1.4 + h / 2.0)


## Les deux bassins des fontaines dansantes, de part et d'autre du tapis : leurs jets montent et retombent en
## vagues, comme au casino.
static func _fontaines(K) -> void:
	for s in [-1.0, 1.0]:
		var x0: float = s * 8.0
		var x1: float = s * 30.0
		var xa := minf(x0, x1)
		var xb := maxf(x0, x1)
		K.plan("eau_nuit", xa, xb, -62.0, -42.0, 0.35)
		for z in [-62.0, -42.0]:
			K.box("marbre_noir", xb - xa + 0.8, 0.6, 0.4, (xa + xb) / 2.0, 0.3, z)
			K.box("or", xb - xa + 0.8, 0.06, 0.44, (xa + xb) / 2.0, 0.62, z)
		for x in [xa, xb]:
			K.box("marbre_noir", 0.4, 0.6, 20.4, x, 0.3, -52.0)
			K.box("or", 0.44, 0.06, 20.4, x, 0.62, -52.0)
		K.obstacle(xa - 0.2, xb + 0.2, -62.2, -41.8, 0.0, 0.8)
		var jets := []
		for i in 9:
			for k in 3:
				jets.append({"x": lerpf(xa + 1.5, xb - 1.5, i / 8.0), "z": -56.5 + k * 4.5, "h": 9.0 if k == 1 else 6.0, "r": 0.09})
		K.jets(jets, 0.35, func(i, t):
			var col: int = i / 3
			return clampf(0.55 + 0.45 * sin(t * 1.6 - col * 0.7 + s), 0.05, 1.0))
		for i in 5:
			K.lumiere(lerpf(xa + 2.0, xb - 2.0, i / 4.0), 0.8, -52.0, Color("#7FD8FF") if i % 2 == 0 else Color("#FFD27A"), 1.2, 9.0)


## Jackpot, le chat noir en smoking, assis sur sa pile de jetons : vingt mètres d'or et de laque. Ses yeux
## s'allument (fortune.gd les fait luire plus fort au but).
static func _jackpot(K) -> Array:
	var z := Z_JACKPOT
	# La pile de jetons, rouge, noir et or, et son socle de marbre.
	K.cyl("marbre_noir", 6.8, 7.0, 0.8, 0, 0.4, z, 32)
	K.cyl("or", 6.9, 6.9, 0.12, 0, 0.86, z, 32)
	K.rond(0, z, 7.0, 0.0, 3.0)
	for i in 8:
		var m: String = ["rouge_e", "laque_noire", "or", "creme"][i % 4]
		K.cyl(m, 5.0 - (i % 2) * 0.05, 5.0 - (i % 2) * 0.05, 0.42, (i % 3) * 0.12 - 0.12, 1.12 + i * 0.44, z + (i % 2) * 0.1, 32)
	var y0 := 1.0 + 8 * 0.44
	K.texte("JACKPOT", 7.0, 1.1, 0, y0 - 1.9, z - 5.08, PI, "neon", Color("#FFD24A"))
	# Le corps assis : une poire noire, le plastron blanc, le nœud papillon rouge, les revers d'or.
	K.sph("laque_noire", 3.6, 0, y0 + 3.4, z + 0.4, 1.25)
	K.sph("laque_noire", 2.2, -2.0, y0 + 1.4, z - 1.6, 0.6)
	K.sph("laque_noire", 2.2, 2.0, y0 + 1.4, z - 1.6, 0.6)
	K.sph("blanc", 2.0, 0, y0 + 4.0, z - 2.1, 1.6)
	for s in [-1.0, 1.0]:
		K.beam("or", Vector3(s * 0.6, y0 + 7.0, z - 2.6), Vector3(s * 1.9, y0 + 2.4, z - 2.4), 0.5, 0.3)
	K.box("rouge_e", 1.8, 0.7, 0.5, 0, y0 + 6.6, z - 3.1)
	K.sph("rouge_e", 0.45, 0, y0 + 6.6, z - 3.35)
	# Les pattes avant, sur la pile ; la queue qui s'enroule en point d'interrogation.
	for s in [-1.0, 1.0]:
		K.cyl("laque_noire", 0.75, 0.9, 3.8, s * 1.3, y0 + 2.0, z - 2.7, 12)
		K.sph("blanc", 0.95, s * 1.3, y0 + 0.4, z - 3.0, 0.6)
	var queue := [Vector3(2.8, y0 + 0.6, z + 2.8), Vector3(4.6, y0 + 1.0, z + 1.5), Vector3(5.4, y0 + 3.0, z), Vector3(5.0, y0 + 5.0, z - 1.0), Vector3(4.0, y0 + 5.6, z - 1.6)]
	for i in queue.size() - 1:
		K.beam("laque_noire", queue[i], queue[i + 1], 0.8, 0.8)
	K.sph("laque_noire", 0.5, queue[-1].x, queue[-1].y, queue[-1].z)
	# La tête, le museau blanc, les oreilles, les moustaches d'or.
	var yt := y0 + 9.6
	K.sph("laque_noire", 2.6, 0, yt, z - 0.6, 0.92)
	K.sph("blanc", 1.1, 0, yt - 0.9, z - 2.9, 0.75)
	K.sph("rose_lum", 0.28, 0, yt - 0.4, z - 3.6)
	for s in [-1.0, 1.0]:
		K.cyl("laque_noire", 0.05, 1.1, 2.2, s * 1.55, yt + 2.3, z - 0.4, 4, 0.0, -s * 0.35)
		K.cyl("rose_lum", 0.02, 0.6, 1.4, s * 1.5, yt + 2.1, z - 0.75, 4, 0.0, -s * 0.35)
		for k in 3:
			K.beam("or", Vector3(s * 0.7, yt - 0.9 + k * 0.25, z - 3.4), Vector3(s * 3.4, yt - 0.6 + k * 0.45, z - 3.0), 0.05, 0.05)
	# Le haut-de-forme, son ruban rouge et sa bordure d'or, posé de travers.
	var hat := Transform3D(Basis.from_euler(Vector3(0, 0, 0.12)), Vector3(0.3, yt + 2.4, z - 0.6))
	K.put("laque_noire", _cyl_mesh(1.9, 1.9, 0.18, 32), hat)
	K.put("laque_noire", _cyl_mesh(1.25, 1.35, 2.8, 24), hat * Transform3D(Basis.IDENTITY, Vector3(0, 1.45, 0)))
	K.put("rouge_e", _cyl_mesh(1.38, 1.38, 0.45, 24), hat * Transform3D(Basis.IDENTITY, Vector3(0, 0.45, 0)))
	K.put("or", _cyl_mesh(1.92, 1.92, 0.06, 32), hat * Transform3D(Basis.IDENTITY, Vector3(0, 0.1, 0)))
	# Le monocle d'or, à l'œil droit.
	K.tore("or", 0.75, 0.08, Transform3D(Basis.from_euler(Vector3(PI / 2.0, 0, 0)), Vector3(-0.95, yt + 0.4, z - 2.85)), 20)
	K.beam("or", Vector3(-1.6, yt, z - 2.8), Vector3(-2.0, yt - 3.2, z - 2.5), 0.03, 0.03)
	# Les yeux : deux amandes d'ambre qui luisent, que fortune.gd fait battre.
	var yeux := []
	for s in [-1.0, 1.0]:
		var oeil := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.55
		sm.height = 1.1
		oeil.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color("#FFC21A")
		m.emission_enabled = true
		m.emission = Color("#FFB000")
		m.emission_energy_multiplier = 3.0
		oeil.material_override = m
		oeil.position = Vector3(s * 0.95, yt + 0.4, z - 2.75)
		oeil.scale = Vector3(1.0, 0.7, 0.4)
		K.zone.add_child(oeil)
		yeux.append(oeil)
	# Éclairée d'en bas, comme les statues du Strip.
	K.lumiere(0, 2.0, z - 9.0, Color("#FFD9A0"), 3.0, 22.0)
	K.lumiere(0, yt + 1.0, z - 7.0, Color("#FFE6C0"), 1.6, 12.0)
	return yeux


static func _cyl_mesh(r_haut: float, r_bas: float, h: float, seg: int) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_haut
	c.bottom_radius = r_bas
	c.height = h
	c.radial_segments = seg
	c.rings = 1
	return c


## La station de taxis, au bout du tapis : l'auvent noir et or sous son enseigne, deux taxis jaunes qui
## attendent et la limousine du président. On y repart vers le casino ou l'aéroport.
static func _station(K, E) -> void:
	var z := Z_TAXI
	K.box("laque_noire", 14.0, 0.5, 5.0, 0, 4.2, z)
	K.box("or", 14.2, 0.16, 5.2, 0, 3.92, z)
	K.box("or", 14.2, 0.16, 5.2, 0, 4.48, z)
	for x in [-6.6, 6.6]:
		for dz in [-2.2, 2.2]:
			K.cyl("or", 0.12, 0.14, 3.9, x, 1.95, z + dz, 10)
			K.rond(x, z + dz, 0.16)
	E.cadre_ampoules(K, 0, 5.4, z + 2.4, 9.0, 1.6, 0.0, 0.18)
	K.box("laque_noire", 9.0, 1.6, 0.2, 0, 5.4, z + 2.3)
	K.texte("TAXIS", 8.0, 1.0, 0, 5.4, z + 2.42, 0.0, "neon", Color("#FFD24A"))
	E.cadre_ampoules(K, 0, 5.4, z - 2.4, 9.0, 1.6, PI, 0.18)
	K.box("laque_noire", 9.0, 1.6, 0.2, 0, 5.4, z - 2.3)
	K.texte("STADE DE LA FORTUNE", 8.4, 0.7, 0, 5.4, z - 2.42, PI, "neon", Color("#FFD24A"))
	K.plan("ampoule", -6.8, 6.8, z - 2.4, z + 2.4, 3.83, false)
	K.lumiere(0, 3.4, z, Color("#FFE2B0"), 1.8, 10.0)
	# Les voitures : deux taxis le long de la ronde, la limousine noire au bout.
	var taxis = E.flotte(K, "taxi", 2)
	E.garer(K, taxis, 0, "taxi", -4.0, z - 6.6, PI / 2.0, "#F2C12E")
	E.garer(K, taxis, 1, "taxi", 2.0, z - 6.6, PI / 2.0, "#F2C12E")
	var limo = E.flotte(K, "limo", 1)
	E.garer(K, limo, 0, "limo", 14.0, z - 6.6, PI / 2.0, "#0B0B0E")
	# La borne : un pupitre d'or où un voiturier en livrée appelle la voiture.
	K.box("laque_noire", 1.2, 1.1, 0.7, -1.8, 0.55, z - 2.6)
	K.box("or", 1.3, 0.06, 0.8, -1.8, 1.12, z - 2.6)
	K.obstacle(-2.4, -1.2, z - 2.95, z - 2.25, 0.0, 1.1)
	K.interaction("taxi", "E : prendre un taxi", 0, 1.1, z - 3.0, Vector3(10.0, 2.2, 3.6))


static func _palmiers() -> Array:
	var out := []
	for i in 7:
		var z := -40.0 - i * 7.5
		for s in [-1.0, 1.0]:
			out.append([s * 33.0, z, i * 0.9 + s, 1.05 + fmod(i * 0.37, 0.3)])
	for x in [-24.0, -12.0, 12.0, 24.0]:
		out.append([x, -88.5, x * 0.1, 1.1])
	return out


## Six projecteurs qui fouillent le ciel depuis les coins du parvis, et deux depuis le dos de Jackpot.
static func _projecteurs(K, E) -> Array:
	var pivots := []
	var pieds := [Vector3(-34, 0.4, -40), Vector3(34, 0.4, -40), Vector3(-34, 0.4, -90), Vector3(34, 0.4, -90), Vector3(-6, 0.4, -77), Vector3(6, 0.4, -77)]
	for i in pieds.size():
		var p: Vector3 = pieds[i]
		K.cyl("acier_sombre", 0.7, 0.9, 0.8, p.x, 0.4, p.z, 12)
		var mi: MeshInstance3D = E.faisceau(K, Color("#FFF2D8") if i % 2 == 0 else Color("#BFD8FF"), 0.35, 160.0, 4.0, 0.6)
		var pivot: Node3D = mi.get_parent()
		pivot.position = p + Vector3(0, 0.6, 0)
		pivot.set_meta("phase", i * 1.1)
		pivots.append(pivot)
	K.chaque_image(func(_dt, t):
		for pv in pivots:
			var ph: float = pv.get_meta("phase")
			# Le cylindre descend du pivot : renversé, il monte ; il balance de part et d'autre de la verticale.
			pv.rotation = Vector3(PI + 0.35 * sin(t * 0.37 + ph), 0, 0.4 * sin(t * 0.23 + ph * 1.7)))
	return pivots


## Le Strip la nuit tout autour, ses hôtels en blocs et leurs enseignes au sud ; au sud-ouest, la tour du casino
## Minuit et sa couronne rouge, celle qu'on voit depuis le boulevard.
static func _strip(K, E) -> void:
	for c in [[Vector3(0, 30, 165), PI, 330.0], [Vector3(0, 30, -168), 0.0, 330.0], [Vector3(158, 30, 0), -PI / 2.0, 340.0], [Vector3(-158, 30, 0), PI / 2.0, 340.0]]:
		var q := QuadMesh.new()
		q.size = Vector2(c[2], 64.0)
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = K.mat("strip")
		mi.position = c[0]
		mi.rotation.y = c[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		K.zone.add_child(mi)
	# Les hôtels du Strip, au-delà de la ronde des taxis.
	var hotels := [[-70.0, -40.0, 46.0, E.HOTEL, "THE ROYALE", "#FFD24A"], [-30.0, -8.0, 32.0, E.VERRE, "OASIS", "#7FD8FF"],
		[8.0, 34.0, 58.0, E.DORE, "EL DORADO", "#FFB347"], [44.0, 76.0, 38.0, E.BALCONS, "FLAMINGO BAY", "#FF6FAE"]]
	for h in hotels:
		E.bloc(K, h[0], h[1], -132.0, -112.0, 0.0, h[2], h[3], "neo", Color("#2C2620"))
		E.enseigne(K, h[4], h[5], (h[1] - h[0]) * 0.8, 3.2, (h[0] + h[1]) / 2.0, h[2] - 3.0, -111.9, 0.0)
		E.ecran(K, (h[0] + h[1]) / 2.0, 8.0, -111.85, (h[1] - h[0]) * 0.6, 6.0, 0.0, [E.LED_ROSE, E.LED_CYAN, E.LED_REVUE, E.LED_ROUGE][hotels.find(h)], hotels.find(h) * 2.0)
	# La tour Minuit, au sud-ouest : son fût, sa couronne rouge, son nom.
	E.bloc(K, -118.0, -100.0, -104.0, -86.0, 0.0, 84.0, E.TOUR, "sneo", Color("#1A0A0E"))
	K.box("laque_noire", 19.0, 5.0, 19.0, -109.0, 86.5, -95.0)
	K.box("rouge_lum", 19.2, 0.25, 19.2, -109.0, 84.1, -95.0)
	E.enseigne(K, "MINUIT", "#FF3348", 16.0, 3.8, -99.4, 86.5, -95.0, PI / 2.0)
	E.enseigne(K, "MINUIT", "#FF3348", 16.0, 3.8, -109.0, 86.5, -85.4, 0.0)
