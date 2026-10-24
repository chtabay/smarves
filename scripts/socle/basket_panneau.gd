extends PanelContainer
## Le panneau du club de basket, à l'entrée de la salle (scène du socle, fil de la salle) : ce qu'on lit
## dans le hall d'une vraie salle (demande de Guillaume du 24 octobre 2026). L'affiche du match, le
## tableau de la poule, et l'équipe par ses noms. Les notes de la semaine et les statistiques sont au
## bureau du club. Tout vient de l'autoload Basket ; la fenêtre se ferme par son bouton ou Échap.

signal closed

const OR := Color(0.83, 0.66, 0.23)
const TEXTE := Color(0.94, 0.94, 0.9)
const DOUX := Color(0.66, 0.7, 0.76)
const FOND := Color(0.08, 0.13, 0.24, 0.98)

## La commune dont on lit le club.
var commune := ""


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
	add_theme_stylebox_override("panel", st)
	var defile := ScrollContainer.new()
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.custom_minimum_size = Vector2(760, 560)
	add_child(defile)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	defile.add_child(col)
	remplir(col)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		closed.emit()


func _ligne(parent: Control, texte: String, couleur := TEXTE, taille := 16) -> Label:
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


func remplir(col: VBoxContainer) -> void:
	var b := basket()
	var club: Dictionary = b.fiche(commune)
	_ligne(col, str(club.nom).to_upper(), OR, 26)
	var ici: Array = b.place_de(commune)
	if ici.is_empty():
		_ligne(col, "Le club n'est pas encore au championnat.", DOUX)
		_fermer(col)
		return
	var n: int = ici[0]
	var g: int = ici[1]

	# L'affiche du match : le prochain, ou le score du dernier tant qu'il est frais.
	var m: Dictionary = b.match_pour_salle(commune)
	if not m.is_empty():
		var affiche := _ligne(col, ("%s %d – %d %s" % [m.dom, m.score[0], m.score[1], m.ext]) if m.fini else ("%s  –  %s\n%s" % [m.dom, m.ext, m.quand]), TEXTE, 22)
		affiche.name = "Affiche"
		affiche.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# Le tableau de la poule.
	_ligne(col, b.nom_division(n, g), OR, 18)
	var grille := GridContainer.new()
	grille.name = "Poule"
	grille.columns = 6
	grille.add_theme_constant_override("h_separation", 18)
	col.add_child(grille)
	for h in ["", "Club", "J", "V", "Écart", "Pts"]:
		_ligne(grille, h, DOUX, 14)
	var rang := 0
	for l in b.classement(b.saison, n, g):
		rang += 1
		var c := OR if l.club == commune else TEXTE
		_ligne(grille, str(rang), c, 15)
		_ligne(grille, b.fiche(l.club).nom, c, 15)
		_ligne(grille, str(l.j), c, 15)
		_ligne(grille, str(l.v), c, 15)
		_ligne(grille, "%+d" % (l.pour - l.contre), c, 15)
		_ligne(grille, str(l.pts), c, 15)

	# Le trombinoscope : les noms, sans notes ni statistiques (elles sont au bureau du club).
	if b.cliches.is_empty():
		_fermer(col)
		return
	var mm: Array = b.match_du_club(commune)
	var e: Dictionary = b.equipe(b.saison, n, g, ici[2], mm[3] if not mm.is_empty() else maxi(1, b.journee_jouee()))
	if not e.joueurs.is_empty():
		_ligne(col, "L'équipe", OR, 18)
		var trombi := GridContainer.new()
		trombi.name = "Trombinoscope"
		trombi.columns = 2
		trombi.add_theme_constant_override("h_separation", 28)
		col.add_child(trombi)
		var joueurs: Array = e.joueurs.duplicate()
		joueurs.sort_custom(func(a, x): return str(a.nom) < str(x.nom))
		for j in joueurs:
			_ligne(trombi, str(j.nom), TEXTE, 15)
	_fermer(col)


func _fermer(col: VBoxContainer) -> void:
	var bouton := Button.new()
	bouton.text = "Fermer"
	bouton.size_flags_horizontal = Control.SIZE_SHRINK_END
	bouton.pressed.connect(func(): closed.emit())
	col.add_child(bouton)
