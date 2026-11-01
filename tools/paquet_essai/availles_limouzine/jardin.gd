extends RefCounted
## Le jardin du 10 place Adrien-Bernard, derrière la maison aux volets blancs, d'après la vue aérienne
## (l'emprise relevée point par point), les photos de Guillaume et OpenStreetMap. Un grand jardin en pente
## douce vers le nord-est, qu'on contemple depuis la terrasse au dos de la maison : en contrebas le bassin
## en haricot à rebord de ciment, ses nénuphars et ses iris, la roue de fer et le cornouiller panaché ; la
## pelouse et son allée tondue ; à droite le grand cèdre bleu au tronc énorme et le verger de pommiers ; au
## fond le séquoia (30 m mesurés), l'épicéa, un second cèdre bleu, des bouleaux, un hêtre pourpre, et le
## petit sous-bois dont les arbres couvrent la ruelle qui longe le jardin ; les rosiers et les pivoines au
## pied de la terrasse, le vieux portique rouillé contre le mur de pierre.
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
const TERRASSE_O := Vector2(-12.6, -24.75)
const TERRASSE_U := Vector2(0.951, -0.308)
const TERRASSE_L := 4.2
const TERRASSE_P := 2.0

## Le bassin, en contrebas de la terrasse.
const BASSIN := Vector2(-9.2, -28.3)
const BASSIN_ROT := 0.45

## L'allée tondue, de l'escalier de la terrasse au sous-bois.
const ALLEE := [Vector2(-9.9, -25.9), Vector2(-7.0, -30.6), Vector2(-4.6, -33.6), Vector2(-2.6, -37.0), Vector2(-1.0, -40.4)]

## La lisière du sous-bois : de la rue à l'angle nord-ouest, puis le long de la ruelle.
const SOUS_BOIS := [Vector2(-18.3, -28.2), Vector2(-19.1, -31.8), Vector2(-13.8, -35.0), Vector2(-9.6, -37.7), Vector2(0.5, -43.3), Vector2(5.1, -45.9)]

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
	var x = -TERRASSE_L / 2.0
	while x < TERRASSE_L / 2.0 - 0.05:
		var l: float = minf(f.rng.randf_range(0.45, 0.75), TERRASSE_L / 2.0 - x)
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
		boule(f, pxf * Vector3(0, 0.2, 0), Vector3(0.14, 0.1, 0.14), Color(0.3, 0.5, 0.22))
		for k in 5:
			f.batch.box("trim", pxf, Vector3(f.rng.randf_range(-0.1, 0.1), 0.27, f.rng.randf_range(-0.1, 0.1)), Vector3(0.05, 0.04, 0.05), Color(0.86, 0.16, 0.2))


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
## voisins de l'est ; mousse et lichen sur le chaperon.
static func _murs(c: Node3D, f) -> void:
	for k in MURS:
		var a: Vector2 = EMPRISE[k]
		var b: Vector2 = EMPRISE[(k + 1) % EMPRISE.size()]
		var h = 0.75 if k <= 4 else 0.55
		var l = a.distance_to(b)
		var d = (b - a) / l
		# Côté ouest, le mur part du dernier pilier de la palissade blanche ; le portillon s'ouvre près
		# de l'angle nord-ouest, sur le chemin.
		var t0 = 2.45 if k == 0 else 0.0
		var trous = [[l - 0.95, l - 0.42]] if k == 0 else []
		var t = t0
		while t < l - 0.001:
			var t1 = minf(t + 0.6, l)
			var dans_trou = false
			for tr in trous:
				if t1 > tr[0] and t < tr[1]:
					dans_trou = true
			if dans_trou:
				t = t1
				continue
			_pan_de_mur(c, f, a + d * t, a + d * t1, h)
			t = t1
		# Un pilier à chaque angle, qui lie les deux pans.
		_pilier(c, f, b, h + 0.08, 0.3)
	_portillon(c, f)


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


