extends RefCounted
## Lot A, zones R-ESCALIER et R-ESCALIER-PALIER (js/zones/a-escalier.js) : le grand escalier double, le bassin
## aux jets chorégraphiés, le mur de cascade. Rectangle [-14, 14] × [-30, -12] ; au nord de z = -25,5, plein.
## Volées en x ∈ [-11, -7] et [7, 11] : départ z = -12 (y 0), palier z ∈ [-19,5 ; -18] (y 3), arrivée
## z = -25,5 (y 6, galerie nord). Chaque volée : vingt marches de 15 cm, et une rampe de collision dessous.

const COTES := [["ouest", -1.0], ["est", 1.0]]


static func construire(K) -> void:
	K.zone_debut("R-ESCALIER")

	# --- sol et murs ---
	K.plan("marbre_creme", -14, 14, -25.5, -12, 0)
	K.dalle(-14, 14, -25.5, -12)
	K.plan("damier", -3, 3, -13.5, -12, 0.002)
	K.seuil(-14, -12, 14, -12)
	K.box("pierre", 28, 6, 0.2, 0, 3, -25.6)
	K.solide(28, 6, 0.2, 0, 3, -25.6)
	K.mur(-13.9, -25.5, -13.9, -12, 5.4, 1, 0, [], "pierre", 1.2, false)
	K.mur(13.9, -25.5, 13.9, -12, 5.4, -1, 0, [{"at": 8.5, "w": 6.0, "h": 3.6}], "pierre", 1.2, false)
	K.cadre(14, -17, PI / 2.0, 6, 3.6)
	K.seuil(14, -20, 14, -14)
	K.texte("THÉÂTRE · PARIS SPORTIFS", 3.2, 0.34, 13.78, 4.1, -17, -PI / 2.0)
	K.box("laque_noire", 0.06, 3.6, 6.0, 14.2, 1.8, -17)
	K.solide(0.3, 3.6, 6.0, 14.3, 1.8, -17)
	for sg in [-1.0, 1.0]:
		var zs := [-14.2, -18.75, -23.3] if sg < 0 else [-13.0, -20.9, -24.4]
		for z in zs:
			K.pilastre(sg * 13.8, z, -sg * PI / 2.0, 5.4)
			K.lanterne(sg * 13.49, 2.8, z, 0.45)
		K.urne(sg * 12.75, -24.6, 1.3)
	for z in [-16.5, -21.0]:
		K.urne(-13.15, z, 1.3)

	# --- les deux volées : marches pleines de marbre, tapis rouge, tringles d'or ---
	for c in COTES:
		var s: float = c[1]
		var x := s * 9.0
		for v in [[-12.0, 0.0], [-19.5, 3.0]]:
			for i in 20:
				var top: float = v[1] + 0.15 * (i + 1)
				var zf: float = v[0] - 0.3 * i
				var zc := zf - 0.15
				K.box("marbre_creme", 4, top, 0.3, x, top / 2.0, zc)
				K.box("coussin", 2.4, 0.012, 0.3, x, top + 0.006, zc)
				K.box("coussin", 2.4, 0.15, 0.012, x, top - 0.075, zf + 0.006)
				K.box("gorge", 3.9, 0.018, 0.012, x, top - 0.016, zf + 0.018)
				K.cyl("or", 0.011, 0.011, 2.52, x, top + 0.022, zf - 0.285, 5, 0, PI / 2.0)
		# Le palier, et sous lui la masse pleine.
		K.box("marbre_creme", 4, 3, 1.5, x, 1.5, -18.75)
		K.box("coussin", 2.4, 0.012, 1.5, x, 3.006, -18.75)
		K.rampe(x, 3.8, -12.0, 0.0, -18.0, 3.0)
		K.dalle(x - 2, x + 2, -19.5, -18.0, 3.0)
		K.rampe(x, 3.8, -19.5, 3.0, -25.5, 6.0)
		# Les limons pleins et leurs balustrades, côté allée et côté bassin.
		for e in [[s * 11.25, -12.0], [s * 6.75, -13.5]]:
			var lx: float = e[0]
			var zs: float = e[1]
			var y0 := (-12.0 - zs) * 0.5 + 0.1
			var pts := [[zs, y0], [-18.0, 3.1], [-19.5, 3.1], [-25.5, 6.1]]
			for i in 3:
				var a: Array = pts[i]
				var b: Array = pts[i + 1]
				# Le limon : un prisme sous la ligne des marches, de l'épaisseur d'un mur.
				var l := Vector2(b[0] - a[0], b[1] - a[1]).length()
				var pente := atan2(b[1] - a[1], -(b[0] - a[0]))
				K.put("marbre_creme", K._box_mesh(0.5, 0.3, l), K.xf(lx, (a[1] + b[1]) / 2.0 - 0.15, (a[0] + b[0]) / 2.0, pente, 0, 0))
				K.balustres(Vector3(lx, a[1], a[0]), Vector3(lx, b[1], b[0]))
			K.obstacle(lx - 0.25, lx + 0.25, -25.5, zs, 0.0, 7.2)
		# Départ : une pile à lanterne côté allée, un lion d'or côté bassin ; palier : deux piles à lanterne.
		var ox := s * 11.25
		K.box("marbre_creme", 0.6, 2.3, 0.6, ox, 1.15, -12.32)
		K.box("or", 0.68, 0.07, 0.68, ox, 2.33, -12.32)
		K.box("marbre_rouge", 0.7, 0.3, 0.7, ox, 0.15, -12.32)
		K.lanterne(ox, 2.45, -12.32, 0.75)
		K.obstacle(ox - 0.32, ox + 0.32, -12.64, -12.02)
		for px in [ox, s * 6.75]:
			K.box("marbre_creme", 0.34, 1.25, 0.34, px, 3.1 + 0.625, -18.75)
			K.box("or", 0.4, 0.05, 0.4, px, 4.375, -18.75)
			K.lanterne(px, 4.5, -18.75, 0.6)
		_lion(K, s * 6.5, -12.8)
		K.obstacle(s * 7.0, s * 11.0, -25.5, -19.6, 0.0, 2.9)

	# --- le bassin aux jets (x ∈ [-6, 6], z ∈ [-25 ; -13,5]) : margelle de marbre noir, 24 jets et un geyser ---
	for r in [[-6.5, 6.5, -13.95, -13.5], [-6.5, 6.5, -25.0, -24.55], [-6.5, -5.55, -24.55, -13.95], [5.55, 6.5, -24.55, -13.95]]:
		K.box("marbre_noir", r[1] - r[0], 0.5, r[3] - r[2], (r[0] + r[1]) / 2.0, 0.25, (r[2] + r[3]) / 2.0)
	K.box("or", 13.04, 0.04, 0.03, 0, 0.42, -13.485)
	K.plan("eau", -5.55, 5.55, -24.55, -13.95, 0.38)
	K.obstacle(-6.5, 6.5, -25.5, -13.5, 0.0, 0.5)
	var liste := []
	for e in [[2.5, 3.4], [4.2, 4.5]]:
		for i in 12:
			var b := deg_to_rad(-80.0 + i * 160.0 / 11.0)
			liste.append({"x": e[0] * sin(b), "z": -19.0 - e[0] * cos(b), "h": e[1], "r": 0.05})
	liste.append({"x": 0.0, "z": -19.0, "h": 5.5, "r": 0.1})
	# La chorégraphie en boucle de 48 s : quatre tableaux de 12 s, fondus d'une seconde (DA § 6.4).
	var tableau := func(n: int, i: int, u: float) -> float:
		var g := i == 24
		var k := i % 12
		match n:
			0: return 0.35 + 0.1 * sin(u * 2.0) if g else 0.5 + 0.5 * sin(TAU * u / 3.0 - k * 0.5)
			1: return 0.2 if g else 0.55 + 0.45 * sin(TAU * u + (i % 2) * PI)
			2:
				var f := fmod(u, 6.0) / 6.0
				return (pow(f / 0.85, 1.4) if f < 0.85 else 1.0 - (f - 0.85) / 0.15) * (1.0 if g else 0.9) + 0.04
		return 0.86 + 0.14 * sin(u * 3.1) if g else 0.42 + 0.06 * sin(u * 2.3 + k)
	K.jets(liste, 0.38, func(i, t):
		var T := fmod(t, 48.0)
		var n := int(T / 12.0)
		var u := T - n * 12.0
		var v: float = tableau.call(n, i, u)
		return v * u + tableau.call((n + 3) % 4, i, u + 12.0) * (1.0 - u) if u < 1.0 else v)
	for i in 3:
		var z: float = [-14.9, -16.1, -17.3][i]
		K.jet_arc(-5.4, 0.42, z, 1.3, z - 0.3, 2.3 - i * 0.25)
		K.jet_arc(5.4, 0.42, z + 0.5, -1.3, z + 0.2, 2.3 - i * 0.25)

	# --- le mur de cascade : onyx rétroéclairé, deux nappes d'eau ---
	K.box("onyx", 12, 5.55, 0.1, 0, 3.225, -25.45)
	for x in [-6.12, 6.12]:
		K.box("or", 0.24, 6, 0.3, x, 3, -25.38)
	K.box("or", 12.5, 0.16, 0.4, 0, 5.94, -25.36)
	K.box("marbre_noir", 12.5, 0.1, 0.3, 0, 5.82, -25.38)
	for x in [-3.0, 0.0, 3.0]:
		K.box("or", 0.07, 5.55, 0.04, x, 3.225, -25.39)
	var nappe := QuadMesh.new()
	nappe.size = Vector2(11.9, 5.33)
	K.put("jet", nappe, K.xf(0, 3.115, -25.33))

	# --- la colonnade colossale prolongée et l'entablement de la nef ---
	for sg in [-1.0, 1.0]:
		K.colonne(sg * 13.3, -21, 1.1, 11.0, true)
		K.entablement(sg * 13.3, -25.5, sg * 13.3, -12, 11)
	K.entablement(-12.75, -25.9, 12.75, -25.9, 11)

	K.lumiere(0, 3.0, -21.5, K.pal.ambre, 2.0, 12.0)
	K.lumiere(0, 4.6, -15, K.pal.lumiere, 1.6, 12.0)
	K.zone_fin()


