extends PanelContainer
## Le craps, d'après Addict : Pass Line et Don't Pass (le 12 rend la mise côté Don't), Field (2 double,
## 12 triple), Place 6 et 8 à 7 contre 6, Any Seven 4 contre 1, Any Craps 7 contre 1.

signal played(bet: int, payout: int)
signal closed
signal dice_rolled(values: Array)
## Pour la table 3D : les mises posées (clé -> montant), et le coup réglé (somme, ce que rapporte
## chaque case gagnante, et l'annonce du croupier).
signal bets_changed(bets: Dictionary)
signal settled(total: int, wins: Dictionary, call: String)

const BARRE := preload("res://scripts/jeux/barre.gd")

const CHIPS := [5, 25, 100, 500]
const FACES := ["⚀", "⚁", "⚂", "⚃", "⚄", "⚅"]
const NAMES := {"pass": "Pass Line", "dont": "Don't Pass", "field": "Field  2·3·4·9·10·11·12",
	"place6": "Place 6", "place8": "Place 8", "seven": "Any Seven", "craps": "Any Craps"}

var title := "Craps"
var chip_index := 0
var bets := {}
var point := 0
var busy := false
var _dice: Label
var _point_label: Label
var _info: Label
var _chip_label: Label
var _buttons := {}
var _font: Font
## Debout à la table 3D : on mise sur le tapis, le panneau devient une barre basse.
var embedded := false
var table3d: Node
var _chip_row: HBoxContainer
var _total_label: Label
var _wins := {}


func _ready() -> void:
	_font = Polices.texte()
	if embedded:
		_build_bar()
		return
	custom_minimum_size = Vector2(860, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var t := Label.new()
	t.text = title
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 30)
	t.add_theme_color_override("font_color", Color(0.96, 0.8, 0.45))
	v.add_child(t)
	_point_label = Label.new()
	_point_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_point_label.add_theme_font_size_override("font_size", 18)
	v.add_child(_point_label)
	_dice = Label.new()
	_dice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dice.add_theme_font_override("font", _font)
	_dice.add_theme_font_size_override("font_size", 90)
	_dice.text = "⚂ ⚃"
	v.add_child(_dice)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	var center := CenterContainer.new()
	center.add_child(grid)
	v.add_child(center)
	for k in ["pass", "dont", "field", "place6", "place8", "seven", "craps"]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(195, 46)
		b.pressed.connect(_place.bind(k))
		grid.add_child(b)
		_buttons[k] = b
	_info = Label.new()
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info.add_theme_font_size_override("font_size", 20)
	_info.text = "Misez sur la Pass Line, puis lancez les dés."
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
	roll.text = "Lancer les dés  (Espace)"
	roll.pressed.connect(_roll)
	controls.add_child(roll)
	var leave := Button.new()
	leave.text = "Quitter (Échap)"
	leave.pressed.connect(_leave)
	controls.add_child(leave)
	_chip(0)
	_refresh()


## La barre basse : jetons, mises sur le tapis, message du croupier, lancer.
func _build_bar() -> void:
	BARRE.style(self)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	add_child(v)
	_info = BARRE.label("Misez sur la Pass Line en cliquant sur le tapis, puis lancez les dés.", 18, BARRE.CREAM)
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
	_chip_label.custom_minimum_size = Vector2(92, 0)
	h.add_child(_chip_label)
	h.add_child(BARRE.separator())
	_point_label = BARRE.label("", 16, BARRE.GOLD)
	_point_label.custom_minimum_size = Vector2(130, 0)
	h.add_child(_point_label)
	_total_label = BARRE.label("", 16, BARRE.CREAM)
	_total_label.custom_minimum_size = Vector2(150, 0)
	h.add_child(_total_label)
	var roll := BARRE.main_button("  Lancer les dés  (Espace)  ")
	roll.pressed.connect(_roll)
	h.add_child(roll)
	var leave := BARRE.pill("Quitter  (Échap)")
	leave.pressed.connect(_leave)
	h.add_child(leave)
	_chip(0)
	_refresh()


func _pick_chip(i: int) -> void:
	chip_index = i
	_chip(0)


func _chip(d: int) -> void:
	chip_index = clampi(chip_index + d, 0, CHIPS.size() - 1)
	_chip_label.text = "Jeton : %d" % CHIPS[chip_index]
	if _chip_row:
		BARRE.select(_chip_row, chip_index)


func _place(key: String) -> void:
	if busy:
		return
	if (key == "pass" or key == "dont") and point != 0:
		_info.text = "La ligne se joue au premier lancer, avant qu'un point soit établi."
		return
	if not Game.spend(CHIPS[chip_index]):
		_info.text = "Pas assez de crédits pour ce jeton."
		return
	bets[key] = bets.get(key, 0) + CHIPS[chip_index]
	_refresh()


