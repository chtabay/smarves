extends CanvasLayer
## Le carnet du joueur (autoload « Carnet »), ouvert par C : un cahier d'écolier à petits carreaux,
## écrit à l'encre bleue, partagé par des intercalaires de couleur. Pas de commentaire : les chiffres
## sont alignés, le joueur fait la soustraction. Une fiche de papier glisse en bas de l'écran à chaque
## recette, à chaque reprise d'un bien, à chaque ticket réglé.
##
## Les onglets, de gauche à droite :
## - « Aujourd'hui », la page où le carnet s'ouvre quand quelque chose attend (à la Football Manager) : ce
##   qu'il y a à faire, le plus pressé d'abord et chaque ligne avec son bouton (la décision de la semaine se
##   tranche là), ce qui est arrivé depuis la dernière visite, une carte par club suivi (rang, forme,
##   prochain match, direction), et les prochains rendez-vous (scripts/socle/aujourdhui.gd) ;
## - « Courrier » : les avis du courrier (autoload Avis), les nouveaux sur la page de gauche, les déjà lus
##   à droite, chacun avec le bouton de l'écran où il mène ; le nombre de non lus est sur l'intercalaire ;
## - « Mes clubs » : une page par club suivi (le classement du groupe, sa ligne soulignée, les quatorze
##   journées, l'effectif, les parts et la direction), puis « Le calendrier » des deux championnats, la
##   journée, l'intersaison (où se prennent les parts), le mercato et le marché (scripts/socle/calendrier.gd) ;
## - « Ma carrière », tenu par le socle : ce qui suit le joueur d'une commune à l'autre (crédits, dettes
##   par banque, biens, obligations, bourse, fortune nette et sa courbe semaine après semaine), le
##   palmarès des clubs suivis, les records et les engagements en cours (scripts/socle/carriere.gd) ;
## - « Mes cartes » : le classeur des cartes possédées, un sous-onglet par village, avec le topo complet
##   des parts de club (scripts/carnet_cartes.gd) ;
## - un onglet par commune : la commune d'origine d'abord, dont la page vient du jeu (le champ
##   « page_carnet » de son manifeste), puis chaque commune qui tient des compteurs au carnet
##   (docs/COMMUNE.md, « Le carnet du joueur ») : ils se lisent de partout, et ne bougent que quand
##   le joueur y est ;
## - « La Vienne » : les communes à installer et à visiter, et les derniers passages.

const PAPER := Color(0.97, 0.95, 0.88)
const MARGIN_RED := Color(0.85, 0.3, 0.3, 0.55)
const INK := Color(0.12, 0.2, 0.5)
const INK_LIGHT := Color(0.3, 0.38, 0.62)
const PENCIL := Color(0.38, 0.36, 0.34)
const RED_INK := Color(0.7, 0.12, 0.12)
## Le papier des intercalaires, un par onglet, dans l'ordre (le dernier se répète).
const TEINTES := [Color(0.91, 0.8, 0.52), Color(0.7, 0.83, 0.68), Color(0.89, 0.7, 0.7), Color(0.71, 0.79, 0.9), Color(0.84, 0.75, 0.89)]

## Au-delà, les compteurs d'une commune passent sur la page de droite.
const LIGNES_A_GAUCHE := 14

var _root: Control
var _left: VBoxContainer
var _right: VBoxContainer
var _onglets: HBoxContainer
var _slip: PanelContainer
var _slip_label: Label
var _slip_tween: Tween
## Une fiche arrivée carnet ouvert : elle attend qu'on le referme.
var _pending_slip := ""
## L'avis de la fiche à l'écran (un clic y mène ; {} : le courrier entier), ou null pour une fiche sans suite.
var _slip_avis = null
var _pending_avis = null
## La pastille du courrier : tant qu'il reste des avis non lus, en bas à gauche, hors table et carnet fermé.
var _pastille: Button
var _hand: Font
var _hand_bold: Font
var _mouse_before := Input.MOUSE_MODE_VISIBLE
var _paused_before := false
## Le logement qu'on est en train d'aménager dans le carnet (« » : aucun).
var _amenage := ""
## La feuille dépliée par-dessus le carnet (le plan d'une commune, la semaine) : sa feuille, et ce qu'on y écrit.
var _cover: Control
var _sheet: PanelContainer
var _sheet_box: VBoxContainer
## Ce que montre la feuille dépliée : « agenda » (la semaine), ou ce que la page d'origine sait déplier (« plan »).
var _sheet_mode := "plan"
## L'onglet ouvert : « aujourdhui », « compte », « vienne » ou l'id d'une commune.
var _onglet := "aujourdhui"
## Ce que dit la pastille, relu chaque seconde : [choses à faire, nouvelles].
var _compte_pastille := [0, 0]
var _pastille_lue := -1.0
## La page de « Mes clubs » ouverte : l'id d'un club suivi, « calendrier », ou « » (le premier club).
var _club_vu := ""
## La page de la commune d'origine (son manifeste, « page_carnet ») : un nœud qui remplit les deux pages.
var _page_origine: Node
## Les deux pages ouvertes, et le classeur de cartes qui prend leur place sous l'onglet « Mes cartes ».
var _spread: HBoxContainer
var _album: Control


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Le cahier d'écolier tient au papier quadrillé et aux filets ; l'écriture reste celle du jeu.
	_hand = Polices.texte()
	_hand_bold = Polices.gras()
	_build()
	_root.visible = false
	_charger_page_origine()
	Biens.changed.connect(func():
		if _root.visible:
			_refresh())
	# Les recettes des biens, et tout ce qui prévient, passent par le courrier, qui fait glisser la fiche.
	Avis.fiche.connect(show_slip)
	Avis.change.connect(func():
		if _root.visible:
			_refresh.call_deferred())
	# Les communes du portail : la liste se lit au lancement, l'installation finit en arrière-plan.
	Communes.catalogue_lu.connect(func():
		if _root.visible:
			_refresh())
	Communes.installee.connect(func(_id, _ok, message):
		show_slip(message)
		if _root.visible:
			_refresh())
	Communes.etat_change.connect(func(_id):
		if _root.visible:
			_refresh.call_deferred())
	Doublure.change.connect(func():
		if _root.visible and _sheet.visible and _sheet_mode == "doublure":
			_refresh.call_deferred())
	# Chaque passage dans une commune qui tient des compteurs se note, pour la date de la page.
	if get_tree().has_signal("scene_changed"):
		get_tree().connect("scene_changed", _noter_passage)


func is_open() -> bool:
	return _root.visible


## La page de la commune d'origine, s'il y en a une : le jeu la désigne dans son manifeste. Un paquet de
## commune ne fournit jamais de code au carnet ; ses compteurs suffisent (noter).
func _charger_page_origine() -> void:
	var o: Commune = Communes.origine()
	var chemin := str(o.data.get("page_carnet", "")) if o != null else ""
	if chemin == "" or not ResourceLoader.exists(chemin):
		return
	_page_origine = (load(chemin) as Script).new()
	_page_origine.set("carnet", self)
	_page_origine.name = "PageOrigine"
	add_child(_page_origine)


## La page de la commune d'origine (ou null) : la commune y range son plan, ses adresses.
func page_origine() -> Node:
	return _page_origine


func _unhandled_input(event: InputEvent) -> void:
	if _root.visible and not _sheet.visible and _onglet == "cartes" and _album.saisir(event):
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		if Settings.is_open() or Bienvenue.is_open() or get_tree().current_scene == null or get_tree().current_scene.name == "Titre":
			return
		toggle()
		get_viewport().set_input_as_handled()
	elif _root.visible and event.is_action_pressed("ui_cancel"):
		if _sheet.visible:
			_show_sheet(false, _sheet_mode)
		else:
			toggle()
		get_viewport().set_input_as_handled()
	elif _root.visible and not _sheet.visible and event is InputEventKey and event.pressed \
			and event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_PAGEUP, KEY_PAGEDOWN]:
		tourner(1 if event.keycode in [KEY_RIGHT, KEY_PAGEDOWN] else -1)
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if _root.visible:
		_root.visible = false
		_sheet.visible = false
		if _album.zoom_ouvert():
			_album.fermer_zoom()
		Input.mouse_mode = _mouse_before
		get_tree().paused = _paused_before
		if _onglet == "courrier":
			Avis.tout_lu()
		_pastille_lue = -1.0
		if _pending_slip != "":
			show_slip.call_deferred(_pending_slip, _pending_avis)
			_pending_slip = ""
			_pending_avis = null
	else:
		_mouse_before = Input.mouse_mode
		_paused_before = get_tree().paused
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_noter_passage()
		CARRIERE.noter(fortune_nette(), Agenda.maintenant(), Game.saving_enabled)
		# Quelque chose attend : le carnet s'ouvre sur « Aujourd'hui », comme la boîte de Football Manager.
		if not a_faire().is_empty() or not Avis.non_lus().is_empty():
			_onglet = "aujourdhui"
		_refresh()
		_root.visible = true
		get_tree().paused = true


# --- Les onglets ----------------------------------------------------------------------------------

