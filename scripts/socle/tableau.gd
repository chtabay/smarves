extends CanvasLayer
## Le panneau d'affichage de la mairie et la porte des maisons des autres (autoload « Tableau »), étape 2
## du multi : ce que montre l'autoload Voisinage. Le panneau a quatre affiches : « Les meilleurs
## placements » à la craie de Lucien (le total gagné au jeu, qu'il « analyse »), les petites annonces des
## joueurs, les rendez-vous des parties à plusieurs, et qui est passé au village depuis hier. À la porte
## d'une maison possédée par d'autres joueurs : leurs noms, et un mot à glisser dans leur livre d'or.

const OR := Color(0.96, 0.8, 0.45)
const EAU := Color(0.35, 0.8, 0.75)
const TEXTE := Color(0.88, 0.9, 0.92)
const DOUX := Color(0.65, 0.7, 0.75)
const CRAIE := Color(0.93, 0.93, 0.88)
const ARDOISE := Color(0.14, 0.2, 0.18, 0.98)
const LIEUX := {"place": "la place", "cafe": "le Café de la Place", "casino": "le Casino", "rabelais": "la salle Rabelais",
	"moulin": "le Moulin des Dames", "banque": "le Crédit Smarvois", "bois": "le bois de Saint-Pierre",
	"passelourdin": "Passelourdin", "boutique": "la boutique"}
const NOMS_LOTS := {"chambre_cafe": "La chambre au-dessus du café", "maison_place": "La maison de maître",
	"maison_eglise": "La maison de la rue de l'Église"}
const JOURS := ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]

var _root: Control
var _box: VBoxContainer
## « panneau », ou le lot d'une maison.
var _mode := ""
## Le joueur à qui l'on écrit, à la porte d'une maison.
var _pour := {}
var _note := ""
var _mouse_before := Input.MOUSE_MODE_VISIBLE
var _paused_before := false


func _ready() -> void:
	layer = 44
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.visible = false
	add_child(_root)
	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, 0.45)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(voile)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var fenetre := PanelContainer.new()
	var st := _boite(ARDOISE, Color(0.55, 0.42, 0.25), 6, 26, 6)
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 24
	fenetre.add_theme_stylebox_override("panel", st)
	center.add_child(fenetre)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 10)
	fenetre.add_child(colonne)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(980, 540)
	colonne.add_child(scroll)
	# Le bouton reste sous le texte qui défile, toujours visible.
	var bas := HBoxContainer.new()
	bas.alignment = BoxContainer.ALIGNMENT_END
	bas.add_child(_bouton("Fermer", OR, Color(0.1, 0.07, 0.03), Color(0, 0, 0, 0), fermer, 18))
	colonne.add_child(bas)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 12)
	scroll.add_child(_box)
	Voisinage.lu.connect(func():
		if is_open():
			_remplir())


func is_open() -> bool:
	return _root.visible


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed("ui_cancel"):
		fermer()
		get_viewport().set_input_as_handled()


## Le panneau de la mairie.
func ouvrir_panneau() -> void:
	_ouvrir("panneau")


## La porte d'une maison que d'autres joueurs possèdent.
func ouvrir_maison(lot: String) -> void:
	_ouvrir(lot)


func _ouvrir(mode: String) -> void:
	if not is_open():
		_mouse_before = Input.mouse_mode
		_paused_before = get_tree().paused
	_mode = mode
	_pour = {}
	_note = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_root.visible = true
	_remplir()
	Voisinage.lire()


func fermer() -> void:
	if not is_open():
		return
	_root.visible = false
	Input.mouse_mode = _mouse_before
	get_tree().paused = _paused_before


func _remplir() -> void:
	for c in _box.get_children():
		c.queue_free()
	if _mode == "panneau":
		_remplir_panneau()
	else:
		_remplir_maison(_mode)


# --- Le panneau de la mairie -------------------------------------------------------------------

