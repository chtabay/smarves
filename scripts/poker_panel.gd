extends PanelContainer
## Le poker des Ambassadeurs, d'après Addict : Texas Hold'em sans limite, blindes 25/50, six places,
## 2 000 au plus engagés par donne pour chacun, la maison prend 5 % du pot après le flop (100 au plus).
## Une commune peut donner d'autres tarifs à sa table (socle 1.7) : configurer_blindes(), avant que le
## panneau entre dans la scène ; il faut au moins la grosse blinde pour s'asseoir.
## Les habitués ont chacun leur manière : le Commandant serré et agressif, Mme Duval paie pour voir,
## Teddy relance tout, la comtesse Orlov est patiente, Maître Garnier calcule.

signal played(bet: int, payout: int)
signal closed
## Pour la table 3D : la donne distribuée, une rue retournée, les mises ramassées au pot, l'abattage.
signal hand_started
signal board_dealt(cards: Array)
signal street_ended
signal showdown(winners: Array, show_all: bool, amount: int)
signal changed

const BARRE := preload("res://scripts/jeux/barre.gd")
const REGLES := preload("res://scripts/jeux/regles.gd")

## Les tarifs de la table : les Ambassadeurs par défaut, ceux d'une commune par configurer_blindes().
var SB := 25
var BB := 50
var CAP := 2000
const SUITS := ["♠", "♥", "♦", "♣"]
const RANKS := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "V", "D", "R", "A"]
const CATEGORIES := ["Hauteur", "Paire", "Deux paires", "Brelan", "Quinte", "Couleur", "Full", "Carré", "Quinte flush"]

var title := "Poker des Ambassadeurs"
## [nom, serrage (0 lâche, 1 serré), agressivité (0 passif, 1 agressif)]
var regulars := [["le Commandant", 0.75, 0.8], ["Mme Duval", 0.1, 0.15], ["Teddy", 0.2, 0.9], ["la comtesse Orlov", 0.6, 0.35], ["Maître Garnier", 0.5, 0.55]]

var seats: Array = []          # dictionnaires : name, ai, stack, cards, bet, folded, acted, style
var board: Array = []
var deck: Array = []
var pot := 0
var street := 0               # 0 préflop, 1 flop, 2 turn, 3 river
var current_bet := 0
var dealer := 0
var player_in := 0            # ce que le joueur a engagé dans la donne
var in_hand := false
var _waiting_player := false
var _rows: Array[Label] = []
var _board_label: Label
var _pot_label: Label
var _hand_label: Label
var _log: Label
var _buttons := {}
var _raise_to := BB * 2
var _raise_label: Label
var _font: Font
## Assis à la table 3D : la table montre les cartes et les plaques, le panneau devient une barre basse.
var embedded := false
var table3d: Node
## La place qui doit parler (-1 : personne).
var turn := -1
var _info: Label
## Le rappel des cartes, en petit sous le récit, à côté du pot : sa main et le tableau.
var _rappel: HBoxContainer
var _rappel_cle := ""
## La dernière donne finie, pour le rappel qui reste après elle : les gagnants, et si les mains ont été
## montrées. Vide tant qu'aucune donne n'est finie.
var dernier_abattage := {}


func _ready() -> void:
	_font = Polices.texte()
	seats.append({"name": "Vous", "ai": false})
	for r in regulars:
		seats.append({"name": r[0], "ai": true, "tight": r[1], "aggr": r[2], "stack": 5000})
	showdown.connect(_noter_abattage)
	if embedded:
		_build_bar()
	else:
		_build_panel()
	_log.text = "%s vous salue d'un signe de tête. Une donne ?" % (regulars[0][0].substr(0, 1).to_upper() + regulars[0][0].substr(1))
	_render()


