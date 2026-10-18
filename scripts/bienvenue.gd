extends CanvasLayer
## La bienvenue (autoload « Bienvenue ») : à chaque lancement, une fenêtre au milieu de la place. À
## gauche la carte de la Vienne, Smarves en or et les villes publiées en vert d'eau ; à droite les
## crédits, la nouvelle version du jeu quand il y en a une (autoload Version), les villes de la
## Vienne (« Voir les villes » déplie la liste, à installer et à visiter sur place), le compte
## Pyramides (autoload Compte : connexion, partie gardée au compte, choix entre deux parties) et
## « Jouer ». Tout en bas, en tout petit, « Effacer ma partie… » : le seul endroit où l'on efface sa
## partie (il n'y a plus de « Nouvelle partie » dans le menu Échap), derrière une page qui demande
## d'écrire EFFACER. Direction « La Vienne », choisie par Guillaume le 17 octobre
## 2026.

const OR := Color(0.96, 0.8, 0.45)
const EAU := Color(0.35, 0.8, 0.75)
const TEXTE := Color(0.88, 0.9, 0.92)
const DOUX := Color(0.65, 0.7, 0.75)
const ROUGE := Color(0.95, 0.45, 0.42)

var _root: Control
var _carte: CarteVienne
var _box: VBoxContainer
var _scroll: ScrollContainer
## Sous la colonne, hors du défilement : « Jouer » reste en vue quelle que soit la longueur.
var _pied: VBoxContainer
var _liste := false
## La page qui efface la partie, ouverte par le petit lien du bas.
var _effacer := false
## Une fois par lancement ; jamais dans les captures.
var _attendue := not "--capture" in " ".join(OS.get_cmdline_user_args())
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
	if is_open() and event.is_action_pressed("ui_cancel"):
		fermer()
		get_viewport().set_input_as_handled()


## Elle attend que le joueur soit sur la place, déjà accueilli par Josiane, sans carnet, réglages ni
## partie en cours. Les outils de test (-s) mènent leur propre partie : pas de bienvenue pour eux.
func _essayer() -> void:
	if not _attendue:
		return
	var scene := get_tree().current_scene
	if scene == null or scene.name != "Main" or get_tree().get_script() != null or scene.has_meta("vitrine") \
			or not Game.welcomed or Carnet.is_open() or Settings.is_open() or get_tree().paused:
		return
	_attendue = false
	ouvrir()


func ouvrir(liste := false) -> void:
	if not is_open():
		_mouse_before = Input.mouse_mode
		_paused_before = get_tree().paused
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	_root.visible = true
	_liste = liste
	_effacer = false
	_remplir()


func fermer() -> void:
	if not is_open():
		return
	_root.visible = false
	Communes.marquer_vues()
	Input.mouse_mode = _mouse_before
	get_tree().paused = _paused_before


# --- La fenêtre --------------------------------------------------------------------------------

func _construire() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var voile := ColorRect.new()
	voile.color = Color(0, 0, 0, 0.45)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(voile)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var fenetre := PanelContainer.new()
	var st := _boite(Color(0.06, 0.08, 0.12, 0.96), Color(EAU, 0.35), 10, 28)
	st.shadow_color = Color(0, 0, 0, 0.5)
	st.shadow_size = 24
	fenetre.add_theme_stylebox_override("panel", st)
	center.add_child(fenetre)
	var rang := HBoxContainer.new()
	rang.add_theme_constant_override("separation", 28)
	fenetre.add_child(rang)
	_carte = CarteVienne.new()
	_carte.custom_minimum_size = Vector2(380, 540)
	rang.add_child(_carte)
	var colonne := VBoxContainer.new()
	colonne.add_theme_constant_override("separation", 14)
	rang.add_child(colonne)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(440, 0)
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


