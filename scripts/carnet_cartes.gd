extends Control
## Le classeur de cartes du carnet (onglet « Mes cartes ») : ce qu'on possède, en cartes à collectionner
## façon titre de propriété du Monopoly, collées sur le papier quadrillé du carnet. Les villages s'empilent
## de haut en bas : la commune d'origine d'abord, puis chaque commune (Casino Minuit, à Las Vegas, en est
## une) où l'on tient un bien ou des parts de club. Demande de Guillaume du 20 octobre.
##
## Chaque village a trois rubriques :
## - « Mes biens » : seulement les cartes qu'on possède, rangées par genre (les maisons, les murs, la
##   garde-robe, le garage, la brocante, les souvenirs), chaque genre de sa couleur. La bordure dit le
##   rang du bien, du bronze au prestige, selon son prix ; les cartes de prestige ont un reflet qui passe.
## - « Mes clubs sportifs » : chaque club dont on tient au moins une obligation, avec le topo complet de
##   ses neuf obligations, à soi, en vente, ou tenues par un autre joueur (son nom dessus).
## - « Mes établissements » : chaque établissement dont on tient au moins une part (le café, le moulin,
##   la salle des fêtes du comité…), avec le topo complet de ses parts, à soi ou en vente.
## La commune d'origine s'ouvre sur « Mon parcours » (les quatre marches de l'investisseur, de la première
## part au second club) ; sous chaque club, ce qu'il manque pour le diriger (scripts/socle/diriger.gd). Les
## cartes qu'on tient sont en grand, les places à compléter en petit (demande de Guillaume du 23 octobre).
## Une rubrique vide dit où aller pour l'acheter : rien ne s'achète ici, et seuls les gestes sans prix
## (porter, conduire, habiter, louer) se font depuis le classeur.
##
## À l'entrée des clubs, le même classeur montre les cartes d'un seul club (seul_club).
##
## Navigation : la molette ou le doigt font défiler, ↑ ↓ sautent d'un village à l'autre, comme les noms
## de village de la tête ; un clic montre une carte en grand avec sa fiche, ← → passent à la voisine,
## Échap la repose.

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
const DIRIGER := preload("res://scripts/socle/diriger.gd")
## La taille des places à compléter (en vente, à d'autres joueurs), à côté des cartes qu'on tient.
const K_PLACE := 0.66

## Le carnet, qui tient le classeur.
var carnet = null
## Le village qu'on regarde, en haut de la page (« » : la commune d'origine).
var village := ""
## Un seul club, à l'entrée du club : {sport, club}. Vide : le classeur entier.
var seul_club := {}
var _titre: Label
var _villages_box: HBoxContainer
## Le titre de chaque village dans la page, pour y sauter : {id: Control}.
var _ancres := {}
## Les noms de village de la tête : {id: Button}.
var _boutons_village := {}
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
	_titre = _mot(tete, "Mes cartes", 26, INK, _gras)
	_titre.size_flags_vertical = Control.SIZE_SHRINK_END
	_villages_box = HBoxContainer.new()
	_villages_box.add_theme_constant_override("separation", 6)
	_villages_box.size_flags_vertical = Control.SIZE_SHRINK_END
	tete.add_child(_villages_box)
	_resume = _mot(tete, "", 16, PENCIL)
	_resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_resume.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_resume.size_flags_vertical = Control.SIZE_SHRINK_END
	_defile = ScrollContainer.new()
	_defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_defile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_defile.get_v_scroll_bar().value_changed.connect(func(_v): _suivre_defilement())
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


## Les établissements d'un village dont on tient au moins une part, avec le topo complet : une carte par
## part, à soi ou en vente. [{id, nom, n, max, cartes}] ; une carte : {id, kind « part_etab », bien, nom, genre, prix, rente, charge, standing,
## etat (« moi », « libre »), rang, de, phrase}.
func etablissements(v: String) -> Array:
	var o: Commune = Communes.origine()
	var out: Array = []
	for it in Biens.catalogue():
		if it.kind != "part" or _village_de(it) != v:
			continue
		var n := Biens.count(it.id)
		if n <= 0:
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
	for c in _villages_box.get_children() + _page.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	_affichees = []
	_ancres = {}
	_boutons_village = {}
	if not seul_club.is_empty():
		_remplir_club()
	else:
		var vs := villages()
		if village == "" or not vs.any(func(x): return x.id == village):
			village = str(vs[0].id) if not vs.is_empty() else ""
		_titre.text = "Mes cartes"
		_villages_box.visible = vs.size() > 1
		for x in vs:
			if vs.size() > 1:
				_onglet_village(x)
			_village(x)
		var miennes := _affichees.filter(func(c): return c.etat == "moi")
		_resume.text = "%d %s  ·  estimées %s" % [miennes.size(), "carte" if miennes.size() == 1 else "cartes", Game.fmt(_estimation(miennes))]
	if _zoom.visible and _affichees.is_empty():
		fermer_zoom()
	elif _zoom.visible:
		montrer(clampi(_index, 0, _affichees.size() - 1))


