extends SceneTree
## Le plan du village pour les pensionnaires (docs/PENSIONNAIRES.md, « Le corps ») :
## godot --headless --path . -s tools/plan_pensionnaires.gd -- --sortie=chemin/plan.json
## Un pensionnaire n'a pas de moteur physique : le serveur (la fonction doublures du dépôt addict) le fait
## marcher sur ce plan. On y sonde la scène principale, case par case (une demi-unité, 1,2 m) : le sol
## sous la case et rien de solide à hauteur d'homme. Chaque ligne du plan est une rangée de cases d'ouest
## en est, du nord au sud ; « # » est une case où l'on ne passe pas, sinon un caractère de l'alphabet
## base64 donne la hauteur du sol (son rang moins 32, en dixièmes d'unité). Les lieux ont leur porte :
## l'id, le nom et la case libre la plus proche de l'entrée.
## À relancer quand le village change, puis recopier le fichier dans addict (doublures/plan.json).

const PAS := 0.5
const X0 := -82.0
const X1 := 82.0
const Z0 := -79.0
const Z1 := 37.0
## Les noms des lieux des rues, tels qu'on les dit au village ; un emplacement absent d'ici n'est pas un lieu.
const NOMS := {
	"notaire": "l'étude de Maître Garnier", "poste": "la poste", "boucherie": "la boucherie Texier",
	"coiffure": "Gisèle Coiffure", "couture": "Raymonde, couture et retouches", "pizzeria": "la Pizzeria du Clain",
	"epicerie": "l'Épicerie du Bourg", "fleurs": "Fleurs Odette", "brocante": "la brocante Boutin",
	"bibliotheque": "la bibliothèque municipale", "garage": "le garage Fradin", "pharmacie": "la pharmacie",
	"ecole": "l'école", "stade": "le stade municipal", "moulin": "le Moulin des Dames",
}
const B64 := "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"


