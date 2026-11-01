extends RefCounted
## Le jardin du 10 place Adrien-Bernard, derrière la maison aux volets blancs, d'après la vue aérienne
## (l'emprise relevée point par point), les photos de Guillaume et OpenStreetMap. Un grand jardin en pente
## douce vers le nord-est, qu'on contemple depuis la terrasse au dos de la maison : en contrebas le bassin
## en haricot à rebord de ciment, ses nénuphars et ses iris, la roue de fer et le cornouiller panaché ; la
## pelouse et son allée tondue ; à droite le grand cèdre bleu au tronc énorme et le verger de pommiers ; au
## fond le séquoia (30 m mesurés), l'épicéa, un second cèdre bleu, des bouleaux, un hêtre pourpre, et le
## petit sous-bois dont les arbres couvrent la ruelle qui longe le jardin ; les rosiers et les pivoines au
## pied de la terrasse, le vieux portique rouillé contre le mur de pierre, l'abri couvert au bout de
## l'allée, le portillon de l'angle nord-est sur le chemin.
##
## Toutes les mesures sont en unités du bourg (2,4 m). construire(c, f, parent) reçoit la scène du bourg.

const M := 1.0 / 2.4
const BUGEY := "res://bibliotheque/vegetation-du-bugey/1/plante.tscn"
const LYON := "res://bibliotheque/vegetation-lyonnaise/1/plante.tscn"
const PLACE := "res://bibliotheque/arbres-de-place/1/arbre.tscn"

## L'emprise du jardin, relevée sur la vue aérienne : du coin nord de la maison, le long de la rue, de la
## ruelle au nord, puis les limites est et sud, jusqu'au dos de la maison.
const EMPRISE := [
	Vector2(-17.4, -25.2), Vector2(-19.1, -31.8), Vector2(-13.8, -35.0), Vector2(-9.6, -37.7),
	Vector2(0.5, -43.3), Vector2(5.1, -45.9), Vector2(6.6, -39.8), Vector2(8.3, -34.0),
	Vector2(4.4, -31.0), Vector2(-2.0, -27.1), Vector2(-7.6, -23.6), Vector2(-10.5, -22.6),
	Vector2(-11.0, -24.2), Vector2(-13.9, -24.6), Vector2(-15.4, -25.4),
]
## Les côtés de l'emprise qui ont un mur de pierre (index du premier point) : la ruelle et les voisins.
const MURS := [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]

## La terrasse au dos de la maison : son origine au pied du mur, +X le long de la maison, +Z vers le jardin.
const TERRASSE_O := Vector2(-12.79, -24.69)
const TERRASSE_U := Vector2(0.951, -0.308)
const TERRASSE_L := 4.6
const TERRASSE_P := 2.0

## Le bassin, en contrebas de la terrasse.
const BASSIN := Vector2(-9.2, -28.3)
const BASSIN_ROT := 0.45

## L'allée tondue, de l'escalier de la terrasse au sous-bois.
const ALLEE := [Vector2(-9.9, -25.9), Vector2(-7.0, -30.6), Vector2(-4.6, -33.6), Vector2(-2.9, -36.5)]

## L'abri couvert, au bout de l'allée, à l'endroit du petit toit que montre le plan.
const ABRI := Vector2(-2.0, -37.7)

## Le portillon : le côté de l'emprise (index du premier point) et sa place, comptée depuis le bout du
## côté (l'angle nord-est).
const PORTILLON_COTE := 4
const PORTILLON := [0.42, 0.95]

## La lisière du sous-bois : de la rue à l'angle nord-ouest, puis le long de la ruelle.
const SOUS_BOIS := [Vector2(-18.3, -28.2), Vector2(-19.1, -31.8), Vector2(-13.8, -35.0), Vector2(-9.6, -37.7), Vector2(0.5, -43.3), Vector2(5.1, -45.9)]

## Le feuillage : une carte de touffe pour combien de feuilles comptées, et sa taille en longueurs de feuille.
const CARTES := 0.5
const TAILLE_CARTE := 3.4

const PELOUSE := Color(0.55, 0.68, 0.16)
const CIMENT := Color(0.76, 0.72, 0.62)
const PIERRE := Color(0.62, 0.56, 0.47)


static func construire(c: Node3D, f, parent: Node3D) -> void:
	_sol(c, f)
	_terrasse(c, f, parent)
	_bassin(c, f, parent)
	_murs(c, f)
	_sous_bois(c, f, parent)
	_arbres(c, f, parent)
	_massifs(c, f, parent)
	_portique(c, f, Vector2(-15.6, -30.9), 0.35)
	_abri(c, f)
	_poser_feuillage(parent)
	var pr: Vector2 = contour_bassin()[9]
	_roue(c, f, pr + (pr - BASSIN).normalized() * 0.22)


static func TERRASSE_N() -> Vector2:
	return Vector2(-TERRASSE_U.y, TERRASSE_U.x) * -1.0


static func dedans(p: Vector2, poly: Array) -> bool:
	var c = false
	var j = poly.size() - 1
	for i in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[j]
		if (a.y > p.y) != (b.y > p.y) and p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
			c = not c
		j = i
	return c


static func _dist_ligne(p: Vector2, l: Array) -> float:
	var m = 1e9
	for i in l.size() - 1:
		var a: Vector2 = l[i]
		var b: Vector2 = l[i + 1]
		var t = clampf((p - a).dot(b - a) / (b - a).length_squared(), 0.0, 1.0)
		m = minf(m, p.distance_to(a + (b - a) * t))
	return m


## Le contour du bassin en haricot, dans le repère du monde.
static func contour_bassin() -> Array:
	var pts = []
	var n = 28
	for i in n:
		var t = TAU * i / n
		var r = 1.0 - 0.32 * exp(-pow(wrapf(t - PI / 2.0, -PI, PI), 2.0) / 0.35)
		var q = Vector2(2.0 * cos(t) * r, 1.15 * sin(t) * r)
		pts.append(BASSIN + q.rotated(BASSIN_ROT))
	return pts


static func _dans_terrasse(p: Vector2, marge: float) -> bool:
	var d = p - TERRASSE_O
	var x = d.dot(TERRASSE_U)
	var z = d.dot(TERRASSE_N())
	return absf(x) < TERRASSE_L / 2.0 + marge and z > -0.6 and z < TERRASSE_P + marge


# --- Le sol ---------------------------------------------------------------------------------------

## La pelouse, posée sur le relief par carrés : plus sombre sous les arbres du fond, l'allée tondue plus
## claire, un peu d'herbe sèche au pied de la terrasse.
static func _sol(c: Node3D, f) -> void:
	var pas = 0.6
	var bassin = contour_bassin()
	var fond = SOUS_BOIS
	var x = -19.5
	while x < 8.6:
		var z = -46.2
		while z < -22.3:
			var m = Vector2(x + pas / 2.0, z + pas / 2.0)
			if dedans(m, EMPRISE) and not _dans_terrasse(m, -0.05) and not (dedans(m, bassin)):
				var col = PELOUSE.lerp(Color(0.64, 0.72, 0.2), f.rng.randf() * 0.5)
				var df = _dist_ligne(m, fond)
				if df < 4.4:
					# Sous les arbres : l'herbe rare, la litière de feuilles et la mousse.
					var litiere = Color(0.5, 0.37, 0.2).lerp(Color(0.42, 0.33, 0.18), f.rng.randf())
					col = col.lerp(litiere, clampf((1.0 - df / 4.4) * 2.2, 0.0, 1.0))
				var da = _dist_ligne(m, ALLEE)
				if da < 0.42:
					col = Color(0.62, 0.66, 0.36).lerp(Color(0.72, 0.66, 0.42), f.rng.randf() * 0.6)
				if _dans_terrasse(m, 0.9):
					col = col.lerp(Color(0.74, 0.66, 0.4), 0.55)
				var q = []
				for o in [Vector2(0, 0), Vector2(pas, 0), Vector2(pas, pas), Vector2(0, pas)]:
					q.append(Vector3(x + o.x, c.sol(x + o.x, z + o.y) + 0.03, z + o.y))
				f.batch.quad("trim", Transform3D.IDENTITY, q, Vector3.UP, col)
			z += pas
		x += pas


# --- La terrasse ----------------------------------------------------------------------------------

