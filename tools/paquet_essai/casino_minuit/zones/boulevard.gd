extends RefCounted
## Lot E « dehors », zone X-BOULEVARD (js/zones/e-boulevard.js) : les trottoirs, les bordures, Las Vegas
## Boulevard (six voies, chaussée à y = −0,15, plateau piéton surélevé au passage x ∈ [-3, 3]), le terre-plein à
## palmiers, les lampadaires, les garde-corps, les abribus et la station de taxis, les feux tricolores et
## piétons, et le trafic (berlines, taxis, SUV, sportives, limousines, bus), qui s'arrête au feu et tant que le
## joueur est sur le passage. Le passage n'est praticable qu'au bonhomme blanc : des barrières invisibles en
## ferment les bords tant que les voitures ont le vert. Les voitures de luxe garées sous la porte-cochère sont
## dans les mêmes flottes. À la station de taxis d'en face, comme au pupitre du voiturier, on repart à l'aéroport.

const LOT_E := "res://communes/casino_minuit/zones/lot_e.gd"
const SPAN := 330.0
const CW := 3.0
const RAMP := 1.2
## Le cycle des feux (s) : voitures au vert 34, orange 4, rouge intégral 2, piétons 14 et clignotant 6, rouge 2.
const CYCLE := 62.0
const T_Y := 34.0
const T_R := 38.0
const T_W := 40.0
const T_F := 54.0
const T_C := 60.0
## Les voitures de luxe à l'arrêt sous la porte-cochère (e-casino.js, E.park) : type, x, z, cap, peinture.
const GAREES := [["limo", -8.6, 36.6, 0.0, "#0B0B0E"], ["sport", 6.2, 36.7, PI, "#B3121F"], ["suv", 11.6, 36.5, PI, "#EDEAE2"]]
const TYPES := ["berline", "taxi", "suv", "sport", "limo", "bus"]


static func construire(K) -> void:
	var E = load(LOT_E)
	var L: Dictionary = E.LAY
	var RY: float = L.ROAD_Y
	K.zone_debut("X-BOULEVARD")
	_sols(K, E, L, RY)
	_terre_plein(K, E, L, RY)
	_palmiers(K, E, L)
	_lampadaires(K, E, L, RY)
	_abri(K, E, -40, L.CURB0 - 1.7, 0.0, "bus")
	_abri(K, E, 40, L.CURB1 + 1.7, PI, "taxi")
	_abri(K, E, -40, L.CURB1 + 1.7, PI, "bus")
	var feux := _feux(K, E, L)
	_trafic(K, E, L, RY, feux)
	K.zone_fin()


# --- Les sols : trottoirs, parvis des voisins, chaussée, plateau piéton, marquage ---------------------------

