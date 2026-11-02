class_name Bureau
extends FootTableau
## Le bureau du club (docs/SUITE.md, section 6) : on y pilote le club, dans une page qui prend presque tout
## l'écran, à la Football Manager. À gauche, les couleurs et le rang du club, puis la barre des pages :
## l'accueil, l'effectif, la tactique (les onze postes sur le terrain, une consigne par joueur), l'agenda du
## club, le championnat (les clubs, les buteurs, les passeurs, les clean sheets), la recherche de joueurs et
## les offres en cours, ces deux-là prises au mercato (FootMercato, emboîté). Sur un téléphone, la barre
## devient une rangée d'onglets en haut. Demande de Guillaume du 18 octobre : « le pilotage ne se fait pas
## avec le président, il se fait plutôt dans le bureau ».
##
## Depuis le 23 octobre (« quelque chose de réellement addictif, à la Football Manager ») : l'accueil est le
## courrier du club (comptes rendus, progrès de l'entraînement, rapport de l'adjoint, ce qui reste à faire),
## avec l'objectif de la direction et sa confiance ; la page Adversaire donne le rapport de l'adjoint et la
## répétition (le match joué vingt fois à l'entraînement avec la tactique qu'on prépare) ; la page
## Entraînement choisit le programme de la semaine, qui fait progresser les joueurs (FootEntrainement).
##
## Tout vient de Football et de Mercato par leurs fonctions publiques ; ce que Football ne donne pas encore
## (les postes et consignes individuelles, les statistiques des joueurs), la page le dit au lieu de le
## calculer. S'ouvre et se ferme comme les autres fenêtres du stade (signal closed, Échap).

## Le registre des obligations, que le stade ouvre à la place du bureau.
signal obligations

## Le marché, pour ses fonctions sans état (la valeur d'un joueur, le cran d'une compétence).
const MERCATO := preload("res://scripts/socle/mercato/mercato.gd")
const DIRIGER := preload("res://scripts/socle/diriger.gd")
const AUJOURDHUI := preload("res://scripts/socle/aujourdhui.gd")
const PAGES := [["accueil", "Accueil"], ["effectif", "Effectif"], ["tactique", "Tactique"], ["adversaire", "Adversaire"],
	["entrainement", "Entraînement"], ["agenda", "Agenda"], ["championnat", "Championnat"], ["recherche", "Recherche de joueurs"],
	["offres", "Offres en cours"]]
## Le courrier lu, sur cet appareil (dans le dossier de Football) : {id: true}.
const FICHIER_COURRIER := "courrier_lu.json"
## Les matchs d'une répétition à l'entraînement.
const REPETITIONS := 20
const VERT := Color(0.45, 0.85, 0.5)
## Ce que dit l'adjoint d'un duel, du net avantage au danger.
const MOTS_DUELS := {"milieu": ["nous dominerons", "léger avantage", "équilibre", "ils auront le ballon", "ils domineront"],
	"attaque": ["grand ouvert", "jouable", "équilibre", "fermé", "verrouillé"],
	"defense": ["solide", "tient", "équilibre", "à surveiller", "danger"]}
const ROUGE := Color(0.95, 0.45, 0.4)
const ONGLETS_CHAMPIONNAT := [["classement", "Classement"], ["buteurs", "Buteurs"], ["passeurs", "Passeurs"], ["clean_sheets", "Clean sheets"]]
## Les fonds : la barre de gauche, plus sombre, et la page ; ceux du carnet depuis le 25 octobre 2026
## (scripts/socle/teintes.gd), plutôt qu'un vert d'ardoise.
const NUIT := Color(0.08, 0.07, 0.075, 0.99)
const PAGE := Color(0.11, 0.098, 0.1, 0.99)
const LIGNE := Color(1, 1, 1, 0.04)
const PELOUSE := Color(0.2, 0.45, 0.24)
const PELOUSE_CLAIRE := Color(0.23, 0.5, 0.27)
## Les colonnes de l'effectif qu'on peut trier, et leur sens.
const TRIS_EFFECTIF := {"poste": "Poste", "nom": "Nom", "age": "Âge", "note": "Note", "buts": "Buts", "passes": "Passes", "valeur": "Valeur"}

var club := ""
var page := "accueil"
## La tactique se lit sans se régler : on ne dirige pas le club (ou la saison n'est pas tirée).
var _lecture := false
## La composition a changé à l'écran depuis la dernière validation (ou le chargement).
var modifie := false
var onglet_championnat := "classement"
var tri_effectif := "poste"
## La fiche d'un joueur du cru ouverte dans l'effectif (son id), ou "".
var joueur_ouvert := ""
## Le message du courrier ouvert à l'accueil (son id), ou "".
var message_ouvert := ""
## Le programme choisi à la page Entraînement, avant d'être posé (« » : celui de la consigne).
var programme_choisi := ""
## La dernière répétition à l'entraînement : Football.repetition, ou {} ; et si elle se joue.
var repetition := {}
var _repete := false

## La composition en cours d'écriture : {formation, mentalite, pressing, onze (11 ids, l'ordre des cases),
## banc, ordres {id: rôle}} ; vide tant qu'on n'a pas ouvert la tactique. Football les reçoit en compo, banc, roles.
var compo := {}
## Le poste choisi sur le terrain (son rang dans la formation, ou 100 + rang sur le banc), et le joueur choisi.
var case_choisie := -1
var joueur_choisi := ""
var _message := ""

var _nav: VBoxContainer
var _boutons_nav := {}
var _nom_club: Label
var _rang: Label
var _solde: Label
var _rafraichir_prevu := false
var _titre: Label
var _sous_titre: Label
var _corps: VBoxContainer
var _mercato: FootMercato
## La largeur de la colonne à droite du terrain (la tactique).
var _largeur_liste := 400.0


func _ready() -> void:
	if foot().niveaux.is_empty():
		foot().actualiser()
	var e := _ecran()
	var etroit := _etroit()
	# Toute la page, à 2 % près ; sur un téléphone, sous la barre du haut (les crédits, « Sortir »).
	var marge := Vector2(8, BARRE_HAUT) if etroit else e * 0.02
	custom_minimum_size = Vector2(e.x - 2.0 * marge.x, e.y - marge.y - (8.0 if etroit else marge.y))
	# Posé tel quel dans un CanvasLayer (le stade) : il s'étire sur l'écran, à la même marge.
	if not get_parent() is Container:
		set_anchors_preset(Control.PRESET_FULL_RECT)
		offset_left = marge.x
		offset_right = -marge.x
		offset_top = marge.y
		offset_bottom = -(8.0 if etroit else marge.y)
	var fond := _boite(PAGE, Color(0.55, 0.42, 0.25), 6, 0, 2)
	fond.shadow_color = Color(0, 0, 0, 0.5)
	fond.shadow_size = 24
	add_theme_stylebox_override("panel", fond)
	var cadre: BoxContainer = VBoxContainer.new() if etroit else HBoxContainer.new()
	cadre.add_theme_constant_override("separation", 0)
	add_child(cadre)
	var barre := PanelContainer.new()
	barre.name = "Barre"
	barre.add_theme_stylebox_override("panel", _boite(NUIT, Color.TRANSPARENT, 6, 8 if etroit else 16))
	cadre.add_child(barre)
	if etroit:
		var defile := ScrollContainer.new()
		defile.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		defile.custom_minimum_size.y = 46
		barre.add_child(defile)
		_nav = VBoxContainer.new()
		defile.add_child(_nav)
	else:
		barre.custom_minimum_size.x = 250
		_nav = VBoxContainer.new()
		_nav.add_theme_constant_override("separation", 6)
		barre.add_child(_nav)
	var droite := PanelContainer.new()
	droite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	droite.size_flags_vertical = Control.SIZE_EXPAND_FILL
	droite.add_theme_stylebox_override("panel", _boite(Color.TRANSPARENT, Color.TRANSPARENT, 0, 10 if etroit else 22))
	cadre.add_child(droite)
	var page_col := VBoxContainer.new()
	page_col.add_theme_constant_override("separation", 6 if etroit else 10)
	droite.add_child(page_col)
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", 16)
	page_col.add_child(tete)
	_titre = _mot("", 22 if etroit else 32, CRAIE, Polices.titre())
	tete.add_child(_titre)
	_sous_titre = _mot("", 14 if etroit else 15, DOUX)
	_sous_titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sous_titre.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_sous_titre.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sous_titre.clip_text = true
	_sous_titre.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tete.add_child(_sous_titre)
	# La croix, en haut à droite (demande de Guillaume du 25 octobre 2026), à la place de « Quitter le bureau ».
	var croix: Button = preload("res://scripts/socle/croix.gd").creer(func(): closed.emit())
	croix.name = "Quitter"
	tete.add_child(croix)
	page_col.add_child(_filet())
	_corps = VBoxContainer.new()
	_corps.name = "Page"
	_corps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_corps.add_theme_constant_override("separation", 6 if etroit else 10)
	page_col.add_child(_corps)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--bureau-page="):
			page = arg.get_slice("=", 1)
		elif arg.begins_with("--bureau-onglet="):
			onglet_championnat = arg.get_slice("=", 1)
		elif arg == "--bureau-courrier":
			# Le message le plus récent du courrier, ouvert (captures).
			var liste := courrier()
			if not liste.is_empty():
				message_ouvert = str(liste[0].id)
		elif arg == "--bureau-repetition":
			repeter.call_deferred()
		elif arg.begins_with("--bureau-programme="):
			programme_choisi = arg.get_slice("=", 1)
		elif arg.begins_with("--bureau-case="):
			# Un poste choisi sur le terrain, sa consigne individuelle ouverte (captures).
			case_choisie = int(arg.get_slice("=", 1))
	foot().change.connect(_rafraichir)
	var m := _mercato_noeud()
	if m != null:
		m.change.connect(_rafraichir)
	aller(page)


static func _mercato_noeud() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Mercato")


## La largeur de la page (hors barre de gauche) : les textes repliés s'y tiennent.
func _largeur_page() -> float:
	return custom_minimum_size.x - (24.0 if _etroit() else 250.0 + 48.0)


## La hauteur laissée au corps de la page, sous le titre.
func _hauteur_page() -> float:
	return custom_minimum_size.y - (46.0 + 20.0 + 48.0 if _etroit() else 44.0 + 70.0)


func _large() -> float:
	return minf(980.0, _largeur_page() - 16.0)


## Change de page.
func aller(p: String) -> void:
	if not PAGES.any(func(x): return x[0] == p):
		p = "accueil"
	page = p
	joueur_ouvert = ""
	_message = ""
	repetition = {}
	_dessiner()


## Redessine ce qui bouge quand Football ou Mercato changent ; la tactique garde ce qu'on y écrit, et les
## pages du mercato se redessinent seules.
func _rafraichir() -> void:
	# Plusieurs signaux d'affilée ne font qu'un dessin, à la fin de l'image.
	if _rafraichir_prevu:
		return
	_rafraichir_prevu = true
	_rafraichir_maintenant.call_deferred()


