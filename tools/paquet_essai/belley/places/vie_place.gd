extends RefCounted
## La vie de la place de la Cathédrale (verdict n° 16 du juge : personne sur le parvis) : des passants du socle
## (Atelier.personnage, « client ») qui causent par petits groupes sur le parvis et au pied des marches, d'autres
## qui suivent le trottoir ; et l'annonce du Grand Prix de la Louve, la course du dimanche (course-cycliste@1) :
## la banderole tendue au-dessus de la rue des Barons, les barrières de foule rouge et blanc déjà rangées le long
## du parvis.
##   VIE.new(hauteur).batir(parent)

const PLACE := preload("res://communes/belley/places/place_cathedrale.gd")
const OUTILS := preload("res://communes/belley/atelier/outils.gd")
const BORDURE := Color("b3ab9c")
## Le trottoir et la chaussée au soleil rendaient la vue à pied trop claire (verdict n° 23 : médiane 161) : des
## albédos plus sourds, qui rendent #B5AA92 et #8E8780 à la lumière de Belley.
const TROTTOIR := Color("a89c84")
## L'axe de la rue des Barons dans son tronçon d'arrivée, et sa demi-largeur de chaussée (bourg.json).
const BARONS := [Vector2(117.0, 295.0), Vector2(128.0, 299.0), Vector2(159.0, 313.0), Vector2(165.0, 315.0)]
const DEMI_CHAUSSEE := 2.5
## Le mur du jardin de gauche, entre la première maison et la suivante, en retrait (abscisses le long de la rue
## depuis BARONS[1]), et son portail.
const MUR_DE := 7.6
const MUR_A := 30.0
const PORTAIL := 14.0
const MOELLON := Color("a89574")
const CHAPERON := Color("c9bba0")
const PORTE := Color("4f6b52")

var hauteur: Callable


func _init(sol: Callable) -> void:
	hauteur = sol


func _p(v: Vector2, dy := 0.0) -> Vector3:
	return Vector3(v.x, hauteur.call(v.x, v.y) + dy, v.y)


func batir(parent: Node3D) -> void:
	var n := Node3D.new()
	n.name = "ViePlace"
	parent.add_child(n)
	var d := (PLACE.ALLEE_B - PLACE.ALLEE_A).normalized()
	var nrm := Vector2(-d.y, d.x)
	var longueur := PLACE.ALLEE_A.distance_to(PLACE.ALLEE_B)
	_course(n, d, nrm, longueur)
	_trottoirs(n)
	_rue_des_barons(n)
	_mur_de_jardin(n)
	_marche(n, d, nrm, longueur)
	# Le côté ouvert de la rue des Barons, en descendant vers la place : un trottoir, sa bordure et une haie basse
	# devant les jardins, au lieu d'un talus de pelouse (verdict n° 19).
	var bugey: PackedScene = load(Bibliotheque.scene("vegetation-du-bugey@1", "decor"))
	var r0 := Vector2(128.0, 299.0)
	var r1 := Vector2(159.0, 313.0)
	var dr := (r1 - r0).normalized()
	var flanc := Vector2(-dr.y, dr.x)
	for k in int(r0.distance_to(r1) / 3.0):
		var v := r0 + dr * (1.5 + k * 3.0) + flanc * 5.2
		var h: Node3D = bugey.instantiate()
		h.set("plante", "haie")
		h.set("graine", 60 + k)
		h.set("options", {"longueur": 3.1, "hauteur": 0.9 + 0.1 * (k % 3)})
		h.position = _p(v)
		h.rotation.y = -atan2(dr.y, dr.x)
		n.add_child(h)
	# Les groupes qui causent : sur le parvis dallé, au pied des marches, près des lanternes.
	var groupes := [
		[PLACE.ALLEE_A + d * 6.0 - nrm * 7.0, 3],
		[PLACE.ALLEE_A + d * 17.0 - nrm * 6.0, 2],
		[PLACE.ALLEE_A + d * 27.0 - nrm * 8.0, 3],
		[Vector2(186.0, 346.0), 2],
		[Vector2(196.0, 340.0), 3],
	]
	var g := 0
	for gr in groupes:
		var c: Vector2 = gr[0]
		var nb: int = gr[1]
		for k in nb:
			var a := TAU * k / nb + float(g) * 0.7
			var v := c + Vector2(cos(a), sin(a)) * 0.75
			var f := Atelier.personnage("client", 300 + g)
			if f == null:
				continue
			n.add_child(f)
			f.position = _p(v, 0.17)
			f.regarder(_p(c))
			f.jouer(["talk", "idle", "arms", "talk", "phone"][g % 5])
			g += 1
	# Les passants du trottoir, côté maisons, et de l'allée du parvis : des allers et retours lents.
	var circuits := [
		[PLACE.ALLEE_A + nrm * 9.4 + d * 2.0, PLACE.ALLEE_B + nrm * 9.4 - d * 2.0],
		[PLACE.ALLEE_B - nrm * 4.0 - d * 1.0, PLACE.ALLEE_A - nrm * 4.0 + d * 1.0],
		[PLACE.ALLEE_A - nrm * 9.0 + d * 4.0, PLACE.ALLEE_B - nrm * 9.0 - d * 6.0],
	]
	for k in 6:
		var cir: Array = circuits[k % circuits.size()]
		var pts := [_p(cir[0], 0.17), _p(cir[1], 0.17)]
		var f := Atelier.personnage("client", 340 + k)
		if f == null:
			continue
		n.add_child(f)
		f.suivre(pts, k % 2, 1.0 + 0.1 * (k % 3), 2.5, "idle")
		f.position = pts[0].lerp(pts[1], 0.15 + 0.3 * k / 6.0)


