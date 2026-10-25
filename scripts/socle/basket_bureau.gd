extends "res://scripts/socle/basket_ecran.gd"
## Le bureau du président du club de basket, dans la pièce du président (porte « Vestiaires · Bureau du
## club », fil de la salle). Trois pages :
## - l'équipe : les dix vrais joueurs, leur note de la semaine, leur forme, leur salaire fixé à l'achat et
##   leur dernier match réel ; la consigne du prochain match (titulaires ou rotation large) ; libérer un
##   joueur (il coûte encore la moitié de son salaire jusqu'à la fin de la saison) ;
## - le marché : les vrais joueurs libres du groupe, aux enchères jusqu'au jeudi 22 h, avant le cliché du
##   vendredi. Le prix de départ suit la note, le salaire est fixé à l'achat ; la meilleure offre d'un club
##   qui a une place et la masse salariale l'emporte. On mise de sa poche ; une mise dépassée est rendue ;
## - les comptes : la masse salariale sous le plafond, la recette, ce que versent les obligations.
## C'est celui qui a le plus investi dans le club qui décide (basket_parts.gd) ; les autres lisent.

## « equipe », « marche » ou « comptes ».
var page := "equipe"
## Le marché : « note » (les meilleures notes) ou « forme » (ceux qui montent).
var tri := "note"
var _message := ""
var _mises := {}
## Le nom en cours de saisie, gardé quand la fenêtre se redessine.
var _nom_saisi := ""


func ouvert() -> void:
	basket().lire()


func remplir(col: VBoxContainer) -> void:
	var b := basket()
	var club: Dictionary = b.fiche(commune)
	_mot(col, "LE BUREAU DU PRÉSIDENT", TEINTES.CRAYON, 12)
	_mot(col, str(club.nom).to_upper(), OR, 26)
	var ici: Array = b.place_de(commune)
	if ici.is_empty() or not b.clubs.has(commune):
		_mot(col, "Le club n'est pas encore au championnat.", DOUX)
		_fermer(col)
		return
	# Qui dirige, en une ligne et un (i) ; ce qui empêche de décider, dit tout de suite plutôt qu'au
	# premier clic, en une ligne rouge, le pourquoi dans le (i).
	var refus: String = b.refus_bureau(commune)
	var qui := _rangee(col)
	var dirige: bool = refus == "" and b.peut_decider(commune)
	_mot(qui, "✓ Vous dirigez" if dirige else "Lecture seule", VERT if dirige else ROUGE, 15).name = "Direction"
	qui.add_child(AIDE.creer(b.phrase_actionnaires(commune) + ("\n" + pourquoi(refus) if refus != "" else "")))
	# Renommer le club : son dirigeant, s'il en tient des parts (demande de Guillaume du 23 octobre 2026).
	if refus == "" and b.investi(commune) > 0:
		var r := _rangee(col)
		var saisie := LineEdit.new()
		saisie.name = "NomDuClub"
		saisie.text = _nom_saisi if _nom_saisi != "" else str(club.nom)
		saisie.max_length = 40
		saisie.custom_minimum_size.x = 320
		saisie.text_changed.connect(func(t): _nom_saisi = t)
		r.add_child(saisie)
		saisie.tooltip_text = "Le nom du club, pour tous les joueurs (3 à 40 caractères)."
		_bouton(r, "Renommer", func(): _renommer(saisie.text), "Renommer", "registre")
	var onglets := _rangee(col)
	for p in [["equipe", "L'équipe", "effectif"], ["marche", "Le marché", "mercato"], ["comptes", "Les comptes", "comptes"]]:
		var bt := _bouton(onglets, p[1], func(): page = p[0]; _message = ""; rafraichir(), "Onglet_" + p[0], p[2])
		bt.disabled = page == p[0]
	if _message != "":
		_mot(col, _message, ROUGE if _message.begins_with("!") else OR, 15).text = _message.trim_prefix("!")
	_filet(col)
	if b.cliches.is_empty():
		_mot(col, "Les notes des joueurs ne sont pas encore arrivées : il faut être connecté une première fois.", DOUX)
	elif not b.tirage_fait(commune) and page != "comptes":
		var l := _mot(col, "L'effectif n'est pas encore tiré : il arrive %s au soir." % preload("res://scripts/socle/basket_club.gd")._jour(b.quand_tirage()), TEXTE, 16)
		AIDE.poser(l, "Les dix joueurs du club arrivent avec les premières notes. Le marché ouvre ensuite, et la première journée se joue le samedi à 20 h.")
	elif page == "marche":
		_marche(col)
	elif page == "comptes":
		_comptes(col)
	else:
		_equipe(col)
	_fermer(col)