static func _terrasse(c: Node3D, f, parent: Node3D) -> void:
	var n = TERRASSE_N()
	var haut = -1e9
	var bas = 1e9
	for i in 5:
		var p: Vector2 = TERRASSE_O + TERRASSE_U * (i - 2) * TERRASSE_L / 4.0
		haut = maxf(haut, c.sol(p.x, p.y))
		var q: Vector2 = p + n * (TERRASSE_P + 0.4)
		bas = minf(bas, c.sol(q.x, q.y))
	var y = maxf(haut + 0.05, bas + 0.35)
	var xf = Transform3D(Basis(Vector3.UP, atan2(n.x, n.y)), Vector3(TERRASSE_O.x, 0, TERRASSE_O.y))
	# Le plateau de gravier, le mur de soutènement de pierre et ses grosses pierres de couronnement.
	var ep = y - bas + 0.3
	f.batch.box("wall", xf, Vector3(0, y - ep / 2.0, TERRASSE_P / 2.0 - 0.3), Vector3(TERRASSE_L, ep, TERRASSE_P + 0.6), Color(0.66, 0.54, 0.34))
	f.batch.box("trim", xf, Vector3(0, y + 0.005, TERRASSE_P / 2.0 - 0.3), Vector3(TERRASSE_L - 0.1, 0.02, TERRASSE_P + 0.5), Color(0.72, 0.68, 0.6))
	# Le plateau porte le promeneur : on y monte par l'escalier, on n'en tombe pas.
	_solide(f, xf, Vector3(0, y - ep / 2.0 + 0.01, TERRASSE_P / 2.0 - 0.3), Vector3(TERRASSE_L, ep, TERRASSE_P + 0.6))
	for s in [-1.0, 1.0]:
		_solide(f, xf, Vector3(s * (TERRASSE_L / 2.0 + 0.02), y + 0.1, TERRASSE_P / 2.0), Vector3(0.3, 0.2, TERRASSE_P))
	# Les pierres de couronnement, interrompues en haut de l'escalier.
	var g0: float = TERRASSE_L / 2.0 - 0.95
	var g1: float = TERRASSE_L / 2.0 - 0.15
	var x = -TERRASSE_L / 2.0
	while x < TERRASSE_L / 2.0 - 0.05:
		var l: float = minf(f.rng.randf_range(0.45, 0.75), TERRASSE_L / 2.0 - x)
		if x + l > g0 and x < g1:
			l = g0 - x if x < g0 - 0.05 else 0.0
			if l <= 0.0:
				x = g1
				continue
		var col = Color(0.72, 0.6, 0.4).lerp(Color(0.62, 0.56, 0.36), f.rng.randf() * 0.5)
		f.batch.box("trim", xf, Vector3(x + l / 2.0, y + 0.085, TERRASSE_P + 0.02), Vector3(l - 0.03, 0.19, 0.3), col)
		x += l
	for s in [-1.0, 1.0]:
		f.batch.box("trim", xf, Vector3(s * (TERRASSE_L / 2.0 + 0.02), y + 0.085, TERRASSE_P / 2.0), Vector3(0.3, 0.19, TERRASSE_P), Color(0.7, 0.58, 0.38))
	# Les moellons du mur, côté jardin.
	var fxf = xf * Transform3D(Basis(), Vector3(0, 0, TERRASSE_P + 0.181))
	for i in int(TERRASSE_L * ep * 18.0):
		var px: float = f.rng.randf_range(-TERRASSE_L / 2.0 + 0.08, TERRASSE_L / 2.0 - 0.08)
		var py: float = f.rng.randf_range(bas - 0.2, y - 0.05)
		var sx: float = f.rng.randf_range(0.06, 0.14)
		var sy: float = f.rng.randf_range(0.04, 0.08)
		f.batch.quad("trim", fxf, [Vector3(px - sx, py - sy, 0), Vector3(px + sx, py - sy, 0), Vector3(px + sx, py + sy, 0), Vector3(px - sx, py + sy, 0)], Vector3.BACK, Color(0.74, 0.6, 0.4).lerp(Color(0.56, 0.44, 0.28), f.rng.randf()))
	# L'escalier qui descend au jardin, au bout est, vers l'allée.
	var nb = maxi(2, int(ceil((y - bas) / 0.12)))
	for k in nb:
		var hy: float = y - (k + 1) * (y - bas) / nb
		f.batch.box("trim", xf, Vector3(TERRASSE_L / 2.0 - 0.55, (hy + bas) / 2.0 - 0.1, TERRASSE_P + 0.25 + k * 0.22), Vector3(0.8, hy - bas + 0.25, 0.24), Color(0.68, 0.64, 0.56))
	# Sous les marches, une rampe invisible pour que le promeneur monte sans buter.
	var run: float = nb * 0.22
	var rise: float = y - bas
	var pente: float = atan2(rise, run)
	var rxf = xf * Transform3D(Basis(Vector3.RIGHT, pente), Vector3(TERRASSE_L / 2.0 - 0.55, (y + bas) / 2.0 - 0.06, TERRASSE_P + 0.14 + run / 2.0))
	_solide(f, rxf, Vector3.ZERO, Vector3(0.8, 0.1, sqrt(run * run + rise * rise) + 0.1))
	# Une table de fer et deux chaises pour contempler le jardin.
	var t = xf * Transform3D(Basis(), Vector3(1.5, y, 0.5))
	f.batch.cylinder("trim", t, Vector3(0, 0.3, 0), 0.26, 0.03, Color(0.2, 0.26, 0.22), 12)
	f.batch.box("trim", t, Vector3(0, 0.15, 0), Vector3(0.04, 0.3, 0.04), Color(0.2, 0.26, 0.22))
	for s in [-1.0, 1.0]:
		var ch = t * Transform3D(Basis(Vector3.UP, s * 0.4), Vector3(s * 0.45, 0, 0.1))
		f.batch.box("trim", ch, Vector3(0, 0.18, 0), Vector3(0.18, 0.025, 0.18), Color(0.2, 0.26, 0.22))
		f.batch.box("trim", ch, Vector3(0, 0.32, 0.09), Vector3(0.18, 0.28, 0.02), Color(0.2, 0.26, 0.22))
		for q in [Vector3(-0.07, 0.09, -0.07), Vector3(0.07, 0.09, -0.07), Vector3(-0.07, 0.09, 0.07), Vector3(0.07, 0.09, 0.07)]:
			f.batch.box("trim", ch, q, Vector3(0.015, 0.18, 0.015), Color(0.2, 0.26, 0.22))
	# Des pots de géraniums au bord.
	for i in 3:
		var pxf = xf * Transform3D(Basis(), Vector3(-1.6 + i * 0.5, y, 0.25))
		f.batch.cylinder("trim", pxf, Vector3.ZERO, 0.1, 0.14, Color(0.72, 0.4, 0.26), 8)
		feuilles(f, Transform3D(Basis(), pxf * Vector3(0, 0.22, 0)), Vector3(0.15, 0.1, 0.15), 30, Color(0.3, 0.5, 0.22), 0.05, 0.25, [Color(0.86, 0.16, 0.2), 0.4])


# --- Le bassin ------------------------------------------------------------------------------------

static func _bassin(c: Node3D, f, parent: Node3D) -> void:
	var pts = contour_bassin()
	# Le miroir d'eau se pose au-dessus du relief le plus haut sous le bassin, pour que le terrain ne le
	# couvre jamais ; le rebord monte d'autant côté pente.
	var haut = -1e9
	for p in pts:
		haut = maxf(haut, c.sol(p.x, p.y))
	for p in pts:
		for t in [0.25, 0.5, 0.75]:
			var q: Vector2 = BASSIN.lerp(p, t)
			haut = maxf(haut, c.sol(q.x, q.y))
	var eau = haut + 0.04
	# L'eau : un miroir vert sombre, qui reflète le ciel et les arbres.
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		for q in [BASSIN, a, b]:
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(q.x, eau, q.y))
	var mi = MeshInstance3D.new()
	mi.name = "Bassin_eau"
	mi.mesh = st.commit()
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.42, 0.22)
	mat.metallic = 0.1
	mat.roughness = 0.35
	mat.metallic_specular = 0.4
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	parent.add_child(mi)
	# Le fond, qu'on devine sous l'eau, et le rebord de ciment arrondi.
	for i in pts.size():
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		var m = (a + b) / 2.0
		var d = b - a
		var sol: float = c.sol(m.x, m.y)
		var dessous = minf(sol, eau) - 0.12
		var h = maxf(sol, eau) + 0.07 - dessous
		var xf = Transform3D(Basis(Vector3.UP, atan2(d.x, d.y) - PI / 2.0), Vector3(m.x, dessous + h / 2.0, m.y))
		f.batch.box("trim", xf, Vector3.ZERO, Vector3(d.length() + 0.06, h, 0.24), CIMENT.darkened(f.rng.randf() * 0.1))
		f.batch.box("trim", xf, Vector3(0, h / 2.0 + 0.01, 0), Vector3(d.length() + 0.06, 0.03, 0.2), CIMENT.lightened(0.08))
		# Les coulures sombres sous le rebord, côté eau.
		var dir = (m - BASSIN).normalized()
		f.batch.box("trim", Transform3D(xf.basis, Vector3(m.x - dir.x * 0.125, eau + 0.02, m.y - dir.y * 0.125)), Vector3.ZERO, Vector3(d.length(), 0.05, 0.01), Color(0.32, 0.3, 0.22))
	# Les nénuphars, leurs fleurs roses et blanches, et le tas de pierres blanches au bord.
	for i in 16:
		var a: float = f.rng.randf() * TAU
		var r: float = f.rng.randf_range(0.0, 0.8)
		var q: Vector2 = BASSIN + Vector2(cos(a) * r * 1.4, sin(a) * r * 0.7).rotated(BASSIN_ROT) + Vector2(0.4, 0.1)
		var rr: float = f.rng.randf_range(0.09, 0.16)
		f.batch.cylinder("trim", Transform3D.IDENTITY, Vector3(q.x, eau + 0.005, q.y), rr, 0.01, Color(0.28, 0.46, 0.2).lerp(Color(0.45, 0.5, 0.22), f.rng.randf()), 7)
		if i % 4 == 0:
			var fc = Color(0.98, 0.7, 0.8) if i % 8 == 0 else Color(0.97, 0.96, 0.9)
			for k in 3:
				f.batch.box("trim", Transform3D(Basis(Vector3.UP, k * 1.05), Vector3(q.x, eau + 0.04, q.y)), Vector3.ZERO, Vector3(0.09, 0.04, 0.03), fc)
			f.batch.box("trim", Transform3D.IDENTITY, Vector3(q.x, eau + 0.06, q.y), Vector3(0.03, 0.02, 0.03), Color(0.95, 0.8, 0.2))
	var tas: Vector2 = pts[20]
	for k in 5:
		var rot = Basis(Vector3.UP, f.rng.randf() * TAU) * Basis(Vector3.RIGHT, f.rng.randf_range(-0.3, 0.3))
		f.batch.box("trim", Transform3D(rot, Vector3(tas.x + f.rng.randf_range(-0.2, 0.2), eau + 0.05 + k * 0.025, tas.y + f.rng.randf_range(-0.2, 0.2))), Vector3.ZERO, Vector3(0.24, 0.07, 0.12), Color(0.9, 0.88, 0.82))
	# Les iris au bord, côté terrasse : leurs lames et leurs fleurs violettes au cœur jaune.
	for k in [2, 4, 5, 7, 24, 26]:
		var p: Vector2 = pts[k]
		var o: Vector2 = p + (p - BASSIN).normalized() * 0.28
		_iris(c, f, o)
	# La petite cabane des canards au toit de tuiles, au coin ouest.
	var loin: Vector2 = pts[0]
	for q in pts:
		if (q as Vector2).distance_to(TERRASSE_O) > loin.distance_to(TERRASSE_O):
			loin = q
	var cab: Vector2 = loin + (loin - BASSIN).normalized() * 0.35
	var cxf = Transform3D(Basis(Vector3.UP, BASSIN_ROT + 0.3), Vector3(cab.x, c.sol(cab.x, cab.y), cab.y))
	f.batch.box("trim", cxf, Vector3(0, 0.12, 0), Vector3(0.5, 0.24, 0.36), CIMENT.darkened(0.1))
	f.batch.box("trim", cxf, Vector3(0.1, 0.09, 0.181), Vector3(0.14, 0.14, 0.01), Color(0.12, 0.1, 0.08))
	for s in [-1.0, 1.0]:
		f.batch.box_tilted("roof", cxf, Vector3(0, 0.3, s * 0.11), Vector3(0.62, 0.03, 0.27), s * -0.45, Color(0.76, 0.42, 0.3))