## Le petit portillon de l'angle nord-ouest, sous les arbres : deux piliers de pierre, une porte de bois
## gris à claire-voie, entrouverte sur le chemin.
static func _portillon(c: Node3D, f) -> void:
	var a: Vector2 = EMPRISE[0]
	var b: Vector2 = EMPRISE[1]
	var l = a.distance_to(b)
	var d = (b - a) / l
	var p: Vector2 = a + d * (l - 0.95)
	var q: Vector2 = a + d * (l - 0.42)
	_pilier(c, f, p, 0.9, 0.24)
	_pilier(c, f, q, 0.9, 0.24)
	var y: float = c.sol(p.x, p.y)
	var bois = Color(0.5, 0.5, 0.44)
	# Le vantail pivote sur le pilier sud et s'ouvre de 30° vers le jardin.
	var ang = atan2(d.x, d.y) - PI / 2.0
	var gxf = Transform3D(Basis(Vector3.UP, ang + 0.5), Vector3(p.x, y, p.y)) * Transform3D(Basis(), Vector3(0.14, 0, 0))
	var lg = q.distance_to(p) - 0.26
	for yy in [0.12, 0.62]:
		f.batch.box("trim", gxf, Vector3(lg / 2.0, yy, 0), Vector3(lg, 0.05, 0.035), bois.darkened(0.1))
	for i in 6:
		f.batch.box("trim", gxf, Vector3(0.03 + i * (lg - 0.06) / 5.0, 0.38, 0), Vector3(0.035, 0.66, 0.03), bois.lerp(Color(0.6, 0.6, 0.54), f.rng.randf() * 0.4))
	f.batch.box_tilted("trim", gxf, Vector3(lg / 2.0, 0.37, 0.02), Vector3(lg * 1.1, 0.04, 0.03), 0.0, bois.darkened(0.15))
	f.batch.box("trim", gxf, Vector3(lg - 0.04, 0.45, 0.03), Vector3(0.03, 0.06, 0.03), Color(0.2, 0.2, 0.2))
	# Le seuil de terre battue qui sort vers le chemin.
	var m: Vector2 = (p + q) / 2.0
	f.batch.box("trim", Transform3D(Basis(Vector3.UP, ang), Vector3(m.x, c.sol(m.x, m.y) + 0.02, m.y)), Vector3.ZERO, Vector3(0.5, 0.03, 0.9), Color(0.46, 0.38, 0.28))


# --- Le sous-bois ---------------------------------------------------------------------------------

## Sous les arbres du fond et à l'angle nord-ouest : fougères, lierre au sol et sur le mur, houx, une
## branche morte, des pierres moussues ; et des arbres de plus qui ferment la voûte au-dessus du
## portillon.
static func _sous_bois(c: Node3D, f, parent: Node3D) -> void:
	for a in [[BUGEY, "chene", Vector2(-16.6, -32.4), 14, 14.0], [PLACE, "if", Vector2(-18.0, -29.6), 5, 6.5],
			[BUGEY, "charme", Vector2(-11.8, -36.6), 3, 10.0]]:
		_plante(c, parent, a[0], a[1], a[2], a[3], {"hauteur": a[4]})
	var n = 0
	var essais = 0
	while n < 70 and essais < 600:
		essais += 1
		var p = Vector2(f.rng.randf_range(-19.0, 5.0), f.rng.randf_range(-45.8, -27.0))
		var dl: float = _dist_ligne(p, SOUS_BOIS)
		if not dedans(p, EMPRISE) or dl > 3.0 or dl < 0.3:
			continue
		n += 1
		var genre: int = n % 5
		if genre < 3:
			fougere(c, f, p)
		elif genre == 3:
			_lierre_sol(c, f, p)
		else:
			var y: float = c.sol(p.x, p.y)
			boule(f, Vector3(p.x, y + 0.32, p.y), Vector3(0.4, 0.36, 0.4), Color(0.14, 0.26, 0.12).lerp(Color(0.22, 0.32, 0.14), f.rng.randf()), 7, 4)
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


