extends RefCounted
## La place Saint-Georges (note d'intentions, scènes 1 à 3 de la version 0.1) : les fronts de rue composés autour
## de la place, l'hôtel de Lafage sur le côté est, les platanes réels du plan, le jardin d'enfants du square
## Jean-Calas, les terrasses, le café de courses à l'angle de la rue de la Pomme et l'étal du primeur.
## Tout est composé avec la bibliothèque commune : les briques toulousaines (facadier-toulousain@1,
## mobilier-toulousain@1) quand le socle les a, les lyonnaises sinon.
## Les briques sont en mètres : chaque pièce se pose sous un nœud à l'échelle 1/2,4.

const UNITE := 2.4
const LAFAGE_SCRIPT := preload("res://communes/toulouse/lafage.gd")
## L'hôtel de Lafage : le bâtiment 458 du plan (19 place Saint-Georges, OSM node/2006246750), façade à l'ouest.
const LAFAGE := 458
## Sa façade sur la place, du sud au nord (les trois murs presque alignés du plan, réunis en un seul).
const LAFAGE_SUD := Vector2(20.49, 1.21)
const LAFAGE_NORD := Vector2(13.12, -16.15)
## Le café de courses, Les Trois Platanes, à l'angle de la rue de la Pomme : le front le plus proche de ce point.
const CAFE := Vector2(-4.5, -4.0)
## Le Cercle de la Violette, la salle de jeu à seuil, dans l'hôtel à porche voisin de Lafage, au nord-est.
const CERCLE := Vector2(10.5, -19.0)
## Les portes des deux salles de jeu de la place : l'id de la structure, son nœud, ce que dit la porte.
const PORTES := {
	"trois_platanes": ["PorteTroisPlatanes", "Les Trois Platanes : le café de courses"],
	"violette": ["PorteViolette", "Le Cercle de la Violette"],
}
const PERSIENNES := ["9daa92", "e7ddc4", "8c9daa", "b9b2a0"]
const TOILES := [["8c2f39", "f1e6cc"], ["f1e6cc", "f1e6cc"], ["2e7d5b", "f1e6cc"], ["8c2f39", "8c2f39"]]
## Les enseignes des cafés et des restaurants de la place : des maisons inventées (aucune enseigne réelle).
const ENSEIGNES := ["CAFÉ DES CAPITOULS", "LE PASTEL", "BAR DE LA BRIQUE", "AU CASSOULET", "LA VIOLETTE", "BAR DES ARCADES", "CHEZ PEYROLLES", "LE TOURNESOL", "LA GARONNETTE", "CAFÉ DU MIDI"]


static func _brique(ref: String, fichier: String) -> Script:
	return load(Bibliotheque.scene(ref, "decor").get_base_dir() + "/" + fichier)


## Jusqu'où, autour de la place, les fronts sont composés (en unités : 7 × 2,4 ≈ 17 m, le débouché des rues) ;
## au-delà, les îlots en volumes suffisent.
const ABORDS := 7.0
## Les arbres des rues et des cours, jusqu'à cette distance du centre de la place (55 unités, 130 m), en multimaillages
## que le socle change en imposteurs au-delà de 120 m ; plus loin, les toits les cachent.
const LOIN := 55.0


## Les bâtiments dont la place compose les fronts : ceux qui ont un mur sur la rue aux abords de la place.
## Rend {indice: [murs sur la rue, chacun [a, c]]}.
static func batiments_composes(t) -> Dictionary:
	var r := {}
	var abords: PackedVector2Array = Geometry2D.offset_polygon(PackedVector2Array(t.PLACE_SAINT_GEORGES), ABORDS)[0]
	for b in t.data.batiments:
		var poly: PackedVector2Array = t._horaire(b.poly)
		var murs := []
		for k in poly.size():
			var a := poly[k]
			var c := poly[(k + 1) % poly.size()]
			if a.distance_to(c) * UNITE < 3.6:
				continue
			if not Geometry2D.is_point_in_polygon((a + c) * 0.5, abords):
				continue
			if t.sur_la_rue(a, c):
				murs.append([a, c])
		if not murs.is_empty():
			r[int(b.i)] = murs
	return r


static func construire(t) -> void:
	var racine := Node3D.new()
	racine.name = "SaintGeorges"
	t.add_child(racine)
	_fronts(t, racine)
	_platanes(t, racine)
	_jardin(t, racine)
	_mobilier(t, racine)
	_vie(racine)
	_fondre(racine, "Facades")
	_fondre(racine, "Mobilier")
	_fondre(racine, "Platanes")


# --- Les fronts -----------------------------------------------------------------------------------

## Le nombre d'étages au-dessus du rez-de-chaussée, d'après la hauteur réelle (rez-de-chaussée 4,2 m, étages 3,3).
static func _niveaux(b: Dictionary) -> int:
	return clampi(int(round((float(b.h) * UNITE - 4.2) / 3.3)), 1, 5)


