class_name FootTableau
extends PanelContainer
## Le tableau du dimanche : l'ardoise du Café de la Place où Josiane écrit, à la craie, le championnat
## de la Vienne (docs/SUITE.md, section 6). Le classement de la division qu'on suit (celle du club de
## la commune d'origine, sinon la Division 1), la dernière journée jouée, la prochaine, et le prochain
## coup d'envoi. On lit, on ne joue pas : les paris viendront au comptoir. Tout vient de l'autoload
## Football ; la fenêtre se ferme par son bouton ou Échap (signal closed), comme les jeux du café.

signal closed

const OR := Color(0.96, 0.8, 0.45)
const CRAIE := Color(0.93, 0.93, 0.88)
const DOUX := Color(0.68, 0.72, 0.7)
const ARDOISE := Color(0.14, 0.2, 0.18, 0.98)
const JOURS := ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
const MOIS := ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]

## La division montrée : [niveau, groupe].
var division: Array = []


## Les autoloads, cherchés à la racine : la fenêtre se construit aussi hors du jeu (essais), où le nom
## « Football » n'est pas encore connu quand ce script se compile.
static func foot() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Football")


static func communes() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Communes")


func _ready() -> void:
	if foot().niveaux.is_empty():
		foot().actualiser()
	var st := _boite(ARDOISE, Color(0.55, 0.42, 0.25), 6, 24, 6)
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 24
	add_theme_stylebox_override("panel", st)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 10)
	add_child(colonne)
	remplir(colonne)


## Remplit la fenêtre d'après la pyramide du moment.
func remplir(colonne: VBoxContainer) -> void:
	for c in colonne.get_children():
		c.free()
	division = division_suivie()
	var n: int = division[0]
	var g: int = division[1]
	var s: int = foot().saison
	var joues: int = foot().journee_jouee()
	colonne.add_child(_mot("Le tableau du dimanche", 30, OR, Polices.gras()))
	colonne.add_child(_mot("Championnat de la Vienne  ·  saison %d  ·  %s" % [s, _periode(joues)], 17, DOUX))
	var rang := HBoxContainer.new()
	rang.add_theme_constant_override("separation", 36)
	colonne.add_child(rang)

	# À gauche, le classement de la division suivie.
	var gauche := VBoxContainer.new()
	gauche.add_theme_constant_override("separation", 6)
	rang.add_child(gauche)
	gauche.add_child(_mot(foot().nom_division(n, g), 22, CRAIE, Polices.gras()))
	gauche.add_child(_classement(s, n, g))

	# À droite, la dernière journée, la prochaine, et le coup d'envoi.
	var droite := VBoxContainer.new()
	droite.add_theme_constant_override("separation", 6)
	droite.custom_minimum_size.x = 380
	rang.add_child(droite)
	if joues > 0:
		droite.add_child(_mot("Journée %d, dimanche dernier" % joues, 22, CRAIE, Polices.gras()))
		for m in foot().journee(s, n, g, joues):
			droite.add_child(_match(m))
	else:
		droite.add_child(_mot("Pas encore de match cette saison", 22, CRAIE, Polices.gras()))
		droite.add_child(_mot("La craie attend le premier dimanche.", 16, DOUX))
	var prochain: Array = foot().prochain_coup_envoi(foot().maintenant())
	droite.add_child(_filet())
	if prochain[0] == s:
		droite.add_child(_mot("Journée %d, à venir" % prochain[1], 22, CRAIE, Polices.gras()))
		for m in foot().journee(s, n, g, prochain[1], 0):
			droite.add_child(_match(m))
	droite.add_child(_mot("Coup d'envoi : %s, à %d h." % [date(prochain[2]), foot().HEURE_COUP_ENVOI], 16, OR))

	colonne.add_child(_filet())
	colonne.add_child(_mot(mot_de_la_commune(), 16, DOUX, null, true))
	var bas := HBoxContainer.new()
	bas.alignment = BoxContainer.ALIGNMENT_END
	colonne.add_child(bas)
	bas.add_child(_bouton("Reposer la craie  (Échap)", func(): closed.emit()))


## La division qu'on suit : celle du club de la commune d'origine (Smarves) s'il existe, sinon la Division 1.
func division_suivie() -> Array:
	var origine: Commune = communes().origine()
	if origine:
		var p: Array = foot().place_de(origine.id)
		if not p.is_empty():
			return p
	return [0, 0]


## Où en est la commune d'origine : son club et sa division, ou qu'il lui manque un terrain.
func mot_de_la_commune() -> String:
	var origine: Commune = communes().origine()
	var nb := 0
	for n in foot().niveaux:
		for g in n:
			nb += g.size()
	var pyramide := "%d clubs en %s." % [nb, "une division" if foot().niveaux.size() == 1 else "%d divisions" % foot().niveaux.size()]
	if origine == null:
		return pyramide
	var p: Array = foot().place_de(origine.id)
	if p.is_empty():
		if origine.id in foot().en_attente():
			return "%s a son terrain : son club entre dans la pyramide à la saison prochaine. %s" % [origine.nom, pyramide]
		return "%s n'a pas encore de club : il lui faudrait un terrain. %s" % [origine.nom, pyramide]
	var club: Dictionary = foot().clubs[origine.id]
	return "%s joue en %s. %s" % [club.nom, foot().nom_division(p[0], p[1]), pyramide]


