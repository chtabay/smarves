extends PanelContainer
## Le panneau du club de basket, à l'entrée de la salle (scène du socle, fil de la salle) : le groupe et son
## classement, le dernier match et le prochain, et l'effectif de vrais joueurs avec leur note de la
## semaine, leur forme et leur dernier match réel. On lit, on ne décide rien : le mercato viendra au
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
	var jj: int = b.journee_jouee()
	_ligne(col, "Saison %d · niveau %d%s · %d journée%s jouée%s sur %d" % [b.saison, n + 1,
		" (groupe %d)" % (g + 1) if b.niveaux[n].size() > 1 else "", jj, "s" if jj > 1 else "", "s" if jj > 1 else "", b.JOURNEES], DOUX)
	if b.cliches.is_empty():
		_ligne(col, "Les notes des joueurs ne sont pas encore arrivées : il faut être connecté une première fois.", DOUX)
		_fermer(col)
		return

	# Le classement du groupe.
	var grille := GridContainer.new()
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

	# Le match du moment.
	var m: Dictionary = b.match_pour_salle(commune)
	if not m.is_empty():
		if m.fini:
			_ligne(col, "%s %d – %d %s" % [m.dom, m.score[0], m.score[1], m.ext], TEXTE, 20)
		else:
			_ligne(col, "Prochain match : %s – %s, %s" % [m.dom, m.ext, m.quand], TEXTE, 18)

	# L'effectif, avec la note de la semaine.
	var mm: Array = b.match_du_club(commune)
	var e: Dictionary = b.equipe(b.saison, n, g, ici[2], mm[3] if not mm.is_empty() else maxi(1, jj))
	_ligne(col, "L'effectif (notes de la semaine, de 1 à 99)", OR, 18)
	var joueurs: Array = e.joueurs.duplicate()
	joueurs.sort_custom(func(a, x): return a.note > x.note)
	for j in joueurs:
		var fleche: String = ["▼", "=", "▲"][int(j.get("forme", 0)) + 1]
		var d: Dictionary = j.get("derniere", {})
		var reel := ""
		if not d.is_empty():
			reel = " — %s : %d pts, %d reb, %d pd (PIR %d) contre %s" % [d.date, d.pts, d.reb, d.pd, d.pir, d.adv]
		var etat := "" if j.dispo else " · indisponible"
		_ligne(col, "%d %s  %s (%s)%s%s" % [j.note, fleche, j.nom, j.get("club", "?"), etat, reel], TEXTE if j.dispo else DOUX, 14)
	_fermer(col)


func _fermer(col: VBoxContainer) -> void:
	var bouton := Button.new()
	bouton.text = "Fermer"
	bouton.size_flags_horizontal = Control.SIZE_SHRINK_END
	bouton.pressed.connect(func(): closed.emit())
	col.add_child(bouton)