static func _arbres(c: Node3D, f, parent: Node3D) -> void:
	# Les trois grands : le séquoia au fond, le cèdre bleu à droite, le second cèdre à gauche.
	sequoia(c, f, Vector2(-1.6, -40.6), 14.0)
	cedre_bleu(c, f, Vector2(-3.8, -29.9), 6.0, 2.6)
	cedre_bleu(c, f, Vector2(-8.4, -35.0), 5.0, 1.6)
	# L'épicéa sombre à gauche, et un second plus loin le long de la ruelle.
	_plante(c, parent, BUGEY, "cedre", Vector2(-12.2, -35.6), 3, {"hauteur": 19.0})
	_plante(c, parent, BUGEY, "cedre", Vector2(2.6, -42.4), 8, {"hauteur": 16.0})
	# Les bouleaux, troncs blancs, autour du séquoia.
	_plante(c, parent, PLACE, "bouleau", Vector2(-4.2, -38.6), 11, {"hauteur": 15.0})
	_plante(c, parent, PLACE, "bouleau", Vector2(0.9, -38.0), 4, {"hauteur": 12.0})
	_plante(c, parent, PLACE, "bouleau", Vector2(-6.6, -40.4), 9, {"hauteur": 13.0})
	# Le petit sous-bois du fond, le long de la ruelle : chênes, charmes, ifs, thuyas, et leurs couronnes
	# qui passent par-dessus le mur.
	for a in [[BUGEY, "chene", Vector2(-9.8, -38.4), 5, 13.0], [BUGEY, "charme", Vector2(-5.2, -41.6), 2, 11.0],
			[BUGEY, "charme", Vector2(-14.6, -34.1), 7, 10.0], [BUGEY, "chene", Vector2(1.6, -44.0), 12, 12.0],
			[PLACE, "if", Vector2(-7.6, -38.9), 6, 6.0], [PLACE, "if", Vector2(-2.6, -42.6), 3, 5.0],
			[LYON, "cypres", Vector2(5.0, -43.6), 4, 9.0], [LYON, "cypres", Vector2(6.0, -41.2), 9, 8.0],
			[LYON, "cypres", Vector2(6.8, -38.0), 2, 7.5], [BUGEY, "charme", Vector2(-17.2, -31.4), 5, 9.0]]:
		_plante(c, parent, a[0], a[1], a[2], a[3], {"hauteur": a[4]})
	for p in [Vector2(-11.6, -37.0), Vector2(-8.6, -39.6), Vector2(-4.0, -42.6), Vector2(-0.6, -43.4), Vector2(3.6, -45.0), Vector2(-13.6, -35.6)]:
		_plante(c, parent, LYON, "buisson", p, int(p.x * 7.0) & 31, {})
	# Le tilleul et le hêtre pourpre du côté de la rue, devant les maisons de la place.
	_plante(c, parent, PLACE, "tilleul", Vector2(-17.6, -27.4), 13, {"hauteur": 12.0})
	hetre_pourpre(c, f, Vector2(-16.0, -29.4), 6.5)
	# Le verger à l'est : des pommiers en fleurs, un cerisier du Japon rose, un genêt.
	var vergers = [Vector2(0.4, -31.3), Vector2(2.3, -32.0), Vector2(4.4, -33.0), Vector2(-0.4, -33.4), Vector2(1.6, -34.2), Vector2(3.6, -35.2), Vector2(5.6, -36.2)]
	for i in vergers.size():
		pommier(c, f, vergers[i], i)
	_plante(c, parent, BUGEY, "cerisier", Vector2(2.6, -37.2), 6, {"hauteur": 5.5, "saison": "fleurs"})
	_plante(c, parent, BUGEY, "arbuste_fleuri", Vector2(6.4, -34.6), 3, {"hauteur": 2.0, "fleurs": "f2c14e"})


