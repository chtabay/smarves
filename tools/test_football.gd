extends SceneTree
## Vérifie la pyramide du football de la Vienne sans affichage : godot --headless --path . -s tools/test_football.gd
## Le hasard rejouable donne les mêmes tirages que le Vestiaire (Zeus) ; la pyramide se fonde sur les
## terrains du registre, complétée d'invités ; un terrain nouveau reçoit son club à la saison suivante ;
## quand le bas est plein, un niveau s'ouvre ; le premier monte, les deux derniers descendent ; un
## résultat ne dépend que de la graine et des décisions prises avant le coup d'envoi.

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

	# Saison 1, avant le premier dimanche : personne n'a de terrain, huit invités.
	t = foot.coup_envoi(1, 1) - 3600
	foot.actualiser()
	check(foot.saison == 1 and foot.niveaux.size() == 1 and foot.niveaux[0].size() == 1 and foot.niveaux[0][0].size() == 8, "la pyramide se fonde : un groupe de huit")
	check(foot.clubs.values().filter(func(c): return c.invite).size() == 7 and foot.clubs.has("smarves"), "le stade de Smarves au registre : l'Étoile et sept invités")
	check(not foot.clubs.smarves.invite and foot.clubs.values().filter(func(c): return c.insee == "86263").size() == 1, "Smarves a son club de plein droit, jamais en invité")
	check(foot.periode() == "mercato", "la semaine d'avant la première journée est le mercato")
	var noms: Array = foot.niveaux[0][0].map(func(id): return foot.clubs[id].nom)
	check(noms.all(func(n): return n.contains(" de ") or n.contains(" d'")), "les invités portent un nom de club de village : %s" % str(noms.slice(0, 3)))
	check(foot.en_attente().is_empty(), "rien n'attend")

	# La commune d'essai déclare un terrain : son club entre à la saison suivante, pas pendant celle-ci.
	t = foot.coup_envoi(1, 3) + 60
	var pck := TMP + "essai.pck"
	var pk := PCKPacker.new()
	pk.pck_start(pck)
	pk.add_file("res://communes/essai/commune.json", ESSAI + "commune.json")
	pk.add_file("res://communes/essai/commune.tscn", ESSAI + "commune.tscn")
	pk.flush()
	check(communes.charger_pack(pck) == "essai", "la commune d'essai se greffe")
	foot.actualiser()
	check(not foot.clubs.has("essai") and foot.en_attente() == ["essai"], "en pleine saison, le club d'essai attend la saison suivante")
	check(foot.journee_jouee() == 3 and foot.periode() == "saison", "trois journées jouées")
	check(foot.saison_a(foot.coup_envoi(1, 14) + 86400 * 9) == 2, "la semaine après la dernière journée appartient déjà à la saison suivante")

	# Le classement après trois journées, et après quatorze.
	var cl: Array = foot.classement(1, 0, 0)
	check(cl.size() == 8 and cl.all(func(l): return l.j == 3), "huit lignes, trois matchs chacune")
	var complet: Array = foot.classement(1, 0, 0, 14)
	var pts := 0
	for l in complet:
		pts += l.pts
	check(complet.all(func(l): return l.j == 14) and pts >= 14 * 4 * 2 and pts <= 14 * 4 * 3, "quatorze journées, %d points distribués" % pts)
	var cal: Array = foot.calendrier(1, foot.niveaux[0][0], 0, 0)
	check(cal.size() == 14 and cal.all(func(j): return j.size() == 4), "le calendrier a quatorze journées de quatre matchs")
	var rencontres := {}
	for j in cal:
		for m in j:
			rencontres["%s-%s" % [m.dom, m.ext]] = rencontres.get("%s-%s" % [m.dom, m.ext], 0) + 1
	check(rencontres.size() == 56 and rencontres.values().all(func(n): return n == 1), "chaque club reçoit chaque autre une fois")

	# Un résultat est le même pour tout le monde ; une décision avant le match le change, pas après.
	var m0: Dictionary = foot.journee(1, 0, 0, 5, 14)[0]
	var r1: Array = foot.resultat(1, 5, m0.dom, m0.ext)
	check(r1 == foot.resultat(1, 5, m0.dom, m0.ext) and r1.size() == 2 and r1[0] >= 0, "le résultat se rejoue à l'identique : %s" % str(r1))
	check(not foot.decider(1, 3, m0.dom, {"mentalite": "offensive"}), "on ne décide plus d'un match joué")
	check(foot.decider(1, 5, m0.dom, {"mentalite": "offensive"}), "on décide d'un match à venir")
	var r2: Array = foot.resultat(1, 5, m0.dom, m0.ext)
	var differe := r1 != r2
	for j in range(6, 15):
		var m: Dictionary = foot.journee(1, 0, 0, j, 14)[0]
		var avant: Array = foot.resultat(1, j, m.dom, m.ext)
		foot.decisions["1/%d/%s" % [j, m.dom]] = {"mentalite": "offensive"}
		differe = differe or avant != foot.resultat(1, j, m.dom, m.ext)
	check(differe, "une décision change le tirage")
	# Les consignes : propres et dans le même ordre partout, locales tant que le serveur ne les a pas,
	# et celles du serveur l'emportent.
	check(foot.decisions["1/5/%s" % m0.dom] == {"formation": "4-4-2", "mentalite": "offensive", "pressing": "normal"}, "une consigne est complétée et rangée dans l'ordre")
	check(foot.consigne({"formation": "7-7-7", "pressing": "haut"}) == {"formation": "4-4-2", "mentalite": "equilibree", "pressing": "haut"}, "une valeur inconnue retombe sur le défaut")
	var cd: Dictionary = foot.consigne_de(1, 5, m0.dom)
	check(cd.etat == "locale" and foot.locales.has("1/5/%s" % m0.dom), "sans compte, la consigne reste locale")
	check(foot.appliquer_consignes([{"saison": 1, "journee": 5, "club": m0.dom, "formation": "4-3-3", "mentalite": "offensive", "pressing": "haut", "par": "Lucien"}]), "le serveur apporte la consigne du même match")
	cd = foot.consigne_de(1, 5, m0.dom)
	check(cd.etat == "commune" and cd.par == "Lucien" and cd.consigne.formation == "4-3-3" and not foot.locales.has("1/5/%s" % m0.dom), "la consigne du serveur l'emporte et n'est plus locale")
	check(not foot.appliquer_consignes([{"saison": 1, "journee": 5, "club": m0.dom, "formation": "4-3-3", "mentalite": "offensive", "pressing": "haut", "par": "Lucien"}]), "la relire ne change rien")
	# Les parts du club, chez le notaire : sans actionnaire tout le monde parle ; sinon le plus gros, ou chacun à égalité.
	check(foot.peut_decider(m0.dom) and foot.actionnaires(m0.dom).is_empty(), "sans actionnaire, le président écoute tout le monde")
	foot.appliquer_parts([{"club": m0.dom, "nombre": 2, "par": "Lucien", "moi": false}, {"club": m0.dom, "nombre": 1, "par": "Moi", "moi": true}])
	check(not foot.peut_decider(m0.dom) and foot.actionnaires(m0.dom).size() == 1, "Lucien tient deux parts : lui seul parle, et mes parts viennent d'ici, pas du serveur")
	check(not foot.decider(1, 6, m0.dom, {"mentalite": "tout"}), "sans parts, la consigne est refusée")
	foot.detenir(m0.dom, 2)
	check(foot.peut_decider(m0.dom) and foot.actionnaires(m0.dom)[0].moi, "deux parts d'ici : à égalité, je parle aussi, et je passe devant")
	check(foot.phrase_actionnaires(m0.dom) == "Vous tenez 2 parts, Lucien tient 2 parts : c'est vous qui parlez au président.", "la phrase des actionnaires : %s" % foot.phrase_actionnaires(m0.dom))
	foot.detenir(m0.dom, 1)
	check(not foot.peut_decider(m0.dom) and foot.phrase_actionnaires(m0.dom).ends_with("c'est Lucien qui parle au président."), "une part contre deux : c'est Lucien qui parle")
	check(foot.parts_a_declarer.has(m0.dom) and foot.parts_locales[m0.dom] == 1, "les parts d'ici attendent d'être déclarées au serveur")
	var fr: float = foot.recette_facteur(m0.dom)
	check(fr >= 0.7 - 0.001 and fr <= 1.4 + 0.001 and foot.recette_facteur("nulle_part") == 1.0, "la rente d'une part suit le classement (×%.1f), ×1 pour un club inconnu" % fr)
	check(absf(foot.recette_facteur(cl[0].club) - 1.4) < 0.001 and absf(foot.recette_facteur(cl[7].club) - 0.7) < 0.001, "×1,4 en tête, ×0,7 en queue")
	foot.detenir(m0.dom, 0)
	foot.appliquer_parts([])
	foot.parts_a_declarer = {}
	check(foot.peut_decider(m0.dom), "les parts revendues, tout le monde parle de nouveau")
	var pm: Dictionary = foot.prochain_match(m0.dom)
	check(pm.s == 1 and pm.j == foot.journee_jouee() + 1 and (pm.dom == m0.dom or pm.ext == m0.dom) and pm.quand == foot.coup_envoi(1, pm.j), "le prochain match du club : %s" % str(pm))
	foot.decisions = {}
	foot.locales = {}
	foot.auteurs = {}
	check(foot.journee(1, 0, 0, 7)[0].score.is_empty() and foot.journee(1, 0, 0, 3)[0].score.size() == 2, "un match à venir n'a pas de score, un match joué en a un")

	# Saison 2 : le club d'essai entre à la place d'un invité ; un seul niveau, personne ne monte.
	t = foot.coup_envoi(2, 1) - 3600
	foot.actualiser()
	check(foot.saison == 2 and foot.historique.size() == 1 and foot.historique[0].montes.is_empty(), "la saison 1 est close, sans montée : champion %s" % foot.clubs[foot.historique[0].champion].nom)
	check(foot.clubs.has("essai") and foot.place_de("essai") == [0, 0] and foot.niveaux[0][0].size() == 8, "l'Union sportive d'essai est en Division 1 à la place d'un invité")
	check(not foot.clubs.has("invite_86113"), "c'est l'invité de sa propre commune qu'il remplace")
	check(foot.clubs.essai.nom == "Union sportive d'essai" and foot.clubs.essai.court == "USE" and foot.clubs.essai.couleurs == ["#1b3c8c", "#f2c94c"], "son nom, son sigle et ses couleurs viennent du manifeste")
	check(foot.clubs.size() == 8 and foot.en_attente().is_empty(), "huit clubs, rien n'attend")

	# Le mercato : la semaine d'avant la première journée, douze libres, une recrue par club, un libre ne part qu'une fois.
	check(foot.periode() == "mercato" and foot.mercato_ouvert(2) and not foot.mercato_ouvert(1), "une heure avant la saison 2, son mercato est ouvert")
	var libres: Array = foot.libres(2)
	check(libres.size() == 12 and libres[0].poste == "G" and libres[11].poste == "A" and libres[3].nom == foot.libres(2)[3].nom, "douze joueurs libres, les mêmes à chaque tirage")
	check(foot.prix_de(60) == 1200 and foot.prix_de(85) == 6080 and libres.all(func(j): return j.prix == foot.prix_de(j.note)), "le prix suit la note")
	check(foot.recruter(1, "essai", 0).raison == "ferme", "pas de recrue pour une saison passée")
	var avant: Dictionary = foot.effectif("essai", 2)
	var r0: Dictionary = foot.recruter(2, "essai", 0)
	check(r0.ok and foot.transferts_locaux.has("2/essai") and foot.transfert_de(2, "essai").etat == "locale", "l'Union d'essai recrute le premier libre, en local")
	var apres: Dictionary = foot.effectif("essai", 2)
	check(apres.size() == avant.size() and apres.has("essai/libre0") and apres["essai/libre0"].nom == libres[0].nom, "la recrue entre, l'effectif garde sa taille")
	var gardiens_avant: Array = avant.keys().filter(func(id): return avant[id].poste == "G")
	var gardiens_apres: Array = apres.keys().filter(func(id): return apres[id].poste == "G")
	check(gardiens_apres.size() == gardiens_avant.size() and not apres.has(gardiens_avant.reduce(func(a, b): return a if avant[a].note <= avant[b].note else b)), "le plus faible gardien cède sa place")
	check(foot.recruter(2, "essai", 1).raison == "deja", "une recrue par club et par saison")
	check(foot.recruter(2, "smarves", 0).raison == "pris" and foot.preneur(2, 0) == "essai", "un libre ne part qu'une fois")
	check(foot.appliquer_transferts([{"saison": 2, "club": "essai", "joueur": 5, "par": "Lucien"}]), "le serveur apporte une autre recrue pour le même club")
	check(foot.transfert_de(2, "essai").etat == "commune" and foot.effectif("essai", 2).has("essai/libre5") and not foot.effectif("essai", 2).has("essai/libre0"), "elle l'emporte sur la recrue locale")
	check(foot.prochain_mercato() == foot.coup_envoi(3, 1) - 7 * 86400, "le prochain mercato est celui de la saison 3")
	foot.transferts = {}
	foot.transferts_locaux = {}
	foot._effectifs = {}
	foot._matchs = {}

	# Huit terrains de plus au catalogue : le bas est plein, un niveau 2 à deux groupes s'ouvre.
	var entrees := []
	var inseeS := ["86133", "86290", "86015", "86009", "86062", "86100", "86150", "86200"]
	for i in inseeS.size():
		var c := Vienne.commune(inseeS[i])
		entrees.append({"insee": inseeS[i], "id": "c%d" % i, "nom": c.nom, "version": "0.1.0", "paquet": "https://exemple.fr/c%d.pck" % i,
			"taille": 1000, "sha256": "0".repeat(64), "structures": [{"type": "terrain_foot", "id": "stade", "nom": "Le stade", "club": "Le club de %s" % c.nom}]})
	communes.catalogue = Portail.entrees(JSON.stringify({"format": 1, "communes": entrees}))
	communes.catalogue_lu.emit()
	check(registre.de_type("terrain_foot").size() == 10, "dix terrains au registre, avec celui de Smarves")
	foot.actualiser()
	check(foot.niveaux.size() == 2 and foot.niveaux[1].size() == 2 and foot.niveaux[1].all(func(g): return g.size() == 8), "le niveau 2 s'ouvre avec deux groupes de huit")
	var reels: Array = foot.clubs.keys().filter(func(id): return not foot.clubs[id].invite)
	check(reels.size() == 10 and foot.clubs.size() == 24, "dix clubs de plein droit, vingt-quatre en tout")
	check(_sans_doublon(foot), "aucun club dans deux groupes")
	check(foot.nom_division(1, 1) == "Division 2, groupe B" and foot.nom_division(0, 0) == "Division 1", "les divisions ont un nom")

	# Saison 3 : le premier de chaque groupe du bas monte, les deux derniers du haut descendent.
	var finals := [foot.classement(2, 1, 0, 14)[0].club, foot.classement(2, 1, 1, 14)[0].club]
	var haut: Array = foot.classement(2, 0, 0, 14)
	var descendent := [haut[6].club, haut[7].club]
	t = foot.coup_envoi(3, 1) - 3600
	foot.actualiser()
	var h: Dictionary = foot.historique[1]
	check(foot.saison == 3 and h.montes == finals and h.descendus == descendent, "montées %s, descentes %s" % [str(h.montes), str(h.descendus)])
	check(finals.all(func(c): return foot.place_de(c) == [0, 0]) and foot.place_de(descendent[0]) == [1, 0] and foot.place_de(descendent[1]) == [1, 1], "les montés sont en Division 1, les descendus dans les deux groupes fils")
	check(foot.niveaux.all(func(n): return n.all(func(g): return g.size() == 8)) and _sans_doublon(foot), "tous les groupes font huit, sans doublon")

	# La pyramide se relit du fichier ; une pyramide vide se refonde à l'identique.
	var copie: Array = foot.niveaux.duplicate(true)
	foot.niveaux = []
	foot.clubs = {}
	foot.charger()
	check(foot.niveaux == copie and foot.saison == 3, "la pyramide se relit du fichier")

	# Dix saisons d'affilée tiennent.
	t = foot.coup_envoi(13, 1) - 3600
	foot.actualiser()
	check(foot.saison == 13 and foot.historique.size() == 12 and foot.niveaux.all(func(n): return n.all(func(g): return g.size() == 8)) and _sans_doublon(foot), "dix saisons de plus : la pyramide tient")
	t = foot.coup_envoi(13, 14) + 86400 * 9
	foot.actualiser()
	check(foot.saison == 14 and foot.periode() == "treve" and foot.journee_jouee() == 0, "la semaine après la dernière journée, c'est la trêve de la saison 14")
	t = foot.coup_envoi(13, 1) - 3600
	check(foot.prochain_coup_envoi(t)[0] == 13 and foot.prochain_coup_envoi(t)[1] == 1, "le prochain coup d'envoi est la première journée de la saison 13")

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
