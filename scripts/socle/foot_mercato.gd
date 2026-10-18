class_name FootMercato
extends FootTableau
## Le mercato du président : le marché des transferts à la Hattrick (autoload Mercato, docs/SUITE.md
## section 6, « le mercato »). Trois pages sur la même ardoise :
## - la recherche : les quarante nouveaux de la semaine et les joueurs que les clubs remettent en vente, filtrés et triés à la Hattrick, avec
##   leur date limite, le prix du moment et qui mène ;
## - la fiche d'un joueur, à la Hattrick : forme, expérience, endurance, les sept compétences en mots,
##   salaire, valeur, les offres, et la case où l'on tape sa mise (pas de limite, sinon sa poche) ;
## - l'effectif : les joueurs que le club a achetés au marché, qu'on peut remettre en vente.
## C'est celui qui dirige le club qui enchérit et vend, de sa poche, et il faut son compte Pyramides : les
## enchères comptent pour tous les villages. Hors ligne, on lit le dernier état connu.
##
## Elle emprunte au tableau du dimanche son ardoise et ses petites pièces ; s'ouvre et se ferme comme
## lui (signal closed, Échap). Le stade l'ouvre par open_mercato(), depuis le siège du club. Le bureau du club
## (Bureau) l'emboîte aussi, sans ardoise ni onglets (integre) : ses pages Recherche et Offres en cours.

var club := ""
## « marche », « suivis », « offres », « fiche » (lot_ouvert) ou « effectif » ; une fiche de l'effectif garde joueur_ouvert.
var page := "marche"
## Emboîtée dans le bureau du club : ni ardoise, ni titre, ni onglets, ni bouton pour sortir ; la place qu'on lui laisse.
var integre := false
var hauteur := 0.0
var largeur := 0.0
var lot_ouvert := ""
var joueur_ouvert := ""
var _ligne_etat: Label
var _saisie: LineEdit
var _message := ""
var _minuteur: Timer
## La page d'où l'on a ouvert la fiche.
var _retour := "marche"
var _lu := 0.0


func _ready() -> void:
	if integre:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_colonne = VBoxContainer.new()
		_colonne.add_theme_constant_override("separation", 8)
		_colonne.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		add_child(_colonne)
	else:
		_preparer()
	for arg in ([] as Array) if integre else OS.get_cmdline_user_args():
		if arg == "--marche-demo":
			demo(mercato(), club)
		elif arg == "--mercato-page=effectif" or arg == "--mercato-page=suivis":
			page = arg.get_slice("=", 1)
		elif arg == "--mercato-filtre":
			# Une recherche de défenseurs, bons défenseurs au moins, triés par prix (captures).
			mercato().filtres = {"poste": "D", "comp1": "defense", "niv1": 10, "tri": "prix"}
		elif arg == "--mercato-page=fiche":
			# La fiche d'une enchère ouverte où le club mène, sinon de la première ouverte (captures).
			var ouverts: Array = mercato().lots_semaine(mercato().semaine_a(mercato().maintenant())).filter(func(e): return not e.ferme)
			var miens := ouverts.filter(func(e): return e.meneur_moi)
			if not ouverts.is_empty():
				lot_ouvert = str((miens if not miens.is_empty() else ouverts)[0].lot)
				page = "fiche"
	var m := mercato()
	m.change.connect(_rafraichir)
	m.lire()
	# Les comptes à rebours avancent, et le marché se relit toutes les trente secondes tant qu'on le regarde.
	_minuteur = Timer.new()
	_minuteur.wait_time = 15.0
	_minuteur.timeout.connect(func():
		_lu += _minuteur.wait_time
		if _lu >= 30.0:
			_lu = 0.0
			mercato().lire()
		_rafraichir())
	add_child(_minuteur)
	_minuteur.start()
	remplir(_colonne)


static func mercato() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node("Mercato")


## Redessine, sauf pendant qu'on tape sa mise.
func _rafraichir() -> void:
	if _saisie != null and is_instance_valid(_saisie) and _saisie.has_focus():
		return
	var focus := get_viewport().gui_get_focus_owner() if get_viewport() != null else null
	if focus is LineEdit or focus is OptionButton:
		return
	remplir(_colonne)


