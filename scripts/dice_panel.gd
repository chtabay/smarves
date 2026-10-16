extends PanelContainer
## Le Grand Hasard (trois dés), le jeu de la Loggia dans Addict : un numéro paie 1, 2 ou 3 fois selon
## le nombre de dés qui le montrent ; Petit (4 à 10) et Grand (11 à 17) paient 1 contre 1 et perdent sur
## un triple ; « n'importe quel triple » paie 30 contre 1. Mises de 10 à 500.

signal played(bet: int, payout: int)
signal closed
signal dice_rolled(values: Array)

const CHIPS := [10, 25, 100, 500]
const FACES := ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]

var title := "Le Grand Hasard"
var chip_index := 0
var bets := {}
var busy := false
var _dice: Label
var _info: Label
var _chip_label: Label
var _buttons := {}
var _font: SystemFont


func _ready() -> void:
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Segoe UI Symbol", "Georgia"])
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
	rule.text = "Numéro : 1, 2 ou 3 fois la mise  ·  Petit / Grand 1 contre 1, perdus sur un triple  ·  Triple 30 contre 1"
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule.add_theme_font_size_override("font_size", 14)
	rule.add_theme_color_override("font_color", Color(0.7, 0.66, 0.6))
	v.add_child(rule)
	_dice = Label.new()
	_dice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice.add_theme_font_override("font", _font)
	_dice.add_theme_font_size_override("font_size", 96)
	_dice.text = "⚀ ⚀ ⚀"
	v.add_child(_dice)
	var nums := HBoxContainer.new()
	nums.alignment = BoxContainer.ALIGNMENT_CENTER
	nums.add_theme_constant_override("separation", 6)
	v.add_child(nums)
	for n in 6:
		nums.add_child(_bet_button("n%d" % (n + 1), FACES[n], Vector2(90, 56)))
	var outs := HBoxContainer.new()
	outs.alignment = BoxContainer.ALIGNMENT_CENTER
	outs.add_theme_constant_override("separation", 6)
	v.add_child(outs)
	outs.add_child(_bet_button("small", "Petit 4–10", Vector2(180, 44)))
	outs.add_child(_bet_button("triple", "Triple", Vector2(180, 44)))
	outs.add_child(_bet_button("big", "Grand 11–17", Vector2(180, 44)))
	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 20)
	_info.text = "Misez sur un numéro ou une chance, puis secouez le gobelet."
	v.add_child(_info)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	v.add_child(controls)
	var minus := Button.new()
	minus.text = "−"
	minus.pressed.connect(func(): _chip(-1))
	controls.add_child(minus)
	_chip_label = Label.new()
	_chip_label.custom_minimum_size = Vector2(110, 0)
	_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_child(_chip_label)
	var plus := Button.new()
	plus.text = "+"
	plus.pressed.connect(func(): _chip(1))
	controls.add_child(plus)
	var roll := Button.new()
	roll.text = "Secouer le gobelet  (Espace)"
	roll.pressed.connect(_roll)
	controls.add_child(roll)
	var leave := Button.new()
	leave.text = "Quitter (Échap)"
	leave.pressed.connect(func(): closed.emit())
	controls.add_child(leave)
	_chip(0)


func _bet_button(key: String, text: String, size: Vector2) -> Button:
	var b := Button.new()
	b.custom_minimum_size = size
	b.text = text
	b.set_meta("label", text)
	b.add_theme_font_override("font", _font)
	b.add_theme_font_size_override("font_size", 30 if key.begins_with("n") else 18)
	b.pressed.connect(_place.bind(key))
	_buttons[key] = b
	return b


func _chip(d: int) -> void:
	chip_index = clampi(chip_index + d, 0, CHIPS.size() - 1)
	_chip_label.text = "Jeton : %d" % CHIPS[chip_index]


func _place(key: String) -> void:
	if busy:
		return
	if bets.get(key, 0) + CHIPS[chip_index] > 500:
		_info.text = "La table est plafonnée à 500 par case."
		return
	if not Game.spend(CHIPS[chip_index]):
		_info.text = "Pas assez de crédits pour ce jeton."
		return
	bets[key] = bets.get(key, 0) + CHIPS[chip_index]
	for k in _buttons:
		var b: Button = _buttons[k]
		b.text = b.get_meta("label") + (" · %d" % bets[k] if bets.has(k) else "")


func _roll() -> void:
	if busy or bets.is_empty():
		if bets.is_empty():
			_info.text = "Posez d'abord une mise."
		return
	busy = true
	Sfx.play("shake", -4.0)
	for i in 12:
		_dice.text = "%s %s %s" % [FACES.pick_random(), FACES.pick_random(), FACES.pick_random()]
		await get_tree().create_timer(0.06 + i * 0.012).timeout
	var d := [randi_range(1, 6), randi_range(1, 6), randi_range(1, 6)]
	dice_rolled.emit(d)
	Sfx.play("dice", -4.0)
	_dice.text = "%s %s %s" % [FACES[d[0] - 1], FACES[d[1] - 1], FACES[d[2] - 1]]
	var sum: int = d[0] + d[1] + d[2]
	var triple: bool = d[0] == d[1] and d[1] == d[2]
	var total := 0
	var payout := 0
	for k in bets:
		var b: int = bets[k]
		total += b
		if k.begins_with("n"):
			var hits := d.count(int(k.substr(1)))
			if hits > 0:
				payout += b + b * hits
		elif k == "small" and not triple and sum >= 4 and sum <= 10:
			payout += b * 2
		elif k == "big" and not triple and sum >= 11 and sum <= 17:
			payout += b * 2
		elif k == "triple" and triple:
			payout += b * 31
	bets.clear()
	for k in _buttons:
		_buttons[k].text = _buttons[k].get_meta("label")
	_info.text = "Total %d%s. %s" % [sum, " (triple)" if triple else "", "Vous encaissez %s." % Game.fmt(payout) if payout > 0 else "La chance tourne, l'investissement reste."]
	busy = false
	played.emit(total, payout)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_roll()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