static func _iris(c: Node3D, f, p: Vector2) -> void:
	var y: float = c.sol(p.x, p.y)
	for i in 9:
		var a: float = f.rng.randf() * TAU
		var t = Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, f.rng.randf_range(-0.25, 0.25)), Vector3(p.x + f.rng.randf_range(-0.12, 0.12), y, p.y + f.rng.randf_range(-0.12, 0.12)))
		f.batch.box("trim", t, Vector3(0, 0.2, 0), Vector3(0.03, 0.4, 0.008), Color(0.3, 0.56, 0.24).lerp(Color(0.42, 0.64, 0.3), f.rng.randf()))
	for i in 4:
		var q = Vector3(p.x + f.rng.randf_range(-0.15, 0.15), y + f.rng.randf_range(0.38, 0.5), p.y + f.rng.randf_range(-0.15, 0.15))
		f.batch.box("trim", Transform3D.IDENTITY, q, Vector3(0.006, 0.12, 0.006), Color(0.3, 0.5, 0.22))
		for k in 3:
			f.batch.box_tilted("trim", Transform3D(Basis(Vector3.UP, k * TAU / 3.0), q + Vector3(0, 0.06, 0)), Vector3(0, 0, 0.04), Vector3(0.05, 0.012, 0.08), 0.5, Color(0.42, 0.26, 0.74))
		f.batch.box("trim", Transform3D.IDENTITY, q + Vector3(0, 0.08, 0), Vector3(0.035, 0.05, 0.035), Color(0.36, 0.22, 0.68))
		f.batch.box("trim", Transform3D.IDENTITY, q + Vector3(0, 0.055, 0.03), Vector3(0.025, 0.012, 0.03), Color(0.96, 0.82, 0.2))


# --- Les murs -------------------------------------------------------------------------------------

## Les murs de pierre sèche qui ferment le jardin : plus hauts le long de la ruelle, plus bas chez les
## voisins de l'est ; mousse et lichen sur le chaperon. Ils arrêtent le promeneur, comme les piliers.
static func _murs(c: Node3D, f) -> void:
	for k in MURS:
		var a: Vector2 = EMPRISE[k]
		var b: Vector2 = EMPRISE[(k + 1) % EMPRISE.size()]
		var h = 0.75 if k <= 4 else 0.55
		var l = a.distance_to(b)
		var d = (b - a) / l
		# Côté ouest, le mur part du dernier pilier de la palissade blanche ; le portillon s'ouvre à
		# l'angle nord-est, sur le chemin de la rue Maquis-Maurice.
		var t0 = 2.45 if k == 0 else 0.0
		var trous = [[l - PORTILLON[1], l - PORTILLON[0]]] if k == PORTILLON_COTE else []
		var t = t0
		while t < l - 0.001:
			var t1 = minf(t + 0.6, l)
			if trous.size() > 0 and t1 > trous[0][0] and t < trous[0][1]:
				if t < trous[0][0] - 0.01:
					_pan_de_mur(c, f, a + d * t, a + d * trous[0][0], h)
				t = trous[0][1]
				continue
			_pan_de_mur(c, f, a + d * t, a + d * t1, h)
			t = t1
		# Un pilier à chaque angle, qui lie les deux pans.
		_pilier(c, f, b, h + 0.08, 0.3)
	_portillon(c, f)


## Une boîte de collision du jardin (repère xf), dans un seul corps statique.
static func _solide(f, xf: Transform3D, centre: Vector3, taille: Vector3) -> void:
	var corps: StaticBody3D = f.parent.get_node_or_null("Solides_jardin")
	if corps == null:
		corps = StaticBody3D.new()
		corps.name = "Solides_jardin"
		f.parent.add_child(corps)
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = taille
	cs.shape = bx
	cs.transform = xf * Transform3D(Basis(), centre)
	corps.add_child(cs)


## Un pan de mur de pierre sèche entre p et q : sa fondation descend sous le point le plus bas du terrain,
## son chaperon suit la pente, son pied est mangé de mousse et d'herbe.
static func _pan_de_mur(c: Node3D, f, p: Vector2, q: Vector2, h: float) -> void:
	var d: Vector2 = (q - p).normalized()
	var l: float = p.distance_to(q) + 0.04
	var m: Vector2 = (p + q) / 2.0
	var yp: float = c.sol(p.x, p.y)
	var yq: float = c.sol(q.x, q.y)
	var ym: float = c.sol(m.x, m.y)
	var bas: float = minf(minf(yp, yq), ym) - 0.35
	var haut: float = maxf(maxf(yp, yq), ym) + h
	var xf = Transform3D(Basis(Vector3.UP, atan2(d.x, d.y) - PI / 2.0), Vector3(m.x, 0, m.y))
	f.batch.box("wall", xf, Vector3(0, (bas + haut) / 2.0, 0), Vector3(l, haut - bas, 0.22), PIERRE.darkened(0.08))
	f.batch.box("trim", xf, Vector3(0, haut + 0.03, 0), Vector3(l, 0.07, 0.27), Color(0.52, 0.52, 0.42).lerp(Color(0.4, 0.5, 0.3), f.rng.randf() * 0.6))
	_solide(f, xf, Vector3(0, (bas + haut + 0.07) / 2.0, 0), Vector3(l, haut + 0.07 - bas, 0.27))
	var sol_bas: float = minf(yp, yq)
	for s in [-1.0, 1.0]:
		var fz = s * 0.112
		for i in int(l * h * 16.0):
			var px: float = f.rng.randf_range(-l / 2.0 + 0.04, l / 2.0 - 0.04)
			var py: float = f.rng.randf_range(sol_bas + 0.04, haut - 0.05)
			var sx: float = f.rng.randf_range(0.05, 0.12)
			var sy: float = f.rng.randf_range(0.03, 0.06)
			f.batch.quad("trim", xf, [Vector3(px - sx, py - sy, fz), Vector3(px + sx, py - sy, fz), Vector3(px + sx, py + sy, fz), Vector3(px - sx, py + sy, fz)], Vector3(0, 0, s), Color(0.7, 0.63, 0.5).lerp(Color(0.48, 0.43, 0.36), f.rng.randf()))
		# Le pied du mur : une bande de mousse et de terre qui suit le sol, puis des touffes d'herbe.
		f.batch.quad("trim", xf, [Vector3(-l / 2.0, yp - 0.05, fz * 1.06), Vector3(l / 2.0, yq - 0.05, fz * 1.06), Vector3(l / 2.0, yq + 0.1, fz * 1.06), Vector3(-l / 2.0, yp + 0.1, fz * 1.06)], Vector3(0, 0, s), Color(0.34, 0.38, 0.22).lerp(Color(0.3, 0.26, 0.18), f.rng.randf() * 0.5))
		for i in 3:
			var tx: float = f.rng.randf_range(-l / 2.0, l / 2.0)
			var ty: float = lerpf(yp, yq, (tx + l / 2.0) / l)
			f.batch.box("trim", xf, Vector3(tx, ty + 0.05, s * 0.15), Vector3(0.12, 0.1, 0.06), Color(0.36, 0.5, 0.2).lerp(Color(0.5, 0.58, 0.26), f.rng.randf()))


static func _pilier(c: Node3D, f, p: Vector2, h: float, l: float) -> void:
	var y: float = c.sol(p.x, p.y)
	f.batch.box("wall", Transform3D.IDENTITY, Vector3(p.x, y + (h - 0.35) / 2.0, p.y), Vector3(l, h + 0.35, l), PIERRE.darkened(0.12))
	f.batch.box("trim", Transform3D.IDENTITY, Vector3(p.x, y + h + 0.04, p.y), Vector3(l + 0.06, 0.08, l + 0.06), Color(0.6, 0.58, 0.5))
	_solide(f, Transform3D.IDENTITY, Vector3(p.x, y + (h - 0.35) / 2.0, p.y), Vector3(l + 0.06, h + 0.43, l + 0.06))


## Le petit portillon de l'angle nord-est, sous les arbres, au bout du mur de la ruelle : deux piliers de
## pierre, une porte de bois gris à claire-voie, entrouverte vers le jardin ; dehors, le chemin.
static func _portillon(c: Node3D, f) -> void:
	var a: Vector2 = EMPRISE[PORTILLON_COTE]
	var b: Vector2 = EMPRISE[(PORTILLON_COTE + 1) % EMPRISE.size()]
	var l = a.distance_to(b)
	var d = (b - a) / l
	var p: Vector2 = a + d * (l - PORTILLON[1])
	var q: Vector2 = a + d * (l - PORTILLON[0])
	_pilier(c, f, p, 0.9, 0.24)
	_pilier(c, f, q, 0.9, 0.24)
	var y: float = c.sol(p.x, p.y)
	var bois = Color(0.5, 0.5, 0.44)
	# Le vantail pivote sur le pilier ouest et s'ouvre de 30° vers le jardin.
	var ang = atan2(d.x, d.y) - PI / 2.0
	var vers_jardin := Vector2(-d.y, d.x)
	if not dedans((p + q) / 2.0 + vers_jardin * 0.5, EMPRISE):
		vers_jardin = -vers_jardin
	var ouvre: float = 0.5 if Vector2(d.y, -d.x).dot(vers_jardin) > 0.0 else -0.5
	var gxf = Transform3D(Basis(Vector3.UP, ang + ouvre), Vector3(p.x, y, p.y)) * Transform3D(Basis(), Vector3(0.14, 0, 0))
	var lg = q.distance_to(p) - 0.26
	for yy in [0.12, 0.62]:
		f.batch.box("trim", gxf, Vector3(lg / 2.0, yy, 0), Vector3(lg, 0.05, 0.035), bois.darkened(0.1))
	for i in 6:
		f.batch.box("trim", gxf, Vector3(0.03 + i * (lg - 0.06) / 5.0, 0.38, 0), Vector3(0.035, 0.66, 0.03), bois.lerp(Color(0.6, 0.6, 0.54), f.rng.randf() * 0.4))
	f.batch.box_tilted("trim", gxf, Vector3(lg / 2.0, 0.37, 0.02), Vector3(lg * 1.1, 0.04, 0.03), 0.0, bois.darkened(0.15))
	f.batch.box("trim", gxf, Vector3(lg - 0.04, 0.45, 0.03), Vector3(0.03, 0.06, 0.03), Color(0.2, 0.2, 0.2))
	# Le seuil de terre battue, du jardin au chemin.
	var m: Vector2 = (p + q) / 2.0
	f.batch.box("trim", Transform3D(Basis(Vector3.UP, ang), Vector3(m.x, c.sol(m.x, m.y) + 0.02, m.y)), Vector3.ZERO, Vector3(0.5, 0.03, 0.9), Color(0.46, 0.38, 0.28))