## Ce que valent à la revente les cartes qu'on tient : le prix de reprise des biens et des parts, le
## rachat des obligations.
func _estimation(liste: Array) -> int:
	var total := 0
	for c in liste:
		match str(c.kind):
			"souvenir":
				pass
			"part_etab":
				total += int(round(int(c.prix) * Biens.RESALE))
			"obligation":
				total += int(round(int(c.valeur) * (Football if c.sport == "football" else Basket).RACHAT))
			_:
				for i in int(c.n):
					total += int(round(Biens.price_of(str(c.id), i) * Biens.RESALE))
	return total


## Un village : son titre, puis ses trois rubriques. Une rubrique vide dit où aller.
func _village(x: Dictionary) -> void:
	var id := str(x.id)
	var origine := id == _origine()
	_tete_village(x)
	if origine:
		_parcours()
	# Mes biens, ensemble, rangés par genre : la couleur du bandeau dit le genre.
	_categorie("Mes biens")
	var liste := cartes(id)
	if liste.is_empty():
		_vide("Pas encore de bien ici. " + ("Raymonde a des costumes, Roger Fradin une Mobylette, Maître Garnier des maisons : chaque achat vient se coller ici." if origine \
			else "Le notaire de %s, sur place, a les adresses à vendre." % str(x.nom)))
	else:
		var flot := _flot()
		for c in liste:
			_ajouter(flot, c)
	# Mes clubs sportifs : ceux dont on tient une obligation, avec le topo complet.
	_categorie("Mes clubs sportifs")
	var tous := clubs(id)
	var miens := tous.filter(func(cl): return (cl.cartes as Array).any(func(c): return c.qui == "moi"))
	if miens.is_empty():
		var ou := []
		for cl in tous:
			ou.append("%s, %s" % [str(cl.nom), "à l'étude du notaire ou dans les locaux du club" if cl.sport == "football" else "au tableau des parts, à l'entrée de la salle"])
		_vide("Aucune obligation de club. " + ("Elles se prennent : " + " ; ".join(ou) + "." if not ou.is_empty() else "Il n'y a pas encore de club au championnat ici."))
	for club in miens:
		var mien := (club.cartes as Array).filter(func(c): return c.qui == "moi").size()
		var autres := (club.cartes as Array).filter(func(c): return c.qui == "autre").size()
		var libres := (club.cartes as Array).size() - mien - autres
		_titre_section(str(club.nom), "%d à vous · %d à d'autres joueurs · %d en vente" % [mien, autres, libres], club.cartes[0].couleurs[0])
		var p := _mot(_page, str(club.phrase), 16, INK_LIGHT)
		p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var verse := 0
		for c in club.cartes:
			if c.qui == "moi":
				verse += int(c.dividende)
		var d := _mot(_page, DIRIGER.phrase(Football if club.sport == "football" else Basket, str(club.club)), 16, INK, _gras)
		d.name = "PourDiriger_" + str(club.sport)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_mot(_page, "Vos obligations versent environ %s crédits par journée jouée." % Game.fmt(verse), 16, INK_LIGHT)
		_cartes_et_places(club.cartes, "qui", "%d en vente · %d à d'autres joueurs" % [libres, autres])
	# Mes établissements : ceux dont on tient une part, avec le topo complet.
	_categorie("Mes établissements")
	var etabs := etablissements(id)
	if etabs.is_empty():
		_vide("Aucune part d'établissement. " + ("Maître Garnier, à l'étude, vend des parts du café, du moulin et des autres maisons du village." if origine \
			else "Le notaire de %s les vend sur place." % str(x.nom)))
	for e in etabs:
		_titre_section(str(e.nom), "%d à vous · %d en vente" % [int(e.n), int(e.max) - int(e.n)], _couleur_genre("part"))
		var rente := 0
		for c in e.cartes:
			if c.etat == "moi":
				rente += int(c.rente)
		_mot(_page, "Vos parts annoncent %s crédits de rente à chaque recette (toutes les %d mises)." % [Game.fmt(rente), Biens.PERIOD], 16, INK_LIGHT)
		_cartes_et_places(e.cartes, "etat", "%d en vente" % (int(e.max) - int(e.n)))


