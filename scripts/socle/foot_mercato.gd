class_name FootMercato
extends FootTableau
## Le mercato du président : le marché des transferts à la Hattrick (autoload Mercato, docs/SUITE.md
## section 6, « le mercato »). Trois pages sur la même ardoise :
## - le marché : les seize nouveaux de la semaine et les joueurs que les clubs remettent en vente, avec
##   leur date limite, le prix du moment et qui mène ;
## - la fiche d'un joueur, à la Hattrick : forme, expérience, endurance, les sept compétences en mots,
##   salaire, valeur, les offres, et la case où l'on tape sa mise (pas de limite, sinon sa poche) ;
## - l'effectif : les joueurs que le club a achetés au marché, qu'on peut remettre en vente.
## C'est celui qui dirige le club qui enchérit et vend, de sa poche, et il faut son compte Pyramides : les
## enchères comptent pour tous les villages. Hors ligne, on lit le dernier état connu.
##
## Elle emprunte au tableau du dimanche son ardoise et ses petites pièces ; s'ouvre et se ferme comme
## lui (signal closed, Échap). Le stade l'ouvre par open_mercato(), depuis la causerie.

var club := ""
## « marche », « fiche » (lot_ouvert) ou « effectif » ; une fiche de l'effectif garde joueur_ouvert.
var page := "marche"
var lot_ouvert := ""
var joueur_ouvert := ""
var _ligne_etat: Label
var _saisie: LineEdit
var _message := ""
var _minuteur: Timer
var _lu := 0.0


func _ready() -> void:
	_preparer()
	if "--marche-demo" in OS.get_cmdline_user_args():
		demo(mercato(), club)
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
	remplir(_colonne)


func remplir(colonne: VBoxContainer) -> void:
	_vider(colonne)
	_saisie = null
	var f := foot()
	var c: Dictionary = f.clubs.get(club, {})
	colonne.add_child(_mot("L E   M E R C A T O", 13, DOUX))
	colonne.add_child(_mot(str(c.get("nom", "Le club")), 26 if _etroit() else 34, CRAIE, Polices.titre(), _etroit()))
	var onglets := HFlowContainer.new()
	onglets.add_theme_constant_override("h_separation", 10)
	onglets.add_theme_constant_override("v_separation", 6)
	colonne.add_child(onglets)
	var m := mercato()
	var t: int = m.maintenant()
	var miens: Array = m.joueurs_de(club, t)
	for o in [["marche", "Le marché"], ["effectif", "Nos joueurs du marché  (%d)" % miens.size()]]:
		var b := _bouton(o[1], func(): aller(o[0]), 15)
		b.name = "Onglet_" + o[0]
		b.disabled = page == o[0]
		onglets.add_child(b)
	for n in m.nouvelles.slice(0, 2):
		colonne.add_child(_mot(str(n), 15, OR, null, true))
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
		_:
			_marche(corps)
	var defile := ScrollContainer.new()
	defile.name = "Corps"
	defile.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	defile.add_child(corps)
	var haut_max := _ecran().y - (290.0 if _etroit() else 400.0) - 24.0 * mini(m.nouvelles.size(), 2)
	defile.custom_minimum_size = Vector2(0.0 if _etroit() else minf(1080.0, _ecran().x - 160.0),
		clampf(corps.get_combined_minimum_size().y, 120.0, maxf(160.0, haut_max)))
	colonne.add_child(defile)
	colonne.add_child(_filet())
	_ligne_etat = _mot(_message if _message != "" else _etat_texte(), 15, DOUX, null, true)
	colonne.add_child(_ligne_etat)
	var bas := HFlowContainer.new()
	bas.alignment = FlowContainer.ALIGNMENT_END
	bas.add_theme_constant_override("h_separation", 10)
	colonne.add_child(bas)
	if page == "fiche":
		bas.add_child(_bouton("Retour", func(): aller("effectif" if joueur_ouvert != "" else "marche")))
	bas.add_child(_bouton("Laisser le président  (Échap)", func(): closed.emit()))


func aller(p: String) -> void:
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

func _marche(colonne: VBoxContainer) -> void:
	var m := mercato()
	var t: int = m.maintenant()
	var k: int = m.semaine_a(t)
	colonne.add_child(_mot("Seize joueurs mis en vente chaque dimanche à 17 h par les clubs de la Vienne, aux enchères jusqu'à leur date limite. Le plus offrant l'emporte.", 15, DOUX, null, true))
	var liste := VBoxContainer.new()
	liste.add_theme_constant_override("separation", 4 if _etroit() else 6)
	var lots: Array = m.lots_semaine(k)
	for e in m.ventes():
		if e.valable and (not e.ferme or t - int(e.echeance) < 3 * 86400):
			lots.append(e)
	var ouverts := lots.filter(func(e): return not e.ferme)
	var clos := lots.filter(func(e): return e.ferme)
	ouverts.sort_custom(func(a, b): return int(a.echeance) < int(b.echeance))
	clos.sort_custom(func(a, b): return int(a.echeance) > int(b.echeance))
	liste.add_child(_mot("En vente  ·  %d" % ouverts.size(), 19, CRAIE, Polices.gras()))
	if ouverts.is_empty():
		liste.add_child(_mot("Plus rien en vente cette semaine : les nouveaux arrivent dimanche à 17 h.", 15, DOUX, null, true))
	for e in ouverts:
		liste.add_child(_rangee(e))
	if not clos.is_empty():
		liste.add_child(_mot("Partis cette semaine", 19, CRAIE, Polices.gras()))
		for e in clos:
			liste.add_child(_rangee(e))
	colonne.add_child(liste)