## Pousse un point du jardin vers l'intérieur jusqu'à r du mur le plus proche : les couronnes restent
## au-dessus du jardin et laissent libres le chemin de la ruelle et les jardins voisins.
static func loin_des_murs(p: Vector2, r: float) -> Vector2:
	for passe in 4:
		for k in MURS:
			var a: Vector2 = EMPRISE[k]
			var b: Vector2 = EMPRISE[(k + 1) % EMPRISE.size()]
			var ab := b - a
			var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var proche := a + ab * t
			var dd := p.distance_to(proche)
			var n := Vector2(-ab.y, ab.x).normalized()
			if not dedans((a + b) / 2.0 + n * 0.3, EMPRISE):
				n = -n
			var cote := (p - proche).dot(n)
			if cote < r:
				p += n * (r - cote)
	return p


# --- Le feuillage ---------------------------------------------------------------------------------

## Le feuillage du jardin : toutes les touffes dans une seule surface, sous le nuanceur des feuilles en dentelle.
static var _st_feuilles: SurfaceTool = null


## Un nuage de touffes : des paires de cartes croisées semées dans un ellipsoïde (repère xf, rayons r), plus
## serrées vers la surface ; le nuanceur y dessine les feuilles (forme : voir feuillage.gdshader) et perce le reste.
## Chaque carte prend la normale de la couronne (du cœur vers le dehors, un peu vers le ciel) et s'assombrit vers le
## cœur. n compte les feuilles comme avant, taille leur longueur ; fleurs : [couleur, proportion(, forme)].
static func feuilles(f, xf: Transform3D, r: Vector3, n: int, col: Color, taille: float, variation := 0.25, fleurs: Array = [], forme := 0) -> void:
	if _st_feuilles == null:
		_st_feuilles = SurfaceTool.new()
		_st_feuilles.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st: SurfaceTool = _st_feuilles
	var cartes: int = maxi(1, int(n * CARTES))
	for i in cartes:
		var d := Vector3(f.rng.randfn(), f.rng.randfn(), f.rng.randfn())
		if d.length_squared() < 1e-6:
			continue
		d = d.normalized()
		var u: float = pow(f.rng.randf(), 0.45)
		var p: Vector3 = xf * (Vector3(d.x * r.x, d.y * r.y, d.z * r.z) * u)
		var nn: Vector3 = (xf.basis * Vector3(d.x / r.x, d.y / r.y, d.z / r.z)).normalized()
		var fl: bool = fleurs.size() >= 2 and f.rng.randf() < float(fleurs[1]) and u > 0.5
		var fo: int = (int(fleurs[2]) if fleurs.size() > 2 else 4) if fl else forme
		var c: Color
		if fl:
			c = (fleurs[0] as Color).lerp(Color.WHITE, f.rng.randf() * 0.15)
		else:
			c = col.lerp(col.lightened(0.3), f.rng.randf() * variation * 2.0).darkened((1.0 - u) * 0.4 + f.rng.randf() * variation * 0.4)
			c = c.lightened(maxf(nn.y, 0.0) * 0.1)
		c.a = clampf(u, 0.2, 1.0)
		var s: float = taille * TAILLE_CARTE * f.rng.randf_range(0.75, 1.25) * (0.8 + 0.3 * u)
		var nrm := (nn + Vector3(f.rng.randf_range(-0.5, 0.5), 0.3, f.rng.randf_range(-0.5, 0.5))).normalized()
		var uu := nrm.cross(Vector3.RIGHT if absf(nrm.x) < 0.9 else Vector3.FORWARD).normalized().rotated(nrm, f.rng.randf() * TAU)
		var vv := nrm.cross(uu)
		var normale := (nrm * 0.12 + nn * 0.88 + Vector3(0, 0.2, 0)).normalized()
		var demi := s * 0.5
		for carte in 2:
			var a: Vector3 = uu if carte == 0 else vv
			var b: Vector3 = vv if carte == 0 else (nrm * 0.8 + uu * 0.2).normalized()
			var k := float(f.rng.randi() % 64)
			var coins := [p - a * demi - b * demi, p + a * demi - b * demi, p + a * demi + b * demi, p - a * demi + b * demi]
			var uv := [Vector2(k + 0.001, fo + 0.999), Vector2(k + 0.999, fo + 0.999), Vector2(k + 0.999, fo + 0.001), Vector2(k + 0.001, fo + 0.001)]
			for j in [0, 1, 2, 0, 2, 3]:
				st.set_color(c)
				st.set_normal(normale)
				st.set_uv(uv[j])
				st.add_vertex(coins[j])


## Pose le feuillage accumulé sous parent, une seule surface au nuanceur des feuilles.
static func _poser_feuillage(parent: Node3D) -> void:
	if _st_feuilles == null:
		return
	var mi := MeshInstance3D.new()
	mi.name = "Feuillage_jardin"
	mi.mesh = _st_feuilles.commit()
	var m := ShaderMaterial.new()
	m.shader = load("res://communes/availles_limouzine/feuillage.gdshader")
	mi.material_override = m
	parent.add_child(mi)
	_st_feuilles = null


## Un repère dont l'axe X suit dir (pour les branches et les nappes de feuillage).
static func repere(dir: Vector3, o: Vector3) -> Transform3D:
	var x := dir.normalized()
	var z := x.cross(Vector3.UP if absf(x.y) < 0.95 else Vector3.FORWARD).normalized()
	var y := z.cross(x)
	return Transform3D(Basis(x, y, z), o)


## Un tronçon de bois de a à b, qui s'effile de ra à rb.
static func bois(f, a: Vector3, b: Vector3, ra: float, rb: float, col: Color, cotes := 7) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.01:
		return
	var y := d / l
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(y)
	var xf := Transform3D(Basis(x, y, z), a)
	f.batch.cylinder("trim", xf, Vector3.ZERO, ra, l * 0.52, col, cotes)
	f.batch.cylinder("trim", xf, Vector3(0, l * 0.5, 0), (ra + rb) / 2.0, l * 0.5, col.darkened(0.05), cotes)


## Les branches d'un feuillu : chaque rameau se divise en deux ou trois qui s'écartent et montent ; les
## bouts reçoivent les touffes de feuilles.
static func rameau(f, a: Vector3, dir: Vector3, l: float, r: float, prof: int, bouts: Array, ecorce: Color, ouverture := 0.55, monte := 0.15) -> void:
	var b := a + dir * l
	bois(f, a, b, r, r * 0.7, ecorce, 7 if r > 0.04 else 5)
	if prof == 0:
		bouts.append(b)
		return
	var nb = 2 + (1 if f.rng.randf() < 0.5 else 0)
	var phase = f.rng.randf() * TAU
	var perp0 := dir.cross(Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT).normalized()
	for k in nb:
		var az: float = phase + TAU * k / nb + f.rng.randf_range(-0.4, 0.4)
		var perp := perp0.rotated(dir, az)
		var nd := (dir * cos(ouverture) + perp * sin(ouverture)).normalized()
		nd = (nd + Vector3.UP * monte).normalized()
		rameau(f, b, nd, l * f.rng.randf_range(0.62, 0.8), r * 0.62, prof - 1, bouts, ecorce, ouverture, monte)


## Un feuillu : un fût, des charpentières qui se divisent, des touffes de feuilles au bout des rameaux.
## genre 0 : chêne, vert sombre ; 1 : charme ou tilleul, vert franc ; 2 : hêtre pourpre.
static func feuillu(c: Node3D, f, p: Vector2, h: float, genre: int) -> void:
	p = loin_des_murs(p, h * 0.4)
	var y: float = c.sol(p.x, p.y)
	var pied := Vector3(p.x, y - 0.05, p.y)
	var ecorce: Color = [Color(0.36, 0.32, 0.27), Color(0.5, 0.5, 0.46), Color(0.44, 0.42, 0.4)][genre]
	var vert: Color = [Color(0.22, 0.38, 0.14), Color(0.32, 0.5, 0.17), Color(0.38, 0.15, 0.2)][genre]
	var tete = pied + Vector3(f.rng.randf_range(-0.06, 0.06), 1.0, f.rng.randf_range(-0.06, 0.06)).normalized() * h * 0.36
	bois(f, pied, tete, h * 0.045, h * 0.032, ecorce, 9)
	var bouts := []
	var nb := 4 + (1 if genre != 1 else 0)
	for k in nb:
		var az: float = TAU * k * 0.382 * 2.0 + f.rng.randf_range(-0.3, 0.3)
		var dd := Vector3(cos(az) * 0.85, 1.0, sin(az) * 0.85).normalized()
		var depart: Vector3 = pied.lerp(tete, 0.72 + 0.28 * k / nb)
		rameau(f, depart, dd, h * (0.21 - 0.02 * k / nb), h * 0.022, 2, bouts, ecorce, 0.5)
	rameau(f, tete, Vector3.UP, h * 0.22, h * 0.024, 2, bouts, ecorce, 0.4)
	var rc := h * 0.16
	for q in bouts:
		feuilles(f, Transform3D(Basis(Vector3.UP, f.rng.randf() * TAU), q + Vector3(0, rc * 0.25, 0)), Vector3(rc, rc * 0.72, rc), 64, vert, h * 0.028, 0.25, [], 1 if genre == 0 else 0)
	_solide(f, Transform3D.IDENTITY, pied + Vector3(0, h * 0.18, 0), Vector3(h * 0.08, h * 0.36, h * 0.08))
	# Le lierre au pied du tronc.
	for k in 8:
		var a: float = f.rng.randf() * TAU
		f.batch.box("trim", Transform3D(Basis(Vector3.UP, a), pied + Vector3(cos(a) * h * 0.045, f.rng.randf_range(0.05, 0.6), sin(a) * h * 0.045)), Vector3.ZERO, Vector3(0.12, 0.14, 0.04), Color(0.14, 0.3, 0.12).lerp(Color(0.24, 0.38, 0.16), f.rng.randf()))