# --- Le parcours ---------------------------------------------------------------------------------

## Les quatre marches de l'investisseur, de la première part au second club, pour la commune d'origine
## (demande de Guillaume du 23 octobre : une gestion accessible dès les premiers gains, où l'on progresse).
## [{id, titre, texte, etat}] ; etat : « fait », « suivant » (la première marche à faire, ouverte),
## « ouvert », « ferme » (son lieu n'est pas encore ouvert). La marche suivante peut mener chez Maître
## Garnier (aller : « notaire »).
func parcours() -> Array:
	var o: Commune = Communes.origine()
	var v := str(o.id)
	var out: Array = []
	# 1. Une part d'établissement.
	var parts := Biens.catalogue().filter(func(it): return it.kind == "part" and _village_de(it) == v)
	var a_une_part := parts.any(func(it): return Biens.count(it.id) > 0)
	var moins_chere := {}
	for it in parts:
		if Biens.available(it.id) and (moins_chere.is_empty() or Biens.next_price(it.id) < Biens.next_price(moins_chere.id)):
			moins_chere = it
	var hote := str(Biens.SELLERS.notaire.host)
	out.append({"id": "part", "titre": "Une part d'établissement", "etat": "fait" if a_une_part else "ouvert", "aller": "notaire",
		"texte": "Vos parts versent leur rente à chaque recette, toutes les %d mises." % Biens.PERIOD if a_une_part else
			("%s, %s crédits, chez %s : elle rapporte à chaque recette, toutes les %d mises." % [str(moins_chere.name), Game.fmt(Biens.next_price(moins_chere.id)), hote, Biens.PERIOD]
			if not moins_chere.is_empty() else "Les parts s'ouvrent avec les lieux du village.")})
	# 2. et 4. Les clubs de la commune, dans l'ordre de leurs seuils.
	var clubs_ici: Array = []
	for st in o.structures():
		var sport := "football" if str(st.get("type", "")) == "terrain_foot" else ("basket" if str(st.get("type", "")) == "gymnase" else "")
		if sport == "":
			continue
		var lieu := {}
		for l in o.lieux():
			if l.id == str(st.id):
				lieu = l
		clubs_ici.append({"sport": sport, "nom": str(st.get("club", "le club")), "lieu": str(lieu.get("name", st.get("nom", ""))),
			"seuil": int(lieu.get("seuil", 0))})
	clubs_ici.sort_custom(func(a, b): return a.seuil < b.seuil)
	var dirige_un := false
	var meilleur := {}
	for cl in clubs_ici:
		var m: Node = Football if cl.sport == "football" else Basket
		cl.moteur = m
		cl.tient = m.clubs.has(v) and int(m.investi(v)) > 0
		if cl.tient:
			var e := DIRIGER.etat(m, v)
			dirige_un = dirige_un or bool(e.dirige)
			if meilleur.is_empty() or int(e.manque) < int(meilleur.manque):
				meilleur = e.merged({"moteur": m, "nom": cl.nom})
	for i in clubs_ici.size():
		var cl: Dictionary = clubs_ici[i]
		var ouvert := Game.won >= int(cl.seuil)
		var ou := "à l'étude de %s ou dans les locaux du club" % hote if cl.sport == "football" else "au tableau des parts, à l'entrée de la salle"
		var texte := ""
		if cl.tient:
			texte = "Vous tenez %s crédits d'obligations %s ; elles versent à chaque journée jouée." % [Game.fmt(int(cl.moteur.investi(v))), DIRIGER.de(cl.nom)]
		elif not ouvert:
			texte = "%s ouvre à %s gagnés au jeu (encore %s) : les obligations %s partent de %s crédits." \
				% [cl.lieu, Game.fmt(int(cl.seuil)), Game.fmt(int(cl.seuil) - Game.won), DIRIGER.de(cl.nom), Game.fmt(cl.moteur.valeur(1))]
		else:
			texte = "Les obligations %s, dès %s crédits, %s, %s : elles versent à chaque journée jouée." % [DIRIGER.de(cl.nom), Game.fmt(cl.moteur.valeur(1)), ou, DIRIGER.ferme_texte(cl.moteur)]
		out.append({"id": "club_" + str(cl.sport), "titre": "Une obligation de club" if i == 0 else "Un second club, %s" % cl.nom,
			"etat": "fait" if cl.tient else ("ouvert" if ouvert else "ferme"), "texte": texte,
			"aller": "notaire" if cl.sport == "football" else ""})
		if i == 0:
			# 3. Diriger un club, juste après la première obligation.
			var t := "Celui qui a mis le plus dans un club le dirige (un club par division, on en change à l'intersaison) : la tactique, le marché, le bureau du président."
			if dirige_un:
				t = "Vous dirigez un club : son bureau est à vous."
			elif not meilleur.is_empty():
				var ph: String = DIRIGER.phrase(meilleur.moteur, v)
				t = "%s : %s" % [meilleur.nom, ph.substr(0, 1).to_lower() + ph.substr(1)]
			out.append({"id": "diriger", "titre": "Diriger un club", "etat": "fait" if dirige_un else ("ouvert" if not meilleur.is_empty() else "ferme"),
				"texte": t, "aller": ""})
	for x in out:
		if x.etat == "ouvert":
			x.etat = "suivant"
			break
	return out


