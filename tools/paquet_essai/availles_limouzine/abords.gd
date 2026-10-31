extends RefCounted
## Les abords des lieux retravaillés d'Availles-Limouzine, posés après les bâtiments : ce qui n'est ni
## une maison ni une rue. La place de l'Église (ses tilleuls taillés, le calvaire au serpent, les deux
## puits au pied de l'église) ; le lavoir du Fond de la Ville au bord de la Vienne, derrière la porte de
## la Rivière ; la place Adrien-Bernard et le parc du numéro 10.
##
## construire(c) reçoit la scène du bourg (availles.gd) : son sol(x, z), ses matières, ses nœuds.

const FACADES := preload("res://scripts/village/facades.gd")
const ARBRE := "res://bibliotheque/arbres-de-place/1/arbre.tscn"
const OBJET := "res://bibliotheque/mobilier-de-place/1/objet.tscn"
## Les briques de la bibliothèque sont en mètres ; le bourg compte en unités de 2,4 m.
const M := 1.0 / 2.4

const GRANITE := Color(0.62, 0.57, 0.52)
const CALCAIRE := Color(0.84, 0.8, 0.7)
const FER := Color(0.13, 0.13, 0.14)
const PORTEE := 90.0


static func construire(c: Node3D) -> void:
	var noeud := Node3D.new()
	noeud.name = "Abords"
	c.add_child(noeud)
	var f = FACADES.new(noeud, Polices.texte(), 860150)
	# Chaque lieu a ses maillages, que la caméra écarte quand il est hors champ ; les arbres, les
	# moellons et le petit mobilier s'effacent au-delà de PORTEE unités.
	var lieux := [["Eglise", _place_eglise], ["Lavoir", _lavoir], ["AdrienBernard", _place_adrien_bernard]]
	for l in lieux:
		var sous := Node3D.new()
		sous.name = l[0]
		noeud.add_child(sous)
		f.parent = sous
		l[1].call(c, f, sous)
		f.commit(c._mats, c._mats.glass, "Abords_" + l[0])
		for g in sous.find_children("*", "GeometryInstance3D", true, false):
			if not str(g.name).ends_with("_wall") and not str(g.name).ends_with("_roof"):
				(g as GeometryInstance3D).visibility_range_end = PORTEE
				(g as GeometryInstance3D).visibility_range_end_margin = 10.0
				(g as GeometryInstance3D).visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF


## Un tilleul de la bibliothèque, taillé en tête de chat comme ceux des places du Poitou, pied en (x, z).
static func tilleul(c: Node3D, parent: Node3D, x: float, z: float, graine: int, hauteur := 7.0, espece := "tilleul") -> void:
	var a: Node3D = load(ARBRE).instantiate()
	a.espece = espece
	a.graine = graine
	a.options = {"hauteur": hauteur, "vent": 0.4}
	a.scale = Vector3.ONE * M
	a.position = Vector3(x, c.sol(x, z) - 0.02, z)
	a.rotation.y = graine * 1.7
	parent.add_child(a)


## Un objet de la bibliothèque (banc, lampadaire, fontaine…), en (x, z), tourné de rot (radians).
static func objet(c: Node3D, parent: Node3D, nom: String, x: float, z: float, rot: float, graine := 1, opt := {}, dy := 0.0) -> Node3D:
	var o: Node3D = load(OBJET).instantiate()
	o.objet = nom
	o.graine = graine
	o.options = opt
	o.scale = Vector3.ONE * M
	o.position = Vector3(x, c.sol(x, z) + dy, z)
	o.rotation.y = rot
	parent.add_child(o)
	return o


# --- La place de l'Église ------------------------------------------------------------------------
## D'après la vue aérienne de l'IGN : une grande place de sable stabilisé, ocre rose, sur l'ancien
## cimetière, devant la façade ouest ; trois rangées de tilleuls taillés (le long de la rue du nord, en
## travers au milieu, le long de la rue de l'Église au sud), un grand tilleul libre près du calvaire ;
## le calvaire, sa croix de pierre et le serpent enroulé autour d'une amphore, le visage encapuchonné
## qui pleure à sa base ; les deux puits au pied de l'église. Le sol et le nivellement sont dans zones.json.