## L'annonce de la course : la banderole au-dessus de la rue, à l'entrée de la place, et les barrières de foule
## le long du parvis, prêtes pour dimanche.
func _course(n: Node3D, d: Vector2, nrm: Vector2, longueur: float) -> void:
	var scene: PackedScene = load(Bibliotheque.scene("course-cycliste@1", "decor"))
	var lacet := atan2(d.x, d.y)
	# La banderole traverse la rue des Barons à son tronçon serré, d'une façade à l'autre : on passe dessous en
	# arrivant (verdicts n° 18 et 19).
	var banderole: Node3D = scene.instantiate()
	banderole.set("objet", "banderole")
	banderole.set("graine", 11)
	# taille_texte : la PR #309 de la bibliothèque ; ignorée tant qu'elle n'est pas fusionnée.
	banderole.set("options", {"texte": "GRAND PRIX DE LA LOUVE", "largeur": 9.5, "couleur": "d22a2a", "taille_texte": "ajuste"})
	banderole.position = _p(Vector2(133.0, 301.2))
	banderole.rotation.y = atan2(-0.91, -0.41)
	n.add_child(banderole)
	for k in 3:
		var b: Node3D = scene.instantiate()
		b.set("objet", "barrieres")
		b.set("graine", 20 + k)
		b.set("options", {"largeur": 8.0, "couleur": "d22a2a", "texte": "LA LOUVE"})
		b.position = _p(PLACE.ALLEE_A + d * (6.0 + k * (longueur - 12.0) / 2.0) - nrm * 10.6, 0.17)
		b.rotation.y = lacet + PI * 0.5
		n.add_child(b)


## Les trottoirs relevés des deux côtés de la rue des Barons, à l'arrivée sur la place (verdict n° 20) : le chant
## de la bordure de granit, son dessus, puis 2,2 m de trottoir, recoupés tous les 2 m pour suivre la pente.
func _trottoirs(n: Node3D) -> void:
	var o := OUTILS.new(1035)
	for i in BARONS.size() - 1:
		var a: Vector2 = BARONS[i]
		var c: Vector2 = BARONS[i + 1]
		var dr := (c - a).normalized()
		var nb := maxi(1, ceili(a.distance_to(c) / 2.0))
		for cote: float in [-1.0, 1.0]:
			var e := Vector2(-dr.y, dr.x) * cote
			for k in nb:
				var p0 := a.lerp(c, float(k) / nb) + e * DEMI_CHAUSSEE
				var p1 := a.lerp(c, float(k + 1) / nb) + e * DEMI_CHAUSSEE
				var y0: float = hauteur.call(p0.x, p0.y) + 0.13
				var y1: float = hauteur.call(p1.x, p1.y) + 0.13
				o.quad(Vector3(p0.x, y0, p0.y), Vector3(p1.x, y1, p1.y), Vector3(p1.x, y1 + 0.15, p1.y), Vector3(p0.x, y0 + 0.15, p0.y), Vector3(-e.x, 0, -e.y), BORDURE.darkened(0.08), OUTILS.PEINT)
				var q0 := p0 + e * 0.25
				var q1 := p1 + e * 0.25
				o.quad(Vector3(p0.x, y0 + 0.15, p0.y), Vector3(p1.x, y1 + 0.15, p1.y), Vector3(q1.x, y1 + 0.15, q1.y), Vector3(q0.x, y0 + 0.15, q0.y), Vector3.UP, BORDURE, OUTILS.PEINT)
				var r0 := p0 + e * 2.45
				var r1 := p1 + e * 2.45
				var t := TROTTOIR.darkened(float(absi(hash(Vector2i(k + i * 40, int(cote)))) % 5) * 0.012)
				o.quad(Vector3(q0.x, y0 + 0.145, q0.y), Vector3(q1.x, y1 + 0.145, q1.y), Vector3(r1.x, y1 + 0.145, r1.y), Vector3(r0.x, y0 + 0.145, r0.y), Vector3.UP, t, OUTILS.PEINT)
	o.construire(n, "TrottoirsBarons")