func _rafraichir_maintenant() -> void:
	_rafraichir_prevu = false
	if not is_inside_tree():
		return
	# Pas sous un clic en cours : la page se redessine une fois le bouton relâché.
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		get_tree().create_timer(0.2).timeout.connect(_rafraichir)
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is OptionButton:
		return
	_barre_nav()
	if page in ["accueil", "effectif", "agenda", "championnat", "adversaire", "entrainement"]:
		_dessiner()


func _dessiner() -> void:
	_barre_nav()
	_vider(_corps)
	_mercato = null
	var nom: String = PAGES.filter(func(x): return x[0] == page)[0][1]
	_titre.text = nom
	_sous_titre.text = _phrase_prochain_match()
	match page:
		"effectif":
			if joueur_ouvert != "":
				_fiche_cru(_defile())
			else:
				_effectif(_defile())
		"tactique":
			_tactique(_corps)
		"adversaire":
			_adversaire(_defile())
		"entrainement":
			_entrainement(_defile())
		"agenda":
			_agenda(_defile())
		"championnat":
			_championnat(_corps)
		"recherche", "offres":
			_mercato_emboite("marche" if page == "recherche" else "offres")
		_:
			_accueil(_defile())


## Le corps d'une page qui défile.
func _defile() -> VBoxContainer:
	var d := ScrollContainer.new()
	d.name = "Defile"
	d.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	d.custom_minimum_size.y = _hauteur_page()
	_corps.add_child(d)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6 if _etroit() else 10)
	d.add_child(v)
	return v


# ---------------------------------------------------------------- la barre de gauche

func _barre_nav() -> void:
	if _boutons_nav.is_empty():
		_poser_barre()
	var f := foot()
	var c: Dictionary = f.clubs.get(club, {})
	if _nom_club != null:
		_ecrire(_nom_club, str(c.get("nom", "Le club")))
	if _rang != null:
		_ecrire(_rang, _phrase_rang())
		_rang.visible = _rang.text != ""
	if _solde != null:
		_ecrire(_solde, "Vous avez %s crédits." % Game.fmt(Game.credits))
	for p in PAGES:
		var b: Button = _boutons_nav[p[0]]
		var texte: String = p[1]
		if p[0] == "accueil":
			var n_lus := non_lus()
			if n_lus > 0:
				texte += "  (%d)" % n_lus
		if p[0] == "offres":
			var m := _mercato_noeud()
			if m != null:
				var o: Dictionary = m.offres_du_club(club)
				var n: int = o.encheres.filter(func(e): return not e.ferme).size() + o.ventes.filter(func(e): return not e.ferme).size()
				if n > 0:
					texte += "  (%d)" % n
		if b.text != texte:
			b.text = texte
		if bool(b.get_meta("ouvert", false)) != (p[0] == page):
			_habiller_onglet(b, p[0] == page)


## La barre se pose une fois : ses boutons restent les mêmes, seuls leurs textes changent. Un bouton
## refait sous le curseur perdrait le clic entre l'appui et le relâché.
func _poser_barre() -> void:
	var f := foot()
	var c: Dictionary = f.clubs.get(club, {})
	var etroit := _etroit()
	var rangee: BoxContainer = HBoxContainer.new() if etroit else VBoxContainer.new()
	rangee.add_theme_constant_override("separation", 6 if etroit else 4)
	if not etroit:
		var ecusson := HBoxContainer.new()
		ecusson.add_theme_constant_override("separation", 10)
		ecusson.add_child(_couleurs(c.get("couleurs", ["#2a8fd1", "#ffffff"])))
		ecusson.add_child(_mot("B U R E A U", 12, DOUX))
		_nav.add_child(ecusson)
		_nom_club = _mot("", 22, CRAIE, Polices.titre(), false)
		_nom_club.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_nom_club.custom_minimum_size.x = 218
		_nav.add_child(_nom_club)
		_rang = _mot("", 14, OR)
		_rang.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_rang.custom_minimum_size.x = 218
		_nav.add_child(_rang)
		var sep := Control.new()
		sep.custom_minimum_size.y = 14
		_nav.add_child(sep)
	_nav.add_child(rangee)
	if etroit:
		rangee.add_child(_couleurs(c.get("couleurs", ["#2a8fd1", "#ffffff"])))
	for p in PAGES:
		var cle: String = p[0]
		var b := _onglet(p[1], cle == page, func(): aller(cle))
		b.name = "Nav_" + cle
		rangee.add_child(b)
		_boutons_nav[cle] = b
	if etroit:
		return
	var ressort := Control.new()
	ressort.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_nav.add_child(ressort)
	_nav.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_solde = _mot("", 14, DOUX)
	_nav.add_child(_solde)


## Ne touche un texte que s'il change : rien ne se remet en page pour rien.
func _ecrire(l: Label, texte: String) -> void:
	if l.text != texte:
		l.text = texte


## Une entrée de la barre : à plat, l'entrée ouverte soulignée d'or à gauche (en bas sur un téléphone).
func _onglet(texte: String, ouvert: bool, action: Callable) -> Button:
	var b := Button.new()
	b.text = texte
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 14 if _etroit() else 17)
	_habiller_onglet(b, ouvert)
	b.pressed.connect(action)
	return b


func _habiller_onglet(b: Button, ouvert: bool) -> void:
	b.set_meta("ouvert", ouvert)
	b.add_theme_font_override("font", Polices.gras() if ouvert else Polices.texte())
	for etat in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := _boite(Color(OR, 0.16) if ouvert else (Color(1, 1, 1, 0.06) if etat == "hover" else Color.TRANSPARENT), Color.TRANSPARENT, 4, 8)
		s.content_margin_left = 14
		s.content_margin_right = 14
		if ouvert:
			s.border_color = OR
			if _etroit():
				s.border_width_bottom = 3
			else:
				s.border_width_left = 4
		b.add_theme_stylebox_override(etat, s)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, OR if ouvert else CRAIE)


## « 2e de la Division 1, 12 points » d'après le classement du moment.
func _phrase_rang() -> String:
	var f := foot()
	var place: Array = f.place_de(club)
	if place.is_empty():
		return "Inscrit pour la saison qui vient."
	var cl: Array = f.classement(f.saison, place[0], place[1])
	for i in cl.size():
		if cl[i].club == club:
			return "%s de la %s, %d point%s" % [FootLocaux._rang(i + 1), f.nom_division(place[0], place[1]), int(cl[i].pts), "s" if int(cl[i].pts) > 1 else ""]
	return str(f.nom_division(place[0], place[1]))


func _phrase_prochain_match() -> String:
	var f := foot()
	var r: Dictionary = f.prochain_match(club)
	if r.is_empty():
		return "Pas de match avant la saison qui vient."
	var adv: String = r.ext if r.dom == club else r.dom
	var phrase := "Prochain match : %s à %d h, %s %s" % [date(r.quand), f.HEURE_COUP_ENVOI, "contre" if r.dom == club else "chez", str(f.clubs.get(adv, {}).get("nom", adv))]
	# Ce qui presse, en bout de ligne (demande de Guillaume du 31 octobre 2026) : le compte à rebours, et pour
	# le dirigeant si la composition est posée ; pour les autres, que le bureau se lit seulement.
	phrase += "  ·  dans %s" % AUJOURDHUI.dans(int(r.quand), int(f.maintenant())).trim_prefix("dans ")
	if not f.peut_decider(club):
		phrase += "  ·  lecture seule"
	elif FootDilemmes.tactique_posee(f, club, int(r.s), int(r.j)):
		phrase += "  ·  composition posée ✓"
	else:
		phrase += "  ·  composition à poser"
	return phrase


# ---------------------------------------------------------------- l'accueil

func _accueil(col: VBoxContainer) -> void:
	var etroit := _etroit()
	var largeur := _largeur_page() - 24.0
	var rangee: Container = VBoxContainer.new() if etroit else HBoxContainer.new()
	rangee.add_theme_constant_override("separation", 16)
	col.add_child(rangee)
	var l_courrier := largeur if etroit else floorf(largeur * 0.56)
	var l_cartes := largeur if etroit else largeur - l_courrier - 16.0
	var gauche := VBoxContainer.new()
	gauche.add_theme_constant_override("separation", 16)
	gauche.custom_minimum_size.x = l_courrier
	rangee.add_child(gauche)
	var faire := a_faire()
	if not faire.is_empty():
		_carte_a_faire(_carte(gauche, "À faire avant le coup d'envoi", l_courrier), faire, l_courrier - 30.0)
	_courrier(_carte(gauche, "Le courrier du club", l_courrier), l_courrier - 30.0)
	var droite := VBoxContainer.new()
	droite.add_theme_constant_override("separation", 16)
	droite.custom_minimum_size.x = l_cartes
	rangee.add_child(droite)
	var w := l_cartes - 30.0
	_carte_match(_carte(droite, "Le prochain match"), w)
	_carte_direction(_carte(droite, "La direction"), w)
	var f := foot()
	var place: Array = f.place_de(club)
	if not place.is_empty():
		var carte4 := _carte(droite, "Le classement")
		var grille := _classement(f.saison, place[0], place[1])
		grille.add_theme_constant_override("v_separation", 2)
		carte4.add_child(grille)
		var b4 := _bouton("Le championnat", func(): aller("championnat"), 14)
		b4.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		carte4.add_child(b4)
	_carte_marche(_carte(droite, "Le marché"), w)


## Ce que le dirigeant a à faire avant le prochain coup d'envoi, fait ou pas : [{cle, titre, fait, page,
## bouton}] ; [] pour qui ne dirige pas, ou entre deux saisons. La composition, le programme de la semaine,
## et la décision de la semaine quand elle attend (elle se tranche dans les messages du carnet).
func a_faire() -> Array:
	var f := foot()
	var r: Dictionary = f.prochain_match(club)
	if r.is_empty() or not f.peut_decider(club):
		return []
	var c: Dictionary = f.consigne_de(r.s, r.j, club)
	var out: Array = [
		{"cle": "composition", "titre": "Poser la composition (formation, onze, consignes)", "fait": FootDilemmes.tactique_posee(f, club, int(r.s), int(r.j)),
			"page": "tactique", "bouton": "La tactique"},
		{"cle": "entrainement", "titre": "Choisir le programme d'entraînement de la semaine", "fait": (c.consigne as Dictionary).has("entrainement"),
			"page": "entrainement", "bouton": "L'entraînement"},
	]
	var avis: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Avis")
	if avis != null:
		for a in avis.liste:
			if str(a.get("genre", "")) != "dilemme" or str((a.get("dilemme", {}) as Dictionary).get("club", "")) != club:
				continue
			var ch: Array = avis.choix_de(a)
			if ch.is_empty() or not ch[0].ouvert:
				continue
			out.append({"cle": "dilemme", "titre": "Trancher la décision de la semaine : %s" % str(a.titre), "fait": ch.any(func(x): return x.fait),
				"page": "", "bouton": ""})
	return out


