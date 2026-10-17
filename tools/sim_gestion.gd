extends Node
## Simule la gestion des biens sur la première heure, à côté de la simulation de progression :
## godot --headless --path . res://tools/sim_gestion.tscn
## Mêmes joueurs moyens que tools/sim_progression.gd (un coup toutes les 5 secondes, une mise d'un
## dixième des crédits, avances de Josiane puis M. Brunet), joués deux fois avec les mêmes tirages :
## sans rien acheter, puis en achetant comme un joueur moyen (le bien le moins cher proposé (une fois sur
## deux, le moins cher qui rapporte) dès qu'on a trois fois son prix, et un joueur sur quatre qui fait financer par M. Brunet ce qu'il
## n'a pas de quoi payer trois fois).
## Résultats dans docs/GESTION.md.

const PLAYERS := 300
const MINUTES := 60.0
const SECONDS_PER_PLAY := 5.0
const FINANCERS := 0.25

var SLOT = load("res://scripts/slot_machine.gd")
var MAIN = load("res://scripts/main.gd")
var CASINO = load("res://scripts/casino_interior.gd")
var GAME = load("res://scripts/game_state.gd")
var BIENS = load("res://scripts/biens.gd")

var strip: Array = []
var milestones := {}


func _ready() -> void:
	for s in SLOT.STRIP_WEIGHTS:
		for k in SLOT.STRIP_WEIGHTS[s]:
			strip.append(s)
	for p in MAIN.PLACES:
		if p.seuil > 0:
			milestones["Lieu : " + p.name] = p.seuil
	for l in CASINO.LOCKS:
		if l.get("on", "won") == "won":
			milestones["Casino : " + l.name] = l.seuil
	var base := _run(false)
	var with := _run(true)
	print("=== %d joueurs, %d minutes : sans biens / avec biens ===" % [PLAYERS, MINUTES])
	var keys := milestones.keys()
	keys.sort_custom(func(a, b): return milestones[a] < milestones[b])
	for k in keys:
		print("%-42s seuil %7d   %3d %% · %s   |   %3d %% · %s" % [k, milestones[k],
			_pct(base.times[k]), _med(base.times[k], " min"), _pct(with.times[k]), _med(with.times[k], " min")])
	print("Premier prêt de M. Brunet          %3d %% · %s   |   %3d %% · %s" % [_pct(base.loan), _med(base.loan, " min"), _pct(with.loan), _med(with.loan, " min")])
	print("Dette médiane à 30 min / 60 min    %s / %s   |   %s / %s" % [_med(base.debt30, ""), _med(base.debt60, ""), _med(with.debt30, ""), _med(with.debt60, "")])
	print("Gagné au jeu médian à 60 min       %s   |   %s" % [_med(base.won60, ""), _med(with.won60, "")])
	print("Fortune nette médiane à 60 min (crédits + biens - dette)   %s   |   %s" % [_med(base.net60, ""), _med(with.net60, "")])
	print("")
	var cash := _run(true, 0.0)
	var fin := _run(true, 1.0)
	print("--- Les biens : joueur moyen (un sur quatre fait financer) | n'achète que comptant | fait toujours financer ---")
	for row in [["Premier achat (médiane)", "first_buy", " min"], ["Achats à 30 min", "buys30", ""], ["Achats à 60 min", "buys60", ""],
			["Rente annoncée par recette à 60 min", "rente60", ""], ["Rente versée en moyenne par recette", "paid60", ""],
			["Charges par recette à 60 min", "charge60", ""], ["Standing à 60 min", "standing60", ""],
			["Dépensé en biens dans l'heure", "spent60", ""], ["Reçu en rentes dans l'heure", "rentes60", ""],
			["Payé en charges dans l'heure", "charges60", ""], ["Dette à 60 min", "debt60", ""],
			["Fortune nette à 60 min", "net60", ""], ["Gagné au jeu à 60 min", "won60", ""]]:
		print("%-38s %10s | %10s | %10s" % [row[0], _med(with[row[1]], row[2]), _med(cash[row[1]], row[2]), _med(fin[row[1]], row[2])])
	print("%-38s %9d %% | %9d %% | %9d %%" % ["Reprise par M. Brunet dans l'heure", _pct(with.reprise), _pct(cash.reprise), _pct(fin.reprise)])
	var firsts := {}
	for f in with.first_items:
		firsts[f] = firsts.get(f, 0) + 1
	print("Premier bien acheté : %s" % str(firsts))
	for prof in [["joueur moyen", with], ["comptant", cash], ["financé", fin]]:
		var at_curve := ""
		for m in [5, 10, 15, 20, 30, 40, 50, 60]:
			at_curve += "  %d min : %s" % [m, _med(prof[1].curve[m], "")]
		print("Rente annoncée médiane, %s :%s" % [prof[0], at_curve])
	get_tree().quit(0)