## La rue des Barons n'est plus vide (verdict n° 23) : c'est le parcours de dimanche. Les barrières de foule
## attendent déjà le long de la haie, un vélo est appuyé contre une façade, des passants montent et descendent les
## trottoirs, deux voisins causent sur le pas d'une porte.
func _rue_des_barons(n: Node3D) -> void:
	var scene: PackedScene = load(Bibliotheque.scene("course-cycliste@1", "decor"))
	var a: Vector2 = BARONS[1]
	var c: Vector2 = BARONS[2]
	var dr := (c - a).normalized()
	var flanc := Vector2(-dr.y, dr.x)
	var lacet := -atan2(dr.y, dr.x)
	for k in 3:
		var b: Node3D = scene.instantiate()
		b.set("objet", "barrieres")
		b.set("graine", 30 + k)
		b.set("options", {"largeur": 8.0, "couleur": "d22a2a", "texte": "LA LOUVE"})
		b.position = _p(a + dr * (6.0 + k * 8.6) + flanc * 4.4, 0.28)
		b.rotation.y = lacet
		n.add_child(b)
	var velo: Node3D = scene.instantiate()
	velo.set("objet", "velo")
	velo.set("graine", 41)
	velo.set("options", {"couleur": "2f5f8f"})
	velo.position = _p(a + dr * 9.0 - flanc * 4.6, 0.28)
	velo.rotation.y = lacet
	n.add_child(velo)
	# Les passants des trottoirs, en allers et retours lents.
	var circuits := [
		[a - flanc * 3.6 + dr * 1.0, c - flanc * 3.6],
		[c - flanc * 4.1, a - flanc * 4.1 + dr * 3.0],
		[a + flanc * 3.2 + dr * 2.0, c + flanc * 3.2],
	]
	for k in 5:
		var cir: Array = circuits[k % circuits.size()]
		var pts := [_p(cir[0], 0.28), _p(cir[1], 0.28)]
		var f := Atelier.personnage("client", 360 + k)
		if f == null:
			continue
		n.add_child(f)
		f.suivre(pts, k % 2, 0.9 + 0.1 * (k % 3), 3.0, "idle")
		f.position = pts[0].lerp(pts[1], 0.1 + 0.18 * k)
	var seuil := a + dr * PORTAIL - flanc * 4.2
	for k in 2:
		var f := Atelier.personnage("client", 370 + k)
		if f == null:
			continue
		n.add_child(f)
		f.position = _p(seuil + dr * (0.8 if k == 0 else -0.8), 0.28)
		f.regarder(_p(seuil))
		f.jouer(["talk", "arms"][k])


