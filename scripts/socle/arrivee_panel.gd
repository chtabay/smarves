extends "res://scripts/socle/relooking_panel.gd"
## L'arrivée à Smarves (demande de Guillaume du 25 octobre 2026) : la première fois qu'il entre sur la place,
## après la connexion au compte s'il en a une, le joueur choisit son allure, gratuitement, parmi six visages
## et six tenues (Avatar.VISAGES_ARRIVEE, Avatar.TENUES_ARRIVEE). À gauche l'aperçu du panneau des
## prestations, qui tourne ; à droite deux flèches pour le visage et deux pour la tenue, sans noms. Le reste se fait ensuite en ville, et se
## paie : Raymonde pour la tenue, Gisèle pour la coiffure, le docteur Maupas pour le visage.
## Ouvert par main.gd (_arrivee) quand la partie n'a pas encore été accueillie (Game.welcomed) : un joueur
## qui a déjà une partie ne le voit jamais.

## Le village est public (Lasso 013, page « Le village ») : dit à chaque nouveau joueur avant d'entrer.
const PUBLIC := "Le village est public : les images des pensionnaires (les agents qui jouent ici), avec les joueurs présents et leurs bulles, peuvent être montrées sur Lasso, à la page « Le village »."

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
	# Le cadre connu des participants (Lasso, doc 02, règle 4) : ce qui se passe sur la place peut être montré.
	_label(v, PUBLIC, 13, INK_LIGHT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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


## Le i-ième visage (en boucle : les flèches passent du dernier au premier).
func choisir_visage(i: int) -> void:
	visage = posmod(i, Avatar.VISAGES_ARRIVEE.size())
	_rafraichir()


func choisir_tenue(i: int) -> void:
	tenue = posmod(i, Avatar.TENUES_ARRIVEE.size())
	_rafraichir()


## Garde l'allure choisie (sans rien payer) et laisse entrer sur la place.
func entrer_a_smarves() -> void:
	Biens.relooker(Avatar.arrivee(visage, tenue), 0)
	closed.emit()


func _rafraichir() -> void:
	_essai = Avatar.arrivee(visage, tenue)
	for c in _liste.get_children():
		c.queue_free()
	var haut := Control.new()
	haut.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_liste.add_child(haut)
	_fleches("Visage", "Le visage", choisir_visage.bind(visage - 1), choisir_visage.bind(visage + 1))
	_fleches("Tenue", "La tenue", choisir_tenue.bind(tenue - 1), choisir_tenue.bind(tenue + 1))
	var bas := Control.new()
	bas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_liste.add_child(bas)
	_label(_liste, "C'est offert à l'arrivée. Ensuite, chaque retouche se paie en ville.", 14, INK_LIGHT)
	if is_instance_valid(_apercu):
		_apercu.set_look(Avatar.fiche(str(Biens.worn), _essai))


## Une ligne : son titre, et deux flèches qui font passer les choix, en boucle, sans les nommer.
func _fleches(nom: String, titre: String, avant: Callable, apres: Callable) -> void:
	var row := HBoxContainer.new()
	row.name = nom
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_liste.add_child(row)
	var moins := _button("◀", avant)
	moins.custom_minimum_size = Vector2(96, 56)
	row.add_child(moins)
	var l := _label(row, titre, 22, INK, true)
	l.custom_minimum_size.x = 180
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	var plus := _button("▶", apres)
	plus.custom_minimum_size = Vector2(96, 56)
	row.add_child(plus)


## Échap entre avec l'allure en cours : on ne reste jamais coincé devant la place.
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		entrer_a_smarves()
		get_viewport().set_input_as_handled()