func _pct(arr: Array) -> int:
	return int(100.0 * arr.size() / PLAYERS)


func _med(arr: Array, unit: String) -> String:
	if arr.is_empty():
		return "jamais"
	var a := arr.duplicate()
	a.sort()
	var v = a[a.size() / 2]
	return ("%.1f" % v if typeof(v) == TYPE_FLOAT else Game.fmt(int(v))) + unit


func _price(id: String, n: int) -> int:
	return BIENS.price_of(id, n)


func _run(with_biens: bool, financers := FINANCERS) -> Dictionary:
	var r := {"times": {}, "loan": [], "debt30": [], "debt60": [], "won60": [], "net60": [], "first_buy": [],
		"buys30": [], "buys60": [], "rente60": [], "paid60": [], "charge60": [], "standing60": [], "spent60": [],
		"rentes60": [], "charges60": [], "reprise": [], "first_items": [], "curve": {}}
	for m in [5, 10, 15, 20, 30, 40, 50, 60]:
		r.curve[m] = []
	for k in milestones:
		r.times[k] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var brng := RandomNumberGenerator.new()
	brng.seed = 77
	for pl in PLAYERS:
		var financer := brng.randf() < financers
		var credits: int = GAME.START_CREDITS
		var won := 0
		var debt := 0
		var advances: int = GAME.MAX_ADVANCES
		var plays_since := 0
		var bets := 0
		var period_staked := 0
		var t := 0.0
		var reached := {}
		var first_loan := -1.0
		var peak: int = GAME.START_CREDITS
		var owned := {}
		var worn := ""
		var driven := ""
		var buys := 0
		var spent := 0
		var rentes := 0
		var charges_paid := 0
		var paid_sum := 0
		var paid_n := 0
		var since_reprise := 0
		var had_reprise := false
		var first_buy := -1.0
		var next_mark := 0
		var marks := [5, 10, 15, 20, 30, 40, 50, 60]
		while t < MINUTES * 60.0:
			t += SECONDS_PER_PLAY * rng.randf_range(0.6, 1.4)
			peak = maxi(peak, credits)
			var standing := _standing(owned, worn, driven) if with_biens else 0
			var loan_base := func() -> int:
				var b := 500 if debt == 0 else maxi(500, int(debt / 2.0 / 500.0) * 500)
				return maxi(b, 500 * (1 + standing / 2)) if with_biens else b
			if credits < peak * 2 / 5 and advances <= 0 and rng.randf() < 0.03:
				var amount: int = loan_base.call()
				credits += amount
				debt += amount + int(round(amount * GAME.LOAN_FEE))
				if first_loan < 0.0:
					first_loan = t
			if credits < 5:
				if advances > 0:
					advances -= 1
					credits += GAME.ADVANCE
				else:
					var amount: int = loan_base.call()
					credits += amount
					debt += amount + int(round(amount * GAME.LOAN_FEE))
					if first_loan < 0.0:
						first_loan = t
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
					r.times[k].append(t / 60.0)
			if with_biens:
				# La recette, toutes les 20 mises.
				bets += 1
				period_staked += bet
				if bets >= BIENS.PERIOD:
					bets = 0
					var paid := 0
					var animation := minf(1.0, float(period_staked) / BIENS.ANIMATION)
					period_staked = 0
					for id in owned:
						var it: Dictionary = BIENS.item(id)
						paid += int(round(it.rente * owned[id] * brng.randf_range(BIENS.YIELD_MIN, BIENS.YIELD_MAX) * animation))
					var ch := _charges(owned, worn, driven)
					rentes += paid
					charges_paid += ch
					if not owned.is_empty():
						paid_sum += paid
						paid_n += 1
					credits += paid - ch
					if credits < 0:
						debt += -credits
						credits = 0
					since_reprise += 1
					if debt >= BIENS.REPRISE_DEBT and since_reprise >= BIENS.REPRISE_EVERY and not owned.is_empty() \
							and debt >= BIENS.REPRISE_RATIO * _value(owned):
						var best := ""
						for id in owned:
							if best == "" or _resale(id, owned) > _resale(best, owned):
								best = id
						debt = maxi(0, debt - _resale(best, owned))
						owned[best] -= 1
						if owned[best] <= 0:
							owned.erase(best)
							if worn == best:
								worn = ""
							if driven == best:
								driven = ""
						since_reprise = 0
						had_reprise = true
				# Le joueur moyen achète le bien le moins cher proposé quand il a trois fois son prix en poche.
				if brng.randf() < 0.03:
					var id := _cheapest(owned, worn, driven, won, brng.randf() < 0.5)
					if id != "":
						var price := _price(id, int(owned.get(id, 0)))
						var financed := financer and credits < price * 3
						if financed:
							# M. Brunet avance le prix, frais de dossier compris.
							debt += price + int(round(price * GAME.LOAN_FEE))
						if credits >= price * 3 or financed:
							if not financed:
								credits -= price
							spent += price
							buys += 1
							owned[id] = int(owned.get(id, 0)) + 1
							var kind: String = BIENS.item(id).kind
							if kind == "tenue":
								worn = id
							elif kind == "vehicule":
								driven = id
							if first_buy < 0.0:
								first_buy = t
								r.first_items.append(id)
			while next_mark < marks.size() and t >= marks[next_mark] * 60.0:
				r.curve[marks[next_mark]].append(_rente(owned))
				next_mark += 1
			if absf(t - 1800.0) < SECONDS_PER_PLAY:
				r.debt30.append(debt)
				r.buys30.append(buys)
		r.debt60.append(debt)
		r.won60.append(won)
		r.net60.append(credits + (_value(owned) if with_biens else 0) - debt)
		if first_loan >= 0.0:
			r.loan.append(first_loan / 60.0)
		if with_biens:
			if first_buy >= 0.0:
				r.first_buy.append(first_buy / 60.0)
			r.buys60.append(buys)
			r.rente60.append(_rente(owned))
			r.paid60.append(paid_sum / maxi(1, paid_n))
			r.charge60.append(_charges(owned, worn, driven))
			r.standing60.append(_standing(owned, worn, driven))
			r.spent60.append(spent)
			r.rentes60.append(rentes)
			r.charges60.append(charges_paid)
			if had_reprise:
				r.reprise.append(1)
	return r


