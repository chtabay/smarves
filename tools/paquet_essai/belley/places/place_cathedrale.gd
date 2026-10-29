extends RefCounted
## La place de la Cathédrale, telle que sur la planche et sur le plan réel (le parking OSM « Place de la
## Cathédrale », ses deux rangs de tilleuls) : l'allée au milieu, les places en épi de part et d'autre, peintes
## en blanc ; les passages piétons sur la rue Saint-Jean et devant le parvis ; les bornes qui gardent le
## trottoir, les lanternes doubles, les jardinières fleuries au pied des marches ; les voitures garées
## (voitures-des-annees-80@1).

const OUTILS := preload("res://communes/belley/atelier/outils.gd")
const REPEINDRE := preload("res://communes/belley/atelier/repeindre.gd")
const MODELES := ["citadine", "compacte", "berline", "compacte", "break", "citadine", "fourgonnette"]

## L'allée du parking, d'un bout à l'autre (relevée sur le plan).
const ALLEE_A := Vector2(163.6, 318.0)
const ALLEE_B := Vector2(193.4, 334.7)
const BLANC := Color("eeeee6", 0.9)
const BORNE := Color("3a3d40", 0.6)
const BORDURE := Color("bdb5a6", 0.95)
const TROTTOIR := Color("b9ad98", 0.95)
## Les arbres du stationnement, alignés de part et d'autre, au bout des places (planche : sept ou huit par rang).
const ARBRES_PAR_RANG := 7

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
	_bordures()
	o.construire(n, "Sol")
	_mobilier(n)
	_arbres(n)


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
			if k > 0:
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
	# Le long du trottoir de la rue piétonne, entre les bornes, une jardinière tous les 6 m, comme sur la planche.
	for k in 6:
		poses.append(["jardiniere", Vector2(157.5, 333.4).lerp(Vector2(189.0, 351.4), (k + 0.5) / 6.0) + Vector2(0.5, -0.9), -2.1])
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
	# Les massifs fleuris aux pieds des marches du parvis et aux angles de la place (vegetation-du-bugey@1).
	var bugey: PackedScene = load(Bibliotheque.scene("vegetation-du-bugey@1", "decor"))
	var massifs := [Vector2(186.0, 343.0), Vector2(194.5, 337.5), Vector2(203.0, 333.0), Vector2(161.0, 322.0), Vector2(170.0, 340.0)]
	for k in massifs.size():
		var m: Node3D = bugey.instantiate()
		m.set("plante", "arbuste_fleuri")
		m.set("graine", 500 + k)
		m.set("options", {"fleurs": ["d04a8a", "e0605a", "f4f0e6", "f2c14e", "b06ad0"][k]})
		var v: Vector2 = massifs[k]
		m.position = _p(v, 0.1)
		parent.add_child(m)


## Les bordures de granit et les trottoirs qui ceinturent le stationnement : le chant relevé de 0,16 m, le
## dessus de la bordure, puis le trottoir de 2 m au-delà, où se tiennent les arbres.
func _bordures() -> void:
	var d := (ALLEE_B - ALLEE_A).normalized()
	var nrm := Vector2(-d.y, d.x)
	var longueur := ALLEE_A.distance_to(ALLEE_B)
	var bord := 3.0 + 5.0 + 0.2
	for cote: float in [-1.0, 1.0]:
		var a := ALLEE_A + nrm * cote * bord - d * 0.5
		var b := ALLEE_B + nrm * cote * bord + d * 0.5
		var e := nrm * cote
		var nb := int(ceil((longueur + 1.0) / 2.0))
		for k in nb:
			var p0 := a.lerp(b, float(k) / nb)
			var p1 := a.lerp(b, float(k + 1) / nb)
			var y0: float = hauteur.call(p0.x, p0.y)
			var y1: float = hauteur.call(p1.x, p1.y)
			o.quad(Vector3(p0.x, y0, p0.y), Vector3(p1.x, y1, p1.y), Vector3(p1.x, y1 + 0.16, p1.y), Vector3(p0.x, y0 + 0.16, p0.y), Vector3(-e.x, 0, -e.y), BORDURE, OUTILS.PEINT)
			var q0 := p0 + e * 0.25
			var q1 := p1 + e * 0.25
			o.quad(Vector3(p0.x, y0 + 0.16, p0.y), Vector3(p1.x, y1 + 0.16, p1.y), Vector3(q1.x, y1 + 0.16, q1.y), Vector3(q0.x, y0 + 0.16, q0.y), Vector3.UP, BORDURE.lightened(0.05), OUTILS.PEINT)
			var r0 := p0 + e * 2.4
			var r1 := p1 + e * 2.4
			var t := TROTTOIR.darkened(float(absi(hash(Vector2i(k, int(cote)))) % 6) * 0.01)
			o.quad(Vector3(q0.x, y0 + 0.155, q0.y), Vector3(q1.x, y1 + 0.155, q1.y), Vector3(r1.x, y1 + 0.155, r1.y), Vector3(r0.x, y0 + 0.155, r0.y), Vector3.UP, t, OUTILS.PEINT)


## Le rang d'arbres du stationnement, sur le trottoir côté place, au bout des places (arbres-d-ombriere@1,
## repeints du vert posé de la planche).
func _arbres(parent: Node3D) -> void:
	var scene: PackedScene = load(Bibliotheque.scene("arbres-d-ombriere@1", "decor"))
	var d := (ALLEE_B - ALLEE_A).normalized()
	var nrm := Vector2(-d.y, d.x)
	var longueur := ALLEE_A.distance_to(ALLEE_B)
	# Un seul rang, côté place : deux rangs serrés faisaient une chenille (verdict n° 6).
	for cote: float in [1.0]:
		for k in ARBRES_PAR_RANG:
			var v := ALLEE_A + d * (1.5 + k * (longueur - 3.0) / (ARBRES_PAR_RANG - 1)) + nrm * cote * 9.4
			var g := 700 + k + (10 if cote > 0.0 else 0)
			var t: Node3D = scene.instantiate()
			t.set("arbre", "micocoulier")
			t.set("graine", g)
			t.set("options", {"hauteur": 8.0 + float(k % 3) * 0.5})
			t.position = Vector3(v.x, hauteur.call(v.x, v.y) + 0.1, v.y)
			t.rotation.y = float(g) * 0.37
			parent.add_child(t)
			REPEINDRE.feuillage(t)


## Le stationnement a ses propres arbres : la ville n'y plante pas ceux du relevé.
static func sur_le_stationnement(v: Vector2) -> bool:
	var d := (ALLEE_B - ALLEE_A).normalized()
	var w := v - ALLEE_A
	var t := w.dot(d)
	return t > -4.0 and t < ALLEE_A.distance_to(ALLEE_B) + 4.0 and absf(w.dot(Vector2(-d.y, d.x))) < 13.0
