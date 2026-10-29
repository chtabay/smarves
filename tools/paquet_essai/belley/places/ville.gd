extends RefCounted
## La ville de Belley sur ses emprises réelles (BD TOPO, bourg.json) : chaque maison monte sur son plan, à sa
## hauteur, avec son toit à deux pans ou en croupe, ses cheminées à pots ; les façades portent leurs fenêtres à
## volets dessinées par le shader (atelier/facade.gdshader). Les rues, les trottoirs et les places se drapent
## sur le relief. Les bâtiments qu'une scène reconstruit à la main (la cathédrale…) sont passés.

const OUTILS := preload("res://communes/belley/atelier/outils.gd")
const ARBRES := preload("res://communes/belley/places/arbres.gd")
const DOSSIER := "res://communes/belley/"
const UNITE := 2.4

## Les enduits de la note, et ceux de la planche (crème, sable, ocre pâle).
const ENDUITS := [Color("e4d7bd"), Color("d2be98"), Color("e8dcc2"), Color("ddc9a3"), Color("efe4cc"), Color("d9c7a5"), Color("e2cfa8")]
const PIERRES := [Color("ddd3bc"), Color("cfc3a6"), Color("d8ccb0")]
const TUILES := [Color("c27a50", 0.0), Color("b56b45", 0.0), Color("a8613f", 0.0), Color("c98a5e", 0.0), Color("b9744c", 0.0), Color("9c5a3e", 0.0)]
const ARDOISE := Color("4b535c", 0.0)
const ZINC := Color("8a9298", 0.4)
const BRIQUE := Color("b5603e", 0.9)
const POT := Color("c06a40", 0.9)

const ASPHALTE := Color("7c7d7c", 0.95)
const TROTTOIR := Color("c4bdae", 0.95)
const PAVE := Color("a9a397", 0.95)

## Les numéros des bâtiments (dans bourg.json) qu'une scène bâtit elle-même.
var passer := {2219: true}
var hauteur: Callable
var b: Dictionary


func _init(sol: Callable) -> void:
	hauteur = sol
	b = JSON.parse_string(FileAccess.get_file_as_string(DOSSIER + "bourg.json"))


## Bâtit les maisons en lots de 300 m (un maillage par lot, pour que le moteur écarte ce qui n'est pas vu).
func batir(parent: Node3D) -> void:
	var lots := {}
	var bats: Array = b.batiments
	for i in bats.size():
		if passer.has(i):
			continue
		var r: Array = bats[i].rect
		var cle := Vector2i(floori(r[0] * UNITE / 300.0), floori(r[1] * UNITE / 300.0))
		if not lots.has(cle):
			lots[cle] = []
		lots[cle].append(i)
	for cle in lots:
		var o := OUTILS.new(cle.x * 31 + cle.y)
		for i in lots[cle]:
			maison(o, bats[i], i)
		o.construire(parent, "Maisons_%d_%d" % [cle.x, cle.y])
	_rues(parent)
	var pts := []
	for a in b.arbres:
		pts.append([float(a[0]) * UNITE, float(a[1]) * UNITE])
	ARBRES.planter(parent, pts, hauteur)


