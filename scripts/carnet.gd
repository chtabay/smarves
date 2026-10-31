extends CanvasLayer
## Le carnet du joueur (autoload « Carnet »), ouvert par C. Depuis le 24 octobre 2026 (demande de Guillaume :
## « reproduire le mécanisme de stimulation de Football Manager dans cette interface », « un UI designer doit
## faire une passe sur ce carnet, voire revoir la DA »), c'est un écran façon Football Manager : des panneaux
## sombres et plats, une typographie sans empattement, les couleurs de chaque club. Une fiche glisse en bas
## de l'écran à chaque recette, à chaque reprise d'un bien, à chaque ticket réglé.
##
## En haut, le bandeau : la date, le prochain match des clubs suivis et son compte à rebours, les crédits et
## la fortune nette. À gauche, cinq rubriques fixes, quel que soit le nombre de villages visités :
## - « Messages » (la boîte, la clé « boite »), la page où le carnet s'ouvre quand quelque chose attend, comme la boîte de réception de
##   Football Manager : à gauche ce qu'il y a à faire, le plus pressé d'abord et chaque ligne avec son bouton
##   (la décision de la semaine se tranche là), puis les messages, nouveaux puis lus ; à droite le message
##   ouvert et ses boutons, ou le résumé du jour : une carte par club suivi, les prochains rendez-vous
##   (scripts/socle/aujourdhui.gd). Un message est lu dès qu'on l'ouvre, ou quand ce qu'il demandait est
##   fait (Avis.solder) ; tous le sont en quittant la boîte, ou d'un clic sur « Tout marquer comme lu » ;
## - « Mes clubs » : une page par club suivi (le classement du groupe, sa ligne soulignée, les quatorze
##   journées, l'effectif, les parts et la direction), puis « Le calendrier » des deux championnats, la
##   journée, l'intersaison, la relève des présidents, le mercato et le marché (scripts/socle/calendrier.gd) ;
## - « Mes biens » : les comptes (crédits, dettes par banque, biens, obligations, bourse, fortune nette), ce
##   qu'on tient village par village, les engagements en cours ; et le classeur des cartes possédées, un
##   sous-onglet par village, avec le topo complet des parts de club (scripts/carnet_cartes.gd) ;
## - « Ma carrière » : la fortune semaine après semaine, le palmarès des clubs suivis, les records, les
##   réussites cochées dans chaque village (scripts/socle/carriere.gd) ;
## - « Les villages » : la liste de tous les villages, qu'on filtre en tapant un nom. Chacun garde sa page :
##   la commune d'origine d'abord, dont la page vient du jeu (le champ « page_carnet » de son manifeste),
##   puis chaque commune qui tient des compteurs au carnet (docs/COMMUNE.md, « Le carnet du joueur ») : ils
##   se lisent de partout, et ne bougent que quand le joueur y est ; enfin « La Vienne », les communes à
##   installer et à visiter.

## Les couleurs de l'écran. Les noms d'origine (papier, encre, crayon) restent : la page de la commune
## d'origine, le pensionnaire et le classeur écrivent avec.
## Depuis le 25 octobre 2026, les teintes du reste du jeu (scripts/socle/teintes.gd) : la nuit chaude, le
## laiton et l'or, à la place de l'ardoise et du bleu vif.
const TEINTES := preload("res://scripts/socle/teintes.gd")
const FOND := TEINTES.NUIT
const BARRE := TEINTES.BARRE
const PAPER := TEINTES.PANNEAU
const CARTE := TEINTES.CARTE
const BOUTON := TEINTES.BOUTON
const LIGNE := TEINTES.FILET
const INK := TEINTES.TEXTE
const INK_LIGHT := TEINTES.DOUX
const PENCIL := TEINTES.CRAYON
const RED_INK := TEINTES.ROUGE
const ACCENT := TEINTES.OR
const MARGIN_RED := ACCENT
const VERT := TEINTES.VERT
const OCRE := TEINTES.OCRE

## Au-delà, les compteurs d'une commune passent sur la page de droite.
const LIGNES_A_GAUCHE := 14
## Les cinq rubriques, dans l'ordre de la barre.
const RUBRIQUES := [["boite", "Messages"], ["clubs", "Mes clubs"], ["biens", "Mes biens"], ["carriere", "Ma carrière"], ["villages", "Les villages"]]
## Les anciens noms d'onglet (les liens du courrier, les écrans du jeu) : la page qu'ils ouvrent maintenant.
const ALIAS := {"aujourdhui": "boite", "courrier": "boite", "compte": "biens"}