## Le parcours, en tête de la commune d'origine : une ligne par marche, la suivante en avant. Rien quand
## tout est fait.
func _parcours() -> void:
	var marches := parcours()
	if marches.all(func(x): return x.etat == "fait"):
		return
	var bloc := VBoxContainer.new()
	bloc.name = "Parcours"
	bloc.add_theme_constant_override("separation", 2)
	_page.add_child(bloc)
	_mot(bloc, "Mon parcours", 22, INK_LIGHT, _gras)
	for x in marches:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 10)
		r.name = "Marche_" + str(x.id)
		bloc.add_child(r)
		var signe := _mot(r, {"fait": "✓", "suivant": "→", "ouvert": "·", "ferme": "○"}[x.etat], 18,
			{"fait": Color(0.2, 0.55, 0.3), "suivant": RED_INK, "ouvert": INK_LIGHT, "ferme": PENCIL}[x.etat], _gras)
		signe.custom_minimum_size.x = 22
		signe.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 0)
		r.add_child(col)
		_mot(col, str(x.titre), 17, INK if x.etat != "ferme" else PENCIL, _gras if x.etat == "suivant" else _texte)
		var t := _mot(col, str(x.texte), 15, INK_LIGHT if x.etat != "ferme" else PENCIL)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if x.etat == "suivant" and str(x.aller) != "":
			_geste(col, "chez " + str(Biens.SELLERS[x.aller].host), _aller_chez.bind(str(x.aller)))
	var bas := Control.new()
	bas.custom_minimum_size.y = 6
	bloc.add_child(bas)


## Va chez un vendeur depuis le classeur (comme les adresses de la page de la commune).
func _aller_chez(vendeur: String) -> void:
	_quitter(func():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = false
		get_tree().change_scene_to_file(Biens.SELLERS[vendeur].scene))


## À l'entrée d'un club : ses neuf obligations, rien d'autre.
func _remplir_club() -> void:
	var moteur: Node = Football if seul_club.sport == "football" else Basket
	_villages_box.visible = false
	if not moteur.clubs.has(str(seul_club.club)):
		_titre.text = "Les parts du club"
		_resume.text = ""
		_vide("Le club n'est pas encore au championnat.")
		return
	var club := _club(str(seul_club.sport), moteur, str(seul_club.club))
	_titre.text = str(club.nom)
	var mien := (club.cartes as Array).filter(func(c): return c.qui == "moi").size()
	var autres := (club.cartes as Array).filter(func(c): return c.qui == "autre").size()
	_resume.text = "%d à vous · %d à d'autres joueurs · %d en vente" % [mien, autres, (club.cartes as Array).size() - mien - autres]
	var p := _mot(_page, str(club.phrase), 16, INK_LIGHT)
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var flot := _flot()
	for c in club.cartes:
		_ajouter(flot, c)


