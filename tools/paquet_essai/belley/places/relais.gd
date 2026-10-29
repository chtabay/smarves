extends RefCounted
## Le Relais des Lônes, au bout de la route du pont de Lucey, entre la route et le Rhône : le clin d'œil à
## l'auberge de la seconde planche. Une ferme de pierre en équerre sous ses tuiles creuses, volets vert d'eau,
## glycine et vigne vierge ; la cour de gravier où l'on se gare ; la terrasse sous les parasols et sous le grand
## platane ; la halle de bois au fond du pré, l'aire de jeux ; le mur bahut et sa barrière le long de la route ;
## les cyprès et les peupliers ; derrière, les lônes et leurs roselières.
##
## Repère : l'origine au coin de la cour sur la route (le tronçon réel de la route du pont de Lucey entre le
## carrefour de la route de la Tour et le chemin empierré) ; +X le long de la route vers le sud-est, +Z vers le
## Rhône, au nord-est. Le repère est retourné pour que, vue de la route, l'auberge soit à gauche et la halle à
## droite, comme sur la planche. Tout est posé sur le sol réel.

const OUTILS := preload("res://communes/belley/atelier/outils.gd")
const ARBRES := preload("res://communes/belley/places/arbres.gd")
const FENETRES := preload("res://communes/belley/atelier/fenetres.gd")

const ORIGINE := Vector2(7173.0, 639.2)
## Le lacet du repère : +Z regarde le nord-est, vers les lônes.
const LACET := deg_to_rad(138.1)

const MOELLON := Color("d9ccb2", 0.0)
const MOELLON_2 := Color("cdbd9e", 0.0)
const ANGLE := Color("e6d9bc", 1.0)
const TUILE := Color("c8743f", 1.0)
const VOLET := Color("7e9a96", 0.6)
const BOIS := Color("8a6440", 0.8)
const BOIS_CLAIR := Color("b08a5a", 0.8)
const GRAVIER := Color("d6c4a6", 0.95)
const PELOUSE := Color("8fb34c", 0.95)
const ARDOISE_HALLE := Color("5d6066", 0.0)
const VITRE := Color(0.18, 0.21, 0.25, 0.2)

var hauteur: Callable
var o: RefCounted
var base: Transform3D
var sol0 := 0.0


func _init(sol: Callable) -> void:
	hauteur = sol


## Un point du repère local (x, z) posé sur le sol, relevé de dy.
func p(x: float, z: float, dy := 0.0) -> Vector3:
	var w := base * Vector3(x, 0, z)
	return Vector3(w.x, hauteur.call(w.x, w.z) + dy, w.z)


## Un point du repère local à l'altitude du plancher de l'auberge.
func q(x: float, y: float, z: float) -> Vector3:
	var w := base * Vector3(x, 0, z)
	return Vector3(w.x, sol0 + y, w.z)


func batir(parent: Node3D) -> Node3D:
	base = Transform3D(Basis(Vector3.UP, LACET) * Basis.from_scale(Vector3(-1, 1, 1)), Vector3(ORIGINE.x, 0, ORIGINE.y))
	var w := base * Vector3(12, 0, 22)
	sol0 = hauteur.call(w.x, w.z) + 0.25
	o = OUTILS.new(7)
	var n := Node3D.new()
	n.name = "RelaisDesLones"
	parent.add_child(n)
	_cour()
	_corps(Vector2(2.0, 18.0), Vector2(28.0, 27.0), 6.4, 0)
	_corps(Vector2(28.0, 12.0), Vector2(38.0, 30.0), 6.0, 1)
	_corps(Vector2(-6.0, 20.0), Vector2(2.0, 27.0), 3.6, 2)
	_terrasse(n)
	_halle()
	_clotures()
	var mi: MeshInstance3D = o.construire(n, "Relais")
	mi.set_instance_shader_parameter("sol", sol0)
	_vegetation(n)
	_voitures(n)
	return n


## La cour de gravier et le pré, drapés sur le sol, et les places peintes.
func _cour() -> void:
	_draper(Rect2(-6, 0, 52, 30), GRAVIER)
	_draper(Rect2(46, 12, 22, 34), PELOUSE)
	for k in 4:
		var x := 8.0 + k * 3.0
		_trait(Vector2(x, 2.0), Vector2(x, 7.0))
	_trait(Vector2(8.0, 7.0), Vector2(17.0, 7.0))
	for k in 3:
		var x := 26.0 + k * 3.0
		_trait(Vector2(x, 9.0), Vector2(x, 14.0))