var _root: Control
var _left: VBoxContainer
var _right: VBoxContainer
## La barre des rubriques, à gauche, et le bandeau du haut.
var _onglets: VBoxContainer
var _bandeau: HBoxContainer
var _slip: PanelContainer
var _slip_label: Label
var _slip_tween: Tween
## Une fiche arrivée carnet ouvert : elle attend qu'on le referme.
var _pending_slip := ""
## L'avis de la fiche à l'écran (un clic y mène ; {} : le courrier entier), ou null pour une fiche sans suite.
var _slip_avis = null
var _pending_avis = null
## La pastille : tant que quelque chose attend, en bas à gauche, hors table et carnet fermé.
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
## La page ouverte : une rubrique (« boite », « clubs », « biens », « carriere », « villages »), ou une page
## d'une rubrique : « cartes » (le classeur, dans Mes biens), « vienne » ou l'id d'une commune (Les villages).
var _onglet := "boite"
## Ce que dit la pastille, relu chaque seconde : [choses à faire, nouvelles].
var _compte_pastille := [0, 0]
var _pastille_lue := -1.0
## La page de « Mes clubs » ouverte : l'id d'un club suivi, « calendrier », ou « » (le premier club).
var _club_vu := ""
## Le message ouvert à droite de la boîte (son id), ou « » : le résumé du jour.
var _avis_vu := ""
## Ce qu'on a tapé pour filtrer la liste des villages.
var _recherche := ""
var _liste_villages: VBoxContainer
## La page de la commune d'origine (son manifeste, « page_carnet ») : un nœud qui remplit les deux pages.
var _page_origine: Node
## Les deux pages ouvertes, et le classeur de cartes qui prend leur place sous « Mes cartes ».
var _spread: HBoxContainer
var _album: Control
## Le bureau d'un club ouvert par-dessus le carnet (gerer), ou null.
var _gestion: Control


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
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
	Pensionnaire.change.connect(func():
		if _root.visible and _sheet.visible and _sheet_mode == "pensionnaire":
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
	# Le bureau d'un club ouvert par-dessus : c'est lui qui répond (Échap le referme, pas le carnet).
	if _gestion != null:
		return
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
		fermer_gestion()
		_root.visible = false
		_sheet.visible = false
		if _album.zoom_ouvert():
			_album.fermer_zoom()
		Input.mouse_mode = _mouse_before
		get_tree().paused = _paused_before
		if _onglet == "boite":
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
		# Quelque chose attend : le carnet s'ouvre sur la boîte, comme Football Manager.
		Avis.solder()
		if not a_faire().is_empty() or not Avis.non_lus().is_empty():
			_onglet = "boite"
			_avis_vu = ""
		_refresh()
		_root.visible = true
		get_tree().paused = true


# --- Gérer un club sans aller au stade ------------------------------------------------------------

const BUREAU_FOOT := "res://scripts/socle/bureau.gd"
const BUREAU_BASKET := "res://scripts/socle/basket_bureau.gd"
const PARTS_FOOT := "res://scripts/socle/foot_obligations.gd"
const PARTS_BASKET := "res://scripts/socle/basket_parts.gd"
const NOTAIRE := preload("res://scripts/socle/notaire.gd")


## Ouvre le bureau d'un club par-dessus le carnet, où qu'on soit (demande de Guillaume du 24 octobre 2026 :
## « le carnet permet d'aller au stade d'un club mais pas de le gérer »). Football : le bureau du stade
## (bureau.gd), sur la page donnée (tactique, entrainement, offres...). Basket : le bureau du président
## (basket_bureau.gd), page equipe, marche ou comptes. On le referme (Échap) et l'on retrouve le carnet.
## Les parts s'achètent chez le notaire (notaire, ci-dessous).
func gerer(sport: String, club: String, page := "") -> void:
	if club == "":
		return
	var voile := _voile()
	var b: Control
	if sport == "basket":
		b = load(BUREAU_BASKET).new()
		b.commune = club
		if page in ["equipe", "marche", "comptes"]:
			b.page = page
		var centre := CenterContainer.new()
		centre.set_anchors_preset(Control.PRESET_FULL_RECT)
		voile.add_child(centre)
		centre.add_child(b)
	else:
		b = load(BUREAU_FOOT).new()
		b.club = club
		if page != "":
			b.page = page
		# Le registre des parts : le notaire prend la place du bureau.
		b.obligations.connect(func(): notaire.call_deferred("football", club))
		voile.add_child(b)
	b.name = "Bureau"
	b.closed.connect(func():
		# Échap a refermé le bureau : il ne referme pas aussi le carnet.
		if get_viewport() != null:
			get_viewport().set_input_as_handled()
		fermer_gestion()
		_refresh())


## Le registre des parts d'un club, chez le notaire, ouvert « par téléphone » par-dessus le carnet (demande de
## Guillaume du 24 octobre 2026 : « les achats de parts se font chez le notaire comme le reste »). C'est le
## registre de l'étude, où qu'on soit : Maître Garnier signe. Football : FootObligations ; basket : le
## tableau des parts (basket_parts.gd). On le referme (Échap) et l'on retrouve le carnet.
func notaire(sport: String, club: String) -> void:
	if club == "":
		return
	var voile := _voile()
	voile.name = "Notaire"
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.add_child(centre)
	var pile := VBoxContainer.new()
	pile.add_theme_constant_override("separation", 6)
	centre.add_child(pile)
	# Une étiquette sur fond plein : le haut du carnet ne passe pas au travers.
	var tel := PanelContainer.new()
	tel.name = "AuTelephone"
	tel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var st := StyleBoxFlat.new()
	st.bg_color = BARRE
	st.set_corner_radius_all(6)
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	tel.add_theme_stylebox_override("panel", st)
	pile.add_child(tel)
	_text(tel, "%s, au téléphone" % str(NOTAIRE.etude(Commune.smarves()).nom), 15, INK).autowrap_mode = TextServer.AUTOWRAP_OFF
	var p: Control = load(PARTS_BASKET if sport == "basket" else PARTS_FOOT).new()
	if sport == "basket":
		p.commune = club
	else:
		p.club = club
	p.name = "Registre"
	# Le registre du football ne défile pas sur un grand écran : il tient ici dans la hauteur, et défile au-delà.
	var defile := ScrollContainer.new()
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pile.add_child(defile)
	defile.add_child(p)
	var tenir := func():
		var m: Vector2 = p.get_combined_minimum_size()
		defile.custom_minimum_size = Vector2(m.x, minf(m.y, get_viewport().get_visible_rect().size.y - 90.0))
	p.minimum_size_changed.connect(tenir)
	tenir.call()
	p.closed.connect(func():
		if get_viewport() != null:
			get_viewport().set_input_as_handled()
		fermer_gestion()
		_refresh())


## Le voile sombre par-dessus le carnet (ouvert s'il ne l'est pas), qui tient le bureau ou le notaire.
func _voile() -> Control:
	if not _root.visible:
		toggle()
	fermer_gestion()
	var voile := Control.new()
	voile.name = "Gestion"
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.add_child(dim)
	add_child(voile)
	_gestion = voile
	return voile


## Le bureau ou le notaire ouvert par-dessus le carnet, ou null.
func gestion() -> Control:
	return _gestion


func fermer_gestion() -> void:
	if _gestion == null:
		return
	remove_child(_gestion)
	_gestion.queue_free()
	_gestion = null


# --- Les rubriques --------------------------------------------------------------------------------

## Les cinq rubriques de la barre, dans l'ordre : [[clé, nom]].
func onglets() -> Array:
	return RUBRIQUES.duplicate(true)


## La rubrique d'une page : « cartes » est dans Mes biens, une commune et « vienne » dans Les villages.
func rubrique(cle := "") -> String:
	if cle == "":
		cle = _onglet
	cle = str(ALIAS.get(cle, cle))
	if cle == "cartes":
		return "biens"
	if cle == "calendrier":
		return "clubs"
	if RUBRIQUES.any(func(r): return r[0] == cle):
		return cle
	return "villages"


## Le chiffre rouge d'une rubrique : ce qui attend dans la boîte, les communes qui demandent un geste.
func pastille_de(cle: String) -> int:
	match cle:
		"boite":
			var liste := a_faire()
			var en_attente: Array = liste.filter(func(x): return x.genre == "dilemme").map(func(x): return x.avis.id)
			return liste.size() + Avis.non_lus().filter(func(a): return not en_attente.has(a.id)).size()
		"villages":
			return Communes.a_faire().size()
	return 0


## Les villages du carnet, dans l'ordre de la liste : [[id, nom]], la commune d'origine d'abord.
func villages() -> Array:
	var out: Array = []
	var o: Commune = Communes.origine()
	if _page_origine != null and o != null:
		out.append([o.id, o.nom])
	for id in _communes_au_carnet():
		out.append([id, _nom_commune(id)])
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
	cle = str(ALIAS.get(cle, cle))
	if cle != "vienne" and rubrique(cle) == "villages" and cle != "villages" and not villages().any(func(v): return v[0] == cle):
		cle = "villages"
	if cle != _onglet and _album.zoom_ouvert():
		_album.fermer_zoom()
	if rubrique(cle) != "boite" and _onglet == "boite":
		Avis.tout_lu()
	if cle == "boite" and _onglet != "boite":
		_avis_vu = ""
	_onglet = cle
	_amenage = ""
	_refresh()


## Passe à la rubrique suivante (1) ou précédente (-1), en bouclant.
func tourner(sens: int) -> void:
	var cles := RUBRIQUES.map(func(o): return o[0])
	ouvrir_onglet(cles[posmod(cles.find(rubrique()) + sens, cles.size())])


## Les pages d'une rubrique, sous son nom dans la barre : [[clé, nom]].
func _sous_pages(r: String) -> Array:
	match r:
		"clubs":
			# Le nom suffit dans la barre : « (basket) » se lit sur la page.
			return pages_clubs().map(func(p): return [p[0], str(p[1]).trim_suffix(" (basket)")])
		"biens":
			return [["biens", "Mes comptes"], ["cartes", "Mes cartes"]]
		"villages":
			var out: Array = [["villages", "Tous les villages"]]
			var v := villages()
			if not v.is_empty():
				out.append(v[0])
			if _onglet != "vienne" and rubrique() == "villages" and _onglet != "villages" and not out.any(func(x): return x[0] == _onglet):
				out.append([_onglet, _nom_commune(_onglet)])
			out.append(["vienne", "À installer"])
			return out
	return []


func _fill_onglets() -> void:
	var r := rubrique()
	for x in RUBRIQUES:
		var cle: String = x[0]
		var actif: bool = cle == r
		var b := _bouton_barre(_onglets, str(x[1]), actif, 18, 44)
		b.name = "Rubrique_" + cle
		b.pressed.connect(ouvrir_onglet.bind(cle))
		var n := pastille_de(cle)
		if n > 0:
			var p := _badge(b, str(n), RED_INK if cle == "boite" else OCRE)
			p.name = "Pastille"
		if actif:
			for s in _sous_pages(cle):
				var cle_s := str(s[0])
				var vue := cle_s == (_club_vu if cle == "clubs" else _onglet)
				var sb := _bouton_barre(_onglets, str(s[1]), vue, 15, 32, 30, 10)
				sb.name = "Page_" + cle_s
				sb.tooltip_text = str(s[1])
				sb.disabled = vue
				if cle == "clubs":
					sb.pressed.connect(func():
						_club_vu = cle_s
						_refresh())
				else:
					sb.pressed.connect(ouvrir_onglet.bind(cle_s))


## Un bouton de la barre : une rubrique (en gras, le liseré bleu quand elle est ouverte) ou une de ses pages.
func _bouton_barre(parent: Control, t: String, actif: bool, taille: int, haut: int, retrait := 16, droite := 44) -> Button:
	var b := Button.new()
	b.text = t
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size.y = haut
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.clip_text = true
	b.add_theme_font_override("font", _hand_bold if actif else _hand)
	b.add_theme_font_size_override("font_size", taille)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(k, INK if actif or k == "font_hover_color" else INK_LIGHT)
	for k in ["normal", "hover", "pressed", "focus", "disabled"]:
		var st := StyleBoxFlat.new()
		st.bg_color = CARTE if actif else (CARTE.darkened(0.25) if k == "hover" else Color(0, 0, 0, 0))
		st.content_margin_left = retrait
		st.content_margin_right = droite
		st.border_width_left = 3 if actif and taille >= 18 else 0
		st.border_color = ACCENT
		b.add_theme_stylebox_override(k, st)
	parent.add_child(b)
	return b


## Un chiffre dans une pastille, au bord droit d'un bouton.
func _badge(b: Control, t: String, couleur: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = couleur
	st.set_corner_radius_all(9)
	st.content_margin_left = 7
	st.content_margin_right = 7
	p.add_theme_stylebox_override("panel", st)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _text(p, t, 13, FOND, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT, Control.PRESET_MODE_KEEP_SIZE, 12)
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	return p


## Le bandeau du haut : la date, le prochain match et son compte à rebours, les crédits et la fortune.
func _fill_bandeau() -> void:
	var t: int = Agenda.maintenant()
	var gauche := VBoxContainer.new()
	gauche.add_theme_constant_override("separation", -2)
	gauche.custom_minimum_size.x = 204
	_bandeau.add_child(gauche)
	_text(gauche, "LE CARNET", 13, ACCENT, true).autowrap_mode = TextServer.AUTOWRAP_OFF
	_text(gauche, "%s, %s" % [Agenda.date(t), Agenda.heure(t)], 15, INK_LIGHT).autowrap_mode = TextServer.AUTOWRAP_OFF
	var milieu := HBoxContainer.new()
	milieu.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	milieu.add_theme_constant_override("separation", 10)
	milieu.name = "ProchainMatch"
	_bandeau.add_child(milieu)
	var p := prochain_match()
	if p.is_empty():
		_text(milieu, "Aucun match à venir pour vos clubs.", 15, PENCIL).autowrap_mode = TextServer.AUTOWRAP_OFF
	else:
		_ecusson(milieu, p.couleurs, 16)
		var l := _text(milieu, "%s%s %s %s  ·  J%d, %s %s" % ["Basket · " if p.sport == "basket" else "", p.nom, "contre" if p.domicile else "chez", p.nom_adv,
			int(p.j), Agenda.jour_relatif(int(p.quand), t), Agenda.heure(int(p.quand))], 16, INK)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.clip_text = true
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_text(milieu, AUJOURDHUI.dans(int(p.quand), t), 17, ACCENT, true).autowrap_mode = TextServer.AUTOWRAP_OFF
	for x in [["Crédits", Game.fmt(Game.credits)], ["Fortune nette", Game.fmt(fortune_nette())]]:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -2)
		v.custom_minimum_size.x = 120
		_bandeau.add_child(v)
		var a := _text(v, str(x[0]).to_upper(), 12, PENCIL, true)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		a.autowrap_mode = TextServer.AUTOWRAP_OFF
		var b := _text(v, str(x[1]), 18, INK, true)
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
	# La croix, en haut à droite ; les raccourcis dans sa bulle.
	_bandeau.add_child(CROIX.creer(toggle, "Fermer  (C ou Échap)\n← → : changer de rubrique%s" % ("\n↑ ↓ : villages" if _onglet == "cartes" else "")))


## Le prochain match des clubs suivis, football et basket : {sport, club, nom, couleurs, j, quand, domicile,
## nom_adv}, ou {}.
func prochain_match() -> Dictionary:
	var out := {}
	var cartes: Array = AUJOURDHUI.clubs(Football, Avis).map(func(c): return AUJOURDHUI.carte(Football, c))
	cartes += AUJOURDHUI.clubs_basket(Basket).map(func(c): return AUJOURDHUI.carte_basket(Basket, c))
	for c in cartes:
		if c.is_empty() or (c.prochain as Dictionary).is_empty():
			continue
		if out.is_empty() or int(c.prochain.quand) < int(out.quand):
			var sport := str(c.get("sport", "football"))
			out = {"sport": sport, "club": c.club, "nom": c.nom, "couleurs": couleurs_club(sport, str(c.club)), "j": c.prochain.j,
				"quand": c.prochain.quand, "domicile": c.prochain.domicile, "nom_adv": c.prochain.nom_adv}
	return out


## Les deux couleurs d'un club (son maillot), lisibles sur l'écran sombre.
func couleurs_club(sport: String, club: String) -> Array:
	var c: Array = (Basket.fiche(club) if sport == "basket" else (Football.clubs.get(club, {}) as Dictionary)).get("couleurs", ["#5a6a80", "#ffffff"])
	return [Color.html(str(c[0])), Color.html(str(c[1]))]


## Le liseré d'un club sur une carte : sa première couleur, éclaircie si elle se perd dans le fond.
static func _lisere(couleurs: Array) -> Color:
	var c: Color = couleurs[0]
	if c.get_luminance() < 0.3:
		c = couleurs[1] if (couleurs[1] as Color).get_luminance() >= 0.3 else c.lightened(0.45)
	return c


## L'écusson d'un club : un carré à sa première couleur, bordé de la seconde.
func _ecusson(parent: Control, couleurs: Array, cote := 18) -> void:
	var p := Panel.new()
	var st := StyleBoxFlat.new()
	st.bg_color = couleurs[0]
	st.border_color = couleurs[1]
	st.set_border_width_all(2)
	st.set_corner_radius_all(4)
	p.add_theme_stylebox_override("panel", st)
	p.custom_minimum_size = Vector2(cote, cote)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(p)


# --- L'écran -------------------------------------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	# La fenêtre : le bandeau en haut, la barre des rubriques à gauche, les deux panneaux.
	var cover := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = FOND
	cs.set_corner_radius_all(10)
	cs.border_color = Color(TEINTES.LAITON, 0.55)
	cs.set_border_width_all(1)
	cs.shadow_color = Color(0, 0, 0, 0.55)
	cs.shadow_size = 22
	cover.add_theme_stylebox_override("panel", cs)
	center.add_child(cover)
	_cover = cover
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	cover.add_child(col)
	var tete := PanelContainer.new()
	var ts := StyleBoxFlat.new()
	ts.bg_color = BARRE
	ts.corner_radius_top_left = 10
	ts.corner_radius_top_right = 10
	ts.border_color = LIGNE
	ts.border_width_bottom = 1
	ts.content_margin_left = 18
	ts.content_margin_right = 22
	ts.content_margin_top = 8
	ts.content_margin_bottom = 8
	tete.add_theme_stylebox_override("panel", ts)
	tete.custom_minimum_size.y = 52
	col.add_child(tete)
	_bandeau = HBoxContainer.new()
	_bandeau.add_theme_constant_override("separation", 22)
	tete.add_child(_bandeau)
	var corps := HBoxContainer.new()
	corps.add_theme_constant_override("separation", 0)
	col.add_child(corps)
	var barre := PanelContainer.new()
	var bs := StyleBoxFlat.new()
	bs.bg_color = BARRE
	bs.corner_radius_bottom_left = 10
	bs.content_margin_top = 12
	bs.content_margin_bottom = 12
	bs.content_margin_left = 0
	bs.content_margin_right = 0
	barre.add_theme_stylebox_override("panel", bs)
	barre.custom_minimum_size.x = 222
	corps.add_child(barre)
	_onglets = VBoxContainer.new()
	_onglets.add_theme_constant_override("separation", 2)
	barre.add_child(_onglets)
	var marge := MarginContainer.new()
	for k in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		marge.add_theme_constant_override(k, 12)
	corps.add_child(marge)
	var pages := VBoxContainer.new()
	marge.add_child(pages)
	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 12)
	pages.add_child(spread)
	_spread = spread
	_left = _page(spread)
	_right = _page(spread)
	_album = preload("res://scripts/carnet_cartes.gd").new()
	_album.carnet = self
	_album.name = "Cartes"
	_album.visible = false
	pages.add_child(_album)
	_album.custom_minimum_size = Vector2(936, 680)
	# La feuille dépliée, un grand panneau par-dessus la fenêtre.
	_sheet = PanelContainer.new()
	_sheet.custom_minimum_size = Vector2(1148, 728)
	var sh := StyleBoxFlat.new()
	sh.bg_color = PAPER
	sh.set_content_margin_all(26)
	sh.content_margin_left = 34
	sh.set_corner_radius_all(10)
	sh.border_color = LIGNE
	sh.set_border_width_all(1)
	sh.shadow_color = Color(0, 0, 0, 0.55)
	sh.shadow_size = 22
	_sheet.add_theme_stylebox_override("panel", sh)
	_sheet.visible = false
	center.add_child(_sheet)
	_sheet_box = VBoxContainer.new()
	_sheet_box.add_theme_constant_override("separation", 4)
	_sheet.add_child(_sheet_box)


