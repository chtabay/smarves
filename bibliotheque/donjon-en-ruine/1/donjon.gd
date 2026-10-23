extends Node3D
## Le donjon en ruine, venu du château baronnial de Chauvigny 0.2.2 (Le duke, MIT) : un donjon roman de
## 12 × 16 m éventré, ses murs de 14 à 32 m aux sommets déchiquetés, la géminée du mur ouest, les contreforts
## plats chaînés de pierre de taille, les trous de boulin, les traces des planchers et deux cheminées murales
## dedans, la grosse tour demi-ronde plaquée au nord, la tourelle d'escalier en vis au nord-est, l'aiguille
## (un pan de mur isolé au nord-ouest), le lierre et les éboulis. Posé sur un sol plat à y = 0 : les murs
## plongent de 2 m dessous, ce qui absorbe une pente douce. En mètres ; on entre par la brèche du mur est (+x).
const A := preload("res://bibliotheque/donjon-en-ruine/1/pierre.gd")
const H_DONJON := 32.0

## Les petits objets (pierres tombées, lierre) et les trous de boulin, à part : une commune peut les cacher de
## loin (visibility_range_end) pour alléger le regard.
var _petits: Node3D
var _boulins_g: Node3D
var _fait := false


func _ready() -> void:
	if _fait:
		return
	_fait = true
	_petits = A.groupe(self, "Petits")
	_boulins_g = A.groupe(self, "Boulins")
	var g := A.groupe(self, "Donjon")
	_donjon_ruine(g, Vector3.ZERO)
	A.fusionner(g)
	# comme à Chauvigny : les petits objets disparaissent à 70 m, les trous de boulin à 150 m
	for lot in [[_petits, 20.0, 70.0, 6.0], [_boulins_g, 40.0, 150.0, 10.0]]:
		A.fusionner(lot[0], lot[1])
		for n in lot[0].get_children():
			if n is GeometryInstance3D:
				n.visibility_range_end = lot[2]
				n.visibility_range_end_margin = lot[3]

## Le groupe où poser un petit objet : celui des petits objets pendant la construction, sinon g.
func _pg(g: Node3D) -> Node3D:
	return _petits if is_instance_valid(_petits) else g

## Une pierre tombée, bon marché (une boîte tournée : 12 triangles au lieu des 56 d'A.rocher), posée à p.
func _pierre(g: Node3D, p: Vector3, taille: Vector3, c: Variant = "ruine_sombre", graine := 0) -> void:
	var b := A.bloc(g, p + Vector3(0, taille.y * .3, 0), taille * Vector3(.9, .8, .9), c)
	b.rotation = Vector3(fposmod(graine * .37, .5) - .25, fposmod(graine * 1.91, TAU), fposmod(graine * .53, .4) - .2)

## Un sommet de ruine déchiqueté le long d'un mur (a → b au sol, sommet du mur à y, épaisseur e) : jamais un
## rythme de merlons (0.2, reprise : les photos 03 et 07). Une crête continue : de longs pans à quelques hauteurs,
## qui se suivent par des cassures en biais, et çà et là une brèche jusqu'à l'arase ; un seul maillage.
## h_max : le plus haut ressaut ; plat : un intervalle [début, fin] (en mètres depuis a) laissé à l'arase, pour
## qu'un oiseau s'y pose.
func _sommet_ruine(g: Node3D, a: Vector3, b: Vector3, y: float, e: float, h_max: float, graine: int, c: Variant = "ruine", plat := Vector2(-1, -1)) -> void:
	var d := b - a
	d.y = 0.0
	var l := d.length()
	if l < .5: return
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	# les points de la crête, tous les 0,9 à 1,6 m ; les hauteurs par paliers (_paliers)
	var ts: Array = [0.0]
	while ts[-1] < l - .9:
		ts.append(minf(float(ts[-1]) + rng.randf_range(.9, 1.6), l))
	if float(ts[-1]) < l: ts.append(l)
	var hs := _paliers(ts.size(), h_max, rng)
	for i in ts.size():
		var t: float = ts[i]
		if plat.y > plat.x:
			# l'arase plate de l'oiseau, et une pente douce pour y descendre
			var dist := maxf(plat.x - t, t - plat.y)
			if dist <= 0.0: hs[i] = 0.0
			elif dist < 1.6: hs[i] = minf(hs[i], dist * .8)
	var pts: Array = []
	for i in ts.size(): pts.append(Vector2(ts[i], hs[i]))
	_crete(g, a, d / l, y, e, pts, c)

