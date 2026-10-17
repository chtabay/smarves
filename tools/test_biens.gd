extends Node
## Test automatique des biens : godot --headless --path . res://tools/test_biens.tscn
## Achète, finance, fait tourner des recettes, revend, déclenche une reprise, puis remet tout à zéro.
## Ne touche pas à la sauvegarde.

var _fails := 0


func _check(cond: bool, what: String) -> void:
	print(("ok      " if cond else "ÉCHEC   ") + what)
	if not cond:
		_fails += 1


func _bets(n: int, bet := 25) -> void:
	for i in n:
		Game.spend(bet)


func _ready() -> void:
	# Pas de Game.reset() ici : il effacerait la vraie sauvegarde.
	Game.saving_enabled = false
	Game.credits = 5000
	Game.won = 0
	Game.staked = 0
	Game.debt = 0
	Game.changed.emit()
	_check(Biens.buy("smarvoise"), "achat comptant d'une part de la Smarvoise")
	_check(Game.credits == 4800 and Biens.count("smarvoise") == 1, "200 crédits débités")
	_check(Biens.next_price("smarvoise") == 300, "la deuxième part coûte 300")
	_check(not Biens.buy("fournil"), "le fournil n'est pas proposé avant 3 000 gagnés")
	var debt := Game.debt
	_check(Biens.buy("mobylette", true), "mobylette financée par M. Brunet")
	_check(Game.debt == debt + 525 and Game.credits == 4800, "dette : prix et frais de dossier, crédits intacts")
	_check(Biens.standing() == 1 and Biens.driven == "mobylette", "standing 1, on conduit la mobylette")
	var before := Game.credits
	_bets(19)
	_check(Biens.recettes == 0, "pas de recette avant 20 mises")
	_bets(1)
	_check(Biens.recettes == 1, "une recette à la 20e mise")
	var paid := Game.credits - (before - 20 * 25)
	_check(paid >= 7 - 5 and paid <= 20 - 5, "recette pleine entre 35 et 100 %% de 20, moins 5 de charges (%d)" % paid)
	_bets(20, 5)
	_check(Biens.last_animation == 0.2, "recette au cinquième quand on mise 5 (%.2f)" % Biens.last_animation)
	var c := Game.credits
	_check(Biens.sell("smarvoise") == 120 and Game.credits == c + 120, "revente à 60 %")
	Game.advances_left = 0
	_check(Biens.offer_tournee() and Game.advances_left == 1, "la tournée remet une avance")
	# La reprise : grosse dette, peu de biens.
	Game.debt = 20000
	Biens._since_reprise = Biens.REPRISE_EVERY
	_bets(20)
	_check(Biens.reprises == 1 and Biens.count("mobylette") == 0, "M. Brunet reprend la mobylette")
	Game.staked = 0
	Game.changed.emit()
	_check(Biens.owned.is_empty() and Biens.recettes == 0, "nouvelle partie : plus de biens")
	print("\n%s" % ("Tout est bon." if _fails == 0 else "%d échec(s)." % _fails))
	get_tree().quit(_fails)
