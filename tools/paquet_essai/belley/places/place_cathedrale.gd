extends RefCounted
## La place de la Cathédrale, telle que sur la planche et sur le plan réel (le parking OSM « Place de la
## Cathédrale », ses deux rangs de tilleuls) : l'allée au milieu, les places en épi de part et d'autre, peintes
## en blanc ; les passages piétons sur la rue Saint-Jean et devant le parvis ; les bornes qui gardent le
## trottoir, les lanternes doubles, les jardinières fleuries au pied des marches ; les voitures garées
## (voitures-des-annees-80@1).

const OUTILS := preload("res://communes/belley/atelier/outils.gd")
const MODELES := ["citadine", "compacte", "berline", "compacte", "break", "citadine", "fourgonnette"]

## L'allée du parking, d'un bout à l'autre (relevée sur le plan).
const ALLEE_A := Vector2(163.6, 318.0)
const ALLEE_B := Vector2(193.4, 334.7)
const BLANC := Color("eeeee6", 0.9)
const BORNE := Color("3a3d40", 0.6)

var hauteur: Callable
var o: RefCounted


func _init(sol: Callable) -> void:
	hauteur = sol


func batir(parent: Node3D) -> void:
	o = OUTILS.new(1034)
	var n := Node3D.new()
	n.name = "PlaceCathedrale"
	parent.add_child(n)
	_stationnement(n)
	_passage(Vector2(166.2, 313.0), Vector2(-0.46, 0.89), 4.5)
	_passage(Vector2(158.6, 327.4), Vector2(-0.46, 0.89), 4.5)
	_passage(Vector2(191.0, 339.8), Vector2(-0.42, 0.91), 3.5)
	_passage(Vector2(176.0, 341.6), Vector2(0.87, 0.5), 4.0)
	# Les bornes : le long du trottoir de la rue piétonne et du parvis.
	_bornes(Vector2(157.5, 333.4), Vector2(189.0, 351.4), 2.4)
	_bornes(Vector2(195.0, 324.0), Vector2(205.0, 330.0), 2.4)
	o.construire(n, "Sol")
	_mobilier(n)


## Un point du sol, relevé de dy.
func _p(v: Vector2, dy: float) -> Vector3:
	return Vector3(v.x, hauteur.call(v.x, v.y) + dy, v.y)


## Un trait peint de a à b, de largeur l.
func trace(a: Vector2, b: Vector2, l: float, col := BLANC) -> void:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x) * l * 0.5
	o.quad(_p(a + n, 0.15), _p(b + n, 0.15), _p(b - n, 0.15), _p(a - n, 0.15), Vector3.UP, col, OUTILS.PEINT)


func _stationnement(parent: Node3D) -> void:
	var d := (ALLEE_B - ALLEE_A).normalized()
	var nrm := Vector2(-d.y, d.x)
	var longueur := ALLEE_A.distance_to(ALLEE_B)
	var demi_allee := 3.0
	var prof := 5.0
	var pas := 2.6
	# Les places en épi, à 60°, de chaque côté de l'allée.
	var epi := d * cos(deg_to_rad(60.0)) + nrm * sin(deg_to_rad(60.0))
	var graine := 0
	var voitures: PackedScene = load(Bibliotheque.scene("voitures-des-annees-80@1", "decor"))
	for cote: float in [-1.0, 1.0]:
		var axe := epi if cote > 0.0 else d * cos(deg_to_rad(60.0)) - nrm * sin(deg_to_rad(60.0))
		var k := 0
		var t := 2.5
		while t < longueur - 3.0:
			var pied := ALLEE_A + d * t + nrm * cote * demi_allee
			trace(pied, pied + axe * (prof / sin(deg_to_rad(60.0))), 0.12)
			# Une voiture dans la plupart des places, comme un samedi après-midi.
			if k > 0 and absi(hash(Vector2(t, cote))) % 10 < 8:
				var milieu := pied - d * pas * 0.5 + axe * prof * 0.55
				var lacet := atan2(axe.x, axe.y) + (PI if cote < 0.0 else 0.0)
				var noeud: Node3D = voitures.instantiate()
				noeud.set("voiture", MODELES[graine % MODELES.size()])
				noeud.set("graine", graine)
				graine += 1
				noeud.position = _p(milieu, 0.15)
				noeud.rotation.y = lacet
				parent.add_child(noeud)
			t += pas
			k += 1
		# La ligne qui borde l'allée.
		trace(ALLEE_A + nrm * cote * demi_allee + d * 2.5, ALLEE_A + nrm * cote * demi_allee + d * (t - pas), 0.1)


## Un passage piéton : des bandes de 0,5 m parallèles à la rue (sa direction dir), sur sa largeur.
func _passage(centre: Vector2, dir: Vector2, largeur: float) -> void:
	var d := dir.normalized()
	var n := Vector2(-d.y, d.x)
	var bandes := int(largeur / 1.0)
	for k in bandes:
		var c := centre + n * ((k - (bandes - 1) * 0.5) * 1.0)
		trace(c - d * 1.4, c + d * 1.4, 0.5)


func _bornes(a: Vector2, b: Vector2, pas: float) -> void:
	var n := int(a.distance_to(b) / pas)
	for k in n + 1:
		var p := a.lerp(b, float(k) / n)
		var y: float = hauteur.call(p.x, p.y) + 0.1
		o.cylindre(Transform3D(Basis(), Vector3(p.x, y, p.y)), 0.1, 0.09, 0.85, 8, BORNE, OUTILS.PEINT)
		o.boule(Vector3(p.x, y + 0.88, p.y), Vector3(0.1, 0.07, 0.1), BORNE, 0.0, OUTILS.PEINT, 0.0)


## Les lanternes doubles et les jardinières du mobilier du Bugey (bibliothèque, mobilier-du-bugey@1).
func _mobilier(parent: Node3D) -> void:
	var scene: PackedScene = load(Bibliotheque.scene("mobilier-du-bugey@1", "decor"))
	var poses := [
		["lampadaire", Vector2(160.0, 314.5), 0.0], ["lampadaire", Vector2(155.0, 330.0), 0.0],
		["lampadaire", Vector2(172.0, 342.5), 0.0], ["lampadaire", Vector2(188.0, 352.0), 0.0],
		["lampadaire", Vector2(198.0, 322.0), 0.0], ["lampadaire", Vector2(206.0, 330.5), 0.0],
		["jardiniere", Vector2(192.0, 345.5), -2.1], ["jardiniere", Vector2(200.5, 329.5), -2.1],
		["jardiniere", Vector2(180.0, 345.0), -2.1], ["jardiniere", Vector2(196.5, 349.0), -2.1],
	]
	var g := 0
	for p in poses:
		var m: Node3D = scene.instantiate()
		m.set("objet", p[0])
		m.set("graine", g)
		g += 1
		var v: Vector2 = p[1]
		m.position = _p(v, 0.12)
		m.rotation.y = p[2]
		parent.add_child(m)
