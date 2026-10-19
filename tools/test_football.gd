extends SceneTree
## Vérifie le championnat de football de la Vienne sans affichage : godot --headless --path . -s tools/test_football.gd
## Le hasard rejouable donne les mêmes tirages que le Vestiaire (Zeus) ; le championnat ne compte que les
## clubs inscrits (un terrain au registre), deux suffisent ; un terrain nouveau reçoit son club à la saison
## suivante, ou tout de suite tant que personne n'a joué ; quand le bas est plein, un niveau s'ouvre ; le premier monte, les deux
## derniers descendent ; l'effectif est celui de la fondation, vieilli saison après saison ; la consigne
## porte la composition et les rôles ; un résultat ne dépend que de la graine et des décisions prises
## avant le coup d'envoi ; les statistiques comptent les buts des matchs joués.

const ESSAI := "res://tools/commune_essai/"
const TMP := "user://test_football/"

var fails := 0
var t := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var communes: Node = root.get_node("Communes")
	var registre: Node = root.get_node("Registre")
	var foot: Node = root.get_node("Football")
	DirAccess.make_dir_recursive_absolute(TMP)
	foot.dossier = TMP
	foot.effacer()
	foot.regler_horloge(func(): return t)

	_hasard()
	_calendrier_reel(foot)

	# Saison 1, avant le premier dimanche : Smarves a son terrain, et personne d'autre. Un club, pas de match.
	t = foot.coup_envoi(1, 1) - 3600
	foot.actualiser()
	check(foot.saison == 1 and foot.niveaux == [[["smarves"]]], "le championnat se fonde avec les seuls clubs inscrits : %s" % str(foot.niveaux))
	check(foot.clubs.size() == 1 and not foot.clubs.smarves.has("invite") and foot.clubs.smarves.fondation == 1, "l'Étoile de Smarves, fondée à la saison 1, sans club fictif")
	check(foot.periode() == "mercato", "la semaine d'avant la première journée est le mercato")
	check(foot.en_attente().is_empty(), "rien n'attend")
	var cal1: Array = foot.calendrier(1, foot.niveaux[0][0], 0, 0)
	check(cal1.size() == 14 and cal1.all(func(j): return j.is_empty()), "seul, le club n'a pas de match : quatorze journées vides")
	check(foot.prochain_match("smarves").is_empty() and foot.journee(1, 0, 0, 1).is_empty(), "pas de prochain match pour l'Étoile")
	var cl1: Array = foot.classement(1, 0, 0, 14)
	check(cl1.size() == 1 and cl1[0].j == 0 and foot.recette_facteur("smarves") == 1.0, "un classement à une ligne, sans match ; la rente des obligations reste à ×1")
	var vienne: Array = foot.clubs_de_la_vienne()
	check(vienne.size() == 40 and vienne == vienne.duplicate().filter(func(x): return true) and vienne.all(func(n): return n.contains(" de ") or n.contains(" d'")), "quarante clubs de village pour le marché, hors championnat : %s" % str(vienne.slice(0, 3)))
	check(foot.nom_de_village({"insee": "86113", "nom": "Iteuil"}).ends_with("d'Iteuil"), "un nom de club de village : %s" % foot.nom_de_village({"insee": "86113", "nom": "Iteuil"}))

	# L'effectif de fondation : dix-huit joueurs tirés une fois, qui restent d'une saison à l'autre.
	var e1: Dictionary = foot.effectif("smarves", 1)
	check(e1.size() == 18 and e1.has("smarves/1") and e1.has("smarves/18") and e1 == foot.fondateurs("smarves"), "dix-huit fondateurs, du smarves/1 au smarves/18")
	check(e1.values().filter(func(j): return j.poste == "G").size() == 2 and e1.values().filter(func(j): return j.poste == "A").size() == 4, "deux gardiens, quatre attaquants")
	check(e1.values().all(func(j): return j.age >= 17 and j.age <= 33 and j.note >= 35 and j.competences.size() == 8), "des âges de 17 à 33 ans, huit compétences chacun")
	var f1: float = foot.force("smarves", 1)
	check(f1 >= 45.0 and f1 <= 85.0 and absf(f1 - foot.force("smarves", 1)) < 0.001, "la force du club est la moyenne de ses onze meilleurs : %.1f" % f1)
	var e3: Dictionary = foot.effectif("smarves", 3)
	var restes: Array = e1.keys().filter(func(id): return e3.has(id))
	check(restes.size() >= 14 and restes.all(func(id): return e3[id].nom == e1[id].nom and e3[id].age == e1[id].age + 2), "deux saisons plus tard, les mêmes joueurs ont deux ans de plus : %d restent" % restes.size())
	var partis: Array = e1.keys().filter(func(id): return not e3.has(id))
	check(partis.all(func(id): return e1[id].age + 2 > foot.RETRAITE) and e3.size() == 18, "ceux qui passent %d ans partent, remplacés par des jeunes du cru (%d)" % [foot.RETRAITE, partis.size()])
	var jeunes: Array = e3.keys().filter(func(id): return not e1.has(id))
	check(jeunes.all(func(id): return e3[id].age <= 21 and int(id.get_slice("/", 1)) > 18), "les jeunes ont au plus 21 ans et un numéro nouveau : %s" % str(jeunes))
	check(e1.keys().any(func(id): return e3.has(id) and e3[id].note != e1[id].note), "les notes bougent avec l'âge")
	check(foot.progression(19, Hasard.depuis(1)) >= 4 and foot.progression(34, Hasard.depuis(1)) <= -5, "les jeunes progressent, les anciens déclinent")

	# La commune d'essai déclare un terrain pendant la saison 1, trois journées passées sans match : personne
	# n'a joué, le club entre tout de suite et le championnat part à la journée qui vient.
	t = foot.coup_envoi(1, 3) + 60
	var pck := TMP + "essai.pck"
	var pk := PCKPacker.new()
	pk.pck_start(pck)
	pk.add_file("res://communes/essai/commune.json", ESSAI + "commune.json")
	pk.add_file("res://communes/essai/commune.tscn", ESSAI + "commune.tscn")
	pk.flush()
	check(communes.charger_pack(pck) == "essai", "la commune d'essai se greffe")
	foot.actualiser()
	check(foot.clubs.has("essai") and foot.en_attente().is_empty() and foot.niveaux == [[["essai", "smarves"]]], "seul jusque-là, l'Étoile reçoit son adversaire sans attendre la saison suivante : %s" % str(foot.niveaux))
	check(foot.journee_jouee() == 3 and foot.clubs.essai.fondation == 1 and foot.clubs.essai.depuis == 4, "fondé à la saison 1, à partir de la journée 4")
	check(foot.journee(1, 0, 0, 3).is_empty() and foot.journee(1, 0, 0, 4).size() == 1 and foot.journee(1, 0, 0, 14).size() == 1, "pas de match avant son arrivée, un match par journée ensuite")
	var pm1: Dictionary = foot.prochain_match("smarves")
	check(pm1.s == 1 and pm1.j == 4 and "essai" in [pm1.dom, pm1.ext] and pm1.quand == foot.coup_envoi(1, 4), "le prochain match de l'Étoile est la journée 4 : %s" % str(pm1))
	check(foot.classement(1, 0, 0).size() == 2 and foot.classement(1, 0, 0).all(func(l): return l.j == 0), "deux lignes au classement, aucun match joué")
	t = foot.coup_envoi(1, 5) + 60
	check(foot.classement(1, 0, 0).all(func(l): return l.j == 2), "deux dimanches plus tard, deux matchs chacun")
	check(foot.saison_a(foot.coup_envoi(1, 14) + 86400 * 9) == 2, "la semaine après la dernière journée appartient déjà à la saison suivante")

	# Saison 2 : deux clubs, ça suffit pour jouer. Quatorze journées, un match chacune, chacun chez soi à son tour.
	t = foot.coup_envoi(2, 1) - 3600
	foot.actualiser()
	check(foot.saison == 2 and foot.historique.size() == 1 and foot.historique[0].champion in ["essai", "smarves"] and foot.historique[0].montes.is_empty(), "la saison 1 est close, sans montée")
	check(foot.niveaux == [[["essai", "smarves"]]] and foot.clubs.essai.fondation == 1, "l'Union sportive d'essai reste en Division 1")
	check(foot.clubs.essai.nom == "Union sportive d'essai" and foot.clubs.essai.court == "USE" and foot.clubs.essai.couleurs == ["#1b3c8c", "#f2c94c"], "son nom, son sigle et ses couleurs viennent du manifeste")
	var cal: Array = foot.calendrier(2, foot.niveaux[0][0], 0, 0)
	check(cal.size() == 14 and cal.all(func(j): return j.size() == 1), "quatorze journées d'un match")
	check(cal.filter(func(j): return j[0].dom == "smarves").size() == 7 and cal[0][0].dom != cal[1][0].dom, "sept fois chez l'un, sept fois chez l'autre, en alternant")
	var pm: Dictionary = foot.prochain_match("smarves")
	check(pm.s == 2 and pm.j == 1 and "essai" in [pm.dom, pm.ext] and pm.quand == foot.coup_envoi(2, 1), "le prochain match de l'Étoile : %s" % str(pm))
	check(foot.prochaine_journee() == [2, 1], "la prochaine journée est la première de la saison 2")

	# Le classement après trois journées, et après quatorze.
	t = foot.coup_envoi(2, 3) + 60
	var cl: Array = foot.classement(2, 0, 0)
	check(cl.size() == 2 and cl.all(func(l): return l.j == 3), "deux lignes, trois matchs chacune")
	var complet: Array = foot.classement(2, 0, 0, 14)
	var pts := 0
	for l in complet:
		pts += l.pts
	check(complet.all(func(l): return l.j == 14) and pts >= 28 and pts <= 42, "quatorze journées, %d points distribués" % pts)
	check(absf(foot.recette_facteur(cl[0].club) - 1.4) < 0.001 and absf(foot.recette_facteur(cl[1].club) - 0.7) < 0.001, "la rente des obligations : ×1,4 en tête, ×0,7 en queue, même à deux")

	# Un résultat est le même pour tout le monde ; une décision avant le match le change, pas après.
	var m0: Dictionary = foot.journee(2, 0, 0, 5, 14)[0]
	var r1: Array = foot.resultat(2, 5, m0.dom, m0.ext)
	check(r1 == foot.resultat(2, 5, m0.dom, m0.ext) and r1.size() == 2 and r1[0] >= 0, "le résultat se rejoue à l'identique : %s" % str(r1))
	check(not foot.decider(2, 3, m0.dom, {"mentalite": "offensive"}), "on ne décide plus d'un match joué")
	check(foot.decider(2, 5, m0.dom, {"mentalite": "offensive"}), "on décide d'un match à venir")
	var r2: Array = foot.resultat(2, 5, m0.dom, m0.ext)
	var differe := r1 != r2
	for j in range(6, 15):
		var m: Dictionary = foot.journee(2, 0, 0, j, 14)[0]
		var avant: Array = foot.resultat(2, j, m.dom, m.ext)
		foot.decisions["2/%d/%s" % [j, m.dom]] = {"mentalite": "offensive"}
		differe = differe or avant != foot.resultat(2, j, m.dom, m.ext)
	check(differe, "une décision change le tirage")
	# Les consignes : propres et dans le même ordre partout, locales tant que le serveur ne les a pas,
	# et celles du serveur l'emportent.
	check(foot.decisions["2/5/%s" % m0.dom] == {"formation": "4-4-2", "mentalite": "offensive", "pressing": "normal"}, "une consigne est complétée et rangée dans l'ordre")
	check(foot.consigne({"formation": "7-7-7", "pressing": "haut"}) == {"formation": "4-4-2", "mentalite": "equilibree", "pressing": "haut"}, "une valeur inconnue retombe sur le défaut")
	check(foot.consigne({"compo": ["", "", ""], "banc": [], "roles": {"x": "normal", "y": "inconnu"}}).size() == 3, "une compo vide, un banc vide, des rôles muets ne s'écrivent pas : la consigne d'avant reste la même")
	var cd: Dictionary = foot.consigne_de(2, 5, m0.dom)
	check(cd.etat == "locale" and foot.locales.has("2/5/%s" % m0.dom), "sans compte, la consigne reste locale")
	check(foot.appliquer_consignes([{"saison": 2, "journee": 5, "club": m0.dom, "formation": "4-3-3", "mentalite": "offensive", "pressing": "haut", "par": "Lucien"}]), "le serveur apporte la consigne du même match")
	cd = foot.consigne_de(2, 5, m0.dom)
	check(cd.etat == "commune" and cd.par == "Lucien" and cd.consigne.formation == "4-3-3" and not foot.locales.has("2/5/%s" % m0.dom), "la consigne du serveur l'emporte et n'est plus locale")
	check(not foot.appliquer_consignes([{"saison": 2, "journee": 5, "club": m0.dom, "formation": "4-3-3", "mentalite": "offensive", "pressing": "haut", "par": "Lucien"}]), "la relire ne change rien")

	# La composition, le banc et les rôles : la tactique du bureau, dans la consigne et dans le match.
	var club := "smarves"
	var ej: Dictionary = foot.effectif(club, 2, 6)
	var auto: Array = foot.compo_auto(club, 2, 6, "4-3-3")
	check(auto.size() == 11 and auto.all(func(id): return id != null and ej.has(id)) and ej[auto[0]].poste == "G", "l'adjoint aligne onze joueurs du club, le gardien en premier")
	var banc_auto: Array = foot.banc_auto(club, 2, 6, auto)
	check(banc_auto.size() == 7 and banc_auto.all(func(id): return not auto.has(id)) and ej[banc_auto[0]].poste == "G", "sept remplaçants, un gardien d'abord")
	var autre_gardien: String = ej.keys().filter(func(id): return ej[id].poste == "G" and id != auto[0])[0]
	var compo: Array = auto.duplicate()
	compo[0] = autre_gardien
	compo[3] = "smarves/999"
	var banc := [auto[0], auto[5]]
	check(foot.decider(2, 6, club, {"formation": "4-3-3", "compo": compo, "banc": banc, "roles": {compo[10]: "tireur", compo[1]: "defensif", compo[2]: "normal", "smarves/999": "offensif"}}), "la consigne de la journée 6 porte la compo, le banc et les rôles")
	var c6: Dictionary = foot.consigne_de(2, 6, club).consigne
	check(c6.keys() == ["formation", "mentalite", "pressing", "compo", "banc", "roles"] and c6.compo == compo and c6.banc == banc and c6.roles == {compo[10]: "tireur", compo[1]: "defensif", "smarves/999": "offensif"}, "la consigne est rangée : la compo, le banc, les rôles sans « normal » : %s" % str(c6.roles))
	var m6: Dictionary = foot.prochain_match(club) if foot.prochain_match(club).j == 6 else foot.journee(2, 0, 0, 6, 0)[0]
	var direct: Dictionary = foot.rencontre_en_direct(2, 6, m6.dom, m6.ext)
	var mienne: Dictionary = direct.etat.equipes[0] if direct.etat.equipes[0].club == club else direct.etat.equipes[1]
	var ids_onze: Array = mienne.onze.map(func(e): return e.id)
	check(mienne.formation == "4-3-3" and ids_onze[0] == autre_gardien and ids_onze.size() == 11 and not ids_onze.has("smarves/999") and ids_onze.has(auto[0]) == false, "dimanche, le second gardien est dans les buts ; la case du joueur inconnu est comblée par l'adjoint")
	check(mienne.banc[0] == auto[0] and mienne.banc.size() == 7 and mienne.roles == {compo[10]: "tireur", compo[1]: "defensif"}, "le banc commence par le gardien écarté ; les rôles des joueurs présents sont dans le match : %s" % str(mienne.roles))
	check(FootMatch.tireur_cpa(mienne, direct.joueurs).id == compo[10] and FootMatch.role_de(mienne, compo[1]).defense > 1.0, "le tireur désigné prend les coups de pied arrêtés, le défensif défend plus")
	check(foot.appliquer_consignes([{"saison": 2, "journee": 6, "club": club, "formation": "4-3-3", "mentalite": "equilibree", "pressing": "normal", "par": "Lucien", "detail": {"compo": compo, "banc": banc, "roles": {compo[10]: "tireur"}}}]), "le serveur apporte le détail dans sa colonne")
	check(foot.consigne_de(2, 6, club).consigne.roles == {compo[10]: "tireur"} and foot.consigne_de(2, 6, club).consigne.compo == compo, "et il se lit comme une consigne d'ici")
	var actuel: Array = foot.effectif_actuel(club)
	check(actuel.size() == 18 and actuel[0].poste == "G" and actuel[-1].poste == "A" and actuel.all(func(j): return j.has("id")), "l'effectif du moment, trié par poste, chaque joueur avec son id")
	check(foot.joueur_de(club, 2, 6, auto[1]).id == auto[1] and foot.joueur_de(club, 2, 6, "smarves/999").is_empty(), "un joueur se retrouve par son id")

	# Les statistiques du championnat : buteurs, passeurs, clean sheets, comptés des matchs joués.
	var stats: Dictionary = foot.statistiques(2, 0, 0, 14)
	var buts := 0
	var blanchissages := 0
	for j in range(1, 15):
		for m in foot.journee(2, 0, 0, j, 14):
			buts += m.score[0] + m.score[1]
			blanchissages += (1 if m.score[1] == 0 else 0) + (1 if m.score[0] == 0 else 0)
	var somme := func(liste: Array, cle: String) -> int:
		var n := 0
		for l in liste:
			n += int(l[cle])
		return n
	check(somme.call(stats.buteurs, "buts") == buts and buts > 0, "%d buts en quatorze journées, tous à un buteur" % buts)
	check(somme.call(stats.clean_sheets, "n") == blanchissages, "%d clean sheets, un par match sans but encaissé" % blanchissages)
	check(somme.call(stats.passeurs, "passes") <= buts and stats.buteurs[0].buts >= stats.buteurs[-1].buts, "des passes au plus autant que de buts, les meilleurs d'abord")
	check(stats.buteurs.all(func(l): return l.nom != "" and l.prenom != "" and l.club in ["essai", "smarves"] and l.id.begins_with(l.club + "/")), "chaque ligne a un nom, un prénom et un club")
	foot.decisions = {}
	foot.locales = {}
	foot.auteurs = {}
	foot.oublier_effectifs()

	# Les obligations du club, chez le notaire (modèle Impérial 2030) : sans porteur tout le monde parle ;
	# sinon la plus grosse somme investie, ou chacun à égalité.
	var game: Node = root.get_node("Game")
	game.saving_enabled = false
	game.credits = 10000
	check(foot.peut_decider(m0.dom) and foot.actionnaires(m0.dom).is_empty(), "sans porteur, le président écoute tout le monde")
	check(foot.valeur(1) == 500 and foot.valeur(9) == 7500 and foot.dividende_de(3) == 150, "neuf tailles, de 500 à 7 500 ; 50 crédits par cran et par journée")
	foot.appliquer_obligations([{"club": m0.dom, "rang": 5, "par": "Lucien", "moi": false}, {"club": m0.dom, "rang": 1, "par": "Lucien", "moi": false}])
	check(not foot.peut_decider(m0.dom) and foot.actionnaires(m0.dom).size() == 1 and foot.actionnaires(m0.dom)[0].investi == 3500, "Lucien a 3 500 dans le club (n° 5 et n° 1) : lui seul parle")
	check(not foot.decider(2, 6, m0.dom, {"mentalite": "tout"}), "sans obligation, la consigne est refusée")
	check(foot.prendre(m0.dom, 5).raison == "prise" and foot.prendre(m0.dom, 12).raison == "rang", "une obligation tenue ne se prend pas, ni un rang qui n'existe pas")
	check(foot.prendre(m0.dom, 3).ok and game.credits == 8500 and foot.mes_obligations(m0.dom) == [3], "la n° 3 prise : 1 500 débités")
	check(not foot.peut_decider(m0.dom), "1 500 contre 3 500 : c'est toujours Lucien qui parle")
	check(foot.prendre(m0.dom, 4).ok and foot.investi(m0.dom) == 3750 and foot.peut_decider(m0.dom), "la n° 4 en plus : 3 750, je passe devant")
	check(foot.phrase_actionnaires(m0.dom) == "Vous avez 3 750 crédits dans le club, Lucien 3 500 : c'est vous qui parlez au président.", "la phrase des porteurs : %s" % foot.phrase_actionnaires(m0.dom))
	check(foot.obligations_a_declarer[m0.dom] == {"3": true, "4": true}, "les prises d'ici attendent le serveur")
	game.credits = 100
	check(foot.prendre(m0.dom, 2).raison == "credits", "sans crédits, pas d'obligation")
	game.credits = 10000
	check(foot.echanger(m0.dom, 3, 7).ok and game.credits == 10000 - 3500 and foot.mes_obligations(m0.dom) == [7, 4] and foot.obligations_a_declarer[m0.dom]["3"] == false, "la n° 3 échangée contre la n° 7 pour la différence (3 500)")
	check(foot.echanger(m0.dom, 4, 5).raison == "prise" and foot.echanger(m0.dom, 9, 8).raison == "absente", "pas d'échange contre une tenue, ni depuis une qu'on n'a pas")
	var r4: Dictionary = foot.rendre(m0.dom, 4)
	check(r4.ok and r4.montant == 1800 and game.credits == 6500 + 1800 and foot.mes_obligations(m0.dom) == [7], "la n° 4 rendue à l'étude, 80 % de 2 250")
	# Les dividendes : rien sur les journées déjà jouées, puis 50 par cran et par journée, au classement.
	check(foot.dividendes_dus().is_empty(), "rien n'est dû pour les journées d'avant l'achat")
	t = foot.coup_envoi(2, 7) + 3 * 3600
	var dus: Array = foot.dividendes_dus()
	check(dus.size() == 4 and dus[0].j == 4 and dus[3].j == 7 and dus[0].brut == int(round(350 * foot.recette_facteur(m0.dom))), "quatre journées jouées depuis la n° 7 : quatre dividendes de 350 au classement (%s)" % str(dus))
	foot.salaires = func(_c: String) -> int: return 700
	check(foot.dividendes_dus()[0].salaires == int(round(700.0 * 5000.0 / 8500.0)), "les salaires du mercato se retiennent au prorata de l'investi")
	foot.salaires = Callable()
	var credits_avant: int = game.credits
	var verses: Array = foot.verser_dividendes()
	var total := 0
	for v in verses:
		total += int(v.net)
	check(verses.size() == 4 and game.credits == credits_avant + total and foot.dividendes_dus().is_empty() and foot.dividendes[m0.dom].j == 7, "versés une fois, dans la bourse")
	# Le serveur a le dernier mot : une prise qu'il donne à un autre est rendue à sa valeur.
	foot.obligations_a_declarer = {}
	credits_avant = game.credits
	foot.appliquer_obligations([{"club": m0.dom, "rang": 7, "par": "Marcel", "moi": false}, {"club": m0.dom, "rang": 2, "par": "Moi", "moi": true}])
	check(foot.mes_obligations(m0.dom) == [2] and game.credits == credits_avant + 5000, "la n° 7 à Marcel au serveur : rendue 5 000 ; la n° 2 qu'il me donne arrive")
	t = foot.coup_envoi(2, 3) + 60
	var fr: float = foot.recette_facteur(m0.dom)
	check(fr >= 0.7 - 0.001 and fr <= 1.4 + 0.001 and foot.recette_facteur("nulle_part") == 1.0, "la rente d'une part suit le classement (×%.1f), ×1 pour un club inconnu" % fr)
	foot.rendre(m0.dom, 2)
	foot.appliquer_obligations([])
	foot.obligations_a_declarer = {}
	foot.dividendes = {}
	check(foot.peut_decider(m0.dom) and foot.actionnaires(m0.dom).is_empty(), "les obligations rendues, tout le monde parle de nouveau")
	pm = foot.prochain_match(m0.dom)
	check(pm.s == 2 and pm.j == foot.journee_jouee() + 1 and (pm.dom == m0.dom or pm.ext == m0.dom) and pm.quand == foot.coup_envoi(2, pm.j), "le prochain match du club : %s" % str(pm))
	check(foot.journee(2, 0, 0, 7)[0].score.is_empty() and foot.journee(2, 0, 0, 3)[0].score.size() == 2, "un match à venir n'a pas de score, un match joué en a un")

	# Le mercato des libres : la semaine d'avant la première journée, douze libres, une recrue par club, un libre ne part qu'une fois.
	t = foot.coup_envoi(3, 1) - 3600
	foot.actualiser()
	check(foot.saison == 3 and foot.periode() == "mercato" and foot.mercato_ouvert(3) and not foot.mercato_ouvert(2), "une heure avant la saison 3, son mercato est ouvert")
	var libres: Array = foot.libres(3)
	check(libres.size() == 12 and libres[0].poste == "G" and libres[11].poste == "A" and libres[3].nom == foot.libres(3)[3].nom, "douze joueurs libres, les mêmes à chaque tirage")
	check(foot.prix_de(60) == 1200 and foot.prix_de(85) == 6080 and libres.all(func(j): return j.prix == foot.prix_de(j.note)), "le prix suit la note")
	check(foot.recruter(2, "essai", 0).raison == "ferme", "pas de recrue pour une saison passée")
	var avant: Dictionary = foot.effectif("essai", 3)
	var r0: Dictionary = foot.recruter(3, "essai", 0)
	check(r0.ok and foot.transferts_locaux.has("3/essai") and foot.transfert_de(3, "essai").etat == "locale", "l'Union d'essai recrute le premier libre, en local")
	var apres: Dictionary = foot.effectif("essai", 3)
	check(apres.size() == avant.size() and apres.has("essai/libre0") and apres["essai/libre0"].nom == libres[0].nom, "la recrue entre, l'effectif garde sa taille")
	var gardiens_avant: Array = avant.keys().filter(func(id): return avant[id].poste == "G")
	var gardiens_apres: Array = apres.keys().filter(func(id): return apres[id].poste == "G")
	check(gardiens_apres.size() == gardiens_avant.size() and not apres.has(gardiens_avant.reduce(func(a, b): return a if avant[a].note <= avant[b].note else b)), "le plus faible gardien cède sa place")
	check(foot.recruter(3, "essai", 1).raison == "deja", "une recrue par club et par saison")
	check(foot.recruter(3, "smarves", 0).raison == "pris" and foot.preneur(3, 0) == "essai", "un libre ne part qu'une fois")
	check(foot.appliquer_transferts([{"saison": 3, "club": "essai", "joueur": 5, "par": "Lucien"}]), "le serveur apporte une autre recrue pour le même club")
	check(foot.transfert_de(3, "essai").etat == "commune" and foot.effectif("essai", 3).has("essai/libre5") and not foot.effectif("essai", 3).has("essai/libre0"), "elle l'emporte sur la recrue locale")
	check(foot.prochain_mercato() == foot.coup_envoi(4, 1) - 7 * 86400, "le prochain mercato est celui de la saison 4")
	foot.transferts = {}
	foot.transferts_locaux = {}
	foot.oublier_effectifs()

	# Le crochet du module mercato : un renfort entre dans l'effectif de la journée, pas dans celui d'avant.
	var base: Dictionary = foot.effectif("essai", 3)
	var premier: String = base.keys()[0]
	foot.renforts = func(_s: int, j: int, _c: String) -> Array:
		return [] if j < 3 else [{"id": "essai/m2-7", "prenom": "Jan", "nom": "Hattrick", "poste": "A", "age": 24,
			"note": 70, "condition": 100, "moral": 70, "competences": base[premier].competences}]
	foot.oublier_effectifs()
	check(not foot.effectif("essai", 3, 2).has("essai/m2-7") and foot.effectif("essai", 3, 3).has("essai/m2-7"), "le renfort acheté joue à partir de la journée 3")
	check(foot.effectif("essai", 3, 3).size() == base.size() + 1 and foot.effectif("essai", 3, 3).has(premier) and not foot.effectif("essai", 3, 3)["essai/m2-7"].has("id"), "il s'ajoute aux joueurs du cru")
	check(foot.rencontre_en_direct(3, 3, "essai", "smarves").joueurs.has("essai/m2-7"), "le match de la journée 3 le connaît")
	foot.renforts = Callable()
	foot.oublier_effectifs()
	check(not foot.effectif("essai", 3, 3).has("essai/m2-7"), "sans module, l'effectif est celui du tirage")

	# Huit terrains de plus au catalogue, pendant la saison 3 : ils entrent à la saison 4. Six complètent la
	# Division 1, le bas est plein, un niveau 2 à deux groupes s'ouvre et les deux derniers y jouent ensemble.
	t = foot.coup_envoi(3, 2) + 60
	var entrees := []
	var inseeS := ["86133", "86290", "86015", "86009", "86062", "86100", "86150", "86200"]
	for i in inseeS.size():
		var c := Vienne.commune(inseeS[i])
		entrees.append({"insee": inseeS[i], "id": "c%d" % i, "nom": c.nom, "version": "0.1.0", "paquet": "https://exemple.fr/c%d.pck" % i,
			"taille": 1000, "sha256": "0".repeat(64), "structures": [{"type": "terrain_foot", "id": "stade", "nom": "Le stade", "club": "Le club de %s" % c.nom}]})
	communes.catalogue = Portail.entrees(JSON.stringify({"format": 1, "communes": entrees}))
	communes.catalogue_lu.emit()
	check(registre.de_type("terrain_foot").size() == 10, "dix terrains au registre, avec ceux de Smarves et d'essai")
	foot.actualiser()
	check(foot.saison == 3 and foot.clubs.size() == 2 and foot.en_attente().size() == 8, "en pleine saison 3, les huit attendent")
	t = foot.coup_envoi(4, 1) - 3600
	foot.actualiser()
	check(foot.saison == 4 and foot.niveaux.size() == 2 and foot.niveaux[0][0].size() == 8 and foot.niveaux[1].size() == 2 and foot.niveaux[1][0].size() == 2 and foot.niveaux[1][1].is_empty(), "la Division 1 à huit, le niveau 2 s'ouvre : deux clubs en groupe A, le groupe B vide : %s" % str(foot.niveaux[1]))
	check(foot.clubs.size() == 10 and foot.clubs.values().all(func(c): return not c.has("invite")) and foot.clubs.c7.fondation == 4, "dix clubs de plein droit, rien d'autre")
	check(_sans_doublon(foot), "aucun club dans deux groupes")
	check(foot.nom_division(1, 1) == "Division 2, groupe B" and foot.nom_division(0, 0) == "Division 1", "les divisions ont un nom")
	check(foot.calendrier(4, foot.niveaux[0][0], 0, 0).all(func(j): return j.size() == 4) and foot.calendrier(4, foot.niveaux[1][0], 1, 0).all(func(j): return j.size() == 1), "à huit, quatre matchs par journée ; à deux, un seul")
	var rencontres := {}
	for j in foot.calendrier(4, foot.niveaux[0][0], 0, 0):
		for m in j:
			rencontres["%s-%s" % [m.dom, m.ext]] = rencontres.get("%s-%s" % [m.dom, m.ext], 0) + 1
	check(rencontres.size() == 56 and rencontres.values().all(func(n): return n == 1), "à huit, chaque club reçoit chaque autre une fois")

	# Saison 5 : le premier du groupe A monte, l'avant-dernier de la Division 1 descend chez lui ; le groupe B vide n'échange rien.
	var monte: String = foot.classement(4, 1, 0, 14)[0].club
	var haut: Array = foot.classement(4, 0, 0, 14)
	var descend: String = haut[6].club
	t = foot.coup_envoi(5, 1) - 3600
	foot.actualiser()
	var h: Dictionary = foot.historique[3]
	check(foot.saison == 5 and h.montes == [monte] and h.descendus == [descend], "montée %s, descente %s" % [str(h.montes), str(h.descendus)])
	check(foot.place_de(monte) == [0, 0] and foot.place_de(descend) == [1, 0] and foot.place_de(haut[7].club) == [0, 0], "le monté est en Division 1, le descendu en groupe A ; le dernier reste, faute de groupe B")
	check(foot.niveaux[0][0].size() == 8 and foot.niveaux[1][0].size() == 2 and foot.niveaux[1][1].is_empty() and _sans_doublon(foot), "les groupes gardent leur taille, sans doublon")

	# La pyramide se relit du fichier ; une sauvegarde d'avant, avec ses clubs invités, les perd en se relisant.
	var copie: Array = foot.niveaux.duplicate(true)
	foot.niveaux = []
	foot.clubs = {}
	foot.charger()
	check(foot.niveaux == copie and foot.saison == 5, "la pyramide se relit du fichier")
	Portail.ecrire(TMP.path_join(foot.FICHIER), JSON.stringify({"saison": 2, "niveaux": [[["invite_86999", "smarves"]]], "historique": [],
		"clubs": {"smarves": {"nom": "L'Étoile de Smarves", "court": "ESM", "couleurs": ["#1b3c8c", "#f2c94c"], "commune": "smarves", "insee": "86263", "invite": false},
			"invite_86999": {"nom": "Avenir d'ailleurs", "court": "AVA", "couleurs": ["#1b3c8c", "#f2c94c"], "commune": "", "insee": "86999", "invite": true}}}))
	foot.charger()
	check(foot.niveaux == [[["smarves"]]] and foot.clubs.size() == 1 and not foot.clubs.smarves.has("invite") and foot.clubs.smarves.fondation == 1, "l'invité d'une vieille sauvegarde s'en va, l'Étoile reçoit sa fondation")
	foot.sauver()

	# Dix saisons d'affilée tiennent.
	t = foot.coup_envoi(15, 1) - 3600
	foot.actualiser()
	check(foot.saison == 15 and foot.historique.size() == 13 and _sans_doublon(foot), "treize saisons de plus : la pyramide tient")
	t = foot.coup_envoi(15, 14) + 86400 * 9
	foot.actualiser()
	check(foot.saison == 16 and foot.periode() == "treve" and foot.journee_jouee() == 0, "la semaine après la dernière journée, c'est la trêve de la saison 16")
	t = foot.coup_envoi(15, 1) - 3600
	check(foot.prochain_coup_envoi(t)[0] == 15 and foot.prochain_coup_envoi(t)[1] == 1, "le prochain coup d'envoi est la première journée de la saison 15")

	foot.effacer()
	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


