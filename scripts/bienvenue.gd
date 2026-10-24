extends CanvasLayer
## La bienvenue (autoload « Bienvenue »). Sur l'écran titre (demande de Guillaume du 24 octobre 2026 :
## « cet encart de droite pourrait être dédié à mettre le joueur dans l'action ») :
## - à droite, l'encart « Ce soir à Smarves » : la banque, ce qui s'est passé depuis la dernière visite,
##   ce qui attend, le courrier, le village (les blocs de scripts/socle/accueil.gd, que le mode léger
##   reprendra) ; chaque ligne mène où elle parle, la partie lancée ;
## - en bas, une seule ligne, comme Steam pendant un téléchargement : « À jour », la ville qui se
##   télécharge et sa jauge, ou la nouvelle version en or ; le compte en un nom ; « détails ▴ » déplie
##   à droite la liste des villes et des mises à jour.
## Le compte Pyramides (autoload Compte : connexion, partie gardée au compte, choix entre deux parties)
## et « Effacer ma partie… » sont des pages ouvertes depuis la rubrique Compte des réglages : à droite
## sur l'écran titre, au milieu sur la place. La fenêtre s'ouvre seule sur la place quand deux parties
## sont à départager. Effacer demande d'écrire EFFACER. La carte de la Vienne n'est plus à l'accueil :
## on la découvre au premier voyage (carnet, « Les villages », et la gare).

const OR := Color(0.96, 0.8, 0.45)
const EAU := Color(0.35, 0.8, 0.75)
const TEXTE := Color(0.88, 0.9, 0.92)
const DOUX := Color(0.65, 0.7, 0.75)
const ROUGE := Color(0.95, 0.45, 0.42)
const ACCUEIL := preload("res://scripts/socle/accueil.gd")
const AUJOURDHUI := preload("res://scripts/socle/aujourdhui.gd")
const AIDE := preload("res://scripts/socle/aide.gd")

var _root: Control
var _centre: CenterContainer
var _voile: ColorRect
## Sur l'écran titre, la fenêtre est un panneau ancré à droite : pas de voile, pas de pause.
var _dock := false
var _box: VBoxContainer
var _scroll: ScrollContainer
## Sous la colonne, hors du défilement : « Jouer » reste en vue quelle que soit la longueur.
var _pied: VBoxContainer
var _style_fenetre: StyleBoxFlat
## La page montrée : « soiree » (l'encart de l'écran titre), « liste » (villes et mises à jour),
## « compte » ou « effacer » (ouvertes depuis les réglages).
var _page := "soiree"
## La barre du bas de l'écran titre, et sa rangée.
var _barre: PanelContainer
var _barre_rang: HBoxContainer
const BARRE := 44.0
## Sur la place, la fenêtre ne s'ouvre seule que pour départager deux parties (Compte « choix »).
var _attendue := false
## Jamais dans les captures ni les outils de test (-s), qui mènent leur propre partie.
var _seule := not "--capture" in " ".join(OS.get_cmdline_user_args())
var _mouse_before := Input.MOUSE_MODE_VISIBLE
var _paused_before := false


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS
	_construire()
	_root.visible = false
	Communes.catalogue_lu.connect(func():
		if is_open():
			_remplir())
	Communes.etat_change.connect(func(_id):
		if is_open():
			_remplir.call_deferred())
	Version.lue.connect(func():
		if is_open():
			_remplir())
	Compte.change.connect(func():
		if is_open():
			_remplir.call_deferred()
		# Deux parties ont avancé chacune de leur côté : la fenêtre s'ouvre pour que le joueur choisisse.
		elif Compte.etat == "choix":
			_attendue = true)
	var guet := Timer.new()
	guet.wait_time = 1.0
	guet.autostart = true
	guet.timeout.connect(_essayer)
	add_child(guet)


func is_open() -> bool:
	return _root.visible


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and not _dock and event.is_action_pressed("ui_cancel"):
		fermer()
		get_viewport().set_input_as_handled()