func _build_panel() -> void:
	custom_minimum_size = Vector2(900, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Color(0.96, 0.8, 0.45))
	v.add_child(t)
	var rule := Label.new()
	rule.text = "Texas Hold'em sans limite  ·  blindes %s/%s  ·  %s au plus par donne  ·  5 %% de la maison après le flop" % [Game.fmt(SB), Game.fmt(BB), Game.fmt(CAP)]
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule.add_theme_font_size_override("font_size", 14)
	rule.add_theme_color_override("font_color", Color(0.72, 0.68, 0.62))
	v.add_child(rule)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	v.add_child(grid)
	for s in seats:
		var l := Label.new()
		l.add_theme_font_override("font", _font)
		l.add_theme_font_size_override("font_size", 17)
		l.custom_minimum_size = Vector2(430, 0)
		grid.add_child(l)
		_rows.append(l)
	_board_label = Label.new()
	_board_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_board_label.add_theme_font_override("font", _font)
	_board_label.add_theme_font_size_override("font_size", 40)
	v.add_child(_board_label)
	_pot_label = Label.new()
	_pot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pot_label.add_theme_font_size_override("font_size", 20)
	v.add_child(_pot_label)
	_hand_label = Label.new()
	_hand_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hand_label.add_theme_font_override("font", _font)
	_hand_label.add_theme_font_size_override("font_size", 30)
	v.add_child(_hand_label)
	_log = Label.new()
	_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.custom_minimum_size = Vector2(860, 50)
	_log.add_theme_font_size_override("font_size", 17)
	v.add_child(_log)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 8)
	v.add_child(controls)
	_buttons["deal"] = _button(controls, "Nouvelle donne", _new_hand)
	_buttons["fold"] = _button(controls, "Se coucher", _on_fold)
	_buttons["call"] = _button(controls, "Suivre", _on_call)
	_buttons["less"] = _button(controls, "−", func(): _adjust_raise(-1))
	_raise_label = Label.new()
	_raise_label.custom_minimum_size = Vector2(140, 0)
	_raise_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_child(_raise_label)
	_buttons["more"] = _button(controls, "+", func(): _adjust_raise(1))
	_buttons["raise"] = _button(controls, "Relancer", _on_raise)
	controls.add_child(REGLES.bouton(self, "poker", false))
	_button(controls, "Quitter (Échap)", _leave)


## La barre basse : ce qui vient de se passer, le pot et la main, puis les actions.
## Les tarifs d'une table de commune (socle 1.7) : petite et grosse blinde, plafond engagé par donne.
## À appeler avant que le panneau entre dans la scène. Rend false, sans rien changer, pour des tarifs
## incohérents (une blinde nulle, la petite plus grosse que la grosse, un plafond sous la grosse).
func configurer_blindes(petite: int, grosse: int, plafond: int) -> bool:
	if petite <= 0 or grosse < petite or plafond < grosse:
		push_warning("Poker : tarifs refusés (%d/%d, plafond %d)." % [petite, grosse, plafond])
		return false
	SB = petite
	BB = grosse
	CAP = plafond
	_raise_to = BB * 2
	return true


func _build_bar() -> void:
	BARRE.style(self)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	_log = BARRE.label("", 20, BARRE.CREAM)
	_log.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_log.add_theme_font_override("font", BARRE.KIT.serif())
	v.add_child(_log)
	# Les cartes et le pot sur une seule ligne, côte à côte : la barre reste aussi basse qu'avant le
	# rappel et laisse voir les cartes posées sur la table.
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 22)
	ligne.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(ligne)
	_rappel = HBoxContainer.new()
	_rappel.add_theme_constant_override("separation", 4)
	ligne.add_child(_rappel)
	_info = BARRE.label("", 20, BARRE.MUTED)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ligne.add_child(_info)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	_buttons["deal"] = BARRE.main_button("  Nouvelle donne  (Espace)  ")
	_buttons["deal"].pressed.connect(_new_hand)
	h.add_child(_buttons["deal"])
	for k in [["fold", "Se coucher", _on_fold], ["call", "Suivre", _on_call], ["less", "  −  ", func(): _adjust_raise(-1)]]:
		_buttons[k[0]] = BARRE.pill(k[1])
		_buttons[k[0]].pressed.connect(k[2])
		h.add_child(_buttons[k[0]])
	_raise_label = BARRE.label("", 20, BARRE.CREAM)
	_raise_label.custom_minimum_size = Vector2(150, 0)
	_raise_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(_raise_label)
	for k in [["more", "  +  ", func(): _adjust_raise(1)], ["raise", "Relancer", _on_raise]]:
		_buttons[k[0]] = BARRE.pill(k[1])
		_buttons[k[0]].pressed.connect(k[2])
		h.add_child(_buttons[k[0]])
	h.add_child(BARRE.separator())
	# Se pencher sur la table : le tableau et les mains montrées, de près.
	_buttons["vue"] = BARRE.pill("Vue  (V)")
	_buttons["vue"].focus_mode = Control.FOCUS_NONE
	_buttons["vue"].pressed.connect(_basculer_vue)
	h.add_child(_buttons["vue"])
	h.add_child(REGLES.bouton(self, "poker"))
	var leave := BARRE.pill("Quitter  (Échap)")
	leave.pressed.connect(_leave)
	h.add_child(leave)