## L'épicéa : un fût droit, des étages de branches qui partent à l'horizontale et retombent, chacune
## couverte d'une nappe de rameaux vert sombre qui pend ; la flèche au sommet.
static func epicea(c: Node3D, f, p: Vector2, h: float) -> void:
	p = loin_des_murs(p, h * 0.22)
	var y: float = c.sol(p.x, p.y)
	var pied := Vector3(p.x, y - 0.05, p.y)
	bois(f, pied, pied + Vector3(0, h * 0.97, 0), h * 0.028, h * 0.006, Color(0.38, 0.3, 0.25), 7)
	var etages := 22
	for e in etages:
		var t: float = float(e) / (etages - 1)
		var yy: float = h * (0.1 + 0.84 * t)
		var rr: float = h * 0.22 * pow(1.0 - t, 0.9) + 0.12
		var nbr: int = 7 if t < 0.7 else 5
		for k in nbr:
			var az: float = TAU * k / nbr + e * 0.9 + f.rng.randf_range(-0.25, 0.25)
			var dir := Vector3(cos(az), -0.18 - 0.25 * (1.0 - t), sin(az)).normalized()
			var o := pied + Vector3(0, yy, 0)
			if rr > 0.5:
				bois(f, o, o + dir * rr * 0.9, h * 0.006, h * 0.002, Color(0.32, 0.26, 0.2), 4)
			var col = Color(0.12, 0.25, 0.13).lerp(Color(0.18, 0.33, 0.17), f.rng.randf())
			var nxf := repere(dir, o + dir * rr * 0.55 + Vector3(0, -rr * 0.08, 0))
			feuilles(f, nxf, Vector3(rr * 0.55, rr * 0.16, rr * 0.3), int(14 + 40 * rr / (h * 0.22)), col, h * 0.016, 0.2, [], 2)
	feuilles(f, Transform3D(Basis(), pied + Vector3(0, h * 0.97, 0)), Vector3(0.08, h * 0.05, 0.08), 12, Color(0.2, 0.36, 0.2), h * 0.012, 0.25, [], 2)
	_solide(f, Transform3D.IDENTITY, pied + Vector3(0, h * 0.25, 0), Vector3(h * 0.06, h * 0.5, h * 0.06))


## Le cèdre bleu de l'Atlas, comme sur les photos : un tronc énorme qui se divise en deux ou trois
## flèches, une silhouette large et un peu irrégulière faite de nappes de rameaux bleu-gris étagées,
## plates dessus, qui retombent à leur bout, très serrées ; un peu de ciel entre les étages.
static func cedre_bleu(c: Node3D, f, p: Vector2, h: float, rayon: float) -> void:
	p = loin_des_murs(p, rayon * 0.95)
	var y: float = c.sol(p.x, p.y)
	var pied := Vector3(p.x, y - 0.05, p.y)
	var ecorce := Color(0.4, 0.37, 0.34)
	var fourche := pied + Vector3(0, h * 0.3, 0)
	bois(f, pied, fourche, rayon * 0.16, rayon * 0.12, ecorce, 10)
	var fleches := []
	for b in 3:
		var a: float = TAU * b / 3.0 + 0.5
		var tete := fourche + Vector3(cos(a) * rayon * 0.18, h * 0.62, sin(a) * rayon * 0.18)
		bois(f, fourche, tete, rayon * 0.08, rayon * 0.02, ecorce.lightened(0.04), 7)
		fleches.append(tete)
	var bleu := Color(0.42, 0.56, 0.58)
	var nappes := int(30 * rayon)
	for i in nappes:
		var t: float = pow(f.rng.randf(), 0.75)
		var yy: float = h * (0.22 + 0.74 * t)
		var rmax: float = rayon * (1.0 - 0.75 * pow(t, 1.4))
		var az: float = f.rng.randf() * TAU
		var dd: float = rmax * sqrt(f.rng.randf_range(0.15, 1.0))
		var o := pied + Vector3(0, yy, 0)
		var centre := o + Vector3(cos(az) * dd, 0, sin(az) * dd)
		var rr: float = rayon * f.rng.randf_range(0.26, 0.4) * (1.0 - 0.45 * t)
		if dd > rayon * 0.3:
			bois(f, o, centre, rayon * 0.035, rayon * 0.012, ecorce, 5)
		var dir := Vector3(cos(az), -0.12, sin(az))
		var col = bleu.lerp(Color(0.56, 0.68, 0.68), f.rng.randf() * 0.7).darkened(f.rng.randf() * 0.12)
		var nxf := repere(dir, centre)
		feuilles(f, nxf, Vector3(rr, rr * 0.2, rr * 0.8), int(240 * rr / (rayon * 0.33)), col, rayon * 0.032, 0.22, [], 3)
		# Le bout de la nappe qui retombe.
		feuilles(f, repere(Vector3(cos(az), -0.5, sin(az)), centre + Vector3(cos(az), -0.3, sin(az)) * rr * 0.9), Vector3(rr * 0.35, rr * 0.12, rr * 0.5), int(64 * rr / (rayon * 0.33)), col.darkened(0.06), rayon * 0.03, 0.2, [], 3)
	for tete in fleches:
		feuilles(f, Transform3D(Basis(), tete), Vector3(rayon * 0.16, h * 0.05, rayon * 0.16), 110, bleu.lightened(0.08), rayon * 0.03, 0.25, [], 3)
	_solide(f, Transform3D.IDENTITY, pied + Vector3(0, h * 0.15, 0), Vector3(rayon * 0.32, h * 0.3, rayon * 0.32))


## Le séquoia : un tronc roux cannelé qui s'évase au pied, une flèche étroite et haute de petites nappes
## vert sombre, plus clairsemée en bas.
static func sequoia(c: Node3D, f, p: Vector2, h: float) -> void:
	p = loin_des_murs(p, 1.7)
	var y: float = c.sol(p.x, p.y)
	var pied := Vector3(p.x, y - 0.05, p.y)
	var roux := Color(0.55, 0.3, 0.2)
	bois(f, pied, pied + Vector3(0, 0.6, 0), 0.55, 0.4, roux.darkened(0.15), 12)
	bois(f, pied + Vector3(0, 0.5, 0), pied + Vector3(0, h * 0.98, 0), 0.4, 0.05, roux, 11)
	for k in 10:
		var a: float = TAU * k / 10.0
		bois(f, pied + Vector3(cos(a) * 0.4, 0, sin(a) * 0.4), pied + Vector3(cos(a) * 0.34, h * 0.2, sin(a) * 0.34), 0.04, 0.025, roux.darkened(0.25), 4)
	var nappes := 200
	for i in nappes:
		var t: float = f.rng.randf()
		var yy: float = h * (0.16 + 0.82 * t)
		var rmax: float = 1.6 * pow(1.0 - t, 0.8) + 0.25
		var az: float = f.rng.randf() * TAU
		var dd: float = rmax * f.rng.randf_range(0.3, 0.85)
		var centre := pied + Vector3(cos(az) * dd, yy, sin(az) * dd)
		var rr: float = rmax * 0.45
		var col = Color(0.18, 0.3, 0.16).lerp(Color(0.28, 0.4, 0.2), f.rng.randf() * 0.6)
		feuilles(f, repere(Vector3(cos(az), -0.25, sin(az)), centre), Vector3(rr, rr * 0.3, rr * 0.6), 34, col, 0.13, 0.2, [], 2)
	_solide(f, Transform3D.IDENTITY, pied + Vector3(0, 1.5, 0), Vector3(1.1, 3.0, 1.1))


## Le bouleau : un tronc fin et blanc taché de noir, un peu penché, des rameaux qui montent puis
## pendent, un feuillage clair et léger qui laisse passer le jour.
static func bouleau(c: Node3D, f, p: Vector2, h: float, graine: int) -> void:
	p = loin_des_murs(p, h * 0.22)
	var y: float = c.sol(p.x, p.y)
	var pied := Vector3(p.x, y - 0.05, p.y)
	var penche := Vector3(cos(graine * 1.3) * 0.08, 1.0, sin(graine * 1.3) * 0.08).normalized()
	var tete := pied + penche * h * 0.92
	bois(f, pied, tete, h * 0.016, h * 0.006, Color(0.8, 0.79, 0.74), 10)
	for k in int(h * 4.0):
		var t: float = f.rng.randf_range(0.04, 0.8)
		var q := pied.lerp(tete, t)
		var a: float = f.rng.randf() * TAU
		f.batch.box("trim", Transform3D(Basis(Vector3.UP, a), q + Vector3(cos(a), 0, sin(a)) * h * 0.016), Vector3.ZERO, Vector3(h * 0.02, 0.03, 0.01), Color(0.12, 0.12, 0.12))
	var bouts := []
	for k in 9:
		var t: float = 0.32 + k * 0.065
		var az: float = graine + k * 2.4
		rameau(f, pied.lerp(tete, t), Vector3(cos(az) * 1.1, 1.0, sin(az) * 1.1).normalized(), h * 0.17 * (1.25 - t), h * 0.008, 2, bouts, Color(0.3, 0.26, 0.24), 0.6, -0.25)
	bouts.append(tete)
	for q in bouts:
		feuilles(f, Transform3D(Basis(), q + Vector3(0, -h * 0.03, 0)), Vector3(h * 0.045, h * 0.065, h * 0.045), 22, Color(0.42, 0.56, 0.2), h * 0.014, 0.3)
	_solide(f, Transform3D.IDENTITY, pied + Vector3(0, h * 0.2, 0), Vector3(h * 0.04, h * 0.4, h * 0.04))


## L'if : une masse sombre et serrée, large en bas, plusieurs têtes.
static func if_(c: Node3D, f, p: Vector2, h: float) -> void:
	p = loin_des_murs(p, h * 0.32)
	var y: float = c.sol(p.x, p.y)
	var pied := Vector3(p.x, y - 0.05, p.y)
	bois(f, pied, pied + Vector3(0, h * 0.4, 0), h * 0.05, h * 0.03, Color(0.45, 0.3, 0.24), 7)
	for k in 6:
		var t: float = k / 5.0
		var r: float = h * (0.3 - 0.2 * t)
		var o = pied + Vector3(f.rng.randf_range(-0.1, 0.1) * h, h * (0.3 + 0.55 * t), f.rng.randf_range(-0.1, 0.1) * h)
		feuilles(f, Transform3D(Basis(Vector3.UP, k), o), Vector3(r, r * 0.8, r), int(160 * r / (h * 0.3)), Color(0.12, 0.22, 0.12), h * 0.03, 0.18, [], 2)
	_solide(f, Transform3D.IDENTITY, pied + Vector3(0, h * 0.2, 0), Vector3(h * 0.1, h * 0.4, h * 0.1))


