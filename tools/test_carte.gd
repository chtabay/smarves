extends SceneTree
## Vérifie la carte de la Vienne de bout en bout : godot --headless --path . -s tools/test_carte.gd
## Ligugé (tools/paquet_essai/liguge/), emballée ici en pack, se greffe et s'allume sur la carte ; on
## y va depuis la carte, on rouvre la carte depuis Ligugé, et l'on rentre à Smarves. Le dézoom du
## village au-delà du dernier cran ouvre la carte ; la carte ne laisse jamais perdre le département.

const LIGUGE := "res://tools/paquet_essai/liguge/"
const TMP := "user://test_carte/"

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var communes: Node = root.get_node("Communes")
	var carte: CanvasLayer = root.get_node("Carte")
	_camera()
	_dessin()
	DirAccess.make_dir_recursive_absolute(TMP)
	communes.dossier_greffes = TMP
	DirAccess.remove_absolute(TMP + "allumees.json")
	var pk := PCKPacker.new()
	pk.pck_start(TMP + "liguge.pck")
	for f in ["commune.json", "commune.tscn", "liguge.gd"]:
		pk.add_file("res://communes/liguge/" + f, LIGUGE + f)
	pk.flush()
	check(communes.charger_pack(TMP + "liguge.pck") == "liguge", "Ligugé se greffe depuis son pack %s" % str(communes.refus))

	change_scene_to_file("res://scenes/main.tscn")
	await _attendre(1.0)
	check(communes.actuelle() == "smarves", "au village, on est à Smarves")
	check(carte.peut_ouvrir(), "la carte peut s'ouvrir au village")
	carte.ouvrir()
	await _attendre(0.3)
	var c: CarteVienne = carte.get("_carte")
	check(carte.is_open() and paused, "la carte est ouverte et le village en pause")
	check(c.ici == "86263", "l'épingle est sur Smarves")
	check(c.installees == ["86133"], "Ligugé est installée sur la carte")
	check(c.s_allume(), "Smarves et Ligugé s'allument à la première ouverture")
	var vues = JSON.parse_string(FileAccess.get_file_as_string(TMP + "allumees.json"))
	check(vues is Array and "86133" in vues and "86263" in vues, "les communes allumées sont retenues : %s" % str(vues))
	carte.fermer()
	await _attendre(0.8)
	carte.ouvrir()
	await _attendre(0.3)
	check(not c.s_allume(), "rien ne se rallume à l'ouverture suivante")

	carte.aller("86133")
	await _attendre(1.5)
	check(current_scene != null and current_scene.scene_file_path == "res://communes/liguge/commune.tscn", "« Y aller » mène à Ligugé")
	check(not carte.is_open() and not paused, "la carte s'est effacée, Ligugé n'est pas en pause")
	check(communes.actuelle() == "liguge", "on est à Ligugé")
	var cam = current_scene.get_viewport().get_camera_3d() if current_scene else null
	check(cam != null and cam.has_signal("au_dela") and not cam.notches.is_empty(), "Ligugé a la caméra à crans de Smarves")
	check(carte.peut_ouvrir(), "la carte s'ouvre aussi depuis Ligugé")
	carte.ouvrir()
	await _attendre(0.3)
	check(c.ici == "86133", "l'épingle est sur Ligugé")
	carte.aller("86263")
	await _attendre(1.5)
	check(current_scene != null and current_scene.scene_file_path == "res://scenes/main.tscn", "on rentre à Smarves par la carte")
	check(communes.actuelle() == "smarves", "de retour à Smarves")

	# Poitiers et les communes pas encore développées ne mènent nulle part.
	carte.ouvrir()
	await _attendre(0.3)
	carte.aller("86194")
	await _attendre(0.8)
	check(carte.is_open() and current_scene.scene_file_path == "res://scenes/main.tscn", "Poitiers reste dans la brume")
	carte.fermer()
	await _attendre(0.8)
	check(not carte.is_open() and not paused, "Échap ou Revenir rend le village")
	await _france(carte)
	await _car_et_routes(carte)
	await _mises_a_jour(carte, communes)
	await _telechargement(communes)
	await _titre(carte)
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


