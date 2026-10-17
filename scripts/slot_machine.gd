extends PanelContainer
## « La Smarvoise » : la machine à sous du fond du Café de la Place, chez Josiane.

signal played(bet: int, payout: int)
signal closed
## Pour animer les rouleaux de la machine 3D.
signal reels_started
signal reels_stopped(line: Array)

## Symboles de la bande, du plus rare au plus courant.
const SYMBOLS := ["7", "★", "♣", "♥", "♦", "♠"]
const COLORS := [Color(0.95, 0.25, 0.2), Color(1.0, 0.82, 0.3), Color(0.45, 0.85, 0.5),
	Color(0.95, 0.4, 0.55), Color(0.4, 0.7, 1.0), Color(0.2, 0.2, 0.28)]
## Trois identiques sur la ligne : multiplicateur de la mise.
const PAYS := {"7": 400, "★": 150, "♣": 60, "♥": 25, "♦": 15, "♠": 10}
## Composition d'une bande (nombre de cases par symbole).
const STRIP_WEIGHTS := {"7": 1, "★": 2, "♣": 3, "♥": 4, "♦": 5, "♠": 6}
const BETS := [1, 5, 10, 25, 100]
const CELL := 96.0
const BARRE := preload("res://scripts/jeux/barre.gd")

var game: Node
var title := "La Smarvoise"
var subtitle := "Café de la Place  ·  la machine de Josiane"
var bet_index := 1
var spinning := false
var strips: Array = []
var offsets := [0.0, 0.0, 0.0]
var speeds := [0.0, 0.0, 0.0]
var stop_at := [-1, -1, -1]
var reels: Array[Control] = []
var symbol_font: Font
var _result: Label
var _bet_label: Label
var _spin_button: Button
## Devant une machine 3D : les tambours tournent dans le caisson, le panneau devient une barre basse.
var embedded := false
var _chip_row: HBoxContainer


func _ready() -> void:
	symbol_font = Polices.texte()
	for r in 3:
		var strip: Array[String] = []
		for s in STRIP_WEIGHTS:
			for k in STRIP_WEIGHTS[s]:
				strip.append(s)
		strip.shuffle()
		strips.append(strip)
		offsets[r] = randi() % strip.size() * CELL
	if embedded:
		_build_bar()
	else:
		_build()
		# Aucun bouton ne garde le focus : sinon, après un clic, le premier Échap ne fait que le retirer
		# et la machine reste ouverte, et Espace appuierait le bouton en plus de tirer le bras.
		for b in find_children("*", "Button", true, false):
			(b as Button).focus_mode = Control.FOCUS_NONE


func _build_bar() -> void:
	BARRE.style(self)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	_result = BARRE.label("Trois symboles identiques sur la ligne.", 18)
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_result)
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
	_spin_button = BARRE.main_button("  Tirer le bras  (Espace)  ")
	_spin_button.pressed.connect(spin)
	h.add_child(_spin_button)
	var leave := BARRE.pill("Quitter  (Échap)")
	leave.pressed.connect(func(): closed.emit())
	h.add_child(leave)
	_change_bet(0)


func _pick_bet(i: int) -> void:
	if spinning:
		return
	bet_index = i
	_change_bet(0)


func _build() -> void:
	custom_minimum_size = Vector2(560, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)

	var title_label := Label.new()
	title_label.text = self.title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 34)
	title_label.add_theme_color_override("font_color", Color(0.96, 0.8, 0.45))
	v.add_child(title_label)
	var sub := Label.new()
	sub.text = subtitle
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 15)
	sub.add_theme_color_override("font_color", Color(0.7, 0.65, 0.58))
	v.add_child(sub)

	var window := PanelContainer.new()
	var wsb := StyleBoxFlat.new()
	wsb.bg_color = Color(0.03, 0.02, 0.02)
	wsb.border_color = Color(0.7, 0.5, 0.25)
	wsb.set_border_width_all(3)
	wsb.set_corner_radius_all(6)
	wsb.set_content_margin_all(8)
	window.add_theme_stylebox_override("panel", wsb)
	v.add_child(window)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 8)
	window.add_child(h)
	for r in 3:
		var reel := Control.new()
		reel.custom_minimum_size = Vector2(150, CELL * 3)
		reel.clip_contents = true
		reel.draw.connect(_draw_reel.bind(r, reel))
		h.add_child(reel)
		reels.append(reel)

	_result = Label.new()
	_result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.add_theme_font_size_override("font_size", 22)
	_result.text = "Trois symboles identiques sur la ligne."
	v.add_child(_result)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	controls.add_theme_constant_override("separation", 10)
	v.add_child(controls)
	var minus := Button.new()
	minus.text = "−"
	minus.pressed.connect(func(): _change_bet(-1))
	controls.add_child(minus)
	_bet_label = Label.new()
	_bet_label.custom_minimum_size = Vector2(120, 0)
	_bet_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.add_child(_bet_label)
	var plus := Button.new()
	plus.text = "+"
	plus.pressed.connect(func(): _change_bet(1))
	controls.add_child(plus)
	_spin_button = Button.new()
	_spin_button.text = "Tirer le bras  (Espace)"
	_spin_button.pressed.connect(spin)
	controls.add_child(_spin_button)

	var pays := Label.new()
	var parts := []
	for s in PAYS:
		parts.append("%s%s%s ×%d" % [s, s, s, PAYS[s]])
	pays.text = "   ".join(parts) + "   ·   deux 7 : ×2"
	pays.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pays.add_theme_font_override("font", symbol_font)
	pays.add_theme_font_size_override("font_size", 14)
	pays.add_theme_color_override("font_color", Color(0.65, 0.62, 0.58))
	v.add_child(pays)

	var leave := Button.new()
	leave.text = "Quitter la machine  (Échap)"
	leave.pressed.connect(func(): closed.emit())
	v.add_child(leave)
	_change_bet(0)


