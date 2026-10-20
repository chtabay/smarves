extends SceneTree
## Vérifie le championnat de basket sans affichage : godot --headless --path . -s tools/test_basket_championnat.gd
## Avec un seul gymnase, un groupe de huit et sept figurants ; chaque place joue chaque autre deux fois,
## une fois chez elle ; un club nouveau prend la place d'un figurant avec ses points ; quand le niveau du
## bas est plein, un niveau s'ouvre dessous ; à la fin de la saison, le premier monte et les deux derniers
## descendent ; un joueur réel n'est qu'à un club par groupe ; tout se recalcule à l'identique.

const CLICHE := "res://tools/fixtures/basket_cliche.json"

var fails := 0
var t := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func gymnase(commune: String, club: String) -> Dictionary:
	return {"commune": commune, "nom": "La salle de " + commune, "type": "gymnase", "champs": {"club": club}}


func _init() -> void:
	await process_frame
	var basket: Node = root.get_node("Basket")
	basket.dossier = ""
	basket.effacer()
	basket.regler_horloge(func(): return t)
	var inscrits: Array = [gymnase("smarves", "Les Hérons du Clain")]
	basket.source_gymnases = func(): return inscrits

	# Le type « gymnase » du manifeste.
	check(Structures.verifier([{"type": "gymnase", "id": "gymnase", "nom": "La salle", "club": "Les Hérons", "court": "HER", "couleurs": ["#14213d", "#d4a93a"]}]).is_empty(), "un gymnase bien déclaré passe")
	check(not Structures.verifier([{"type": "gymnase", "id": "gymnase", "nom": "La salle"}]).is_empty(), "un gymnase sans club est refusé")
	check(not Structures.verifier([{"type": "gymnase", "id": "gymnase", "nom": "La salle", "club": "X", "couleurs": ["bleu"]}]).is_empty(), "des couleurs illisibles sont refusées")
	check(Commune.SOCLE.naturalnocasecmp_to("1.9") >= 0, "le socle (%s) connaît le gymnase, venu en 1.9" % Commune.SOCLE)

	# Le calendrier : chaque place joue chaque autre deux fois, une fois chez elle, une fois par journée.
	var vus := {}
	var calendrier_juste := true
	for j in range(1, basket.JOURNEES + 1):
		var jouent := {}
		for paire in basket.rencontres(j):
			jouent[paire[0]] = true
			jouent[paire[1]] = true
			vus["%d-%d" % paire] = int(vus.get("%d-%d" % paire, 0)) + 1
		calendrier_juste = calendrier_juste and jouent.size() == 8
	check(calendrier_juste and vus.size() == 56 and vus.values().all(func(v): return v == 1),
		"quatorze journées : chaque place reçoit chaque autre une fois (%d rencontres)" % vus.size())
	check(basket.id_cliche(1, 1) == "2026-10-23" and basket.id_cliche(1, 2) == "2026-10-30", "la journée du samedi joue le cliché de la veille : %s" % basket.id_cliche(1, 1))

	# Sans cliché : la pyramide se fonde, sans effectif.
	t = basket.coup_envoi(1, 1) - 3600
	basket.actualiser()
	check(basket.niveaux.size() == 1 and basket.niveaux[0].size() == 1 and basket.niveaux[0][0].size() == 8, "un groupe de huit")
	check(basket.place_de("smarves").size() == 3 and basket.effectifs.is_empty(), "les Hérons tiennent une place ; pas d'effectif sans cliché")
	var figurants := []
	for p in 8:
		var qui: String = basket.titulaire(0, 0, p, 1)
		if qui.begins_with("fig/"):
			figurants.append(basket.fiche(qui).nom)
	check(figurants.size() == 7 and figurants.all(func(n): return n != ""), "sept figurants de la Vienne : %s" % ", ".join(figurants))

	# Le cliché arrive : les effectifs se tirent, dix par place, un joueur à un seul club du groupe.
	# Le cliché de la veille de la première journée : c'est lui, et lui seul, qui sert au tirage.
	var premier: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CLICHE))
	premier.id = basket.id_cliche(1, 1)
	basket.garder(premier)
	var codes := {}
	var dix := true
	for p in 8:
		var e: Array = basket.effectifs["0/0/%d" % p]
		dix = dix and e.size() == 10
		for c in e:
			codes[c] = true
	check(dix and codes.size() == 80, "dix joueurs réels par club, quatre-vingts différents dans le groupe")

	# Cinq journées jouées : un classement juste, le même recalculé.
	t = basket.coup_envoi(1, 5) + 3 * 3600
	var c1: Array = basket.classement(1, 0, 0)
	var juste := c1.all(func(l): return l.j == 5 and l.v + l.d == 5 and l.pts == 2 * l.v + l.d)
	var pour := 0
	var contre := 0
	for l in c1:
		pour += l.pour
		contre += l.contre
	check(juste and pour == contre, "cinq journées au classement, autant de points marqués qu'encaissés")
	basket._oublier()
	check(JSON.stringify(basket.classement(1, 0, 0)) == JSON.stringify(c1), "le même classement recalculé de zéro")
	var m: Dictionary = basket.rencontre(1, 0, 0, 1, basket.rencontres(1)[0][0], basket.rencontres(1)[0][1])
	check(m.score[0] > 40 and m.score[1] > 40, "un vrai score de basket : %s" % str(m.score))

	# Huit gymnases de plus après la cinquième journée : sept remplacent les figurants, le huitième ouvre un niveau.
	var fig_place: int = -1
	for p in 8:
		if basket.titulaire(0, 0, p, 6).begins_with("fig/"):
			fig_place = p
			break
	var points_avant: int = c1.filter(func(l): return l.place == fig_place)[0].pts
	for i in 8:
		inscrits.append(gymnase("commune%d" % i, "Club %d" % i))
	basket.actualiser()
	check(basket.niveaux.size() == 2 and basket.niveaux[1].size() == 2, "le niveau du dessous s'ouvre : deux groupes de huit")
	check(basket.titulaire(0, 0, fig_place, 6) == "commune0", "commune0 prend la place d'un figurant à la journée suivante")
	check(basket.titulaire(0, 0, fig_place, 5).begins_with("fig/"), "le figurant reste aux journées déjà jouées")
	var l0: Dictionary = basket.classement(1, 0, 0).filter(func(l): return l.place == fig_place)[0]
	check(l0.club == "commune0" and l0.pts == points_avant and l0.j == 5, "il reprend ses %d points et ses cinq matchs" % points_avant)
	check(basket.place_de("commune7")[0] == 1 and basket.effectifs.has("1/0/0") and basket.effectifs.has("1/1/7"), "le neuvième club va au niveau du dessous, qui a ses effectifs")
	var humains := 0
	for p in 8:
		humains += 0 if basket.titulaire(0, 0, p, 6).begins_with("fig/") else 1
	check(humains == 8, "le premier niveau n'a plus que des clubs inscrits")

	# Le match pour la salle, et le panneau du club.
	var ms: Dictionary = basket.match_pour_salle("smarves")
	check(ms.has("dom") and ms.has("ext") and (ms.fini == false or (ms.score.size() == 2 and ms.feuilles.size() == 2 and ms.feuilles[0][0].has("pas"))),
		"le match pour la salle : %s – %s" % [ms.get("dom", "?"), ms.get("ext", "?")])
	var panneau: PanelContainer = load("res://scripts/socle/basket_panneau.gd").new()
	panneau.commune = "smarves"
	root.add_child(panneau)
	var textes: Array = []
	var pile: Array = [panneau]
	while not pile.is_empty():
		var x: Node = pile.pop_back()
		if x is Label:
			textes.append(x.text)
		pile.append_array(x.get_children())
	var tout := "\n".join(textes)
	check(tout.contains("LES HÉRONS DU CLAIN") and tout.contains("Pts") and tout.contains("PIR"), "le panneau : le club, le classement, les vrais matchs des joueurs")
	panneau.queue_free()

	# Un joueur que le cliché ne connaît pas est indisponible.
	basket.effectifs["0/0/0"][0] = "inconnu"
	basket._oublier()
	var e0: Dictionary = basket.equipe(1, 0, 0, 0, 6)
	check(not e0.joueurs[0].dispo and e0.joueurs[1].note > 0, "un joueur absent du cliché ne joue pas")

	# La saison se clôt : le premier de chaque groupe du bas monte, les deux derniers du haut descendent.
	var haut: Array = basket.classement(1, 0, 0, 14).map(func(l): return l.club)
	var bas0: Array = basket.classement(1, 1, 0, 14).map(func(l): return l.club)
	var bas1: Array = basket.classement(1, 1, 1, 14).map(func(l): return l.club)
	t = basket.coup_envoi(2, 1) - 3 * 86400
	basket.actualiser()
	var groupe0: Array = []
	for p in 8:
		groupe0.append(basket.titulaire(0, 0, p, 1))
	check(basket.saison == 2 and basket.historique[0].champion == haut[0], "saison 2 ; champion : %s" % basket.fiche(haut[0]).nom)
	check(bas0[0] in groupe0 and bas1[0] in groupe0 and not haut[6] in groupe0 and not haut[7] in groupe0, "deux montent, deux descendent")
	check(basket.place_de(haut[6])[0] == 1 and basket.place_de(haut[7])[0] == 1, "les deux derniers jouent au niveau du dessous")

	print("\n%s" % ("TOUT EST BON" if fails == 0 else "%d ÉCHEC(S)" % fails))
	quit(1 if fails else 0)