## Un panneau : fond uni, coins arrondis, et ce qu'il contient défile.
func _page(parent: Control) -> VBoxContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(462, 680)
	var st := StyleBoxFlat.new()
	st.bg_color = PAPER
	st.set_corner_radius_all(8)
	st.content_margin_left = 20
	st.content_margin_right = 14
	st.content_margin_top = 16
	st.content_margin_bottom = 14
	p.add_theme_stylebox_override("panel", st)
	parent.add_child(p)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	p.add_child(scroll)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 3)
	scroll.add_child(v)
	return v


func _text(parent: Control, t: String, size := 17, color := INK, bold := false) -> Label:
	var l := Label.new()
	l.text = t
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", _hand_bold if bold else _hand)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


## Le titre d'un panneau, souligné d'un filet.
func _title(parent: Control, t: String) -> void:
	var l := _text(parent, t, 23, INK, true)
	l.add_theme_constant_override("line_spacing", 0)
	var filet := ColorRect.new()
	filet.color = LIGNE
	filet.custom_minimum_size.y = 1
	filet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(filet)
	_gap(parent, 4)


## Un intertitre en petites capitales.
func _rubrique(parent: Control, t: String, couleur := PENCIL) -> Label:
	_gap(parent, 6)
	var l := _text(parent, t.to_upper(), 13, couleur, true)
	return l


## Une ligne de compte : le libellé à gauche, le chiffre à droite.
func _row(parent: Control, label: String, value: String, color := INK, bold := false) -> void:
	var h := HBoxContainer.new()
	parent.add_child(h)
	var a := _text(h, label, 16, color, bold)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := _text(h, value, 16, color, bold)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.autowrap_mode = TextServer.AUTOWRAP_OFF


const PICTOS := preload("res://scripts/socle/pictos.gd")
const CROIX := preload("res://scripts/socle/croix.gd")
const AIDE := preload("res://scripts/socle/aide.gd")


## Un bouton plat, à la couleur de l'écran, son picto devant le mot (scripts/socle/pictos.gd). La flèche
## d'avant (« → le bureau ») tombe : c'est un bouton ; « ← » devient le picto du retour.
func _link(parent: Control, t: String, action: Callable, enabled := true, picto := "") -> Button:
	var b := Button.new()
	b.text = t.trim_prefix("→ ")
	if t.begins_with("→ ") and picto == "":
		picto = "aller"
	if b.text.begins_with("← "):
		b.text = b.text.trim_prefix("← ")
		if picto == "":
			picto = "retour"
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	if b.text.length() > 44:
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	b.add_theme_font_override("font", _hand_bold)
	b.add_theme_font_size_override("font_size", 15)
	for k in ["font_color", "font_pressed_color", "font_focus_color", "icon_normal_color", "icon_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(k, ACCENT)
	b.add_theme_color_override("font_hover_color", Color(1, 0.92, 0.7))
	b.add_theme_color_override("icon_hover_color", Color(1, 0.92, 0.7))
	b.add_theme_color_override("font_disabled_color", PENCIL)
	b.add_theme_color_override("icon_disabled_color", PENCIL)
	if picto != "":
		# Dessiné en blanc, teinté par les couleurs du bouton.
		b.icon = PICTOS.texture(picto, Color.WHITE, 18)
		b.add_theme_constant_override("h_separation", 7)
	for k in ["normal", "hover", "pressed", "focus", "disabled"]:
		var st := StyleBoxFlat.new()
		st.bg_color = {"hover": BOUTON.lightened(0.12), "pressed": BOUTON.darkened(0.1), "disabled": Color(0, 0, 0, 0)}.get(k, BOUTON)
		# Le filet laiton des boutons du jeu (le compteur, les réglages).
		st.border_color = Color(TEINTES.LAITON, 0.25 if k == "disabled" else 0.6)
		st.set_border_width_all(1)
		st.set_corner_radius_all(4)
		st.content_margin_left = 10 if picto != "" else 12
		st.content_margin_right = 12
		st.content_margin_top = 5
		st.content_margin_bottom = 5
		b.add_theme_stylebox_override(k, st)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _gap(parent: Control, h := 10) -> void:
	var c := Control.new()
	c.custom_minimum_size.y = h
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)


## Une carte : un bloc plus clair que le panneau, avec un liseré de couleur à gauche.
func _cadre(col: Control, lisere: Color, nom := "") -> VBoxContainer:
	var cadre := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = CARTE
	st.set_corner_radius_all(6)
	st.border_color = lisere
	st.border_width_left = 4
	st.content_margin_left = 14
	st.content_margin_right = 12
	st.content_margin_top = 8
	st.content_margin_bottom = 10
	cadre.add_theme_stylebox_override("panel", st)
	if nom != "":
		cadre.name = nom
	col.add_child(cadre)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	cadre.add_child(v)
	return v


func _refresh() -> void:
	# Retirés tout de suite : les nouveaux boutons gardent leur nom (« Choix_a », pas « Choix_a2 »).
	for c in _left.get_children() + _right.get_children() + _sheet_box.get_children() + _onglets.get_children() + _bandeau.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	_liste_villages = null
	_cover.visible = not _sheet.visible
	if _sheet.visible:
		_fill_sheet()
		return
	if rubrique() == "villages" and _onglet not in ["villages", "vienne"] and not villages().any(func(v): return v[0] == _onglet):
		_onglet = "villages"
	_fill_bandeau()
	_fill_onglets()
	_spread.visible = _onglet != "cartes"
	_album.visible = _onglet == "cartes"
	match _onglet:
		"boite":
			_fill_boite()
		"biens":
			_fill_compte()
		"carriere":
			_fill_carriere()
		"cartes":
			_album.remplir()
		"clubs":
			_fill_clubs()
		"villages":
			_fill_villages()
		"vienne":
			_fill_vienne()
		_:
			_retour_villages()
			if _page_origine != null and Communes.origine() != null and _onglet == Communes.origine().id:
				_page_origine.remplir(_left, _right)
			else:
				_fill_commune(_onglet)


# --- La boîte : ce qui attend, les messages, le résumé du jour -----------------------------------

const AUJOURDHUI := preload("res://scripts/socle/aujourdhui.gd")


## Ce qui attend le joueur (scripts/socle/aujourdhui.gd), le plus pressé d'abord.
func a_faire() -> Array:
	return AUJOURDHUI.a_faire(Football, Avis, Bourse, Basket)


func _fill_boite() -> void:
	var t: int = Agenda.maintenant()
	Avis.solder()
	_title(_left, "Messages")
	var liste := a_faire()
	var a_faire_l := _rubrique(_left, "À faire (%d)" % liste.size() if not liste.is_empty() else "✓ Rien ne presse", RED_INK if not liste.is_empty() else VERT)
	if liste.is_empty():
		_aide(a_faire_l, "Pas de décision en attente, pas de composition à poser.")
	for x in liste:
		_une_chose(_left, x, t)
	# Une décision déjà dans « À faire » ne se répète pas dans les messages.
	var en_attente: Array = liste.filter(func(x): return x.genre == "dilemme").map(func(x): return x.avis.id)
	var nouveaux: Array = Avis.non_lus().filter(func(a): return not en_attente.has(a.id))
	_rubrique(_left, "Nouveau (%d)" % nouveaux.size() if not nouveaux.is_empty() else "Rien de nouveau", ACCENT if not nouveaux.is_empty() else PENCIL)
	for a in nouveaux:
		_ligne_avis(_left, a, t, true)
	if not nouveaux.is_empty():
		var tout := _link(_left, "Tout marquer comme lu", func():
			Avis.tout_lu()
			_refresh(), true, "choix")
		tout.name = "ToutLu"
	var lus: Array = Avis.liste.filter(func(x): return bool(x.lu) and not en_attente.has(x.id))
	_aide(_rubrique(_left, "Déjà lu (%d)" % lus.size() if not lus.is_empty() else "Déjà lu"), "La boîte garde les %d derniers messages." % Avis.GARDES)
	for a in lus.slice(0, 25):
		_ligne_avis(_left, a, t, false)
	# À droite : le message ouvert, ou le résumé du jour.
	var vu: Array = Avis.liste.filter(func(x): return x.id == _avis_vu)
	if not vu.is_empty():
		_un_avis(_right, vu[0], t)
		return
	_avis_vu = ""
	_fill_resume(t)


## Le résumé du jour, à droite de la boîte : les clubs suivis, puis les prochains rendez-vous.
func _fill_resume(t: int) -> void:
	_title(_right, "Mes clubs")
	var clubs: Array = AUJOURDHUI.clubs(Football, Avis)
	var paniers: Array = AUJOURDHUI.clubs_basket(Basket)
	if clubs.is_empty() and paniers.is_empty():
		_aide(_text(_right, "Aucun club suivi.", 15, PENCIL), "Une obligation de club se prend au registre du stade (football) ou au tableau des parts de la salle (basket), toute l'année ; elle rapporte un dividende chaque journée, et la plus grosse mise dirige.")
	for club in clubs:
		var c: Dictionary = AUJOURDHUI.carte(Football, club)
		if not c.is_empty():
			_une_carte(_right, c, t)
	for club in paniers:
		var c: Dictionary = AUJOURDHUI.carte_basket(Basket, club)
		if not c.is_empty():
			_une_carte(_right, c, t)
	# Les rendez-vous en tableau : quand, dans combien, quoi ; la saison dans le (i).
	_aide(_rubrique(_right, "Prochains rendez-vous"), preload("res://scripts/socle/calendrier.gd").resume(Football, "football"))
	var g := _grille(_right, "Rendez_vous", ["Quand", "Dans", "Quoi"])
	for rv in Agenda.prochains(3, t):
		var en_cours: bool = Agenda.en_cours(rv, t)
		var couleur := INK_LIGHT if rv.annonce else INK
		_ligne_grille(g, ["%s, %s" % [_jour_court(int(rv.quand), t), Agenda.heure(rv.quand)],
			"maintenant" if en_cours else AUJOURDHUI.dans(rv.quand, t), str(rv.titre)], 2, couleur, false)[1].add_theme_color_override("font_color", ACCENT)
	_gap(_right, 4)
	_link(_right, "Toute la semaine", _show_sheet.bind(true, "agenda"), true, "semaine")


## Une chose à faire : l'échéance, ce qu'il faut faire, et le bouton qui le fait (ou les deux choix d'une
## décision de la semaine, tranchés ici même). Le liseré est rouge à moins de six heures de l'échéance.
func _une_chose(col: VBoxContainer, x: Dictionary, t: int) -> void:
	_gap(col, 2)
	var urgent: bool = x.genre == "bourse" or int(x.quand) - t < 6 * 3600
	var v := _cadre(col, RED_INK if urgent else OCRE)
	var echeance := "à régler" if x.genre == "bourse" else "avant le coup d'envoi, %s" % AUJOURDHUI.dans(int(x.quand), t)
	if x.genre == "diriger":
		echeance = "la relève, %s" % AUJOURDHUI.dans(int(x.quand), t)
	elif x.genre == "mercato":
		echeance = "le mercato ferme %s" % AUJOURDHUI.dans(int(x.quand), t)
	_text(v, echeance, 13, RED_INK if urgent else OCRE, true)
	var titre := _text(v, str(x.titre), 17, INK, true)
	titre.name = "AFaire"
	if str(x.texte) != "":
		_text(v, str(x.texte), 14, INK_LIGHT)
	if x.genre == "dilemme":
		_gap(v, 2)
		for c in Avis.choix_de(x.avis):
			var b := _link(v, str(c.libelle), func():
				Avis.trancher(x.avis, str(c.choix))
				# Le message reste ouvert à droite : ce qu'on a choisi, et l'autre choix jusqu'au coup d'envoi.
				_avis_vu = str(x.avis.id)
				_refresh(), true, "choix")
			b.name = "Choix_" + str(c.choix)
	elif str(x.bouton) != "":
		var l: Dictionary = x.lien
		var ok: bool = Avis.peut_aller(l)
		_gap(v, 2)
		var b := _link(v, str(x.bouton), func(): Avis.aller({"id": "", "lien": l}), ok, _picto_du_lien(l))
		b.name = "Faire_" + str(x.genre)
		if not ok:
			b.tooltip_text = "Une fois levé de table."