## Le bien le moins cher que le vendeur propose, en sautant les tenues et véhicules moins beaux que l'actuel.
func _cheapest(owned: Dictionary, worn: String, driven: String, won: int, rente_only := false) -> String:
	var best := ""
	var best_price := 0
	for it in BIENS.CATALOGUE:
		var n := int(owned.get(it.id, 0))
		if won < it.gate or n >= it.max or (rente_only and it.rente <= 0):
			continue
		if it.kind == "tenue" and worn != "" and BIENS.item(worn).standing >= it.standing:
			continue
		if it.kind == "vehicule" and driven != "" and BIENS.item(driven).standing >= it.standing:
			continue
		var p := _price(it.id, n)
		if best == "" or p < best_price:
			best = it.id
			best_price = p
	return best


func _standing(owned: Dictionary, worn: String, driven: String) -> int:
	var s := 0
	for id in owned:
		var it: Dictionary = BIENS.item(id)
		if it.kind in ["part", "maison"]:
			s += it.standing * owned[id]
	if worn != "":
		s += BIENS.item(worn).standing
	if driven != "":
		s += BIENS.item(driven).standing
	return s


func _charges(owned: Dictionary, worn: String, driven: String) -> int:
	var c := 0
	for id in owned:
		var it: Dictionary = BIENS.item(id)
		if it.kind in ["part", "maison"]:
			c += it.charge * owned[id]
	if worn != "":
		c += BIENS.item(worn).charge
	if driven != "":
		c += BIENS.item(driven).charge
	return c


func _rente(owned: Dictionary) -> int:
	var r := 0
	for id in owned:
		r += BIENS.item(id).rente * owned[id]
	return r


func _value(owned: Dictionary) -> int:
	var v := 0
	for id in owned:
		for n in owned[id]:
			v += int(round(_price(id, n) * BIENS.RESALE))
	return v


func _resale(id: String, owned: Dictionary) -> int:
	return int(round(_price(id, owned[id] - 1) * BIENS.RESALE))