func remplir(colonne: VBoxContainer) -> void:
	_vider(colonne)
	_saisie = null
	var f := foot()
	var c: Dictionary = f.clubs.get(club, {})
	var m := mercato()
	var t: int = m.maintenant()
	var miens: Array = m.joueurs_de(club, t)
	# Sur un téléphone, le haut se serre pour laisser la place à la liste.
	if not _etroit() and not integre:
		colonne.add_child(_mot("L E   M E R C A T O", 13, DOUX))
	if not integre:
		colonne.add_child(_mot(("Le mercato  ·  " if _etroit() else "") + str(c.get("nom", "Le club")), 22 if _etroit() else 34, CRAIE, Polices.titre()))
	var onglets := HFlowContainer.new()
	onglets.add_theme_constant_override("h_separation", 10)
	onglets.add_theme_constant_override("v_separation", 6)
	if not integre:
		colonne.add_child(onglets)
	for o in [["marche", "La recherche"], ["suivis", "Suivis  (%d)" % m.encheres_suivies().size()], ["effectif", "Nos joueurs  (%d)" % miens.size()]]:
		var b := _bouton(o[1], func(): aller(o[0]), 15)
		b.name = "Onglet_" + o[0]
		b.disabled = page == o[0]
		# L'onglet ouvert : plein, à l'encre de l'ardoise.
		var plein := _boite(Color(OR, 0.85), OR, 4, 8)
		plein.content_margin_left = 18
		plein.content_margin_right = 18
		b.add_theme_stylebox_override("disabled", plein)
		b.add_theme_color_override("font_disabled_color", ARDOISE)
		onglets.add_child(b)
	for n in m.nouvelles.slice(0, 2):
		colonne.add_child(_mot(str(n), 15, OR, null, true))
	if not integre:
		colonne.add_child(_filet())
	# Le corps de la page défile seul : le haut et la rangée du bas restent à l'écran, téléphone compris.
	var corps := VBoxContainer.new()
	corps.add_theme_constant_override("separation", 6 if _etroit() else 8)
	corps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	match page:
		"fiche":
			_fiche(corps)
		"effectif":
			_effectif(corps, miens)
		"suivis":
			_suivis(corps)
		"offres":
			_offres(corps)
		_:
			_marche(corps)
	var defile := ScrollContainer.new()
	defile.name = "Corps"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.add_child(corps)
	var haut_max := _ecran().y - (350.0 if _etroit() else 470.0) - 24.0 * mini(m.nouvelles.size(), 2)
	if integre:
		haut_max = hauteur - (96.0 if page == "fiche" else 56.0) - 26.0 * mini(m.nouvelles.size(), 2)
	defile.custom_minimum_size = Vector2(largeur if integre else (0.0 if _etroit() else minf(1080.0, _ecran().x - 160.0)), maxf(160.0, haut_max))
	colonne.add_child(defile)
	# Une page courte ne garde pas toute la hauteur : on la mesure une fois posée.
	(func():
		if is_instance_valid(defile) and is_instance_valid(corps) and not integre:
			defile.custom_minimum_size.y = clampf(corps.get_combined_minimum_size().y, 80.0, maxf(160.0, haut_max))).call_deferred()
	colonne.add_child(_filet())
	_ligne_etat = _mot(_message if _message != "" else _etat_texte(), 15, DOUX, null, true)
	colonne.add_child(_ligne_etat)
	var bas := HFlowContainer.new()
	bas.alignment = FlowContainer.ALIGNMENT_END
	bas.add_theme_constant_override("h_separation", 10)
	colonne.add_child(bas)
	if page == "fiche":
		bas.add_child(_bouton("Retour", func(): aller(_retour)))
	if not integre:
		bas.add_child(_bouton("Laisser le président  (Échap)", func(): closed.emit()))
	elif bas.get_child_count() == 0:
		bas.queue_free()


## Emboîtée, Échap ramène d'une fiche à la liste et laisse le reste au bureau.
func _unhandled_input(event: InputEvent) -> void:
	if not integre:
		super(event)
	elif visible and page == "fiche" and event.is_action_pressed("ui_cancel"):
		aller(_retour)
		get_viewport().set_input_as_handled()


## Emboîtée, un texte replié tient dans la place laissée par le bureau.
func _large() -> float:
	return minf(900.0, largeur - 24.0) if integre and largeur > 0.0 else super()


func aller(p: String) -> void:
	if p == "fiche" and page != "fiche":
		_retour = page
	page = p
	_message = ""
	if p != "fiche":
		lot_ouvert = ""
		joueur_ouvert = ""
	remplir(_colonne)


## Ouvre la fiche d'un lot du marché (ou d'un joueur de l'effectif, lot « »).
func ouvrir(lot: String, joueur := "") -> void:
	lot_ouvert = lot
	joueur_ouvert = joueur
	aller("fiche")


# ---------------------------------------------------------------- le marché

## Les postes, les âges, les crans et les tris proposés par la recherche.
const CHOIX_POSTES := [["", "Tous les postes"], ["G", "Gardiens"], ["D", "Défenseurs"], ["M", "Milieux"], ["A", "Attaquants"]]
const CHOIX_AGES := [[0, 99, "Tous les âges"], [17, 20, "17 à 20 ans"], [21, 24, "21 à 24 ans"], [25, 28, "25 à 28 ans"], [29, 99, "29 ans et plus"]]
const CHOIX_TRIS := [["echeance", "Date limite"], ["prix", "Prix"], ["age", "Âge"], ["note", "Note"], ["comp1", "1re compétence"]]
const NOMS_COMP := {"endurance": "Endurance", "gardien": "Gardien", "defense": "Défense", "jeu": "Construction", "aile": "Ailes",
	"passe": "Passes", "but": "Buteur", "cpa": "Coups de pied arrêtés"}