## Le picto d'un lien d'avis : le bureau et ses pages, le stade, le registre, la semaine.
static func _picto_du_lien(l) -> String:
	if not l is Dictionary:
		return "aller"
	match str(l.get("vers", "")):
		"bureau", "gerer":
			return {"tactique": "tactique", "entrainement": "entrainement", "offres": "mercato", "recherche": "mercato", "marche": "mercato",
				"comptes": "comptes", "effectif": "effectif", "championnat": "classement", "equipe": "effectif"}.get(str(l.get("page", "")), "gerer")
		"notaire", "registre":
			return "registre"
		"stade", "salle":
			return "lieu"
		"agenda":
			return "semaine"
		"carnet":
			return "cartes" if str(l.get("onglet", "")) == "cartes" else "aller"
	return "aller"


## Une ligne de la boîte : un point bleu tant qu'il n'est pas lu, le titre, l'heure. Un clic l'ouvre à droite.
func _ligne_avis(col: VBoxContainer, a: Dictionary, t: int, nouveau: bool) -> void:
	var ouvert: bool = str(a.id) == _avis_vu
	var b := Button.new()
	b.name = "Message"
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size.y = 38
	for k in ["normal", "hover", "pressed", "focus"]:
		var st := StyleBoxFlat.new()
		st.bg_color = BOUTON if ouvert else (CARTE if k == "hover" else Color(0, 0, 0, 0))
		st.set_corner_radius_all(5)
		b.add_theme_stylebox_override(k, st)
	# Ouvert, il est lu : il passe dans « Déjà lu » (Football Manager fait de même).
	b.pressed.connect(func():
		_avis_vu = str(a.id)
		Avis.lire(str(a.id))
		_refresh())
	col.add_child(b)
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.offset_right = -8
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var point := _text(h, "●" if nouveau else " ", 11, ACCENT)
	point.autowrap_mode = TextServer.AUTOWRAP_OFF
	point.custom_minimum_size.x = 10
	point.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var titre := _text(h, str(a.titre), 15, INK if nouveau else INK_LIGHT, nouveau)
	titre.name = "Nouveau" if nouveau else "Avis"
	titre.autowrap_mode = TextServer.AUTOWRAP_OFF
	titre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	titre.clip_text = true
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var quand := _text(h, "%s, %s" % [Agenda.jour_relatif(int(a.quand), t), Agenda.heure(int(a.quand))], 13, PENCIL)
	quand.autowrap_mode = TextServer.AUTOWRAP_OFF
	quand.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for n in h.get_children():
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE


## La carte d'un club suivi : son écusson, son nom et sa division, son rang, sa forme en pastilles, son
## prochain match, l'objectif de la direction et sa confiance, et qui dirige. Un clic ouvre sa page.
func _une_carte(col: VBoxContainer, c: Dictionary, t: int) -> void:
	_gap(col, 2)
	var basket: bool = str(c.get("sport", "")) == "basket"
	var couleurs := couleurs_club("basket" if basket else "football", str(c.club))
	var v := _cadre(col, _lisere(couleurs), ("Basket_" if basket else "Club_") + str(c.club))
	var cadre: Control = v.get_parent()
	cadre.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cadre.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			ouvrir_club(("basket:" if basket else "") + str(c.club)))
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", 8)
	v.add_child(tete)
	_ecusson(tete, couleurs)
	var nom := _text(tete, "%s%s" % ["Basket · " if basket else "", c.nom], 17, INK, true)
	nom.autowrap_mode = TextServer.AUTOWRAP_OFF
	nom.clip_text = true
	nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Qui dirige : un ✓ si c'est vous, sinon le mot de la direction dans le (i).
	var qui := _text(tete, "✓ vous dirigez" if c.dirige else "", 13, VERT, true)
	qui.autowrap_mode = TextServer.AUTOWRAP_OFF
	if not c.dirige:
		qui.queue_free()
		tete.add_child(AIDE.creer(str(c.direction)))
	# Une rangée de chiffres : la division, le rang, les points, la forme.
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 6)
	v.add_child(ligne)
	var chiffres := "%s  ·  %s / %d  ·  %s" % [c.division, AUJOURDHUI.rang(int(c.rang)), int(c.taille), _pts(int(c.pts))] if int(c.joues) > 0 else "%s  ·  saison à venir" % c.division
	_text(ligne, chiffres, 14, INK_LIGHT).autowrap_mode = TextServer.AUTOWRAP_OFF
	var ressort := Control.new()
	ressort.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ligne.add_child(ressort)
	for x in str(c.forme):
		_pastille_forme(ligne, x)
	var p: Dictionary = c.prochain
	if not p.is_empty():
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		v.add_child(h)
		var ic := TextureRect.new()
		ic.texture = PICTOS.texture("semaine", INK_LIGHT, 15)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(ic)
		var adv := "%s%s" % [p.nom_adv, " (%s)" % AUJOURDHUI.rang(int(p.rang_adv)) if int(c.joues) > 0 and int(p.rang_adv) > 0 else ""]
		var l := _text(h, "J%d · %s %s" % [int(p.j), "contre" if p.domicile else "chez", adv], 14, INK)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.tooltip_text = "%s à %s" % [Agenda.jour_relatif(int(p.quand), t), Agenda.heure(int(p.quand))]
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		_text(h, AUJOURDHUI.dans(int(p.quand), t), 14, ACCENT, true).autowrap_mode = TextServer.AUTOWRAP_OFF
	var o: Dictionary = c.objectif
	var cf: Dictionary = c.confiance
	if not o.is_empty():
		# L'objectif en un mot, la confiance en jauge ; la phrase de la direction dans le (i).
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		v.add_child(h)
		_text(h, "Objectif : %s" % str(o.titre).to_lower(), 13, INK_LIGHT).autowrap_mode = TextServer.AUTOWRAP_OFF
		if not cf.is_empty():
			var ressort2 := Control.new()
			ressort2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			h.add_child(ressort2)
			_jauge(h, int(cf.valeur), "Confiance")
			h.add_child(AIDE.creer("Confiance de la direction : %d sur 100. %s" % [int(cf.valeur), cf.phrase]))
	if basket and not p.is_empty():
		_text(v, "Consigne : %s" % ("titulaires" if str(c.consigne) == "titulaires" else "rotation"), 13, INK_LIGHT)
	_gap(v, 2)
	if basket:
		_actions(v, [
			{"picto": "gerer", "mot": "Gérer", "lien": {"vers": "gerer", "sport": "basket", "club": str(c.club), "page": "equipe"}, "nom": "Gerer", "principal": true, "aide": "Le bureau du président, ici même."},
			{"picto": "lieu", "mot": "Salle", "lien": {"vers": "salle", "club": str(c.club)}, "nom": "Salle", "aide": "Aller à la salle du club."}])
	else:
		_actions(v, [
			{"picto": "gerer", "mot": "Gérer", "lien": {"vers": "bureau", "club": str(c.club), "page": ""}, "nom": "Gerer", "principal": true, "aide": "Le bureau du club, ici même."},
			{"picto": "tactique", "mot": "Tactique", "lien": {"vers": "bureau", "club": str(c.club), "page": "tactique"}, "nom": "Tactique", "aide": "La composition du prochain match."},
			{"picto": "lieu", "mot": "Stade", "lien": {"vers": "stade", "club": str(c.club)}, "nom": "Stade", "aide": "Aller au stade du club."}])


## « aujourd'hui », « demain », ou « mer. 25 nov. ».
static func _jour_court(quand: int, t: int) -> String:
	var r := Agenda.jour_relatif(quand, t)
	if r in ["aujourd'hui", "demain"]:
		return r
	return "%s. %s" % [Agenda.date(quand).split(" ")[0].left(3), preload("res://scripts/socle/calendrier.gd").jour_court(quand)]


## Les journées d'un club en tableau, à la Football Manager : J, la date, domicile (⌂) ou extérieur,
## l'adversaire, le résultat en pastille et le score, ou le compte à rebours du prochain match. Chaque
## journée : {j, quand, dom, adv, score ([] si à jouer), issue (V, N, D ou "")}.
func _journees(parent: Control, journees: Array, prochain_j: int, t: int) -> void:
	var g := GridContainer.new()
	g.name = "Journees"
	g.columns = 5
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 2)
	parent.add_child(g)
	var jour_court: Callable = preload("res://scripts/socle/calendrier.gd").jour_court
	for m in journees:
		var joue: bool = not (m.score as Array).is_empty()
		var prochain: bool = int(m.j) == prochain_j
		var couleur := INK if prochain or joue else INK_LIGHT
		_text(g, "J%d" % int(m.j), 13, PENCIL, prochain).autowrap_mode = TextServer.AUTOWRAP_OFF
		_text(g, str(jour_court.call(int(m.quand))), 13, INK_LIGHT).autowrap_mode = TextServer.AUTOWRAP_OFF
		var ic := TextureRect.new()
		ic.texture = PICTOS.texture("maison" if m.dom else "aller", PENCIL if not prochain else INK, 14)
		ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ic.tooltip_text = "à domicile" if m.dom else "à l'extérieur"
		ic.mouse_filter = Control.MOUSE_FILTER_PASS
		g.add_child(ic)
		var adv := _text(g, str(m.adv), 14, couleur, prochain)
		adv.autowrap_mode = TextServer.AUTOWRAP_OFF
		adv.clip_text = true
		adv.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		adv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var res := HBoxContainer.new()
		res.add_theme_constant_override("separation", 5)
		res.alignment = BoxContainer.ALIGNMENT_END
		g.add_child(res)
		if joue:
			_pastille_forme(res, str(m.issue))
			_text(res, "%d-%d" % [int(m.score[0]), int(m.score[1])], 14, INK, true).autowrap_mode = TextServer.AUTOWRAP_OFF
		elif prochain:
			_text(res, AUJOURDHUI.dans(int(m.quand), t), 13, ACCENT, true).autowrap_mode = TextServer.AUTOWRAP_OFF


## Une petite jauge sur 100, comme la confiance des écrans de Football Manager : vert, ocre ou rouge.
func _jauge(parent: Control, valeur: int, nom: String) -> void:
	var fond := PanelContainer.new()
	fond.name = "Jauge_" + nom
	fond.custom_minimum_size = Vector2(70, 8)
	fond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fond.tooltip_text = "%s : %d / 100" % [nom, valeur]
	var st := StyleBoxFlat.new()
	st.bg_color = BOUTON.darkened(0.3)
	st.set_corner_radius_all(3)
	fond.add_theme_stylebox_override("panel", st)
	parent.add_child(fond)
	var plein := ColorRect.new()
	plein.color = VERT if valeur >= 60 else (OCRE if valeur >= 40 else RED_INK)
	plein.custom_minimum_size = Vector2(70.0 * clampf(valeur / 100.0, 0.0, 1.0), 8)
	plein.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	plein.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fond.add_child(plein)
	_text(parent, str(valeur), 13, INK, true).autowrap_mode = TextServer.AUTOWRAP_OFF


## « 1 pt », « 7 pts ».
static func _pts(n: int) -> String:
	return "%d pt%s" % [n, "" if absi(n) <= 1 else "s"]


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
	var l := _text(p, lettre, 13, FOND, true)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF


# --- Ma carrière : la fortune, le palmarès, les records, les réussites ----------------------------

const CARRIERE := preload("res://scripts/socle/carriere.gd")


## « Ma carrière » : à gauche la fortune nette en grand, sa variation et sa courbe, les records ; à droite
## le pensionnaire, le palmarès des clubs suivis, les réussites cochées dans chaque village.
func _fill_carriere() -> void:
	_title(_left, "Ma carrière")
	_rubrique(_left, "Fortune nette")
	var f := fortune_nette()
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	_left.add_child(h)
	_text(h, Game.fmt(f), 34, INK, true).autowrap_mode = TextServer.AUTOWRAP_OFF
	var v = CARRIERE.variation(f, Agenda.maintenant())
	if v != null:
		var l := _text(h, "%s%s depuis la semaine dernière" % ["+" if int(v) > 0 else "", Game.fmt(int(v))], 15, VERT if int(v) > 0 else (RED_INK if int(v) < 0 else INK_LIGHT), true)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		# Sans largeur, le texte replié tombait lettre par lettre.
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.name = "Variation"
	_fill_courbe(_left)
	_fill_records(_left)
	# Le pensionnaire en tête de page : sous les réussites, qui s'allongent à chaque village, il ne se voyait
	# plus sans faire défiler (remarque de Guillaume du 24 octobre 2026).
	_fill_pensionnaire(_right)
	_fill_palmares(_right)
	_fill_succes(_right)


