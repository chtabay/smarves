extends RefCounted
## Lot A, zone R-ROTONDE (js/zones/a-rotonde.js) : la rotonde d'entrée à coupole et la fontaine de la
## Fortune. Rectangle [-10, 10] × [12, 30], tambour de rayon 8 m centré en (0, 21). Angles « boussole » :
## 0 = nord (vers l'atrium), π/2 = est, π = sud (l'entrée), 3π/2 = ouest.

const CX := 0.0
const CZ := 21.0
const R := 8.0
## Les quatre portails : demi-largeur de l'échancrure du tambour, distance du mur de fond, hauteur.
const AXES := [
	{"b": 0.0, "hw": 3.4, "D": 9.0, "H": 10.3},
	{"b": PI / 2.0, "hw": 2.9, "D": 10.0, "H": 5.0},
	{"b": PI, "hw": 3.4, "D": 9.0, "H": 4.2},
	{"b": 3.0 * PI / 2.0, "hw": 2.9, "D": 10.0, "H": 5.0},
]
const COL := 28.0 * PI / 180.0
const NICHE := 8.5 * PI / 180.0


static func pt(b: float, r: float) -> Vector2:
	return Vector2(CX + r * sin(b), CZ - r * cos(b))


## Un point dans le repère d'un portail : lat le long du mur, depth vers le dehors.
static func _p(a: Dictionary, lat: float, depth: float) -> Vector2:
	return Vector2(CX + sin(a.b) * depth + cos(a.b) * lat, CZ - cos(a.b) * depth + sin(a.b) * lat)