func _draper(r: Rect2, col: Color) -> void:
	var pas := 2.0
	var x := r.position.x
	while x < r.end.x - 0.01:
		var z := r.position.y
		while z < r.end.y - 0.01:
			# Une dalle de 2 m n'a pas tout à fait le ton de sa voisine : le gravier a des places plus usées.
			var k := float(absi(hash(Vector2i(int(x), int(z)))) % 100) / 100.0
			var c := col.darkened(k * 0.07) if k < 0.5 else col.lightened((k - 0.5) * 0.08)
			o.quad(p(x, z, 0.1), p(x + pas, z, 0.1), p(x + pas, z + pas, 0.1), p(x, z + pas, 0.1), Vector3.UP, c, OUTILS.PEINT)
			z += pas
		x += pas


func _trait(a: Vector2, b: Vector2) -> void:
	var d := (b - a).normalized()
	var nn := Vector2(-d.y, d.x) * 0.06
	o.quad(p(a.x + nn.x, a.y + nn.y, 0.12), p(b.x + nn.x, b.y + nn.y, 0.12), p(b.x - nn.x, b.y - nn.y, 0.12), p(a.x - nn.x, a.y - nn.y, 0.12), Vector3.UP, Color("f2efe6", 0.9), OUTILS.PEINT)


## Un corps de bâtiment, de a à b (coins opposés au sol, dans le repère), de h à l'égout, sous un toit à deux
## pans d'axe x et ses croupes de rive ; ses fenêtres à volets, ses portes, ses cheminées.
func _corps(a: Vector2, b: Vector2, h: float, rang: int) -> void:
	var c: Color = MOELLON if rang != 1 else MOELLON_2
	var x0 := a.x
	var x1 := b.x
	var z0 := a.y
	var z1 := b.y
	var long_x := (x1 - x0) >= (z1 - z0)
	var coins := [q(x0, -1.5, z0), q(x1, -1.5, z0), q(x1, -1.5, z1), q(x0, -1.5, z1)]
	var sols := [Vector3(0, 0, -1), Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(-1, 0, 0)]
	for k in 4:
		var u: Vector3 = coins[k]
		var v: Vector3 = coins[(k + 1) % 4]
		var nn: Vector3 = base.basis * sols[k]
		o.quad(u, v, v + Vector3(0, h + 1.5, 0), u + Vector3(0, h + 1.5, 0), nn, c)
		# Les chaînes d'angle, en pierre de taille claire.
		var y := 0.0
		var i := 0
		while y < h - 0.3:
			var lg := 0.5 if i % 2 == 0 else 0.3
			var d := (v - u).normalized()
			var off := nn * 0.04
			o.quad(u + Vector3(0, 1.5 + y, 0) + off, u + d * lg + Vector3(0, 1.5 + y, 0) + off, u + d * lg + Vector3(0, 1.5 + y + 0.32, 0) + off, u + Vector3(0, 1.5 + y + 0.32, 0) + off, nn, ANGLE)
			y += 0.36
			i += 1
	# Les baies : sur les longs pans, deux niveaux (un seul pour l'appentis).
	var niveaux := 1 if h < 4.0 else 2
	for face in [0, 2]:
		var zf := z0 if face == 0 else z1
		var sens := -1.0 if face == 0 else 1.0
		var l := x1 - x0
		var nb := int(l / 3.4)
		for k in nb:
			var x := x0 + (k + 0.5) * l / nb
			for niv in niveaux:
				var porte := niv == 0 and (k % 3 == 1)
				_baie(Vector3(x, 0.0 if porte else 1.0 + niv * 2.9, zf), Vector3(0, 0, sens), porte)
	if not long_x:
		for face in [1, 3]:
			var xf := x1 if face == 1 else x0
			var sens := 1.0 if face == 1 else -1.0
			var l := z1 - z0
			var nb := int(l / 3.6)
			for k in nb:
				var z := z0 + (k + 0.5) * l / nb
				for niv in niveaux:
					_baie(Vector3(xf, 1.0 + niv * 2.9, z), Vector3(sens, 0, 0), false)
	# Le toit : deux pans le long du plus grand côté, une croupe courte à chaque bout.
	var d := 0.5
	var montee := minf(x1 - x0, z1 - z0) * 0.5 * 0.55
	var ye := h - 0.2
	var yf := h + montee
	if long_x:
		var zm := (z0 + z1) * 0.5
		var r := (z1 - z0) * 0.35
		o.pan(q(x0 - d, ye, z0 - d), q(x1 + d, ye, z0 - d), q(x1 - r, yf, zm), q(x0 + r, yf, zm), TUILE)
		o.pan(q(x1 + d, ye, z1 + d), q(x0 - d, ye, z1 + d), q(x0 + r, yf, zm), q(x1 - r, yf, zm), TUILE)
		o.croupe(q(x0 - d, ye, z1 + d), q(x0 - d, ye, z0 - d), q(x0 + r, yf, zm), TUILE)
		o.croupe(q(x1 + d, ye, z0 - d), q(x1 + d, ye, z1 + d), q(x1 - r, yf, zm), TUILE)
		_cheminee(q(x0 + (x1 - x0) * 0.28, yf - 0.3, zm))
		if x1 - x0 > 16.0:
			_cheminee(q(x0 + (x1 - x0) * 0.72, yf - 0.3, zm))
	else:
		var xm := (x0 + x1) * 0.5
		var r := (x1 - x0) * 0.35
		o.pan(q(x1 + d, ye, z0 - d), q(x1 + d, ye, z1 + d), q(xm, yf, z1 - r), q(xm, yf, z0 + r), TUILE)
		o.pan(q(x0 - d, ye, z1 + d), q(x0 - d, ye, z0 - d), q(xm, yf, z0 + r), q(xm, yf, z1 - r), TUILE)
		o.croupe(q(x0 - d, ye, z0 - d), q(x1 + d, ye, z0 - d), q(xm, yf, z0 + r), TUILE)
		o.croupe(q(x1 + d, ye, z1 + d), q(x0 - d, ye, z1 + d), q(xm, yf, z1 - r), TUILE)
		_cheminee(q(xm, yf - 0.3, (z0 + z1) * 0.5))
	o.quad(q(x0 - d, ye - 0.06, z0 - d), q(x1 + d, ye - 0.06, z0 - d), q(x1 + d, ye - 0.06, z1 + d), q(x0 - d, ye - 0.06, z1 + d), Vector3.DOWN, Color(0.36, 0.3, 0.24, 0.9), OUTILS.PEINT)