func _remplir_panneau() -> void:
	_box.add_child(_mot("M A I R I E   D E   S M A R V E S", 13, Color(0.75, 0.68, 0.5)))
	_box.add_child(_mot("Le panneau d'affichage", 34, Color.WHITE, Polices.titre()))
	if Voisinage.etat == "hors_ligne":
		_box.add_child(_mot("Hors ligne : le panneau se lira au retour du réseau.", 16, DOUX))
	var rang := HBoxContainer.new()
	rang.add_theme_constant_override("separation", 18)
	_box.add_child(rang)
	var gauche := _affiche(rang)
	var droite := _affiche(rang)
	# La craie de Lucien.
	gauche.add_child(_titre_affiche("LES MEILLEURS PLACEMENTS"))
	gauche.add_child(_mot("à la craie, par Lucien : « Je ne parie pas, j'analyse. »", 14, DOUX))
	var liste := Voisinage.classement()
	if liste.is_empty():
		gauche.add_child(_mot("Le tableau attend son premier joueur au compte.", 16, CRAIE, null, true))
	for i in liste.size():
		var l := HBoxContainer.new()
		l.add_child(_mot("%d.  %s" % [i + 1, liste[i].nom], 18, CRAIE))
		var s := Control.new()
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_child(s)
		l.add_child(_mot(Game.fmt(int(liste[i].gagne)), 18, OR))
		gauche.add_child(l)
	gauche.add_child(_filet())
	gauche.add_child(_titre_affiche("RENDEZ-VOUS"))
	for rv in Voisinage.prochains_rendez_vous():
		gauche.add_child(_mot("%s, %s à %s" % [rv.quoi, _jour(rv.quand), _heure(rv.quand)], 17, CRAIE, null, true))
	gauche.add_child(_mot("Dans %s. La table est partagée tous les soirs entre les joueurs connectés : à ces heures-là, on y trouve du monde." % Voisinage.RENDEZ_VOUS[0][4], 14, DOUX, null, true))
	# Les petites annonces.
	droite.add_child(_titre_affiche("PETITES ANNONCES"))
	var annonces := Voisinage.annonces()
	if annonces.is_empty():
		droite.add_child(_mot("Aucune annonce cette semaine.", 16, CRAIE))
	for a in annonces.slice(0, 6):
		droite.add_child(_mot("« %s »" % a.texte, 16, CRAIE, null, true))
		droite.add_child(_mot("%s, %s" % [a.nom, _il_y_a(int(a.quand))], 13, DOUX))
	droite.add_child(_saisie("Votre annonce (une par jour)", 120, func(t):
		var r: Dictionary = await Voisinage.annoncer(t)
		_note = r.message
		_remplir()))
	droite.add_child(_filet())
	droite.add_child(_titre_affiche("PASSÉS AU VILLAGE DEPUIS HIER"))
	var passages := Voisinage.passages()
	if passages.is_empty():
		droite.add_child(_mot("Personne d'autre, ou personne qui ait signé.", 16, CRAIE))
	for lieu in passages:
		var noms: Array = passages[lieu]
		var nom: String = LIEUX.get(lieu, lieu.replace("_", " "))
		droite.add_child(_mot("%s : %s" % [nom.substr(0, 1).to_upper() + nom.substr(1), ", ".join(noms.slice(0, 6))], 16, CRAIE, null, true))
	# Les mots que les autres ont glissés sous les portes du joueur : la mairie fait office de boîte aux lettres.
	var mots := Voisinage.mots()
	if mots.is_empty():
		return
	var rang2 := HBoxContainer.new()
	_box.add_child(rang2)
	var livre := _affiche(rang2)
	livre.add_child(_titre_affiche("VOTRE LIVRE D'OR"))
	for m in mots.slice(0, 8):
		livre.add_child(_mot("« %s »" % m.texte, 16, CRAIE, null, true))
		livre.add_child(_mot("%s, à %s, %s" % [m.nom, NOMS_LOTS.get(m.lot, "votre porte").to_lower(), _il_y_a(int(m.quand))], 13, DOUX))


# --- La porte d'une maison ---------------------------------------------------------------------

