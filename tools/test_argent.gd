extends SceneTree
## Vérifie l'argent tenu par le serveur sans réseau : godot --headless --path . -s tools/test_argent.gd
## Un faux serveur suit les règles de la migration (supabase/migrations/20261019020000_smarves_argent.sql :
## smarves_argent_ouvrir, smarves_argent_mouvement, smarves_argent) : la base sans les fonctions (le jeu
## reste local), l'ouverture du solde avec la poche de l'appareil, les jeux qui font bouger la poche, la
## file hors ligne, la réponse perdue rejouée sous la même clé, l'argent dépensé ailleurs (Casino Minuit),
## le refus d'un solde négatif, le plafond du change, un deuxième appareil, la même file rejouée par deux
## appareils, et un autre compte. La vraie partie n'est pas touchée (les tests n'écrivent rien).

var fails := 0
var argent: Node
var game: Node
var compte: Node

## Le faux serveur : « en_ligne », « hors_ligne » (rien ne revient), « absent » (la migration n'est pas
## appliquée : 404), « perdu » (le mouvement passe, mais la réponse se perd).
var mode := "en_ligne"
var moi := "alice"
var comptes := {}
var journal: Array = []
var plafonds := {"casino_minuit": {"entree": 50000, "sortie": 50000}}
var appels := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	argent = root.get_node("Argent")
	game = root.get_node("Game")
	compte = root.get_node("Compte")
	game.tiroirs.erase(argent.TIROIR)
	compte.joueur_id = moi
	argent.appel = serveur

	# La base n'a pas encore les fonctions : le jeu reste local, sans erreur ni changement.
	mode = "absent"
	game.credits = 1200
	await argent.rapprocher()
	check(argent.etat == "absent" and game.credits == 1200 and not argent.ouvert(), "sans la migration, le jeu reste local")
	var avant := appels
	await argent.rapprocher()
	check(appels == avant, "et ne redemande pas avant la demi-heure")
	argent._absent_a = -100000.0

	# L'ouverture : le solde du serveur part de la poche de l'appareil.
	mode = "en_ligne"
	await argent.rapprocher()
	check(argent.etat == "a_jour" and argent.ouvert() and comptes.get(moi) == 1200, "le solde s'ouvre avec la poche : %s" % str(comptes.get(moi)))
	check(journal.size() == 1 and journal[0].motif == "ouverture", "l'ouverture est au journal")

	# Les jeux font bouger la poche : le rapprochement l'envoie.
	game.cash_in(300)
	await argent.rapprocher()
	check(comptes[moi] == 1500 and journal[-1].motif == "jeu" and journal[-1].montant == 300, "un gain des jeux part au serveur")
	await argent.rapprocher()
	check(journal.size() == 2 and game.credits == 1500, "rien n'a bougé : rien ne part")

	# Hors ligne : la file attend, le jeu continue.
	mode = "hors_ligne"
	game.spend(200)
	await argent.rapprocher()
	game.spend(100)
	await argent.rapprocher()
	check(argent.etat == "hors_ligne" and argent.en_attente() == 2 and game.credits == 1200, "hors ligne, deux mouvements attendent")
	check(comptes[moi] == 1500, "le serveur n'a encore rien vu")
	mode = "en_ligne"
	await argent.rapprocher()
	check(argent.en_attente() == 0 and comptes[moi] == 1200 and game.credits == 1200 and argent.etat == "a_jour", "de retour, la file part dans l'ordre")

	# La réponse se perd : le mouvement est passé, il est rejoué sous la même clé et compté une fois.
	mode = "perdu"
	game.cash_in(500)
	await argent.rapprocher()
	check(comptes[moi] == 1700 and argent.en_attente() == 1, "réponse perdue : le serveur a compté, l'appareil ne le sait pas")
	var n := journal.size()
	mode = "en_ligne"
	await argent.rapprocher()
	check(comptes[moi] == 1700 and journal.size() == n and argent.en_attente() == 0 and game.credits == 1700, "rejoué sous la même clé, il n'est compté qu'une fois")

	# Casino Minuit dépense au serveur : la poche s'y range.
	_ailleurs("casino_minuit", "jetons", -700)
	await argent.rapprocher()
	check(game.credits == 1000 and comptes[moi] == 1000, "ce que Minuit a pris quitte la poche : %d" % game.credits)

	# Un mouvement que la poche ne couvre pas est refusé sur place.
	check(not argent.mouvement("casino_minuit", "jetons", -2000) and game.credits == 1000, "pas de solde négatif dans la poche")

	# Minuit a dépensé pendant que les jeux perdaient : le serveur refuse de descendre sous zéro, on
	# perd ce qui reste, pas davantage.
	_ailleurs("casino_minuit", "jetons", -900)
	game.credits -= 400
	await argent.rapprocher()
	check(_refuse("solde"), "le serveur refuse un solde négatif")
	check(comptes[moi] == 0 and game.credits == 0 and argent.en_attente() == 0, "on perd ce qui reste : poche %d, serveur %d" % [game.credits, comptes[moi]])
	check(_somme() == comptes[moi], "le solde est la somme du journal")

	# Le change, plafonné par jour : revendre 60 000 jetons d'un coup est refusé, et défait sur l'appareil.
	game.cash_in(80000)
	await argent.rapprocher()
	# (Le mouvement part aussitôt : le faux serveur répond dans la même image.)
	check(argent.mouvement("casino_minuit", "jetons", 60000), "revendre 60 000 jetons")
	await argent.rapprocher()
	check(_refuse("plafond") and comptes[moi] == 80000 and game.credits == 80000, "au-delà du plafond du jour, il est refusé et défait")
	check(argent.mouvement("casino_minuit", "jetons", -30000), "acheter 30 000 jetons")
	await argent.rapprocher()
	check(comptes[moi] == 50000 and game.credits == 50000, "sous le plafond, il passe : %d" % comptes[moi])

	# Un deuxième appareil, partie neuve : il ne rouvre pas le solde, il s'y range.
	var tiroir_a: Dictionary = game.tiroir(argent.TIROIR).duplicate(true)
	game.tiroirs.erase(argent.TIROIR)
	game.credits = 1000
	await argent.rapprocher()
	check(game.credits == 50000 and comptes[moi] == 50000 and journal.filter(func(m): return m.motif == "ouverture").size() == 1,
		"un autre appareil se range au solde du serveur, sans le rouvrir")

	# La même file reprise par deux appareils (la partie est partie au compte avec elle) : comptée une fois.
	mode = "hors_ligne"
	game.tiroirs[argent.TIROIR] = tiroir_a
	game.credits = 50000
	game.cash_in(250)
	await argent.rapprocher()
	var copie: Dictionary = game.tiroir(argent.TIROIR).duplicate(true)
	mode = "en_ligne"
	await argent.rapprocher()
	game.tiroirs[argent.TIROIR] = copie
	game.credits = 50250
	await argent.rapprocher()
	check(comptes[moi] == 50250 and game.credits == 50250 and argent.en_attente() == 0, "une file rejouée par un autre appareil ne compte qu'une fois")

	# Un autre compte sur la même partie : le solde de référence ne vaut plus, on ouvre le sien.
	moi = "bob"
	compte.joueur_id = "bob"
	await argent.rapprocher()
	check(comptes.get("bob") == 50250 and comptes["alice"] == 50250 and argent.ouvert(), "un autre compte ouvre son propre solde")

	# Sans compte, rien ne part.
	argent.appel = Callable()
	compte.joueur_id = ""
	avant = appels
	await argent.rapprocher()
	check(appels == avant, "sans compte, rien ne part")
	game.tiroirs.erase(argent.TIROIR)

	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


