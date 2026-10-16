extends PanelContainer
## Les paris à cote du village : la pétanque de Lucien et la course des trois zèbres.
## Chaque concurrent a une cote affichée ; ses chances réelles sont un peu plus faibles que ce que
## la cote promet (la marge de l'organisateur), comme au PMU.

signal played(bet: int, payout: int)
signal closed

const BETS := [10, 50, 100, 500, 1000]

var title := "Les paris"
var subtitle := ""
## [nom, cote (gain pour 1 misé)]
var runners: Array = []
var verb := "gagne"
var bet_index := 1
var pick := -1
var busy := false
var _bars: Array[ProgressBar] = []
var _buttons: Array[Button] = []
var _info: Label
var _bet_label: Label


func _ready() -> void:
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
	var sub := Label.new()
	sub.text = subtitle
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.72, 0.68, 0.62))
	v.add_child(sub)
	for i in runners.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		v.add_child(row)
		var b := Button.new()
		b.custom_minimum_size = Vector2(300, 44)
		b.text = "%s  ·  %s contre 1" % [runners[i][0], _odds(runners[i][1])]
		b.toggle_mode = true
		b.pressed.connect(_choose.bind(i))
		row.add_child(b)
		_buttons.append(b)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(380, 24)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.max_value = 100
		row.add_child(bar)
		_bars.append(bar)
	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 20)
	_info.text = "Choisissez votre favori et votre mise."
	v.add_child(_info)
	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	v.add_child(controls)
	var minus := Button.new()
	minus.text = "−"
	minus.pressed.connect(func(): _change(-1))
	controls.add_child(minus)
	_bet_label = Label.new()
	_bet_label.custom_minimum_size = Vector2(120, 0)
	_bet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_child(_bet_label)
	var plus := Button.new()
	plus.text = "+"
	plus.pressed.connect(func(): _change(1))
	controls.add_child(plus)
	var go := Button.new()
	go.text = "Parier et lancer  (Espace)"
	go.pressed.connect(_run)
	controls.add_child(go)
	var leave := Button.new()
	leave.text = "Quitter (Échap)"
	leave.pressed.connect(func(): closed.emit())
	controls.add_child(leave)
	_change(0)


func _odds(o: float) -> String:
	return str(int(o)) if o == floor(o) else str(o).replace(".", ",")


func _change(d: int) -> void:
	if busy:
		return
	bet_index = clampi(bet_index + d, 0, BETS.size() - 1)
	_bet_label.text = "Mise : %d" % BETS[bet_index]


func _choose(i: int) -> void:
	if busy:
		return
	pick = i
	for k in _buttons.size():
		_buttons[k].button_pressed = k == i


func _run() -> void:
	if busy:
		return
	if pick < 0:
		_info.text = "Choisissez d'abord sur qui parier."
		return
	var bet: int = BETS[bet_index]
	if not Game.spend(bet):
		_info.text = "Pas assez de crédits pour cette mise."
		return
	busy = true
	# Probabilités : inverses des cotes, ramenées à 85 % de ce qu'elles promettent.
	var weights: Array[float] = []
	var total := 0.0
	for r in runners:
		var w := 1.0 / (float(r[1]) + 1.0)
		weights.append(w)
		total += w
	var roll := randf() * total
	var winner := 0
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			winner = i
			break
	var paid_odds: float = runners[pick][1]
	# La marge de l'organisateur : une part des victoires « prévues » n'a pas lieu pour le parieur.
	if winner == pick and randf() < 0.15:
		winner = (pick + 1 + randi() % (runners.size() - 1)) % runners.size()
	for b in _bars:
		b.value = 0
	var speeds: Array[float] = []
	for i in runners.size():
		speeds.append(randf_range(18.0, 26.0))
	var finished := false
	while not finished:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		for i in runners.size():
			var boost := 6.0 if i == winner and _bars[i].value > 60.0 else 0.0
			_bars[i].value = minf(99.0 if i != winner else 100.0, _bars[i].value + (speeds[i] + boost + randf_range(-6, 6)) * dt)
		finished = _bars[winner].value >= 100.0
	var payout := 0
	if winner == pick:
		payout = bet + int(round(bet * paid_odds))
		_info.text = "%s %s ! Vous encaissez %s." % [runners[winner][0], verb, Game.fmt(payout)]
	else:
		_info.text = "%s %s. La prochaine sera la bonne." % [runners[winner][0], verb]
	busy = false
	played.emit(bet, payout)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_run()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