func _periode(joues: int) -> String:
	match foot().periode():
		"treve":
			return "trêve"
		"mercato":
			return "mercato"
	return "journée %d sur %d" % [joues, foot().JOURNEES] if joues > 0 else "avant la première journée"


## « dimanche 25 octobre » pour un instant en secondes locales.
static func date(t: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(t)
	return "%s %s %s" % [JOURS[d.weekday], "1er" if d.day == 1 else str(d.day), MOIS[d.month - 1]]


func _classement(s: int, n: int, g: int) -> GridContainer:
	var grille := GridContainer.new()
	grille.columns = 9
	grille.add_theme_constant_override("h_separation", 14)
	grille.add_theme_constant_override("v_separation", 4)
	for t in ["", "Club", "J", "G", "N", "P", "BP", "BC", "Pts"]:
		var e := _mot(t, 14, DOUX)
		e.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if t.length() <= 3 and t != "" else HORIZONTAL_ALIGNMENT_LEFT
		grille.add_child(e)
	var origine: Commune = communes().origine()
	var lignes: Array = foot().classement(s, n, g)
	for i in lignes.size():
		var l: Dictionary = lignes[i]
		var club: Dictionary = foot().clubs[l.club]
		var chez_nous: bool = origine != null and l.club == origine.id
		var encre := OR if chez_nous else CRAIE
		var rangl := _mot("%d." % (i + 1), 16, encre)
		rangl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grille.add_child(rangl)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.add_child(_couleurs(club.couleurs))
		var nom := _mot(club.nom, 16, encre, Polices.gras() if chez_nous else null)
		nom.custom_minimum_size.x = 300
		nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		h.add_child(nom)
		grille.add_child(h)
		for k in ["j", "g", "n", "p", "bp", "bc", "pts"]:
			var c := _mot(str(l[k]), 16, encre if k != "pts" else OR, Polices.gras() if k == "pts" else null)
			c.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			grille.add_child(c)
	return grille


## Le fanion d'un club : ses deux couleurs.
func _couleurs(couleurs: Array) -> Control:
	var f := PanelContainer.new()
	var st := _boite(Color.html(str(couleurs[0])), Color.html(str(couleurs[1])) if couleurs.size() > 1 else Color.TRANSPARENT, 2, 0, 2)
	f.add_theme_stylebox_override("panel", st)
	f.custom_minimum_size = Vector2(16, 16)
	f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return f


## Une ligne de match : « Union sportive d'Iteuil  2 - 1  Étoile de Smarves », ou l'heure si pas joué.
func _match(m: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var dom := _mot(foot().clubs[m.dom].court, 16, CRAIE, Polices.gras())
	dom.custom_minimum_size.x = 48
	dom.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(dom)
	var score: Array = m.score
	var milieu := _mot("%d - %d" % [score[0], score[1]] if not score.is_empty() else "–", 16, OR if not score.is_empty() else DOUX, Polices.gras())
	milieu.custom_minimum_size.x = 56
	milieu.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(milieu)
	h.add_child(_mot(foot().clubs[m.ext].court, 16, CRAIE, Polices.gras()))
	var noms := _mot("%s – %s" % [foot().clubs[m.dom].nom, foot().clubs[m.ext].nom], 13, DOUX)
	noms.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	noms.custom_minimum_size.x = 180
	noms.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(noms)
	return h


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- les petits outils du dessin

func _boite(fond: Color, bord: Color, rayon := 6, marge := 12, epaisseur := 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fond
	s.border_color = bord
	s.set_border_width_all(epaisseur if bord.a > 0 else 0)
	s.set_corner_radius_all(rayon)
	s.set_content_margin_all(marge)
	return s


func _mot(t: String, taille: int, couleur: Color, police: Font = null, replie := false) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", police if police else Polices.texte())
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	if replie:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 900
	return l


func _filet() -> ColorRect:
	var f := ColorRect.new()
	f.color = Color(1, 1, 1, 0.1)
	f.custom_minimum_size.y = 1
	return f


func _bouton(t: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", Polices.gras())
	b.add_theme_font_size_override("font_size", 16)
	for etat in ["normal", "hover", "pressed", "focus"]:
		var s := _boite(Color(OR, 0.25 if etat == "hover" or etat == "pressed" else 0.12), OR, 4, 8)
		s.content_margin_left = 18
		s.content_margin_right = 18
		b.add_theme_stylebox_override(etat, s)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, OR)
	b.pressed.connect(action)
	return b