func _carte_a_faire(c: VBoxContainer, faire: Array, w: float) -> void:
	c.get_parent().name = "AFaire"
	for x in faire:
		var ligne := HBoxContainer.new()
		ligne.add_theme_constant_override("separation", 10)
		ligne.name = "AFaire_" + str(x.cle)
		c.add_child(ligne)
		var m := _mot(("✓  " if x.fait else "○  ") + str(x.titre), 15, DOUX if x.fait else CRAIE, null if x.fait else Polices.gras(), true)
		m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		m.custom_minimum_size.x = maxf(120.0, w - 170.0)
		ligne.add_child(m)
		if str(x.page) != "" and not bool(x.fait):
			var cible := str(x.page)
			ligne.add_child(_bouton(str(x.bouton), func(): aller(cible), 14))
	if faire.all(func(x): return bool(x.fait)):
		_texte(c, "Tout est prêt pour dimanche.", w, 14, VERT)
	elif faire.any(func(x): return x.cle == "dilemme" and not x.fait):
		_texte(c, "La décision de la semaine se tranche dans les messages du carnet.", w, 13, DOUX)


## Un texte replié à la largeur donnée.
func _texte(parent: Container, t: String, largeur: float, taille := 15, couleur := CRAIE, police: Font = null) -> Label:
	var l := _mot(t, taille, couleur, police, true)
	l.custom_minimum_size.x = maxf(120.0, largeur)
	parent.add_child(l)
	return l


func _carte_match(c: VBoxContainer, w: float) -> void:
	var f := foot()
	var r: Dictionary = f.prochain_match(club)
	if r.is_empty():
		_texte(c, "La saison qui vient n'est pas encore tirée.", w, 16)
		return
	var adv: String = r.ext if r.dom == club else r.dom
	_texte(c, "%s – %s" % [f.clubs[r.dom].nom, f.clubs[r.ext].nom], w, 19, CRAIE, Polices.gras())
	_texte(c, "Journée %d, %s à %d h, %s." % [r.j, date(r.quand), f.HEURE_COUP_ENVOI, "à domicile" if r.dom == club else "chez %s" % f.clubs[adv].nom], w, 15, DOUX)
	var d: Dictionary = f.consigne_de(r.s, r.j, club)
	var prog := FootEntrainement.programme(d.consigne.get("entrainement", ""))
	_texte(c, "Consigne : %s, %s, pressing %s. Entraînement : %s." % [d.consigne.formation, FootMatch.MENTALITES[d.consigne.mentalite].nom.to_lower(),
		FootMatch.PRESSINGS[d.consigne.pressing].nom.to_lower(), str(FootEntrainement.PROGRAMMES[prog].nom).to_lower()], w, 15)
	var ligne := HFlowContainer.new()
	ligne.add_theme_constant_override("h_separation", 10)
	ligne.add_theme_constant_override("v_separation", 6)
	ligne.add_child(_bouton("Préparer la tactique", func(): aller("tactique"), 14))
	ligne.add_child(_bouton("L'adversaire", func(): aller("adversaire"), 14))
	c.add_child(ligne)


func _carte_direction(c: VBoxContainer, w: float) -> void:
	var f := foot()
	var obj := FootCourrier.objectif(f, club)
	if not obj.is_empty():
		_texte(c, "Objectif : %s" % str(obj.titre).to_lower(), w, 17, CRAIE, Polices.gras())
		_texte(c, str(obj.phrase), w, 14, DOUX)
	var conf := FootCourrier.confiance(f, club)
	if not conf.is_empty():
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.add_child(_mot("Confiance", 14, DOUX))
		var v := float(conf.valeur)
		var jauge := ColorRect.new()
		jauge.name = "Confiance"
		jauge.color = Color(1, 1, 1, 0.1)
		jauge.custom_minimum_size = Vector2(minf(220.0, w - 200.0), 10)
		jauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var plein := ColorRect.new()
		plein.color = VERT if v >= 60.0 else (OR if v >= 40.0 else ROUGE)
		plein.size = Vector2(jauge.custom_minimum_size.x * v / 100.0, 10)
		jauge.add_child(plein)
		h.add_child(jauge)
		h.add_child(_mot(str(conf.phrase), 14, plein.color))
		c.add_child(h)
	_texte(c, str(f.phrase_actionnaires(club)), w, 14, OR)
	if f.investi(club) > 0:
		_texte(c, "Dividendes touchés depuis le début : %s crédits." % Game.fmt(int(f.dividendes_total)), w, 14)
	var b2 := _bouton("Le registre des obligations", func(): obligations.emit(), 14)
	b2.name = "Obligations"
	b2.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	c.add_child(b2)


func _carte_marche(c: VBoxContainer, w: float) -> void:
	var m := _mercato_noeud()
	if m == null:
		_texte(c, "Le marché n'est pas ouvert ici.", w, 15, DOUX)
		return
	for n in m.nouvelles.slice(0, 2):
		_texte(c, str(n), w, 14, OR)
	var o: Dictionary = m.offres_du_club(club)
	var tete: int = o.encheres.filter(func(e): return not e.ferme and e.meneur == club).size()
	var depasse: int = o.encheres.filter(func(e): return not e.ferme and e.meneur != club).size()
	_texte(c, "%d enchère%s en tête, %d dépassée%s, %d vente%s ouverte%s. Quarante nouveaux joueurs chaque dimanche à 17 h." % [tete, "s" if tete > 1 else "", depasse, "s" if depasse > 1 else "",
		o.ventes.size(), "s" if o.ventes.size() > 1 else "", "s" if o.ventes.size() > 1 else ""], w, 14)
	var ligne := HFlowContainer.new()
	ligne.add_theme_constant_override("h_separation", 10)
	ligne.add_theme_constant_override("v_separation", 6)
	ligne.add_child(_bouton("Chercher un joueur", func(): aller("recherche"), 14))
	ligne.add_child(_bouton("Nos offres en cours", func(): aller("offres"), 14))
	c.add_child(ligne)


# ---------------------------------------------------------------- le courrier

## Les messages du club (FootCourrier.messages), le plus récent d'abord.
func courrier() -> Array:
	return FootCourrier.messages(foot(), club)


static func _chemin_lus() -> String:
	var d := str(foot().dossier)
	return "" if d == "" else d.path_join(FICHIER_COURRIER)


static func lus() -> Dictionary:
	var chemin := _chemin_lus()
	if chemin == "" or not FileAccess.file_exists(chemin):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(chemin))
	return v if v is Dictionary else {}


static func marquer_lu(id: String) -> void:
	var l := lus()
	if l.has(id):
		return
	l[id] = true
	var chemin := _chemin_lus()
	if chemin == "":
		return
	var fichier := FileAccess.open(chemin, FileAccess.WRITE)
	if fichier != null:
		fichier.store_string(JSON.stringify(l))


## Combien de messages du courrier n'ont pas été ouverts.
func non_lus() -> int:
	var l := lus()
	return courrier().filter(func(m): return not l.has(str(m.id))).size()


func _courrier(c: VBoxContainer, w: float) -> void:
	var liste := courrier()
	if liste.is_empty():
		_texte(c, "Rien encore : le courrier arrive avec le calendrier.", w, 15, DOUX)
		return
	var l := lus()
	var v := VBoxContainer.new()
	v.name = "Courrier"
	v.add_theme_constant_override("separation", 2)
	c.add_child(v)
	for m in liste.slice(0, 24):
		var id := str(m.id)
		var ouvert := id == message_ouvert
		var neuf := not l.has(id)
		var b := Button.new()
		b.name = "Message_" + id.replace("/", "_")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		b.custom_minimum_size.x = w
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		b.text = "%s   %s   %s" % ["●" if neuf else "  ", _date_courte(int(m.quand)), m.titre]
		b.add_theme_font_override("font", Polices.gras() if neuf or ouvert else Polices.texte())
		b.add_theme_font_size_override("font_size", 14 if _etroit() else 15)
		for etat in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(etat, _boite(Color(OR, 0.14) if ouvert else (Color(1, 1, 1, 0.06) if etat == "hover" else Color(1, 1, 1, 0.02)), Color.TRANSPARENT, 3, 6))
		b.add_theme_color_override("font_color", OR if neuf or ouvert else CRAIE)
		b.add_theme_color_override("font_hover_color", OR)
		b.pressed.connect(func(): _ouvrir_message(id))
		v.add_child(b)
		if ouvert:
			var corps := VBoxContainer.new()
			corps.add_theme_constant_override("separation", 8)
			var marge := MarginContainer.new()
			marge.add_theme_constant_override("margin_left", 22)
			marge.add_theme_constant_override("margin_bottom", 8)
			marge.add_child(corps)
			v.add_child(marge)
			_texte(corps, str(m.texte), w - 30.0, 15)
			if str(m.get("page", "")) != "":
				var cible := str(m.page)
				var aller_b := _bouton(str(m.get("bouton", "Y aller")), func(): aller(cible), 14)
				aller_b.name = "Suite"
				aller_b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
				corps.add_child(aller_b)


func _ouvrir_message(id: String) -> void:
	message_ouvert = "" if message_ouvert == id else id
	marquer_lu(id)
	_dessiner()


## « dim. 15 nov. »
static func _date_courte(t: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(t)
	var mois := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]
	return "%s. %d %s" % [str(JOURS[int(d.weekday)]).left(3), int(d.day), mois[int(d.month) - 1]]



## Une carte de l'accueil : un fond un peu plus clair, un titre.
func _carte(parent: Container, titre: String, largeur := 0.0) -> VBoxContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if largeur > 0.0:
		p.custom_minimum_size.x = largeur
	p.add_theme_stylebox_override("panel", _boite(Color(1, 1, 1, 0.04), Color(1, 1, 1, 0.08), 6, 14))
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	v.add_child(_mot(titre.to_upper(), 12, DOUX))
	return v


# ---------------------------------------------------------------- l'effectif

## La journée dont on montre l'effectif : la prochaine (les joueurs achetés au marché y sont).
func _journee() -> Array:
	var f := foot()
	var r: Dictionary = f.prochain_match(club)
	if not r.is_empty():
		return [int(r.s), int(r.j)]
	return [int(f.saison), clampi(int(f.journee_jouee()) + 1, 1, int(f.JOURNEES))]


func _joueurs() -> Dictionary:
	var sj := _journee()
	return foot().effectif(club, sj[0], sj[1])


## Les statistiques de la division du club cette saison (Football.statistiques) : {buteurs, passeurs,
## clean_sheets}, ou {} tant que Football ne les donne pas.
func _statistiques() -> Dictionary:
	var f := foot()
	if not f.has_method("statistiques"):
		return {}
	var place: Array = f.place_de(club)
	if place.is_empty():
		place = division_suivie()
	var s: Variant = f.call("statistiques", f.saison, place[0], place[1])
	return s if s is Dictionary else {}