## Dézoomer encore sur la Vienne entière montre la France ; zoomer sur la Vienne y redescend.
func _france(carte: CanvasLayer) -> void:
	check(France.departements().size() == 96 and France.departement("86").nom == "Vienne", "les 96 départements, la Vienne en 86")
	var km := France.distance_km(Vienne.centre("86263"), Vector2(2.3522, 48.8566))
	check(km > 280.0 and km < 320.0, "Smarves est à environ 300 km de Paris à vol d'oiseau : %d" % km)
	carte.ouvrir()
	await _attendre(1.3)
	var c: CarteVienne = carte.get("_carte")
	c._zoomer(0.8, c.size / 2.0)
	check(c.niveau == "departement", "un cran de molette contre la Vienne entière ne suffit pas")
	c._zoomer(0.8, c.size / 2.0)
	check(c.niveau == "france", "deux crans, et c'est la France")
	check((carte.get("_grand_titre") as Label).text == "Carte de France", "le titre le dit")
	await _attendre(1.3)
	check(c.zoom == 1.0, "la France se découvre entière")
	var vienne := c.centre_de("86")
	check(c.commune_sous(c.vers_ecran(vienne)) == "86", "un clic au milieu de la Vienne désigne la Vienne")
	check(c.commune_sous(c.vers_ecran(c.vers_plan(Vector2(2.3522, 48.8566)))) == "75", "Paris est à Paris")
	check(France.regions().size() == 13 and France.region_de("86") == "75" and France.region("75").nom == "Nouvelle-Aquitaine", "les 13 régions, la Vienne en Nouvelle-Aquitaine")
	check(_ariane(carte) == ["France"], "le fil d'Ariane dit « France » : %s" % str(_ariane(carte)))
	c.choix.emit("33")
	await _attendre(0.1)
	var textes := _textes(carte.get("_fiche_box"))
	check("Nouvelle-Aquitaine" in textes and "Voir la région  →" in textes, "sur la France entière, la Gironde désigne sa région : %s" % str(textes))
	carte.vers_region("75")
	await _attendre(1.0)
	check(c.region == "75" and c.zoom > 1.5 and _ariane(carte) == ["France", "Nouvelle-Aquitaine"], "on regarde la Nouvelle-Aquitaine : %s" % str(_ariane(carte)))
	c.choix.emit("33")
	await _attendre(0.1)
	textes = _textes(carte.get("_fiche_box"))
	check("Gironde" in textes and textes.any(func(t): return "km de Smarves" in t) and "Voir ses communes  →" in textes, "la fiche de la Gironde dit sa distance et mène à ses communes : %s" % str(textes))
	c.choix.emit("75")
	carte.vers_departement("33")
	await _attendre(1.0)
	check(c.niveau == "departement" and c.departement == "33" and Departements.communes("33").size() > 500, "on descend en Gironde, commune par commune")
	check(_ariane(carte) == ["France", "Nouvelle-Aquitaine", "Gironde"], "le fil d'Ariane le dit : %s" % str(_ariane(carte)))
	check(c.commune_sous(c.vers_ecran(c.centre_de("33063"))) == "33063", "Bordeaux est à Bordeaux")
	c.choix.emit("33063")
	await _attendre(0.1)
	textes = _textes(carte.get("_fiche_box"))
	check(textes.any(func(t): return "car régional jusqu'à Bordeaux" in t), "Bordeaux est au bout du car régional : %s" % str(textes))
	check(carte.trajet("86133")[1].ends_with("en car départemental") and carte.trajet("86133")[0] < 15, "Ligugé, à quelques kilomètres en car départemental : %s" % str(carte.trajet("86133")))
	var modes := func(t: Array) -> Array: return t[2].map(func(e): return [e[0], e[2]])
	check(modes.call(carte.trajet("19272")) == [["car départemental", "86194"], ["car régional", "19272"]],
		"Tulle : le car jusqu'à Poitiers, puis le car régional jusqu'à Tulle, son chef-lieu : %s" % str(carte.trajet("19272")))
	check(modes.call(carte.trajet("33243")) == [["car départemental", "86194"], ["car régional", "33063"], ["car départemental", "33243"]],
		"Libourne : par les chefs-lieux, Poitiers puis Bordeaux : %s" % str(carte.trajet("33243")))
	check(modes.call(carte.trajet("86263", "33243")) == [["car départemental", "33063"], ["car régional", "86194"], ["car départemental", "86263"]],
		"et le retour fait le même chemin : %s" % str(carte.trajet("86263", "33243")))
	check(modes.call(carte.trajet("69266")) == [["car départemental", "86194"], ["avion", "69123"], ["car départemental", "69266"]]
		and "avion de Poitiers-Biard à Lyon" in carte.trajet("69266")[1], "Villeurbanne : l'avion de Poitiers-Biard à Lyon, puis le car : %s" % str(carte.trajet("69266")))
	check(modes.call(carte.trajet("15014", "69266")) == [["car départemental", "69123"], ["car régional", "15014"]],
		"de Villeurbanne à Aurillac, le car régional d'Auvergne-Rhône-Alpes part de Lyon : %s" % str(carte.trajet("15014", "69266")))
	var gares := Departements.connus().filter(func(d): return Departements.commune(Departements.chef_lieu(d)).is_empty())
	check(gares.is_empty(), "chaque département connu a sa gare, son chef-lieu, dans ses communes : %s" % str(gares))
	check(France.region("84").departements.all(func(d): return Departements.connu(str(d))), "l'Auvergne-Rhône-Alpes est sur la carte, commune par commune")
	carte.vers_france()
	await _attendre(1.3)
	carte.vers_departement("86")
	await _attendre(1.0)
	check(c.niveau == "departement" and c.departement == "86", "le fil d'Ariane remonte, la Vienne se retrouve")
	carte.vers_france()
	await _attendre(1.3)
	c.cadrer("86", CarteVienne.ZOOM_MAX_FRANCE)
	c._zoomer(1.25, c.size / 2.0)
	await _attendre(0.9)
	check(c.niveau == "departement" and c.zoom == 1.0, "zoomer encore sur la Vienne y redescend")
	carte.fermer()
	await _attendre(0.8)
	carte.ouvrir()
	await _attendre(0.3)
	check(c.niveau == "departement", "la carte se rouvre sur la Vienne")
	carte.vers_france()
	await _attendre(0.2)
	carte.fermer()
	await _attendre(0.8)
	check(not carte.is_open() and not paused, "on revient au village depuis la France")