## Le cyprès : une colonne étroite et dense, vert sombre, qui pointe.
static func cypres(c: Node3D, f, p: Vector2, h: float) -> void:
	p = loin_des_murs(p, h * 0.12)
	var y: float = c.sol(p.x, p.y)
	var pied := Vector3(p.x, y - 0.05, p.y)
	bois(f, pied, pied + Vector3(0, h * 0.2, 0), h * 0.025, h * 0.02, Color(0.4, 0.3, 0.24), 6)
	for k in 7:
		var t: float = k / 6.0
		var r: float = h * 0.11 * (1.0 - 0.7 * t * t)
		feuilles(f, Transform3D(Basis(Vector3.UP, k), pied + Vector3(0, h * (0.15 + 0.75 * t), 0)), Vector3(r, h * 0.12, r), int(70 * r / (h * 0.11)) + 10, Color(0.14, 0.27, 0.15), h * 0.02, 0.18, [], 2)
	_solide(f, Transform3D.IDENTITY, pied + Vector3(0, h * 0.2, 0), Vector3(h * 0.08, h * 0.4, h * 0.08))


## Un vieux pommier : le tronc noueux et penché, des charpentières tordues, une couronne basse en
## touffes, semée de fleurs blanches et roses (ou un cerisier du Japon, presque tout rose).
static func pommier(c: Node3D, f, p: Vector2, graine: int, fleur := Color(0.98, 0.93, 0.93), part := 0.3, taille := 1.0) -> void:
	p = loin_des_murs(p, 1.2 * taille)
	var y: float = c.sol(p.x, p.y)
	var pied := Vector3(p.x, y - 0.03, p.y)
	var ecorce := Color(0.4, 0.36, 0.3)
	var a0: float = graine * 1.9
	var tete := pied + Vector3(cos(a0) * 0.2, 0.85, sin(a0) * 0.2) * taille
	bois(f, pied, tete, 0.09 * taille, 0.07 * taille, ecorce, 7)
	var bouts := []
	for k in 3:
		var az: float = a0 + TAU * k / 3.0 + f.rng.randf_range(-0.3, 0.3)
		rameau(f, tete, Vector3(cos(az) * 1.1, 0.8, sin(az) * 1.1).normalized(), 0.5 * taille, 0.05 * taille, 2, bouts, ecorce, 0.7, 0.1)
	for q in bouts:
		feuilles(f, Transform3D(Basis(Vector3.UP, f.rng.randf() * TAU), q + Vector3(0, 0.1, 0) * taille), Vector3(0.42, 0.3, 0.42) * taille, 44, Color(0.44, 0.62, 0.26), 0.085 * taille, 0.3, [fleur, part])
	_solide(f, Transform3D.IDENTITY, pied + Vector3(0, 0.4 * taille, 0), Vector3(0.18, 0.8, 0.18) * taille)


## Un arbuste : quelques lobes de feuillage serrés posés au sol, des tiges au pied.
## fleurs : [couleur, proportion] ; r : son rayon (unités).
static func arbuste(c: Node3D, f, p: Vector2, r: float, col: Color, fleurs: Array = [], lobes := 4) -> void:
	var y: float = c.sol(p.x, p.y)
	for k in 5:
		var a: float = f.rng.randf() * TAU
		bois(f, Vector3(p.x, y, p.y), Vector3(p.x + cos(a) * r * 0.4, y + r * 0.7, p.y + sin(a) * r * 0.4), r * 0.04, r * 0.02, Color(0.36, 0.3, 0.24), 4)
	for k in lobes:
		var a: float = TAU * k / lobes + f.rng.randf_range(-0.4, 0.4)
		var d: float = r * (0.0 if k == 0 else f.rng.randf_range(0.3, 0.5))
		var rl: float = r * f.rng.randf_range(0.55, 0.75)
		var o := Vector3(p.x + cos(a) * d, y + rl * 0.85 + (r * 0.25 if k == 0 else 0.0), p.y + sin(a) * d)
		feuilles(f, Transform3D(Basis(Vector3.UP, a), o), Vector3(rl, rl * 0.8, rl), int(70 * rl / 0.4) + 12, col, r * 0.13, 0.28, fleurs)


## Le cornouiller panaché du bassin : un grand arbuste aux rameaux arqués, feuillage vert bordé de crème,
## qui retombe jusqu'au sol.
static func cornouiller(c: Node3D, f, p: Vector2) -> void:
	var y: float = c.sol(p.x, p.y)
	for k in 9:
		var a: float = TAU * k / 9.0 + f.rng.randf_range(-0.2, 0.2)
		var d: float = f.rng.randf_range(0.35, 0.75)
		var o = Vector3(p.x + cos(a) * d, y + f.rng.randf_range(0.4, 0.95), p.y + sin(a) * d)
		bois(f, Vector3(p.x, y, p.y), o, 0.03, 0.015, Color(0.5, 0.26, 0.22), 4)
		feuilles(f, repere(Vector3(cos(a), -0.6, sin(a)), o), Vector3(0.45, 0.32, 0.36), 90, Color(0.5, 0.62, 0.32), 0.07, 0.3, [Color(0.94, 0.93, 0.8), 0.45, 0])
	feuilles(f, Transform3D(Basis(), Vector3(p.x, y + 1.0, p.y)), Vector3(0.5, 0.4, 0.5), 100, Color(0.5, 0.62, 0.32), 0.07, 0.3, [Color(0.94, 0.93, 0.8), 0.45, 0])


## Un rosier : un arbuste aux fleurs d'une couleur ; tige : sur un tronc, en boule.
static func rosier(c: Node3D, f, p: Vector2, couleur: Color, tige := false) -> void:
	if tige:
		var y: float = c.sol(p.x, p.y)
		bois(f, Vector3(p.x, y, p.y), Vector3(p.x, y + 0.6, p.y), 0.03, 0.025, Color(0.36, 0.3, 0.24), 5)
		feuilles(f, Transform3D(Basis(), Vector3(p.x, y + 0.82, p.y)), Vector3(0.32, 0.26, 0.32), 90, Color(0.26, 0.44, 0.18), 0.06, 0.25, [couleur, 0.3])
		return
	arbuste(c, f, p, 0.42, Color(0.24, 0.42, 0.17), [couleur, 0.28], 3)


# --- Le sous-bois ---------------------------------------------------------------------------------

## Sous les arbres du fond et à l'angle nord-ouest : fougères, lierre au sol et sur le mur, houx, une
## branche morte, des pierres moussues. Les arbres restent côté jardin : le chemin de la ruelle est libre.
static func _sous_bois(c: Node3D, f, parent: Node3D) -> void:
	feuillu(c, f, Vector2(-16.6, -32.4), 12.0 * M, 0)
	feuillu(c, f, Vector2(-11.8, -36.6), 10.0 * M, 1)
	if_(c, f, Vector2(-17.6, -29.8), 6.0 * M)
	var n = 0
	var essais = 0
	while n < 260 and essais < 2500:
		essais += 1
		var p = Vector2(f.rng.randf_range(-19.0, 5.0), f.rng.randf_range(-45.8, -27.0))
		var dl: float = _dist_ligne(p, SOUS_BOIS)
		if not dedans(p, EMPRISE) or dl > 3.0 or dl < 0.3:
			continue
		n += 1
		var genre: int = n % 10
		var y: float = c.sol(p.x, p.y)
		if genre < 5:
			fougere(c, f, p)
		elif genre < 8:
			_lierre_sol(c, f, p)
		elif genre == 8:
			# Un arbuste bas d'un mètre et demi : houx aux baies rouges, noisetier.
			if n % 20 == 8:
				arbuste(c, f, p, 0.4, Color(0.12, 0.26, 0.12), [Color(0.75, 0.08, 0.08), 0.05], 3)
			else:
				arbuste(c, f, p, 0.45, Color(0.26, 0.42, 0.18), [], 3)
		else:
			# Des copeaux et des brindilles.
			for k in 4:
				f.batch.box("trim", Transform3D(Basis(Vector3.UP, f.rng.randf() * TAU), Vector3(p.x + f.rng.randf_range(-0.3, 0.3), y + 0.035, p.y + f.rng.randf_range(-0.3, 0.3))), Vector3.ZERO, Vector3(0.16, 0.03, 0.04), Color(0.46, 0.34, 0.2) if k % 2 else Color(0.62, 0.5, 0.32))
	# Une branche morte en travers, des pierres moussues au pied du mur.
	var br = Vector2(-15.2, -32.6)
	var yb: float = c.sol(br.x, br.y)
	f.batch.box("trim", Transform3D(Basis(Vector3.UP, 0.7), Vector3(br.x, yb + 0.07, br.y)), Vector3.ZERO, Vector3(1.6, 0.12, 0.12), Color(0.36, 0.3, 0.24))
	for k in 6:
		var q: Vector2 = EMPRISE[1].lerp(EMPRISE[2], 0.1 + k * 0.12) + Vector2(0.25, 0.35)
		f.batch.box("trim", Transform3D(Basis(Vector3.UP, f.rng.randf() * TAU), Vector3(q.x, c.sol(q.x, q.y) + 0.05, q.y)), Vector3.ZERO, Vector3(0.22, 0.12, 0.16), Color(0.42, 0.46, 0.3).lerp(Color(0.5, 0.48, 0.4), f.rng.randf()))
	# Le lierre qui grimpe sur le mur, autour de l'angle nord-ouest, côté jardin.
	for k in 40:
		var e0: Vector2 = EMPRISE[1]
		var e1: Vector2 = EMPRISE[0] if k % 2 == 0 else EMPRISE[2]
		var t: float = f.rng.randf_range(0.15, 3.5)
		var dn: Vector2 = (e1 - e0).normalized()
		var q: Vector2 = e0 + dn * t
		var vers_jardin = Vector2(-dn.y, dn.x)
		if not dedans(q + vers_jardin * 0.5, EMPRISE):
			vers_jardin = -vers_jardin
		var y: float = c.sol(q.x, q.y)
		var hh: float = f.rng.randf_range(0.05, 0.7)
		var lxf = Transform3D(Basis(Vector3.UP, atan2(dn.x, dn.y)), Vector3(q.x + vers_jardin.x * 0.125, y + hh, q.y + vers_jardin.y * 0.125))
		f.batch.box("trim", lxf, Vector3.ZERO, Vector3(0.03, f.rng.randf_range(0.12, 0.22), f.rng.randf_range(0.14, 0.26)), Color(0.14, 0.3, 0.12).lerp(Color(0.24, 0.38, 0.16), f.rng.randf()))


