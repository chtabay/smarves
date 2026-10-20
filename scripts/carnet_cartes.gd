extends Control
## Le classeur de cartes du carnet (onglet « Mes cartes ») : ce qu'on possède, en cartes à collectionner
## façon titre de propriété du Monopoly, collées sur le papier quadrillé du carnet. Un sous-onglet par
## village : la commune d'origine d'abord, puis chaque commune où l'on tient un bien ou des parts de club.
##
## Sous chaque village, « Mes biens » : seulement les cartes qu'on possède, rangées par genre (les maisons,
## les murs, la garde-robe, le garage, la brocante, les souvenirs), chaque genre de sa couleur. La bordure dit
## le rang du bien, du bronze au prestige, selon son prix ; les cartes de prestige ont un reflet qui passe.
##
## Les parts d'établissement ont le topo complet, chacune dans sa catégorie. « Les établissements » : les
## parts que vend le notaire (le café, le moulin, le fournil, le comité des fêtes, le casino), une carte
## par part, à soi ou en vente. « Les clubs » : les neuf obligations de chaque club en neuf cartes, à soi,
## en vente, ou tenues par un autre joueur (son nom dessus). Rien ne s'achète ici : la carte dit où aller, et seuls les gestes sans prix (porter, conduire, habiter, louer)
## se font depuis le classeur.
##
## Navigation : ↑ ↓ passent d'un village à l'autre, un clic montre une carte en grand avec sa fiche,
## ← → passent à la voisine, Échap la repose.

signal ferme_zoom

## Les encres et le papier du carnet (scripts/carnet.gd).
const PAPER := Color(0.97, 0.95, 0.88)
const MARGIN_RED := Color(0.85, 0.3, 0.3, 0.55)
const INK := Color(0.12, 0.2, 0.5)
const INK_LIGHT := Color(0.3, 0.38, 0.62)
const PENCIL := Color(0.38, 0.36, 0.34)
const RED_INK := Color(0.65, 0.15, 0.15)
const OR := Color(0.86, 0.68, 0.25)
const ARDOISE := Color(0.36, 0.42, 0.5)
const VISAGE := Color(0.995, 0.985, 0.955)
## La bordure d'une carte selon son rang : bronze, argent, or, prestige.
const RANGS := [Color(0.66, 0.46, 0.3), Color(0.7, 0.74, 0.79), Color(0.85, 0.66, 0.22), Color(0.95, 0.82, 0.42)]
const NOMS_RANGS := ["bronze", "argent", "or", "prestige"]
## La taille d'une carte dans le classeur ; en grand, elle est multipliée par ZOOM.
const CARTE := Vector2(150, 236)
const ZOOM := 1.62
## Les genres de biens, dans l'ordre de la page, chacun de sa couleur, comme les rues du plateau.
const GENRES := [
	["part", "Les parts", Color(0.13, 0.46, 0.29)],
	["maison", "Les maisons", Color(0.78, 0.16, 0.18)],
	["murs", "Les murs", Color(0.92, 0.52, 0.12)],
	["tenue", "La garde-robe", Color(0.82, 0.38, 0.58)],
	["vehicule", "Le garage", Color(0.3, 0.6, 0.82)],
	["meuble", "La brocante", Color(0.52, 0.34, 0.2)],
	["souvenir", "Les souvenirs", Color(0.46, 0.3, 0.66)],
	["autre", "Les autres biens", Color(0.4, 0.46, 0.5)],
]
const NOTAIRE := preload("res://scripts/socle/notaire.gd")

## Le carnet, qui tient le classeur.
var carnet = null
## Le village ouvert (« » : la commune d'origine).
var village := ""
var _villages_box: HBoxContainer
var _resume: Label
var _defile: ScrollContainer
var _page: VBoxContainer
var _zoom: Control
var _zoom_boite: HBoxContainer
## Les cartes affichées, dans l'ordre : le zoom passe de l'une à l'autre.
var _affichees: Array = []
var _index := -1
var _texte: Font
var _gras: Font


func _ready() -> void:
	_texte = Polices.texte()
	_gras = Polices.gras()
	custom_minimum_size = Vector2(1120, 680)
	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	marge.add_theme_constant_override("margin_left", 62)
	marge.add_theme_constant_override("margin_right", 30)
	marge.add_theme_constant_override("margin_top", 22)
	marge.add_theme_constant_override("margin_bottom", 18)
	add_child(marge)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	marge.add_child(col)
	# La tête : le titre, les villages en sous-onglets, et le compte du village.
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", 18)
	col.add_child(tete)
	_mot(tete, "Mes cartes", 26, INK, _gras).size_flags_vertical = Control.SIZE_SHRINK_END
	_villages_box = HBoxContainer.new()
	_villages_box.add_theme_constant_override("separation", 6)
	_villages_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_villages_box.size_flags_vertical = Control.SIZE_SHRINK_END
	tete.add_child(_villages_box)
	_resume = _mot(tete, "", 16, PENCIL)
	_resume.size_flags_vertical = Control.SIZE_SHRINK_END
	_defile = ScrollContainer.new()
	_defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_defile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(_defile)
	_page = VBoxContainer.new()
	_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_page.add_theme_constant_override("separation", 8)
	_defile.add_child(_page)
	# La carte en grand, par-dessus la page.
	_zoom = Control.new()
	_zoom.set_anchors_preset(Control.PRESET_FULL_RECT)
	_zoom.visible = false
	add_child(_zoom)
	var voile := ColorRect.new()
	voile.color = Color(0.16, 0.12, 0.08, 0.72)
	voile.set_anchors_preset(Control.PRESET_FULL_RECT)
	voile.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			fermer_zoom())
	_zoom.add_child(voile)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zoom.add_child(centre)
	_zoom_boite = HBoxContainer.new()
	_zoom_boite.add_theme_constant_override("separation", 22)
	centre.add_child(_zoom_boite)


## Le papier à petits carreaux et la marge rouge, comme les pages du carnet.
func _draw() -> void:
	var st := StyleBoxFlat.new()
	st.bg_color = PAPER
	st.set_corner_radius_all(4)
	draw_style_box(st, Rect2(Vector2.ZERO, size))
	var pas := 18.0
	var y := 64.0
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.55, 0.68, 0.85, 0.32), 1.0)
		y += pas
	var x := pas
	while x < size.x:
		draw_line(Vector2(x, 64), Vector2(x, size.y), Color(0.55, 0.68, 0.85, 0.16), 1.0)
		x += pas
	draw_line(Vector2(46, 0), Vector2(46, size.y), MARGIN_RED, 2.0)


