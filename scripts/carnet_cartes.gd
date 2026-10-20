extends Control
## Le classeur de cartes du carnet (onglet « Mes cartes ») : tout ce qui s'achète devient une carte à
## collectionner, façon titre de propriété du Monopoly. Une famille par couleur, comme les rues du
## plateau : les parts du village, chaque quartier du notaire (ses maisons et ses murs), les clubs, la
## garde-robe, le garage, la brocante, les souvenirs, et les biens des autres communes.
##
## Une carte a trois états : à soi (en couleur, avec ses exemplaires), à acquérir (pâlie, avec son prix
## et son vendeur), ou fermée (vue de dos, jusqu'au seuil du lieu qui la vend). La bordure dit son rang,
## du bronze au prestige, selon le prix ; les cartes de prestige qu'on tient ont un reflet qui passe.
##
## Les clubs ont leur carte de parts : les neuf obligations du club en damier, celles qu'on tient en or,
## celles des autres joueurs en ardoise, les libres en pointillé. Rien ne s'achète ici : la carte dit où
## aller, et seuls les gestes sans prix (porter, conduire, habiter, louer) se font depuis le classeur.
##
## Navigation : les familles dans la colonne de gauche (↑ ↓), un clic sur une carte la montre en grand
## avec sa fiche, ← → passent à la voisine, Échap la repose.

signal ferme_zoom

const FEUTRE := Color(0.075, 0.2, 0.17)
const FEUTRE_CLAIR := Color(0.11, 0.27, 0.23)
const CREME := Color(0.96, 0.93, 0.84)
const CREME_DOUX := Color(0.75, 0.78, 0.72)
const OR := Color(0.86, 0.68, 0.25)
const ARDOISE := Color(0.36, 0.42, 0.5)
const VISAGE := Color(0.985, 0.97, 0.93)
## La bordure d'une carte selon son rang : bronze, argent, or, prestige.
const RANGS := [Color(0.66, 0.46, 0.3), Color(0.7, 0.74, 0.79), Color(0.85, 0.66, 0.22), Color(0.95, 0.82, 0.42)]
const NOMS_RANGS := ["bronze", "argent", "or", "prestige"]
## La taille d'une carte dans le classeur ; en grand, elle est multipliée par ZOOM.
const CARTE := Vector2(150, 236)
const ZOOM := 1.62
## Les familles hors quartiers, dans l'ordre du classeur (les quartiers viennent après les parts).
const FAMILLES := {
	"parts": {"nom": "Les parts du village", "couleur": Color(0.13, 0.46, 0.29)},
	"clubs": {"nom": "Les clubs", "couleur": Color(0.12, 0.2, 0.46)},
	"tenue": {"nom": "La garde-robe", "couleur": Color(0.82, 0.38, 0.58)},
	"vehicule": {"nom": "Le garage", "couleur": Color(0.3, 0.6, 0.82)},
	"meuble": {"nom": "La brocante", "couleur": Color(0.52, 0.34, 0.2)},
	"souvenirs": {"nom": "Les souvenirs", "couleur": Color(0.46, 0.3, 0.66)},
}
## Les couleurs des quartiers, dans l'ordre du registre du notaire, comme les rues du plateau.
const QUARTIERS := [Color(0.78, 0.16, 0.18), Color(0.92, 0.52, 0.12), Color(0.9, 0.74, 0.12), Color(0.55, 0.78, 0.9), Color(0.6, 0.38, 0.22)]
const AILLEURS := Color(0.4, 0.46, 0.5)
const NOTAIRE := preload("res://scripts/socle/notaire.gd")

## Le carnet, qui tient le classeur.
var carnet = null
## La famille ouverte (« » : toutes), et le filtre « seulement les miennes ».
var famille := ""
var miennes := false
var _rail: VBoxContainer
var _grille: VBoxContainer
var _defile: ScrollContainer
var _compte: Label
var _filtre: CheckBox
var _barre: Barre
var _zoom: Control
var _zoom_boite: HBoxContainer
## Les cartes affichées, dans l'ordre : le zoom passe de l'une à l'autre.
var _affichees: Array = []
var _index := -1
var _texte: Font
var _gras: Font
var _titre: Font


