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
	_mot(col, "LE BUREAU DU PRÉSIDENT", DOUX, 13)
	_mot(col, str(club.nom).to_upper(), OR, 26)
	var ici: Array = b.place_de(commune)
	if ici.is_empty() or not b.clubs.has(commune):
		_mot(col, "Le club n'est pas encore au championnat.", DOUX)
		_fermer(col)
		return
	_mot(col, b.phrase_actionnaires(commune), OR, 15)
	# Ce qui empêche de décider, dit tout de suite plutôt qu'au premier clic.
	var refus: String = b.refus_bureau(commune)
	if refus != "":
		_mot(col, pourquoi(refus) + (" Vous pouvez tout lire, sans rien changer." if refus in ["compte", "parts"] else ""), ROUGE, 15)
	# Renommer le club : son dirigeant, s'il en tient des parts (demande de Guillaume du 23 octobre 2026).
	if refus == "" and b.investi(commune) > 0:
		var r := _rangee(col)
		_mot(r, "Le nom du club :", DOUX, 15)
		var saisie := LineEdit.new()
		saisie.name = "NomDuClub"
		saisie.text = _nom_saisi if _nom_saisi != "" else str(club.nom)
		saisie.max_length = 40
		saisie.custom_minimum_size.x = 320
		saisie.text_changed.connect(func(t): _nom_saisi = t)
		r.add_child(saisie)
		_bouton(r, "Renommer", func(): _renommer(saisie.text), "Renommer")
	var onglets := _rangee(col)
	for p in [["equipe", "L'équipe"], ["marche", "Le marché"], ["comptes", "Les comptes"]]:
		var bt := _bouton(onglets, p[1], func(): page = p[0]; _message = ""; rafraichir(), "Onglet_" + p[0])
		bt.disabled = page == p[0]
	if _message != "":
		_mot(col, _message, ROUGE if _message.begins_with("!") else OR, 15).text = _message.trim_prefix("!")
	_filet(col)
	if b.cliches.is_empty():
		_mot(col, "Les notes des joueurs ne sont pas encore arrivées : il faut être connecté une première fois.", DOUX)
	elif not b.tirage_fait(commune) and page != "comptes":
		_mot(col, "L'effectif n'est pas encore tiré : les dix joueurs du club arrivent avec les premières notes, %s au soir. Le marché ouvre ensuite, et la première journée se joue le samedi à 20 h." % preload("res://scripts/socle/basket_club.gd")._jour(b.quand_tirage()), TEXTE, 16)
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
	_mot(h, "Consigne pour la journée %d :" % prochaine, TEXTE, 16)
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
	_mot(col, "L'effectif (%d joueurs, %s crédits de salaires par journée sur %s permis)" % [joueurs.size(), Game.fmt(b.masse_salariale(commune, maxi(1, j))), Game.fmt(b.PLAFOND)], OR, 18)
	for e in joueurs:
		var f: Dictionary = fiches[e.code]
		var r := _rangee(col)
		var d: Dictionary = f.get("derniere", {})
		var reel := ""
		if not d.is_empty():
			reel = " — %s : %d pts, %d reb, %d pd (PIR %d) contre %s" % [d.date, d.pts, d.reb, d.pd, d.pir, d.adv]
		var texte := "%d %s  %s (%s, %s)  ·  %s par journée%s" % [int(f.get("note", 0)), fleche(int(f.get("forme", 0))), str(f.get("nom", e.code)),
			str(f.get("club", "?")), str(f.get("poste", "")).to_lower(), Game.fmt(int(e.salaire)), reel]
		var l := _mot(r, texte, TEXTE if bool(f.get("dispo", false)) else DOUX, 14)
		l.custom_minimum_size.x = 640
		if liberes.has(e.code):
			_mot(r, "libéré jeudi", ROUGE, 14)
		elif jm > 0 and decide:
			_bouton(r, "Libérer", func(): _liberer(e.code), "Liberer_" + e.code)
	if jm > 0:
		_mot(col, "Un joueur libéré quitte le club à la clôture du jeudi %s ; il compte pour la moitié de son salaire jusqu'à la fin de la saison." % _date(b.cloture(b.saison, jm)), DOUX, 13)


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
	_mot(col, "Les joueurs libres du groupe, pour la journée %d. Clôture le jeudi %s à 22 h ; le joueur arrive avant le cliché du vendredi." % [jm, _date(b.cloture(b.saison, jm))], TEXTE, 15)
	_mot(col, "Place pour %d joueur%s ; %s crédits de salaires encore permis par journée. Une offre qui ne tient pas dans l'effectif ou sous le plafond à la clôture ne compte pas." % [maxi(0, places), "s" if places > 1 else "", Game.fmt(maxi(0, reste))], DOUX, 14)
	var h := _rangee(col)
	for t in [["note", "Les meilleures notes"], ["forme", "Ceux qui montent"]]:
		var bt := _bouton(h, t[1], func(): tri = t[0]; rafraichir(), "Tri_" + t[0])
		bt.disabled = tri == t[0]
	var libres: Array = b.joueurs_libres(commune)
	if tri == "forme":
		libres = libres.filter(func(x): return int(x.forme) > 0)
	var decide: bool = b.peut_decider(commune)
	for x in libres.slice(0, 30):
		var r := _rangee(col)
		var offre := ""
		if int(x.offre) > 0:
			offre = "  ·  meilleure offre %s (%s)" % [Game.fmt(int(x.offre)), "vous" if bool(x.moi) else b.fiche(str(x.meneur)).nom]
		var l := _mot(r, "%d %s  %s (%s, %s)  ·  départ %s, salaire %s%s" % [int(x.note), fleche(int(x.forme)), x.nom, x.club, str(x.comp),
			Game.fmt(int(x.prix)), Game.fmt(int(x.salaire)), offre], TEXTE, 14)
		l.custom_minimum_size.x = 560
		if not decide:
			continue
		var minimum: int = maxi(int(x.prix), int(x.offre) + b.pas(int(x.offre)) if int(x.offre) > 0 else 0)
		var saisie := LineEdit.new()
		saisie.name = "Mise_" + str(x.code)
		saisie.text = str(_mises.get(x.code, minimum))
		saisie.custom_minimum_size.x = 90
		saisie.text_changed.connect(func(t): _mises[x.code] = t)
		r.add_child(saisie)
		_bouton(r, "Enchérir", func(): _encherir(str(x.code), int(saisie.text)), "Encherir_" + str(x.code))
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
	_mot(col, "Masse salariale : %s crédits par journée, sur %s permis." % [Game.fmt(masse), Game.fmt(b.PLAFOND)], TEXTE)
	_mot(col, "Recette d'une journée : %s crédits ×%.1f au classement d'aujourd'hui." % [Game.fmt(b.RECETTE), facteur], TEXTE)
	_mot(col, "Bénéfice partagé entre les obligations : %s crédits par journée." % Game.fmt(int(maxf(0.0, b.RECETTE * facteur - masse))), OR)
	_filet(col)
	var inv: int = b.investi(commune)
	if inv > 0:
		var par_journee := 0
		for r in b.mes_obligations(commune):
			par_journee += b.dividende(commune, r, maxi(1, b.journee_jouee()))
		_mot(col, "Vous avez %s crédits dans le club (obligations n° %s), qui rapportent environ %s crédits par journée." % [Game.fmt(inv), ", ".join(b.mes_obligations(commune).map(func(x): return str(x))), Game.fmt(par_journee)], TEXTE)
	else:
		_mot(col, "Vous n'avez pas d'obligation du club : le tableau des parts est à l'entrée du grand hall.", DOUX)
	var mises := 0
	for lot in b.retenues:
		mises += int(b.retenues[lot])
	if mises > 0:
		_mot(col, "Mises en cours au marché : %s crédits retenus." % Game.fmt(mises), TEXTE)
	_mot(col, "Dividendes du basket touchés depuis le début : %s crédits. Vous avez %s crédits." % [Game.fmt(int(b.dividendes_total)), Game.fmt(Game.credits)], DOUX)


# ---------------------------------------------------------------- outils

func _apres(r: Dictionary, bien: String) -> void:
	_message = bien if r.get("ok", false) else "!" + pourquoi(str(r.get("raison", "")))
	rafraichir()


static func _date(t: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(t)
	return "%d/%02d" % [d.day, d.month]