static func construire(K) -> void:
	K.zone_debut("R-ROTONDE")
	var NH := asin(0.7 / R)

	# --- sol : damier, rosace de mosaïque ; dalles praticables ---
	K.plan("damier", -10, 10, 12, 30, 0)
	K.disque("rosace", CX, CZ, 6.55, 0.004, 72)
	K.dalle(-10, 10, 12, 30)

	# --- tambour : lambris de marbre, pierre, niches à statues ---
	var niches := []
	for k in 4:
		var a: Dictionary = AXES[k]
		var n: Dictionary = AXES[(k + 1) % 4]
		var ha := asin(a.hw / R)
		var nha := asin(n.hw / R)
		var s0: float = a.b + ha
		var s1: float = a.b + PI / 2.0 - nha
		var dg: float = a.b + PI / 4.0
		var n1 := dg - NICHE
		var n2 := dg + NICHE
		K.arc("marbre_creme", CX, CZ, R - 0.06, s0, s1, 0.14, 1.2)
		K.arc("marbre_noir", CX, CZ, R - 0.08, s0, s1, 0.0, 0.14)
		K.arc("or", CX, CZ, R - 0.09, s0, s1, 1.17, 1.25)
		K.arc("pierre_haute", CX, CZ, R, s0, s1, 4.0, 9.5)
		for r in [[s0, n1 - NH], [n1 + NH, n2 - NH], [n2 + NH, s1]]:
			K.arc("pierre", CX, CZ, R, r[0], r[1], 1.2, 4.0)
		K.arc("or", CX, CZ, R - 0.03, s0, s1, 4.55, 4.67)
		niches.append(n1)
		niches.append(n2)
		# Le tambour arrête le pas : des segments le long de l'arc.
		var pas := (s1 - s0) / 5.0
		for i in 5:
			var p := pt(s0 + i * pas, R + 0.14)
			var q := pt(s0 + (i + 1) * pas, R + 0.14)
			K.segment(p.x, p.y, q.x, q.y, 0.16, 0.0, 9.5)
	# Les coins du carré hors du cercle : comblés, pour ne pas se perdre derrière le tambour.
	for x in [-9.0, 9.0]:
		for z in [13.0, 29.0]:
			K.obstacle(x - 1.0, x + 1.0, z - 1.0, z + 1.0)
	var attributs := ["amphore", "corne", "", "roue"]
	for i in niches.size():
		var b: float = niches[i]
		var dx := sin(b)
		var dz := -cos(b)
		var lx := cos(b)
		var lz := sin(b)
		var dc := R * cos(NH)
		var ox := CX + dx * dc
		var oz := CZ + dz * dc
		# Le creux de la niche (demi-cylindre et cul-de-four), tendu de velours rouge.
		var face := atan2(-dx, -dz)
		K.bande("coussin", ox, oz, [0.7, 0.7, 1.2], [0.7, 0.7, 3.3], b - PI / 2.0, b + PI / 2.0, "in")
		for q in 4:
			var f0 := PI / 2.0 * q / 4.0
			var f1 := PI / 2.0 * (q + 1) / 4.0
			K.bande("coussin", ox, oz, [0.7 * cos(f0), 0.7 * cos(f0), 3.3 + 0.7 * sin(f0)], [0.7 * cos(f1), 0.7 * cos(f1), 3.3 + 0.7 * sin(f1)], b - PI / 2.0, b + PI / 2.0, "in")
		K.put("or", K._arc_or(0.7, 0.8, 0.08, 12), K.xf(ox - dx * 0.02, 3.3, oz - dz * 0.02, 0, face))
		for sg in [-1.0, 1.0]:
			K.box("or", 0.1, 2.1, 0.08, ox + lx * sg * 0.75 - dx * 0.02, 2.25, oz + lz * sg * 0.75 - dz * 0.02, face)
		var sp := pt(b, R + 0.4)
		K.statue(sp.x, sp.y, 2.0, 1.2, -b, "marbre_creme", attributs[i % 4])

	# --- portails : échancrures du tambour, plafonds, attiques, murs de fond percés ---
	for k in 4:
		var a: Dictionary = AXES[k]
		var dc := sqrt(R * R - a.hw * a.hw)
		var d1: float = a.D - 0.2
		var y1: float = a.H
		var ry_prof := atan2(cos(a.b), sin(a.b))
		var ry_face := atan2(-sin(a.b), cos(a.b))
		for sg in [-1.0, 1.0]:
			var p0 := _p(a, sg * a.hw, dc)
			var p1 := _p(a, sg * a.hw, d1)
			var m := (p0 + p1) / 2.0
			var l := p0.distance_to(p1)
			K.box("pierre", l, y1, 0.2, m.x + cos(a.b) * sg * 0.1, y1 / 2.0, m.y + sin(a.b) * sg * 0.1, ry_prof)
			var lm := _p(a, sg * (a.hw - 0.03), (dc + d1) / 2.0)
			K.box("marbre_creme", l, 1.2, 0.05, lm.x, 0.6, lm.y, ry_prof)
			K.box("or", l, 0.07, 0.07, lm.x, 1.21, lm.y, ry_prof)
			K.segment(p0.x, p0.y, p1.x, p1.y, 0.2, 0.0, y1)
		var c0 := _p(a, 0.0, (dc + d1) / 2.0)
		K.box("pierre", 2.0 * a.hw, 0.2, d1 - dc, c0.x, y1 + 0.1, c0.y, ry_face)
		if y1 < 9.5:
			var ca := _p(a, 0.0, dc)
			K.box("pierre", 2.0 * a.hw, 9.5 - y1, 0.2, ca.x, (y1 + 9.5) / 2.0, ca.y, ry_face)
			var mo := _p(a, 0.0, dc - 0.03)
			K.box("or", 2.0 * a.hw, 0.1, 0.1, mo.x, y1 + 0.05, mo.y, ry_face)
		var mid := _p(a, 0.0, a.D)
		match k:
			0:
				# Nord : la grande arche de 6 m vers l'atrium, et au-dessus la baie de vue de la galerie.
				K.box("pierre", 0.4, y1, 0.2, -a.hw + 0.2, y1 / 2.0, 12.1)
				K.box("pierre", 0.4, y1, 0.2, a.hw - 0.2, y1 / 2.0, 12.1)
				K.box("pierre", 6.0, 1.0, 0.2, 0.0, 5.5, 12.1)
				K.box("pierre", 6.0, 0.3, 0.2, 0.0, 10.15, 12.1)
				K.arche(0.0, 12.0, 0.0, 6.0, 5.0)
				K.box("or", 6.8, 0.08, 0.1, 0.0, 5.08, 12.24)
				K.box("or", 6.8, 0.08, 0.1, 0.0, 5.96, 12.24)
				K.texte("CASINO MINUIT", 5.2, 0.74, 0.0, 5.52, 12.215, 0.0, "neon")
				K.seuil(-3, 12, 3, 12)
			2:
				# Sud : l'entrée principale, une baie de 6 × 3,6 m.
				K.mur(-a.hw, 29.9, a.hw, 29.9, y1, 0, -1, [{"at": a.hw, "w": 6.0, "h": 3.6}], "pierre", 0.0, false)
				K.cadre(0.0, 29.9, 0.0, 6.0, 3.6, 0.3)
			_:
				var w0 := _p(a, -a.hw, a.D - 0.1)
				var w1 := _p(a, a.hw, a.D - 0.1)
				K.mur(w0.x, w0.y, w1.x, w1.y, y1, -sin(a.b), cos(a.b), [{"at": a.hw, "w": 5.0, "h": 4.6}], "pierre", 0.0, false)
				K.arche(mid.x, mid.y, PI / 2.0, 5.0, 4.6)
				K.seuil(mid.x, mid.y - 2.5, mid.x, mid.y + 2.5)
				# À l'ouest, le lobby de l'hôtel (lot B) ; à l'est, le club Minuit (lot C).
	# Les inscriptions des attiques.
	for e in [[3, "HÔTEL · RÉCEPTION"], [1, "CLUB MINUIT · CAISSE"], [2, "BONNE FORTUNE"]]:
		var a: Dictionary = AXES[e[0]]
		var m := _p(a, 0.0, sqrt(R * R - a.hw * a.hw) - 0.02)
		K.texte(e[1], 4.6, 0.5, m.x, a.H + 0.75, m.y, atan2(-sin(a.b), cos(a.b)), "grave")

	# --- colonnade : 8 colonnes par paires autour des portails, lanternes ---
	for a in AXES:
		for d in [-COL, COL]:
			var p := pt(a.b + d, 7.15)
			K.colonne(p.x, p.y, 0.95, 9.5)
			var q := pt(a.b + d, 6.42)
			K.lanterne(q.x, 2.9, q.y, 0.5)

	# --- entablement circulaire et coupole peinte ---
	K.anneau("pierre_haute", CX, CZ, 6.5, R, 9.5, 0.0, TAU, false)
	K.arc("pierre_haute", CX, CZ, 6.5, 0.0, TAU, 9.5, 9.95)
	K.arc("or", CX, CZ, 6.47, 0.0, TAU, 9.93, 10.0)
	K.arc("marbre_rouge", CX, CZ, 6.5, 0.0, TAU, 9.99, 10.55)
	K.bande("pierre_haute", CX, CZ, [6.5, 6.5, 10.55], [6.15, 6.15, 10.78], 0.0, TAU, "down")
	K.arc("pierre_haute", CX, CZ, 6.15, 0.0, TAU, 10.78, 11.0)
	K.arc("gorge", CX, CZ, 6.46, 0.0, TAU, 10.5, 10.55)
	K.arc("gorge", CX, CZ, 7.9, 0.0, TAU, 9.4, 9.46)
	for i in 12:
		# La frise « FORTVNA · AVDACES · IVVAT » : douze cartouches autour de l'entablement.
		var b := TAU * i / 12.0
		var p := pt(b, 6.42)
		K.texte(["FORTVNA", "AVDACES", "IVVAT"][i % 3], 2.6, 0.4, p.x, 10.27, p.y, -b, "grave")
	K.coupole(CX, 11.0, CZ, 7.0, 6.0, 1.3)
	K.lustre_anneau(CX, 8.7, CZ, 2.2, 7.1)

	# --- fontaine de la Fortune ---
	K.bande("marbre_noir", CX, CZ, [3.05, 3.05, 0.0], [3.0, 3.0, 0.55], 0.0, TAU, "out")
	K.anneau("marbre_noir", CX, CZ, 2.55, 3.0, 0.55)
	K.arc("marbre_noir", CX, CZ, 2.55, 0.0, TAU, 0.3, 0.55)
	K.bande("or", CX, CZ, [3.04, 3.04, 0.44], [3.03, 3.03, 0.5], 0.0, TAU, "out")
	K.disque("eau", CX, CZ, 2.55, 0.42, 40)
	K.cyl("marbre_noir", 0.95, 1.05, 0.5, CX, 0.25, CZ, 20)
	K.put("marbre_creme", K.lathe([[0.72, 0.98], [1.02, 1.1], [1.3, 1.3], [1.4, 1.5], [1.32, 1.53], [1.22, 1.46], [0.68, 1.3], [0.72, 0.98]], 28), K.xf(CX, 0, CZ))
	K.tore("or", 1.4, 0.035, K.xf(CX, 1.5, CZ), 32)
	K.put("nappe", K.lathe([[1.46, 0.42], [1.38, 1.5]], 28), K.xf(CX, 0, CZ))
	K.put("marbre_creme", K.lathe([[0.7, 0.5], [0.52, 0.62], [0.48, 1.0], [0.44, 1.5], [0.42, 2.12], [0.52, 2.2], [0.66, 2.26], [0.66, 2.4]], 20), K.xf(CX, 0, CZ))
	K.cyl("marbre_rouge", 0.64, 0.66, 0.12, CX, 2.46, CZ, 20)
	K.cyl("or", 0.69, 0.69, 0.05, CX, 2.4, CZ, 20)
	K.cyl("or", 0.48, 0.48, 0.05, CX, 1.72, CZ, 20)
	_fortune(K, CX, 2.52, CZ)
	for i in 4:
		# Les dauphins d'or au pied de la vasque.
		var b := PI / 4.0 + i * PI / 2.0
		var p := pt(b, 0.98)
		K.tore("statue_or", 0.34, 0.1, K.xf(p.x, 0.62, p.y, PI / 2.0, PI / 2.0 - b, 0), 9)
		K.sph("statue_or", 0.15, p.x + cos(b) * 0.34, 0.62, p.y + sin(b) * 0.34)
	for i in 8:
		var b := i * PI / 4.0
		var p := pt(b, 2.42)
		var q := pt(b, 1.15)
		K.jet_arc(p.x, 0.52, p.y, q.x, q.y, 1.25, 0.03)
	var liste := []
	for i in 8:
		var p := pt(PI / 8.0 + i * PI / 4.0, 1.95)
		liste.append({"x": p.x, "z": p.y, "h": 1.5, "r": 0.045})
	K.jets(liste, 0.42, func(i, t): return 0.55 + 0.45 * sin(t * 1.7 - i * PI / 4.0))
	K.rond(CX, CZ, 3.2)

	# --- entrée principale : porte-tambour tournante, vantaux vitrés, le Strip derrière ---
	K.box("marbre_noir", 7.0, 0.01, 1.2, 0, 0.01, 30.2)
	for r in [[PI / 4.0 + 0.12, 3.0 * PI / 4.0 - 0.12], [5.0 * PI / 4.0 + 0.12, 7.0 * PI / 4.0 - 0.12]]:
		K.bande("verre", 0, 29.6, [0.92, 0.92, 0.05], [0.92, 0.92, 2.5], r[0], r[1], "out", 0.0, 0.2)
	K.cyl("marbre_noir", 0.98, 0.98, 0.3, 0, 2.65, 29.6, 24)
	K.cyl("or", 1.0, 1.0, 0.05, 0, 2.5, 29.6, 24)
	K.cyl("or", 1.0, 1.0, 0.05, 0, 2.82, 29.6, 24)
	K.cyl("or", 0.035, 0.035, 2.5, 0, 1.25, 29.6, 8)
	for sg in [-1.0, 1.0]:
		K.box("or", 0.07, 2.56, 0.08, sg * 1.0, 1.28, 29.88)
	K.box("verre", 5.9, 1.0, 0.03, 0, 3.05, 29.88)
	K.box("or", 5.9, 0.08, 0.1, 0, 2.54, 29.88)
	K.texte("SORTIE · LAS VEGAS BOULEVARD", 3.6, 0.36, 0, 3.05, 29.84, PI, "neon", K.pal.or_clair)
	var tourniquet := MeshInstance3D.new()
	var vantaux := BoxMesh.new()
	vantaux.size = Vector3(1.74, 2.4, 0.03)
	tourniquet.mesh = vantaux
	tourniquet.material_override = K.mat("verre")
	tourniquet.position = Vector3(0, 1.25, 29.6)
	var vantail2 := MeshInstance3D.new()
	vantail2.mesh = vantaux
	vantail2.material_override = K.mat("verre")
	vantail2.rotation.y = PI / 2.0
	tourniquet.add_child(vantail2)
	K.zone.add_child(tourniquet)
	K.chaque_image(func(dt, _t): tourniquet.rotation.y += dt * 0.55)
	# Le tambour tourne au milieu ; on passe de part et d'autre, sur le parvis du Strip (lot E, facade.gd).
	K.rond(0, 29.6, 0.96)

	# --- bancs courbes contre le tambour, sous les niches ---
	for k in 4:
		var b := PI / 4.0 + k * PI / 2.0
		var h := 0.19
		K.bande("marbre_creme", CX, CZ, [7.22, 7.22, 0.0], [7.22, 7.22, 0.42], b - h, b + h, "in")
		K.anneau("coussin", CX, CZ, 7.22, 7.9, 0.47, b - h + 0.012, b + h - 0.012)
		K.arc("coussin", CX, CZ, 7.2, b - h + 0.012, b + h - 0.012, 0.4, 0.47)
		for sg in [-1.0, 1.0]:
			var e := pt(b + sg * h, 7.56)
			K.box("marbre_creme", 0.16, 0.66, 0.74, e.x, 0.33, e.y, -b)
			K.sph("or", 0.07, e.x - sin(b) * 0.3, 0.73, e.y + cos(b) * 0.3)
		for i in [-1, 0, 1]:
			var c := pt(b + i * 0.13, 7.6)
			K.rond(c.x, c.y, 0.42, 0.0, 0.5)

	# --- lumière : le lustre sous l'oculus, la face de la fontaine, le portail nord ---
	K.lumiere(CX, 6.4, CZ, K.pal.lumiere, 2.2, 14.0)
	K.lumiere(0, 3.2, 25.4, K.pal.lumiere, 1.4, 10.0)
	K.lumiere(0, 3.6, 14.6, K.pal.ambre, 1.2, 9.0)
	K.zone_fin()