func _remplir() -> void:
	for c in _box.get_children() + _pied.get_children():
		c.queue_free()
	_carte.publiees = Communes.publiees().map(func(e): return e.insee)
	_carte.installees = Communes.installees().map(func(id): return Communes.commune(id).insee)
	_carte.queue_redraw()
	if _effacer:
		_remplir_effacer()
	elif _liste:
		_remplir_liste()
	else:
		_remplir_accueil()


func _remplir_accueil() -> void:
	_box.add_child(_mot("S M A R V E S  ·  V I E N N E", 13, Color(0.55, 0.75, 0.75)))
	_box.add_child(_mot("Bienvenue à Smarves", 38, Color.WHITE, Polices.titre()))
	# Deux parties à départager : la fenêtre ne parle que de cela.
	if Compte.etat == "choix":
		_box.add_child(_filet())
		_remplir_compte()
		_pied.add_child(_bouton("Décider plus tard", Color(0, 0, 0, 0), DOUX, Color(1, 1, 1, 0.3), fermer, 16))
		return
	_box.add_child(_mot("%s crédits en poche  ·  fortune nette %s" % [Game.fmt(Game.credits), Game.fmt(Game.credits + Biens.value() - Game.debt)], 17, DOUX))
	_box.add_child(_filet())
	_remplir_mises_a_jour()
	_box.add_child(_filet())
	var n := Communes.nouvelles.size()
	_box.add_child(_mot(("%d VILLE%s NOUVELLE%s" % [n, "S" if n > 1 else "", "S" if n > 1 else ""]) if n > 0 else "LES VILLES DE LA VIENNE", 14, EAU, Polices.gras()))
	_box.add_child(_mot(_villes_en_une_ligne(), 18, TEXTE, null, true))
	var rang := HBoxContainer.new()
	rang.add_theme_constant_override("separation", 10)
	if not Communes.publiees().is_empty() or not Communes.installees().is_empty():
		rang.add_child(_bouton("Villes et mises à jour  →", Color(0, 0, 0, 0), EAU, EAU, ouvrir.bind(true)))
	rang.add_child(_bouton("Ouvrir la carte  (M)", Color(0, 0, 0, 0), TEXTE, Color(1, 1, 1, 0.3), _vers_la_carte))
	_box.add_child(rang)
	_box.add_child(_filet())
	_remplir_compte()
	# Tout au fond, à peine lisible : on n'efface pas sa partie par mégarde.
	var effacer := _bouton("Effacer ma partie…", Color(0, 0, 0, 0), Color(DOUX, 0.45), Color(0, 0, 0, 0), func():
		_effacer = true
		_remplir(), 12)
	effacer.focus_mode = Control.FOCUS_NONE
	_box.add_child(effacer)
	var jouer := _bouton("Jouer", OR, Color(0.1, 0.07, 0.03), Color(0, 0, 0, 0), fermer, 22)
	jouer.custom_minimum_size.x = 220
	_pied.add_child(jouer)
	jouer.grab_focus.call_deferred()


## Effacer sa partie : ce n'est pas recommencer, c'est tout perdre, ici et au compte. Il faut écrire
## EFFACER pour que le bouton réponde ; « Garder ma partie » a le focus.
func _remplir_effacer() -> void:
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
		_effacer = false
		_remplir(), 22)
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
			_box.add_child(_mot("Votre partie est gardée sur cet appareil. Avec votre compte Pyramides, elle vous suit sur vos autres appareils.", 17, DOUX, null, true))
			_box.add_child(_bouton("Se connecter avec Pyramides", Color(0, 0, 0, 0), EAU, EAU, Compte.se_connecter))
		"connexion":
			_box.add_child(_mot(Compte.message, 17, TEXTE, null, true))
			_box.add_child(_bouton("Annuler", Color(0, 0, 0, 0), DOUX, Color(1, 1, 1, 0.3), Compte.annuler, 15))
		"erreur":
			_box.add_child(_mot(Compte.message, 17, ROUGE, null, true))
			_box.add_child(_bouton("Réessayer", Color(0, 0, 0, 0), EAU, EAU, Compte.se_connecter))
		"expire":
			_box.add_child(_mot("La connexion a expiré. Votre partie continue sur cet appareil et partira au compte dès que vous vous reconnectez.", 17, DOUX, null, true))
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