## L'arrêt du car sur la place et les panneaux au bout des routes ouvrent la carte.
func _car_et_routes(carte: CanvasLayer) -> void:
	check(Vienne.voisine("86263", Vector2(-1, 0)) == "86133" and Vienne.voisine("86263", Vector2(0, 1)) == "86214"
		and Vienne.voisine("86263", Vector2(1, 0)) == "86180", "au bout des routes : Ligugé à l'ouest, Saint-Benoît au nord, Nouaillé-Maupertuis à l'est")
	var actions := {}
	for a in current_scene.find_children("*", "Area3D", true, false):
		if a.has_meta("action") and a.get_meta("interact", "") in ["car", "sortie"]:
			actions[a.get_meta("prompt")] = a.get_meta("action")
	check(actions.has("E : prendre le car départemental"), "un arrêt de car sur la place")
	check(actions.has("E : prendre la route de Ligugé") and actions.has("E : prendre la route de Saint-Benoît")
		and actions.has("E : prendre la route de Nouaillé-Maupertuis"), "trois panneaux de sortie : %s" % str(actions.keys()))
	(actions["E : prendre le car départemental"] as Callable).call()
	await _attendre(0.3)
	var c: CarteVienne = carte.get("_carte")
	check(carte.is_open() and (carte.get("_grand_titre") as Label).text.begins_with("Arrêt de la Place"), "le car ouvre la carte de ses arrêts")
	check(c.lignes == ["86133"], "ses lignes vont aux communes où l'on peut aller : %s" % str(c.lignes))
	carte.fermer()
	await _attendre(0.8)
	(actions["E : prendre la route de Saint-Benoît"] as Callable).call()
	await _attendre(0.3)
	check(carte.is_open() and c.choisie == "86214" and c.lignes.is_empty(), "la route du nord montre Saint-Benoît")
	carte.fermer()
	await _attendre(0.8)
	check(not carte.is_open() and not paused, "on revient au bout de la route")


