extends PanelContainer
## Roulette européenne (un seul zéro), règles d'Addict : plein 35 contre 1, chances simples 1 contre 1,
## douzaines et colonnes 2 contre 1. Le zéro fait perdre toutes les chances simples.

signal played(bet: int, payout: int)
signal closed
## Pour animer la roue 3D de la table : le numéro tiré et la durée du lancer.
signal spin_started(number: int, duration: float)
## Pour la table 3D : les mises posées (clé -> montant), et le résultat (gain par case gagnante).
signal bets_changed(bets: Dictionary)
signal settled(number: int, wins: Dictionary)

const BARRE := preload("res://scripts/jeux/barre.gd")
const REGLES := preload("res://scripts/jeux/regles.gd")

const RED := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
const WHEEL := [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10, 5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
const CHIPS := [1, 5, 25, 100, 500]

var title := "Roulette"
var chip_index := 1
## Mises posées : clé de case -> montant.
var bets := {}
var spinning := false
var _wheel: Control
var _wheel_angle := 0.0
var _ball_angle := 0.0
var _result_number := -1
var _cells := {}
var _info: Label
var _chip_label: Label
var _spin_button: Button
var _font: Font
## Assis à une table 3D : on mise sur le tapis, le panneau devient une barre basse.
var embedded := false
var spin_time := 4.0
var _chip_row: HBoxContainer
var _total_label: Label


func _ready() -> void:
	_font = get_theme_default_font()
	if embedded:
		_build_bar()
		return
	custom_minimum_size = Vector2(980, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Color(0.96, 0.8, 0.45))
	v.add_child(t)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	_wheel = Control.new()
	_wheel.custom_minimum_size = Vector2(250, 250)
	_wheel.draw.connect(_draw_wheel)
	h.add_child(_wheel)

	var table := VBoxContainer.new()
	table.add_theme_constant_override("separation", 3)
	h.add_child(table)
	var grid_row := HBoxContainer.new()
	grid_row.add_theme_constant_override("separation", 3)
	table.add_child(grid_row)
	var zero := _cell("0", "n0", Color(0.05, 0.4, 0.2))
	zero.custom_minimum_size = Vector2(44, 3 * 44 + 6)
	grid_row.add_child(zero)
	var grid := GridContainer.new()
	grid.columns = 13
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	grid_row.add_child(grid)
	for row in 3:
		for col in 12:
			var n: int = col * 3 + (3 - row)
			grid.add_child(_cell(str(n), "n%d" % n, Color(0.7, 0.08, 0.1) if n in RED else Color(0.08, 0.08, 0.09)))
		grid.add_child(_cell("2:1", "col%d" % (3 - row), Color(0.05, 0.32, 0.17)))
	var dozens := HBoxContainer.new()
	dozens.add_theme_constant_override("separation", 3)
	table.add_child(dozens)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(47, 0)
	dozens.add_child(spacer)
	for d in 3:
		var c := _cell(["1re douzaine", "2e douzaine", "3e douzaine"][d], "doz%d" % (d + 1), Color(0.05, 0.32, 0.17))
		c.custom_minimum_size = Vector2(4 * 44 + 9, 34)
		dozens.add_child(c)
	var simples := HBoxContainer.new()
	simples.add_theme_constant_override("separation", 3)
	table.add_child(simples)
	var spacer2 := Control.new()
	spacer2.custom_minimum_size = Vector2(47, 0)
	simples.add_child(spacer2)
	for s in [["Manque", "low"], ["Pair", "even"], ["Rouge", "red"], ["Noir", "black"], ["Impair", "odd"], ["Passe", "high"]]:
		var col := Color(0.05, 0.32, 0.17)
		if s[1] == "red":
			col = Color(0.7, 0.08, 0.1)
		elif s[1] == "black":
			col = Color(0.08, 0.08, 0.09)
		var c := _cell(s[0], s[1], col)
		c.custom_minimum_size = Vector2(2 * 44 + 1.5, 34)
		simples.add_child(c)

	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 20)
	_info.text = "Cliquez sur les cases pour miser, puis lancez la bille."
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
	_chip_label.custom_minimum_size = Vector2(120, 0)
	_chip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_child(_chip_label)
	var plus := Button.new()
	plus.text = "+"
	plus.pressed.connect(func(): _chip(1))
	controls.add_child(plus)
	var clear := Button.new()
	clear.text = "Retirer les mises"
	clear.pressed.connect(_clear)
	controls.add_child(clear)
	_spin_button = Button.new()
	_spin_button.text = "Lancer la bille  (Espace)"
	_spin_button.pressed.connect(spin)
	controls.add_child(_spin_button)
	controls.add_child(REGLES.bouton(self, "roulette", false))
	var leave := Button.new()
	leave.text = "Quitter la table  (Échap)"
	leave.pressed.connect(func(): closed.emit())
	controls.add_child(leave)
	_chip(0)