static func _fronts(t, racine: Node3D) -> void:
	if _toulousain("facadier-toulousain@1"):
		_fronts_toulousains(t, racine)
		return
	var fac: Script = _brique("facadier-lyonnais@1", "facadier.gd")
	var composes: Dictionary = batiments_composes(t)
	var groupe := Node3D.new()
	groupe.name = "Facades"
	racine.add_child(groupe)
	# Les volumes des bâtiments composés, à la hauteur des façades qu'on leur pose.
	var sm := SurfaceTool.new()
	sm.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stt := SurfaceTool.new()
	stt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var place := PackedVector2Array(t.PLACE_SAINT_GEORGES)
	var cafe_pose := false
	var murs_cafe := _mur_le_plus_proche(composes, CAFE)
	for i in composes:
		var b: Dictionary = t.data.batiments[i]
		var n := _niveaux(b)
		var hm := 4.2 + n * 3.3
		if int(i) == LAFAGE:
			hm = LAFAGE_SCRIPT.RDC + LAFAGE_SCRIPT.ETAGE1 + LAFAGE_SCRIPT.ETAGE2 + 0.74
		t.volume(sm, stt, b, t._horaire(b.poly), hm / UNITE - 0.05, t.teinte_mur(b))
		for m in composes[i]:
			var a: Vector2 = m[0]
			var c: Vector2 = m[1]
			var l: float = a.distance_to(c) * UNITE
			var u := (c - a).normalized()
			var dehors := Vector2(u.y, -u.x)
			var sur_place := Geometry2D.is_point_in_polygon((a + c) * 0.5 + dehors * 2.0, place)
			if int(i) == LAFAGE and dehors.x < -0.7:
				continue
			var morceaux := maxi(1, int(round(l / 9.5)))
			var w := l / morceaux
			for k in morceaux:
				var milieu := a.lerp(c, (k + 0.5) / morceaux) + dehors * 0.04
				var graine := int(i) * 31 + k * 7
				var r := RandomNumberGenerator.new()
				r.seed = graine
				var opt := {"w": w + 0.1, "d": 5.0, "niveaux": n, "toit": "tuile",
					"persiennes": PERSIENNES[r.randi() % PERSIENNES.size()],
					"toile": TOILES[r.randi() % TOILES.size()],
					"enduit": _teinte_front(t, b, r)}
				var type := "classique"
				if w < 6.0:
					type = "etroite"
				elif w < 8.5:
					type = "maison"
				elif w > 11.0 and n >= 4:
					type = "immeuble"
				if sur_place:
					opt["rdc"] = "cafe" if r.randf() < 0.45 else "boutique"
					opt["enseigne"] = ENSEIGNES[graine % ENSEIGNES.size()]
				elif r.randf() < 0.5:
					opt["rdc"] = "logis"
				if not cafe_pose and murs_cafe == [i, m] and k == morceaux / 2:
					opt["rdc"] = "cafe"
					opt["enseigne"] = "LES TROIS PLATANES"
					opt["toile"] = ["2e7d5b", "f1e6cc"]
					cafe_pose = true
				if type == "etroite":
					opt["niveaux"] = mini(n, 4)
				var porteur := Node3D.new()
				porteur.transform = Transform3D(Basis(Vector3.UP, atan2(dehors.x, dehors.y)).scaled(Vector3.ONE / UNITE), Vector3(milieu.x, 0.0, milieu.y))
				groupe.add_child(porteur)
				fac.maison(porteur, Vector3.ZERO, type, graine, opt)
	_lafage(groupe)
	var murs_mat := ShaderMaterial.new()
	murs_mat.shader = load(t.DOSSIER + "murs.gdshader")
	var toit_mat := ShaderMaterial.new()
	toit_mat.shader = load("res://shaders/roof_tiles.gdshader")
	var mesh := ArrayMesh.new()
	sm.commit(mesh)
	mesh.surface_set_material(0, murs_mat)
	stt.commit(mesh)
	mesh.surface_set_material(1, toit_mat)
	var mi := MeshInstance3D.new()
	mi.name = "Volumes"
	mi.mesh = mesh
	racine.add_child(mi)


