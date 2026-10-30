extends RefCounted
## Les jardins des cœurs d'îlot autour de la place, en volume (verdict n° 13 du juge : peints au sol, ils faisaient
## des pois) : des fruitiers, des arbustes fleuris et des bouts de haie taillée de vegetation-du-bugey@1, semés sur
## les prés, bosquets et vergers du relevé (couverture.png), hors des maisons, des rues et des places de
## bourg.json (les sols : places et cours). Chaque essence est bâtie une fois, puis posée en MultiMesh : quelques centaines de plantes pour le
## prix de quelques appels de rendu.
##   JARDINS.new(hauteur).batir(parent)

const PLANTE := preload("res://bibliotheque/vegetation-du-bugey/1/plante.gd")
const PLACE_CATHEDRALE := preload("res://communes/belley/places/place_cathedrale.gd")
const CATHEDRALE := preload("res://communes/belley/places/cathedrale.gd")
const OUTILS := preload("res://communes/belley/atelier/outils.gd")
const DOSSIER := "res://communes/belley/"
const MOELLON := Color("a89574", 0.0)
const CHAPERON := Color("b3a688", 0.0)
const UNITE := 2.4
const CENTRE := Vector2(200.0, 340.0)
const RAYON := 160.0
const PAS := 3.5
## Les classes du relevé où il y a des jardins : le pré, le bosquet, le verger, la lande, et les abords des rues
## du relevé (la chaussée elle-même est exclue par bourg.json).
const JARDINS := [0, 2, 5, 6, 8]
## L'angle du parcellaire, celui du shader du sol (relief/terrain.gdshader, jardins).
const ANGLE := 0.52
## Le repère du joueur sur la place (belley.gd, Vue1_Cathedrale) et le rayon où les plantes sont celles de la brique.
const REPERE := Vector2(165.0, 318.0)
const PRES := 55.0

var hauteur: Callable


func _init(sol: Callable) -> void:
	hauteur = sol


