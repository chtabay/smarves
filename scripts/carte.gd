extends CanvasLayer
## L'écran de la carte de la Vienne (autoload « Carte »). On y arrive en dézoomant au-delà du cran
## « quartier » au village (molette ou pincer), avec M, depuis la bienvenue, ou dès le menu de départ ; on en repart en
## zoomant sur sa commune, avec Échap ou « Revenir ». Smarves en or, les villes installées en vert
## d'eau vif, les villes publiées sur le portail en vert d'eau pâle, les autres en filigrane, et
## Poitiers dans la brume. Une commune qui arrive (publiée, installée) s'allume à l'ouverture
## suivante. Toucher une commune la montre dans la fiche ; « Y aller » change de commune.

const OR := Color(0.96, 0.8, 0.45)
const EAU := Color(0.35, 0.8, 0.75)
const TEXTE := Color(0.88, 0.9, 0.92)
const DOUX := Color(0.65, 0.7, 0.75)
const ROUGE := Color(0.95, 0.45, 0.42)
const NUIT := Color(0.05, 0.07, 0.1)
## Le zoom d'où l'on part et où l'on replonge : la commune remplit le milieu de l'écran.
const ZOOM_COMMUNE := 7.0
## Les communes déjà allumées sous les yeux du joueur.
const VUES := "allumees.json"

var _root: Control
var _voile: ColorRect
var _carte: CarteVienne
var _fiche: PanelContainer
var _fiche_box: VBoxContainer
var _compte: Label
var _retour: Button
var _aide: Label
var _mouse_before := Input.MOUSE_MODE_VISIBLE
var _paused_before := false
var _en_route := false
## Ouverte depuis l'écran titre : pas encore de partie, on n'est nulle part, « Revenir » rend le menu.
var _titre := false
var _capture := "--capture" in " ".join(OS.get_cmdline_user_args())


func _ready() -> void:
	layer = 46
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construire()
	_root.visible = false
	Communes.catalogue_lu.connect(func():
		if is_open():
			_rafraichir(true))
	Communes.installee.connect(func(id, ok, message):
		if is_open():
			_rafraichir(true)
			if not ok:
				_montrer(Communes.au_catalogue(id).get("insee", ""), message)
			else:
				_montrer(Communes.commune(id).insee))


func is_open() -> bool:
	return _root.visible


## M ouvre la carte depuis le village ou une commune greffée, quand rien d'autre n'est ouvert.
func _unhandled_input(event: InputEvent) -> void:
	if is_open():
		if event.is_action_pressed("ui_cancel"):
			fermer()
			get_viewport().set_input_as_handled()
		elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
			fermer()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M and peut_ouvrir():
		ouvrir()
		get_viewport().set_input_as_handled()


## Dehors seulement : au village (sans table ni panneau ouvert) ou dans une commune greffée.
func peut_ouvrir() -> bool:
	var scene := get_tree().current_scene
	if scene == null or _en_route or Carnet.is_open() or Settings.is_open() or Bienvenue.is_open() or scene.has_meta("vitrine"):
		return false
	if Communes.actuelle() != Communes.ORIGINE:
		return true
	if scene.name != "Main" or get_tree().paused:
		return false
	var panneaux = scene.get("_panels")
	return not (panneaux is Node and panneaux.get_child_count() > 0)


## depuis_titre : depuis le menu de départ, avant d'entrer dans le jeu ; choisir Smarves lance la partie.
func ouvrir(depuis_titre := false) -> void:
	if is_open():
		return
	_titre = depuis_titre
	_mouse_before = Input.mouse_mode
	_paused_before = get_tree().paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_root.visible = true
	_rafraichir(false)
	var ici := _ici()
	_carte.ici = "" if _titre else ici
	_carte.choisie = ""
	_montrer(ici)
	# On s'élève au-dessus de sa commune, puis le département entier se découvre.
	_carte.cadrer(ici, ZOOM_COMMUNE)
	_carte.cadrer_tout(1.1)
	_voile.color = Color(NUIT, 1.0)
	var t := create_tween()
	t.tween_property(_voile, "color:a", 0.0, 0.45)
	var neuves := _neuves()
	_carte.allumer(neuves)
	if not neuves.is_empty():
		if not _capture:
			Portail.ecrire(Communes.dossier_greffes.path_join(VUES), JSON.stringify(_allumees()))


