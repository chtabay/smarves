extends CanvasLayer
## Le carnet du joueur (autoload « Carnet »), ouvert par C : un cahier d'écolier à petits carreaux,
## écrit à l'encre bleue, partagé par des intercalaires de couleur. Pas de commentaire : les chiffres
## sont alignés, le joueur fait la soustraction. Une fiche de papier glisse en bas de l'écran à chaque
## recette, à chaque reprise d'un bien, à chaque ticket réglé.
##
## Les onglets, de gauche à droite :
## - « Mon compte », tenu par le socle : ce qui suit le joueur d'une commune à l'autre (crédits, dettes
##   par banque, biens, obligations, bourse, fortune nette), la semaine et les engagements en cours ;
## - « Courrier » : les avis du courrier (autoload Avis), les nouveaux sur la page de gauche, les déjà lus
##   à droite, chacun avec le bouton de l'écran où il mène ; le nombre de non lus est sur l'intercalaire ;
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
## L'onglet ouvert : « compte », « vienne » ou l'id d'une commune.
var _onglet := "compte"
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
		if _pending_slip != "":
			show_slip.call_deferred(_pending_slip, _pending_avis)
			_pending_slip = ""
			_pending_avis = null
	else:
		_mouse_before = Input.mouse_mode
		_paused_before = get_tree().paused
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_noter_passage()
		_refresh()
		_root.visible = true
		get_tree().paused = true


# --- Les onglets ----------------------------------------------------------------------------------

## Les onglets du cahier, dans l'ordre : [[clé, nom]].
func onglets() -> Array:
	var n: int = Avis.non_lus().size()
	var out := [["compte", "Mon compte"], ["courrier", "Courrier (%d)" % n if n > 0 else "Courrier"], ["cartes", "Mes cartes"]]
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
		_onglet = "compte"
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
	for c in _left.get_children() + _right.get_children() + _sheet_box.get_children() + _onglets.get_children():
		c.queue_free()
	_cover.visible = not _sheet.visible
	if _sheet.visible:
		_fill_sheet()
		return
	_fill_onglets()
	_spread.visible = _onglet != "cartes"
	_album.visible = _onglet == "cartes"
	match _onglet:
		"compte":
			_fill_compte()
		"cartes":
			_album.remplir()
		"courrier":
			_fill_courrier()
		"vienne":
			_fill_vienne()
		_:
			if _page_origine != null and Communes.origine() != null and _onglet == Communes.origine().id:
				_page_origine.remplir(_left, _right)
			else:
				_fill_commune(_onglet)


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
	_fill_agenda(_right)
	_fill_engagements(_right)


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

## « Cette semaine », en tête de « Mon compte » (sur un téléphone, la page ne tient pas dans l'écran) : les trois
## prochains rendez-vous, et de quoi déplier toute la semaine.
func _fill_agenda(page: VBoxContainer) -> void:
	_title(page, "Cette semaine")
	var t := Agenda.maintenant()
	var liste := Agenda.prochains(3, t)
	if liste.is_empty():
		_text(page, "Rien d'annoncé d'ici la semaine prochaine.", 16, INK_LIGHT)
	for rv in liste:
		var quand := "en ce moment" if Agenda.en_cours(rv, t) else "%s, %s" % [Agenda.jour_relatif(rv.quand, t), Agenda.heure(rv.quand)]
		_text(page, "%s  ·  %s%s" % [quand, rv.titre, "  (annoncé)" if rv.annonce else ""], 17, INK_LIGHT if rv.annonce else INK)
	_link(page, "→ toute la semaine", _show_sheet.bind(true, "agenda")).custom_minimum_size.y = 48


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
	_text(_left, "Ce qui est arrivé : les matchs de vos clubs, les dividendes, les parts, les tickets, le mercato.", 15, PENCIL)
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
	var nom: String = Avis.nom_du_lien(a.get("lien", {}))
	if nom != "":
		var ok: bool = Avis.peut_aller(a.lien)
		_link(col, "→ " + nom + ("" if ok else " (une fois levé de table)"), func(): Avis.aller(a), ok).custom_minimum_size.y = 36


## La pastille : « Courrier : 3 nouvelles », en bas à gauche, quand rien d'autre n'y est (ni fiche, ni carnet,
## ni table). Un clic ouvre le courrier.
func _process(_delta: float) -> void:
	var n: int = Avis.non_lus().size()
	var montrer: bool = n > 0 and not _root.visible and not (_slip != null and _slip.visible) and not Avis.occupe()
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
		_pastille.pressed.connect(func(): ouvrir_sur("courrier"))
		add_child(_pastille)
		move_child(_pastille, 0)
	_pastille.visible = montrer
	if montrer:
		_pastille.text = "Courrier : %s%s" % ["une nouvelle" if n == 1 else "%d nouvelles" % n, "" if Tactile.active else "  (C)"]
		_pastille.reset_size()
		_pastille.position = Vector2(28, get_viewport().get_visible_rect().size.y - _pastille.size.y - 60)