## La recherche de transferts, à la Hattrick : les filtres en haut, la liste triée en dessous.
func _marche(colonne: VBoxContainer) -> void:
	var m := mercato()
	var f: Dictionary = m.filtres
	var filtres := HFlowContainer.new()
	filtres.name = "Filtres"
	filtres.add_theme_constant_override("h_separation", 10)
	filtres.add_theme_constant_override("v_separation", 6)
	colonne.add_child(filtres)
	filtres.add_child(_choix("Poste", CHOIX_POSTES.map(func(x): return x[1]), CHOIX_POSTES.map(func(x): return x[0]).find(str(f.get("poste", ""))),
		func(i): _filtrer({"poste": CHOIX_POSTES[i][0]})))
	var age_i := 0
	for i in CHOIX_AGES.size():
		if int(CHOIX_AGES[i][0]) == int(f.get("age_min", 0)) and int(CHOIX_AGES[i][1]) == int(f.get("age_max", 99)):
			age_i = i
	filtres.add_child(_choix("Age", CHOIX_AGES.map(func(x): return x[2]), age_i, func(i): _filtrer({"age_min": CHOIX_AGES[i][0], "age_max": CHOIX_AGES[i][1]})))
	var comps := [""] + NOMS_COMP.keys()
	var crans := range(4, 19)
	for n in ["1", "2"]:
		filtres.add_child(_choix("Comp" + n, ["Compétence"] + NOMS_COMP.values(), maxi(0, comps.find(str(f.get("comp" + n, "")))),
			func(i): _filtrer({"comp" + n: comps[i], "niv" + n: int(f.get("niv" + n, 9)) if i > 0 else 0})))
		if str(f.get("comp" + n, "")) != "":
			filtres.add_child(_choix("Niv" + n, crans.map(func(c): return "au moins " + mercato().NIVEAUX[c]), maxi(0, crans.find(int(f.get("niv" + n, 9)))),
				func(i): _filtrer({"niv" + n: crans[i]})))
	var plafond := LineEdit.new()
	plafond.name = "PrixMax"
	plafond.placeholder_text = "Prix maximum"
	plafond.text = str(int(f.prix_max)) if int(f.get("prix_max", 0)) > 0 else ""
	plafond.custom_minimum_size.x = 150
	plafond.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	plafond.add_theme_font_size_override("font_size", 14)
	plafond.text_submitted.connect(func(x): _filtrer({"prix_max": int(x.to_int())}))
	plafond.focus_exited.connect(func():
		if is_instance_valid(plafond) and int(plafond.text.to_int()) != int(m.filtres.get("prix_max", 0)):
			_filtrer.call_deferred({"prix_max": int(plafond.text.to_int())}))
	filtres.add_child(plafond)
	filtres.add_child(_choix("Tri", CHOIX_TRIS.map(func(x): return "Trier : " + x[1]), maxi(0, CHOIX_TRIS.map(func(x): return x[0]).find(str(f.get("tri", "echeance")))),
		func(i): _filtrer({"tri": CHOIX_TRIS[i][0]})))
	if not f.is_empty():
		filtres.add_child(_bouton("Tout voir", func():
			m.filtres = {}
			m.sauver()
			remplir(_colonne), 13))
	var trouves: Array = m.rechercher(f)
	var total: int = m.ouvertes().size()
	colonne.add_child(_mot("%d joueur%s sur %d en vente. Quarante nouveaux chaque dimanche à 17 h, mis en vente par les clubs de la Vienne ; le plus offrant l'emporte." % [trouves.size(), "s" if trouves.size() > 1 else "", total], 14, DOUX, null, true))
	var liste := VBoxContainer.new()
	liste.add_theme_constant_override("separation", 4 if _etroit() else 5)
	for e in trouves:
		liste.add_child(_rangee(e, [str(f.get("comp1", "")), str(f.get("comp2", ""))]))
	if trouves.is_empty():
		liste.add_child(_mot("Personne ne répond à ces critères cette semaine." if total > 0 else "Plus rien en vente cette semaine : les nouveaux arrivent dimanche à 17 h.", 15, CRAIE, null, true))
	colonne.add_child(liste)


func _filtrer(d: Dictionary) -> void:
	var m := mercato()
	for k in d:
		if d[k] is String and d[k] == "" or (k.begins_with("niv") or k == "prix_max") and int(d[k]) == 0:
			m.filtres.erase(k)
		else:
			m.filtres[k] = d[k]
	if int(m.filtres.get("age_min", 0)) == 0 and int(m.filtres.get("age_max", 99)) == 99:
		m.filtres.erase("age_min")
		m.filtres.erase("age_max")
	if str(m.filtres.get("tri", "echeance")) == "echeance":
		m.filtres.erase("tri")
	m.sauver()
	remplir(_colonne)