# ---------------------------------------------------------------- l'équipe

func _equipe(col: VBoxContainer) -> void:
	var b := basket()
	var ici: Array = b.place_de(commune)
	var jm: int = b.journee_du_marche()
	var j: int = jm - 1 if jm > 0 else b.JOURNEES
	var prochaine: int = mini(b.journee_jouee() + 1, b.JOURNEES)
	var decide: bool = b.peut_decider(commune)
	var consigne: String = b.consigne_de(b.saison, prochaine, commune)
	var h := _rangee(col)
	_mot(h, "Consigne pour la journée %d" % prochaine, DOUX, 15)
	for c in [["titulaires", "Les titulaires"], ["rotation", "Rotation large"]]:
		var bt := _bouton(h, c[1], func(): _consigne(c[0]), "Consigne_" + c[0])
		bt.disabled = consigne == c[0] or not decide
	var cl: Dictionary = b.cliche(b.id_cliche(b.saison, maxi(1, j)))
	var liberes: Array = b.liberations_prevues(commune)
	var joueurs: Array = (b.effectif(b.saison, ici[0], ici[1], ici[2], maxi(1, j)) as Array).duplicate()
	var fiches := {}
	for e in joueurs:
		fiches[e.code] = cl.get("joueurs", {}).get(e.code, {})
	joueurs.sort_custom(func(a, x): return int(fiches[a.code].get("note", 0)) > int(fiches[x.code].get("note", 0)))
	var masse: int = b.masse_salariale(commune, maxi(1, j))
	_tuiles(col, [["Effectif", "%d / %d" % [joueurs.size(), b.EFFECTIF], "joueurs", TEXTE, ""],
		["Salaires", Game.fmt(masse), "sur %s / j." % Game.fmt(b.PLAFOND), ROUGE if masse > b.PLAFOND else TEXTE,
			"La masse salariale d'une journée, sous le plafond de la ligue. Au-dessus, le marché refuse les offres qui ne tiennent pas."]])
	var t := _mot(col, "L'EFFECTIF", TEINTES.CRAYON, 12)
	AIDE.poser(t, "Note de la semaine sur 100, ▲ en forme, ▼ en baisse ; en gris, un joueur absent de son dernier match. Éval. : l'évaluation du match (points, rebonds, passes, moins les tirs manqués et les ballons perdus)."
		+ ("\nUn joueur libéré quitte le club à la clôture du jeudi %s ; il compte pour la moitié de son salaire jusqu'à la fin de la saison." % _date(b.cloture(b.saison, jm)) if jm > 0 else ""))
	# Un tableau, comme l'effectif de l'Étoile : une colonne par donnée, plutôt qu'une ligne de base de données.
	# Le dernier match réel en colonnes (points, rebonds, passes, évaluation), comme les statistiques de
	# Football Manager, plutôt qu'en une phrase.
	var g := _tableau(col, ["Note", "", "Joueur", "Poste", "Club", "Salaire", "Match", "Pts", "Rbd", "Pd", "Éval.", "Adv.", ""])
	for e in joueurs:
		var f: Dictionary = fiches[e.code]
		var dispo := bool(f.get("dispo", false))
		_cellules(g, [str(int(f.get("note", 0))), fleche(int(f.get("forme", 0))), nom_lisible(str(f.get("nom", e.code))), poste_fr(str(f.get("poste", ""))),
			str(f.get("club", "?")), "%s / j." % Game.fmt(int(e.salaire))] + colonnes_match(f.get("derniere", {})), dispo)
		if liberes.has(e.code):
			_mot(g, "libéré jeudi", ROUGE, 14)
		elif jm > 0 and decide:
			_bouton(g, "Libérer", func(): _liberer(e.code), "Liberer_" + e.code)
		else:
			g.add_child(Control.new())


func _renommer(nom: String) -> void:
	var r: Dictionary = await basket().renommer(commune, nom)
	if r.get("ok", false):
		_nom_saisi = ""
	_apres(r, "Le club s'appelle désormais %s, pour tous les joueurs." % basket().fiche(commune).nom)


func _consigne(c: String) -> void:
	var r: Dictionary = await basket().poser_consigne(commune, c)
	_apres(r, "Consigne posée.")


func _liberer(code: String) -> void:
	var r: Dictionary = await basket().liberer(commune, code)
	_apres(r, "Le joueur partira à la clôture du marché.")


# ---------------------------------------------------------------- le marché