const RANGEES_EGLISE := [
	[Vector2(-97.2, -74.7), Vector2(-88.2, -69.8), 6],
	[Vector2(-101.4, -69.6), Vector2(-93.6, -65.4), 5],
	[Vector2(-104.6, -65.4), Vector2(-91.4, -60.6), 8],
]


static func _place_eglise(c: Node3D, f, parent: Node3D) -> void:
	var g := 11
	for r in RANGEES_EGLISE:
		var a: Vector2 = r[0]
		var b: Vector2 = r[1]
		var n: int = r[2]
		for k in n:
			var p := a.lerp(b, float(k) / (n - 1))
			tilleul(c, parent, p.x, p.y, g, 6.2 + float(g % 3) * 0.5)
			g += 1
	tilleul(c, parent, -102.6, -71.2, 3, 9.5)
	_calvaire(c, f, Vector2(-100.9, -72.2))
	_puits(c, f, Vector2(-65.3, -60.7), 0.4)
	_puits(c, f, Vector2(-86.2, -58.9), 2.1)
	for p in [[-99.6, -68.3, 2.07], [-95.9, -66.3, 2.07], [-93.2, -71.2, -1.07]]:
		objet(c, parent, "banc", p[0], p[1], p[2], 3)
	objet(c, parent, "lampadaire", -96.8, -72.6, 0.0, 2)
	objet(c, parent, "corbeille", -97.6, -67.4, 0.0, 2)


## Le calvaire de la place : trois marches de granite, un socle carré où se tient le visage encapuchonné,
## le fût, l'amphore et le serpent qui s'y enroule, la croix de pierre au sommet.
static func _calvaire(c: Node3D, f, p: Vector2) -> void:
	var y: float = c.sol(p.x, p.y)
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(-57.6)), Vector3(p.x, y - 0.02, p.y))
	for k in 3:
		var s := 1.5 - k * 0.38
		f.batch.box("trim", xf, Vector3(0, 0.07 + k * 0.13, 0), Vector3(s, 0.14, s), GRANITE.darkened(0.04 * k))
	f.batch.box("wall", xf, Vector3(0, 0.7, 0), Vector3(0.5, 0.6, 0.5), CALCAIRE.darkened(0.06))
	f.batch.box("trim", xf, Vector3(0, 1.02, 0), Vector3(0.6, 0.06, 0.6), CALCAIRE)
	# Le visage encapuchonné, en relief sur la face du socle tournée vers l'église.
	f.batch.box("trim", xf, Vector3(0, 0.72, 0.26), Vector3(0.18, 0.24, 0.04), CALCAIRE.darkened(0.18))
	f.batch.box("trim", xf, Vector3(0, 0.71, 0.285), Vector3(0.1, 0.13, 0.02), CALCAIRE.darkened(0.05))
	# L'amphore, et le serpent qui monte autour d'elle.
	f.batch.cylinder("trim", xf, Vector3(0, 1.05, 0), 0.12, 0.08, CALCAIRE, 10)
	f.batch.cylinder("trim", xf, Vector3(0, 1.13, 0), 0.17, 0.22, CALCAIRE.lightened(0.04), 10)
	f.batch.cylinder("trim", xf, Vector3(0, 1.35, 0), 0.09, 0.1, CALCAIRE, 10)
	for i in 14:
		var a := i * 0.75
		var r := 0.19 - i * 0.006
		f.batch.box("trim", xf, Vector3(cos(a) * r, 1.08 + i * 0.04, sin(a) * r), Vector3(0.06, 0.045, 0.06), Color(0.36, 0.4, 0.34))
	# Le fût et la croix.
	f.batch.box("trim", xf, Vector3(0, 2.0, 0), Vector3(0.12, 1.3, 0.12), CALCAIRE.lightened(0.03))
	f.batch.box("trim", xf, Vector3(0, 2.42, 0), Vector3(0.62, 0.11, 0.11), CALCAIRE.lightened(0.03))
	for s in [-1.0, 1.0]:
		f.batch.box("trim", xf, Vector3(s * 0.31, 2.42, 0), Vector3(0.05, 0.16, 0.14), CALCAIRE.darkened(0.04))
	f.batch.box("trim", xf, Vector3(0, 2.68, 0), Vector3(0.16, 0.05, 0.14), CALCAIRE.darkened(0.04))


