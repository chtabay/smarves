extends CanvasLayer
## Le coin d'une commune greffée, en haut à gauche (demande de Guillaume du 30 octobre 2026 : « les menus in
## game ne sont pas très élégants »). Ce n'étaient que deux boutons gris de Godot, « Revenir à Smarves » et
## « La carte (M) », en texte brut sur la vue. C'est désormais un cartouche du lieu, dans les teintes du
## compteur de crédits, de la carte et du carnet (TEINTES) : une plaque de nuit bordée de laiton qui dit
## d'abord où l'on est (le département en petites capitales, la commune en or ; la ville et le pays pour
## une destination lointaine), puis, après un filet, les deux boutons, chacun avec son picto au trait et,
## pour la carte, sa touche dessinée en petite capsule. Le cartouche tient sur une ligne, à la hauteur de
## l'ancienne rangée : ce que les paquets posent dessous (un titre, une aide, un compteur) reste dégagé.
##
## Tant qu'on est dans une commune, habit() habille aussi par défaut tout bouton qu'un paquet pose sans
## style (Communes le met sur la fenêtre) : plus de bouton gris de Godot au milieu d'un lieu.
##   _coin = COIN.new(_rentrer, func(): Carte.ouvrir())
##   _coin.poser(commune(actuelle_apres))

const TEINTES := preload("res://scripts/socle/teintes.gd")
const PICTOS := preload("res://scripts/socle/pictos.gd")

const MARGE := Vector2(16, 16)

static var _habit: Theme

var _departement: Label
var _nom: Label
var _rentrer: Button
var _carte: Button


func _init(rentrer: Callable, carte: Callable) -> void:
	layer = 90
	name = "Coin"
	var plaque := PanelContainer.new()
	plaque.name = "Plaque"
	plaque.position = MARGE
	plaque.add_theme_stylebox_override("panel", _fond())
	add_child(plaque)
	var rang := HBoxContainer.new()
	rang.name = "Rang"
	rang.add_theme_constant_override("separation", 4)
	plaque.add_child(rang)

	var lieu := VBoxContainer.new()
	lieu.alignment = BoxContainer.ALIGNMENT_CENTER
	lieu.add_theme_constant_override("separation", -3)
	var marge := MarginContainer.new()
	marge.add_theme_constant_override("margin_left", 10)
	marge.add_theme_constant_override("margin_right", 8)
	marge.add_child(lieu)
	rang.add_child(marge)
	_departement = _mot(11, TEINTES.CRAYON)
	_nom = _mot(21, TEINTES.OR)
	lieu.add_child(_departement)
	lieu.add_child(_nom)

	rang.add_child(_filet())
	_rentrer = _bouton("maison", "Revenir à Smarves", "", rentrer)
	rang.add_child(_rentrer)
	_carte = _bouton("carte", "La carte", "M", carte)
	rang.add_child(_carte)


## Habille le cartouche pour la commune où l'on entre : son nom, son département (ou sa ville et son
## pays, au loin), et le premier bouton, qui rentre en avion d'une destination lointaine.
func poser(c: Commune) -> void:
	var loin := c != null and c.lointaine()
	_nom.text = c.nom if c != null else ""
	_departement.text = _surtitre(c).to_upper()
	_departement.visible = _departement.text != ""
	_rentrer.text = "Reprendre l'avion" if loin else "Revenir à Smarves"
	_rentrer.icon = PICTOS.texture("avion" if loin else "maison", Color.WHITE, 18)


## Le petit texte au-dessus du nom : la ville et le pays d'une destination lointaine (« Las Vegas · États-Unis »),
## le département sinon (« Rhône »).
static func _surtitre(c: Commune) -> String:
	if c == null:
		return ""
	if c.lointaine():
		var parts := PackedStringArray()
		for t in [c.ville(), c.pays()]:
			if t != "":
				parts.append(t)
		return "  ·  ".join(parts)
	return str(France.departement(Departements.de(c.insee)).get("nom", ""))