## Sur l'écran titre, le panneau est toujours là ; on le quitte avec lui. Sur la place, la fenêtre
## attend le joueur déjà accueilli par Josiane, sans carnet, réglages ni partie en cours.
func _essayer() -> void:
	var titre := _sur_le_titre()
	if _dock and not titre:
		fermer()
	# La jauge et son pourcentage avancent d'eux-mêmes.
	if _dock and is_open() and Communes.en_cours != "":
		_remplir_barre()
	if not _seule or get_tree().get_script() != null:
		return
	if titre:
		if not is_open():
			ouvrir()
		return
	if not _attendue:
		return
	var scene := get_tree().current_scene
	if scene == null or scene.name != "Main" or scene.has_meta("vitrine") \
			or not Game.welcomed or Carnet.is_open() or Settings.is_open() or get_tree().paused:
		return
	_attendue = false
	ouvrir()


func _sur_le_titre() -> bool:
	var scene := get_tree().current_scene
	return scene != null and scene.name == "Titre"


func ouvrir(liste := false) -> void:
	ouvrir_page("liste" if liste else ("soiree" if _sur_le_titre() else "compte"))


## Ouvre une page (soiree, liste, compte, effacer) : à droite de l'écran titre, ailleurs au milieu.
func ouvrir_page(page: String) -> void:
	_dock = _sur_le_titre()
	if not is_open() and not _dock:
		_mouse_before = Input.mouse_mode
		_paused_before = get_tree().paused
	if not _dock:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
	_voile.visible = not _dock
	# Ancré à droite de l'écran titre, qui garde la gauche pour son nom et ses boutons.
	_centre.anchor_left = 0.56 if _dock else 0.0
	_centre.offset_bottom = -BARRE if _dock else 0.0
	_barre.visible = _dock
	_root.visible = true
	_page = page if not (page == "soiree" and not _dock) else "compte"
	if _dock:
		Voisinage.lire()
	_remplir()


func fermer() -> void:
	if not is_open():
		return
	_root.visible = false
	Communes.marquer_vues()
	if _dock:
		_dock = false
		return
	Input.mouse_mode = _mouse_before
	get_tree().paused = _paused_before


# --- La fenêtre --------------------------------------------------------------------------------

func _construire() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Sur l'écran titre, seuls le panneau et ses boutons prennent la souris ; ailleurs, le voile.
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	_voile = ColorRect.new()
	_voile.color = Color(0, 0, 0, 0.45)
	_voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(_voile)
	_centre = CenterContainer.new()
	_centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_centre)
	var fenetre := PanelContainer.new()
	var st := _boite(Color(0.06, 0.08, 0.12, 0.96), Color(EAU, 0.35), 10, 28)
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 24
	fenetre.add_theme_stylebox_override("panel", st)
	_style_fenetre = st
	_centre.add_child(fenetre)
	var rang := HBoxContainer.new()
	rang.add_theme_constant_override("separation", 28)
	fenetre.add_child(rang)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 14)
	rang.add_child(colonne)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(460, 540)
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	colonne.add_child(_scroll)
	_pied = VBoxContainer.new()
	colonne.add_child(_pied)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 12)
	_scroll.add_child(_box)
	_construire_barre()
	get_viewport().size_changed.connect(_ajuster)
	Avis.change.connect(func():
		if is_open() and _page == "soiree":
			_remplir.call_deferred())
	Voisinage.lu.connect(func():
		if is_open() and _page == "soiree":
			_remplir.call_deferred())


## La colonne défile dans ce que laisse l'écran : sur un téléphone en paysage (600 de haut), « Jouer »
## et « Entrer » restent en vue sous elle au lieu de sortir par le bas.
func _ajuster() -> void:
	if not is_open():
		return
	var ecran := get_viewport().get_visible_rect().size
	var bas := ecran.y < 760.0
	_style_fenetre.set_content_margin_all(16 if bas else 28)
	var pied := _pied.get_combined_minimum_size().y + 14.0 if _pied.get_child_count() > 0 else 0.0
	var autour := pied + _style_fenetre.content_margin_top + _style_fenetre.content_margin_bottom + 24.0 + (BARRE if _dock else 0.0)
	var haut := clampf(ecran.y - autour, 160.0, 540.0)
	# À droite du titre, le cadre se tient à ce qu'il dit : pas de grand vide pour un joueur qui commence.
	if _dock:
		haut = clampf(_box.get_combined_minimum_size().y, 160.0, haut)
	_scroll.custom_minimum_size.y = haut


