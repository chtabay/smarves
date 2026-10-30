extends SceneTree
## Parcourt une commune à hauteur de joueur, pour juger le lieu comme un joueur le verra
## (docs/CONCEPTION.md, « Juger à hauteur de joueur »). La commune s'ouvre comme chez un joueur, comme
## dans tools/test_commune.gd ; l'habitant est posé sur chacun de ses repères de vue, l'un après l'autre,
## puis marche de chaque repère au suivant. Avec un rendu (sans --headless), chaque repère est photographié
## trois fois : en vue de dessus au cran du jeu, à pied à hauteur d'yeux, et à pied en se retournant.
##
##   godot --path . -s tools/parcours_commune.gd -- <id>                       res://communes/<id>/
##   godot --path . -s tools/parcours_commune.gd -- <id> --pck=build/<id>.pck   un paquet emballé, tel quel
##   --depuis=res://chemin/   un autre dossier source (comme tools/test_commune.gd)
##   --reperes=Vue            le début du nom des repères (Marker3D) à suivre, dans l'ordre de leurs noms
##                            (Vue1_Belvedere, Vue2_SousLesArches…) ; « Vue » par défaut, Arrivee s'il n'y en a pas
##   --sortie=dossier/        les captures et le rapport ; user://parcours/<id>/ par défaut
##   --point=x,y,z,lacet      un point de vue de plus, en unités de la scène et en degrés (répétable) ;
##                            pour regarder une commune sans repères, ou un endroit précis. Avec --point,
##                            seuls les points donnés sont suivis
##   --sans-marche            les captures seulement
##   --libre=x,y,z,lacet,tangage[,champ]   une vue libre de plus (répétable), caméra posée où l'on veut,
##                            hors du joueur : en unités de la scène et en degrés (tangage négatif : on
##                            regarde vers le bas ; champ : l'angle de vue, 70 par défaut). Les vues libres
##                            se prennent après les repères, nommées libre-1, libre-2…
##   --sans-interface         les captures sans l'interface (le décor seul) ; par défaut, elles sont prises
##                            telles qu'en jeu, avec ce que le joueur voit à l'écran
##   sans id                  le kit de départ (tools/kit/), comme tools/test_commune.gd
## Avec --headless, aucune image : seuls les poses et les marches sont éprouvées.
## Les quatre regards du retour de l'auteur de Chauvigny : à pied, de dessus, libre, tel qu'en jeu.
##
## Les repères se posent dans la scène de la commune : un Marker3D par point de vue, son -Z tourné vers
## ce que le joueur doit voir. Deux repères qui se suivent doivent se rejoindre à pied presque en ligne
## droite : pour un détour (un escalier, un pont, une porte), posez un repère au coude (Vue2b_Escalier).
## Un repère pèse quelques octets dans le paquet ; on peut aussi les garder dans une scène de travail.

const TMP := "user://parcours_commune/"
const KIT := "res://tools/kit/"
const KIT_COMMUNE := {"id": "la_villedieu_du_clain", "nom": "La Villedieu-du-Clain", "insee": "86290"}

var fails := 0
var lignes: PackedStringArray = []
var sortie := ""
var images := false
var a_pied := false
var sans_interface := false


