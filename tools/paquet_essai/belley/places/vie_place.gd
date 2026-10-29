extends RefCounted
## La vie de la place de la Cathédrale (verdict n° 16 du juge : personne sur le parvis) : des passants du socle
## (Atelier.personnage, « client ») qui causent par petits groupes sur le parvis et au pied des marches, d'autres
## qui suivent le trottoir ; et l'annonce du Grand Prix de la Louve, la course du dimanche (course-cycliste@1) :
## la banderole tendue au-dessus de la rue des Barons, les barrières de foule rouge et blanc déjà rangées le long
## du parvis.
##   VIE.new(hauteur).batir(parent)

const PLACE := preload("res://communes/belley/places/place_cathedrale.gd")

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
	banderole.set("options", {"texte": "GRAND PRIX DE LA LOUVE", "largeur": 9.5, "couleur": "d22a2a"})
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