## Laisse la table finir ses gestes (cartes qui glissent, plaques ramassées).
func _wait_table() -> void:
	if table3d:
		await get_tree().create_timer(table3d.busy_time() + 0.1).timeout


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# --- Cartes et évaluation -----------------------------------------------------------------

func _card_text(c: Dictionary) -> String:
	return RANKS[c.r] + SUITS[c.s]


## Rang comparable d'une main de 5 à 7 cartes : [catégorie, départages…].
static func evaluate(cards: Array) -> Array:
	var counts := {}
	var suits := {}
	for c in cards:
		counts[c.r] = counts.get(c.r, 0) + 1
		if not suits.has(c.s):
			suits[c.s] = []
		suits[c.s].append(c.r)
	var flush_suit := -1
	for s in suits:
		if suits[s].size() >= 5:
			flush_suit = s
	if flush_suit >= 0:
		var sf := _straight_high(suits[flush_suit])
		if sf >= 0:
			return [8, sf]
	var groups := []
	for r in counts:
		groups.append([counts[r], r])
	groups.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] > b[1]))
	if groups[0][0] == 4:
		return [7, groups[0][1], _kickers(counts, [groups[0][1]], 1)[0]]
	if groups[0][0] == 3 and groups.size() > 1 and groups[1][0] >= 2:
		return [6, groups[0][1], groups[1][1]]
	if flush_suit >= 0:
		var f: Array = suits[flush_suit].duplicate()
		f.sort()
		f.reverse()
		return [5] + f.slice(0, 5)
	var st := _straight_high(counts.keys())
	if st >= 0:
		return [4, st]
	if groups[0][0] == 3:
		return [3, groups[0][1]] + _kickers(counts, [groups[0][1]], 2)
	if groups[0][0] == 2 and groups.size() > 1 and groups[1][0] == 2:
		return [2, groups[0][1], groups[1][1]] + _kickers(counts, [groups[0][1], groups[1][1]], 1)
	if groups[0][0] == 2:
		return [1, groups[0][1]] + _kickers(counts, [groups[0][1]], 3)
	return [0] + _kickers(counts, [], 5)


static func _kickers(counts: Dictionary, exclude: Array, n: int) -> Array:
	var ks := []
	for r in counts:
		if not (r in exclude):
			ks.append(r)
	ks.sort()
	ks.reverse()
	return ks.slice(0, n)


static func _straight_high(ranks: Array) -> int:
	var present := {}
	for r in ranks:
		present[r] = true
	for high in range(12, 3, -1):
		var ok := true
		for k in 5:
			if not present.has(high - k):
				ok = false
				break
		if ok:
			return high
	if present.has(12) and present.has(0) and present.has(1) and present.has(2) and present.has(3):
		return 3
	return -1


static func compare(a: Array, b: Array) -> int:
	for i in mini(a.size(), b.size()):
		if a[i] != b[i]:
			return 1 if a[i] > b[i] else -1
	return 0


## Les noms des valeurs, au singulier et au pluriel, pour dire une main en entier.
const NOMS := ["deux", "trois", "quatre", "cinq", "six", "sept", "huit", "neuf", "dix", "valet", "dame", "roi", "as"]
const NOMS_PL := ["deux", "trois", "quatre", "cinq", "six", "sept", "huit", "neuf", "dix", "valets", "dames", "rois", "as"]