func _remplir() -> void:
	for c in _box.get_children() + _pied.get_children():
		# Hors de l'arbre tout de suite : _ajuster mesure la nouvelle colonne, pas l'ancienne.
		c.get_parent().remove_child(c)
		c.queue_free()
	match _page:
		"effacer":
			_remplir_effacer()
		"liste":
			_remplir_liste()
		"soiree":
			_remplir_soiree()
		_:
			_remplir_page_compte()
	if _dock:
		_remplir_barre()
	_ajuster.call_deferred()


## L'encart de l'écran titre : la vie du joueur, pas celle du jeu. Les blocs viennent de ACCUEIL ; un bloc
## vide ne s'écrit pas.
func _remplir_soiree() -> void:
	# Deux parties à départager : l'encart ne parle que de cela.
	if Compte.etat == "choix":
		_remplir_page_compte()
		return
	_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_box.add_child(_mot(_moment(), 15, Color(0.55, 0.75, 0.75), Polices.gras()))
	var b := ACCUEIL.banque(Game, Biens)
	_box.add_child(_mot("%s cr." % Game.fmt(b.credits), 40, OR, Polices.titre()))
	var fortune := _mot("fortune nette %s  ·  dette %s" % [Game.fmt(b.fortune), Game.fmt(b.dette)], 16, DOUX)
	_box.add_child(fortune)
	AIDE.poser(fortune, "La fortune nette : vos crédits, plus ce que valent vos biens, moins ce que vous devez à M. Brunet.")
	var possede := ACCUEIL.biens(Biens)
	_box.add_child(_ligne("Vos biens  ·  %s" % possede.texte, TEXTE, _suivre.bind({"id": "", "lien": {"vers": "carnet", "onglet": "biens"}})))
	var d := ACCUEIL.depuis(Avis)
	if str(d.texte) != "":
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.add_child(_mot("Depuis votre passage", 15, DOUX))
		h.add_child(_mot(d.texte, 16, EAU, Polices.gras()))
		_box.add_child(h)
		AIDE.poser(h.get_child(1), "Ce que la partie a fait sans vous, d'après le courrier pas encore lu : il est au carnet, rubrique « Messages ».")
	var t: int = Football.maintenant()
	var faire := ACCUEIL.a_faire(AUJOURDHUI.a_faire(Football, Avis, Bourse, Basket), t)
	if not faire.is_empty():
		_box.add_child(_filet())
		_box.add_child(_mot("À FAIRE", 14, OR, Polices.gras()))
		for x in faire:
			_box.add_child(_ligne("%s  ·  %s" % [x.titre, x.quand], TEXTE, _suivre.bind(x.avis if not (x.avis as Dictionary).is_empty() else {"id": "", "lien": x.lien})))
	var courrier := ACCUEIL.courrier(Avis)
	if not courrier.is_empty():
		_box.add_child(_filet())
		_box.add_child(_mot("COURRIER", 14, EAU, Polices.gras()))
		for x in courrier:
			_box.add_child(_ligne(str(x.titre), TEXTE, _suivre.bind(x.avis)))
	var village := ACCUEIL.village(Voisinage)
	if str(village.texte) != "":
		_box.add_child(_filet())
		_box.add_child(_mot("AU VILLAGE", 14, Color(0.55, 0.6, 0.66), Polices.gras()))
		_box.add_child(_ligne(village.texte, TEXTE, _suivre.bind({"id": "", "lien": {"vers": "agenda"}})))


