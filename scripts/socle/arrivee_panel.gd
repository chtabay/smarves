extends "res://scripts/socle/relooking_panel.gd"
## L'arrivée à Smarves (demande de Guillaume du 25 octobre 2026) : la première fois qu'il entre sur la place,
## après la connexion au compte s'il en a une, le joueur choisit son allure, gratuitement, parmi six visages
## et six tenues (Avatar.VISAGES_ARRIVEE, Avatar.TENUES_ARRIVEE). À gauche l'aperçu du panneau des
## prestations, qui tourne ; à droite les deux rangées de choix. Le reste se fait ensuite en ville, et se
## paie : Raymonde pour la tenue, Gisèle pour la coiffure, le docteur Maupas pour le visage.
## Ouvert par main.gd (_arrivee) quand la partie n'a pas encore été accueillie (Game.welcomed) : un joueur
## qui a déjà une partie ne le voit jamais.

var visage := 0
var tenue := 0


func _ready() -> void:
	_serif = Polices.texte()
	_essai = Avatar.arrivee(visage, tenue)
	custom_minimum_size = Vector2(980, 620)
	var st := StyleBoxFlat.new()
	st.bg_color = PAPER
	st.border_color = Color(0.45, 0.32, 0.18)
	st.set_border_width_all(2)
	st.set_corner_radius_all(3)
	st.set_content_margin_all(24)
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 14
	add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	_label(v, "Avant d'entrer à Smarves", 28, INK, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(v, "Choisissez votre allure. Vous la ferez retoucher en ville : Raymonde pour la tenue, Gisèle pour la coiffure, le docteur Maupas pour le visage.",
		16, INK_LIGHT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var rule := ColorRect.new()
	rule.color = Color(0.45, 0.32, 0.18, 0.6)
	rule.custom_minimum_size.y = 2
	v.add_child(rule)
	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 20)
	v.add_child(h)
	h.add_child(_vue())
	_liste = VBoxContainer.new()
	_liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_liste.add_theme_constant_override("separation", 10)
	h.add_child(_liste)
	var bas := HBoxContainer.new()
	bas.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(bas)
	var entrer := _button("Entrer à Smarves", entrer_a_smarves)
	entrer.name = "Entrer"
	entrer.custom_minimum_size = Vector2(220, 48)
	entrer.add_theme_font_size_override("font_size", 20)
	bas.add_child(entrer)
	_rafraichir()


func choisir_visage(i: int) -> void:
	visage = clampi(i, 0, Avatar.VISAGES_ARRIVEE.size() - 1)
	_rafraichir()


func choisir_tenue(i: int) -> void:
	tenue = clampi(i, 0, Avatar.TENUES_ARRIVEE.size() - 1)
	_rafraichir()


## Garde l'allure choisie (sans rien payer) et laisse entrer sur la place.
func entrer_a_smarves() -> void:
	Biens.relooker(Avatar.arrivee(visage, tenue), 0)
	closed.emit()


func _rafraichir() -> void:
	_essai = Avatar.arrivee(visage, tenue)
	for c in _liste.get_children():
		c.queue_free()
	_label(_liste, "Le visage", 19, INK, true)
	var noms: Array = []
	for i in Avatar.VISAGES_ARRIVEE:
		noms.append(Avatar.VISAGES[i][0])
	_grille("Visages", noms, visage, choisir_visage)
	_label(_liste, "La tenue", 19, INK, true)
	noms = []
	for t in Avatar.TENUES_ARRIVEE:
		noms.append(t[0])
	_grille("Tenues", noms, tenue, choisir_tenue)
	_label(_liste, "C'est offert à l'arrivée. Ensuite, chaque retouche se paie en ville.", 14, INK_LIGHT)
	if is_instance_valid(_apercu):
		_apercu.set_look(Avatar.fiche(str(Biens.worn), _essai))


## Trois colonnes de boutons, le choix en cours enfoncé.
func _grille(nom: String, noms: Array, choisi: int, action: Callable) -> void:
	var g := GridContainer.new()
	g.name = nom
	g.columns = 3
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	_liste.add_child(g)
	for i in noms.size():
		var b := _button(str(noms[i]), action.bind(i))
		b.toggle_mode = true
		b.button_pressed = i == choisi
		b.custom_minimum_size = Vector2(190, 44)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_text = false
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if i == choisi:
			var s := StyleBoxFlat.new()
			s.bg_color = Color(0.45, 0.32, 0.18)
			s.set_corner_radius_all(2)
			s.content_margin_left = 12
			s.content_margin_right = 12
			s.content_margin_top = 5
			s.content_margin_bottom = 5
			for state in ["normal", "hover", "pressed", "focus"]:
				b.add_theme_stylebox_override(state, s)
			for couleur in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
				b.add_theme_color_override(couleur, PAPER)
		g.add_child(b)


## Échap entre avec l'allure en cours : on ne reste jamais coincé devant la place.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		entrer_a_smarves()
		get_viewport().set_input_as_handled()
