extends Node
## Test automatique des biens : godot --headless --path . res://tools/test_biens.tscn
## Achète, finance, fait tourner des recettes, revend, déclenche une reprise, puis remet tout à zéro.
## Ne touche pas à la sauvegarde.

var _fails := 0


func _check(cond: bool, what: String) -> void:
	print(("ok      " if cond else "ÉCHEC   ") + what)
	if not cond:
		_fails += 1


func _bets(n: int, bet := 25) -> void:
	for i in n:
		Game.spend(bet)


func _ready() -> void:
	# Pas de Game.reset() ici : il effacerait la vraie sauvegarde.
	Game.saving_enabled = false
	Game.credits = 5000
	Game.won = 0
	Game.staked = 0
	Game.debt = 0
	Game.changed.emit()
	_check(Biens.buy("smarvoise"), "achat comptant d'une part de la Smarvoise")
	_check(Game.credits == 4800 and Biens.count("smarvoise") == 1, "200 crédits débités")
	_check(Biens.next_price("smarvoise") == 300, "la deuxième part coûte 300")
	_check(not Biens.buy("fournil"), "le fournil n'est pas proposé avant 3 000 gagnés")
	var debt := Game.debt
	_check(Biens.buy("mobylette", true), "mobylette financée par M. Brunet")
	_check(Game.debt == debt + 525 and Game.credits == 4800, "dette : prix et frais de dossier, crédits intacts")
	_check(Biens.standing() == 1 and Biens.driven == "mobylette", "standing 1, on conduit la mobylette")
	var before := Game.credits
	_bets(19)
	_check(Biens.recettes == 0, "pas de recette avant 20 mises")
	_bets(1)
	_check(Biens.recettes == 1, "une recette à la 20e mise")
	var paid := Game.credits - (before - 20 * 25)
	_check(paid >= 7 - 5 and paid <= 20 - 5, "recette pleine entre 35 et 100 %% de 20, moins 5 de charges (%d)" % paid)
	_bets(20, 5)
	_check(Biens.last_animation == 0.2, "recette au cinquième quand on mise 5 (%.2f)" % Biens.last_animation)
	var c := Game.credits
	_check(Biens.sell("smarvoise") == 120 and Game.credits == c + 120, "revente à 60 %")
	Game.advances_left = 0
	_check(Biens.offer_tournee() and Game.advances_left == 1, "la tournée remet une avance")
	# La reprise : grosse dette, peu de biens.
	Game.debt = 20000
	Biens._since_reprise = Biens.REPRISE_EVERY
	_bets(20)
	_check(Biens.reprises == 1 and Biens.count("mobylette") == 0, "M. Brunet reprend la mobylette")
	# Les logements : louer ou habiter.
	Game.credits = 5000
	_check(Biens.buy("chambre") and Biens.logements.has("chambre"), "la chambre achetée devient un logement")
	_check(Biens.logements.chambre.lot == "chambre_cafe" and not Biens.is_habite("chambre"), "lot chambre_cafe, louée d'abord")
	var s0 := Biens.standing()
	var r0 := Biens.rente_annoncee()
	Biens.habiter("chambre")
	_check(Biens.habite() == "chambre" and Biens.rente_annoncee() == r0 - 80, "habitée : plus de rente annoncée")
	_check(Biens.standing() == s0 + 1, "habitée : standing compté deux fois (%d → %d)" % [s0, Biens.standing()])
	Biens.logements.chambre.meubles["mur_gauche"] = "affiche_loto_1987"
	Biens.louer("chambre")
	_check(Biens.habite() == "" and Biens.rente_annoncee() == r0, "remise en location")
	# L'ameublement : un meuble de la brocante sur un emplacement du bon genre.
	Game.won = 25000
	# Les obligations de l'Étoile ne sont pas des biens : le lot du plan ne s'achète pas, le championnat les tient.
	Game.credits = 5000
	_check(not Biens.available("etoile") and not Biens.buy("etoile") and Biens.item("etoile").kind == "club", "le lot de l'Étoile ne s'achète pas à l'étude")
	_check(Biens.facteur_club("smarves") >= 0.7 and Biens.facteur_club("smarves") <= 1.4, "le facteur du club est entre ×0,7 et ×1,4")
	_check(Biens.slots("chambre").size() == 6, "la chambre a 6 emplacements")
	Biens.logements.chambre.interieur = "maison_v1"
	_check(Biens.slots("chambre").size() == 24, "le gabarit de la maison en a 24")
	Biens.logements.chambre.interieur = "maison_place_v1"
	_check(Biens.slots("chambre").size() == 48, "celui de la maison de maître 48")
	Biens.logements.chambre.interieur = "chambre_v1"
	_check(Biens.trouvailles.has("premier_jeton"), "le premier jeton, remis avec le premier logement")
	Game.credits = 5000
	_check(Biens.buy("lit_cuivre") and Biens.free_count("lit_cuivre") == 1, "un lit acheté chez Ginette, pas encore posé")
	_check(not Biens.poser("chambre", "chambre_mur_1", "lit_cuivre"), "un lit ne se pose pas au mur")
	_check(Biens.poser("chambre", "chambre_lit_1", "lit_cuivre") and Biens.free_count("lit_cuivre") == 0, "posé sur l'emplacement du lit")
	var s1 := Biens.standing()
	Biens.habiter("chambre")
	_check(Biens.standing() == s1 + 1 + 1, "habitée : chambre et lit comptent (%d → %d)" % [s1, Biens.standing()])
	_check(Biens.sell("lit_cuivre") > 0 and not Biens.logements.chambre.meubles.has("chambre_lit_1"), "revendu, le lit se décroche")
	Biens.buy("lit_cuivre")
	Biens.poser("chambre", "chambre_lit_1", "lit_cuivre")
	Biens.louer("chambre")
	_check(Biens.door_of("chambre_cafe").owned and Biens.door_of("maison_place").en_vente, "door_of : la chambre est à nous, la maison de maître en vente")
	# Saisie d'une maison habitée, avec une trouvaille au mur : un carton, et retour à l'hôtel.
	Biens.habiter("chambre")
	var noted := []
	Biens.note.connect(func(t): noted.append(t))
	Game.debt = 20000
	Biens._since_reprise = Biens.REPRISE_EVERY
	_bets(20)
	_check(not Biens.logements.has("chambre") and Biens.habite() == "", "M. Brunet reprend la chambre, retour à l'hôtel")
	_check(Biens.count("lit_cuivre") == 0, "le lit part avec la chambre")
	_check(noted.size() > 0 and "carton" in noted[-1], "la trouvaille revient dans un carton")
	# Toutes les adresses du village sont au registre : maisons, murs des boutiques, bâtiments publics.
	var reg := Biens.NOTAIRE.registre(Commune.smarves())
	var numeros: Array = reg.adresses.filter(func(a): return int(a.numero) > 0)
	_check(numeros.size() >= 30, "plus de trente adresses dans les rues (%d)" % numeros.size())
	for a in reg.adresses:
		_check(not Biens.item(a.id).is_empty(), "l'adresse %s a sa fiche (%s)" % [a.ligne, a.id])
	_check(Biens.NOTAIRE.verifier(Commune.smarves().data.notaire).is_empty(), "le notaire du manifeste est bien écrit")
	_check(Biens.item("adr_mairie").kind == "murs" and Biens.item("adr_mairie").gate == 0, "les murs de la mairie se vendent dès le départ")
	var maisons: Array = reg.adresses.filter(func(a): return a.genre == "maison")
	var m: String = maisons[0].id
	Game.credits = 50000
	_check(Biens.buy(m) and Biens.logements.has(m), "une maison de la rue devient un logement (%s)" % m)
	_check(Biens.slots(m).size() > 0, "et a ses emplacements (%s)" % Biens.logements[m].interieur)
	var r1 := Biens.rente_annoncee()
	Biens.habiter(m)
	_check(Biens.habite() == m and Biens.rente_annoncee() == r1 - Biens.item(m).rente, "habitée, elle ne verse plus de rente")
	var s2 := Biens.standing()
	_check(Biens.buy("adr_boucherie") and Biens.standing() == s2 + Biens.item("adr_boucherie").standing, "les murs de la boucherie comptent au standing")
	_check(Biens.charges() >= Biens.item("adr_boucherie").charge, "et coûtent leurs charges")
	_check(not Biens.logements.has("adr_boucherie"), "des murs ne sont pas un logement")
	# Le grenier : on y monte ce qu'on n'a pas posé, on l'en redescend, et il a ses limites.
	Game.credits += 5000
	Biens.buy("tableau_marine")
	_check(Biens.rangeables().has("tableau_marine"), "un meuble pas posé peut monter au grenier")
	_check(Biens.ranger(m, "tableau_marine") and Biens.grenier(m) == ["tableau_marine"], "il y monte")
	_check(Biens.free_count("tableau_marine") == 0 and not Biens.posables("mur").has("tableau_marine"), "rangé, il ne se pose plus")
	_check(not Biens.ranger(m, "tableau_marine"), "on ne range pas deux fois la même chose")
	_check(Biens.capacite_grenier(m) >= 6, "le grenier tient des cartons (%d)" % Biens.capacite_grenier(m))
	_check(Biens.sortir(m, "tableau_marine") and Biens.free_count("tableau_marine") == 1, "et il en redescend")
	Biens.ranger(m, "tableau_marine")
	Biens.sell("tableau_marine")
	_check(Biens.grenier(m).is_empty(), "revendu, il quitte le grenier")
	Game.staked = 0
	Game.changed.emit()
	_check(Biens.owned.is_empty() and Biens.recettes == 0 and Biens.logements.is_empty(), "nouvelle partie : plus de biens")
	print("\n%s" % ("Tout est bon." if _fails == 0 else "%d échec(s)." % _fails))
	get_tree().quit(_fails)