## La Fortune (statue d'or, ~3,1 m) : robe drapée, buste, tête à chignon et diadème, couronne de laurier
## levée de la main droite, roue tenue de la main gauche. Regarde vers l'entrée (+Z). (x, y, z) = pied.
static func _fortune(K, x: float, y: float, z: float) -> void:
	var m := "statue_or"
	K.put(m, K.lathe([[0.6, 0.0], [0.56, 0.06], [0.47, 0.3], [0.4, 0.75], [0.35, 1.15], [0.36, 1.45], [0.3, 1.72], [0.31, 1.95], [0.36, 2.2], [0.33, 2.36], [0.16, 2.48], [0.1, 2.6]], 14), K.xf(x, y, z))
	K.sph(m, 0.19, x, y + 2.78, z, 1.18)
	K.sph(m, 0.13, x, y + 2.86, z - 0.17)
	K.cyl(m, 0.2, 0.19, 0.05, x, y + 2.88, z + 0.02, 12)
	for i in range(-2, 3):
		K.box(m, 0.035, 0.12 - absi(i) * 0.02, 0.03, x + i * 0.075, y + 2.96, z + 0.17 - absi(i) * 0.03)
	for i in 9:
		var a := TAU * i / 9.0 + 0.3
		K.beam(m, Vector3(x + sin(a) * 0.56, y + 0.04, z + cos(a) * 0.56), Vector3(x + sin(a) * 0.36, y + 1.3, z + cos(a) * 0.36), 0.07, 0.05)
	K.tore(m, 0.31, 0.035, K.xf(x, y + 1.74, z), 14)
	K.sph(m, 0.12, x - 0.34, y + 2.3, z)
	K.sph(m, 0.12, x + 0.34, y + 2.3, z)
	K.beam(m, Vector3(x - 0.34, y + 2.3, z), Vector3(x - 0.62, y + 2.62, z + 0.22), 0.1, 0.1)
	K.beam(m, Vector3(x - 0.62, y + 2.62, z + 0.22), Vector3(x - 0.66, y + 3.08, z + 0.36), 0.085, 0.085)
	K.tore(m, 0.2, 0.04, K.xf(x - 0.66, y + 3.24, z + 0.4, 0.5, 0, 0), 14)
	K.beam(m, Vector3(x + 0.34, y + 2.3, z), Vector3(x + 0.56, y + 1.75, z + 0.16), 0.1, 0.1)
	K.beam(m, Vector3(x + 0.56, y + 1.75, z + 0.16), Vector3(x + 0.74, y + 1.32, z + 0.2), 0.085, 0.085)
	var roue = K.xf(x + 0.78, y + 0.86, z + 0.22, PI / 2.0, 0.25, 0)
	K.tore(m, 0.45, 0.045, roue, 22)
	for i in 4:
		K.put(m, K._box_mesh(0.86, 0.04, 0.04), K.xf(x + 0.78, y + 0.86, z + 0.22, 0, 0.25, i * PI / 4.0))