func _mot(parent: Control, t: String, taille := 16, couleur := INK, police: Font = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", police if police != null else _texte)
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	parent.add_child(l)
	return l


# --- Ce que contient le classeur ----------------------------------------------------------------

func _origine() -> String:
	var o: Commune = Communes.origine()
	return o.id if o != null else ""


## La commune d'un bien du catalogue : la sienne s'il vient d'ailleurs, sinon la commune d'origine.
func _village_de(it: Dictionary) -> String:
	var c := str(it.get("commune", ""))
	return c if c != "" else _origine()


## Les villages du classeur, dans l'ordre : [{id, nom}]. La commune d'origine toujours, puis chaque commune
## où l'on tient un bien ou une obligation de club.
func villages() -> Array:
	var ids: Array = [_origine()]
	for id in Biens.owned:
		if Biens.count(id) > 0:
			var v := _village_de(Biens.item(id))
			if not ids.has(v):
				ids.append(v)
	for moteur in [Football, Basket]:
		for club in moteur.clubs:
			if not ids.has(club) and not moteur.mes_obligations(club).is_empty():
				ids.append(club)
	return ids.map(func(id): return {"id": id, "nom": _nom_commune(id)})


func _nom_commune(id: String) -> String:
	var c: Commune = Communes.commune(id)
	if c != null:
		return c.nom
	var e := Communes.au_catalogue(id)
	return str(e.get("nom", id.capitalize()))


## Les cartes des biens qu'on possède dans un village, genre par genre puis du moins cher au plus cher.
## Une carte : {id, genre_id, couleur, nom, genre, icone, prix, rente, charge, standing, n, max, etat, rang,
## de, phrase, vendeur, kind}.
func cartes(v: String) -> Array:
	var o: Commune = Communes.origine()
	var out: Array = []
	for it in Biens.catalogue():
		var n := Biens.count(it.id)
		if n <= 0 or it.kind in ["club", "part"] or _village_de(it) != v:
			continue
		var g := _genre_id(it, o)
		out.append({"id": it.id, "genre_id": g, "couleur": _couleur_genre(g), "nom": it.name, "genre": _genre(it, o),
			"icone": _icone(it, o), "prix": Biens.next_price(it.id) if n < int(it.max) else int(it.price), "rente": int(it.rente),
			"charge": int(it.charge), "standing": int(it.standing), "n": n, "max": int(it.max), "etat": "moi",
			"rang": _rang(int(it.price)), "de": str(it.get("from", "")), "phrase": str(it.get("blurb", "")),
			"vendeur": str(it.get("seller", "")), "kind": str(it.kind)})
	if v == _origine():
		for id in Biens.trouvailles:
			if Biens.TROUVAILLES.has(id):
				out.append({"id": id, "genre_id": "souvenir", "couleur": _couleur_genre("souvenir"), "nom": str(Biens.TROUVAILLES[id].name),
					"genre": "Souvenir · à poser chez soi", "icone": "souvenir", "prix": 0, "rente": 0, "charge": 0, "standing": 0,
					"n": 1, "max": 1, "etat": "moi", "rang": 3, "de": "", "phrase": "", "vendeur": "", "kind": "souvenir"})
	var ordre := GENRES.map(func(g): return g[0])
	out.sort_custom(func(a, b):
		var ga := ordre.find(a.genre_id)
		var gb := ordre.find(b.genre_id)
		if ga != gb:
			return ga < gb
		return int(a.prix) < int(b.prix) if int(a.prix) != int(b.prix) else str(a.nom) < str(b.nom))
	return out


func _genre_id(it: Dictionary, o: Commune) -> String:
	var k := str(it.kind)
	return k if k in ["part", "maison", "murs", "tenue", "vehicule", "meuble"] else "autre"


func _couleur_genre(g: String) -> Color:
	for x in GENRES:
		if x[0] == g:
			return x[2]
	return GENRES[-1][2]


## La ligne sous l'image : ce qu'est la carte, et où.
func _genre(it: Dictionary, o: Commune) -> String:
	match str(it.kind):
		"part":
			var a := NOTAIRE.adresse(o, str(it.id))
			return "Part · %s" % str(a.get("etiquette", "au village")).trim_prefix("← ").trim_suffix(" →")
		"maison":
			return "Maison · " + str(it.get("adresse", "au village")) if str(it.get("adresse", "")) != "" else "Maison · au village"
		"murs":
			var a := NOTAIRE.adresse(o, str(it.id))
			return ("Bâtiment public" if str(a.get("genre", "")) == "public" else "Murs d'une boutique") + " · loué"
		"tenue":
			return "Tenue · chez Raymonde"
		"vehicule":
			return "Véhicule · garage Fradin"
		"meuble":
			return "Meuble · " + str(Biens.GENRES.get(str(it.get("slot", "")), "chez soi"))
	return str(it.kind).capitalize()


func _icone(it: Dictionary, o: Commune) -> String:
	if str(it.kind) == "murs":
		return "public" if str(NOTAIRE.adresse(o, str(it.id)).get("genre", "")) == "public" else "murs"
	return str(it.kind) if str(it.kind) in ["part", "maison", "tenue", "vehicule", "meuble"] else "murs"


static func _rang(prix: int) -> int:
	if prix >= 15000:
		return 3
	if prix >= 5000:
		return 2
	if prix >= 1000:
		return 1
	return 0


## Les établissements d'un village dont le notaire vend des parts, avec le topo complet : une carte par
## part, à soi ou en vente. Ceux dont le seuil n'est pas atteint n'y sont pas encore, sauf si l'on en tient.
## [{id, nom, cartes}] ; une carte : {id, kind « part_etab », bien, nom, genre, prix, rente, charge, standing,
## etat (« moi », « libre »), rang, de, phrase}.
func etablissements(v: String) -> Array:
	var o: Commune = Communes.origine()
	var out: Array = []
	for it in Biens.catalogue():
		if it.kind != "part" or _village_de(it) != v:
			continue
		var n := Biens.count(it.id)
		if n <= 0 and Game.won < int(it.gate):
			continue
		var lieu := _genre(it, o).trim_prefix("Part · ")
		var parts: Array = []
		for i in int(it.max):
			var prix := Biens.price_of(it.id, i)
			parts.append({"id": "part:%s:%d" % [it.id, i + 1], "kind": "part_etab", "bien": it.id, "numero": i + 1, "nom": it.name,
				"genre": "Part %d sur %d" % [i + 1, int(it.max)], "icone": "part", "couleur": _couleur_genre("part"),
				"prix": prix, "valeur": prix, "rente": int(it.rente), "charge": int(it.charge), "standing": int(it.standing),
				"etat": "moi" if i < n else "libre", "qui": "moi" if i < n else "libre", "n": 1 if i < n else 0, "max": 1,
				"rang": _rang(prix), "de": str(it.get("from", "")), "phrase": str(it.get("blurb", ""))})
		out.append({"id": it.id, "nom": lieu, "n": n, "max": int(it.max), "cartes": parts})
	return out


## Les clubs d'un village, avec le topo complet de leurs parts : [{sport, club, nom, phrase, investi,
## cartes}], une carte par obligation : {id, kind « obligation », sport, club, nom, genre, rang_part,
## valeur, dividende, qui (« moi », « libre », « autre »), par, etat, rang, couleurs}.
func clubs(v: String) -> Array:
	var out: Array = []
	for sport in ["football", "basket"]:
		var moteur: Node = Football if sport == "football" else Basket
		if moteur.clubs.has(v):
			out.append(_club(sport, moteur, v))
	return out


func _club(sport: String, moteur: Node, club: String) -> Dictionary:
	var fiche: Dictionary = moteur.clubs.get(club, {})
	var brut: Array = fiche.get("couleurs", ["#14213d", "#d4a93a"])
	var couleurs := [_couleur(brut[0]), _couleur(brut[1] if brut.size() > 1 else "#ffffff")]
	var nom := str(fiche.get("nom", club))
	var cartes_club: Array = []
	for r in range(1, moteur.OBLIGATIONS.size() + 1):
		var p: Dictionary = moteur.porteur(club, r)
		var qui := "libre" if p.is_empty() else ("moi" if bool(p.moi) else "autre")
		var valeur: int = moteur.valeur(r)
		cartes_club.append({"id": "%s:%s:%d" % [sport, club, r], "kind": "obligation", "sport": sport, "club": club, "nom": nom,
			"genre": "Obligation n° %d" % r, "rang_part": r, "valeur": valeur, "dividende": _dividende(sport, club, r, valeur),
			"qui": qui, "par": str(p.get("nom", "")), "etat": qui, "rang": _rang(valeur), "couleurs": couleurs,
			"couleur": couleurs[0], "icone": sport, "n": 1 if qui == "moi" else 0, "max": 1})
	return {"sport": sport, "club": club, "nom": nom, "phrase": str(moteur.phrase_actionnaires(club)),
		"investi": int(moteur.investi(club)), "cartes": cartes_club}


## Ce qu'une obligation verse par journée jouée, au classement d'aujourd'hui.
func _dividende(sport: String, club: String, r: int, valeur: int) -> int:
	if sport == "football":
		return int(round(Football.dividende_de(r) * Football.recette_facteur(club)))
	var benefice := maxf(0.0, Basket.RECETTE * Basket.recette_facteur(club) - Basket.masse_salariale(club))
	return int(round(benefice * valeur / float(Basket.TOTAL)))


static func _couleur(v) -> Color:
	if v is Color:
		return v
	return Color.from_string(str(v), Color(0.1, 0.15, 0.3))


# --- La page d'un village -----------------------------------------------------------------------

func remplir() -> void:
	var vs := villages()
	if village == "" or not vs.any(func(x): return x.id == village):
		village = str(vs[0].id) if not vs.is_empty() else ""
	for c in _villages_box.get_children() + _page.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	for x in vs:
		_onglet_village(x, cartes(x.id).size())
	var liste := cartes(village)
	var estimation := 0
	for c in liste:
		for i in (int(c.n) if c.kind != "souvenir" else 0):
			estimation += int(round(Biens.price_of(str(c.id), i) * Biens.RESALE))
	_resume.text = "%d %s  ·  estimées %s" % [liste.size(), "carte" if liste.size() == 1 else "cartes", Game.fmt(estimation)]
	_affichees = []
	if liste.is_empty() and village == _origine():
		_mot(_page, "Pas encore de bien à %s." % _nom_commune(village), 18, INK_LIGHT)
		var t := _mot(_page, "Raymonde a des costumes, Roger Fradin une Mobylette, Maître Garnier des maisons. Chaque achat vient se coller ici.", 16, PENCIL)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# Les biens tiennent ensemble, rangés par genre : la couleur du bandeau dit le genre.
	var flot: HFlowContainer = null
	if not liste.is_empty():
		_categorie("Mes biens")
		flot = _flot()
	for c in liste:
		_ajouter(flot, c)
	# Les parts d'établissement : le topo complet, une carte par part.
	var etabs := etablissements(village)
	if not etabs.is_empty():
		_categorie("Les établissements")
		for e in etabs:
			_titre_section(str(e.nom), "%d à vous · %d en vente" % [int(e.n), int(e.max) - int(e.n)], _couleur_genre("part"))
			flot = _flot()
			for c in e.cartes:
				_ajouter(flot, c)
	# Les clubs : le topo complet, une carte par obligation.
	var cl := clubs(village)
	if not cl.is_empty():
		_categorie("Les clubs")
	for club in cl:
		var mien := (club.cartes as Array).filter(func(x): return x.qui == "moi").size()
		var autres := (club.cartes as Array).filter(func(x): return x.qui == "autre").size()
		var libres := (club.cartes as Array).size() - mien - autres
		_titre_section(str(club.nom), "%d à vous · %d à d'autres joueurs · %d en vente" % [mien, autres, libres], club.cartes[0].couleurs[0])
		var p := _mot(_page, str(club.phrase), 16, INK_LIGHT)
		p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		flot = _flot()
		for c in club.cartes:
			_ajouter(flot, c)
	if _zoom.visible and _affichees.is_empty():
		fermer_zoom()
	elif _zoom.visible:
		montrer(clampi(_index, 0, _affichees.size() - 1))


func _onglet_village(x: Dictionary, n: int) -> void:
	var actif: bool = x.id == village
	var b := Button.new()
	b.name = "Village_" + str(x.id)
	b.text = "%s  %d" % [x.nom, n]
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", _gras if actif else _texte)
	b.add_theme_font_size_override("font_size", 18)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, INK if actif or k == "font_hover_color" else INK_LIGHT)
	for k in ["normal", "hover", "pressed", "focus"]:
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.55, 0.68, 0.85, 0.18) if k == "hover" and not actif else Color(0, 0, 0, 0)
		st.content_margin_left = 10
		st.content_margin_right = 10
		st.content_margin_top = 2
		st.content_margin_bottom = 2
		st.border_width_bottom = 3 if actif else 0
		st.border_color = MARGIN_RED
		b.add_theme_stylebox_override(k, st)
	b.pressed.connect(choisir_village.bind(str(x.id)))
	_villages_box.add_child(b)