## Une liste déroulante sur l'ardoise.
func _choix(nom: String, libelles: Array, choisi: int, action: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.name = nom
	o.add_theme_font_size_override("font_size", 14)
	o.add_theme_font_override("font", Polices.texte())
	for l in libelles:
		o.add_item(str(l))
	o.select(clampi(choisi, 0, libelles.size() - 1))
	o.item_selected.connect(func(i): action.call(i))
	return o


## Les joueurs suivis : leur prix du moment et qui mène, comme au marché.
func _suivis(colonne: VBoxContainer) -> void:
	var m := mercato()
	var liste: Array = m.encheres_suivies()
	colonne.add_child(_mot("Les joueurs que vous suivez, de la date limite la plus proche à la plus lointaine. L'étoile d'une ligne ou d'une fiche les ajoute ou les retire.", 14, DOUX, null, true))
	if liste.is_empty():
		colonne.add_child(_mot("Vous ne suivez personne pour l'instant.", 16, CRAIE))
	for e in liste:
		colonne.add_child(_rangee(e, []))


## Les offres en cours du club : ses enchères (en tête, dépassées, gagnées ou perdues ces trois derniers
## jours), ses ventes, puis les joueurs suivis.
func _offres(colonne: VBoxContainer) -> void:
	var m := mercato()
	var o: Dictionary = m.offres_du_club(club)
	colonne.add_child(_mot("Nos enchères", 18, CRAIE, Polices.gras()))
	if o.encheres.is_empty():
		colonne.add_child(_mot("Le club n'a pas d'enchère en cours. La recherche de joueurs montre ceux qui sont en vente.", 15, DOUX, null, true))
	for e in o.encheres:
		colonne.add_child(_rangee(e, []))
	colonne.add_child(_filet())
	colonne.add_child(_mot("Nos ventes", 18, CRAIE, Polices.gras()))
	if o.ventes.is_empty():
		colonne.add_child(_mot("Rien en vente. Un joueur acheté au marché se remet en vente depuis sa fiche, dans l'effectif.", 15, DOUX, null, true))
	for e in o.ventes:
		colonne.add_child(_rangee(e, []))
	colonne.add_child(_filet())
	colonne.add_child(_mot("Les joueurs suivis", 18, CRAIE, Polices.gras()))
	_suivis(colonne)


## Une ligne de la liste, à la Hattrick : le nom, le poste et l'âge, deux compétences en petites barres
## (celles de la recherche, sinon les deux de son poste), la date limite, le prix et qui mène, l'étoile.
func _rangee(e: Dictionary, comps: Array) -> Control:
	var m := mercato()
	var j: Dictionary = e.joueur
	var h := HFlowContainer.new()
	h.name = "Lot_" + str(e.lot)
	h.add_theme_constant_override("h_separation", 6 if _etroit() else 10)
	h.add_theme_constant_override("v_separation", 2)
	var etoile := _etoile(str(e.lot), 14)
	h.add_child(etoile)
	var nom := _mot("%s %s" % [j.prenom, j.nom], 15, CRAIE, Polices.gras())
	nom.custom_minimum_size.x = 120 if _etroit() else 180
	h.add_child(nom)
	var fiche := _mot("%s  ·  %d ans  ·  %d" % [str(j.poste), j.age, j.note], 14, DOUX)
	fiche.tooltip_text = "%s, %d ans, note %d" % [FootMatch.POSTES.get(j.poste, j.poste), j.age, j.note]
	fiche.mouse_filter = Control.MOUSE_FILTER_PASS
	fiche.custom_minimum_size.x = 92 if _etroit() else 110
	h.add_child(fiche)
	var a_montrer: Array = comps.filter(func(c): return c != "")
	for c in m.PRINCIPALES[str(j.poste)]:
		if a_montrer.size() < 2 and not c in a_montrer:
			a_montrer.append(c)
	for c in a_montrer:
		h.add_child(_mini(c, float(j.competences.get(c, 0))))
	var quand := _mot(_echeance_courte(e), 14, DOUX)
	quand.custom_minimum_size.x = 88 if _etroit() else 120
	h.add_child(quand)
	var prix := _mot(_prix_texte(e), 14, OR if e.meneur == club else CRAIE)
	prix.clip_text = true
	prix.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	prix.custom_minimum_size.x = 150 if _etroit() else 250
	h.add_child(prix)
	var b := _bouton("Enchérir" if not e.ferme else "Fiche", func(): ouvrir(str(e.lot)), 14)
	b.name = "Fiche_" + str(e.lot)
	h.add_child(b)
	return h


## Une compétence en petit : son nom court, une barre de la couleur de son cran, le cran.
func _mini(cle: String, v: float) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var court := {"endurance": "End", "gardien": "Gar", "defense": "Déf", "jeu": "Cons", "aile": "Ail", "passe": "Pas", "but": "But", "cpa": "CPA"}
	var l := _mot(court.get(cle, cle), 12, DOUX)
	l.custom_minimum_size.x = 32
	h.add_child(l)
	h.add_child(_barre(v, 40 if _etroit() else 54))
	var n := _mot(str(mercato().niveau(v)), 13, couleur_cran(mercato().niveau(v)))
	n.custom_minimum_size.x = 18
	n.tooltip_text = mercato().mot_niveau(v)
	n.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(n)
	h.custom_minimum_size.x = 100 if _etroit() else 118
	return h


## La couleur d'un cran, du rouge des crans faibles à l'or des grands.
static func couleur_cran(n: int) -> Color:
	if n <= 4:
		return Color(0.86, 0.38, 0.32)
	if n <= 7:
		return Color(0.9, 0.6, 0.3)
	if n <= 10:
		return Color(0.88, 0.8, 0.42)
	if n <= 13:
		return Color(0.55, 0.8, 0.45)
	return Color(0.98, 0.84, 0.35)


## L'étoile qui suit un joueur.
func _etoile(lot: String, taille := 16) -> Button:
	var m := mercato()
	var suivi: bool = m.suivis.has(lot)
	var b := Button.new()
	b.name = "Suivre_" + lot
	b.flat = true
	b.text = "★" if suivi else "☆"
	b.tooltip_text = "Ne plus suivre" if suivi else "Suivre ce joueur"
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", taille + 4)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, OR if suivi else DOUX)
	b.pressed.connect(func(): m.suivre(lot, not suivi))
	return b


## « mardi 20 h », ou « dans 2 h 14 » le dernier jour, « clos » après.
func _echeance_courte(e: Dictionary) -> String:
	var t: int = mercato().maintenant()
	var r := int(e.echeance) - t
	if r <= 0:
		return "clos " + JOURS[Time.get_datetime_dict_from_unix_time(int(e.echeance)).weekday]
	if r < 86400:
		return "dans %d h %02d" % [r / 3600, (r % 3600) / 60] if r >= 3600 else "dans %d min" % maxi(1, r / 60)
	var d := Time.get_datetime_dict_from_unix_time(int(e.echeance))
	return "%s %d h%s" % [JOURS[d.weekday], d.hour, "" if d.minute == 0 else "%02d" % d.minute]


func _qui(e: Dictionary, meneur: String) -> String:
	if meneur == "invite":
		return str(e.acheteur)
	if meneur == club:
		return "vous" if bool(e.get("meneur_moi", false)) else str(foot().clubs.get(club, {}).get("nom", club))
	return str(foot().clubs.get(meneur, {}).get("nom", meneur))


func _prix_texte(e: Dictionary) -> String:
	var fmt := Game.fmt(int(e.prix))
	if e.ferme:
		if e.gagnant == "":
			return "invendu"
		return "%s crédits, %s" % [fmt, _qui(e, e.gagnant)]
	if e.meneur == "":
		return "mise à prix : %s crédits" % fmt
	return "%s crédits, %s" % [fmt, _qui(e, e.meneur)]


# ---------------------------------------------------------------- la fiche

func _fiche(colonne: VBoxContainer) -> void:
	var m := mercato()
	var e: Dictionary = m.enchere(lot_ouvert) if lot_ouvert != "" else {}
	var j: Dictionary
	if not e.is_empty():
		j = e.joueur
	else:
		var t: int = m.maintenant()
		j = m.joueur_en(joueur_ouvert, foot().saison_a(t))
		if j.is_empty():
			aller("marche")
			return
		j.forme = m.forme(joueur_ouvert, m.semaine_a(t))
		var v: Dictionary = m.vente_ouverte(joueur_ouvert)
		if not v.is_empty():
			e = v
	var titre := HBoxContainer.new()
	titre.add_theme_constant_override("separation", 6)
	if not e.is_empty() and lot_ouvert != "":
		titre.add_child(_etoile(lot_ouvert, 20))
	titre.add_child(_mot("%s %s" % [j.prenom, j.nom], 24 if _etroit() else 28, CRAIE, Polices.gras()))
	colonne.add_child(titre)
	var origine := ""
	if not e.is_empty():
		origine = "mis en vente par %s" % e.vendeur
	var jours: int = m.age_jours(m.maintenant())
	colonne.add_child(_mot("%s  ·  %d ans et %d jour%s  ·  note %d%s" % [FootMatch.POSTES.get(j.poste, j.poste), j.age, jours, "s" if jours > 1 else "", j.note, "  ·  " + origine if origine != "" else ""], 16, DOUX, null, true))
	var rang: Container = HFlowContainer.new() if _etroit() else HBoxContainer.new()
	rang.add_theme_constant_override("separation", 36)
	rang.add_theme_constant_override("h_separation", 36)
	rang.add_theme_constant_override("v_separation", 10)
	colonne.add_child(rang)

	# À gauche, le joueur : à la Hattrick, en mots.
	var gauche := VBoxContainer.new()
	gauche.add_theme_constant_override("separation", 4)
	gauche.add_child(_mot("Forme : %s (%d)    Expérience : %s (%d)" % [m.FORMES[int(j.forme)], int(j.forme), m.NIVEAUX[clampi(int(j.experience), 0, 20)], int(j.experience)], 15, CRAIE))
	var grille := GridContainer.new()
	grille.name = "Competences"
	grille.columns = 3
	grille.add_theme_constant_override("h_separation", 12)
	grille.add_theme_constant_override("v_separation", 3)
	gauche.add_child(grille)
	for cle in ["endurance", "gardien", "defense", "jeu", "aile", "passe", "but", "cpa"]:
		var v := float(j.competences.get(cle, 0))
		grille.add_child(_mot(NOMS_COMP[cle], 14, DOUX))
		grille.add_child(_barre(v))
		grille.add_child(_mot("%s (%d)" % [m.mot_niveau(v), m.niveau(v)], 14, couleur_cran(m.niveau(v))))
	gauche.add_child(_mot("Salaire : %s crédits la semaine    Valeur estimée : %s crédits" % [Game.fmt(int(j.salaire)), Game.fmt(int(j.valeur))], 15, DOUX, null, _etroit()))

	# À droite, l'enchère : la date limite, les offres, la mise.
	var droite := VBoxContainer.new()
	droite.add_theme_constant_override("separation", 6)
	droite.custom_minimum_size.x = 460 if _etroit() else 400
	# Sur un téléphone, l'enchère d'abord : la mise est à portée de pouce sans défiler.
	if _etroit():
		rang.add_child(droite)
		rang.add_child(gauche)
	else:
		rang.add_child(gauche)
		rang.add_child(droite)
	if e.is_empty():
		_vendre(droite, j)
		return
	droite.add_child(_texte(droite, "Date limite : %s" % _echeance_longue(e), 15, CRAIE))
	if int(e.echeance) != int(e.echeance_prevue):
		droite.add_child(_texte(droite, "Repoussée par une offre de dernière minute.", 14, DOUX))
	droite.add_child(_texte(droite, "Mise à prix : %s crédits" % Game.fmt(int(e.prix_depart)), 15, DOUX))
	if e.ferme:
		var issue: String = "Invendu : personne n'a voulu de lui à ce prix." if e.gagnant == "" else "Adjugé à %s pour %s crédits." % [_qui(e, e.gagnant), Game.fmt(int(e.prix))]
		droite.add_child(_texte(droite, issue, 17, OR))
	elif e.meneur == "":
		droite.add_child(_texte(droite, "Pas encore d'offre.", 17, CRAIE))
	else:
		droite.add_child(_texte(droite, "En tête : %s, %s crédits." % [_qui(e, e.meneur), Game.fmt(int(e.prix))], 17, OR))
	if not e.offres.is_empty():
		# L'historique des offres, en petit tableau.
		var offres := GridContainer.new()
		offres.name = "Offres"
		offres.columns = 3
		offres.add_theme_constant_override("h_separation", 14)
		offres.add_theme_constant_override("v_separation", 2)
		for t in ["Offre", "Club", "Par"]:
			offres.add_child(_mot(t, 12, DOUX))
		for o in e.offres.slice(0, 6):
			offres.add_child(_mot(Game.fmt(int(o.montant)), 14, CRAIE))
			var nc := _mot(str(foot().clubs.get(o.club, {}).get("nom", o.club)), 14, DOUX)
			nc.clip_text = true
			nc.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			nc.custom_minimum_size.x = 170
			offres.add_child(nc)
			offres.add_child(_mot("vous" if bool(o.get("moi", false)) else str(o.par), 14, DOUX))
		droite.add_child(offres)
	if e.ferme:
		return
	if e.club_vendeur == club:
		droite.add_child(_texte(droite, "C'est notre vente : le club n'enchérit pas sur ses propres joueurs.", 15, DOUX))
		return
	var ligne := HFlowContainer.new()
	ligne.add_theme_constant_override("h_separation", 8)
	ligne.add_theme_constant_override("v_separation", 6)
	droite.add_child(ligne)
	_saisie = LineEdit.new()
	_saisie.name = "Mise"
	_saisie.text = str(int(e.minimum))
	_saisie.custom_minimum_size.x = 140
	_saisie.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_saisie.add_theme_font_size_override("font_size", 16)
	_saisie.text_submitted.connect(func(_t): miser(str(e.lot)))
	ligne.add_child(_saisie)
	var b := _bouton("Enchérir", func(): miser(str(e.lot)))
	b.name = "Encherir"
	ligne.add_child(b)
	var plus := HFlowContainer.new()
	plus.add_theme_constant_override("h_separation", 6)
	droite.add_child(plus)
	for x in [100, 500, 1000]:
		plus.add_child(_bouton("+%s" % Game.fmt(x), func(): _ajouter(x), 13))
	droite.add_child(_texte(droite, "Au moins %s crédits, et pas de plafond : seule votre poche compte. Votre mise est retenue tant que vous menez, rendue si l'on vous dépasse." % Game.fmt(int(e.minimum)), 14, DOUX))


func _texte(_parent: Control, t: String, taille: int, couleur: Color) -> Label:
	var l := _mot(t, taille, couleur)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 460 if _etroit() else 400
	return l


func _ajouter(x: int) -> void:
	if _saisie != null:
		_saisie.text = str(int(_saisie.text.to_int()) + x)


## Une barre de compétence, de la couleur de son cran.
func _barre(v: float, largeur := 0) -> Control:
	var fond := ColorRect.new()
	fond.color = Color(1, 1, 1, 0.08)
	fond.custom_minimum_size = Vector2(largeur if largeur > 0 else (90 if _etroit() else 140), 8 if largeur > 0 else 10)
	fond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var plein := ColorRect.new()
	plein.color = Color(couleur_cran(mercato().niveau(v)), 0.85)
	plein.size = Vector2(fond.custom_minimum_size.x * clampf(v / 100.0, 0.0, 1.0), fond.custom_minimum_size.y)
	fond.add_child(plein)
	return fond


func _echeance_longue(e: Dictionary) -> String:
	var d := Time.get_datetime_dict_from_unix_time(int(e.echeance))
	var heure := "%d h%s" % [d.hour, "" if d.minute == 0 else "%02d" % d.minute]
	var r: int = int(e.echeance) - mercato().maintenant()
	if r <= 0:
		return "%s, à %s (close)" % [date(int(e.echeance)), heure]
	var reste := "%d j %d h" % [r / 86400, (r % 86400) / 3600] if r >= 86400 else ("%d h %02d" % [r / 3600, (r % 3600) / 60] if r >= 3600 else "%d min" % maxi(1, r / 60))
	return "%s, à %s (dans %s)" % [date(int(e.echeance)), heure, reste]


## Enchérit du montant tapé ; la ligne du bas dit ce qu'il en est.
func miser(lot: String) -> void:
	var montant := int(_saisie.text.to_int()) if _saisie != null else 0
	_message = "Le président passe le coup de fil…"
	if _ligne_etat != null:
		_ligne_etat.text = _message
	var r: Dictionary = await mercato().encherir(lot, club, montant)
	var e: Dictionary = mercato().enchere(lot)
	if r.ok:
		_message = "Offre posée : vous menez à %s crédits." % Game.fmt(montant) if r.mene else "%s surenchérit aussitôt : %s crédits. Rien n'est retenu de votre poche." % [e.acheteur, Game.fmt(int(r.prix))]
	else:
		_message = _raison(str(r.raison), e)
	remplir(_colonne)


func _raison(raison: String, e: Dictionary) -> String:
	return {"compte": "Pour enchérir, connectez-vous à votre compte Pyramides : les enchères comptent pour tous les villages.",
		"parts": "Le président n'écoute que celui qui dirige le club. Maître Garnier cède des parts du club à l'étude.",
		"ferme": "L'enchère est close.", "vendeur": "Le club n'enchérit pas sur ses propres ventes.",
		"bas": "Trop bas : il faut au moins %s crédits." % Game.fmt(int(e.get("minimum", 0))),
		"credits": "Il vous manque des crédits : vous avez %s crédits en poche." % Game.fmt(Game.credits),
		"deja": "Ce joueur est déjà en vente.", "pas_a_nous": "Ce joueur n'est pas au club.",
		"prix": "Un prix de départ d'au moins 10 crédits.", "reseau": "Le téléphone sonne dans le vide : réessayez dans un instant."}.get(raison, "Le président fait non de la tête.")


# ---------------------------------------------------------------- l'effectif

func _effectif(colonne: VBoxContainer, miens: Array) -> void:
	var m := mercato()
	var s: int = foot().saison_a(m.maintenant())
	colonne.add_child(_mot("Les joueurs achetés au marché jouent pour le club dès le coup d'envoi qui suit l'achat, et se revendent. Les dix-huit joueurs du cru, eux, sont du pays : ils ne se vendent pas.", 15, DOUX, null, true))
	if miens.is_empty():
		colonne.add_child(_mot("Le club n'a encore acheté personne.", 17, CRAIE))
	for id in miens:
		var j: Dictionary = m.joueur_en(id, s)
		var h := HFlowContainer.new()
		h.name = "Joueur_" + str(id)
		h.add_theme_constant_override("h_separation", 12)
		var nom := _mot("%s %s" % [j.prenom, j.nom], 15, CRAIE, Polices.gras())
		nom.custom_minimum_size.x = 170 if _etroit() else 200
		h.add_child(nom)
		var fiche := _mot("%s  ·  %d ans  ·  note %d  ·  %s crédits la semaine" % [FootMatch.POSTES.get(j.poste, j.poste), j.age, j.note, Game.fmt(int(j.salaire))], 14, DOUX)
		fiche.custom_minimum_size.x = 300 if _etroit() else 420
		h.add_child(fiche)
		var v: Dictionary = m.vente_ouverte(id)
		if not v.is_empty():
			h.add_child(_mot("en vente, %s" % _prix_texte(v), 14, OR))
		h.add_child(_bouton("Fiche", func(): ouvrir("", id), 14))
		colonne.add_child(h)
	if not miens.is_empty():
		colonne.add_child(_mot("Masse salariale : %s crédits la semaine." % Game.fmt(int(m.salaires(club))), 15, DOUX))


## La case de vente d'un joueur de l'effectif : un prix de départ et une durée.
func _vendre(droite: VBoxContainer, j: Dictionary) -> void:
	droite.add_child(_texte(droite, "Le remettre en vente", 18, CRAIE))
	droite.add_child(_texte(droite, "Prix de départ libre ; la vente se clôt à 21 h, dans un, trois ou sept jours. Le prix revient dans la poche de celui qui le met en vente.", 14, DOUX))
	_saisie = LineEdit.new()
	_saisie.name = "Prix"
	_saisie.text = str(int(j.valeur) / 2)
	_saisie.custom_minimum_size.x = 140
	_saisie.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	_saisie.add_theme_font_size_override("font_size", 16)
	droite.add_child(_saisie)
	var ligne := HFlowContainer.new()
	ligne.add_theme_constant_override("h_separation", 8)
	droite.add_child(ligne)
	for n in mercato().DUREES:
		var b := _bouton("%d jour%s" % [n, "s" if n > 1 else ""], func(): mettre_en_vente(str(j.id), n), 14)
		b.name = "Vendre_%d" % n
		ligne.add_child(b)


func mettre_en_vente(joueur: String, jours: int) -> void:
	var prix := int(_saisie.text.to_int()) if _saisie != null else 0
	var r: Dictionary = await mercato().vendre(club, joueur, prix, jours)
	_message = "En vente à partir de %s crédits." % Game.fmt(prix) if r.ok else _raison(str(r.raison), {})
	remplir(_colonne)


func _etat_texte() -> String:
	var m := mercato()
	var f := foot()
	if not m.connecte():
		return "Hors ligne ou sans compte : on regarde le marché, on n'enchérit pas. Connectez-vous à votre compte Pyramides pour enchérir."
	if not f.peut_decider(club):
		return "Le président n'écoute que celui qui dirige le club. Maître Garnier cède des parts du club à l'étude."
	var retenu := 0
	for x in m.retenues.values():
		retenu += int(x)
	return "Vous enchérissez de votre poche : le club n'a pas de caisse. Vous avez %s crédits%s." % [Game.fmt(Game.credits), ", et %s retenus sur vos offres en tête" % Game.fmt(retenu) if retenu > 0 else ""]


# ---------------------------------------------------------------- la démonstration (captures)

## Un marché animé pour les captures : des offres d'autres villages, une offre du club en tête, un joueur
## déjà acheté et remis en vente par un autre club, un serveur qui dit oui.
static func demo(m: Node, club: String) -> void:
	var f := foot()
	var t: int = m.maintenant()
	var k: int = m.semaine_a(t)
	var autre := ""
	for id in f.clubs:
		if id != club and not bool(f.clubs[id].get("invite", false)):
			autre = id
	if autre == "":
		for id in f.clubs:
			if id != club:
				autre = id
				break
	var encheres: Array = []
	var ventes: Array = []
	# Les enchères déjà closes de la semaine : le club en a gagné deux, l'autre club une, qu'il remet en vente.
	var clos: Array = m.lots_semaine(k).filter(func(e): return e.ferme)
	for e in clos.slice(0, 2):
		encheres.append({"lot": e.lot, "club": club, "montant": int(e.plafond) + 40, "par": "vous", "moi": true, "quand": "2026-10-19 10:00:00.000"})
	var heure := func(x: int) -> String: return Time.get_datetime_string_from_unix_time(x, true)
	if clos.size() > 2:
		var lot_autre: String = clos[2].lot
		encheres.append({"lot": lot_autre, "club": autre, "montant": int(clos[2].plafond) + 100, "par": "Lucien", "moi": false, "quand": "2026-10-19 11:00:00.000"})
		ventes.append({"id": 1, "club": autre, "joueur": lot_autre, "saison": f.saison_a(t), "prix_depart": 800,
			"echeance": heure.call(m.echeance_vente(t, 3)), "cree": heure.call(t - 3600), "par": "Lucien", "moi": false})
	# Cette semaine : des offres sur les lots ouverts.
	var lots: Array = m.lots_semaine(k).filter(func(e): return not e.ferme)
	if lots.size() > 2:
		var a: Dictionary = lots[0]
		encheres.append({"lot": a.lot, "club": autre, "montant": int(a.prix_depart) + 200, "par": "Lucien", "moi": false, "quand": "2026-10-20 09:00:00.000"})
		var b: Dictionary = lots[2]
		encheres.append({"lot": b.lot, "club": club, "montant": int(b.plafond) + 60, "par": "vous", "moi": true, "quand": "2026-10-20 09:30:00.000"})
	m.appel = func(fonction: String, _corps: Dictionary) -> Dictionary:
		if fonction == "smarves_mercato":
			return {"code": 200, "corps": {"encheres": encheres, "ventes": ventes, "prolongations": []}}
		return {"code": 200, "corps": {"ok": true}}
	m.appliquer({"encheres": encheres, "ventes": ventes, "prolongations": []})
	m.nouvelles = []
	m.suivis = {}
	for e in lots.slice(0, 7):
		if lots.find(e) % 2 == 0:
			m.suivis[e.lot] = true
	if not clos.is_empty():
		var g: Dictionary = m.enchere(clos[0].lot)
		m.nouvelles = ["Enchère gagnée : %s %s rejoint %s pour %s crédits. Il joue dès le prochain coup d'envoi." % [g.joueur.prenom, g.joueur.nom, f.clubs.get(club, {}).get("nom", club), Game.fmt(int(g.prix))]]