## Le titre d'un village, en grand, souligné deux fois : on y saute depuis la tête.
func _tete_village(x: Dictionary) -> void:
	var bloc := VBoxContainer.new()
	bloc.name = "Village_" + str(x.id)
	bloc.add_theme_constant_override("separation", 2)
	_page.add_child(bloc)
	_ancres[str(x.id)] = bloc
	if _ancres.size() > 1:
		var haut := Control.new()
		haut.custom_minimum_size.y = 18
		bloc.add_child(haut)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	bloc.add_child(h)
	_mot(h, str(x.nom), 32, INK, _gras)
	var c: Commune = Communes.commune(str(x.id))
	if c != null and c.lointaine():
		_mot(h, "%s%s" % [c.ville(), ", " + c.pays() if c.pays() != "" else ""], 17, PENCIL).size_flags_vertical = Control.SIZE_SHRINK_CENTER
	for e in [3, 1]:
		var souligne := ColorRect.new()
		souligne.color = MARGIN_RED
		souligne.custom_minimum_size = Vector2(0, e)
		bloc.add_child(souligne)


## Une ligne au crayon, là où une rubrique n'a pas de carte.
func _vide(t: String) -> void:
	var l := _mot(_page, t, 16, PENCIL)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _onglet_village(x: Dictionary) -> void:
	var b := Button.new()
	b.name = "Aller_" + str(x.id)
	b.text = str(x.nom)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(choisir_village.bind(str(x.id)))
	_villages_box.add_child(b)
	_boutons_village[str(x.id)] = b
	_style_village(b, str(x.id) == village)


func _style_village(b: Button, actif: bool) -> void:
	b.add_theme_font_override("font", _gras if actif else _texte)
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


## Le nom de village de la tête suit la page : c'est celui dont le titre est passé en haut.
func _suivre_defilement() -> void:
	var haut := _defile.scroll_vertical + 24
	var vu := village
	for id in _ancres:
		if (_ancres[id] as Control).position.y <= haut:
			vu = id
	if vu != village:
		village = vu
		for id in _boutons_village:
			_style_village(_boutons_village[id], id == village)


## Une rubrique d'un village, soulignée à l'encre rouge comme un titre de cahier.
func _categorie(t: String) -> void:
	var bloc := VBoxContainer.new()
	bloc.add_theme_constant_override("separation", 2)
	_page.add_child(bloc)
	var haut := Control.new()
	haut.custom_minimum_size.y = 4
	bloc.add_child(haut)
	_mot(bloc, t, 22, INK_LIGHT, _gras)
	var souligne := ColorRect.new()
	souligne.color = Color(0.55, 0.68, 0.85, 0.7)
	souligne.custom_minimum_size = Vector2(0, 1)
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
	_mot(tete, t, 19, INK, _gras)
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


## Les cartes qu'on tient d'un club ou d'un établissement, en grand, puis ses places à compléter, en petit,
## comme les cases vides d'un album : le topo complet reste, sans prendre la page. `cle` : « qui » ou « etat ».
func _cartes_et_places(liste: Array, cle: String, compte: String) -> void:
	var flot := _flot()
	for c in liste:
		if c[cle] == "moi":
			_ajouter(flot, c)
	var places := liste.filter(func(c): return c[cle] != "moi")
	if places.is_empty():
		return
	_mot(_page, "À compléter : " + compte, 15, PENCIL)
	var petit := _flot()
	for c in places:
		_ajouter(petit, c, K_PLACE)


func _ajouter(flot: HFlowContainer, c: Dictionary, k := 1.0) -> void:
	var vue := CarteVue.new()
	vue.classeur = self
	vue.donnees = c
	vue.couleur = c.couleur
	vue.k = k
	vue.name = "Carte_" + str(c.id).replace("/", "_").replace(":", "_")
	var i := _affichees.size()
	vue.choisie.connect(func(): montrer(i))
	flot.add_child(vue)
	_affichees.append(c)


## Les cartes qu'on tient dans un village, en petit, pour les pages du carnet : biens, obligations de
## club et parts d'établissement à soi. Un clic ouvre le classeur sur la carte. Au plus `au_plus`
## vignettes, puis « + n autres ». Rend le nombre de cartes.
func vignettes(parent: Control, v: String, k := 0.42, au_plus := 14) -> int:
	var liste: Array = cartes(v)
	for cl in clubs(v):
		liste.append_array((cl.cartes as Array).filter(func(c): return c.qui == "moi"))
	for e in etablissements(v):
		liste.append_array((e.cartes as Array).filter(func(c): return c.etat == "moi"))
	if liste.is_empty():
		return 0
	var flot := HFlowContainer.new()
	flot.name = "Vignettes"
	flot.add_theme_constant_override("h_separation", 8)
	flot.add_theme_constant_override("v_separation", 8)
	parent.add_child(flot)
	for c in liste.slice(0, au_plus):
		var vue := CarteVue.new()
		vue.classeur = self
		vue.donnees = c
		vue.couleur = c.couleur
		vue.k = k
		vue.name = "Vignette_" + str(c.id).replace("/", "_").replace(":", "_")
		vue.choisie.connect(func():
			if carnet != null:
				carnet.ouvrir_onglet("cartes")
			aller(v, str(c.id)))
		flot.add_child(vue)
	if liste.size() > au_plus:
		var reste := _mot(flot, "+ %d autre%s" % [liste.size() - au_plus, "s" if liste.size() - au_plus > 1 else ""], 15, PENCIL)
		reste.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return liste.size()