## Un disque épais, dessus et dessous : les nappes du cèdre, qu'on voit aussi d'en bas.
static func disque(f, xf: Transform3D, r: float, ep: float, haut: Color, dessous: Color, n := 8) -> void:
	for i in n:
		var a0: float = TAU * i / n
		var a1: float = TAU * (i + 1) / n
		var p0 = Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 = Vector3(cos(a1) * r, 0, sin(a1) * r)
		var nn = Vector3(cos((a0 + a1) / 2.0), 0, sin((a0 + a1) / 2.0))
		f.batch.quad("trim", xf, [p0, p1, p1 + Vector3.UP * ep, p0 + Vector3.UP * ep], nn, haut.darkened(0.1))
		f.batch.tri("trim", xf, Vector3.UP * ep * 1.6, p0 + Vector3.UP * ep, p1 + Vector3.UP * ep, Vector3.UP, haut)
		f.batch.tri("trim", xf, Vector3.ZERO, p1, p0, Vector3.DOWN, dessous)


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


## Le séquoia : un tronc roux qui s'évase au pied, une flèche étroite de touffes vert sombre.
static func sequoia(c: Node3D, f, p: Vector2, h: float) -> void:
	var y: float = c.sol(p.x, p.y)
	var xf = Transform3D(Basis(), Vector3(p.x, y - 0.05, p.y))
	var roux = Color(0.55, 0.3, 0.2)
	f.batch.cylinder("trim", xf, Vector3.ZERO, 0.62, 0.5, roux.darkened(0.15), 10)
	var k = 0
	while k < 6:
		var hb = k * h * 0.16
		f.batch.cylinder("trim", xf, Vector3(0, hb, 0), 0.5 - k * 0.07, h * 0.16 + 0.02, roux.lerp(Color(0.62, 0.38, 0.26), float(k % 2) * 0.3), 9)
		k += 1
	var etages = 16
	for e in etages:
		var t = float(e) / (etages - 1)
		var yy = h * (0.2 + 0.8 * t)
		var r = lerpf(2.4, 0.3, pow(t, 0.9))
		var col = Color(0.2, 0.32, 0.17).lerp(Color(0.3, 0.42, 0.22), f.rng.randf() * 0.5)
		for s in 5:
			var a = TAU * s / 5.0 + e * 0.7
			var c2 = Vector3(cos(a) * r * 0.55, yy, sin(a) * r * 0.55)
			boule(f, xf * c2, Vector3(r * 0.55, h * 0.045, r * 0.55), col, 6, 3)
	boule(f, xf * Vector3(0, h * 0.98, 0), Vector3(0.25, 0.6, 0.25), Color(0.26, 0.38, 0.2), 6, 3)