func _ready() -> void:
	_texte = Polices.texte()
	_gras = Polices.gras()
	_titre = Polices.titre()
	custom_minimum_size = Vector2(1120, 680)
	var fond := Panel.new()
	fond.set_anchors_preset(Control.PRESET_FULL_RECT)
	var st := StyleBoxFlat.new()
	st.bg_color = FEUTRE
	st.set_corner_radius_all(4)
	st.border_color = Color(0.04, 0.12, 0.1)
	st.set_border_width_all(2)
	fond.add_theme_stylebox_override("panel", st)
	fond.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fond)
	var marge := MarginContainer.new()
	marge.set_anchors_preset(Control.PRESET_FULL_RECT)
	for k in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		marge.add_theme_constant_override(k, 18)
	add_child(marge)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	marge.add_child(col)
	# La tête : le titre, le compte des cartes et sa barre.
	var tete := HBoxContainer.new()
	tete.add_theme_constant_override("separation", 16)
	col.add_child(tete)
	var t := _mot(tete, "Ma collection", 30, CREME, _titre)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_compte = _mot(tete, "", 17, CREME_DOUX)
	_compte.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_barre = Barre.new()
	_barre.custom_minimum_size = Vector2(220, 12)
	_barre.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tete.add_child(_barre)
	var corps := HBoxContainer.new()
	corps.add_theme_constant_override("separation", 16)
	corps.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(corps)
	# La colonne des familles.
	var gauche := VBoxContainer.new()
	gauche.custom_minimum_size.x = 214
	gauche.add_theme_constant_override("separation", 8)
	corps.add_child(gauche)
	var rd := ScrollContainer.new()
	rd.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rd.size_flags_vertical = Control.SIZE_EXPAND_FILL
	gauche.add_child(rd)
	_rail = VBoxContainer.new()
	_rail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rail.add_theme_constant_override("separation", 3)
	rd.add_child(_rail)
	var filtre := CheckBox.new()
	filtre.name = "Miennes"
	filtre.text = "Seulement les miennes"
	filtre.focus_mode = Control.FOCUS_NONE
	filtre.add_theme_font_override("font", _texte)
	filtre.add_theme_font_size_override("font_size", 15)
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		filtre.add_theme_color_override(k, CREME_DOUX)
	filtre.toggled.connect(func(on: bool):
		miennes = on
		remplir())
	gauche.add_child(filtre)
	_filtre = filtre
	# Les cartes.
	_defile = ScrollContainer.new()
	_defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_defile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_defile.size_flags_vertical = Control.SIZE_EXPAND_FILL
	corps.add_child(_defile)
	_grille = VBoxContainer.new()
	_grille.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grille.add_theme_constant_override("separation", 10)
	_defile.add_child(_grille)
	# La carte en grand, par-dessus le classeur.
	_zoom = Control.new()
	_zoom.set_anchors_preset(Control.PRESET_FULL_RECT)
	_zoom.visible = false
	add_child(_zoom)
	var voile := ColorRect.new()
	voile.color = Color(0.02, 0.06, 0.05, 0.86)
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


func _mot(parent: Control, t: String, taille := 16, couleur := CREME, police: Font = null) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_override("font", police if police != null else _texte)
	l.add_theme_font_size_override("font_size", taille)
	l.add_theme_color_override("font_color", couleur)
	parent.add_child(l)
	return l


# --- Ce que contient le classeur ----------------------------------------------------------------

## Les familles du classeur, dans l'ordre : [{id, nom, couleur}].
func familles() -> Array:
	var out: Array = [_famille("parts")]
	var o: Commune = Communes.origine()
	var reg := NOTAIRE.registre(o)
	for i in reg.quartiers.size():
		var q: Dictionary = reg.quartiers[i]
		out.append({"id": "q:" + str(q.id), "nom": str(q.nom), "couleur": QUARTIERS[i % QUARTIERS.size()]})
	for id in ["clubs", "tenue", "vehicule", "meuble", "souvenirs"]:
		out.append(_famille(id))
	var vues := {}
	for it in Biens.catalogue():
		var commune := str(it.get("commune", ""))
		if commune != "" and not vues.has(commune):
			vues[commune] = true
			out.append({"id": "c:" + commune, "nom": "À " + _nom_commune(commune), "couleur": AILLEURS})
	return out


func _famille(id: String) -> Dictionary:
	return {"id": id, "nom": FAMILLES[id].nom, "couleur": FAMILLES[id].couleur}


func _nom_commune(id: String) -> String:
	var c: Commune = Communes.commune(id)
	return c.nom if c != null else id.capitalize()