## Une version publiée plus récente se voit sur la carte et dans la fiche ; un pack remplacé pendant la
## partie n'est pas relu par-dessus l'ancien.
func _mises_a_jour(carte: CanvasLayer, communes: Node) -> void:
	communes.catalogue = [{"insee": "86133", "id": "liguge", "nom": "Ligugé", "auteur": "Claude", "version": "0.3.0",
		"description": "", "paquet": "https://exemple.fr/liguge.pck", "taille": 1, "sha256": "0".repeat(64), "publie_le": ""}]
	check(communes.mise_a_jour("liguge") == "0.3.0", "la version 0.3.0 publiée est une mise à jour de la 0.2.0")
	carte.ouvrir()
	await _attendre(0.3)
	var c: CarteVienne = carte.get("_carte")
	check(c.a_jour == {"86133": "0.3.0"}, "la carte marque Ligugé d'une pastille")
	carte.call("_montrer", "86133")
	await _attendre(0.1)
	var textes := []
	for n in (carte.get("_fiche_box") as Node).find_children("*", "", true, false):
		if n is Label or n is Button:
			textes.append(n.text)
	check("MISE À JOUR" in textes and "Mettre à jour (0.3.0)" in textes, "la fiche propose la mise à jour : %s" % str(textes))
	check(textes.any(func(t): return "version 0.2.0" in t and "par Claude" in t), "la fiche dit la version et l'auteur : %s" % str(textes))
	carte.fermer()
	await _attendre(0.8)
	communes.installations["liguge"] = "0.3.0"
	check(communes.mise_a_jour("liguge") == "" and communes.en_attente("liguge") == "0.3.0", "téléchargée, elle attend le prochain lancement")
	communes.installations.erase("liguge")
	communes.catalogue = []
	# Ligugé est montée ; on dépose par-dessus un autre pack du même nom.
	await _attendre(1.1)
	var pk := PCKPacker.new()
	pk.pck_start(TMP + "liguge.pck")
	for f in ["commune.json", "commune.tscn", "liguge.gd", "liguge.gd"]:
		pk.add_file("res://communes/liguge/" + f, LIGUGE + f)
	pk.flush()
	check(not communes.ouvrir("liguge") and str(communes.refus[-1][1]).contains("prochain lancement"), "un pack remplacé pendant la partie attend le prochain lancement")