## Fait défiler la page jusqu'au titre d'un village.
func choisir_village(id: String) -> void:
	if not _ancres.has(id):
		return
	village = id
	_defile.scroll_vertical = int((_ancres[id] as Control).position.y)
	for k in _boutons_village:
		_style_village(_boutons_village[k], k == village)


## Saute au village suivant (1) ou précédent (-1), en bouclant.
func tourner_village(sens: int) -> void:
	var ids: Array = _ancres.keys()
	if ids.is_empty():
		return
	choisir_village(ids[posmod(ids.find(village) + sens, ids.size())])


## Ouvre le classeur sur une carte : son village en haut, la carte en grand (depuis l'onglet d'un village).
func aller(v: String, id: String) -> void:
	for i in _affichees.size():
		if str(_affichees[i].id) == id:
			montrer(i)
			break
	# La page vient d'être remplie : on saute au village une fois qu'elle est posée.
	await get_tree().process_frame
	choisir_village(v)


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
	if event.keycode in [KEY_UP, KEY_DOWN] and not event.echo and _ancres.size() > 1:
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


# --- À l'entrée d'un club ---------------------------------------------------------------------

## Montre, par-dessus l'écran d'où on l'ouvre (le panneau du stade, le tableau des parts de la salle), les
## cartes des parts d'un seul club, comme au classeur. Échap ou « Refermer » la reposent. Rend la vitrine.
static func ouvrir_club(depuis: Control, sport: String, club: String) -> Control:
	var v := Vitrine.new()
	v.album = load("res://scripts/carnet_cartes.gd").new()
	v.album.seul_club = {"sport": sport, "club": club}
	depuis.get_parent().add_child(v)
	return v


class Vitrine extends Control:
	## Le classeur, réglé sur un seul club avant d'entrer dans l'arbre.
	var album: Control

	func _ready() -> void:
		name = "CartesDuClub"
		process_mode = Node.PROCESS_MODE_ALWAYS
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var voile := ColorRect.new()
		voile.color = Color(0, 0, 0, 0.6)
		voile.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(voile)
		var centre := CenterContainer.new()
		centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(centre)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		centre.add_child(col)
		album.custom_minimum_size = Vector2(1120, 600)
		# Sur un téléphone, le classeur se réduit pour tenir dans l'écran.
		var ecran := get_viewport().get_visible_rect().size
		var k := minf(1.0, minf((ecran.x - 32.0) / 1120.0, (ecran.y - 90.0) / 600.0))
		var tenue := Control.new()
		tenue.custom_minimum_size = Vector2(1120, 600) * k
		col.add_child(tenue)
		album.scale = Vector2(k, k)
		tenue.add_child(album)
		album.size = Vector2(1120, 600)
		album.remplir()
		var fermer := Button.new()
		fermer.name = "Refermer"
		fermer.text = "Refermer les cartes  (Échap)"
		fermer.size_flags_horizontal = Control.SIZE_SHRINK_END
		fermer.custom_minimum_size.y = 48
		fermer.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		fermer.add_theme_font_override("font", Polices.gras())
		fermer.add_theme_font_size_override("font_size", 18)
		for e in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
			fermer.add_theme_color_override(e, INK if e != "font_hover_color" else RED_INK)
		for e in ["normal", "hover", "pressed", "focus"]:
			var st := StyleBoxFlat.new()
			st.bg_color = PAPER if e != "hover" else PAPER.darkened(0.05)
			st.set_corner_radius_all(4)
			st.content_margin_left = 18
			st.content_margin_right = 18
			st.border_color = MARGIN_RED
			st.border_width_left = 3
			fermer.add_theme_stylebox_override(e, st)
		fermer.pressed.connect(queue_free)
		col.add_child(fermer)

	func _input(event: InputEvent) -> void:
		if album == null or not is_visible_in_tree():
			return
		if album.saisir(event):
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_cancel"):
			get_viewport().set_input_as_handled()
			queue_free()


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