## Repart dans sa commune : la carte replonge sur elle et s'efface.
func fermer() -> void:
	if not is_open() or _en_route:
		return
	_en_route = true
	_carte.cadrer(_ici(), ZOOM_COMMUNE, 0.45)
	var t := create_tween()
	t.tween_property(_voile, "color:a", 1.0, 0.45)
	await t.finished
	_cacher()
	get_tree().paused = _paused_before
	Input.mouse_mode = _mouse_before


func _cacher() -> void:
	_root.visible = false
	_en_route = false
	_voile.color.a = 0.0


## Va dans une autre commune : Smarves (on rentre), ou une commune greffée installée.
func aller(insee: String) -> void:
	if _en_route:
		return
	if insee == _ici() and not _titre:
		fermer()
		return
	var c := Communes.par_insee(insee)
	if c == null:
		return
	_en_route = true
	_carte.cadrer(insee, ZOOM_COMMUNE, 0.6)
	var t := create_tween()
	t.tween_property(_voile, "color:a", 1.0, 0.6)
	await t.finished
	_cacher()
	if c.id == Communes.ORIGINE:
		Communes.revenir()
	elif not Communes.visiter(c.id):
		get_tree().paused = _paused_before
		Carnet.show_slip("%s ne s'ouvre pas : %s" % [c.nom, Communes.refus[-1][1] if not Communes.refus.is_empty() else "scène introuvable"])


func _ici() -> String:
	var c := Communes.commune(Communes.actuelle())
	return c.insee if c else CarteVienne.ORIGINE_INSEE


## Les communes marquées sur la carte : Smarves, les villes installées et les publiées.
func _allumees() -> Array:
	var out := [CarteVienne.ORIGINE_INSEE]
	for i in _carte.installees + _carte.publiees:
		if not out.has(i):
			out.append(i)
	return out


func _neuves() -> Array:
	var vues = Portail.lire_json(Communes.dossier_greffes.path_join(VUES))
	var deja: Array = vues if vues is Array else []
	return _allumees().filter(func(i): return not deja.has(i))


# --- L'écran ------------------------------------------------------------------------------------