## Le style des boutons sans habit d'une commune : celui des boutons du coin, sur fond de bouton du carnet.
static func habit() -> Theme:
	if _habit != null:
		return _habit
	_habit = Theme.new()
	_habit.set_font("font", "Button", Polices.gras())
	for k in ["normal", "hover", "pressed", "disabled", "focus"]:
		var st := StyleBoxFlat.new()
		st.bg_color = {"hover": TEINTES.BOUTON.lightened(0.12), "pressed": TEINTES.BOUTON.darkened(0.1),
			"disabled": Color(TEINTES.NUIT, 0.8)}.get(k, Color(TEINTES.BOUTON, 0.94))
		st.border_color = Color(TEINTES.LAITON, 0.25 if k == "disabled" else 0.6)
		st.set_border_width_all(1)
		st.set_corner_radius_all(5)
		st.content_margin_left = 14
		st.content_margin_right = 14
		st.content_margin_top = 6
		st.content_margin_bottom = 6
		if k == "focus":
			st.draw_center = false
			st.border_color = Color(TEINTES.OR, 0.7)
		_habit.set_stylebox(k, "Button", st)
	_habit.set_color("font_color", "Button", TEINTES.OR)
	_habit.set_color("font_hover_color", "Button", Color(1, 0.92, 0.7))
	_habit.set_color("font_pressed_color", "Button", Color(1, 0.92, 0.7))
	_habit.set_color("font_focus_color", "Button", TEINTES.OR)
	_habit.set_color("font_disabled_color", "Button", Color(TEINTES.CRAYON, 0.7))
	_habit.set_constant("h_separation", "Button", 8)
	return _habit


func _mot(taille: int, couleur: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_override("font", Polices.gras())
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	if taille < 14:
		# Les petites capitales espacées du surtitre, comme « S M A R V E S » au-dessus du compteur.
		var espace := FontVariation.new()
		espace.base_font = Polices.gras()
		espace.spacing_glyph = 2
		l.add_theme_font_override("font", espace)
	return l


func _filet() -> Control:
	var f := ColorRect.new()
	f.color = Color(TEINTES.LAITON, 0.3)
	f.custom_minimum_size = Vector2(1, 0)
	f.size_flags_vertical = Control.SIZE_EXPAND_FILL
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", 7)
	m.add_theme_constant_override("margin_bottom", 7)
	m.add_theme_constant_override("margin_left", 2)
	m.add_theme_constant_override("margin_right", 2)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_child(f)
	return m


## Un bouton du cartouche : son picto en or, son mot, et sa touche en capsule à droite s'il en a une.
func _bouton(picto: String, texte: String, touche: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.tooltip_text = texte + ("  (%s)" % touche if touche != "" else "")
	b.icon = PICTOS.texture(picto, Color.WHITE, 18)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", Polices.gras())
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_constant_override("h_separation", 9)
	for k in ["font_color", "font_focus_color"]:
		b.add_theme_color_override(k, TEINTES.TEXTE)
	for k in ["font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, TEINTES.OR)
	for k in ["icon_normal_color", "icon_focus_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		b.add_theme_color_override(k, TEINTES.OR)
	for k in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		var st := StyleBoxFlat.new()
		st.bg_color = {"hover": Color(TEINTES.LAITON, 0.18), "pressed": Color(TEINTES.LAITON, 0.28),
			"hover_pressed": Color(TEINTES.LAITON, 0.28)}.get(k, Color(0, 0, 0, 0))
		st.set_corner_radius_all(5)
		st.content_margin_left = 12
		st.content_margin_right = 38 if touche != "" else 14
		st.content_margin_top = 8
		st.content_margin_bottom = 8
		b.add_theme_stylebox_override(k, st)
	if touche != "":
		b.add_child(_capsule(touche))
	b.pressed.connect(action)
	return b


## La touche du raccourci, dessinée comme une touche de clavier : un liseré laiton, plus épais dessous.
func _capsule(touche: String) -> Control:
	var c := PanelContainer.new()
	c.name = "Touche"
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, 0)
	st.border_color = Color(TEINTES.LAITON, 0.5)
	st.set_border_width_all(1)
	st.border_width_bottom = 2
	st.set_corner_radius_all(4)
	st.content_margin_left = 6
	st.content_margin_right = 6
	st.content_margin_top = 0
	st.content_margin_bottom = 0
	c.add_theme_stylebox_override("panel", st)
	var l := Label.new()
	l.text = touche
	l.add_theme_font_override("font", Polices.gras())
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", TEINTES.DOUX)
	c.add_child(l)
	c.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	c.grow_vertical = Control.GROW_DIRECTION_BOTH
	c.offset_right = -12
	return c


func _fond() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(TEINTES.NUIT, 0.86)
	st.border_color = Color(TEINTES.LAITON, 0.55)
	st.set_border_width_all(1)
	st.set_corner_radius_all(7)
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 8
	st.shadow_offset = Vector2(0, 3)
	st.set_content_margin_all(4)
	return st
