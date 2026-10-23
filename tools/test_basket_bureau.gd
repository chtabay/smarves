extends SceneTree
## Vérifie le bureau du club de basket sans affichage : godot --headless --path . -s tools/test_basket_bureau.gd
## Un faux serveur tient les mêmes règles que les fonctions smarves_basket_* (supabase/migrations) : les
## obligations décident de qui dirige, les enchères du groupe se règlent au jeudi 22 h (la meilleure offre
## qui tient dans l'effectif et sous le plafond), une mise dépassée est rendue, un joueur libéré part et
## coûte encore la moitié de son salaire, la consigne passe au match, les dividendes se versent ; le
## tableau des parts et le bureau s'ouvrent et agissent.

const CLICHE := "res://tools/fixtures/basket_cliche.json"

var fails := 0
var t := 0
## Le faux serveur : ce que les tables tiendraient.
var serveur := {"obligations": [], "encheres": [], "liberations": [], "consignes": [], "noms": []}
var appels: Array = []
var quand := 0
var basket: Node
var game: Node


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func gymnase(commune: String, club: String) -> Dictionary:
	return {"commune": commune, "nom": "La salle de " + commune, "type": "gymnase", "champs": {"club": club}}


## Les règles des fonctions du serveur, pour le joueur « Moi » ; un autre agit en posant ses lignes à la main.
func appel(f: String, c: Dictionary) -> Dictionary:
	appels.append(f)
	match f:
		"smarves_basket_bureau":
			var out := {}
			for k in serveur:
				out[k] = (serveur[k] as Array).map(func(x):
					var y: Dictionary = x.duplicate()
					y.moi = str(x.get("par", "")) == "Moi"
					return y)
			return {"code": 200, "corps": out}
		"smarves_basket_obligation_prendre":
			if serveur.obligations.any(func(o): return o.club == c.p_club and int(o.rang) == int(c.p_rang)):
				return {"code": 200, "corps": {"ok": false, "raison": "prise"}}
			serveur.obligations.append({"club": c.p_club, "rang": int(c.p_rang), "par": "Moi"})
			return {"code": 200, "corps": {"ok": true}}
		"smarves_basket_obligation_rendre":
			serveur.obligations = serveur.obligations.filter(func(o): return not (o.club == c.p_club and int(o.rang) == int(c.p_rang) and o.par == "Moi"))
			return {"code": 200, "corps": {"ok": true}}
		"smarves_basket_encherir":
			if t >= basket.cloture(c.p_saison, c.p_journee):
				return {"code": 200, "corps": {"ok": false, "raison": "ferme"}}
			if not dirige(c.p_club, "Moi"):
				return {"code": 200, "corps": {"ok": false, "raison": "parts"}}
			var meilleure := 0
			for o in serveur.encheres:
				if int(o.saison) == c.p_saison and int(o.journee) == c.p_journee and o.groupe == c.p_groupe and o.joueur == c.p_joueur:
					meilleure = maxi(meilleure, int(o.montant))
			if meilleure > 0 and int(c.p_montant) < meilleure + basket.pas(meilleure):
				return {"code": 200, "corps": {"ok": false, "raison": "bas"}}
			quand += 1
			serveur.encheres.append({"saison": c.p_saison, "journee": c.p_journee, "groupe": c.p_groupe, "joueur": c.p_joueur, "club": c.p_club,
				"montant": int(c.p_montant), "par": "Moi", "quand": "%06d" % quand})
			return {"code": 200, "corps": {"ok": true, "quand": "%06d" % quand}}
		"smarves_basket_liberer":
			if t >= basket.cloture(c.p_saison, c.p_journee):
				return {"code": 200, "corps": {"ok": false, "raison": "ferme"}}
			serveur.liberations.append({"saison": c.p_saison, "journee": c.p_journee, "club": c.p_club, "joueur": c.p_joueur, "par": "Moi"})
			return {"code": 200, "corps": {"ok": true}}
		"smarves_basket_consigne":
			serveur.consignes = serveur.consignes.filter(func(x): return not (int(x.saison) == c.p_saison and int(x.journee) == c.p_journee and x.club == c.p_club))
			serveur.consignes.append({"saison": c.p_saison, "journee": c.p_journee, "club": c.p_club, "consigne": c.p_consigne, "par": "Moi"})
			return {"code": 200, "corps": {"ok": true}}
		"smarves_basket_nommer":
			if not basket.nom_valide(c.p_nom):
				return {"code": 200, "corps": {"ok": false, "raison": "nom"}}
			if not serveur.obligations.any(func(o): return o.club == c.p_club and o.par == "Moi"):
				return {"code": 200, "corps": {"ok": false, "raison": "detenir"}}
			if not dirige(c.p_club, "Moi"):
				return {"code": 200, "corps": {"ok": false, "raison": "parts"}}
			serveur.noms = serveur.noms.filter(func(x): return x.club != c.p_club)
			serveur.noms.append({"club": c.p_club, "nom": c.p_nom, "par": "Moi"})
			return {"code": 200, "corps": {"ok": true}}
	return {"code": 404, "corps": null}


