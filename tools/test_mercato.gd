extends SceneTree
## Vérifie le marché des transferts sans affichage : godot --headless --path . -s tools/test_mercato.gd
## Le calendrier des lots (le même que le serveur), le tirage de la semaine, le vieillissement, puis les
## enchères contre un faux serveur qui suit les règles de la migration (smarves_mercato_encherir,
## smarves_mercato_vendre, smarves_mercato) : l'acheteur invité qui surenchérit sous son plafond, la mise
## retenue puis rendue ou dépensée, la prolongation de dernière minute, la vente d'un joueur acheté et son
## encaissement, qui possède qui, et ce que le moteur reçoit par journée. Enfin la fenêtre.

const TMP := "user://test_mercato/"

var fails := 0
var t := 0
var m: Node
var foot: Node

## Le faux serveur : ses tables, et qui dirige quel club (pyramide_id -> club).
var encheres: Array = []
var ventes: Array = []
var prolongations := {}
var moi := "moi"
var directeurs := {}
var id_vente := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	foot = root.get_node("Football")
	m = root.get_node("Mercato")
	var game: Node = root.get_node("Game")
	DirAccess.make_dir_recursive_absolute(TMP)
	foot.dossier = TMP
	m.dossier = TMP
	foot.effacer()
	m.effacer()
	foot.regler_horloge(func(): return t)
	# Le dimanche 18 octobre 2026 à 18 h, une heure après l'ouverture de la semaine 0.
	t = foot.coup_envoi(1, 1) - 7 * 86400 + 3 * 3600
	foot.actualiser()
	check(foot.clubs.has("smarves"), "la pyramide se fonde, avec l'Étoile")
	var autre := ""
	for id in foot.clubs:
		if id != "smarves":
			autre = id
			break

	_calendrier()
	_tirage()

	# Le faux serveur et un compte : enchérir devient possible.
	m.appel = serveur
	game.credits = 50000
	var k: int = m.semaine_a(t)
	var lots: Array = m.lots_semaine(k)
	var cible: Dictionary = lots.filter(func(e): return not e.ferme and e.plafond >= e.prix_depart)[0]
	var lot: String = cible.lot
	check(cible.meneur == "" or cible.meneur == "invite", "personne n'a encore enchéri sur %s" % lot)

	# Trop bas, puis sous le plafond de l'acheteur invité : il surenchérit aussitôt, rien n'est retenu.
	var r: Dictionary = await m.encherir(lot, "smarves", int(cible.minimum) - 10)
	check(not r.ok and r.raison == "bas", "une offre sous le minimum est refusée")
	var sous := int(cible.minimum)
	if sous >= int(cible.plafond):
		sous = int(cible.plafond) - 10
	r = await m.encherir(lot, "smarves", maxi(sous, int(cible.prix_depart)))
	var e: Dictionary = m.enchere(lot)
	if int(cible.plafond) > maxi(sous, int(cible.prix_depart)):
		check(r.ok and not r.mene and e.meneur == "invite" and e.prix > maxi(sous, int(cible.prix_depart)), "sous son plafond, %s surenchérit aussitôt (%d)" % [e.acheteur, e.prix])
		check(game.credits == 50000 and m.retenues.is_empty(), "rien n'est retenu d'une offre dépassée")

	# Au plafond : on mène, la mise est retenue.
	var mise := int(e.minimum) if int(e.minimum) >= int(e.plafond) else int(e.plafond)
	r = await m.encherir(lot, "smarves", mise)
	e = m.enchere(lot)
	check(r.ok and r.mene and e.meneur == "smarves" and e.meneur_moi, "au plafond, l'Étoile mène à %d" % mise)
	check(game.credits == 50000 - mise and int(m.retenues.get(lot, 0)) == mise, "la mise est retenue de la poche")

	# Un autre village enchérit plus haut : la mise est rendue à la relecture.
	var plus: int = mise + m.pas(mise) + 100
	_offre(lot, autre, plus, "lucien")
	await m.lire()
	e = m.enchere(lot)
	check(e.meneur == autre and game.credits == 50000 and m.retenues.is_empty(), "dépassé par %s : la mise est rendue" % autre)
	check(m.nouvelles.size() > 0 and str(m.nouvelles[0]).begins_with("Enchère dépassée"), "une nouvelle le dit")

	# On reprend la tête à la dernière minute : la date limite recule de trois minutes.
	t = int(e.echeance) - 60
	var reprise: int = plus + m.pas(plus)
	r = await m.encherir(lot, "smarves", reprise)
	e = m.enchere(lot)
	check(r.ok and r.mene and int(e.echeance) == t + m.PROLONGATION, "une offre dans les trois dernières minutes repousse la date limite")
	check(game.credits == 50000 - reprise, "la nouvelle mise est retenue")

	# La date limite passe : l'enchère est gagnée, la mise dépensée, le joueur au club.
	t = int(e.echeance) + 10
	await m.lire()
	e = m.enchere(lot)
	check(e.ferme and e.gagnant == "smarves" and m.retenues.is_empty() and game.credits == 50000 - reprise, "l'enchère est gagnée, la mise dépensée")
	check(str(m.nouvelles[0]).begins_with("Enchère gagnée"), "une nouvelle l'annonce")
	check(m.joueurs_de("smarves", t) == [lot] and m.proprietaire(lot, t - 3600) == "", "le joueur est à l'Étoile depuis la date limite")
	# Le moteur le reçoit à la journée qui suit, jamais avant.
	var s: int = foot.saison_a(foot.coup_envoi(1, 1))
	var renf: Array = m.renforts(s, 1, "smarves")
	check(renf.size() == 1 and str(renf[0].id) == "smarves/m-" + lot and renf[0].has("competences") and renf[0].competences.size() == 8, "le moteur reçoit le renfort pour la journée 1, au nom du club")
	check(m.renforts(s, 1, autre).is_empty(), "l'autre club ne le reçoit pas")
	check(m.salaires("smarves") == int(m.joueur_en(lot, s).salaire), "la masse salariale compte son salaire")

	# Le revendre : une vente à la fois, encaissée une seule fois.
	r = await m.vendre("smarves", lot, 500, 3)
	check(r.ok and not m.vente_ouverte(lot).is_empty(), "l'Étoile met son joueur en vente")
	check(m.refus_vente("smarves", lot, 500, 3) == "deja", "pas deux ventes à la fois")
	var v: Dictionary = m.vente_ouverte(lot)
	check((await m.encherir(v.lot, "smarves", 600)).raison == "vendeur", "le club n'enchérit pas sur sa propre vente")
	_offre(v.lot, autre, maxi(int(v.plafond), 500) + 50, "lucien")
	t = int(v.echeance) + 60
	var avant: int = game.credits
	await m.lire()
	await m.lire()
	var fin: Dictionary = m.enchere(v.lot)
	check(fin.ferme and fin.gagnant == autre and game.credits == avant + int(fin.prix), "vendu à %s : %d crédits encaissés une fois" % [autre, fin.prix])
	check(m.joueurs_de("smarves", t).is_empty() and m.joueurs_de(autre, t) == [lot], "le joueur a changé de club")
	check(m.renforts(s, 1, "smarves").is_empty() and m.renforts(s, 1, autre).size() == 1, "au premier coup d'envoi, il joue pour son nouveau club")

	# Une vente posée par un club qui n'a pas le joueur ne compte pour personne.
	ventes.append({"id": 99, "club": "smarves", "joueur": "s0-3", "saison": 1, "prix_depart": 100, "echeance": _texte(t + 86400), "cree": _texte(t), "par": "moi", "moi": true})
	await m.lire()
	check(m.ventes().all(func(x): return x.lot != "v99"), "une vente sans le joueur est ignorée")

	# Les refus : sans la direction, sans compte.
	foot.parts["smarves"] = [{"par": "Gaston", "nombre": 3, "moi": false}]
	var ouvert: Array = m.lots_semaine(m.semaine_a(t)).filter(func(x): return not x.ferme)
	if not ouvert.is_empty():
		check(m.refus(ouvert[0].lot, "smarves", 100000) == "parts", "sans la direction du club, pas d'enchère")
	foot.parts.erase("smarves")
	m.appel = Callable()
	if not ouvert.is_empty():
		check(m.refus(ouvert[0].lot, "smarves", 100000) == "compte", "sans compte, pas d'enchère")
	m.appel = serveur

	# La sauvegarde garde l'état lu, les mises et ce qui est réglé.
	m.sauver()
	var n_avant: int = m.etat.encheres.size()
	m.etat = {"encheres": [], "ventes": [], "prolongations": {}}
	m.charger()
	check(m.etat.encheres.size() == n_avant and m.reglees.size() >= 2, "la sauvegarde relit le marché")
	check(m.joueurs_de(autre, t) == [lot], "et qui possède qui, après relecture")

	await _fenetre(game)

	m.appel = Callable()
	foot.regler_horloge(Callable())
	m.effacer()
	foot.effacer()
	print("%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


func _calendrier() -> void:
	check(m.debut_semaine(1) == foot.coup_envoi(1, 1) + 2 * 3600 and m.semaine_a(t) == 0, "la semaine 1 s'ouvre le 25 octobre à 17 h ; on est en semaine 0")
	var d := Time.get_datetime_dict_from_unix_time(m.echeance_lot(0, 0))
	check(d.month == 10 and d.day == 19 and d.hour == 19 and d.weekday == 1, "le premier lot de la semaine 0 se clôt lundi 19 octobre à 19 h")
	var bon := true
	for i in m.LOTS:
		var x: int = m.echeance_lot(4, i)
		var dd := Time.get_datetime_dict_from_unix_time(x)
		bon = bon and dd.weekday >= 1 and dd.weekday <= 6 and dd.hour >= 19 and dd.hour <= 22 and x > m.debut_semaine(4) and x < m.debut_semaine(5)
	check(bon, "les seize dates limites tombent du lundi au samedi, entre 19 h et 22 h")
	check(m.pas(100) == 10 and m.pas(1000) == 20 and m.pas(2450) == 50 and m.pas(5000) == 100, "le surplus minimum : 2 %, au moins 10, à la dizaine supérieure")
	var v := Time.get_datetime_dict_from_unix_time(m.echeance_vente(t, 3))
	check(v.day == 21 and v.hour == 21, "une vente de trois jours se clôt le mercredi à 21 h")


func _tirage() -> void:
	var a: Array = m.lots_semaine(3)
	var b: Array = m.lots_semaine(3)
	check(a.size() == 16 and a[7].joueur.nom == b[7].joueur.nom and a[7].plafond == b[7].plafond, "seize lots, les mêmes à chaque tirage")
	var postes := {}
	for e in a:
		postes[e.joueur.poste] = int(postes.get(e.joueur.poste, 0)) + 1
	check(postes == {"G": 2, "D": 5, "M": 5, "A": 4} or (postes.G == 2 and postes.D == 5 and postes.M == 5 and postes.A == 4), "deux gardiens, cinq défenseurs, cinq milieux, quatre attaquants")
	check(a.all(func(e): return e.prix_depart >= 100 and e.joueur.competences.size() == 8 and e.joueur.forme >= 1 and e.joueur.forme <= 8), "un prix de départ, huit compétences, une forme de 1 à 8")
	check(m.lots_semaine(4)[0].joueur.nom != a[0].joueur.nom or m.lots_semaine(4)[1].joueur.nom != a[1].joueur.nom, "une autre semaine, d'autres joueurs")
	# Le vieillissement : un an par saison, les jeunes progressent, les vieux déclinent.
	var jeune := ""
	var vieux := ""
	for k in range(0, 6):
		for i in m.LOTS:
			var n: Dictionary = m.naissance("s%d-%d" % [k, i])
			if n.age <= 19 and jeune == "":
				jeune = n.id
			if n.age >= 32 and vieux == "":
				vieux = n.id
	var j0: Dictionary = m.joueur_en(jeune, int(m.naissance(jeune).saison))
	var j2: Dictionary = m.joueur_en(jeune, int(m.naissance(jeune).saison) + 2)
	check(j2.age == j0.age + 2 and j2.note > j0.note, "un jeune de %d ans prend deux ans et progresse (%d → %d)" % [j0.age, j0.note, j2.note])
	if vieux != "":
		var v0: Dictionary = m.joueur_en(vieux, int(m.naissance(vieux).saison))
		var v2: Dictionary = m.joueur_en(vieux, int(m.naissance(vieux).saison) + 2)
		check(v2.note < v0.note and v2.valeur < v0.valeur, "un ancien de %d ans décline, sa valeur aussi" % v0.age)
	check(m.mot_niveau(62) == "excellent" and m.niveau(62) == 12, "les compétences en mots, à la Hattrick")


## La fenêtre : le marché, une fiche, l'effectif.
func _fenetre(game: Node) -> void:
	var fen: PanelContainer = load("res://scripts/socle/foot_mercato.gd").new()
	fen.club = "smarves"
	root.add_child(fen)
	await process_frame
	var lignes := fen.find_children("Lot_*", "", true, false)
	check(lignes.size() >= 1, "le marché liste les lots (%d)" % lignes.size())
	var ouvert: Array = m.lots_semaine(m.semaine_a(t)).filter(func(x): return not x.ferme)
	if not ouvert.is_empty():
		fen.ouvrir(ouvert[0].lot)
		await process_frame
		check(fen.find_child("Mise", true, false) != null and fen.find_child("Competences", true, false) != null, "la fiche montre les compétences et la case de la mise")
		var champ: LineEdit = fen.find_child("Mise", true, false)
		champ.text = str(int(ouvert[0].plafond) + 1000)
		var avant: int = game.credits
		await fen.miser(ouvert[0].lot)
		check(game.credits < avant and m.enchere(ouvert[0].lot).meneur_moi, "la fenêtre enchérit, sans plafond de mise")
	fen.aller("effectif")
	await process_frame
	check(fen.find_child("Onglet_effectif", true, false).disabled, "l'onglet de l'effectif s'ouvre")
	fen.queue_free()
	await process_frame


# ---------------------------------------------------------------- le faux serveur

func _texte(x: int) -> String:
	return Time.get_datetime_string_from_unix_time(x, true)


func _offre(lot: String, club: String, montant: int, qui: String) -> void:
	encheres.append({"lot": lot, "club": club, "montant": montant, "par": qui, "pyramide_id": qui, "quand": _texte(t) + ".%03d" % encheres.size()})


func serveur(fonction: String, corps: Dictionary) -> Dictionary:
	match fonction:
		"smarves_mercato":
			var e: Array = []
			for o in encheres:
				e.append({"lot": o.lot, "club": o.club, "montant": o.montant, "par": o.par, "moi": o.pyramide_id == moi, "quand": o.quand})
			var p: Array = []
			for lot in prolongations:
				p.append({"lot": lot, "echeance": _texte(prolongations[lot])})
			return {"code": 200, "corps": {"encheres": e, "ventes": ventes.duplicate(true), "prolongations": p}}
		"smarves_mercato_encherir":
			var lot: String = corps.p_lot
			var depart := 1
			var ouverture := 0
			var fin := 0
			var vente := {}
			if lot.begins_with("s"):
				ouverture = m.debut_semaine(m.lot_semaine(lot))
				fin = int(prolongations.get(lot, m.echeance_lot(m.lot_semaine(lot), m.lot_rang(lot))))
			else:
				for v in ventes:
					if "v%d" % int(v.id) == lot:
						vente = v
				if vente.is_empty():
					return {"code": 200, "corps": {"ok": false, "raison": "inconnu"}}
				if vente.club == corps.p_club:
					return {"code": 200, "corps": {"ok": false, "raison": "vendeur"}}
				ouverture = m._heure(vente.cree)
				fin = m._heure(vente.echeance)
				depart = int(vente.prix_depart)
			if t < ouverture or t >= fin:
				return {"code": 200, "corps": {"ok": false, "raison": "ferme"}}
			var meilleure := -1
			for o in encheres:
				if o.lot == lot and int(o.montant) >= depart:
					meilleure = maxi(meilleure, int(o.montant))
			if int(corps.p_montant) < depart or (meilleure >= 0 and int(corps.p_montant) < meilleure + m.pas(meilleure)):
				return {"code": 200, "corps": {"ok": false, "raison": "bas"}}
			_offre(lot, corps.p_club, int(corps.p_montant), moi)
			encheres[-1].par = "moi"
			if fin - t < 180:
				fin = t + 180
				if vente.is_empty():
					prolongations[lot] = fin
				else:
					vente.echeance = _texte(fin)
			return {"code": 200, "corps": {"ok": true, "echeance": _texte(fin)}}
		"smarves_mercato_vendre":
			for v in ventes:
				if v.joueur == corps.p_joueur and m._heure(v.echeance) > t:
					return {"code": 200, "corps": {"ok": false, "raison": "deja"}}
			id_vente += 1
			var ech := _texte(m.echeance_vente(t, int(corps.p_jours)))
			ventes.append({"id": id_vente, "club": corps.p_club, "joueur": corps.p_joueur, "saison": corps.p_saison, "prix_depart": corps.p_prix,
				"echeance": ech, "cree": _texte(t), "par": "moi", "moi": true})
			return {"code": 200, "corps": {"ok": true, "id": id_vente, "echeance": ech, "cree": _texte(t)}}
	return {"code": 404, "corps": null}