## « Ce soir à Smarves », « Ce matin… », « Cet après-midi… », à l'heure de l'appareil.
static func _moment() -> String:
	var h := int(Time.get_datetime_dict_from_system().hour)
	return "CE MATIN À SMARVES" if h >= 5 and h < 12 else ("CET APRÈS-MIDI À SMARVES" if h >= 12 and h < 18 else "CE SOIR À SMARVES")


## Une ligne de l'encart qui mène où elle parle : sur l'écran titre, la partie se lance d'abord.
func _ligne(t: String, encre: Color, action: Callable) -> Button:
	# Une rangée qui se voit cliquable d'emblée (Guillaume, 24 octobre : « ne semble pas assez cliquable ») :
	# un fond léger, un filet à gauche, la flèche au bout ; au survol, le fond s'allume.
	var b := _bouton(t + "   ›", Color(0, 0, 0, 0), encre, Color(0, 0, 0, 0), action, 16)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.add_theme_font_override("font", Polices.texte())
	for etat in ["normal", "hover", "pressed", "focus"]:
		var st := _boite(Color(1, 1, 1, 0.05) if etat in ["normal", "focus"] else Color(EAU, 0.16), Color(0, 0, 0, 0), 4, 8)
		st.content_margin_left = 12
		st.content_margin_right = 12
		st.content_margin_top = 6
		st.content_margin_bottom = 6
		st.border_color = Color(EAU, 0.55 if etat in ["normal", "focus"] else 0.95)
		st.border_width_left = 2
		b.add_theme_stylebox_override(etat, st)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	return b


## Suit le lien d'un avis (ou d'une ligne « À faire ») : depuis l'écran titre, la partie se lance, puis le
## carnet ou le bureau s'ouvre par-dessus la place.
func _suivre(avis: Dictionary) -> void:
	var titre := get_tree().current_scene
	if _dock and titre != null and titre.has_method("jouer"):
		# L'encart se ferme avant que la partie s'ouvre : rien de la bienvenue ne reste par-dessus la place.
		fermer()
		titre.jouer()
		await get_tree().create_timer(0.6).timeout
	Avis.aller(avis)


## La page du compte (réglages, rubrique Compte ; seule quand deux parties sont à départager).
func _remplir_page_compte() -> void:
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	if not _dock:
		_box.add_child(_mot("Votre compte Pyramides", 34, Color.WHITE, Polices.titre()))
		_box.add_child(_filet())
	_remplir_compte()
	if Compte.etat == "choix":
		if not _dock:
			_pied.add_child(_bouton("Décider plus tard", Color(0, 0, 0, 0), DOUX, Color(1, 1, 1, 0.3), fermer, 16))
		return
	if _dock:
		_box.add_child(_filet())
		_box.add_child(_bouton("←  Retour", Color(0, 0, 0, 0), TEXTE, Color(1, 1, 1, 0.3), ouvrir_page.bind("soiree"), 16))
		return
	var jouer := _bouton("Jouer", OR, Color(0.1, 0.07, 0.03), Color(0, 0, 0, 0), fermer, 22)
	jouer.custom_minimum_size.x = 220
	_pied.add_child(jouer)
	jouer.grab_focus.call_deferred()


# --- La barre du bas ---------------------------------------------------------------------------

func _construire_barre() -> void:
	_barre = PanelContainer.new()
	_barre.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_barre.offset_top = -BARRE
	_barre.mouse_filter = Control.MOUSE_FILTER_STOP
	var st := _boite(Color(0.03, 0.04, 0.06, 0.92), Color(0, 0, 0, 0), 0, 0)
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.border_color = Color(EAU, 0.25)
	st.border_width_top = 1
	_barre.add_theme_stylebox_override("panel", st)
	_barre.visible = false
	_root.add_child(_barre)
	_barre_rang = HBoxContainer.new()
	_barre_rang.add_theme_constant_override("separation", 14)
	_barre.add_child(_barre_rang)