## Un vieux puits : sa margelle ronde de granite, deux montants de pierre, la traverse et la poulie.
static func _puits(c: Node3D, f, p: Vector2, rot: float) -> void:
	var xf := Transform3D(Basis(Vector3.UP, rot), Vector3(p.x, c.sol(p.x, p.y) - 0.03, p.y))
	f.batch.cylinder("wall", xf, Vector3.ZERO, 0.45, 0.42, GRANITE, 12)
	f.batch.cylinder("trim", xf, Vector3(0, 0.42, 0), 0.5, 0.07, GRANITE.lightened(0.08), 12)
	f.batch.cylinder("trim", xf, Vector3(0, 0.43, 0), 0.34, 0.07, Color(0.05, 0.05, 0.06), 12)
	for s in [-1.0, 1.0]:
		f.batch.box("trim", xf, Vector3(s * 0.46, 0.85, 0), Vector3(0.12, 0.85, 0.14), GRANITE.lightened(0.04))
	f.batch.box("trim", xf, Vector3(0, 1.3, 0), Vector3(1.06, 0.07, 0.07), FER)
	f.batch.cylinder("trim", xf * Transform3D(Basis(Vector3.BACK, PI / 2.0), Vector3(0.05, 1.22, 0)), Vector3.ZERO, 0.08, 0.06, FER, 8)
	f.batch.box("trim", xf, Vector3(0, 0.9, 0), Vector3(0.012, 0.6, 0.012), Color(0.45, 0.4, 0.33))
	f.batch.cylinder("trim", xf, Vector3(0, 0.52, 0), 0.07, 0.1, Color(0.3, 0.32, 0.34), 8)


# --- Le lavoir du Fond de la Ville ---------------------------------------------------------------
## Derrière la porte de la Rivière, au bout de la rue des Cavaliers, sur la rive de la Vienne, d'après
## photos : le chemin de gravier qui sort de l'arc, la pelouse de la rive et sa bordure de pierre basse au
## bord de l'eau, les trois marches où l'on descend laver, les pierres à laver inclinées vers la rivière,
## un banc de pierre ; deux saules pleureurs ; en face, sur l'autre rive, la culée de l'ancien pont. Le
## repère du lavoir : l'origine au bord de l'eau, +Z vers la rivière, +X vers l'amont (le nord-est).

const LAVOIR := Vector2(72.18, -9.38)
const LAVOIR_N := Vector2(0.784, -0.62)
const CULEE := Vector2(108.6, -38.2)