## Le cèdre bleu de l'Atlas : un tronc épais qui se divise, des plateaux de rameaux bleu-gris étagés,
## larges et plats comme des nappes, qui retombent un peu à leur bout.
static func cedre_bleu(c: Node3D, f, p: Vector2, h: float, rayon: float) -> void:
	var y: float = c.sol(p.x, p.y)
	var xf = Transform3D(Basis(), Vector3(p.x, y - 0.05, p.y))
	var ecorce = Color(0.44, 0.4, 0.36)
	f.batch.cylinder("trim", xf, Vector3.ZERO, rayon * 0.15, h * 0.4, ecorce, 9)
	for b in 3:
		var a: float = TAU * b / 3.0 + 0.5
		var bxf = xf * Transform3D(Basis(Vector3.UP, -a) * Basis(Vector3.RIGHT, 0.3), Vector3(0, h * 0.34, 0))
		f.batch.cylinder("trim", bxf, Vector3.ZERO, rayon * 0.07, h * 0.5, ecorce.lightened(0.05), 7)
	var bleu = Color(0.46, 0.6, 0.62)
	var etages = 8
	for e in etages:
		var t: float = float(e) / (etages - 1)
		var yy: float = h * (0.42 + 0.52 * t)
		var r: float = rayon * lerpf(1.0, 0.45, t)
		var nb: int = 5 if t < 0.5 else (4 if t < 0.8 else 3)
		for s2 in nb:
			var a: float = TAU * s2 / nb + e * 1.1 + f.rng.randf_range(-0.4, 0.4)
			var d: float = r * f.rng.randf_range(0.4, 0.85)
			var col = bleu.lerp(Color(0.58, 0.7, 0.7), f.rng.randf() * 0.7).darkened(f.rng.randf() * 0.1)
			var cc = xf * Vector3(cos(a) * d, yy + f.rng.randf_range(-0.4, 0.4), sin(a) * d)
			var rr: float = r * f.rng.randf_range(0.4, 0.58)
			# La nappe : un disque plat, son dessous plus sombre, son bord qui retombe.
			disque(f, Transform3D(Basis(Vector3.UP, a), cc), rr, h * 0.018, col, col.lightened(0.04), 9)
			disque(f, Transform3D(Basis(Vector3.UP, a + 0.3), cc - Vector3(0, h * 0.018, 0)), rr * 1.1, h * 0.015, col.darkened(0.08), col.lightened(0.02), 9)
			disque(f, Transform3D(Basis(Vector3.UP, a), cc + Vector3(0, h * 0.018, 0)), rr * 0.65, h * 0.015, col.lightened(0.06), col, 8)
	boule(f, xf * Vector3(0, h, 0), Vector3(rayon * 0.2, h * 0.06, rayon * 0.2), bleu.lightened(0.1), 6, 3)


## Le hêtre pourpre : une couronne ronde et dense, feuillage rouge sombre.
static func hetre_pourpre(c: Node3D, f, p: Vector2, h: float) -> void:
	var y: float = c.sol(p.x, p.y)
	var xf = Transform3D(Basis(), Vector3(p.x, y - 0.05, p.y))
	f.batch.cylinder("trim", xf, Vector3.ZERO, 0.22, h * 0.5, Color(0.5, 0.48, 0.45), 8)
	var pourpre = Color(0.5, 0.25, 0.27)
	for i in 9:
		var a: float = TAU * i / 9.0
		var d: float = f.rng.randf_range(0.6, 1.5)
		boule(f, xf * Vector3(cos(a) * d, h * f.rng.randf_range(0.55, 0.85), sin(a) * d), Vector3(1.3, 1.1, 1.3), pourpre.lerp(Color(0.62, 0.32, 0.32), f.rng.randf() * 0.5), 7, 4)
	boule(f, xf * Vector3(0, h * 0.9, 0), Vector3(1.4, 1.1, 1.4), pourpre.lightened(0.05), 7, 4)


## Un vieux pommier : le tronc noueux et penché, une couronne basse et ronde, couverte de fleurs blanches.
static func pommier(c: Node3D, f, p: Vector2, graine: int) -> void:
	var y: float = c.sol(p.x, p.y)
	var xf = Transform3D(Basis(Vector3.UP, graine * 1.9), Vector3(p.x, y - 0.03, p.y))
	var ecorce = Color(0.4, 0.36, 0.3)
	f.batch.box_tilted("trim", xf, Vector3(0, 0.35, 0.05), Vector3(0.14, 0.75, 0.14), 0.18, ecorce)
	f.batch.box_tilted("trim", xf, Vector3(0, 0.82, 0.02), Vector3(0.11, 0.45, 0.11), -0.35, ecorce.lightened(0.06))
	for i in 4:
		var a: float = TAU * i / 4.0 + graine
		var bxf = xf * Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, 0.9), Vector3(0, 0.95, 0))
		f.batch.box("trim", bxf, Vector3(0, 0.3, 0), Vector3(0.06, 0.6, 0.06), ecorce)
	var vert = Color(0.5, 0.68, 0.32)
	for i in 6:
		var a: float = TAU * i / 6.0 + graine * 0.7
		var cc = xf * Vector3(cos(a) * 0.6, 1.35 + f.rng.randf_range(-0.1, 0.2), sin(a) * 0.6)
		boule(f, cc, Vector3(0.6, 0.42, 0.6), vert.lerp(Color(0.62, 0.74, 0.38), f.rng.randf() * 0.5), 8, 4)
		for k in 7:
			var q = cc + Vector3(f.rng.randf_range(-0.55, 0.55), f.rng.randf_range(-0.1, 0.4), f.rng.randf_range(-0.55, 0.55))
			f.batch.box("trim", Transform3D.IDENTITY, q, Vector3(0.09, 0.07, 0.09), Color(0.98, 0.96, 0.94).lerp(Color(0.98, 0.82, 0.88), f.rng.randf() * 0.5))