## Une ligne : l'état du jeu et des villes (ACCUEIL.etat), sa jauge et son geste, puis le compte en un
## nom, puis « détails » qui déplie la liste à droite (et la replie).
func _remplir_barre() -> void:
	for c in _barre_rang.get_children():
		c.queue_free()
	var e := ACCUEIL.etat(Version, Communes)
	var teinte: Color = {"ok": Color(0.55, 0.85, 0.6), "or": OR, "rouge": ROUGE}.get(e.teinte, DOUX)
	var etat := _mot(e.texte, 15, teinte, Polices.gras())
	etat.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_barre_rang.add_child(etat)
	if str(e.en_cours) != "":
		_barre_rang.add_child(BarreProgres.pour(e.en_cours, OR, 160.0))
	if not (e.geste as Array).is_empty():
		var g := _petit(e.geste[0], teinte, e.geste[1])
		g.pressed.connect(_remplir)
		_barre_rang.add_child(g)
	var vide := Control.new()
	vide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_barre_rang.add_child(vide)
	_barre_rang.add_child(_petit(ACCUEIL.compte(Compte), DOUX, ouvrir_page.bind("compte")))
	var liste := _page == "liste"
	_barre_rang.add_child(_petit("détails  ▾" if liste else "détails  ▴", TEXTE, ouvrir_page.bind("soiree" if liste else "liste")))


func _petit(t: String, encre: Color, action: Callable) -> Button:
	var b := _bouton(t, Color(0, 0, 0, 0), encre, Color(0, 0, 0, 0), action, 14)
	b.focus_mode = Control.FOCUS_NONE
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for etat in ["normal", "hover", "pressed", "focus", "disabled"]:
		var st: StyleBoxFlat = b.get_theme_stylebox(etat)
		st.content_margin_left = 8
		st.content_margin_right = 8
		st.content_margin_top = 4
		st.content_margin_bottom = 4
	return b


## Effacer sa partie : ce n'est pas recommencer, c'est tout perdre, ici et au compte. Il faut écrire
## EFFACER pour que le bouton réponde ; « Garder ma partie » a le focus.
func _remplir_effacer() -> void:
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_child(_mot("EFFACER MA PARTIE", 14, ROUGE, Polices.gras()))
	var compte := " et sur votre compte Pyramides, donc sur tous vos appareils" if Compte.connecte() else ""
	_box.add_child(_mot("Vos %s crédits, vos biens, vos paris et tout ce que vous avez gagné seront effacés sur cet appareil%s. Rien ne pourra être récupéré." \
			% [Game.fmt(Game.credits), compte], 17, TEXTE, null, true))
	_box.add_child(_mot("Pour confirmer, écrivez EFFACER :", 15, DOUX))
	var champ := LineEdit.new()
	champ.custom_minimum_size.x = 220
	champ.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	champ.add_theme_font_override("font", Polices.gras())
	champ.add_theme_font_size_override("font_size", 17)
	champ.add_theme_color_override("font_color", TEXTE)
	champ.add_theme_stylebox_override("normal", _boite(Color(1, 1, 1, 0.05), Color(1, 1, 1, 0.3), 4, 8))
	champ.add_theme_stylebox_override("focus", _boite(Color(1, 1, 1, 0.05), ROUGE, 4, 8))
	_box.add_child(champ)
	var bouton := _bouton("Effacer définitivement", Color(0, 0, 0, 0), ROUGE, ROUGE, _tout_effacer, 15, false)
	_box.add_child(bouton)
	champ.text_changed.connect(func(t: String): bouton.disabled = t.strip_edges().to_upper() != "EFFACER")
	var garder := _bouton("Garder ma partie", OR, Color(0.1, 0.07, 0.03), Color(0, 0, 0, 0), func():
		if _dock:
			ouvrir_page("soiree")
		else:
			fermer(), 22)
	garder.custom_minimum_size.x = 220
	_pied.add_child(garder)
	garder.grab_focus.call_deferred()


func _tout_effacer() -> void:
	fermer()
	Game.reset()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