## Les fronts au façadier toulousain (la brique foraine, la génoise, les persiennes gris vert) : le type suit la
## largeur du morceau et sa place (les cafés et les restaurants sur la place, les logis dans les rues), le
## parement suit le mur du plan (brique ou enduit), les niveaux la hauteur réelle.
static func _fronts_toulousains(t, racine: Node3D) -> void:
	var fac: Script = _brique("facadier-toulousain@1", "facadier.gd")
	var composes: Dictionary = batiments_composes(t)
	var groupe := Node3D.new()
	groupe.name = "Facades"
	racine.add_child(groupe)
	var sm := SurfaceTool.new()
	sm.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stt := SurfaceTool.new()
	stt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var place := PackedVector2Array(t.PLACE_SAINT_GEORGES)
	var cafe_pose := false
	var cercle_pose := false
	var murs_cafe := _mur_le_plus_proche(composes, CAFE)
	var sans_lafage := composes.duplicate()
	sans_lafage.erase(LAFAGE)
	var murs_cercle := _mur_le_plus_proche(sans_lafage, CERCLE)
	var portes := {}
	for i in composes:
		var b: Dictionary = t.data.batiments[i]
		var n := clampi(int(round((float(b.h) * UNITE - fac.RDC) / fac.ETAGE)), 1, 6)
		var hm: float = fac.RDC + n * fac.ETAGE
		if int(i) == LAFAGE:
			hm = LAFAGE_SCRIPT.RDC + LAFAGE_SCRIPT.ETAGE1 + LAFAGE_SCRIPT.ETAGE2 + 0.74
		t.volume(sm, stt, b, t._horaire(b.poly), hm / UNITE - 0.05, t.teinte_mur(b))
		for m in composes[i]:
			var a: Vector2 = m[0]
			var c: Vector2 = m[1]
			var l: float = a.distance_to(c) * UNITE
			var u := (c - a).normalized()
			var dehors := Vector2(u.y, -u.x)
			var sur_place := Geometry2D.is_point_in_polygon((a + c) * 0.5 + dehors * 2.0, place)
			if int(i) == LAFAGE and dehors.x < -0.7:
				continue
			var morceaux := maxi(1, int(round(l / 9.0)))
			var w := l / morceaux
			for k in morceaux:
				var milieu := a.lerp(c, (k + 0.5) / morceaux) + dehors * 0.04
				var graine := int(i) * 31 + k * 7
				var r := RandomNumberGenerator.new()
				r.seed = graine
				var opt := {"w": w + 0.1, "d": 6.0, "niveaux": n}
				# La brique domine : les murs de brique du plan, et trois sur cinq des autres ; l'enduit rose poudre
				# ou crème pour le reste, à chaînes de brique.
				if b.mur == "brique" or r.randf() < 0.6:
					opt["brique"] = ["rose", "orange", "saumon", "claire", "rose"][r.randi() % 5]
				else:
					opt["enduit"] = ["rose_poudre", "creme", "ocre_rose"][r.randi() % 3]
				var type := "moyenne"
				if w < 5.6:
					type = "etroite"
				elif w > 9.5 and n >= 4:
					type = "immeuble"
				if sur_place:
					var genre: String = ["cafe", "restaurant", "commerce", "cafe"][r.randi() % 4]
					opt["rdc"] = genre
					opt["enseigne"] = ENSEIGNES[graine % ENSEIGNES.size()] if genre != "commerce" else ""
					opt["toile"] = TOILES[r.randi() % TOILES.size()]
					if w > 11.0 and opt.has("enduit"):
						type = "hotel"
						opt["rdc"] = "porche"
					opt["vigne"] = r.randf() < 0.15
					opt["fleurs"] = r.randf() < 0.65
					# Les persiennes gris vert, crème ou gris bleu sur presque toutes les façades ; les autres ont leurs
					# fenêtres nues, comme les immeubles enduits de la place.
					opt["persiennes"] = PERSIENNES[r.randi() % PERSIENNES.size()] if r.randf() < 0.85 else false
				else:
					# Dans le débouché des rues : des façades un peu plus sobres que sur la place, mais habitées (des
					# persiennes sept fois sur dix, des balconnets une fois sur deux, des fleurs, un peu de vigne).
					opt["rdc"] = "logis" if r.randf() < 0.6 else "commerce"
					opt["vigne"] = r.randf() < 0.1
					opt["fleurs"] = r.randf() < 0.45
					opt["balconnets"] = r.randf() < 0.5
					opt["persiennes"] = PERSIENNES[r.randi() % PERSIENNES.size()] if r.randf() < 0.7 else false
				if not cafe_pose and murs_cafe == [i, m] and k == morceaux / 2:
					opt["rdc"] = "cafe"
					opt["enseigne"] = "LES TROIS PLATANES"
					opt["toile"] = ["2e7d5b", "f1e6cc"]
					opt.erase("enduit")
					opt["brique"] = "rose"
					cafe_pose = true
					portes["trois_platanes"] = [milieu, dehors]
				elif not cercle_pose and murs_cercle == [i, m] and k == morceaux / 2:
					type = "hotel"
					opt["rdc"] = "porche"
					opt.erase("brique")
					opt["enduit"] = "rose_poudre"
					opt["balconnets"] = true
					cercle_pose = true
					portes["violette"] = [milieu, dehors]
				if type == "etroite":
					opt["niveaux"] = mini(n, 4)
				var porteur := Node3D.new()
				porteur.transform = Transform3D(Basis(Vector3.UP, atan2(dehors.x, dehors.y)).scaled(Vector3.ONE / UNITE), Vector3(milieu.x, 0.0, milieu.y))
				groupe.add_child(porteur)
				fac.maison(porteur, Vector3.ZERO, type, graine, opt)
	_lafage(groupe)
	_portes(t, portes)
	var murs_mat := ShaderMaterial.new()
	murs_mat.shader = load(t.DOSSIER + "murs.gdshader")
	var toit_mat := ShaderMaterial.new()
	toit_mat.shader = load("res://shaders/roof_tiles.gdshader")
	var mesh := ArrayMesh.new()
	sm.commit(mesh)
	mesh.surface_set_material(0, murs_mat)
	stt.commit(mesh)
	mesh.surface_set_material(1, toit_mat)
	var mi := MeshInstance3D.new()
	mi.name = "Volumes"
	mi.mesh = mesh
	racine.add_child(mi)


## Les portes des salles de jeu : le nœud qui place la structure (manifeste, « noeud »), tourné vers la place,
## et la zone où l'on appuie sur E. Fermée, la porte dit le seuil.
static func _portes(t, portes: Dictionary) -> void:
	for id in portes:
		var milieu: Vector2 = portes[id][0]
		var dehors: Vector2 = portes[id][1]
		var q := milieu + dehors * 0.35
		var repere := Node3D.new()
		repere.name = PORTES[id][0]
		repere.transform = Transform3D(Basis(Vector3.UP, atan2(dehors.x, dehors.y)), Vector3(q.x, 0.05, q.y))
		t.add_child(repere)
		var zone := Area3D.new()
		zone.name = "Zone"
		zone.position = Vector3(0, 0.6, 0)
		zone.set_meta("interact", id)
		var invite: String = PORTES[id][1]
		if not SalleJeu.ouverte("toulouse", id):
			invite += " · ouvre à %s crédits gagnés au jeu" % Game.fmt(SalleJeu.seuil("toulouse", id))
		zone.set_meta("prompt", invite)
		var f := CollisionShape3D.new()
		var forme := BoxShape3D.new()
		forme.size = Vector3(1.4, 1.2, 0.6)
		f.shape = forme
		zone.add_child(f)
		repere.add_child(zone)


## Vrai si la brique est dans la bibliothèque de ce socle (les briques toulousaines, tant qu'elles n'y sont pas,
## laissent la place aux lyonnaises).
static func _toulousain(ref: String) -> bool:
	return Bibliotheque.scene(ref, "decor") != ""


## La brique domine (parti pris de la note) : un front de brique foraine sur trois sur quatre, l'enduit rose
## poudre ou crème pour les autres, comme les hôtels particuliers.
static func _teinte_front(t, b: Dictionary, r: RandomNumberGenerator) -> String:
	if b.mur == "brique" or r.randf() < 0.6:
		return t.BRIQUES[r.randi() % t.BRIQUES.size()]
	return t.ENDUITS[r.randi() % t.ENDUITS.size()]


