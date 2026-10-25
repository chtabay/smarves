extends SceneTree
## Vérifie l'allure du joueur (Avatar, docs/AVATAR.md) sans toucher à la sauvegarde :
## godot --headless --path . -s tools/test_avatar.gd
## Le code de la présence aller-retour et dans les règles de la base, la fiche retouchée (corpulence,
## sexe, vêtements), le paiement chez chaque métier, les crans de la salle de sport et du restaurant, les
## retouches qui tombent avec la tenue, l'enregistrement dans les biens, les panneaux et les boutiques.

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var G: Node = root.get_node("Game")
	var B: Node = root.get_node("Biens")
	# Chargée ici, après les autoloads : la boutique parle à Game et à Biens.
	var PR: GDScript = load("res://scripts/socle/prestation.gd")
	G.saving_enabled = false
	G.credits = 100000
	B.avatar = {}
	B.worn = ""

	# Le joueur d'origine : pas de code, la présence porte la tenue seule, comme avant.
	check(Avatar.code({}) == "" and Avatar.mot("smoking", {}) == "smoking", "le joueur d'origine n'a pas de code")
	check(Cast.moi() == Cast.player(""), "sans retouche, la fiche est celle du costume bleu nuit")

	# Le code : aller-retour, et toujours un mot que la base accepte.
	var r := {"sexe": 1, "peau": 6, "nez": 4, "taille": 2, "poids": -3, "coupe": 9, "cheveux": 0, "haut": 6,
		"couleur_haut": 5, "bas": 0, "couleur_bas": 13, "chapeau": 7, "cou": 4, "lunettes": 2}
	check(Avatar.decoder(Avatar.code(r)) == Avatar.nettoyer(r), "le code rend les mêmes réglages")
	var max := {}
	for c in Avatar.CHAMPS:
		max[c[0]] = Avatar.bornes(c[0]).y
	var re := RegEx.create_from_string("^[a-z0-9_]{0,40}$")
	for t in ["", "smoking", "haut_de_forme", "trois_pieces", "cloue/redingote", "Une Tenue"]:
		var m := Avatar.mot(t, max)
		check(re.search(m) != null, "le mot « %s » passe la règle de la base (%d lettres)" % [m, m.length()])
	check(Avatar.lire_mot(Avatar.mot("smoking", r)) == ["smoking", Avatar.nettoyer(r)], "le mot se relit en tenue et réglages")
	check(Avatar.decoder("zzzz").is_empty() and Avatar.decoder("a~~").is_empty(), "un code abîmé rend le joueur d'origine")
	check(Avatar.nettoyer({"poids": 99, "sexe": 1, "inconnu": 3}) == {"sexe": 1}, "les réglages hors bornes ou inconnus tombent")

	# La fiche retouchée.
	var gros := Avatar.fiche("", {"poids": 4})
	var mince := Avatar.fiche("", {"poids": -3})
	check(float(gros.build.belly) > 1.4 and float(mince.build.belly) < 0.9, "la corpulence change le ventre")
	check(float(gros.build.width) > float(mince.build.width), "et la carrure")
	var femme := Avatar.fiche("smoking", {"sexe": 1, "pilosite": 2, "coupe": 7})
	check(femme.has("lip") and not "moustache" in femme.face and femme.hair == "carre", "une femme : du rouge, pas de moustache, sa coupe")
	check(femme.top == "smoking", "elle garde la tenue achetée")
	var jupe := Avatar.fiche("dimanche", {"bas": 1, "couleur_bas": 5})
	check(jupe.get("skirt", false) and not jupe.has("legs") and jupe.skirt_color == Avatar.COULEURS[5][0], "la jupe remplace le pantalon")
	var chapeau := Avatar.fiche("haut_de_forme", {"chapeau": 0})
	check(chapeau.hat == "", "on peut ôter le chapeau d'une tenue")
	check(Avatar.fiche("haut_de_forme", {"cou": 1}).hat == "haut_de_forme", "un réglage d'à côté ne l'ôte pas")
	var autre := Cast.player(Avatar.mot("smoking", {"peau": 7, "poids": 3}))
	check(autre.fur == Avatar.PEAUX[7][0] and autre.top == "smoking" and float(autre.build.belly) > 1.3, "un autre joueur se voit tel qu'il s'est fait retoucher")
	check(Cast.player("smoking") == Cast.NAMED.joueur.merged(Cast.PLAYER_OUTFITS.smoking, true), "un ancien mot reste la tenue seule")

	# Les prix : seuls les champs changés comptent, au tarif.
	check(Avatar.prix("coiffure", {}, {"coupe": 3, "cheveux": 2}) == 150, "coupe et couleur chez Gisèle : 150")
	check(Avatar.prix("coiffure", {}, {"coupe": 3, "peau": 2}) == 60, "le teint ne se paie pas chez la coiffeuse")
	check(Avatar.prix("chirurgie", {}, Avatar.avec_visage({}, 10), 1.5) == 4500, "un autre visage chez un chirurgien plus cher de moitié : 4 500")
	check(Avatar.prix("chirurgie", {}, {"coupe": 3}) == 0, "la coupe ne se paie pas chez le chirurgien")
	check(Avatar.visage({}) == 0, "le joueur d'origine a le premier visage de l'album")
	var fatale := Avatar.avec_visage({"pilosite": 2, "coupe": 1}, 10)
	check(Avatar.visage(fatale) == 10 and Avatar.valeur(fatale, "pilosite") == 0 and Avatar.valeur(fatale, "coupe") >= 6,
		"la femme fatale : son sexe, son teint, son nez ; plus de barbe, une coupe qui lui va")
	var vus := {}
	for v in Avatar.VISAGES:
		vus["%d/%d/%d" % [v[1], v[2], v[3]]] = true
	check(vus.size() == Avatar.VISAGES.size(), "les %d visages de l'album sont tous différents" % Avatar.VISAGES.size())

	# Payer, et ce que ça fait aux biens.
	var credits: int = G.credits
	check(B.relooker({"coupe": 3}, 60) and G.credits == credits - 60 and B.avatar == {"coupe": 3}, "on paie et on garde la coupe")
	check(B.apparence() == Avatar.mot("", {"coupe": 3}) and Cast.moi().hair == "gomina", "la présence et la fiche la portent")
	G.credits = 10
	check(not B.relooker({"coupe": 4}, 60) and B.avatar == {"coupe": 3}, "sans les crédits, rien ne change")
	G.credits = 100000
	check(B.corpulence(2, 110) and Avatar.valeur(B.avatar, "poids") == 2, "le menu complet : deux crans de plus")
	check(B.corpulence(9, 260) and Avatar.valeur(B.avatar, "poids") == Avatar.POIDS_MAX, "le restaurant s'arrête à très rond")
	check(B.corpulence(-3, 1200) and Avatar.valeur(B.avatar, "poids") == 1, "le coach particulier : trois crans de moins")
	B.relooker(B.avatar.merged({"couleur_haut": 3, "chapeau": 2, "lunettes": 1}, true), 0)
	G.credits += 300
	B.buy("dimanche")
	check(not B.avatar.has("couleur_haut") and B.avatar.get("chapeau", -1) == 2 and B.avatar.get("lunettes", -1) == 1,
		"une nouvelle tenue efface les retouches du haut, garde le chapeau et les lunettes")

	# L'enregistrement : les retouches partent avec les biens (et donc avec le compte).
	var f := FileAccess.open("user://test_avatar_biens.save", FileAccess.WRITE)
	f.store_string(JSON.stringify({"avatar": B.avatar}))
	f.close()
	var relu = JSON.parse_string(FileAccess.get_file_as_string("user://test_avatar_biens.save"))
	check(Avatar.nettoyer(relu.avatar) == B.avatar, "les réglages se relisent du fichier (nombres JSON)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_avatar_biens.save"))
	var src := FileAccess.get_file_as_string("res://scripts/biens.gd")
	check(src.contains("\"avatar\": avatar") and src.contains("avatar = Avatar.nettoyer(data.get(\"avatar\""), "les biens écrivent et relisent l'avatar")

	# L'arrivée : six visages et six tenues, offerts, seulement pour une partie pas encore accueillie.
	check(Avatar.VISAGES_ARRIVEE.size() == 6 and Avatar.TENUES_ARRIVEE.size() == 6, "l'arrivée propose six visages et six tenues")
	check(Avatar.arrivee(0, 0).is_empty(), "le premier visage et la première tenue : le joueur d'origine")
	var allures := {}
	for vi in 6:
		for ti in 6:
			var a := Avatar.arrivee(vi, ti)
			allures[Avatar.code(a)] = true
			check(Avatar.visage(a) == Avatar.VISAGES_ARRIVEE[vi], "visage %d, tenue %d : un visage de l'album" % [vi, ti])
			check(re.search(Avatar.mot("", a)) != null, "visage %d, tenue %d : un mot que la base accepte" % [vi, ti])
	check(allures.size() == 36, "les trente-six allures sont toutes différentes")
	var dame := Avatar.fiche("", Avatar.arrivee(4, 4))
	check(dame.has("lip") and dame.top == "robe", "la femme fatale en robe bordeaux")
	B.avatar = {}
	G.credits = 500
	var AP: GDScript = load("res://scripts/socle/arrivee_panel.gd")
	var arr: PanelContainer = AP.new()
	var ferme := [false]
	arr.closed.connect(func(): ferme[0] = true)
	root.add_child(arr)
	await process_frame
	check(arr.find_child("Visages", true, false).get_child_count() == 6 and arr.find_child("Tenues", true, false).get_child_count() == 6,
		"le panneau d'arrivée montre six visages et six tenues")
	arr.choisir_visage(3)
	arr.choisir_tenue(2)
	check(B.avatar.is_empty(), "essayer à l'arrivée ne change rien tant qu'on n'entre pas")
	arr.entrer_a_smarves()
	check(ferme[0] and B.avatar == Avatar.arrivee(3, 2) and G.credits == 500, "en entrant, l'allure est gardée, sans rien payer")
	arr.queue_free()
	var main_src := FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main_src.contains("if not Game.welcomed") and main_src.contains("_arrivee()"), "l'arrivée ne s'ouvre qu'à une partie pas encore accueillie")
	B.avatar = {}
	G.credits = 100000

	# Les panneaux : un par métier, qui se construit, et dont les essais se paient.
	for metier in Avatar.METIERS:
		var p: PanelContainer = PR.panneau(metier, {"tenancier": "Essai"})
		root.add_child(p)
		await process_frame
		check(p.get_child_count() > 0, "le panneau « %s » se construit" % metier)
		if Avatar.METIERS[metier].has("visages"):
			p.choisir_visage(5)
			check(Avatar.visage(p._essai) == 5 and p.prix_essai() == 3000, "« chirurgie » : un visage de l'album coûte 3 000")
			p.changer_visage(1)
			check(Avatar.visage(p._essai) == 6, "« chirurgie » : la flèche passe au visage suivant")
			p.choisir_visage(Avatar.VISAGES.size() - 1)
			p.changer_visage(1)
			check(Avatar.visage(p._essai) == 0, "« chirurgie » : et l'album tourne en boucle")
			p.choisir_visage(Avatar.visage(B.avatar))
			check(p.prix_essai() == 0, "« chirurgie » : reprendre le sien ne coûte rien")
		elif Avatar.METIERS[metier].has("champs"):
			var champ: String = p.champs()[0]
			var avant := Avatar.valeur(B.avatar, champ)
			p.essayer(champ, 1)
			check(p.prix_essai() == Avatar.prix_champ(metier, champ), "« %s » : essayer %s coûte son prix" % [metier, champ])
			p.essayer(champ, -1)
			check(p.prix_essai() == 0 and Avatar.valeur(p._essai, champ) == avant, "« %s » : revenir en arrière ne coûte rien" % metier)
		else:
			check(p.formules().size() == 3, "« %s » : trois formules" % metier)
		p.queue_free()
	var chez_tonio: PanelContainer = PR.panneau("restaurant", {"tarif": 2.0, "formules": [{"nom": "La galette", "prix": 15, "poids": 1}]})
	root.add_child(chez_tonio)
	await process_frame
	check(chez_tonio.formules() == [{"id": "La galette", "nom": "La galette", "poids": 1, "prix": 30, "dit": ""}], "une commune donne ses formules et son tarif")
	chez_tonio.queue_free()

	# Les boutiques de Smarves : leur tenancier a sa fiche, leur porte existe sur la place.
	for id in PR.SMARVES:
		var m: Dictionary = PR.SMARVES[id]
		check(Cast.NAMED.has(str(m.who)) and Avatar.METIERS.has(str(m.metier)), "%s : métier connu, %s a sa fiche" % [m.nom, m.tenancier])
	var village: GDScript = load("res://scripts/village/village.gd")
	for porte in village.PRESTATIONS:
		check(PR.SMARVES.has(village.PRESTATIONS[porte]), "la porte « %s » mène à une maison" % porte)
	G.won = 0
	check(not PR.smarves("chirurgie"), "le docteur Maupas attend 3 000 crédits gagnés")
	check(PR.ouvrir("inconnu") == false, "un métier inconnu n'ouvre rien")

	B.avatar = {}
	B._vider()
	print("\n%s" % ("Tout est bon." if fails == 0 else "%d échec(s)." % fails))
	quit(1 if fails > 0 else 0)
