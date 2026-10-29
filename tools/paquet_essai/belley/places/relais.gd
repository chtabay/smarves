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
const FACADIER := preload("res://bibliotheque/facadier-du-bugey/1/facadier.gd")
const REPEINDRE := preload("res://communes/belley/atelier/repeindre.gd")

const ORIGINE := Vector2(7173.0, 639.2)
## Le lacet du repère : +Z regarde le nord-est, vers les lônes.
const LACET := deg_to_rad(138.1)

const MOELLON := Color("d9ccb2", 0.0)
const ANGLE := Color("e6d9bc", 1.0)
const VOLET := Color("7e9a96", 0.6)
const BOIS := Color("8a6440", 0.8)
const BOIS_CLAIR := Color("b08a5a", 0.8)
const GRAVIER := Color("cdb89a", 0.95)
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
	_maisons(n)
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
			var k2 := float(absi(hash(Vector2i(int(x / 6.0), int(z / 6.0)) * 3)) % 100) / 100.0
			var c := col.darkened(k * 0.08 + k2 * 0.06) if k < 0.5 else col.lightened((k - 0.5) * 0.06).darkened(k2 * 0.06)
			o.quad(p(x, z, 0.1), p(x + pas, z, 0.1), p(x + pas, z + pas, 0.1), p(x, z + pas, 0.1), Vector3.UP, c, OUTILS.PEINT)
			z += pas
		x += pas


func _trait(a: Vector2, b: Vector2) -> void:
	var d := (b - a).normalized()
	var nn := Vector2(-d.y, d.x) * 0.06
	o.quad(p(a.x + nn.x, a.y + nn.y, 0.12), p(b.x + nn.x, b.y + nn.y, 0.12), p(b.x - nn.x, b.y - nn.y, 0.12), p(a.x - nn.x, a.y - nn.y, 0.12), Vector3.UP, Color("f2efe6", 0.9), OUTILS.PEINT)


## Un corps de bâtiment, de a à b (coins opposés au sol, dans le repère), de h à l'égout, sous un toit à deux
## pans d'axe x et ses croupes de rive ; ses fenêtres à volets, ses portes, ses cheminées.
## L'auberge, par le façadier du Bugey (facadier-du-bugey@1), comme la planche : plusieurs corps de moellons
## décalés en plan et au faîtage, une ferme, un logis à balcon de bois, un pavillon plus haut, une remise ; la
## vigne sur un tiers des façades. Chaque corps : [x du milieu, z de la façade, type, options] ; la façade
## regarde la route (−Z du relais).
func _maisons(parent: Node3D) -> void:
	var corps := [
		[-2.5, 21.0, "r0", {"w": 7.0, "d": 7.0, "mur": "moellons", "pierre": "a89070", "couverture": "tuile_vieillie", "vigne": false}],
		[7.5, 18.0, "ferme", {"w": 13.0, "d": 9.5, "niveaux": 1, "mur": "moellons", "pierre": "b9a27a", "couverture": "tuile_vieillie", "vigne": true, "volet": "7e9a96", "volets": "bois"}],
		[20.5, 19.2, "vigneronne", {"w": 13.0, "d": 9.0, "mur": "moellons", "pierre": "a89070", "couverture": "tuile_vieillie", "balcon": true, "vigne": false, "volet": "7e9a96"}],
		[33.0, 12.5, "r2", {"w": 10.0, "d": 12.0, "niveaux": 2, "mur": "moellons", "pierre": "b9a27a", "couverture": "tuile_vieillie", "vigne": true, "volet": "7e9a96", "lucarnes": 1}],
	]
	var face := base.basis * Vector3(0, 0, -1)
	for i in corps.size():
		var c: Array = corps[i]
		var p0 := base * Vector3(c[0], 0, c[1])
		var y: float = hauteur.call(p0.x, p0.z)
		var m: Node3D = FACADIER.maison(parent, Vector3(p0.x, y, p0.z), c[2], 71 + i * 7, c[3])
		m.rotation.y = atan2(face.x, face.z)


func _terrasse(parent: Node3D) -> void:
	# La treille devant la façade : les tonnelles de vigne du mobilier du Bugey, bout à bout.
	var bugey_mob: PackedScene = load(Bibliotheque.scene("mobilier-du-bugey@1", "decor"))
	for k in 5:
		var t: Node3D = bugey_mob.instantiate()
		t.set("objet", "tonnelle")
		t.set("graine", 60 + k)
		t.position = p(7.5 + k * 3.4, 15.6, 0.05)
		t.rotation.y = LACET
		parent.add_child(t)
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
	_poser(parent, load(Bibliotheque.scene("arbres-d-ombriere@1", "decor")), "arbre", "platane", 207, {"hauteur": 18.0}, Vector2(41.5, 20.5))
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
			v.boule(pc + Vector3(0, 1.0 + f * hh * 0.82, 0), Vector3(1.05 - f * 0.7, hh * 0.2, 1.05 - f * 0.7), Color("2f5a2a").lightened(f * 0.08), 0.12, OUTILS.FEUILLE, 0.03, 0.6, 5, 8)
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
	REPEINDRE.feuillage(m)