## L'hôtel de Lafage, sur toute la longueur de son côté de la place, avancé de 60 cm pour couvrir les petits
## décrochements du cadastre.
static func _lafage(groupe: Node3D) -> void:
	var u := (LAFAGE_NORD - LAFAGE_SUD).normalized()
	var dehors := Vector2(u.y, -u.x)
	if dehors.x > 0.0:
		dehors = -dehors
	var milieu := (LAFAGE_SUD + LAFAGE_NORD) * 0.5 + dehors * 0.25
	var porteur := Node3D.new()
	porteur.name = "Lafage"
	porteur.transform = Transform3D(Basis(Vector3.UP, atan2(dehors.x, dehors.y)).scaled(Vector3.ONE / UNITE), Vector3(milieu.x, 0.0, milieu.y))
	groupe.add_child(porteur)
	LAFAGE_SCRIPT.construire(porteur, LAFAGE_SUD.distance_to(LAFAGE_NORD) * UNITE, 12.0)


static func _mur_le_plus_proche(composes: Dictionary, p: Vector2) -> Array:
	var meilleur := []
	var d := INF
	for i in composes:
		for m in composes[i]:
			var e: float = ((m[0] + m[1]) * 0.5).distance_to(p)
			if e < d:
				d = e
				meilleur = [i, m]
	return meilleur


# --- Les platanes ---------------------------------------------------------------------------------

## Les arbres réels du plan : des platanes de Lyon au fût marbré (la même essence que les quais du Rhône, une
## seule brique pour une essence). Ceux de la place sont posés un à un, plus grands et grillagés au pied ;
## les autres, dans les cours et les rues, en trois modèles répétés.
static func _platanes(t, racine: Node3D) -> void:
	var veg: Script = _brique("vegetation-lyonnaise@1", "plante.gd")
	var groupe := Node3D.new()
	groupe.name = "Platanes"
	racine.add_child(groupe)
	var place := Geometry2D.offset_polygon(PackedVector2Array(t.PLACE_SAINT_GEORGES), 2.0)[0]
	var loin := []
	var clair := ShaderMaterial.new()
	clair.shader = load(t.DOSSIER + "feuillage.gdshader")
	for k in t.data.arbres.size():
		var a: Array = t.data.arbres[k]
		var p := Vector2(a[0], a[1])
		if Geometry2D.is_point_in_polygon(p, place):
			var porteur := Node3D.new()
			# L'ombrière : la couronne élargie d'un quart, au-dessus des terrasses, et un feuillage plus clair.
			porteur.transform = Transform3D(Basis(Vector3.UP, k * 1.7).scaled(Vector3(1.25, 1.0, 1.25) / UNITE), Vector3(p.x, 0.0, p.y))
			groupe.add_child(porteur)
			veg.pousser(porteur, Vector3.ZERO, "platane", k, {"hauteur": 19.0 + (k % 4) * 0.9, "pied": "grille"})
			_eclaircir(porteur, clair)
		elif t.batiment_en(p).is_empty() and p.distance_to(t.CENTRE_DETAIL) < LOIN:
			loin.append(p)
	# Les arbres hors de la place : trois platanes modèles, en multimaillages par cases de 30 m, que le socle
	# remplace au loin par leurs images (Lointain.imposteurs).
	var modeles := []
	for m in 3:
		var n := Node3D.new()
		veg.pousser(n, Vector3.ZERO, "platane", 900 + m, {"hauteur": 13.0 + m * 2.0})
		modeles.append(n)
	var cases := {}
	for k in loin.size():
		var p: Vector2 = loin[k]
		var cle := Vector3i(int(floor(p.x / 12.5)), int(floor(p.y / 12.5)), k % 3)
		if not cases.has(cle):
			cases[cle] = []
		cases[cle].append(p)
	for cle in cases:
		var modele: Node3D = modeles[cle.z]
		for mi in modele.find_children("*", "MeshInstance3D", true, false):
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = (mi as MeshInstance3D).mesh
			mm.instance_count = cases[cle].size()
			for j in cases[cle].size():
				var p: Vector2 = cases[cle][j]
				mm.set_instance_transform(j, Transform3D(Basis(Vector3.UP, p.x * 3.1 + p.y).scaled(Vector3.ONE / UNITE), Vector3(p.x, 0.0, p.y)))
			var mmi := MultiMeshInstance3D.new()
			mmi.name = "Arbres_%d_%d_%d" % [cle.x, cle.y, cle.z]
			mmi.multimesh = mm
			racine.add_child(mmi)
	for n in modeles:
		n.free()


## Remplace le feuillage de la brique par le feuillage clair de la place (même couleur par sommet, même vent).
static func _eclaircir(n: Node, clair: ShaderMaterial) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var mat := m.get_active_material(s) as ShaderMaterial
			if mat != null and mat.shader != null and mat.shader.resource_path.ends_with("feuillage.gdshader"):
				m.set_surface_override_material(s, clair)


# --- Le jardin d'enfants --------------------------------------------------------------------------