## Les buts et les passes de la saison d'un joueur, lus dans les statistiques de la division : {buts, passes}.
func _stats(id: String, st := {}) -> Dictionary:
	if st.is_empty():
		st = _statistiques()
	var out := {}
	for e in st.get("buteurs", []):
		if str(e.get("id", "")) == id:
			out.buts = int(e.get("buts", e.get("n", 0)))
	for e in st.get("passeurs", []):
		if str(e.get("id", "")) == id:
			out.passes = int(e.get("passes", e.get("n", 0)))
	return out


## L'id au marché d'un joueur acheté (« club/m-s3-12 » → « s3-12 »), ou "".
func _id_marche(id: String) -> String:
	var i := id.find("/m-")
	return id.substr(i + 3) if i >= 0 else ""


func _effectif(col: VBoxContainer) -> void:
	var joueurs := _joueurs()
	# Le début de la saison : ce que l'entraînement a fait depuis.
	var debut: Dictionary = foot().effectif(club, _journee()[0], 1)
	var avec_stats := foot().has_method("statistiques")
	var st := _statistiques()
	var etroit := _etroit()
	var ids: Array = joueurs.keys()
	var ordre_poste := {"G": 0, "D": 1, "M": 2, "A": 3}
	var stats := {}
	for id in ids:
		stats[id] = _stats(str(id), st) if avec_stats else {}
	var cle := tri_effectif
	ids.sort_custom(func(a, b):
		var ja: Dictionary = joueurs[a]
		var jb: Dictionary = joueurs[b]
		match cle:
			"nom":
				return str(ja.nom) < str(jb.nom)
			"age":
				return int(ja.age) < int(jb.age)
			"note":
				return int(ja.note) > int(jb.note)
			"buts", "passes":
				return int(stats[a].get(cle, 0)) > int(stats[b].get(cle, 0))
			"valeur":
				return MERCATO.valeur_de(int(ja.note), int(ja.age)) > MERCATO.valeur_de(int(jb.note), int(jb.age))
		if ja.poste != jb.poste:
			return ordre_poste[ja.poste] < ordre_poste[jb.poste]
		return int(ja.note) > int(jb.note))
	var achetes := ids.filter(func(id): return _id_marche(str(id)) != "").size()
	col.add_child(_mot("%d joueurs, dont %d acheté%s au marché. Un clic sur un nom ouvre sa fiche ; un clic sur l'en-tête trie." % [ids.size(), achetes, "s" if achetes > 1 else ""], 14, DOUX, null, true))
	var colonnes: Array = ["poste", "nom", "age", "note", "c1", "c2"]
	if not etroit:
		colonnes += ["buts", "passes", "valeur"]
	var grille := GridContainer.new()
	grille.name = "Effectif"
	grille.columns = colonnes.size()
	grille.add_theme_constant_override("h_separation", 12 if etroit else 22)
	grille.add_theme_constant_override("v_separation", 3)
	col.add_child(grille)
	for k in colonnes:
		if TRIS_EFFECTIF.has(k):
			var b := Button.new()
			b.text = TRIS_EFFECTIF[k] + ("  ▾" if k == tri_effectif else "")
			b.flat = true
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.add_theme_font_size_override("font_size", 13)
			b.add_theme_color_override("font_color", OR if k == tri_effectif else DOUX)
			b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
			b.pressed.connect(func():
				tri_effectif = k
				_dessiner())
			grille.add_child(b)
		else:
			grille.add_child(_mot("Compétences" if k == "c1" else "", 13, DOUX))
	for id in ids:
		var j: Dictionary = joueurs[id]
		var marche := _id_marche(str(id))
		for k in colonnes:
			match k:
				"poste":
					grille.add_child(_mot(str(j.poste), 15, OR if marche != "" else CRAIE, Polices.gras()))
				"nom":
					var b := Button.new()
					b.name = "Joueur_" + str(id).replace("/", "_")
					b.text = "%s %s" % [j.prenom, j.nom]
					b.flat = true
					b.alignment = HORIZONTAL_ALIGNMENT_LEFT
					b.custom_minimum_size.x = 170 if etroit else 220
					b.add_theme_font_override("font", Polices.gras())
					b.add_theme_font_size_override("font_size", 15)
					b.add_theme_color_override("font_color", CRAIE)
					b.add_theme_color_override("font_hover_color", OR)
					b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
					b.pressed.connect(func(): _ouvrir_joueur(str(id)))
					grille.add_child(b)
				"age":
					grille.add_child(_mot("%d ans" % int(j.age), 15, DOUX))
				"note":
					var gagne := int(j.note) - int(debut.get(id, j).note)
					grille.add_child(_mot(str(int(j.note)) + ("  ▲%d" % gagne if gagne > 0 else ""), 15, VERT if gagne > 0 else CRAIE, Polices.gras()))
				"c1", "c2":
					var principales: Array = MERCATO.PRINCIPALES.get(str(j.poste), ["jeu", "passe"])
					var c: String = principales[0 if k == "c1" else 1]
					grille.add_child(_mini_comp(c, FootMatch.competence(j, c)))
				"buts", "passes":
					grille.add_child(_mot(str(int(stats[id].get(k, 0))) if avec_stats else "–", 15, CRAIE))
				"valeur":
					grille.add_child(_mot("%s cr." % Game.fmt(MERCATO.valeur_de(int(j.note), int(j.age))), 14, DOUX))
	var legende := _mot("Compétences, les deux qui comptent le plus à son poste : Gar gardien, Déf défense, Cons construction du jeu, Ail aile, Pas passe, But finition, CPA coups de pied arrêtés. Le chiffre (de 0 à 20) et sa couleur, du rouge au vert, disent s’il est faible ou fort. Un poste en or : un joueur acheté au marché.", 13, DOUX, null, true)
	legende.name = "Legende"
	col.add_child(legende)
	if not avec_stats:
		col.add_child(_mot("Les buts et les passes de la saison arrivent avec les statistiques du championnat.", 13, DOUX, null, true))
	var m := _mercato_noeud()
	if m != null and achetes > 0:
		col.add_child(_mot("Masse salariale des joueurs achetés : %s crédits la semaine." % Game.fmt(int(m.salaires(club))), 14, DOUX))


## Une compétence en petit : son nom court, une barre de la couleur de son cran.
func _mini_comp(cle: String, v: float) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var court := {"endurance": "End", "gardien": "Gar", "defense": "Déf", "jeu": "Cons", "aile": "Ail", "passe": "Pas", "but": "But", "cpa": "CPA"}
	var n := _mot(str(court.get(cle, cle)), 12, DOUX)
	n.custom_minimum_size.x = 34
	h.add_child(n)
	h.add_child(_barre(v, 64))
	var cran := MERCATO.niveau(v)
	h.add_child(_mot(str(cran), 12, FootMercato.couleur_cran(cran)))
	h.tooltip_text = "%s : %s (%d)" % [FootMatch.COMPETENCES.get(cle, cle), MERCATO.mot_niveau(v), cran]
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	return h


func _barre(v: float, largeur := 120) -> Control:
	var fond := ColorRect.new()
	fond.color = Color(1, 1, 1, 0.1)
	fond.custom_minimum_size = Vector2(largeur, 8)
	fond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var plein := ColorRect.new()
	plein.color = FootMercato.couleur_cran(MERCATO.niveau(v))
	plein.size = Vector2(largeur * clampf(v / 100.0, 0.0, 1.0), 8)
	fond.add_child(plein)
	return fond


## Un joueur acheté au marché s'ouvre dans la fiche du mercato (on peut l'y remettre en vente) ; un joueur du
## cru, dans la fiche du bureau.
func _ouvrir_joueur(id: String) -> void:
	var marche := _id_marche(id)
	if marche != "":
		page = "recherche"
		_dessiner()
		if _mercato != null:
			_mercato._retour = "marche"
			_mercato.ouvrir("", marche)
		return
	joueur_ouvert = id
	_dessiner()


func _fiche_cru(col: VBoxContainer) -> void:
	var joueurs := _joueurs()
	var j: Dictionary = joueurs.get(joueur_ouvert, {})
	if j.is_empty():
		joueur_ouvert = ""
		_effectif(col)
		return
	col.add_child(_mot("%s %s" % [j.prenom, j.nom], 26, CRAIE, Polices.gras()))
	col.add_child(_mot("%s  ·  %d ans  ·  note %d  ·  joueur du cru : il ne se vend pas" % [FootMatch.POSTES.get(j.poste, j.poste), int(j.age), int(j.note)], 16, DOUX, null, true))
	var grille := GridContainer.new()
	grille.name = "Competences"
	grille.columns = 3
	grille.add_theme_constant_override("h_separation", 14)
	grille.add_theme_constant_override("v_separation", 4)
	col.add_child(grille)
	var d0: Dictionary = foot().effectif(club, _journee()[0], 1).get(joueur_ouvert, j)
	for cle in ["endurance", "gardien", "defense", "jeu", "aile", "passe", "but", "cpa"]:
		var v := FootMatch.competence(j, cle)
		grille.add_child(_mot(FootMercato.NOMS_COMP[cle], 15, DOUX))
		grille.add_child(_barre(v, 160))
		var gagne := MERCATO.niveau(v) - MERCATO.niveau(FootMatch.competence(d0, cle))
		grille.add_child(_mot("%s (%d)  ·  %d %% vers le suivant%s" % [MERCATO.mot_niveau(v), MERCATO.niveau(v), roundi(100.0 * FootEntrainement.vers_cran(v)), "  ▲%d cette saison" % gagne if gagne > 0 else ""],
			15, FootMercato.couleur_cran(MERCATO.niveau(v))))
	var s := _stats(joueur_ouvert)
	if not s.is_empty():
		col.add_child(_mot("Cette saison : %d match%s, %d but%s, %d passe%s décisive%s." % [int(s.get("matchs", 0)), "s" if int(s.get("matchs", 0)) > 1 else "",
			int(s.get("buts", 0)), "s" if int(s.get("buts", 0)) > 1 else "", int(s.get("passes", 0)), "s" if int(s.get("passes", 0)) > 1 else "", "s" if int(s.get("passes", 0)) > 1 else ""], 15, CRAIE, null, true))
	col.add_child(_mot("Valeur estimée : %s crédits." % Game.fmt(MERCATO.valeur_de(int(j.note), int(j.age))), 15, DOUX))
	var b := _bouton("Retour à l'effectif", func():
		joueur_ouvert = ""
		_dessiner(), 14)
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	col.add_child(b)


# ---------------------------------------------------------------- la tactique

## Les consignes individuelles que le moteur de match connaît (Football.ROLES, {clé: nom}), en {clé: {nom}},
## la consigne par défaut d'abord ; {} tant que le moteur n'en a pas.
static func ordres() -> Dictionary:
	var roles: Variant = foot().get("ROLES")
	if not roles is Dictionary:
		return {}
	var defaut := str(foot().get("ROLE_DEFAUT")) if foot().get("ROLE_DEFAUT") != null else "normal"
	var out := {}
	if (roles as Dictionary).has(defaut):
		out[defaut] = {"nom": str(roles[defaut])}
	for k in roles:
		out[k] = {"nom": str(roles[k])}
	return out


