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
	await _titre(carte)
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


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
