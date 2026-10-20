extends PanelContainer
## Le fond commun des écrans du club de basket (le tableau des parts, le bureau du président) : un panneau
## bleu nuit bordé d'or, aux couleurs du panneau du club, qui tient dans l'écran et défile au-delà ; il se
## ferme par son bouton ou Échap (signal closed). La salle les ouvre plein cadre (fil de la salle) avec
## « commune », l'id de la commune du club. Tout vient de l'autoload Basket.

signal closed

const OR := Color(0.83, 0.66, 0.23)
const TEXTE := Color(0.94, 0.94, 0.9)
const DOUX := Color(0.66, 0.7, 0.76)
const ROUGE := Color(0.9, 0.45, 0.4)
const FOND := Color(0.08, 0.13, 0.24, 0.98)

## La commune dont on ouvre le club.
var commune := ""
var _colonne: VBoxContainer
var _fenetre: ScrollContainer


static func basket() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Basket")


func _ready() -> void:
	var b := basket()
	if b.niveaux.is_empty():
		b.actualiser()
	var st := StyleBoxFlat.new()
	st.bg_color = FOND
	st.border_color = OR
	st.set_border_width_all(3)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(20)
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 24
	add_theme_stylebox_override("panel", st)
	_fenetre = ScrollContainer.new()
	_fenetre.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_fenetre)
	_colonne = VBoxContainer.new()
	_colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_colonne.add_theme_constant_override("separation", 8)
	_fenetre.add_child(_colonne)
	_ajuster()
	b.change.connect(rafraichir)
	ouvert()
	rafraichir()


## À l'ouverture, avant le premier dessin (les écrans y relisent le serveur, y versent les dividendes).
func ouvert() -> void:
	pass


## Redessine la fenêtre d'après l'autoload.
func rafraichir() -> void:
	if _colonne == null:
		return
	_vider(_colonne)
	remplir(_colonne)


func remplir(_col: VBoxContainer) -> void:
	pass


func _ajuster() -> void:
	var v := get_viewport()
	var ecran: Vector2 = v.get_visible_rect().size if v != null else Vector2(1600, 900)
	_fenetre.custom_minimum_size = Vector2(minf(880.0, ecran.x - 60.0), minf(680.0, ecran.y - 80.0))


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


# ---------------------------------------------------------------- les petits outils du dessin

func _vider(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


func _mot(parent: Control, texte: String, couleur := TEXTE, taille := 16) -> Label:
	var l := Label.new()
	l.text = texte
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_font_size_override("font_size", taille)
	parent.add_child(l)
	return l


func _bouton(parent: Control, texte: String, action: Callable, nom := "") -> Button:
	var b := Button.new()
	b.text = texte
	if nom != "":
		b.name = nom
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for etat in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = Color(OR, 0.25 if etat in ["hover", "pressed"] else (0.04 if etat == "disabled" else 0.12))
		s.border_color = Color(OR, 0.4 if etat == "disabled" else 1.0)
		s.set_border_width_all(1)
		s.set_corner_radius_all(4)
		s.set_content_margin_all(6)
		s.content_margin_left = 14
		s.content_margin_right = 14
		b.add_theme_stylebox_override(etat, s)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, OR)
	b.add_theme_color_override("font_disabled_color", Color(OR, 0.4))
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _rangee(parent: Control) -> HFlowContainer:
	var h := HFlowContainer.new()
	h.add_theme_constant_override("h_separation", 10)
	h.add_theme_constant_override("v_separation", 4)
	parent.add_child(h)
	return h


func _filet(parent: Control) -> void:
	var f := ColorRect.new()
	f.color = Color(1, 1, 1, 0.1)
	f.custom_minimum_size.y = 1
	parent.add_child(f)


func _fermer(parent: Control) -> void:
	var bas := HBoxContainer.new()
	bas.alignment = BoxContainer.ALIGNMENT_END
	parent.add_child(bas)
	_bouton(bas, "Fermer  (Échap)", func(): closed.emit(), "Fermer")


## Pourquoi un acte n'a pas pu se faire, en une phrase.
static func pourquoi(raison: String) -> String:
	return {"compte": "Il faut être connecté à son compte Pyramides : le marché et les parts comptent pour tous les villages.",
		"parts": "Un autre porteur a mis plus que vous dans le club : c'est lui qui dirige.",
		"club": "Le club n'est pas au championnat.", "ferme": "C'est fermé pour cette fois.",
		"pris": "Ce joueur n'est plus libre dans le groupe.", "bas": "L'offre est trop basse.",
		"credits": "Il vous manque des crédits.", "prise": "Quelqu'un l'a prise avant vous.",
		"absente": "Celle-là n'est pas à vous.", "absent": "Ce joueur n'est pas dans l'effectif.",
		"reseau": "Le serveur ne répond pas ; réessayez dans un moment."}.get(raison, "Ça n'a pas marché.")


static func fleche(forme: int) -> String:
	return ["▼", "=", "▲"][clampi(forme, -1, 1) + 1]