## Toutes les cartes, famille par famille. Une carte : {id, famille, nom, genre, icone, prix, rente,
## charge, standing, n, max, etat (« moi », « libre », « fermee »), seuil, rang, de, phrase, vendeur},
## et pour un club : {sport, club, couleurs, cases [{rang, valeur, qui (« moi », « autre », « libre »), par}]}.
func cartes() -> Array:
	var par_famille := {}
	var o: Commune = Communes.origine()
	for it in Biens.catalogue():
		if it.kind == "club" or int(it.get("price", 0)) <= 0:
			continue
		var fam := _famille_de(it, o)
		var n := Biens.count(it.id)
		var etat := "moi" if n > 0 else ("fermee" if Game.won < int(it.gate) else "libre")
		var c := {"id": it.id, "famille": fam, "nom": it.name, "genre": _genre(it, o), "icone": _icone(it, o),
			"prix": Biens.next_price(it.id) if n < int(it.max) else int(it.price), "rente": int(it.rente), "charge": int(it.charge),
			"standing": int(it.standing), "n": n, "max": int(it.max), "etat": etat, "seuil": int(it.gate),
			"rang": _rang(int(it.price)), "de": str(it.get("from", "")), "phrase": str(it.get("blurb", "")),
			"vendeur": str(it.get("seller", "")), "kind": str(it.kind)}
		if not par_famille.has(fam):
			par_famille[fam] = []
		par_famille[fam].append(c)
	par_famille["clubs"] = _clubs()
	var souvenirs: Array = []
	for id in Biens.TROUVAILLES:
		var a := Biens.trouvailles.has(id)
		souvenirs.append({"id": id, "famille": "souvenirs", "nom": str(Biens.TROUVAILLES[id].name), "genre": "Souvenir · à poser chez soi",
			"icone": "souvenir", "prix": 0, "rente": 0, "charge": 0, "standing": 0, "n": 1 if a else 0, "max": 1,
			"etat": "moi" if a else "fermee", "seuil": 0, "rang": 3, "de": "", "phrase": "", "vendeur": "", "kind": "souvenir"})
	par_famille["souvenirs"] = souvenirs
	var out: Array = []
	for f in familles():
		var liste: Array = par_famille.get(f.id, [])
		# Dans une famille, du moins cher au plus cher, comme sur le plateau.
		liste.sort_custom(func(a, b): return int(a.prix) < int(b.prix) if int(a.prix) != int(b.prix) else str(a.nom) < str(b.nom))
		out.append_array(liste)
	return out


func _famille_de(it: Dictionary, o: Commune) -> String:
	if str(it.get("commune", "")) != "":
		return "c:" + str(it.commune)
	match str(it.kind):
		"part":
			return "parts"
		"maison", "murs":
			var q := NOTAIRE.quartier_of(o, str(it.id))
			if q == "":
				# Les murs du catalogue d'origine (la chambre, les deux maisons) sont sur la place.
				var reg := NOTAIRE.registre(o)
				q = str(reg.quartiers[0].id) if not reg.quartiers.is_empty() else ""
			return "q:" + q
		"tenue", "vehicule", "meuble":
			return str(it.kind)
	return "c:" + str(it.get("commune", "ailleurs"))


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


## Les cartes de parts des clubs : celui de la commune d'origine, et ceux où quelqu'un a déjà des parts.
func _clubs() -> Array:
	var out: Array = []
	var o: Commune = Communes.origine()
	var origine := o.id if o != null else ""
	for sport in ["football", "basket"]:
		var moteur: Node = Football if sport == "football" else Basket
		var ids: Array = moteur.clubs.keys()
		ids.sort_custom(func(a, b): return (a == origine and b != origine) or ((a == origine) == (b == origine) and str(a) < str(b)))
		for club in ids:
			if club != origine and moteur.actionnaires(club).is_empty():
				continue
			out.append(_carte_club(sport, moteur, club))
	return out


func _carte_club(sport: String, moteur: Node, club: String) -> Dictionary:
	var fiche: Dictionary = moteur.clubs.get(club, {})
	var cases: Array = []
	var a_moi := 0
	for r in range(1, moteur.OBLIGATIONS.size() + 1):
		var p: Dictionary = moteur.porteur(club, r)
		var qui := "libre" if p.is_empty() else ("moi" if bool(p.moi) else "autre")
		if qui == "moi":
			a_moi += 1
		cases.append({"rang": r, "valeur": moteur.valeur(r), "qui": qui, "par": str(p.get("nom", ""))})
	var couleurs: Array = fiche.get("couleurs", ["#14213d", "#d4a93a"])
	return {"id": "%s:%s" % [sport, club], "famille": "clubs", "nom": str(fiche.get("nom", club)),
		"genre": ("Football" if sport == "football" else "Basket") + " · neuf obligations", "icone": sport,
		"prix": moteur.valeur(1), "rente": 0, "charge": 0, "standing": 0, "n": a_moi, "max": moteur.OBLIGATIONS.size(),
		"etat": "moi" if a_moi > 0 else "libre", "seuil": 0, "rang": 3, "de": "", "phrase": "", "vendeur": "", "kind": "club",
		"sport": sport, "club": club, "couleurs": [_couleur(couleurs[0]), _couleur(couleurs[1] if couleurs.size() > 1 else "#ffffff")],
		"cases": cases, "dirige": moteur.peut_decider(club) and a_moi > 0, "actionnaires": moteur.actionnaires(club),
		"phrase_capital": str(moteur.phrase_actionnaires(club))}


static func _couleur(v) -> Color:
	if v is Color:
		return v
	return Color.from_string(str(v), Color(0.1, 0.15, 0.3))


# --- Le classeur ----------------------------------------------------------------------------------

