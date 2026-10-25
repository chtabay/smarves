extends SceneTree
## Vérifie l'accueil sans réseau : godot --headless --path . -s tools/test_accueil.gd
## Les blocs (scripts/socle/accueil.gd) avec un courrier et un voisinage posés à la main ; puis l'écran
## titre : trois boutons sans la carte, l'encart « Ce soir à Smarves » à droite, la barre du bas qui
## déplie la liste, et la rubrique Compte des réglages qui ouvre le compte et l'effacement.

const TMP := "user://test_accueil/"

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _textes(n: Node) -> String:
	var out := ""
	if n is CanvasItem and not (n as CanvasItem).is_visible_in_tree():
		return out
	if n is Label:
		out += (n as Label).text + "\n"
	if n is Button:
		out += (n as Button).text + "\n"
	for c in n.get_children():
		out += _textes(c)
	return out


func _bouton(n: Node, texte: String) -> Button:
	if n is Button and (n as Button).text == texte and (n as Button).is_visible_in_tree():
		return n
	for c in n.get_children():
		var b := _bouton(c, texte)
		if b != null:
			return b
	return null


func _bouton_qui_commence(n: Node, debut: String) -> Button:
	if n is Button and (n as Button).text.begins_with(debut):
		return n
	for c in n.get_children():
		var b := _bouton_qui_commence(c, debut)
		if b != null:
			return b
	return null