## La composition en place pour le prochain match, complétée par l'équipe type là où rien n'est posé.
func _charger_compo() -> void:
	var f := foot()
	var r: Dictionary = f.prochain_match(club)
	var d: Dictionary = {}
	if not r.is_empty():
		d = (f.consigne_de(r.s, r.j, club).consigne as Dictionary).duplicate(true)
	else:
		d = f.consigne({})
	compo = {"formation": str(d.get("formation", "4-4-2")), "mentalite": str(d.get("mentalite", "equilibree")),
		"pressing": str(d.get("pressing", "normal")), "onze": [], "banc": [], "ordres": {}}
	var joueurs := _joueurs()
	# La compo posée (Football : « compo », 11 ids, "" pour une case laissée à l'adjoint), que l'équipe type complète.
	var posee: Array = d.get("compo", [])
	var choisie := case_choisie
	_equipe_type()
	case_choisie = choisie
	if posee.size() == compo.onze.size():
		for i in posee.size():
			var id := str(posee[i])
			if id != "" and joueurs.has(id):
				placer(id, i)
		var banc: Array = (d.get("banc", []) as Array).filter(func(id): return joueurs.has(id) and not compo.onze.has(id))
		if not banc.is_empty():
			compo.banc = banc
		compo.ordres = (d.get("roles", {}) as Dictionary).duplicate()
	modifie = false


## L'équipe type de l'adjoint : le meilleur onze de la formation, et les sept meilleurs restants sur le banc.
func _equipe_type() -> void:
	var f := foot()
	if f.has_method("compo_auto") and f.has_method("banc_auto"):
		var sj := _journee()
		compo.onze = (f.call("compo_auto", club, sj[0], sj[1], compo.formation) as Array).map(func(x): return null if str(x) == "" else x)
		compo.banc = f.call("banc_auto", club, sj[0], sj[1], compo.onze)
	else:
		var joueurs := _joueurs()
		var ids: Array = joueurs.keys()
		compo.onze = FootMatch.compo_auto(ids, joueurs, compo.formation)
		compo.banc = FootMatch.banc_auto(ids, joueurs, compo.onze)
	compo.ordres = {}
	case_choisie = -1
	joueur_choisi = ""


func _tactique(col: VBoxContainer) -> void:
	var f := foot()
	var r: Dictionary = f.prochain_match(club)
	if compo.is_empty():
		_charger_compo()
	var decide: bool = f.peut_decider(club) and not r.is_empty()
	# Qui ne dirige pas lit la tactique posée sans pouvoir la changer (demande de Guillaume du 31 octobre
	# 2026) : les listes et le terrain ne bougent plus, et un bandeau dit qui la règle.
	_lecture = not decide
	var etroit := _etroit()
	if _lecture and not r.is_empty():
		var dg: Dictionary = DIRIGER.dirigeant(f, club)
		var pose: Dictionary = f.consigne_de(r.s, r.j, club)
		var de := "l'équipe type de l'adjoint" if str(pose.etat) == "aucune" else ("la tactique posée par %s" % str(pose.par) if str(pose.par) != "" else "la tactique posée")
		var qui := str(dg.get("nom", "")) if not dg.is_empty() else ""
		var bandeau := _mot("Lecture seule : voici %s pour dimanche. %s Pour diriger, il faut avoir mis le plus dans le club, chez le notaire (la règle : carnet, Mes clubs, « Comment ça marche »)." % [
			de, ("%s dirige le club : lui seul la change." % qui) if qui != "" else "Seul celui qui dirige le club la change."], 14, DOUX, null, true)
		bandeau.name = "Lecture"
		col.add_child(bandeau)
	# En haut : la formation, la mentalité, le pressing, et les deux boutons.
	var haut := HFlowContainer.new()
	haut.add_theme_constant_override("h_separation", 10)
	haut.add_theme_constant_override("v_separation", 6)
	col.add_child(haut)
	var formations: Array = FootMatch.FORMATIONS.keys()
	haut.add_child(_liste("Formation", formations.map(func(k): return str(k)), formations.find(compo.formation), func(i):
		compo.formation = formations[i]
		_equipe_type()
		modifie = true
		_dessiner()))
	var mentalites: Array = FootMatch.MENTALITES.keys()
	haut.add_child(_liste("Mentalite", mentalites.map(func(k): return "Mentalité : " + str(FootMatch.MENTALITES[k].nom).to_lower()), mentalites.find(compo.mentalite), func(i):
		compo.mentalite = mentalites[i]
		modifie = true
		_dessiner()))
	var pressings: Array = FootMatch.PRESSINGS.keys()
	haut.add_child(_liste("Pressing", pressings.map(func(k): return "Pressing " + str(FootMatch.PRESSINGS[k].nom).to_lower()), pressings.find(compo.pressing), func(i):
		compo.pressing = pressings[i]
		modifie = true
		_dessiner()))
	var b1 := _bouton("Équipe type", func():
		_equipe_type()
		modifie = true
		_dessiner(), 14)
	b1.name = "EquipeType"
	b1.disabled = _lecture
	haut.add_child(b1)
	var b2 := _bouton("Valider la composition", func(): valider(), 14)
	b2.name = "Valider"
	b2.disabled = not decide
	haut.add_child(b2)
	if modifie and decide:
		var m := _mot("Modifiée, pas encore validée", 14, ROUGE, Polices.gras())
		m.name = "NonValidee"
		m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		haut.add_child(m)
	var b3 := _bouton("Répétition", func(): repeter(), 14)
	b3.name = "Repeter"
	b3.tooltip_text = "Vingt matchs d'opposition contre l'adversaire de dimanche, avec cette tactique."
	b3.disabled = r.is_empty()
	haut.add_child(b3)
	# Au milieu : le terrain à gauche, l'effectif à droite.
	var milieu := HBoxContainer.new()
	milieu.add_theme_constant_override("separation", 14 if etroit else 24)
	milieu.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(milieu)
	var h_dispo := _hauteur_page() - (110.0 if etroit else 130.0)
	var gauche := VBoxContainer.new()
	gauche.add_theme_constant_override("separation", 6)
	milieu.add_child(gauche)
	var terrain_h := maxf(260.0, h_dispo - (58.0 if etroit else 70.0))
	var terrain_l := minf(terrain_h * 0.74, _largeur_page() * 0.5)
	terrain_h = terrain_l / 0.74
	if etroit:
		# Sur un téléphone, le terrain s'élargit (un peu écrasé) pour que les postes ne se chevauchent pas.
		terrain_h = maxf(240.0, h_dispo - 96.0)
		terrain_l = _largeur_page() * 0.44
	_largeur_liste = _largeur_page() - terrain_l - (14.0 if etroit else 24.0) - 8.0
	var terrain := _terrain(Vector2(terrain_l, terrain_h))
	gauche.add_child(terrain)
	gauche.add_child(_banc())
	var droite := VBoxContainer.new()
	droite.custom_minimum_size.x = _largeur_liste
	droite.add_theme_constant_override("separation", 6)
	milieu.add_child(droite)
	_panneau_case(droite)
	var d := ScrollContainer.new()
	d.name = "Joueurs"
	d.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	d.custom_minimum_size.y = maxf(120.0, h_dispo - (120.0 if case_choisie >= 0 else 40.0))
	droite.add_child(d)
	var liste := VBoxContainer.new()
	liste.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	liste.add_theme_constant_override("separation", 2)
	d.add_child(liste)
	_liste_joueurs(liste)
	# En bas : d'où vient la consigne, ou ce qui manque pour décider.
	var etat := ""
	if r.is_empty():
		etat = "La saison qui vient n'est pas encore tirée : la composition attend le calendrier."
	elif not f.peut_decider(club):
		etat = ""
	elif _message != "":
		etat = _message
	else:
		etat = _etat_consigne(f.consigne_de(r.s, r.j, club))
	if ordres().is_empty():
		etat += "  Les consignes individuelles arrivent avec le prochain moteur de match."
	if not repetition.is_empty():
		etat = "Répétition, %d matchs : %d V, %d N, %d D (%.1f – %.1f par match).  %s" % [int(repetition.essais), int(repetition.victoires), int(repetition.nuls), int(repetition.defaites),
			float(repetition.pour) / maxf(float(repetition.essais), 1.0), float(repetition.contre) / maxf(float(repetition.essais), 1.0), etat]
	var l := _mot(etat, 14, DOUX, null, true)
	l.name = "Etat"
	col.add_child(l)


func _liste(nom: String, libelles: Array, choisi: int, action: Callable) -> OptionButton:
	var o := OptionButton.new()
	o.name = nom
	o.add_theme_font_size_override("font_size", 14)
	o.add_theme_font_override("font", Polices.texte())
	for x in libelles:
		o.add_item(str(x))
	o.select(clampi(choisi, 0, libelles.size() - 1))
	o.item_selected.connect(func(i): action.call(i))
	o.disabled = _lecture
	return o


## Le terrain vu de dessus, notre but en bas : un bouton par poste de la formation, à sa place.
func _terrain(taille: Vector2) -> Control:
	var t := Terrain.new()
	t.name = "Terrain"
	t.custom_minimum_size = taille
	var joueurs := _joueurs()
	var cases: Array = FootMatch.FORMATIONS[compo.formation]
	var bw := clampf(taille.x * 0.2, 66.0, 112.0)
	var bh := 34.0 if _etroit() else 44.0
	for i in cases.size():
		var c: Array = cases[i]
		var id = compo.onze[i] if i < compo.onze.size() else null
		var b := _pion(i, c, id, joueurs)
		b.size = Vector2(bw, bh)
		b.position = Vector2(float(c[2]) / 100.0 * taille.x - bw / 2.0, float(c[3]) / 100.0 * taille.y - bh / 2.0)
		b.position = b.position.clamp(Vector2.ZERO, taille - b.size)
		t.add_child(b)
	return t