func dirige(club: String, qui: String) -> bool:
	var par := {}
	for o in serveur.obligations:
		if o.club == club:
			par[o.par] = int(par.get(o.par, 0)) + basket.valeur(int(o.rang))
	return par.is_empty() or int(par.get(qui, 0)) >= par.values().max()


func textes(n: Node) -> String:
	var out: Array = []
	var pile: Array = [n]
	while not pile.is_empty():
		var x: Node = pile.pop_back()
		if x is Label or x is Button:
			out.append(x.text)
		pile.append_array(x.get_children())
	return "\n".join(out)


func trouver(n: Node, nom: String) -> Node:
	return n.find_child(nom, true, false)


func _init() -> void:
	await process_frame
	basket = root.get_node("Basket")
	game = root.get_node("Game")
	basket.dossier = ""
	basket.effacer()
	basket.regler_horloge(func(): return t)
	basket.appel = appel
	var inscrits: Array = [gymnase("smarves", "Les Hérons du Clain"), gymnase("rivale", "Les Loups de Rivale")]
	basket.source_gymnases = func(): return inscrits
	game.credits = 100000

	t = basket.coup_envoi(1, 1) - 3600
	# Avant le cliché de la première journée : pas d'effectif, le marché attend, et le bureau le dit.
	basket.actualiser()
	check(not basket.tirage_fait("smarves") and basket.joueurs_libres("smarves").is_empty(), "avant le tirage, le marché attend")
	var avant_tirage: PanelContainer = load("res://scripts/socle/basket_bureau.gd").new()
	avant_tirage.commune = "smarves"
	root.add_child(avant_tirage)
	await process_frame
	basket.cliches["2000-01-01"] = {"id": "2000-01-01", "joueurs": {}}
	avant_tirage.rafraichir()
	check(textes(avant_tirage).contains("L'effectif n'est pas encore tiré"), "le bureau dit que l'effectif se tire avec les premières notes")
	# Un texte dans une rangée garde sa largeur (il s'écrivait une lettre par ligne).
	var consigne_l: Label = null
	for x in avant_tirage.find_children("*", "Label", true, false):
		if x.get_parent() is HFlowContainer:
			consigne_l = x
	check(consigne_l == null or consigne_l.autowrap_mode == TextServer.AUTOWRAP_OFF, "un texte en rangée ne se replie pas")
	avant_tirage.queue_free()
	basket.cliches.erase("2000-01-01")
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CLICHE))
	for j in [1, 2, 3]:
		var c: Dictionary = fixture.duplicate(true)
		c.id = basket.id_cliche(1, j)
		basket.garder(c)
	var ici: Array = basket.place_de("smarves")
	var rivale: Array = basket.place_de("rivale")
	check(ici.size() == 3 and rivale.size() == 3 and ici[1] == rivale[1], "les Hérons et les Loups dans le même groupe")

	# Le tirage tient sous le plafond.
	var sous := true
	var masses: Array = []
	for p in 8:
		var m: int = basket._masse(basket.marche_du_groupe(1, 0, 0, 1), p)
		masses.append(m)
		sous = sous and m <= basket.PLAFOND and (basket.effectif(1, 0, 0, p, 1) as Array).size() == 10
	check(sous, "dix joueurs par club, masses du tirage sous %d : %s" % [basket.PLAFOND, str(masses)])
	check(basket.salaire_de(85) > 2 * basket.salaire_de(55) and basket.prix_de(85) == 8 * basket.salaire_de(85), "le salaire et le prix suivent la note (85 : %d, 55 : %d)" % [basket.salaire_de(85), basket.salaire_de(55)])

	# Les obligations : qui dirige.
	serveur.obligations.append({"club": "smarves", "rang": 5, "par": "Lucien"})
	await basket.lire()
	check(not basket.peut_decider("smarves") and basket.porteur("smarves", 5).nom == "Lucien", "Lucien tient la n° 5 : c'est lui qui dirige")
	check(basket.joueurs_libres("smarves").size() > 100, "le marché du groupe : %d joueurs libres" % basket.joueurs_libres("smarves").size())
	var r: Dictionary = await basket.encherir("smarves", basket.joueurs_libres("smarves")[0].code, 100000)
	check(not r.ok and r.raison == "parts", "sans diriger, pas d'enchère")
	var avant: int = game.credits
	check(basket.prendre("smarves", 9).ok and game.credits == avant - 7500, "la n° 9 prise pour 7 500 crédits")
	await basket.envoyer()
	check(serveur.obligations.size() == 2 and basket.peut_decider("smarves") and basket.a_declarer.is_empty(), "le serveur la sait ; vous dirigez")
	check(not basket.prendre("smarves", 5).ok, "la n° 5 est déjà prise")

	# Une enchère, dépassée, reprise, gagnée à la clôture.
	var cible: Dictionary = basket.joueurs_libres("smarves")[0]
	avant = game.credits
	r = await basket.encherir("smarves", cible.code, cible.prix - 10)
	check(not r.ok and r.raison == "bas", "sous le prix de départ, refusé")
	r = await basket.encherir("smarves", cible.code, cible.prix)
	check(r.ok and game.credits == avant - cible.prix and basket.joueurs_libres("smarves")[0].moi, "mise de %d crédits retenue, vous menez" % cible.prix)
	quand += 1
	serveur.encheres.append({"saison": 1, "journee": 2, "groupe": "0-0", "joueur": cible.code, "club": "rivale", "montant": cible.prix + 500, "par": "Odile", "quand": "%06d" % quand})
	await basket.lire()
	check(game.credits == avant, "les Loups passent devant : la mise est rendue")
	r = await basket.encherir("smarves", cible.code, cible.prix + 510)
	check(not r.ok and r.raison == "bas", "il faut le surplus minimum")
	r = await basket.encherir("smarves", cible.code, cible.prix + 600)
	check(r.ok and game.credits == avant - cible.prix - 600, "nouvelle mise, vous menez")
	# Une offre de la rivale sur un autre joueur, et une libération de notre côté.
	var autre: Dictionary = basket.joueurs_libres("smarves")[1]
	quand += 1
	serveur.encheres.append({"saison": 1, "journee": 2, "groupe": "0-0", "joueur": autre.code, "club": "rivale", "montant": autre.prix, "par": "Odile", "quand": "%06d" % quand})
	var depart: Dictionary = basket.effectif(1, ici[0], ici[1], ici[2], 1)[9]
	r = await basket.liberer("smarves", depart.code)
	check(r.ok and basket.liberations_prevues("smarves").has(depart.code), "un joueur libéré à la clôture")
	r = await basket.poser_consigne("smarves", "rotation")
	check(r.ok and basket.equipe(1, ici[0], ici[1], ici[2], 1).consigne == "rotation", "la consigne « rotation » pour la journée 1")

	t = basket.cloture(1, 2) + 60
	await basket.lire()
	var apres: Array = basket.effectif(1, ici[0], ici[1], ici[2], 2)
	var codes: Array = apres.map(func(e): return e.code)
	check(codes.has(cible.code) and not codes.has(depart.code) and apres.size() == 10, "à la clôture : la recrue arrive, le libéré part")
	check(game.credits == avant - cible.prix - 600 and basket.retenues.is_empty(), "la mise gagnante est payée, rien n'est rendu")
	check((basket.effectif(1, rivale[0], rivale[1], rivale[2], 2) as Array).any(func(e): return e.code == autre.code) == ((basket.effectif(1, rivale[0], rivale[1], rivale[2], 1) as Array).size() < 10),
		"les Loups n'ont leur joueur que s'il leur reste une place")
	var masse: int = basket.masse_salariale("smarves", 2)
	var attendue := 0
	for e in apres:
		attendue += int(e.salaire)
	check(masse == attendue + int(depart.salaire) / 2, "la masse compte la moitié du salaire du libéré (%d)" % masse)
	check(basket.equipe(1, ici[0], ici[1], ici[2], 2).consigne == "rotation", "la consigne tient tant qu'on n'en pose pas d'autre")
	var suivant: Dictionary = basket.joueurs_libres("smarves")[0]
	var r2: Dictionary = await basket.encherir("smarves", suivant.code, suivant.prix)
	check(basket.journee_du_marche() == 3 and r2.ok, "le marché suivant s'ouvre pour la journée 3")
	basket.retenues.clear()

	# Les dividendes après deux journées jouées.
	t = basket.coup_envoi(1, 2) + 3 * 3600
	var dus: Array = basket.dividendes_dus()
	avant = game.credits
	var verse: int = basket.verser_dividendes()
	check(dus.size() == 2 and verse > 0 and game.credits == avant + verse and basket.dividendes_dus().is_empty(), "deux journées de dividendes versées : %d crédits" % verse)
	check(basket.dividende("smarves", 9, 2) > basket.dividende("smarves", 1, 2), "la n° 9 rapporte plus que la n° 1")

	# Le tableau des parts et le bureau s'ouvrent.
	var parts: PanelContainer = load("res://scripts/socle/basket_parts.gd").new()
	parts.commune = "smarves"
	root.add_child(parts)
	await process_frame
	var tout := textes(parts)
	check(tout.contains("LES HÉRONS DU CLAIN") and tout.contains("tenue par Lucien") and tout.contains("à vous") and trouver(parts, "Prendre_1") != null, "le tableau des parts : les porteurs et les obligations libres")
	avant = game.credits
	(trouver(parts, "Prendre_1") as Button).pressed.emit()
	await process_frame
	check(game.credits == avant - 500 and basket.mes_obligations("smarves").has(1), "le bouton Prendre prend la n° 1")
	parts.queue_free()

	var bureau: PanelContainer = load("res://scripts/socle/basket_bureau.gd").new()
	bureau.commune = "smarves"
	root.add_child(bureau)
	await process_frame
	tout = textes(bureau)
	check(tout.contains("LE BUREAU DU PRÉSIDENT") and tout.contains("Consigne pour la journée") and tout.contains("par journée"), "le bureau : l'équipe et la consigne")
	var bb := load("res://scripts/socle/basket_bureau.gd")
	check(bb.nom_lisible("HORTON TUCKER, TALEN") == "Talen Horton Tucker" and bb.poste_fr("Guard") == "arrière", "les noms en clair, le poste en français")
	check(bb.match_lisible({"date": "2026-03-20", "pts": 23, "reb": 1, "pd": 2, "pir": 19, "adv": "MIL"}) == "20/03 · 23 pts, 1 rbd, 2 pd · éval. 19 · contre MIL", "le dernier match en clair")
	check(not tout.contains("PIR"), "plus de sigle PIR dans l'effectif")
	(trouver(bureau, "Onglet_marche") as Button).pressed.emit()
	await process_frame
	tout = textes(bureau)
	check(tout.contains("Les joueurs libres du groupe") and trouver(bureau, "Encherir_" + str(basket.joueurs_libres("smarves")[1].code)) != null, "le marché : les joueurs libres et la case de mise")
	(trouver(bureau, "Onglet_comptes") as Button).pressed.emit()
	await process_frame
	check(textes(bureau).contains("Masse salariale"), "les comptes")

	# Renommer le club : son dirigeant, s'il en tient des parts ; le nom vaut pour tous, et revient du serveur.
	check(basket.peut_decider("smarves") and basket.investi("smarves") > 0 and trouver(bureau, "Renommer") != null, "le dirigeant voit la case du nom du club")
	check(not basket.nom_valide("ab") and not basket.nom_valide("<b>Club</b>") and basket.nom_valide("L'Étoile du Clain & Co."), "un nom de 3 à 40 caractères, sans balise")
	var r_nom: Dictionary = await basket.renommer("smarves", "x")
	check(not r_nom.ok and r_nom.raison == "nom", "un nom trop court est refusé")
	(trouver(bureau, "NomDuClub") as LineEdit).text = "  Les  Grues   du Clain "
	(trouver(bureau, "Renommer") as Button).pressed.emit()
	await process_frame
	await process_frame
	check(basket.fiche("smarves").nom == "Les Grues du Clain" and basket.clubs.smarves.nom == "Les Hérons du Clain", "le club s'appelle les Grues du Clain ; le gymnase garde son nom d'origine")
	check(textes(bureau).contains("LES GRUES DU CLAIN"), "le bureau prend le nouveau nom")
	basket.bureau.noms = []
	await basket.lire()
	check(basket.nom_choisi("smarves") == "Les Grues du Clain", "le nom revient du serveur, pour tous les joueurs")
	serveur.obligations.append({"club": "rivale", "rang": 9, "par": "Lucien"})
	r_nom = await basket.renommer("rivale", "Les Grues de Rivale")
	check(not r_nom.ok and r_nom.raison in ["detenir", "parts"], "on ne renomme pas un club dont on n'a pas de part")
	bureau.queue_free()

	print("\n%s" % ("TOUT EST BON" if fails == 0 else "%d ÉCHEC(S)" % fails))
	quit(1 if fails else 0)