func batir(parent: Node3D) -> void:
	var b: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DOSSIER + "bourg.json"))
	var couv := (load(DOSSIER + "relief/couverture.png") as Texture2D).get_image()
	if couv.is_compressed():
		couv.decompress()
	var cm = JSON.parse_string(FileAccess.get_file_as_string(DOSSIER + "relief/couverture.json"))
	var obstacles := _obstacles(b)
	# Les essences, bâties une fois chacune : [plante, graine, options].
	var essences := [
		["cerisier", 3, {"hauteur": 4.2, "saison": "fruits"}],
		["cerisier", 8, {"hauteur": 5.0, "saison": "fruits"}],
		["cerisier", 12, {"hauteur": 3.6, "saison": "fruits"}],
		["arbuste_fleuri", 5, {"hauteur": 1.5, "fleurs": "f4f0e6"}],
		["arbuste_fleuri", 9, {"hauteur": 1.3, "fleurs": "d04a8a"}],
		["haie", 4, {"longueur": 4.0, "hauteur": 1.3}],
		["haie", 6, {"longueur": 4.0, "hauteur": 0.85}],
	]
	var poses := []
	for e in essences:
		poses.append([])
	var n := int(RAYON / PAS)
	for i in range(-n, n + 1):
		for j in range(-n, n + 1):
			var g := absi(hash(Vector2i(i, j)))
			var v := CENTRE + Vector2(i, j) * PAS + Vector2(float(g % 97) / 97.0 - 0.5, float(g % 89) / 89.0 - 0.5) * PAS * 0.8
			if v.distance_to(CENTRE) > RAYON:
				continue
			var px := int((v.x - float(cm.cadre[0])) / float(cm.pas))
			var pz := int((v.y - float(cm.cadre[1])) / float(cm.pas))
			if px < 0 or pz < 0 or px >= couv.get_width() or pz >= couv.get_height():
				continue
			var c := int(round(couv.get_pixel(px, pz).r * 255.0))
			if not c in JARDINS or _occupe(obstacles, v) or _cathedrale(v) or PLACE_CATHEDRALE.sur_le_stationnement(v):
				continue
			var tirage := g % 100
			var k := -1
			if tirage < 30:
				k = g % 3
			elif tirage < 46:
				k = 3 + g % 2
			if k < 0:
				continue
			var lacet := ANGLE + (PI * 0.5 if g % 2 == 0 else 0.0) if k >= 5 else float(g % 628) / 100.0
			poses[k].append(Transform3D(Basis(Vector3.UP, -lacet), Vector3(v.x, hauteur.call(v.x, v.y) - 0.05, v.y)))
	# Les limites des parcelles, continues : des haies taillées et, une fois sur trois, un muret de moellons, le
	# long des lanières du parcellaire (le même angle que le sol) et en travers, tous les 12 m environ.
	var murets: RefCounted = OUTILS.new(4421)
	var ca := cos(ANGLE)
	var sa := sin(ANGLE)
	var qc := Vector2(ca * CENTRE.x - sa * CENTRE.y, sa * CENTRE.x + ca * CENTRE.y)
	var monde := func(q: Vector2) -> Vector2: return Vector2(ca * q.x + sa * q.y, -sa * q.x + ca * q.y)
	var limites := []
	var y := floorf((qc.y - RAYON) / 10.0) * 10.0
	while y < qc.y + RAYON:
		var x := floorf((qc.x - RAYON) / 4.0) * 4.0
		while x < qc.x + RAYON:
			# Le type de limite tient sur 16 m : des tronçons continus, pas des bouts de haie isolés.
			limites.append([monde.call(Vector2(x + 2.0, y)), ANGLE, absi(hash(Vector2i(int(floor(x / 16.0)), int(y))))])
			x += 4.0
		var xt := floorf((qc.x - RAYON) / 12.0) * 12.0 + float(absi(hash(int(y))) % 12)
		while xt < qc.x + RAYON:
			for k in 2:
				limites.append([monde.call(Vector2(xt, y + 2.5 + k * 5.0)), ANGLE - PI * 0.5, absi(hash(Vector2i(int(xt), int(y) * 7)))])
			xt += 12.0 + float(absi(hash(Vector2i(int(xt), int(y)))) % 9)
		y += 10.0
	for l in limites:
		var v: Vector2 = l[0]
		if v.distance_to(CENTRE) > RAYON:
			continue
		var px := int((v.x - float(cm.cadre[0])) / float(cm.pas))
		var pz := int((v.y - float(cm.cadre[1])) / float(cm.pas))
		if px < 0 or pz < 0 or px >= couv.get_width() or pz >= couv.get_height():
			continue
		if not int(round(couv.get_pixel(px, pz).r * 255.0)) in JARDINS or _occupe(obstacles, v) or _cathedrale(v) or PLACE_CATHEDRALE.sur_le_stationnement(v):
			continue
		var t := Transform3D(Basis(Vector3.UP, l[1]), Vector3(v.x, hauteur.call(v.x, v.y) - 0.05, v.y))
		# Un tiers de haies, un tiers de murets, un tiers sans rien : la limite a ses trous.
		if int(l[2]) % 3 == 2:
			continue
		if int(l[2]) % 3 == 0:
			murets.boite(t * Transform3D(Basis(), Vector3(0, 0.35, 0)), Vector3(4.02, 0.8, 0.4), MOELLON)
			murets.boite(t * Transform3D(Basis(), Vector3(0, 0.79, 0)), Vector3(4.02, 0.08, 0.5), CHAPERON)
		else:
			# Des haies de hauteurs et d'épaisseurs variables.
			var e := 0.8 + float(int(l[2]) % 7) * 0.08
			poses[5 + int(l[2]) % 2].append(t * Transform3D(Basis.from_scale(Vector3(1.0, 0.7 + float(int(l[2]) % 5) * 0.15, e)), Vector3.ZERO))
	murets.construire(parent, "Murets")
	var tmp := Node3D.new()
	var noeud := Node3D.new()
	noeud.name = "Jardins"
	parent.add_child(noeud)
	for k in essences.size():
		if poses[k].is_empty():
			continue
		var e: Array = essences[k]
		# Près du joueur (à moins de PRES du repère de la place), la plante de la bibliothèque ; plus loin, sa
		# silhouette basse définition, cinquante fois plus légère (une plante de la brique fait 6 000 à 9 000
		# triangles, il y en a plus de mille).
		var proches := []
		var loin := []
		for t: Transform3D in poses[k]:
			(proches if Vector2(t.origin.x, t.origin.z).distance_to(REPERE) < PRES else loin).append(t)
		if not proches.is_empty():
			PLANTE.pousser(tmp, Vector3.ZERO, e[0], e[1], e[2])
			var mi: MeshInstance3D = null
			for enfant in tmp.get_children():
				if enfant is MeshInstance3D:
					mi = enfant
			_semer(noeud, "%s_%d" % [e[0], k], mi.mesh, proches, PRES + 60.0)
			for enfant in tmp.get_children():
				tmp.remove_child(enfant)
				enfant.free()
		if not loin.is_empty():
			_semer(noeud, "%s_%d_loin" % [e[0], k], _silhouette(e), loin, 420.0)
	tmp.free()