## Les onglets du cahier, dans l'ordre : [[clé, nom]].
func onglets() -> Array:
	var n: int = Avis.non_lus().size()
	var out := [["aujourdhui", "Aujourd'hui"], ["courrier", "Courrier (%d)" % n if n > 0 else "Courrier"], ["clubs", "Mes clubs"], ["compte", "Ma carrière"], ["cartes", "Mes cartes"]]
	var o: Commune = Communes.origine()
	if _page_origine != null and o != null:
		out.append([o.id, o.nom])
	for id in _communes_au_carnet():
		out.append([id, _nom_commune(id)])
	out.append(["vienne", "La Vienne"])
	return out


## Les communes qui ont une page de compteurs : les installées qui en déclarent, puis celles dont le
## carnet garde une trace sans qu'elles soient là (désinstallées, ou pas encore lues au lancement).
func _communes_au_carnet() -> Array:
	var out: Array = []
	var o: Commune = Communes.origine()
	for id in Communes.ordre:
		if o != null and id == o.id and _page_origine != null:
			continue
		if not _compteurs(id).is_empty():
			out.append(id)
	for id in Game.carnet:
		if not out.has(id) and not (o != null and id == o.id and _page_origine != null) and not _compteurs(id).is_empty():
			out.append(id)
	# Un village où l'on tient des cartes a sa page, même sans compteurs (Casino Minuit).
	for x in _album.villages():
		if not out.has(x.id) and not (o != null and x.id == o.id and _page_origine != null):
			out.append(x.id)
	return out


func ouvrir_onglet(cle: String) -> void:
	# L'ancien onglet « Le calendrier » est la dernière page de « Mes clubs ».
	if cle == "calendrier":
		_club_vu = "calendrier"
		cle = "clubs"
	if cle != _onglet and _album.zoom_ouvert():
		_album.fermer_zoom()
	if cle != _onglet and _onglet == "courrier":
		Avis.tout_lu()
	_onglet = cle
	_amenage = ""
	_refresh()


## Passe à l'onglet suivant (1) ou précédent (-1), en bouclant.
func tourner(sens: int) -> void:
	var cles := onglets().map(func(o): return o[0])
	var i := cles.find(_onglet)
	ouvrir_onglet(cles[posmod((0 if i < 0 else i) + sens, cles.size())])


func _fill_onglets() -> void:
	var liste := onglets()
	if not liste.any(func(o): return o[0] == _onglet):
		_onglet = "aujourdhui"
	for i in liste.size():
		var cle: String = liste[i][0]
		var actif := cle == _onglet
		var b := Button.new()
		b.text = liste[i][1]
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.add_theme_font_override("font", _hand_bold if actif else _hand)
		b.add_theme_font_size_override("font_size", 19)
		for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, INK if actif else INK_LIGHT)
		var teinte: Color = TEINTES[mini(i, TEINTES.size() - 1)]
		for k in ["normal", "hover", "pressed", "focus"]:
			var st := StyleBoxFlat.new()
			# L'intercalaire ouvert prend le papier de la page : il en sort, un peu plus haut que les autres.
			st.bg_color = PAPER if actif else (teinte.lightened(0.12) if k == "hover" else teinte)
			st.corner_radius_top_left = 7
			st.corner_radius_top_right = 7
			st.content_margin_left = 16
			st.content_margin_right = 16
			st.content_margin_top = 6 if actif else 4
			st.content_margin_bottom = 6 if actif else 2
			st.border_width_top = 2
			st.border_color = MARGIN_RED if actif else teinte.darkened(0.18)
			b.add_theme_stylebox_override(k, st)
		b.size_flags_vertical = Control.SIZE_SHRINK_END
		b.pressed.connect(ouvrir_onglet.bind(cle))
		_onglets.add_child(b)
	var vide := Control.new()
	vide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_onglets.add_child(vide)
	var aide := _text(_onglets, "C ou Échap : fermer  ·  ← → : tourner les pages%s" % ("  ·  ↑ ↓ : villages" if _onglet == "cartes" else ""), 15, Color(0.86, 0.8, 0.72))
	aide.autowrap_mode = TextServer.AUTOWRAP_OFF
	aide.size_flags_vertical = Control.SIZE_SHRINK_CENTER


# --- Le cahier ------------------------------------------------------------------------------

## Une page à petits carreaux, avec la marge rouge.
class Page extends PanelContainer:
	var margin_left := true

	func _draw() -> void:
		var step := 18.0
		var y := 64.0
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.55, 0.68, 0.85, 0.32), 1.0)
			y += step
		var x := step
		while x < size.x:
			draw_line(Vector2(x, 64), Vector2(x, size.y), Color(0.55, 0.68, 0.85, 0.16), 1.0)
			x += step
		var mx := 46.0 if margin_left else size.x - 46.0
		draw_line(Vector2(mx, 0), Vector2(mx, size.y), Color(0.85, 0.3, 0.3, 0.55), 2.0)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	# La couverture de carton, les intercalaires qui en dépassent, et les deux pages ouvertes.
	var cover := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.32, 0.12, 0.1)
	cs.set_corner_radius_all(10)
	cs.set_content_margin_all(14)
	cs.content_margin_top = 8
	cs.shadow_color = Color(0, 0, 0, 0.5)
	cs.shadow_size = 18
	cover.add_theme_stylebox_override("panel", cs)
	center.add_child(cover)
	_cover = cover
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	cover.add_child(col)
	_onglets = HBoxContainer.new()
	_onglets.add_theme_constant_override("separation", 4)
	_onglets.custom_minimum_size.y = 40
	col.add_child(_onglets)
	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 0)
	col.add_child(spread)
	_spread = spread
	_left = _page(spread, false)
	_right = _page(spread, true)
	_album = preload("res://scripts/carnet_cartes.gd").new()
	_album.carnet = self
	_album.name = "Cartes"
	_album.visible = false
	col.add_child(_album)
	# La feuille dépliée, une grande feuille quadrillée collée dans la couverture.
	_sheet = Page.new()
	_sheet.custom_minimum_size = Vector2(1148, 728)
	var sh := StyleBoxFlat.new()
	sh.bg_color = PAPER
	sh.set_content_margin_all(26)
	sh.content_margin_left = 62
	sh.set_corner_radius_all(4)
	sh.shadow_color = Color(0, 0, 0, 0.5)
	sh.shadow_size = 18
	_sheet.add_theme_stylebox_override("panel", sh)
	_sheet.visible = false
	center.add_child(_sheet)
	_sheet_box = VBoxContainer.new()
	_sheet_box.add_theme_constant_override("separation", 4)
	_sheet.add_child(_sheet_box)


func _page(parent: Control, right: bool) -> VBoxContainer:
	var p := Page.new()
	p.margin_left = right
	p.custom_minimum_size = Vector2(560, 680)
	var st := StyleBoxFlat.new()
	st.bg_color = PAPER
	st.content_margin_left = 62 if right else 30
	st.content_margin_right = 30 if right else 62
	st.content_margin_top = 26
	st.content_margin_bottom = 22
	if right:
		st.corner_radius_top_right = 4
		st.corner_radius_bottom_right = 4
	else:
		st.corner_radius_bottom_left = 4
	p.add_theme_stylebox_override("panel", st)
	parent.add_child(p)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	scroll.add_child(v)
	return v


func _text(parent: Control, t: String, size := 19, color := INK, bold := false) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", _hand_bold if bold else _hand)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _title(parent: Control, t: String) -> void:
	var l := _text(parent, t, 26, INK, true)
	l.add_theme_constant_override("line_spacing", 0)


## Une ligne de compte : le libellé à gauche, le chiffre à droite.
func _row(parent: Control, label: String, value: String, color := INK, bold := false) -> void:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var a := _text(h, label, 18, color, bold)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := _text(h, value, 18, color, bold)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.autowrap_mode = TextServer.AUTOWRAP_OFF


func _link(parent: Control, t: String, action: Callable, enabled := true) -> Button:
	var b := Button.new()
	b.text = t
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = not enabled
	b.add_theme_font_override("font", _hand)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", Color(0.65, 0.15, 0.15))
	b.add_theme_color_override("font_hover_color", Color(0.85, 0.2, 0.2))
	b.add_theme_color_override("font_disabled_color", PENCIL)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _gap(parent: Control, h := 10) -> void:
	var c := Control.new()
	c.custom_minimum_size.y = h
	parent.add_child(c)


func _refresh() -> void:
	# Retirés tout de suite : les nouveaux boutons gardent leur nom (« Choix_a », pas « Choix_a2 »).
	for c in _left.get_children() + _right.get_children() + _sheet_box.get_children() + _onglets.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	_cover.visible = not _sheet.visible
	if _sheet.visible:
		_fill_sheet()
		return
	_fill_onglets()
	_spread.visible = _onglet != "cartes"
	_album.visible = _onglet == "cartes"
	match _onglet:
		"aujourdhui":
			_fill_aujourdhui()
		"compte":
			_fill_compte()
		"cartes":
			_album.remplir()
		"clubs":
			_fill_clubs()
		"courrier":
			_fill_courrier()
		"vienne":
			_fill_vienne()
		_:
			if _page_origine != null and Communes.origine() != null and _onglet == Communes.origine().id:
				_page_origine.remplir(_left, _right)
			else:
				_fill_commune(_onglet)