## Une catégorie de parts, soulignée à l'encre rouge comme un titre de cahier.
func _categorie(t: String) -> void:
	var bloc := VBoxContainer.new()
	bloc.add_theme_constant_override("separation", 2)
	_page.add_child(bloc)
	var haut := Control.new()
	haut.custom_minimum_size.y = 6
	bloc.add_child(haut)
	_mot(bloc, t, 24, INK, _gras)
	var souligne := ColorRect.new()
	souligne.color = MARGIN_RED
	souligne.custom_minimum_size = Vector2(0, 2)
	bloc.add_child(souligne)


func _titre_section(t: String, compte: String, couleur: Color) -> void:
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", 10)
	_page.add_child(tete)
	var pastille := ColorRect.new()
	pastille.color = couleur
	pastille.custom_minimum_size = Vector2(14, 14)
	pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tete.add_child(pastille)
	_mot(tete, t, 21, INK, _gras)
	_mot(tete, compte, 16, PENCIL).size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _flot() -> HFlowContainer:
	var flot := HFlowContainer.new()
	flot.add_theme_constant_override("h_separation", 14)
	flot.add_theme_constant_override("v_separation", 14)
	_page.add_child(flot)
	var bas := Control.new()
	bas.custom_minimum_size.y = 6
	_page.add_child(bas)
	return flot