## Le compte Pyramides : se connecter, où en est la partie gardée au compte, et le choix quand deux
## appareils ont joué chacun de leur côté.
func _remplir_compte() -> void:
	var titre := "VOTRE COMPTE" if Compte.nom == "" or Compte.etat in ["deconnecte", "connexion", "erreur"] \
			else "VOTRE COMPTE  ·  %s" % Compte.nom.to_upper()
	_box.add_child(_mot(titre, 14, Color(0.55, 0.6, 0.66), Polices.gras()))
	match Compte.etat:
		"deconnecte":
			AIDE.poser(_ajoute(_mot("Partie gardée sur cet appareil.", 17, DOUX)), "Avec votre compte Pyramides, elle vous suit sur vos autres appareils, et vous jouez aux tables à plusieurs.")
			_box.add_child(_bouton("Se connecter avec Pyramides", Color(0, 0, 0, 0), EAU, EAU, Compte.se_connecter))
		"connexion":
			_box.add_child(_mot(Compte.message, 17, TEXTE, null, true))
			_box.add_child(_bouton("Annuler", Color(0, 0, 0, 0), DOUX, Color(1, 1, 1, 0.3), Compte.annuler, 15))
		"erreur":
			_box.add_child(_mot(Compte.message, 17, ROUGE, null, true))
			_box.add_child(_bouton("Réessayer", Color(0, 0, 0, 0), EAU, EAU, Compte.se_connecter))
		"expire":
			AIDE.poser(_ajoute(_mot("La connexion a expiré.", 17, DOUX)), "Votre partie continue sur cet appareil et partira au compte dès que vous vous reconnectez.")
			_box.add_child(_bouton("Se reconnecter", Color(0, 0, 0, 0), EAU, EAU, Compte.se_connecter))
		"choix":
			_remplir_choix()
		_:
			var ligne: String = {"verification": "Lecture de la partie du compte…", "envoi": "Envoi de la partie au compte…",
				"hors_ligne": "Hors ligne : votre partie partira au compte au retour du réseau."}.get(Compte.etat,
				Compte.message if Compte.message != "" else "Partie gardée au compte %s." % _il_y_a(Compte.synchro_a))
			_box.add_child(_mot(ligne, 17, DOUX, null, true))
			_box.add_child(_bouton("Se déconnecter", Color(0, 0, 0, 0), DOUX, Color(0, 0, 0, 0), Compte.se_deconnecter, 15))


func _remplir_choix() -> void:
	_box.add_child(_mot("Cet appareil et votre compte ont chacun avancé de leur côté. Laquelle des deux parties garder ? L'autre sera remplacée.", 17, TEXTE, null, true))
	var r: Dictionary = Compte.autre.get("resume", {})
	var ici := Compte.resume()
	var rang := HBoxContainer.new()
	rang.add_theme_constant_override("separation", 12)
	rang.add_child(_fiche_partie("CET APPAREIL", Compte.appareil() + ", maintenant", ici, "Garder celle-ci", Compte.garder_appareil))
	rang.add_child(_fiche_partie("LE COMPTE", "%s, %s" % [Compte.autre.get("appareil", "autre appareil"), _il_y_a(int(Compte.autre.get("maj", 0)))],
		r, "Reprendre celle-ci", Compte.prendre_compte))
	_box.add_child(rang)


func _fiche_partie(titre: String, ou: String, resume: Dictionary, action: String, quoi: Callable) -> PanelContainer:
	var cadre := PanelContainer.new()
	cadre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cadre.add_theme_stylebox_override("panel", _boite(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.12), 6, 12))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	cadre.add_child(v)
	v.add_child(_mot(titre, 13, EAU, Polices.gras()))
	var lieu := _mot(ou, 14, DOUX, null, true)
	lieu.custom_minimum_size.x = 0
	v.add_child(lieu)
	v.add_child(_mot("%s crédits" % Game.fmt(int(resume.get("credits", 0))), 19, Color.WHITE, Polices.gras()))
	v.add_child(_mot("fortune nette %s" % Game.fmt(int(resume.get("fortune", 0))), 15, TEXTE))
	v.add_child(_mot("gagné au jeu %s" % Game.fmt(int(resume.get("gagne", 0))), 15, TEXTE))
	v.add_child(_bouton(action, Color(0, 0, 0, 0), OR, OR, quoi, 15))
	return cadre


