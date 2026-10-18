extends PanelContainer
## Le grenier d'un logement (Biens.grenier) : ce qui est rangé en cartons, à descendre, et ce qu'on
## pourrait y monter (meubles et trouvailles pas posés, tenues pas portées, véhicules pas conduits).
## Chaque ligne a son bouton, assez grand pour le doigt.

signal closed

const INK := Color(0.12, 0.14, 0.3)
const INK_LIGHT := Color(0.32, 0.32, 0.42)
const PAPER := Color(0.96, 0.93, 0.84)

var home := ""
var _list: VBoxContainer
var _serif: Font


func _ready() -> void:
	_serif = Polices.texte()
	custom_minimum_size = Vector2(680, 560)
	var st := StyleBoxFlat.new()
	st.bg_color = PAPER
	st.border_color = Color(0.45, 0.32, 0.18)
	st.set_border_width_all(2)
	st.set_corner_radius_all(3)
	st.set_content_margin_all(22)
	add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	_label(v, "Le grenier", 26, INK, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(v, str(Biens.item(home).get("name", "")), 16, INK_LIGHT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	scroll.add_child(_list)
	var close := _button("Fermer  (Échap)", func(): closed.emit())
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(close)
	Biens.changed.connect(_refresh)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var stored: Array = Biens.grenier(home)
	var cap := Biens.capacite_grenier(home)
	_label(_list, "Rangé  ·  %d carton%s sur %d" % [stored.size(), "s" if stored.size() > 1 else "", cap], 18, INK, true)
	if stored.is_empty():
		_label(_list, "Rien pour l'instant : des poutres, de la poussière, et la place de ranger une vie.", 15, INK_LIGHT)
	for thing in stored:
		_row(Biens.name_of(thing), "Descendre", Biens.sortir.bind(home, thing), true)
	var libres: Array = Biens.rangeables()
	_label(_list, "À ranger", 18, INK, true)
	if libres.is_empty():
		_label(_list, "Tout ce que vous avez est posé, porté ou conduit.", 15, INK_LIGHT)
	var seen := {}
	for thing in libres:
		if seen.has(thing):
			continue
		seen[thing] = true
		var n: int = libres.count(thing)
		var nom := Biens.name_of(thing) if n == 1 else "%s  ×%d" % [Biens.name_of(thing), n]
		_row(nom, "Monter", Biens.ranger.bind(home, thing), stored.size() < cap)


func _row(t: String, action: String, call: Callable, enabled: bool) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	_list.add_child(h)
	var l := _label(h, t, 16, INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(_button(action, func(): call.call(), enabled))


func _label(parent: Control, t: String, size: int, color: Color, bold := false) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", Polices.gras() if bold else _serif)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _button(t: String, action: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = t
	b.disabled = not enabled
	b.custom_minimum_size = Vector2(130, 48)
	b.add_theme_font_override("font", _serif)
	b.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var s := StyleBoxFlat.new()
		s.bg_color = {"normal": Color(0.9, 0.85, 0.72), "hover": Color(0.98, 0.9, 0.7), "pressed": Color(0.85, 0.75, 0.55),
			"disabled": Color(0.9, 0.88, 0.82), "focus": Color(0, 0, 0, 0)}[state]
		s.border_color = Color(0.45, 0.32, 0.18, 0.35 if state == "disabled" else 0.9)
		s.set_border_width_all(1)
		s.set_corner_radius_all(2)
		s.content_margin_left = 12
		s.content_margin_right = 12
		b.add_theme_stylebox_override(state, s)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, INK)
	b.add_theme_color_override("font_disabled_color", INK_LIGHT)
	if not b.disabled:
		b.pressed.connect(action)
	return b