static func _sols(K, E, L: Dictionary, RY: float) -> void:
	K.plan("trottoir", -L.XEND - 2, L.XEND + 2, L.WALK0, L.CURB0, 0.003)
	K.plan("trottoir", -L.XEND - 2, -L.LAKE_OUT, L.FACADE, L.WALK0, 0.003)
	K.plan("trottoir", L.LAKE_OUT, L.XEND + 2, L.FACADE, L.WALK0, 0.003)
	K.plan("trottoir", -L.XEND - 2, L.XEND + 2, L.CURB1, L.ARENA, 0.003)
	for s in [-1.0, 1.0]:
		var a: float = s * (L.XEND + 2)
		var b: float = s * SPAN
		K.plan("trottoir", minf(a, b), maxf(a, b), L.CURB0 - 8, L.CURB0, 0.003)
		K.plan("trottoir", minf(a, b), maxf(a, b), L.CURB1, L.CURB1 + 10, 0.003)
	K.plan("asphalte", -SPAN, -CW - RAMP, L.CURB0, L.CURB1, RY)
	K.plan("asphalte", CW + RAMP, SPAN, L.CURB0, L.CURB1, RY)
	# Le plateau surélevé, ses rampes pour les voitures.
	K.box("rouge_sombre", 2 * CW, 0.15, L.CURB1 - L.CURB0, 0, -0.075, (L.CURB0 + L.CURB1) / 2.0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in [-1.0, 1.0]:
		var a: float = s * CW
		var b: float = s * (CW + RAMP)
		K._quad(st, Vector3(a, 0, L.CURB0), Vector3(a, 0, L.CURB1), Vector3(b, RY, L.CURB1), Vector3(b, RY, L.CURB0), Vector3(s * 0.12, 1, 0))
	K.put("asphalte", st.commit())
	# Les zébras, les lignes d'arrêt et de voies, la double ligne jaune au bord du terre-plein.
	for p in [[L.CURB0 + 0.4, L.MED0 - 0.3], [L.MED1 + 0.3, L.CURB1 - 0.4]]:
		var z: float = p[0]
		while z < p[1] - 0.3:
			K.box("blanc", 2 * CW - 0.6, 0.012, 0.55, 0, 0.006, z + 0.275)
			z += 1.0
	K.box("blanc", 0.4, 0.012, L.MED0 - L.CURB0 - 0.3, 5.0, RY + 0.006, (L.CURB0 + L.MED0) / 2.0)
	K.box("blanc", 0.4, 0.012, L.CURB1 - L.MED1 - 0.3, -5.0, RY + 0.006, (L.MED1 + L.CURB1) / 2.0)
	for z in [L.CURB0 + 3.33, L.CURB0 + 6.67, L.MED1 + 3.33, L.MED1 + 6.67]:
		var x := -SPAN
		while x < SPAN:
			if absf(x + 1.5) >= CW + RAMP + 4:
				K.box("blanc", 3, 0.012, 0.13, x + 1.5, RY + 0.006, z)
			x += 9.0
	for s in [-1.0, 1.0]:
		var a: float = s * (CW + RAMP)
		var b: float = s * SPAN
		var c := (a + b) / 2.0
		for z in [L.CURB0 + 0.3, L.CURB1 - 0.3]:
			K.box("blanc", absf(b - a), 0.012, 0.13, c, RY + 0.006, z)
		for z in [L.MED0 - 0.25, L.MED1 + 0.25]:
			K.box("jaune", absf(b - a), 0.012, 0.12, c, RY + 0.006, z - 0.09)
			K.box("jaune", absf(b - a), 0.012, 0.12, c, RY + 0.006, z + 0.09)
	# Les flèches au sol avant le feu.
	for v in E.VOIES:
		var x: float = -v[1] * 18.0
		var d: float = v[1]
		K.box("blanc", 2.6, 0.012, 0.16, x, RY + 0.007, v[0])
		for k in [-1.0, 1.0]:
			K.box("blanc", 0.9, 0.012, 0.14, x + d * 1.1, RY + 0.007, v[0] + k * 0.25, k * d * 0.6)


# --- Bordures, terre-plein planté, garde-corps ------------------------------------------------------

static func _terre_plein(K, E, L: Dictionary, RY: float) -> void:
	var zm: float = (L.MED0 + L.MED1) / 2.0
	for s in [-1.0, 1.0]:
		var a: float = s * CW
		var b: float = s * SPAN
		var c := (a + b) / 2.0
		var w := absf(b - a)
		K.box("bordure", w, 0.17, 0.3, c, -0.07, L.CURB0 + 0.15)
		K.box("bordure", w, 0.17, 0.3, c, -0.07, L.CURB1 - 0.15)
		K.box("bordure", w, 0.38, 0.3, c, 0.04, L.MED0 + 0.15)
		K.box("bordure", w, 0.38, 0.3, c, 0.04, L.MED1 - 0.15)
		K.box("terre_e", w, 0.05, L.MED1 - L.MED0 - 0.6, c, 0.18, zm)
	# Les haies basses du terre-plein.
	var haie := SphereMesh.new()
	haie.radius = 1.0
	haie.height = 2.0
	haie.radial_segments = 7
	haie.rings = 4
	var h := RandomNumberGenerator.new()
	h.seed = 91
	var x := -SPAN + 3.0
	while x < SPAN:
		if absf(x) >= CW + 1.5:
			K.put("feuille_sombre" if h.randf() < 0.3 else "feuille", haie, K.xf(x + h.randf() - 0.5, 0.45, zm + (h.randf() - 0.5) * 1.6, 0, h.randf() * PI, 0, 0.9 + h.randf() * 0.5, 0.45, 0.6 + h.randf() * 0.3))
		x += 3.2
	# Le garde-corps du terre-plein, qui dissuade de traverser hors du passage.
	for s in [-1.0, 1.0]:
		var a: float = s * (CW + 0.6)
		var b: float = s * SPAN
		K.box("acier_sombre", absf(b - a), 0.06, 0.06, (a + b) / 2.0, 1.15, zm)
		K.box("acier_sombre", absf(b - a), 0.05, 0.05, (a + b) / 2.0, 0.7, zm)
		var p := minf(a, b)
		while p <= maxf(a, b):
			K.box("acier_sombre", 0.07, 1.0, 0.07, p, 0.68, zm)
			p += 2.5
	# Les garde-corps décoratifs le long des bordures (sauf au passage, aux abribus, à la station de taxis).
	var trous := [[-CW - 0.8, CW + 0.8], [-46.5, -33.5], [33.5, 46.5]]
	for z in [L.CURB0 - 0.35, L.CURB1 + 0.35]:
		var px: float = -L.XEND
		while px <= L.XEND:
			if not _dans(px, trous):
				K.cyl("laque_noire", 0.05, 0.06, 0.9, px, 0.45, z, 6)
				K.sph("or", 0.07, px, 0.94, z)
				if not _dans(px + 2.0, trous) and px + 2.0 <= L.XEND:
					K.beam("laque_noire", Vector3(px, 0.82, z), Vector3(px + 2.0, 0.82, z), 0.035, 0.035)
			px += 2.0
	# Les bornes du refuge.
	for s in [-1.0, 1.0]:
		for z in [L.MED0 + 0.3, L.MED1 - 0.3]:
			K.cyl("acier_sombre", 0.1, 0.1, 0.9, s * (CW - 0.2), 0.45, z, 8)
			K.cyl("blanc_froid", 0.105, 0.105, 0.06, s * (CW - 0.2), 0.8, z, 8)
			K.rond(s * (CW - 0.2), z, 0.13)


static func _dans(x: float, trous: Array) -> bool:
	for t in trous:
		if x > t[0] and x < t[1]:
			return true
	return false


# --- Les palmiers (instanciés) -----------------------------------------------------------------------

static func _palmiers(K, E, L: Dictionary) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 17
	var liste := []
	var zm: float = (L.MED0 + L.MED1) / 2.0
	var x := -226.0
	while x < 230.0:
		if absf(x) >= 9.0:
			liste.append([x, zm + (r.randf() - 0.5) * 0.8, r.randf() * TAU, (0.85 + r.randf() * 0.35) * 1.15, 0.2])
		x += 11.0
	x = -114.0
	while x <= 114.0:
		if absf(x) >= 9.0 and not (x > -48.0 and x < -32.0):
			liste.append([x, L.CURB0 - 1.2, r.randf() * TAU, 0.85 + r.randf() * 0.35])
		x += 12.0
	x = -108.0
	while x <= 114.0:
		if absf(x) >= 9.0 and not (x > 32.0 and x < 48.0) and not (x > -48.0 and x < -34.0):
			liste.append([x, L.CURB1 + 1.3, r.randf() * TAU, 0.85 + r.randf() * 0.35])
		x += 12.0
	for s in [-1.0, 1.0]:
		x = 64.0
		while x <= 112.0:
			liste.append([s * x, 42.0, r.randf() * TAU, (0.85 + r.randf() * 0.35) * 1.1])
			x += 16.0
	E.palmiers(K, liste)
	for p in liste:
		if p[1] < L.CURB0 or p[1] > L.CURB1:
			K.cyl("pierre_sombre", 0.75, 0.8, 0.14, p[0], 0.07, p[1], 10)
			K.cyl("terre_e", 0.66, 0.66, 0.02, p[0], 0.15, p[1], 10)
			K.rond(p[0], p[1], 0.55)


# --- Les lampadaires, deux lumières au passage piéton -----------------------------------------------------

static func _lampadaires(K, E, L: Dictionary, RY: float) -> void:
	var zm: float = (L.MED0 + L.MED1) / 2.0
	var x := -SPAN + 15.0
	while x < SPAN:
		if absf(x) >= 6.0:
			E.lampadaire(K, x, zm, [-1.0, 1.0], 0.2)
		x += 33.0
	x = -108.0
	while x <= 108.0:
		E.lampadaire(K, x + 6.0, L.CURB0 - 0.9, [1.0])
		K.rond(x + 6.0, L.CURB0 - 0.9, 0.3)
		E.lampadaire(K, x + 18.0, L.CURB1 + 0.9, [-1.0])
		K.rond(x + 18.0, L.CURB1 + 0.9, 0.3)
		x += 36.0
	for p in [[-14.0, zm], [14.0, zm]]:
		K.lumiere(p[0], 8.6, p[1], Color("#FFDDB0"), 1.3, 20.0)


# --- Les abribus (côté casino, x = −40 ; en face, x = −40) et la station de taxis (en face, x = 40) -----------

static func _abri(K, E, x: float, z: float, f: float, tag: String) -> void:
	var s := 1.0 if f == 0.0 else -1.0
	K.box("acier_sombre", 6, 0.12, 2.0, x, 2.65, z)
	K.box("verre_sombre", 6, 0.02, 1.9, x, 2.58, z)
	for dx in [-2.9, 2.9]:
		K.box("acier_sombre", 0.1, 2.6, 0.1, x + dx, 1.3, z - s * 0.85)
	K.box("acier_sombre", 6, 2.2, 0.06, x, 1.4, z - s * 0.9)
	K.box("laque_noire", 1.6, 2.2, 0.2, x + 2.2, 1.3, z - s * 0.7)
	E.ecran(K, x + 2.2, 1.3, z - s * 0.59, 1.4, 1.9, 0.0 if f == 0.0 else PI, E.LED_BLEU, x * 0.1)
	K.box("laque_noire", 3.4, 0.08, 0.45, x - 1.0, 0.48, z - s * 0.55)
	for dx in [-2.4, 0.4]:
		K.box("acier_sombre", 0.06, 0.48, 0.4, x + dx, 0.24, z - s * 0.55)
	K.cyl("acier_sombre", 0.05, 0.05, 3.0, x - 3.4, 1.5, z + s * 0.6, 6)
	K.box("marine", 0.7, 0.5, 0.06, x - 3.4, 2.8, z + s * 0.6)
	E.enseigne(K, "BUS" if tag == "bus" else "TAXI", "#4D7BFF" if tag == "bus" else "#FFC24A", 0.6, 0.3, x - 3.4, 2.8, z + s * 0.64, 0.0 if f == 0.0 else PI, "bloc")
	K.obstacle(x - 3.0, x + 3.0, z - s * 0.95 - 0.08, z - s * 0.95 + 0.08, 0.0, 2.6)
	K.obstacle(x + 1.4, x + 3.0, minf(z - s * 0.8, z - s * 0.6), maxf(z - s * 0.8, z - s * 0.6), 0.0, 2.6)
	K.rond(x - 3.4, z + s * 0.6, 0.15)
	var sieges := []
	for dx in [-2.0, -1.0, 0.0]:
		sieges.append([Vector3(x + dx, 0.5, z - s * 0.52), PI if f == 0.0 else 0.0])
	var attente := []
	for i in 4:
		attente.append([Vector3(x - 2.5 + i * 1.4, 0, z + s * 1.1), PI if f == 0.0 else 0.0])
	var cle := "e_%s_%s" % [tag, "casino" if z < 64.0 else "enface"]
	K.places[cle] = sieges
	K.places[cle + "_attente"] = attente
	if tag == "taxi":
		# La station de taxis : on y repart à l'aéroport, comme au pupitre du voiturier.
		E.enseigne(K, "AÉROPORT · McCARRAN", "#FFE2B4", 3.4, 0.3, x, 2.38, z + s * 1.02, PI, "bloc")
		var a: Area3D = K.interaction("taxi_aeroport", "Prendre un taxi pour l'aéroport", x - 1.0, 1.1, z + s * 1.3, Vector3(6.0, 2.2, 1.6))
		a.set_meta("interact", "sortie")


# --- Les feux : mâts à potence au-dessus des voies, têtes piétons ----------------------------------------

## Les têtes de feux : les boîtiers sont fusionnés ; les lentilles allumées sont cinq MultiMesh (rouge, orange,
## vert des voitures ; main et bonhomme des piétons), que le cycle montre ou cache.
static func _feux(K, E, L: Dictionary) -> Dictionary:
	var lentilles := {"rouge": [], "orange": [], "vert": [], "main": [], "marche": []}
	var tete := func(x: float, y: float, z: float, ry: float) -> void:
		K.box("laque_noire", 0.42, 1.2, 0.36, x, y, z, ry)
		K.box("or", 0.46, 0.04, 0.4, x, y + 0.62, z, ry)
		var o := Vector3(sin(ry), 0, cos(ry)) * 0.2
		lentilles.rouge.append(Vector3(x, y + 0.36, z) + o)
		lentilles.orange.append(Vector3(x, y, z) + o)
		lentilles.vert.append(Vector3(x, y - 0.36, z) + o)
	var pieton := func(x: float, y: float, z: float, ry: float) -> void:
		K.box("laque_noire", 0.4, 0.75, 0.3, x, y, z, ry)
		var o := Vector3(sin(ry), 0, cos(ry)) * 0.17
		lentilles.main.append(Vector3(x, y + 0.17, z) + o)
		lentilles.marche.append(Vector3(x, y - 0.17, z) + o)
	for m in [[-4.4, L.CURB0 - 0.7, 1.0, PI / 2.0], [4.4, L.CURB1 + 0.7, -1.0, -PI / 2.0]]:
		var x: float = m[0]
		var z: float = m[1]
		var dz: float = m[2]
		var ry: float = m[3]
		K.cyl("laque_noire", 0.14, 0.18, 7.2, x, 3.6, z, 10)
		K.cyl("or", 0.22, 0.22, 0.3, x, 0.15, z, 10)
		K.beam("laque_noire", Vector3(x, 6.8, z), Vector3(x, 6.8, z + dz * 10.2), 0.16, 0.2)
		K.beam("laque_noire", Vector3(x, 6.2, z), Vector3(x, 6.75, z + dz * 2.6), 0.06, 0.06)
		for d in [1.7, 5.0, 8.4]:
			tete.call(x, 6.1, z + dz * d, ry)
		E.enseigne(K, "LAS VEGAS BLVD", "#EAF2FF", 2.6, 0.4, x + sin(ry) * 0.04, 7.25, z + dz * 5.4, ry, "bloc")
		K.box("lueur#1F6A3A", 0.04, 0.46, 2.7, x, 7.25, z + dz * 5.4)
		tete.call(x, 3.4, z + dz * 0.25, ry)
		pieton.call(x + 0.25 * signf(-x), 2.6, z, 0.0 if dz > 0.0 else PI)
		K.rond(x, z, 0.25)
	var zm: float = (L.MED0 + L.MED1) / 2.0
	for x in [-CW - 0.35, CW + 0.35]:
		K.cyl("laque_noire", 0.08, 0.1, 3.0, x, 1.5, zm, 8)
		pieton.call(x, 2.6, zm - 0.2, PI)
		pieton.call(x, 2.6, zm + 0.2, 0.0)
	var mats := {"rouge": "rouge_lum", "orange": "ambre_lum", "vert": "vert_lum", "main": "lueur#FF7A1A", "marche": "blanc_froid"}
	var noeuds := {}
	var bille := SphereMesh.new()
	bille.radius = 0.12
	bille.height = 0.24
	bille.radial_segments = 8
	bille.rings = 4
	for k in lentilles:
		var pts: Array = lentilles[k]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = bille
		mm.instance_count = pts.size()
		for i in pts.size():
			mm.set_instance_transform(i, Transform3D(Basis(), pts[i]))
		var mi := MultiMeshInstance3D.new()
		mi.name = "feux_" + k
		mi.multimesh = mm
		mi.material_override = K.mat(mats[k])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		K.zone.add_child(mi)
		noeuds[k] = mi
	return noeuds


# --- Le trafic ------------------------------------------------------------------------------------------

## Une barrière du passage piéton (feu piéton rouge), dont la forme s'active ou non.
static func _barriere(K, z0: float, z1: float) -> CollisionShape3D:
	var corps := StaticBody3D.new()
	corps.position = Vector3(0, 1.2, (z0 + z1) / 2.0)
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(2 * CW, 2.4, absf(z1 - z0))
	f.shape = b
	corps.add_child(f)
	K.zone.add_child(corps)
	return f


static func _trafic(K, E, L: Dictionary, RY: float, feux: Dictionary) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 2026
	var voies := []
	var voitures := []
	for vi in E.VOIES.size():
		var v: Array = E.VOIES[vi]
		var bord: bool = vi == 0 or vi == 5
		var voie := {"z": v[0], "dir": v[1], "cote": "ouest" if v[1] < 0 else "est", "arret_bus": 46.0 if v[1] < 0 else -34.0, "voitures": []}
		var n := 8 if bord else 10
		for k in n:
			var t := r.randf()
			var type := "berline" if t < 0.42 else ("taxi" if t < 0.62 else ("suv" if t < 0.8 else ("sport" if t < 0.88 else ("limo" if t < 0.95 else "berline"))))
			if bord and k % 4 == 1:
				type = "bus"
			var d: Array = E.DIMS[type]
			var peintures: Array = E.PEINTURES[type]
			var c := {"type": type, "len": d[0], "vmax": d[3] * (0.85 + r.randf() * 0.25) * (0.9 if bord else 1.0),
				"s": SPAN - k * (2.0 * SPAN / n) - r.randf() * 12.0, "v": 0.0, "a": 0.0, "voie": voie,
				"couleur": peintures[r.randi() % peintures.size()], "attente": 0.0, "servi": false, "i": 0, "mm": null}
			c.v = c.vmax * 0.8
			voie.voitures.append(c)
			voitures.append(c)
		voie.voitures.sort_custom(func(a, b): return a.s > b.s)
		voies.append(voie)
	# Une flotte par type ; les voitures garées en tête de leur flotte.
	for type in TYPES:
		var roulent := voitures.filter(func(c): return c.type == type)
		var garees := GAREES.filter(func(g): return g[0] == type)
		if roulent.is_empty() and garees.is_empty():
			continue
		var mm: MultiMesh = E.flotte(K, type, roulent.size() + garees.size())
		for i in garees.size():
			var g: Array = garees[i]
			E.garer(K, mm, i, type, g[1], g[2], g[3], g[4])
		for i in roulent.size():
			var c: Dictionary = roulent[i]
			c.i = garees.size() + i
			c.mm = mm
			mm.set_instance_custom_data(c.i, Color(Color(c.couleur).srgb_to_linear(), 0.0))
	var barrieres := {"ouest": [_barriere(K, L.CURB0 - 0.1, L.CURB0 + 0.15), _barriere(K, L.MED0 - 0.15, L.MED0 + 0.1)],
		"est": [_barriere(K, L.MED1 - 0.1, L.MED1 + 0.15), _barriere(K, L.CURB1 - 0.15, L.CURB1 + 0.1)]}
	var zones := {"ouest": [L.CURB0 + 0.05, L.MED0 - 0.05], "est": [L.MED1 + 0.05, L.CURB1 - 0.05]}
	var STOP := CW + RAMP + 1.1
	var etat := {"t": 8.0, "phase": ""}
	K.places["e_feux"] = [etat]
	K.chaque_image(func(dt: float, t: float) -> void:
		dt = minf(dt, 0.05)
		etat.t = fmod(etat.t + dt, CYCLE)
		var tc: float = etat.t
		var ph := "vert" if tc < T_Y else ("orange" if tc < T_R else ("rouge" if tc < T_W else ("pietons" if tc < T_F else ("clignotant" if tc < T_C else "rouge2"))))
		if ph != etat.phase:
			etat.phase = ph
			feux.rouge.visible = ph != "vert" and ph != "orange"
			feux.orange.visible = ph == "orange"
			feux.vert.visible = ph == "vert"
		var marche := tc >= T_W and tc < T_C
		var clin := ph == "clignotant" and fmod(t, 1.0) < 0.5
		feux.main.visible = not marche or clin
		feux.marche.visible = marche and ph != "clignotant"
		# Le joueur sur le passage : sa chaussée est occupée, ses barrières restent ouvertes.
		var occupe := {"ouest": false, "est": false}
		var p = K.racine.get("player")
		if p != null:
			var pp: Vector3 = p.global_position
			for cote in zones:
				var zz: Array = zones[cote]
				occupe[cote] = absf(pp.x) <= CW + 0.3 and pp.z >= zz[0] - 0.05 and pp.z <= zz[1] + 0.05
		for cote in barrieres:
			for f in barrieres[cote]:
				f.disabled = marche or occupe[cote]
		var vert := tc < T_Y
		var orange := tc >= T_Y and tc < T_R
		for voie in voies:
			var arr: Array = voie.voitures
			var n := arr.size()
			var stop_req: bool = not vert or occupe[voie.cote]
			for i in n:
				var c: Dictionary = arr[i]
				var front: float = c.s + c.len / 2.0
				var gap: float
				if i > 0:
					var a: Dictionary = arr[i - 1]
					gap = (a.s - a.len / 2.0) - front
				else:
					var a: Dictionary = arr[n - 1]
					gap = (a.s + 2.0 * SPAN - a.len / 2.0) - front
				# Au feu (ou passage occupé), l'arrêt n'est imposé qu'avant la ligne : une voiture engagée poursuit.
				if front < -STOP + 0.4:
					var d_stop := -STOP - front
					var doit := stop_req
					if doit and orange and not occupe[voie.cote] and c.v * c.v / 9.0 > d_stop:
						doit = false
					if doit:
						gap = minf(gap, d_stop)
				# L'arrêt de bus, sur la voie de bordure : 7 s, une fois par passage.
				if c.type == "bus" and not c.servi:
					var d_bus: float = voie.arret_bus - front
					if d_bus > -0.5 and d_bus < 60.0:
						gap = minf(gap, maxf(0.0, d_bus) + 2.2)
						if d_bus < 1.5 and c.v < 0.3:
							c.attente += dt
							if c.attente > 7.0:
								c.servi = true
								c.attente = 0.0
				var s_star: float = 2.2 + c.v * 1.1
				var acc: float = 2.2 * (1.0 - pow(c.v / c.vmax, 4.0) - (pow(s_star / gap, 2.0) if gap > 0.05 else 99.0))
				acc = clampf(acc, -9.0, 2.2)
				c.v = maxf(0.0, c.v + acc * dt)
				if gap < 0.15:
					c.v = 0.0
				c.a = acc
				c.s += c.v * dt
			# Au bout de la boucle, la voiture de tête repart derrière la dernière, dans le brouillard.
			if arr[0].s > SPAN:
				var c: Dictionary = arr.pop_front()
				var last: Dictionary = arr[arr.size() - 1]
				c.s = minf(-SPAN, last.s - last.len / 2.0 - c.len / 2.0 - 8.0 - r.randf() * 30.0)
				c.servi = false
				arr.push_back(c)
		for c in voitures:
			var voie: Dictionary = c.voie
			var x: float = voie.dir * c.s
			var ax := absf(x)
			var bosse := 0.15 if ax < CW else (0.15 * (CW + RAMP - ax) / RAMP if ax < CW + RAMP else 0.0)
			c.mm.set_instance_transform(c.i, Transform3D(Basis(Vector3.UP, 0.0 if voie.dir > 0 else PI), Vector3(x, RY + bosse, voie.z))))