func _marche(col: VBoxContainer) -> void:
	var b := basket()
	var jm: int = b.journee_du_marche()
	if jm == 0:
		_mot(col, "Le marché est fermé jusqu'à la saison prochaine.", DOUX)
		return
	var ici: Array = b.place_de(commune)
	var places: int = b.EFFECTIF - (b.effectif(b.saison, ici[0], ici[1], ici[2], jm - 1) as Array).size() + b.liberations_prevues(commune).size()
	var reste: int = b.PLAFOND - b.masse_salariale(commune, jm - 1)
	_tuiles(col, [["Clôture", "jeu. %s" % _date(b.cloture(b.saison, jm)), "à 22 h · journée %d" % jm, OR,
			"Les joueurs libres du groupe, aux enchères jusqu'au jeudi 22 h ; le joueur arrive avant le cliché du vendredi. Une mise dépassée est rendue."],
		["Places", str(maxi(0, places)), "dans l'effectif", TEXTE if places > 0 else ROUGE, ""],
		["Salaires permis", Game.fmt(maxi(0, reste)), "par journée", TEXTE if reste > 0 else ROUGE,
			"Une offre qui ne tient pas dans l'effectif ou sous le plafond à la clôture ne compte pas."]])
	var t := _mot(col, "LES JOUEURS LIBRES DU GROUPE", TEINTES.CRAYON, 12)
	t.name = "Libres"
	var h := _rangee(col)
	for x in [["note", "Les meilleures notes"], ["forme", "Ceux qui montent"]]:
		var bt := _bouton(h, x[1], func(): tri = x[0]; rafraichir(), "Tri_" + x[0], "classement")
		bt.disabled = tri == x[0]
	var libres: Array = b.joueurs_libres(commune)
	if tri == "forme":
		libres = libres.filter(func(x): return int(x.forme) > 0)
	var decide: bool = b.peut_decider(commune)
	var g := _tableau(col, ["Note", "", "Joueur", "Poste", "Club", "Départ", "Salaire", "Meilleure offre", "", ""])
	for x in libres.slice(0, 30):
		var offre := "—"
		if int(x.offre) > 0:
			offre = "%s (%s)" % [Game.fmt(int(x.offre)), "vous" if bool(x.moi) else b.fiche(str(x.meneur)).nom]
		_cellules(g, [str(int(x.note)), fleche(int(x.forme)), nom_lisible(str(x.nom)), poste_fr(str(x.get("poste", ""))), str(x.club),
			Game.fmt(int(x.prix)), "%s / j." % Game.fmt(int(x.salaire)), offre], true)
		if not decide:
			g.add_child(Control.new())
			g.add_child(Control.new())
			continue
		var minimum: int = maxi(int(x.prix), int(x.offre) + b.pas(int(x.offre)) if int(x.offre) > 0 else 0)
		var saisie := LineEdit.new()
		saisie.name = "Mise_" + str(x.code)
		saisie.text = str(_mises.get(x.code, minimum))
		saisie.custom_minimum_size.x = 90
		saisie.text_changed.connect(func(t): _mises[x.code] = t)
		g.add_child(saisie)
		_bouton(g, "Enchérir", func(): _encherir(str(x.code), int(saisie.text)), "Encherir_" + str(x.code))
	if libres.is_empty():
		_mot(col, "Personne pour l'instant.", DOUX)


func _encherir(code: String, montant: int) -> void:
	var r: Dictionary = await basket().encherir(commune, code, montant)
	_mises.erase(code)
	_apres(r, "Offre posée : %s crédits retenus jusqu'à la clôture." % Game.fmt(montant))


# ---------------------------------------------------------------- les comptes