static func _lavoir(c: Node3D, f, parent: Node3D) -> void:
	var eau: float = c.data.niveau_eau
	var y0 := eau + 0.3
	var xf := Transform3D(Basis(Vector3.UP, atan2(LAVOIR_N.x, LAVOIR_N.y)), Vector3(LAVOIR.x, y0, LAVOIR.y))
	var pierre := Color(0.7, 0.64, 0.55)
	var dalle := Color(0.74, 0.7, 0.62)
	var lw := 4.4
	var prof := 2.4
	# Le quai : un massif de pierre posé sur la rive, son dessus de dalles, son parement côté eau.
	f.batch.box("wall", xf, Vector3(0, -0.6, -prof / 2.0), Vector3(lw + 1.2, 1.2, prof), pierre)
	# Le dessus est une pelouse, cernée côté eau d'une bordure de pierre basse ; le chemin de gravier
	# qui descend de la porte y arrive par l'arrière.
	f.batch.box("trim", xf, Vector3(0, 0.02, -prof / 2.0 - 0.15), Vector3(lw + 1.25, 0.05, prof - 0.25), Color(0.42, 0.56, 0.27))
	f.batch.box("trim", xf, Vector3(0, 0.05, -0.15), Vector3(lw + 1.25, 0.1, 0.3), dalle)
	var REM = load("res://communes/availles_limouzine/remarquables.gd")
	REM._moellons(f, xf, lw + 1.2, 0.0, pierre, -1.0)
	# Les trois marches qui descendent dans l'eau, au milieu.
	for k in 3:
		f.batch.box("trim", xf, Vector3(0.4, -0.12 - k * 0.12, 0.15 + k * 0.28), Vector3(1.6, 0.12, 0.3), dalle.darkened(0.08 + k * 0.06))
	# Les pierres à laver, inclinées vers la rivière, de part et d'autre des marches.
	for x in [-1.9, -1.2, 1.6, 2.2]:
		f.batch.box_tilted("trim", xf, Vector3(x, 0.08, -0.15), Vector3(0.6, 0.08, 0.42), deg_to_rad(18.0), dalle.lightened(0.05))
	# Le banc de pierre au fond du quai.
	f.batch.box("trim", xf, Vector3(1.4, 0.2, -prof + 0.3), Vector3(1.1, 0.08, 0.36), dalle.darkened(0.05))
	for x in [1.0, 1.8]:
		f.batch.box("trim", xf, Vector3(x, 0.08, -prof + 0.3), Vector3(0.14, 0.16, 0.3), pierre)
	# En face, la culée de l'ancien pont : un massif de pierre au ras de l'eau, envahi d'herbe.
	var cxf := Transform3D(Basis(Vector3.UP, atan2(LAVOIR_N.x, LAVOIR_N.y)), Vector3(CULEE.x, eau - 0.3, CULEE.y))
	f.batch.box("wall", cxf, Vector3(0, 0.75, 0), Vector3(3.0, 1.5, 2.4), pierre.darkened(0.1))
	f.batch.box("trim", cxf, Vector3(0, 1.52, 0), Vector3(3.1, 0.06, 2.5), Color(0.38, 0.5, 0.28))
	REM._moellons(f, cxf * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -1.2)), 3.0, 1.5, pierre.darkened(0.1))
	# Deux saules pleureurs sur la rive, de part et d'autre du lavoir, les branches jusqu'à l'herbe.
	for p in [[-4.2, -0.7], [5.6, -2.0]]:
		var q: Vector3 = xf * Vector3(p[0], 0, p[1])
		_saule_pleureur(f, Vector3(q.x, c.sol(q.x, q.z) - 0.05, q.z))


# --- La place Adrien-Bernard ---------------------------------------------------------------------
## D'après la vue aérienne de l'IGN, OpenStreetMap et les vues de la place : à l'ouest de la D8, la
## terrasse en demi-lune de la fontaine, son bassin en demi-cercle adossé au mur qui longe la route,
## le bec de bronze dans le mur ; autour, les huit bancs de béton blanc relevés dans OSM, les massifs
## cernés de murets de moellons, les deux escaliers (cinq marches au nord-ouest, deux au sud), la
## boîte à livres ; dix jeunes tilleuls en arc de cercle dans les pelouses, deux au nord le long de la route. À l'est de
## la route, la bande plantée de tilleuls, ses bancs, puis le parking devant les maisons. Le sol, le
## nivellement, les places et les voitures sont dans zones.json.

const AB_C := Vector2(-25.4, -19.4)
const AB_U := Vector2(0.152, 0.988)
const AB_W := Vector2(-0.988, 0.152)
const BANCS_AB := [
	Vector2(-28.22, -20.6), Vector2(-28.51, -19.36), Vector2(-28.28, -18.01), Vector2(-27.48, -16.89),
	Vector2(-23.31, -21.81), Vector2(-23.06, -20.44), Vector2(-22.82, -18.93), Vector2(-22.59, -17.62),
]
const ARBRES_AB := [
	Vector2(-25.2, -29.0), Vector2(-24.9, -27.0),
	Vector2(-22.9, -24.6), Vector2(-22.4, -22.6), Vector2(-21.9, -19.9), Vector2(-21.5, -17.3),
	Vector2(-21.1, -15.0), Vector2(-20.7, -12.8),
]