## « Mon pensionnaire » : l'habitant que le modèle de langage du joueur fait vivre. Une carte, et le bouton qui
## ouvre sa fiche (ou le formulaire pour l'enregistrer, s'il n'existe pas encore).
func _fill_pensionnaire(page: VBoxContainer) -> void:
	var v := _cadre(page, ACCENT, "Pensionnaire")
	_text(v, "MON PENSIONNAIRE", 13, PENCIL, true)
	var nom := str((Pensionnaire.fiche as Dictionary).get("nom", ""))
	if nom != "":
		_text(v, nom, 17, INK, true)
	else:
		_text(v, "Un habitant que vous créez et que votre modèle de langage fait vivre, aux événements du village.", 14, INK_LIGHT)
	_gap(v, 2)
	var b := _link(v, "Sa fiche" if nom != "" else "Enregistrer mon pensionnaire", func():
		_show_sheet(true, "pensionnaire")
		Pensionnaire.lire(), true, "fiche")
	b.name = "Ouvrir_pensionnaire"
	_gap(page, 4)


## La fortune nette, semaine après semaine : une courbe, la plus haute et la plus basse notées.
func _fill_courbe(page: VBoxContainer) -> void:
	var c: Array = CARRIERE.courbe()
	if c.size() < 2:
		_aide(_text(page, "Pas encore de courbe.", 14, PENCIL), "La courbe de la fortune se dessine semaine après semaine, à chaque ouverture du carnet.")
		return
	_rubrique(page, "La fortune, sur %d semaines" % c.size())
	var k := Courbe.new()
	k.points = c.map(func(x): return int(x[1]))
	k.custom_minimum_size = Vector2(0, 130)
	k.name = "Courbe"
	page.add_child(k)
	var vals: Array = k.points
	_text(page, "de %s à %s" % [Game.fmt(vals.min()), Game.fmt(vals.max())], 13, PENCIL)


class Courbe extends Control:
	var points: Array = []

	func _draw() -> void:
		draw_style_box(_fond(), Rect2(Vector2.ZERO, size))
		if points.size() < 2:
			return
		var lo: float = points.min()
		var hi: float = points.max()
		var h := maxf(1.0, hi - lo)
		var pts := PackedVector2Array()
		for i in points.size():
			pts.append(Vector2(10 + (size.x - 20) * i / float(points.size() - 1), size.y - 10 - (size.y - 20) * (float(points[i]) - lo) / h))
		if lo < 0 and hi > 0:
			var y0 := size.y - 10 - (size.y - 20) * (0.0 - lo) / h
			draw_line(Vector2(0, y0), Vector2(size.x, y0), Color(RED_INK, 0.4), 1.0)
		var aire := PackedVector2Array(pts)
		aire.append(Vector2(pts[pts.size() - 1].x, size.y - 4))
		aire.append(Vector2(pts[0].x, size.y - 4))
		draw_colored_polygon(aire, Color(ACCENT, 0.12))
		draw_polyline(pts, ACCENT, 2.5, true)
		draw_circle(pts[pts.size() - 1], 4.5, INK)

	static func _fond() -> StyleBoxFlat:
		var st := StyleBoxFlat.new()
		st.bg_color = CARTE
		st.set_corner_radius_all(6)
		return st


## Quelques records : la plus haute fortune, les dividendes, les clubs dirigés.
func _fill_records(page: VBoxContainer) -> void:
	_rubrique(page, "Records")
	_row(page, "La plus haute fortune notée", Game.fmt(maxi(CARRIERE.record(), fortune_nette())), INK_LIGHT)
	_row(page, "Dividendes reçus, football", Game.fmt(Football.dividendes_total), INK_LIGHT)
	_row(page, "Dividendes reçus, basket", Game.fmt(Basket.dividendes_total), INK_LIGHT)
	var n := 0
	for club in AUJOURDHUI.clubs(Football, Avis):
		if Football.peut_decider(club):
			n += 1
	for club in AUJOURDHUI.clubs_basket(Basket):
		if Basket.peut_decider(club):
			n += 1
	_row(page, "Clubs dirigés aujourd'hui", str(n), INK_LIGHT)
	_row(page, "Gagné au jeu, depuis le début", Game.fmt(Game.won), INK_LIGHT)


## Le palmarès des clubs suivis (Football.historique, Basket.historique).
func _fill_palmares(page: VBoxContainer) -> void:
	_title(page, "Mon palmarès")
	var rien := true
	var suivis: Array = AUJOURDHUI.clubs(Football, Avis).map(func(c): return [Football, c, _nom_club(c)])
	suivis += AUJOURDHUI.clubs_basket(Basket).map(func(c): return [Basket, c, "%s (basket)" % Basket.fiche(c).nom])
	for y in suivis:
		for x in CARRIERE.palmares(y[0], y[1]):
			rien = false
			var place := "%s %s" % [AUJOURDHUI.rang(int(x.rang)), x.division] if int(x.rang) > 0 else ""
			var mots: Array = [place, str(x.titre).to_lower() if place != "" else str(x.titre)].filter(func(m): return m != "")
			_text(page, "Saison %d, %s : %s" % [int(x.saison), y[2], ", ".join(mots)], 15, OCRE if str(x.titre) in ["Champion", "Montée"] else INK)
	if rien:
		_aide(_text(page, "Aucune saison close", 14, PENCIL), "Le palmarès s'écrit à chaque fin de saison d'un club suivi : la place finale, les titres, les montées.")


## Les réussites de tous les villages : les compteurs qui se cochent (genre « case »), une fois cochés.
func _fill_succes(page: VBoxContainer) -> void:
	_rubrique(page, "Mes réussites")
	var rien := true
	for v in villages():
		var valeurs: Dictionary = (Game.carnet.get(v[0], {}) as Dictionary).get("valeurs", {})
		if _compteurs(v[0]).any(func(d): return str(d.get("genre", "")) == "case" and valeurs.get(str(d.id)) == true):
			rien = false
			_text(page, str(v[1]), 14, INK_LIGHT, true)
			_fill_reussites(page, v[0], valeurs, false)
	if rien:
		_text(page, "Aucune encore. Chaque village a les siennes : elles se cochent sur place.", 14, PENCIL)


# --- Mes clubs : un club par page, et le calendrier ----------------------------------------------

## Les pages de « Mes clubs » : [[clé, nom]], un club suivi par page, puis le calendrier.
func pages_clubs() -> Array:
	var out: Array = AUJOURDHUI.clubs(Football, Avis).map(func(c): return [c, _nom_club(c)])
	out += AUJOURDHUI.clubs_basket(Basket).map(func(c): return ["basket:" + c, "%s (basket)" % Basket.fiche(c).nom])
	out.append(["calendrier", "Le calendrier"])
	return out


func _fill_clubs() -> void:
	var pages := pages_clubs()
	if not pages.any(func(p): return p[0] == _club_vu):
		_club_vu = str(pages[0][0])
	# Les pages (un club, le calendrier) sont sous « Mes clubs », dans la barre.
	if _club_vu == "calendrier":
		_fill_calendrier()
		return
	if _club_vu.begins_with("basket:"):
		_fill_un_club_basket(_club_vu.trim_prefix("basket:"))
		return
	_fill_un_club(_club_vu)


## La tête de la page d'un club : un bandeau à ses couleurs, son écusson, son nom, sa division.
func _tete_club(sport: String, club: String, nom: String, sous_titre: String) -> void:
	var couleurs := couleurs_club(sport, club)
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = (couleurs[0] as Color).darkened(0.35) if (couleurs[0] as Color).get_luminance() > 0.12 else (couleurs[0] as Color).lightened(0.12)
	st.border_color = _lisere(couleurs)
	st.border_width_bottom = 3
	st.set_corner_radius_all(6)
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", st)
	p.name = "Bandeau_club"
	_left.add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	_ecusson(h, couleurs, 30)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_text(v, nom, 22, INK, true)
	_text(v, sous_titre, 14, INK_LIGHT)
	_gap(_left, 6)


## La page d'un club suivi, à la Football Manager : le bandeau, trois tuiles (rang, points, forme), le
## prochain match en une ligne, la barre d'actions (le bureau s'ouvre ici même), le classement ; en face,
## les journées, les cinq meilleurs joueurs, les parts en une ligne. Les explications vont aux infobulles.
func _fill_un_club(club: String) -> void:
	var c: Dictionary = AUJOURDHUI.carte(Football, club)
	if c.is_empty():
		_text(_left, "Ce club n'est plus dans la pyramide.", 16, PENCIL)
		return
	var t: int = Agenda.maintenant()
	_tete_club("football", club, str(c.nom), "%s, saison %d%s" % [c.division, int(Football.saison), "  ·  vous dirigez" if c.dirige else ""])
	var place: Array = Football.place_de(club)
	var cl: Array = Football.classement(Football.saison, place[0], place[1])
	var sauve: int = cl.size() - int(Football.DESCENDENT)
	_tuiles_club(c, sauve)
	_prochain_club(c, t)
	var bureau := func(p: String) -> Dictionary: return {"vers": "bureau", "club": club, "page": p}
	_actions(_left, [
		{"picto": "gerer", "mot": "Gérer", "lien": bureau.call(""), "nom": "Gerer", "principal": true, "aide": "Le bureau du club : l'accueil, le courrier, la direction."},
		{"picto": "tactique", "mot": "Tactique", "lien": bureau.call("tactique"), "nom": "Tactique", "aide": "La composition et les consignes du prochain match."},
		{"picto": "entrainement", "mot": "Entraînement", "lien": bureau.call("entrainement"), "nom": "Entrainement", "aide": "Le programme de la semaine."},
		{"picto": "mercato", "mot": "Mercato", "lien": bureau.call("recherche"), "nom": "Mercato", "aide": "Chercher des joueurs, suivre les offres."},
		{"picto": "lieu", "mot": "Stade", "lien": {"vers": "stade", "club": club}, "nom": "Stade", "aide": "Aller au stade du club."},
		{"picto": "registre", "mot": "Le notaire", "lien": {"vers": "notaire", "sport": "football", "club": club}, "nom": "Notaire", "aide": "Acheter ou rendre des parts, chez le notaire, par téléphone."},
	])
	_aide(_rubrique(_left, "Classement"), "Le premier monte, les %d derniers descendent." % int(Football.DESCENDENT))
	var g := _grille(_left, "Classement", ["", "Club", "J", "Diff.", "Pts"])
	for i in cl.size():
		var l: Dictionary = cl[i]
		var moi: bool = l.club == club
		var couleur := ACCENT if moi else (INK_LIGHT if i >= sauve and sauve >= 2 else INK)
		_ligne_grille(g, [str(i + 1), _nom_club(str(l.club)), str(int(l.j)), ("+" if int(l.diff) > 0 else "") + str(int(l.diff)), str(int(l.pts))], 1, couleur, moi)
	# En face : les journées, l'effectif, les parts.
	_rubrique(_right, "Journées")
	var journees := []
	for j in range(1, int(Football.JOURNEES) + 1):
		var m: Dictionary = FootCourrier.match_de(Football, club, Football.saison, j)
		if m.is_empty():
			continue
		var dom: bool = m.dom == club
		var x := {"j": j, "quand": Football.coup_envoi(Football.saison, j), "dom": dom, "adv": _nom_club(str(m.ext if dom else m.dom)), "score": [], "issue": ""}
		if not (m.score as Array).is_empty():
			var i := FootCourrier.issue(m, club)
			x.score = [i.pour, i.contre]
			x.issue = i.lettre
		journees.append(x)
	_journees(_right, journees, int(c.prochain.j) if not c.prochain.is_empty() else -1, t)
	_rubrique(_right, "Effectif")
	var eff: Dictionary = Football.effectif(club, Football.saison)
	var ids: Array = eff.keys()
	ids.sort_custom(func(a, b): return int(eff[a].note) > int(eff[b].note) if int(eff[a].note) != int(eff[b].note) else str(a) < str(b))
	var ge := _grille(_right, "Effectif", ["Joueur", "Poste", "Note", "Moral"])
	for id in ids.slice(0, 5):
		var p: Dictionary = eff[id]
		var moral := int(p.get("moral", 70))
		var cases := _ligne_grille(ge, ["%s %s" % [str(p.get("prenom", "")).left(1) + ".", p.get("nom", "")], str(p.get("poste", "")), str(int(p.get("note", 0))), str(moral)], 0, INK, false)
		if moral < 40:
			cases[3].add_theme_color_override("font_color", RED_INK)
	if ids.size() > 5:
		_link(_right, "Les %d joueurs" % ids.size(), func(): gerer("football", club, "effectif"), true, "effectif").name = "Tout_effectif"
	_rubrique(_right, "Parts")
	var miennes: Array = Football.mes_obligations(club)
	_parts(_right, miennes.size(), Football.investi(club), Football.actionnaires(club), str(c.direction))