## Une fenêtre à volets ouverts (ou une porte vitrée) sur un mur du repère : pied à `at` (local), n vers dehors.
func _baie(at: Vector3, n: Vector3, porte: bool) -> void:
	var b := base.basis * Basis(n.cross(Vector3.UP).normalized() * -1.0, Vector3.UP, n)
	var w := base * Vector3(at.x, 0, at.z)
	var t := Transform3D(b, Vector3(w.x, sol0 + at.y, w.z))
	# Les mêmes baies que celles de la ville (atelier/fenetres.gd), au niveau des façadiers de la bibliothèque.
	var g := absi(hash(at))
	if porte:
		FENETRES._porte(o, t * Transform3D(Basis(), Vector3(0, -0.55, 0)), Color("6b4a32", 0.7), g)
	else:
		FENETRES._fenetre(o, t, 1.0, 1.4, VOLET, g * 5 + 1, g % 3 == 0)


func _cheminee(pied: Vector3) -> void:
	o.boite(Transform3D(base.basis, pied + Vector3(0, 1.0, 0)), Vector3(0.9, 2.2, 0.6), MOELLON)
	o.boite(Transform3D(base.basis, pied + Vector3(0, 2.15, 0)), Vector3(1.05, 0.12, 0.75), ANGLE)


## La terrasse : le treillage à vigne devant la façade, les tables sous les parasols (bibliothèque).
func _terrasse(parent: Node3D) -> void:
	var y := 2.6
	for k in 6:
		var x := 6.0 + k * 3.2
		o.boite(Transform3D(base.basis, q(x, y * 0.5, 14.5)), Vector3(0.14, y, 0.14), BOIS)
		o.boite(Transform3D(base.basis, q(x, y, 16.2)), Vector3(0.12, 0.12, 3.6), BOIS)
	o.boite(Transform3D(base.basis, q(14.0, y + 0.06, 14.5)), Vector3(16.4, 0.12, 0.14), BOIS)
	for k in 14:
		var x := 6.0 + k * 1.2
		o.boule(q(x, y + 0.25, 15.0 + (k % 3) * 1.1), Vector3(0.9, 0.35, 0.8), Color("6f9e36"), 0.25, OUTILS.FEUILLE, 0.08, 0.6, 4, 7)
	var scene: PackedScene = load(Bibliotheque.scene("mobilier-de-place@1", "decor"))
	var tables := [Vector2(7, 12.5), Vector2(11.5, 13), Vector2(16, 12.5), Vector2(20.5, 13), Vector2(39.5, 15), Vector2(43.5, 18.5),
		Vector2(39.5, 22), Vector2(43.5, 25.5), Vector2(40, 28.5)]
	for i in tables.size():
		var m: Node3D = scene.instantiate()
		m.set("objet", "terrasse")
		m.set("graine", 3)
		m.set("options", {"toile": ["efe7d6", "efe7d6"]})
		m.position = p(tables[i].x, tables[i].y, 0.1)
		parent.add_child(m)
	# Les jardinières de bois qui ferment la terrasse sur la cour.
	for k in 5:
		var m: Node3D = scene.instantiate()
		m.set("objet", "jardiniere")
		m.set("graine", 11 + k)
		m.position = p(5.0 + k * 4.2, 10.0, 0.1)
		m.rotation.y = LACET
		parent.add_child(m)


