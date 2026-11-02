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
## La division choisie à l'ardoise (un de ses clubs suivis), [] : celle qu'on suit d'office.
var division_choisie: Array = []
## La colonne de la fenêtre : le tableau, ou la feuille d'un match.
var _colonne: VBoxContainer
## Sur un écran étroit, ce qui fait défiler la colonne.
var _fenetre: ScrollContainer
## Sur un écran étroit, la rangée du bas (les boutons) reste sous le défilement, toujours visible.
var _pied_conteneur: VBoxContainer
## La barre du haut d'un téléphone (le compteur de crédits à gauche, « Sortir » à droite) : l'ardoise
## reste en dessous, et au-dessus du bord bas d'autant.
const BARRE_HAUT := 96.0



## Les autoloads, cherchés à la racine : la fenêtre se construit aussi hors du jeu (essais), où le nom
## « Football » n'est pas encore connu quand ce script se compile.
static func foot() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Football")


static func communes() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Communes")


func _ready() -> void:
	_preparer()
	remplir(_colonne)


## L'ardoise et sa colonne. Sur un écran étroit (un téléphone : Tactile ramène la base vers 1067 × 600),
## la fenêtre tient dans l'écran et défile, les marges se serrent, les colonnes s'empilent.
func _preparer() -> void:
	if foot().niveaux.is_empty():
		foot().actualiser()
	var etroit := _etroit()
	var st := _boite(ARDOISE, Color(0.55, 0.42, 0.25), 6, 12 if etroit else 24, 6)
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 24
	add_theme_stylebox_override("panel", st)
	_colonne = VBoxContainer.new()
	_colonne.add_theme_constant_override("separation", 6 if etroit else 10)
	if etroit:
		var ext := VBoxContainer.new()
		ext.add_theme_constant_override("separation", 6)
		add_child(ext)
		_fenetre = ScrollContainer.new()
		_fenetre.name = "Fenetre"
		_fenetre.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		ext.add_child(_fenetre)
		_colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_fenetre.add_child(_colonne)
		_pied_conteneur = VBoxContainer.new()
		_pied_conteneur.name = "Pied"
		ext.add_child(_pied_conteneur)
		_colonne.minimum_size_changed.connect(_ajuster)
		_ajuster()
	else:
		add_child(_colonne)


## La rangée du bas d'une fenêtre (ses boutons), alignée à droite : dans la colonne sur un ordinateur ;
## sur un écran étroit, sous le défilement, pour qu'on la voie sans dérouler.
func _pied(colonne: VBoxContainer) -> HBoxContainer:
	var bas := HBoxContainer.new()
	bas.alignment = BoxContainer.ALIGNMENT_END
	bas.add_theme_constant_override("separation", 10)
	if _pied_conteneur != null:
		_vider(_pied_conteneur)
		_pied_conteneur.add_child(bas)
	else:
		colonne.add_child(bas)
	return bas


## Sur un écran étroit, la fenêtre prend la taille de son contenu, sans dépasser l'écran : au-delà, on défile.
func _ajuster() -> void:
	if _fenetre == null or _colonne == null:
		return
	var maxi := _ecran() - Vector2(36, 36 + 2.0 * BARRE_HAUT)
	if _pied_conteneur != null:
		maxi.y -= _pied_conteneur.get_combined_minimum_size().y + 6.0
	var taille := _colonne.get_combined_minimum_size()
	_fenetre.custom_minimum_size = Vector2(minf(taille.x + 14.0, maxi.x), minf(taille.y, maxi.y))


## L'écran, dans les unités de l'interface (1600 × 900 sur un ordinateur, moins sur un téléphone).
func _ecran() -> Vector2:
	var v := get_viewport()
	return v.get_visible_rect().size if v != null else Vector2(1600, 900)


## Un écran étroit : un téléphone, ou une petite fenêtre.
func _etroit() -> bool:
	var e := _ecran()
	return e.x < 1300.0 or e.y < 760.0


## La largeur d'un texte replié : il laisse, sur un téléphone, la place du bouton « Sortir » en haut à droite.
func _large() -> float:
	return minf(900.0, _ecran().x - 190.0)