## Des hauteurs de crête « par paliers » (n points, de 0 à h_max) : un niveau tenu sur deux à cinq points,
## à peine incliné, puis un autre, franchement différent ; une fois sur six, une brèche jusqu'à l'arase.
func _paliers(n: int, h_max: float, rng: RandomNumberGenerator) -> Array:
	var hs: Array = []
	var niveau := rng.randf_range(.35, 1.0) * h_max
	var pente := 0.0
	while hs.size() < n:
		var long := rng.randi_range(2, 5)
		pente = rng.randf_range(-.12, .12) * h_max
		for k in long:
			if hs.size() >= n: break
			hs.append(clampf(niveau + pente * k, 0.0, h_max))
		if rng.randf() < .17:
			if hs.size() < n: hs.append(0.0)
		var nouveau := rng.randf_range(.15, 1.0) * h_max
		if absf(nouveau - niveau) < .3 * h_max: nouveau = fposmod(niveau + .45 * h_max, h_max * .9) + .1 * h_max
		niveau = nouveau
	return hs

## Une crête de mur (maillage seul) : le profil « pts » ([distance depuis a, hauteur] croissant en distance),
## au-dessus de l'arase y, le long de dir (horizontal, unitaire), d'épaisseur e : ses deux faces, son dessus en
## pente d'un point à l'autre, ses deux bouts.
func _crete(g: Node3D, a: Vector3, dir: Vector3, y: float, e: float, pts: Array, c: Variant = "ruine") -> void:
	var perp := Vector3(-dir.z, 0, dir.x)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var o := Vector3(a.x, y - .06, a.z)
	var n := 0
	for i in pts.size() - 1:
		var p0: Vector2 = pts[i]
		var p1: Vector2 = pts[i + 1]
		if p0.y <= .01 and p1.y <= .01: continue
		var b0 := o + dir * p0.x
		var b1 := o + dir * p1.x
		var h0 := Vector3(0, p0.y + .06, 0)
		var h1 := Vector3(0, p1.y + .06, 0)
		for s in [-1.0, 1.0]:
			var f: Vector3 = perp * (float(s) * e * .5)
			# la face : un trapèze, du bas des deux points à leurs hauteurs
			_quad4(st, [b0 + f, b1 + f, b1 + f + h1, b0 + f + h0], perp * s)
		# le dessus, en pente
		var seg := (b1 + h1) - (b0 + h0)
		var nrm := seg.cross(perp).normalized()
		if nrm.y < 0.0: nrm = -nrm
		_quad(st, b0 + h0 - perp * (e * .5), seg, perp * e, nrm)
		n += 1
	# les deux bouts
	for bout in [[0, -1.0], [pts.size() - 1, 1.0]]:
		var p: Vector2 = pts[bout[0]]
		if p.y <= .01: continue
		var bb := o + dir * p.x - perp * (e * .5)
		_quad(st, bb, perp * e, Vector3(0, p.y + .06, 0), dir * float(bout[1]))
	if n == 0: return
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = A.mat(c)
	g.add_child(m)

## Une couronne de ruine sur un mur rond (maillage seul) : l'arc de cercle de centre p (sol de la tour),
## de rayon extérieur r et d'épaisseur e, de l'angle a0 à a1 en n pas, au-dessus de l'arase h ; hs : les
## hauteurs aux n + 1 sommets (fermée : le dernier rejoint le premier).
func _couronne(g: Node3D, p: Vector3, r: float, e: float, h: float, a0: float, a1: float, hs: Array, c: Variant = "ruine") -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := hs.size() - 1
	var k := 0
	for i in n:
		var u0: float = hs[i]
		var u1: float = hs[i + 1]
		if u0 <= .01 and u1 <= .01: continue
		var t0 := lerpf(a0, a1, float(i) / n)
		var t1 := lerpf(a0, a1, float(i + 1) / n)
		var d0 := Vector3(cos(t0), 0, sin(t0))
		var d1 := Vector3(cos(t1), 0, sin(t1))
		var y0 := p + Vector3(0, h - .06, 0)
		var hv0 := Vector3(0, u0 + .06, 0)
		var hv1 := Vector3(0, u1 + .06, 0)
		for face in [[r, 1.0], [r - e, -1.0]]:
			var rr: float = face[0]
			_quad4(st, [y0 + d0 * rr, y0 + d1 * rr, y0 + d1 * rr + hv1, y0 + d0 * rr + hv0], (d0 + d1).normalized() * float(face[1]))
		# le dessus
		var dessus := [y0 + d0 * (r - e) + hv0, y0 + d0 * r + hv0, y0 + d1 * r + hv1, y0 + d1 * (r - e) + hv1]
		var nt: Vector3 = ((dessus[2] as Vector3) - dessus[1]).cross((dessus[0] as Vector3) - dessus[1]).normalized()
		if nt.y < 0.0: nt = -nt
		_quad4(st, dessus, nt)
		k += 1
	if k == 0: return
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = A.mat(c)
	g.add_child(m)