# --- Aujourd'hui : ce qui attend, ce qui est arrivé, les clubs suivis ---------------------------

const AUJOURDHUI := preload("res://scripts/socle/aujourdhui.gd")
const VERT := Color(0.18, 0.5, 0.25)
const OCRE := Color(0.62, 0.5, 0.2)


## Ce qui attend le joueur (scripts/socle/aujourdhui.gd), le plus pressé d'abord.
func a_faire() -> Array:
	return AUJOURDHUI.a_faire(Football, Avis, Bourse)


func _fill_aujourdhui() -> void:
	var t: int = Agenda.maintenant()
	_title(_left, "Aujourd'hui")
	_text(_left, "%s, %s" % [Agenda.date(t), Agenda.heure(t)], 15, PENCIL)
	_gap(_left, 6)
	var liste := a_faire()
	_text(_left, "À faire (%d)" % liste.size() if not liste.is_empty() else "Rien ne presse.", 21, RED_INK if not liste.is_empty() else INK_LIGHT, true)
	if liste.is_empty():
		_text(_left, "Pas de décision en attente, pas de composition à poser. Les clubs que vous suivez, en face.", 15, PENCIL)
	for x in liste:
		_une_chose(_left, x, t)
	_gap(_left, 12)
	# Une décision déjà dans « À faire » ne se répète pas ici.
	var en_attente: Array = liste.filter(func(x): return x.genre == "dilemme").map(func(x): return x.avis.id)
	var nouveaux: Array = Avis.non_lus().filter(func(a): return not en_attente.has(a.id))
	_text(_left, "Depuis votre dernière visite", 20, INK, true)
	if nouveaux.is_empty():
		_text(_left, "Rien de nouveau au courrier.", 16, INK_LIGHT)
	for a in nouveaux.slice(0, 3):
		var l := _text(_left, "%s, %s  ·  %s" % [Agenda.jour_relatif(int(a.quand), t), Agenda.heure(int(a.quand)), a.titre], 16, INK)
		l.name = "Nouveau"
	if nouveaux.size() > 3:
		_text(_left, "et %d autres." % (nouveaux.size() - 3), 15, PENCIL)
	_link(_left, "→ le courrier" + (" (%d)" % nouveaux.size() if not nouveaux.is_empty() else ""), ouvrir_onglet.bind("courrier")).custom_minimum_size.y = 40
	# En face : les clubs suivis, puis les prochains rendez-vous.
	_title(_right, "Mes clubs")
	var clubs: Array = AUJOURDHUI.clubs(Football, Avis)
	if clubs.is_empty():
		_text(_right, "Vous ne suivez aucun club. Une obligation de club se prend au registre du stade, à l'intersaison ; elle rapporte un dividende chaque journée, et la plus grosse mise dirige.", 16, PENCIL)
	for club in clubs:
		var c: Dictionary = AUJOURDHUI.carte(Football, club)
		if not c.is_empty():
			_une_carte(_right, c, t)
	_gap(_right, 10)
	_text(_right, "Prochains rendez-vous", 20, INK, true)
	for rv in Agenda.prochains(3, t):
		var quand := "en ce moment" if Agenda.en_cours(rv, t) else "%s, %s (%s)" % [Agenda.jour_relatif(rv.quand, t), Agenda.heure(rv.quand), AUJOURDHUI.dans(rv.quand, t)]
		_text(_right, "%s  ·  %s" % [quand, rv.titre], 16, INK_LIGHT if rv.annonce else INK)
	_text(_right, preload("res://scripts/socle/calendrier.gd").resume(Football, "football"), 15, PENCIL)
	_link(_right, "→ toute la semaine", _show_sheet.bind(true, "agenda")).custom_minimum_size.y = 40


## Une chose à faire : l'échéance, ce qu'il faut faire, et le bouton qui le fait (ou les deux choix d'une
## décision de la semaine, tranchés ici même).
func _une_chose(col: VBoxContainer, x: Dictionary, t: int) -> void:
	_gap(col, 6)
	var echeance := "à régler" if x.genre == "bourse" else "avant le coup d'envoi, %s" % AUJOURDHUI.dans(int(x.quand), t)
	if x.genre == "diriger":
		echeance = "l'intersaison ferme %s" % AUJOURDHUI.dans(int(x.quand), t)
	elif x.genre == "mercato":
		echeance = "le mercato ferme %s" % AUJOURDHUI.dans(int(x.quand), t)
	_text(col, echeance, 15, Color(0.65, 0.15, 0.15))
	var titre := _text(col, str(x.titre), 18, INK, true)
	titre.name = "AFaire"
	if str(x.texte) != "":
		_text(col, str(x.texte), 15, PENCIL)
	if x.genre == "dilemme":
		for c in Avis.choix_de(x.avis):
			var b := _link(col, "→ " + str(c.libelle), func():
				Avis.trancher(x.avis, str(c.choix))
				_refresh(), true)
			b.name = "Choix_" + str(c.choix)
			b.custom_minimum_size.y = 36
	elif str(x.bouton) != "":
		var l: Dictionary = x.lien
		var ok: bool = Avis.peut_aller(l)
		var b := _link(col, "→ " + str(x.bouton) + ("" if ok else " (une fois levé de table)"), func(): Avis.aller({"id": "", "lien": l}), ok)
		b.name = "Faire_" + str(x.genre)
		b.custom_minimum_size.y = 36


## La carte d'un club suivi : son nom et sa division, son rang, sa forme en pastilles, son prochain match,
## l'objectif de la direction et sa confiance, et qui dirige.
func _une_carte(col: VBoxContainer, c: Dictionary, t: int) -> void:
	_gap(col, 6)
	var cadre := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = PAPER.darkened(0.035)
	st.border_color = MARGIN_RED
	st.border_width_left = 3
	st.content_margin_left = 12
	st.content_margin_right = 10
	st.content_margin_top = 6
	st.content_margin_bottom = 8
	cadre.add_theme_stylebox_override("panel", st)
	cadre.name = "Club_" + str(c.club)
	col.add_child(cadre)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	cadre.add_child(v)
	_text(v, "%s%s" % [c.nom, "  ·  vous dirigez" if c.dirige else ""], 19, INK, true)
	var place := "%s sur %d, %d pts en %d %s" % [AUJOURDHUI.rang(int(c.rang)), int(c.taille), int(c.pts), int(c.joues), "match" if int(c.joues) <= 1 else "matchs"]
	if int(c.joues) > 0:
		if int(c.rang) > 1:
			place += ", à égalité avec le 1er" if int(c.ecart_tete) == 0 else ", à %d du 1er" % int(c.ecart_tete)
		elif int(c.taille) > 1:
			place += ", en tête"
	_text(v, "%s  ·  %s" % [c.division, place], 16, INK)
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 4)
	v.add_child(ligne)
	_text(ligne, "Forme", 15, PENCIL).autowrap_mode = TextServer.AUTOWRAP_OFF
	if str(c.forme) == "":
		_text(ligne, "pas encore de match joué", 15, PENCIL).autowrap_mode = TextServer.AUTOWRAP_OFF
	for x in str(c.forme):
		_pastille_forme(ligne, x)
	var p: Dictionary = c.prochain
	if not p.is_empty():
		var adv := "%s%s" % [p.nom_adv, " (%s)" % AUJOURDHUI.rang(int(p.rang_adv)) if int(c.joues) > 0 and int(p.rang_adv) > 0 else ""]
		_text(v, "Journée %d, %s à %s, %s : %s %s" % [int(p.j), Agenda.jour_relatif(int(p.quand), t), Agenda.heure(int(p.quand)), AUJOURDHUI.dans(int(p.quand), t),
			"contre" if p.domicile else "chez", adv], 16, INK)
	var o: Dictionary = c.objectif
	var cf: Dictionary = c.confiance
	if not o.is_empty():
		_text(v, "Objectif : %s%s" % [str(o.titre).to_lower(), "  ·  confiance %d sur 100. %s" % [int(cf.valeur), cf.phrase] if not cf.is_empty() else ""], 15, INK_LIGHT)
	if not c.dirige:
		_text(v, str(c.direction), 15, PENCIL)
	var l := {"vers": "bureau", "club": str(c.club), "page": ""}
	var ok: bool = Avis.peut_aller(l)
	_link(v, "→ le bureau du club" + ("" if ok else " (une fois levé de table)"), func(): Avis.aller({"id": "", "lien": l}), ok).custom_minimum_size.y = 32


