extends SceneTree
## Vérifie le match minute par minute sans affichage : godot --headless --path . -s tools/test_foot_match.gd
## Le moteur repris du Vestiaire (FootMatch) joue un match complet et rejouable ; ses buts font le score ;
## les effectifs d'une saison sont stables, chaque joueur a ses sept compétences ; une décision d'avant-match
## change la rencontre ; le onze occupe trois couloirs et chaque action a le sien ; sur cent matchs, le
## nombre de buts reste celui d'un championnat, avec des corners, des coups francs et des penaltys ; la
## feuille du match s'ouvre depuis le tableau.

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var foot: Node = root.get_node("Football")
	foot.dossier = ""
	var t5: int = foot.coup_envoi(1, 5) + 3600
	foot.regler_horloge(func(): return t5)
	foot.actualiser()
	var groupe: Array = foot.niveaux[0][0]
	var dom: String = groupe[0]
	var ext: String = groupe[1]

	# L'effectif d'une saison.
	var eff: Dictionary = foot.effectif(dom, 1)
	check(eff.size() == 18, "dix-huit joueurs par club : %d" % eff.size())
	var postes := {}
	for j in eff.values():
		postes[j.poste] = postes.get(j.poste, 0) + 1
		check(j.note >= 35 and j.note <= 92 and j.age >= 17 and j.age <= 36, "%s %s : note %d, %d ans" % [j.prenom, j.nom, j.note, j.age]) if j.note < 35 or j.note > 92 else null
	check(postes == {"G": 2, "D": 6, "M": 6, "A": 4}, "deux gardiens, six défenseurs, six milieux, quatre attaquants : %s" % str(postes))
	check(foot.effectif(dom, 1) == eff and foot.effectif(dom, 2) != eff, "le même effectif toute la saison, un autre la saison suivante")

	# Les sept compétences de chacun, au profil de son poste, les mêmes à chaque lecture.
	var g_ok := true
	var a_ok := true
	for j in eff.values():
		var c: Dictionary = j.get("competences", {})
		if c.size() != 8 or c.values().any(func(v): return v < 20 or v > 95):
			g_ok = false
		if j.poste == "G" and c.get("gardien", 0) <= c.get("but", 0):
			g_ok = false
		if j.poste == "A" and c.get("but", 0) <= c.get("gardien", 0):
			a_ok = false
	check(g_ok and a_ok, "huit compétences par joueur : le gardien garde, le buteur marque")
	var costaud := {"poste": "M", "note": 60, "age": 26, "competences": {"endurance": 90}}
	var fragile := {"poste": "M", "note": 60, "age": 26, "competences": {"endurance": 30}}
	check(FootMatch.perte_condition(costaud) < 0.75 * FootMatch.perte_condition(fragile) and FootMatch.perte_condition(fragile, 1.35) > FootMatch.perte_condition(fragile), "l'endurance ralentit l'usure, le pressing haut l'accélère : %.3f contre %.3f par minute" % [FootMatch.perte_condition(costaud), FootMatch.perte_condition(fragile)])
	check(FootMatch.competence(eff.values()[0], "cpa") == float(eff.values()[0].competences.cpa) and FootMatch.competence({"poste": "M", "note": 60}, "jeu") > 55.0, "la compétence lue, ou déduite de la note quand elle manque")
	check(FootMatch.couloir_de(FootMatch.FORMATIONS["4-4-2"][1]) == "gauche" and FootMatch.couloir_de(FootMatch.FORMATIONS["4-4-2"][2]) == "centre" and FootMatch.couloir_de(FootMatch.FORMATIONS["4-4-2"][4]) == "droite", "les cases ont leur couloir")

	# Un match joué d'une traite.
	var etat: Dictionary = foot.rencontre(1, 5, dom, ext)
	check(etat.fini and etat.periode == 2 and etat.minute >= 92, "le match va au bout : %s à la %d" % [FootMatch.libelle_minute(etat), etat.minute])
	check(etat.score == foot.resultat(1, 5, dom, ext), "le score officiel est celui du match : %s" % str(etat.score))
	var buts := [0, 0]
	for b in etat.buts:
		buts[b.equipe] += 1
	check(buts == etat.score, "les buts du récit font le score")
	var types: Array = etat.evenements.map(func(e): return e.type)
	check(types[0] == "coupEnvoi" and "mi-temps" in types and "reprise" in types and types[-1] == "fin", "coup d'envoi, mi-temps, reprise, fin")
	check(etat.evenements.size() >= 20 and etat.evenements.all(func(e): return not "{" in e.texte), "le commentateur parle sans trou : %d lignes" % etat.evenements.size())
	for i in 2:
		check(etat.equipes[i].remplacements <= FootMatch.MAX_REMPLACEMENTS and etat.equipes[i].onze.size() <= 11, "équipe %d : %d changements, %d sur le terrain" % [i, etat.equipes[i].remplacements, etat.equipes[i].onze.size()])
	var poss: Array = FootMatch.possession(etat)
	check(poss[0] + poss[1] == 100 and etat.stats[0].tirs >= etat.stats[0].cadres, "possession et tirs se tiennent : %s" % str(poss))
	var onze0: Array = etat.equipes[0].onze
	check(onze0.all(func(e): return e.couloir in FootMatch.COULOIRS) and onze0.any(func(e): return e.couloir == "gauche") and onze0.any(func(e): return e.couloir == "droite"), "le onze occupe les trois couloirs")
	var occasions: Array = etat.evenements.filter(func(e): return e.type == "occasion")
	check(occasions.all(func(e): return e.couloir in FootMatch.COULOIRS and e.phase in ["jeu", "corner", "coupFranc", "penalty"]), "chaque occasion a son couloir et sa phase : %d occasions" % occasions.size())
	var tirs: Array = etat.evenements.filter(func(e): return e.type in ["but", "arret", "rate", "poteau"])
	check(tirs.all(func(e): return e.has("couloir") and e.has("joueur")), "chaque tir dit son couloir et son tireur")
	var s0: Dictionary = etat.stats[0]
	check(s0.couloirs.gauche + s0.couloirs.centre + s0.couloirs.droite == occasions.filter(func(e): return e.equipe == 0 and e.phase in ["jeu", "penalty"]).size(), "les occasions se comptent par couloir : %s" % str(s0.couloirs))
	var secteurs: Dictionary = FootMatch.secteurs(etat.equipes[0], etat.joueurs if etat.has("joueurs") else _joueurs_de(foot, dom, ext))
	check(secteurs.has("attaque_gauche") and secteurs.has("defense_droite") and secteurs.milieu > 20.0 and secteurs.milieu < 110.0, "les secteurs à l'échelle d'une note : milieu %.0f, attaque gauche %.0f, défense centre %.0f" % [secteurs.milieu, secteurs.attaque_gauche, secteurs.defense_centre])

	# Rejouable, et sensible aux décisions.
	var h := Hasard.depuis(Hasard.graine("essai"))
	var joueurs := {}
	joueurs.merge(foot.effectif(dom, 1))
	joueurs.merge(foot.effectif(ext, 1))
	var a := FootMatch.simuler(FootMatch.creer(foot._equipe(1, 5, dom, joueurs), foot._equipe(1, 5, ext, joueurs), joueurs, Hasard.depuis(7)), joueurs, Hasard.depuis(7))
	var b := FootMatch.simuler(FootMatch.creer(foot._equipe(1, 5, dom, joueurs), foot._equipe(1, 5, ext, joueurs), joueurs, Hasard.depuis(7)), joueurs, Hasard.depuis(7))
	check(a.score == b.score and a.evenements.size() == b.evenements.size() and a.evenements[-1].texte == b.evenements[-1].texte, "à graine égale, même match")
	check(foot.decider(1, 9, dom, {"mentalite": "tout", "formation": "4-3-3", "pressing": "haut"}), "on décide la tactique d'un match à venir")
	var r9: Dictionary = foot.rencontre(1, 9, dom, ext) if foot.calendrier(1, groupe, 0, 0)[8].any(func(m): return m.dom == dom and m.ext == ext) else foot.rencontre(1, 9, dom, groupe[2])
	check(r9.equipes[0].formation == "4-3-3" and r9.equipes[0].onze.size() <= 11, "la formation décidée est jouée : %s" % r9.equipes[0].formation)
	check(foot.rencontre(1, 5, dom, ext).equipes[0].mentalite in ["equilibree", "prudente", "offensive", "tout"], "sans décision, l'équipe part équilibrée")

	# Cent matchs : des buts comme dans un championnat, et l'avantage du terrain.
	var total := 0
	var dom_gagne := 0
	var n := 0
	for j in range(1, 15):
		for m in foot.journee(1, 0, 0, j, 14):
			total += m.score[0] + m.score[1]
			dom_gagne += 1 if m.score[0] > m.score[1] else 0
			n += 1
	for j in range(1, 15):
		for m in foot.journee(2, 0, 0, j, 14):
			total += m.score[0] + m.score[1]
			dom_gagne += 1 if m.score[0] > m.score[1] else 0
			n += 1
	var moyenne := float(total) / n
	check(n == 112 and moyenne >= 1.8 and moyenne <= 3.6, "%d matchs, %.2f buts par match" % [n, moyenne])
	check(dom_gagne >= n * 0.3, "le terrain compte : %d victoires à domicile sur %d" % [dom_gagne, n])

	# Sur ces matchs, les coups de pied arrêtés et les ailes existent, le centre domine.
	var cpa := {"corner": 0, "coupFranc": 0, "penalty": 0}
	var couloirs := {"gauche": 0, "centre": 0, "droite": 0}
	var buts_tete := 0
	var buts_cpa := 0
	for j in range(1, 15):
		for m in foot.journee(1, 0, 0, j, 14):
			var e: Dictionary = foot.rencontre(1, j, m.dom, m.ext)
			for ev in e.evenements:
				if ev.type == "occasion":
					if ev.phase != "jeu":
						cpa[ev.phase] += 1
					couloirs[ev.couloir] += 1
			for bt in e.buts:
				buts_tete += 1 if bt.tete else 0
				buts_cpa += 1 if bt.coup_franc or bt.penalty else 0
	check(cpa.corner >= 10 and cpa.coupFranc >= 10 and cpa.penalty >= 1, "corners, coups francs et penaltys sur une saison : %s" % str(cpa))
	check(couloirs.centre > couloirs.gauche and couloirs.centre > couloirs.droite and couloirs.gauche > 0 and couloirs.droite > 0, "les trois couloirs servent, le centre d'abord : %s" % str(couloirs))
	check(buts_tete >= 3 and buts_cpa >= 1, "des buts de la tête (%d) et sur coup de pied arrêté (%d)" % [buts_tete, buts_cpa])
	# Au coup d'envoi, le corner est tiré par le meilleur tireur de coups de pied arrêtés du onze.
	var frais := FootMatch.creer(foot._equipe(1, 5, dom, joueurs), foot._equipe(1, 5, ext, joueurs), joueurs, Hasard.depuis(3))
	var hc := Hasard.depuis(3)
	var corner := {}
	for k in 40:
		FootMatch._corner(frais, 0, "gauche", joueurs, hc)
		var occ: Array = frais.evenements.filter(func(e): return e.type == "occasion" and e.get("phase", "") == "corner")
		if not occ.is_empty():
			corner = occ[0]
			break
	check(not corner.is_empty() and corner.tireur == FootMatch._meilleur(frais.equipes[0], joueurs, "cpa").id and corner.joueur != corner.tireur and corner.couloir == "gauche", "le meilleur tireur de coups de pied arrêtés tire le corner, un autre le reprend")

	# La feuille du match dans le tableau.
	var fenetre := FootTableau.new()
	root.add_child(fenetre)
	await process_frame
	var boutons: Array = fenetre.find_children("Feuille_*", "Button", true, false)
	check(boutons.size() == 4, "quatre feuilles à ouvrir pour la journée jouée : %d" % boutons.size())
	boutons[0].pressed.emit()
	await process_frame
	var textes := _textes(fenetre)
	check(textes.any(func(x): return x == "Le match minute par minute") and textes.any(func(x): return x.begins_with("Buts ")), "la feuille montre les buts et le récit")
	check(fenetre.find_children("Recit", "ScrollContainer", true, false).size() == 1 and textes.has("possession"), "le récit défile, les chiffres sont là")
	check(textes.any(func(x): return x.contains("Journée 5 de la saison 1")), "la feuille dit quel match c'est")
	fenetre.free()

	print("\n%d échec(s)" % fails)
	quit(1 if fails > 0 else 0)


func _joueurs_de(foot: Node, dom: String, ext: String) -> Dictionary:
	var j := {}
	j.merge(foot.effectif(dom, 1))
	j.merge(foot.effectif(ext, 1))
	return j


func _textes(n: Node) -> Array:
	var out: Array = []
	for l in n.find_children("*", "Label", true, false):
		out.append(l.text)
	return out