func _init() -> void:
	await process_frame
	var sortie := "user://plan_pensionnaires.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sortie="):
			sortie = a.substr(9)
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	game.welcomed = true
	change_scene_to_file("res://scenes/main.tscn")
	await create_timer(1.5).timeout
	await physics_frame
	var main: Node = current_scene
	var village: Node = main.get_node("Village")
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var corps := PhysicsShapeQueryParameters3D.new()
	var boule := SphereShape3D.new()
	boule.radius = 0.3
	corps.shape = boule
	var largeur := int(round((X1 - X0) / PAS))
	var hauteur := int(round((Z1 - Z0) / PAS))
	var lignes: Array[String] = []
	var libres := 0
	for j in hauteur:
		var ligne := ""
		for i in largeur:
			var x := X0 + (i + 0.5) * PAS
			var z := Z0 + (j + 0.5) * PAS
			var sol = _sol(space, x, z)
			if sol == null:
				ligne += "#"
				continue
			corps.transform = Transform3D(Basis(), Vector3(x, float(sol) + 0.65, z))
			var bloque := false
			for hit in space.intersect_shape(corps, 4):
				if not (hit.collider is Area3D):
					bloque = true
					break
			var rang := clampi(int(round(float(sol) * 10.0)) + 32, 0, 63)
			ligne += "#" if bloque else B64[rang]
			if not bloque:
				libres += 1
		lignes.append(ligne)
	# On ne garde que ce qu'on atteint à pied depuis le milieu de la place, sans marche de plus de
	# 0,4 unité : les toits bas et les cours fermées tombent.
	var atteint := {}
	var file := [Vector2i(int((0.0 - X0) / PAS), int((2.0 - Z0) / PAS))]
	atteint[file[0]] = true
	while not file.is_empty():
		var c: Vector2i = file.pop_back()
		var h := B64.find(lignes[c.y][c.x])
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var v: Vector2i = c + dv
			if v.x < 0 or v.y < 0 or v.x >= largeur or v.y >= hauteur or atteint.has(v) or lignes[v.y][v.x] == "#":
				continue
			if absi(B64.find(lignes[v.y][v.x]) - h) > 4:
				continue
			atteint[v] = true
			file.append(v)
	libres = 0
	for j in hauteur:
		var l := lignes[j].to_utf8_buffer()
		for i in largeur:
			if not atteint.has(Vector2i(i, j)):
				l[i] = 35
			else:
				libres += 1
		lignes[j] = l.get_string_from_utf8()
	var plan := {"pas": PAS, "x0": X0, "z0": Z0, "largeur": largeur, "hauteur": hauteur, "lignes": lignes, "lieux": {}}
	# Les lieux : ceux de la place (leurs bâtiments) et ceux des rues (leur porte).
	var noms := {}
	for p in Commune.smarves().lieux():
		noms[str(p.id)] = str(p.get("name", p.id))
	for id in main.place_signs:
		var b: Node3D = main.place_signs[id].get_parent()
		plan.lieux[id] = _porte(plan, b.global_position, Vector3(0, 0, 2), noms.get(id, id))
	for id in village.lots:
		var lot: Dictionary = village.lots[id]
		if not NOMS.has(id):
			continue
		var d = lot.get("door")
		var p: Vector3 = d if d is Vector3 else lot.pos
		plan.lieux[id] = _porte(plan, p, Vector3(p.x, 0, 6.4), NOMS[id])
	plan.lieux["mairie"] = _porte(plan, Vector3(-4.6, 0, -5.8), Vector3(-4.6, 0, 0), "la mairie et son panneau")
	plan.lieux["eglise"] = _porte(plan, Vector3(0.4, 0, -6.0), Vector3(0.4, 0, 0), "l'église")
	# La roulette de la boulangerie, devant son étal (main.gd, _build_gambling).
	plan.lieux["boulangerie"] = _porte(plan, Vector3(7.0, 0, -1.6), Vector3(0, 0, 0), "la boulangerie et sa roulette")
	# Les quartiers, pour dire où l'on est : id → {nom, x, z, largeur, profondeur} (village.ZONES).
	plan.quartiers = {}
	for id in village.ZONES:
		var r: Rect2 = village.ZONES[id].rect
		plan.quartiers[id] = {"nom": village.ZONES[id].nom, "x": r.position.x, "z": r.position.y, "largeur": r.size.x, "profondeur": r.size.y}
	var f := FileAccess.open(sortie, FileAccess.WRITE)
	f.store_string(JSON.stringify(plan))
	f.close()
	print("plan : %d × %d cases, %d libres, %d lieux → %s" % [largeur, hauteur, libres, plan.lieux.size(), sortie])
	quit(0 if libres > 1000 else 1)


## La hauteur du sol sous (x, z), ou null s'il n'y en a pas.
func _sol(space: PhysicsDirectSpaceState3D, x: float, z: float) -> Variant:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 8.0, z), Vector3(x, -6.0, z))
	q.collide_with_areas = false
	var r := space.intersect_ray(q)
	if r.is_empty():
		return null
	# Un toit n'est pas un sol : au-dessus de trois unités, on n'y marche pas.
	return r.position.y if r.position.y < 3.0 else null


## La case libre la plus proche de l'entrée d'un lieu, en allant de l'entrée vers la rue.
func _porte(plan: Dictionary, depuis: Vector3, vers: Vector3, nom: String) -> Dictionary:
	var dir := vers - depuis
	dir.y = 0.0
	var n := maxi(1, int(dir.length() / (PAS * 0.5)))
	for k in n + 1:
		var p := depuis + dir * (float(k) / n)
		var i := int(floor((p.x - plan.x0) / PAS))
		var j := int(floor((p.z - plan.z0) / PAS))
		if j >= 0 and j < plan.hauteur and i >= 0 and i < plan.largeur and plan.lignes[j][i] != "#":
			return {"nom": nom, "i": i, "j": j}
	return {"nom": nom, "i": -1, "j": -1}
