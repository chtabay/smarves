extends PanelContainer
## Le fond commun des écrans du club de basket (le tableau des parts, le bureau du président) : un panneau
## de nuit bordé de laiton, aux teintes du carnet (scripts/socle/teintes.gd), qui tient dans l'écran et
## défile au-delà ; il se ferme par la croix en haut à droite ou Échap (signal closed). La salle les ouvre plein cadre (fil de la salle) avec
## « commune », l'id de la commune du club. Tout vient de l'autoload Basket.

signal closed

const TEINTES := preload("res://scripts/socle/teintes.gd")
const AIDE := preload("res://scripts/socle/aide.gd")
const PICTOS := preload("res://scripts/socle/pictos.gd")
const OR := TEINTES.OR
const TEXTE := TEINTES.TEXTE
const DOUX := TEINTES.DOUX
const ROUGE := TEINTES.ROUGE
const VERT := TEINTES.VERT
const FOND := Color(TEINTES.NUIT, 0.98)

## La commune dont on ouvre le club.
var commune := ""
var _colonne: VBoxContainer
var _fenetre: ScrollContainer
## Le cadre qui porte le défilement et, par-dessus, la croix.
var _cadre: Control


static func basket() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Basket")


func _ready() -> void:
	var b := basket()
	if b.niveaux.is_empty():
		b.actualiser()
	var st := StyleBoxFlat.new()
	st.bg_color = FOND
	st.border_color = Color(TEINTES.LAITON, 0.7)
	st.set_border_width_all(1)
	st.set_corner_radius_all(8)
	st.set_content_margin_all(20)
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 24
	add_theme_stylebox_override("panel", st)
	_cadre = Control.new()
	add_child(_cadre)
	_fenetre = ScrollContainer.new()
	_fenetre.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_fenetre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Le défilement commence sous la croix : sa barre ne passe pas dessous.
	_fenetre.offset_top = 22.0
	_cadre.add_child(_fenetre)
	var croix: Button = preload("res://scripts/socle/croix.gd").creer(func(): closed.emit())
	_cadre.add_child(croix)
	croix.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	croix.offset_left = -24.0
	croix.offset_right = 10.0
	croix.offset_top = -14.0
	croix.offset_bottom = 20.0
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
	_cadre.custom_minimum_size = Vector2(minf(880.0, ecran.x - 60.0), minf(680.0, ecran.y - 80.0))


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
	# Seul un texte en colonne passe à la ligne : dans une rangée ou une grille, un label qui se replie n'a
	# plus de largeur et s'écrit une lettre par ligne.
	if parent is VBoxContainer:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_font_size_override("font_size", taille)
	parent.add_child(l)
	return l


func _bouton(parent: Control, texte: String, action: Callable, nom := "", picto := "") -> Button:
	var b := Button.new()
	b.text = texte
	if nom != "":
		b.name = nom
	if picto != "":
		b.icon = PICTOS.texture(picto, Color.WHITE, 18)
		b.add_theme_constant_override("h_separation", 7)
		for c in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
			b.add_theme_color_override(c, OR)
		b.add_theme_color_override("icon_disabled_color", Color(OR, 0.4))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for etat in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := StyleBoxFlat.new()
		s.bg_color = TEINTES.BOUTON.lightened(0.12) if etat in ["hover", "pressed"] else (Color(TEINTES.BOUTON, 0.3) if etat == "disabled" else TEINTES.BOUTON)
		s.border_color = Color(TEINTES.LAITON, 0.3 if etat == "disabled" else 0.6)
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


## Des tuiles à la Football Manager : un intitulé en petites capitales, un chiffre, une précision ; le
## détail dans le (i). Chaque tuile : [intitulé, chiffre, précision, couleur du chiffre, explication].
func _tuiles(parent: Control, tuiles: Array) -> HFlowContainer:
	var h := HFlowContainer.new()
	h.name = "Tuiles"
	h.add_theme_constant_override("h_separation", 8)
	h.add_theme_constant_override("v_separation", 8)
	parent.add_child(h)
	for t in tuiles:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(170, 0)
		var st := StyleBoxFlat.new()
		st.bg_color = TEINTES.CARTE
		st.set_corner_radius_all(5)
		st.content_margin_left = 12
		st.content_margin_right = 12
		st.content_margin_top = 7
		st.content_margin_bottom = 8
		p.add_theme_stylebox_override("panel", st)
		h.add_child(p)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		p.add_child(v)
		var tete := HBoxContainer.new()
		tete.add_theme_constant_override("separation", 5)
		v.add_child(tete)
		_mot(tete, str(t[0]).to_upper(), TEINTES.CRAYON, 12)
		if t.size() > 4 and str(t[4]) != "":
			tete.add_child(AIDE.creer(str(t[4])))
		_mot(v, str(t[1]), t[3] if t.size() > 3 else TEXTE, 22)
		if str(t[2]) != "":
			_mot(v, str(t[2]), DOUX, 13)
	return h


## Un tableau de comptes à deux colonnes : le libellé (et son (i)), le chiffre à droite. Chaque ligne :
## [libellé, chiffre, couleur, explication] ; une ligne vide trace un filet.
func _comptes_en_lignes(parent: Control, lignes: Array) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = "Lignes"
	v.add_theme_constant_override("separation", 4)
	parent.add_child(v)
	for l in lignes:
		if l.is_empty():
			_filet(v)
			continue
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		v.add_child(h)
		var a := _mot(h, str(l[0]), DOUX, 15)
		if l.size() > 3 and str(l[3]) != "":
			h.add_child(AIDE.creer(str(l[3])))
		var ressort := Control.new()
		ressort.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(ressort)
		var b := _mot(h, str(l[1]), l[2] if l.size() > 2 else TEXTE, 16)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		a.name = "Libelle"
	return v


## La fermeture : depuis le 25 octobre 2026, la croix en haut à droite (posée une fois, dans _ready).
func _fermer(_parent: Control) -> void:
	pass


## Pourquoi un acte n'a pas pu se faire, en une phrase.
static func pourquoi(raison: String) -> String:
	return {"compte": "Il faut être connecté à son compte Pyramides : le marché et les parts comptent pour tous les villages.",
		"parts": "Un autre porteur a mis plus que vous dans le club : c'est lui qui dirige.",
		"club": "Le club n'est pas au championnat.", "ferme": "C'est fermé pour cette fois.",
		"pris": "Ce joueur n'est plus libre dans le groupe.", "bas": "L'offre est trop basse.",
		"credits": "Il vous manque des crédits.", "prise": "Quelqu'un l'a prise avant vous.",
		"intersaison": "Le serveur n'a pas encore ouvert les parts hors de l'intersaison : réessayez dans un moment.",
		"ailleurs": "Vous dirigez déjà un club : un président n'en dirige qu'un à la fois, et n'en change qu'à la relève du lundi.",
		"saison": "Vous avez déjà changé de club dans cette période : on en change une fois pendant la saison, une fois pendant l'intersaison.",
		"absente": "Celle-là n'est pas à vous.", "absent": "Ce joueur n'est pas dans l'effectif.",
		"reseau": "Le serveur ne répond pas ; réessayez dans un moment.",
		"detenir": "Il faut tenir au moins une part du club, et le diriger, pour le renommer.",
		"nom": "Le nom doit faire de 3 à 40 caractères : lettres, chiffres, espaces, apostrophes, tirets, points ou « & »."}.get(raison, "Ça n'a pas marché.")


static func fleche(forme: int) -> String:
	return ["▼", "=", "▲"][clampi(forme, -1, 1) + 1]