## Un lion assis stylisé, d'or, sur son piédestal ; il regarde vers le sud (l'atrium).
static func _lion(K, x: float, z: float) -> void:
	var m := "statue_or"
	var y := 0.8
	K.box("marbre_noir", 1.0, 0.75, 1.4, x, 0.375, z)
	K.box("or", 1.06, 0.05, 1.46, x, 0.775, z)
	K.put(m, SphereMesh.new(), K.xf(x, y + 0.36, z - 0.22, -0.35, 0, 0, 0.3, 0.36, 0.42))
	K.put(m, SphereMesh.new(), K.xf(x, y + 0.56, z + 0.12, 0.5, 0, 0, 0.27, 0.44, 0.28))
	K.sph(m, 0.3, x, y + 0.98, z + 0.2, 1.05)
	K.sph(m, 0.2, x, y + 1.0, z + 0.4, 0.95)
	K.box(m, 0.16, 0.12, 0.16, x, y + 0.93, z + 0.58)
	for sg in [-1.0, 1.0]:
		K.cyl(m, 0.07, 0.08, 0.6, x + sg * 0.15, y + 0.3, z + 0.36, 8)
		K.box(m, 0.14, 0.08, 0.22, x + sg * 0.15, y + 0.04, z + 0.42)
		K.sph(m, 0.07, x + sg * 0.16, y + 1.22, z + 0.22)
	K.obstacle(x - 0.5, x + 0.5, z - 0.7, z + 0.7, 0.0, 1.9)