## Les maisons, les places et les rues proches, rangées par case de 20 m : [polygones, rubans].
func _obstacles(b: Dictionary) -> Dictionary:
	var cases := {}
	var ajouter := func(bas: Vector2, haut: Vector2, chose) -> void:
		for cx in range(int(floor(bas.x / 20.0)), int(floor(haut.x / 20.0)) + 1):
			for cz in range(int(floor(bas.y / 20.0)), int(floor(haut.y / 20.0)) + 1):
				var cle := Vector2i(cx, cz)
				if not cases.has(cle):
					cases[cle] = []
				cases[cle].append(chose)
	for liste in [b.batiments, b.sols]:
		for m in liste:
			var poly := PackedVector2Array()
			for p in m.p:
				poly.append(Vector2(p[0], p[1]) * UNITE)
			var r := Rect2(poly[0], Vector2.ZERO)
			for p in poly:
				r = r.expand(p)
			if r.get_center().distance_to(CENTRE) > RAYON + 60.0:
				continue
			ajouter.call(r.position - Vector2(2, 2), r.end + Vector2(2, 2), poly)
	for rue in b.routes:
		var l: float = float(rue.l) * UNITE * 0.5 + 2.6
		for k in rue.p.size() - 1:
			var a := Vector2(rue.p[k][0], rue.p[k][1]) * UNITE
			var c := Vector2(rue.p[k + 1][0], rue.p[k + 1][1]) * UNITE
			if a.distance_to(CENTRE) > RAYON + 200.0:
				continue
			ajouter.call(Vector2(minf(a.x, c.x), minf(a.y, c.y)) - Vector2(l, l), Vector2(maxf(a.x, c.x), maxf(a.y, c.y)) + Vector2(l, l), [a, c, l])
	return cases


func _occupe(cases: Dictionary, v: Vector2) -> bool:
	var cle := Vector2i(int(floor(v.x / 20.0)), int(floor(v.y / 20.0)))
	if not cases.has(cle):
		return false
	for chose in cases[cle]:
		if chose is PackedVector2Array:
			if Geometry2D.is_point_in_polygon(v, chose) or _pres_du_bord(v, chose, 1.8):
				return true
		else:
			if Geometry2D.get_closest_point_to_segment(v, chose[0], chose[1]).distance_to(v) < chose[2]:
				return true
	return false


func _pres_du_bord(v: Vector2, poly: PackedVector2Array, d: float) -> bool:
	for k in poly.size():
		if Geometry2D.get_closest_point_to_segment(v, poly[k], poly[(k + 1) % poly.size()]).distance_to(v) < d:
			return true
	return false


## La cathédrale, son parvis et ses marches : de 14 m devant la façade à 75 m derrière, sur 32 m de large.
func _cathedrale(v: Vector2) -> bool:
	var dehors := Vector2(-0.862, -0.508)
	var o: Vector2 = CATHEDRALE.ORIGINE
	var p := Geometry2D.get_closest_point_to_segment(v, o + dehors * 14.0, o - dehors * 75.0)
	return p.distance_to(v) < 16.0


func _semer(noeud: Node3D, nom: String, mesh: Mesh, poses: Array, portee: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = poses.size()
	for q in poses.size():
		mm.set_instance_transform(q, poses[q])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nom
	mmi.multimesh = mm
	mmi.visibility_range_end = portee
	noeud.add_child(mmi)


## La silhouette basse définition d'une essence : quelques boules de feuillage de ses verts, un fût.
func _silhouette(e: Array) -> Mesh:
	var o: RefCounted = OUTILS.new(int(e[1]) * 31)
	var verts: Array = PLANTE.VERTS[e[0]].map(func(h): return Color(h))
	var opt: Dictionary = e[2]
	var tmp := Node3D.new()
	match str(e[0]):
		"cerisier":
			var h := float(opt.get("hauteur", 4.5))
			o.cylindre(Transform3D(Basis(), Vector3.ZERO), 0.14, 0.1, h * 0.4, 5, Color("6a5444"), OUTILS.PEINT, false)
			for q in 4:
				var a := q * TAU / 4.0 + 0.4
				var c := Vector3(cos(a) * h * 0.16, h * (0.62 + 0.06 * (q % 2)), sin(a) * h * 0.16)
				o.boule(c, Vector3(h * 0.24, h * 0.2, h * 0.24), verts[q % verts.size()], 0.15, OUTILS.FEUILLE, 0.05, 0.4, 3, 6)
			o.boule(Vector3(0, h * 0.82, 0), Vector3(h * 0.22, h * 0.18, h * 0.22), verts[0], 0.15, OUTILS.FEUILLE, 0.05, 0.4, 3, 6)
		"arbuste_fleuri":
			var h := float(opt.get("hauteur", 1.5))
			var fleur := Color(str(opt.get("fleurs", "f4f0e6")))
			o.boule(Vector3(0, h * 0.5, 0), Vector3(h * 0.55, h * 0.5, h * 0.55), verts[1], 0.2, OUTILS.FEUILLE, 0.05, 0.3, 3, 6)
			for q in 5:
				var a := q * TAU / 5.0
				o.boule(Vector3(cos(a) * h * 0.4, h * (0.6 + 0.08 * (q % 2)), sin(a) * h * 0.4), Vector3(0.12, 0.1, 0.12), fleur, 0.0, OUTILS.FEUILLE, 0.0, 0.3, 2, 4)
		_:
			var l := float(opt.get("longueur", 4.0))
			var h := float(opt.get("hauteur", 1.1))
			o.boule(Vector3(0, h * 0.5, 0), Vector3(l * 0.52, h * 0.5, 0.45), verts[1], 0.1, OUTILS.FEUILLE, 0.05, 0.2, 3, 8)
	var mi: MeshInstance3D = o.construire(tmp, "silhouette")
	var mesh := mi.mesh
	tmp.free()
	return mesh
