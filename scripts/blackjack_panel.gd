extends PanelContainer
## Blackjack, règles d'Addict : sabot de 6 jeux, le croupier reste sur tout 17, blackjack payé 3 contre 2,
## doublement sur les deux premières cartes, ni partage ni assurance.

signal played(bet: int, payout: int)
signal closed
## Pour poser les cartes sur le feutre 3D : « player » ou « dealer », la carte, et si elle est face cachée.
signal card_dealt(who: String, card: Dictionary, hidden: bool)
signal hand_started
signal hole_revealed(card: Dictionary)

const BETS := [5, 10, 25, 100, 500]
const SUITS := ["♠", "♥", "♦", "♣"]
const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "V", "D", "R"]

var title := "Blackjack"
var bet_index := 1
var shoe: Array = []
var player: Array = []
var dealer: Array = []
var bet := 0
var in_hand := false
var _dealer_box: HBoxContainer
var _player_box: HBoxContainer
var _dealer_total: Label
var _player_total: Label
var _info: Label
var _bet_label: Label
var _deal: Button
var _hit: Button
var _stand: Button
var _double: Button
var _symbol_font: SystemFont


func _ready() -> void:
	_symbol_font = SystemFont.new()
	_symbol_font.font_names = PackedStringArray(["Georgia", "Segoe UI Symbol"])
	custom_minimum_size = Vector2(760, 0)
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
	rule.text = "Le blackjack paie 3 contre 2  ·  le croupier reste sur 17"
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule.add_theme_font_size_override("font_size", 14)
	rule.add_theme_color_override("font_color", Color(0.7, 0.66, 0.6))
	v.add_child(rule)

	_dealer_total = _row_label(v, "Croupier")
	_dealer_box = _hand_box(v)
	_player_total = _row_label(v, "Vous")
	_player_box = _hand_box(v)

	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 20)
	_info.text = "Choisissez votre mise et distribuez."
	v.add_child(_info)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	v.add_child(controls)
	var minus := Button.new()
	minus.text = "−"
	minus.pressed.connect(func(): _change_bet(-1))
	controls.add_child(minus)
	_bet_label = Label.new()
	_bet_label.custom_minimum_size = Vector2(110, 0)
	_bet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_child(_bet_label)
	var plus := Button.new()
	plus.text = "+"
	plus.pressed.connect(func(): _change_bet(1))
	controls.add_child(plus)
	_deal = _button(controls, "Distribuer", _start)
	_hit = _button(controls, "Carte", _on_hit)
	_stand = _button(controls, "Rester", _on_stand)
	_double = _button(controls, "Doubler", _on_double)
	_button(controls, "Quitter (Échap)", func(): closed.emit())
	_change_bet(0)
	_set_buttons()


func _row_label(v: VBoxContainer, who: String) -> Label:
	var l := Label.new()
	l.text = who
	l.add_theme_color_override("font_color", Color(0.85, 0.82, 0.75))
	v.add_child(l)
	return l


func _hand_box(v: VBoxContainer) -> HBoxContainer:
	var felt := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.3, 0.16)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	felt.add_theme_stylebox_override("panel", sb)
	felt.custom_minimum_size = Vector2(0, 130)
	v.add_child(felt)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	felt.add_child(h)
	return h


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _change_bet(d: int) -> void:
	if in_hand:
		return
	bet_index = clampi(bet_index + d, 0, BETS.size() - 1)
	_bet_label.text = "Mise : %d" % BETS[bet_index]


func _draw_card() -> Dictionary:
	Sfx.play("card", -6.0)
	if shoe.size() < 60:
		shoe.clear()
		for deck in 6:
			for s in 4:
				for r in 13:
					shoe.append({"r": r, "s": s})
		shoe.shuffle()
	return shoe.pop_back()


static func total(hand: Array) -> int:
	var t := 0
	var aces := 0
	for c in hand:
		var v: int = mini(c.r + 1, 10)
		if c.r == 0:
			aces += 1
			v = 11
		t += v
	while t > 21 and aces > 0:
		t -= 10
		aces -= 1
	return t


