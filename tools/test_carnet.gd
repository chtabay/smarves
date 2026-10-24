extends SceneTree
## Vérifie le carnet du joueur sans affichage : godot --headless --path . -s tools/test_carnet.gd
## Les rubriques et la liste des villages (la commune d'origine, les communes à compteurs), la vérification
## du champ « carnet » d'un manifeste, Carnet.noter (ce qu'il refuse, ce qu'il range), la page d'une
## commune lue de partout, même retirée, et la section relue par la sauvegarde du socle.

const SAUVEGARDE := preload("res://scripts/socle/sauvegarde.gd")
const DIR := "user://test_carnet/"
const COMPTEURS := [
	{"id": "parts_moulin", "libelle": "Parts du moulin", "genre": "nombre", "rubrique": "Mes affaires"},
	{"id": "caisse", "libelle": "Dans la caisse du café", "genre": "credits", "rubrique": "Mes affaires"},
	{"id": "surnom", "libelle": "Au club de pétanque", "genre": "texte"},
	{"id": "carte_peche", "libelle": "Carte de pêche", "genre": "case"},
]

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	var carnet: Node = root.get_node("Carnet")
	var communes: Node = root.get_node("Communes")
	game.saving_enabled = false
	game.carnet = {}

	# La vérification du manifeste, avec les phrases que le portail reprend.
	check(Commune.verifier_carnet(null).is_empty(), "sans champ « carnet », rien à redire")
	check(Commune.verifier_carnet(COMPTEURS).is_empty(), "quatre compteurs bien formés passent")
	check(Commune.verifier_carnet({"a": 1}) == PackedStringArray(["carnet doit être une liste de compteurs"]), "un objet à la place d'une liste est refusé")
	var mauvais := Commune.verifier_carnet([{"id": "a"}, {"id": "Grand", "libelle": "x", "genre": "nombre"},
		{"id": "b", "libelle": "x", "genre": "nombre"}, {"id": "b", "libelle": "y", "genre": "monnaie"},
		{"id": "c", "libelle": "x".repeat(61), "genre": "case", "rubrique": 3}])
	check(mauvais.has("carnet : compteur incomplet (id, libelle, genre) : { \"id\": \"a\" }"), "compteur incomplet")
	check(mauvais.has("carnet : id invalide : « Grand » (minuscules, chiffres, _)"), "id en majuscules")
	check(mauvais.has("carnet : compteur en double : b"), "compteur en double")
	check(mauvais.has("carnet : genre inconnu pour b : « monnaie » (nombre, credits, texte, case)"), "genre inconnu")
	check(mauvais.has("carnet : libelle de c trop long (60 caractères au plus)"), "libellé trop long")
	check(mauvais.has("carnet : rubrique de c doit être un texte"), "rubrique qui n'est pas un texte")
	var trop: Array = []
	for i in 25:
		trop.append({"id": "c%d" % i, "libelle": "x", "genre": "nombre"})
	check(Commune.verifier_carnet(trop).has("carnet : 24 compteurs au plus"), "25 compteurs, c'est trop")

	# Les cinq rubriques, fixes ; les villages sont une liste, Smarves d'abord.
	var cles: Array = carnet.onglets().map(func(o): return o[0])
	check(cles == ["boite", "clubs", "biens", "carriere", "villages"], "les rubriques : Boîte, Mes clubs, Mes biens, Ma carrière, Les villages (%s)" % str(cles))
	cles = carnet.villages().map(func(o): return o[0])
	check(cles == ["smarves"], "un seul village au carnet : Smarves (%s)" % str(cles))

	# Une commune d'essai qui tient quatre compteurs.
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/commune_essai/commune.json"))
	m.carnet = COMPTEURS
	var c := Commune.depuis_texte(JSON.stringify(m), "user://communes/essai/commune.json", "user://essai.pck")
	check(c.valide(), "la commune d'essai et ses compteurs se valident (%s)" % "; ".join(c.erreurs))
	check(communes.inscrire(c), "la commune d'essai s'inscrit")
	cles = carnet.villages().map(func(o): return o[0])
	check(cles == ["smarves", "essai"] and carnet.onglets().size() == 5, "elle a sa page dans Les villages, après Smarves ; les rubriques ne bougent pas")

	# Ailleurs que chez elle, elle n'écrit rien.
	check(not carnet.noter("essai", "parts_moulin", 2), "hors de la commune, noter est refusé")
	check(str(communes.refus[-1][1]).contains("que chez elle"), "et la raison est dite")
	# Chez elle : la scène ouverte est la sienne.
	var scene := Node.new()
	scene.scene_file_path = str(m.scene)
	root.add_child(scene)
	current_scene = scene
	check(communes.actuelle() == "essai", "le joueur est dans la commune d'essai")
	check(not carnet.noter("essai", "inconnu", 1), "une clé non déclarée est refusée")
	check(not carnet.noter("smarves", "parts_moulin", 1), "une commune n'écrit pas dans la section d'une autre")
	check(not carnet.noter("essai", "parts_moulin", "deux"), "un texte pour un nombre est refusé")
	check(not carnet.noter("essai", "carte_peche", 1), "un nombre pour une case est refusé")
	check(carnet.noter("essai", "parts_moulin", 2.0), "un nombre entier, même écrit 2.0, est noté")
	check(carnet.noter("essai", "caisse", 1250), "des crédits sont notés")
	check(carnet.noter("essai", "surnom", "le pointeur du dimanche ".repeat(5)), "un texte est noté")
	check(carnet.noter("essai", "carte_peche", true), "une case est notée")
	check(carnet.lire("essai", "parts_moulin") == 2 and typeof(carnet.lire("essai", "parts_moulin")) == TYPE_INT, "la valeur se relit, en entier")
	check(str(carnet.lire("essai", "surnom")).length() == Commune.CARNET_TEXTE_MAX, "un texte trop long est coupé à 80 caractères")
	var s: Dictionary = game.carnet.essai
	check(s.nom == "La commune d'essai" and (s.compteurs as Array).size() == 4 and int(s.vu) > 0, "la section garde le nom, la déclaration et la date du passage")

	# La page de la commune, chez elle.
	carnet.toggle()
	carnet.ouvrir_onglet("essai")
	await process_frame
	var g := _texte(carnet.get("_left"))
	check(g.contains("La commune d'essai") and g.contains("Vous y êtes"), "sa page dit qu'on y est")
	check(g.contains("Mes affaires") and g.contains("Parts du moulin\n2") and g.contains("1 250") and g.contains("Carte de pêche\noui"), "les compteurs s'écrivent selon leur genre")

	# Revenu à Smarves : la page se lit encore, avec la date du dernier passage.
	current_scene = null
	scene.queue_free()
	carnet.ouvrir_onglet("essai")
	await process_frame
	g = _texte(carnet.get("_left"))
	check(g.contains("Noté à votre dernier passage") and g.contains("1 250"), "de Smarves, la page se lit, datée du dernier passage")

	# Mon compte : la fortune nette tient les crédits, les biens et les dettes, par banque.
	game.debts = {"smarves": 300, "essai": 120}
	carnet.ouvrir_onglet("compte")
	await process_frame
	g = _texte(carnet.get("_left"))
	check(g.contains("Dette au Crédit Smarvois\n-300") and g.contains("Dette à la caisse d'essai\n-120"), "une ligne de dette par banque, au nom de sa banque")
	check(carnet.fortune_nette() == game.credits + root.get_node("Biens").value() - 420, "fortune nette : crédits, biens, moins les dettes")
	check(g.contains("Fortune nette\n" + game.fmt(carnet.fortune_nette())), "et elle s'écrit en bas des comptes")
	check(_texte(carnet.get("_right")).contains("Mes engagements"), "en face, la semaine et les engagements")
	game.debts = {}

	# Chaque rubrique et chaque page se remplit sans erreur, et les flèches passent d'une rubrique à l'autre.
	for o in carnet.onglets() + carnet.villages() + [["cartes", "Mes cartes"], ["vienne", "La Vienne"]]:
		carnet.ouvrir_onglet(o[0])
		await process_frame
		check(_texte(carnet.get("_album") if o[0] == "cartes" else carnet.get("_left")) != "", "la page « %s » se remplit" % o[1])
	check(carnet.get("_onglet") == "vienne" and carnet.rubrique() == "villages", "La Vienne est une page des villages")
	carnet.tourner(1)
	check(carnet.get("_onglet") == "boite", "après Les villages, on revient à la boîte")
	carnet.tourner(-1)
	check(carnet.get("_onglet") == "villages", "et dans l'autre sens")
	# La liste des villages se filtre en tapant un nom.
	var champ: LineEdit = carnet.get("_left").find_child("Recherche", true, false)
	check(champ != null and carnet.get("_left").find_child("Village_essai", true, false) != null and carnet.get("_left").find_child("Village_smarves", true, false) != null, "la liste montre Smarves et la commune d'essai")
	champ.text_changed.emit("essai")
	await process_frame
	var liste: Array = carnet.get("_left").find_children("Village_*", "Button", true, false).filter(func(b): return not b.is_queued_for_deletion())
	check(liste.size() == 1 and liste[0].name == "Village_essai", "« essai » ne laisse que la commune d'essai")
	liste[0].pressed.emit()
	await process_frame
	check(carnet.get("_onglet") == "essai" and carnet.rubrique() == "villages" and carnet.get("_left").find_child("Retour", true, false) != null, "un clic ouvre sa page, avec le retour à la liste")
	check(carnet.get("_onglets").find_child("Page_essai", true, false) != null, "et elle s'ajoute sous Les villages, dans la barre")
	carnet.set("_recherche", "")
	carnet.toggle()

	# La section part avec le socle et se relit ; la commune retirée garde sa page.
	DirAccess.make_dir_recursive_absolute(DIR)
	SAUVEGARDE.ecrire(game, DIR)
	game.carnet = {}
	SAUVEGARDE.charger(game, DIR)
	check(game.carnet.has("essai") and int(game.carnet.essai.valeurs.caisse) == 1250, "la page de la commune se relit de la sauvegarde du socle")
	communes.communes.erase("essai")
	communes.ordre.erase("essai")
	cles = carnet.villages().map(func(o): return o[0])
	check(cles.has("essai"), "désinstallée, la commune garde sa page, de sa copie de la déclaration")
	check(carnet._compteurs("essai").size() == 4, "la copie suffit à dessiner la page")
	SAUVEGARDE.effacer(DIR)
	game.carnet = {}

	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


func _texte(n: Node) -> String:
	var out := ""
	for c in n.get_children():
		if c.is_queued_for_deletion():
			continue
		if c is Label or c is Button:
			out += c.text + "\n"
		out += _texte(c)
	return out
