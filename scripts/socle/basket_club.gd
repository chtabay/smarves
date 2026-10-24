extends "res://scripts/socle/basket_ecran.gd"
## L'accueil du club de basket : la porte d'entrée de la gestion, qu'on ouvre de partout dans la salle (le
## bouton « Le club », la touche B, le comptoir de l'accueil du hall). Guillaume n'avait trouvé ni son club
## ni comment le gérer (22 octobre 2026) : ici, d'un coup d'œil, qui dirige, ce qu'il reste à faire pour
## diriger, et les trois écrans du club (le bureau du président, le notaire au téléphone, le panneau). Le bouton choisi
## est rangé dans « suite » avant la fermeture : la salle ouvre alors l'écran demandé.

## L'écran que la salle doit ouvrir en refermant l'accueil : « bureau », « notaire », « panneau » ou « ».
var suite := ""


func ouvert() -> void:
	basket().lire()
	# Une connexion faite d'ici (le bouton de l'étape 2) redessine l'accueil.
	var compte: Node = basket()._compte()
	if compte != null and compte.has_signal("change"):
		compte.change.connect(rafraichir)


func remplir(col: VBoxContainer) -> void:
	var b := basket()
	var club: Dictionary = b.fiche(commune)
	_mot(col, "L'ACCUEIL DU CLUB", DOUX, 13)
	_mot(col, str(club.nom).to_upper(), OR, 28)
	var ici: Array = b.place_de(commune)
	if ici.is_empty() or not b.clubs.has(commune):
		_mot(col, "Le club n'est pas encore au championnat : il y entre dès que sa salle est déclarée.", DOUX)
		_fermer(col)
		return
	var cl: Array = b.classement(b.saison, ici[0], ici[1])
	var rang := 0
	for i in cl.size():
		if cl[i].club == commune:
			rang = i + 1
	var jj: int = b.journee_jouee()
	_mot(col, "Saison %d · niveau %d%s · %s" % [b.saison, ici[0] + 1, " (groupe %d)" % (ici[1] + 1) if b.niveaux[ici[0]].size() > 1 else "",
		"%de sur %d après %d journée%s" % [rang, cl.size(), jj, "s" if jj > 1 else ""] if jj > 0 else "la saison n'a pas commencé"], TEXTE, 16)
	var m: Dictionary = b.match_pour_salle(commune)
	if not m.is_empty():
		if m.fini:
			_mot(col, "Dernier match : %s %d – %d %s" % [m.dom, m.score[0], m.score[1], m.ext], TEXTE, 16)
		else:
			_mot(col, "Prochain match : %s – %s, %s" % [m.dom, m.ext, m.quand], TEXTE, 16)
	# La saison en une phrase : l'intersaison (où se prennent les parts) et le marché.
	_mot(col, preload("res://scripts/socle/calendrier.gd").resume(b, "basket"), DOUX, 15)
	_filet(col)
	_mot(col, "Pour diriger le club", OR, 19)
	for e in etapes():
		var r := _rangee(col)
		_mot(r, "✓" if e.fait else "→", Color(0.45, 0.8, 0.5) if e.fait else OR, 18)
		_mot(r, e.titre, DOUX if e.fait else TEXTE, 17)
		# Le détail sous son titre, en retrait.
		var marge := MarginContainer.new()
		marge.add_theme_constant_override("margin_left", 26)
		col.add_child(marge)
		var detail := VBoxContainer.new()
		marge.add_child(detail)
		_mot(detail, e.texte, DOUX, 15)
		if e.has("action"):
			_bouton(detail, e.action[0], e.action[1], e.action[2]).size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_filet(col)
	for x in [["bureau", "Le bureau du président", "l'équipe, la consigne, le marché, les comptes"],
			["notaire", "Le notaire", "prendre ou rendre une part, par téléphone"],
			["panneau", "Le classement et le match", "l'affiche, la poule, l'équipe"]]:
		var bt := _bouton(col, "%s  ·  %s" % [x[1], x[2]], func(): suite = x[0]; closed.emit(), "Aller_" + x[0])
		bt.alignment = HORIZONTAL_ALIGNMENT_LEFT
		bt.add_theme_font_size_override("font_size", 17)
	var cal := _bouton(col, "Le calendrier  ·  les journées, l'intersaison, le marché, au carnet", func(): preload("res://scripts/socle/calendrier.gd").ouvrir(), "Calendrier")
	cal.alignment = HORIZONTAL_ALIGNMENT_LEFT
	cal.add_theme_font_size_override("font_size", 17)
	_fermer(col)


## Les quatre étapes pour diriger le club, avec leur état : [{titre, texte, fait}].
func etapes() -> Array:
	var b := basket()
	var out: Array = []
	var a: Array = b.actionnaires(commune)
	var dirige: bool = b.peut_decider(commune)
	var inv: int = b.investi(commune)
	var texte := ""
	if a.is_empty():
		texte = "Personne ne tient de part : le bureau est ouvert à tous. Une part, dès 500 crédits, vous en fait le premier dirigeant, et chaque journée lui verse un dividende. Les parts se prennent à l'intersaison, %s." % preload("res://scripts/socle/diriger.gd").phrase_intersaison(b)
	elif dirige:
		texte = "Vous avez %s crédits dans le club : c'est vous qui le dirigez. Son nom se change au bureau du président." % Game.fmt(inv)
	else:
		texte = preload("res://scripts/socle/diriger.gd").phrase(b, commune) + " Les parts se signent chez le notaire."
	out.append({"titre": "Prendre des parts du club", "texte": texte, "fait": inv > 0 and dirige})
	var connecte: bool = b.connecte()
	var connexion := {"titre": "Être connecté à son compte Pyramides", "fait": connecte,
		"texte": "Vous êtes connecté : vos parts et vos offres comptent pour tout le monde." if connecte else
			"Les parts, le marché et la consigne passent par le serveur, comme pour les autres joueurs : la page de connexion s'ouvre dans le navigateur."}
	var compte: Node = b._compte()
	if not connecte and compte != null:
		connexion.action = ["Se connecter avec Pyramides", compte.se_connecter, "SeConnecter"]
	out.append(connexion)
	var tire: bool = b.tirage_fait(commune)
	var ici: Array = b.place_de(commune)
	var n := 0
	if tire:
		n = (b.effectif(b.saison, ici[0], ici[1], ici[2], maxi(1, b.journee_jouee())) as Array).size()
	out.append({"titre": "Recevoir l'effectif", "fait": tire,
		"texte": "Dix vrais joueurs de l'Euroleague et de l'EuroCup, tirés pour la saison : %d sont au club." % n if tire else
			"Les dix joueurs du club se tirent avec les premières notes, %s au soir. Jusque-là, l'effectif est vide." % _jour(b.quand_tirage())})
	var jm: int = b.journee_du_marche()
	var marche := ""
	if jm == 0:
		marche = "Le marché est fermé jusqu'à la saison prochaine."
	elif not tire:
		marche = "Le marché ouvre après le tirage. Ensuite : enchérir sur les joueurs libres jusqu'au %s à 22 h, et choisir la consigne du samedi." % _jour(b.cloture(b.saison, jm))
	else:
		marche = "Enchères ouvertes jusqu'au %s à 22 h, au bureau du président ; la consigne du samedi s'y choisit aussi." % _jour(b.cloture(b.saison, jm))
	out.append({"titre": "Renforcer l'équipe au marché", "texte": marche, "fait": false})
	return out


static func _jour(t: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(t)
	return "%s %d/%02d" % [["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"][d.weekday], d.day, d.month]
