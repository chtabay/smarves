extends "res://scripts/socle/basket_ecran.gd"
## Le tableau des parts du club de basket, à l'entrée du grand hall de la salle (et à la table du conseil,
## dans la pièce du président) : les neuf obligations du club, comme au football, de 500 à 7 500 crédits,
## chacune en un seul exemplaire. La plus grosse somme investie dirige le club (le mercato, la consigne) ;
## on en prend toute l'année, et la direction change à la relève du lundi à midi (scripts/socle/diriger.gd) ;
## chaque journée jouée verse un dividende, la recette du match moins les salaires, au prorata de la
## valeur de l'obligation. On en prend une libre, on en rend une (reprise à 80 %). Les porteurs sont
## publics, comme le championnat ; il faut son compte Pyramides pour en prendre.

const DIRIGER := preload("res://scripts/socle/diriger.gd")

var _etat: Label
var _message := ""


func ouvert() -> void:
	var b := basket()
	b.lire()
	var verse: int = b.verser_dividendes()
	if verse > 0:
		_message = "Le club vous a versé %s crédits de dividendes." % Game.fmt(verse)


func remplir(col: VBoxContainer) -> void:
	var b := basket()
	var club: Dictionary = b.fiche(commune)
	_mot(col, "LES PARTS DU CLUB", DOUX, 13)
	_mot(col, str(club.nom).to_upper(), OR, 26)
	if not b.clubs.has(commune):
		_mot(col, "Le club n'est pas encore au championnat.", DOUX)
		_fermer(col)
		return
	_mot(col, b.phrase_actionnaires(commune), OR)
	# Ce qui manque pour diriger, calculé plutôt que laissé au joueur.
	_mot(col, DIRIGER.phrase(b, commune), TEXTE, 17).name = "PourDiriger"
	var suffit: int = int(DIRIGER.etat(b, commune).suffit)
	# Les parts se prennent toute l'année (demande du 31 octobre) ; la direction change à la relève.
	_mot(col, "Les parts se prennent toute l'année, et se rendent quand on veut. La direction d'un club change à la relève, le lundi à midi.", DOUX, 15).name = "Fenetre"
	var demande := DIRIGER.bouton_releve(b, commune)
	if demande != "":
		var changer: bool = bool(DIRIGER.relevable(b, commune).changer)
		_bouton(col, demande, func(): agir(await b.prendre_direction(commune, changer)), "ChangerDeClub" if changer else "DemanderDirection")
	elif int(DIRIGER.etat(b, commune).releve) > 0:
		_bouton(col, "Renoncer à la relève", func(): agir(await b.renoncer_direction()), "Renoncer")
	var facteur: float = b.recette_facteur(commune)
	var benefice := maxf(0.0, b.RECETTE * facteur - b.masse_salariale(commune))
	_mot(col, "À chaque journée jouée, le club partage sa recette (%s crédits, ×%.1f au classement d'aujourd'hui) moins ses salaires (%s) entre les obligations, au prorata de leur valeur. On en rend une à 80 %%." \
		% [Game.fmt(b.RECETTE), facteur, Game.fmt(b.masse_salariale(commune))], DOUX, 14)
	_filet(col)
	for r in range(1, b.OBLIGATIONS.size() + 1):
		var h := _rangee(col)
		var titre := _mot(h, "n° %d  ·  %s crédits  ·  environ %s par journée" % [r, Game.fmt(b.valeur(r)), Game.fmt(int(round(benefice * b.valeur(r) / float(b.TOTAL))))], TEXTE, 16)
		titre.custom_minimum_size.x = 420
		titre.autowrap_mode = TextServer.AUTOWRAP_OFF
		var p: Dictionary = b.porteur(commune, r)
		if p.is_empty():
			var bt := _bouton(h, "Prendre", func(): agir(b.prendre(commune, r)), "Prendre_%d" % r)
			bt.disabled = Game.credits < b.valeur(r)
			if r == suffit:
				_mot(h, "← pour diriger", OR, 15)
			if bt.disabled:
				_mot(h, DIRIGER.manque_credits(b.valeur(r)), DOUX, 14)
		elif bool(p.moi):
			_mot(h, "à vous", OR, 15)
			_bouton(h, "Rendre  (%s)" % Game.fmt(int(round(b.valeur(r) * b.RACHAT))), func(): agir(b.rendre(commune, r)), "Rendre_%d" % r)
		else:
			_mot(h, "tenue par %s" % str(p.nom), DOUX, 15)
	_filet(col)
	_etat = _mot(col, _message if _message != "" else _etat_texte(), DOUX, 15)
	# Les cartes des parts du club, comme au classeur du carnet (demande de Guillaume du 20 octobre).
	_bouton(col, "Voir les cartes des parts", func():
		preload("res://scripts/carnet_cartes.gd").ouvrir_club(self, "basket", commune), "VoirCartes")
	_bouton(col, "Le calendrier", func(): preload("res://scripts/socle/calendrier.gd").ouvrir(), "Calendrier")
	_fermer(col)


func agir(r: Dictionary) -> void:
	_message = "" if r.get("ok", false) else pourquoi(str(r.get("raison", "")))
	if r.get("releve", false):
		_message = "C'est noté : vous prenez la direction à la relève, %s." % DIRIGER.date(int(r.get("effet", 0)))
	rafraichir()


func _etat_texte() -> String:
	var b := basket()
	var inv: int = b.investi(commune)
	if inv <= 0:
		return "Vous n'avez rien dans le club. Vous avez %s crédits." % Game.fmt(Game.credits)
	return "Vous avez %s crédits dans le club et touché %s crédits de dividendes du basket. Vous avez %s crédits." \
		% [Game.fmt(inv), Game.fmt(int(b.dividendes_total)), Game.fmt(Game.credits)]
