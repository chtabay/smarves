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
	"notaire": ["PorteNotaire", "L'étude de Maître Escudier, notaire"],
	"chemiserie": ["PorteChemiserie", "La Chemiserie Saint-Georges"],
	"change": ["PorteChange", "La charge d'Estrade et Fils, agent de change"],
	"maison_violette": ["PorteMaisonViolette", "4, place Saint-Georges"],
	"maison_pomme": ["PorteMaisonPomme", "12, rue de la Pomme"],
}
## Les intérieurs du socle sur la place (Guillaume, 30 octobre) : l'étude du notaire au nord, la chemiserie au
## sud-est, la charge d'agent de change à l'ouest. Le point du plan dont la façade la plus proche porte la porte,
## et le rez-de-chaussée qu'on donne à cette façade.
const ENTREES := {
	"notaire": [Vector2(4.0, -16.6), {"rdc": "porche", "enduit": "creme"}],
	"chemiserie": [Vector2(13.5, 9.9), {"rdc": "commerce", "enseigne": "CHEMISERIE SAINT-GEORGES", "toile": ["1d3b6e", "f1e6cc"]}],
	"change": [Vector2(0.24, 9.09), {"rdc": "commerce", "enseigne": "ESTRADE & FILS · CHANGE", "toile": ["2b2b2b", "c9a45c"]}],
	"maison_violette": [Vector2(-9.1, -10.6), {"rdc": "logis"}],
	"maison_pomme": [Vector2(-13.5, -2.2), {"rdc": "logis"}],
}
## Les logements du registre du notaire qui ont leur porte sur la place ou dans la rue de la Pomme.
const LOGEMENTS := ["maison_violette", "maison_pomme"]
## Les portes des salles de jeu, qui disent leur seuil tant qu'elles sont fermées.
const SALLES := ["trois_platanes", "violette"]
const PERSIENNES := ["9daa92", "e7ddc4", "8c9daa", "b9b2a0"]
const TOILES := [["8c2f39", "f1e6cc"], ["f1e6cc", "f1e6cc"], ["2e7d5b", "f1e6cc"], ["8c2f39", "8c2f39"]]
## Les enseignes des cafés et des restaurants de la place : des maisons inventées (aucune enseigne réelle).
## Les deux petits kiosques du plan au nord-ouest de la place (bâtiments 1166 et 1167) : ils tombent dans la rue
## et n'existent plus (Guillaume, 29 octobre : « le bar du Tournesol est à supprimer »). Ni façade ni volume.
const FANTOMES := [1166, 1167]
## Les parterres de la place, relevés dans OpenStreetMap (landuse=flowerbed, murets) : on circule tout autour, à
## quatre ou cinq mètres des façades, et l'axe de la rue Saint-Antoine-du-T à la rue Boulbonne traverse la place
## entre eux (Guillaume, 30 octobre). L'ouest le long de la rue, le grand L du nord, l'est le long de la rue,
## la virgule de l'est, la bande du milieu, le grand L du sud-est. Un muret bas de pierre claire, la terre plantée
## juste sous son rebord, et les platanes dedans.
const TERRE_PLEINS := [
	[Vector2(-0.14, -0.8), Vector2(1.55, -1.53), Vector2(-1.8, -9.36), Vector2(-2.7, -9.47), Vector2(-3.33, -8.76)],
	[Vector2(11.0, -8.84), Vector2(11.57, -7.62), Vector2(13.17, -8.33), Vector2(10.29, -15.36), Vector2(0.24, -13.36), Vector2(1.67, -10.2), Vector2(2.83, -10.68), Vector2(2.03, -12.56), Vector2(9.25, -13.84), Vector2(11.39, -9.0)],
	[Vector2(0.41, 0.97), Vector2(2.1, 0.24), Vector2(5.21, 8.29), Vector2(4.74, 9.03), Vector2(3.56, 8.88)],
	[Vector2(9.42, 4.66), Vector2(8.32, 5.19), Vector2(7.28, 2.72), Vector2(9.2, 1.7), Vector2(10.28, 0.41), Vector2(10.8, -0.65), Vector2(11.16, -1.77), Vector2(12.45, -2.33), Vector2(13.0, -1.11), Vector2(12.19, -0.76), Vector2(11.85, 0.27), Vector2(11.37, 1.18), Vector2(10.47, 2.36), Vector2(8.92, 3.47)],
	[Vector2(3.12, -10.03), Vector2(1.99, -9.5), Vector2(3.22, -6.8), Vector2(5.28, -7.5), Vector2(6.96, -7.42), Vector2(8.1, -7.08), Vector2(9.06, -6.52), Vector2(10.63, -7.21), Vector2(10.05, -8.42), Vector2(9.13, -8.02), Vector2(8.13, -8.47), Vector2(6.93, -8.82), Vector2(5.37, -8.88), Vector2(3.79, -8.51)],
	[Vector2(13.71, -2.88), Vector2(15.17, -3.53), Vector2(18.39, 3.38), Vector2(10.07, 9.36), Vector2(8.65, 5.98), Vector2(9.77, 5.4), Vector2(10.7, 7.51), Vector2(16.56, 3.11), Vector2(14.46, -1.75), Vector2(14.23, -1.65)],
]
## Les platanes des parterres, aux arbres d'OpenStreetMap ; sans celui qui cachait le fronton de l'hôtel de Lafage
## (Guillaume, 30 octobre : « son centre est à pouvoir contempler »).
const PLATANES_DES_TERRE_PLEINS := [Vector2(1.72, 1.49), Vector2(2.75, 4.04), Vector2(4.19, 7.59), Vector2(10.53, 8.06), Vector2(13.12, 6.67), Vector2(14.75, 5.42), Vector2(16.5, 4.16), Vector2(18.0, 3.09), Vector2(16.6, 0.37), Vector2(11.61, -10.86), Vector2(11.24, -13.08), Vector2(10.1, -15.34), Vector2(7.99, -15.09), Vector2(5.55, -14.41), Vector2(3.45, -13.95), Vector2(0.8, -13.14), Vector2(-1.92, -7.5), Vector2(0.03, -2.67)]
## La hauteur de la terre des terre-pleins, en mètres : un bac planté, juste sous le rebord du muret (60 cm).
const PELOUSE := 0.45
## Le jardin d'enfants, dans l'aire de jeux réelle (OpenStreetMap, leisure=playground) : entre les bras du grand L
## du nord et la bande du milieu. Son centre en unités, portillon au sud. Il fait 9 m sur 7.
const JARDIN := Vector2(6.5, -11.3)
const JARDIN_DEMI := Vector2(1.95, 1.5)
const ENSEIGNES := ["CAFÉ DES CAPITOULS", "LE PASTEL", "BAR DE LA BRIQUE", "AU CASSOULET", "LA VIOLETTE", "BAR DES ARCADES", "CHEZ PEYROLLES", "LE TOURNESOL", "LA GARONNETTE", "CAFÉ DU MIDI"]


