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
## Ce qu'on doit au Crédit Smarvois. Les intérêts courent avec les mises, pas avec le temps.
var debt := 0
var loans_taken := 0
var _plays_since_interest := 0
const INTEREST_EVERY := 20   # mises
const INTEREST_RATE := 0.03  # par période
const LOAN_FEE := 0.05       # frais de dossier


func spend(amount: int) -> bool:
	if credits < amount:
		return false
	credits -= amount
	staked += amount
	if debt > 0:
		_plays_since_interest += 1
		if _plays_since_interest >= INTEREST_EVERY:
			_plays_since_interest = 0
			debt += maxi(1, int(round(debt * INTEREST_RATE)))
	changed.emit()
	return true


## M. Brunet accorde toujours le prêt : le montant arrive en crédits, la dette compte les frais.
func borrow(amount: int) -> void:
	credits += amount
	debt += amount + int(round(amount * LOAN_FEE))
	loans_taken += 1
	changed.emit()


func repay(amount: int) -> int:
	var paid := mini(amount, mini(credits, debt))
	credits -= paid
	debt -= paid
	changed.emit()
	return paid


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