## Le jardin de gauche, dans le vide après la première maison (verdict n° 24) : un mur de moellons de 1,8 m au
## bord du trottoir, son chaperon, et un portail de bois peint entre deux piliers de pierre de taille.
func _mur_de_jardin(n: Node3D) -> void:
	var o := OUTILS.new(1036)
	var a: Vector2 = BARONS[1]
	var dr := (BARONS[2] - a).normalized()
	var dehors := -Vector2(-dr.y, dr.x)
	var bord := DEMI_CHAUSSEE + 2.45 + 0.25
	var base := Basis(Vector3.UP, -atan2(dr.y, dr.x))
	for troncon in [[MUR_DE, PORTAIL - 1.7], [PORTAIL + 1.7, MUR_A]]:
		var nb := ceili((troncon[1] - troncon[0]) / 2.0)
		var l: float = (troncon[1] - troncon[0]) / nb
		for k in nb:
			var v: Vector2 = a + dr * (float(troncon[0]) + (k + 0.5) * l) + dehors * bord
			var y: float = hauteur.call(v.x, v.y)
			o.boite(Transform3D(base, Vector3(v.x, y + 0.8, v.y)), Vector3(l + 0.02, 2.0, 0.45), MOELLON)
			o.boite(Transform3D(base, Vector3(v.x, y + 1.84, v.y)), Vector3(l + 0.04, 0.1, 0.58), CHAPERON)
	for cote: float in [-1.0, 1.0]:
		var v := a + dr * (PORTAIL + cote * 1.45) + dehors * bord
		var y: float = hauteur.call(v.x, v.y)
		o.boite(Transform3D(base, Vector3(v.x, y + 1.0, v.y)), Vector3(0.5, 2.4, 0.55), CHAPERON.darkened(0.04))
		o.boite(Transform3D(base, Vector3(v.x, y + 2.25, v.y)), Vector3(0.62, 0.12, 0.66), CHAPERON)
		o.boite(Transform3D(base, Vector3(v.x, y + 2.42, v.y)), Vector3(0.3, 0.22, 0.3), CHAPERON.lightened(0.04))
	# Les deux vantaux de planches, avec leur traverse haute et leur écharpe.
	var p := a + dr * PORTAIL + dehors * bord
	var yp: float = hauteur.call(p.x, p.y)
	for cote: float in [-1.0, 1.0]:
		var c := p + dr * cote * 0.6
		o.boite(Transform3D(base, Vector3(c.x, yp + 0.95, c.y)), Vector3(1.16, 1.75, 0.06), PORTE)
		for k in 5:
			var x := c + dr * (-0.46 + k * 0.23)
			o.boite(Transform3D(base, Vector3(x.x, yp + 0.95, x.y) + Vector3(-dehors.x, 0, -dehors.y) * 0.04), Vector3(0.02, 1.7, 0.02), PORTE.darkened(0.25))
		o.boite(Transform3D(base, Vector3(c.x, yp + 1.62, c.y) + Vector3(-dehors.x, 0, -dehors.y) * 0.05), Vector3(1.12, 0.12, 0.04), PORTE.darkened(0.12))
		o.boite(Transform3D(base, Vector3(c.x, yp + 0.32, c.y) + Vector3(-dehors.x, 0, -dehors.y) * 0.05), Vector3(1.12, 0.12, 0.04), PORTE.darkened(0.12))
		o.boite(Transform3D(base * Basis(Vector3.BACK, cote * 0.95), Vector3(c.x, yp + 0.97, c.y) + Vector3(-dehors.x, 0, -dehors.y) * 0.05), Vector3(1.45, 0.1, 0.04), PORTE.darkened(0.12))
	o.construire(n, "MurDeJardin")


## Un peu de vie sur la place (verdict n° 25) : deux étals de primeurs au bout du parvis, leurs caisses et une
## charrette, des clients devant ; deux bancs où l'on s'arrête.
func _marche(n: Node3D, d: Vector2, nrm: Vector2, longueur: float) -> void:
	var scene: PackedScene = load(Bibliotheque.scene("mobilier-du-bugey@1", "decor"))
	var lacet := atan2(d.x, d.y)
	var objets := [
		["etal", longueur - 5.0, -7.4, 0.0],
		["etal", longueur - 10.5, -7.4, 0.0],
		["caisses", longueur - 7.8, -6.2, 0.4],
		["charrette", longueur - 2.0, -8.8, 1.2],
		["banc", 11.5, -9.6, 0.0],
		["banc", 22.0, -9.6, 0.0],
	]
	var g := 80
	for ob in objets:
		var m: Node3D = scene.instantiate()
		m.set("objet", ob[0])
		m.set("options", {"allume": false})
		m.set("graine", g)
		g += 1
		m.position = _p(PLACE.ALLEE_A + d * float(ob[1]) + nrm * float(ob[2]), 0.17)
		m.rotation.y = lacet + PI * 0.5 + float(ob[3])
		n.add_child(m)
	# Les clients devant les étals.
	for k in 5:
		var f := Atelier.personnage("client", 380 + k)
		if f == null:
			continue
		n.add_child(f)
		var t := longueur - 4.0 - k * 1.6
		var v := PLACE.ALLEE_A + d * t + nrm * (-5.4 + 0.3 * float(k % 2))
		f.position = _p(v, 0.17)
		f.regarder(_p(PLACE.ALLEE_A + d * t + nrm * -7.4))
		f.jouer(["idle", "talk", "arms", "idle", "phone"][k])