static func _ab(R: float, deg: float) -> Vector2:
	var a := deg_to_rad(deg)
	return AB_C + (AB_W * cos(a) + AB_U * sin(a)) * R


static func _place_adrien_bernard(c: Node3D, f, parent: Node3D) -> void:
	var REM = load("res://communes/availles_limouzine/remarquables.gd")
	var pierre := Color(0.74, 0.68, 0.58)
	var beton := Color(0.92, 0.91, 0.88)
	var y0: float = c.sol(AB_C.x, AB_C.y)
	var rot := atan2(AB_W.x, AB_W.y)
	# Le mur qui longe la route, côté est de la terrasse, du nord au sud des massifs.
	var mxf := Transform3D(Basis(Vector3.UP, rot), Vector3(AB_C.x, y0, AB_C.y))
	# Dans mxf : +Z vers l'ouest (le cœur de la terrasse), +X vers le nord (AB_U vaut le sud).
	f.batch.box("wall", mxf, Vector3(0, 0.2, -0.1), Vector3(10.4, 0.5, 0.25), pierre)
	REM._moellons(f, mxf * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 0, -0.22)), 10.4, 0.45, pierre, -0.05)
	f.batch.box("trim", mxf, Vector3(0, 0.47, -0.1), Vector3(10.45, 0.05, 0.3), pierre.lightened(0.15))
	# Le bassin en demi-cercle, adossé au mur : sa margelle, son eau, le bec de bronze dans le mur.
	var rb := 1.3
	var n := 14
	for k in n:
		var a0 := -PI / 2.0 + PI * k / n
		var a1 := -PI / 2.0 + PI * (k + 1) / n
		var am := (a0 + a1) / 2.0
		var q := Vector3(sin(am) * rb, 0.1, cos(am) * rb)
		var l := 2.0 * rb * sin(PI / n / 2.0) + 0.04
		f.batch.box("trim", mxf * Transform3D(Basis(Vector3.UP, am), q), Vector3.ZERO, Vector3(l, 0.24, 0.2), pierre.lightened(0.1))
		var e0 := Vector3(sin(a0) * rb, 0.12, cos(a0) * rb)
		var e1 := Vector3(sin(a1) * rb, 0.12, cos(a1) * rb)
		f.batch.tri("trim", mxf, Vector3(0, 0.12, 0.05), e1, e0, Vector3.UP, Color(0.24, 0.36, 0.38))
	f.batch.box("trim", mxf, Vector3(0, 0.35, 0.06), Vector3(0.22, 0.22, 0.08), Color(0.42, 0.33, 0.2))
	f.batch.box("trim", mxf, Vector3(0, 0.32, 0.16), Vector3(0.04, 0.04, 0.16), Color(0.42, 0.33, 0.2))
	f.batch.box("trim", mxf, Vector3(0, 0.22, 0.25), Vector3(0.03, 0.18, 0.03), Color(0.75, 0.86, 0.9))
	# Les murets de moellons des massifs : l'arc extérieur et l'arc intérieur, ouverts aux escaliers.
	for seg in [[-90.0, -68.0], [-56.0, 72.0]]:
		for R in [5.2, 3.4]:
			var hm := 0.15 if R > 4.0 else 0.06
			var a: float = seg[0]
			while a < seg[1] - 0.1:
				var b: float = minf(a + 8.0, seg[1])
				var pa := _ab(R, a)
				var pb := _ab(R, b)
				var m := (pa + pb) / 2.0
				var ya: float = c.sol(m.x, m.y)
				var t := Transform3D(Basis(Vector3.UP, atan2(pb.x - pa.x, pb.y - pa.y) + PI / 2.0), Vector3(m.x, ya, m.y))
				f.batch.box("wall", t, Vector3(0, hm / 2.0 - 0.05, 0), Vector3(pa.distance_to(pb) + 0.04, hm + 0.1, 0.2), pierre)
				f.batch.box("trim", t, Vector3(0, hm + 0.02, 0), Vector3(pa.distance_to(pb) + 0.06, 0.04, 0.24), pierre.lightened(0.12))
				a = b
	# Les escaliers : cinq marches qui descendent au nord-ouest, deux au sud.
	for e in [[-62.0, 5], [80.0, 2]]:
		var pm := _ab(4.3, e[0])
		var dirv := (pm - AB_C).normalized()
		var t := Transform3D(Basis(Vector3.UP, atan2(dirv.x, dirv.y)), Vector3(pm.x, c.sol(pm.x, pm.y), pm.y))
		for k in int(e[1]):
			f.batch.box("trim", t, Vector3(0, 0.05 - k * 0.04, -0.6 + k * 1.6 / e[1]), Vector3(1.3, 0.1, 1.6 / e[1] + 0.02), beton.darkened(0.08 + 0.03 * k))
	# Les bancs de béton blanc, sans dossier, tournés vers le bassin (ou vers la route, à l'est).
	for p in BANCS_AB:
		var vise: Vector2 = AB_C if p.x < -25.0 else p + AB_W * -1.0
		var dv: Vector2 = (vise - p).normalized()
		var t := Transform3D(Basis(Vector3.UP, atan2(dv.x, dv.y)), Vector3(p.x, c.sol(p.x, p.y), p.y))
		f.batch.box("trim", t, Vector3(0, 0.19, 0), Vector3(0.78, 0.07, 0.22), beton)
		for s in [-1.0, 1.0]:
			f.batch.box("trim", t, Vector3(s * 0.28, 0.08, 0), Vector3(0.1, 0.16, 0.18), beton.darkened(0.06))
	# La boîte à livres, sur son pied.
	var bl := Vector2(-26.99, -16.46)
	var tb := Transform3D(Basis(Vector3.UP, 0.4), Vector3(bl.x, c.sol(bl.x, bl.y), bl.y))
	f.batch.box("trim", tb, Vector3(0, 0.3, 0), Vector3(0.06, 0.6, 0.06), Color(0.3, 0.25, 0.2))
	f.batch.box("wall", tb, Vector3(0, 0.75, 0), Vector3(0.36, 0.34, 0.24), Color(0.2, 0.45, 0.6))
	f.batch.box("roof", tb, Vector3(0, 0.95, 0), Vector3(0.42, 0.05, 0.3), Color(0.5, 0.25, 0.2))
	f._glass(tb, Vector3(0, 0.75, 0.125), Vector2(0.26, 0.24), 0, false, Color.WHITE)
	# Les tilleuls : dix en arc de cercle dans les massifs, puis ceux du nord et de la bande de l'est.
	var g := 41
	for k in 10:
		var a := -80.0 + k * 17.0
		if absf(a + 62.0) < 7.0:
			continue
		var p := _ab(4.4, a)
		tilleul(c, parent, p.x, p.y, g, 6.0 + float(g % 3) * 0.6)
		g += 1
	for p in ARBRES_AB:
		tilleul(c, parent, p.x, p.y, g, 6.0 + float(g % 3) * 0.6)
		g += 1
	# Les lampadaires de la place.
	for q in [[-24.6, -23.2], [-23.9, -15.2], [-29.6, -24.8], [-19.0, -26.0]]:
		objet(c, parent, "lampadaire", q[0], q[1], 0.0, 3)