static func _de(r: int) -> String:
	return "d'as" if r == 12 else "de " + NOMS_PL[r]


static func _au(r: int) -> String:
	return {12: "à l'as", 10: "à la dame"}.get(r, "au " + NOMS[r])


## Une main évaluée, dite en entier : « paire de rois », « deux paires, valets et neuf », « full aux dames
## par les huit ». Avec l'article (« une paire de rois ») pour finir une phrase : « … remporte 300 avec ».
static func nommer(e: Array, article := false) -> String:
	if e.is_empty():
		return ""
	var r: int = e[1] if e.size() > 1 else 0
	var nom: String = [
		"hauteur " + NOMS[r],
		"paire " + _de(r),
		"deux paires, %s et %s" % [NOMS_PL[r], NOMS_PL[e[2]] if e.size() > 2 else ""],
		"brelan " + _de(r),
		"quinte " + _au(r),
		"couleur " + _au(r),
		"full aux %s par les %s" % [NOMS_PL[r], NOMS_PL[e[2]] if e.size() > 2 else ""],
		"carré " + _de(r),
		"quinte flush royale" if r == 12 else "quinte flush " + _au(r),
	][e[0]]
	if not article or e[0] in [0, 2]:
		return nom
	return ("une " if e[0] in [1, 4, 5, 8] else "un ") + nom


## Les cinq cartes qui font la meilleure main parmi cinq à sept : celles que le rappel fait briller.
static func meilleures_cinq(cards: Array) -> Array:
	if cards.size() <= 5:
		return cards.duplicate()
	var best: Array = []
	var best_e: Array = []
	var n := cards.size()
	for m in 1 << n:
		var cinq: Array = []
		for k in n:
			if m & (1 << k):
				cinq.append(cards[k])
		if cinq.size() != 5:
			continue
		var e := evaluate(cinq)
		if best_e.is_empty() or compare(e, best_e) > 0:
			best_e = e
			best = cinq
	return best


## Force estimée d'une main par tirages au hasard contre les adversaires encore en jeu.
func _strength(hole: Array, opponents: int) -> float:
	var known := hole + board
	var wins := 0.0
	var trials := 60
	for t in trials:
		var pool: Array = []
		for s in 4:
			for r in 13:
				var c := {"r": r, "s": s}
				var used := false
				for k in known:
					if k.r == r and k.s == s:
						used = true
						break
				if not used:
					pool.append(c)
		pool.shuffle()
		var full_board: Array = board + pool.slice(0, 5 - board.size())
		var idx := 5 - board.size()
		var mine := evaluate(hole + full_board)
		var best := 1
		for o in opponents:
			var theirs := evaluate([pool[idx], pool[idx + 1]] + full_board)
			idx += 2
			var cmp := compare(mine, theirs)
			if cmp < 0:
				best = -1
				break
			elif cmp == 0:
				best = 0
		wins += 1.0 if best == 1 else (0.5 if best == 0 else 0.0)
	return wins / trials


# --- Déroulement d'une donne ---------------------------------------------------------------

func _new_hand() -> void:
	if in_hand:
		return
	if Game.credits < BB:
		_log.text = "Il faut au moins %d crédits pour s'asseoir." % BB
		return
	in_hand = true
	deck.clear()
	for s in 4:
		for r in 13:
			deck.append({"r": r, "s": s})
	deck.shuffle()
	Sfx.play("shuffle", -6.0)
	board.clear()
	pot = 0
	street = 0
	player_in = 0
	dealer = (dealer + 1) % seats.size()
	for s in seats:
		s.cards = [deck.pop_back(), deck.pop_back()]
		s.bet = 0
		s.folded = false
		s.acted = false
		s.engage = 0
		if s.ai and s.stack < 1000:
			s.stack = 5000  # un habitué n'arrive jamais à court : il « réinvestit »
	_post((dealer + 1) % seats.size(), SB)
	_post((dealer + 2) % seats.size(), BB)
	current_bet = BB
	_raise_to = BB * 2
	_log.text = "Nouvelle donne. Blindes %d et %d." % [SB, BB]
	hand_started.emit()
	_render()
	await _wait_table()
	await _betting_round((dealer + 3) % seats.size())