func _refresh() -> void:
	for k in _buttons:
		_buttons[k].text = NAMES[k] + ("  ·  %d" % bets[k] if bets.has(k) else "")
	_point_label.text = "Premier lancer" if point == 0 else "Le point est %d" % point
	if embedded:
		var t := 0
		for k in bets:
			t += bets[k]
		_total_label.text = "Sur le tapis : %s" % Game.fmt(t)
		bets_changed.emit(bets.duplicate())


func _roll() -> void:
	if busy:
		return
	if bets.is_empty():
		_info.text = "Posez d'abord une mise."
		return
	busy = true
	Sfx.play("shake", -4.0)
	var a := randi_range(1, 6)
	var b := randi_range(1, 6)
	var s := a + b
	if embedded:
		# Les dés roulent sur la table : le coup se règle quand ils sont posés.
		_info.text = "Les dés roulent."
		dice_rolled.emit([a, b])
		await get_tree().create_timer(table3d.throw_time if table3d else 1.6).timeout
		Sfx.play("dice", -4.0)
	else:
		for i in 10:
			_dice.text = "%s %s" % [FACES.pick_random(), FACES.pick_random()]
			await get_tree().create_timer(0.05 + i * 0.015).timeout
		Sfx.play("dice", -4.0)
		dice_rolled.emit([a, b])
		_dice.text = "%s %s" % [FACES[a - 1], FACES[b - 1]]
	var wins := {}
	_wins = wins
	var paid := 0
	var resolved := 0
	var notes: Array[String] = []
	# Paris d'un seul lancer.
	if bets.has("field"):
		var f: int = bets["field"]
		resolved += f
		var fm := 2 if s in [3, 4, 9, 10, 11] else (3 if s == 2 else (4 if s == 12 else 0))
		if fm > 0:
			paid += f * fm
			wins["field"] = f * fm
		bets.erase("field")
	if bets.has("seven"):
		resolved += bets["seven"]
		if s == 7:
			paid += bets["seven"] * 5
			wins["seven"] = bets["seven"] * 5
		bets.erase("seven")
	if bets.has("craps"):
		resolved += bets["craps"]
		if s in [2, 3, 12]:
			paid += bets["craps"] * 8
			wins["craps"] = bets["craps"] * 8
		bets.erase("craps")
	# La ligne.
	if point == 0:
		if s in [7, 11]:
			paid += _settle("pass", 2)
			resolved += _settle_lose("dont")
			notes.append("Natural")
		elif s in [2, 3]:
			resolved += _settle_lose("pass")
			paid += _settle("dont", 2)
			notes.append("Craps")
		elif s == 12:
			resolved += _settle_lose("pass")
			paid += _settle("dont", 1)
			notes.append("Craps, le 12 rend le Don't")
		else:
			point = s
			notes.append("Le point est %d" % s)
	else:
		if s == point:
			paid += _settle("pass", 2)
			resolved += _settle_lose("dont")
			notes.append("Le point est fait")
			point = 0
		elif s == 7:
			resolved += _settle_lose("pass")
			paid += _settle("dont", 2)
			resolved += _settle_lose("place6") + _settle_lose("place8")
			notes.append("Seven out")
			point = 0
		# Les cases Place travaillent quand un point est établi.
		if point != 0 or s != 7:
			for n in [6, 8]:
				var k := "place%d" % n
				if s == n and bets.has(k):
					paid += bets[k] * 7 / 6
					wins[k] = bets[k] * 7 / 6
	var call := ", ".join(notes) if notes.size() > 0 else "Rien de décidé"
	settled.emit(s, wins, call)
	_refresh()
	_info.text = "%d. %s.%s" % [s, call, " Vous encaissez %s." % Game.fmt(paid) if paid > 0 else ""]
	busy = false
	played.emit(resolved, paid)


## Rend la mise multipliée (2 = gagné à égalité de mise) et retire le pari.
func _settle(key: String, mult: int) -> int:
	if not bets.has(key):
		return 0
	var v: int = bets[key] * mult
	bets.erase(key)
	_wins[key] = v
	return v


func _settle_lose(key: String) -> int:
	if not bets.has(key):
		return 0
	var v: int = bets[key]
	bets.erase(key)
	return v


## En quittant la table, on reprend ses mises encore sur le tapis.
func _leave() -> void:
	for k in bets:
		Game.credits += bets[k]
		Game.staked -= bets[k]
	bets.clear()
	Game.changed.emit()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		_roll()
		get_viewport().set_input_as_handled()
	elif embedded and event is InputEventKey and event.pressed and event.keycode >= KEY_1 and event.keycode < KEY_1 + CHIPS.size():
		chip_index = event.keycode - KEY_1
		_chip(0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		_leave()
		get_viewport().set_input_as_handled()