## La page d'un club de basket suivi : la même ordonnance ; le bureau du président s'ouvre ici même.
func _fill_un_club_basket(club: String) -> void:
	var c: Dictionary = AUJOURDHUI.carte_basket(Basket, club)
	if c.is_empty():
		_text(_left, "Ce club n'est plus au championnat.", 16, PENCIL)
		return
	var t: int = Agenda.maintenant()
	var s: int = Basket.saison
	_tete_club("basket", club, str(c.nom), "Basket, %s, saison %d%s" % [c.division, s, "  ·  vous dirigez" if c.dirige else ""])
	var ici: Array = Basket.place_de(club)
	var cl: Array = Basket.classement(s, ici[0], ici[1])
	var sauve: int = cl.size() - int(Basket.DESCENDENT)
	_tuiles_club(c, sauve)
	_prochain_club(c, t)
	if not c.prochain.is_empty():
		_text(_left, "Consigne : %s" % ("tous les titulaires" if str(c.consigne) == "titulaires" else "rotation"), 13, INK_LIGHT)
	var bureau := func(p: String) -> Dictionary: return {"vers": "gerer", "sport": "basket", "club": club, "page": p}
	_actions(_left, [
		{"picto": "gerer", "mot": "Gérer", "lien": bureau.call("equipe"), "nom": "Gerer", "principal": true, "aide": "Le bureau du président : l'équipe, la consigne du match."},
		{"picto": "mercato", "mot": "Marché", "lien": bureau.call("marche"), "nom": "Marche", "aide": "Les joueurs libres, aux enchères jusqu'au jeudi 22 h."},
		{"picto": "comptes", "mot": "Comptes", "lien": bureau.call("comptes"), "nom": "Comptes", "aide": "La masse salariale, la recette, les obligations."},
		{"picto": "lieu", "mot": "Salle", "lien": {"vers": "salle", "club": club}, "nom": "Salle", "aide": "Aller à la salle du club."},
		{"picto": "registre", "mot": "Le notaire", "lien": {"vers": "notaire", "sport": "basket", "club": club}, "nom": "Notaire", "aide": "Acheter ou rendre des parts, chez le notaire, par téléphone."},
	])
	_aide(_rubrique(_left, "Classement"), "Deux points la victoire, un la défaite. Le premier monte, les %d derniers descendent." % int(Basket.DESCENDENT))
	var g := _grille(_left, "Classement", ["", "Club", "V-D", "Diff.", "Pts"])
	for i in cl.size():
		var l: Dictionary = cl[i]
		var moi: bool = str(l.club) == club
		var diff: int = int(l.pour) - int(l.contre)
		_ligne_grille(g, [str(i + 1), str(Basket.fiche(str(l.club)).nom), "%d-%d" % [int(l.v), int(l.d)], ("+" if diff > 0 else "") + str(diff), str(int(l.pts))], 1,
			ACCENT if moi else (INK_LIGHT if i >= sauve else INK), moi)
	_rubrique(_right, "Journées")
	var journees := []
	for j in range(1, int(Basket.JOURNEES) + 1):
		var m: Dictionary = AUJOURDHUI.match_basket(Basket, club, s, j)
		if m.is_empty():
			continue
		var x := {"j": j, "quand": int(m.quand), "dom": bool(m.dom), "adv": str(Basket.fiche(str(m.adv)).nom), "score": [], "issue": ""}
		if not (m.score as Array).is_empty():
			x.score = [int(m.score[0]), int(m.score[1])]
			x.issue = "V" if int(m.score[0]) > int(m.score[1]) else "D"
		journees.append(x)
	_journees(_right, journees, int(c.prochain.j) if not c.prochain.is_empty() else -1, t)
	_rubrique(_right, "Effectif")
	var j0: int = mini(int(Basket.journee_jouee()) + 1, int(Basket.JOURNEES))
	var joueurs: Array = (Basket.equipe(s, ici[0], ici[1], ici[2], j0).joueurs as Array).duplicate()
	if joueurs.is_empty():
		_text(_right, "Tiré le vendredi d'avant la première journée.", 14, PENCIL)
	else:
		joueurs.sort_custom(func(a, b): return int(a.note) > int(b.note) if int(a.note) != int(b.note) else str(a.code) < str(b.code))
		var ge := _grille(_right, "Effectif", ["Joueur", "Son club", "Note"])
		for x in joueurs.slice(0, 5):
			var dispo := bool(x.get("dispo", true))
			_ligne_grille(ge, [str(x.nom) + ("" if dispo else " (absent)"), str(x.get("club", "")), str(int(x.note))], 0, INK if dispo else PENCIL, false)
		_row(_right, "Masse salariale", "%s / %s" % [Game.fmt(Basket.masse_salariale(club)), Game.fmt(int(Basket.PLAFOND))], INK_LIGHT)
		if joueurs.size() > 5:
			_link(_right, "Les %d joueurs" % joueurs.size(), func(): gerer("basket", club, "equipe"), true, "effectif").name = "Tout_effectif"
	_rubrique(_right, "Parts")
	_parts(_right, (Basket.mes_obligations(club) as Array).size(), Basket.investi(club), Basket.actionnaires(club), str(c.direction))


## Trois tuiles sous le bandeau : le rang (et l'écart au premier), les points, la forme.
func _tuiles_club(c: Dictionary, sauve: int) -> void:
	var h := HBoxContainer.new()
	h.name = "Tuiles"
	h.add_theme_constant_override("separation", 8)
	_left.add_child(h)
	var joues := int(c.joues)
	var ecart := "—"
	if joues > 0:
		ecart = "en tête" if int(c.rang) == 1 and int(c.ecart_tete) == 0 and int(c.taille) > 1 else ("à égalité" if int(c.ecart_tete) == 0 else "à %s du 1er" % _pts(int(c.ecart_tete)))
	var danger: bool = joues > 0 and sauve >= 2 and int(c.rang) > sauve
	var rang := _tuile(h, "Rang", AUJOURDHUI.rang(int(c.rang)) if joues > 0 else "—", "sur %d, %s" % [int(c.taille), ecart] if joues > 0 else "sur %d" % int(c.taille), RED_INK if danger else INK)
	if joues > 0 and sauve >= 2:
		AIDE.poser(rang.get_child(0).get_child(0), "Dans la zone de descente." if danger else "%s d'avance sur la descente." % _pts(int(c.ecart_relegation)))
	_tuile(h, "Points", str(int(c.pts)), "en %d %s" % [joues, "match" if joues <= 1 else "matchs"])
	var f := _tuile(h, "Forme", "", "" if str(c.forme) != "" else "aucun match")
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 3)
	f.get_child(0).add_child(ligne)
	f.get_child(0).move_child(ligne, 1)
	for x in str(c.forme):
		_pastille_forme(ligne, x)
	_gap(_left, 4)


## Une tuile : un intitulé en petites capitales, un chiffre, une précision.
func _tuile(parent: Control, titre: String, valeur: String, sous: String, couleur := INK) -> PanelContainer:
	var p := PanelContainer.new()
	p.name = "Tuile_" + titre
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var st := StyleBoxFlat.new()
	st.bg_color = CARTE
	st.set_corner_radius_all(6)
	st.content_margin_left = 10
	st.content_margin_right = 8
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", st)
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	p.add_child(v)
	_text(v, titre.to_upper(), 11, PENCIL, true)
	if valeur != "":
		_text(v, valeur, 22, couleur, true).autowrap_mode = TextServer.AUTOWRAP_OFF
	if sous != "":
		var s := _text(v, sous, 12, INK_LIGHT)
		s.autowrap_mode = TextServer.AUTOWRAP_OFF
		s.clip_text = true
		s.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return p


## Le prochain match, en une ligne, avec son picto.
func _prochain_club(c: Dictionary, t: int) -> void:
	var p: Dictionary = c.prochain
	if p.is_empty():
		return
	var h := HBoxContainer.new()
	h.name = "Prochain"
	h.add_theme_constant_override("separation", 6)
	_left.add_child(h)
	var ic := TextureRect.new()
	ic.texture = PICTOS.texture("semaine", INK_LIGHT, 16)
	ic.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var adv := "%s%s" % [p.nom_adv, " (%s)" % AUJOURDHUI.rang(int(p.rang_adv)) if int(c.joues) > 0 and int(p.rang_adv) > 0 else ""]
	var l := _text(h, "J%d, %s %s  ·  %s" % [int(p.j), "contre" if p.domicile else "chez", adv, AUJOURDHUI.dans(int(p.quand), t)], 15, INK, true)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.tooltip_text = "%s à %s" % [Agenda.jour_relatif(int(p.quand), t), Agenda.heure(int(p.quand))]
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	_gap(_left, 2)


## La barre d'actions : un picto et un mot par bouton, l'explication en infobulle. Chaque action est un lien
## (Avis.aller) ; un lien qui change de lieu reste grisé à table. [{picto, mot, lien, nom, principal, aide}]
func _actions(parent: Control, liste: Array) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.name = "Actions"
	f.add_theme_constant_override("h_separation", 6)
	f.add_theme_constant_override("v_separation", 6)
	parent.add_child(f)
	for x in liste:
		var l: Dictionary = x.lien
		var ok: bool = Avis.peut_aller(l)
		var b := _link(f, str(x.mot), func(): Avis.aller({"id": "", "lien": l}), ok, str(x.picto))
		b.name = "Action_" + str(x.nom)
		b.tooltip_text = str(x.get("aide", "")) + ("" if ok else "\nUne fois levé de table.")
		b.custom_minimum_size.y = 34
		if bool(x.get("principal", false)):
			_principal(b)
	_gap(parent, 4)
	return f