func _post(i: int, amount: int) -> int:
	var s: Dictionary = seats[i]
	var pay := amount
	if not s.ai:
		pay = mini(amount, mini(Game.credits, CAP - player_in))
		if pay > 0 and not Game.spend(pay):
			pay = 0
		player_in += pay
	else:
		# Un habitué non plus ne met jamais plus que le plafond dans une donne (comme au serveur).
		pay = mini(amount, mini(s.stack, CAP - int(s.get("engage", 0))))
		s.stack -= pay
		s.engage = int(s.get("engage", 0)) + pay
	s.bet += pay
	pot += pay
	return pay


func _active() -> Array:
	var a := []
	for i in seats.size():
		if not seats[i].folded:
			a.append(i)
	return a


func _betting_round(start: int) -> void:
	for s in seats:
		s.acted = false
	var i := start
	var guard := 0
	while guard < 60:
		guard += 1
		if _active().size() <= 1:
			break
		var s: Dictionary = seats[i]
		var done := true
		for k in _active():
			var o: Dictionary = seats[k]
			if not o.acted or (o.bet < current_bet and not _all_in(k)):
				done = false
		if done:
			break
		if not s.folded and not (s.acted and s.bet >= current_bet) and not _all_in(i):
			turn = i
			if s.ai:
				_render()
				await get_tree().create_timer(0.45).timeout
				_ai_act(i)
			else:
				_waiting_player = true
				_render()
				while _waiting_player:
					await get_tree().process_frame
			s.acted = true
			turn = -1
			_render()
		i = (i + 1) % seats.size()
	await _next_street()


func _all_in(i: int) -> bool:
	var s: Dictionary = seats[i]
	if s.ai:
		return s.stack <= 0 or int(s.get("engage", 0)) >= CAP
	return player_in >= CAP or Game.credits <= 0


func _ai_act(i: int) -> void:
	var s: Dictionary = seats[i]
	var to_call: int = current_bet - s.bet
	var strength := _strength(s.cards, _active().size() - 1)
	var need: float = 0.25 + s.tight * 0.3 - (0.0 if street == 0 else 0.05)
	var pot_odds: float = float(to_call) / float(pot + to_call) if to_call > 0 else 0.0
	if to_call > 0 and strength < need and strength < pot_odds + 0.1 and randf() > (1.0 - s.tight) * 0.4:
		s.folded = true
		_log.text = "%s se couche." % s.name
		return
	if strength > need + 0.15 and randf() < s.aggr:
		var target: int = current_bet + maxi(BB, int(pot * (0.5 + s.aggr * 0.5) / float(SB)) * SB)
		var pay := _post(i, target - s.bet)
		if s.bet > current_bet:
			current_bet = s.bet
			for k in _active():
				if k != i:
					seats[k].acted = false
			_log.text = "%s relance à %d." % [s.name, current_bet]
		else:
			_log.text = "%s suit (%d)." % [s.name, pay]
		return
	if to_call > 0:
		_post(i, to_call)
		_log.text = "%s suit." % s.name
	else:
		_log.text = "%s parle." % s.name


func _next_street() -> void:
	street_ended.emit()
	for s in seats:
		s.bet = 0
	current_bet = 0
	_raise_to = BB
	if _active().size() > 1 and street < 3:
		if street == 0:
			board += [deck.pop_back(), deck.pop_back(), deck.pop_back()]
		else:
			board.append(deck.pop_back())
		street += 1
		board_dealt.emit(board.slice(board.size() - (3 if street == 1 else 1)))
		_render()
		await get_tree().create_timer(0.5).timeout
		await _wait_table()
		await _betting_round((dealer + 1) % seats.size())
		return
	_showdown()


