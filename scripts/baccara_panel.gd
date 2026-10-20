extends PanelContainer
## Punto banco, règles d'Addict : sabot de 8 jeux, tableau de tirage fixe. Joueur 1 contre 1,
## Banquier 1 contre 1 moins 5 % de commission, Égalité 8 contre 1 (une égalité rend Joueur et Banquier).

signal played(bet: int, payout: int)
signal closed
signal hand_started
signal card_dealt(who: String, card: Dictionary, hidden: bool)
## Pour la table 3D : les mises posées (clé -> montant), et le coup réglé (gain par case, points).
signal bets_changed(bets: Dictionary)
signal settled(wins: Dictionary, player: int, banker: int)

const BARRE := preload("res://scripts/jeux/barre.gd")
const REGLES := preload("res://scripts/jeux/regles.gd")

const CHIPS := [100, 500, 1000, 5000]
const SUITS := ["♠", "♥", "♦", "♣"]
const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "V", "D", "R"]

var title := "Baccara"
## Au Banco des salons particuliers, la Banque gagne sans commission.
var commission := true
var chip_index := 0
var shoe: Array = []
var bets := {"joueur": 0, "banquier": 0, "egalite": 0}
var busy := false
var _player_box: HBoxContainer
var _banker_box: HBoxContainer
var _info: Label
var _chip_label: Label
var _bet_buttons := {}
var _font: Font
## Assis à la table 3D : on mise sur le tapis, le panneau devient une barre basse.
var embedded := false
var table3d: Node
var _chip_row: HBoxContainer
var _total_label: Label


func _ready() -> void:
	_font = Polices.texte()
	if embedded:
		_build_bar()
		return
	custom_minimum_size = Vector2(820, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Color(0.96, 0.8, 0.45))
	v.add_child(t)
	var rule := Label.new()
	rule.text = "Joueur 1 contre 1  ·  Banquier 1 contre 1%s  ·  Égalité 8 contre 1" % (" moins 5 %" if commission else "")
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule.add_theme_font_size_override("font_size", 14)
	rule.add_theme_color_override("font_color", Color(0.7, 0.66, 0.6))
	v.add_child(rule)
	var hands := HBoxContainer.new()
	hands.alignment = BoxContainer.ALIGNMENT_CENTER
	hands.add_theme_constant_override("separation", 30)
	v.add_child(hands)
	_player_box = _hand(hands, "Joueur")
	_banker_box = _hand(hands, "Banquier")
	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 20)
	_info.text = "Posez vos plaques, puis demandez les cartes."
	v.add_child(_info)
	var bet_row := HBoxContainer.new()
	bet_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bet_row.add_theme_constant_override("separation", 10)
	v.add_child(bet_row)
	for k in ["joueur", "egalite", "banquier"]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(200, 50)
		b.pressed.connect(_place.bind(k))
		bet_row.add_child(b)
		_bet_buttons[k] = b
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	v.add_child(controls)
	var minus := Button.new()
	minus.text = "−"
	minus.pressed.connect(func(): _chip(-1))
	controls.add_child(minus)
	_chip_label = Label.new()
	_chip_label.custom_minimum_size = Vector2(130, 0)
	_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_child(_chip_label)
	var plus := Button.new()
	plus.text = "+"
	plus.pressed.connect(func(): _chip(1))
	controls.add_child(plus)
	var deal := Button.new()
	deal.text = "Les cartes  (Espace)"
	deal.pressed.connect(_deal)
	controls.add_child(deal)
	controls.add_child(REGLES.bouton(self, "baccara", false))
	var leave := Button.new()
	leave.text = "Quitter (Échap)"
	leave.pressed.connect(_leave)
	controls.add_child(leave)
	_chip(0)
	_refresh()


## La barre basse : plaques, mises sur le tapis, message du croupier, les cartes.
func _build_bar() -> void:
	BARRE.style(self)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	_info = BARRE.label("Misez sur le Joueur, la Banque ou l'Égalité en cliquant sur le tapis, puis demandez les cartes.", 18, BARRE.CREAM)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_override("font", BARRE.KIT.serif())
	v.add_child(_info)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	_chip_row = BARRE.chip_row(CHIPS, chip_index, _pick_chip)
	h.add_child(_chip_row)
	_chip_label = BARRE.label("", 15, BARRE.MUTED)
	_chip_label.custom_minimum_size = Vector2(120, 0)
	h.add_child(_chip_label)
	h.add_child(BARRE.separator())
	_total_label = BARRE.label("Sur le tapis : 0", 16, BARRE.CREAM)
	_total_label.custom_minimum_size = Vector2(170, 0)
	h.add_child(_total_label)
	var clear := BARRE.pill("Retirer")
	clear.pressed.connect(_clear)
	h.add_child(clear)
	var deal := BARRE.main_button("  Les cartes  (Espace)  ")
	deal.pressed.connect(_deal)
	h.add_child(deal)
	h.add_child(REGLES.bouton(self, "baccara"))
	var leave := BARRE.pill("Quitter  (Échap)")
	leave.pressed.connect(_leave)
	h.add_child(leave)
	_chip(0)


func _pick_chip(i: int) -> void:
	chip_index = i
	_chip(0)


## Les plaques reviennent au joueur (bouton Retirer, ou en quittant la table).
func _clear() -> void:
	if busy:
		return
	for k in bets:
		Game.credits += bets[k]
		Game.staked -= bets[k]
		bets[k] = 0
	Game.changed.emit()
	_refresh()


func _leave() -> void:
	if busy:
		return
	_clear()
	closed.emit()