## La halle de bois du fond, sous son toit d'ardoise, ouverte de trois côtés.
func _halle() -> void:
	var x0 := 46.0
	var z0 := 16.0
	var l := 18.0
	var pr := 10.0
	var h := 3.2
	for i in 4:
		for j in 2:
			var x := x0 + i * l / 3.0
			var z := z0 + j * pr
			o.boite(Transform3D(base.basis, q(x, h * 0.5, z)), Vector3(0.3, h, 0.3), BOIS)
	for j in 2:
		o.boite(Transform3D(base.basis, q(x0 + l * 0.5, h, z0 + j * pr)), Vector3(l + 0.4, 0.3, 0.3), BOIS)
	for i in 4:
		o.boite(Transform3D(base.basis, q(x0 + i * l / 3.0, h + 0.1, z0 + pr * 0.5)), Vector3(0.25, 0.25, pr + 0.4), BOIS_CLAIR)
	var ye := h + 0.1
	var yf := h + 3.2
	var d := 0.8
	o.pan(q(x0 - d, ye, z0 - d), q(x0 + l + d, ye, z0 - d), q(x0 + l + d, yf, z0 + pr * 0.5), q(x0 - d, yf, z0 + pr * 0.5), ARDOISE_HALLE, OUTILS.ARDOISE)
	o.pan(q(x0 + l + d, ye, z0 + pr + d), q(x0 - d, ye, z0 + pr + d), q(x0 - d, yf, z0 + pr * 0.5), q(x0 + l + d, yf, z0 + pr * 0.5), ARDOISE_HALLE, OUTILS.ARDOISE)
	for s: float in [0.0, 1.0]:
		var x := x0 + s * l + (d if s > 0.5 else -d)
		o.tri(q(x, ye, z0 - d), q(x, ye, z0 + pr + d), q(x, yf, z0 + pr * 0.5), base.basis * Vector3(1 if s > 0.5 else -1, 0, 0), BOIS_CLAIR, OUTILS.PEINT)
	# Les tables de la halle, de longues planches sur tréteaux.
	for i in 3:
		for j in 2:
			var c := Vector3(x0 + 3.0 + i * 6.0, 0, z0 + 2.8 + j * 4.4)
			o.boite(Transform3D(base.basis, q(c.x, 0.76, c.z)), Vector3(3.6, 0.08, 0.9), BOIS_CLAIR)
			for s: float in [-1.0, 1.0]:
				o.boite(Transform3D(base.basis, q(c.x, 0.4, c.z + s * 0.75)), Vector3(3.4, 0.06, 0.3), BOIS)
				o.boite(Transform3D(base.basis, q(c.x + s * 1.5, 0.38, c.z)), Vector3(0.08, 0.76, 0.7), BOIS)
	# L'aire de jeux : la cabane sur pilotis, son toboggan jaune.
	var aj := Vector3(56.0, 0, 36.0)
	for i in 2:
		for j in 2:
			o.boite(Transform3D(base.basis, q(aj.x + i * 2.0, 1.2, aj.z + j * 2.0)), Vector3(0.14, 2.4, 0.14), BOIS_CLAIR)
	o.boite(Transform3D(base.basis, q(aj.x + 1.0, 1.3, aj.z + 1.0)), Vector3(2.2, 0.1, 2.2), BOIS)
	o.pan(q(aj.x - 0.2, 2.6, aj.z - 0.2), q(aj.x + 2.2, 2.6, aj.z - 0.2), q(aj.x + 2.2, 3.3, aj.z + 1.0), q(aj.x - 0.2, 3.3, aj.z + 1.0), BOIS_CLAIR, OUTILS.PEINT)
	o.pan(q(aj.x + 2.2, 2.6, aj.z + 2.2), q(aj.x - 0.2, 2.6, aj.z + 2.2), q(aj.x - 0.2, 3.3, aj.z + 1.0), q(aj.x + 2.2, 3.3, aj.z + 1.0), BOIS_CLAIR, OUTILS.PEINT)
	o.quad(q(aj.x + 2.1, 1.35, aj.z + 0.4), q(aj.x + 2.1, 1.35, aj.z + 1.6), q(aj.x + 4.4, 0.25, aj.z + 1.6), q(aj.x + 4.4, 0.25, aj.z + 0.4), base.basis * Vector3(0.4, 1, 0).normalized(), Color("e8c33a", 0.4), OUTILS.PEINT)