## Des trous de boulin en grille sur une face (les trous des échafaudages, restés ouverts) : de petits carrés
## sombres, un seul maillage (deux triangles par trou). o : le coin bas de la face, u : le long de la face,
## n : la normale (dehors), l × h : l'étendue, pas : [horizontal, vertical]. Un trou sur huit manque.
func _boulins(g: Node3D, o: Vector3, u: Vector3, n: Vector3, l: float, h: float, pas := Vector2(1.5, 1.25), graine := 0, cote := .24) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var v := Vector3.UP
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var nx := maxi(1, int(l / pas.x))
	var ny := maxi(1, int(h / pas.y))
	var dx := l / nx
	var dy := h / ny
	var k := 0
	for j in ny:
		for i in nx:
			if rng.randf() < .12: continue
			var c := o + n * .03 + u * (dx * (i + .5) + (dx * .25 if j % 2 else 0.0)) + v * (dy * (j + .5))
			if (c - o).dot(u) > l: continue
			var s := cote * rng.randf_range(.8, 1.15) * .5
			var q := [c - u * s - v * s, c + u * s - v * s, c + u * s + v * s, c - u * s + v * s]
			# (le sens d'enroulement des faces de révolution de l'atelier : la face dehors est devant)
			for idx in ([0, 2, 3, 0, 1, 2] if u.cross(v).dot(n) < 0.0 else [0, 3, 2, 0, 2, 1]):
				st.set_normal(n)
				st.add_vertex(q[idx])
			k += 1
	if k == 0: return
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = A.mat("noir")
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# (dans leur groupe à part : on ne les voit pas de loin)
	var cible: Node3D = _boulins_g if is_instance_valid(_boulins_g) else g
	if cible != g and g.is_inside_tree() and cible.is_inside_tree():
		m.transform = cible.global_transform.affine_inverse() * g.global_transform
		cible.add_child(m)
	else:
		g.add_child(m)

## Du lierre au pied d'un mur : des buissons sans tronc, plaqués, couleur buis.
func _lierre(g: Node3D, p: Vector3, rayon := 1.0, graine := 0) -> void:
	A.buisson(g, p, rayon, Color("2f4a2a"), graine, false)

## Des pierres tombées autour d'un point.
func _eboulis(g: Node3D, p: Vector3, n: int, rayon: float, graine: int, c: Variant = "ruine_sombre") -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	for i in n:
		var a := rng.randf() * TAU
		var r := rng.randf_range(.3, 1.0) * rayon
		var q := Vector3(p.x + cos(a) * r, 0, p.z + sin(a) * r)
		q.y = 0.0 + .05
		var t := rng.randf_range(.4, 1.1)
		_pierre(_pg(g), q, Vector3(t, t * rng.randf_range(.45, .7), t * rng.randf_range(.7, 1.1)), c, graine + i)

