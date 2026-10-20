extends PanelContainer
## Deux jeux de roue d'Addict, dans le même panneau :
## - « roue » : la Roue de la fortune, 54 cases (1, 2, 5, 10, 20, Joker et Étoile à 40) ;
## - « boule » : la Boule, 9 numéros ; un numéro paie 7 contre 1, les chances simples 1 contre 1,
##   et le 5, numéro de la maison, fait perdre toutes les chances simples.

signal played(bet: int, payout: int)
signal closed
## Pour la table 3D : la case tirée (index dans « segments ») et la durée du lancer, les mises posées,
## et le coup réglé (ce que rend chaque mise, mise comprise).
signal spin_started(index: int, duration: float)
signal bets_changed(bets: Dictionary)
signal settled(result: String, wins: Dictionary)

const BARRE := preload("res://scripts/jeux/barre.gd")
const REGLES := preload("res://scripts/jeux/regles.gd")

const CHIPS := [10, 20, 100, 500]
const ROUE_COUNTS := {"1": 24, "2": 15, "5": 7, "10": 4, "20": 2, "Joker": 1, "Étoile": 1}
const ROUE_PAYS := {"1": 1, "2": 2, "5": 5, "10": 10, "20": 20, "Joker": 40, "Étoile": 40}
const ROUE_COLORS := {"1": Color(0.95, 0.85, 0.3), "2": Color(0.3, 0.6, 0.95), "5": Color(0.85, 0.3, 0.6),
	"10": Color(0.3, 0.8, 0.45), "20": Color(0.95, 0.5, 0.2), "Joker": Color(0.1, 0.1, 0.12), "Étoile": Color(0.95, 0.95, 0.95)}
const BOULE_RED := [1, 3, 6, 8]  # le 5 est jaune, à la maison

var mode := "roue"
var title := "La Roue de la fortune"
var chip_index := 0
var bets := {}
var busy := false
var segments: Array = []
var _angle := 0.0
var _wheel: Control
var _info: Label
var _chip_label: Label
var _buttons := {}
var _font: Font
## Assis à la table 3D : on mise sur le tapis, le panneau devient une barre basse.
var embedded := false
var table3d: Node
var _chip_row: HBoxContainer
var _total_label: Label


func _ready() -> void:
	_font = get_theme_default_font()
	make_segments()
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
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)
	_wheel = Control.new()
	_wheel.custom_minimum_size = Vector2(260, 260)
	_wheel.draw.connect(_draw_wheel)
	h.add_child(_wheel)
	var grid := GridContainer.new()
	grid.columns = 3 if mode == "roue" else 5
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	h.add_child(grid)
	var keys: Array = ROUE_COUNTS.keys() if mode == "roue" else ["1", "2", "3", "4", "5", "6", "7", "8", "9", "rouge", "noir", "pair", "impair", "manque", "passe"]
	for k in keys:
		var b := Button.new()
		b.custom_minimum_size = Vector2(150 if mode == "roue" else 96, 46)
		b.set_meta("label", _label_for(k))
		b.text = _label_for(k)
		b.pressed.connect(_place.bind(k))
		grid.add_child(b)
		_buttons[k] = b
	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 20)
	_info.text = "Misez, puis lancez la roue." if mode == "roue" else "Misez, puis lancez la boule. Le 5 est à la maison."
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
	var spin_b := Button.new()
	spin_b.text = "Lancer  (Espace)"
	spin_b.pressed.connect(_spin)
	controls.add_child(spin_b)
	controls.add_child(REGLES.bouton(self, "roue", false))
	var leave := Button.new()
	leave.text = "Quitter (Échap)"
	leave.pressed.connect(_leave)
	controls.add_child(leave)
	_chip(0)


## Les cases de la roue (la table 3D les lit avant que le panneau soit affiché).
func make_segments() -> void:
	if not segments.is_empty():
		return
	if mode == "roue":
		for k in ROUE_COUNTS:
			for i in ROUE_COUNTS[k]:
				segments.append(k)
		segments.shuffle()
	else:
		for n in range(1, 10):
			segments.append(str(n))


