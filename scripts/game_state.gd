extends Node
## L'état de la partie, partagé entre le village et le casino (autoload « Game »).

signal changed

const START_CREDITS := 200
const ADVANCE := 100
const MAX_ADVANCES := 3

var credits := START_CREDITS
## Total gagné au jeu (gains bruts encaissés) : c'est lui qui ouvre les lieux et les salles.
var won := 0
## Total misé, pour les seuils qui portent sur les mises (comme la salle des fêtes d'Addict).
var staked := 0
var advances_left := MAX_ADVANCES


func spend(amount: int) -> bool:
	if credits < amount:
		return false
	credits -= amount
	staked += amount
	changed.emit()
	return true


func cash_in(amount: int) -> void:
	if amount <= 0:
		return
	credits += amount
	won += amount
	changed.emit()


## Si le joueur ne peut plus miser, Josiane (ou la caisse du casino) avance de quoi continuer.
func advance_if_broke(min_bet: int) -> bool:
	if credits >= min_bet or advances_left <= 0:
		return false
	advances_left -= 1
	credits += ADVANCE
	changed.emit()
	return true


static func fmt(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out