func _showdown() -> void:
	var active := _active()
	var rake := 0
	if street >= 1:
		rake = mini(100, int(pot * 0.05))
	var net_pot := pot - rake
	var winners: Array = []
	var best: Array = []
	if active.size() == 1:
		winners = active
	else:
		for i in active:
			var e := evaluate(seats[i].cards + board)
			var cmp := compare(e, best) if best.size() > 0 else 1
			if cmp > 0:
				best = e
				winners = [i]
			elif cmp == 0:
				winners.append(i)
	var share := net_pot / winners.size()
	var payout := 0
	var names: Array[String] = []
	for w in winners:
		names.append(seats[w].name)
		if seats[w].ai:
			seats[w].stack += share
		else:
			payout += share
	var how := "" if best.is_empty() else " avec %s" % nommer(best, true)
	# Les mains montrées : celles des gagnants, dites en clair, pour savoir ce qui a battu la sienne.
	if active.size() > 1 and not (0 in winners):
		how += " (%s)" % " · ".join(winners.map(func(w): return "%s %s" % [_card_text(seats[w].cards[0]), _card_text(seats[w].cards[1])]))
	var verb := "remportent" if winners.size() > 1 else ("remportez" if winners == [0] else "remporte")
	var who := " et ".join(names)
	_log.text = "%s %s %s%s.%s" % [who.substr(0, 1).to_upper() + who.substr(1), verb, Game.fmt(net_pot), how,
		(" La maison prend %d." % rake) if rake > 0 else ""]
	in_hand = false
	showdown.emit(winners, active.size() > 1, net_pot)
	_render(true)
	played.emit(player_in, payout)


# --- Actions du joueur ----------------------------------------------------------------------

func _on_fold() -> void:
	if not _waiting_player:
		return
	seats[0].folded = true
	_log.text = "Vous vous couchez."
	_waiting_player = false


func _on_call() -> void:
	if not _waiting_player:
		return
	var to_call: int = current_bet - seats[0].bet
	if to_call > 0:
		_post(0, to_call)
		_log.text = "Vous suivez."
	else:
		_log.text = "Vous parlez."
	_waiting_player = false


func _adjust_raise(d: int) -> void:
	_raise_to = clampi(_raise_to + d * BB, current_bet + BB, current_bet + CAP)
	_render()


func _on_raise() -> void:
	if not _waiting_player:
		return
	var target: int = maxi(_raise_to, current_bet + BB)
	var paid := _post(0, target - seats[0].bet)
	if seats[0].bet > current_bet:
		current_bet = seats[0].bet
		for k in _active():
			if k != 0:
				seats[k].acted = false
		_log.text = "Vous relancez à %d." % current_bet
	elif paid > 0:
		_log.text = "Vous suivez."
	_waiting_player = false


func _leave() -> void:
	if in_hand:
		_log.text = "Finissez d'abord la donne (ou couchez-vous)."
		return
	closed.emit()


func _render(show_all := false) -> void:
	if embedded:
		_render_bar()
		changed.emit()
		return
	for i in seats.size():
		var s: Dictionary = seats[i]
		var cards := "· ·"
		if s.has("cards") and (not s.ai or (show_all and not s.folded)):
			cards = "%s %s" % [_card_text(s.cards[0]), _card_text(s.cards[1])]
		var stack := Game.fmt(Game.credits) if not s.ai else Game.fmt(s.stack)
		var state := "couché" if s.get("folded", false) else ("mise %d" % s.get("bet", 0) if s.get("bet", 0) > 0 else "")
		_rows[i].text = "%s%s  —  %s   %s   %s" % ["▶ " if i == dealer else "   ", s.name, cards, stack, state]
		_rows[i].add_theme_color_override("font_color", Color(1, 0.88, 0.55) if not s.ai else (Color(0.5, 0.5, 0.55) if s.get("folded", false) else Color(0.88, 0.85, 0.8)))
	var b: Array[String] = []
	for c in board:
		b.append(_card_text(c))
	_board_label.text = "  ".join(b) if b.size() > 0 else "· · · · ·"
	_pot_label.text = "Pot : %s   ·   à suivre : %d" % [Game.fmt(pot), maxi(0, current_bet - seats[0].get("bet", 0))]
	if seats[0].has("cards") and in_hand:
		var e := evaluate(seats[0].cards + board) if board.size() >= 3 else []
		_hand_label.text = "Vos cartes : %s %s%s" % [_card_text(seats[0].cards[0]), _card_text(seats[0].cards[1]), ("   (" + CATEGORIES[e[0]] + ")") if e.size() > 0 else ""]
	_raise_label.text = "Relance à %d" % _raise_to
	var acting := _waiting_player and in_hand
	_buttons["deal"].disabled = in_hand
	for k in ["fold", "call", "raise", "less", "more"]:
		_buttons[k].disabled = not acting
	_buttons["call"].text = "Suivre %d" % (current_bet - seats[0].get("bet", 0)) if current_bet > seats[0].get("bet", 0) else "Parler"