## Une pastille de forme : V en vert, N en ocre, D en rouge.
func _pastille_forme(parent: Control, lettre: String) -> void:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = VERT if lettre == "V" else (OCRE if lettre == "N" else RED_INK)
	st.set_corner_radius_all(4)
	st.content_margin_left = 6
	st.content_margin_right = 6
	p.add_theme_stylebox_override("panel", st)
	p.name = "Forme_" + lettre
	parent.add_child(p)
	var l := _text(p, lettre, 14, PAPER, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF


# --- Ma carrière : la fortune, le palmarès, les records ------------------------------------------

const CARRIERE := preload("res://scripts/socle/carriere.gd")


## La fortune nette, semaine après semaine : une courbe à l'encre, la plus haute et la plus basse notées.
func _fill_courbe(page: VBoxContainer) -> void:
	var c: Array = CARRIERE.courbe()
	if c.size() < 2:
		_text(page, "La courbe de la fortune se dessine semaine après semaine, à chaque ouverture du carnet.", 15, PENCIL)
		return
	_gap(page, 4)
	_text(page, "La fortune, sur %d semaines" % c.size(), 16, INK, true)
	var k := Courbe.new()
	k.points = c.map(func(x): return int(x[1]))
	k.custom_minimum_size = Vector2(0, 90)
	k.name = "Courbe"
	page.add_child(k)
	var vals: Array = k.points
	_text(page, "de %s à %s" % [Game.fmt(vals.min()), Game.fmt(vals.max())], 14, PENCIL)


class Courbe extends Control:
	var points: Array = []

	func _draw() -> void:
		if points.size() < 2:
			return
		var lo: float = points.min()
		var hi: float = points.max()
		var h := maxf(1.0, hi - lo)
		var pts := PackedVector2Array()
		for i in points.size():
			pts.append(Vector2(6 + (size.x - 12) * i / float(points.size() - 1), size.y - 6 - (size.y - 12) * (float(points[i]) - lo) / h))
		if lo < 0 and hi > 0:
			var y0 := size.y - 6 - (size.y - 12) * (0.0 - lo) / h
			draw_line(Vector2(0, y0), Vector2(size.x, y0), Color(0.7, 0.12, 0.12, 0.4), 1.0)
		draw_polyline(pts, Color(0.12, 0.2, 0.5), 2.0, true)
		draw_circle(pts[pts.size() - 1], 3.5, Color(0.7, 0.12, 0.12))


## Le palmarès des clubs suivis (Football.historique), et quelques records.
func _fill_palmares(page: VBoxContainer) -> void:
	_title(page, "Mon palmarès")
	var rien := true
	for club in AUJOURDHUI.clubs(Football, Avis):
		for x in CARRIERE.palmares(Football, club):
			rien = false
			var place := "%s %s" % [AUJOURDHUI.rang(int(x.rang)), x.division] if int(x.rang) > 0 else ""
			var mots: Array = [place, str(x.titre).to_lower() if place != "" else str(x.titre)].filter(func(m): return m != "")
			_text(page, "Saison %d, %s : %s" % [int(x.saison), _nom_club(club), ", ".join(mots)], 17, RED_INK if str(x.titre) in ["Champion", "Montée"] else INK)
	if rien:
		_text(page, "Aucune saison close avec un club suivi. Le palmarès s'écrit à chaque fin de saison : la place finale, les titres, les montées.", 15, PENCIL)
	_gap(page, 4)
	_text(page, "Records", 18, INK, true)
	_row(page, "La plus haute fortune notée", Game.fmt(maxi(CARRIERE.record(), fortune_nette())), INK_LIGHT)
	_row(page, "Dividendes reçus", Game.fmt(Football.dividendes_total), INK_LIGHT)
	var n := 0
	for club in AUJOURDHUI.clubs(Football, Avis):
		if Football.peut_decider(club):
			n += 1
	_row(page, "Clubs dirigés aujourd'hui", str(n), INK_LIGHT)


# --- Mes clubs : un club par page, et le calendrier ----------------------------------------------

## Les pages de « Mes clubs » : [[clé, nom]], un club suivi par page, puis le calendrier.
func pages_clubs() -> Array:
	var out: Array = AUJOURDHUI.clubs(Football, Avis).map(func(c): return [c, _nom_club(c)])
	out.append(["calendrier", "Le calendrier"])
	return out


func _fill_clubs() -> void:
	var pages := pages_clubs()
	if not pages.any(func(p): return p[0] == _club_vu):
		_club_vu = str(pages[0][0])
	# Les sous-onglets : un mot par page, le sien en gras.
	var rangee := HFlowContainer.new()
	rangee.add_theme_constant_override("h_separation", 6)
	_left.add_child(rangee)
	for p in pages:
		var b := _link(rangee, str(p[1]), func():
			_club_vu = str(p[0])
			_refresh(), str(p[0]) != _club_vu)
		b.name = "Page_" + str(p[0])
		if str(p[0]) == _club_vu:
			b.add_theme_font_override("font", _hand_bold)
			b.add_theme_color_override("font_disabled_color", INK)
	_gap(_left, 4)
	if _club_vu == "calendrier":
		_fill_calendrier()
		return
	_fill_un_club(_club_vu)


## La page d'un club suivi : le classement de son groupe (sa ligne soulignée), ses quatorze journées ; en
## face, l'effectif, les parts et la direction, le calendrier en bref.
func _fill_un_club(club: String) -> void:
	var c: Dictionary = AUJOURDHUI.carte(Football, club)
	if c.is_empty():
		_text(_left, "Ce club n'est plus dans la pyramide.", 16, PENCIL)
		return
	var t: int = Agenda.maintenant()
	_title(_left, str(c.nom))
	_text(_left, "%s, saison %d" % [c.division, int(Football.saison)], 15, PENCIL)
	_gap(_left, 4)
	var place: Array = Football.place_de(club)
	var cl: Array = Football.classement(Football.saison, place[0], place[1])
	var g := GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 12)
	g.name = "Classement"
	_left.add_child(g)
	for h in ["", "Club", "J", "Diff.", "Pts"]:
		_text(g, h, 14, PENCIL).autowrap_mode = TextServer.AUTOWRAP_OFF
	var sauve: int = cl.size() - int(Football.DESCENDENT)
	for i in cl.size():
		var l: Dictionary = cl[i]
		var moi: bool = l.club == club
		var couleur := RED_INK if moi else (INK_LIGHT if i >= sauve and sauve >= 2 else INK)
		for v in [str(i + 1), _nom_club(str(l.club)), str(int(l.j)), ("+" if int(l.diff) > 0 else "") + str(int(l.diff)), str(int(l.pts))]:
			var x := _text(g, v, 16, couleur, moi)
			x.autowrap_mode = TextServer.AUTOWRAP_OFF
			if v == _nom_club(str(l.club)):
				x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				x.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
				x.clip_text = true
	var ecarts: Array = []
	if int(c.joues) > 0:
		ecarts.append("en tête" if int(c.rang) == 1 and int(c.ecart_tete) == 0 and int(c.taille) > 1 else ("à égalité avec le 1er" if int(c.ecart_tete) == 0 else "à %d pts du 1er" % int(c.ecart_tete)))
		if sauve >= 2 and int(c.rang) <= sauve:
			ecarts.append("%d pts d'avance sur la descente" % int(c.ecart_relegation))
		elif sauve >= 2:
			ecarts.append("dans la zone de descente")
	if not ecarts.is_empty():
		_text(_left, ", ".join(ecarts).substr(0, 1).to_upper() + ", ".join(ecarts).substr(1) + ".", 15, INK)
	_text(_left, "Le premier monte, les %d derniers descendent." % int(Football.DESCENDENT), 14, PENCIL)
	_gap(_left, 8)
	_text(_left, "Les quatorze journées", 18, INK, true)
	for j in range(1, int(Football.JOURNEES) + 1):
		var m: Dictionary = FootCourrier.match_de(Football, club, Football.saison, j)
		if m.is_empty():
			continue
		var dom: bool = m.dom == club
		var adv := _nom_club(str(m.ext if dom else m.dom))
		var jour := preload("res://scripts/socle/calendrier.gd").jour_court(Football.coup_envoi(Football.saison, j))
		if not (m.score as Array).is_empty():
			var i := FootCourrier.issue(m, club)
			_text(_left, "J%d  %s  %s %d-%d %s %s" % [j, jour, i.lettre, i.pour, i.contre, "contre" if dom else "chez", adv], 15,
				VERT if i.lettre == "V" else (RED_INK if i.lettre == "D" else OCRE))
		else:
			var prochain: bool = not c.prochain.is_empty() and int(c.prochain.j) == j
			_text(_left, "J%d  %s  %s %s%s" % [j, jour, "contre" if dom else "chez", adv, "  ·  " + AUJOURDHUI.dans(int(c.prochain.quand), t) if prochain else ""], 15,
				INK if prochain else INK_LIGHT, prochain)
	# En face : l'effectif, les parts, le calendrier.
	_title(_right, "L'effectif")
	var eff: Dictionary = Football.effectif(club, Football.saison)
	var ids: Array = eff.keys()
	ids.sort_custom(func(a, b): return int(eff[a].note) > int(eff[b].note) if int(eff[a].note) != int(eff[b].note) else str(a) < str(b))
	var ge := GridContainer.new()
	ge.columns = 4
	ge.add_theme_constant_override("h_separation", 12)
	ge.name = "Effectif"
	_right.add_child(ge)
	for h in ["Joueur", "Poste", "Note", "Moral"]:
		_text(ge, h, 14, PENCIL).autowrap_mode = TextServer.AUTOWRAP_OFF
	for id in ids.slice(0, 11):
		var p: Dictionary = eff[id]
		var nom := _text(ge, "%s %s" % [str(p.get("prenom", "")).left(1) + ".", p.get("nom", "")], 15, INK)
		nom.autowrap_mode = TextServer.AUTOWRAP_OFF
		nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for v in [str(p.get("poste", "")), str(int(p.get("note", 0))), str(int(p.get("moral", 70)))]:
			_text(ge, v, 15, RED_INK if v == str(int(p.get("moral", 70))) and int(p.get("moral", 70)) < 40 else INK).autowrap_mode = TextServer.AUTOWRAP_OFF
	if ids.size() > 11:
		_text(_right, "et %d autres au bureau du club." % (ids.size() - 11), 14, PENCIL)
	_gap(_right, 8)
	_title(_right, "Les parts")
	var miennes: Array = Football.mes_obligations(club)
	_text(_right, "Vous en tenez %d, %s investis." % [miennes.size(), Game.fmt(Football.investi(club))] if not miennes.is_empty() else "Vous n'en tenez aucune.", 16, INK)
	for a in (Football.actionnaires(club) as Array).slice(0, 3):
		_row(_right, "vous" if bool(a.moi) else str(a.nom), Game.fmt(int(a.investi)), INK if bool(a.moi) else INK_LIGHT)
	_text(_right, str(c.direction), 15, PENCIL)
	for x in [["→ le bureau du club", {"vers": "bureau", "club": club, "page": ""}], ["→ le registre des parts", {"vers": "registre", "club": club}]]:
		var l: Dictionary = x[1]
		var ok: bool = Avis.peut_aller(l)
		_link(_right, str(x[0]) + ("" if ok else " (une fois levé de table)"), func(): Avis.aller({"id": "", "lien": l}), ok).custom_minimum_size.y = 34
	_gap(_right, 6)
	_text(_right, preload("res://scripts/socle/calendrier.gd").resume(Football, "football"), 14, PENCIL)