func remplir() -> void:
	var toutes := cartes()
	var fams := familles()
	var a_moi := toutes.filter(func(c): return c.etat == "moi").size()
	_compte.text = "%d / %d cartes  ·  estimation %s" % [a_moi, toutes.size(), Game.fmt(Biens.value())]
	_barre.part = float(a_moi) / maxf(1.0, float(toutes.size()))
	_barre.queue_redraw()
	_filtre.set_pressed_no_signal(miennes)
	if famille != "" and not fams.any(func(f): return f.id == famille):
		famille = ""
	for c in _rail.get_children() + _grille.get_children():
		c.get_parent().remove_child(c)
		c.queue_free()
	_bouton_famille({"id": "", "nom": "Toutes les cartes", "couleur": OR}, a_moi, toutes.size())
	for f in fams:
		var liste := toutes.filter(func(c): return c.famille == f.id)
		if liste.is_empty():
			continue
		_bouton_famille(f, liste.filter(func(c): return c.etat == "moi").size(), liste.size())
	_affichees = []
	for f in fams:
		if famille != "" and f.id != famille:
			continue
		var liste := toutes.filter(func(c): return c.famille == f.id and (not miennes or c.etat == "moi"))
		if liste.is_empty():
			continue
		var tete := HBoxContainer.new()
		tete.add_theme_constant_override("separation", 10)
		_grille.add_child(tete)
		var pastille := Pastille.new()
		pastille.couleur = f.couleur
		pastille.custom_minimum_size = Vector2(14, 14)
		pastille.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tete.add_child(pastille)
		_mot(tete, str(f.nom), 20, CREME, _gras)
		var tenues := toutes.filter(func(c): return c.famille == f.id and c.etat == "moi").size()
		var total := toutes.filter(func(c): return c.famille == f.id).size()
		var l := _mot(tete, "%d / %d%s" % [tenues, total, "  ·  famille complète" if tenues == total else ""], 15, OR if tenues == total else CREME_DOUX)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var flot := HFlowContainer.new()
		flot.add_theme_constant_override("h_separation", 14)
		flot.add_theme_constant_override("v_separation", 14)
		_grille.add_child(flot)
		for c in liste:
			var vue := CarteVue.new()
			vue.classeur = self
			vue.donnees = c
			vue.couleur = f.couleur
			vue.name = "Carte_" + str(c.id).replace("/", "_").replace(":", "_")
			var i := _affichees.size()
			vue.choisie.connect(func(): montrer(i))
			flot.add_child(vue)
			_affichees.append({"carte": c, "couleur": f.couleur, "famille": f.nom})
	if _affichees.is_empty():
		_mot(_grille, "Pas encore de carte ici. Maître Garnier, Raymonde, Roger Fradin et Ginette Boutin en vendent au village.", 17, CREME_DOUX).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if _zoom.visible and _affichees.is_empty():
		fermer_zoom()
	elif _zoom.visible:
		montrer(clampi(_index, 0, _affichees.size() - 1))


func _bouton_famille(f: Dictionary, tenues: int, total: int) -> void:
	var actif: bool = famille == f.id
	var b := Button.new()
	b.name = "Famille_" + (str(f.id).replace(":", "_") if f.id != "" else "toutes")
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(0, 38)
	for k in ["normal", "hover", "pressed", "focus"]:
		var st := StyleBoxFlat.new()
		st.bg_color = FEUTRE_CLAIR.lightened(0.08) if actif else (FEUTRE_CLAIR if k == "hover" else Color(0, 0, 0, 0))
		st.set_corner_radius_all(6)
		st.border_width_left = 4 if actif else 0
		st.border_color = f.couleur
		b.add_theme_stylebox_override(k, st)
	b.pressed.connect(choisir_famille.bind(str(f.id)))
	_rail.add_child(b)
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 12
	h.offset_right = -10
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var p := Pastille.new()
	p.couleur = f.couleur
	p.custom_minimum_size = Vector2(12, 12)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(p)
	var n := _mot(h, str(f.nom), 15, CREME if actif else CREME_DOUX, _gras if actif else _texte)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.clip_text = true
	var c := _mot(h, "%d/%d" % [tenues, total], 14, OR if tenues == total and total > 0 else CREME_DOUX)
	c.size_flags_vertical = Control.SIZE_SHRINK_CENTER


func choisir_famille(id: String) -> void:
	famille = id
	_index = -1
	remplir()
	_defile.scroll_vertical = 0