## Le long de la route, le mur bahut de pierre et sa barrière de bois ; la clôture du pré.
func _clotures() -> void:
	var x := -2.0
	while x < 44.0:
		if x < 4.0 or x > 9.0:
			o.boite(Transform3D(base.basis, p(x + 1.0, -1.0, 0.75)), Vector3(2.02, 1.1, 0.45), MOELLON)
			o.boite(Transform3D(base.basis, p(x + 1.0, -1.0, 1.45)), Vector3(2.02, 0.08, 0.06), BOIS)
			o.boite(Transform3D(base.basis, p(x + 1.0, -1.0, 1.75)), Vector3(2.02, 0.08, 0.06), BOIS)
			o.boite(Transform3D(base.basis, p(x, -1.0, 1.25)), Vector3(0.1, 1.1, 0.1), BOIS)
		x += 2.0
	# Les piliers de l'entrée.
	for xp: float in [4.0, 9.0]:
		o.boite(Transform3D(base.basis, p(xp, -1.0, 1.0)), Vector3(0.7, 2.0, 0.7), ANGLE)
	var z := 17.5
	while z < 46.0:
		o.boite(Transform3D(base.basis, p(68.0, z, 0.55)), Vector3(0.12, 1.1, 0.12), BOIS)
		o.boite(Transform3D(base.basis, p(68.0, z + 1.0, 0.8)), Vector3(0.06, 0.1, 2.0), BOIS_CLAIR)
		z += 2.0