func _ajouter(flot: HFlowContainer, c: Dictionary) -> void:
	var vue := CarteVue.new()
	vue.classeur = self
	vue.donnees = c
	vue.couleur = c.couleur
	vue.name = "Carte_" + str(c.id).replace("/", "_").replace(":", "_")
	var i := _affichees.size()
	vue.choisie.connect(func(): montrer(i))
	flot.add_child(vue)
	_affichees.append(c)


func choisir_village(id: String) -> void:
	village = id
	_index = -1
	remplir()
	_defile.scroll_vertical = 0


## Passe au village suivant (1) ou précédent (-1), en bouclant.
func tourner_village(sens: int) -> void:
	var ids: Array = villages().map(func(x): return x.id)
	if ids.is_empty():
		return
	choisir_village(ids[posmod(ids.find(village) + sens, ids.size())])


## Les touches du classeur, avant celles du carnet : vrai si elle est prise.
func saisir(event: InputEvent) -> bool:
	if not (event is InputEventKey and event.pressed):
		return false
	if _zoom.visible:
		if event.is_action_pressed("ui_cancel"):
			fermer_zoom()
			return true
		if event.keycode in [KEY_LEFT, KEY_RIGHT]:
			montrer(posmod(_index + (1 if event.keycode == KEY_RIGHT else -1), _affichees.size()))
			return true
		return false
	if event.keycode in [KEY_UP, KEY_DOWN] and not event.echo:
		tourner_village(1 if event.keycode == KEY_DOWN else -1)
		return true
	return false


func zoom_ouvert() -> bool:
	return _zoom.visible


# --- La carte en grand ------------------------------------------------------------------------

func montrer(i: int) -> void:
	if i < 0 or i >= _affichees.size():
		return
	var nouveau := not _zoom.visible
	_index = i
	for c in _zoom_boite.get_children():
		_zoom_boite.remove_child(c)
		c.queue_free()
	var c: Dictionary = _affichees[i]
	_fleche(_zoom_boite, "←", -1)
	var vue := CarteVue.new()
	vue.classeur = self
	vue.donnees = c
	vue.couleur = c.couleur
	vue.k = ZOOM
	vue.fixe = true
	vue.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_zoom_boite.add_child(vue)
	_zoom_boite.add_child(_fiche(c))
	_fleche(_zoom_boite, "→", 1)
	_zoom.visible = true
	if nouveau:
		vue.pivot_offset = CARTE * ZOOM / 2.0
		vue.scale = Vector2(0.86, 0.86)
		_zoom.modulate.a = 0.0
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(vue, "scale", Vector2.ONE, 0.22)
		tw.tween_property(_zoom, "modulate:a", 1.0, 0.16)


func fermer_zoom() -> void:
	_zoom.visible = false
	ferme_zoom.emit()


func _fleche(parent: Control, t: String, sens: int) -> void:
	var b := Button.new()
	b.text = t
	b.name = "Precedente" if sens < 0 else "Suivante"
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(52, 52)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_override("font", _gras)
	b.add_theme_font_size_override("font_size", 26)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, INK if k != "font_hover_color" else RED_INK)
	for k in ["normal", "hover", "pressed", "focus"]:
		var st := StyleBoxFlat.new()
		st.bg_color = PAPER if k != "hover" else PAPER.darkened(0.05)
		st.set_corner_radius_all(26)
		st.shadow_color = Color(0, 0, 0, 0.25)
		st.shadow_size = 4
		b.add_theme_stylebox_override(k, st)
	b.disabled = _affichees.size() < 2
	b.pressed.connect(func(): montrer(posmod(_index + sens, _affichees.size())))
	parent.add_child(b)