## Le bouton principal : plein, à la couleur d'accent.
func _principal(b: Button) -> void:
	for k in ["normal", "hover", "pressed", "focus"]:
		var st: StyleBoxFlat = (b.get_theme_stylebox(k) as StyleBoxFlat).duplicate()
		st.bg_color = {"hover": ACCENT.lightened(0.12), "pressed": ACCENT.darkened(0.12)}.get(k, ACCENT)
		b.add_theme_stylebox_override(k, st)
	for k in ["font_color", "font_pressed_color", "font_focus_color", "font_hover_color", "icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(k, FOND)


## Un (i) juste après un texte : l'explication au survol ou au toucher (scripts/socle/aide.gd).
func _aide(c: Control, t: String) -> void:
	AIDE.poser(c, t)


## Une grille à en-têtes (le classement, l'effectif).
func _grille(parent: Control, nom: String, titres: Array) -> GridContainer:
	var g := GridContainer.new()
	g.columns = titres.size()
	g.add_theme_constant_override("h_separation", 12)
	g.add_theme_constant_override("v_separation", 1)
	g.name = nom
	parent.add_child(g)
	for h in titres:
		_text(g, h, 13, PENCIL).autowrap_mode = TextServer.AUTOWRAP_OFF
	return g


## Une ligne de grille ; la colonne « large » prend la place qui reste, coupée au besoin.
func _ligne_grille(g: GridContainer, valeurs: Array, large: int, couleur: Color, gras: bool) -> Array:
	var out := []
	for i in valeurs.size():
		var x := _text(g, str(valeurs[i]), 15, couleur, gras)
		x.autowrap_mode = TextServer.AUTOWRAP_OFF
		if i == large:
			x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			x.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			x.clip_text = true
		out.append(x)
	return out


## Les parts en une ligne (combien on en tient, ce qu'on y a mis), puis le premier actionnaire ; qui dirige
## dans le (i).
func _parts(parent: Control, n: int, investi: int, actionnaires: Array, direction: String) -> void:
	var l := _text(parent, "Vous en tenez %d, %s investis." % [n, Game.fmt(investi)] if n > 0 else "Vous n'en tenez aucune.", 15, INK)
	l.name = "Parts"
	if direction != "":
		_aide(l, direction)
	for a in actionnaires.slice(0, 2):
		_row(parent, "vous" if bool(a.moi) else str(a.nom), Game.fmt(int(a.investi)), INK if bool(a.moi) else INK_LIGHT)


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


## Les obligations de basket qu'on tient, à leur valeur de reprise : club -> crédits.
func _obligations_basket() -> Dictionary:
	var out := {}
	for club in AUJOURDHUI.clubs_basket(Basket):
		out[club] = int(round(Basket.investi(club) * Basket.RACHAT))
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
	for club in _obligations_basket():
		t += int(_obligations_basket()[club])
	return t


## « Mes biens » : à gauche les comptes (ce qui fait la fortune nette) et ce qui est passé par les mains depuis
## le début ; à droite ce qu'on tient village par village, en petites cartes, et les engagements en cours.
func _fill_compte() -> void:
	_title(_left, "Mes comptes")
	_row(_left, "Crédits en poche", Game.fmt(Game.credits))
	_row(_left, "Mes biens (estimation à la revente)", Game.fmt(Biens.value()))
	var obl := _obligations()
	for club in obl:
		_row(_left, "Obligations, %s" % _nom_club(club), Game.fmt(int(obl[club])))
	var obb := _obligations_basket()
	for club in obb:
		_row(_left, "Obligations, %s (basket)" % Basket.fiche(club).nom, Game.fmt(int(obb[club])))
	if not Bourse.ouvertes().is_empty():
		_row(_left, "En bourse (au dernier cours)", Game.fmt(_en_bourse()))
	if Game.debts.is_empty():
		_row(_left, "Dettes", "0")
	for preteur in Game.debts:
		_row(_left, "Dette " + _a_la(_banque(str(preteur))), Game.fmt(-Game.debt_of(str(preteur))), RED_INK)
	_gap(_left, 2)
	_row(_left, "Fortune nette", Game.fmt(fortune_nette()), INK, true)
	var v = CARRIERE.variation(fortune_nette(), Agenda.maintenant())
	if v != null:
		_row(_left, "Depuis la semaine dernière", ("+" if int(v) > 0 else "") + Game.fmt(int(v)), VERT if int(v) > 0 else (RED_INK if int(v) < 0 else INK_LIGHT))
	_rubrique(_left, "Depuis le début")
	_row(_left, "Gagné au jeu", Game.fmt(Game.won), INK_LIGHT)
	_row(_left, "Misé", Game.fmt(Game.staked), INK_LIGHT)
	_row(_left, "Dépensé en biens", Game.fmt(Biens.total_spent), INK_LIGHT)
	_row(_left, "Reçu en rentes", Game.fmt(Biens.total_rentes), INK_LIGHT)
	_row(_left, "Payé en charges", Game.fmt(Biens.total_charges), INK_LIGHT)
	if Football.dividendes_total + Basket.dividendes_total > 0:
		_row(_left, "Reçu en dividendes", Game.fmt(Football.dividendes_total + Basket.dividendes_total), INK_LIGHT)
	var paris := Paris.bilan()
	if int(paris.tickets) > 0:
		_row(_left, "Parié au comptoir", Game.fmt(int(paris.mise)), INK_LIGHT)
		_row(_left, "Gagné au comptoir", Game.fmt(int(paris.gagne)), INK_LIGHT)
	_fill_possessions(_right)
	_fill_engagements(_right)


## Ce qu'on tient, village par village : le compte des cartes, leurs vignettes, et le classeur.
func _fill_possessions(page: VBoxContainer) -> void:
	_title(page, "Ce que je possède")
	for x in _album.villages():
		var id := str(x.id)
		var n := 0
		for c in _album.cartes(id):
			n += int(c.n)
		var etab: int = _album.etablissements(id).size()
		var clubs: int = _album.clubs(id).filter(func(c): return not (Football if c.sport == "football" else Basket).mes_obligations(str(c.club)).is_empty()).size()
		var mots: Array = []
		if n > 0:
			mots.append("%d bien%s" % [n, "s" if n > 1 else ""])
		if etab > 0:
			mots.append("%d établissement%s" % [etab, "s" if etab > 1 else ""])
		if clubs > 0:
			mots.append("%d club%s" % [clubs, "s" if clubs > 1 else ""])
		var tete := HBoxContainer.new()
		page.add_child(tete)
		var nom := _text(tete, str(x.nom), 16, INK, true)
		nom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_text(tete, " · ".join(mots) if not mots.is_empty() else "rien pour l'instant", 14, INK_LIGHT if not mots.is_empty() else PENCIL).autowrap_mode = TextServer.AUTOWRAP_OFF
		_album.vignettes(page, id, 0.3, 10)
		_gap(page, 4)
	_link(page, "Le classeur de cartes", ouvrir_onglet.bind("cartes"), true, "cartes")


## « Mes engagements » (docs/ACTIVITES.md, « Ce que rassemble le carnet ») : ce qui court et où le
## retrouver. On n'y agit pas : chaque ligne dit où aller.
func _fill_engagements(page: VBoxContainer) -> void:
	_gap(page, 6)
	_title(page, "Mes engagements")
	var t := Agenda.maintenant()
	var rien := true
	for tk in Paris.ouverts():
		rien = false
		var regle := Football.coup_envoi(int(tk.s), int(tk.j)) + Paris.REGLEMENT
		var n: int = (tk.choix as Dictionary).size()
		_text(page, "Ticket de la journée %d, %d %s" % [int(tk.j), n, "match" if n == 1 else "matchs"], 16, INK, true)
		_text(page, "misé %s à %s, réglé %s à %s, où que vous soyez" % [Game.fmt(int(tk.mise)), str(tk.cote).replace(".", ","),
			Agenda.jour_relatif(regle, t), Agenda.heure(regle)], 14, INK_LIGHT)
	for club in _obligations():
		rien = false
		var rangs := Football.mes_obligations(club)
		var par_journee := 0
		for r in rangs:
			par_journee += Football.dividende_de(r)
		_text(page, "Obligations de %s" % _nom_club(club), 16, INK, true)
		_text(page, "%d %s, %s investis, %s par journée avant le classement%s" % [rangs.size(),
			"tenue" if rangs.size() == 1 else "tenues", Game.fmt(Football.investi(club)), Game.fmt(par_journee),
			" · vous parlez au président" if Football.peut_decider(club) else ""], 14, INK_LIGHT)
	for club in _obligations_basket():
		rien = false
		var rangs: Array = Basket.mes_obligations(club)
		_text(page, "Obligations de %s (basket)" % Basket.fiche(club).nom, 16, INK, true)
		_text(page, "%d %s, %s investis, un dividende par journée jouée : la recette moins les salaires%s" % [rangs.size(),
			"tenue" if rangs.size() == 1 else "tenues", Game.fmt(Basket.investi(club)), " · vous dirigez le club" if Basket.peut_decider(club) else ""], 14, INK_LIGHT)
	for p in Bourse.ouvertes():
		rien = false
		var appel := Bourse.en_appel(p)
		_text(page, Bourse.intitule(p), 16, RED_INK if appel else INK, true)
		var r := Bourse.resultat(p)
		_text(page, "garantie %s, %s%s au dernier cours%s" % [Game.fmt(int(p.get("garantie", 0))), "+" if r > 0 else "", Game.fmt(r),
			" · appel de marge : renflouer ou solder à la charge" if appel else ""], 16, RED_INK if appel else INK_LIGHT)
	if rien:
		_text(page, "Rien d'engagé : ni ticket, ni obligation, ni position.", 14, INK_LIGHT)


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
	var section := ""
	var lignes := 0
	for d in _compteurs(id):
		var r := str(d.get("rubrique", ""))
		if lignes >= LIGNES_A_GAUCHE and page == _left and r != section:
			page = _right
		if r != section:
			section = r
			if r != "":
				_gap(page, 6)
				_text(page, r, 18, INK, true)
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
func _fill_reussites(page: VBoxContainer, id: String, valeurs: Dictionary, titre := true) -> void:
	var faites := _compteurs(id).filter(func(d): return str(d.get("genre", "")) == "case" and valeurs.get(str(d.id)) == true)
	if faites.is_empty():
		return
	if titre:
		_title(page, "Mes réussites")
	var flot := HFlowContainer.new()
	flot.add_theme_constant_override("h_separation", 8)
	flot.add_theme_constant_override("v_separation", 8)
	page.add_child(flot)
	for d in faites:
		var tampon := PanelContainer.new()
		tampon.name = "Reussite_" + str(d.id)
		var st := StyleBoxFlat.new()
		st.bg_color = Color(OCRE, 0.12)
		st.border_color = OCRE
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
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", OCRE)
		tampon.add_child(l)
		flot.add_child(tampon)
	_gap(page, 6)


## Les cartes qu'on tient dans une commune, en petit, et où acheter autre chose : chez son notaire.
func _fill_mes_cartes(page: VBoxContainer, id: String) -> void:
	_title(page, "Mes cartes ici")
	if _album.vignettes(page, id) == 0:
		_text(page, "Aucune carte ici pour l'instant.", 15, INK_LIGHT)
	var notaire := "Pour acheter autre chose, le notaire de %s, sur place." % _nom_commune(id)
	if Communes.origine() != null and id == Communes.origine().id:
		notaire = "Pour acheter autre chose, Maître Garnier, à l'étude."
	_text(page, notaire, 14, PENCIL)
	_link(page, "Mes cartes d'ici", func():
		ouvrir_onglet("cartes")
		await get_tree().process_frame
		_album.choisir_village(id), true, "cartes")
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
			_text(g, ("✓ " if j.jouee else ("→ " if j.prochaine else "")) + mot, 15, ACCENT if j.prochaine else (INK_LIGHT if j.jouee else INK), j.prochaine).autowrap_mode = TextServer.AUTOWRAP_OFF
		_gap(page, 6)
		_text(page, d.regle, 15, INK_LIGHT)
	_gap(_right, 6)
	_link(_right, "La semaine, jour par jour", _show_sheet.bind(true, "agenda"), true, "semaine")


# --- Les villages : la liste, et la Vienne --------------------------------------------------------

## « Les villages » : la liste de tous les villages du carnet, filtrée par ce qu'on tape ; chacun s'ouvre sur
## sa page. En face, les derniers passages, et la Vienne (les communes à installer).
func _fill_villages() -> void:
	_title(_left, "Les villages")
	var champ := LineEdit.new()
	champ.name = "Recherche"
	champ.placeholder_text = "Chercher un village"
	champ.text = _recherche
	champ.clear_button_enabled = true
	champ.add_theme_font_override("font", _hand)
	champ.add_theme_font_size_override("font_size", 16)
	champ.add_theme_color_override("font_color", INK)
	champ.add_theme_color_override("font_placeholder_color", PENCIL)
	champ.add_theme_color_override("caret_color", ACCENT)
	for k in ["normal", "focus"]:
		var st := StyleBoxFlat.new()
		st.bg_color = CARTE
		st.set_corner_radius_all(6)
		st.border_color = ACCENT if k == "focus" else LIGNE
		st.set_border_width_all(1)
		st.content_margin_left = 12
		st.content_margin_right = 8
		st.content_margin_top = 6
		st.content_margin_bottom = 6
		champ.add_theme_stylebox_override(k, st)
	champ.text_changed.connect(func(t: String):
		_recherche = t
		_remplir_liste_villages())
	_left.add_child(champ)
	_gap(_left, 4)
	_liste_villages = VBoxContainer.new()
	_liste_villages.add_theme_constant_override("separation", 4)
	_left.add_child(_liste_villages)
	_remplir_liste_villages()
	_title(_right, "Mes passages")
	var vus: Array = Game.carnet.keys().filter(func(id): return int((Game.carnet[id] as Dictionary).get("vu", 0)) > 0)
	vus.sort_custom(func(a, b): return int(Game.carnet[a].vu) > int(Game.carnet[b].vu))
	if vus.is_empty():
		_text(_right, "Aucun passage noté ailleurs pour l'instant.", 15, INK_LIGHT)
	for id in vus.slice(0, 8):
		_row(_right, _nom_commune(id), Agenda.date(int(Game.carnet[id].vu)), INK)
	_rubrique(_right, "La Vienne")
	var n: int = Communes.a_faire().size()
	_text(_right, "Les communes publiées sur le portail, à installer et à visiter%s." % (" : %d demande%s un geste" % [n, "nt" if n > 1 else ""] if n > 0 else ""), 14, PENCIL)
	_link(_right, "Les communes à installer", ouvrir_onglet.bind("vienne"), true, "installer")
	_link(_right, "La carte de la Vienne", _carte, true, "carte")


## Les lignes de la liste des villages : une carte par village dont le nom contient ce qu'on a tapé.
func _remplir_liste_villages() -> void:
	if _liste_villages == null:
		return
	for c in _liste_villages.get_children():
		_liste_villages.remove_child(c)
		c.queue_free()
	var cherche := _recherche.strip_edges().to_lower()
	var trouves: Array = villages().filter(func(v): return cherche == "" or str(v[1]).to_lower().contains(cherche) or str(v[0]).contains(cherche))
	if trouves.is_empty():
		_text(_liste_villages, "Aucun village ne s'appelle ainsi au carnet." if cherche != "" else "Aucun village au carnet pour l'instant.", 15, PENCIL)
	var o: Commune = Communes.origine()
	for v in trouves:
		var id := str(v[0])
		var b := Button.new()
		b.name = "Village_" + id
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.custom_minimum_size.y = 52
		for k in ["normal", "hover", "pressed", "focus"]:
			var st := StyleBoxFlat.new()
			st.bg_color = CARTE.lightened(0.06) if k == "hover" else CARTE
			st.set_corner_radius_all(6)
			st.border_color = ACCENT if Communes.actuelle() == id else LIGNE
			st.border_width_left = 4
			b.add_theme_stylebox_override(k, st)
		b.pressed.connect(ouvrir_onglet.bind(id))
		_liste_villages.add_child(b)
		var col := VBoxContainer.new()
		col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		col.offset_left = 16
		col.offset_right = -12
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", -1)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(col)
		var nom := _text(col, str(v[1]) + ("  ·  vous y êtes" if Communes.actuelle() == id else ("  ·  votre village" if o != null and id == o.id else "")), 16, INK, true)
		nom.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var detail := _text(col, _resume_village(id), 13, INK_LIGHT)
		detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail.autowrap_mode = TextServer.AUTOWRAP_OFF
		detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		detail.clip_text = true


## Un village en une ligne : ce qu'on y tient, ses réussites, le dernier passage.
func _resume_village(id: String) -> String:
	var mots: Array = []
	var n := 0
	for c in _album.cartes(id):
		n += int(c.n)
	n += _album.etablissements(id).size()
	if n > 0:
		mots.append("%d carte%s" % [n, "s" if n > 1 else ""])
	var valeurs: Dictionary = (Game.carnet.get(id, {}) as Dictionary).get("valeurs", {})
	var cases: Array = _compteurs(id).filter(func(d): return str(d.get("genre", "")) == "case")
	if not cases.is_empty():
		var faites: int = cases.filter(func(d): return valeurs.get(str(d.id)) == true).size()
		mots.append("%d réussite%s sur %d" % [faites, "s" if faites > 1 else "", cases.size()])
	var vu := int((Game.carnet.get(id, {}) as Dictionary).get("vu", 0))
	if vu > 0 and Communes.actuelle() != id:
		mots.append("passé %s" % Agenda.date(vu))
	if Communes.commune(id) == null and (Communes.origine() == null or id != Communes.origine().id):
		mots.append("plus installée")
	return " · ".join(mots) if not mots.is_empty() else "rien de noté pour l'instant"


## En haut de la page d'un village : le retour à la liste.
func _retour_villages() -> void:
	var b := _link(_left, "← Les villages", ouvrir_onglet.bind("villages"))
	b.name = "Retour"
	_gap(_left, 2)


func _fill_vienne() -> void:
	_retour_villages()
	_title(_left, "Les communes de la Vienne")
	_fill_communes(_left, false)
	_title(_right, "Mes passages")
	var vus: Array = Game.carnet.keys().filter(func(id): return int((Game.carnet[id] as Dictionary).get("vu", 0)) > 0)
	vus.sort_custom(func(a, b): return int(Game.carnet[a].vu) > int(Game.carnet[b].vu))
	if vus.is_empty():
		_text(_right, "Aucun passage noté ailleurs pour l'instant.", 15, INK_LIGHT)
	for id in vus:
		_row(_right, _nom_commune(id), Agenda.date(int(Game.carnet[id].vu)), INK)
		if villages().any(func(o): return o[0] == id):
			_link(_right, "→ ouvrir sa page", ouvrir_onglet.bind(id))
	_gap(_right)
	_link(_right, "La carte de la Vienne", _carte, true, "carte")


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
	if _sheet_mode == "pensionnaire":
		var ecran := _ecran()
		var etroit := ecran.x < 1300.0 or ecran.y < 760.0
		_sheet.custom_minimum_size = Vector2(minf(1148.0, ecran.x - (440.0 if etroit else 24.0)), minf(728.0, ecran.y - 24.0))
		Pensionnaire.remplir(self, _sheet_box, _show_sheet.bind(false, "pensionnaire"))
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
		_link(page, "Tout mettre à jour", Communes.tout_mettre_a_jour, true, "installer")
	for id in ids:
		_gap(page, 4)
		var e := Communes.au_catalogue(id)
		var c := Communes.commune(id)
		var etat := Communes.etat(id)
		var marque: String = {"mise_a_jour": "  ·  mise à jour", "a_relancer": "  ·  à relancer", "echec": "  ·  échec"}.get(etat,
			"  ·  nouvelle" if Communes.nouvelles.has(id) else "")
		_text(page, str(e.get("nom", c.nom if c else id)) + marque, 16, INK, true)
		_text(page, Communes.resume(id), 14, RED_INK if etat == "echec" else PENCIL)
		if etat in ["publiee", "mise_a_jour"] and str(e.get("description", "")) != "":
			_text(page, e.description, 14, INK_LIGHT)
		if etat in ["telechargement", "attente"]:
			page.add_child(BarreProgres.pour(id, PENCIL, 240.0))
		var g := Communes.geste(id)
		if not g.is_empty():
			_link(page, "→ " + str(g[0]).to_lower(), g[1])
		if c != null:
			_link(page, "→ y aller", _visiter.bind(id))
	if Communes.publiees().is_empty() and Communes.installees().is_empty():
		_text(page, "Aucune autre commune publiée pour l'instant." if Communes.catalogue_etat == "en_ligne" else "Le catalogue se lit quand le jeu est en ligne.", 15, INK_LIGHT)
	for r in Communes.refusees():
		_text(page, "%s : paquet refusé, %s" % [r.nom, r.raison], 16, RED_INK)
	_link(page, "Relire la liste" if Communes.catalogue_etat != "lecture" else "Lecture de la liste…", Communes.lire_catalogue, Communes.catalogue_etat != "lecture", "relire")
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
	_text(_sheet_box, "Du %s au %s. En gris, ce qui n'est qu'annoncé : les tables ouvriront plus tard." \
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
		var h := _text(ligne, "en cours" if Agenda.en_cours(rv, t) else Agenda.heure(rv.quand), 18, ACCENT)
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
		st.set_corner_radius_all(8)
		st.shadow_color = Color(0, 0, 0, 0.45)
		st.shadow_size = 10
		st.border_color = ACCENT
		st.border_width_left = 4
		_slip.add_theme_stylebox_override("panel", st)
		_slip.custom_minimum_size.x = 420
		_slip.gui_input.connect(_clic_fiche)
		add_child(_slip)
		# Sous le carnet : une fiche arrivée juste avant qu'on l'ouvre ne vient pas sur la page.
		move_child(_slip, 0)
		_slip_label = _text(_slip, "", 16)
		_slip_label.custom_minimum_size.x = 400
	_slip_label.text = text
	# Une fiche du courrier se clique : elle mène où dit l'avis. Les autres laissent passer la souris.
	_slip.mouse_filter = Control.MOUSE_FILTER_IGNORE if avis == null else Control.MOUSE_FILTER_STOP
	_slip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_slip.visible = true
	_fit_slip()
	# Le texte ne connaît sa hauteur qu'une fois mis en page : on reprend la mesure à l'image suivante.
	_fit_slip.call_deferred()
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


# --- Ouvrir le carnet sur une page -----------------------------------------------------------------

## Ouvre le carnet sur une rubrique ou une page (« boite », « biens », « cartes », une commune…, et les anciens
## noms : « courrier », « aujourdhui », « compte »), ou sur la semaine (« agenda »).
func ouvrir_sur(cle: String) -> void:
	if not _root.visible:
		toggle()
	if cle == "agenda":
		_show_sheet(true, "agenda")
		return
	if _sheet.visible:
		_sheet.visible = false
	ouvrir_onglet(cle)


## Un message ouvert, à droite de la boîte : son heure, son titre, son texte, et ses boutons (les choix d'une
## décision de la semaine, ou l'écran où il mène).
func _un_avis(col: VBoxContainer, a: Dictionary, t: int) -> void:
	var retour := _link(col, "← Le résumé du jour", func():
		_avis_vu = ""
		_refresh())
	retour.name = "Retour"
	_gap(col, 6)
	_text(col, "%s, %s" % [Agenda.jour_relatif(int(a.quand), t), Agenda.heure(int(a.quand))], 14, ACCENT, true)
	var titre := _text(col, str(a.titre), 22, INK, true)
	titre.name = "Ouvert"
	var filet := ColorRect.new()
	filet.color = LIGNE
	filet.custom_minimum_size.y = 1
	col.add_child(filet)
	_gap(col, 4)
	if str(a.texte) != "":
		_text(col, str(a.texte), 16, INK_LIGHT)
	_gap(col, 8)
	# Une décision de la semaine (FootDilemmes) : ses deux choix, ou celui qui est fait.
	var choix: Array = Avis.choix_de(a)
	if not choix.is_empty():
		var fait: Array = choix.filter(func(c): return c.fait)
		if not fait.is_empty():
			var v := _cadre(col, VERT)
			_text(v, "Vous avez choisi : %s." % fait[0].libelle, 15, INK, true)
			if fait[0].ouvert:
				_text(v, "Vous pouvez encore changer d'avis avant le coup d'envoi.", 14, INK_LIGHT)
			_gap(col, 4)
		if choix[0].ouvert:
			for c in choix:
				if c.fait:
					continue
				var b := _link(col, str(c.libelle), func():
					Avis.trancher(a, str(c.choix))
					_refresh(), true, "choix")
				b.name = "Choix_" + str(c.choix)
		elif fait.is_empty():
			_text(col, "Trop tard pour trancher : le match a commencé, ou vous ne dirigez plus le club.", 14, PENCIL)
		return
	var nom: String = Avis.nom_du_lien(a.get("lien", {}))
	if nom != "":
		var ok: bool = Avis.peut_aller(a.lien)
		var b := _link(col, nom, func(): Avis.aller(a), ok, _picto_du_lien(a.lien))
		b.name = "Aller"
		if not ok:
			b.tooltip_text = "Une fois levé de table."


## La pastille : « Messages : 2 choses à faire · 3 nouvelles  (C) », en bas à gauche, quand rien d'autre n'y est
## (ni fiche, ni carnet, ni table). Un clic ouvre la boîte. Le compte se relit chaque seconde.
func texte_pastille(f: int, n: int) -> String:
	var mots: Array = []
	if f > 0:
		mots.append("une chose à faire" if f == 1 else "%d choses à faire" % f)
	if n > 0:
		mots.append("une nouvelle" if n == 1 else "%d nouvelles" % n)
	return "Messages : %s%s" % [" · ".join(mots), "" if Tactile.active else "  (C)"]


func _process(_delta: float) -> void:
	var horloge := Time.get_ticks_msec() / 1000.0
	if horloge - _pastille_lue >= 1.0 or _pastille_lue < 0:
		_pastille_lue = horloge
		Avis.solder()
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
			st.bg_color = PAPER if k == "normal" else CARTE
			st.set_corner_radius_all(8)
			st.content_margin_left = 14
			st.content_margin_right = 14
			st.content_margin_top = 7
			st.content_margin_bottom = 7
			st.border_color = RED_INK if _compte_pastille[0] > 0 else ACCENT
			st.border_width_left = 4
			st.shadow_color = Color(0, 0, 0, 0.35)
			st.shadow_size = 5
			_pastille.add_theme_stylebox_override(k, st)
		_pastille.pressed.connect(func(): ouvrir_sur("boite"))
		add_child(_pastille)
		move_child(_pastille, 0)
	_pastille.visible = montrer
	if montrer:
		_pastille.text = texte_pastille(f, n)
		_pastille.reset_size()
		_pastille.position = Vector2(28, get_viewport().get_visible_rect().size.y - _pastille.size.y - 60)