# --- Mon compte : ce qui suit le joueur partout --------------------------------------------------

## Le nom de la banque d'un prêteur, d'après le manifeste de la commune qui le déclare.
func _banque(preteur: String) -> String:
	for id in Communes.ordre:
		var c: Commune = Communes.communes[id]
		if c.preteur() == preteur:
			return str(c.banque().get("nom", c.nom))
	return preteur.capitalize()


## « Le Crédit Smarvois » devient « au Crédit Smarvois », « La Banque » « à la Banque ».
static func _a_la(nom: String) -> String:
	for p in [["Le ", "au "], ["La ", "à la "], ["Les ", "aux "], ["L'", "à l'"], ["L’", "à l’"]]:
		if nom.begins_with(p[0]):
			return p[1] + nom.substr(p[0].length())
	return "à " + nom


## Ce que valent les obligations tenues, reprises par l'étude : club -> crédits.
func _obligations() -> Dictionary:
	var out := {}
	for club in Football.obligations_locales:
		if not Football.mes_obligations(club).is_empty():
			out[club] = int(round(Football.investi(club) * Football.RACHAT))
	return out


## Ce que valent les positions ouvertes en bourse, au dernier cours.
func _en_bourse() -> int:
	var t := 0
	for p in Bourse.ouvertes():
		t += int(p.get("valeur", p.get("garantie", 0)))
	return t


func _nom_club(club: String) -> String:
	return str((Football.clubs.get(club, {}) as Dictionary).get("nom", club))


func fortune_nette() -> int:
	var t := Game.credits + Biens.value() + _en_bourse() - Game.debt
	for club in _obligations():
		t += int(_obligations()[club])
	return t


func _fill_compte() -> void:
	_title(_left, "Mes comptes")
	_gap(_left, 6)
	_row(_left, "Crédits en poche", Game.fmt(Game.credits))
	_row(_left, "Mes biens (estimation à la revente)", Game.fmt(Biens.value()))
	var obl := _obligations()
	for club in obl:
		_row(_left, "Obligations, %s" % _nom_club(club), Game.fmt(int(obl[club])))
	if not Bourse.ouvertes().is_empty():
		_row(_left, "En bourse (au dernier cours)", Game.fmt(_en_bourse()))
	if Game.debts.is_empty():
		_row(_left, "Dettes", "0")
	for preteur in Game.debts:
		_row(_left, "Dette " + _a_la(_banque(str(preteur))), Game.fmt(-Game.debt_of(str(preteur))), RED_INK)
	_row(_left, "Fortune nette", Game.fmt(fortune_nette()), INK, true)
	var v = CARRIERE.variation(fortune_nette(), Agenda.maintenant())
	if v != null:
		_row(_left, "Depuis la semaine dernière", ("+" if int(v) > 0 else "") + Game.fmt(int(v)), VERT if int(v) > 0 else (RED_INK if int(v) < 0 else INK_LIGHT))
	_fill_courbe(_left)
	_gap(_left)
	_text(_left, "Depuis le début", 20, INK, true)
	_row(_left, "Gagné au jeu", Game.fmt(Game.won), INK_LIGHT)
	_row(_left, "Misé", Game.fmt(Game.staked), INK_LIGHT)
	_row(_left, "Dépensé en biens", Game.fmt(Biens.total_spent), INK_LIGHT)
	_row(_left, "Reçu en rentes", Game.fmt(Biens.total_rentes), INK_LIGHT)
	_row(_left, "Payé en charges", Game.fmt(Biens.total_charges), INK_LIGHT)
	if Football.dividendes_total > 0:
		_row(_left, "Reçu en dividendes", Game.fmt(Football.dividendes_total), INK_LIGHT)
	var paris := Paris.bilan()
	if int(paris.tickets) > 0:
		_row(_left, "Parié au comptoir", Game.fmt(int(paris.mise)), INK_LIGHT)
		_row(_left, "Gagné au comptoir", Game.fmt(int(paris.gagne)), INK_LIGHT)
	_fill_palmares(_right)
	_fill_engagements(_right)
	_gap(_right)
	_title(_right, "Ma doublure")
	_text(_right, "Un habitant tenu par votre modèle de langage, qui joue sans vous quelques fois par semaine.", 16, PENCIL)
	_link(_right, "→ ouvrir sa fiche", func():
		_show_sheet(true, "doublure")
		Doublure.lire()).custom_minimum_size.y = 48


## « Mes engagements » (docs/ACTIVITES.md, « Ce que rassemble le carnet ») : ce qui court et où le
## retrouver. On n'y agit pas : chaque ligne dit où aller.
func _fill_engagements(page: VBoxContainer) -> void:
	_gap(page)
	_title(page, "Mes engagements")
	var t := Agenda.maintenant()
	var rien := true
	for tk in Paris.ouverts():
		rien = false
		var regle := Football.coup_envoi(int(tk.s), int(tk.j)) + Paris.REGLEMENT
		var n: int = (tk.choix as Dictionary).size()
		_text(page, "Ticket de la journée %d, %d %s" % [int(tk.j), n, "match" if n == 1 else "matchs"], 18, INK, true)
		_text(page, "misé %s à %s, réglé %s à %s, où que vous soyez" % [Game.fmt(int(tk.mise)), str(tk.cote).replace(".", ","),
			Agenda.jour_relatif(regle, t), Agenda.heure(regle)], 16, INK_LIGHT)
	for club in _obligations():
		rien = false
		var rangs := Football.mes_obligations(club)
		var par_journee := 0
		for r in rangs:
			par_journee += Football.dividende_de(r)
		_text(page, "Obligations de %s" % _nom_club(club), 18, INK, true)
		_text(page, "%d %s, %s investis, %s par journée avant le classement%s" % [rangs.size(),
			"tenue" if rangs.size() == 1 else "tenues", Game.fmt(Football.investi(club)), Game.fmt(par_journee),
			" · vous parlez au président" if Football.peut_decider(club) else ""], 16, INK_LIGHT)
	for p in Bourse.ouvertes():
		rien = false
		var appel := Bourse.en_appel(p)
		_text(page, Bourse.intitule(p), 18, RED_INK if appel else INK, true)
		var r := Bourse.resultat(p)
		_text(page, "garantie %s, %s%s au dernier cours%s" % [Game.fmt(int(p.get("garantie", 0))), "+" if r > 0 else "", Game.fmt(r),
			" · appel de marge : renflouer ou solder à la charge" if appel else ""], 16, RED_INK if appel else INK_LIGHT)
	if rien:
		_text(page, "Rien d'engagé : ni ticket, ni obligation, ni position.", 16, INK_LIGHT)


# --- Les pages des communes : leurs compteurs ----------------------------------------------------

func _nom_commune(id: String) -> String:
	var c: Commune = Communes.commune(id)
	if c != null:
		return c.nom
	return str((Game.carnet.get(id, {}) as Dictionary).get("nom", id.capitalize()))