func maison(o: RefCounted, m: Dictionary, graine: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine * 7919
	var poly := PackedVector2Array()
	for p in m.p:
		poly.append(Vector2(p[0], p[1]) * UNITE)
	if poly.size() < 3:
		return
	if Geometry2D.is_polygon_clockwise(poly):
		poly.reverse()
	var bas := INF
	var haut := -INF
	for p in poly:
		var y: float = hauteur.call(p.x, p.y)
		bas = minf(bas, y)
		haut = maxf(haut, y)
	var h: float = maxf(float(m.h) * UNITE, 2.6)
	var y0 := bas - 0.4
	var egout := haut + h
	var pierre: bool = m.mur == "pierre"
	var col: Color = PIERRES[rng.randi() % PIERRES.size()] if pierre else ENDUITS[rng.randi() % ENDUITS.size()]
	# Les murs, sur le plan réel ; les fenêtres sont celles du shader.
	for k in poly.size():
		var a := poly[k]
		var c := poly[(k + 1) % poly.size()]
		var e := c - a
		if e.length() < 0.2:
			continue
		var n := Vector3(e.y, 0, -e.x).normalized()
		o.mur(Vector3(a.x, y0, a.y), Vector3(c.x, y0, c.y), egout - y0, n, col, rng.randi() % 256)
	# Le toit, sur le rectangle qui serre le plan.
	var r: Array = m.rect
	var centre := Vector2(r[0], r[1]) * UNITE
	var ang: float = r[4]
	var lx: float = r[2] * UNITE
	var lz: float = r[3] * UNITE
	var ux := Vector2(cos(ang), sin(ang))
	var uz := Vector2(-sin(ang), cos(ang))
	if lz > lx:
		var t := lx
		lx = lz
		lz = t
		var tv := ux
		ux = uz
		uz = -tv
	var toit: Color = TUILES[rng.randi() % TUILES.size()]
	var genre := OUTILS.TUILE
	if m.toit == "ardoise":
		toit = ARDOISE
		genre = OUTILS.ARDOISE
	elif m.toit == "zinc" or m.toit == "plat":
		toit = ZINC
		genre = OUTILS.PEINT
	var plat: bool = m.toit == "plat" or float(m.rempli) < 0.45
	var debord := 0.45
	var dx := lx * 0.5 + debord
	var dz := lz * 0.5 + debord
	var montee := clampf(float(m.pente), 0.45, 1.0) * lz * 0.5
	if plat:
		_terrasse(o, poly, egout, toit if genre == OUTILS.PEINT else ZINC)
		return
	montee = minf(montee, 7.0)
	var p3 := func(v: Vector2, y: float) -> Vector3: return Vector3(v.x, y, v.y)
	var A := centre - ux * dx - uz * dz
	var B := centre + ux * dx - uz * dz
	var Cc := centre + ux * dx + uz * dz
	var D := centre - ux * dx + uz * dz
	var ye := egout - debord * montee / (lz * 0.5)
	var yf := egout + montee
	var croupe: bool = int(m.pans) == 4
	var retrait := (dz if croupe else 0.0)
	retrait = minf(retrait, dx * 0.9)
	var F1 := centre - ux * (dx - retrait)
	var F2 := centre + ux * (dx - retrait)
	o.pan(p3.call(A, ye), p3.call(B, ye), p3.call(F2, yf), p3.call(F1, yf), toit, genre)
	o.pan(p3.call(Cc, ye), p3.call(D, ye), p3.call(F1, yf), p3.call(F2, yf), toit, genre)
	if croupe:
		o.croupe(p3.call(D, ye), p3.call(A, ye), p3.call(F1, yf), toit, genre)
		o.croupe(p3.call(B, ye), p3.call(Cc, ye), p3.call(F2, yf), toit, genre)
	else:
		# Les pignons, de l'enduit de la maison, sous les rives.
		for bout in [[A, D, F1, -1.0], [B, Cc, F2, 1.0]]:
			var a2: Vector2 = bout[0] + ux * debord * -float(bout[3])
			var d2: Vector2 = bout[1] + ux * debord * -float(bout[3])
			var f2: Vector2 = bout[2] + ux * debord * -float(bout[3])
			var n := Vector3(ux.x, 0, ux.y) * float(bout[3])
			o.tri(p3.call(a2, egout), p3.call(d2, egout), p3.call(f2, yf - 0.1), n, col, OUTILS.PEINT)
	# La sous-face du débord, sombre : elle dessine l'égout.
	o.quad(p3.call(A, ye - 0.08), p3.call(B, ye - 0.08), p3.call(Cc, ye - 0.08), p3.call(D, ye - 0.08), Vector3.DOWN, Color(0.35, 0.3, 0.26, 0.9), OUTILS.PEINT)
	# Les cheminées : une ou deux souches de brique ou d'enduit, et leurs pots de terre.
	var nb := 1 + (1 if lx > 14.0 and rng.randf() < 0.6 else 0)
	for k in nb:
		var s := (-1.0 if k == 0 else 1.0) * rng.randf_range(0.2, 0.42) * lx
		var off := rng.randf_range(-0.25, 0.25) * lz
		var pc := centre + ux * s + uz * off
		var yc := yf - absf(off) / (lz * 0.5) * montee
		var enduit := rng.randf() < 0.5
		var cc: Color = col if enduit else BRIQUE
		var sx := rng.randf_range(0.6, 1.1)
		o.pave(Vector3(pc.x, yc - 1.0, pc.y), Vector3(sx, 2.2, 0.55), cc, ang, false, OUTILS.PEINT)
		o.pave(Vector3(pc.x, yc + 1.2, pc.y), Vector3(sx + 0.12, 0.14, 0.67), Color("d8cfbe", 0.9), ang, false, OUTILS.PEINT)
		var pots := 1 + rng.randi() % 3
		for q in pots:
			var px: Vector2 = pc + ux * ((q - (pots - 1) * 0.5) * 0.3)
			o.cylindre(Transform3D(Basis(), Vector3(px.x, yc + 1.34, px.y)), 0.11, 0.09, 0.42, 6, POT, OUTILS.PEINT)


func _terrasse(o: RefCounted, poly: PackedVector2Array, y: float, col: Color) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	for k in range(0, idx.size(), 3):
		var a := poly[idx[k]]
		var c := poly[idx[k + 1]]
		var d := poly[idx[k + 2]]
		o.tri(Vector3(a.x, y, a.y), Vector3(c.x, y, c.y), Vector3(d.x, y, d.y), Vector3.UP, col, OUTILS.PEINT)
	# L'acrotère.
	for k in poly.size():
		var a := poly[k]
		var c := poly[(k + 1) % poly.size()]
		var e := c - a
		if e.length() < 0.2:
			continue
		var n := Vector3(e.y, 0, -e.x).normalized()
		o.quad(Vector3(a.x, y, a.y), Vector3(c.x, y, c.y), Vector3(c.x, y + 0.5, c.y), Vector3(a.x, y + 0.5, a.y), n, Color("d8cfbe", 0.9), OUTILS.PEINT)


## Les rues et leurs trottoirs, puis les places, drapés sur le sol.
const AVEC_TROTTOIRS := ["secondary", "primary", "tertiary", "residential", "unclassified", "living_street"]


func _rues(parent: Node3D) -> void:
	var o := OUTILS.new(7)
	for r in b.routes:
		var pts := PackedVector2Array()
		for p in r.p:
			pts.append(Vector2(p[0], p[1]) * UNITE)
		var l: float = float(r.l) * UNITE
		var k: String = r.k
		if k in ["footway", "path", "steps", "track", "cycleway"]:
			ruban(o, pts, l, 0.06, TROTTOIR)
		elif k == "pedestrian":
			ruban(o, pts, l, 0.08, PAVE)
		else:
			if k in AVEC_TROTTOIRS:
				ruban(o, pts, l + 3.2, 0.1, TROTTOIR)
			ruban(o, pts, l, 0.13, ASPHALTE)
	for s in b.sols:
		var poly := PackedVector2Array()
		for p in s.p:
			poly.append(Vector2(p[0], p[1]) * UNITE)
		draper(o, poly, 0.12, ASPHALTE if s.k == "place" else PAVE)
	o.construire(parent, "Rues")


## Un ruban de largeur l le long d'une ligne, à dy au-dessus du sol, recoupé tous les 3 m pour suivre la pente.
func ruban(o: RefCounted, ligne: PackedVector2Array, l: float, dy: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in ligne.size() - 1:
		var a := ligne[i]
		var c := ligne[i + 1]
		var n := maxi(1, ceili(a.distance_to(c) / 3.0))
		for j in n:
			pts.append(a.lerp(c, float(j) / n))
	pts.append(ligne[ligne.size() - 1])
	if pts.size() < 2:
		return
	var g := []
	var d := []
	for i in pts.size():
		var t := (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var n := Vector2(-t.y, t.x) * l * 0.5
		var pg := pts[i] + n
		var pd := pts[i] - n
		g.append(Vector3(pg.x, hauteur.call(pg.x, pg.y) + dy, pg.y))
		d.append(Vector3(pd.x, hauteur.call(pd.x, pd.y) + dy, pd.y))
	for i in pts.size() - 1:
		o.quad(g[i], g[i + 1], d[i + 1], d[i], Vector3.UP, col, OUTILS.PEINT)
	# Un rond au bout, pour que les rues se raccordent.
	for bout in [0, pts.size() - 1]:
		var c := pts[bout]
		var yc: float = hauteur.call(c.x, c.y) + dy
		for q in 8:
			var a0 := TAU * q / 8.0
			var a1 := TAU * (q + 1) / 8.0
			o.tri(Vector3(c.x, yc, c.y), Vector3(c.x + cos(a0) * l * 0.5, yc, c.y + sin(a0) * l * 0.5), Vector3(c.x + cos(a1) * l * 0.5, yc, c.y + sin(a1) * l * 0.5), Vector3.UP, col, OUTILS.PEINT)


## Un sol plan (une place, une cour) drapé sur le relief en carreaux de 2 m.
func draper(o: RefCounted, poly: PackedVector2Array, dy: float, col: Color) -> void:
	var r := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		r = r.expand(p)
	var pas := 2.0
	var x := r.position.x
	while x < r.end.x:
		var z := r.position.y
		while z < r.end.y:
			if Geometry2D.is_point_in_polygon(Vector2(x + pas * 0.5, z + pas * 0.5), poly):
				var q := []
				for c in [Vector2(x, z), Vector2(x + pas, z), Vector2(x + pas, z + pas), Vector2(x, z + pas)]:
					q.append(Vector3(c.x, hauteur.call(c.x, c.y) + dy, c.y))
				o.quad(q[0], q[1], q[2], q[3], Vector3.UP, col, OUTILS.PEINT)
			z += pas
		x += pas