# --- Les massifs ----------------------------------------------------------------------------------

static func _massifs(c: Node3D, f, parent: Node3D) -> void:
	var n = TERRASSE_N()
	# Au pied de la terrasse : les rosiers (rouge, orange, rose) et les pivoines roses.
	var couleurs = ["e0605a", "e8823a", "d04a8a", "f4b0c0", "e0605a"]
	for i in 5:
		var p: Vector2 = TERRASSE_O + TERRASSE_U * (-1.8 + i * 0.75) + n * (TERRASSE_P + 0.75)
		_plante(c, parent, BUGEY, "arbuste_fleuri", p, 20 + i, {"hauteur": 1.4, "fleurs": couleurs[i]})
	for i in 4:
		var p: Vector2 = TERRASSE_O + TERRASSE_U * (-1.5 + i * 0.8) + n * (TERRASSE_P + 0.4)
		pivoine(c, f, p)
	# Autour du bassin : le grand cornouiller panaché, les acanthes en épis, la lavande.
	var o: Vector2 = BASSIN + Vector2(-1.6, -1.3)
	var y: float = c.sol(o.x, o.y)
	for i in 7:
		var a: float = TAU * i / 7.0
		boule(f, Vector3(o.x + cos(a) * 0.45, y + 0.55 + f.rng.randf() * 0.3, o.y + sin(a) * 0.45), Vector3(0.45, 0.4, 0.45), Color(0.74, 0.8, 0.52).lerp(Color(0.46, 0.62, 0.3), f.rng.randf() * 0.7), 7, 4)
	for k in 3:
		var p: Vector2 = BASSIN + Vector2(1.9 + k * 0.3, -0.9 + k * 0.25)
		acanthe(c, f, p)
	for k in 4:
		var p: Vector2 = BASSIN + Vector2(-0.6 + k * 0.45, 1.7)
		var yy: float = c.sol(p.x, p.y)
		boule(f, Vector3(p.x, yy + 0.18, p.y), Vector3(0.24, 0.18, 0.24), Color(0.5, 0.56, 0.5), 6, 3)
		for i in 8:
			f.batch.box("trim", Transform3D.IDENTITY, Vector3(p.x + f.rng.randf_range(-0.2, 0.2), yy + 0.36, p.y + f.rng.randf_range(-0.2, 0.2)), Vector3(0.025, 0.1, 0.025), Color(0.56, 0.44, 0.78))
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
	# Des rosiers et un épine-vinette pourpre le long de l'allée, des rosiers tiges près du verger.
	for i in 4:
		var p: Vector2 = ALLEE[1].lerp(ALLEE[3], i / 3.0) + Vector2(0.7, 0.3)
		_plante(c, parent, BUGEY, "arbuste_fleuri", p, 40 + i, {"hauteur": 1.2, "fleurs": ["d04a8a", "e0605a", "f4f0e6", "e8823a"][i]})
	for a in [Vector2(1.6, 1.7), Vector2(2.6, 0.7), Vector2(2.9, -0.6)]:
		var ab: Vector2 = BASSIN + a
		var ya: float = c.sol(ab.x, ab.y)
		f.batch.cylinder("trim", Transform3D.IDENTITY, Vector3(ab.x, ya, ab.y), 0.05, 0.4, Color(0.36, 0.3, 0.24), 6)
		for k in 3:
			boule(f, Vector3(ab.x + f.rng.randf_range(-0.25, 0.25), ya + 0.65 + k * 0.22, ab.y + f.rng.randf_range(-0.25, 0.25)), Vector3(0.5, 0.42, 0.5), Color(0.3, 0.5, 0.18).lerp(Color(0.46, 0.62, 0.22), f.rng.randf()), 7, 4)
	var ev: Vector2 = BASSIN + Vector2(2.6, -2.4)
	boule(f, Vector3(ev.x, c.sol(ev.x, ev.y) + 0.4, ev.y), Vector3(0.55, 0.4, 0.55), Color(0.42, 0.16, 0.2), 7, 4)