func _sans_doublon(foot: Node) -> bool:
	var vus := {}
	for n in foot.niveaux:
		for g in n:
			for id in g:
				if vus.has(id) or not foot.clubs.has(id):
					return false
				vus[id] = true
	return vus.size() == foot.clubs.size()


func _hasard() -> void:
	# Les mêmes nombres que creerHasard(12345) dans Zeus (src/moteur/hasard.js).
	var h := Hasard.depuis(12345)
	var a := h.suivant()
	var b := h.suivant()
	check(absf(a - 0.9797282677609473) < 1e-12 and absf(b - 0.3067522644996643) < 1e-12 and h.entier(1, 100) == 49, "mulberry32 donne les mêmes tirages que le Vestiaire")
	check(Hasard.graine("abc") == Hasard.graine("abc") and Hasard.graine("abc") != Hasard.graine("abd"), "une graine stable par texte")


func _calendrier_reel(foot: Node) -> void:
	var d := Time.get_datetime_dict_from_unix_time(foot.coup_envoi(1, 1))
	check(d.weekday == Time.WEEKDAY_SUNDAY and d.hour == 15 and d.day == 25 and d.month == 10, "la saison 1 commence le dimanche 25 octobre 2026 à 15 h")
	check(foot.coup_envoi(1, 14) - foot.coup_envoi(1, 1) == 13 * 7 * 86400, "quatorze dimanches")
	check(foot.coup_envoi(2, 1) - foot.coup_envoi(1, 1) == 16 * 7 * 86400, "seize semaines par saison")
	check(foot.saison_a(foot.coup_envoi(1, 1) - 86400 * 30) == 1 and foot.saison_a(foot.debut(2)) == 2 and foot.saison_a(foot.debut(2) - 1) == 1, "la saison du calendrier commence deux semaines avant son premier dimanche")
	check(foot.journee_jouee_a(foot.coup_envoi(1, 1) - 1, 1) == 0 and foot.journee_jouee_a(foot.coup_envoi(1, 1), 1) == 1 and foot.journee_jouee_a(foot.coup_envoi(1, 14) + 86400 * 10, 1) == 14, "la journée qui vient de se jouer")