func _start() -> void:
	if in_hand:
		return
	var amount: int = BETS[bet_index]
	if not Game.spend(amount):
		_info.text = "Pas assez de crédits pour cette mise."
		return
	bet = amount
	in_hand = true
	player = [_draw_card(), _draw_card()]
	dealer = [_draw_card(), _draw_card()]
	hand_started.emit()
	card_dealt.emit("player", player[0], false)
	card_dealt.emit("dealer", dealer[0], false)
	card_dealt.emit("player", player[1], false)
	card_dealt.emit("dealer", dealer[1], true)
	_render(true)
	if total(player) == 21:
		_finish()
	else:
		_info.text = "Carte ou rester ?"
	_set_buttons()


func _on_hit() -> void:
	if not in_hand:
		return
	player.append(_draw_card())
	card_dealt.emit("player", player[-1], false)
	_render(true)
	if total(player) > 21:
		_finish()
	elif total(player) == 21:
		_on_stand()
	_set_buttons()


func _on_double() -> void:
	if not in_hand or player.size() != 2:
		return
	if not Game.spend(bet):
		_info.text = "Pas assez de crédits pour doubler."
		return
	bet *= 2
	player.append(_draw_card())
	card_dealt.emit("player", player[-1], false)
	_render(true)
	_finish()


func _on_stand() -> void:
	if in_hand:
		_finish()


func _finish() -> void:
	var p := total(player)
	var natural := p == 21 and player.size() == 2
	hole_revealed.emit(dealer[1])
	if p <= 21 and not natural:
		while total(dealer) < 17:
			dealer.append(_draw_card())
			card_dealt.emit("dealer", dealer[-1], false)
	var d := total(dealer)
	var dealer_natural := d == 21 and dealer.size() == 2
	var payout := 0
	if p > 21:
		_info.text = "Vous sautez à %d. Une prochaine main vous attend." % p
	elif natural and not dealer_natural:
		payout = bet + bet * 3 / 2
		_info.text = "Blackjack ! Vous encaissez %s." % Game.fmt(payout)
	elif dealer_natural and not natural:
		_info.text = "Blackjack du croupier."
	elif d > 21 or p > d:
		payout = bet * 2
		_info.text = "Gagné, %d contre %d. Vous encaissez %s." % [p, d, Game.fmt(payout)]
	elif p == d:
		payout = bet
		_info.text = "Égalité à %d, la mise est rendue." % p
	else:
		_info.text = "Le croupier fait %d. Un investissement se mesure sur la durée." % d
	in_hand = false
	_render(false)
	_set_buttons()
	played.emit(bet, payout)


func _set_buttons() -> void:
	_deal.disabled = in_hand
	_hit.disabled = not in_hand
	_stand.disabled = not in_hand
	_double.disabled = not in_hand or player.size() != 2


func _render(hide_hole: bool) -> void:
	for c in _dealer_box.get_children():
		c.queue_free()
	for c in _player_box.get_children():
		c.queue_free()
	for i in dealer.size():
		_dealer_box.add_child(_card_view(dealer[i], hide_hole and i == 1))
	for c in player:
		_player_box.add_child(_card_view(c, false))
	_player_total.text = "Vous : %d" % total(player)
	_dealer_total.text = "Croupier : %s" % ("?" if hide_hole else str(total(dealer)))


func _card_view(c: Dictionary, hidden: bool) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.45, 0.06, 0.1) if hidden else Color(0.98, 0.96, 0.9)
	sb.border_color = Color(0.85, 0.7, 0.4)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	p.add_theme_stylebox_override("panel", sb)
	p.custom_minimum_size = Vector2(72, 104)
	var l := Label.new()
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", _symbol_font)
	l.add_theme_font_size_override("font_size", 30)
	if hidden:
		l.text = "♦"
		l.add_theme_color_override("font_color", Color(0.85, 0.7, 0.4))
	else:
		l.text = "%s\n%s" % [RANKS[c.r], SUITS[c.s]]
		l.add_theme_color_override("font_color", Color(0.75, 0.05, 0.1) if c.s in [1, 2] else Color(0.08, 0.08, 0.1))
	p.add_child(l)
	return p


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
