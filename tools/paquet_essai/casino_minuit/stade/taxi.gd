extends CanvasLayer
## Le taxi de Las Vegas : un panneau laqué noir et or, où l'on choisit sa course (1, 2… ou un clic ; Échap pour
## rester). Le casino y propose l'aéroport et le stade de la Fortune ; le stade, le casino et l'aéroport.
## ouvrir(scene, joueur, titre, [[libellé, détail, Callable], …]) : le joueur est gelé tant que le panneau est ouvert.

var _joueur: Node
var _choix: Array = []
var _souris_avant := Input.MOUSE_MODE_VISIBLE


static func ouvrir(scene: Node, joueur: Node, titre: String, choix: Array) -> CanvasLayer:
	var t: CanvasLayer = load("res://communes/casino_minuit/stade/taxi.gd").new()
	t.name = "Taxi"
	t.layer = 8
	t._joueur = joueur
	t._choix = choix
	scene.add_child(t)
	t._batir(titre)
	return t


func _batir(titre: String) -> void:
	_souris_avant = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if _joueur and "frozen" in _joueur:
		_joueur.frozen = true
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("#0E0C10")
	sb.border_color = Color("#D9A441")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(26)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 18
	p.add_theme_stylebox_override("panel", sb)
	centre.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(460, 0)
	p.add_child(v)
	var damier := Label.new()
	damier.text = "▚▞▚▞▚▞▚▞  TAXI  ▚▞▚▞▚▞▚▞"
	damier.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damier.add_theme_color_override("font_color", Color("#F2C12E"))
	damier.add_theme_font_size_override("font_size", 18)
	v.add_child(damier)
	var h := Label.new()
	h.text = titre
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_theme_font_override("font", Polices.titre())
	h.add_theme_font_size_override("font_size", 26)
	h.add_theme_color_override("font_color", Color("#FFD27A"))
	v.add_child(h)
	for i in _choix.size():
		var c: Array = _choix[i]
		var b := Button.new()
		b.text = "%d.  %s\n      %s" % [i + 1, c[0], c[1]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 64)
		b.add_theme_font_size_override("font_size", 18)
		for etat in ["normal", "hover", "pressed", "focus"]:
			var s := StyleBoxFlat.new()
			s.bg_color = Color("#B3121F") if etat == "hover" or etat == "pressed" else Color("#1C171B")
			s.border_color = Color("#D9A441")
			s.set_border_width_all(1 if etat == "normal" else 2)
			s.set_corner_radius_all(6)
			s.set_content_margin_all(10)
			b.add_theme_stylebox_override(etat, s)
		b.add_theme_color_override("font_color", Color("#F3EAD7"))
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.pressed.connect(choisir.bind(i))
		v.add_child(b)
	var bas := Label.new()
	bas.text = "Échap : rester ici"
	bas.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bas.add_theme_color_override("font_color", Color("#A89880"))
	bas.add_theme_font_size_override("font_size", 14)
	v.add_child(bas)


func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	var k: int = e.keycode
	if k == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		fermer()
	elif k >= KEY_1 and k < KEY_1 + _choix.size():
		get_viewport().set_input_as_handled()
		choisir(k - KEY_1)


## La course choisie : le panneau se ferme, le taxi part.
func choisir(i: int) -> void:
	var f: Callable = _choix[i][2]
	fermer()
	f.call()


func fermer() -> void:
	if _joueur and is_instance_valid(_joueur) and "frozen" in _joueur:
		_joueur.frozen = false
	Input.mouse_mode = _souris_avant
	queue_free()