## Les couleurs du jeu de cartes : pique et trèfle noirs, cœur et carreau rouges.
const COULEURS_ENSEIGNES := [Color(0.1, 0.1, 0.12), Color(0.78, 0.1, 0.13), Color(0.78, 0.1, 0.13), Color(0.1, 0.1, 0.12)]


## Ses deux cartes pour le rappel, ou rien : pas de donne, ou couché.
func mes_cartes() -> Array:
	if not in_hand or seats[0].get("folded", false) or not seats[0].has("cards"):
		return []
	return seats[0].cards


## Ce que la table 3D a déjà posé : le rappel ne montre pas une carte avant qu'elle soit sur le tapis.
## Sans table (le panneau au milieu de l'écran), tout ce qui est donné.
func _posees() -> Dictionary:
	if table3d and is_instance_valid(table3d) and table3d.has_method("cartes_posees"):
		return table3d.cartes_posees()
	return {"main": 2, "tableau": 5}


## Sa main telle qu'on la voit sur la table.
func main_visible() -> Array:
	return mes_cartes().slice(0, int(_posees().main))


## Le tableau tel qu'on le voit sur la table.
func tableau_visible() -> Array:
	return board.slice(0, int(_posees().tableau))


## Ce que sa main vaut avec le tableau posé (« paire de rois »), ou rien avant le flop.
func ma_main_nommee() -> String:
	var main := main_visible()
	var tableau := tableau_visible()
	if main.size() < 2 or tableau.size() < 3:
		return ""
	return nommer(evaluate(main + tableau))


func _noter_abattage(winners: Array, show_all: bool, _amount: int) -> void:
	dernier_abattage = {"winners": winners.duplicate(), "show": show_all}
	if embedded:
		_render_rappel()


static func _cle_carte(c: Dictionary) -> String:
	return "%d-%d" % [int(c.r), int(c.s)]


## Le rappel : « Main » et ses deux cartes, « Table » et les cinq places du tableau (vides tant qu'elles
## ne sont pas posées sur le tapis). Les cartes qui font la main brillent, les autres s'effacent un peu.
## La donne finie, il reste : la main du gagnant, la sienne, et le tableau. Rebâti seulement quand les
## cartes changent.
func _render_rappel() -> void:
	if _rappel == null:
		return
	var main := main_visible()
	var tableau := tableau_visible()
	var fin := not in_hand and not dernier_abattage.is_empty()
	var cle := "%s|%s|%s|%s|%s" % [in_hand, main, tableau, fin, dernier_abattage if fin else {}]
	if fin:
		cle += "|%s|%s" % [board, seats.map(func(x): return [x.get("cards", []), x.get("folded", false)])]
	if cle == _rappel_cle:
		return
	_rappel_cle = cle
	for c in _rappel.get_children():
		c.queue_free()
	if fin:
		_rappel_abattage()
		return
	_rappel.visible = not main.is_empty() or not tableau.is_empty()
	if not _rappel.visible:
		return
	var brille := {}
	if main.size() == 2 and tableau.size() >= 3:
		for c in meilleures_cinq(main + tableau):
			brille[_cle_carte(c)] = true
	if not main.is_empty():
		_rappel_main("Main", main, brille)
	_rappel_main("Table", tableau, brille, 5)