## Passe à la famille suivante (1) ou précédente (-1) de la colonne, en bouclant.
func tourner_famille(sens: int) -> void:
	var ids: Array = [""]
	var toutes := cartes()
	for f in familles():
		if toutes.any(func(c): return c.famille == f.id):
			ids.append(f.id)
	choisir_famille(ids[posmod(ids.find(famille) + sens, ids.size())])


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
		tourner_famille(1 if event.keycode == KEY_DOWN else -1)
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
	var e: Dictionary = _affichees[i]
	_fleche(_zoom_boite, "←", -1)
	var vue := CarteVue.new()
	vue.classeur = self
	vue.donnees = e.carte
	vue.couleur = e.couleur
	vue.k = ZOOM
	vue.fixe = true
	vue.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_zoom_boite.add_child(vue)
	_zoom_boite.add_child(_fiche(e))
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
	b.add_theme_font_size_override("font_size", 24)
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, CREME if k != "font_hover_color" else OR)
	for k in ["normal", "hover", "pressed", "focus"]:
		var st := StyleBoxFlat.new()
		st.bg_color = Color(1, 1, 1, 0.12 if k == "hover" else 0.06)
		st.set_corner_radius_all(26)
		b.add_theme_stylebox_override(k, st)
	b.disabled = _affichees.size() < 2
	b.pressed.connect(func(): montrer(posmod(_index + sens, _affichees.size())))
	parent.add_child(b)


## La fiche à côté de la carte en grand : ce qu'elle vaut, ce qu'elle rapporte, où l'acheter, et les
## gestes sans prix.
func _fiche(e: Dictionary) -> Control:
	var c: Dictionary = e.carte
	var panneau := PanelContainer.new()
	panneau.custom_minimum_size = Vector2(420, 0)
	panneau.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.05, 0.13, 0.11, 0.96)
	st.set_corner_radius_all(10)
	st.set_content_margin_all(22)
	st.border_color = e.couleur
	st.border_width_top = 4
	panneau.add_theme_stylebox_override("panel", st)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panneau.add_child(v)
	_mot(v, str(e.famille).to_upper(), 13, (e.couleur as Color).lightened(0.35), _gras)
	var nom := _mot(v, str(c.nom) if c.kind != "souvenir" or c.etat == "moi" else "Un souvenir à trouver", 26, CREME, _titre)
	nom.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nom.custom_minimum_size.x = 376
	_mot(v, "%s  ·  carte %s" % [c.genre, NOMS_RANGS[int(c.rang)]], 14, CREME_DOUX)
	if str(c.phrase) != "" and c.etat != "fermee":
		var q := _mot(v, str(c.phrase) + ("  — " + str(c.de) if str(c.de) != "" else ""), 15, Color(0.85, 0.82, 0.7))
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		q.custom_minimum_size.x = 376
	_filet(v)
	if c.kind == "club":
		_fiche_club(v, c)
	elif c.kind == "souvenir":
		var t := "Posé ou rangé chez vous : il ne se vend ni ne se saisit." if c.etat == "moi" else "Le village en garde quelques-uns : ils viennent en jouant, ou en cherchant bien."
		_mot(v, t, 15, CREME_DOUX).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	else:
		_fiche_bien(v, c)
	return panneau


func _filet(v: VBoxContainer) -> void:
	var r := ColorRect.new()
	r.color = Color(1, 1, 1, 0.12)
	r.custom_minimum_size.y = 1
	v.add_child(r)


func _ligne(v: VBoxContainer, a: String, b: String, couleur := CREME) -> void:
	var h := HBoxContainer.new()
	v.add_child(h)
	var l := _mot(h, a, 16, CREME_DOUX)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mot(h, b, 16, couleur, _gras)