## La fiche à côté de la carte en grand, sur une fiche de papier : ce que vaut la carte, ce qu'elle
## rapporte, où l'acheter, et les gestes sans prix.
func _fiche(c: Dictionary) -> Control:
	var panneau := PanelContainer.new()
	panneau.custom_minimum_size = Vector2(430, 0)
	panneau.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var st := StyleBoxFlat.new()
	st.bg_color = PAPER
	st.set_corner_radius_all(4)
	st.set_content_margin_all(22)
	st.content_margin_left = 26
	st.border_color = MARGIN_RED
	st.border_width_left = 3
	st.shadow_color = Color(0, 0, 0, 0.35)
	st.shadow_size = 12
	panneau.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	panneau.add_child(v)
	var obligation: bool = c.kind == "obligation"
	var nom := _mot(v, str(c.nom), 26, INK, _gras)
	nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nom.custom_minimum_size.x = 380
	_mot(v, "%s  ·  carte %s" % [c.genre, NOMS_RANGS[int(c.rang)]], 16, PENCIL)
	if str(c.get("phrase", "")) != "":
		var q := _mot(v, str(c.phrase) + ("  — " + str(c.de) if str(c.de) != "" else ""), 16, INK_LIGHT)
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		q.custom_minimum_size.x = 380
	_filet(v)
	if obligation:
		_fiche_obligation(v, c)
	elif c.kind == "part_etab":
		_fiche_part(v, c)
	elif c.kind == "souvenir":
		_mot(v, "Posé ou rangé chez vous : il ne se vend ni ne se saisit.", 16, INK_LIGHT).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		_fiche_bien(v, c)
	return panneau


func _filet(v: VBoxContainer) -> void:
	var r := ColorRect.new()
	r.color = Color(0.55, 0.68, 0.85, 0.5)
	r.custom_minimum_size.y = 1
	v.add_child(r)


## Une ligne de compte, comme au carnet : le libellé à gauche, le chiffre à droite.
func _ligne(v: VBoxContainer, a: String, b: String, couleur := INK) -> void:
	var h := HBoxContainer.new()
	v.add_child(h)
	var l := _mot(h, a, 17, INK_LIGHT)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mot(h, b, 17, couleur, _gras)


func _fiche_bien(v: VBoxContainer, c: Dictionary) -> void:
	var id := str(c.id)
	var it := Biens.item(id)
	var n := int(c.n)
	if int(c.max) > 1:
		_ligne(v, "Exemplaires", "%d / %d" % [n, int(c.max)])
	if c.rente > 0:
		_ligne(v, "Rente annoncée, par recette", Game.fmt(int(c.rente) * n))
	if c.charge > 0:
		_ligne(v, "Charges, par recette", Game.fmt(int(c.charge) * n))
	if c.standing > 0:
		_ligne(v, "Standing", "+%d" % (int(c.standing) * n))
	var reprise := 0
	for i in n:
		reprise += int(round(Biens.price_of(id, i) * Biens.RESALE))
	_ligne(v, "Estimation à la revente", Game.fmt(reprise))
	if n < int(c.max):
		_ligne(v, "Prix du suivant", Game.fmt(int(c.prix)), RED_INK)
	# L'état, et les gestes sans prix.
	if c.kind == "tenue":
		if Biens.worn == id:
			_mot(v, "Vous la portez.", 16, PENCIL)
		else:
			_geste(v, "la porter", func(): Biens.wear(id))
	elif c.kind == "vehicule":
		if Biens.driven == id:
			_mot(v, "Au garage de la place : c'est elle que vous prenez.", 16, PENCIL)
		else:
			_geste(v, "la prendre", func(): Biens.wear(id))
	elif Biens.logements.has(id):
		var habitee := Biens.is_habite(id)
		_mot(v, "Vous y habitez : elle ne verse pas de rente, mais compte double en standing." if habitee else "Louée : elle verse sa rente à chaque recette.", 16, PENCIL).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_geste(v, "la remettre en location" if habitee else "m'y installer", func():
			if habitee:
				Biens.louer(id)
			else:
				Biens.habiter(id))
		_geste(v, "y aller", func(): _quitter(func(): Biens.enter(id)))
	elif c.kind == "meuble":
		var pose := Biens.placed_count(id)
		_mot(v, "%d posé%s chez vous, %d au carton ou au grenier." % [pose, "s" if pose > 1 else "", n - pose], 16, PENCIL)
	if n < int(c.max):
		var vendeur: Dictionary = Biens.SELLERS.get(str(c.vendeur), {})
		var o: Commune = Communes.origine()
		if str(it.get("commune", "")) != "" and (o == null or str(it.commune) != o.id):
			_mot(v, "Le suivant, chez le notaire de %s, sur place." % _nom_commune(str(it.commune)), 16, PENCIL)
		elif not vendeur.is_empty():
			var page = carnet.page_origine() if carnet != null else null
			if page != null and page.has_method("go_to"):
				_geste(v, "le suivant : %s" % str(vendeur.name), func(): page.go_to(str(c.vendeur)))


func _fiche_part(v: VBoxContainer, c: Dictionary) -> void:
	var id := str(c.bien)
	var n := Biens.count(id)
	var it := Biens.item(id)
	_ligne(v, "Parts tenues", "%d / %d" % [n, int(it.max)])
	_ligne(v, "Rente annoncée de cette part, par recette", Game.fmt(int(c.rente)))
	if int(c.standing) > 0:
		_ligne(v, "Standing", "+%d" % int(c.standing))
	if c.etat == "moi":
		_ligne(v, "Estimation à la revente", Game.fmt(int(round(int(c.prix) * Biens.RESALE))))
		_mot(v, "Elle est à vous.", 16, PENCIL)
	else:
		_ligne(v, "Prix de cette part", Game.fmt(int(c.prix)), RED_INK)
		var avant := int(c.numero) - 1 - n
		_mot(v, "En vente chez Maître Garnier%s." % ("" if avant <= 0 else ", après %d autre%s" % [avant, "s" if avant > 1 else ""]), 16, RED_INK)
		var page = carnet.page_origine() if carnet != null else null
		if page != null and page.has_method("go_to") and Biens.SELLERS.has(str(it.get("seller", ""))):
			_geste(v, "y aller", func(): page.go_to(str(it.seller)))