## Le square Jean-Calas, au nord-est de la place : un muret de pierre à grille de fonte, un sol de sable, un
## portique et un toboggan, deux bancs tournés vers les jeux.
static func _jardin(t, racine: Node3D) -> void:
	var poly := PackedVector2Array()
	for s in t.data.sols:
		if str(s.get("nom", "")) == "Square Jean Calas":
			for q in s.p:
				poly.append(Vector2(q[0], q[1]))
	if poly.size() < 3:
		return
	if _toulousain("mobilier-toulousain@1"):
		# Le jardin d'enfants toulousain (muret de brique, grille, portique, toboggan), son portillon vers la
		# place, à l'ouest.
		var centre := Vector2.ZERO
		for q in poly:
			centre += q
		centre /= poly.size()
		_parterre(racine, Geometry2D.offset_polygon(poly, 0.4)[0], centre)
		var porteur := Node3D.new()
		porteur.name = "Jardin"
		porteur.transform = Transform3D(Basis(Vector3.UP, -PI * 0.5).scaled(Vector3.ONE / UNITE), Vector3(centre.x, 0.0, centre.y))
		racine.add_child(porteur)
		_brique("mobilier-toulousain@1", "objet.gd").poser(porteur, Vector3.ZERO, "jardin_enfants", 31555)
		return
	var o = _brique("mobilier-lyonnais@1", "outils.gd").new(31555)
	var c := Vector2.ZERO
	for q in poly:
		c += q
	c /= poly.size()
	# Le sol de sable, un peu au-dessus de la brique.
	var sable := Color("d8c39a")
	var tri := Geometry2D.triangulate_polygon(poly)
	for k in range(0, tri.size(), 3):
		var a := Vector3(poly[tri[k]].x, 0.03, poly[tri[k]].y) * UNITE
		var b := Vector3(poly[tri[k + 1]].x, 0.03, poly[tri[k + 1]].y) * UNITE
		var d := Vector3(poly[tri[k + 2]].x, 0.03, poly[tri[k + 2]].y) * UNITE
		o.tri(a, b, d, Vector3.UP, sable)
	# Le muret et sa grille, ouverts d'une porte face à la place (vers l'ouest).
	for k in poly.size():
		var a := poly[k] * UNITE
		var b := poly[(k + 1) % poly.size()] * UNITE
		var l := a.distance_to(b)
		if l < 0.3:
			continue
		var u := (b - a) / l
		var ang := atan2(-u.y, u.x)
		var m := (a + b) * 0.5
		if (m / UNITE - c).normalized().x < -0.85 and l > 2.0:
			continue
		o.boite(Transform3D(Basis(Vector3.UP, ang), Vector3(m.x, 0.3, m.y)), Vector3(l + 0.3, 0.6, 0.35), Color("d9cbb0"), 0, true)
		o.boite(Transform3D(Basis(Vector3.UP, ang), Vector3(m.x, 0.63, m.y)), Vector3(l + 0.4, 0.06, 0.42), Color("efe6d4"))
		var n := int(l / 0.14)
		for j in n:
			var p := a + u * (j + 0.5) * l / n
			o.boite(Transform3D(Basis(Vector3.UP, ang), Vector3(p.x, 0.95, p.y)), Vector3(0.025, 0.6, 0.025), Color("23272a"))
		o.boite(Transform3D(Basis(Vector3.UP, ang), Vector3(m.x, 1.24, m.y)), Vector3(l, 0.04, 0.04), Color("23272a"))
	# Le portique (deux balançoires) et le toboggan, bois peint et métal.
	var cm := c * UNITE
	var bois := Color("b98a4e")
	for s in [-1.0, 1.0]:
		o.branche(Vector3(cm.x - 2.6, 0, cm.y + s * 0.9), Vector3(cm.x - 2.6, 2.3, cm.y), 0.07, 0.06, bois)
		o.branche(Vector3(cm.x + 0.6, 0, cm.y + s * 0.9), Vector3(cm.x + 0.6, 2.3, cm.y), 0.07, 0.06, bois)
	o.branche(Vector3(cm.x - 2.8, 2.3, cm.y), Vector3(cm.x + 0.8, 2.3, cm.y), 0.07, 0.07, bois)
	for x in [-1.8, -0.3]:
		o.branche(Vector3(cm.x + x, 2.3, cm.y), Vector3(cm.x + x, 0.55, cm.y), 0.012, 0.012, Color("23272a"))
		o.boite(Transform3D(Basis(), Vector3(cm.x + x, 0.5, cm.y)), Vector3(0.45, 0.05, 0.2), Color("8c2f39"))
	var tob := Vector3(cm.x + 2.6, 0, cm.y + 1.6)
	o.boite(Transform3D(Basis(), tob + Vector3(0, 0.75, 0)), Vector3(1.0, 1.5, 1.0), Color("2e7d5b"), 0, true)
	o.boite(Transform3D(Basis(), tob + Vector3(0, 1.55, 0)), Vector3(1.1, 0.1, 1.1), Color("e0a93a"))
	o.boite(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-35.0)), tob + Vector3(0, 0.75, -1.4)), Vector3(0.6, 0.06, 2.2), Color("d9473b"))
	var porteur := Node3D.new()
	porteur.name = "Jardin"
	porteur.scale = Vector3.ONE / UNITE
	racine.add_child(porteur)
	o.construire(porteur, "SquareJeanCalas")