## Un paquet installé depuis la bienvenue ou la carte, jeu en pause, arrive quand même.
func _telechargement(communes: Node) -> void:
	var srv := TMP + "serveur/"
	DirAccess.make_dir_recursive_absolute(srv)
	DirAccess.copy_absolute(TMP + "liguge.pck", srv + "liguge.pck")
	DirAccess.remove_absolute(TMP + "liguge.pck.nouveau")
	var pid := OS.create_process("python3", ["-m", "http.server", "8765", "--bind", "127.0.0.1", "--directory", ProjectSettings.globalize_path(srv)])
	await _attendre(1.5)
	communes.catalogue = [{"insee": "86133", "id": "liguge", "nom": "Ligugé", "auteur": "Claude", "version": "0.4.0", "description": "",
		"paquet": "http://127.0.0.1:8765/liguge.pck", "taille": FileAccess.get_file_as_bytes(srv + "liguge.pck").size(),
		"sha256": FileAccess.get_sha256(srv + "liguge.pck"), "publie_le": ""}]
	var fin := [null]
	var rappel := func(id, ok, message): fin[0] = [id, ok, message]
	communes.installee.connect(rappel)
	paused = true
	communes.installer("liguge")
	for i in 40:
		if fin[0] != null:
			break
		await _attendre(0.25)
	paused = false
	communes.installee.disconnect(rappel)
	check(fin[0] != null and fin[0][1], "jeu en pause, le paquet se télécharge : %s" % str(fin[0]))
	check(FileAccess.file_exists(TMP + "liguge.pck.nouveau") and communes.en_attente("liguge") == "0.4.0", "Ligugé déjà ouverte : la 0.4.0 attend le prochain lancement")
	check(communes.etat("liguge") == "a_relancer" and (communes.geste("liguge").is_empty() or communes.geste("liguge")[0] == "Relancer maintenant"),
		"son état est « à relancer » : %s" % communes.resume("liguge"))

	# Iteuil, installée en 0.1.0 et jamais ouverte : sa 0.2.0 arrive toute seule au lancement.
	_paquet_iteuil(TMP + "iteuil.pck", "0.1.0")
	check(communes.charger_pack(TMP + "iteuil.pck") == "iteuil", "Iteuil se greffe en 0.1.0 %s" % str(communes.refus.slice(-1)))
	_paquet_iteuil(srv + "iteuil.pck", "0.2.0")
	# Vivonne, publiée et jamais installée : validée avec ses développeurs, elle arrive toute seule.
	_paquet_iteuil(srv + "vivonne.pck", "0.1.0", "vivonne", "Vivonne", "86293")
	var publie := func(id: String, version: String, fichier: String, sha := "") -> Dictionary:
		return {"insee": ({"iteuil": "86113", "vivonne": "86293"}[id] if id in ["iteuil", "vivonne"] else (communes.commune(id).insee if communes.commune(id) else "86088")), "id": id, "nom": id.capitalize(), "auteur": "Claude",
			"version": version, "description": "", "paquet": "http://127.0.0.1:8765/" + fichier,
			"taille": FileAccess.get_file_as_bytes(srv + fichier).size() if FileAccess.file_exists(srv + fichier) else 10,
			"sha256": sha if sha != "" else FileAccess.get_sha256(srv + fichier), "publie_le": ""}
	communes.catalogue = [publie.call("iteuil", "0.2.0", "iteuil.pck"), publie.call("vivonne", "0.1.0", "vivonne.pck"),
		publie.call("croutelle", "0.1.0", "absent.pck", "0".repeat(64))]
	check(communes.etat("iteuil") == "mise_a_jour" and communes.etat("croutelle") == "publiee", "Iteuil a une mise à jour, Croutelle est publiée")
	communes.call("_mettre_a_jour_seules")
	check(communes.etat("iteuil") == "telechargement" and communes.etat("vivonne") == "attente" and communes.etat("croutelle") == "attente",
		"une à la fois : Vivonne et Croutelle, publiées, attendent leur tour sans qu'on les demande")
	for i in 40:
		if communes.en_cours == "" and communes.file.is_empty():
			break
		await _attendre(0.25)
	check(communes.etat("iteuil") == "a_jour" and communes.commune("iteuil").data.version == "0.2.0" and communes.mises_a_jour_seules.has("iteuil"),
		"Iteuil s'est mise à jour toute seule : %s" % communes.resume("iteuil"))
	check(communes.etat("vivonne") == "a_jour" and communes.arrivees_seules == ["vivonne"], "Vivonne est arrivée toute seule : %s" % communes.resume("vivonne"))
	check(communes.etat("croutelle") == "echec" and communes.geste("croutelle")[0] == "Réessayer", "Croutelle a échoué, on peut réessayer : %s" % communes.resume("croutelle"))
	check(communes.a_faire() == ["liguge", "croutelle"], "à faire : Ligugé à relancer, Croutelle à réessayer : %s" % str(communes.a_faire()))
	OS.kill(pid)
	communes.installations.erase("liguge")
	communes.echecs.clear()
	communes.catalogue = []


## Un paquet d'Iteuil fait de la scène de Ligugé, à la version voulue.
func _paquet_iteuil(chemin: String, version: String, id := "iteuil", nom := "Iteuil", insee := "86113") -> void:
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LIGUGE + "commune.json"))
	m.id = id
	m.nom = nom
	m.insee = insee
	m.version = version
	m.scene = "res://communes/%s/commune.tscn" % id
	m.banque.preteur = id
	var f := FileAccess.open(TMP + id + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(m))
	f.close()
	var pk := PCKPacker.new()
	pk.pck_start(chemin)
	pk.add_file("res://communes/%s/commune.json" % id, TMP + id + ".json")
	pk.add_file("res://communes/%s/commune.tscn" % id, LIGUGE + "commune.tscn")
	pk.flush()