func _remplir_maison(lot: String) -> void:
	_box.add_child(_mot("À  L A  P O R T E", 13, Color(0.75, 0.68, 0.5)))
	_box.add_child(_mot(NOMS_LOTS.get(lot, "Une maison"), 32, Color.WHITE, Polices.titre()))
	var gens := Voisinage.voisins(lot)
	if gens.is_empty():
		_box.add_child(_mot("Personne d'autre n'a la clef de cette maison.", 17, CRAIE))
		return
	_box.add_child(_mot("Les joueurs qui ont la clef de cette maison. Ils ne sont pas là, mais leur livre d'or est dans l'entrée.", 16, DOUX, null, true))
	for g in gens.slice(0, 8):
		var l := HBoxContainer.new()
		l.add_theme_constant_override("separation", 14)
		l.add_child(_mot(g.nom, 20, CRAIE, Polices.gras()))
		var meubles := int(g.get("meubles", 0))
		l.add_child(_mot(("y habite" if g.get("habite", false) else "la loue") + ("  ·  %d meuble%s" % [meubles, "s" if meubles > 1 else ""] if meubles > 0 else "  ·  pas encore meublée"), 16, DOUX))
		var s := Control.new()
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_child(s)
		if Compte.connecte():
			l.add_child(_bouton("Laisser un mot", Color(0, 0, 0, 0), EAU, EAU, func():
				_pour = g
				_note = ""
				_remplir(), 15))
		_box.add_child(l)
	if not Compte.connecte():
		_box.add_child(_mot("Connectez-vous à votre compte Pyramides, dans les réglages, pour leur laisser un mot.", 15, DOUX, null, true))
	elif not _pour.is_empty():
		_box.add_child(_filet())
		_box.add_child(_saisie("Un mot pour %s" % _pour.nom, 200, func(t):
			var r: Dictionary = await Voisinage.laisser_mot(str(_pour.id), lot, t)
			_note = r.message
			if r.ok:
				_pour = {}
			_remplir()))
	elif _note != "":
		_box.add_child(_mot(_note, 15, OR))


# --- Les pièces --------------------------------------------------------------------------------

## Une ligne à écrire et son bouton ; sans compte, une phrase qui dit pourquoi on ne peut pas.
func _saisie(invite: String, longueur: int, envoyer: Callable) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	if not Compte.connecte():
		v.add_child(_mot("Pour afficher la vôtre, connectez-vous à votre compte Pyramides dans les réglages.", 14, DOUX, null, true))
		return v
	var champ := LineEdit.new()
	champ.placeholder_text = invite
	champ.max_length = longueur
	champ.add_theme_font_override("font", Polices.texte())
	champ.add_theme_font_size_override("font_size", 16)
	champ.custom_minimum_size.y = 40
	v.add_child(champ)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var envoi := func():
		if champ.text.strip_edges() != "":
			envoyer.call(champ.text.strip_edges())
	h.add_child(_bouton("Afficher" if _mode == "panneau" else "Glisser sous la porte", Color(0, 0, 0, 0), OR, OR, envoi, 15))
	champ.text_submitted.connect(func(_t): envoi.call())
	if _note != "":
		h.add_child(_mot(_note, 14, OR))
	v.add_child(h)
	return v


func _affiche(rang: HBoxContainer) -> VBoxContainer:
	var cadre := PanelContainer.new()
	cadre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cadre.add_theme_stylebox_override("panel", _boite(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.1), 4, 16))
	rang.add_child(cadre)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	cadre.add_child(v)
	return v


func _titre_affiche(t: String) -> Label:
	return _mot(t, 14, EAU, Polices.gras())


static func _jour(quand: int) -> String:
	var aujourdhui := int(floor((Time.get_unix_time_from_system() + _decalage()) / 86400.0))
	var j := int(floor(quand / 86400.0))
	if j == aujourdhui:
		return "aujourd'hui"
	if j == aujourdhui + 1:
		return "demain"
	return JOURS[(j + 4) % 7]


static func _heure(quand: int) -> String:
	var s := quand % 86400
	var m := (s / 60) % 60
	return "%d h%s" % [s / 3600, (" %02d" % m) if m > 0 else ""]


static func _decalage() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


static func _il_y_a(quand: int) -> String:
	var s := int(Time.get_unix_time_from_system()) - quand
	if s < 3600:
		return "il y a %d min" % maxi(1, s / 60)
	if s < 48 * 3600:
		return "il y a %d h" % (s / 3600)
	return "il y a %d jours" % (s / 86400)


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
		l.custom_minimum_size.x = 300
	return l


func _filet() -> ColorRect:
	var f := ColorRect.new()
	f.color = Color(1, 1, 1, 0.1)
	f.custom_minimum_size.y = 1
	return f


func _bouton(t: String, fond: Color, encre: Color, bord: Color, action: Callable, taille := 17) -> Button:
	var b := Button.new()
	b.text = t
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", Polices.gras())
	b.add_theme_font_size_override("font_size", taille)
	for etat in ["normal", "hover", "pressed", "focus"]:
		var f := fond
		if etat == "hover" or etat == "pressed":
			f = fond.lightened(0.12) if fond.a > 0 else Color(encre, 0.12)
		var s := _boite(f, bord, 4, 10)
		s.content_margin_left = 20
		s.content_margin_right = 20
		b.add_theme_stylebox_override(etat, s)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, encre)
	b.pressed.connect(action)
	return b