## Le parterre du centre de la place (photos de Guillaume, 29 octobre) : une pelouse cernée d'un muret bas de
## pierre claire, 60 cm à chaperon, ouvert à l'ouest face à la place et au sud vers la rue ; le jardin d'enfants
## au milieu. Une disposition propre à la place, faite comme le sol, avec les outils du mobilier lyonnais.
static func _parterre(racine: Node3D, poly: PackedVector2Array, centre: Vector2) -> void:
	var o = _brique("mobilier-lyonnais@1", "outils.gd").new(1762)
	var herbe := Color("86ad52")
	var tri := Geometry2D.triangulate_polygon(poly)
	for k in range(0, tri.size(), 3):
		var a := Vector3(poly[tri[k]].x * UNITE, 0.12, poly[tri[k]].y * UNITE)
		var b := Vector3(poly[tri[k + 1]].x * UNITE, 0.12, poly[tri[k + 1]].y * UNITE)
		var d := Vector3(poly[tri[k + 2]].x * UNITE, 0.12, poly[tri[k + 2]].y * UNITE)
		o.tri(a, b, d, Vector3.UP, herbe.lightened(0.03 * (k % 3)))
	var pierre := Color("d9cbae")
	var chaperon := Color("e0d6c1")
	for k in poly.size():
		var a := poly[k] * UNITE
		var b := poly[(k + 1) % poly.size()] * UNITE
		var l := a.distance_to(b)
		if l < 0.2:
			continue
		var u := (b - a) / l
		var dir := ((a + b) * 0.5 / UNITE - centre).normalized()
		# Les passages : 2,4 m au milieu des côtés ouest et sud, assez longs pour en avoir.
		var morceaux := [[0.0, l]]
		if l > 4.0 and (dir.x < -0.6 or dir.y > 0.75):
			morceaux = [[0.0, l * 0.5 - 1.2], [l * 0.5 + 1.2, l]]
		for m in morceaux:
			var lm: float = m[1] - m[0]
			if lm < 0.2:
				continue
			var c: Vector2 = a + u * (m[0] + lm * 0.5)
			var bas := Basis(Vector3.UP, atan2(-u.y, u.x))
			o.boite(Transform3D(bas, Vector3(c.x, 0.27, c.y)), Vector3(lm + 0.3, 0.54, 0.3), pierre, 0, true)
			o.boite(Transform3D(bas, Vector3(c.x, 0.57, c.y)), Vector3(lm + 0.34, 0.07, 0.38), chaperon)
	var porteur := Node3D.new()
	porteur.name = "Parterre"
	porteur.scale = Vector3.ONE / UNITE
	racine.add_child(porteur)
	o.construire(porteur, "Parterre")


# --- Le mobilier ----------------------------------------------------------------------------------

## Les terrasses du nord de la place (au soleil du soir), celle des Trois Platanes, celle des arcades de Lafage,
## l'étal du primeur, les lampadaires, les potelets le long de la rue, les bancs et les jardinières.
static func _mobilier(t, racine: Node3D) -> void:
	if _toulousain("mobilier-toulousain@1"):
		_mobilier_toulousain(t, racine)
		return
	var mob: Script = _brique("mobilier-lyonnais@1", "objet.gd")
	var groupe := Node3D.new()
	groupe.name = "Mobilier"
	groupe.scale = Vector3.ONE / UNITE
	racine.add_child(groupe)
	var poser := func(nom: String, p: Vector2, lacet: float, graine: int, opt := {}) -> void:
		var n := Node3D.new()
		n.transform = Transform3D(Basis(Vector3.UP, lacet), Vector3(p.x, 0.0, p.y) * UNITE)
		groupe.add_child(n)
		mob.poser(n, Vector3.ZERO, nom, graine, opt)
	# Les terrasses : trois rangs au pied des façades nord, tournées vers la place (le sud).
	var g := 0
	for x in [1.0, 3.6, 6.2, 8.8, 11.4]:
		for z in [-15.6, -13.4]:
			poser.call("terrasse", Vector2(x + (z + 15.0) * 0.4, z), 0.0, g, {"toile": TOILES[g % 2]})
			g += 1
	# Les Trois Platanes : tables serrées dans l'angle de la rue de la Pomme, store vert et blanc.
	for p in [Vector2(-2.6, -6.0), Vector2(-2.2, -3.6), Vector2(-0.4, -7.2), Vector2(0.0, -4.8), Vector2(-4.4, -8.4)]:
		poser.call("terrasse", p, PI * 0.5, g, {"toile": ["2e7d5b", "f1e6cc"]})
		g += 1
	# Sous les arcades de Lafage, côté place : le restaurant de l'hôtel.
	for z in [-11.0, -8.2, -5.4, -2.6]:
		poser.call("terrasse", Vector2(15.2 + (z + 11.0) * 0.12, z), -PI * 0.5, g, {"toile": ["f1e6cc", "f1e6cc"]})
		g += 1
	# Le primeur, au sud-est, sous son store vert et blanc.
	poser.call("etal", Vector2(13.4, 6.6), deg_to_rad(-120.0), 3, {"toile": ["2e7d5b", "f1e6cc"]})
	poser.call("etal", Vector2(11.6, 8.0), deg_to_rad(-120.0), 5, {"toile": ["2e7d5b", "f1e6cc"]})
	# Les lampadaires à lanterne, au bord du tapis de brique.
	var poly := PackedVector2Array(t.PLACE_SAINT_GEORGES)
	var tour := 0.0
	for k in poly.size():
		tour += poly[k].distance_to(poly[(k + 1) % poly.size()])
	var pas := tour / 14.0
	var s := 0.0
	var j := 0
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		var l := a.distance_to(b)
		var u := (b - a) / l
		while s < l:
			var p := a + u * s + Vector2(u.y, -u.x) * -1.2
			poser.call("lampadaire", p, 0.0, j)
			j += 1
			s += pas
		s -= l
	# Les potelets de fonte le long de la rue qui borde la place à l'ouest.
	var w0 := Vector2(-6.6, -15.0)
	var w1 := Vector2(3.6, 15.8)
	for k in 22:
		var p := w0.lerp(w1, float(k) / 21.0)
		if absf(p.y) < 2.2:
			continue
		poser.call("borne", p + Vector2(1.0, 0.0), 0.0, k)
	# Les bancs autour du jardin, tournés vers les jeux, et des jardinières de bois fleuries.
	poser.call("banc", Vector2(6.8, -7.0), PI * 0.5, 1)
	poser.call("banc", Vector2(7.0, -2.6), PI * 0.5, 2)
	poser.call("banc", Vector2(13.0, 0.6), PI, 3)
	for p in [Vector2(-1.2, -10.4), Vector2(-0.6, -1.2), Vector2(4.6, 10.4), Vector2(14.0, -13.4), Vector2(18.4, 1.0)]:
		poser.call("jardiniere", p, 0.0, int(p.x * 10.0), {"longueur": 1.6})
	poser.call("corbeille", Vector2(6.0, -10.0), 0.0, 1)
	poser.call("corbeille", Vector2(9.0, 9.0), 0.0, 2)