func _fiche_obligation(v: VBoxContainer, c: Dictionary) -> void:
	var foot: bool = c.sport == "football"
	var moteur: Node = Football if foot else Basket
	_ligne(v, "Valeur", Game.fmt(int(c.valeur)))
	_ligne(v, "Dividende par journée jouée, aujourd'hui", "≈ " + Game.fmt(int(c.dividende)))
	match str(c.qui):
		"moi":
			_ligne(v, "Reprise si vous la rendez", Game.fmt(int(round(int(c.valeur) * moteur.RACHAT))))
			_mot(v, "Elle est à vous.", 16, PENCIL)
		"autre":
			_mot(v, "Tenue par %s." % str(c.par), 16, PENCIL)
		_:
			_mot(v, "En vente : elle est libre, le premier qui la prend l'a.", 16, RED_INK)
	_filet(v)
	var p := _mot(v, str(moteur.phrase_actionnaires(str(c.club))), 16, INK_LIGHT)
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.custom_minimum_size.x = 380
	var ou := "Les obligations libres se prennent à l'étude de Maître Garnier, ou dans les locaux du club." if foot \
		else "Les obligations libres se prennent au tableau des parts, à l'entrée du grand hall de la salle."
	var l := _mot(v, ou, 16, PENCIL)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 380
	var page = carnet.page_origine() if carnet != null else null
	if foot and page != null and page.has_method("go_to") and Biens.SELLERS.has("notaire"):
		_geste(v, "aller chez le notaire", func(): page.go_to("notaire"))


