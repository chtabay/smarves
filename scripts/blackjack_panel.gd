extends PanelContainer
## Blackjack, règles d'Addict : sabot de 6 jeux, le croupier reste sur tout 17, blackjack payé 3 contre 2,
## doublement sur les deux premières cartes.
## Le partage et l'assurance s'ouvrent par un seuil (SEUIL_REGLES gagnés au jeu), à toutes les tables :
## deux cartes de même valeur se séparent en deux mains, chacune avec sa mise (jusqu'à quatre mains ; deux
## as partagés reçoivent une carte chacun, et 21 sur une main partagée n'est pas un blackjack) ; quand le
## croupier montre un as, on peut s'assurer pour la moitié de la mise, payée 2 contre 1 s'il a blackjack.
## Une fois les règles ouvertes, le croupier regarde sous son as ou son dix et retourne tout de suite un
## blackjack. Avant le seuil, la table joue exactement comme avant.

signal played(bet: int, payout: int)
signal closed
## Pour poser les cartes sur le feutre 3D : « player » ou « dealer », la carte, et si elle est face cachée.
signal card_dealt(who: String, card: Dictionary, hidden: bool)
signal hand_started
signal hole_revealed(card: Dictionary)
## Le partage : la main « from » garde sa première carte, la seconde part former la main « to » (to = from + 1).
signal hand_split(from: int, to: int)
## Une main doublée : sa mise grandit de « amount ».
signal hand_doubled(hand: int, amount: int)
## L'assurance posée, pour la moitié de la mise.
signal insured(amount: int)

## Le seuil, sur le total gagné au jeu, qui ouvre le partage et l'assurance (docs : règles du blackjack).
const SEUIL_REGLES := 1000
const MAINS_MAX := 4

## Les mises proposées : celles du casino par défaut, celles d'une commune par configurer_mises().
var BETS := [5, 10, 25, 100, 500]
const BARRE := preload("res://scripts/jeux/barre.gd")
const REGLES := preload("res://scripts/jeux/regles.gd")
const SUITS := ["♠", "♥", "♦", "♣"]
const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "V", "D", "R"]

var title := "Blackjack"
var bet_index := 1
var shoe: Array = []
## Les mains du joueur : une seule, ou jusqu'à quatre après des partages. {cards, bet, done, aces}.
var hands: Array = []
## La main qui se joue.
var active := 0
## Les cartes de la main qui se joue.
var player: Array:
	get:
		return hands[active].cards if active < hands.size() else []
var dealer: Array = []
## Tout ce qui est misé sur les mains (doublements et partages compris), sans l'assurance.
var bet := 0
var in_hand := false
## L'assurance prise sur cette donne (0 : aucune).
var assurance := 0
## Le croupier montre un as : on attend la réponse à l'assurance avant de jouer.
var attente_assurance := false
## Le partage et l'assurance, ouverts pour la donne en cours (le seuil est relu à chaque donne).
var regles_completes := false
var _split: Button
var _insure: Button
var _no_insure: Button
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
var _symbol_font: Font
## Assis à une table 3D : les cartes sont sur le feutre, le panneau devient une barre basse,
## et ses messages attendent que le croupier ait fini ses gestes.
var embedded := false
var table3d: Node
var _chip_row: HBoxContainer


func _ready() -> void:
	_symbol_font = Polices.texte()
	if embedded:
		_build_bar()
		return
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
	_info.text = _accueil()
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
	_split = _button(controls, "Partager", _on_split)
	_insure = _button(controls, "Assurer", _on_insure)
	_no_insure = _button(controls, "Sans assurance", _on_no_insure)
	controls.add_child(REGLES.bouton(self, "blackjack", false))
	_button(controls, "Quitter (Échap)", func(): closed.emit())
	_change_bet(0)
	_set_buttons()