## Le mobilier au mobilier toulousain : les grands parasols crème des terrasses du nord, les stores verts des
## Trois Platanes, les tables sous les arcades de Lafage, les chevalets des menus, les lanternes à six pans, les
## potelets de fonte, les bacs de bois fleuris. Le banc, la corbeille et l'étal restent lyonnais (la brique
## toulousaine ne les refait pas).
static func _mobilier_toulousain(t, racine: Node3D) -> void:
	var tou: Script = _brique("mobilier-toulousain@1", "objet.gd")
	var lyo: Script = _brique("mobilier-lyonnais@1", "objet.gd")
	var groupe := Node3D.new()
	groupe.name = "Mobilier"
	groupe.scale = Vector3.ONE / UNITE
	racine.add_child(groupe)
	var poser := func(nom: String, p: Vector2, lacet: float, graine: int, opt := {}) -> void:
		var n := Node3D.new()
		n.transform = Transform3D(Basis(Vector3.UP, lacet), Vector3(p.x, 0.0, p.y) * UNITE)
		groupe.add_child(n)
		if nom in ["banc", "corbeille", "etal"]:
			lyo.poser(n, Vector3.ZERO, nom, graine, opt)
		else:
			tou.poser(n, Vector3.ZERO, nom, graine, opt)
	var creme := ["f0e3c4", "f0e3c4"]
	# Les terrasses du nord, au soleil du soir : un rang de grands parasols crème, un rang de tables au pied
	# des façades, des parasols ronds bordeaux entre les deux.
	var g := 0
	for x in [1.0, 3.6, 6.2, 8.8, 11.4]:
		poser.call("grand_parasol", Vector2(x - 0.6, -13.4), 0.0, g, {"toile": creme})
		poser.call("terrasse", Vector2(x - 1.2, -15.9), 0.0, g + 1, {"tables": 2})
		if g % 4 == 0:
			poser.call("parasol", Vector2(x + 0.7, -11.6), 0.0, g + 2, {"toile": ["8a2a2e", "8a2a2e"]})
		g += 3
	for x in [2.2, 7.4]:
		poser.call("chevalet", Vector2(x, -12.0), 0.3, g)
		g += 1
	# Les Trois Platanes : trois stores verts et blancs le long de l'angle de la rue de la Pomme, des tables
	# serrées devant, le menu du jour sur l'ardoise.
	var vert := ["2f6a4a", "f3ead6"]
	for p in [Vector2(-2.9, -7.4), Vector2(-2.3, -5.0), Vector2(-1.7, -2.6)]:
		poser.call("store_terrasse", p, PI * 0.5 + 0.2, g, {"toile": vert})
		g += 1
	for p in [Vector2(-0.3, -6.4), Vector2(0.3, -4.0)]:
		poser.call("terrasse", p, PI * 0.5 + 0.2, g, {"tables": 2})
		g += 1
	poser.call("chevalet", Vector2(-0.6, -8.8), 1.2, g)
	g += 1
	# Sous les arcades de Lafage, côté place : les tables du restaurant de l'hôtel, deux parasols crème.
	# La façade de Lafage file du nord au sud ; les tables à 2,4 m devant elle, entre les arcades et le parterre.
	var le_long := func(z: float, recul: float) -> Vector2:
		var f := (z - LAFAGE_NORD.y) / (LAFAGE_SUD.y - LAFAGE_NORD.y)
		return Vector2(lerpf(LAFAGE_NORD.x, LAFAGE_SUD.x, f) - recul, z)
	var lacet := atan2(LAFAGE_SUD.x - LAFAGE_NORD.x, LAFAGE_SUD.y - LAFAGE_NORD.y) + PI * 0.5
	for z in [-13.0, -10.2, -7.4, -4.6, -1.8]:
		poser.call("terrasse", le_long.call(z, 1.0), lacet, g, {"tables": 3})
		g += 1
	poser.call("parasol", le_long.call(-11.6, 1.1), 0.0, g, {"toile": creme})
	poser.call("parasol", le_long.call(-3.2, 1.1), 0.0, g + 1, {"toile": creme})
	poser.call("chevalet", le_long.call(0.2, 1.2), lacet, g + 2)
	# Les deux étals au sud-est, sous leur store vert et blanc.
	poser.call("etal", Vector2(13.4, 6.6), deg_to_rad(-120.0), 3, {"toile": ["2e7d5b", "f1e6cc"]})
	poser.call("etal", Vector2(11.6, 8.0), deg_to_rad(-120.0), 5, {"toile": ["2e7d5b", "f1e6cc"]})
	# Les lanternes à six pans, au bord du tapis de brique, déjà allumées : le soir tombe.
	var poly := PackedVector2Array(t.PLACE_SAINT_GEORGES)
	var tour := 0.0
	for k in poly.size():
		tour += poly[k].distance_to(poly[(k + 1) % poly.size()])
	var pas := tour / 14.0
	var s := 0.0
	var j := 0
	for k in poly.size():
		var a := poly[k]
		var b := poly[(k + 1) % poly.size()]
		var l := a.distance_to(b)
		var u := (b - a) / l
		while s < l:
			poser.call("lampadaire", a + u * s + Vector2(u.y, -u.x) * -1.2, 0.0, j)
			j += 1
			s += pas
		s -= l
	# Les potelets de fonte le long de la rue qui borde la place à l'ouest, un appui-vélo à l'angle.
	var w0 := Vector2(-6.6, -15.0)
	var w1 := Vector2(3.6, 15.8)
	for k in 22:
		var p := w0.lerp(w1, float(k) / 21.0)
		if absf(p.y) < 2.2:
			continue
		poser.call("potelet", p + Vector2(1.0, 0.0), 0.0, k)
	poser.call("appui_velo", Vector2(-5.2, -11.6), PI * 0.5 - 0.3, 1, {"longueur": 4.0})
	# Les bancs autour du jardin, tournés vers les jeux, les bacs de bois fleuris, les corbeilles.
	poser.call("banc", Vector2(6.8, -7.0), PI * 0.5, 1)
	poser.call("banc", Vector2(7.0, -2.6), PI * 0.5, 2)
	poser.call("banc", Vector2(13.0, 0.6), PI, 3)
	for p in [Vector2(-1.2, -10.4), Vector2(-0.6, -1.2), Vector2(4.6, 10.4), Vector2(14.0, -13.4), Vector2(18.4, 1.0)]:
		poser.call("bac_bois", p, 0.0, int(p.x * 10.0), {"longueur": 1.8})
	poser.call("corbeille", Vector2(6.0, -10.0), 0.0, 1)
	poser.call("corbeille", Vector2(9.0, 9.0), 0.0, 2)