## La barre basse : jetons, mise totale, message du croupier, boutons.
func _build_bar() -> void:
	BARRE.style(self)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	_info = BARRE.label("Faites vos jeux : cliquez sur le tapis pour miser.", 18, BARRE.CREAM)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_override("font", _serif())
	v.add_child(_info)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	_chip_row = BARRE.chip_row(CHIPS, chip_index, _pick_chip)
	h.add_child(_chip_row)
	_chip_label = BARRE.label("", 15, BARRE.MUTED)
	_chip_label.custom_minimum_size = Vector2(92, 0)
	h.add_child(_chip_label)
	h.add_child(BARRE.separator())
	_total_label = BARRE.label("Sur le tapis : 0", 16, BARRE.CREAM)
	_total_label.custom_minimum_size = Vector2(150, 0)
	h.add_child(_total_label)
	var clear := BARRE.pill("Retirer")
	clear.pressed.connect(_clear)
	h.add_child(clear)
	_spin_button = BARRE.main_button("  Lancer la bille  (Espace)  ")
	_spin_button.pressed.connect(spin)
	h.add_child(_spin_button)
	h.add_child(REGLES.bouton(self, "roulette"))
	var leave := BARRE.pill("Quitter  (Échap)")
	leave.pressed.connect(func(): closed.emit())
	h.add_child(leave)
	_chip(0)


func _pick_chip(i: int) -> void:
	chip_index = i
	_chip(0)


func _serif() -> Font:
	return Polices.texte()