func _hand(parent: Control, who: String) -> HBoxContainer:
	var v := VBoxContainer.new()
	parent.add_child(v)
	var l := Label.new()
	l.text = who
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(l)
	var felt := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.18, 0.04, 0.06) if who == "Banquier" else Color(0.04, 0.08, 0.22)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	felt.add_theme_stylebox_override("panel", sb)
	felt.custom_minimum_size = Vector2(330, 130)
	v.add_child(felt)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	felt.add_child(h)
	return h


func _chip(d: int) -> void:
	chip_index = clampi(chip_index + d, 0, CHIPS.size() - 1)
	_chip_label.text = "Plaque : %s" % Game.fmt(CHIPS[chip_index])
	if _chip_row:
		BARRE.select(_chip_row, chip_index)


func _place(key: String) -> void:
	if busy:
		return
	if not Game.spend(CHIPS[chip_index]):
		_info.text = "Pas assez de crédits pour cette plaque."
		return
	bets[key] += CHIPS[chip_index]
	_refresh()


func _refresh() -> void:
	var names := {"joueur": "Joueur", "banquier": "Banquier", "egalite": "Égalité"}
	for k in _bet_buttons:
		_bet_buttons[k].text = "%s%s" % [names[k], ("  ·  %s" % Game.fmt(bets[k])) if bets[k] > 0 else ""]
	if embedded:
		_total_label.text = "Sur le tapis : %s" % Game.fmt(bets.joueur + bets.banquier + bets.egalite)
		bets_changed.emit(bets.duplicate())


func _card() -> Dictionary:
	Sfx.play("card", -6.0)
	if shoe.size() < 14:
		shoe.clear()
		for d in 8:
			for s in 4:
				for r in 13:
					shoe.append({"r": r, "s": s})
		shoe.shuffle()
	return shoe.pop_back()


static func value(hand: Array) -> int:
	var t := 0
	for c in hand:
		t += 0 if c.r >= 9 else c.r + 1
	return t % 10


## Le tableau de tirage classique du punto banco.
static func banker_draws(b: int, third: int) -> bool:
	if third < 0:
		return b <= 5
	match b:
		0, 1, 2: return true
		3: return third != 8
		4: return third >= 2 and third <= 7
		5: return third >= 4 and third <= 7
		6: return third == 6 or third == 7
	return false


func _deal() -> void:
	var total: int = bets.joueur + bets.banquier + bets.egalite
	if busy or total == 0:
		if total == 0:
			_info.text = "Posez d'abord une plaque."
		return
	busy = true
	var p := [_card(), _card()]
	var b := [_card(), _card()]
	var third := -1
	if value(p) < 8 and value(b) < 8:
		if value(p) <= 5:
			var c := _card()
			p.append(c)
			third = 0 if c.r >= 9 else c.r + 1
		if banker_draws(value(b), third):
			b.append(_card())
	hand_started.emit()
	if embedded:
		# Sur la table, les cartes sortent dans l'ordre du jeu : Joueur, Banque, Joueur, Banque, puis
		# les troisièmes cartes. Le coup se règle quand le croupier a tout retourné.
		_info.text = "Les cartes."
		for i in 2:
			card_dealt.emit("player", p[i], true)
			card_dealt.emit("dealer", b[i], true)
		if p.size() > 2:
			card_dealt.emit("player", p[2], false)
		if b.size() > 2:
			card_dealt.emit("dealer", b[2], false)
		await get_tree().create_timer(table3d.busy_time() + 0.2 if table3d else 2.0).timeout
	else:
		_show(_player_box, p)
		_show(_banker_box, b)
		for c in p:
			card_dealt.emit("player", c, false)
		for c in b:
			card_dealt.emit("dealer", c, false)
	var pv := value(p)
	var bv := value(b)
	var wins := {}
	var msg := ""
	if pv > bv:
		wins.joueur = bets.joueur * 2
		msg = "Le Joueur gagne, %d à %d." % [pv, bv]
	elif bv > pv:
		wins.banquier = bets.banquier * 2 - (int(round(bets.banquier * 0.05)) if commission else 0)
		msg = "La Banque gagne, %d à %d." % [bv, pv]
	else:
		wins = {"joueur": bets.joueur, "banquier": bets.banquier, "egalite": bets.egalite * 9}
		msg = "Égalité à %d." % pv
	var payout := 0
	for k in wins:
		payout += wins[k]
	settled.emit(wins, pv, bv)
	if payout > 0:
		msg += " Vous encaissez %s." % Game.fmt(payout)
	else:
		msg += " Un placement de long terme."
	_info.text = msg
	for k in bets:
		bets[k] = 0
	_refresh()
	busy = false
	played.emit(total, payout)


func _show(box: HBoxContainer, hand: Array) -> void:
	for c in box.get_children():
		c.queue_free()
	for c in hand:
		var p := PanelContainer.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.98, 0.96, 0.9)
		sb.border_color = Color(0.85, 0.7, 0.4)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(6)
		p.add_theme_stylebox_override("panel", sb)
		p.custom_minimum_size = Vector2(72, 104)
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_font_override("font", _font)
		l.add_theme_font_size_override("font_size", 30)
		l.text = "%s\n%s" % [RANKS[c.r], SUITS[c.s]]
		l.add_theme_color_override("font_color", Color(0.75, 0.05, 0.1) if c.s in [1, 2] else Color(0.08, 0.08, 0.1))
		p.add_child(l)
		box.add_child(p)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_deal()
		get_viewport().set_input_as_handled()
	elif embedded and event is InputEventKey and event.pressed and event.keycode >= KEY_1 and event.keycode < KEY_1 + CHIPS.size():
		chip_index = event.keycode - KEY_1
		_chip(0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_leave()
		get_viewport().set_input_as_handled()
