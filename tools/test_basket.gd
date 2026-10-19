extends SceneTree
## Vérifie le match de basket sans affichage : godot --headless --path . -s tools/test_basket.gd
## Le cliché d'essai est une vraie semaine de l'Euroleague 2025-26 (20 mars 2026), noté par la fonction
## « basket » du serveur (addict, supabase/functions/basket/notes.js). Un match ne dépend que des équipes
## et de la graine ; les scores sont ceux du basket ; la meilleure équipe gagne le plus souvent sans tout
## gagner ; les absents sont remplacés par des joueurs du village ; la feuille de match tombe juste.

const CLICHE := "res://tools/fixtures/basket_cliche.json"

var fails := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	var cliche: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CLICHE))
	var tous: Array = []
	for code in cliche.joueurs:
		var j: Dictionary = cliche.joueurs[code].duplicate()
		j.code = code
		tous.append(j)
	tous.sort_custom(func(a, b): return a.note > b.note if a.note != b.note else a.code < b.code)
	check(tous.size() > 200, "le cliché d'essai note %d joueurs" % tous.size())

	# Huit équipes de dix, tirées au serpent : de force voisine.
	var equipes: Array = []
	for i in 8:
		equipes.append({"nom": "Équipe %d" % i, "joueurs": [], "consigne": "titulaires"})
	for r in 10:
		for i in 8:
			var k := i if r % 2 == 0 else 7 - i
			var j: Dictionary = tous[r * 8 + k].duplicate()
			j.dispo = true
			equipes[k].joueurs.append(j)
	var forte := {"nom": "Forte", "joueurs": tous.slice(0, 10).map(func(j): var x: Dictionary = j.duplicate(); x.dispo = true; return x)}
	var faible := {"nom": "Faible", "joueurs": tous.slice(tous.size() - 60, tous.size() - 50).map(func(j): var x: Dictionary = j.duplicate(); x.dispo = true; return x)}

	# Même graine, même match.
	var a := BasketMatch.jouer(equipes[0], equipes[1], 1234)
	var b := BasketMatch.jouer(equipes[0], equipes[1], 1234)
	check(JSON.stringify(a) == JSON.stringify(b), "même graine, même match : %s" % str(a.score))
	check(JSON.stringify(a) != JSON.stringify(BasketMatch.jouer(equipes[0], equipes[1], 1235)), "une autre graine, un autre match")

	# Les scores du basket, et une feuille qui tombe juste.
	var points := 0
	var n := 0
	var bas := 999
	var haut := 0
	var juste := true
	var minutes := true
	var victoires_dom := 0
	var prolong := 0
	for i in 8:
		for k in 8:
			if i == k:
				continue
			for g in 5:
				var m := BasketMatch.jouer(equipes[i], equipes[k], Hasard.graine("%d/%d/%d" % [i, k, g]))
				for c in 2:
					points += m.score[c]
					n += 1
					bas = mini(bas, m.score[c])
					haut = maxi(haut, m.score[c])
					var s := 0
					var mn := 0
					for f in m.joueurs[c]:
						s += f.pts
						mn += f.min
						juste = juste and f.pts == 2 * f.t2[0] + 3 * f.t3[0] + f.lf[0]
					juste = juste and s == m.score[c]
					var duree: int = 200 + 25 * m.prolongations
					minutes = minutes and mn == duree
				var q := [0, 0]
				for x in m.quarts:
					q[0] += x[0]
					q[1] += x[1]
				juste = juste and q == m.score
				victoires_dom += 1 if m.score[0] > m.score[1] else 0
				prolong += 1 if m.prolongations > 0 else 0
	var moyenne := float(points) / n
	print("        %d matchs : %.1f points en moyenne (de %d à %d), %d%% gagnés à domicile, %d prolongations" % [n / 2, moyenne, bas, haut, victoires_dom * 200 / n, prolong])
	check(moyenne > 72.0 and moyenne < 90.0, "des scores de basket : %.1f points par équipe en moyenne" % moyenne)
	check(bas > 45 and haut < 130, "pas de score aberrant (de %d à %d)" % [bas, haut])
	check(juste, "les points des joueurs font le score, les quarts aussi, chaque panier compte ce qu'il vaut")
	check(minutes, "les cinq sur le terrain : 200 minutes de joueurs par équipe, 25 de plus par prolongation")
	check(victoires_dom * 2 > n * 0.5 and victoires_dom * 2 < n * 0.62, "un petit avantage à domicile")

	# La force compte, sans tout décider.
	var gagne := 0
	for g in 200:
		var m := BasketMatch.jouer(faible, forte, g) if g % 2 else BasketMatch.jouer(forte, faible, g)
		var f := 1 if g % 2 else 0
		gagne += 1 if m.score[f] > m.score[1 - f] else 0
	check(gagne >= 185, "les dix meilleures notes battent une équipe faible %d fois sur 200" % gagne)
	var proche := 0
	for g in 200:
		var m := BasketMatch.jouer(equipes[3], equipes[4], g) if g % 2 else BasketMatch.jouer(equipes[4], equipes[3], g)
		var f := 0 if g % 2 else 1
		proche += 1 if m.score[f] > m.score[1 - f] else 0
	check(proche > 70 and proche < 130, "deux équipes voisines du même tirage : %d victoires sur 200 pour la première" % proche)

	# Les minutes suivent la consigne.
	var t := BasketMatch.jouer(equipes[0], equipes[1], 7)
	var r := BasketMatch.jouer(equipes[0].merged({"consigne": "rotation"}, true), equipes[1], 7)
	check(t.joueurs[0][0].min > r.joueurs[0][0].min and t.joueurs[0][9].min < r.joueurs[0][9].min,
		"titulaires : %d min pour le meilleur ; rotation large : %d" % [t.joueurs[0][0].min, r.joueurs[0][0].min])

	# Les absents ne jouent pas ; à moins de cinq, le village complète.
	var blesses: Dictionary = equipes[2].duplicate(true)
	for i in 7:
		blesses.joueurs[i].dispo = false
	var m := BasketMatch.jouer(blesses, equipes[3], 99)
	var codes: Array = m.joueurs[0].map(func(f): return f.code)
	check(m.joueurs[0].size() == 5 and codes.count("village-1") == 1 and codes.count("village-2") == 1 and not codes.has(equipes[2].joueurs[0].code),
		"trois présents et deux joueurs du village : %s" % str(codes))
	var perdu := 0
	for g in 100:
		var x := BasketMatch.jouer(blesses, equipes[3], g)
		perdu += 1 if x.score[0] < x.score[1] else 0
	check(perdu > 75, "une équipe décimée perd %d fois sur 100" % perdu)

	print("\n%s" % ("TOUT EST BON" if fails == 0 else "%d ÉCHEC(S)" % fails))
	quit(1 if fails else 0)