func _fiche_bien(v: VBoxContainer, c: Dictionary) -> void:
	var id := str(c.id)
	var it := Biens.item(id)
	var n := int(c.n)
	if int(c.max) > 1:
		_ligne(v, "Exemplaires", "%d / %d" % [n, int(c.max)], OR if n >= int(c.max) else CREME)
	if c.rente > 0:
		_ligne(v, "Rente annoncée, par recette", Game.fmt(int(c.rente) * maxi(1, n)))
	if c.charge > 0:
		_ligne(v, "Charges, par recette", Game.fmt(int(c.charge) * maxi(1, n)))
	if c.standing > 0:
		_ligne(v, "Standing", "+%d" % (int(c.standing) * maxi(1, n)))
	if n > 0:
		var reprise := 0
		for i in n:
			reprise += int(round(Biens.price_of(id, i) * Biens.RESALE))
		_ligne(v, "Estimation à la revente", Game.fmt(reprise))
	if n < int(c.max):
		_ligne(v, "Prix" if n == 0 else "Prix du suivant", Game.fmt(int(c.prix)), OR)
	# L'état, et les gestes sans prix.
	var gestes := HFlowContainer.new()
	gestes.add_theme_constant_override("h_separation", 8)
	gestes.add_theme_constant_override("v_separation", 8)
	if c.kind == "tenue" and n > 0:
		if Biens.worn == id:
			_mot(v, "Vous la portez.", 15, OR)
		else:
			_geste(gestes, "La porter", func(): Biens.wear(id))
	elif c.kind == "vehicule" and n > 0:
		if Biens.driven == id:
			_mot(v, "Au garage de la place : c'est elle que vous prenez.", 15, OR)
		else:
			_geste(gestes, "La prendre", func(): Biens.wear(id))
	elif Biens.logements.has(id):
		var habitee := Biens.is_habite(id)
		_mot(v, "Vous y habitez : elle ne verse pas de rente, mais compte double en standing." if habitee else "Louée : elle verse sa rente à chaque recette.", 15, OR)
		_geste(gestes, "La remettre en location" if habitee else "M'y installer", func():
			if habitee:
				Biens.louer(id)
			else:
				Biens.habiter(id))
		_geste(gestes, "Y aller", func(): _quitter(func(): Biens.enter(id)))
	elif c.kind == "meuble" and n > 0:
		var pose := Biens.placed_count(id)
		_mot(v, "%d posé%s chez vous, %d au carton ou au grenier." % [pose, "s" if pose > 1 else "", n - pose], 15, CREME_DOUX)
	if c.etat == "fermee":
		var t := "La carte se retourne quand vous aurez gagné %s au jeu (vous en êtes à %s)." % [Game.fmt(int(c.seuil)), Game.fmt(Game.won)]
		_mot(v, t, 15, CREME_DOUX).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	elif n < int(c.max):
		var vendeur: Dictionary = Biens.SELLERS.get(str(c.vendeur), {})
		var o: Commune = Communes.origine()
		var ailleurs := str(it.get("commune", "")) != "" and (o == null or str(it.commune) != o.id)
		if ailleurs:
			_mot(v, "Chez le notaire de %s, sur place." % _nom_commune(str(it.commune)), 15, CREME_DOUX)
		elif not vendeur.is_empty():
			_mot(v, "En vente : %s." % str(vendeur.name), 15, CREME_DOUX)
			var page = carnet.page_origine() if carnet != null else null
			if page != null and page.has_method("go_to"):
				_geste(gestes, "Y aller", func(): page.go_to(str(c.vendeur)))
	if gestes.get_child_count() > 0:
		v.add_child(gestes)
	else:
		gestes.free()


func _fiche_club(v: VBoxContainer, c: Dictionary) -> void:
	var foot: bool = c.sport == "football"
	var moteur: Node = Football if foot else Basket
	for cs in c.cases:
		var qui := "à vous" if cs.qui == "moi" else ("libre" if cs.qui == "libre" else str(cs.par))
		_ligne(v, "n° %d  ·  %s crédits" % [int(cs.rang), Game.fmt(int(cs.valeur))], qui,
			OR if cs.qui == "moi" else (Color(0.62, 0.86, 0.66) if cs.qui == "libre" else Color(0.7, 0.76, 0.84)))
	_filet(v)
	var p := _mot(v, str(c.phrase_capital), 15, CREME_DOUX)
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	p.custom_minimum_size.x = 376
	if int(c.n) > 0:
		_ligne(v, "Investi", Game.fmt(int(moteur.investi(str(c.club)))), OR)
	var ou := "Les obligations libres se prennent à l'étude de Maître Garnier, ou dans les locaux du club." if foot \
		else "Les obligations libres se prennent au tableau des parts, à l'entrée du grand hall de la salle."
	_mot(v, ou, 15, CREME_DOUX).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var page = carnet.page_origine() if carnet != null else null
	if foot and page != null and page.has_method("go_to") and Biens.SELLERS.has("notaire"):
		var gestes := HFlowContainer.new()
		v.add_child(gestes)
		_geste(gestes, "Aller chez le notaire", func(): page.go_to("notaire"))