## Un poste sur le terrain : son nom (DC, MG…), le joueur qui l'occupe et sa note à ce poste.
func _pion(i: int, c: Array, id, joueurs: Dictionary) -> Button:
	var b := Button.new()
	b.name = "Case_%d" % i
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var choisi := case_choisie == i
	var j: Dictionary = joueurs.get(id, {}) if id != null else {}
	var hors_poste: bool = not j.is_empty() and str(j.poste) != str(c[0])
	for etat in ["normal", "hover", "pressed", "focus"]:
		var s := _boite(Color(0.06, 0.1, 0.08, 0.86) if not choisi else Color(OR, 0.9), OR if choisi or etat == "hover" else Color(1, 1, 1, 0.35), 6, 2, 2 if choisi else 1)
		b.add_theme_stylebox_override(etat, s)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var encre := ARDOISE if choisi else CRAIE
	var haut := _mot("%s%s" % [c[1], "  %d" % int(roundf(FootMatch.note_effective(j, str(c[0]), 100.0))) if not j.is_empty() else ""], 10 if _etroit() else 12, ARDOISE if choisi else (Color(0.95, 0.6, 0.4) if hors_poste else OR), Polices.gras())
	haut.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(haut)
	var nom := _mot(FootMatch.nom_court(j) if not j.is_empty() else "libre", 11 if _etroit() else 13, encre)
	nom.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nom.clip_text = true
	nom.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	v.add_child(nom)
	var o := str(compo.ordres.get(id, "")) if id != null else ""
	if o != "" and ordres().has(o):
		b.tooltip_text = "Consigne : %s" % ordres()[o].nom
		nom.text += "  •"
	b.pressed.connect(func(): _cliquer_case(i))
	return b


## Le banc : sept places sous le terrain.
func _banc() -> Control:
	var h := HFlowContainer.new()
	h.name = "Banc"
	h.add_theme_constant_override("h_separation", 4)
	h.add_theme_constant_override("v_separation", 4)
	h.add_child(_mot("Banc", 13, DOUX))
	var joueurs := _joueurs()
	for k in 7:
		var id = compo.banc[k] if k < compo.banc.size() else null
		var j: Dictionary = joueurs.get(id, {}) if id != null else {}
		var choisi := case_choisie == 100 + k
		var b := Button.new()
		b.name = "Banc_%d" % k
		b.text = ("%s %s" % [j.poste, FootMatch.nom_court(j)]) if not j.is_empty() else "libre"
		b.custom_minimum_size.x = 0
		b.add_theme_font_size_override("font_size", 12)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		for etat in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(etat, _boite(Color(OR, 0.9) if choisi else Color(1, 1, 1, 0.06), OR if etat == "hover" else Color.TRANSPARENT, 4, 4))
		b.add_theme_color_override("font_color", ARDOISE if choisi else CRAIE)
		b.pressed.connect(func(): _cliquer_case(100 + k))
		h.add_child(b)
	return h


## Le poste choisi : qui l'occupe, et sa consigne individuelle.
func _panneau_case(col: VBoxContainer) -> void:
	if case_choisie < 0 or case_choisie >= 100:
		var aide := _mot("Touchez un poste du terrain pour voir son joueur. Le chiffre est la note du joueur à ce poste." if _lecture \
			else "Choisissez un poste sur le terrain, puis le joueur qui le prend dans la liste (ou l'inverse). Le chiffre est la note du joueur à ce poste.", 14, DOUX, null, true)
		aide.custom_minimum_size.x = _largeur_liste
		col.add_child(aide)
		return
	var c: Array = FootMatch.FORMATIONS[compo.formation][case_choisie]
	var id = compo.onze[case_choisie] if case_choisie < compo.onze.size() else null
	var joueurs := _joueurs()
	var j: Dictionary = joueurs.get(id, {}) if id != null else {}
	col.add_child(_mot("%s (%s)%s" % [c[1], FootMatch.POSTES[c[0]].to_lower(), "  ·  %s %s" % [j.prenom, j.nom] if not j.is_empty() else ""], 17, CRAIE, Polices.gras()))
	var o := ordres()
	if o.is_empty() or j.is_empty():
		return
	var cles: Array = o.keys().filter(func(k): return not o[k].has("postes") or str(c[0]) in o[k].postes)
	if cles.is_empty():
		return
	var actuel := cles.find(str(compo.ordres.get(id, cles[0])))
	var ligne := HBoxContainer.new()
	ligne.add_theme_constant_override("separation", 10)
	ligne.add_child(_mot("Consigne individuelle", 14, DOUX))
	ligne.add_child(_liste("Ordre", cles.map(func(k): return str(o[k].nom)), maxi(0, actuel), func(i):
		if i == 0:
			compo.ordres.erase(id)
		else:
			compo.ordres[id] = cles[i]
		modifie = true
		_dessiner()))
	col.add_child(ligne)


## La liste des joueurs à droite du terrain : titulaires (avec leur poste), remplaçants, puis les autres ;
## avec un poste choisi, la note de chacun à ce poste.
func _liste_joueurs(liste: VBoxContainer) -> void:
	var joueurs := _joueurs()
	var ids: Array = joueurs.keys()
	var ordre_poste := {"G": 0, "D": 1, "M": 2, "A": 3}
	ids.sort_custom(func(a, b):
		if joueurs[a].poste != joueurs[b].poste:
			return ordre_poste[joueurs[a].poste] < ordre_poste[joueurs[b].poste]
		return int(joueurs[a].note) > int(joueurs[b].note))
	var poste_case := ""
	if case_choisie >= 0 and case_choisie < 100:
		poste_case = str(FootMatch.FORMATIONS[compo.formation][case_choisie][0])
	for id in ids:
		var j: Dictionary = joueurs[id]
		var ou := ""
		var k: int = compo.onze.find(id)
		if k >= 0:
			ou = str(FootMatch.FORMATIONS[compo.formation][k][1])
		elif compo.banc.has(id):
			ou = "banc"
		var b := Button.new()
		b.name = "Choix_" + str(id).replace("/", "_")
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var note := int(j.note)
		var detail := "note %d" % note
		if poste_case != "":
			detail = "à ce poste %d" % int(roundf(FootMatch.note_effective(j, poste_case, 100.0)))
		b.text = "%-5s %s  %s %s   ·   %s" % [ou if ou != "" else "", str(j.poste), j.prenom, j.nom, detail]
		b.clip_text = true
		b.add_theme_font_override("font", Polices.texte())
		b.add_theme_font_size_override("font_size", 13 if _etroit() else 14)
		var choisi: bool = joueur_choisi == str(id)
		for etat in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(etat, _boite(Color(OR, 0.85) if choisi else (Color(1, 1, 1, 0.07) if etat == "hover" else Color(1, 1, 1, 0.02 if ou == "" else 0.05)), Color.TRANSPARENT, 3, 4))
		b.add_theme_color_override("font_color", ARDOISE if choisi else (OR if ou != "" and ou != "banc" else (CRAIE if ou == "banc" else DOUX)))
		b.add_theme_color_override("font_hover_color", OR)
		b.pressed.connect(func(): _cliquer_joueur(str(id)))
		liste.add_child(b)


## Un clic sur un poste : avec un joueur choisi, il y va ; sinon le poste est choisi (ou ne l'est plus).
func _cliquer_case(i: int) -> void:
	if _lecture:
		# En lecture, un poste se regarde (son joueur, sa consigne) sans changer de main.
		case_choisie = -1 if case_choisie == i or i >= 100 else i
		joueur_choisi = ""
		_dessiner()
		return
	if joueur_choisi != "":
		placer(joueur_choisi, i)
		joueur_choisi = ""
		case_choisie = i if i < 100 else -1
	else:
		case_choisie = -1 if case_choisie == i else i
	_dessiner()


func _cliquer_joueur(id: String) -> void:
	if _lecture:
		return
	if case_choisie >= 0:
		placer(id, case_choisie)
		joueur_choisi = ""
	else:
		joueur_choisi = "" if joueur_choisi == id else id
	_dessiner()


## Met le joueur id au poste i (ou à la place i - 100 du banc) ; celui qui l'occupait prend la place qu'il
## laisse (un échange), ou sort de la feuille s'il n'en laisse pas.
func placer(id: String, i: int) -> void:
	var onze: Array = compo.onze
	var banc: Array = compo.banc
	var depuis_onze := onze.find(id)
	var depuis_banc := banc.find(id)
	var occupant = null
	if i >= 100:
		var k := i - 100
		occupant = banc[k] if k < banc.size() else null
		if k >= banc.size():
			banc.append(id)
		else:
			banc[k] = id
	else:
		occupant = onze[i]
		onze[i] = id
	if depuis_onze >= 0 and depuis_onze != i:
		onze[depuis_onze] = occupant
	elif depuis_banc >= 0 and depuis_banc != i - 100:
		if occupant != null:
			banc[depuis_banc] = occupant
		else:
			banc.remove_at(depuis_banc)
	# Un joueur qui quitte le onze perd sa consigne.
	for x in compo.ordres.keys():
		if not onze.has(x):
			compo.ordres.erase(x)
	compo.banc = banc.filter(func(x): return x != null)
	_message = ""
	repetition = {}
	modifie = true


## Envoie la composition au championnat (Football.decider), comme la causerie le fait de la consigne.
func valider() -> void:
	var f := foot()
	var r: Dictionary = f.prochain_match(club)
	if r.is_empty():
		return
	var d := {"formation": compo.formation, "mentalite": compo.mentalite, "pressing": compo.pressing,
		"compo": compo.onze.map(func(x): return "" if x == null else str(x)), "banc": compo.banc.duplicate(), "roles": compo.ordres.duplicate()}
	# Le programme d'entraînement de la semaine reste celui qui est posé.
	var pose: Dictionary = f.consigne_de(r.s, r.j, club).consigne
	if pose.has("entrainement"):
		d["entrainement"] = pose.entrainement
	var ok: bool = f.decider(r.s, r.j, club, d)
	if ok:
		modifie = false
	_message = ("Composition enregistrée. " + _etat_consigne(f.consigne_de(r.s, r.j, club))) if ok else "Le match est joué ou se joue : la composition attendra le suivant."
	_dessiner()


func _etat_consigne(actuelle: Dictionary) -> String:
	var compte: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Compte")
	var connecte: bool = compte != null and compte.connecte()
	match str(actuelle.etat):
		"commune":
			return "Au championnat%s : tout le monde verra ce match joué ainsi." % (" (posée par %s)" % actuelle.par if actuelle.par != "" else "")
		"locale":
			return "Gardée sur cet appareil, en route vers le championnat." if connecte else "Gardée sur cet appareil seulement : connectez-vous à votre compte Pyramides (dans les réglages) pour qu'elle compte pour tout le monde."
	return "Rien n'est encore posé : sans consigne, l'adjoint aligne l'équipe type en 4-4-2."


## Le terrain : la pelouse en bandes, les lignes à la craie, notre but en bas.
class Terrain extends Control:
	func _draw() -> void:
		var s := size
		var bandes := 8
		for i in bandes:
			draw_rect(Rect2(0, s.y * i / bandes, s.x, s.y / bandes + 1), Bureau.PELOUSE if i % 2 == 0 else Bureau.PELOUSE_CLAIRE)
		var craie := Color(1, 1, 1, 0.55)
		var m := 6.0
		var r := Rect2(m, m, s.x - 2 * m, s.y - 2 * m)
		draw_rect(r, craie, false, 2.0)
		draw_line(Vector2(r.position.x, s.y / 2), Vector2(r.end.x, s.y / 2), craie, 2.0)
		draw_arc(s / 2, s.x * 0.14, 0, TAU, 40, craie, 2.0)
		for haut in [true, false]:
			var y0 := r.position.y if haut else r.end.y
			var sens := 1.0 if haut else -1.0
			var surface := Rect2(s.x * 0.2, y0 if haut else y0 - s.y * 0.16, s.x * 0.6, s.y * 0.16)
			draw_rect(surface, craie, false, 2.0)
			var petite := Rect2(s.x * 0.36, y0 if haut else y0 - s.y * 0.06, s.x * 0.28, s.y * 0.06)
			draw_rect(petite, craie, false, 2.0)
			draw_circle(Vector2(s.x / 2, y0 + sens * s.y * 0.11), 2.5, craie)


