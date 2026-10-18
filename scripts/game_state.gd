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
## Ce qu'on doit, par prêteur : chaque commune a sa banque (« smarves » : le Crédit Smarvois de M. Brunet).
## Les intérêts courent avec les mises, pas avec le temps.
var debts := {}
## Le prêteur par défaut : la banque de la commune d'origine (son manifeste, banque.preteur).
var lender := "smarves"
## La dette au total, tous prêteurs confondus. L'écrire ajuste celle du prêteur par défaut (puis, pour
## une baisse qui la dépasse, celle des autres), si bien que le code d'avant garde le même sens.
var debt: int:
	get:
		return _total_debt()
	set(v):
		var delta := v - _total_debt()
		if delta == 0:
			return
		if delta > 0:
			debts[lender] = debt_of(lender) + delta
			return
		for k in [lender] + debts.keys():
			var cut := mini(-delta, debt_of(k))
			debts[k] = debt_of(k) - cut
			delta += cut
		for k in debts.keys():
			if int(debts[k]) <= 0:
				debts.erase(k)
## Les tiroirs des communes (id -> données) : chacune y range ce qui n'appartient qu'à elle.
var tiroirs := {}
## Les pages des communes au carnet du joueur (Carnet.noter) : id -> {nom, compteurs, valeurs, vu}. Au socle,
## pas dans les tiroirs : une commune n'y écrit que par le carnet, qui vérifie ce qu'elle déclare.
var carnet := {}
var loans_taken := 0
## L'accueil de Josiane a eu lieu (première partie).
var welcomed := false
## Où réapparaître sur la place en sortant d'un bâtiment (« casino »), le temps d'un changement de scène.
var return_point := ""
## Les outils de test coupent la sauvegarde pour ne jamais toucher à la vraie partie.
var saving_enabled := true
var peak_credits := START_CREDITS
var _last_call_staked := -100000
var _plays_since_interest := 0
const INTEREST_EVERY := 20   # mises
const INTEREST_RATE := 0.03  # par période
const LOAN_FEE := 0.05       # frais de dossier


const SAUVEGARDE := preload("res://scripts/socle/sauvegarde.gd")
## L'ancien fichier unique, migré en tiroirs au premier lancement (scripts/socle/sauvegarde.gd).
const SAVE_PATH := "user://smarves.save"


func _ready() -> void:
	if Communes.origine():
		lender = Communes.origine().preteur()
	load_game()
	changed.connect(save_game)


## La partie est gardée sur la machine du joueur, et reprise au lancement suivant.
func save_game() -> void:
	# Ni les captures de vérification ni les tests automatiques ne touchent à la vraie partie.
	if not saving_enabled or get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()):
		return
	SAUVEGARDE.ecrire(self)


func load_game() -> void:
	# Les captures de vérification partent toujours d'une partie neuve.
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			return
	# Un outil lancé par -s lit l'ancienne partie sans la migrer : il ne réécrit jamais la vraie partie.
	SAUVEGARDE.charger(self, "user://", get_tree().get_script() == null)


## Relit la partie écrite sur l'appareil, en partant de zéro (la partie du compte vient d'y être
## reprise, scripts/socle/compte.gd). Sans signal : les biens se relisent d'abord, sinon ils
## prendraient une baisse du total misé pour une nouvelle partie et s'effaceraient.
func recharger() -> void:
	_remettre_a_zero()
	SAUVEGARDE.charger(self)


## Nouvelle partie : on efface tout et on repart du pécule.
func reset() -> void:
	_remettre_a_zero()
	SAUVEGARDE.effacer()
	changed.emit()


func _remettre_a_zero() -> void:
	credits = START_CREDITS
	won = 0
	staked = 0
	advances_left = MAX_ADVANCES
	debts = {}
	tiroirs = {}
	carnet = {}
	loans_taken = 0
	peak_credits = START_CREDITS
	_last_call_staked = -100000
	welcomed = false


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
			for k in debts:
				debts[k] = int(debts[k]) + maxi(1, int(round(int(debts[k]) * INTEREST_RATE)))
	changed.emit()
	return true


## Des crédits posés en tapis sur une table à plusieurs (scripts/jeux/poker_multi.gd) : ils quittent la
## poche sans être misés ; ce que montrent les donnes se compte à chaque abattage.
func spend_chips(amount: int) -> bool:
	if amount <= 0 or credits < amount:
		return false
	credits -= amount
	Sfx.play("chips", -9.0)
	changed.emit()
	return true


## M. Brunet accorde toujours le prêt : le montant arrive en crédits, la dette compte les frais.
## from : le prêteur (« » : celui de la commune d'origine).
func borrow(amount: int, from := "") -> void:
	var k := from if from != "" else lender
	credits += amount
	debts[k] = debt_of(k) + amount + int(round(amount * LOAN_FEE))
	# Le compte des prêts est celui de M. Brunet (ses arguments changent) ; un autre banquier tient le sien.
	if k == lender:
		loans_taken += 1
	changed.emit()


## Rembourse un prêteur, ou toutes les dettes en commençant par le prêteur par défaut (to : « »).
func repay(amount: int, to := "") -> int:
	var paid := mini(amount, mini(credits, debt if to == "" else debt_of(to)))
	credits -= paid
	if to == "":
		debt -= paid
	else:
		debts[to] = debt_of(to) - paid
		if debts[to] <= 0:
			debts.erase(to)
	changed.emit()
	return paid


func debt_of(from: String) -> int:
	return int(debts.get(from, 0))


func _total_debt() -> int:
	var t := 0
	for k in debts:
		t += int(debts[k])
	return t


## Le tiroir d'une commune, à remplir par elle ; il est écrit avec la partie (Game.changed).
func tiroir(id: String) -> Dictionary:
	if not tiroirs.has(id):
		tiroirs[id] = {}
	return tiroirs[id]


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
