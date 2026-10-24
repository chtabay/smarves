extends SceneTree
## Vérifie le basket dans le carnet sans affichage : godot --headless --path . -s tools/test_carnet_basket.gd
## Un club de basket dont on tient une part a sa carte sur « Aujourd'hui », ses choses à faire (la consigne
## du match, une enchère dépassée), sa page dans « Mes clubs », sa ligne dans « Ma carrière » ; le courrier
## dit ses résultats et ses dividendes.

const CLICHE := "res://tools/fixtures/basket_cliche.json"
const TMP := "user://test_carnet_basket/"

var fails := 0
var t := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _textes(n: Node) -> String:
	var out := ""
	if n is Label:
		out += (n as Label).text + "\n"
	if n is Button:
		out += (n as Button).text + "\n"
	for c in n.get_children():
		out += _textes(c)
	return out


func gymnase(commune: String, club: String) -> Dictionary:
	return {"commune": commune, "nom": "La salle de " + commune, "type": "gymnase", "champs": {"club": club}}


func _initialize() -> void:
	_lancer.call_deferred()


func _lancer() -> void:
	var auj: GDScript = load("res://scripts/socle/aujourdhui.gd")
	var basket: Node = root.get_node("Basket")
	var foot: Node = root.get_node("Football")
	var avis: Node = root.get_node("Avis")
	var carnet: Node = root.get_node("Carnet")
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	DirAccess.make_dir_recursive_absolute(TMP)
	avis.dossier = TMP
	avis.effacer()
	foot.dossier = ""
	foot.effacer()
	basket.dossier = ""
	basket.effacer()
	basket.regler_horloge(func(): return t)
	foot.regler_horloge(func(): return t)
	basket.appel = func(_f, _c): return {"code": 200, "corps": {"ok": true}}
	var inscrits: Array = [gymnase("smarves", "Les Hérons du Clain"), gymnase("rivale", "Les Loups de Rivale")]
	basket.source_gymnases = func(): return inscrits
	t = basket.coup_envoi(1, 1) - 3600
	basket.actualiser()
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CLICHE))
	for j in range(1, 8):
		var c: Dictionary = fixture.duplicate(true)
		c.id = basket.id_cliche(1, j)
		basket.garder(c)
	var club := "smarves"
	check(auj.clubs_basket(basket).is_empty(), "sans part, on ne suit aucun club de basket")
	basket.bureau.obligations = [{"club": club, "rang": 3, "par": "Moi", "moi": true}]
	check(auj.clubs_basket(basket) == [club] and basket.peut_decider(club), "une part des Hérons : on les suit, et on les dirige")

	# ---- la veille du match : la consigne attend
	t = basket.coup_envoi(1, 5) - 86400
	var c: Dictionary = auj.carte_basket(basket, club)
	check(int(c.joues) == 4 and str(c.forme).length() == 4 and int(c.prochain.j) == 5 and int(c.taille) == 8, "la carte : quatre journées, la forme %s, la cinquième à venir" % c.forme)
	var genres: Array = carnet.a_faire().map(func(x): return x.genre)
	check(genres == ["consigne"], "à faire : la consigne du match de demain (%s)" % str(genres))
	basket.bureau.consignes = [{"saison": 1, "journee": 5, "club": club, "consigne": "rotation"}]
	check(carnet.a_faire().is_empty(), "posée, elle quitte la liste")
	check(str(auj.carte_basket(basket, club).consigne) == "rotation", "et la carte la dit")

	# ---- une enchère dépassée, avant la clôture du jeudi
	var j: int = basket.journee_du_marche()
	var ici: Array = basket.place_de(club)
	var libres: Array = basket.joueurs_libres(club)
	check(j == 6 and not libres.is_empty(), "le marché de la journée 6 est ouvert, %d joueurs libres" % libres.size())
	var code: String = libres[0].code
	basket.bureau.encheres = [{"saison": 1, "journee": j, "groupe": "%d-%d" % [ici[0], ici[1]], "joueur": code, "club": club, "montant": 100, "par": "Moi", "moi": true, "quand": "1"},
		{"saison": 1, "journee": j, "groupe": "%d-%d" % [ici[0], ici[1]], "joueur": code, "club": "rivale", "montant": 400, "par": "Lucien", "moi": false, "quand": "2"}]
	basket._oublier()
	var l: Array = carnet.a_faire()
	check(l.size() == 1 and l[0].genre == "enchere" and str(l[0].titre).contains(str(libres[0].nom)) and int(l[0].quand) == basket.cloture(1, j), "à faire : l'enchère dépassée sur %s, jusqu'au jeudi" % libres[0].nom)
	basket.bureau.encheres = []
	basket._oublier()

	# ---- le carnet : la carte, la page, la carrière
	carnet.ouvrir_sur("aujourdhui")
	await process_frame
	var d := _textes(carnet.get("_right"))
	check(carnet.get("_right").find_child("Basket_" + club, true, false) != null and d.contains("Basket · ") and d.contains("Consigne du match : rotation."), "la boîte : la carte des Hérons, avec sa consigne")
	carnet.toggle()
	check(carnet.pages_clubs().map(func(p): return p[0]) == ["basket:" + club, "calendrier"], "Mes clubs : une page pour les Hérons, puis le calendrier")
	carnet.ouvrir_club("basket:" + club)
	await process_frame
	var g := _textes(carnet.get("_left"))
	var gd := _textes(carnet.get("_right"))
	check(carnet.get("_left").find_child("Classement", true, false) != null and g.contains("V-D") and gd.contains("J4  ") and gd.contains("J5  "), "sa page : le classement, les journées")
	check(carnet.get("_right").find_child("Effectif", true, false) != null and _textes(carnet.get("_right")).contains("Masse salariale"), "en face : l'effectif et la masse salariale")
	carnet.ouvrir_onglet("compte")
	await process_frame
	check(_textes(carnet.get("_left")).contains("(basket)"), "Mes biens : les obligations de basket")
	carnet.ouvrir_onglet("carriere")
	await process_frame
	check(_textes(carnet.get("_left")).contains("Dividendes reçus, basket"), "Ma carrière : ses dividendes")
	var avant: int = carnet.fortune_nette()
	basket.bureau.obligations = []
	check(carnet.fortune_nette() == avant - int(round(basket.valeur(3) * basket.RACHAT)), "la part de basket compte dans la fortune nette")
	basket.bureau.obligations = [{"club": club, "rang": 3, "par": "Moi", "moi": true}]
	carnet.toggle()

	# ---- le courrier : les résultats, les dividendes
	avis.verifier()
	check(not avis.liste.any(func(a): return str(a.id).begins_with("basket/")), "la première lecture ne refait pas l'histoire")
	t = basket.coup_envoi(1, 5) + 3 * 3600
	avis.verifier()
	var r: Array = avis.liste.filter(func(a): return str(a.id) == "basket/1/5/%s" % club)
	check(r.size() == 1 and (str(r[0].titre).contains("victoire") or str(r[0].titre).contains("défaite")) and str(r[0].texte).begins_with("Basket, journée 5."), "le résultat de la journée 5 : %s" % (str(r[0].titre) if not r.is_empty() else "rien"))
	basket.dividendes[club] = {"s": 1, "j": 4}
	basket.tic()
	var dv: Array = avis.liste.filter(func(a): return str(a.id).begins_with("dividende_basket/"))
	check(basket.dividendes_total == 0 or (dv.size() == 1 and str(dv[0].texte) == "Basket, journée 5."), "le dividende de la journée 5 au courrier (%d crédits)" % basket.dividendes_total)

	# Le bureau du président relit le serveur en s'ouvrant : en dernier, l'état de l'essai ne compte plus.
	carnet.ouvrir_club("basket:" + club)
	await process_frame
	var marche: Button = carnet.get("_left").find_child("Action_Marche", true, false)
	check(marche != null and marche.icon != null and carnet.get("_left").find_child("Action_Gerer", true, false) != null, "la barre d'actions : Gérer, le marché")
	if marche != null:
		marche.pressed.emit()
	await process_frame
	var bb: Node = carnet.gestion().find_child("Bureau", true, false) if carnet.gestion() != null else null
	check(bb != null and bb.get_script().resource_path.ends_with("basket_bureau.gd") and bb.commune == club and bb.page == "marche", "le marché ouvre le bureau du président par-dessus le carnet")
	if bb != null:
		bb.closed.emit()
	await process_frame
	check(carnet.is_open() and carnet.gestion() == null, "refermé, retour au carnet")
	carnet.toggle()

	avis.effacer()
	basket.effacer()
	print("%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)