static func _brique(ref: String, fichier: String) -> Script:
	return load(Bibliotheque.scene(ref, "decor").get_base_dir() + "/" + fichier)


## Jusqu'où, autour de la place, les fronts sont composés : tout le périmètre de la carte (12,5 unités, 30 m) ;
## au-delà, les îlots en volumes ferment les rues.
const ABORDS := 12.5


## Les bâtiments dont la place compose les fronts : ceux qui ont un mur sur la rue aux abords de la place.
## Rend {indice: [murs sur la rue, chacun [a, c]]}.
static func batiments_composes(t) -> Dictionary:
	var r := {}
	var abords: PackedVector2Array = Geometry2D.offset_polygon(PackedVector2Array(t.PLACE_SAINT_GEORGES), ABORDS)[0]
	for b in t.data.batiments:
		if FANTOMES.has(int(b.i)):
			continue
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
	_terre_pleins(racine)
	_platanes(t, racine)
	_jardin(t, racine)
	_mobilier(t, racine)
	_taxi(racine)
	_vie(racine)
	_fondre(racine, "Facades")
	_fondre(racine, "Mobilier")
	# la fonte perd les réglages d'instance des arbres : on rend le jour du cœur de la voûte au maillage fondu
	# (verdict du juge sur la v0.8, la voûte vue d'en bas reste trop sombre).
	_fondre(racine, "Platanes", {"jour": 1.4, "ajour": 0.75})
	_fondre(racine, "Bacs")


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
	var murs_entrees := {}
	for id in ENTREES:
		murs_entrees[id] = _mur_le_plus_proche(sans_lafage, ENTREES[id][0])
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
				else:
					for id in ENTREES:
						if not portes.has(id) and murs_entrees[id] == [i, m] and k == morceaux / 2:
							var facade: Dictionary = ENTREES[id][1]
							if facade.has("enduit"):
								opt.erase("brique")
							opt.merge(facade, true)
							if facade.rdc == "porche" and w > 9.0:
								type = "hotel"
							portes[id] = [milieu, dehors]
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


## Le seuil de chaque porte posée, où le mobilier ne vient pas.
static var portes_posees: Array[Vector2] = []


## Les portes de la place (salles de jeu, étude, chemiserie, charge) : le nœud qui place la structure (manifeste, « noeud »), tourné vers la place,
## et la zone où l'on appuie sur E. Fermée, la porte dit le seuil.
static func _portes(t, portes: Dictionary) -> void:
	portes_posees.clear()
	for id in portes:
		var milieu: Vector2 = portes[id][0]
		var dehors: Vector2 = portes[id][1]
		var q := milieu + dehors * 0.35
		portes_posees.append(q + dehors * 0.6)
		var repere := Node3D.new()
		repere.name = PORTES[id][0]
		repere.transform = Transform3D(Basis(Vector3.UP, atan2(dehors.x, dehors.y)), Vector3(q.x, 0.05, q.y))
		t.add_child(repere)
		var zone := Area3D.new()
		zone.name = "Zone"
		zone.position = Vector3(0, 0.6, 0)
		zone.set_meta("interact", id)
		var invite: String = PORTES[id][1]
		if id in SALLES and not SalleJeu.ouverte("toulouse", id):
			invite += " · ouvre à %s crédits gagnés au jeu" % Game.fmt(SalleJeu.seuil("toulouse", id))
		elif id in LOGEMENTS:
			invite += " · chez soi" if Biens.logements.has("toulouse/" + id) else " · à vendre chez Maître Escudier"
		zone.set_meta("prompt", invite)
		var f := CollisionShape3D.new()
		var forme := BoxShape3D.new()
		forme.size = Vector3(1.4, 1.2, 0.6)
		f.shape = forme
		zone.add_child(f)
		repere.add_child(zone)
		if id == "notaire":
			_panonceau(repere)


