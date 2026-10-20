extends PanelContainer
## Le grand loto de la salle François-Rabelais : on coche jusqu'à 5 numéros sur 30, M. Gaudin, le président du comité des fêtes,
## en tire 10. Gains selon les numéros trouvés : 2 → mise rendue, 3 → 4 fois, 4 → 20 fois, 5 → 120 fois.

signal played(bet: int, payout: int)
signal closed

const REGLES := preload("res://scripts/jeux/regles.gd")
const BETS := [10, 50, 100, 500]
const PAYS := {2: 1, 3: 4, 4: 20, 5: 120}

var title := "Le grand loto"
var bet_index := 0
var picks: Array[int] = []
var busy := false
var _cells := {}
var _info: Label
var _bet_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(720, 0)
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
	rule.text = "Cochez jusqu'à 5 numéros  ·  2 trouvés : mise rendue  ·  3 : ×4  ·  4 : ×20  ·  5 : ×120"
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rule.add_theme_font_size_override("font_size", 14)
	rule.add_theme_color_override("font_color", Color(0.72, 0.68, 0.62))
	v.add_child(rule)
	var grid := GridContainer.new()
	grid.columns = 10
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	var center := CenterContainer.new()
	center.add_child(grid)
	v.add_child(center)
	for n in range(1, 31):
		var b := Button.new()
		b.text = str(n)
		b.custom_minimum_size = Vector2(56, 48)
		b.toggle_mode = true
		b.toggled.connect(_toggle.bind(n))
		grid.add_child(b)
		_cells[n] = b
	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(660, 0)
	_info.add_theme_font_size_override("font_size", 19)
	_info.text = "Cochez vos numéros, puis M. Gaudin tire les boules."
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
	_bet_label.custom_minimum_size = Vector2(110, 0)
	_bet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_child(_bet_label)
	var plus := Button.new()
	plus.text = "+"
	plus.pressed.connect(func(): _change(1))
	controls.add_child(plus)
	var go := Button.new()
	go.text = "Tirer les boules  (Espace)"
	go.pressed.connect(_draw_balls)
	controls.add_child(go)
	controls.add_child(REGLES.bouton(self, "loto", false))
	var leave := Button.new()
	leave.text = "Quitter (Échap)"
	leave.pressed.connect(func(): closed.emit())
	controls.add_child(leave)
	_change(0)


func _change(d: int) -> void:
	bet_index = clampi(bet_index + d, 0, BETS.size() - 1)
	_bet_label.text = "Grille : %d" % BETS[bet_index]


func _toggle(on: bool, n: int) -> void:
	if busy:
		return
	if on:
		if picks.size() >= 5:
			_cells[n].set_pressed_no_signal(false)
			return
		picks.append(n)
	else:
		picks.erase(n)


func _draw_balls() -> void:
	if busy:
		return
	if picks.size() < 2:
		_info.text = "Cochez au moins deux numéros."
		return
	var bet: int = BETS[bet_index]
	if not Game.spend(bet):
		_info.text = "Pas assez de crédits pour cette grille."
		return
	busy = true
	var pool := range(1, 31)
	pool.shuffle()
	var drawn: Array = pool.slice(0, 10)
	var shown: Array[String] = []
	for n in drawn:
		shown.append(str(n))
		_info.text = "« Le %s ! »   %s" % [str(n), "  ".join(shown)]
		_cells[n].modulate = Color(1.0, 0.85, 0.4)
		await get_tree().create_timer(0.35).timeout
	var hits := 0
	for p in picks:
		if p in drawn:
			hits += 1
	var payout: int = bet * PAYS.get(hits, 0)
	_info.text = "Tirage : %s. Vous trouvez %d numéro%s. %s" % [", ".join(shown), hits, "s" if hits > 1 else "",
		"Vous encaissez %s." % Game.fmt(payout) if payout > 0 else "Le loto, c'est surtout l'ambiance."]
	await get_tree().create_timer(0.8).timeout
	for n in _cells:
		_cells[n].modulate = Color.WHITE
	busy = false
	played.emit(bet, payout)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_draw_balls()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()
