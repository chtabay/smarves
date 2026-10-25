extends Button
## La croix de fermeture, en haut à droite d'une fenêtre (demande de Guillaume du 25 octobre 2026 : « bouton
## de fermeture sous forme de croix en haut à droite plutôt qu'en bas de page en texte »). Un carré discret,
## qui s'éclaire au survol ; la bulle dit le raccourci.
##   const CROIX := preload("res://scripts/socle/croix.gd")
##   rangee.add_child(CROIX.creer(func(): closed.emit(), "Fermer  (Échap)"))

const TEINTES := preload("res://scripts/socle/teintes.gd")
const PICTOS := preload("res://scripts/socle/pictos.gd")


static func creer(action: Callable, bulle := "Fermer  (Échap)", cote := 34) -> Button:
	var b: Button = load("res://scripts/socle/croix.gd").new()
	b.name = "Fermer"
	b.tooltip_text = bulle
	b.custom_minimum_size = Vector2(cote, cote)
	b.icon = PICTOS.texture("fermer", Color.WHITE, int(cote * 0.6))
	b.pressed.connect(action)
	return b


func _init() -> void:
	flat = false
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	expand_icon = false
	size_flags_horizontal = Control.SIZE_SHRINK_END
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for k in ["icon_normal_color", "icon_focus_color"]:
		add_theme_color_override(k, TEINTES.DOUX)
	for k in ["icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color"]:
		add_theme_color_override(k, TEINTES.OR)
	for k in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		var st := StyleBoxFlat.new()
		st.bg_color = Color(TEINTES.LAITON, 0.18) if k in ["hover", "pressed", "hover_pressed"] else Color(0, 0, 0, 0)
		st.border_color = Color(TEINTES.LAITON, 0.5 if k in ["hover", "pressed", "hover_pressed"] else 0.0)
		st.set_border_width_all(1)
		st.set_corner_radius_all(5)
		st.set_content_margin_all(0)
		add_theme_stylebox_override(k, st)