## Une touffe de vivaces : un coussin de feuilles et une pluie de petites fleurs d'une couleur.
static func touffe(c: Node3D, f, p: Vector2, col: Color) -> void:
	var y: float = c.sol(p.x, p.y)
	var r: float = f.rng.randf_range(0.18, 0.28)
	boule(f, Vector3(p.x, y + r * 0.6, p.y), Vector3(r, r * 0.75, r), Color(0.3, 0.48, 0.2).lerp(Color(0.44, 0.58, 0.28), f.rng.randf()), 6, 3)
	for i in 10:
		var q = Vector3(p.x + f.rng.randf_range(-r, r) * 0.7, y + r * 1.15 + f.rng.randf_range(0.0, 0.08), p.y + f.rng.randf_range(-r, r) * 0.7)
		f.batch.box("trim", Transform3D.IDENTITY, q, Vector3(0.05, 0.035, 0.05), col.lerp(Color.WHITE, f.rng.randf() * 0.15))


static func pivoine(c: Node3D, f, p: Vector2) -> void:
	var y: float = c.sol(p.x, p.y)
	boule(f, Vector3(p.x, y + 0.22, p.y), Vector3(0.38, 0.24, 0.38), Color(0.3, 0.52, 0.24), 7, 3)
	for i in 7:
		var q = Vector3(p.x + f.rng.randf_range(-0.3, 0.3), y + 0.42 + f.rng.randf() * 0.06, p.y + f.rng.randf_range(-0.3, 0.3))
		boule(f, q, Vector3(0.08, 0.07, 0.08), Color(0.98, 0.7, 0.82).lerp(Color(0.99, 0.92, 0.95), f.rng.randf() * 0.6), 5, 3)


static func acanthe(c: Node3D, f, p: Vector2) -> void:
	var y: float = c.sol(p.x, p.y)
	boule(f, Vector3(p.x, y + 0.15, p.y), Vector3(0.35, 0.16, 0.35), Color(0.26, 0.42, 0.2), 7, 3)
	for i in 3:
		var q = Vector3(p.x + f.rng.randf_range(-0.15, 0.15), y, p.y + f.rng.randf_range(-0.15, 0.15))
		var hh: float = f.rng.randf_range(0.7, 0.95)
		f.batch.box("trim", Transform3D.IDENTITY, q + Vector3(0, hh / 2.0, 0), Vector3(0.03, hh, 0.03), Color(0.35, 0.45, 0.28))
		for k in 7:
			f.batch.box("trim", Transform3D.IDENTITY, q + Vector3(0, hh * (0.45 + k * 0.075), 0), Vector3(0.08 - k * 0.006, 0.06, 0.08 - k * 0.006), Color(0.92, 0.86, 0.9).lerp(Color(0.72, 0.5, 0.66), float(k % 2) * 0.6))


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