## Remplit la fenêtre d'après la pyramide du moment.
func remplir(colonne: VBoxContainer) -> void:
	_vider(colonne)
	division = division_choisie if not division_choisie.is_empty() else division_suivie()
	var n: int = division[0]
	var g: int = division[1]
	var s: int = foot().saison
	var joues: int = foot().journee_jouee()
	colonne.add_child(_mot("Le tableau du dimanche", 30, OR, Polices.gras()))
	colonne.add_child(_mot("Championnat de la Vienne  ·  saison %d  ·  %s" % [s, _periode(joues)], 17, DOUX))
	# Vos clubs : un bouton par club suivi, qui met sa division à la craie.
	var vos: Array = clubs_suivis().filter(func(c): return not (foot().place_de(str(c)) as Array).is_empty())
	if vos.size() > 1 or (vos.size() == 1 and (foot().place_de(str(vos[0])) as Array).slice(0, 2) != division):
		var ligne := HFlowContainer.new()
		ligne.name = "VosClubs"
		ligne.add_theme_constant_override("h_separation", 8)
		ligne.add_child(_mot("Vos clubs :", 15, DOUX))
		for c in vos:
			var q: Array = foot().place_de(str(c))
			var cle: Array = [q[0], q[1]]
			var b := _bouton(str(foot().clubs[c].nom), func():
				division_choisie = cle
				remplir(colonne), 14)
			b.disabled = cle == division
			ligne.add_child(b)
		colonne.add_child(ligne)
	if not foot().locales.is_empty():
		colonne.add_child(_mot("Vos consignes d'avant-match restent sur cet appareil tant que vous n'êtes pas connecté à votre compte Pyramides : le reste du village ne les voit pas.", 15, OR, null, true))
	elif foot().consignes_etat == "hors_ligne":
		colonne.add_child(_mot("Hors ligne : les consignes des autres clubs se liront au retour du réseau.", 15, DOUX, null, true))
	var rang := HBoxContainer.new()
	rang.add_theme_constant_override("separation", 24 if _etroit() else 36)
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
	if foot().niveaux[n][g].size() < 2:
		droite.add_child(_mot("Pas de match", 22, CRAIE, Polices.gras()))
		droite.add_child(_mot("Le championnat attend un deuxième club : une commune qui déclare un terrain a son club.", 16, DOUX, null, true))
	elif joues > 0:
		droite.add_child(_mot("Journée %d, dimanche dernier" % joues, 22, CRAIE, Polices.gras()))
		for m in foot().journee(s, n, g, joues):
			droite.add_child(_match(m, s, joues))
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
	var bas := _pied(colonne)
	bas.add_child(_bouton("Reposer la craie  (Échap)", func(): closed.emit()))


## Les clubs qu'on suit (parts, puis supporter ; demande de Guillaume du 31 octobre 2026 : « où le supporter
## voit-il les résultats de son club ? partout »), [] hors du jeu.
static func clubs_suivis() -> Array:
	var racine := (Engine.get_main_loop() as SceneTree).root
	var avis: Node = racine.get_node_or_null("Avis")
	if avis == null or not avis.has_method("favoris"):
		return []
	return load("res://scripts/socle/aujourdhui.gd").suivis(foot(), avis)


## La division qu'on suit : celle du premier club qu'on suit, sinon celle du club de la commune d'origine
## (Smarves) s'il existe, sinon la Division 1.
func division_suivie() -> Array:
	for c in clubs_suivis():
		var q: Array = foot().place_de(str(c))
		if not q.is_empty():
			return [q[0], q[1]]
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
		var chez_nous: bool = (origine != null and l.club == origine.id) or clubs_suivis().has(l.club)
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


## Une ligne de match : « USI  2 - 1  ESM », les noms en petit, et la feuille du match s'il est joué.
func _match(m: Dictionary, s := 0, j := 0) -> Control:
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
	if not score.is_empty() and j > 0:
		var b := _bouton("la feuille", func(): ouvrir_feuille(s, j, m.dom, m.ext), 13)
		b.name = "Feuille_%s_%s" % [m.dom, m.ext]
		h.add_child(b)
	return h


# ---------------------------------------------------------------- la feuille d'un match

## Les occasions d'une équipe par couloir, « 3 · 6 · 2 » de gauche à droite.
static func _couloirs(st: Dictionary) -> String:
	var c: Dictionary = st.get("couloirs", {})
	return "%d · %d · %d" % [int(c.get("gauche", 0)), int(c.get("centre", 0)), int(c.get("droite", 0))]