## Une fougère : une couronne de frondes arquées vert tendre.
static func fougere(c: Node3D, f, p: Vector2) -> void:
	var y: float = c.sol(p.x, p.y)
	var col = Color(0.3, 0.5, 0.16).lerp(Color(0.42, 0.58, 0.2), f.rng.randf())
	var l: float = f.rng.randf_range(0.28, 0.42)
	for i in 7:
		var a: float = TAU * i / 7.0 + f.rng.randf_range(-0.2, 0.2)
		var xf = Transform3D(Basis(Vector3.UP, a), Vector3(p.x, y, p.y))
		f.batch.box_tilted("trim", xf, Vector3(0, 0.12, l * 0.35), Vector3(0.09, 0.012, l * 0.7), -0.7, col)
		f.batch.box_tilted("trim", xf, Vector3(0, 0.2, l * 0.85), Vector3(0.08, 0.012, l * 0.45), 0.35, col.darkened(0.08))


## Des feuilles mortes au sol, brun-ocre, et quelques pousses de lierre.
static func _lierre_sol(c: Node3D, f, p: Vector2) -> void:
	for i in 14:
		var q = p + Vector2(f.rng.randf_range(-0.35, 0.35), f.rng.randf_range(-0.35, 0.35))
		var brun = Color(0.55, 0.4, 0.2).lerp(Color(0.66, 0.5, 0.26), f.rng.randf())
		f.batch.box("trim", Transform3D(Basis(Vector3.UP, f.rng.randf() * TAU), Vector3(q.x, c.sol(q.x, q.y) + 0.04, q.y)), Vector3.ZERO, Vector3(0.05, 0.012, 0.035), brun if i % 3 else Color(0.18, 0.3, 0.12))


# --- Les arbres -----------------------------------------------------------------------------------

static func _arbres(c: Node3D, f, parent: Node3D) -> void:
	# Les trois grands : le séquoia au fond, le cèdre bleu à droite, le second cèdre à gauche.
	sequoia(c, f, Vector2(-1.6, -40.6), 14.0)
	cedre_bleu(c, f, Vector2(-3.8, -29.9), 6.4, 2.7)
	cedre_bleu(c, f, Vector2(-8.4, -35.0), 5.2, 1.7)
	# L'épicéa sombre à gauche, et un second plus loin le long de la ruelle.
	epicea(c, f, Vector2(-12.2, -35.6), 19.0 * M)
	epicea(c, f, Vector2(2.6, -42.4), 16.0 * M)
	# Les bouleaux, troncs blancs, autour du séquoia.
	bouleau(c, f, Vector2(-4.6, -38.4), 15.0 * M, 11)
	bouleau(c, f, Vector2(0.9, -38.0), 12.0 * M, 4)
	bouleau(c, f, Vector2(-6.6, -40.0), 13.0 * M, 9)
	# Le petit sous-bois du fond, le long de la ruelle : chênes, charmes, ifs, cyprès.
	for a in [[Vector2(-9.8, -38.4), 12.0, 0], [Vector2(-5.2, -41.0), 10.0, 1], [Vector2(-14.6, -34.1), 10.0, 1], [Vector2(1.6, -43.0), 11.0, 0]]:
		feuillu(c, f, a[0], a[1] * M, a[2])
	if_(c, f, Vector2(-7.6, -38.9), 6.0 * M)
	if_(c, f, Vector2(-2.6, -42.0), 5.0 * M)
	for a in [[Vector2(4.6, -43.4), 9.0], [Vector2(5.6, -41.2), 8.0], [Vector2(6.4, -38.0), 7.5]]:
		cypres(c, f, a[0], a[1] * M)
	for p in [Vector2(-11.6, -37.0), Vector2(-8.6, -39.6), Vector2(-4.0, -42.0), Vector2(-0.6, -42.8), Vector2(3.2, -44.2), Vector2(-13.6, -35.6)]:
		var q: Vector2 = loin_des_murs(p, 0.6)
		arbuste(c, f, q, 0.55, Color(0.24, 0.4, 0.16).lerp(Color(0.34, 0.48, 0.2), f.rng.randf()), [], 4)
	# Le tilleul et le hêtre pourpre du côté de la rue, devant les maisons de la place.
	feuillu(c, f, Vector2(-17.0, -27.6), 12.0 * M, 1)
	feuillu(c, f, Vector2(-15.6, -29.6), 6.5, 2)
	# Le verger à l'est : des pommiers en fleurs, un cerisier du Japon rose, un genêt.
	var vergers = [Vector2(0.4, -31.3), Vector2(2.3, -32.0), Vector2(4.4, -33.0), Vector2(-0.4, -33.4), Vector2(1.6, -34.2), Vector2(3.6, -35.2), Vector2(5.6, -36.2)]
	for i in vergers.size():
		pommier(c, f, vergers[i], i)
	pommier(c, f, Vector2(2.6, -37.2), 6, Color(0.96, 0.62, 0.76), 0.75, 1.3)
	arbuste(c, f, loin_des_murs(Vector2(6.2, -34.6), 0.6), 0.55, Color(0.3, 0.46, 0.16), [Color(0.95, 0.76, 0.3), 0.45], 3)


static func _plante(c: Node3D, parent: Node3D, scene: String, nom: String, p: Vector2, graine: int, opt := {}) -> void:
	var n: Node3D = load(scene).instantiate()
	if scene == PLACE:
		n.set("espece", nom)
	else:
		n.set("plante", nom)
	n.set("graine", graine)
	n.set("options", opt)
	n.scale = Vector3.ONE * M
	n.position = Vector3(p.x, c.sol(p.x, p.y) - 0.02, p.y)
	n.rotation.y = graine * 1.37
	parent.add_child(n)


## Une boule à facettes (un ellipsoïde de rayons r), pour les couronnes et les buissons.
static func boule(f, centre: Vector3, r: Vector3, col: Color, n := 8, m := 4) -> void:
	for j in m:
		var p0 = -PI / 2.0 + PI * j / m
		var p1 = -PI / 2.0 + PI * (j + 1) / m
		for i in n:
			var a0 = TAU * i / n
			var a1 = TAU * (i + 1) / n
			var pts = []
			for q in [[a0, p0], [a1, p0], [a1, p1], [a0, p1]]:
				pts.append(centre + Vector3(cos(q[0]) * cos(q[1]) * r.x, sin(q[1]) * r.y, sin(q[0]) * cos(q[1]) * r.z))
			var am = (a0 + a1) / 2.0
			var pm = (p0 + p1) / 2.0
			var nn = Vector3(cos(am) * cos(pm), sin(pm), sin(am) * cos(pm))
			var t = float(j) / m
			f.batch.quad("trim", Transform3D.IDENTITY, pts, nn, col.lightened(0.14 * (1.0 - t)).lightened(0.04 * t))


# --- Les massifs ----------------------------------------------------------------------------------

static func _massifs(c: Node3D, f, parent: Node3D) -> void:
	var n = TERRASSE_N()
	# Au pied de la terrasse : les rosiers (rouge, orange, rose) et les pivoines roses.
	var couleurs = [Color("e0605a"), Color("e8823a"), Color("d04a8a"), Color("f4b0c0"), Color("e0605a")]
	for i in 5:
		var p: Vector2 = TERRASSE_O + TERRASSE_U * (-1.8 + i * 0.75) + n * (TERRASSE_P + 0.75)
		rosier(c, f, p, couleurs[i])
	for i in 4:
		var p: Vector2 = TERRASSE_O + TERRASSE_U * (-1.5 + i * 0.8) + n * (TERRASSE_P + 0.4)
		pivoine(c, f, p)
	# Autour du bassin : le grand cornouiller panaché, les acanthes en épis, la lavande.
	cornouiller(c, f, BASSIN + Vector2(-1.6, -1.3))
	for k in 3:
		var p: Vector2 = BASSIN + Vector2(1.9 + k * 0.3, -0.9 + k * 0.25)
		acanthe(c, f, p)
	for k in 4:
		var p: Vector2 = BASSIN + Vector2(-0.6 + k * 0.45, 1.7)
		var yy: float = c.sol(p.x, p.y)
		feuilles(f, Transform3D(Basis(), Vector3(p.x, yy + 0.16, p.y)), Vector3(0.24, 0.16, 0.24), 50, Color(0.5, 0.56, 0.5), 0.05, 0.2)
		for i in 14:
			var q = Vector3(p.x + f.rng.randf_range(-0.2, 0.2), yy + 0.34, p.y + f.rng.randf_range(-0.2, 0.2))
			f.batch.box("trim", Transform3D.IDENTITY, q, Vector3(0.022, 0.12, 0.022), Color(0.56, 0.44, 0.78).lerp(Color(0.46, 0.36, 0.7), f.rng.randf()))
	# La ceinture fleurie du bassin, comme sur la photo de juin : achillées blanches, ancolies roses,
	# géraniums vivaces bleus, quelques coquelicots, entre les touffes d'iris.
	var pts = contour_bassin()
	var fleurs = [Color(0.95, 0.93, 0.82), Color(0.94, 0.56, 0.72), Color(0.5, 0.52, 0.86), Color(0.86, 0.4, 0.62), Color(0.9, 0.22, 0.18), Color(0.96, 0.84, 0.3)]
	for k in pts.size():
		if k in [2, 4, 5, 7, 9, 24, 26, 14, 20]:
			continue
		var p: Vector2 = pts[k]
		var o2: Vector2 = p + (p - BASSIN).normalized() * f.rng.randf_range(0.3, 0.55)
		touffe(c, f, o2, fleurs[k % fleurs.size()])
	for k in [10, 17, 22, 0]:
		var p: Vector2 = pts[k]
		_iris(c, f, p + (p - BASSIN).normalized() * 0.6)
	# Un massif de vivaces au pied de la terrasse, devant les rosiers.
	for i in 14:
		var p: Vector2 = TERRASSE_O + TERRASSE_U * f.rng.randf_range(-2.0, 2.0) + n * (TERRASSE_P + f.rng.randf_range(1.15, 1.6))
		touffe(c, f, p, fleurs[i % fleurs.size()])
	# Des rosiers le long de l'allée, des rosiers tiges et un épine-vinette pourpre près du bassin.
	for i in 4:
		var p: Vector2 = ALLEE[1].lerp(ALLEE[3], i / 3.0) + Vector2(0.7, 0.3)
		rosier(c, f, p, [Color("d04a8a"), Color("e0605a"), Color("f4f0e6"), Color("e8823a")][i])
	for a in [Vector2(1.6, 1.7), Vector2(2.6, 0.7), Vector2(2.9, -0.6)]:
		rosier(c, f, BASSIN + a, Color("e0605a"), true)
	arbuste(c, f, BASSIN + Vector2(2.6, -2.4), 0.5, Color(0.42, 0.14, 0.18), [], 3)