## La barre basse : jetons, mises sur le tapis, message du croupier, lancer.
func _build_bar() -> void:
	BARRE.style(self)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	_info = BARRE.label("Misez en touchant le tapis, puis lancez la roue." if mode == "roue" else "Misez en touchant le tapis, puis lancez la boule. Le 5 est à la maison.", 20, BARRE.CREAM)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_override("font", BARRE.KIT.serif())
	v.add_child(_info)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)
	_chip_row = BARRE.chip_row(CHIPS, chip_index, _pick_chip)
	h.add_child(_chip_row)
	_chip_label = BARRE.label("", 20, BARRE.MUTED)
	_chip_label.custom_minimum_size = Vector2(110, 0)
	h.add_child(_chip_label)
	h.add_child(BARRE.separator())
	_total_label = BARRE.label("Sur le tapis : 0", 20, BARRE.CREAM)
	_total_label.custom_minimum_size = Vector2(170, 0)
	h.add_child(_total_label)
	var clear := BARRE.pill("Retirer")
	clear.pressed.connect(_clear)
	h.add_child(clear)
	var go := BARRE.main_button("  Lancer la roue  (Espace)  " if mode == "roue" else "  Lancer la boule  (Espace)  ")
	go.pressed.connect(_spin)
	h.add_child(go)
	h.add_child(REGLES.bouton(self, "roue"))
	var leave := BARRE.pill("Quitter  (Échap)")
	leave.pressed.connect(_leave)
	h.add_child(leave)
	_chip(0)


func _pick_chip(i: int) -> void:
	chip_index = i
	_chip(0)


## Les mises reviennent au joueur (bouton Retirer, ou en quittant la table).
func _clear() -> void:
	if busy:
		return
	for k in bets:
		Game.credits += bets[k]
		Game.staked -= bets[k]
	bets.clear()
	Game.changed.emit()
	_show_bets()


func _leave() -> void:
	if busy:
		return
	_clear()
	closed.emit()


func _show_bets() -> void:
	for k in _buttons:
		_buttons[k].text = _buttons[k].get_meta("label") + ("  ●%d" % bets[k] if bets.has(k) else "")
	if embedded:
		var t := 0
		for k in bets:
			t += bets[k]
		_total_label.text = "Sur le tapis : %s" % Game.fmt(t)
		bets_changed.emit(bets.duplicate())


func _label_for(k: String) -> String:
	if mode == "roue":
		return "%s  ·  %d contre 1" % [k, ROUE_PAYS[k]]
	match k:
		"rouge": return "Rouge"
		"noir": return "Noir"
		"pair": return "Pair"
		"impair": return "Impair"
		"manque": return "Manque 1–4"
		"passe": return "Passe 6–9"
	return k


func _chip(d: int) -> void:
	chip_index = clampi(chip_index + d, 0, CHIPS.size() - 1)
	_chip_label.text = "Jeton : %d" % CHIPS[chip_index]
	if _chip_row:
		BARRE.select(_chip_row, chip_index)


func _place(k: String) -> void:
	if busy:
		return
	if not Game.spend(CHIPS[chip_index]):
		_info.text = "Pas assez de crédits pour ce jeton."
		return
	bets[k] = bets.get(k, 0) + CHIPS[chip_index]
	_show_bets()