# --- La vie -----------------------------------------------------------------------------------------

## La situation du jour (note : « La vie ») : un soir de finale, on attend le coup d'envoi en terrasse. Des
## groupes debout devant les Trois Platanes, des promeneurs qui traversent la place d'une rue à l'autre, un
## livreur qui va de la rue de la Pomme au primeur, des parents au bord du jardin d'enfants.
static func _vie(racine: Node3D) -> void:
	var groupe := Node3D.new()
	groupe.name = "Habitants"
	racine.add_child(groupe)
	var g := 31555
	# Devant le café de courses : trois groupes qui parlent du match, tournés les uns vers les autres.
	for centre in [Vector2(-1.6, -9.6), Vector2(1.2, -2.2), Vector2(-3.4, -1.6)]:
		for k in 3:
			var a: float = TAU * k / 3.0 + centre.x
			var f: Node3D = Atelier.figurant(g, "idle")
			f.position = Vector3(centre.x + cos(a) * 0.45, 0.0, centre.y + sin(a) * 0.45)
			f.rotation.y = atan2(-cos(a), -sin(a))
			groupe.add_child(f)
			g += 1
	# Au bord du jardin d'enfants, deux parents qui regardent les jeux.
	for p in [Vector2(8.2, -9.6), Vector2(8.8, -9.9)]:
		var f: Node3D = Atelier.figurant(g, "idle")
		f.position = Vector3(p.x, 0.0, p.y)
		f.rotation.y = PI * 0.75
		groupe.add_child(f)
		g += 1
	# Les promeneurs : d'une rue à l'autre, en traversant sous les platanes.
	var routes := [
		[Vector3(-12.0, 0, -0.8), Vector3(-4.0, 0, -0.5), Vector3(6.0, 0, 3.0), Vector3(10.0, 0, 10.0), Vector3(6.0, 0, 19.0)],
		[Vector3(-8.0, 0, -17.0), Vector3(-5.0, 0, -9.0), Vector3(2.0, 0, -12.0), Vector3(12.0, 0, -16.0)],
		[Vector3(5.0, 0, 18.0), Vector3(4.0, 0, 8.0), Vector3(-2.0, 0, -6.0), Vector3(-7.0, 0, -16.0)],
		[Vector3(18.0, 0, 2.0), Vector3(12.0, 0, 4.0), Vector3(2.0, 0, 2.0), Vector3(-6.0, 0, -0.6), Vector3(-14.0, 0, -1.0)],
		[Vector3(14.0, 0, -12.0), Vector3(4.0, 0, -11.0), Vector3(-1.0, 0, -4.0), Vector3(1.0, 0, 6.0), Vector3(12.0, 0, 8.0)],
		[Vector3(-14.0, 0, -1.2), Vector3(-2.0, 0, 0.0), Vector3(11.5, 0, 6.0)],
	]
	for k in routes.size():
		var route: Array[Vector3] = []
		route.assign(routes[k])
		var f: Node3D = Atelier.figurant(g, "walk", "village", route)
		f.position = route[0]
		groupe.add_child(f)
		g += 1


# --- La fonte des maillages -----------------------------------------------------------------------

## Fond les maillages d'un groupe en un maillage par matériau et par case de 12 unités (assez gros pour peu de
## surfaces dessinées, assez petit pour que le moteur en écarte une partie hors du champ), en gardant leurs
## corps de collision.
static func _fondre(racine: Node3D, nom: String) -> void:
	var groupe: Node3D = racine.get_node_or_null(nom)
	if groupe == null:
		return
	var cases := {}
	for mi in groupe.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var t := _relatif(m, racine)
		var c := t.origin
		var cle := Vector2i(int(floor(c.x / 12.0)), int(floor(c.z / 12.0)))
		if not cases.has(cle):
			cases[cle] = {}
		for s in m.mesh.get_surface_count():
			var mat: Material = m.get_active_material(s)
			if not cases[cle].has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				cases[cle][mat] = st
			cases[cle][mat].append_from(m.mesh, s, t)
	for cle in cases:
		var mesh := ArrayMesh.new()
		for mat in cases[cle]:
			cases[cle][mat].commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
		var mi := MeshInstance3D.new()
		mi.name = "%s_%d_%d" % [nom, cle.x, cle.y]
		mi.mesh = mesh
		racine.add_child(mi)
	for mi in groupe.find_children("*", "MeshInstance3D", true, false):
		mi.get_parent().remove_child(mi)
		mi.free()


static func _relatif(n: Node3D, racine: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var x: Node = n
	while x != null and x != racine:
		if x is Node3D:
			t = (x as Node3D).transform * t
		x = x.get_parent()
	return t