## Une touffe de vivaces : un coussin de feuilles et une pluie de petites fleurs d'une couleur.
static func touffe(c: Node3D, f, p: Vector2, col: Color) -> void:
	var y: float = c.sol(p.x, p.y)
	var r: float = f.rng.randf_range(0.18, 0.28)
	feuilles(f, Transform3D(Basis(), Vector3(p.x, y + r * 0.55, p.y)), Vector3(r, r * 0.7, r), 36, Color(0.3, 0.48, 0.2).lerp(Color(0.44, 0.58, 0.28), f.rng.randf()), r * 0.2, 0.25, [col, 0.35])


static func pivoine(c: Node3D, f, p: Vector2) -> void:
	var y: float = c.sol(p.x, p.y)
	feuilles(f, Transform3D(Basis(), Vector3(p.x, y + 0.22, p.y)), Vector3(0.38, 0.24, 0.38), 60, Color(0.3, 0.52, 0.24), 0.07, 0.25)
	for i in 7:
		var q = Vector3(p.x + f.rng.randf_range(-0.3, 0.3), y + 0.42 + f.rng.randf() * 0.06, p.y + f.rng.randf_range(-0.3, 0.3))
		feuilles(f, Transform3D(Basis(), q), Vector3(0.06, 0.05, 0.06), 6, Color(0.98, 0.7, 0.82).lerp(Color(0.99, 0.92, 0.95), f.rng.randf() * 0.6), 0.06, 0.1, [], 4)


static func acanthe(c: Node3D, f, p: Vector2) -> void:
	var y: float = c.sol(p.x, p.y)
	feuilles(f, Transform3D(Basis(), Vector3(p.x, y + 0.14, p.y)), Vector3(0.35, 0.15, 0.35), 40, Color(0.26, 0.42, 0.2), 0.09, 0.2)
	for i in 3:
		var q = Vector3(p.x + f.rng.randf_range(-0.15, 0.15), y, p.y + f.rng.randf_range(-0.15, 0.15))
		var hh: float = f.rng.randf_range(0.7, 0.95)
		f.batch.box("trim", Transform3D.IDENTITY, q + Vector3(0, hh / 2.0, 0), Vector3(0.03, hh, 0.03), Color(0.35, 0.45, 0.28))
		for k in 7:
			f.batch.box("trim", Transform3D.IDENTITY, q + Vector3(0, hh * (0.45 + k * 0.075), 0), Vector3(0.08 - k * 0.006, 0.06, 0.08 - k * 0.006), Color(0.92, 0.86, 0.9).lerp(Color(0.72, 0.5, 0.66), float(k % 2) * 0.6))


# --- L'abri ---------------------------------------------------------------------------------------

## L'abri couvert du fond, au nord-ouest du verger, là où le plan montre un petit toit au bout de
## l'allée : quatre poteaux de chêne, un toit d'une pente en vieilles tuiles qui descend vers la ruelle,
## un fond de planches, et dessous le bois de chauffage rangé et une brouette.
static func _abri(c: Node3D, f) -> void:
	var p := ABRI
	var dir := (EMPRISE[4] - EMPRISE[3]).normalized()
	var xf := Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y) - PI / 2.0), Vector3(p.x, c.sol(p.x, p.y), p.y))
	# Dans xf : +X le long de la ruelle, +Z vers le jardin (l'ouvert), -Z vers le mur.
	var w := 1.8
	var d := 1.3
	var chene := Color(0.42, 0.34, 0.26)
	var hav := 1.05
	var har := 0.82
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var hp: float = hav if sz > 0.0 else har
			f.batch.box("trim", xf, Vector3(sx * (w / 2.0 - 0.05), hp / 2.0 - 0.1, sz * (d / 2.0 - 0.05)), Vector3(0.08, hp + 0.2, 0.08), chene)
			_solide(f, xf, Vector3(sx * (w / 2.0 - 0.05), hp / 2.0, sz * (d / 2.0 - 0.05)), Vector3(0.1, hp, 0.1))
	# Les sablières et le toit de tuiles en pente vers le fond.
	for sz in [-1.0, 1.0]:
		var hp: float = hav if sz > 0.0 else har
		f.batch.box("trim", xf, Vector3(0, hp, sz * (d / 2.0 - 0.05)), Vector3(w, 0.07, 0.08), chene.darkened(0.1))
	var pente := atan2(hav - har, d - 0.1)
	var tuile := Color(0.62, 0.38, 0.28)
	f.batch.box_tilted("roof", xf, Vector3(0, (hav + har) / 2.0 + 0.07, 0), Vector3(w + 0.3, 0.06, d + 0.35), -pente, tuile)
	for i in 8:
		f.batch.box_tilted("trim", xf, Vector3(-w / 2.0 - 0.1 + i * (w + 0.2) / 7.0, (hav + har) / 2.0 + 0.11, 0), Vector3(0.05, 0.03, d + 0.35), -pente, tuile.darkened(0.12 + 0.06 * (i % 2)))
	# Le fond de planches, côté mur.
	for i in 9:
		f.batch.box("trim", xf, Vector3(-w / 2.0 + 0.1 + i * (w - 0.2) / 8.0, har / 2.0, -d / 2.0 + 0.02), Vector3((w - 0.2) / 8.0 - 0.01, har, 0.03), Color(0.46, 0.38, 0.3).lerp(Color(0.36, 0.3, 0.24), f.rng.randf()))
	_solide(f, xf, Vector3(0, har / 2.0, -d / 2.0 + 0.02), Vector3(w, har, 0.06))
	# Le bois de chauffage rangé contre le fond : des bûches en bout, rondes et claires.
	for rang in 4:
		for i in 11:
			var bx: float = -0.7 + i * 0.13 + (0.06 if rang % 2 else 0.0)
			if bx > 0.7:
				continue
			var bxf := xf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(bx, 0.07 + rang * 0.12, -d / 2.0 + 0.3))
			f.batch.cylinder("trim", bxf, Vector3(0, -0.22, 0), 0.06, 0.44, Color(0.62, 0.5, 0.34).lerp(Color(0.5, 0.38, 0.26), f.rng.randf()), 6)
	_solide(f, xf, Vector3(0, 0.25, -d / 2.0 + 0.3), Vector3(1.5, 0.5, 0.44))
	# La brouette, sous l'auvent.
	var bxf := xf * Transform3D(Basis(Vector3.UP, 0.4), Vector3(0.55, 0, 0.35))
	f.batch.box("trim", bxf, Vector3(0, 0.26, 0), Vector3(0.34, 0.14, 0.5), Color(0.3, 0.42, 0.34))
	f.batch.cylinder("trim", bxf * Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3(0, 0.1, 0.32)), Vector3(0, -0.03, 0), 0.1, 0.06, Color(0.15, 0.15, 0.15), 8)
	for s in [-1.0, 1.0]:
		f.batch.box("trim", bxf, Vector3(s * 0.12, 0.2, -0.35), Vector3(0.03, 0.03, 0.5), Color(0.4, 0.32, 0.24))


# --- Le portique et la roue -----------------------------------------------------------------------

## Le vieux portique de balançoire, en tubes rouillés, sans ses balançoires.
static func _portique(c: Node3D, f, p: Vector2, rot: float) -> void:
	var y: float = c.sol(p.x, p.y)
	var xf = Transform3D(Basis(Vector3.UP, rot), Vector3(p.x, y, p.y))
	var rouille = Color(0.55, 0.3, 0.17)
	var l = 1.9
	var h = 1.0
	for s in [-1.0, 1.0]:
		for e in [-1.0, 1.0]:
			f.batch.box("trim", xf * Transform3D(Basis(Vector3.RIGHT, e * 0.28), Vector3(s * l / 2.0, h / 2.0, e * h * 0.14)), Vector3.ZERO, Vector3(0.035, h * 1.04, 0.035), rouille)
	f.batch.box("trim", xf, Vector3(0, h, 0), Vector3(l + 0.1, 0.04, 0.04), rouille.darkened(0.1))


## La roue de fer sur son poteau, au bord du bassin : une jante et des rayons en spirale.
static func _roue(c: Node3D, f, p: Vector2) -> void:
	var y: float = c.sol(p.x, p.y)
	var xf = Transform3D(Basis(Vector3.UP, 0.6), Vector3(p.x, y, p.y))
	var fer = Color(0.38, 0.22, 0.14)
	f.batch.box("trim", xf, Vector3(0, 0.25, 0), Vector3(0.06, 0.5, 0.06), fer)
	var r = 0.3
	var cy = 0.5
	for i in 16:
		var a = TAU * i / 16.0
		f.batch.box("trim", xf * Transform3D(Basis(Vector3.BACK, a), Vector3(cos(a) * r, cy + sin(a) * r, 0)), Vector3.ZERO, Vector3(0.025, 0.125, 0.025), fer)
	for s in 3:
		for k in 5:
			var t = (k + 0.5) / 5.0
			var a = TAU * s / 3.0 + t * 2.2
			var rr = r * t
			f.batch.box("trim", xf * Transform3D(Basis(Vector3.BACK, a + 0.9), Vector3(cos(a) * rr, cy + sin(a) * rr, 0)), Vector3.ZERO, Vector3(0.018, 0.08, 0.018), fer)
	f.batch.cylinder("trim", xf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, cy, -0.02)), Vector3.ZERO, 0.04, 0.05, fer, 8)