func _cell(text: String, key: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(44, 44)
	b.add_theme_font_size_override("font_size", 16 if text.length() < 4 else 14)
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = Color(0.85, 0.75, 0.5, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	b.add_theme_stylebox_override("normal", sb)
	var hov := sb.duplicate()
	hov.bg_color = color.lightened(0.25)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", hov)
	b.add_theme_color_override("font_color", Color(0.97, 0.94, 0.86))
	b.pressed.connect(_place_bet.bind(key))
	b.set_meta("label", text)
	_cells[key] = b
	return b


func _chip(d: int) -> void:
	chip_index = clampi(chip_index + d, 0, CHIPS.size() - 1)
	_chip_label.text = "Jeton : %d" % CHIPS[chip_index]
	if _chip_row:
		BARRE.select(_chip_row, chip_index)


func _place_bet(key: String) -> void:
	if spinning:
		return
	var amount: int = CHIPS[chip_index]
	if not Game.spend(amount):
		_info.text = "Pas assez de crédits pour ce jeton."
		return
	bets[key] = bets.get(key, 0) + amount
	_refresh_cells()
	_info.text = "Mise totale : %s" % Game.fmt(_total())


func _clear() -> void:
	if spinning:
		return
	for k in bets:
		Game.credits += bets[k]
		Game.staked -= bets[k]
	bets.clear()
	Game.changed.emit()
	_refresh_cells()
	_info.text = "Mises retirées."


func _total() -> int:
	var t := 0
	for k in bets:
		t += bets[k]
	return t


func _refresh_cells() -> void:
	bets_changed.emit(bets.duplicate())
	if _total_label:
		_total_label.text = "Sur le tapis : %s" % Game.fmt(_total())
	for k in _cells:
		var b: Button = _cells[k]
		b.text = b.get_meta("label") + ("\n●%d" % bets[k] if bets.has(k) else "")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		spin()
		get_viewport().set_input_as_handled()
	elif embedded and event is InputEventKey and event.pressed and event.keycode >= KEY_1 and event.keycode < KEY_1 + CHIPS.size():
		chip_index = event.keycode - KEY_1
		_chip(0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


func spin() -> void:
	if spinning or bets.is_empty():
		if bets.is_empty():
			_info.text = "Posez d'abord une mise."
		return
	spinning = true
	_spin_button.disabled = true
	_info.text = "Rien ne va plus."
	_result_number = randi() % 37
	spin_started.emit(_result_number, spin_time)
	var tw := create_tween().set_parallel()
	var start_w := _wheel_angle
	var start_b := _ball_angle
	var idx: int = WHEEL.find(_result_number)
	var end_w := start_w + TAU * 3.0
	# La bille finit sur la case tirée, en tournant à contre-sens de la roue.
	var end_b := end_w + idx * TAU / 37.0 - TAU * 5.0
	tw.tween_method(_set_wheel_angle, start_w, end_w, spin_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(_set_ball_angle, start_b, end_b, spin_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	await tw.finished
	Sfx.play("dice", -8.0, 1.6)
	var total := _total()
	var payout := 0
	var wins := {}
	for k in bets:
		var w: int = bets[k] * _multiplier(k, _result_number)
		payout += w
		if w > 0:
			wins[k] = w
	settled.emit(_result_number, wins)
	bets.clear()
	_refresh_cells()
	var col := "vert" if _result_number == 0 else ("rouge" if _result_number in RED else "noir")
	if payout > 0:
		_info.text = "%d %s. Vous encaissez %s crédits." % [_result_number, col, Game.fmt(payout)]
	else:
		_info.text = "%d %s. La maison remercie votre confiance." % [_result_number, col]
	played.emit(total, payout)
	spinning = false
	_spin_button.disabled = false


func _set_wheel_angle(a: float) -> void:
	_wheel_angle = a
	if _wheel:
		_wheel.queue_redraw()


func _set_ball_angle(a: float) -> void:
	_ball_angle = a
	if _wheel:
		_wheel.queue_redraw()


## Ce que rend une mise gagnante, mise comprise (0 si perdue).
func _multiplier(key: String, n: int) -> int:
	if key.begins_with("n"):
		return 36 if int(key.substr(1)) == n else 0
	if n == 0:
		return 0
	match key:
		"red": return 2 if n in RED else 0
		"black": return 2 if not (n in RED) else 0
		"even": return 2 if n % 2 == 0 else 0
		"odd": return 2 if n % 2 == 1 else 0
		"low": return 2 if n <= 18 else 0
		"high": return 2 if n >= 19 else 0
	if key.begins_with("doz"):
		var d := int(key.substr(3))
		return 3 if (n - 1) / 12 + 1 == d else 0
	if key.begins_with("col"):
		var c := int(key.substr(3))
		return 3 if (n - 1) % 3 + 1 == c else 0
	return 0


func _draw_wheel() -> void:
	var c := _wheel.size / 2.0
	var r := minf(c.x, c.y) - 6.0
	_wheel.draw_circle(c, r + 6.0, Color(0.32, 0.18, 0.08))
	_wheel.draw_circle(c, r + 2.0, Color(0.85, 0.66, 0.3))
	var step := TAU / 37.0
	for i in 37:
		var n: int = WHEEL[i]
		var a0 := _wheel_angle + i * step - step / 2.0
		var pts := PackedVector2Array([c])
		for k in 5:
			var a := a0 + step * k / 4.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		var col := Color(0.05, 0.45, 0.2) if n == 0 else (Color(0.72, 0.08, 0.1) if n in RED else Color(0.07, 0.07, 0.08))
		_wheel.draw_colored_polygon(pts, col)
		var am := _wheel_angle + i * step
		var tp := c + Vector2(cos(am), sin(am)) * (r - 13.0)
		_wheel.draw_set_transform(tp, am + PI / 2.0)
		_wheel.draw_string(_font, Vector2(-7, 5), str(n), HORIZONTAL_ALIGNMENT_CENTER, 14, 11, Color(1, 1, 1))
		_wheel.draw_set_transform(Vector2.ZERO)
	_wheel.draw_circle(c, r * 0.62, Color(0.35, 0.2, 0.09))
	_wheel.draw_circle(c, r * 0.3, Color(0.85, 0.66, 0.3))
	for k in 4:
		var a := _wheel_angle * 1.0 + k * PI / 2.0
		_wheel.draw_line(c, c + Vector2(cos(a), sin(a)) * r * 0.55, Color(0.9, 0.75, 0.4), 4.0)
	var bp := c + Vector2(cos(_ball_angle), sin(_ball_angle)) * (r - 26.0)
	_wheel.draw_circle(bp, 6.0, Color(0.98, 0.98, 0.95))
