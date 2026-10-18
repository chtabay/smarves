extends SceneTree
## Vérifie les paris du comptoir sans affichage : godot --headless --path . -s tools/test_foot_paris.gd
## Les cotes se tirent des forces, avec la marge de la maison ; un ticket part avant le coup d'envoi,
## pas après ; il se règle à 17 h, le gain rentre dans les crédits et dans le total gagné ; la fenêtre
## montre les quatre matchs de la division suivie.

var fails := 0
var t := 0


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


func _init() -> void:
	await process_frame
	var foot: Node = root.get_node("Football")
	var paris: Node = root.get_node("Paris")
	var game: Node = root.get_node("Game")
	foot.dossier = ""
	paris.dossier = ""
	paris.effacer()
	game.saving_enabled = false
	game.credits = 1000
	game.won = 2000
	game.staked = 0
	foot.regler_horloge(func(): return t)
	t = foot.coup_envoi(1, 1) - 86400
	foot.actualiser()

	# Les cotes.
	var p: Array = paris.probabilites(60.0, 60.0)
	check(absf(p[0] + p[1] + p[2] - 1.0) < 0.001 and p[0] > p[2], "les chances somment à 1 et le terrain compte : %s" % str(p))
	var fort: Array = paris.probabilites(80.0, 40.0)
	check(fort[0] > 0.7 and fort[2] < 0.12, "un fort à domicile contre un faible : %s" % str(fort))
	var c: Array = paris.cotes_de(p)
	check(c.all(func(x): return x >= 1.05) and c[0] < c[2], "les cotes sont au-dessus de 1,05 et le favori paie moins : %s" % str(c))
	var marge: float = 1.0 / c[0] + 1.0 / c[1] + 1.0 / c[2]
	check(marge > 1.1 and marge < 1.25, "la maison garde sa marge (%.2f)" % marge)
	check(paris.issue([2, 1]) == "1" and paris.issue([0, 0]) == "N" and paris.issue([1, 3]) == "2", "l'issue d'un score")

	# Un ticket sur la journée 1, avant le coup d'envoi.
	var m: Dictionary = foot.journee(1, 0, 0, 1, 0)[0]
	var k: String = paris.cle(m.dom, m.ext)
	var cotes: Dictionary = paris.cotes(1, m.dom, m.ext)
	check(cotes.has("1") and cotes.has("N") and cotes.has("2") and cotes["1"] == paris.cotes(1, m.dom, m.ext)["1"], "les cotes d'un match sont fixes : %s" % str(cotes))
	check(not paris.parier(1, 1, 0, 0, {}, 20).ok, "un ticket vide ne se prend pas")
	check(paris.parier(1, 1, 0, 0, {k: "1"}, 15).raison == "mise", "une mise hors carte ne se prend pas")
	var r: Dictionary = paris.parier(1, 1, 0, 0, {k: "1"}, 50)
	check(r.ok and game.credits == 950 and game.staked == 50 and paris.ouverts().size() == 1, "un ticket à 50 part : crédits débités, mise comptée")
	check(absf(float(r.ticket.cote) - float(cotes["1"])) < 0.001, "la cote du ticket simple est celle du match")
	var m2: Dictionary = foot.journee(1, 0, 0, 1, 0)[1]
	var k2: String = paris.cle(m2.dom, m2.ext)
	var r2: Dictionary = paris.parier(1, 1, 0, 0, {k: "N", k2: "2"}, 10)
	check(r2.ok and absf(float(r2.ticket.cote) - snappedf(float(cotes["N"]) * float(paris.cotes(1, m2.dom, m2.ext)["2"]), 0.01)) < 0.011, "un combiné multiplie les cotes (%.2f)" % float(r2.ticket.cote))
	game.credits = 5
	check(paris.parier(1, 1, 0, 0, {k: "1"}, 10).raison == "credits", "sans crédits, pas de ticket")
	game.credits = 940
	check(paris.regler().is_empty() and paris.ouverts().size() == 2, "rien ne se règle avant le dimanche")

	# Le dimanche à 15 h 30 : trop tard pour parier, trop tôt pour régler.
	t = foot.coup_envoi(1, 1) + 1800
	check(paris.parier(1, 1, 0, 0, {k: "1"}, 10).raison == "joue", "le coup d'envoi donné, plus de ticket sur cette journée")
	check(paris.regler().is_empty(), "à 15 h 30, on attend encore")
	# À 17 h : réglé.
	t = foot.coup_envoi(1, 1) + 2 * 3600
	var avant_won: int = game.won
	var avant_credits: int = game.credits
	var regles: Array = paris.regler()
	check(regles.size() == 2 and paris.ouverts().is_empty(), "à 17 h, les deux tickets sont réglés")
	var score: Array = foot.resultat(1, 1, m.dom, m.ext)
	var t1: Dictionary = regles[0]
	var attendu_gagne: bool = paris.issue(score) == "1"
	check((t1.etat == "gagne") == attendu_gagne, "le ticket simple suit le résultat %s (%s)" % [str(score), t1.etat])
	var gains := 0
	for tk in regles:
		gains += int(tk.gain)
	check(game.credits == avant_credits + gains and game.won == avant_won + gains, "le gain rentre dans les crédits et dans le total gagné (%d)" % gains)
	var b: Dictionary = paris.bilan()
	check(b.tickets == 2 and b.mise == 60 and b.gagne == gains, "le bilan : %s" % str(b))
	# Les tickets ne se règlent qu'une fois.
	check(paris.regler().is_empty() and game.credits == avant_credits + gains, "réglé une seule fois")

	# La fenêtre, la veille de la journée 2.
	t = foot.coup_envoi(1, 2) - 86400
	var fenetre: PanelContainer = load("res://scripts/socle/foot_paris.gd").new()
	root.add_child(fenetre)
	await process_frame
	var textes := _textes(fenetre)
	check(textes.any(func(x): return x.begins_with("Journée 2, ")), "la fenêtre parle de la journée à venir")
	var choix: Array = fenetre.find_children("Choix_*", "Button", true, false)
	check(choix.size() == 12, "quatre matchs, trois cotes chacun (%d boutons)" % choix.size())
	check(fenetre.find_children("Mise_*", "Button", true, false).size() == paris.MISES.size() and fenetre.find_child("Jouer", true, false) != null, "les mises et le bouton Jouer")
	check(not fenetre.jouer(), "rien de coché : le ticket ne part pas")
	(choix[0] as Button).pressed.emit()
	await process_frame
	check(fenetre.choix.size() == 1 and fenetre.cote_ticket() > 1.0, "un match coché, une cote")
	var credits_avant: int = game.credits
	check(fenetre.jouer() and game.credits == credits_avant - 20 and paris.ouverts().size() == 1, "le ticket part à la mise par défaut de 20")
	textes = _textes(fenetre)
	check(textes.any(func(x): return x.contains("3 tickets")), "le bilan compte trois tickets")
	fenetre.queue_free()
	paris.effacer()
	print("paris: %d échecs" % fails)
	quit(1 if fails > 0 else 0)


func _textes(n: Node) -> Array:
	var out: Array = []
	for l in n.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out