## Les compteurs d'une commune : ceux de son manifeste quand elle est là, sinon la copie gardée au carnet.
func _compteurs(id: String) -> Array:
	var c: Commune = Communes.commune(id)
	if c != null and c.data.get("carnet") is Array:
		return c.data.carnet
	var s = Game.carnet.get(id)
	if s is Dictionary and s.get("compteurs") is Array:
		return s.compteurs
	return []


## Une valeur telle qu'elle s'écrit sur la page, selon le genre de son compteur.
func _ecrire_valeur(genre: String, v) -> String:
	match genre:
		"credits", "nombre":
			return Game.fmt(int(v)) if v != null else "0"
		"case":
			return "oui" if v == true else "—"
	return str(v) if v != null and str(v) != "" else "—"


func _fill_commune(id: String) -> void:
	var s: Dictionary = Game.carnet.get(id, {})
	var valeurs: Dictionary = s.get("valeurs", {})
	_title(_left, _nom_commune(id))
	if Communes.actuelle() == id:
		_text(_left, "Vous y êtes : la page se tient à jour.", 16, PENCIL)
	elif int(s.get("vu", 0)) > 0:
		_text(_left, "Noté à votre dernier passage, %s." % Agenda.date(int(s.vu)), 16, PENCIL)
	else:
		_text(_left, "Pas encore de passage : la page se remplira sur place.", 16, PENCIL)
	_gap(_left, 6)
	var page := _left
	var rubrique := ""
	var lignes := 0
	for d in _compteurs(id):
		var r := str(d.get("rubrique", ""))
		if lignes >= LIGNES_A_GAUCHE and page == _left and r != rubrique:
			page = _right
		if r != rubrique:
			rubrique = r
			if r != "":
				_gap(page, 6)
				_text(page, r, 20, INK, true)
				lignes += 1
		_row(page, str(d.libelle), _ecrire_valeur(str(d.genre), valeurs.get(str(d.id))), INK_LIGHT if not valeurs.has(str(d.id)) else INK)
		lignes += 1
	if page == _left:
		page = _right
	else:
		_gap(page)
	_fill_reussites(page, id, valeurs)
	_fill_mes_cartes(page, id)
	var e := Communes.au_catalogue(id)
	if str(e.get("description", "")) != "":
		_text(page, str(e.description), 17, INK_LIGHT)
	var c: Commune = Communes.commune(id)
	if c != null and Communes.actuelle() != id:
		_link(page, "→ y aller", _visiter.bind(id))
	elif c == null:
		_text(page, "Elle n'est plus installée : sa page attend votre retour.", 16, PENCIL)


## Les réussites d'une commune : ses compteurs qui se cochent (genre « case »), une fois cochés, en
## tampons à l'encre rouge. Rien si aucun n'est coché.
func _fill_reussites(page: VBoxContainer, id: String, valeurs: Dictionary) -> void:
	var faites := _compteurs(id).filter(func(d): return str(d.get("genre", "")) == "case" and valeurs.get(str(d.id)) == true)
	if faites.is_empty():
		return
	_title(page, "Mes réussites")
	var flot := HFlowContainer.new()
	flot.add_theme_constant_override("h_separation", 8)
	flot.add_theme_constant_override("v_separation", 8)
	page.add_child(flot)
	for d in faites:
		var tampon := PanelContainer.new()
		tampon.name = "Reussite_" + str(d.id)
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.65, 0.15, 0.15, 0.06)
		st.border_color = RED_INK
		st.set_border_width_all(2)
		st.set_corner_radius_all(14)
		st.content_margin_left = 12
		st.content_margin_right = 12
		st.content_margin_top = 3
		st.content_margin_bottom = 3
		tampon.add_theme_stylebox_override("panel", st)
		var l := Label.new()
		l.text = "✓ " + str(d.libelle)
		l.add_theme_font_override("font", _hand_bold)
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", RED_INK)
		tampon.add_child(l)
		flot.add_child(tampon)
	_gap(page, 6)


## Les cartes qu'on tient dans une commune, en petit, et où acheter autre chose : chez son notaire.
func _fill_mes_cartes(page: VBoxContainer, id: String) -> void:
	_title(page, "Mes cartes ici")
	if _album.vignettes(page, id) == 0:
		_text(page, "Aucune carte ici pour l'instant.", 17, INK_LIGHT)
	var notaire := "Pour acheter autre chose, le notaire de %s, sur place." % _nom_commune(id)
	if Communes.origine() != null and id == Communes.origine().id:
		notaire = "Pour acheter autre chose, Maître Garnier, à l'étude."
	_text(page, notaire, 16, PENCIL)
	_link(page, "→ ouvrir mes cartes", func():
		ouvrir_onglet("cartes")
		await get_tree().process_frame
		_album.choisir_village(id))
	_gap(page)


# --- Le calendrier des championnats -----------------------------------------------------------

## Ouvre le carnet à l'onglet du calendrier (les boutons « Le calendrier » du stade et de la salle).
func ouvrir_calendrier() -> void:
	if not _root.visible:
		toggle()
	ouvrir_onglet("calendrier")


## Ouvre « Mes clubs » sur la page d'un club.
func ouvrir_club(club: String) -> void:
	_club_vu = club
	ouvrir_sur("clubs")


func _fill_calendrier() -> void:
	var cal := preload("res://scripts/socle/calendrier.gd")
	for x in [[_left, Football, "football"], [_right, Basket, "basket"]]:
		var page: VBoxContainer = x[0]
		var d: Dictionary = cal.page(x[1], x[2])
		_title(page, d.titre)
		for l in d.lignes:
			if str(l[0]) != "":
				_gap(page, 4)
				_text(page, l[0], 18, INK, true)
			_text(page, l[1], 17 if str(l[0]) != "" else 15, INK if str(l[0]) != "" else INK_LIGHT)
		_gap(page, 8)
		_text(page, "Les journées de la saison %d" % int(d.saison_des_journees), 18, INK, true)
		var g := GridContainer.new()
		g.columns = 4
		g.add_theme_constant_override("h_separation", 14)
		page.add_child(g)
		for j in d.journees:
			var mot := "J%d  %s" % [j.n, j.jour]
			_text(g, ("✓ " if j.jouee else ("→ " if j.prochaine else "")) + mot, 15, RED_INK if j.prochaine else (INK_LIGHT if j.jouee else INK), j.prochaine).autowrap_mode = TextServer.AUTOWRAP_OFF
		_gap(page, 6)
		_text(page, d.regle, 15, INK_LIGHT)
	_gap(_right, 6)
	_link(_right, "→ la semaine, jour par jour", _show_sheet.bind(true, "agenda"))


# --- La Vienne --------------------------------------------------------------------------------

func _fill_vienne() -> void:
	_title(_left, "Les communes de la Vienne")
	_fill_communes(_left, false)
	_title(_right, "Mes passages")
	var vus: Array = Game.carnet.keys().filter(func(id): return int((Game.carnet[id] as Dictionary).get("vu", 0)) > 0)
	vus.sort_custom(func(a, b): return int(Game.carnet[a].vu) > int(Game.carnet[b].vu))
	if vus.is_empty():
		_text(_right, "Aucun passage noté ailleurs pour l'instant.", 17, INK_LIGHT)
	for id in vus:
		_row(_right, _nom_commune(id), Agenda.date(int(Game.carnet[id].vu)), INK)
		if onglets().any(func(o): return o[0] == id):
			_link(_right, "→ ouvrir sa page", ouvrir_onglet.bind(id))
	_gap(_right)
	_link(_right, "→ déplier la carte de la Vienne", _carte).custom_minimum_size.y = 48


func _carte() -> void:
	toggle()
	if Carte.peut_ouvrir():
		Carte.ouvrir()
	else:
		show_slip("La carte de la Vienne se déplie dehors : sur la place, ou dans une commune.")


# --- Ce qu'une commune écrit au carnet ------------------------------------------------------------

## Note la valeur d'un compteur déclaré par la commune (manifeste, champ « carnet »). Une commune n'écrit
## que chez elle, quand le joueur y est ; le socle range la valeur dans sa sauvegarde, avec une copie de
## la déclaration, pour que la page se lise de partout sans monter le paquet. Faux si c'est refusé (la
## raison va dans Communes.refus).
func noter(commune: String, cle: String, valeur) -> bool:
	var c: Commune = Communes.commune(commune)
	if c == null:
		return _refuser(commune, "commune inconnue")
	if Communes.actuelle() != commune:
		return _refuser(commune, "une commune n'écrit au carnet que chez elle, quand le joueur y est")
	var decl := {}
	for d in _compteurs(commune):
		if str(d.get("id", "")) == cle:
			decl = d
	if decl.is_empty():
		return _refuser(commune, "compteur non déclaré : %s" % cle)
	var v = valeur_du_genre(str(decl.genre), valeur)
	if v == null:
		return _refuser(commune, "valeur du mauvais genre pour %s (%s)" % [cle, decl.genre])
	var s := _section(commune)
	(s.valeurs as Dictionary)[cle] = v
	s.vu = Agenda.maintenant()
	Game.save_game()
	if _root.visible:
		_refresh()
	return true