func _spin() -> void:
	if busy or bets.is_empty():
		if bets.is_empty():
			_info.text = "Posez d'abord une mise."
		return
	busy = true
	var n := segments.size()
	var idx := randi() % n
	var step := TAU / n
	# Le pointeur est en haut (angle -PI/2) : on cale la case tirée dessous.
	var target := -PI / 2.0 - idx * step
	while target < _angle + TAU * 4.0:
		target += TAU
	if embedded:
		# La roue (ou la boule) tourne sur la table ; le coup se règle quand elle s'arrête.
		var dur: float = table3d.spin_time if table3d else 3.6
		_info.text = "La roue tourne." if mode == "roue" else "La boule roule."
		spin_started.emit(idx, dur)
		await get_tree().create_timer(dur).timeout
	else:
		spin_started.emit(idx, 3.6)
		var tw := create_tween()
		tw.tween_method(func(a): _angle = a; _wheel.queue_redraw(), _angle, target, 3.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
		await tw.finished
	var result: String = segments[idx]
	var total := 0
	var payout := 0
	var wins := {}
	for k in bets:
		total += bets[k]
		var w: int = bets[k] * _mult(k, result)
		if w > 0:
			wins[k] = w
		payout += w
	settled.emit(result, wins)
	bets.clear()
	_show_bets()
	_info.text = "%s. %s" % [result if mode == "roue" else "Le %s" % result, "Vous encaissez %s." % Game.fmt(payout) if payout > 0 else "Le hasard prépare la suite."]
	busy = false
	played.emit(total, payout)


## Ce que rend une mise gagnante, mise comprise.
func _mult(k: String, r: String) -> int:
	if mode == "roue":
		return ROUE_PAYS[k] + 1 if k == r else 0
	var n := int(r)
	if k.is_valid_int():
		return 8 if int(k) == n else 0
	if n == 5:
		return 0
	match k:
		"rouge": return 2 if n in BOULE_RED else 0
		"noir": return 2 if not (n in BOULE_RED) else 0
		"pair": return 2 if n % 2 == 0 else 0
		"impair": return 2 if n % 2 == 1 else 0
		"manque": return 2 if n <= 4 else 0
		"passe": return 2 if n >= 6 else 0
	return 0


func _draw_wheel() -> void:
	var c := _wheel.size / 2.0
	var r := minf(c.x, c.y) - 10.0
	_wheel.draw_circle(c, r + 8.0, Color(0.85, 0.66, 0.3))
	var n := segments.size()
	var step := TAU / n
	for i in n:
		var s: String = segments[i]
		var a0 := _angle + i * step - step / 2.0
		var pts := PackedVector2Array([c])
		for k in 4:
			var a := a0 + step * k / 3.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		var col: Color
		if mode == "roue":
			col = ROUE_COLORS[s]
		else:
			var num := int(s)
			col = Color(0.95, 0.8, 0.2) if num == 5 else (Color(0.72, 0.08, 0.1) if num in BOULE_RED else Color(0.08, 0.08, 0.09))
		_wheel.draw_colored_polygon(pts, col)
		if mode == "boule" or n < 60:
			var am := _angle + i * step
			var tp := c + Vector2(cos(am), sin(am)) * (r * 0.78)
			_wheel.draw_set_transform(tp, am + PI / 2.0)
			var txt := s if s.length() <= 2 else s.substr(0, 1)
			_wheel.draw_string(_font, Vector2(-8, 5), txt, HORIZONTAL_ALIGNMENT_CENTER, 16, 11 if mode == "roue" else 18,
				Color(0, 0, 0) if mode == "roue" and s != "Joker" else Color(1, 1, 1))
			_wheel.draw_set_transform(Vector2.ZERO)
	_wheel.draw_circle(c, r * 0.22, Color(0.85, 0.66, 0.3))
	# Le pointeur en haut.
	_wheel.draw_colored_polygon(PackedVector2Array([c + Vector2(-10, -r - 12), c + Vector2(10, -r - 12), c + Vector2(0, -r + 10)]), Color(0.95, 0.95, 0.95))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_spin()
		get_viewport().set_input_as_handled()
	elif embedded and event is InputEventKey and event.pressed and event.keycode >= KEY_1 and event.keycode < KEY_1 + CHIPS.size():
		chip_index = event.keycode - KEY_1
		_chip(0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_leave()
		get_viewport().set_input_as_handled()