func _build_bar() -> void:
	BARRE.style(self)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	_info = BARRE.label(_accueil(), 18)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_override("font", _symbol_font)
	v.add_child(_info)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	_chip_row = BARRE.chip_row(BETS, bet_index, _pick_bet)
	h.add_child(_chip_row)
	_bet_label = BARRE.label("", 15, BARRE.MUTED)
	_bet_label.custom_minimum_size = Vector2(80, 0)
	h.add_child(_bet_label)
	h.add_child(BARRE.separator())
	_deal = BARRE.main_button("  Distribuer  (Espace)  ")
	_deal.pressed.connect(_start)
	h.add_child(_deal)
	_hit = BARRE.pill("Carte  (C)")
	_hit.pressed.connect(_on_hit)
	h.add_child(_hit)
	_stand = BARRE.pill("Rester  (R)")
	_stand.pressed.connect(_on_stand)
	h.add_child(_stand)
	_double = BARRE.pill("Doubler  (D)")
	_double.pressed.connect(_on_double)
	h.add_child(_double)
	_split = BARRE.pill("Partager  (P)")
	_split.pressed.connect(_on_split)
	h.add_child(_split)
	_insure = BARRE.pill("Assurer  (A)")
	_insure.pressed.connect(_on_insure)
	h.add_child(_insure)
	_no_insure = BARRE.pill("Sans assurance  (N)")
	_no_insure.pressed.connect(_on_no_insure)
	h.add_child(_no_insure)
	h.add_child(REGLES.bouton(self, "blackjack"))
	var leave := BARRE.pill("Quitter  (Échap)")
	leave.pressed.connect(func(): closed.emit())
	h.add_child(leave)
	_change_bet(0)
	_set_buttons()


## Le partage et l'assurance sont-ils ouverts (seuil passé) ?
static func regles_ouvertes() -> bool:
	return Game.won >= SEUIL_REGLES


func _accueil() -> String:
	return "Choisissez votre mise et distribuez." + (" Ici, on partage les paires et on s'assure contre l'as." if regles_ouvertes() else "")


func _pick_bet(i: int) -> void:
	if in_hand:
		return
	bet_index = i
	_change_bet(0)


## Un message, affiché quand le croupier a fini ce qu'il fait sur la table.
func _say(text: String) -> void:
	if embedded and table3d and table3d.busy_time() > 0.0:
		# Une méthode liée, pas une lambda : la connexion tombe d'elle-même si le panneau est libéré.
		get_tree().create_timer(table3d.busy_time()).timeout.connect(_set_info.bind(text))
	else:
		_set_info(text)


func _set_info(text: String) -> void:
	_info.text = text


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


## Les mises d'une table de commune (sur le modèle de configurer_blindes) : de deux à neuf montants
## croissants, choisis au clavier par 1 à 9. À appeler avant que le panneau entre dans la scène. Rend false,
## sans rien changer, pour une liste incohérente (vide, trop longue, une mise nulle ou en désordre).
func configurer_mises(mises: Array) -> bool:
	var ok := mises.size() >= 2 and mises.size() <= 9
	for i in mises.size():
		ok = ok and typeof(mises[i]) in [TYPE_INT, TYPE_FLOAT] and int(mises[i]) > 0 and (i == 0 or int(mises[i]) > int(mises[i - 1]))
	if not ok:
		push_warning("%s : mises refusées %s." % [title, str(mises)])
		return false
	BETS = mises.map(func(m): return int(m))
	bet_index = mini(bet_index, BETS.size() - 1)
	return true


func _change_bet(d: int) -> void:
	if in_hand:
		return
	bet_index = clampi(bet_index + d, 0, BETS.size() - 1)
	_bet_label.text = "Mise : %d" % BETS[bet_index]
	if _chip_row:
		BARRE.select(_chip_row, bet_index)


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


## La valeur d'une carte au blackjack (l'as compte 11 ici), pour le partage et le regard du croupier.
static func valeur(c: Dictionary) -> int:
	return 11 if c.r == 0 else mini(c.r + 1, 10)


static func _who(i: int) -> String:
	return "player" if i == 0 else "player%d" % i


func _start() -> void:
	if in_hand:
		return
	var amount: int = BETS[bet_index]
	if not Game.spend(amount):
		_say("Pas assez de crédits pour cette mise.")
		return
	regles_completes = regles_ouvertes()
	bet = amount
	in_hand = true
	assurance = 0
	active = 0
	var p := [_draw_card(), _draw_card()]
	hands = [{"cards": p, "bet": amount, "done": false, "aces": false}]
	dealer = [_draw_card(), _draw_card()]
	hand_started.emit()
	card_dealt.emit("player", player[0], false)
	card_dealt.emit("dealer", dealer[0], false)
	card_dealt.emit("player", player[1], false)
	card_dealt.emit("dealer", dealer[1], true)
	_render(true)
	if regles_completes and dealer[0].r == 0:
		attente_assurance = true
		_say("Le croupier montre un as. Assurance ? La moitié de la mise, payée 2 contre 1 s'il a blackjack.")
		_set_buttons()
		return
	_jouer()


## La donne s'engage : le croupier regarde sous son as ou son dix (règles ouvertes), puis on joue.
func _jouer() -> void:
	attente_assurance = false
	if regles_completes and valeur(dealer[0]) >= 10 and total(dealer) == 21:
		_finish()
	elif total(player) == 21:
		_finish()
	else:
		_say(_invite())
	_set_buttons()