## Le panonceau du notaire, à droite de la porte : l'ovale noir bordé d'or, « NOTAIRE », lisible de la place
## (juge, v0.30 : sans lui on ne sait pas que c'est un notaire).
static func _panonceau(repere: Node3D) -> void:
	var u := 1.0 / UNITE
	var p := Node3D.new()
	p.position = Vector3(1.0, 1.75 * u, -0.3)
	repere.add_child(p)
	var or_ := StandardMaterial3D.new()
	or_.albedo_color = Color("c9a45c")
	or_.metallic = 0.6
	or_.roughness = 0.35
	var noir := StandardMaterial3D.new()
	noir.albedo_color = Color("141414")
	for k in 2:
		var mi := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = (0.27 if k == 0 else 0.24) * u
		c.bottom_radius = c.top_radius
		c.height = 0.03 * u
		c.material = or_ if k == 0 else noir
		mi.mesh = c
		mi.rotation.x = PI * 0.5
		mi.scale = Vector3(1.0, 1.0, 0.72)
		mi.position.z = k * 0.012 * u
		p.add_child(mi)
	var l := Label3D.new()
	l.text = "NOTAIRE"
	l.font = Polices.texte()
	l.font_size = 48
	l.pixel_size = 0.0018
	l.modulate = Color("e3c172")
	l.outline_size = 0
	l.position.z = 0.04 * u
	p.add_child(l)


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
## seule brique pour une essence). Ceux de la place sont posés un à un dans les parterres ; les autres, dans les cours et les rues, en trois modèles répétés.
static func _platanes(t, racine: Node3D) -> void:
	var veg: Script = _brique("vegetation-lyonnaise@1", "plante.gd")
	var groupe := Node3D.new()
	groupe.name = "Platanes"
	racine.add_child(groupe)
	var place := Geometry2D.offset_polygon(PackedVector2Array(t.PLACE_SAINT_GEORGES), 2.0)[0]
	var loin := []
	var ombriere: Script = _brique("arbres-d-ombriere@1", "arbre.gd") if _toulousain("arbres-d-ombriere@1") else null
	var clair := ShaderMaterial.new()
	clair.shader = load(t.DOSSIER + "feuillage.gdshader")
	for k in t.data.arbres.size():
		var a: Array = t.data.arbres[k]
		var p := Vector2(a[0], a[1])
		if Geometry2D.is_point_in_polygon(p, place):
			# Les platanes de la place sont tous dans les parterres (PLATANES_DES_TERRE_PLEINS).
			continue
		if t.batiment_en(p).is_empty() and Geometry2D.is_point_in_polygon(p, t.perimetre):
			loin.append(p)
	# Les platanes des terre-pleins, le pied dans la pelouse.
	for k in PLATANES_DES_TERRE_PLEINS.size():
		var p: Vector2 = PLATANES_DES_TERRE_PLEINS[k]
		var porteur := Node3D.new()
		porteur.transform = Transform3D(Basis(Vector3.UP, k * 2.3).scaled(Vector3.ONE / UNITE), Vector3(p.x, PELOUSE / UNITE, p.y))
		groupe.add_child(porteur)
		if ombriere != null:
			ombriere.pousser(porteur, Vector3.ZERO, "platane", 700 + k, {"hauteur": 15.5 + (k % 3) * 0.5})
		else:
			veg.pousser(porteur, Vector3.ZERO, "platane", 700 + k, {"hauteur": 19.0 + (k % 3) * 0.9})
			_eclaircir(porteur, clair)
	# Les arbres du périmètre hors de la place : trois jeunes platanes modèles, en multimaillages par cases de
	# 30 m, que le socle remplace au loin par leurs images (Lointain.imposteurs).
	var modeles := []
	for m in 3:
		var n := Node3D.new()
		if ombriere != null:
			ombriere.pousser(n, Vector3.ZERO, "jeune_platane", 900 + m, {"densite": 0.8})
		else:
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


## Vrai si le point est hors des terre-pleins et du jardin d'enfants, à `marge` unités près.
static func _libre(p: Vector2, marge := 0.4) -> bool:
	for q in portes_posees:
		if p.distance_to(q) < 1.3:
			return false
	if absf(p.x - JARDIN.x) < JARDIN_DEMI.x + marge and absf(p.y - JARDIN.y) < JARDIN_DEMI.y + marge:
		return false
	for tp in TERRE_PLEINS:
		if Geometry2D.is_point_in_polygon(p, Geometry2D.offset_polygon(PackedVector2Array(tp), marge)[0]):
			return false
	return true


## Remplace le feuillage de la brique par le feuillage clair de la place (même couleur par sommet, même vent).
static func _eclaircir(n: Node, clair: ShaderMaterial) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var mat := m.get_active_material(s) as ShaderMaterial
			if mat != null and mat.shader != null and mat.shader.resource_path.ends_with("feuillage.gdshader"):
				m.set_surface_override_material(s, clair)


# --- Le jardin d'enfants --------------------------------------------------------------------------

## Le jardin d'enfants (au mobilier toulousain, dans l'aire de jeux du nord-ouest ; sinon, au lyonnais, sur le
## square Jean-Calas du plan, au nord-est) : un muret de pierre à grille de fonte, un sol de sable, un
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
		# Le jardin d'enfants toulousain (muret de brique, grille, portique, toboggan) dans l'aire de jeux réelle,
		# au nord, entre les deux bras du L ; son portillon vers la place, au sud.
		var porteur := Node3D.new()
		porteur.name = "Jardin"
		porteur.transform = Transform3D(Basis().scaled(Vector3.ONE / UNITE), Vector3(JARDIN.x, 0.0, JARDIN.y))
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