func _aides(n: Node) -> int:
	var k := 1 if n.get_script() != null and (n.get_script() as Script).resource_path == "res://scripts/socle/aide.gd" else 0
	for c in n.get_children():
		k += _aides(c)
	return k


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var A: GDScript = load("res://scripts/socle/accueil.gd")
	var avis: Node = root.get_node("Avis")
	var game: Node = root.get_node("Game")
	var compte: Node = root.get_node("Compte")
	game.saving_enabled = false
	DirAccess.make_dir_recursive_absolute(TMP)
	avis.dossier = TMP
	avis.effacer()

	# ---- la banque
	game.credits = 20346
	var b: Dictionary = A.banque(game, root.get_node("Biens"))
	check(b.credits == 20346 and b.fortune == 20346 + int(root.get_node("Biens").value()) - int(game.debt), "la banque dit les crédits et la fortune nette")

	# ---- les biens, comptés par famille
	var biens: Node = root.get_node("Biens")
	var avant: Dictionary = biens.owned.duplicate()
	biens.owned = {}
	check(A.biens(biens).texte == "aucun bien", "sans bien, la ligne le dit")
	biens.owned = {"maison": 1, "chambre": 1, "smarvoise": 3, "smoking": 1}
	var p: Dictionary = A.biens(biens)
	check(p.total == 6 and p.texte == "2 maisons · 3 parts · 1 objet", "les biens : %s" % p.texte)
	biens.owned = avant

	# ---- depuis votre passage : le courrier non lu, résumé
	check(str(A.depuis(avis).texte) == "", "rien de neuf : la ligne se tait")
	avis.publier({"id": "div/1", "genre": "dividende", "titre": "Dividende de l'ES Smarves", "montant": 800, "importance": "discrete"})
	avis.publier({"id": "div/2", "genre": "dividende", "titre": "Dividende du CEP Poitiers", "montant": 440, "importance": "discrete"})
	avis.publier({"id": "match/1", "genre": "match", "titre": "Victoire 2-1 à Availles"})
	var d: Dictionary = A.depuis(avis)
	check(d.dividendes == 1240 and d.matchs == 1, "les dividendes s'additionnent, les matchs se comptent")
	check(str(d.texte) == "+%s de dividendes · un match joué" % game.fmt(1240), "la ligne : %s" % d.texte)

	# ---- le courrier : les deux derniers non lus, sans les décisions
	avis.publier({"id": "dil/1", "genre": "dilemme", "titre": "Une décision"})
	var c: Array = A.courrier(avis)
	check(c.size() == 2 and not c.any(func(x): return x.titre == "Une décision"), "deux titres au courrier, sans la décision")
	avis.tout_lu()
	check(A.courrier(avis).is_empty() and str(A.depuis(avis).texte) == "", "tout lu : courrier et passage se taisent")

	# ---- à faire : trois lignes au plus, chacune avec son lien
	var t := 1000
	var liste := [{"titre": "Composer l'équipe", "quand": t + 3 * 3600, "lien": {"vers": "bureau", "club": "smarves", "page": "tactique"}},
		{"titre": "Appel de marge", "quand": t, "lien": {}}, {"titre": "Offre", "quand": t + 86400, "lien": {}},
		{"titre": "Quatrième", "quand": t + 2 * 86400, "lien": {}}]
	var f: Array = A.a_faire(liste, t)
	check(f.size() == 3 and f[0].quand == "dans 3 h" and f[0].lien.vers == "bureau", "trois lignes, l'échéance écrite, le lien gardé")
	check(f[1].lien == {"vers": "carnet", "onglet": "aujourdhui"}, "sans lien, la ligne mène à la page « Aujourd'hui »")

	# ---- au village : les passages sans doublon, le prochain rendez-vous
	var vois := Node.new()
	vois.set_script(load("res://scripts/socle/voisinage.gd"))
	vois.donnees = {"passages": {"casino": ["Léa", "Marc"], "bar": ["Léa"]}}
	# Jeudi 1er janvier 1970, midi : le prochain rendez-vous est le poker du vendredi.
	var v: Dictionary = A.village(vois, 12 * 3600)
	check(v.passes == ["Léa", "Marc"], "deux joueurs passés, sans doublon")
	check(str(v.texte).begins_with("2 joueurs passés · poker du vendredi dans 1 j"), "la ligne du village : %s" % v.texte)
	vois.free()

	# ---- la barre : à jour, une ville qui se télécharge, une nouvelle version
	var version: Node = root.get_node("Version")
	var communes: Node = root.get_node("Communes")
	version.etat = "a_jour"
	var e: Dictionary = A.etat(version, communes)
	check(str(e.texte).begins_with("✓ À jour") and e.teinte == "ok", "à jour : %s" % e.texte)
	version.etat = "nouvelle"
	e = A.etat(version, communes)
	check(e.teinte == "or" and e.geste[0] == "Installer", "nouvelle version : en or, avec « Installer »")
	version.etat = "a_jour"
	check(A.compte(compte) == "Partie sur cet appareil", "sans compte, la barre le dit en quatre mots")

	# ---- l'écran titre
	change_scene_to_file("res://scenes/title.tscn")
	await create_timer(1.0).timeout
	var titre := current_scene
	check(titre != null and titre.name == "Titre", "l'écran titre s'ouvre")
	check(_bouton(titre, "La carte") == null, "la carte n'est plus un bouton du titre")
	check(_bouton(titre, "Jouer") != null and _bouton(titre, "Réglages") != null, "Jouer et Réglages restent")
	var bv: Node = root.get_node("Bienvenue")
	bv.ouvrir()
	await process_frame
	var ecrit := _textes(bv)
	check(bv.get("_dock") and bv.get("_page") == "soiree", "à droite, l'encart")
	check("À SMARVES" in ecrit and "%s cr." % game.fmt(20346) in ecrit, "l'encart dit le moment et la banque")
	check(not "Se déconnecter" in ecrit and not "Se connecter" in ecrit and not "Effacer ma partie" in ecrit, "ni compte ni effacement dans l'encart")
	check(not "MISES À JOUR" in ecrit, "les mises à jour ont quitté l'encart")
	check("AU VILLAGE" in ecrit, "le prochain rendez-vous est au village")
	check("Vos biens" in ecrit, "le nombre de biens est sur l'encart")
	var rangee := _bouton_qui_commence(bv, "Vos biens")
	check(rangee != null and rangee.text.ends_with("›") and (rangee.get_theme_stylebox("normal") as StyleBoxFlat).bg_color.a > 0.0, "les lignes se voient cliquables : un fond et une flèche")
	check(_aides(bv) >= 1, "la fortune nette s'explique dans un (i), pas en toutes lettres")
	var barre: Control = bv.get("_barre")
	check(barre.visible and "✓ À jour" in _textes(barre) and "Partie sur cet appareil" in _textes(barre), "la barre du bas : l'état et le compte")
	var details := _bouton(barre, "détails  ▴")
	check(details != null, "« détails » sous la main")
	details.pressed.emit()
	await process_frame
	check(bv.get("_page") == "liste" and "Villes et mises à jour" in _textes(bv), "la barre déplie la liste à droite")
	_bouton(barre, "détails  ▾").pressed.emit()
	await process_frame
	check(bv.get("_page") == "soiree", "et la replie")

	# ---- la rubrique Compte des réglages
	var reglages: Node = root.get_node("Settings")
	reglages.toggle()
	await process_frame
	var r := _textes(reglages)
	check("COMPTE" in r and "Partie sur cet appareil" in r and "Effacer ma partie…" in r, "les réglages ont leur rubrique Compte")
	_bouton(reglages, "Votre compte Pyramides").pressed.emit()
	await process_frame
	check(not reglages.is_open() and bv.get("_page") == "compte" and bv.get("_dock") and "Se connecter avec Pyramides" in _textes(bv), "le compte s'ouvre à droite du titre")
	reglages.toggle()
	await process_frame
	_bouton(reglages, "Effacer ma partie…").pressed.emit()
	await process_frame
	check(bv.get("_page") == "effacer" and "EFFACER MA PARTIE" in _textes(bv), "l'effacement aussi, derrière EFFACER")
	_bouton(bv, "Garder ma partie").pressed.emit()
	await process_frame
	check(bv.get("_page") == "soiree", "« Garder ma partie » ramène à l'encart")
	root.get_tree().paused = false

	# ---- la partie lancée, l'encart encore là (téléphone lent) : un second toucher ne rouvre pas le compte
	bv.ouvrir()
	await process_frame
	titre.jouer()
	await process_frame
	bv.ouvrir_page("compte")
	await process_frame
	check(not bv.is_open(), "sur la place, un bouton de l'encart resté à l'écran le ferme au lieu d'ouvrir le compte")
	root.get_tree().paused = false

	print("\n%s" % ("TOUT EST BON" if fails == 0 else "%d ÉCHEC(S)" % fails))
	quit(1 if fails > 0 else 0)