func check(ok: bool, what: String) -> void:
	dire(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func dire(t: String) -> void:
	print(t)
	lignes.append(t)


func _init() -> void:
	await process_frame
	var id := ""
	var depuis := ""
	var deja := ""
	var prefixe := "Vue"
	var marcher := true
	var points: Array = []
	var libres: Array = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pck="):
			deja = a.trim_prefix("--pck=")
		elif a.begins_with("--depuis="):
			depuis = a.trim_prefix("--depuis=")
		elif a.begins_with("--reperes="):
			prefixe = a.trim_prefix("--reperes=")
		elif a.begins_with("--sortie="):
			sortie = a.trim_prefix("--sortie=")
		elif a.begins_with("--point="):
			points.append(a.trim_prefix("--point=").split_floats(","))
		elif a == "--sans-marche":
			marcher = false
		elif a.begins_with("--libre="):
			libres.append(a.trim_prefix("--libre=").split_floats(","))
		elif a == "--sans-interface":
			sans_interface = true
		elif not a.begins_with("--"):
			id = a
	DirAccess.make_dir_recursive_absolute(TMP)
	if deja == "" and id == "":
		id = KIT_COMMUNE.id
		depuis = _remplir_kit()
	elif deja == "" and depuis == "":
		depuis = "res://communes/%s/" % id
	if id == "" and deja != "":
		id = deja.get_file().get_basename()
	if sortie == "":
		sortie = "user://parcours/%s/" % id
	if not sortie.ends_with("/"):
		sortie += "/"
	DirAccess.make_dir_recursive_absolute(sortie)
	images = DisplayServer.get_name() != "headless"

	var pck := TMP + "%s.pck" % id
	if deja != "":
		DirAccess.copy_absolute(deja, pck)
	else:
		if not depuis.ends_with("/"):
			depuis += "/"
		if not FileAccess.file_exists(depuis + "commune.json"):
			printerr("Pas de manifeste %scommune.json" % depuis)
			quit(2)
			return
		# Le pack, rangé comme le fait tools/emballer_commune.gd.
		var fichiers := {}
		_parcourir(depuis, depuis, "res://communes/%s/" % id, fichiers)
		var pk := PCKPacker.new()
		pk.pck_start(pck)
		for cible in fichiers:
			pk.add_file(cible, fichiers[cible])
		pk.flush()

	var communes: Node = root.get_node("Communes")
	communes.dossier_greffes = TMP
	var lu: String = communes.charger_pack(pck)
	if lu != "":
		id = lu
	var c: Commune = communes.commune(id)
	check(c != null and communes.ouvrir(id), "« %s » se greffe et s'ouvre %s" % [id, str(communes.refus) if not communes.refus.is_empty() else ""])
	if c == null:
		_fin()
		return
	var t0 := Time.get_ticks_msec()
	change_scene_to_file(str(c.data.scene))
	await process_frame
	await process_frame
	var s: Node = current_scene
	dire("        %s, version %s : scène prête en %d ms" % [c.nom, c.data.get("version", "?"), Time.get_ticks_msec() - t0])
	var p = s.get("player") if s != null else null
	var vue: Node = root.get_node("/root/Vue")
	if not (p is CharacterBody3D) or not vue.gere(s):
		check(false, "la scène expose « player » et « camera » (docs/COMMUNE.md, « Le kit de départ »)")
		_fin()
		return

	var reperes: Array = s.find_children(prefixe + "*", "Marker3D", true, false)
	reperes.sort_custom(func(a, b): return String(a.name).naturalnocasecmp_to(String(b.name)) < 0)
	if not points.is_empty():
		reperes = []
		for v in points:
			var m := Marker3D.new()
			m.name = "Point%d" % (reperes.size() + 1)
			s.add_child(m)
			m.global_position = Vector3(v[0], v[1], v[2])
			m.rotation.y = deg_to_rad(v[3]) if v.size() > 3 else 0.0
			reperes.append(m)
	if reperes.is_empty() and s.get_node_or_null("Arrivee") is Marker3D:
		dire("        aucun repère « %s… » : seulement l'arrivée. Posez un Marker3D par point de vue." % prefixe)
		reperes = [s.get_node("Arrivee")]
	if reperes.is_empty():
		check(false, "la scène a des repères « %s… » ou un repère Arrivee" % prefixe)
		_fin()
		return
	dire("        %d repère(s) : %s" % [reperes.size(), ", ".join(reperes.map(func(r): return String(r.name)))])
	if not images:
		dire("        sans rendu (--headless) : pas de captures, les poses et les marches seulement")

	for i in reperes.size():
		var r: Marker3D = reperes[i]
		await _poser(p, r)
		check(p.is_on_floor(), "%s : l'habitant se pose (y %.2f)" % [r.name, p.global_position.y])
		if images:
			await _vue(s, vue, false)
			_cadrer(s, p, r.global_rotation.y)
			await create_timer(1.5, true).timeout
			await _capturer("%02d-%s-1-dessus" % [i + 1, r.name])
			await _vue(s, vue, true)
			p.rotation.y = r.global_rotation.y
			p.set("_pitch", 0.0)
			if p.camera:
				p.camera.rotation.x = 0.0
			await create_timer(0.5, true).timeout
			await _capturer("%02d-%s-2-a-pied" % [i + 1, r.name])
			p.rotation.y = r.global_rotation.y + PI
			await create_timer(0.5, true).timeout
			await _capturer("%02d-%s-3-retour" % [i + 1, r.name])

	if marcher:
		for i in reperes.size() - 1:
			await _marcher(s, vue, p, reperes[i], reperes[i + 1])
	await _vue(s, vue, false)
	if images and not libres.is_empty():
		await _libres(s, libres)
	_fin()


## Les vues libres : une caméra à part, posée et tournée comme demandé, puis la caméra du jeu reprend.
func _libres(s: Node, libres: Array) -> void:
	var avant := root.get_camera_3d()
	var cam := Camera3D.new()
	cam.far = 4000.0
	s.add_child(cam)
	for i in libres.size():
		var v: PackedFloat64Array = libres[i]
		if v.size() < 3:
			check(false, "--libre=%s : au moins x,y,z" % ",".join(Array(v).map(func(x): return str(x))))
			continue
		cam.global_position = Vector3(v[0], v[1], v[2])
		cam.rotation = Vector3(deg_to_rad(v[4]) if v.size() > 4 else 0.0, deg_to_rad(v[3]) if v.size() > 3 else 0.0, 0.0)
		cam.fov = v[5] if v.size() > 5 else 70.0
		# septième valeur : une bascule d'objectif, le cadre décalé vers le haut (en fraction de sa hauteur) sans
		# incliner la caméra, pour garder les verticales droites
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		if v.size() > 6 and v[6] != 0.0:
			cam.projection = Camera3D.PROJECTION_FRUSTUM
			cam.size = 2.0 * cam.near * tan(deg_to_rad(cam.fov) * 0.5)
			cam.frustum_offset = Vector2(0.0, v[6] * cam.size)
		cam.make_current()
		await create_timer(0.5, true).timeout
		await _capturer("libre-%d" % (i + 1))
	cam.queue_free()
	if avant != null and is_instance_valid(avant):
		avant.make_current()


## L'habitant posé sur le repère, tourné comme lui, puis laissé tomber au sol.
func _poser(p: CharacterBody3D, r: Marker3D) -> void:
	p.auto_move = Vector3.ZERO
	p.velocity = Vector3.ZERO
	p.global_position = r.global_position + Vector3(0, 0.05, 0)
	p.rotation.y = r.global_rotation.y
	await create_timer(1.0, true).timeout


## La vue de dessus ou à pied, par la bascule du socle (la touche Tab du joueur).
func _vue(s: Node, vue: Node, pied: bool) -> void:
	if pied != a_pied:
		vue.basculer(s)
		a_pied = pied
		await process_frame


## La caméra de dessus au-dessus de l'habitant, regardant comme le repère.
func _cadrer(s: Node, p: CharacterBody3D, lacet: float) -> void:
	var cam: Camera3D = s.camera
	cam.target = p.global_position + Vector3(0, 0.3, 0)
	cam.set("_target_goal", cam.target)
	cam.yaw = lacet
	cam.set("_yaw_goal", lacet)


## De a vers b à pied, comme un joueur qui tient la flèche vers le but : arrivé, arrêté ou tombé.
func _marcher(s: Node, vue: Node, p: CharacterBody3D, a: Marker3D, b: Marker3D) -> void:
	await _poser(p, a)
	await _vue(s, vue, true)
	var but := b.global_position
	var d0 := _plat(but - p.global_position).length()
	var limite := d0 / maxf(p.speed, 0.1) * 2.5 + 4.0
	var t := 0.0
	var dernier := p.global_position
	var immobile := 0.0
	var etat := ""
	while t < limite:
		var reste := _plat(but - p.global_position)
		if reste.length() < maxf(0.5, p.radius * 4.0):
			etat = "arrive"
			break
		if p.global_position.y < minf(a.global_position.y, but.y) - 5.0:
			etat = "tombe"
			break
		p.rotation.y = atan2(-reste.x, -reste.z)
		p.auto_move = Vector3(0, 0, -1)
		await create_timer(0.2, true).timeout
		t += 0.2
		immobile = immobile + 0.2 if p.global_position.distance_to(dernier) < 0.02 * p.speed else 0.0
		dernier = p.global_position
		if immobile >= 2.0:
			etat = "arrete"
			break
	p.auto_move = Vector3.ZERO
	var reste := _plat(but - p.global_position).length()
	var trajet := "%s → %s (%.1f unités)" % [a.name, b.name, d0]
	match etat:
		"arrive":
			check(true, "%s : on y va à pied en %.1f s" % [trajet, t])
		"tombe":
			check(false, "%s : l'habitant tombe en (%.1f, %.1f, %.1f)" % [trajet, p.global_position.x, p.global_position.y, p.global_position.z])
		_:
			check(false, "%s : arrêté à %.1f unités du but, en (%.1f, %.1f, %.1f) ; un mur, une marche ou un détour (posez un repère au coude)" % [trajet, reste, p.global_position.x, p.global_position.y, p.global_position.z])
	if etat != "arrive" and images:
		await _capturer("bloque-%s-%s" % [a.name, b.name])


func _plat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _capturer(nom: String) -> void:
	var caches: Array = []
	if sans_interface:
		for c in root.find_children("*", "CanvasLayer", true, false):
			if c.visible:
				c.visible = false
				caches.append(c)
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	for c in caches:
		c.visible = true
	if img == null:
		return
	img.save_png(sortie + nom + ".png")
	dire("        capture %s.png" % nom)


func _fin() -> void:
	dire("\n%d échec(s)" % fails)
	var f := FileAccess.open(sortie + "rapport.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(lignes) + "\n")
		f.close()
	print("Rapport et captures : %s" % ProjectSettings.globalize_path(sortie))
	quit(1 if fails > 0 else 0)


## Le kit de départ rempli pour une commune, comme le portail le donne.
func _remplir_kit() -> String:
	var dossier := TMP + "kit/"
	DirAccess.make_dir_recursive_absolute(dossier)
	for f in ["commune.json", "commune.tscn", "commune.gd"]:
		var t := FileAccess.get_file_as_string(KIT + f)
		for k in KIT_COMMUNE:
			t = t.replace("__%s__" % k.to_upper(), KIT_COMMUNE[k])
		var out := FileAccess.open(dossier + f, FileAccess.WRITE)
		out.store_string(t)
		out.close()
	return dossier


func _parcourir(dossier: String, racine: String, cible: String, out: Dictionary) -> void:
	var d := DirAccess.open(dossier)
	for f in d.get_files():
		if f.ends_with(".md"):
			continue
		var chemin := dossier + f
		var dans_le_paquet := cible + chemin.trim_prefix(racine)
		if f.ends_with(".import"):
			out[dans_le_paquet] = chemin
			var cfg := ConfigFile.new()
			if cfg.load(chemin) == OK and cfg.has_section("remap"):
				for k in cfg.get_section_keys("remap"):
					var importe := str(cfg.get_value("remap", k))
					if k.begins_with("path") and FileAccess.file_exists(importe):
						out[importe] = importe
		elif not FileAccess.file_exists(chemin + ".import"):
			out[dans_le_paquet] = chemin
	for sub in d.get_directories():
		_parcourir(dossier + sub + "/", racine, cible, out)