## Un geste, à l'encre rouge comme les liens du carnet.
func _geste(parent: Control, t: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = "→ " + t
	b.name = "Geste_" + t.replace(" ", "_").replace("'", "")
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size.y = 40
	b.add_theme_font_override("font", _texte)
	b.add_theme_font_size_override("font_size", 18)
	b.add_theme_color_override("font_color", RED_INK)
	b.add_theme_color_override("font_hover_color", Color(0.85, 0.2, 0.2))
	b.add_theme_color_override("font_pressed_color", Color(0.85, 0.2, 0.2))
	b.pressed.connect(func():
		action.call()
		if is_inside_tree() and _zoom.visible:
			remplir())
	parent.add_child(b)
	return b


## Ferme le carnet avant d'aller quelque part.
func _quitter(aller: Callable) -> void:
	if carnet != null and carnet.is_open():
		carnet.toggle()
	aller.call()


# --- Les dessins --------------------------------------------------------------------------------

## Une carte : le titre de propriété, dessiné à la main. k agrandit tout (la carte en grand).
class CarteVue extends Control:
	signal choisie

	var classeur = null
	var donnees := {}
	var couleur := Color.WHITE
	var k := 1.0
	## La carte en grand ne bouge pas au survol.
	var fixe := false
	var _survol := false
	var _tw: Tween
	var _reflet := 0.0

	func _ready() -> void:
		custom_minimum_size = CARTE * k
		size = custom_minimum_size
		pivot_offset = custom_minimum_size / 2.0
		mouse_filter = Control.MOUSE_FILTER_STOP if not fixe else Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(_survoler.bind(true))
		mouse_exited.connect(_survoler.bind(false))
		set_process(_brille())
		# Les reflets ne passent pas tous en même temps.
		_reflet = fposmod(float(hash(str(donnees.get("id", "")))) / 997.0, 1.0)

	func _brille() -> bool:
		return donnees.get("etat") == "moi" and int(donnees.get("rang", 0)) >= 3

	func _process(delta: float) -> void:
		_reflet = fposmod(_reflet + delta / 3.2, 1.0)
		queue_redraw()

	func _survoler(dedans: bool) -> void:
		if fixe:
			return
		_survol = dedans
		z_index = 1 if dedans else 0
		if _tw:
			_tw.kill()
		_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tw.tween_property(self, "scale", Vector2(1.07, 1.07) if dedans else Vector2.ONE, 0.14)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if fixe:
			return
		if (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) \
				or (event is InputEventScreenTouch and not event.pressed):
			choisie.emit()
			accept_event()

	func _boite(r: Rect2, fond: Color, rayon: float, bord := Color.TRANSPARENT, epaisseur := 0.0, ombre := 0.0) -> void:
		var st := StyleBoxFlat.new()
		st.bg_color = fond
		st.set_corner_radius_all(int(rayon))
		if epaisseur > 0.0:
			st.border_color = bord
			st.set_border_width_all(int(epaisseur))
		if ombre > 0.0:
			st.shadow_color = Color(0.2, 0.15, 0.1, 0.3)
			st.shadow_size = int(ombre)
			st.shadow_offset = Vector2(1, ombre / 3.0)
		draw_style_box(st, r)

	func _ecrire(t: String, centre_haut: Vector2, largeur: float, taille: float, c: Color, gras := false, lignes := 1) -> void:
		var police: Font = classeur._gras if gras else classeur._texte
		var fs := int(round(taille * k))
		var pos := Vector2(centre_haut.x - largeur / 2.0, centre_haut.y + police.get_ascent(fs))
		draw_multiline_string(police, pos, t, HORIZONTAL_ALIGNMENT_CENTER, largeur, fs, lignes, c,
			TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND, TextServer.JUSTIFICATION_NONE)

	func _draw() -> void:
		var d := donnees
		var w := size.x
		var h := size.y
		var rang: int = int(d.get("rang", 0))
		var bord: Color = RANGS[rang]
		var obligation: bool = d.kind == "obligation"
		var bande: Color = d.couleurs[0] if obligation else couleur
		var encre_bande: Color = d.couleurs[1] if obligation else (Color(0.1, 0.08, 0.06) if bande.get_luminance() > 0.55 else Color.WHITE)
		if obligation and absf(bande.get_luminance() - encre_bande.get_luminance()) < 0.3:
			encre_bande = Color.WHITE if bande.get_luminance() < 0.5 else Color(0.1, 0.08, 0.06)
		_boite(Rect2(0, 0, w, h), VISAGE, 10 * k, bord, (5 if rang >= 2 else 4) * k, (10 if _survol else 5) * k)
		# Le bandeau de couleur, et le nom dedans.
		var m := 9.0 * k
		var bh := 52.0 * k
		_boite(Rect2(m, m, w - 2 * m, bh), bande, 5 * k)
		var titre_h: float = classeur._gras.get_multiline_string_size(str(d.nom), HORIZONTAL_ALIGNMENT_CENTER, w - 2 * m - 10 * k, int(round(14 * k)), 2).y
		_ecrire(str(d.nom), Vector2(w / 2.0, m + (bh - titre_h) / 2.0), w - 2 * m - 10 * k, 14, encre_bande, true, 2)
		var y := m + bh + 6 * k
		# L'image : un rond teinté, et le dessin du genre de bien (un ballon pour une part de club).
		var c := Vector2(w / 2.0, y + 36 * k)
		draw_circle(c, 33 * k, bande.lerp(Color.WHITE, 0.8))
		draw_arc(c, 33 * k, 0, TAU, 48, bande.lerp(Color.WHITE, 0.55), 1.5 * k, true)
		Icones.dessiner(self, str(d.icone), c, 21 * k, bande.darkened(0.25))
		y += 76 * k
		_ecrire(str(d.genre), Vector2(w / 2.0, y), w - 16 * k, 10.5 if not obligation else 12, Color(0.42, 0.4, 0.36), obligation, 2)
		y += 30 * k
		if obligation:
			_stats([["valeur", Game.fmt(int(d.valeur))], ["par journée", "≈ " + Game.fmt(int(d.dividende))]], y, w)
		else:
			_stats([["rente", Game.fmt(int(d.rente)) if int(d.rente) > 0 else "—"], ["charges", Game.fmt(int(d.charge)) if int(d.charge) > 0 else "—"],
				["standing", "+%d" % int(d.standing) if int(d.standing) > 0 else "—"]], y, w)
		# Le pied : à qui elle est, ou les exemplaires.
		var pied := h - 22 * k
		if obligation or d.kind == "part_etab":
			if d.etat == "moi":
				_ecrire("à vous", Vector2(w / 2.0, pied - 2 * k), w - 16 * k, 12, bande.darkened(0.2), true)
		elif int(d.max) > 1:
			var n := int(d.max)
			var pas := 13.0 * k
			var x0 := w / 2.0 - pas * (n - 1) / 2.0
			for i in n:
				var p := Vector2(x0 + i * pas, pied + 6 * k)
				if i < int(d.n):
					draw_circle(p, 4.6 * k, couleur.darkened(0.15))
				else:
					draw_arc(p, 4.2 * k, 0, TAU, 20, Color(0.6, 0.57, 0.5), 1.4 * k, true)
		else:
			_ecrire("à vous", Vector2(w / 2.0, pied - 2 * k), w - 16 * k, 12, couleur.darkened(0.3), true)
		# Le rang, en losange dans le coin.
		if d.etat == "moi":
			var g := Vector2(w - 14 * k, h - 14 * k)
			var lo := 4.5 * k
			draw_colored_polygon(PackedVector2Array([g + Vector2(0, -lo), g + Vector2(lo, 0), g + Vector2(0, lo), g + Vector2(-lo, 0)]), bord.darkened(0.1))
		# Plusieurs exemplaires : la pastille du nombre.
		if int(d.n) > 1:
			var b := Vector2(w - 12 * k, 12 * k)
			draw_circle(b, 12 * k, Color(0.12, 0.1, 0.08))
			draw_arc(b, 12 * k, 0, TAU, 24, OR, 1.5 * k, true)
			_ecrire("×%d" % int(d.n), Vector2(b.x, b.y - 8.5 * k), 30 * k, 12, Color.WHITE, true)
		# Une part en vente est pâlie, avec son prix ; celle d'un autre joueur porte son nom.
		# L'étiquette se pose au pied, sous les chiffres.
		var et := Rect2(12 * k, h - 32 * k, w - 24 * k, 24 * k)
		if d.etat == "libre":
			_boite(Rect2(2 * k, 2 * k, w - 4 * k, h - 4 * k), Color(0.99, 0.97, 0.92, 0.45), 9 * k)
			_boite(et, RED_INK, 12 * k)
			_ecrire("en vente · %s" % Game.fmt(int(d.get("valeur", d.get("prix", 0)))), Vector2(w / 2.0, et.position.y + 4 * k), et.size.x - 6 * k, 12, Color.WHITE, true)
		elif d.etat == "autre":
			_boite(Rect2(2 * k, 2 * k, w - 4 * k, h - 4 * k), Color(0.36, 0.42, 0.5, 0.25), 9 * k)
			_boite(et, ARDOISE, 12 * k)
			_ecrire("à " + str(d.par), Vector2(w / 2.0, et.position.y + 4 * k), et.size.x - 6 * k, 12, Color.WHITE, true)
		elif _brille():
			_reflet_passe(w, h)

	## Les chiffres d'une carte, en colonnes : [[libellé, valeur], …].
	func _stats(cols: Array, y: float, w: float) -> void:
		var lw := (w - 16 * k) / float(cols.size())
		for i in cols.size():
			var cx := 8 * k + lw * (i + 0.5)
			_ecrire(cols[i][0], Vector2(cx, y), lw, 9.5, Color(0.5, 0.47, 0.42))
			_ecrire(cols[i][1], Vector2(cx, y + 13 * k), lw, 14, Color(0.15, 0.13, 0.1), true)
			if i > 0:
				draw_line(Vector2(8 * k + lw * i, y + 2 * k), Vector2(8 * k + lw * i, y + 30 * k), Color(0, 0, 0, 0.12), 1.0)

	## Le reflet des cartes de prestige : une bande claire qui traverse la carte.
	func _reflet_passe(w: float, h: float) -> void:
		var x := lerpf(-w * 0.8, w * 1.8, _reflet)
		var bande := PackedVector2Array([Vector2(x, 0), Vector2(x + 26 * k, 0), Vector2(x + 26 * k - h * 0.45, h), Vector2(x - h * 0.45, h)])
		var carte := PackedVector2Array([Vector2(3 * k, 3 * k), Vector2(w - 3 * k, 3 * k), Vector2(w - 3 * k, h - 3 * k), Vector2(3 * k, h - 3 * k)])
		for p in Geometry2D.intersect_polygons(bande, carte):
			draw_colored_polygon(p, Color(1, 1, 1, 0.22))


## Les dessins des genres de biens, au trait plein, centrés sur c, dans un carré de demi-côté r.
class Icones:
	static func dessiner(ci: CanvasItem, genre: String, c: Vector2, r: float, col: Color) -> void:
		var clair := col.lerp(Color.WHITE, 0.55)
		match genre:
			"part":
				# Trois pièces empilées.
				for i in 3:
					var p := c + Vector2(-r * 0.15 + i * r * 0.15, r * 0.45 - i * r * 0.42)
					ci.draw_set_transform(p, 0, Vector2(1, 0.42))
					ci.draw_circle(Vector2.ZERO, r * 0.72, col)
					ci.draw_arc(Vector2.ZERO, r * 0.52, 0, TAU, 32, clair, r * 0.08)
					ci.draw_set_transform(Vector2.ZERO)
			"maison":
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, -r * 0.05), c + Vector2(0, -r * 0.95), c + Vector2(r, -r * 0.05)]), col)
				ci.draw_rect(Rect2(c + Vector2(-r * 0.75, -r * 0.1), Vector2(r * 1.5, r * 1.0)), col)
				ci.draw_rect(Rect2(c + Vector2(-r * 0.18, r * 0.35), Vector2(r * 0.36, r * 0.55)), clair)
				ci.draw_rect(Rect2(c + Vector2(r * 0.3, r * 0.08), Vector2(r * 0.28, r * 0.24)), clair)
				ci.draw_rect(Rect2(c + Vector2(-r * 0.58, r * 0.08), Vector2(r * 0.28, r * 0.24)), clair)
			"murs":
				# Une devanture et son store rayé.
				ci.draw_rect(Rect2(c + Vector2(-r * 0.85, -r * 0.3), Vector2(r * 1.7, r * 1.2)), col)
				for i in 5:
					var x := -r * 0.95 + i * r * 0.38
					ci.draw_colored_polygon(PackedVector2Array([c + Vector2(x, -r * 0.85), c + Vector2(x + r * 0.38, -r * 0.85),
						c + Vector2(x + r * 0.38, -r * 0.35), c + Vector2(x, -r * 0.35)]), col if i % 2 == 0 else clair)
				ci.draw_rect(Rect2(c + Vector2(-r * 0.65, -r * 0.1), Vector2(r * 0.7, r * 0.55)), clair)
				ci.draw_rect(Rect2(c + Vector2(r * 0.2, -r * 0.1), Vector2(r * 0.4, r * 1.0)), clair)
			"public":
				# Un fronton et ses colonnes.
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, -r * 0.45), c + Vector2(0, -r * 0.95), c + Vector2(r, -r * 0.45)]), col)
				ci.draw_rect(Rect2(c + Vector2(-r, -r * 0.42), Vector2(r * 2, r * 0.16)), col)
				for i in 4:
					ci.draw_rect(Rect2(c + Vector2(-r * 0.8 + i * r * 0.48, -r * 0.2), Vector2(r * 0.2, r * 0.9)), col)
				ci.draw_rect(Rect2(c + Vector2(-r, r * 0.72), Vector2(r * 2, r * 0.2)), col)
			"tenue":
				# Une veste, son col et sa cravate.
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.35, -r * 0.9), c + Vector2(-r * 0.95, -r * 0.6), c + Vector2(-r * 0.8, r * 0.95),
					c + Vector2(r * 0.8, r * 0.95), c + Vector2(r * 0.95, -r * 0.6), c + Vector2(r * 0.35, -r * 0.9), c + Vector2(0, -r * 0.2)]), col)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.32, -r * 0.88), c + Vector2(0, -r * 0.2), c + Vector2(r * 0.32, -r * 0.88)]), clair)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.09, -r * 0.62), c + Vector2(r * 0.09, -r * 0.62), c + Vector2(r * 0.12, r * 0.2),
					c + Vector2(0, r * 0.35), c + Vector2(-r * 0.12, r * 0.2)]), col.darkened(0.3))
			"vehicule":
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r, r * 0.35), c + Vector2(-r, -r * 0.05), c + Vector2(-r * 0.55, -r * 0.15),
					c + Vector2(-r * 0.3, -r * 0.6), c + Vector2(r * 0.4, -r * 0.6), c + Vector2(r * 0.65, -r * 0.15), c + Vector2(r, -r * 0.05), c + Vector2(r, r * 0.35)]), col)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.42, -r * 0.18), c + Vector2(-r * 0.24, -r * 0.48), c + Vector2(r * 0.34, -r * 0.48), c + Vector2(r * 0.5, -r * 0.18)]), clair)
				for x in [-0.55, 0.55]:
					ci.draw_circle(c + Vector2(r * x, r * 0.38), r * 0.27, col.darkened(0.35))
					ci.draw_circle(c + Vector2(r * x, r * 0.38), r * 0.11, clair)
			"meuble":
				# Un fauteuil club.
				ci.draw_rect(Rect2(c + Vector2(-r * 0.6, -r * 0.75), Vector2(r * 1.2, r * 0.9)), col)
				ci.draw_rect(Rect2(c + Vector2(-r * 0.95, -r * 0.25), Vector2(r * 0.4, r * 0.95)), col.darkened(0.15))
				ci.draw_rect(Rect2(c + Vector2(r * 0.55, -r * 0.25), Vector2(r * 0.4, r * 0.95)), col.darkened(0.15))
				ci.draw_rect(Rect2(c + Vector2(-r * 0.55, r * 0.1), Vector2(r * 1.1, r * 0.45)), clair)
				ci.draw_rect(Rect2(c + Vector2(-r * 0.85, r * 0.7), Vector2(r * 0.18, r * 0.25)), col.darkened(0.35))
				ci.draw_rect(Rect2(c + Vector2(r * 0.67, r * 0.7), Vector2(r * 0.18, r * 0.25)), col.darkened(0.35))
			"souvenir":
				var pts := PackedVector2Array()
				for i in 10:
					var a := -PI / 2.0 + i * PI / 5.0
					pts.append(c + Vector2(cos(a), sin(a)) * (r if i % 2 == 0 else r * 0.42))
				ci.draw_colored_polygon(pts, col)
			"football":
				ci.draw_circle(c, r, Color.WHITE)
				ci.draw_arc(c, r, 0, TAU, 40, col, r * 0.1, true)
				var p := PackedVector2Array()
				for i in 5:
					var a := -PI / 2.0 + i * TAU / 5.0
					p.append(c + Vector2(cos(a), sin(a)) * r * 0.38)
				ci.draw_colored_polygon(p, col)
			"basket":
				ci.draw_circle(c, r, Color(0.9, 0.5, 0.15))
				ci.draw_line(c + Vector2(-r, 0), c + Vector2(r, 0), col, r * 0.08)
				ci.draw_line(c + Vector2(0, -r), c + Vector2(0, r), col, r * 0.08)
				ci.draw_arc(c + Vector2(-r * 1.1, 0), r * 0.8, -PI / 3.0, PI / 3.0, 20, col, r * 0.08)
				ci.draw_arc(c + Vector2(r * 1.1, 0), r * 0.8, PI * 2.0 / 3.0, PI * 4.0 / 3.0, 20, col, r * 0.08)