static func _il_y_a(quand: int) -> String:
	var s := int(Time.get_unix_time_from_system()) - quand
	if quand <= 0 or s < 60:
		return "à l'instant"
	if s < 3600:
		return "il y a %d min" % (s / 60)
	if s < 48 * 3600:
		return "il y a %d h" % (s / 3600)
	return "il y a %d jours" % (s / 86400)


## Le jeu lui-même : ce qui a changé, le téléchargement pour cet appareil, et quoi faire ensuite.
func _ligne_jeu() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(_mot("SMARVES", 13, OR, Polices.gras()))
	var lignes: Array = Version.nouveautes.slice(0, 2).map(func(t): return "·  " + t)
	if Version.nouveautes.size() > 2:
		var reste: int = Version.nouveautes.size() - 2
		lignes.append("et %d autre%s changement%s" % [reste, "s" if reste > 1 else "", "s" if reste > 1 else ""])
	if not lignes.is_empty():
		v.add_child(_mot("\n".join(lignes), 16, TEXTE, null, true))
	var telecharger := _bouton("Télécharger la nouvelle version", Color(0, 0, 0, 0), OR, OR, func():
		Version.telecharger()
		_remplir(), 16)
	v.add_child(telecharger)
	if Version.telechargement_ouvert:
		v.add_child(_mot(Version.resume(), 15, DOUX, null, true))
	else:
		AIDE.poser(telecharger, {"Android": "Installez l'APK par-dessus le jeu : votre partie vous suit."}.get(OS.get_name(),
			"Lancez l'installateur : il remplace le jeu, et votre partie vous suit."))
	return v