## Le grand chêne de la terrasse, les cyprès, le rideau de peupliers d'Italie et les
## peupliers noirs (arbres-des-rives@1), les chênes et les charmes du bocage (vegetation-du-bugey@1), les haies
## fleuries.
func _vegetation(parent: Node3D) -> void:
	var rives: PackedScene = load(Bibliotheque.scene("arbres-des-rives@1", "decor"))
	var bugey: PackedScene = load(Bibliotheque.scene("vegetation-du-bugey@1", "decor"))
	_poser(parent, bugey, "plante", "chene", 207, {"hauteur": 15.0}, Vector2(41.5, 20.5))
	# Le rideau de peupliers d'Italie entre le pré et les lônes.
	for k in 11:
		_poser(parent, rives, "arbre", "peuplier", 30 + k, {"hauteur": 22.0 + (k % 3) * 2.5}, Vector2(-8.0 + k * 7.5, 54.0 + (k % 2) * 1.5))
	# Le bocage autour : des bouquets de peupliers noirs, de chênes et de charmes, semés hors de la propriété.
	var semis := 0
	var essais := 0
	while semis < 90 and essais < 1500:
		essais += 1
		var h := absi(hash(Vector2i(essais, 77)))
		var x := -80.0 + float(h % 2300) / 10.0
		var z := -45.0 + float((h / 2300) % 1700) / 10.0
		# Ni sur la propriété, ni sur la route, ni dans l'axe de la vue de la planche.
		if x > -14.0 and x < 74.0 and z > -10.0 and z < 50.0:
			continue
		if z > -12.0 and z < 0.0:
			continue
		if z < -10.0 and x > 10.0 and x < 60.0:
			continue
		var choix := h % 5
		var pos := Vector2(x, z)
		if choix < 2:
			_poser(parent, rives, "arbre", "peuplier_noir", h % 97, {"hauteur": 15.0 + float(h % 7)}, pos)
		elif choix < 4:
			_poser(parent, bugey, "plante", "chene" if choix == 2 else "charme", h % 89, {"hauteur": 11.0 + float(h % 6)}, pos)
		else:
			_poser(parent, rives, "arbre", "peuplier", h % 61, {"hauteur": 20.0 + float(h % 6)}, pos)
		semis += 1
	var v := OUTILS.new(8)
	var cypres := [Vector2(-3, 4), Vector2(-3, 12), Vector2(22, 1.8), Vector2(34, 1.8), Vector2(40, 9), Vector2(66, 14), Vector2(62, 46), Vector2(50, 47)]
	for c in cypres:
		var pc := p(c.x, c.y, -0.1)
		var hh := 8.5 + absi(hash(c)) % 3
		v.branche(pc, pc + Vector3(0, 1.0, 0), 0.12, 0.1, Color("5a4632", 0.9))
		for k in 5:
			var f := k / 5.0
			v.boule(pc + Vector3(0, 1.0 + f * hh * 0.82, 0), Vector3(1.05 - f * 0.7, hh * 0.2, 1.05 - f * 0.7), Color("3f6e2e").lightened(f * 0.12), 0.22, OUTILS.FEUILLE, 0.06, 0.6, 5, 8)
	# L'îlot planté qui sépare les places de la cour, les pots de fleurs devant la terrasse, les arbustes fleuris
	# contre la façade, la haie le long du pré (vegetation-du-bugey@1), comme sur la planche.
	_poser(parent, bugey, "plante", "haie", 301, {"longueur": 9.0}, Vector2(23.0, 6.5), 0.0)
	_poser(parent, bugey, "plante", "arbuste_fleuri", 302, {"fleurs": "e37fa0"}, Vector2(18.0, 6.5), 0.0)
	_poser(parent, bugey, "plante", "arbuste_fleuri", 303, {"fleurs": "f4f0e6"}, Vector2(28.5, 6.5), 0.0)
	for k in 7:
		_poser(parent, bugey, "plante", "fleurs", 310 + k, {}, Vector2(4.5 + k * 3.1, 16.8), 0.0)
	for k in 5:
		_poser(parent, bugey, "plante", "arbuste_fleuri", 320 + k, {"fleurs": ["e37fa0", "d04a8a", "f4f0e6"][k % 3]}, Vector2(3.0 + k * 5.6, 17.6), 0.0)
	_poser(parent, bugey, "plante", "haie", 330, {"longueur": 20.0}, Vector2(57.0, 11.0), 0.0)
	_poser(parent, bugey, "plante", "haie", 331, {"longueur": 26.0}, Vector2(69.0, 31.0), PI * 0.5)
	# Les haies fleuries au pied des murs (lauriers, rosiers).
	for k in 9:
		var x := -1.0 + k * 5.0
		if x > 3.0 and x < 10.0:
			continue
		v.boule(p(x, 2.0, 0.5), Vector3(1.5, 0.9, 0.9), Color("5f9436"), 0.25, OUTILS.FEUILLE, 0.08, 0.6, 5, 8)
		if k % 2 == 0:
			v.boule(p(x + 0.6, 2.2, 1.1), Vector3(0.5, 0.3, 0.4), Color("e37fa0"), 0.3, OUTILS.FEUILLE, 0.05, 0.3, 4, 6)
	v.construire(parent, "Vegetation")


func _voitures(parent: Node3D) -> void:
	var scene: PackedScene = load(Bibliotheque.scene("voitures-des-annees-80@1", "decor"))
	var places := [[Vector2(9.5, 4.5), "compacte", "6b7078"], [Vector2(15.5, 4.5), "break", "e9e7e0"], [Vector2(27.5, 11.5), "compacte", "8d9196"]]
	for i in places.size():
		var vo: Node3D = scene.instantiate()
		vo.set("voiture", places[i][1])
		vo.set("graine", 40 + i)
		vo.set("options", {"couleur": places[i][2]})
		var v: Vector2 = places[i][0]
		vo.position = p(v.x, v.y, 0.1)
		vo.rotation.y = LACET + PI
		parent.add_child(vo)


## Une brique de la bibliothèque posée au sol du repère local.
func _poser(parent: Node3D, scene: PackedScene, champ: String, nom: String, graine: int, options: Dictionary, v: Vector2, lacet := -1.0) -> void:
	var m: Node3D = scene.instantiate()
	m.set(champ, nom)
	m.set("graine", graine)
	m.set("options", options)
	m.position = p(v.x, v.y, -0.05)
	# Un lacet donné est dans le repère du relais ; sinon l'arbre tourne au hasard.
	m.rotation.y = float(graine % 628) / 100.0 if lacet < 0.0 else LACET + lacet
	parent.add_child(m)