## Ce qu'on peut faire, dit au joueur.
func _invite() -> String:
	var t := "Carte ou rester ?"
	if peut_partager():
		t = "Carte, rester ou partager ?"
	if hands.size() > 1:
		t = "Main %d : %s" % [active + 1, t.substr(0, 1).to_lower() + t.substr(1)]
	return t


func _on_insure() -> void:
	if not attente_assurance:
		return
	var a := maxi(1, bet / 2)
	if not Game.spend(a):
		_say("Pas assez de crédits pour s'assurer.")
		return
	assurance = a
	insured.emit(a)
	_jouer()


func _on_no_insure() -> void:
	if attente_assurance:
		_jouer()


## Deux cartes de même valeur, sur une main qui n'a pas encore tiré : elles peuvent se séparer.
func peut_partager() -> bool:
	if not regles_completes or not in_hand or attente_assurance or hands.size() >= MAINS_MAX or active >= hands.size():
		return false
	var h: Dictionary = hands[active]
	return h.cards.size() == 2 and not h.aces and valeur(h.cards[0]) == valeur(h.cards[1])


func _on_split() -> void:
	if not peut_partager():
		return
	var h: Dictionary = hands[active]
	if not Game.spend(h.bet):
		_say("Pas assez de crédits pour partager.")
		return
	var aces: bool = h.cards[0].r == 0
	var autre := {"cards": [h.cards.pop_back()], "bet": h.bet, "done": false, "aces": aces}
	h.aces = aces
	hands.insert(active + 1, autre)
	bet += h.bet
	hand_split.emit(active, active + 1)
	_completer()


func _tirer(i: int) -> void:
	hands[i].cards.append(_draw_card())
	card_dealt.emit(_who(i), hands[i].cards[-1], false)


## La main qui se joue n'a qu'une carte (elle vient d'un partage) : elle reçoit sa seconde. Deux as
## partagés n'en reçoivent qu'une chacun ; 21 se joue tout seul.
func _completer() -> void:
	var h: Dictionary = hands[active]
	if h.cards.size() == 1:
		_tirer(active)
	_render(true)
	if h.aces or total(h.cards) == 21:
		_main_suivante()
	else:
		_say(_invite())
		_set_buttons()


## La main qui se joue est finie : à la suivante, ou au croupier.
func _main_suivante() -> void:
	hands[active].done = true
	if active + 1 < hands.size():
		active += 1
		_completer()
	else:
		_finish()


func _on_hit() -> void:
	if not in_hand or attente_assurance or hands[active].aces:
		return
	_tirer(active)
	_render(true)
	if total(player) >= 21:
		_main_suivante()
	elif hands.size() > 1:
		_say(_invite())
	_set_buttons()


func _on_double() -> void:
	if not in_hand or attente_assurance or player.size() != 2 or hands[active].aces:
		return
	var h: Dictionary = hands[active]
	if not Game.spend(h.bet):
		_say("Pas assez de crédits pour doubler.")
		return
	hand_doubled.emit(active, h.bet)
	bet += h.bet
	h.bet *= 2
	_tirer(active)
	_render(true)
	_main_suivante()


func _on_stand() -> void:
	if in_hand and not attente_assurance:
		_main_suivante()


## Une main contre celle du croupier : [ce qu'elle rend, son issue] ; l'issue est « bust », « blackjack »,
## « dealer_bj », « win », « push » ou « lose ». Une main partagée n'a jamais de blackjack.
func _regler(h: Dictionary) -> Array:
	var p := total(h.cards)
	var natural: bool = p == 21 and h.cards.size() == 2 and hands.size() == 1
	var d := total(dealer)
	var dealer_natural := d == 21 and dealer.size() == 2
	if p > 21:
		return [0, "bust"]
	if natural and not dealer_natural:
		return [h.bet + h.bet * 3 / 2, "blackjack"]
	if dealer_natural and not natural:
		return [0, "dealer_bj"]
	if d > 21 or p > d:
		return [h.bet * 2, "win"]
	if p == d:
		return [h.bet, "push"]
	return [0, "lose"]


