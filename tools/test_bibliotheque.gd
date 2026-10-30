extends SceneTree
## Vérifie la bibliothèque commune et les contrats d'ancres du stade et de la salle, sans affichage :
## godot --headless --path . -s tools/test_bibliotheque.gd
## Chaque brique du catalogue se résout et sa scène existe ; chaque stade de la bibliothèque tient le contrat
## d'ancres ; le manifeste accepte « modele » ; et le stade d'une commune dont le terrain nomme
## « stade-de-campagne@1 » reçoit le club, le match, le tableau, le président, le bureau, le panneau et la sortie ;
## la salle de Smarves sur « salle-de-quartier@1 », le club, le cube, le président, le bureau, les parts et le car ;
## les matières de « matieres-de-minuit@1 » se posent par leur nom (socle 1.17) ; le façadier « facadier-du-poitou@1 »
## bâtit ses dix types ; chaque décor se bâtit seul (le donjon en ruine, l'église romane) ; les arbres, le mobilier
## et le façadier de la place du nord se bâtissent par leur nom, comme les quatre briques du décor lyonnais
## et celles du décor du Bugey.

var fails := 0


const Notaire := preload("res://scripts/socle/notaire.gd")


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
		var fichier := str(b.get(Bibliotheque.champ_fichier(str(b.get("genre", ""))), ""))
		check(str(b.get("nom", "")) != "" and str(b.get("auteur", "")) != "" and str(b.get("licence", "")) != ""
			and (ResourceLoader.exists(fichier) or FileAccess.file_exists(fichier)), "%s : un nom, un auteur, une licence, %s" % [ref, fichier])
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
	# Chaque salle de la bibliothèque tient le contrat de la salle (socle 1.14) ; un parquet déplacé est refusé.
	check(Bibliotheque.references("salle").size() >= 1, "la bibliothèque a une salle de basket : %s" % ", ".join(Bibliotheque.references("salle")))
	for ref in Bibliotheque.references("salle"):
		var n: Node3D = load(Bibliotheque.scene(ref, "salle")).instantiate()
		root.add_child(n)
		check(Ancres.verifier_salle(n).is_empty(), "%s tient le contrat de la salle %s" % [ref, str(Ancres.verifier_salle(n))])
		check(Ancres.verifier_stade(n).size() > 0 and Bibliotheque.scene(ref, "stade") == "", "%s n'est pas un stade" % ref)
		n.queue_free()
	var vide_salle := Node3D.new()
	check(Ancres.verifier_salle(vide_salle).size() == 8, "une salle sans ancres : les huit ancres requises manquent")
	var mp := Marker3D.new()
	mp.name = "Parquet"
	mp.rotation.y = 0.5
	vide_salle.add_child(mp)
	check(Ancres.verifier_salle(vide_salle)[-1].contains("« Parquet » doit être à l'origine"), "un parquet tourné est refusé")
	vide_salle.free()

	# Les matières (socle 1.17) : chaque brique de matières tient sa fiche, chaque matière son image.
	check("matieres-de-minuit@1" in Bibliotheque.references("matieres"), "la bibliothèque a les matières de Minuit")
	for ref in Bibliotheque.references("matieres"):
		var chemin := str(Bibliotheque.brique(ref).matieres)
		var fautes := Bibliotheque.verifier_matieres(JSON.parse_string(FileAccess.get_file_as_string(chemin)), chemin.get_base_dir())
		check(fautes.is_empty(), "%s : ses matières se tiennent %s" % [ref, str(fautes)])
		for nom in Bibliotheque.matieres(ref):
			var t := Bibliotheque.texture(ref, nom)
			check(t != null and t.get_width() >= 256, "%s : « %s » a son image (%s)" % [ref, nom, str(t.get_size()) if t else "aucune"])
	var minuit := Bibliotheque.matieres("matieres-de-minuit@1")
	check(minuit.size() == 19, "les dix-neuf matières de la DA de Minuit : %s" % ", ".join(minuit.keys()))
	# Minuit les prend dans la bibliothèque (socle 1.17) : son kit les nomme, et son décor n'en garde aucune copie.
	# (Le chemin est coupé pour que le SDK, qui n'a pas Minuit, ne l'emporte pas.)
	var minuit_essai := "res://tools" + "/paquet_essai/casino_minuit/"
	if ResourceLoader.exists(minuit_essai + "kit.gd"):
		var kit = load(minuit_essai + "kit.gd")
		var prises := 0
		for nom in kit.DA_TEX:
			if minuit.has(nom) and kit.tex_da(nom) == Bibliotheque.texture("matieres-de-minuit@1", nom):
				prises += 1
		check(prises == kit.DA_TEX.size() and prises == 19, "Minuit prend ses matières dans la bibliothèque (%d / %d)" % [prises, kit.DA_TEX.size()])
		var copies := {}
		for nom in minuit:
			copies[FileAccess.get_md5(minuit[nom].image)] = nom
		var restent := Array(DirAccess.get_files_at(minuit_essai + "decor/tex/")).filter(func(f): return f.ends_with(".png") and copies.has(FileAccess.get_md5(minuit_essai + "decor/tex/" + f)))
		check(restent.is_empty(), "le décor de Minuit n'en garde aucune copie %s" % str(restent))
	var marbre := Bibliotheque.matiere("matieres-de-minuit@1", "marbre_noir")
	check(marbre != null and marbre.shader.resource_path == Bibliotheque.SHADER_MATIERE and marbre.get_shader_parameter("dalle") == Vector2(2, 2)
		and is_equal_approx(marbre.get_shader_parameter("rugosite"), 0.25) and is_equal_approx(marbre.get_shader_parameter("metal"), 0.05),
		"une matière se pose par son nom, avec les réglages de la brique")
	var teint := Bibliotheque.matiere("matieres-de-minuit@1", "marbre_creme", {"teinte": Color(0.6, 0.57, 0.55), "dalle": Vector2(4, 4)})
	check(teint.get_shader_parameter("teinte") == Color(0.6, 0.57, 0.55) and teint.get_shader_parameter("dalle") == Vector2(4, 4)
		and teint != Bibliotheque.matiere("matieres-de-minuit@1", "marbre_creme"), "les réglages de la commune passent devant, sur une matière à elle")
	check(Bibliotheque.matiere("matieres-de-minuit@1", "inconnue") == null and Bibliotheque.matiere("stade-de-campagne@1", "marbre_noir") == null
		and Bibliotheque.matieres("matieres-de-minuit@2").is_empty() and Bibliotheque.scene("matieres-de-minuit@1", "stade") == "",
		"une matière, une brique ou une version inconnues ne rendent rien")
	check(Bibliotheque.verifier_matieres({"matieres": {"Marbre": {"image": "../x.png", "dalle": [0, 2], "lueur": 9, "eclat": 1}}}, "res://nulle/part/").size() == 5,
		"des matières fautives : nom, image hors du dossier, dalle, réglage hors bornes, réglage inconnu")

	# Le façadier du Poitou (Chauvigny 0.2.2, MIT) : un décor qu'on pose par type et graine.
	var facadier := Bibliotheque.scene("facadier-du-poitou@1", "decor")
	check(facadier != "" and "facadier-du-poitou@1" in Bibliotheque.references("decor") and Bibliotheque.scene("facadier-du-poitou@1", "stade") == "",
		"la bibliothèque a le façadier du Poitou, un décor")
	check(FileAccess.file_exists(facadier.get_base_dir() + "/LICENCE.txt") and str(Bibliotheque.brique("facadier-du-poitou@1").get("licence", "")).begins_with("MIT"),
		"le façadier garde sa licence MIT et sa notice")
	var paquet_maison: PackedScene = load(facadier)
	var types: Array = paquet_maison.instantiate().get_script().types()
	var bancs := Node3D.new()
	root.add_child(bancs)
	var mauvais := []
	for ty in types:
		var mf: Node3D = paquet_maison.instantiate()
		mf.type = ty
		mf.graine = 7
		bancs.add_child(mf)
		var w := float(mf.get_meta("w", 0.0))
		var faite := float(mf.get_meta("faite", 0.0))
		if mf.get_meta("type", "") != ty or w < 3.0 or w > 20.0 or faite < 3.0 or mf.find_children("*", "MeshInstance3D", true, false).is_empty():
			mauvais.append(ty)
	check(types.size() == 10 and mauvais.is_empty(), "les dix types se bâtissent, avec leur largeur et leur faîte %s" % str(mauvais))
	var m1: Node3D = paquet_maison.instantiate()
	var m2: Node3D = paquet_maison.instantiate()
	m1.type = "notable"
	m2.type = "notable"
	m2.graine = 2
	m2.options = {"w": 9.0, "quartier": "quai", "vegetal": false}
	bancs.add_child(m1)
	bancs.add_child(m2)
	check(is_equal_approx(float(m2.get_meta("w")), 9.0) and m2.get_meta("vegetal") == [] and str(m1.get_meta("traces")) + str(m1.get_meta("w")) != str(m2.get_meta("traces")) + str(m2.get_meta("w")),
		"les options passent au façadier, et deux graines font deux maisons")
	bancs.queue_free()

	# La place du nord (tirée de l'inspiration d'ambiance de Guillaume) : les arbres, le mobilier et le façadier des
	# Flandres se bâtissent chacun par son nom et sa graine, en un seul maillage et un seul corps.
	var place := Node3D.new()
	root.add_child(place)
	var nord := {"arbres-de-place@1": ["especes", "espece", 5], "mobilier-de-place@1": ["objets", "objet", 13], "facadier-des-flandres@1": ["types", "type", 6]}
	for ref in nord:
		var sc := Bibliotheque.scene(ref, "decor")
		check(sc != "" and ResourceLoader.exists(sc), "la bibliothèque a %s, un décor" % ref)
		if sc == "":
			continue
		var paquet: PackedScene = load(sc)
		var noms: Array = paquet.instantiate().call(nord[ref][0])
		var rates := []
		for nom in noms:
			var d: Node3D = paquet.instantiate()
			d.set(nord[ref][1], nom)
			d.graine = 3
			place.add_child(d)
			var maillages := d.find_children("*", "MeshInstance3D", true, false)
			if d.get_meta(nord[ref][1], "") != nom or maillages.size() != 1 or maillages[0].mesh.get_surface_count() > 3 or d.find_children("*", "CollisionShape3D", true, false).is_empty():
				rates.append(nom)
		check(noms.size() == nord[ref][2] and rates.is_empty(), "%s : les %d se bâtissent, un maillage et un corps chacun %s" % [ref, noms.size(), str(rates)])
	var paquet_nord: PackedScene = load(Bibliotheque.scene("facadier-des-flandres@1", "decor"))
	var f1: Node3D = paquet_nord.instantiate()
	var f2: Node3D = paquet_nord.instantiate()
	f1.type = "cloche"
	f2.type = "cloche"
	f2.graine = 2
	f2.options = {"w": 8.0, "niveaux": 3, "rdc": "passage"}
	place.add_child(f1)
	place.add_child(f2)
	check(is_equal_approx(float(f2.get_meta("w")), 8.0) and float(f2.get_meta("hauteur")) > 4.0 + 3 * 3.2 and float(f1.get_meta("w")) != float(f2.get_meta("w")),
		"les options passent au façadier des Flandres, et deux graines font deux maisons")
	place.queue_free()

	# Le décor lyonnais (tiré du plan d'assets lyonnais de Guillaume) : le façadier, le mobilier, la végétation et les
	# quais se bâtissent chacun par son nom et sa graine, en un seul maillage et un seul corps.
	var lyon := Node3D.new()
	root.add_child(lyon)
	var lyonnais := {"facadier-lyonnais@1": ["types", "type", 11], "mobilier-lyonnais@1": ["objets", "objet", 15],
		"vegetation-lyonnaise@1": ["noms", "plante", 8], "quais-lyonnais@1": ["noms", "module", 12]}
	for ref in lyonnais:
		var sc := Bibliotheque.scene(ref, "decor")
		check(sc != "" and ResourceLoader.exists(sc), "la bibliothèque a %s, un décor" % ref)
		if sc == "":
			continue
		var paquet: PackedScene = load(sc)
		var noms: Array = paquet.instantiate().call(lyonnais[ref][0])
		var rates := []
		for nom in noms:
			var d: Node3D = paquet.instantiate()
			d.set(lyonnais[ref][1], nom)
			d.graine = 3
			lyon.add_child(d)
			var maillages := d.find_children("*", "MeshInstance3D", true, false)
			if d.get_meta(lyonnais[ref][1], "") != nom or maillages.size() != 1 or maillages[0].mesh.get_surface_count() > 3 or d.find_children("*", "CollisionShape3D", true, false).is_empty():
				rates.append(nom)
		check(noms.size() == lyonnais[ref][2] and rates.is_empty(), "%s : les %d se bâtissent, un maillage et un corps chacun %s" % [ref, noms.size(), str(rates)])
	var paquet_lyon: PackedScene = load(Bibliotheque.scene("facadier-lyonnais@1", "decor"))
	var l1: Node3D = paquet_lyon.instantiate()
	var l2: Node3D = paquet_lyon.instantiate()
	l1.type = "cafe"
	l2.type = "cafe"
	l2.graine = 2
	l2.options = {"w": 10.5, "niveaux": 3, "enseigne": "CAFÉ DU GONE"}
	lyon.add_child(l1)
	lyon.add_child(l2)
	var enseignes := l2.find_children("*", "Label3D", true, false).map(func(e): return e.text)
	check(is_equal_approx(float(l2.get_meta("w")), 10.5) and float(l2.get_meta("hauteur")) > 4.2 + 3 * 3.3 and "CAFÉ DU GONE" in enseignes and float(l1.get_meta("w")) != float(l2.get_meta("w")),
		"les options passent au façadier lyonnais (largeur, étages, enseigne du café), et deux graines font deux immeubles")
	var quai: Node3D = load(Bibliotheque.scene("quais-lyonnais@1", "decor")).instantiate()
	quai.module = "escalier_haut"
	lyon.add_child(quai)
	check(is_equal_approx(float(quai.get_meta("haut")), 3.0), "l'escalier haut des quais lyonnais mène à 3 m")
	lyon.queue_free()

	# Le décor du Bugey (tiré de la planche d'assets régionaux de Guillaume) : les maisons de pierre, le mobilier, la
	# végétation et les terrains se bâtissent chacun par son nom, en un seul maillage et un seul corps ; aucune essence
	# n'y redouble celles des autres décors (le tilleul, le bouleau, le cyprès et la vigne se prennent chez eux).
	var bugey := Node3D.new()
	root.add_child(bugey)
	var bugistes := {"facadier-du-bugey@1": ["types", "type", 11], "mobilier-du-bugey@1": ["objets", "objet", 17],
		"vegetation-du-bugey@1": ["noms", "plante", 8], "terrains-du-bugey@1": ["noms", "module", 10]}
	for ref in bugistes:
		var sc := Bibliotheque.scene(ref, "decor")
		check(sc != "" and ResourceLoader.exists(sc), "la bibliothèque a %s, un décor" % ref)
		if sc == "":
			continue
		var paquet: PackedScene = load(sc)
		var noms: Array = paquet.instantiate().call(bugistes[ref][0])
		var rates := []
		for nom in noms:
			var d: Node3D = paquet.instantiate()
			d.set(bugistes[ref][1], nom)
			d.graine = 3
			bugey.add_child(d)
			var maillages := d.find_children("*", "MeshInstance3D", true, false)
			if d.get_meta(bugistes[ref][1], "") != nom or maillages.size() != 1 or maillages[0].mesh.get_surface_count() > 3 or d.find_children("*", "CollisionShape3D", true, false).is_empty():
				rates.append(nom)
		check(noms.size() == bugistes[ref][2] and rates.is_empty(), "%s : les %d se bâtissent, un maillage et un corps chacun %s" % [ref, noms.size(), str(rates)])
	var essences: Array = load(Bibliotheque.scene("vegetation-du-bugey@1", "decor")).instantiate().call("noms")
	var lyonnaises: Array = load(Bibliotheque.scene("vegetation-lyonnaise@1", "decor")).instantiate().call("noms")
	check(not ("tilleul" in essences or "bouleau" in essences or "cypres" in essences or "vigne" in essences or essences.any(func(e): return e in lyonnaises)),
		"la végétation du Bugey ne redouble aucune essence des autres décors")
	# L'appareil « irregulier » (moellons en assises de hauteurs variées, joints sombres) est une option : la maison
	# par défaut reste celle d'hier, à l'appareil régulier.
	var paquet_bugey: PackedScene = load(Bibliotheque.scene("facadier-du-bugey@1", "decor"))
	var sommets := {}
	for appareil in ["", "regulier", "irregulier"]:
		var maison_b: Node3D = paquet_bugey.instantiate()
		maison_b.type = "r1"
		maison_b.graine = 3
		if appareil != "":
			maison_b.options = {"appareil": appareil}
		bugey.add_child(maison_b)
		var mm := maison_b.find_children("*", "MeshInstance3D", true, false)
		sommets[appareil] = mm[0].mesh.surface_get_array_len(0) if mm.size() == 1 else -1
	check(sommets[""] > 0 and sommets[""] == sommets["regulier"] and sommets["irregulier"] > 0 and sommets["irregulier"] != sommets["regulier"],
		"facadier-du-bugey@1 : l'appareil irrégulier se bâtit, et la maison par défaut garde l'appareil régulier %s" % str(sommets))
	bugey.queue_free()

	# Le décor toulousain (tiré des planches de la place Saint-Georges de Guillaume) : les maisons de brique, les sols,
	# le mobilier et les arbres d'ombrière se bâtissent chacun par son nom, en un seul maillage et un seul corps ; le pavage en épi se raccorde
	# d'un module à l'autre, et le carrousel tourne.
	var toulouse := Node3D.new()
	root.add_child(toulouse)
	var toulousains := {"facadier-toulousain@1": ["types", "type", 13], "sols-toulousains@1": ["noms", "module", 10],
		"mobilier-toulousain@1": ["objets", "objet", 12], "arbres-d-ombriere@1": ["noms", "arbre", 4]}
	for ref in toulousains:
		var sc := Bibliotheque.scene(ref, "decor")
		check(sc != "" and ResourceLoader.exists(sc), "la bibliothèque a %s, un décor" % ref)
		if sc == "":
			continue
		var paquet: PackedScene = load(sc)
		var noms: Array = paquet.instantiate().call(toulousains[ref][0])
		var rates := []
		for nom in noms:
			var d: Node3D = paquet.instantiate()
			d.set(toulousains[ref][1], nom)
			d.graine = 3
			toulouse.add_child(d)
			var maillages := d.find_children("*", "MeshInstance3D", true, false)
			if d.get_meta(toulousains[ref][1], "") != nom or maillages.size() != 1 or maillages[0].mesh.get_surface_count() > 3 or d.find_children("*", "CollisionShape3D", true, false).is_empty():
				rates.append(nom)
		check(noms.size() == toulousains[ref][2] and rates.is_empty(), "%s : les %d se bâtissent, un maillage et un corps chacun %s" % [ref, noms.size(), str(rates)])
	# la terrasse prend des clients assis (option clients) : le maillage grossit d'autant
	var sommets_terrasse := {}
	for nb in [0, 5]:
		var tt: Node3D = load(Bibliotheque.scene("mobilier-toulousain@1", "decor")).instantiate()
		tt.objet = "terrasse"
		tt.graine = 4
		tt.options = {"tables": 3, "clients": nb}
		toulouse.add_child(tt)
		sommets_terrasse[nb] = (tt.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh.surface_get_array_len(0)
	check(sommets_terrasse[5] > sommets_terrasse[0] * 1.5, "la terrasse toulousaine assoit des clients quand on lui en demande (%s)" % str(sommets_terrasse))
	var manege: Node3D = load(Bibliotheque.scene("mobilier-toulousain@1", "decor")).instantiate()
	manege.objet = "carrousel"
	toulouse.add_child(manege)
	var cap: float = manege.get_child(0).rotation.y
	manege._process(0.5)
	var platane: Node3D = load(Bibliotheque.scene("arbres-d-ombriere@1", "decor")).instantiate()
	toulouse.add_child(platane)
	check(float(platane.get_meta("hauteur")) >= 16.0 and float(platane.get_meta("couronne")) >= 7.0, "le platane d'ombrière fait au moins 16 m et sa couronne 7 m de rayon")
	var bac: Node3D = load(Bibliotheque.scene("mobilier-toulousain@1", "decor")).instantiate()
	bac.objet = "bac_vegetal"
	bac.options = {"forme": "polygone", "points": [[0, 0], [3.6, -0.4], [4.2, 1.6], [2.0, 2.6]], "plantation": "buis", "couvertine": "c9a070"}
	toulouse.add_child(bac)
	var emprise_bac: Vector2 = bac.get_meta("emprise")
	check(emprise_bac.x > 4.0 and emprise_bac.y > 2.9, "le bac végétal suit le polygone qu'on lui donne (%s)" % str(emprise_bac))
	# un grand bac dense de 1 000 m² se sème selon son aire réelle, sous un plafond de touffes : il se bâtit vite
	var grand_bac: Node3D = load(Bibliotheque.scene("mobilier-toulousain@1", "decor")).instantiate()
	grand_bac.objet = "bac_vegetal"
	grand_bac.options = {"forme": "polygone", "points": [[0, 0], [40, 0], [40, 25], [0, 25]], "plantation": "dense"}
	var t_bac := Time.get_ticks_msec()
	toulouse.add_child(grand_bac)
	t_bac = Time.get_ticks_msec() - t_bac
	check(grand_bac.find_children("*", "MeshInstance3D", true, false).size() == 1 and t_bac < 8000,
		"un bac végétal dense de 1 000 m² se bâtit en %d ms (moins de 8 s)" % t_bac)
	var marronnier: Node3D = load(Bibliotheque.scene("arbres-d-ombriere@1", "decor")).instantiate()
	marronnier.arbre = "marronnier"
	toulouse.add_child(marronnier)
	check(float(marronnier.get_meta("hauteur")) >= 12.0 and float(marronnier.get_meta("hauteur")) <= 18.0, "le marronnier (demandé par la carte de Lyon) fait de 12 à 18 m (%.1f)" % float(marronnier.get_meta("hauteur")))
	var tuilee: Node3D = paquet_lyon.instantiate()
	tuilee.options = {"tuile": "8a4a3a"}
	toulouse.add_child(tuilee)
	check(not tuilee.find_children("*", "MeshInstance3D", true, false).is_empty(), "le façadier lyonnais prend la teinte de tuile qu'on lui donne")
	# la banderole de la course : taille_texte agrandit les lettres, et la toile avec elles
	var hauteur_toile := func(opt: Dictionary) -> float:
		var b: Node3D = load(Bibliotheque.scene("course-cycliste@1", "decor")).instantiate()
		b.objet = "banderole"
		b.options = opt
		toulouse.add_child(b)
		var lab: Label3D = b.find_children("*", "Label3D", true, false)[0]
		return lab.pixel_size * 96.0 * 0.72
	var petite: float = hauteur_toile.call({"largeur": 9.5, "texte": "GRAND PRIX DE LA LOUVE"})
	var grande: float = hauteur_toile.call({"largeur": 9.5, "texte": "LOUVE", "taille_texte": 0.8})
	var pleine: float = hauteur_toile.call({"largeur": 9.5, "texte": "LOUVE", "taille_texte": "ajuste"})
	var bornee: float = hauteur_toile.call({"largeur": 9.5, "texte": "GRAND PRIX DE LA LOUVE", "taille_texte": 2.0})
	check(petite < 0.5 and absf(grande - 0.8) < 0.03 and absf(pleine - 1.2) < 0.03 and bornee < 0.6,
		"la banderole prend la taille de lettres demandée (%.2f, %.2f, « ajuste » %.2f m) et ne déborde jamais de sa toile (%.2f)" % [petite, grande, pleine, bornee])
	var cafe_l: Node3D = paquet_lyon.instantiate()
	cafe_l.type = "cafe"
	cafe_l.options = {"avancee": 2.6, "toile": ["2f5a3a", "2f5a3a"], "enseigne": "CAFÉ SATHONAY"}
	toulouse.add_child(cafe_l)
	var store_l: AABB = (cafe_l.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).get_aabb()
	var lambrequin := cafe_l.find_children("*", "Label3D", true, false).filter(func(e): return e.text == "CAFÉ SATHONAY").size()
	check(store_l.end.z > 2.6 and lambrequin == 2, "les stores bannes du café avancent de 2,6 m et l'enseigne est peinte sur le lambrequin (%.2f, %d)" % [store_l.end.z, lambrequin])
	var sans_store: Node3D = paquet_lyon.instantiate()
	sans_store.type = "cafe"
	sans_store.options = {"avancee": 2.6, "store": false}
	toulouse.add_child(sans_store)
	var nu: AABB = (sans_store.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).get_aabb()
	check(nu.end.z < 2.0, "le façadier lyonnais laisse la devanture sans store banne quand on le demande (%.2f)" % nu.end.z)
	# l'option teinte des arbres d'ombrière : un hexa tire la palette, une liste de verts se mêle selon la graine
	var verts_de := func(t: Node3D) -> Color:
		var cols: PackedColorArray = (t.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh.surface_get_arrays(1)[Mesh.ARRAY_COLOR]
		var somme := Color(0, 0, 0, 0)
		for c in cols:
			somme += c
		return somme / maxf(1, cols.size())
	var teintes := []
	for t in [null, "8ab04a", ["6e9440", "8ab04a", "4d6e33"]]:
		var mt: Node3D = load(Bibliotheque.scene("arbres-d-ombriere@1", "decor")).instantiate()
		mt.arbre = "marronnier"
		if t != null:
			mt.options = {"teinte": t}
		toulouse.add_child(mt)
		teintes.append(verts_de.call(mt))
	check(not teintes[0].is_equal_approx(teintes[1]) and not teintes[0].is_equal_approx(teintes[2]), "l'arbre d'ombrière prend la teinte qu'on lui donne")
	# le jour du ciel au cœur de la couronne est un paramètre d'instance (option jour), et le fût du platane est
	# moins blanc (#B8AE98, verdict de Saint-Georges v0.7)
	var clair: Node3D = load(Bibliotheque.scene("arbres-d-ombriere@1", "decor")).instantiate()
	clair.options = {"jour": 1.1}
	toulouse.add_child(clair)
	var mi_clair: MeshInstance3D = clair.find_children("*", "MeshInstance3D", true, false)[0]
	check(is_equal_approx(float(mi_clair.get_instance_shader_parameter("jour")), 1.1) and is_equal_approx(float(platane.find_children("*", "MeshInstance3D", true, false)[0].get_instance_shader_parameter("jour")), 0.6),
		"l'arbre d'ombrière règle le jour de sa voûte par l'option jour (0,6 par défaut)")
	check(str(platane.ECORCE["platane"]) == "b8ae98" and Color(platane.ECORCE["platane"]).get_luminance() < Color("c9bea0").get_luminance(), "le fût du platane est moins blanc qu'avant (#B8AE98)")
	var teintes_plaques := {}
	for hexa in platane.PLAQUES:
		teintes_plaques[int(Color(hexa).h * 12.0)] = true
	check(teintes_plaques.size() >= 2 and platane.PLAQUES.size() >= 6, "les plaques du platane mêlent crème, gris vert et ocre (%d teintes)" % platane.PLAQUES.size())
	var plat: Node3D = paquet_lyon.instantiate()
	plat.options = {"w": 10.0, "d": 11.0, "niveaux": 3}
	toulouse.add_child(plat)
	var raide: Node3D = paquet_lyon.instantiate()
	raide.options = {"w": 10.0, "d": 11.0, "niveaux": 3, "pente": 30.0, "chassis": 2, "souches": "grosses"}
	toulouse.add_child(raide)
	check(float(raide.get_meta("hauteur")) > float(plat.get_meta("hauteur")) + 0.5, "le toit lyonnais se raidit à 30° quand on le demande (%.2f contre %.2f m au faîte)" % [float(raide.get_meta("hauteur")), float(plat.get_meta("hauteur"))])
	var paquet_ml: PackedScene = load(Bibliotheque.scene("mobilier-lyonnais@1", "decor"))
	var bistrot: Node3D = paquet_ml.instantiate()
	bistrot.objet = "terrasse"
	toulouse.add_child(bistrot)
	var parasol: Node3D = paquet_ml.instantiate()
	parasol.objet = "terrasse"
	parasol.options = {"parasol": true}
	toulouse.add_child(parasol)
	check((bistrot.get_meta("emprise") as Vector2).y < 2.0 and (parasol.get_meta("emprise") as Vector2).y > 3.0, "la terrasse lyonnaise est bistrot sans parasol, et garde son parasol carré sur demande")
	check(manege.is_processing() and not is_equal_approx(manege.get_child(0).rotation.y, cap), "le carrousel toulousain tourne")
	toulouse.queue_free()

	# Les fleuves et les arbres des rives (demandés par la carte de Belley) : les huit modules et les trois arbres se
	# bâtissent, en un seul maillage et un seul corps ; l'eau du fleuve est sous le sol des rives, et son lit sous l'eau.
	var fleuves := Node3D.new()
	root.add_child(fleuves)
	var paquet_f: PackedScene = load(Bibliotheque.scene("fleuves@1", "decor"))
	var modules_f: Array = paquet_f.instantiate().call("noms")
	var rates_f := []
	for nom in modules_f:
		var d: Node3D = paquet_f.instantiate()
		d.module = nom
		d.graine = 3
		fleuves.add_child(d)
		var maillages := d.find_children("*", "MeshInstance3D", true, false)
		if d.get_meta("module", "") != nom or maillages.size() != 1 or maillages[0].mesh.get_surface_count() > 3 or d.find_children("*", "CollisionShape3D", true, false).is_empty():
			rates_f.append(nom)
	check(modules_f.size() == 8 and rates_f.is_empty(), "fleuves@1 : les %d modules se bâtissent, un maillage et un corps chacun %s" % [modules_f.size(), str(rates_f)])
	var fleuve: Node3D = paquet_f.instantiate()
	fleuves.add_child(fleuve)
	var lit: AABB = (fleuve.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).get_aabb()
	check(lit.end.y < 0.0 and lit.position.y <= -3.5 and lit.position.y > -4.0 and is_equal_approx(lit.size.z, 116.0), "le fleuve coule sous le sol des rives, son lit à 3,5 m, 100 m d'eau et 8 m sur chaque berge")
	var paquet_a: PackedScene = load(Bibliotheque.scene("arbres-des-rives@1", "decor"))
	var rates_a := []
	for nom in paquet_a.instantiate().call("noms"):
		var a: Node3D = paquet_a.instantiate()
		a.arbre = nom
		fleuves.add_child(a)
		var maillages := a.find_children("*", "MeshInstance3D", true, false)
		if a.get_meta("arbre", "") != nom or maillages.size() != 1 or maillages[0].mesh.get_surface_count() > 3 or a.find_children("*", "CollisionShape3D", true, false).is_empty():
			rates_a.append(nom)
	var peuplier: Node3D = paquet_a.instantiate()
	fleuves.add_child(peuplier)
	check(rates_a.is_empty() and float(peuplier.get_meta("hauteur")) > 20.0 and float(peuplier.get_meta("couronne")) < 3.0,
		"arbres-des-rives@1 : les trois se bâtissent, et le peuplier est une colonne de plus de 20 m %s" % str(rates_a))
	fleuves.queue_free()

	# Le matériel de course cycliste (demandé par la carte de Belley) : les onze objets se bâtissent, en un seul
	# maillage et un seul corps ; l'arche porte son inscription et enjambe la largeur demandée.
	var course := Node3D.new()
	root.add_child(course)
	var paquet_c: PackedScene = load(Bibliotheque.scene("course-cycliste@1", "decor"))
	var objets_c: Array = paquet_c.instantiate().call("noms")
	var rates_c := []
	for nom in objets_c:
		var c: Node3D = paquet_c.instantiate()
		c.objet = nom
		course.add_child(c)
		var maillages := c.find_children("*", "MeshInstance3D", true, false)
		if c.get_meta("objet", "") != nom or maillages.size() != 1 or maillages[0].mesh.get_surface_count() > 3 or c.find_children("*", "CollisionShape3D", true, false).is_empty():
			rates_c.append(nom)
	check(objets_c.size() == 11 and rates_c.is_empty(), "course-cycliste@1 : les %d objets se bâtissent, un maillage et un corps chacun %s" % [objets_c.size(), str(rates_c)])
	var arche: Node3D = paquet_c.instantiate()
	arche.options = {"texte": "DÉPART", "largeur": 12.0}
	course.add_child(arche)
	var inscrit := false
	for l in arche.find_children("*", "Label3D", true, false):
		if (l as Label3D).text == "DÉPART":
			inscrit = true
	var portee: AABB = (arche.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).get_aabb()
	check(inscrit and portee.size.x > 12.0, "l'arche porte son inscription et enjambe une route de 12 m")
	course.queue_free()

	# Les voitures des années 1980 (demandées par la carte de Belley) : les six se bâtissent, en un seul maillage et
	# un seul corps, à leur longueur ; la suiveuse porte ses vélos au-dessus du toit.
	var garage := Node3D.new()
	root.add_child(garage)
	var paquet_v: PackedScene = load(Bibliotheque.scene("voitures-des-annees-80@1", "decor"))
	var voitures_v: Array = paquet_v.instantiate().call("noms")
	var rates_v := []
	for nom in voitures_v:
		var v: Node3D = paquet_v.instantiate()
		v.voiture = nom
		garage.add_child(v)
		var maillages := v.find_children("*", "MeshInstance3D", true, false)
		var l := float(v.get_meta("longueur", 0.0))
		if v.get_meta("voiture", "") != nom or maillages.size() != 1 or maillages[0].mesh.get_surface_count() > 3 or v.find_children("*", "CollisionShape3D", true, false).is_empty() or l < 3.4 or l > 4.9:
			rates_v.append(nom)
	check(voitures_v.size() == 6 and rates_v.is_empty(), "voitures-des-annees-80@1 : les %d voitures se bâtissent, un maillage et un corps chacun %s" % [voitures_v.size(), str(rates_v)])
	var suiveuse: Node3D = paquet_v.instantiate()
	suiveuse.voiture = "suiveuse"
	garage.add_child(suiveuse)
	var haut_s: AABB = (suiveuse.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).get_aabb()
	check(haut_s.end.y > 2.4, "la suiveuse porte ses vélos sur la galerie (%.2f m)" % haut_s.end.y)
	garage.queue_free()

	# Les intérieurs (socle 1.22) : chaque salle de jeu et chaque étude tient le contrat de son genre.
	check("bar-des-sports@1" in Bibliotheque.references("salle_jeu") and "etude-de-notaire@1" in Bibliotheque.references("etude"),
		"la bibliothèque a le bar des sports et l'étude de notaire")
	for genre in ["salle_jeu", "etude"]:
		for ref in Bibliotheque.references(genre):
			var n: Node3D = load(Bibliotheque.scene(ref, genre)).instantiate()
			root.add_child(n)
			check(Ancres.verifier_genre(n, genre).is_empty(), "%s tient le contrat %s %s" % [ref, "de la salle de jeu" if genre == "salle_jeu" else "de l'étude", str(Ancres.verifier_genre(n, genre))])
			if genre == "salle_jeu":
				check(Ancres.tables(n).size() >= 1, "%s offre %d places de table" % [ref, Ancres.tables(n).size()])
			n.queue_free()
	var bar: Node3D = load(Bibliotheque.scene("bar-des-sports@1", "salle_jeu")).instantiate()
	root.add_child(bar)
	check(Ancres.tables(bar).size() == 4, "le bar des sports a quatre places de table")
	bar.queue_free()
	var vide_jeu := Node3D.new()
	check(Ancres.verifier_genre(vide_jeu, "salle_jeu").size() == 4 and Ancres.verifier_genre(vide_jeu, "etude").size() == 3,
		"un intérieur sans ancres : quatre ancres manquent à la salle de jeu, trois à l'étude")
	vide_jeu.free()

	# Tous les décors, et les intérieurs : chacun se bâtit seul, sur un sol plat, ne nomme rien hors de son dossier
	# et du socle, et garde sa notice quand sa licence la demande.
	var decors := Bibliotheque.references("decor")
	check(decors.has("donjon-en-ruine@1") and decors.has("eglise-romane@1"), "la bibliothèque a le donjon en ruine et l'église romane %s" % str(decors))
	for ref in decors + Bibliotheque.references("salle_jeu") + Bibliotheque.references("etude"):
		var b: Dictionary = Bibliotheque.brique(ref)
		var dossier := str(b.scene).get_base_dir() + "/"
		var hors := []
		for f in DirAccess.get_files_at(dossier):
			if f.get_extension() in ["gd", "tscn", "gdshader"]:
				for ligne in FileAccess.get_file_as_string(dossier + f).split("\n"):
					if "res://" in ligne and not dossier in ligne and not "res://scripts/" in ligne:
						hors.append(f)
		var notice := not str(b.licence).begins_with("MIT") or FileAccess.file_exists(dossier + "LICENCE.txt")
		var d: Node3D = load(b.scene).instantiate()
		root.add_child(d)
		var boite := AABB()
		# Les intérieurs regroupent leur géométrie en multimaillages.
		var maillages := d.find_children("*", "MeshInstance3D", true, false) + d.find_children("*", "MultiMeshInstance3D", true, false)
		for mi in maillages:
			boite = boite.merge(mi.global_transform * mi.get_aabb()) if boite.has_volume() else mi.global_transform * mi.get_aabb()
		var corps := d.find_children("*", "StaticBody3D", true, false)
		if not ref in decors:
			# Sans rendu, un multimaillage n'a pas de boîte : celle d'un intérieur est celle de ses collisions.
			boite = AABB()
			for cs in d.find_children("*", "CollisionShape3D", true, false):
				if cs.shape is BoxShape3D:
					var bb := AABB(-cs.shape.size / 2.0, cs.shape.size)
					boite = boite.merge(cs.global_transform * bb) if boite.has_volume() else cs.global_transform * bb
		check(hors.is_empty() and notice and not maillages.is_empty() and not corps.is_empty() and boite.position.y > -4.0 and boite.position.y < 0.0,
			"%s se bâtit seul (%d maillages, %d corps, boîte %s), sans fichier hors de son dossier %s" % [ref, maillages.size(), corps.size(), str(boite.size), str(hors)])
		if ref == "donjon-en-ruine@1":
			check(boite.size.y > 30.0 and boite.size.x < 30.0, "le donjon monte à plus de 30 m sur moins de 30 m de large")
		if ref == "eglise-romane@1":
			check(absf(boite.get_center().x) < 3.0 and absf(boite.get_center().z) < 3.0 and boite.end.y > 38.0 and boite.end.y < 46.0,
				"l'église est centrée sur l'origine, son clocher à sa mesure (%.1f m, croix comprise)" % boite.end.y)
		d.queue_free()
	var haute: Node3D = load(Bibliotheque.scene("eglise-romane@1", "decor")).instantiate()
	haute.hauteur_clocher = 50.0
	root.add_child(haute)
	var sommet := -INF
	for mi in haute.find_children("*", "MeshInstance3D", true, false):
		sommet = maxf(sommet, (mi.global_transform * mi.get_aabb()).end.y)
	check(sommet > 55.0, "le clocher se règle : %.1f m à Chauvigny, croix comprise" % sommet)
	haute.queue_free()

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
	# Une brique de matières se propose et s'intègre de la même façon, avec son fichier de matières.
	var pm := Bibliotheque.propositions("res://tools/fixtures/proposition_matieres/")
	check(pm.size() == 1 and pm[0].fiche.genre == "matieres" and pm[0].erreurs.is_empty(), "des matières proposées se lisent : %s" % str(pm.map(func(x): return [x.id, x.erreurs])))
	var fm := " ".join(Bibliotheque.verifier_fiche({"genre": "matieres", "nom": "x", "auteur": "a", "licence": "l", "scene": "x.tscn"}, "matieres-x", "res://nulle/part/"))
	check(fm.contains("manquant « matieres »") and fm.contains("inconnu « scene »"),
		"une brique de matières nomme son fichier « matieres », pas une scène")
	var rm: Dictionary = integrer.integrer("essai", "matieres-des-essais", "res://tools/fixtures/proposition_matieres/", racine, cat)
	var lm: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(cat)).briques.get("matieres-des-essais", {})
	check(rm.get("version") == 1 and str(lm.get("genre")) == "matieres" and str(lm.versions["1"].get("matieres")) == racine + "matieres-des-essais/1/matieres.json"
		and FileAccess.file_exists(racine + "matieres-des-essais/1/carrelage.png"), "les matières entrent en version 1, avec leurs images : %s" % str(rm))
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
	var jeu := {"type": "salle_jeu", "id": "bar", "nom": "Le bar", "jeux": ["poker"], "modele": "bar-des-sports@1"}
	check(Structures.verifier([jeu]).is_empty(), "« modele » d'une salle de jeu : une brique de la bibliothèque (socle 1.22)")
	var jeu_stade := jeu.duplicate()
	jeu_stade.modele = "stade-de-campagne@1"
	check(" ".join(Structures.verifier([jeu_stade])).contains("n'est pas une salle de jeu"), "un stade n'est pas une salle de jeu")
	check(Notaire.verifier({"nom": "Maître X", "modele": "etude-de-notaire@1"}).is_empty() and Notaire.verifier({"modele": "res://communes/x/etude.tscn"}).is_empty(),
		"« notaire.modele » : une étude de la bibliothèque, ou une scène de la commune")
	check(" ".join(Notaire.verifier({"modele": "bar-des-sports@1"})).contains("n'est pas une étude") and Notaire.verifier({"modele": "etude.tscn"}).size() == 1
		and Notaire.verifier({"modele": 3}).size() == 1, "un bar, un chemin hors de la commune ou un nombre ne font pas une étude")
	var gym := {"type": "gymnase", "id": "gymnase", "nom": "La salle", "club": "Le club", "modele": "salle-de-quartier@1"}
	check(Structures.verifier([gym]).is_empty(), "le gymnase : « modele » nomme une salle de la bibliothèque")
	var gym_stade := gym.duplicate()
	gym_stade.modele = "stade-de-campagne@1"
	check(Structures.verifier([gym_stade]).size() == 1 and Structures.verifier([gym_stade])[0].contains("pas une salle"), "un stade n'est pas une salle")
	var stade_salle := ok.duplicate()
	stade_salle.modele = "salle-de-quartier@1"
	check(Structures.verifier([stade_salle]).size() == 1, "une salle n'est pas un stade")

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

	# La salle de Smarves sur la salle de quartier : le club s'y branche par les ancres, sans le Garden.
	var g: Dictionary = registre.structure("smarves/gymnase")
	g.champs.modele = "salle-de-quartier@1"
	load("res://scripts/village/salle_basket.gd").prochaine_commune = "smarves"
	change_scene_to_file("res://scenes/salle_basket.tscn")
	await create_timer(1.5).timeout
	var salle: Node = current_scene
	check(salle._modele != null and salle.get_node_or_null("Modele") != null, "la salle de la bibliothèque est posée")
	var its := _interactions(salle)
	for k in ["exit", "president", "bureau", "panneau", "parts"]:
		check(its.has(k), "le socle a posé « %s » sur son ancre de la salle" % k)
	check(not its.has("porte_bureau") and not its.has("echoppe") and salle.get_node_or_null("Foule") == null and salle.get_node_or_null("BureauDuPresident") == null,
		"rien du Garden n'est posé : ni la porte du bureau, ni les échoppes, ni la foule")
	check(salle._president.global_position.distance_to(Ancres.trouver(salle._modele, "President").global_position) < 0.01, "le président de la salle se tient à son ancre")
	check(salle.player.global_position.distance_to(Ancres.trouver(salle._modele, "Arrivee").global_position) < 0.5, "le visiteur paraît à l'arrivée de la salle")
	check(salle._cube.size() == 4 and absf(salle._cube[0].global_position.y - Ancres.trouver(salle._modele, "Cube").global_position.y - 0.25 + 0.5) < 0.6, "le cube pend à son ancre")
	check(salle._cube_titre[0].text != "", "le cube dit le match ou l'entraînement : %s" % salle._cube_titre[0].text)
	var ts: Array = salle.find_children("*", "Label3D", true, false).map(func(l): return l.text)
	check("HÉRONS DU CLAIN  ·  CLAIN GARDEN" in ts, "l'enseigne de la salle porte le club et le nom de la salle")
	var avant_s: int = salle._panel_layer.get_child_count()
	salle._on_interact(its.bureau)
	await process_frame
	check(salle._ecran != null and salle._panel_layer.get_child_count() > avant_s, "le bureau du décor ouvre la gestion de l'équipe")
	g.champs.modele = "salle-de-quartier@9"
	load("res://scripts/village/salle_basket.gd").prochaine_commune = "smarves"
	change_scene_to_file("res://scenes/salle_basket.tscn")
	await create_timer(1.5).timeout
	salle = current_scene
	check(salle._modele == null and _interactions(salle).has("porte_bureau"), "une salle introuvable : c'est le Garden du socle")
	g.champs.erase("modele")

	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
