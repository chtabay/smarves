extends RefCounted
## La barre de jeu posée en bas de l'écran quand on est assis à une table 3D : laque noire et or,
## jetons ronds à choisir, gros bouton bordeaux pour le coup, boutons secondaires en pastille.

const KIT := preload("res://scripts/jeux/kit.gd")
const GOLD := Color(0.89, 0.71, 0.35)
const CREAM := Color(0.95, 0.92, 0.83)
const MUTED := Color(0.73, 0.66, 0.54)


## Habille le panneau en barre basse.
static func style(p: PanelContainer) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.03, 0.035, 0.86)
	sb.border_color = Color(GOLD, 0.55)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 18
	p.add_theme_stylebox_override("panel", sb)


static func _pill(bg: Color, border: Color, radius := 22) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.anti_aliasing = true
	return sb


## Le gros bouton du coup (« Lancer la bille (Espace) »).
static func main_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", KIT.serif())
	b.add_theme_font_size_override("font_size", 22)
	b.add_theme_color_override("font_color", Color(1.0, 0.93, 0.78))
	b.add_theme_color_override("font_hover_color", Color(1, 1, 0.92))
	b.add_theme_color_override("font_disabled_color", Color(0.7, 0.6, 0.5, 0.6))
	b.add_theme_stylebox_override("normal", _pill(Color(0.48, 0.07, 0.13), GOLD, 26))
	b.add_theme_stylebox_override("hover", _pill(Color(0.6, 0.1, 0.17), Color(1.0, 0.85, 0.5), 26))
	b.add_theme_stylebox_override("pressed", _pill(Color(0.38, 0.05, 0.1), GOLD, 26))
	b.add_theme_stylebox_override("disabled", _pill(Color(0.22, 0.08, 0.1), Color(GOLD, 0.3), 26))
	b.custom_minimum_size = Vector2(0, 50)
	return b


static func pill(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 20)
	b.add_theme_color_override("font_color", CREAM)
	b.add_theme_color_override("font_hover_color", Color(1, 0.95, 0.8))
	b.add_theme_stylebox_override("normal", _pill(Color(0.1, 0.07, 0.07, 0.9), Color(GOLD, 0.4)))
	b.add_theme_stylebox_override("hover", _pill(Color(0.18, 0.12, 0.1, 0.95), Color(GOLD, 0.8)))
	b.add_theme_stylebox_override("pressed", _pill(Color(0.06, 0.04, 0.04), GOLD))
	b.add_theme_stylebox_override("disabled", _pill(Color(0.08, 0.06, 0.06, 0.6), Color(GOLD, 0.15)))
	b.custom_minimum_size = Vector2(0, 48)  # Au doigt aussi : 48 px au moins.
	return b


static func label(text := "", size := 20, col := CREAM) -> Label:
	var l := Label.new()
	l.text = text
	# Lisible au téléphone : 20 px au moins.
	l.add_theme_font_size_override("font_size", maxi(size, 20))
	l.add_theme_color_override("font_color", col)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


static func separator() -> Control:
	var s := ColorRect.new()
	s.color = Color(GOLD, 0.25)
	s.custom_minimum_size = Vector2(1, 40)
	return s


## Les jetons à choisir : un bouton rond par valeur, le jeton choisi se soulève.
## « on_pick » reçoit l'index choisi. Renvoie le conteneur ; appeler select(box, i) pour changer.
static func chip_row(values: Array, selected: int, on_pick: Callable) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	for i in values.size():
		var b := Button.new()
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(52, 60)
		b.tooltip_text = "Jeton de %s (touche %d)" % [str(values[i]), i + 1]
		b.set_meta("value", values[i])
		b.set_meta("selected", i == selected)
		var v: int = values[i]
		b.draw.connect(func(): _draw_chip(b, v, b.get_meta("selected"), b.is_hovered()))
		b.mouse_entered.connect(b.queue_redraw)
		b.mouse_exited.connect(b.queue_redraw)
		b.pressed.connect(func(): on_pick.call(i))
		h.add_child(b)
	return h


static func select(row: HBoxContainer, idx: int) -> void:
	for i in row.get_child_count():
		var b: Control = row.get_child(i)
		b.set_meta("selected", i == idx)
		b.queue_redraw()


static func _draw_chip(b: Control, value: int, selected: bool, hover: bool) -> void:
	var st: Array = KIT.chip_style(value)
	var lift := -7.0 if selected else (-2.0 if hover else 0.0)
	var c := b.size / 2.0 + Vector2(0, 4 + lift)
	var r := 23.0
	if selected:
		b.draw_circle(c, r + 4.0, Color(GOLD, 0.9))
	b.draw_circle(c + Vector2(0, 3), r, Color(0, 0, 0, 0.5))
	b.draw_circle(c, r, st[0])
	for k in 8:
		var a := TAU * k / 8.0
		b.draw_arc(c, r - 2.5, a - 0.16, a + 0.16, 6, st[1], 5.0)
	b.draw_arc(c, r * 0.68, 0, TAU, 32, Color(st[1], 0.9), 1.5, true)
	var txt := str(value) if value < 1000 else "%dK" % (value / 1000)
	var ink: Color = st[1] if st[0].get_luminance() > 0.5 else CREAM
	var fs := 17 if txt.length() <= 2 else 14
	b.draw_string(KIT.serif(), c + Vector2(-r, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, ink)


## Place la barre en bas au centre d'un calque plein écran.
static func dock(p: Control, layer: Control) -> void:
	layer.add_child(p)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 18)
	# La taille finale n'est connue qu'après la mise en page : on recentre à chaque changement.
	p.resized.connect(func(): p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_KEEP_SIZE, 18))