## Les crans du fil d'Ariane de la carte.
func _ariane(carte: CanvasLayer) -> Array:
	return (carte.get("_ariane") as Node).get_children().filter(func(n): return n is Button and not n.is_queued_for_deletion()).map(func(b): return b.text)


func _textes(boite: Node) -> Array:
	var out := []
	for n in boite.find_children("*", "", true, false):
		if (n is Label or n is Button) and not n.is_queued_for_deletion():
			out.append(n.text)
	return out


func _attendre(s: float) -> void:
	await create_timer(s, true).timeout


## Au dernier cran, un dézoom de plus annonce la carte ; avant, il ne fait que changer de cran.
func _camera() -> void:
	var cam := Camera3D.new()
	cam.set_script(load("res://scripts/orbit_camera.gd"))
	root.add_child(cam)
	var vu := [0]
	cam.au_dela.connect(func(): vu[0] += 1)
	cam.use_notches([[9.0, -48.0, 34.0], [18.0, -51.0, 30.0], [40.0, -60.0, 30.0]], 1)
	cam.distance = 18.0
	cam.set_notch(2)
	check(vu[0] == 0 and cam.notch == 2, "dézoomer jusqu'au cran quartier ne quitte pas le village")
	cam.set_notch(3)
	check(vu[0] == 0, "tant que la caméra n'est pas arrivée au cran, pas de carte")
	cam.distance = 40.0
	cam.set_notch(3)
	check(vu[0] == 1 and cam.notch == 2, "arrivé au cran quartier, un dézoom de plus ouvre la carte")
	cam.free()


func _dessin() -> void:
	var c := CarteVienne.new()
	c.interactive = true
	c.size = Vector2(1200, 800)
	root.add_child(c)
	c.size = Vector2(1200, 800)
	var lig := c.centre_de("86133")
	check(c.commune_sous(c.vers_ecran(lig)) == "86133", "un clic au centre de Ligugé désigne Ligugé")
	check(c.commune_sous(Vector2(2, 2)) == "", "un clic hors du département ne désigne rien")
	c.cadrer("86133", 4.0)
	check(c.commune_sous(c.size / 2.0) == "86133", "cadrée sur Ligugé, Ligugé est au milieu")
	var plonge := [""]
	c.plongee.connect(func(i): plonge[0] = i)
	for k in 20:
		c._zoomer(1.25, c.size / 2.0)
	check(is_equal_approx(c.zoom, CarteVienne.ZOOM_MAX) and plonge[0] == "86133", "au plus près, zoomer encore plonge dans la commune")
	c._deplacer(Vector2(100000, 100000))
	check(Rect2(Vector2.ZERO, c.size).has_point(c.foyer), "on ne peut pas faire sortir le département de l'écran")
	c.cadrer_tout()
	check(c.zoom == 1.0 and c.foyer == c.size / 2.0, "la vue d'ensemble montre tout le département")
	c.free()


## Dès le menu de départ : la carte s'ouvre sans partie, Revenir rend le menu, choisir Smarves lance le jeu.
func _titre(carte: CanvasLayer) -> void:
	change_scene_to_file("res://scenes/title.tscn")
	await _attendre(1.0)
	carte.ouvrir(true)
	await _attendre(0.3)
	var c: CarteVienne = carte.get("_carte")
	check(carte.is_open() and c.ici == "", "depuis le menu, la carte s'ouvre sans épingle : on n'est encore nulle part")
	check((carte.get("_retour") as Button).text.ends_with("Revenir au menu"), "son retour rend le menu")
	carte.fermer()
	await _attendre(0.8)
	check(not carte.is_open() and not paused and current_scene.scene_file_path == "res://scenes/title.tscn", "on retrouve le menu")
	carte.ouvrir(true)
	await _attendre(0.3)
	carte.aller("86263")
	await _attendre(1.5)
	check(current_scene.scene_file_path == "res://scenes/main.tscn" and not paused, "choisir Smarves sur la carte lance la partie")