# ---------------------------------------------------------------- l'adversaire

## La consigne qu'on prépare à la tactique (même pas encore validée), pour le rapport et la répétition.
func _consigne_en_cours() -> Dictionary:
	if compo.is_empty():
		_charger_compo()
	return {"formation": compo.formation, "mentalite": compo.mentalite, "pressing": compo.pressing,
		"compo": compo.onze.map(func(x): return "" if x == null else str(x)), "banc": compo.banc.duplicate(), "roles": compo.ordres.duplicate()}


func _adversaire(col: VBoxContainer) -> void:
	var f := foot()
	var w := _large()
	var rap := FootCourrier.rapport(f, club, _consigne_en_cours())
	if rap.is_empty():
		_texte(col, "Pas de match avant la saison qui vient : l'adjoint attend le calendrier.", w, 16)
		return
	var c: Dictionary = f.clubs.get(rap.adv, {})
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", 12)
	if c.has("couleurs"):
		tete.add_child(_couleurs(c.couleurs))
	tete.add_child(_mot(str(rap.nom), 24, CRAIE, Polices.gras()))
	tete.add_child(_mot("%s%s" % ["à domicile" if rap.domicile else "à l'extérieur", ", %s du groupe" % FootLocaux._rang(int(rap.rang)) if int(rap.rang) > 0 else ""], 16, DOUX))
	col.add_child(tete)
	var forme := HBoxContainer.new()
	forme.name = "Forme"
	forme.add_theme_constant_override("separation", 4)
	forme.add_child(_mot("Forme ", 15, DOUX))
	if str(rap.forme) == "":
		forme.add_child(_mot("pas encore de match joué", 15, DOUX))
	for x in str(rap.forme):
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", _boite(VERT if x == "V" else (ROUGE if x == "D" else Color(0.6, 0.6, 0.6)), Color.TRANSPARENT, 3, 4))
		var l := _mot(x, 13, ARDOISE, Polices.gras())
		l.custom_minimum_size.x = 14
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		p.add_child(l)
		forme.add_child(p)
	col.add_child(forme)
	var m: Dictionary = rap.meilleur
	_texte(col, "%s Son meilleur joueur : %s %s, %s, note %d." % ["Au dernier match, il jouait en %s." % rap.formation if str(rap.formation) != "" else "On ne l'a pas encore vu jouer : l'adjoint le suppose en 4-4-2.",
		m.get("prenom", ""), m.get("nom", ""), FootMatch.POSTES.get(str(m.get("poste", "")), "").to_lower(), int(m.get("note", 0))], w, 15, CRAIE)
	col.add_child(_filet())
	_texte(col, "Les duels du match, avec la tactique que vous préparez (%s, %s) : en or, nous ; en gris, eux." % [compo.formation, FootMatch.MENTALITES[compo.mentalite].nom.to_lower()], w, 14, DOUX)
	var grille := GridContainer.new()
	grille.name = "Duels"
	grille.columns = 4
	grille.add_theme_constant_override("h_separation", 14)
	grille.add_theme_constant_override("v_separation", 6)
	col.add_child(grille)
	var barre_l := clampf(w * 0.22, 90.0, 220.0)
	for d in rap.duels:
		var nous := float(d.nous)
		var eux := float(d.eux)
		var rapport := nous / maxf(eux, 1.0)
		var t := _mot(str(d.titre), 15, CRAIE)
		t.custom_minimum_size.x = 210 if not _etroit() else 150
		grille.add_child(t)
		grille.add_child(_duel(nous, eux, barre_l))
		var mots: Array = MOTS_DUELS["milieu" if d.secteur == "milieu" else ("defense" if str(d.secteur).begins_with("def_") else "attaque")]
		var verdict: String = mots[0 if rapport >= 1.15 else (1 if rapport >= 1.04 else (2 if rapport > 0.96 else (3 if rapport > 0.87 else 4)))]
		grille.add_child(_mot(verdict, 14, VERT if rapport >= 1.04 else (CRAIE if rapport > 0.96 else (OR if rapport > 0.87 else ROUGE)), Polices.gras()))
		grille.add_child(_mot("%d contre %d" % [roundi(nous), roundi(eux)], 13, DOUX))
	col.add_child(_filet())
	_texte(col, "L'avis de l'adjoint", w, 13, DOUX)
	for conseil in rap.conseils:
		_texte(col, "— " + str(conseil), w, 15)
	_bloc_repetition(col, w)


## Deux barres face à face : la nôtre en or, la leur en craie.
func _duel(nous: float, eux: float, largeur: float) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	var maxi_v := maxf(maxf(nous, eux), 1.0)
	for k in 2:
		var v := nous if k == 0 else eux
		var fond := ColorRect.new()
		fond.color = Color(1, 1, 1, 0.08)
		fond.custom_minimum_size = Vector2(largeur, 9)
		fond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var plein := ColorRect.new()
		plein.color = OR if k == 0 else Color(CRAIE, 0.6)
		plein.size = Vector2(largeur * clampf(v / maxi_v, 0.0, 1.0), 9)
		if k == 0:
			plein.position.x = largeur - plein.size.x
		fond.add_child(plein)
		h.add_child(fond)
	h.tooltip_text = "Nous %d, eux %d" % [roundi(nous), roundi(eux)]
	return h


## La répétition : le bouton, puis ce qu'elle a donné.
func _bloc_repetition(col: VBoxContainer, w: float) -> void:
	var ligne := HFlowContainer.new()
	ligne.add_theme_constant_override("h_separation", 12)
	ligne.add_theme_constant_override("v_separation", 6)
	col.add_child(ligne)
	var b := _bouton("Répéter le match à l'entraînement", func(): repeter(), 14)
	b.name = "Repeter"
	ligne.add_child(b)
	if page == "adversaire":
		ligne.add_child(_bouton("Changer la tactique", func(): aller("tactique"), 14))
	if repetition.is_empty():
		_texte(col, "Vingt matchs d'opposition avec la tactique que vous préparez, contre l'adversaire tel que l'adjoint l'imagine. Le hasard du dimanche, lui, reste à venir.", w, 13, DOUX)
	else:
		var r := repetition
		var l := _texte(col, "Sur %d matchs d'opposition : %d victoire%s, %d nul%s, %d défaite%s ; %.1f buts marqués et %.1f encaissés par match." % [int(r.essais),
			int(r.victoires), "s" if int(r.victoires) > 1 else "", int(r.nuls), "s" if int(r.nuls) > 1 else "", int(r.defaites), "s" if int(r.defaites) > 1 else "",
			float(r.pour) / maxf(float(r.essais), 1.0), float(r.contre) / maxf(float(r.essais), 1.0)], w, 15, OR, Polices.gras())
		l.name = "Repetition"


## Joue la répétition (Football.repetition) avec la consigne en cours, cinq matchs par image pour ne pas
## figer l'écran d'un téléphone, et la montre.
func repeter() -> void:
	var f := foot()
	var r: Dictionary = f.prochain_match(club)
	if r.is_empty() or _repete:
		return
	_repete = true
	var essai := _consigne_en_cours()
	var total := {"victoires": 0, "nuls": 0, "defaites": 0, "pour": 0, "contre": 0, "essais": 0}
	for k in REPETITIONS / 5:
		var x: Dictionary = f.repetition(r.s, r.j, r.dom, r.ext, club, essai, 5)
		for c in total:
			total[c] += int(x[c])
		if k < REPETITIONS / 5 - 1 and is_inside_tree():
			await get_tree().process_frame
	_repete = false
	repetition = total
	if is_inside_tree():
		_dessiner()


# ---------------------------------------------------------------- l'entraînement