func _construire() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var fond := TextureRect.new()
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	fond.texture = _fond()
	fond.stretch_mode = TextureRect.STRETCH_SCALE
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(fond)
	_carte = CarteVienne.new()
	_carte.interactive = true
	_carte.brume = true
	_carte.rivieres = true
	_carte.marge = 36.0
	_carte.set_anchors_preset(Control.PRESET_FULL_RECT)
	_carte.survol.connect(func(i):
		if i != "":
			_montrer(i)
		elif _carte.choisie != "":
			_montrer(_carte.choisie)
		else:
			_montrer(_ici()))
	_carte.choix.connect(func(i):
		_carte.choisie = i
		_montrer(i if i != "" else _ici()))
	_carte.plongee.connect(func(i):
		if i == "" or (i == _ici() and not _titre):
			fermer()
		elif Communes.par_insee(i) != null:
			aller(i))
	_root.add_child(_carte)

	# En haut à gauche, le titre et le compte des communes.
	var cartouche := PanelContainer.new()
	cartouche.add_theme_stylebox_override("panel", _boite(Color(0.04, 0.05, 0.08, 0.72), Color(0, 0, 0, 0), 10, 16))
	cartouche.position = Vector2(18, 14)
	cartouche.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(cartouche)
	var tete := VBoxContainer.new()
	tete.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tete.add_theme_constant_override("separation", 4)
	cartouche.add_child(tete)
	tete.add_child(_mot("L A   V I E N N E", 13, Color(0.55, 0.75, 0.75)))
	tete.add_child(_mot("Carte du département", 34, Color.WHITE, Polices.titre()))
	_compte = _mot("", 16, DOUX)
	tete.add_child(_compte)
	var legende := VBoxContainer.new()
	legende.add_theme_constant_override("separation", 2)
	legende.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tete.add_child(_vide(10))
	tete.add_child(legende)
	for l in [[OR, "votre commune"], [EAU, "villes installées"], [Color(EAU, 0.55), "villes publiées, à installer"], [Color(0.78, 0.8, 0.84, 0.6), "Poitiers, dans la brume"]]:
		var rang := HBoxContainer.new()
		rang.add_theme_constant_override("separation", 8)
		rang.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pastille := ColorRect.new()
		pastille.color = l[0]
		pastille.custom_minimum_size = Vector2(14, 14)
		pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pastille.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rang.add_child(pastille)
		rang.add_child(_mot(l[1], 15, DOUX))
		legende.add_child(rang)

	# En haut à droite, le retour.
	_retour = _bouton("", Color(0, 0, 0, 0), TEXTE, Color(1, 1, 1, 0.3), fermer, 17)
	_retour.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_retour.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_retour.offset_right = -28
	_retour.offset_left = -28
	_retour.offset_top = 26
	_root.add_child(_retour)

	# En bas à droite, la fiche de la commune survolée ou choisie.
	_fiche = PanelContainer.new()
	var st := _boite(Color(0.06, 0.08, 0.12, 0.92), Color(EAU, 0.35), 10, 20)
	st.shadow_color = Color(0, 0, 0, 0.45)
	st.shadow_size = 18
	_fiche.add_theme_stylebox_override("panel", st)
	_fiche.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_fiche.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_fiche.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_fiche.offset_right = -28
	_fiche.offset_bottom = -28
	_fiche.custom_minimum_size.x = 340
	_root.add_child(_fiche)
	_fiche_box = VBoxContainer.new()
	_fiche_box.add_theme_constant_override("separation", 8)
	_fiche.add_child(_fiche_box)

	_aide = _mot("", 14, Color(0.55, 0.6, 0.66))
	_aide.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_aide.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_aide.position = Vector2(32, -40)
	_root.add_child(_aide)

	_voile = ColorRect.new()
	_voile.color = Color(NUIT, 0.0)
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_voile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_voile)


## Un fond de nuit, plus clair au milieu, comme une table éclairée par une lampe.
func _fond() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0.1, 0.13, 0.18))
	g.set_color(1, Color(0.03, 0.04, 0.06))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.1, 1.1)
	t.width = 256
	t.height = 256
	return t


func _rafraichir(garder := true) -> void:
	_carte.publiees = Communes.publiees().map(func(e): return e.insee)
	_carte.installees = Communes.installees().map(func(id): return Communes.commune(id).insee)
	_carte.queue_redraw()
	var n := 1 + Communes.installees().size()
	var p := Communes.publiees().filter(func(e): return Communes.commune(e.id) == null).size()
	var s := "%d commune%s ouverte%s sur %d" % [n, "s" if n > 1 else "", "s" if n > 1 else "", Vienne.communes().size()]
	if p > 0:
		s += ", %d à installer" % p
	_compte.text = s
	var ici := Communes.commune(Communes.actuelle())
	_retour.text = "←  Revenir au menu" if _titre else "←  Revenir à %s" % (ici.nom if ici else "Smarves")
	_aide.text = ("Pincer pour zoomer  ·  glisser pour déplacer  ·  toucher une commune" if Tactile.active
		else "Molette pour zoomer  ·  glisser pour déplacer  ·  cliquer une commune  ·  Échap ou M pour revenir")
	if garder:
		_montrer(_carte.choisie if _carte.choisie != "" else _ici())