func _progres(id: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var c := Communes.commune(id)
	h.add_child(_mot(str(Communes.au_catalogue(id).get("nom", c.nom if c else id)), 15, DOUX))
	h.add_child(BarreProgres.pour(id, OR))
	return h


## « Villes et mises à jour » : le jeu, puis les villes qui demandent un geste, les nouvelles, et
## les autres. Chaque ligne dit son état et son geste, avec les mêmes mots que la carte et le carnet.
func _remplir_liste() -> void:
	_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_box.add_child(_mot("L E S   V I L L E S   D E   L A   V I E N N E", 13, Color(0.55, 0.75, 0.75)))
	_box.add_child(_mot("Villes et mises à jour", 32, Color.WHITE, Polices.titre()))
	_box.add_child(_filet())
	if Version.disponible():
		_box.add_child(_ligne_jeu())
	else:
		_box.add_child(_mot("SMARVES", 13, OR, Polices.gras()))
		_box.add_child(_mot(Version.resume(), 16, DOUX, null, true))
	var faire := Communes.a_faire()
	if faire.any(func(id): return Communes.etat(id) in ["mise_a_jour", "echec"]):
		_box.add_child(_bouton("Tout mettre à jour", Color(0, 0, 0, 0), OR, OR, Communes.tout_mettre_a_jour, 16))
	var autres: Array = Communes.installees().filter(func(id): return not faire.has(id))
	for id in faire + Communes.a_installer().filter(func(id): return not faire.has(id)) + autres:
		_box.add_child(_filet())
		_box.add_child(_ligne_ville(id))
	if Communes.publiees().is_empty() and Communes.installees().is_empty():
		_box.add_child(_filet())
		_box.add_child(_mot(_villes_en_une_ligne(), 18, TEXTE, null, true))
	for r in Communes.refusees():
		_box.add_child(_mot("%s : paquet refusé, %s" % [r.nom, r.raison], 16, ROUGE, null, true))
	_box.add_child(_filet())
	var bas := HBoxContainer.new()
	bas.add_theme_constant_override("separation", 10)
	bas.add_child(_bouton("←  Retour", Color(0, 0, 0, 0), TEXTE, Color(1, 1, 1, 0.3), ouvrir.bind(false), 16))
	bas.add_child(_bouton("Relire la liste" if Communes.catalogue_etat != "lecture" else "Lecture…", Color(0, 0, 0, 0), DOUX, Color(0, 0, 0, 0), Communes.lire_catalogue, 15, Communes.catalogue_etat != "lecture"))
	_box.add_child(bas)
	Communes.marquer_vues.call_deferred()


func _ligne_ville(id: String) -> VBoxContainer:
	var e := Communes.au_catalogue(id)
	var c := Communes.commune(id)
	var etat := Communes.etat(id)
	var fiche := VBoxContainer.new()
	fiche.add_theme_constant_override("separation", 4)
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", 10)
	tete.add_child(_mot(str(e.get("nom", c.nom if c else id)), 20, Color.WHITE, Polices.gras()))
	var marque: Array = {"publiee": ["NOUVELLE", EAU] if Communes.nouvelles.has(id) else [], "mise_a_jour": ["MISE À JOUR", OR],
		"a_relancer": ["À RELANCER", OR], "echec": ["ÉCHEC", ROUGE]}.get(etat, [])
	if not marque.is_empty():
		tete.add_child(_mot(marque[0], 12, marque[1], Polices.gras()))
	fiche.add_child(tete)
	fiche.add_child(_mot(Communes.resume(id), 15, ROUGE if etat == "echec" else DOUX, null, true))
	if etat in ["publiee", "mise_a_jour"] and str(e.get("description", "")) != "":
		fiche.add_child(_mot(e.description, 17, TEXTE, null, true))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	if etat == "telechargement":
		actions.add_child(BarreProgres.pour(id))
	if c != null:
		actions.add_child(_bouton("Y aller  →", EAU, Color(0.04, 0.1, 0.1), Color(0, 0, 0, 0), _visiter.bind(id), 16))
	var g := Communes.geste(id)
	if not g.is_empty():
		var teinte := OR if etat in ["mise_a_jour", "a_relancer"] else EAU
		actions.add_child(_bouton(g[0], Color(0, 0, 0, 0), teinte, teinte, g[1], 16))
	if actions.get_child_count() > 0:
		fiche.add_child(actions)
	return fiche


func _visiter(id: String) -> void:
	fermer()
	if not Communes.visiter(id):
		Carnet.show_slip("%s ne s'ouvre pas : %s" % [Communes.commune(id).nom, Communes.refus[-1][1] if not Communes.refus.is_empty() else "scène introuvable"])


## Ce que la bienvenue dit des villes : les nouvelles d'abord, sinon ce qui est disponible.
func _villes_en_une_ligne() -> String:
	var noms: Array = Communes.nouvelles.map(func(id): return Communes.au_catalogue(id).get("nom", id))
	if noms.size() == 1:
		return "%s a été publiée depuis votre dernière visite." % noms[0]
	if noms.size() > 1:
		return "%s et %s ont été publiées depuis votre dernière visite." % [", ".join(noms.slice(0, -1)), noms[-1]]
	var n := Communes.publiees().size()
	var inst := Communes.installees().size()
	if n > 0:
		return ("Une ville publiée par d'autres joueurs" if n == 1 else "%d villes publiées par d'autres joueurs" % n) \
			+ ((", %d installée%s chez vous." % [inst, "s" if inst > 1 else ""]) if inst > 0 else ", à installer et à visiter.")
	match Communes.catalogue_etat:
		"lecture":
			return "Lecture de la liste…"
		"hors_ligne":
			return "Hors ligne : la liste se lira à la prochaine connexion."
	return "Aucune autre ville publiée pour l'instant. Les développeurs les construisent sur le portail."


# --- Les pièces --------------------------------------------------------------------------------

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
		l.custom_minimum_size.x = 400
	return l


## Ajoute c à la colonne et le rend (pour lui poser un (i)).
func _ajoute(c: Control) -> Control:
	_box.add_child(c)
	return c


func _filet() -> ColorRect:
	var f := ColorRect.new()
	f.color = Color(1, 1, 1, 0.1)
	f.custom_minimum_size.y = 1
	return f


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