## Une main du rappel : son nom, puis ses cartes (et des places vides jusqu'à « places »).
func _rappel_main(nom: String, cards: Array, brille: Dictionary, places := 0) -> void:
	if _rappel.get_child_count() > 0:
		var ecart := Control.new()
		ecart.custom_minimum_size = Vector2(18, 0)
		_rappel.add_child(ecart)
	_rappel.add_child(BARRE.label(nom + " ", 20, BARRE.MUTED))
	for i in maxi(places, cards.size()):
		var c: Dictionary = cards[i] if i < cards.size() else {}
		_rappel.add_child(_mini_carte(c, 1 if c.is_empty() or brille.is_empty() else (2 if brille.has(_cle_carte(c)) else 0)))


## Après la donne : la main du gagnant (ou des gagnants), la sienne si elle est allée jusqu'au bout, et
## le tableau, les cinq cartes gagnantes en lumière. Sans abattage (tout le monde s'est couché), le
## tableau seul.
func _rappel_abattage() -> void:
	var winners: Array = dernier_abattage.get("winners", [])
	var montre: bool = dernier_abattage.get("show", false)
	_rappel.visible = montre or not board.is_empty()
	if not _rappel.visible:
		return
	var brille := {}
	if montre and not winners.is_empty() and board.size() >= 3:
		for c in meilleures_cinq(seats[winners[0]].get("cards", []) + board):
			brille[_cle_carte(c)] = true
	if montre:
		for w in winners.slice(0, 2):
			var nom: String = "Vous" if w == 0 else str(seats[w].name)
			_rappel_main(nom.substr(0, 1).to_upper() + nom.substr(1), seats[w].get("cards", []), brille)
		if not (0 in winners) and not seats[0].get("folded", false) and seats[0].has("cards") and seats[0].cards.size() == 2:
			_rappel_main("Vous", seats[0].cards, brille)
	_rappel_main("Table", board, brille, 5)


## Une petite carte : fond ivoire, la valeur et l'enseigne à la couleur de l'enseigne ; vide, un simple
## cadre doré. « eclat » : 0 effacée (hors de la main), 1 ordinaire, 2 dans la main (cadre d'or).
func _mini_carte(c: Dictionary, eclat := 1) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(5)
	sb.set_border_width_all(2 if eclat == 2 else 1)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.anti_aliasing = true
	var l := Label.new()
	l.custom_minimum_size = Vector2(38, 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 23)
	if c.is_empty():
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = Color(BARRE.GOLD, 0.3)
	else:
		sb.bg_color = Color(0.97, 0.95, 0.9)
		sb.border_color = Color(BARRE.GOLD, 1.0) if eclat == 2 else Color(BARRE.GOLD, 0.6)
		l.text = _card_text(c)
		l.add_theme_color_override("font_color", COULEURS_ENSEIGNES[int(c.s)])
		if eclat == 0:
			p.modulate = Color(1, 1, 1, 0.5)
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(l)
	return p


## Se pencher sur la table, ou se rasseoir.
func _basculer_vue() -> void:
	if table3d and is_instance_valid(table3d) and table3d.has_method("basculer_vue"):
		table3d.basculer_vue()


func _render_bar() -> void:
	_render_rappel()
	var to_call: int = maxi(0, current_bet - seats[0].get("bet", 0))
	var parts: Array[String] = ["Pot : %s" % Game.fmt(pot)]
	if in_hand and not seats[0].get("folded", false):
		if ma_main_nommee() != "":
			parts.append("votre main : %s" % ma_main_nommee())
		parts.append("engagé : %s / %s" % [Game.fmt(player_in), Game.fmt(CAP)])
	_info.text = "   ·   ".join(parts)
	_raise_label.text = "Relance à %s" % Game.fmt(_raise_to)
	var acting := _waiting_player and in_hand
	_buttons["deal"].visible = not in_hand
	for k in ["fold", "call", "raise", "less", "more"]:
		_buttons[k].visible = in_hand
		_buttons[k].disabled = not acting
	_raise_label.visible = in_hand
	_buttons["call"].text = "Suivre %s" % Game.fmt(to_call) if to_call > 0 else "Parler"


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_leave()
		get_viewport().set_input_as_handled()
	elif embedded and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE and not in_hand:
		_new_hand()
		get_viewport().set_input_as_handled()
	elif embedded and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V:
		_basculer_vue()
		get_viewport().set_input_as_handled()
