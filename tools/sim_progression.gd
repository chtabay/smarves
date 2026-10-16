extends Node
## Simule des joueurs moyens pendant une heure, pour vérifier le rythme d'ouverture des lieux :
## godot --headless --path . res://tools/sim_progression.tscn
## Chaque coup dure en moyenne 5 secondes. Le joueur alterne machine à sous et chances simples de la
## roulette, mise selon ses moyens, prend les avances puis emprunte à M. Brunet quand il n'a plus rien.

const PLAYERS := 300
const MINUTES := 60.0
const SECONDS_PER_PLAY := 5.0

var SLOT = load("res://scripts/slot_machine.gd")
var MAIN = load("res://scripts/main.gd")
var CASINO = load("res://scripts/casino_interior.gd")
var GAME = load("res://scripts/game_state.gd")


func _ready() -> void:
	var strip: Array = []
	for s in SLOT.STRIP_WEIGHTS:
		for k in SLOT.STRIP_WEIGHTS[s]:
			strip.append(s)
	var milestones := {}
	for p in MAIN.PLACES:
		if p.seuil > 0:
			milestones["Lieu : " + p.name] = p.seuil
	for l in CASINO.LOCKS:
		if l.get("on", "won") == "won":
			milestones["Casino : " + l.name] = l.seuil
	var times := {}
	for k in milestones:
		times[k] = []
	var loan_times: Array = []
	var debts_30: Array = []
	var debts_60: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for pl in PLAYERS:
		var credits: int = GAME.START_CREDITS
		var won := 0
		var debt := 0
		var advances: int = GAME.MAX_ADVANCES
		var plays_since := 0
		var loans := 0
		var t := 0.0
		var reached := {}
		var first_loan := -1.0
		var peak: int = GAME.START_CREDITS
		while t < MINUTES * 60.0:
			t += SECONDS_PER_PLAY * rng.randf_range(0.6, 1.4)
			peak = maxi(peak, credits)
			# Quand M. Brunet se manifeste (crédits tombés aux deux cinquièmes du sommet), le joueur finit souvent par le voir.
			if credits < peak * 2 / 5 and advances <= 0 and rng.randf() < 0.03:
				var amount := 500 if debt == 0 else maxi(500, int(debt / 2.0 / 500.0) * 500)
				credits += amount
				debt += amount + int(round(amount * GAME.LOAN_FEE))
				if first_loan < 0.0:
					first_loan = t
			# En dessous d'une mise de 5, on va voir Josiane, puis M. Brunet.
			if credits < 5:
				if advances > 0:
					advances -= 1
					credits += GAME.ADVANCE
				else:
					var amount := 500 if debt == 0 else maxi(500, int(debt / 2.0 / 500.0) * 500)
					credits += amount
					debt += amount + int(round(amount * GAME.LOAN_FEE))
					loans += 1
					if first_loan < 0.0:
						first_loan = t
			# Un joueur moyen mise environ un dixième de ce qu'il a, en jetons ronds.
			var bet := 5
			for b in [5, 10, 25, 100, 500]:
				if credits >= b * 10:
					bet = b
			bet = mini(bet, credits)
			credits -= bet
			if debt > 0:
				plays_since += 1
				if plays_since >= GAME.INTEREST_EVERY:
					plays_since = 0
					debt += maxi(1, int(round(debt * GAME.INTEREST_RATE)))
			var payout := 0
			if rng.randf() < 0.5:
				var line := [strip[rng.randi() % strip.size()], strip[rng.randi() % strip.size()], strip[rng.randi() % strip.size()]]
				if line[0] == line[1] and line[1] == line[2]:
					payout = bet * SLOT.PAYS[line[0]]
				elif line.count("7") == 2:
					payout = bet * 2
			else:
				var n := rng.randi() % 37
				if n != 0 and n % 2 == 0:
					payout = bet * 2
			credits += payout
			won += payout
			for k in milestones:
				if not reached.has(k) and won >= milestones[k]:
					reached[k] = t
					times[k].append(t / 60.0)
			if absf(t - 1800.0) < SECONDS_PER_PLAY:
				debts_30.append(debt)

		debts_60.append(debt)
		if first_loan >= 0.0:
			loan_times.append(first_loan / 60.0)
	print("=== %d joueurs, %d minutes ===" % [PLAYERS, MINUTES])
	var keys := milestones.keys()
	keys.sort_custom(func(a, b): return milestones[a] < milestones[b])
	for k in keys:
		var arr: Array = times[k]
		arr.sort()
		var pct := 100.0 * arr.size() / PLAYERS
		var med: String = ("%.1f min" % arr[arr.size() / 2]) if arr.size() > 0 else "jamais"
		print("%-45s seuil %8d   atteint par %3d %%   médiane %s" % [k, milestones[k], int(pct), med])
	loan_times.sort()
	print("Premier prêt de M. Brunet : %d %% des joueurs, médiane %.1f min" % [100 * loan_times.size() / PLAYERS, loan_times[loan_times.size() / 2] if loan_times.size() > 0 else -1.0])
	debts_60.sort()
	print("Dette médiane après une heure : %d" % debts_60[debts_60.size() / 2])
	get_tree().quit(0)