## Les terre-pleins de la place (photos et vue aérienne de Guillaume, 29 octobre) : une pelouse cernée d'un
## muret bas de pierre claire, 60 cm à chaperon. Une disposition propre à la place, faite comme le sol, avec les
## outils du mobilier lyonnais.
static func _terre_pleins(racine: Node3D) -> void:
	var groupe := Node3D.new()
	groupe.name = "Bacs"
	racine.add_child(groupe)
	if _toulousain("mobilier-toulousain@1") and _brique("mobilier-toulousain@1", "objet.gd").OBJETS.has("bac_vegetal"):
		# Le bac végétal de la bibliothèque (verdict du juge sur la v0.6) : le muret de brique foraine à joints, la
		# couvertine de pierre, la terre sous le rebord et un massif dense, sur le contour relevé de chaque bac.
		var tou: Script = _brique("mobilier-toulousain@1", "objet.gd")
		var fleurs := ["b65a4f", "e6dfcd", "8a72a3", "c9a457", "e6dfcd", "b65a4f", "8a72a3", "c9a457"]
		for k in TERRE_PLEINS.size():
			var poly := PackedVector2Array(TERRE_PLEINS[k])
			var cadre := Rect2(poly[0], Vector2.ZERO)
			for q in poly:
				cadre = cadre.expand(q)
			var centre := cadre.get_center()
			var points := []
			for q in poly:
				points.append((q - centre) * UNITE)
			var porteur := Node3D.new()
			porteur.transform = Transform3D(Basis().scaled(Vector3.ONE / UNITE), Vector3(centre.x, 0.0, centre.y))
			groupe.add_child(porteur)
			tou.poser(porteur, Vector3.ZERO, "bac_vegetal", 4507 + k * 31, {"forme": "polygone", "points": points,
				"hauteur": 0.6, "terre": 0.6 - PELOUSE, "plantation": "dense", "fleurs": fleurs[k % fleurs.size()]})
		# Le bac de la bibliothèque est planté en massif dense (plantation dense, semée selon son aire réelle) ; les
		# taches de fleurs par espèce s'y ajoutent, plus espacées.
		var veg_buis: Script = _brique("vegetation-lyonnaise@1", "plante.gd")
		for k in TERRE_PLEINS.size():
			_semer(PackedVector2Array(TERRE_PLEINS[k]), veg_buis, groupe, k, 1.05, 0.6)
		return
	var o = _brique("mobilier-lyonnais@1", "outils.gd").new(1762)
	var veg: Script = _brique("vegetation-lyonnaise@1", "plante.gd")
	for k in TERRE_PLEINS.size():
		_parterre(o, PackedVector2Array(TERRE_PLEINS[k]), veg, groupe, k)
	var porteur := Node3D.new()
	porteur.name = "TerrePleins"
	porteur.scale = Vector3.ONE / UNITE
	racine.add_child(porteur)
	o.construire(porteur, "TerrePleins")