## La fiche d'une commune : ce qu'elle est pour le joueur, et ce qu'il peut y faire.
func _montrer(insee: String, alerte := "") -> void:
	for c in _fiche_box.get_children():
		c.queue_free()
	if insee == "":
		insee = _ici()
	var v := Vienne.commune(insee)
	if v.is_empty():
		return
	var c := Communes.par_insee(insee)
	var e := {}
	for x in Communes.publiees():
		if x.insee == insee:
			e = x
	var ici := insee == _ici() and not _titre
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", 10)
	tete.add_child(_mot(str(v.nom), 26, OR if insee == CarteVienne.ORIGINE_INSEE else Color.WHITE, Polices.titre()))
	if ici:
		tete.add_child(_mot("VOUS ÊTES ICI", 12, EAU, Polices.gras()))
	elif c == null and not e.is_empty() and Communes.nouvelles.has(e.id):
		tete.add_child(_mot("NOUVELLE", 12, EAU, Polices.gras()))
	_fiche_box.add_child(tete)
	var pop := int(v.get("population", 0))
	var etat := ""
	var texte := ""
	if insee == CarteVienne.ORIGINE_INSEE:
		etat = "Votre commune"
		texte = "Le Café de la Place, le casino, le Crédit Smarvois, la salle François-Rabelais et le Moulin des Dames."
	elif insee == CarteVienne.POITIERS_INSEE:
		etat = "Dans la brume"
		texte = "On n'y va pas. C'est là que partent ceux qui ne croient pas au jeu."
	elif c != null:
		etat = "Installée" + ("  ·  version %s" % str(c.data.get("version", "")) if str(c.data.get("version", "")) != "" else "") \
			+ ("  ·  par %s" % str(c.data.auteur) if str(c.data.get("auteur", "")) != "" else "")
		texte = str(e.get("description", c.data.get("description", "")))
	elif not e.is_empty():
		etat = "Publiée par %s  ·  %s" % [e.auteur, Portail.taille(e.taille)]
		texte = str(e.description)
	else:
		etat = "Pas encore développée"
		texte = "Les développeurs construisent les villes de la Vienne sur le portail. Elle s'allumera ici le jour où elle sera publiée."
	_fiche_box.add_child(_mot(etat + ("  ·  %s\u00a0habitants" % Game.fmt(pop).replace(" ", "\u00a0") if pop > 0 and insee != CarteVienne.POITIERS_INSEE else ""), 15, DOUX, null, true))
	if texte != "":
		_fiche_box.add_child(_mot(texte, 16, TEXTE, null, true))
	if alerte != "":
		_fiche_box.add_child(_mot(alerte, 15, ROUGE, null, true))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	if ici:
		actions.add_child(_bouton("Revenir au village" if insee == CarteVienne.ORIGINE_INSEE else "Revenir à %s" % v.nom, OR if insee == CarteVienne.ORIGINE_INSEE else EAU, Color(0.08, 0.06, 0.03), Color(0, 0, 0, 0), fermer, 16))
	elif c != null:
		actions.add_child(_bouton((("Jouer à Smarves  →" if _titre else "Rentrer à Smarves  →") if c.id == Communes.ORIGINE else "Y aller  →"), OR if c.id == Communes.ORIGINE else EAU, Color(0.04, 0.1, 0.1), Color(0, 0, 0, 0), aller.bind(insee), 16))
	elif not e.is_empty():
		if Communes.en_cours == e.id:
			actions.add_child(_mot("Téléchargement en cours…", 16, DOUX))
		else:
			actions.add_child(_bouton("Installer", Color(0, 0, 0, 0), EAU, EAU, Communes.installer.bind(e.id), 16, Communes.en_cours == ""))
	if actions.get_child_count() > 0:
		_fiche_box.add_child(_vide(2))
		_fiche_box.add_child(actions)


# --- Les pièces, comme celles de la bienvenue ---------------------------------------------------

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
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", police if police else Polices.texte())
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("outline_size", 4 if not replie else 0)
	if replie:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 300
	return l


func _vide(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _bouton(t: String, fond: Color, encre: Color, bord: Color, action: Callable, taille := 17, actif := true) -> Button:
	var b := Button.new()
	b.text = t
	b.disabled = not actif
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", Polices.gras())
	b.add_theme_font_size_override("font_size", taille)
	for etat in ["normal", "hover", "pressed", "focus", "disabled"]:
		var f := fond
		if etat == "hover" or etat == "pressed":
			f = fond.lightened(0.12) if fond.a > 0 else Color(encre, 0.12)
		var s := _boite(f, bord if etat != "disabled" else Color(bord, bord.a * 0.4), 4, 10)
		s.content_margin_left = 20
		s.content_margin_right = 20
		b.add_theme_stylebox_override(etat, s)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, encre)
	b.add_theme_color_override("font_disabled_color", Color(encre, 0.4))
	b.pressed.connect(action)
	return b