## Les mises à jour en un seul bloc : une ligne qui dit tout (le jeu, les villes à mettre à jour, ce qui
## se télécharge, ce qui attend le prochain lancement, ce qui s'est fait tout seul), et les gestes.
func _remplir_mises_a_jour() -> void:
	var faire := Communes.a_faire()
	var compte := func(etats: Array) -> int: return faire.filter(func(id): return Communes.etat(id) in etats).size()
	var parts: Array[String] = []
	if Version.disponible():
		parts.append("une nouvelle version du jeu")
	var n: int = compte.call(["mise_a_jour"])
	if n > 0:
		parts.append("%d ville%s à mettre à jour" % [n, "s" if n > 1 else ""])
	n = compte.call(["echec"])
	if n > 0:
		parts.append("%d téléchargement%s à réessayer" % [n, "s" if n > 1 else ""])
	n = compte.call(["telechargement", "attente"])
	if n > 0:
		parts.append("%d en téléchargement" % n)
	n = compte.call(["a_relancer"])
	if n > 0:
		parts.append("%d prête%s au prochain lancement" % [n, "s" if n > 1 else ""])
	_box.add_child(_mot("MISES À JOUR", 14, OR if not parts.is_empty() else DOUX, Polices.gras()))
	var ligne := "Tout est à jour." if Version.etat != "hors_ligne" else "Hors ligne : rien n'a pu être vérifié."
	if not parts.is_empty():
		var phrase := (", ".join(parts.slice(0, -1)) + " et " + parts[-1]) if parts.size() > 1 else parts[0]
		ligne = phrase.left(1).to_upper() + phrase.substr(1) + "."
	if not Communes.mises_a_jour_seules.is_empty():
		var noms: Array = Communes.mises_a_jour_seules.map(func(id): return Communes.commune(id).nom if Communes.commune(id) else id)
		ligne += " %s %s mise%s à jour toute%s seule%s." % [" et ".join(noms), "s'est" if noms.size() == 1 else "se sont",
			"" if noms.size() == 1 else "s", "" if noms.size() == 1 else "s", "" if noms.size() == 1 else "s"]
	_box.add_child(_mot(ligne, 17, TEXTE, null, true))
	for id in faire:
		if Communes.etat(id) == "telechargement":
			_box.add_child(_progres(id))
	if Version.disponible():
		_box.add_child(_ligne_jeu())
	var rang := HBoxContainer.new()
	rang.add_theme_constant_override("separation", 10)
	if compte.call(["mise_a_jour", "echec"]) > 0:
		rang.add_child(_bouton("Tout mettre à jour", Color(0, 0, 0, 0), OR, OR, Communes.tout_mettre_a_jour, 16))
	if compte.call(["a_relancer"]) > 0 and Communes.peut_relancer():
		rang.add_child(_bouton("Relancer maintenant", Color(0, 0, 0, 0), OR, OR, Communes.relancer, 16))
	if rang.get_child_count() > 0:
		_box.add_child(rang)


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
	v.add_child(_bouton("Télécharger la nouvelle version", Color(0, 0, 0, 0), OR, OR, func():
		Version.telecharger()
		_remplir(), 16))
	v.add_child(_mot(Version.resume() if Version.telechargement_ouvert else
		{"Android": "Installez l'APK par-dessus le jeu : votre partie vous suit."}.get(OS.get_name(),
			"Lancez l'installateur : il remplace le jeu, et votre partie vous suit."), 15, DOUX, null, true))
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


func _vers_la_carte() -> void:
	fermer()
	Carte.ouvrir()


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