func _entrainement(col: VBoxContainer) -> void:
	var f := foot()
	var w := _large()
	var r: Dictionary = f.prochain_match(club)
	var pose := FootEntrainement.DEFAUT
	if not r.is_empty():
		pose = FootEntrainement.programme(f.consigne_de(r.s, r.j, club).consigne.get("entrainement", ""))
	var choisi := programme_choisi if programme_choisi != "" else pose
	_texte(col, "Le programme de la semaine, jusqu'au match de dimanche. Les jeunes progressent vite, les anciens à peine ; chacun surtout dans ce que son poste travaille. Les progrès comptent une fois le match joué : cinq points font un cran.", w, 14, DOUX)
	var grille := GridContainer.new()
	grille.name = "Programmes"
	grille.columns = 2 if _etroit() else 4
	grille.add_theme_constant_override("h_separation", 8)
	grille.add_theme_constant_override("v_separation", 8)
	col.add_child(grille)
	var lb := (w - 8.0 * (grille.columns - 1)) / grille.columns
	for cle in FootEntrainement.PROGRAMMES:
		var p: Dictionary = FootEntrainement.PROGRAMMES[cle]
		var b := Button.new()
		b.name = "Programme_" + cle
		b.custom_minimum_size = Vector2(lb, 74)
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var ouvert: bool = cle == choisi
		for etat in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(etat, _boite(Color(OR, 0.18) if ouvert else (Color(1, 1, 1, 0.07) if etat == "hover" else Color(1, 1, 1, 0.03)), OR if ouvert else Color(1, 1, 1, 0.1), 5, 8, 2 if ouvert else 1))
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 10
		v.offset_right = -8
		v.offset_top = 6
		v.add_theme_constant_override("separation", 2)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		v.add_child(_mot(str(p.nom) + ("   ✓ posé" if cle == pose and not r.is_empty() else ""), 15, OR if ouvert else CRAIE, Polices.gras()))
		var ph := _mot(str(p.phrase), 12, DOUX, null, true)
		ph.custom_minimum_size.x = lb - 22.0
		v.add_child(ph)
		b.pressed.connect(func():
			programme_choisi = cle
			_dessiner())
		grille.add_child(b)
	var ligne := HFlowContainer.new()
	ligne.add_theme_constant_override("h_separation", 12)
	col.add_child(ligne)
	var bv := _bouton("Poser le programme « %s »" % FootEntrainement.PROGRAMMES[choisi].nom, func(): poser_programme(choisi), 14)
	bv.name = "PoserProgramme"
	bv.disabled = r.is_empty() or not f.peut_decider(club) or (choisi == pose and f.consigne_de(r.s, r.j, club).etat != "aucune")
	ligne.add_child(bv)
	var etat := ""
	if r.is_empty():
		etat = "La saison qui vient n'est pas encore tirée."
	elif not f.peut_decider(club):
		etat = "Seul celui qui dirige le club choisit le programme. Sans lui, l'adjoint fait du général."
	elif _message != "":
		etat = _message
	else:
		etat = "Programme posé pour la semaine : %s." % str(FootEntrainement.PROGRAMMES[pose].nom).to_lower()
	var le := _mot(etat, 14, DOUX)
	le.name = "Etat"
	ligne.add_child(le)
	col.add_child(_filet())
	# Ce que la semaine apporte à chacun, le plus gros progrès d'abord.
	var joueurs := _joueurs()
	var debut: Dictionary = f.effectif(club, _journee()[0], 1)
	var lignes: Array = []
	for id in joueurs:
		var j: Dictionary = joueurs[id]
		var g := FootEntrainement.gains(j, choisi)
		var meilleure := ""
		if choisi == FootEntrainement.DEFAUT:
			meilleure = "note" if g.has("note") else ""
		else:
			for k in g:
				if k != "note" and (meilleure == "" or float(g[k]) > float(g[meilleure])):
					meilleure = k
		lignes.append({"id": id, "j": j, "g": g, "c": meilleure})
	lignes.sort_custom(func(a, b):
		var ga := float(a.g.get(a.c, 0.0)) if a.c != "" else 0.0
		var gb := float(b.g.get(b.c, 0.0)) if b.c != "" else 0.0
		return ga > gb if ga != gb else str(a.id) < str(b.id))
	_texte(col, "Ce que la semaine apporterait à chacun", w, 13, DOUX)
	var t := GridContainer.new()
	t.name = "Progres"
	t.columns = 5 if _etroit() else 6
	t.add_theme_constant_override("h_separation", 16)
	t.add_theme_constant_override("v_separation", 3)
	col.add_child(t)
	var entetes := ["Joueur", "Âge", "Travaille", "Vers le cran suivant", "Semaine"]
	if not _etroit():
		entetes.append("Depuis le début de saison")
	for x in entetes:
		t.add_child(_mot(x, 13, DOUX))
	for e in lignes:
		var j: Dictionary = e.j
		t.add_child(_mot("%s %s %s" % [j.poste, j.prenom, j.nom], 14, CRAIE))
		t.add_child(_mot("%d ans" % int(j.age), 14, DOUX))
		if e.c == "":
			t.add_child(_mot("–", 14, DOUX))
			t.add_child(Control.new())
			t.add_child(_mot("repos", 14, DOUX))
		elif e.c == "note":
			t.add_child(_mot("tout, note %d" % int(j.note), 14, CRAIE))
			t.add_child(_jauge_cran(fposmod(float(j.note), 1.0), fposmod(float(j.note) + float(e.g.note), 1.0), 140))
			t.add_child(_mot("+%.2f de note" % float(e.g.note), 14, CRAIE))
		else:
			var v := FootMatch.competence(j, e.c)
			t.add_child(_mot("%s %d" % [str(FootMercato.NOMS_COMP.get(e.c, e.c)), MERCATO.niveau(v)], 14, FootMercato.couleur_cran(MERCATO.niveau(v))))
			var vers := FootEntrainement.vers_cran(v)
			var apres := FootEntrainement.vers_cran(v + float(e.g[e.c]))
			t.add_child(_jauge_cran(vers, apres, 140))
			t.add_child(_mot("+%.2f" % float(e.g[e.c]), 14, VERT if float(e.g[e.c]) >= 0.3 else CRAIE))
		if not _etroit():
			var d0: Dictionary = debut.get(e.id, {})
			var crans := FootEntrainement.crans_gagnes(d0, j).size() if not d0.is_empty() else 0
			var dn := float(j.note) - float(d0.get("note", j.note))
			t.add_child(_mot(("%d cran%s, note %+.1f" % [crans, "s" if crans > 1 else "", dn]) if crans > 0 or dn >= 0.05 else "–", 14, VERT if crans > 0 else DOUX))


## Où l'on en est vers le cran suivant, et (plus clair) où la semaine mènerait ; au-delà, le cran tombe.
func _jauge_cran(avant: float, apres: float, largeur: float) -> Control:
	var fond := ColorRect.new()
	fond.color = Color(1, 1, 1, 0.08)
	fond.custom_minimum_size = Vector2(largeur, 8)
	fond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var plus := ColorRect.new()
	plus.color = Color(VERT, 0.55)
	plus.size = Vector2(largeur * (1.0 if apres < avant else apres), 8)
	fond.add_child(plus)
	var plein := ColorRect.new()
	plein.color = OR
	plein.size = Vector2(largeur * avant, 8)
	fond.add_child(plein)
	return fond


## Pose le programme de la semaine dans la consigne du prochain match (Football.decider), sans toucher au reste.
func poser_programme(prog: String) -> void:
	var f := foot()
	var r: Dictionary = f.prochain_match(club)
	if r.is_empty():
		return
	var d: Dictionary = (f.consigne_de(r.s, r.j, club).consigne as Dictionary).duplicate(true)
	d["entrainement"] = prog
	var ok: bool = f.decider(r.s, r.j, club, d)
	programme_choisi = ""
	_message = ("Programme posé : %s. %s" % [str(FootEntrainement.PROGRAMMES[prog].nom).to_lower(), _etat_consigne(f.consigne_de(r.s, r.j, club))]) if ok else "Le match est joué ou se joue : le programme attendra la semaine suivante."
	_dessiner()


# ---------------------------------------------------------------- l'agenda

func _agenda(col: VBoxContainer) -> void:
	var a: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Agenda")
	if a == null:
		col.add_child(_mot("L'agenda n'est pas là.", 15, DOUX))
		return
	var t: int = a.maintenant()
	var rdv: Array = a.entre(t - 3 * 3600, t + 14 * 86400).filter(func(rv): return str(rv.get("activite", "")) in ["football", "mercato"])
	# La saison en une phrase (l'intersaison, où se prennent les parts, et le mercato), et tout le calendrier au carnet.
	col.add_child(_mot(preload("res://scripts/socle/calendrier.gd").resume(foot(), "football"), 15, CRAIE, null, true))
	var cal := _bouton("Tout le calendrier des championnats  (carnet)", func(): preload("res://scripts/socle/calendrier.gd").ouvrir())
	cal.name = "Calendrier"
	col.add_child(cal)
	col.add_child(_mot("Les deux semaines du club : les matchs, l'arrivée des nouveaux joueurs au marché, les dates limites de nos enchères et de nos ventes.", 14, DOUX, null, true))
	if rdv.is_empty():
		col.add_child(_mot("Rien dans les deux semaines qui viennent.", 16, CRAIE))
		return
	var jour := ""
	for rv in rdv:
		var d: String = date(int(rv.quand))
		if d != jour:
			jour = d
			var tete := _mot(d.substr(0, 1).to_upper() + d.substr(1), 16, OR, Polices.gras())
			col.add_child(tete)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 16)
		var heure := _mot(a.heure(int(rv.quand)), 15, CRAIE, Polices.gras())
		heure.custom_minimum_size.x = 64
		h.add_child(heure)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.add_child(_mot(str(rv.get("titre", rv.get("quoi", ""))), 15, CRAIE))
		var detail := str(rv.get("detail", ""))
		if detail != "":
			var l := _mot(detail, 13, DOUX, null, true)
			l.custom_minimum_size.x = _large() - 90.0
			v.add_child(l)
		h.add_child(v)
		col.add_child(h)


# ---------------------------------------------------------------- le championnat

func _championnat(col: VBoxContainer) -> void:
	var f := foot()
	var onglets := HFlowContainer.new()
	onglets.add_theme_constant_override("h_separation", 6)
	col.add_child(onglets)
	for o in ONGLETS_CHAMPIONNAT:
		var b := _onglet(o[1], onglet_championnat == o[0], func():
			onglet_championnat = o[0]
			_dessiner())
		b.name = "Onglet_" + o[0]
		onglets.add_child(b)
	var place: Array = f.place_de(club)
	if place.is_empty():
		place = division_suivie()
	var n: int = place[0]
	var g: int = place[1]
	var v := _defile_dans(col, _hauteur_page() - 56.0)
	v.add_child(_mot("%s, saison %d" % [f.nom_division(n, g), int(f.saison)], 16, DOUX))
	if onglet_championnat == "classement":
		v.add_child(_classement(f.saison, n, g))
		return
	if not f.has_method("statistiques"):
		v.add_child(_mot("Les %s arrivent avec les statistiques des joueurs du championnat." % {"buteurs": "buteurs", "passeurs": "passeurs", "clean_sheets": "clean sheets des gardiens"}[onglet_championnat], 16, CRAIE, null, true))
		return
	var liste: Variant = _statistiques().get(onglet_championnat, [])
	if not liste is Array or (liste as Array).is_empty():
		v.add_child(_mot("Personne encore : aucune journée n'est jouée.", 16, CRAIE))
		return
	var grille := GridContainer.new()
	grille.name = "Statistiques"
	grille.columns = 4
	grille.add_theme_constant_override("h_separation", 18)
	grille.add_theme_constant_override("v_separation", 4)
	v.add_child(grille)
	for t in ["", "Joueur", "Club", {"buteurs": "Buts", "passeurs": "Passes", "clean_sheets": "Matchs"}[onglet_championnat]]:
		grille.add_child(_mot(t, 13, DOUX))
	var i := 0
	for e in (liste as Array).slice(0, 25):
		i += 1
		var nous: bool = str(e.get("club", "")) == club
		var encre := OR if nous else CRAIE
		grille.add_child(_mot("%d." % i, 15, encre))
		grille.add_child(_mot("%s %s" % [e.get("prenom", ""), e.get("nom", "")], 15, encre, Polices.gras() if nous else null))
		var c: Dictionary = f.clubs.get(str(e.get("club", "")), {})
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		if c.has("couleurs"):
			h.add_child(_couleurs(c.couleurs))
		h.add_child(_mot(str(c.get("nom", e.get("club", ""))), 15, DOUX))
		grille.add_child(h)
		var nombre := int(e.get({"buteurs": "buts", "passeurs": "passes", "clean_sheets": "n"}[onglet_championnat], e.get("n", 0)))
		grille.add_child(_mot(str(nombre), 16, OR, Polices.gras()))


func _defile_dans(col: VBoxContainer, h: float) -> VBoxContainer:
	var d := ScrollContainer.new()
	d.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	d.custom_minimum_size.y = h
	col.add_child(d)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	d.add_child(v)
	return v


# ---------------------------------------------------------------- le mercato, emboîté

func _mercato_emboite(p: String) -> void:
	if _mercato_noeud() == null:
		_corps.add_child(_mot("Le marché n'est pas ouvert ici.", 16, DOUX))
		return
	var m := FootMercato.new()
	m.name = "Mercato"
	m.club = club
	m.integre = true
	m.page = p
	m.hauteur = _hauteur_page()
	m.largeur = _largeur_page() - 8.0
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_corps.add_child(m)
	_mercato = m