func _finish() -> void:
	attente_assurance = false
	hole_revealed.emit(dealer[1])
	# Le croupier tire s'il reste une main à battre : ni sautée, ni blackjack.
	var a_battre := false
	for h in hands:
		var p := total(h.cards)
		if p <= 21 and not (p == 21 and h.cards.size() == 2 and hands.size() == 1):
			a_battre = true
	if a_battre:
		while total(dealer) < 17:
			dealer.append(_draw_card())
			card_dealt.emit("dealer", dealer[-1], false)
	var d := total(dealer)
	var dealer_natural := d == 21 and dealer.size() == 2
	var payout := 0
	var issues: Array = []
	for h in hands:
		var r := _regler(h)
		payout += int(r[0])
		issues.append(r[1])
	var texte := ""
	if hands.size() == 1:
		var p := total(hands[0].cards)
		texte = {
			"bust": "Vous sautez à %d. Une prochaine main vous attend." % p,
			"blackjack": "Blackjack ! Vous encaissez %s." % Game.fmt(payout),
			"dealer_bj": "Blackjack du croupier.",
			"win": "Gagné, %d contre %d. Vous encaissez %s." % [p, d, Game.fmt(payout)],
			"push": "Égalité à %d, la mise est rendue." % p,
			"lose": "Le croupier fait %d. Un investissement se mesure sur la durée." % d,
		}[issues[0]]
	else:
		var parts: Array[String] = []
		for i in hands.size():
			var p := total(hands[i].cards)
			parts.append("main %d : %s" % [i + 1, {"bust": "sautée à %d" % p, "dealer_bj": "perdue", "win": "gagnée à %d" % p,
				"push": "égalité à %d" % p, "lose": "perdue à %d" % p, "blackjack": "gagnée à 21"}[issues[i]]])
		var tete := "Le croupier saute" if d > 21 else "Le croupier fait %d" % d
		var verdict := "Il ramasse tout."
		if payout > bet:
			verdict = "Vous encaissez %s." % Game.fmt(payout)
		elif payout > 0:
			verdict = "Vous récupérez %s." % Game.fmt(payout)
		texte = "%s : %s. %s" % [tete, ", ".join(parts), verdict]
	if assurance > 0:
		if dealer_natural:
			payout += assurance * 3
			texte += " L'assurance paie %s." % Game.fmt(assurance * 3)
		else:
			texte += " L'assurance est perdue."
	_say(texte)
	in_hand = false
	_render(false)
	_set_buttons()
	played.emit(bet + assurance, payout)


func _set_buttons() -> void:
	if embedded and table3d and table3d.busy_time() > 0.0:
		for b in [_deal, _hit, _stand, _double]:
			b.disabled = true
		get_tree().create_timer(table3d.busy_time()).timeout.connect(_apply_buttons)
		return
	_apply_buttons()


func _apply_buttons() -> void:
	var jeu := in_hand and not attente_assurance
	var as_partages: bool = jeu and active < hands.size() and hands[active].aces
	_deal.disabled = in_hand
	_hit.disabled = not jeu or as_partages
	_stand.disabled = not jeu
	_double.disabled = not jeu or player.size() != 2 or as_partages
	# Partage et assurance : visibles une fois le seuil passé, l'assurance seulement quand on la propose.
	_split.visible = regles_completes if in_hand else regles_ouvertes()
	_split.disabled = not peut_partager()
	_insure.visible = attente_assurance
	_no_insure.visible = attente_assurance
	# La question de l'assurance prend la place des gestes de la main, le temps d'y répondre.
	for b in [_deal, _hit, _stand, _double]:
		b.visible = not attente_assurance
	if attente_assurance:
		_split.visible = false


func _render(hide_hole: bool) -> void:
	if embedded:
		return
	for c in _dealer_box.get_children():
		c.queue_free()
	for c in _player_box.get_children():
		c.queue_free()
	for i in dealer.size():
		_dealer_box.add_child(_card_view(dealer[i], hide_hole and i == 1))
	for i in hands.size():
		if i > 0:
			var sep := Control.new()
			sep.custom_minimum_size = Vector2(26, 0)
			_player_box.add_child(sep)
		for c in hands[i].cards:
			var v := _card_view(c, false)
			if hands.size() > 1 and i != active and in_hand:
				v.modulate = Color(1, 1, 1, 0.55)
			_player_box.add_child(v)
	if hands.size() > 1:
		var totaux: Array[String] = []
		for i in hands.size():
			totaux.append(("▸ %d" if i == active and in_hand else "%d") % total(hands[i].cards))
		_player_total.text = "Vos mains : %s" % "  ·  ".join(totaux)
	else:
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
	if visible and embedded and event is InputEventKey and event.pressed and not event.echo:
		var b: Button = {KEY_SPACE: _deal, KEY_C: _hit, KEY_R: _stand, KEY_D: _double, KEY_P: _split, KEY_A: _insure, KEY_N: _no_insure}.get(event.keycode)
		if b and b.visible and not b.disabled:
			b.pressed.emit()
			get_viewport().set_input_as_handled()
			return
		if event.keycode >= KEY_1 and event.keycode < KEY_1 + BETS.size():
			_pick_bet(event.keycode - KEY_1)
	if visible and event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