## La feuille d'un match joué : le score, les buteurs, les chiffres, et le match minute par minute tel
## que le commentateur l'a raconté. Le match lui-même ne se suit qu'en direct, au stade.
func ouvrir_feuille(s: int, j: int, dom: String, ext: String) -> void:
	_vider(_colonne)
	var etat: Dictionary = foot().rencontre(s, j, dom, ext)
	var cd: Dictionary = foot().clubs[dom]
	var ce: Dictionary = foot().clubs[ext]
	var haut := HBoxContainer.new()
	haut.add_theme_constant_override("separation", 14)
	_colonne.add_child(haut)
	haut.add_child(_couleurs(cd.couleurs))
	var etroit := _etroit()
	var titre := _mot("%s  %d - %d  %s" % [cd.nom, etat.score[0], etat.score[1], ce.nom], 22 if etroit else 28, OR, Polices.gras(), etroit)
	if etroit:
		titre.custom_minimum_size.x = _large() - 60.0
	haut.add_child(titre)
	haut.add_child(_couleurs(ce.couleurs))
	_colonne.add_child(_mot("Journée %d de la saison %d  ·  %s  ·  %s" % [j, s, etat.stade, foot().nom_division(division[0], division[1])], 16, DOUX))

	var rang := HBoxContainer.new()
	rang.add_theme_constant_override("separation", 20 if etroit else 36)
	_colonne.add_child(rang)
	# Les buteurs, de part et d'autre.
	var joueurs := {}
	joueurs.merge(foot().effectif(dom, s, j))
	joueurs.merge(foot().effectif(ext, s, j))
	for i in 2:
		var col := VBoxContainer.new()
		col.custom_minimum_size.x = 250 if etroit else 300
		rang.add_child(col)
		col.add_child(_mot("Buts %s" % [cd.court if i == 0 else ce.court], 16, CRAIE, Polices.gras()))
		var aucun := true
		for b in etat.buts:
			if b.equipe != i:
				continue
			aucun = false
			var ligne := "%s  %s" % [b.minute, FootMatch.nom_court(joueurs[b.buteur])]
			if b.penalty:
				ligne += " (pén.)"
			elif b.passeur != null:
				ligne += "  (passe de %s)" % FootMatch.nom_court(joueurs[b.passeur])
			col.add_child(_mot(ligne, 14, CRAIE))
		if aucun:
			col.add_child(_mot("–", 14, DOUX))
	# Les chiffres du match.
	var chiffres := GridContainer.new()
	chiffres.columns = 3
	chiffres.add_theme_constant_override("h_separation", 18)
	chiffres.add_theme_constant_override("v_separation", 2)
	rang.add_child(chiffres)
	var poss: Array = FootMatch.possession(etat)
	var st: Array = etat.stats
	for ligne in [["%d %%" % poss[0], "possession", "%d %%" % poss[1]], [str(st[0].tirs), "tirs", str(st[1].tirs)],
			[str(st[0].cadres), "cadrés", str(st[1].cadres)], [str(st[0].corners), "corners", str(st[1].corners)],
			[str(st[0].get("coups_francs", 0)), "coups francs", str(st[1].get("coups_francs", 0))],
			[_couloirs(st[0]), "par couloir", _couloirs(st[1])],
			[str(st[0].fautes), "fautes", str(st[1].fautes)], ["%d / %d" % [st[0].jaunes, st[0].rouges], "cartons", "%d / %d" % [st[1].jaunes, st[1].rouges]]]:
		var a := _mot(ligne[0], 14, CRAIE, Polices.gras())
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		a.custom_minimum_size.x = 60
		chiffres.add_child(a)
		chiffres.add_child(_mot(ligne[1], 13, DOUX))
		chiffres.add_child(_mot(ligne[2], 14, CRAIE, Polices.gras()))

	_colonne.add_child(_filet())
	_colonne.add_child(_mot("Le match minute par minute", 18, CRAIE, Polices.gras()))
	var recit := VBoxContainer.new()
	recit.add_theme_constant_override("separation", 2)
	recit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if etroit:
		# Toute la fenêtre défile déjà : le récit s'y déroule en entier.
		recit.name = "Recit"
		_colonne.add_child(recit)
	else:
		var defile := ScrollContainer.new()
		defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		defile.custom_minimum_size = Vector2(980, 260)
		defile.name = "Recit"
		_colonne.add_child(defile)
		defile.add_child(recit)
	for ev in etat.evenements:
		recit.add_child(_evenement(ev))

	var bas := _pied(_colonne)
	bas.add_child(_bouton("Retour au tableau", func(): remplir(_colonne)))
	bas.add_child(_bouton("Reposer la craie  (Échap)", func(): closed.emit()))


## Une ligne du récit : la minute, puis la phrase ; les buts à l'or, les cartons rouges en rouge.
func _evenement(ev: Dictionary) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var minute := _mot(str(ev.minute), 13, DOUX)
	minute.custom_minimum_size.x = 48
	minute.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(minute)
	var encre := CRAIE
	var police: Font = null
	match str(ev.type):
		"but":
			encre = OR
			police = Polices.gras()
		"rouge":
			encre = Color(0.95, 0.4, 0.35)
		"jaune":
			encre = Color(0.95, 0.85, 0.4)
		"ambiance", "info":
			encre = DOUX
	var texte := _mot(str(ev.texte), 14, encre, police, true)
	texte.custom_minimum_size.x = minf(860.0, _ecran().x - 150.0)
	h.add_child(texte)
	return h


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		closed.emit()
		get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- les petits outils du dessin

## Vide un conteneur sans libérer un bouton pendant son propre signal.
func _vider(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()


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
		l.custom_minimum_size.x = _large()
	return l


func _filet() -> ColorRect:
	var f := ColorRect.new()
	f.color = Color(1, 1, 1, 0.1)
	f.custom_minimum_size.y = 1
	return f


func _bouton(t: String, action: Callable, taille := 16) -> Button:
	var b := Button.new()
	b.text = t
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", Polices.gras())
	b.add_theme_font_size_override("font_size", taille)
	for etat in ["normal", "hover", "pressed", "focus"]:
		var s := _boite(Color(OR, 0.25 if etat == "hover" or etat == "pressed" else 0.12), OR, 4, 8)
		s.content_margin_left = 18
		s.content_margin_right = 18
		b.add_theme_stylebox_override(etat, s)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, OR)
	b.pressed.connect(action)
	return b