## La valeur notée d'un compteur, ou defaut.
func lire(commune: String, cle: String, defaut = null):
	return ((Game.carnet.get(commune, {}) as Dictionary).get("valeurs", {}) as Dictionary).get(cle, defaut)


## La valeur ramenée à son genre, ou null si elle n'en est pas.
static func valeur_du_genre(genre: String, v):
	match genre:
		"nombre", "credits":
			if typeof(v) == TYPE_INT:
				return v
			if typeof(v) == TYPE_FLOAT and is_finite(v) and v == floorf(v):
				return int(v)
		"texte":
			if typeof(v) == TYPE_STRING or typeof(v) == TYPE_STRING_NAME:
				return str(v).left(Commune.CARNET_TEXTE_MAX)
		"case":
			if typeof(v) == TYPE_BOOL:
				return v
	return null


## La section d'une commune dans la sauvegarde du socle, tenue à jour de son nom et de sa déclaration.
func _section(commune: String) -> Dictionary:
	var s: Dictionary = Game.carnet.get(commune, {})
	if not s.get("valeurs") is Dictionary:
		s.valeurs = {}
	var c: Commune = Communes.commune(commune)
	if c != null:
		s.nom = c.nom
		s.compteurs = (c.data.get("carnet", []) as Array).duplicate(true)
	Game.carnet[commune] = s
	return s


func _refuser(commune: String, raison: String) -> bool:
	Communes.refus.append([commune, "carnet : " + raison])
	push_warning("Carnet.noter(%s) : %s" % [commune, raison])
	return false


## Le joueur arrive dans une commune qui tient des compteurs : la date de son passage se note.
func _noter_passage() -> void:
	var id := Communes.actuelle()
	var o: Commune = Communes.origine()
	if (o != null and id == o.id) or Communes.commune(id) == null or _compteurs(id).is_empty():
		return
	_section(id).vu = Agenda.maintenant()
	Game.save_game()


# --- La feuille dépliée ---------------------------------------------------------------------------

## Déplie (ou replie) la feuille : « agenda », la semaine ; sinon ce que la page d'origine sait déplier.
func _show_sheet(open: bool, mode := "plan") -> void:
	_sheet_mode = mode
	_sheet.visible = open
	_refresh()


func _fill_sheet() -> void:
	if _sheet_mode == "agenda":
		_fill_sheet_agenda()
		return
	if _sheet_mode == "doublure":
		var ecran := _ecran()
		var etroit := ecran.x < 1300.0 or ecran.y < 760.0
		_sheet.custom_minimum_size = Vector2(minf(1148.0, ecran.x - (440.0 if etroit else 24.0)), minf(728.0, ecran.y - 24.0))
		Doublure.remplir(self, _sheet_box, _show_sheet.bind(false, "doublure"))
		return
	if _page_origine == null or not _page_origine.feuille(_sheet_box, _sheet_mode):
		_sheet.visible = false
		_refresh.call_deferred()


## « Les communes de la Vienne » : celles que d'autres ont publiées sur le portail, à installer, et
## celles qui sont installées, où l'on peut aller. La carte de la Vienne les montrera à leur place.
func _fill_communes(page: VBoxContainer = null, titre := true) -> void:
	if page == null:
		page = _right
	if titre:
		_gap(page)
		_title(page, "Les communes de la Vienne")
	# Les mêmes états et les mêmes mots que la bienvenue et la carte (Communes.etat, resume, geste) :
	# d'abord ce qui demande un geste, puis les nouvelles, puis les autres.
	var faire := Communes.a_faire()
	var ids: Array = faire + Communes.a_installer().filter(func(id): return not faire.has(id)) \
		+ Communes.installees().filter(func(id): return not faire.has(id))
	if faire.any(func(id): return Communes.etat(id) in ["mise_a_jour", "echec"]):
		_link(page, "→ tout mettre à jour", Communes.tout_mettre_a_jour)
	for id in ids:
		var e := Communes.au_catalogue(id)
		var c := Communes.commune(id)
		var etat := Communes.etat(id)
		var marque: String = {"mise_a_jour": "  ·  mise à jour", "a_relancer": "  ·  à relancer", "echec": "  ·  échec"}.get(etat,
			"  ·  nouvelle" if Communes.nouvelles.has(id) else "")
		_text(page, str(e.get("nom", c.nom if c else id)) + marque, 18, INK, true)
		_text(page, Communes.resume(id), 18, Color(0.7, 0.12, 0.12) if etat == "echec" else PENCIL)
		if etat in ["publiee", "mise_a_jour"] and str(e.get("description", "")) != "":
			_text(page, e.description, 18, INK_LIGHT)
		if etat in ["telechargement", "attente"]:
			page.add_child(BarreProgres.pour(id, PENCIL, 240.0))
		var g := Communes.geste(id)
		if not g.is_empty():
			_link(page, "→ " + str(g[0]).to_lower(), g[1])
		if c != null:
			_link(page, "→ y aller", _visiter.bind(id))
	if Communes.publiees().is_empty() and Communes.installees().is_empty():
		_text(page, "Aucune autre commune publiée pour l'instant." if Communes.catalogue_etat == "en_ligne" else "Le catalogue se lit quand le jeu est en ligne.", 18, INK_LIGHT)
	for r in Communes.refusees():
		_text(page, "%s : paquet refusé, %s" % [r.nom, r.raison], 18, Color(0.7, 0.12, 0.12))
	_link(page, "→ relire la liste" if Communes.catalogue_etat != "lecture" else "Lecture de la liste…", Communes.lire_catalogue, Communes.catalogue_etat != "lecture")
	Communes.marquer_vues.call_deferred()


func _visiter(id: String) -> void:
	if is_open():
		toggle()
	if not Communes.visiter(id):
		show_slip("%s ne s'ouvre pas : %s" % [Communes.commune(id).nom, Communes.refus[-1][1] if not Communes.refus.is_empty() else "scène introuvable"])


# --- L'agenda de la semaine (autoload Agenda) ------------------------------------------------

## L'écran, dans les unités de l'interface (1600 × 900 sur un ordinateur, moins sur un téléphone).
func _ecran() -> Vector2:
	var v := get_viewport()
	return v.get_visible_rect().size if v != null else Vector2(1600, 900)


## La feuille de la semaine : un jour par paragraphe, l'heure dans la marge, ce qui n'est qu'annoncé au
## crayon. Elle tient dans l'écran (un téléphone : Tactile ramène la base vers 1067 × 600) et défile.
func _fill_sheet_agenda() -> void:
	var ecran := _ecran()
	var etroit := ecran.x < 1300.0 or ecran.y < 760.0
	# Sur un téléphone, la feuille laisse libre le coin du bouton « Fermer » de Tactile.
	_sheet.custom_minimum_size = Vector2(minf(1148.0, ecran.x - (440.0 if etroit else 24.0)), minf(728.0, ecran.y - 24.0))
	var t := Agenda.maintenant()
	var tete := HBoxContainer.new()
	_sheet_box.add_child(tete)
	var titre := _text(tete, "L'agenda de la semaine", 24 if etroit else 26, INK, true)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_link(tete, "← revenir au carnet", _show_sheet.bind(false, "agenda")).custom_minimum_size = Vector2(200, 48)
	_text(_sheet_box, "Du %s au %s. Au crayon, ce qui n'est qu'annoncé : les tables ouvriront plus tard." \
		% [Agenda.date(t), Agenda.date(Agenda.fin_de_semaine(t) - 1)], 15 if etroit else 16, PENCIL)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sheet_box.add_child(scroll)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	scroll.add_child(col)
	var liste := Agenda.semaine(t)
	if liste.is_empty():
		_text(col, "Rien d'annoncé d'ici la semaine prochaine.", 18, INK_LIGHT)
	var jour := ""
	for rv in liste:
		var j := Agenda.jour_relatif(rv.quand, t)
		if j != jour:
			jour = j
			_gap(col, 6)
			var nom := j if j == Agenda.date(rv.quand) else "%s, %s" % [j, Agenda.date(rv.quand)]
			_text(col, nom.left(1).to_upper() + nom.substr(1), 20 if etroit else 21, INK, true)
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 14)
		col.add_child(ligne)
		var h := _text(ligne, "en cours" if Agenda.en_cours(rv, t) else Agenda.heure(rv.quand), 18, Color(0.65, 0.15, 0.15))
		h.custom_minimum_size.x = 88 if etroit else 100
		h.autowrap_mode = TextServer.AUTOWRAP_OFF
		var texte := VBoxContainer.new()
		texte.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texte.add_theme_constant_override("separation", 0)
		ligne.add_child(texte)
		var encre := INK_LIGHT if rv.annonce else INK
		_text(texte, "%s  —  %s" % [rv.titre, rv.lieu] if not etroit else rv.titre, 18, encre, not rv.annonce)
		if etroit:
			_text(texte, rv.lieu, 16, encre)
		var mot: String = rv.detail
		if rv.annonce:
			mot = "Annoncé. " + mot
		if mot != "":
			_text(texte, mot, 15, PENCIL)
	_gap(col, 10)
	_text(col, "Tous les jours, à toute heure", 20 if etroit else 21, INK, true)
	for p in Agenda.TOUS_LES_JOURS:
		_text(col, "%s  —  %s" % [p[0], p[1]], 17, INK_LIGHT)


