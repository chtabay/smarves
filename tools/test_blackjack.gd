extends SceneTree
## Vérifie les règles du blackjack : godot --headless --path . -s tools/test_blackjack.gd
## Avant le seuil, la table joue comme avant (ni partage, ni assurance, pas de regard sous l'as) ; après,
## le partage (jusqu'aux as, qui ne reçoivent qu'une carte), le doublement après partage, l'assurance et
## le croupier qui retourne tout de suite son blackjack. Les cartes sortent d'un sabot arrangé.

var fails := 0
var BJ: GDScript
var G: Node
var dernier := []


func check(ok: bool, what: String) -> void:
	print(("ok      " if ok else "ÉCHEC   ") + what)
	if not ok:
		fails += 1


## Une carte : « A », « 2 »… « 10 », « V », « D », « R ».
func c(nom: String) -> Dictionary:
	return {"r": ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "V", "D", "R"].find(nom), "s": 0}


## Un panneau neuf, dont le sabot donnera ces cartes dans l'ordre (joueur, croupier, joueur, croupier…).
func table(cartes: Array, gagne: int) -> PanelContainer:
	G.won = gagne
	G.credits = 10000
	var p: PanelContainer = BJ.new()
	root.add_child(p)
	var sabot: Array = []
	for k in 80:
		sabot.append(c("2"))
	var dans_l_ordre: Array = cartes.map(func(n): return c(n))
	dans_l_ordre.reverse()
	p.shoe = sabot + dans_l_ordre
	p.bet_index = 2  # 25
	dernier = []
	p.played.connect(func(b: int, pay: int): dernier = [b, pay])
	return p


func _init() -> void:
	await process_frame
	G = root.get_node("Game")
	G.saving_enabled = false
	BJ = load("res://scripts/blackjack_panel.gd")

	# Avant le seuil : le croupier montre un as, rien n'est proposé, on joue ; il a blackjack au bout.
	# L'ordre du sabot : joueur, joueur, croupier, croupier, puis les tirages.
	var p := table(["8", "8", "A", "R"], 0)
	p._start()
	check(p.in_hand and not p.attente_assurance, "avant le seuil : pas d'assurance, la main se joue")
	check(not p.peut_partager(), "avant le seuil : une paire ne se partage pas")
	check(not p._split.visible and not p._insure.visible, "avant le seuil : ni « Partager » ni « Assurer » à l'écran")
	p._on_split()
	check(p.hands.size() == 1, "avant le seuil : le partage est refusé")
	p._on_stand()
	check(dernier == [25, 0] and not p.in_hand, "avant le seuil : le blackjack du croupier se découvre à la fin (%s)" % str(dernier))
	p.queue_free()

	# Après le seuil : partage de deux 8, doublement de la première main, la seconde reste à 17.
	p = table(["8", "8", "6", "10", "3", "10", "9", "7"], 1000)
	var avant: int = G.credits
	p._start()
	check(p.peut_partager() and p._split.visible and not p._split.disabled, "après le seuil : deux 8 se partagent")
	p._on_split()
	check(p.hands.size() == 2 and p.active == 0 and p.hands[0].cards.size() == 2 and p.hands[1].cards.size() == 1, "le partage : deux mains, la première reçoit sa seconde carte")
	check(G.credits == avant - 50, "le partage prend une seconde mise (%d)" % (avant - G.credits))
	p._on_double()
	check(p.active == 1 and p.hands[0].bet == 50 and BJ.total(p.hands[0].cards) == 21, "doublé après partage : 8, 3 et 10, la main suivante se joue")
	check(p.hands[1].cards.size() == 2 and BJ.total(p.hands[1].cards) == 17, "la seconde main reçoit sa carte : 17")
	p._on_stand()
	check(not p.in_hand and dernier == [75, 150], "le croupier saute à 23 : 100 pour la première main, 50 pour la seconde (%s)" % str(dernier))
	p.queue_free()

	# L'assurance prise, le croupier a blackjack : il le retourne tout de suite, l'assurance paie 2 contre 1.
	p = table(["10", "7", "A", "R"], 1000)
	avant = G.credits
	p._start()
	check(p.attente_assurance and p._insure.visible and p._hit.disabled, "le croupier montre un as : l'assurance est proposée, on attend la réponse")
	p._on_hit()
	check(p.player.size() == 2, "pas de carte tant qu'on n'a pas répondu")
	p._on_insure()
	check(not p.in_hand and dernier == [37, 36], "blackjack du croupier retourné d'emblée : la mise perdue, l'assurance de 12 paie 36 (%s)" % str(dernier))
	check(G.credits == avant - 37, "mise et assurance prises (%d)" % (avant - G.credits))
	p.queue_free()

	# Sans assurance, le croupier n'a pas blackjack : on joue, et on gagne.
	p = table(["10", "9", "A", "6"], 1000)
	p._start()
	p._on_no_insure()
	check(p.in_hand and not p.attente_assurance and not p._insure.visible, "sans assurance : la main se joue")
	p._on_stand()
	check(dernier == [25, 50], "19 contre 17 : gagné (%s)" % str(dernier))
	p.queue_free()

	# L'assurance perdue : le croupier n'avait rien sous son as.
	p = table(["10", "9", "A", "6"], 1000)
	p._start()
	p._on_insure()
	p._on_stand()
	check(dernier == [37, 50], "assurance perdue, main gagnée (%s)" % str(dernier))
	p.queue_free()

	# Deux as partagés : une carte chacun, et 21 ne vaut pas blackjack.
	p = table(["A", "A", "6", "10", "R", "9", "10"], 1000)
	p._start()
	p._on_split()
	check(not p.in_hand, "deux as partagés : une carte chacun, la donne se finit seule")
	check(dernier == [50, 100], "21 et 20 contre un croupier qui saute : payés 1 contre 1 (%s)" % str(dernier))
	p.queue_free()

	# Le croupier montre un dix et a blackjack : retourné d'emblée, la paire n'a pas le temps de se partager.
	p = table(["9", "9", "R", "A"], 1000)
	p._start()
	check(not p.in_hand and dernier == [25, 0], "dix et as chez le croupier : blackjack retourné d'emblée (%s)" % str(dernier))
	p.queue_free()

	# Son blackjack contre un as du croupier, sans assurance : payé 3 contre 2 après le regard du croupier.
	p = table(["A", "R", "A", "7"], 1000)
	p._start()
	check(p.attente_assurance, "un as chez le croupier : l'assurance d'abord, même avec un blackjack en main")
	p._on_no_insure()
	check(not p.in_hand and dernier == [25, 62], "blackjack payé 3 contre 2 (%s)" % str(dernier))
	p.queue_free()

	# Jusqu'à quatre mains, pas plus.
	p = table(["8", "8", "6", "10", "8", "8", "8", "8", "8", "8"], 1000)
	p._start()
	p._on_split()
	p._on_split()
	p._on_split()
	check(p.hands.size() == 4 and not p.peut_partager(), "quatre mains au plus (%d)" % p.hands.size())
	p.queue_free()

	print("\n%s" % ("Tout est bon." if fails == 0 else "%d échec(s)." % fails))
	quit(1 if fails > 0 else 0)
