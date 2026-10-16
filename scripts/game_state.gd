extends Node
## L'état de la partie, partagé entre le village et le casino (autoload « Game »).

signal changed
## M. Brunet se manifeste quand les crédits ont fondu : la simulation le place vers la demi-heure.
signal brunet_calls

const START_CREDITS := 1000
const ADVANCE := 200
const MAX_ADVANCES := 2

var credits := START_CREDITS
## Total gagné au jeu (gains bruts encaissés) : c'est lui qui ouvre les lieux et les salles.
var won := 0
## Total misé, pour les seuils qui portent sur les mises (comme la salle des fêtes d'Addict).
var staked := 0
var advances_left := MAX_ADVANCES
## Ce qu'on doit au Crédit Smarvois. Les intérêts courent avec les mises, pas avec le temps.
var debt := 0
var loans_taken := 0
## L'accueil de Josiane a eu lieu (première partie).
var welcomed := false
## Les outils de test coupent la sauvegarde pour ne jamais toucher à la vraie partie.
var saving_enabled := true
var peak_credits := START_CREDITS
var _last_call_staked := -100000
var _plays_since_interest := 0
const INTEREST_EVERY := 20   # mises
const INTEREST_RATE := 0.03  # par période
const LOAN_FEE := 0.05       # frais de dossier


const SAVE_PATH := "user://smarves.save"


func _ready() -> void:
	load_game()
	changed.connect(save_game)


## La partie est gardée sur la machine du joueur, et reprise au lancement suivant.
func save_game() -> void:
	# Ni les captures de vérification ni les tests automatiques ne touchent à la vraie partie.
	if not saving_enabled or get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"credits": credits, "won": won, "staked": staked,
		"advances_left": advances_left, "debt": debt, "loans_taken": loans_taken, "peak": peak_credits, "welcomed": welcomed}))


func load_game() -> void:
	# Les captures de vérification partent toujours d'une partie neuve.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			return
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(data) != TYPE_DICTIONARY:
		return
	credits = int(data.get("credits", credits))
	won = int(data.get("won", won))
	staked = int(data.get("staked", staked))
	advances_left = int(data.get("advances_left", advances_left))
	debt = int(data.get("debt", debt))
	loans_taken = int(data.get("loans_taken", loans_taken))
	peak_credits = int(data.get("peak", peak_credits))
	welcomed = bool(data.get("welcomed", welcomed))


## Nouvelle partie : on efface tout et on repart du pécule.
func reset() -> void:
	credits = START_CREDITS
	won = 0
	staked = 0
	advances_left = MAX_ADVANCES
	debt = 0
	loans_taken = 0
	peak_credits = START_CREDITS
	_last_call_staked = -100000
	welcomed = false
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	changed.emit()


func spend(amount: int) -> bool:
	if credits < amount:
		return false
	credits -= amount
	staked += amount
	Sfx.play("chips", -9.0)
	peak_credits = maxi(peak_credits, credits + amount)
	if credits < peak_credits * 2 / 5 and staked - _last_call_staked > 3000:
		_last_call_staked = staked
		brunet_calls.emit()
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