# --- La fiche de papier ------------------------------------------------------------------------

func show_slip(text: String, avis = null) -> void:
	if _root.visible:
		_pending_slip = text
		_pending_avis = avis
		return
	_slip_avis = avis
	if _slip == null:
		_slip = PanelContainer.new()
		var st := StyleBoxFlat.new()
		st.bg_color = PAPER
		st.set_content_margin_all(12)
		st.content_margin_left = 18
		st.shadow_color = Color(0, 0, 0, 0.4)
		st.shadow_size = 8
		st.border_color = MARGIN_RED
		st.border_width_left = 3
		_slip.add_theme_stylebox_override("panel", st)
		_slip.custom_minimum_size.x = 420
		_slip.gui_input.connect(_clic_fiche)
		add_child(_slip)
		# Sous le carnet : une fiche arrivée juste avant qu'on l'ouvre ne vient pas sur la page.
		move_child(_slip, 0)
		_slip_label = _text(_slip, "", 17)
		_slip_label.custom_minimum_size.x = 400
	_slip_label.text = text
	# Une fiche du courrier se clique : elle mène où dit l'avis. Les autres laissent passer la souris.
	_slip.mouse_filter = Control.MOUSE_FILTER_IGNORE if avis == null else Control.MOUSE_FILTER_STOP
	_slip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_slip.visible = true
	_fit_slip()
	# Le texte ne connaît sa hauteur qu'une fois mis en page : on reprend la mesure à l'image suivante.
	_fit_slip.call_deferred()
	_slip.rotation_degrees = -1.5
	_slip.modulate.a = 0.0
	if _slip_tween:
		_slip_tween.kill()
	var tw := create_tween()
	_slip_tween = tw
	tw.tween_property(_slip, "modulate:a", 1.0, 0.3)
	tw.tween_interval(5.0 + text.length() * 0.03)
	tw.tween_property(_slip, "modulate:a", 0.0, 0.8)
	tw.tween_callback(func(): _slip.visible = false)


## La fiche reprend la taille de son texte, puis se pose en bas à gauche.
func _fit_slip() -> void:
	_slip.reset_size()
	_slip.size = _slip.get_combined_minimum_size()
	_slip.position = Vector2(28, get_viewport().get_visible_rect().size.y - _slip.size.y - 60)


func _clic_fiche(e: InputEvent) -> void:
	if _slip_avis == null or not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	var a: Dictionary = _slip_avis
	_slip_avis = null
	if _slip_tween:
		_slip_tween.kill()
	_slip.visible = false
	get_viewport().set_input_as_handled()
	Avis.aller(a)


# --- Le courrier ------------------------------------------------------------------------------------

## Ouvre le carnet sur un onglet (« courrier », « compte », « cartes »…) ou sur la semaine (« agenda »).
func ouvrir_sur(cle: String) -> void:
	if not _root.visible:
		toggle()
	if cle == "agenda":
		_show_sheet(true, "agenda")
		return
	if _sheet.visible:
		_sheet.visible = false
	ouvrir_onglet(cle)


## La page du courrier : les nouveaux à gauche, les déjà lus à droite ; chacun son heure, son titre, son
## texte et le bouton de l'écran où il mène. Ils sont marqués lus en quittant l'onglet.
func _fill_courrier() -> void:
	var t: int = Avis.maintenant()
	var nouveaux: Array = Avis.non_lus()
	_title(_left, "Le courrier")
	_text(_left, "Ce qui est arrivé : les matchs de vos clubs, les décisions de la semaine, les dividendes, les parts, les tickets, le mercato.", 15, PENCIL)
	_gap(_left, 6)
	_text(_left, "Nouveau" if not nouveaux.is_empty() else "Rien de nouveau.", 21, RED_INK if not nouveaux.is_empty() else INK_LIGHT, true)
	for a in nouveaux:
		_un_avis(_left, a, t, true)
	_title(_right, "Déjà lu")
	var lus: Array = Avis.liste.filter(func(x): return bool(x.lu))
	if lus.is_empty():
		_text(_right, "Le courrier garde les %d derniers avis." % Avis.GARDES, 16, PENCIL)
	for a in lus.slice(0, 30):
		_un_avis(_right, a, t, false)


func _un_avis(col: VBoxContainer, a: Dictionary, t: int, nouveau: bool) -> void:
	_gap(col, 6)
	var quand := Agenda.jour_relatif(int(a.quand), t)
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", 10)
	col.add_child(tete)
	var h := _text(tete, "%s, %s" % [quand, Agenda.heure(int(a.quand))], 15, Color(0.65, 0.15, 0.15))
	h.autowrap_mode = TextServer.AUTOWRAP_OFF
	var titre := _text(col, str(a.titre), 18 if nouveau else 17, INK if nouveau else INK_LIGHT, nouveau)
	titre.name = "Avis"
	if str(a.texte) != "":
		_text(col, str(a.texte), 15, PENCIL)
	# Une décision de la semaine (FootDilemmes) : ses deux choix, ou celui qui est fait.
	var choix: Array = Avis.choix_de(a)
	if not choix.is_empty():
		var fait: Array = choix.filter(func(c): return c.fait)
		if not fait.is_empty():
			_text(col, "Vous avez choisi : %s.%s" % [fait[0].libelle, " Vous pouvez encore changer d'avis avant le coup d'envoi." if fait[0].ouvert else ""], 15, INK, true)
		if choix[0].ouvert:
			for c in choix:
				if c.fait:
					continue
				var b := _link(col, "→ " + str(c.libelle), func():
					Avis.trancher(a, str(c.choix))
					_refresh(), true)
				b.name = "Choix_" + str(c.choix)
				b.custom_minimum_size.y = 36
		elif fait.is_empty():
			_text(col, "Trop tard pour trancher : le match a commencé, ou vous ne dirigez plus le club.", 15, PENCIL)
		return
	var nom: String = Avis.nom_du_lien(a.get("lien", {}))
	if nom != "":
		var ok: bool = Avis.peut_aller(a.lien)
		_link(col, "→ " + nom + ("" if ok else " (une fois levé de table)"), func(): Avis.aller(a), ok).custom_minimum_size.y = 36


## La pastille : « Aujourd'hui : 2 choses à faire · 3 nouvelles », en bas à gauche, quand rien d'autre n'y est
## (ni fiche, ni carnet, ni table). Un clic ouvre la page « Aujourd'hui ». Le compte se relit chaque seconde.
## « Aujourd'hui : 2 choses à faire · 3 nouvelles  (C) ».
func texte_pastille(f: int, n: int) -> String:
	var mots: Array = []
	if f > 0:
		mots.append("une chose à faire" if f == 1 else "%d choses à faire" % f)
	if n > 0:
		mots.append("une nouvelle" if n == 1 else "%d nouvelles" % n)
	return "Aujourd'hui : %s%s" % [" · ".join(mots), "" if Tactile.active else "  (C)"]


func _process(_delta: float) -> void:
	var horloge := Time.get_ticks_msec() / 1000.0
	if horloge - _pastille_lue >= 1.0 or _pastille_lue < 0:
		_pastille_lue = horloge
		_compte_pastille = [a_faire().size(), Avis.non_lus().size()]
	var f: int = _compte_pastille[0]
	var n: int = _compte_pastille[1]
	var montrer: bool = (n > 0 or f > 0) and not _root.visible and not (_slip != null and _slip.visible) and not Avis.occupe()
	if _pastille == null:
		if not montrer:
			return
		_pastille = Button.new()
		_pastille.focus_mode = Control.FOCUS_NONE
		_pastille.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_pastille.add_theme_font_override("font", _hand_bold)
		_pastille.add_theme_font_size_override("font_size", 17)
		for k in ["font_color", "font_hover_color", "font_pressed_color"]:
			_pastille.add_theme_color_override(k, INK)
		for k in ["normal", "hover", "pressed"]:
			var st := StyleBoxFlat.new()
			st.bg_color = PAPER if k == "normal" else PAPER.darkened(0.06)
			st.content_margin_left = 14
			st.content_margin_right = 14
			st.content_margin_top = 6
			st.content_margin_bottom = 6
			st.border_color = MARGIN_RED
			st.border_width_left = 3
			st.shadow_color = Color(0, 0, 0, 0.35)
			st.shadow_size = 5
			_pastille.add_theme_stylebox_override(k, st)
		_pastille.pressed.connect(func(): ouvrir_sur("aujourdhui"))
		add_child(_pastille)
		move_child(_pastille, 0)
	_pastille.visible = montrer
	if montrer:
		_pastille.text = texte_pastille(f, n)
		_pastille.reset_size()
		_pastille.position = Vector2(28, get_viewport().get_visible_rect().size.y - _pastille.size.y - 60)