## Les arbustes fleuris d'un bac, tous les `pas` unités, sauf au pied des platanes ; `petit` (0 à 1) les tasse.
static func _semer(poly: PackedVector2Array, veg: Script, plantes: Node3D, k: int, pas: float, petit: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 4507 + k * 31
	var dedans: PackedVector2Array = Geometry2D.offset_polygon(poly, -0.28)[0]
	var cadre := Rect2(poly[0], Vector2.ZERO)
	for q in poly:
		cadre = cadre.expand(q)
	var y := cadre.position.y + pas * 0.5
	var rang := 0
	while y < cadre.end.y:
		var x := cadre.position.x + pas * (0.25 + 0.5 * (rang % 2))
		while x < cadre.end.x:
			var q := Vector2(x, y) + Vector2(r.randf_range(-0.15, 0.15), r.randf_range(-0.15, 0.15))
			x += pas
			if not Geometry2D.is_point_in_polygon(q, dedans):
				continue
			var pres := false
			for t in PLATANES_DES_TERRE_PLEINS:
				if q.distance_to(t) < 0.45:
					pres = true
			if pres:
				continue
			var n := Node3D.new()
			n.transform = Transform3D(Basis(Vector3.UP, r.randf() * TAU).scaled(Vector3.ONE / UNITE), Vector3(q.x, PELOUSE / UNITE, q.y))
			plantes.add_child(n)
			var opt := {"hauteur": r.randf_range(0.7, 1.15) * (1.0 - petit * 0.3), "vent": 0.3}
			# Les fleurs en taches d'une espèce (verdict du juge sur la v0.5), de 3 à 4 m, aux tons sourds.
			var tache := Vector2i(floor(q.x / 1.5), floor(q.y / 1.5))
			opt["fleurs"] = ["b65a4f", "e6dfcd", "8a72a3", "c9a457", "e6dfcd"][absi(tache.x * 7 + tache.y * 13 + k) % 5]
			veg.pousser(n, Vector3.ZERO, "buisson", k * 997 + rang * 31 + int(x * 10.0), opt)
		y += pas * 0.87
		rang += 1


## Un bac planté (verdict du juge sur la v0.4) : un massif dense d'arbustes et de fleurs qui dépassent le rebord,
## la terre visible entre eux ; le muret de brique foraine sous une couvertine de pierre claire à arête vive.
static func _parterre(o, poly: PackedVector2Array, veg: Script, plantes: Node3D, k: int) -> void:
	var terre := Color("5d6b34")
	var tri := Geometry2D.triangulate_polygon(poly)
	for i in range(0, tri.size(), 3):
		var a := Vector3(poly[tri[i]].x * UNITE, PELOUSE, poly[tri[i]].y * UNITE)
		var b := Vector3(poly[tri[i + 1]].x * UNITE, PELOUSE, poly[tri[i + 1]].y * UNITE)
		var d := Vector3(poly[tri[i + 2]].x * UNITE, PELOUSE, poly[tri[i + 2]].y * UNITE)
		o.tri(a, b, d, Vector3.UP, terre.lightened(0.04 * (i % 3)))
	_semer(poly, veg, plantes, k, 0.62, 0.0)
	var brique := Color("a2624a")
	var pierre := Color("d9cdb6")
	for i in poly.size():
		var a := poly[i] * UNITE
		var b := poly[(i + 1) % poly.size()] * UNITE
		var l := a.distance_to(b)
		if l < 0.05:
			continue
		var u := (b - a) / l
		var c := (a + b) * 0.5
		var bas := Basis(Vector3.UP, atan2(-u.y, u.x))
		o.boite(Transform3D(bas, Vector3(c.x, 0.27, c.y)), Vector3(l + 0.22, 0.54, 0.22), brique.lightened(0.04 * (i % 3) - 0.02), 0, true)
		# Les rangs de brique : un joint clair tous les 11 cm, sur les deux faces.
		for h in [0.11, 0.22, 0.33, 0.44]:
			o.boite(Transform3D(bas, Vector3(c.x, h, c.y)), Vector3(l + 0.2, 0.014, 0.228), Color("c9b9a0"))
		o.boite(Transform3D(bas, Vector3(c.x, 0.59, c.y)), Vector3(l + 0.27, 0.1, 0.27), pierre)


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
		if not _libre(p):
			return
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
	var bug: Script = _brique("vegetation-du-bugey@1", "plante.gd") if _toulousain("vegetation-du-bugey@1") else null
	var groupe := Node3D.new()
	groupe.name = "Mobilier"
	groupe.scale = Vector3.ONE / UNITE
	racine.add_child(groupe)
	var poser := func(nom: String, p: Vector2, lacet: float, graine: int, opt := {}) -> void:
		if not _libre(p):
			return
		var n := Node3D.new()
		n.transform = Transform3D(Basis(Vector3.UP, lacet), Vector3(p.x, 0.0, p.y) * UNITE)
		groupe.add_child(n)
		if nom in ["corbeille", "etal"] or (nom == "banc" and not tou.OBJETS.has("banc")):
			lyo.poser(n, Vector3.ZERO, nom, graine, opt)
		elif nom == "fleurs" and bug != null:
			bug.pousser(n, Vector3.ZERO, nom, graine, opt)
		elif nom == "fleurs":
			tou.poser(n, Vector3.ZERO, "bac_bois", graine, {"longueur": 0.9})
		else:
			tou.poser(n, Vector3.ZERO, nom, graine, opt)
			if TABLES.has(nom):
				_affiner(n, nom, opt)
	var creme := ["f0e3c4", "f0e3c4"]
	# Les terrasses du nord, au soleil du soir : deux rangs de tables au pied des façades, là seulement où le
	# passage entre elles et le parterre garde ses cinq mètres (Guillaume, 30 octobre : les tables dans le passage).
	var g := 0
	for x in [-0.4, 1.7]:
		poser.call("terrasse", Vector2(x, -16.0), 0.0, g, {"tables": 2, "clients": 2})
		g += 1
	poser.call("chevalet", Vector2(4.9, -16.2), 0.3, g)
	poser.call("chevalet", Vector2(9.6, -16.6), -0.2, g + 1)
	g += 2
	# Les Trois Platanes : trois stores verts et blancs le long de l'angle de la rue de la Pomme, des tables
	# serrées devant, le menu du jour sur l'ardoise.
	var vert := ["2f6a4a", "f3ead6"]
	for p in [Vector2(-3.5, -7.4), Vector2(-2.9, -5.0), Vector2(-2.3, -2.6)]:
		# des habitués sous les stores (juge, revue finale : la seule terrasse vide de la place)
		poser.call("store_terrasse", p, PI * 0.5 + 0.2, g, {"toile": vert, "clients": 3})
		g += 1
	poser.call("chevalet", Vector2(-4.4, -9.0), 1.2, g)
	g += 1
	# La terrasse de l'ouest, au nord du parterre de la rue, hors de l'entrée de la rue Saint-Antoine-du-T et du
	# passage entre les parterres (Guillaume, 30 octobre) : trois grands parasols crème et bordeaux.
	var n_table := 0
	for p in [Vector2(-2.9, -14.6), Vector2(-1.2, -12.0)]:
		poser.call("grand_parasol", p, 0.3, g, {"toile": creme if n_table != 1 else ["8a2a2e", "8a2a2e"]})
		g += 1
		n_table += 1
	# La terrasse du sud-ouest, au premier plan de la vue de la cible, entre le bac du sud-ouest et la rue :
	# deux rangs parallèles à la rue, une vingtaine de tables (verdict du juge sur la v0.7).
	var rue_sw := (Vector2(4.4, 16.8) - Vector2(0.2, 7.6)).normalized()
	var vers_place := Vector2(rue_sw.y, -rue_sw.x)
	# un seul rang, le long de la rue : le passage entre la terrasse et le parterre reste libre (Guillaume, 30 octobre)
	for rang in 1:
		# sans la première table, devant la porte de la charge d'agent de change
		for i in range(1, 5):
			var p: Vector2 = Vector2(0.2, 7.6) + rue_sw * (1.4 + i * 1.6) + vers_place * (1.4 + rang * 1.25)
			# un client sur une table sur trois (verdict du juge sur la v0.8a)
			poser.call("terrasse", p, -0.45, g, {"tables": 2, "clients": 1 if (rang * 5 + i) % 3 != 2 else 0})
			# des parasols ronds et des grands parasols mêlés, crème et bordeaux sur un rythme irrégulier
			var k := rang * 5 + i
			if k in [0, 2, 3, 6, 8, 9]:
				var toile = ["8a2a2e", "8a2a2e"] if k in [2, 6, 9] else creme
				poser.call("grand_parasol" if k in [3, 8] else "parasol", p + rue_sw * 0.15, 0.0, g + 1, {"toile": toile})
			g += 2
	# Une file de potelets de fonte tous les 2,5 m le long de la rue du sud-ouest, côté place (la cible).
	var rue := [Vector2(-4.6, 1.2), Vector2(0.2, 7.6), Vector2(4.4, 16.8)]
	for k in rue.size() - 1:
		var a: Vector2 = rue[k]
		var b: Vector2 = rue[k + 1]
		var n := int(a.distance_to(b) * UNITE / 2.5)
		for i in n:
			poser.call("potelet", a.lerp(b, (i + 0.5) / n), 0.0, 900 + k * 50 + i)
	# Sous les arcades de Lafage, côté place : les tables du restaurant de l'hôtel, deux parasols crème.
	# La façade de Lafage file du nord au sud ; les tables à 2,4 m devant elle, entre les arcades et le parterre.
	var le_long := func(z: float, recul: float) -> Vector2:
		var f := (z - LAFAGE_NORD.y) / (LAFAGE_SUD.y - LAFAGE_NORD.y)
		return Vector2(lerpf(LAFAGE_NORD.x, LAFAGE_SUD.x, f) - recul, z)
	var lacet := atan2(LAFAGE_SUD.x - LAFAGE_NORD.x, LAFAGE_SUD.y - LAFAGE_NORD.y) + PI * 0.5
	for z in [-13.0, -10.2, -7.4, -4.6, -1.8]:
		poser.call("terrasse", le_long.call(z, 1.0), lacet, g, {"tables": 3, "clients": 2})
		g += 1
	poser.call("parasol", le_long.call(-11.6, 1.1), 0.0, g, {"toile": creme})
	poser.call("parasol", le_long.call(-3.2, 1.1), 0.0, g + 1, {"toile": creme})
	poser.call("chevalet", le_long.call(0.2, 1.2), lacet, g + 2)
	# Les deux étals au sud-est, sous leur store vert et blanc.
	poser.call("etal", Vector2(13.4, 6.6), deg_to_rad(-120.0), 3, {"toile": ["2e7d5b", "f1e6cc"]})
	poser.call("etal", Vector2(11.6, 8.0), deg_to_rad(-120.0), 5, {"toile": ["2e7d5b", "f1e6cc"]})
	# Les lanternes à six pans, au bord du tapis de brique, éteintes : il fait encore grand jour (Guillaume,
	# 29 octobre : pas d'éclats).
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
			poser.call("lampadaire", a + u * s + Vector2(u.y, -u.x) * -1.2, 0.0, j, {"allume": false, "branches": 2})
			j += 1
			s += pas
		s -= l
	# Les bornes de fonte tout le long du filet blanc, une tous les 2,2 m, sauf devant Lafage et là où le
	# trottoir manque ; un pot de fleurs toutes les cinq bornes (image cible de Guillaume).
	var lafage := PackedVector2Array([LAFAGE_SUD, LAFAGE_NORD])
	var b_idx := 0
	var bord: PackedVector2Array = Geometry2D.offset_polygon(PackedVector2Array(t.PLACE_SAINT_GEORGES), 0.45)[0]
	for k in bord.size():
		var a := bord[k]
		var b := bord[(k + 1) % bord.size()]
		var l := a.distance_to(b)
		var u := (b - a) / l
		var n := int(l / 0.92)
		for i in n:
			var q := a + u * (i + 0.5) * l / n
			if Geometry2D.get_closest_point_to_segment(q, lafage[0], lafage[1]).distance_to(q) < 2.6:
				continue
			if not t.batiment_en(q).is_empty() or not t.batiment_en(q + Vector2(u.y, -u.x) * 0.8).is_empty():
				continue
			if b_idx % 5 == 2:
				poser.call("fleurs", q, 0.0, b_idx)
			else:
				poser.call("potelet", q, 0.0, b_idx)
			b_idx += 1
	poser.call("appui_velo", Vector2(-5.2, -11.6), PI * 0.5 - 0.3, 1, {"longueur": 4.0})
	# Des pots de fleurs aux deux bouts de chaque terrasse et au pied des lanternes, des massifs fleuris le long du
	# muret du parterre.
	for p in [Vector2(-1.6, -16.2), Vector2(12.6, -16.6), Vector2(-3.6, -9.0), Vector2(15.4, -14.6), Vector2(18.8, -0.6), Vector2(10.4, -12.0)]:
		poser.call("fleurs", p, 0.0, int(p.x * 7.0 + p.y))
	# Les bancs au bord des terre-pleins, les bacs de bois fleuris, les corbeilles.
	# deux voisins assis sur le banc de l'allée, un lecteur sur celui du sud (juge, v0.12 : la vie de la cible)
	poser.call("banc", Vector2(6.8, -7.0), PI * 0.5, 1, {"assis": 2})
	poser.call("banc", Vector2(7.0, -2.6), PI * 0.5, 2, {"assis": 1})
	poser.call("banc", Vector2(13.0, 0.6), PI, 3)
	# La double rangée de bornes de pierre le long de l'allée qui file vers Lafage : elles rythment le sol de la
	# cible (juge, v0.12).
	if tou.OBJETS.has("borne"):
		for z in [-8.3, -4.7]:
			for i in 6:
				poser.call("borne", Vector2(8.6 + i * 1.3, z), 0.0, 700 + i + int(z))
	for p in [Vector2(4.6, 10.4), Vector2(14.0, -13.4), Vector2(18.4, 1.0)]:
		poser.call("bac_bois", p, 0.0, int(p.x * 10.0), {"longueur": 1.8})
	poser.call("corbeille", Vector2(6.0, -10.0), 0.0, 1)
	poser.call("corbeille", Vector2(9.0, 9.0), 0.0, 2)


## Les tables du mobilier toulousain et, pour chacune, les centres de ses tables (en mètres, dans le repère de
## l'objet) : la brique les couvre d'une seule boîte, on la remplace par un cylindre par table (Guillaume,
## 30 octobre : une hitbox plus fine, qu'on contourne). « n » : le nombre de tables de la terrasse.
const TABLES := {
	"terrasse": [],
	"parasol": [Vector2.ZERO],
	"grand_parasol": [Vector2(-0.95, 0.4), Vector2(0.95, -0.4)],
	"store_terrasse": [Vector2(-1.0, 0.1), Vector2(1.0, 0.1)],
}
## Le rayon d'une table et de ses chaises, en mètres.
const RAYON_TABLE := 0.62


static func _affiner(n: Node3D, nom: String, opt: Dictionary) -> void:
	var centres: Array = TABLES[nom]
	if nom == "terrasse":
		var k_max := clampi(int(opt.get("tables", 3)), 1, 4)
		centres = []
		for k in k_max:
			centres.append(Vector2((k - (k_max - 1) * 0.5) * 1.6, 0.25 if k % 2 == 0 else -0.25))
	for corps in n.find_children("*", "StaticBody3D", true, false):
		for f in corps.get_children():
			corps.remove_child(f)
			f.free()
		for c in centres:
			var f := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = RAYON_TABLE
			cyl.height = 0.9
			f.shape = cyl
			f.position = Vector3(c.x, 0.45, c.y)
			corps.add_child(f)


# --- L'arrêt des taxis ------------------------------------------------------------------------------

## La station de taxis de la rue de la Pomme, à deux pas de la place (Guillaume, 30 octobre) : elle tient lieu de
## l'arrêt du car du socle (la structure « arret_car », nœud ArretDeCar) et ouvre la carte. Une borne à
## lanterne « TAXIS », le marquage jaune au sol, un taxi garé le long du trottoir nord.
const TAXI := Vector2(-9.6, -1.55)


static func _taxi(racine: Node3D) -> void:
	var arret := Node3D.new()
	arret.name = "ArretDeCar"
	arret.position = Vector3(TAXI.x, 0.0, TAXI.y)
	racine.add_child(arret)
	var fonte := StandardMaterial3D.new()
	fonte.albedo_color = Color("2b2f2e")
	var jaune := StandardMaterial3D.new()
	jaune.albedo_color = Color("e2b83a")
	var blanc := StandardMaterial3D.new()
	blanc.albedo_color = Color("f1e6cc")
	blanc.emission_enabled = true
	blanc.emission = Color("f1e6cc")
	blanc.emission_energy_multiplier = 0.25
	var u := 1.0 / UNITE
	# la borne : un fût de fonte, la lanterne carrée « TAXIS » sur ses quatre faces
	_pave(arret, Vector3(2.4 * u, 0.0, -0.1 * u), Vector3(0.14, 2.6, 0.14) * u, fonte)
	_pave(arret, Vector3(2.4 * u, 2.6 * u, -0.1 * u), Vector3(0.62, 0.42, 0.62) * u, blanc)
	_pave(arret, Vector3(2.4 * u, 3.02 * u, -0.1 * u), Vector3(0.7, 0.06, 0.7) * u, fonte)
	for k in 4:
		var l := Label3D.new()
		l.text = "TAXIS"
		l.font = Polices.texte()
		l.font_size = 40
		l.pixel_size = 0.0022
		l.modulate = Color("1d2422")
		l.outline_size = 0
		var a := k * PI * 0.5
		l.position = Vector3(2.4 * u + sin(a) * 0.32 * u, 2.81 * u, -0.1 * u + cos(a) * 0.32 * u)
		l.rotation.y = a
		arret.add_child(l)
	# le marquage au sol : un rectangle jaune le long du trottoir, « TAXI » peint dedans
	for z in [-0.55, 0.55]:
		_pave(arret, Vector3(0.0, 0.004, z * u), Vector3(5.2, 0.008, 0.1) * u, jaune)
	for x in [-2.6, 2.6]:
		_pave(arret, Vector3(x * u, 0.004, 0.0), Vector3(0.1, 0.008, 1.2) * u, jaune)
	for z in [-0.55, 0.55]:
		_pave(arret, Vector3(-5.2 * u, 0.004, z * u), Vector3(5.2, 0.008, 0.1) * u, jaune)
	_pave(arret, Vector3(-7.8 * u, 0.004, 0.0), Vector3(0.1, 0.008, 1.2) * u, jaune)
	var sol := Label3D.new()
	sol.text = "TAXI"
	sol.font = Polices.texte()
	sol.font_size = 64
	sol.pixel_size = 0.004
	sol.modulate = Color("e2b83a")
	sol.outline_size = 0
	sol.rotation = Vector3(-PI * 0.5, PI * 0.5, 0.0)
	sol.position = Vector3(-1.6 * u, 0.012, 0.0)
	arret.add_child(sol)
	# le taxi garé, le long de la rue (la voiture de la ville du socle, à l'échelle)
	# deux taxis garés à la file, le lumineux « TAXI » sur le toit (juge, v0.30)
	var voiture: PackedScene = load("res://assets/kaykit/city/car_taxi.gltf")
	var corps := StaticBody3D.new()
	arret.add_child(corps)
	for x in [0.3, -4.6]:
		if voiture != null:
			var v := voiture.instantiate() as Node3D
			v.rotation.y = PI * 0.5
			v.scale = Vector3.ONE * 4.5 * u
			v.position = Vector3(x * u, 0.0, 0.05 * u)
			arret.add_child(v)
		_pave(arret, Vector3(x * u, 1.62 * u, 0.05 * u), Vector3(0.22, 0.16, 0.6) * u, blanc)
		var toit := Label3D.new()
		toit.text = "TAXI"
		toit.font = Polices.texte()
		toit.font_size = 32
		toit.pixel_size = 0.0016
		toit.modulate = Color("1d2422")
		toit.outline_size = 0
		toit.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		toit.position = Vector3(x * u, 1.7 * u, 0.05 * u)
		arret.add_child(toit)
		var forme := CollisionShape3D.new()
		var boite := BoxShape3D.new()
		boite.size = Vector3(4.3, 1.5, 1.9) * u
		forme.shape = boite
		forme.position = Vector3(x * u, 0.75 * u, 0.05 * u)
		corps.add_child(forme)
	# la zone : devant le taxi, côté rue
	var zone := Area3D.new()
	zone.name = "Zone"
	zone.set_meta("interact", "taxi")
	zone.set_meta("prompt", "E : prendre un taxi (la carte des communes)")
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3(6.4, 2.0, 3.6) * u
	f.shape = b
	f.position = Vector3(0.6 * u, 1.0 * u, 0.4 * u)
	zone.add_child(f)
	arret.add_child(zone)


static func _pave(parent: Node3D, pied: Vector3, taille: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = taille
	m.material = mat
	mi.mesh = m
	mi.position = pied + Vector3(0.0, taille.y * 0.5, 0.0)
	parent.add_child(mi)


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
	for centre in [Vector2(-1.6, -9.6), Vector2(1.2, -2.2), Vector2(1.8, -4.8), Vector2(6.4, -4.4)]:
		for k in 3:
			var a: float = TAU * k / 3.0 + centre.x
			var f: Node3D = Atelier.figurant(g, "idle")
			f.position = Vector3(centre.x + cos(a) * 0.45, 0.0, centre.y + sin(a) * 0.45)
			f.rotation.y = atan2(-cos(a), -sin(a))
			groupe.add_child(f)
			g += 1
	# Au bord du jardin d'enfants, deux parents qui bavardent en surveillant les jeux.
	var voisins := [Vector2(3.6, -14.5), Vector2(4.2, -14.5)]
	for k in 2:
		var p: Vector2 = voisins[k]
		var q: Vector2 = voisins[1 - k]
		var f: Node3D = Atelier.figurant(g, "idle")
		f.position = Vector3(p.x, 0.0, p.y)
		f.rotation.y = atan2(q.x - p.x, q.y - p.y)
		groupe.add_child(f)
		g += 1
	# Les promeneurs : d'une rue à l'autre, entre les terre-pleins.
	var routes := [
		[Vector3(-12.0, 0, -2.0), Vector3(-4.0, 0, -2.1), Vector3(-1.5, 0, -2.4), Vector3(0.6, 0, -1.5), Vector3(3.2, 0, 1.5), Vector3(3.4, 0, 6.5), Vector3(5.0, 0, 12.0), Vector3(6.0, 0, 19.0)],
		[Vector3(-8.0, 0, -17.0), Vector3(-3.2, 0, -11.5), Vector3(-1.5, 0, -9.0), Vector3(6.0, 0, -8.8), Vector3(13.0, 0, -9.5), Vector3(12.6, 0, -14.0)],
		[Vector3(5.0, 0, 18.0), Vector3(3.4, 0, 6.5), Vector3(3.2, 0, 1.5), Vector3(0.6, 0, -1.5), Vector3(-2.0, 0, -6.0), Vector3(-3.2, 0, -11.5), Vector3(-7.0, 0, -16.0)],
		[Vector3(21.5, 0, 2.2), Vector3(20.0, 0, 1.0), Vector3(18.2, 0, -4.0), Vector3(15.6, 0, -4.3), Vector3(13.1, 0, -2.6), Vector3(12.3, 0, 1.0), Vector3(12.0, 0, 4.0), Vector3(3.4, 0, 6.5), Vector3(3.2, 0, 1.5), Vector3(0.6, 0, -1.5), Vector3(-1.5, 0, -2.4), Vector3(-4.0, 0, -2.1), Vector3(-14.0, 0, -2.0)],
		[Vector3(14.0, 0, -11.5), Vector3(13.0, 0, -9.5), Vector3(6.0, 0, -8.8), Vector3(0.6, 0, -1.5), Vector3(3.2, 0, 1.5), Vector3(3.4, 0, 6.5), Vector3(9.0, 0, 5.4)],
		[Vector3(-14.0, 0, -2.0), Vector3(-4.0, 0, -2.1), Vector3(-1.5, 0, -2.4), Vector3(0.6, 0, -1.5), Vector3(3.2, 0, 1.5), Vector3(3.4, 0, 6.5), Vector3(9.6, 0, 4.8)],
		# l'allée entre les deux terre-pleins, vers Lafage : la vue de départ la voit en long (juge, v0.12)
		[Vector3(4.5, 0, -6.0), Vector3(10.0, 0, -6.2), Vector3(16.0, 0, -6.8), Vector3(18.5, 0, -9.0)],
		[Vector3(6.0, 0, -8.6), Vector3(12.0, 0, -6.0), Vector3(17.0, 0, -4.6)],
	]
	# chaque route parcourue dans les deux sens : un promeneur à l'aller, un autre au retour (verdict du juge
	# sur la v0.8 : des passants)
	for k in routes.size():
		for sens in 2:
			var route: Array[Vector3] = []
			route.assign(routes[k])
			if sens == 1:
				route.reverse()
			# deux passants de la rue de la Pomme avaient la même marinière (juge, revue finale) : une autre graine
			var f: Node3D = Atelier.figurant(g + (500 if k == 5 else 0), "walk", "village", route)
			f.position = route[0]
			groupe.add_child(f)
			g += 1
	# Des haltes : deux voisins devant les étals, deux au bord de la terrasse de Lafage, deux sur le trottoir
	# de la grande terrasse du sud-ouest.
	for paire in [[Vector2(12.2, 7.6), Vector2(12.7, 7.1)], [Vector2(10.6, -6.8), Vector2(11.1, -7.3)], [Vector2(-1.0, 4.6), Vector2(-0.6, 5.2)], [Vector2(-1.7, -1.7), Vector2(-1.2, -1.2)],
			[Vector2(8.6, -5.6), Vector2(9.1, -6.1)], [Vector2(15.2, -5.2), Vector2(15.7, -5.7)], [Vector2(17.5, -7.5), Vector2(18.0, -7.0)], [Vector2(9.6, -4.2), Vector2(10.1, -4.0)]]:
		for k in 2:
			var p: Vector2 = paire[k]
			var q: Vector2 = paire[1 - k]
			var f: Node3D = Atelier.figurant(g, "idle")
			f.position = Vector3(p.x, 0.0, p.y)
			f.rotation.y = atan2(q.x - p.x, q.y - p.y)
			groupe.add_child(f)
			g += 1


# --- La fonte des maillages -----------------------------------------------------------------------

## Fond les maillages d'un groupe en un maillage par matériau et par case de 12 unités (assez gros pour peu de
## surfaces dessinées, assez petit pour que le moteur en écarte une partie hors du champ), en gardant leurs
## corps de collision.
static func _fondre(racine: Node3D, nom: String, reglages := {}) -> void:
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
		for r in reglages:
			mi.set_instance_shader_parameter(r, reglages[r])
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