func _geste(parent: Control, t: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = t
	b.name = "Geste_" + t.replace(" ", "_").replace("'", "")
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(0, 42)
	b.add_theme_font_override("font", _gras)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_color_override("font_color", Color(0.1, 0.08, 0.03))
	b.add_theme_color_override("font_hover_color", Color(0.1, 0.08, 0.03))
	b.add_theme_color_override("font_pressed_color", Color(0.1, 0.08, 0.03))
	for k in ["normal", "hover", "pressed", "focus"]:
		var st := StyleBoxFlat.new()
		st.bg_color = OR.lightened(0.15) if k == "hover" else OR
		st.set_corner_radius_all(21)
		st.content_margin_left = 18
		st.content_margin_right = 18
		b.add_theme_stylebox_override(k, st)
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

## Une pastille de couleur, ronde.
class Pastille extends Control:
	var couleur := Color.WHITE

	func _draw() -> void:
		draw_circle(size / 2.0, minf(size.x, size.y) / 2.0, couleur)


## La barre de la collection : la part tenue, en or.
class Barre extends Control:
	var part := 0.0

	func _draw() -> void:
		_pilule(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.12))
		if part > 0.0:
			_pilule(Rect2(Vector2.ZERO, Vector2(maxf(size.y, size.x * clampf(part, 0.0, 1.0)), size.y)), OR)

	func _pilule(r: Rect2, c: Color) -> void:
		var st := StyleBoxFlat.new()
		st.bg_color = c
		st.set_corner_radius_all(int(size.y / 2.0))
		draw_style_box(st, r)


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
			st.shadow_color = Color(0, 0, 0, 0.45)
			st.shadow_size = int(ombre)
			st.shadow_offset = Vector2(0, ombre / 3.0)
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
		if d.etat == "fermee":
			_dos(w, h, bord)
			return
		var club: bool = d.kind == "club"
		var bande: Color = d.couleurs[0] if club else couleur
		var encre_bande: Color = d.couleurs[1] if club else (Color(0.1, 0.08, 0.06) if bande.get_luminance() > 0.55 else Color.WHITE)
		if club and absf(bande.get_luminance() - encre_bande.get_luminance()) < 0.3:
			encre_bande = Color.WHITE if bande.get_luminance() < 0.5 else Color(0.1, 0.08, 0.06)
		_boite(Rect2(0, 0, w, h), VISAGE, 10 * k, bord, (5 if rang >= 2 else 4) * k, (14 if _survol else 7) * k)
		# Le bandeau de couleur, et le nom dedans.
		var m := 9.0 * k
		var bh := 52.0 * k
		_boite(Rect2(m, m, w - 2 * m, bh), bande, 5 * k)
		var titre_h: float = classeur._gras.get_multiline_string_size(str(d.nom), HORIZONTAL_ALIGNMENT_CENTER, w - 2 * m - 10 * k, int(round(14 * k)), 2).y
		_ecrire(str(d.nom), Vector2(w / 2.0, m + (bh - titre_h) / 2.0), w - 2 * m - 10 * k, 14, encre_bande, true, 2)
		var y := m + bh + 6 * k
		if club:
			_damier(d, y, w)
		else:
			# L'image : un rond teinté, et le dessin du genre de bien.
			var c := Vector2(w / 2.0, y + 36 * k)
			draw_circle(c, 33 * k, couleur.lerp(Color.WHITE, 0.8))
			draw_arc(c, 33 * k, 0, TAU, 48, couleur.lerp(Color.WHITE, 0.55), 1.5 * k, true)
			Icones.dessiner(self, str(d.icone), c, 21 * k, couleur.darkened(0.25))
			y += 76 * k
			_ecrire(str(d.genre), Vector2(w / 2.0, y), w - 16 * k, 10.5, Color(0.42, 0.4, 0.36), false, 2)
			y += 30 * k
			_stats(d, y, w)
		# Le pied : les exemplaires, ou le prix.
		var pied := h - 22 * k
		if club:
			var qui := "vous dirigez" if d.dirige else ("dirigé par " + str(d.actionnaires[0].nom) if not d.actionnaires.is_empty() else "capital ouvert à tous")
			_ecrire(qui, Vector2(w / 2.0, pied - 2 * k), w - 16 * k, 11, Color(0.3, 0.28, 0.25), true)
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
		elif d.etat == "moi":
			_ecrire("à vous", Vector2(w / 2.0, pied - 2 * k), w - 16 * k, 12, couleur.darkened(0.3), true)
		# Le rang, en losange dans le coin.
		var g := Vector2(w - 14 * k, h - 14 * k)
		var lo := 4.5 * k
		draw_colored_polygon(PackedVector2Array([g + Vector2(0, -lo), g + Vector2(lo, 0), g + Vector2(0, lo), g + Vector2(-lo, 0)]), bord.darkened(0.1))
		# Plusieurs exemplaires : la pastille du nombre.
		if int(d.n) > 1 and not club:
			var b := Vector2(w - 12 * k, 12 * k)
			draw_circle(b, 12 * k, Color(0.12, 0.1, 0.08))
			draw_arc(b, 12 * k, 0, TAU, 24, OR, 1.5 * k, true)
			_ecrire("×%d" % int(d.n), Vector2(b.x, b.y - 8.5 * k), 30 * k, 12, Color.WHITE, true)
		# À acquérir : la carte est pâlie, avec son prix sur une étiquette.
		if d.etat == "libre":
			_boite(Rect2(2 * k, 2 * k, w - 4 * k, h - 4 * k), Color(0.97, 0.95, 0.9, 0.5), 9 * k)
			var et := Rect2(14 * k, m + bh + 58 * k, w - 28 * k, 24 * k)
			_boite(et, Color(0.1, 0.12, 0.11, 0.92), 12 * k)
			var t := ("dès " if club else "") + Game.fmt(int(d.prix)) + " cr."
			_ecrire(t, Vector2(w / 2.0, et.position.y + 4 * k), et.size.x, 12, Color(0.95, 0.85, 0.55), true)
		elif _brille():
			_reflet_passe(w, h)

	## Les trois chiffres d'un bien : rente, charges, standing.
	func _stats(d: Dictionary, y: float, w: float) -> void:
		var cols := [["rente", "%s" % (Game.fmt(int(d.rente)) if int(d.rente) > 0 else "—")],
			["charges", "%s" % (Game.fmt(int(d.charge)) if int(d.charge) > 0 else "—")],
			["standing", "+%d" % int(d.standing) if int(d.standing) > 0 else "—"]]
		var lw := (w - 16 * k) / 3.0
		for i in 3:
			var cx := 8 * k + lw * (i + 0.5)
			_ecrire(cols[i][0], Vector2(cx, y), lw, 9.5, Color(0.5, 0.47, 0.42))
			_ecrire(cols[i][1], Vector2(cx, y + 13 * k), lw, 14, Color(0.15, 0.13, 0.1), true)
			if i > 0:
				draw_line(Vector2(8 * k + lw * i, y + 2 * k), Vector2(8 * k + lw * i, y + 30 * k), Color(0, 0, 0, 0.12), 1.0)

	## Les neuf obligations d'un club en damier : à soi en or, aux autres en ardoise, libres en pointillé.
	func _damier(d: Dictionary, y: float, w: float) -> void:
		var m := 10.0 * k
		var gap := 5.0 * k
		var cw := (w - 2 * m - 2 * gap) / 3.0
		var ch := 31.0 * k
		for i in d.cases.size():
			var cs: Dictionary = d.cases[i]
			var r := Rect2(m + (i % 3) * (cw + gap), y + 4 * k + (i / 3) * (ch + gap), cw, ch)
			var encre := Color(0.15, 0.13, 0.1)
			match str(cs.qui):
				"moi":
					_boite(r, OR, 4 * k, OR.darkened(0.25), 1.5 * k)
				"autre":
					_boite(r, ARDOISE, 4 * k)
					encre = Color.WHITE
				_:
					_pointilles(r, Color(0.55, 0.52, 0.46))
					encre = Color(0.45, 0.42, 0.38)
			_ecrire(Game.fmt(int(cs.valeur)), Vector2(r.get_center().x, r.position.y + 2 * k), cw, 11.5, encre, true)
			var sous := "vous" if cs.qui == "moi" else ("libre" if cs.qui == "libre" else str(cs.par))
			_ecrire(sous, Vector2(r.get_center().x, r.position.y + 15.5 * k), cw - 4 * k, 9, encre)
		var ly := y + 4 * k + 3 * (ch + gap) + 4 * k
		var n_moi: int = d.cases.filter(func(c): return c.qui == "moi").size()
		var n_aut: int = d.cases.filter(func(c): return c.qui == "autre").size()
		var n_lib: int = d.cases.size() - n_moi - n_aut
		_ecrire("%d à vous · %d aux autres · %d libres" % [n_moi, n_aut, n_lib], Vector2(w / 2.0, ly), w - 12 * k, 9.5, Color(0.42, 0.4, 0.36))

	func _pointilles(r: Rect2, c: Color) -> void:
		var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position]
		for i in 4:
			draw_dashed_line(pts[i], pts[i + 1], c, 1.4 * k, 4 * k)

	## Le dos d'une carte fermée : la couleur de la famille, un motif, et le seuil qui la retourne.
	func _dos(w: float, h: float, bord: Color) -> void:
		var fond := couleur.darkened(0.55)
		_boite(Rect2(0, 0, w, h), fond, 10 * k, couleur.darkened(0.2), 4 * k, 6 * k)
		var m := 10.0 * k
		var inner := Rect2(m, m, w - 2 * m, h - 2 * m)
		_boite(inner, Color(0, 0, 0, 0), 6 * k, couleur.darkened(0.05), 1.5 * k)
		var pas := 12.0 * k
		var x := -h
		while x < w:
			var a := Vector2(x, h)
			var b := Vector2(x + h, 0)
			var seg := Geometry2D.clip_polyline_with_polygon(PackedVector2Array([a, b]),
				PackedVector2Array([inner.position, Vector2(inner.end.x, inner.position.y), inner.end, Vector2(inner.position.x, inner.end.y)]))
			for s in seg:
				draw_polyline(s, Color(1, 1, 1, 0.05), 1.0 * k)
			x += pas
		var c := Vector2(w / 2.0, h * 0.42)
		draw_circle(c, 26 * k, fond.darkened(0.3))
		draw_arc(c, 26 * k, 0, TAU, 40, bord, 2.0 * k, true)
		_ecrire("?", Vector2(c.x, c.y - 17 * k), 40 * k, 26, bord, true)
		var nom := "Un souvenir à trouver" if donnees.kind == "souvenir" else str(donnees.nom)
		_ecrire(nom, Vector2(w / 2.0, 18 * k), w - 28 * k, 11.5, Color(1, 1, 1, 0.75), true, 3)
		if int(donnees.seuil) > 0:
			_ecrire("s'ouvre à", Vector2(w / 2.0, h - 50 * k), w - 20 * k, 10, Color(1, 1, 1, 0.6))
			_ecrire(Game.fmt(int(donnees.seuil)) + " gagnés", Vector2(w / 2.0, h - 36 * k), w - 20 * k, 13, bord, true)

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