func _change_bet(d: int) -> void:
	if spinning:
		return
	bet_index = clampi(bet_index + d, 0, BETS.size() - 1)
	_bet_label.text = "Mise : %d" % BETS[bet_index]
	if _chip_row:
		BARRE.select(_chip_row, bet_index)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_SPACE):
		spin()
		get_viewport().set_input_as_handled()
	elif embedded and event is InputEventKey and event.pressed and not event.echo \
			and event.keycode >= KEY_1 and event.keycode < KEY_1 + BETS.size():
		_pick_bet(event.keycode - KEY_1)
	elif event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


func spin() -> void:
	if spinning:
		return
	var bet: int = BETS[bet_index]
	if not game.spend(bet):
		_result.text = "Pas assez de crédits pour cette mise."
		return
	spinning = true
	_spin_button.disabled = true
	_result.text = ""
	for r in 3:
		speeds[r] = 2200.0 + r * 150.0
		stop_at[r] = randi() % strips[r].size()
	reels_started.emit()
	var t1 := 0.9
	var t2 := 1.3
	var t3 := 1.7
	if strips[0][stop_at[0]] == strips[1][stop_at[1]]:
		t3 += 1.0  # le dernier rouleau fait durer le suspense
	await _stop_reel(0, t1)
	await _stop_reel(1, t2 - t1)
	await _stop_reel(2, t3 - t2)
	var line := [strips[0][stop_at[0]], strips[1][stop_at[1]], strips[2][stop_at[2]]]
	reels_stopped.emit(line)
	var payout := 0
	if line[0] == line[1] and line[1] == line[2]:
		payout = bet * PAYS[line[0]]
	elif line.count("7") == 2:
		payout = bet * 2
	if payout > 0:
		_result.text = "Gagné : %d crédits !" % payout
		_result.add_theme_color_override("font_color", Color(1.0, 0.82, 0.4))
	else:
		_result.text = "Perdu."
		_result.add_theme_color_override("font_color", Color(0.7, 0.68, 0.65))
	played.emit(bet, payout)
	spinning = false
	_spin_button.disabled = false


func _stop_reel(r: int, after: float) -> void:
	await get_tree().create_timer(after).timeout
	Sfx.play("tick", -6.0, 0.8 + r * 0.15)
	speeds[r] = 0.0
	# Le symbole tiré se cale au milieu de la fenêtre.
	var n: int = strips[r].size()
	var goal := float((stop_at[r] - 1 + n) % n) * CELL
	var tw := create_tween()
	var from: float = fmod(offsets[r], n * CELL)
	if goal < from:
		goal += n * CELL
	tw.tween_method(_set_offset.bind(r), from, goal, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished


func _set_offset(x: float, r: int) -> void:
	offsets[r] = x
	if r < reels.size():
		reels[r].queue_redraw()


func _process(delta: float) -> void:
	for r in 3:
		if speeds[r] > 0.0:
			_set_offset(offsets[r] + speeds[r] * delta, r)


func _draw_reel(r: int, reel: Control) -> void:
	var n: int = strips[r].size()
	var w := reel.size.x
	reel.draw_rect(Rect2(Vector2.ZERO, reel.size), Color(0.93, 0.9, 0.82))
	var off: float = fmod(offsets[r], n * CELL)
	var first := int(floor(off / CELL))
	var blur: bool = speeds[r] > 0.0
	for k in range(-1, 5):
		var idx := (first + k) % n
		var y := k * CELL - fmod(off, CELL)
		var s: String = strips[r][idx]
		var col: Color = COLORS[SYMBOLS.find(s)]
		if blur:
			col.a = 0.45
		var fs := 64
		var tw := symbol_font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		reel.draw_string(symbol_font, Vector2((w - tw) / 2.0, y + CELL * 0.72), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	# Ombre de courbure du tambour.
	reel.draw_rect(Rect2(0, 0, w, CELL * 0.6), Color(0, 0, 0, 0.35))
	reel.draw_rect(Rect2(0, CELL * 2.4, w, CELL * 0.6), Color(0, 0, 0, 0.35))
	reel.draw_line(Vector2(0, CELL * 1.5), Vector2(w, CELL * 1.5), Color(0.85, 0.6, 0.2, 0.6), 2.0)