func _comptes(col: VBoxContainer) -> void:
	var b := basket()
	var j: int = maxi(1, b.journee_jouee())
	var masse: int = b.masse_salariale(commune, j)
	var facteur: float = b.recette_facteur(commune)
	var benefice := int(maxf(0.0, b.RECETTE * facteur - masse))
	var inv: int = b.investi(commune)
	var par_journee := 0
	for r in b.mes_obligations(commune):
		par_journee += b.dividende(commune, r, maxi(1, b.journee_jouee()))
	var mises := 0
	for lot in b.retenues:
		mises += int(b.retenues[lot])
	# Un tableau de comptes, à la Football Manager : le chiffre à droite, le calcul dans le (i).
	_tuiles(col, [["Bénéfice", Game.fmt(benefice), "par journée", OR if benefice > 0 else ROUGE,
			"La recette d'une journée moins la masse salariale, partagée entre les obligations du club."],
		["Vos obligations", Game.fmt(inv) if inv > 0 else "—", "≈ %s par journée" % Game.fmt(par_journee) if inv > 0 else "aucune", TEXTE,
			"Maître Garnier cède les obligations du club à l'étude." if inv == 0 else "Obligations n° %s." % ", ".join(b.mes_obligations(commune).map(func(x): return str(x)))]])
	_mot(col, "LES COMPTES D'UNE JOURNÉE", TEINTES.CRAYON, 12)
	var lignes := [["Recette", "%s × %.1f" % [Game.fmt(b.RECETTE), facteur], TEXTE, "La recette de base, multipliée selon le classement d'aujourd'hui."],
		["Masse salariale", "%s / %s" % [Game.fmt(masse), Game.fmt(b.PLAFOND)], ROUGE if masse > b.PLAFOND else TEXTE, "Les salaires d'une journée, sur le plafond permis."],
		["Bénéfice partagé", Game.fmt(benefice), OR, ""], [],
		["Dividendes touchés", Game.fmt(int(b.dividendes_total)), TEXTE, "Depuis le début, toutes saisons du basket."]]
	if mises > 0:
		lignes.append(["Mises au marché", Game.fmt(mises), TEXTE, "Retenues jusqu'à la clôture ; rendues si l'offre est dépassée."])
	lignes.append(["Vos crédits", Game.fmt(Game.credits), DOUX, ""])
	_comptes_en_lignes(col, lignes)


# ---------------------------------------------------------------- outils

## Un tableau à colonnes, sa ligne de titres en petit : rend la grille, qu'on remplit rangée par rangée.
func _tableau(col: VBoxContainer, titres: Array) -> GridContainer:
	var g := GridContainer.new()
	g.columns = titres.size()
	g.add_theme_constant_override("h_separation", 14)
	g.add_theme_constant_override("v_separation", 6)
	col.add_child(g)
	for t in titres:
		_mot(g, str(t).to_upper(), DOUX, 12)
	return g


## Les cellules d'une rangée, en clair si le joueur est disponible ; le nom en gras de couleur.
func _cellules(g: GridContainer, valeurs: Array, clair: bool) -> void:
	for i in valeurs.size():
		var l := _mot(g, str(valeurs[i]), (OR if i == 0 else TEXTE) if clair else DOUX, 15 if i != 2 else 16)
		# Les nombres à droite : la note, les prix, les salaires.
		var v := str(valeurs[i])
		if i == 0 or v.ends_with("/ j.") or v.replace(" ", "").replace("\u202f", "").replace("\u00a0", "").is_valid_int():
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


## « HORTON TUCKER, TALEN » devient « Talen Horton Tucker ».
static func nom_lisible(nom: String) -> String:
	var morceaux := nom.split(",", false, 1)
	var t := (morceaux[1].strip_edges() + " " + morceaux[0].strip_edges()) if morceaux.size() == 2 else nom
	var out: Array = []
	for mot in t.split(" ", false):
		out.append("-".join(Array(mot.split("-")).map(func(m): return m.substr(0, 1).to_upper() + m.substr(1).to_lower())))
	return " ".join(out)


## Le poste en français.
static func poste_fr(poste: String) -> String:
	return {"guard": "arrière", "forward": "ailier", "center": "pivot"}.get(poste.to_lower(), poste.to_lower())


## Le dernier match réel : « 20/03 · 23 pts, 1 rbd, 2 pd · éval. 19 · contre MIL ».
static func match_lisible(d: Dictionary) -> String:
	if d.is_empty():
		return "—"
	var date := str(d.get("date", ""))
	var jour := "%s/%s" % [date.substr(8, 2), date.substr(5, 2)] if date.length() >= 10 else date
	return "%s · %d pts, %d rbd, %d pd · éval. %d · contre %s" % [jour, int(d.pts), int(d.reb), int(d.pd), int(d.pir), str(d.adv)]

## Le dernier match réel en six colonnes : la date, les points, les rebonds, les passes, l'évaluation,
## l'adversaire ; des tirets s'il n'a pas joué.
static func colonnes_match(d: Dictionary) -> Array:
	if d.is_empty():
		return ["—", "", "", "", "", ""]
	var date := str(d.get("date", ""))
	var jour := "%s/%s" % [date.substr(8, 2), date.substr(5, 2)] if date.length() >= 10 else date
	return [jour, str(int(d.pts)), str(int(d.reb)), str(int(d.pd)), str(int(d.pir)), str(d.adv)]


func _apres(r: Dictionary, bien: String) -> void:
	_message = bien if r.get("ok", false) else "!" + pourquoi(str(r.get("raison", "")))
	rafraichir()


static func _date(t: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(t)
	return "%d/%02d" % [d.day, d.month]