func _rangee(e: Dictionary) -> Control:
	var m := mercato()
	var j: Dictionary = e.joueur
	var h := HFlowContainer.new()
	h.name = "Lot_" + str(e.lot)
	h.add_theme_constant_override("h_separation", 12)
	h.add_theme_constant_override("v_separation", 2)
	var nom := _mot("%s %s" % [j.prenom, j.nom], 15, CRAIE, Polices.gras())
	nom.custom_minimum_size.x = 170 if _etroit() else 200
	h.add_child(nom)
	var fiche := _mot("%s  ·  %d ans  ·  note %d" % [FootMatch.POSTES.get(j.poste, j.poste), j.age, j.note], 14, DOUX)
	fiche.custom_minimum_size.x = 210 if _etroit() else 240
	h.add_child(fiche)
	var quand := _mot(_echeance_courte(e), 14, DOUX)
	quand.custom_minimum_size.x = 130
	h.add_child(quand)
	var prix := _mot(_prix_texte(e), 14, OR if e.meneur == club else CRAIE)
	prix.custom_minimum_size.x = 250 if _etroit() else 300
	h.add_child(prix)
	var b := _bouton("Enchérir" if not e.ferme else "Fiche", func(): ouvrir(str(e.lot)), 14)
	b.name = "Fiche_" + str(e.lot)
	h.add_child(b)
	return h


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
		return "%s  ·  %s" % [fmt, _qui(e, e.gagnant)]
	if e.meneur == "":
		return "mise à prix %s" % fmt
	return "%s  ·  %s" % [fmt, _qui(e, e.meneur)]


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
	colonne.add_child(_mot("%s %s" % [j.prenom, j.nom], 24 if _etroit() else 28, CRAIE, Polices.gras()))
	var origine := ""
	if not e.is_empty():
		origine = "mis en vente par %s" % e.vendeur
	colonne.add_child(_mot("%s  ·  %d ans  ·  note %d%s" % [FootMatch.POSTES.get(j.poste, j.poste), j.age, j.note, "  ·  " + origine if origine != "" else ""], 16, DOUX, null, true))
	var rang: Container = HFlowContainer.new() if _etroit() else HBoxContainer.new()
	rang.add_theme_constant_override("separation", 36)
	rang.add_theme_constant_override("h_separation", 36)
	rang.add_theme_constant_override("v_separation", 10)
	colonne.add_child(rang)

	# À gauche, le joueur : à la Hattrick, en mots.
	var gauche := VBoxContainer.new()
	gauche.add_theme_constant_override("separation", 4)
	rang.add_child(gauche)
	gauche.add_child(_mot("Forme : %s (%d)    Expérience : %s (%d)" % [m.FORMES[int(j.forme)], int(j.forme), m.NIVEAUX[clampi(int(j.experience), 0, 20)], int(j.experience)], 15, CRAIE))
	var grille := GridContainer.new()
	grille.name = "Competences"
	grille.columns = 3
	grille.add_theme_constant_override("h_separation", 12)
	grille.add_theme_constant_override("v_separation", 3)
	gauche.add_child(grille)
	for cle in ["endurance", "gardien", "defense", "jeu", "aile", "passe", "but", "cpa"]:
		var v := float(j.competences.get(cle, 0))
		grille.add_child(_mot({"cpa": "Coups de pied arrêtés", "jeu": "Construction", "aile": "Ailes", "passe": "Passes", "but": "Buteur"}.get(cle, FootMatch.COMPETENCES[cle]), 14, DOUX))
		grille.add_child(_barre(v))
		grille.add_child(_mot("%s (%d)" % [m.mot_niveau(v), m.niveau(v)], 14, CRAIE))
	gauche.add_child(_mot("Salaire : %s crédits la semaine    Valeur estimée : %s crédits" % [Game.fmt(int(j.salaire)), Game.fmt(int(j.valeur))], 15, DOUX, null, _etroit()))

	# À droite, l'enchère : la date limite, les offres, la mise.
	var droite := VBoxContainer.new()
	droite.add_theme_constant_override("separation", 6)
	droite.custom_minimum_size.x = 300 if _etroit() else 400
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
	for o in e.offres.slice(0, 4):
		droite.add_child(_texte(droite, "%s crédits  ·  %s, pour %s" % [Game.fmt(int(o.montant)), "vous" if bool(o.get("moi", false)) else str(o.par), foot().clubs.get(o.club, {}).get("nom", o.club)], 14, DOUX))
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
	l.custom_minimum_size.x = 300 if _etroit() else 400
	return l


func _ajouter(x: int) -> void:
	if _saisie != null:
		_saisie.text = str(int(_saisie.text.to_int()) + x)


func _barre(v: float) -> Control:
	var fond := ColorRect.new()
	fond.color = Color(1, 1, 1, 0.08)
	fond.custom_minimum_size = Vector2(90 if _etroit() else 140, 10)
	fond.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var plein := ColorRect.new()
	plein.color = Color(OR, 0.75)
	plein.size = Vector2(fond.custom_minimum_size.x * clampf(v / 100.0, 0.0, 1.0), 10)
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
	# La semaine d'avant : le club a gagné deux joueurs, l'autre club un, qu'il remet en vente.
	for i in [2, 9]:
		var lot := "s%d-%d" % [k - 1, i]
		var e: Dictionary = m.enchere(lot)
		encheres.append({"lot": lot, "club": club, "montant": int(e.plafond) + 40, "par": "vous", "moi": true, "quand": "2026-10-12 10:00:00.000"})
	var lot_autre := "s%d-5" % (k - 1)
	encheres.append({"lot": lot_autre, "club": autre, "montant": int(m.enchere(lot_autre).plafond) + 100, "par": "Lucien", "moi": false, "quand": "2026-10-12 11:00:00.000"})
	var heure := func(x: int) -> String: return Time.get_datetime_string_from_unix_time(x, true)
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