## Un saule pleureur : un tronc penché, une couronne en dôme, et le rideau des branches qui retombent
## jusqu'à un mètre du sol, en huit cartes courbées posées en cercle, d'un vert-gris.
static func _saule_pleureur(f, base: Vector3) -> void:
	var xf := Transform3D(Basis(), base)
	var ecorce := Color(0.4, 0.34, 0.27)
	var vert := Color(0.47, 0.59, 0.35)
	# Le tronc, penché, et quatre maîtresses branches qui partent en arc sous la couronne.
	f.batch.cylinder("trim", xf, Vector3.ZERO, 0.17, 1.7, ecorce, 8)
	for b in 4:
		var ab := TAU * b / 4.0 + 0.4
		var bxf := xf * Transform3D(Basis(Vector3.UP, -ab), Vector3(0, 1.55, 0))
		f.batch.box_tilted("trim", bxf, Vector3(0, 0.45, -0.5), Vector3(0.12, 0.1, 1.3), 0.6, ecorce.darkened(0.1))
	# La couronne : un dôme aplati, large en haut, d'anneaux de facettes.
	var R := 2.0
	var y0 := 2.35
	var hd := 1.15
	var n := 14
	var anneaux := 4
	for k in anneaux:
		var p0 := PI / 2.0 * k / anneaux
		var p1 := PI / 2.0 * (k + 1) / anneaux
		var r0 := R * cos(p0)
		var r1 := R * cos(p1)
		var h0 := y0 + hd * sin(p0)
		var h1 := y0 + hd * sin(p1)
		var c := vert.lerp(vert.lightened(0.18), float(k) / anneaux)
		for s in n:
			var a0 := TAU * s / n
			var a1 := TAU * (s + 1) / n
			var am := (a0 + a1) / 2.0
			var pm := (p0 + p1) / 2.0
			var nn := Vector3(cos(am) * cos(pm), sin(pm), sin(am) * cos(pm))
			f.batch.quad("trim", xf, [Vector3(cos(a0) * r0, h0, sin(a0) * r0), Vector3(cos(a1) * r0, h0, sin(a1) * r0),
				Vector3(cos(a1) * r1, h1, sin(a1) * r1), Vector3(cos(a0) * r1, h1, sin(a0) * r1)], nn, c)
	# Le dessous de la couronne, sombre, pour qu'on ne voie pas le ciel au travers.
	for s in n:
		var a0 := TAU * s / n
		var a1 := TAU * (s + 1) / n
		f.batch.tri("trim", xf, Vector3(0, y0 + 0.1, 0), Vector3(cos(a0) * R, y0, sin(a0) * R), Vector3(cos(a1) * R, y0, sin(a1) * R), Vector3.DOWN, vert.darkened(0.45))
	# Les rameaux qui retombent : dix-huit lanières courbes, sorties du bord du dôme, qui bombent un
	# peu vers l'extérieur puis descendent jusqu'à un mètre du sol ; des jours entre elles.
	var m := 18
	for s in m:
		var a: float = TAU * s / m + f.rng.randf_range(-0.08, 0.08)
		var bas: float = f.rng.randf_range(0.42, 0.8)
		var larg: float = f.rng.randf_range(0.42, 0.62)
		var dir := Vector3(cos(a), 0, sin(a))
		var cote: Vector3 = Vector3(-sin(a), 0, cos(a)) * larg / 2.0
		var pts: Array[Vector3] = []
		var seg := 4
		for k in seg + 1:
			var t := float(k) / seg
			var r := R * 0.92 + 0.32 * sin(t * PI * 0.8)
			pts.append(dir * r + Vector3(0, lerpf(y0 + 0.15, bas, t), 0))
		var c: Color = vert.darkened(f.rng.randf_range(0.0, 0.16))
		for k in seg:
			var up := pts[k]
			var dn := pts[k + 1]
			var w := 1.0 - 0.35 * float(k + 1) / seg
			var q := [up - cote * (1.0 - 0.35 * float(k) / seg), up + cote * (1.0 - 0.35 * float(k) / seg), dn + cote * w, dn - cote * w]
			var nrm := (dn - up).cross(cote).normalized()
			if nrm.dot(dir) < 0.0:
				nrm = -nrm
			f.batch.quad("trim", xf, q, nrm, c)
			f.batch.quad("trim", xf, q, -nrm, c.darkened(0.2))