## Le sommet ruiné d'une tour ronde (à la place du toit « ruine » de l'atelier, trop régulier : il faisait des
## merlons) : une couronne continue, par paliers et cassures en biais, avec une brèche (_couronne, _paliers).
## p : le pied de la tour.
func _sommet_rond(g: Node3D, p: Vector3, r: float, h: float, h_max: float, graine: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	var n := maxi(10, int(TAU * r / 1.3))
	A.cyl(g, p + Vector3(0, h - .1, 0), r - .1, .2, "ruine_sombre", -1, 14)
	var hs := _paliers(n, h_max, rng)
	# une vraie brèche, qui descend en biais jusqu'à l'arase (on ne fait pas le tour d'une couronne intacte)
	var k := rng.randi_range(0, n - 1)
	hs[k] = 0.0
	hs[(k + 1) % n] = minf(hs[(k + 1) % n], h_max * .3)
	hs.append(hs[0])
	var a0 := rng.randf() * TAU
	_couronne(g, p, r, .7, h, a0, a0 + TAU, hs)

func _donjon_ruine(root: Node3D, c: Vector3) -> void:
	var y0 := 0.0
	var g := A.groupe(root, "Donjon_Baronnial", Vector3(c.x, y0, c.z))
	var e := 1.8
	var xi := 6.0 - e * .5   # le plan des faces : l'axe des murs
	var zi := 8.0 - e * .5
	var hw := H_DONJON       # le mur ouest, moitié nord
	var hws := 30.0          # le mur ouest, moitié sud
	var hn := 28.8           # le mur nord
	var hsw := 25.6          # le mur sud, à l'ouest
	var hse := 14.0          # le mur sud, à l'est (effondré par paliers)
	var yf := 20.5           # le bas de la géminée
	var df := yf - 19.0      # (la géminée est dessinée à partir de 19 m, puis remontée)
	# --- le mur ouest, percé de la géminée, sommet déchiqueté ---
	A.bloc(g, Vector3(-xi, (yf - 2.0) * .5, 0), Vector3(e, yf + 2.0, 16.0), "ruine", true)
	for s in [-1.0, 1.0]:
		A.bloc(g, Vector3(-xi, yf + 2.25, s * 4.675), Vector3(e, 4.5, 6.65), "ruine", true)
	A.bloc(g, Vector3(-xi, (yf + 4.5 + hw) * .5, -4.5), Vector3(e, hw - yf - 4.5, 7.0), "ruine", true)
	A.bloc(g, Vector3(-xi, (yf + 4.5 + hws) * .5, 3.5), Vector3(e, hws - yf - 4.5, 9.0), "ruine", true)
	# (l'arase reste plate de z -5,8 à -3,2 : c'est là que se pose l'aigle, z 99,5)
	_sommet_ruine(g, Vector3(-xi, 0, -8.0), Vector3(-xi, 0, -1.0), hw, 1.2, 2.4, 7, "ruine", Vector2(2.0, 5.0))
	_sommet_ruine(g, Vector3(-xi, 0, -1.0), Vector3(-xi, 0, 8.0), hws, 1.2, 3.2, 17)
	# la géminée : colonnette, chapiteau, deux petits arcs, remplissages, appui, arc de décharge
	A.cyl(g, Vector3(-xi, 20.4 + df, 0), .14, 2.8, "taille", -1, 8)
	A.bloc(g, Vector3(-xi, 21.95 + df, 0), Vector3(.5, .3, .5), "taille")
	for s in [-1.0, 1.0]:
		var pa := A.arc(g, Vector3(-xi, 21.9 + df, s * .68), .5, .3, e, "taille", 0.0, PI, 10)
		pa.rotation.y = PI * .5
	A.bloc(g, Vector3(-xi, 23.1 + df, 0), Vector3(e, .8, 2.7), "ruine")
	A.bloc(g, Vector3(-xi, 22.5 + df, 0), Vector3(e, .5, .5), "ruine")
	for s in [-1.0, 1.0]:
		A.bloc(g, Vector3(-xi, 22.5 + df, s * 1.2), Vector3(e, .5, .35), "ruine")
	A.bloc(g, Vector3(-xi, 18.88 + df, 0), Vector3(e + .4, .25, 3.3), "taille")
	var decharge := A.arc(g, Vector3(-6.05, 22.4 + df, 0), 1.5, .35, .3, "taille", 0.0, PI, 14)
	decharge.rotation.y = PI * .5
	# une archère et deux petites romanes sur la face ouest (vues du pont)
	A.bloc(g, Vector3(-6.02, 7.5, -3.0), Vector3(.1, 1.5, .22), "noir")
	A.fenetre_romane(g, Vector3(-6.02, 14.0, 3.5), 1.0, 1.9, -PI * .5, false)
	A.fenetre_romane(g, Vector3(-6.02, 28.0, -3.4), .9, 1.7, -PI * .5, false)
	# --- le mur nord ---
	A.bloc(g, Vector3(0, (hn - 2.0) * .5, -zi), Vector3(12.0, hn + 2.0, e), "ruine", true)
	_sommet_ruine(g, Vector3(-6, 0, -zi), Vector3(6, 0, -zi), hn, 1.2, 3.4, 9)
	A.fenetre_romane(g, Vector3(3.9, 25.4, -8.02), 1.0, 2.0, PI, false)
	# --- le mur sud : 31 m à l'ouest, 17 m à l'est (effondré par paliers) ---
	A.bloc(g, Vector3(-3.0, (hsw - 2.0) * .5, zi), Vector3(6.0, hsw + 2.0, e), "ruine", true)
	A.bloc(g, Vector3(3.0, (hse - 2.0) * .5, zi), Vector3(6.0, hse + 2.0, e), "ruine", true)
	A.bloc(g, Vector3(.6, hse + 4.5, zi), Vector3(1.4, 9.0, e), "ruine")
	_sommet_ruine(g, Vector3(-6, 0, zi), Vector3(-.2, 0, zi), hsw, 1.2, 3.6, 13)
	_sommet_ruine(g, Vector3(1.4, 0, zi), Vector3(6, 0, zi), hse, 1.2, 2.8, 15)
	A.fenetre_romane(g, Vector3(-3.0, 18.0, 8.02), 1.0, 2.0, 0.0, false)
	A.bloc(g, Vector3(-3.0, 8.0, 8.02), Vector3(.22, 1.5, .1), "noir")
	# --- le mur est, éventré : deux moignons et l'ancienne porte, dont l'arc tient encore ---
	A.mur_ruine(g, Vector3(xi, 0, -8.0), Vector3(xi, 0, -2.3), 2.1, 4.6, e, "ruine", 31)
	A.mur_ruine(g, Vector3(xi, 0, 1.3), Vector3(xi, 0, 8.0), 1.4, 3.2, e, "ruine", 32)
	for z in [-2.65, 1.65]:
		A.bloc(g, Vector3(xi, 1.3, z), Vector3(e + .2, 2.6, .7), "taille", true)
	var arc_porte := A.arc(g, Vector3(xi, 2.6, -.5), 1.5, .55, e, "taille", 0.0, PI, 14)
	arc_porte.rotation.y = PI * .5
	A.bloc(g, Vector3(xi, 4.4, -.5), Vector3(e, .8, 2.4), "ruine")
	# --- les chaînes d'angle, à la hauteur de chaque mur ---
	for coin in [[-5.5, -7.5, hn], [-5.5, 7.5, hsw], [5.5, -7.5, hn - 4.0], [5.5, 7.5, hse]]:
		A.bloc(g, Vector3(coin[0], coin[2] * .5 - 1.0, coin[1]), Vector3(1.0, coin[2] + 2.0, 1.0), "taille")
	# --- les contreforts plats, chaînés de pierre de taille (deux à l'ouest, un au sud) ---
	_contrefort(g, Vector3(-6.0, 0, -5.6), Vector3(-1, 0, 0), 1.6, .55, hw - 6.0)
	_contrefort(g, Vector3(-6.0, 0, 5.6), Vector3(-1, 0, 0), 1.6, .55, hws - 7.0)
	_contrefort(g, Vector3(-5.0, 0, 8.0), Vector3(0, 0, 1), 1.5, .5, hsw - 5.0)
	# --- les trous de boulin, en grille, sur les trois grandes faces ---
	_boulins(g, Vector3(-6.0, 2.0, -7.6), Vector3(0, 0, 1), Vector3(-1, 0, 0), 6.0, hw - 4.5, Vector2(1.45, 1.3), 501)
	_boulins(g, Vector3(-6.0, 2.0, 1.6), Vector3(0, 0, 1), Vector3(-1, 0, 0), 6.0, hws - 4.5, Vector2(1.45, 1.3), 502)
	_boulins(g, Vector3(-6.0, 2.0, -1.4), Vector3(0, 0, 1), Vector3(-1, 0, 0), 2.8, yf - 3.0, Vector2(1.4, 1.3), 503)
	_boulins(g, Vector3(-5.7, 2.0, -8.0), Vector3(1, 0, 0), Vector3(0, 0, -1), 11.4, hn - 4.0, Vector2(1.5, 1.3), 504)
	_boulins(g, Vector3(-5.7, 2.0, 8.0), Vector3(1, 0, 0), Vector3(0, 0, 1), 5.5, hsw - 4.0, Vector2(1.5, 1.3), 505)
	_boulins(g, Vector3(.2, 2.0, 8.0), Vector3(1, 0, 0), Vector3(0, 0, 1), 5.5, hse - 3.0, Vector2(1.5, 1.3), 506)
	# --- à l'intérieur : les traces des planchers (bande sombre, trous de poutres, corbeaux) ---
	var niveaux := [5.0, 10.0, 15.0, 20.0, 25.5]
	var faces := [
		# [centre de la face, direction le long de la face, normale vers l'intérieur, longueur, hauteur du mur]
		[Vector3(-xi + e * .5, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 0), 12.4, hws],
		[Vector3(0, 0, -zi + e * .5), Vector3(1, 0, 0), Vector3(0, 0, 1), 8.4, hn],
		[Vector3(-3.0, 0, zi - e * .5), Vector3(1, 0, 0), Vector3(0, 0, -1), 6.0, hsw],
		[Vector3(3.0, 0, zi - e * .5), Vector3(1, 0, 0), Vector3(0, 0, -1), 6.0, hse],
	]
	for f in faces:
		var centre: Vector3 = f[0]
		var le: Vector3 = f[1]
		var nrm: Vector3 = f[2]
		var longueur: float = f[3]
		var ry := atan2(le.x, le.z) + PI * .5
		for niv in niveaux:
			if niv > float(f[4]) - 1.5: continue
			# (la géminée occupe le mur ouest de 20,5 à 25 : pas de plancher en travers)
			if f == faces[0] and niv > yf - 1.0 and niv < yf + 5.5: continue
			A.bloc(g, centre + nrm * .06 + Vector3(0, niv - .12, 0), Vector3(longueur, .26, .12), "ruine_sombre", false, ry)
			var n := int(longueur / 1.3)
			for i in n:
				var t := (float(i) + .5) / n - .5
				var p := centre + le * (t * longueur) + nrm * .05
				A.bloc(g, p + Vector3(0, niv - .5, 0), Vector3(.36, .4, .1), "noir", false, ry)
				if i % 2 == 0:
					A.bloc(g, p + nrm * .2 + Vector3(0, niv - .95, 0), Vector3(.42, .34, .5), "taille", false, ry)
	# --- deux cheminées murales dans le mur ouest ---
	for ch in [[2.0, 5.0], [-2.5, 10.0]]:
		var zc: float = ch[0]
		var yb: float = ch[1]
		var fx := -xi + e * .5
		A.bloc(g, Vector3(fx + .06, yb + .8, zc), Vector3(.12, 1.6, 1.7), "noir")
		for s in [-1.0, 1.0]:
			A.bloc(g, Vector3(fx + .25, yb + .75, zc + s * 1.05), Vector3(.5, 1.5, .4), "taille")
		A.bloc(g, Vector3(fx + .28, yb + 1.7, zc), Vector3(.56, .4, 2.6), "taille")
		A.bloc(g, Vector3(fx + .22, yb + 2.25, zc), Vector3(.44, .7, 2.3), "ruine_sombre")
		A.bloc(g, Vector3(fx + .17, yb + 2.95, zc), Vector3(.34, .7, 1.9), "ruine_sombre")
		A.bloc(g, Vector3(fx + .12, yb + 3.7, zc), Vector3(.24, .8, 1.4), "ruine_sombre")
	# --- par terre : des gravats, des blocs tombés, un linteau, des dalles ---
	A.bloc_taille(g, Vector3(1.5, 0, -3.5), Vector3(2.2, .7, .8), .3, "taille")
	A.bloc_taille(g, Vector3(-1.0, 0, 4.0), Vector3(1.1, .8, .9), 1.1, "ruine")
	A.bloc_taille(g, Vector3(2.4, 0, 3.2), Vector3(.8, .5, .7), .7, "ruine_sombre")
	for i in 7:
		var rng := RandomNumberGenerator.new()
		rng.seed = 300 + i
		var t := rng.randf_range(.4, .9)
		A.rocher(g, Vector3(rng.randf_range(-3.5, 3.8), .05, rng.randf_range(-5.5, 5.5)), Vector3(t, t * .5, t * .9), "ruine_sombre", 300 + i)
	for i in 5:
		A.bloc(g, Vector3(-2.5 + i * 1.1, .04, -1.0 + (i % 2) * .9), Vector3(.9, .08, .8), "taille", false, i * .3)
	# --- la grosse tour demi-ronde, plaquée contre la face nord (photo de l'entrée), presque aussi haute ---
	_demi_tour(g, Vector3(-.3, 0, -8.9), 3.8, 23.0, Vector3(0, 0, -1), 610)
	# dehors : le lierre et les pierres tombées
	_lierre(root, Vector3(c.x - 6.6, y0, c.z - 5.0), 1.3, 7)
	_lierre(root, Vector3(c.x - 6.5, y0, c.z + 6.5), 1.0, 8)
	_lierre(root, Vector3(c.x + 4.6, y0, c.z - 10.0), 1.1, 9)
	_eboulis(root, Vector3(c.x + 7.5, 0, c.z + 7.0), 7, 2.6, 310)
	_eboulis(root, Vector3(c.x + 5.6, 0, c.z - 11.4), 3, 1.4, 320)
	_eboulis(root, Vector3(c.x - 6.6, 0, c.z - 13.6), 5, 1.6, 330)
	# --- l'aiguille : un pan de mur isolé, haut et fin, au nord-ouest (vu du pont, il se détache sur le ciel) ---
	_aiguille(root, Vector3(c.x - 4.5, 0, c.z - 14.5))
	_eboulis(root, Vector3(c.x - 10.6, 0, c.z - 15.6), 4, 1.4, 340)
	# l'escalier en vis : une tourelle ronde accolée à l'angle nord-est, qui dépasse le moignon du mur est
	var vis := A.groupe(root, "TourelleEscalier_NE")
	A.tour(vis, Vector3(c.x + xi + .4, y0 - .2, c.z - zi - .3), 1.45, 20.0, "ruine", {"toit": "", "archeres": 4, "cordon": false, "base": 1.6})
	_sommet_rond(vis, Vector3(c.x + xi + .4, y0 - .2, c.z - zi - .3), 1.45, 20.0, 1.6, 761)
	# le lierre qui grimpe : à l'angle nord-ouest, sur la tour demi-ronde, sur le mur ouest
	_lierre_grimpant(root, Vector3(c.x - xi - .5, y0, c.z - zi - .95), Vector3(0, 0, -1), 6.5, 71)
	_lierre_grimpant(root, Vector3(c.x + 2.0, y0, c.z - 12.0), Vector3(.6, 0, -.8), 4.0, 72)
	_lierre_grimpant(root, Vector3(c.x - xi - .95, y0, c.z + 4.0), Vector3(-1, 0, 0), 5.5, 73)
	_lierre_grimpant(root, Vector3(c.x - xi - .95, y0, c.z - 3.6), Vector3(-1, 0, 0), 3.2, 74)

## Un contrefort plat contre une face (pied au sol local y = 0, « n » la normale de la face), large de w,
## saillant de s, haut de h : le corps en moellon de ruine, les deux arêtes chaînées de pierre de taille
## (une boutisse, une panneresse, en alternance), un glacis de taille au sommet.
func _contrefort(g: Node3D, pied: Vector3, n: Vector3, w: float, s: float, h: float, corps_c: Variant = "ruine", chaine := true) -> void:
	var ry := atan2(n.x, n.z)
	var u := Vector3(n.z, 0, -n.x)  # le long de la face
	var centre := pied + n * (s * .5)
	A.bloc(g, centre + Vector3(0, (h - 2.0) * .5, 0), Vector3(w, h + 2.0, s), corps_c, false, ry)
	if chaine:
		# les pierres d'angle, en un seul maillage : de chaque pierre, le devant et le flanc (4 triangles)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var devant := centre + n * (s * .5 + .025)
		var k := 0
		var y := .2
		while y < h - .5:
			var long := .62 if k % 2 == 0 else .36
			for cote in [-1.0, 1.0]:
				var arete: Vector3 = devant + u * (cote * (w * .5 + .025)) + Vector3(0, y, 0)
				_quad(st, arete, -u * (cote * long), Vector3(0, .4, 0), n)
				_quad(st, arete, -n * (s + .05), Vector3(0, .4, 0), u * cote)
			y += .44
			k += 1
		var m := MeshInstance3D.new()
		m.mesh = st.commit()
		m.material_override = A.mat("taille")
		g.add_child(m)
	var gl := A.bloc(g, centre + Vector3(0, h + .15, 0) - n * .05, Vector3(w + .1, .3, s + .25), "taille", false, ry)
	gl.rotation = Vector3(-.45, ry, 0)

## Un quadrilatère quelconque q[0] → q[3] (dans l'ordre du tour) dans un SurfaceTool, tourné vers « nrm »
## (même enroulement que _quad).
func _quad4(st: SurfaceTool, q: Array, nrm: Vector3) -> void:
	var u: Vector3 = (q[1] as Vector3) - q[0]
	var v: Vector3 = (q[3] as Vector3) - q[0]
	for idx in ([0, 2, 3, 0, 1, 2] if u.cross(v).dot(nrm) < 0.0 else [0, 3, 2, 0, 2, 1]):
		st.set_normal(nrm)
		st.add_vertex(q[idx])

## Un quadrilatère o, o + a, o + a + b, o + b dans un SurfaceTool, tourné vers « nrm » (même sens
## d'enroulement que les révolutions de l'atelier).
func _quad(st: SurfaceTool, o: Vector3, a: Vector3, b: Vector3, nrm: Vector3) -> void:
	var q := [o, o + a, o + a + b, o + b]
	for idx in ([0, 2, 3, 0, 1, 2] if a.cross(b).dot(nrm) < 0.0 else [0, 3, 2, 0, 2, 1]):
		st.set_normal(nrm)
		st.add_vertex(q[idx])

## La grosse tour demi-ronde plaquée contre un mur : un demi-cylindre (le côté plat dans le mur, « dehors »
## la direction de son ventre), un sommet déchiqueté, des archères, des trous de boulin, sa collision.
func _demi_tour(g: Node3D, p: Vector3, r: float, h: float, dehors: Vector3, graine: int) -> void:
	var t := A.groupe(g, "TourDemiRonde", p, atan2(dehors.x, dehors.z))
	# (dans le repère de la tour : le ventre vers +Z, le mur le long de X)
	var n := 12
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var bas := -2.5
	for i in n:
		var a0 := PI * float(i) / n
		var a1 := PI * float(i + 1) / n
		var q0 := Vector3(cos(a0) * r, 0, sin(a0) * r)
		var q1 := Vector3(cos(a1) * r, 0, sin(a1) * r)
		var v := [q0 + Vector3(0, bas, 0), q1 + Vector3(0, bas, 0), q1 + Vector3(0, h, 0), q0 + Vector3(0, h, 0)]
		var nr := [Vector3(cos(a0), 0, sin(a0)), Vector3(cos(a1), 0, sin(a1)), Vector3(cos(a1), 0, sin(a1)), Vector3(cos(a0), 0, sin(a0))]
		# (le sens d'enroulement des révolutions de l'atelier : la face dehors devant)
		for k in [0, 2, 3, 0, 1, 2]:
			st.set_normal(nr[k])
			st.add_vertex(v[k])
		# le dessus (on le voit du haut du donjon)
		for q in [Vector3.ZERO, q0, q1]:
			st.set_normal(Vector3.UP)
			st.add_vertex(q + Vector3(0, h, 0))
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = A.mat("ruine")
	t.add_child(m)
	for bx in [[r, 0.0, .42], [r * .84, .42, .76], [r * .53, .76, 1.0]]:
		A.collision(t, Vector3(0, (h + bas) * .5, r * (bx[1] + bx[2]) * .5), Vector3(2.0 * bx[0], h - bas, r * (bx[2] - bx[1])))
	# un talus de pierre de taille au pied, un cordon à mi-hauteur
	var rng := RandomNumberGenerator.new()
	rng.seed = graine
	for i in n:
		var am := PI * (float(i) + .5) / n
		var ry := -am + PI * .5
		A.bloc(t, Vector3(cos(am) * (r + .12), .6, sin(am) * (r + .12)), Vector3(r * PI / n * 1.08, 2.4, .5), "taille", false, ry)
		A.bloc(t, Vector3(cos(am) * (r + .1), h * .55, sin(am) * (r + .1)), Vector3(r * PI / n * 1.06, .3, .3), "taille", false, ry)
		# les trous de boulin, colonne par colonne
		if i % 2 == 0:
			_boulins(t, Vector3(cos(am) * r, 3.0, sin(am) * r), Vector3(-sin(am), 0, cos(am)), Vector3(cos(am), 0, sin(am)), .3, h - 5.0, Vector2(.3, 1.35), graine + i, .24)
	for am in [PI * .3, PI * .72]:
		A.bloc(t, Vector3(cos(am) * (r + .02), 9.0 + am * 2.0, sin(am) * (r + .02)), Vector3(.2, 1.5, .12), "noir", false, -am + PI * .5)
	# le sommet déchiqueté : une demi-couronne continue, plus haute contre le donjon, cassée en biais vers le ventre
	var hs := _paliers(n + 1, 3.2, rng)
	hs[0] = maxf(hs[0], 2.6)
	hs[n] = maxf(hs[n], 2.2)
	_couronne(t, Vector3.ZERO, r, .9, h, 0.0, PI, hs)

## L'aiguille du baronnial : un pan de mur isolé, haut et fin (1,2 m d'épaisseur, 2,6 de large), qui
## s'amincit en montant, son arête chaînée, ses trous de boulin, son sommet cassé en biseau.
func _aiguille(root: Node3D, p0: Vector3) -> void:
	var y := 0.0 - .2
	var a := A.groupe(root, "Aiguille", Vector3(p0.x, y, p0.z), .12)
	# (dans son repère : large selon X, mince selon Z)
	A.bloc(a, Vector3(0, 6.5, 0), Vector3(2.6, 17.0, 1.25), "ruine", true)
	A.bloc(a, Vector3(-.2, 17.5, 0), Vector3(2.1, 5.0, 1.15), "ruine")
	A.bloc(a, Vector3(-.45, 21.3, 0), Vector3(1.5, 2.6, 1.05), "ruine")
	A.bloc(a, Vector3(-.65, 23.0, 0), Vector3(.9, 1.2, .95), "ruine")
	A.bloc(a, Vector3(.55, 20.3, 0), Vector3(.7, .9, 1.0), "ruine")
	# l'arête ouest chaînée de pierre de taille
	var k := 0
	var yy := .4
	while yy < 20.0:
		var long := .7 if k % 2 == 0 else .4
		A.bloc(a, Vector3(-1.3 + long * .5 + (.2 if yy > 15.0 else 0.0), yy, 0), Vector3(long, .42, 1.3), "taille")
		yy += .46
		k += 1
	_boulins(a, Vector3(-1.1, 2.0, .64), Vector3(1, 0, 0), Vector3(0, 0, 1), 2.2, 16.0, Vector2(1.1, 1.3), 640)
	_boulins(a, Vector3(-1.1, 2.0, -.64), Vector3(1, 0, 0), Vector3(0, 0, -1), 2.2, 16.0, Vector2(1.1, 1.3), 641)
	A.bloc(a, Vector3(.2, 12.0, .64), Vector3(.18, 1.3, .06), "noir")

## Du lierre qui grimpe sur une face de mur : des touffes empilées contre la face (normale « nrm »),
## plus étroites vers le haut, jusqu'à la hauteur h.
func _lierre_grimpant(g: Node3D, pied: Vector3, nrm: Vector3, h: float, graine := 0) -> void:
	var n := maxi(2, int(h / 1.4))
	for i in n:
		var t := float(i) / maxf(n - 1, 1.0)
		var r := lerpf(1.15, .55, t)
		var p := pied + nrm * (.1 + r * .15) + Vector3(0, lerpf(0.0, h - r * .9, t), 0)
		A.buisson(g, p, r, Color("2f4a2a").lightened(.04 * (i % 3)), graine + i, false)
