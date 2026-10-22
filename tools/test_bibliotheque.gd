extends SceneTree
## Vérifie la bibliothèque commune et le contrat d'ancres du stade, sans affichage :
## godot --headless --path . -s tools/test_bibliotheque.gd
## Chaque brique du catalogue se résout et sa scène existe ; chaque stade de la bibliothèque tient le contrat
## d'ancres ; le manifeste accepte « modele » ; et le stade d'une commune dont le terrain nomme
## « stade-de-campagne@1 » reçoit le club, le match, le tableau, le président, le bureau, le panneau et la sortie.

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _interactions(n: Node) -> Dictionary:
	var out := {}
	for a in n.find_children("*", "Area3D", true, false):
		var k := str(a.get_meta("interact", ""))
		if k != "":
			out[k] = a
	return out


func _init() -> void:
	await process_frame
	var game: Node = root.get_node("Game")
	var foot: Node = root.get_node("Football")
	var registre: Node = root.get_node("Registre")
	game.saving_enabled = false
	game.welcomed = true
	foot.dossier = ""

	# Le catalogue : des références « id@version », chacune vers une scène qui existe.
	check(Bibliotheque.est_reference("stade-de-campagne@1") and not Bibliotheque.est_reference("stade-de-campagne")
		and not Bibliotheque.est_reference("Stade@1") and not Bibliotheque.est_reference("stade@0") and not Bibliotheque.est_reference("-x@1"),
		"une référence s'écrit « id@version »")
	var refs := Bibliotheque.references()
	check(refs.size() >= 1 and "stade-de-campagne@1" in refs, "la bibliothèque a ses briques : %s" % ", ".join(refs))
	for ref in refs:
		var b := Bibliotheque.brique(ref)
		check(str(b.get("nom", "")) != "" and str(b.get("auteur", "")) != "" and str(b.get("licence", "")) != ""
			and ResourceLoader.exists(str(b.get("scene", ""))), "%s : un nom, un auteur, une licence, une scène" % ref)
	check(Bibliotheque.brique("stade-de-campagne@2").is_empty() and Bibliotheque.brique("inconnu@1").is_empty(), "une version ou une brique inconnue ne se résout pas")
	check(Bibliotheque.scene("stade-de-campagne@1", "gymnase") == "", "une brique ne sert que pour son genre")

	# Chaque stade de la bibliothèque tient le contrat d'ancres.
	for ref in Bibliotheque.references("stade"):
		var n: Node3D = load(Bibliotheque.scene(ref, "stade")).instantiate()
		root.add_child(n)
		check(Ancres.verifier_stade(n).is_empty(), "%s tient le contrat du stade %s" % [ref, str(Ancres.verifier_stade(n))])
		n.queue_free()
	# Un décor sans ses ancres est refusé, une pelouse déplacée aussi.
	var vide := Node3D.new()
	check(Ancres.verifier_stade(vide).size() == 7, "un décor sans ancres : les sept ancres requises manquent")
	var m := Marker3D.new()
	m.name = "Pelouse"
	m.position = Vector3(5, 0, 0)
	vide.add_child(m)
	check(Ancres.verifier_stade(vide).size() == 7 and Ancres.verifier_stade(vide)[-1].contains("origine"), "une pelouse hors de l'origine est refusée")
	vide.free()

	# Une commune propose une brique : son dossier bibliotheque/<id>/ et sa fiche ; Guillaume l'intègre à la main.
	var props := Bibliotheque.propositions("res://tools/fixtures/proposition/")
	check(props.size() == 1 and props[0].id == "stade-des-essais" and props[0].erreurs.is_empty(), "la brique proposée se lit avec sa fiche : %s" % str(props.map(func(x): return [x.id, x.erreurs])))
	check(Bibliotheque.verifier_fiche({"genre": "fusee", "nom": "x", "auteur": "a", "licence": "l", "scene": "../x.tscn", "prix": 3}, "Fusee", "res://nulle/part/").size() == 4,
		"une fiche fautive : id, genre, champ inconnu, scène hors du dossier")
	var integrer = load("res://tools/integrer_brique.gd")
	var racine := "user://biblio_essai/"
	DirAccess.make_dir_recursive_absolute(racine)
	var cat := racine + "bibliotheque.json"
	DirAccess.remove_absolute(cat)
	var r1: Dictionary = integrer.integrer("essai", "stade-des-essais", "res://tools/fixtures/proposition/", racine, cat)
	check(r1.get("version") == 1 and r1.scene == racine + "stade-des-essais/1/stade.tscn", "la brique entre en version 1 : %s" % str(r1))
	var tscn := FileAccess.get_file_as_string(racine + "stade-des-essais/1/stade.tscn")
	check(tscn.contains(racine + "stade-des-essais/1/stade.gd") and not tscn.contains("res://communes/"), "ses chemins sont ceux de la bibliothèque")
	check(not FileAccess.file_exists(racine + "stade-des-essais/1/brique.json"), "la fiche passe au catalogue, pas dans le dossier")
	var lu: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(cat))
	var b: Dictionary = lu.briques.get("stade-des-essais", {})
	check(b.get("auteur") == "Le kit des communes" and b.get("commune") == "essai" and b.get("licence") == "CC0" and b.versions.has("1"), "le catalogue garde le crédit de l'auteur et de sa commune")
	var integree: Node3D = load(r1.scene).instantiate()
	root.add_child(integree)
	check(Ancres.verifier_stade(integree).is_empty(), "le stade intégré tient le contrat")
	integree.queue_free()
	var r2: Dictionary = integrer.integrer("essai", "stade-des-essais", "res://tools/fixtures/proposition/", racine, cat)
	check(r2.get("version") == 2 and FileAccess.file_exists(racine + "stade-des-essais/1/stade.tscn"), "une nouvelle proposition fait une version 2, la 1 reste")
	lu.briques["stade-des-essais"].auteur = "Quelqu'un d'autre"
	FileAccess.open(cat, FileAccess.WRITE).store_string(JSON.stringify(lu))
	check(integrer.integrer("essai", "stade-des-essais", "res://tools/fixtures/proposition/", racine, cat).has("erreur"), "un nom déjà pris par un autre auteur est refusé")
	check(integrer.integrer("essai", "inconnue", "res://tools/fixtures/proposition/", racine, cat).has("erreur"), "une brique non proposée est refusée")
	Bibliotheque._catalogue = {}

	# Le manifeste : « modele » nomme une brique ou une scène de la commune, jamais les deux avec « scene ».
	var base := {"type": "terrain_foot", "id": "stade", "nom": "Le stade", "club": "Le club"}
	var ok := base.duplicate()
	ok.modele = "stade-de-campagne@1"
	check(Structures.verifier([ok]).is_empty(), "« modele » : une brique de la bibliothèque")
	var maison := base.duplicate()
	maison.modele = "res://communes/essai/stade.tscn"
	check(Structures.verifier([maison]).is_empty(), "« modele » : une scène de la commune")
	var inconnu := base.duplicate()
	inconnu.modele = "stade-de-campagne@9"
	check(Structures.verifier([inconnu]).size() == 1, "une version inconnue est refusée : %s" % str(Structures.verifier([inconnu])))
	var ailleurs := base.duplicate()
	ailleurs.modele = "res://scenes/stade.tscn"
	check(Structures.verifier([ailleurs]).size() == 1, "une scène hors de la commune est refusée")
	var deux := ok.duplicate()
	deux.scene = "res://communes/essai/stade.tscn"
	check(Structures.verifier([deux]).size() == 1, "« scene » et « modele » ensemble sont refusés")

	# Le stade de la commune d'essai, sur le décor de campagne : le club s'y branche par les ancres.
	var t5: int = foot.coup_envoi(1, 5) + 3600
	foot.regler_horloge(func(): return t5)
	load("res://tools/essai.gd").greffer(root)
	foot.actualiser()
	var e: Dictionary = registre.structure("essai/stade")
	e.champs.modele = "stade-de-campagne@1"
	game.won = 3000
	load("res://scripts/village/stade.gd").prochaine_commune = "essai"
	change_scene_to_file("res://scenes/stade.tscn")
	await create_timer(1.5).timeout
	var stade: Node = current_scene
	check(stade._modele != null and stade.get_node_or_null("Modele") != null, "le décor de la bibliothèque est posé")
	check(stade._club == "essai" and stade._acteurs.size() == 22 and "essai" in [stade._rencontre.dom, stade._rencontre.ext], "le club de la commune y joue son match de la journée 5")
	check(stade._horloge.text.begins_with("Journée 5") and stade._score.text.contains("-"), "le tableau du décor suit le match : %s" % stade._horloge.text)
	var it := _interactions(stade)
	for k in ["exit", "president", "bureau", "panneau", "feuille", "buvette"]:
		check(it.has(k), "le socle a posé « %s » sur son ancre" % k)
	check(not it.has("locaux") and not it.has("sortir_siege"), "pas de siège à part : la gestion est au bureau du décor")
	var bureau: Node3D = Ancres.trouver(stade._modele, "Bureau")
	check(it.has("bureau") and (it.bureau.get_parent() as Node3D).global_position.distance_to(bureau.global_position) < 0.01, "le bureau est à l'ancre du décor")
	var pres: Node3D = Ancres.trouver(stade._modele, "President")
	check(stade._president.global_position.distance_to(pres.global_position) < 0.01, "le président se tient à son ancre")
	var arrivee: Node3D = Ancres.trouver(stade._modele, "Arrivee")
	check(stade.player.global_position.distance_to(arrivee.global_position) < 0.5, "le visiteur paraît à l'ancre d'arrivée")
	check(str(it.exit.get_meta("prompt")) == "E : sortir du stade" and stade._lot() == "stade", "la sortie ramène à la porte du terrain")
	var textes: Array = stade.find_children("*", "Label3D", true, false).map(func(l): return l.text)
	check("UNION SPORTIVE D'ESSAI  ·  STADE D'ESSAI" in textes, "le fronton de la tribune porte le club et le stade")
	check(not ("LE SIÈGE DU CLUB" in textes) and not ("BUVETTE" in textes), "rien du décor du socle n'est posé par-dessus")
	var avant: int = stade._panel_layer.get_child_count()
	stade._on_interact(it.bureau)
	await process_frame
	var page: Node = stade._panel_layer.get_child(-1) if stade._panel_layer.get_child_count() > avant else null
	check(page != null and str(page.get("club")) == "essai", "le bureau du décor ouvre la gestion du club")
	if page:
		page.closed.emit()
	await process_frame
	stade._on_interact(it.president)
	check(stade._causerie != null and stade._causerie.club == "essai", "le président du décor ouvre la causerie du club")

	# Un décor qui ne tient pas le contrat : le stade du socle prend sa place.
	e.champs.modele = "stade-de-campagne@7"
	load("res://scripts/village/stade.gd").prochaine_commune = "essai"
	change_scene_to_file("res://scenes/stade.tscn")
	await create_timer(1.0).timeout
	stade = current_scene
	check(stade._modele == null and _interactions(stade).has("locaux") and stade._supporters.size() > 10, "un décor introuvable : c'est le stade du socle")
	e.champs.erase("modele")

	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