# ---------------------------------------------------------------- le faux serveur

var _refus: Array = []


func _refuse(raison: String) -> bool:
	return raison in _refus


func _somme() -> int:
	var s := 0
	for m in journal:
		if m.joueur == moi:
			s += int(m.montant)
	return s


## Un mouvement fait au serveur par un autre (Casino Minuit, un autre appareil).
func _ailleurs(source: String, motif: String, montant: int) -> void:
	var r := _mouvement("ailleurs-%d" % journal.size(), source, motif, montant)
	check(r.ok, "%s : %d au serveur" % [source, montant])


func _mouvement(cle: String, source: String, motif: String, montant: int) -> Dictionary:
	if not comptes.has(moi):
		return {"ok": false, "raison": "compte"}
	for m in journal:
		if m.joueur == moi and m.cle == cle:
			if m.source == source and m.motif == motif and m.montant == montant:
				return {"ok": true, "deja": true, "solde": comptes[moi]}
			return {"ok": false, "raison": "cle", "solde": comptes[moi]}
	if comptes[moi] + montant < 0:
		_refus.append("solde")
		return {"ok": false, "raison": "solde", "solde": comptes[moi]}
	if plafonds.has(source):
		var entre := 0
		var sort := 0
		for m in journal:
			if m.joueur == moi and m.source == source:
				if m.montant > 0:
					entre += m.montant
				else:
					sort -= m.montant
		if (montant > 0 and entre + montant > plafonds[source].entree) or (montant < 0 and sort - montant > plafonds[source].sortie):
			_refus.append("plafond")
			return {"ok": false, "raison": "plafond", "solde": comptes[moi]}
	comptes[moi] += montant
	journal.append({"joueur": moi, "cle": cle, "source": source, "motif": motif, "montant": montant})
	return {"ok": true, "solde": comptes[moi], "id": journal.size()}


func serveur(fonction: String, corps: Dictionary) -> Dictionary:
	appels += 1
	if mode == "absent":
		return {"code": 404, "corps": {"code": "PGRST202", "message": "Could not find the function public.%s" % fonction}}
	if mode == "hors_ligne":
		return {"code": 0, "corps": null}
	match fonction:
		"smarves_argent_ouvrir":
			if comptes.has(moi):
				return {"code": 200, "corps": {"ok": true, "cree": false, "solde": comptes[moi]}}
			comptes[moi] = int(corps.p_solde)
			journal.append({"joueur": moi, "cle": corps.p_cle, "source": "smarves", "motif": "ouverture", "montant": int(corps.p_solde)})
			return {"code": 200, "corps": {"ok": true, "cree": true, "solde": comptes[moi]}}
		"smarves_argent_mouvement":
			var cle := str(corps.p_cle)
			if not RegEx.create_from_string("^[A-Za-z0-9_.:-]{8,80}$").search(cle):
				return {"code": 400, "corps": {"message": "cle invalide"}}
			var r := _mouvement(cle, corps.p_source, corps.p_motif, int(corps.p_montant))
			if mode == "perdu":
				return {"code": 0, "corps": null}
			return {"code": 200, "corps": r}
		"smarves_argent":
			if not comptes.has(moi):
				return {"code": 200, "corps": {"ouvert": false}}
			return {"code": 200, "corps": {"ouvert": true, "solde": comptes[moi], "mouvements": [], "change": {}}}
	return {"code": 404, "corps": null}
