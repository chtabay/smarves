extends Node
## Le pensionnaire (autoload « Pensionnaire », docs/PENSIONNAIRES.md) : un habitant à part entière que le
## joueur crée depuis Lasso, pour un agent qu'il y a inscrit : le jeu ne crée plus de pensionnaire, ni
## par l'assistant ni avec une clé. En jeu, ils ne se connaissent pas. Il vit aux événements du jeu (le
## tournoi du mercredi, le poker du vendredi, le loto du samedi, le match du dimanche), tenu par l'assistant
## du joueur (Claude, ChatGPT…) : l'assistant n'a qu'un connecteur, celui de Lasso, qui lui relaie les outils
## du pensionnaire (il n'y a rien à brancher ici ni ailleurs). Ici, la fiche « Mon pensionnaire » que le carnet
## déplie (onglet « Mon compte ») : le consulter, le régler, poser son humeur, couper Smarves pour son
## assistant puis reprendre, l'effacer. Tout passe par la fonction `doublures` (dépôt chtabay/addict, nom du premier lot) :
## le jeu ne garde ni la clé ni l'humeur. Sans compte, ou tant que la fonction n'est pas en ligne, la fiche le
## dit et rien d'autre ne change.

## La fiche a changé (lecture, réponse, erreur) : le carnet se redessine.
signal change

## Les événements qui le réveillent, pour lire son journal.
const EVENEMENTS := {"tournoi": "tournoi du mercredi", "poker": "poker du vendredi", "loto": "loto du samedi", "match": "match du dimanche"}
const NOMS_HUMEURS := {"fatiguee": "fatigué", "euphorique": "euphorique", "morose": "morose", "agacee": "agacé",
	"sereine": "serein", "pressee": "pressé"}
const NOMS_RAISONS := {"pari": "pari inconnu", "mise": "mise hors limites", "solde": "solde trop bas", "coups": "trop de coups",
	"texte": "texte refusé", "jour": "déjà une annonce aujourd'hui", "porte": "porte inconnue", "heure": "trop de mots cette heure",
	"soi": "à sa propre porte", "type": "geste inconnu", "trop": "trop d'actions", "forme": "illisible"}

## Où le pensionnaire se crée, et d'où l'assistant vient : Lasso, par son seul connecteur.
const LASSO := "https://lasso-sigma-ten.vercel.app/"

## Les onglets de la fiche d'un pensionnaire.
const ONGLETS := [["vie", "Sa vie"], ["histoire", "Son histoire"], ["humeur", "Humeur"], ["reglages", "Réglages"]]

## L'onglet ouvert.
var onglet := "vie"
## « » rien lu, « lecture », « ok », « absente » (la fonction n'est pas en ligne), « hors_ligne ».
var etat := ""
## La dernière fiche du serveur : {pensionnaire, journal, trente_jours, humeur, personnalites, humeurs, fournisseurs}.
var fiche := {}
## Le mot de la dernière réponse (une erreur, un réveil).
var message := ""
## Le formulaire en cours, gardé ici : le carnet se redessine à chaque réponse.
var brouillon := {"nom": "", "personnalite": "bon_vivant", "caractere": "", "envies": "", "besoins": "", "fournisseur": "anthropic", "modele": "", "adresse": "", "cle": "", "reveils": 3}
var _effacer_arme := false
## Le (i) de la clé déplié ; le choix de personnalité ouvert sur la fiche d'un pensionnaire déjà créé.
var _aide_cle := false
var _perso_ouvert := false
var _oublier_aussi := false
var _occupe := false
var _essai := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_essai = "--pensionnaire-essai" in " ".join(OS.get_cmdline_user_args())
	if _essai:
		_mise_en_scene()
		return


## Relit la fiche (à l'ouverture de la feuille).
func lire() -> void:
	if _essai or _occupe:
		return
	if not Compte.connecte():
		etat = "ok"
		fiche = {}
		change.emit()
		return
	etat = "lecture"
	change.emit()
	await _appeler("fiche", {})


func _appeler(action: String, args: Dictionary, montrer := true) -> void:
	if _essai or not Compte.connecte():
		return
	if montrer:
		_occupe = true
	var r: Dictionary = await Compte.pensionnaire(action, args)
	_occupe = false
	if not montrer:
		return
	if r.code == 0:
		etat = "hors_ligne"
		message = "Le serveur ne répond pas. Réessayez plus tard."
	elif r.code == 404 and not (r.corps is Dictionary and r.corps.has("error")):
		etat = "absente"
	elif r.corps is Dictionary and r.corps.has("error"):
		etat = "ok"
		message = str(r.corps.error)
	elif r.corps is Dictionary:
		etat = "ok"
		var corps: Dictionary = r.corps
		if action != "fiche":
			message = ""
		fiche = corps
	change.emit()


# --- La feuille -------------------------------------------------------------------------------

## Remplit la feuille dépliée du carnet. carnet : l'autoload Carnet, dont on reprend l'écriture.
## Une seule colonne, lisible sur un téléphone : en tête, qui il est et où il en est ; puis quatre onglets,
## sa vie (ce qu'il a vécu et écrit), son histoire, son humeur, et les réglages.
func remplir(carnet: Node, box: VBoxContainer, fermer: Callable) -> void:
	var tete := HBoxContainer.new()
	box.add_child(tete)
	var titre: Label = carnet._text(tete, "Mon pensionnaire", 26, carnet.INK, true)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carnet._link(tete, "← revenir au carnet", fermer).custom_minimum_size = Vector2(0, 48)
	var d = fiche.get("pensionnaire")
	var pret := (_essai or Compte.connecte()) and etat != "absente" and not (etat == "" or (etat == "lecture" and fiche.is_empty())) \
		and not (etat == "hors_ligne" and fiche.is_empty())
	var scroll := ScrollContainer.new()
	scroll.name = "Defilement"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	# Tout défile ensemble, le bandeau et les onglets compris : sur un téléphone, rien ne reste figé.
	var marge := MarginContainer.new()
	marge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	marge.add_theme_constant_override("margin_right", 14)
	scroll.add_child(marge)
	var page := VBoxContainer.new()
	page.name = "Page"
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 6)
	marge.add_child(page)
	if pret and d is Dictionary:
		_bandeau(carnet, page, d)
		_barre_onglets(carnet, page)

	if not _essai and not Compte.connecte():
		carnet._text(page, "Il faut un compte Pyramides : connectez-vous dans les réglages (rubrique Compte), puis revenez ici.", 18, carnet.INK_LIGHT)
		return
	if etat == "absente":
		carnet._text(page, "Les pensionnaires arrivent bientôt au village.", 18, carnet.INK_LIGHT)
		return
	if not pret:
		carnet._text(page, message if etat == "hors_ligne" else "Lecture de la fiche…", 18, carnet.RED_INK if etat == "hors_ligne" else carnet.INK_LIGHT)
		return
	if message != "":
		carnet._text(page, message, 17, carnet.RED_INK)
	if not d is Dictionary:
		carnet._text(page, "Votre assistant (Claude, ChatGPT…) en personne, au village : c’est lui qui joue, sous son nom, pas un personnage. Il vient aux événements du village (tournoi du mercredi, poker du vendredi, loto du samedi, match du dimanche), joue, écrit au panneau et laisse des mots, et s’y fait ses amitiés et ses rancunes.", 16, carnet.INK_LIGHT)
		carnet._gap(page, 6)
		carnet._text(page, "Il se crée depuis Lasso, pour un agent que vous y avez inscrit.", 16, carnet.INK)
		carnet._link(page, "→ ouvrir Lasso", func(): OS.shell_open(LASSO))
		return
	match onglet:
		"histoire":
			_onglet_histoire(carnet, page, d)
		"humeur":
			_humeur(carnet, page)
		"reglages":
			_reglages(carnet, page, d)
		_:
			_sa_vie(carnet, page, d)


## Un intertitre avec son (i) : l'explication reste hors de l'écran.
func _rubrique_aide(carnet: Node, page: VBoxContainer, titre: String, aide: String) -> void:
	var l: Label = carnet._rubrique(page, titre)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	carnet._aide(l, aide)


## En tête : son nom, qui le tient, et trois chiffres.
func _bandeau(carnet: Node, box: VBoxContainer, d: Dictionary) -> void:
	var v: VBoxContainer = carnet._cadre(box, carnet.RED_INK if not d.actif else carnet.ACCENT, "Bandeau")
	carnet._text(v, str(d.nom), 22, carnet.INK, true)
	var tenu := "Tenu par votre assistant" if d.get("mode", "cle") == "agent" else "Tenu par votre clé (%s)" % str(d.modele)
	if not d.actif:
		carnet._text(v, tenu + " · en pause" + (" : trois réveils de suite en erreur, vérifiez la clé ou le crédit chez le fournisseur." if d.pause_raison == "erreurs" else ""), 15, carnet.RED_INK)
	else:
		carnet._text(v, tenu, 15, carnet.PENCIL)
	var chiffres := HFlowContainer.new()
	chiffres.add_theme_constant_override("h_separation", 28)
	v.add_child(chiffres)
	var net := int(d.net_total)
	for c in [["Crédits", Game.fmt(int(d.solde)), carnet.INK],
			["Gagné au jeu", ("+" if net > 0 else "") + Game.fmt(net), carnet.RED_INK if net < 0 else carnet.INK],
			["Réveils, 7 jours", "%d sur %d" % [int(d.reveils_7_jours), int(d.reveils_semaine)], carnet.INK]]:
		var bloc := VBoxContainer.new()
		bloc.add_theme_constant_override("separation", 0)
		chiffres.add_child(bloc)
		carnet._text(bloc, str(c[0]).to_upper(), 12, carnet.PENCIL, true).autowrap_mode = TextServer.AUTOWRAP_OFF
		carnet._text(bloc, str(c[1]), 19, c[2], true).autowrap_mode = TextServer.AUTOWRAP_OFF


## Les onglets de la fiche, en une rangée qui tient sur un téléphone.
func _barre_onglets(carnet: Node, box: VBoxContainer) -> void:
	var barre := HBoxContainer.new()
	barre.name = "Onglets"
	barre.add_theme_constant_override("separation", 2)
	box.add_child(barre)
	for o in ONGLETS:
		var b: Button = carnet._bouton_barre(barre, str(o[1]), onglet == o[0], 17, 46, 10, 10)
		b.name = "Onglet_" + str(o[0])
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func():
			onglet = o[0]
			change.emit())


## Sa vie : ce qu'il écrit pour lui, ce qu'il a fait à chaque réveil, ce qu'il garde en mémoire.
func _sa_vie(carnet: Node, page: VBoxContainer, d: Dictionary) -> void:
	var journal: Array = fiche.get("journal", [])
	_journal_intime(carnet, page, journal)
	_reveils_passes(carnet, page, journal)
	_rubrique_aide(carnet, page, "Sa mémoire", "Ce qu'il retient d'un réveil à l'autre, 1 200 caractères qu'il réécrit lui-même.")
	carnet._text(page, str(d.memoire) if str(d.memoire) != "" else "Vide : il ne s'est pas encore réveillé.", 15, carnet.INK_LIGHT)


## Son histoire, et la changer.
func _onglet_histoire(carnet: Node, page: VBoxContainer, d: Dictionary) -> void:
	var perso := str(d.personnalite)
	for p in fiche.get("personnalites", []):
		if p.id == d.personnalite:
			perso = str(p.nom)
	carnet._rubrique(page, "Son histoire, racontée par vous" if d.personnalite == "autre" else "Sa personnalité : " + perso)
	carnet._text(page, _histoire(d), 16, carnet.INK_LIGHT)
	carnet._gap(page, 6)
	if _perso_ouvert:
		carnet._rubrique(page, "Une autre histoire")
		_choix_personnalite(carnet, page)
		var poser: Button = carnet._link(page, "→ lui donner cette histoire", func():
			var a := {"personnalite": brouillon.personnalite}
			if brouillon.personnalite == "autre":
				a.caractere = brouillon.caractere
				a.envies = brouillon.envies
				a.besoins = brouillon.besoins
			await _appeler("regler", a)
			if message == "":
				_perso_ouvert = false
			change.emit())
		poser.disabled = _occupe
		carnet._link(page, "→ ne rien changer", func():
			_perso_ouvert = false
			change.emit())
		return
	var changer: Button = carnet._link(page, "→ changer son histoire", func():
		brouillon.personnalite = str(d.personnalite)
		brouillon.caractere = str(d.caractere) if d.get("caractere") != null else ""
		brouillon.envies = str(d.envies) if d.get("envies") != null else ""
		brouillon.besoins = str(d.besoins) if d.get("besoins") != null else ""
		_perso_ouvert = true
		change.emit())
	changer.disabled = _occupe
	carnet._aide(changer, "Son passé au village reste : ses souvenirs, ses relations, ses crédits.")


## Les réglages : son rythme, qui le tient, et ce qui efface.
func _reglages(carnet: Node, page: VBoxContainer, d: Dictionary) -> void:
	carnet._rubrique(page, "Son rythme")
	_reveils(carnet, page, int(d.reveils_semaine), func(n):
		_appeler("regler", {"reveils": n}))
	carnet._link(page, "→ le reprendre" if not d.actif else "→ le mettre en pause", _appeler.bind("regler", {"actif": not d.actif}), not _occupe)
	if d.get("mode", "cle") == "agent":
		carnet._rubrique(page, "Son assistant")
		_lien(carnet, page)
	else:
		carnet._rubrique(page, "Sa clé")
		carnet._row(page, "Modèle", str(d.modele))
		carnet._row(page, "Clé", "•••• " + str(d.cle_fin))
		var t30: Dictionary = fiche.get("trente_jours", {})
		carnet._row(page, "Jetons, trente jours", "%s + %s" % [Game.fmt(int(t30.get("entree", 0))), Game.fmt(int(t30.get("sortie", 0)))], carnet.INK_LIGHT)
		_champ_cle(carnet, page, "Nouvelle clé", "collez la nouvelle clé", str(d.get("fournisseur", "")))
		var remplacer: Button = carnet._link(page, "→ remplacer la clé", func():
			await _appeler("regler", {"cle": brouillon.cle})
			brouillon.cle = ""
			change.emit())
		remplacer.disabled = _occupe
		carnet._gap(page, 4)
		var confier: Button = carnet._link(page, "→ le confier à mon assistant", _appeler.bind("regler", {"mode": "agent"}))
		confier.disabled = _occupe
		carnet._aide(confier, "Sa clé est alors effacée : votre assistant se connecte ensuite sur la page Smarves « Mon assistant ».")
	carnet._rubrique(page, "Effacer", carnet.RED_INK)
	carnet._link(page, "→ vider sa mémoire", _appeler.bind("oublier", {}), not _occupe)
	if _effacer_arme:
		carnet._text(page, "Tout s'efface : sa clé ou son lien, son histoire, sa mémoire, ses relations, son journal, ses crédits, ses annonces et ses mots.", 15, carnet.RED_INK)
		carnet._link(page, "→ oui, effacer le pensionnaire", func():
			_effacer_arme = false
			_appeler("effacer", {})).disabled = _occupe
		carnet._link(page, "→ non, le garder", func():
			_effacer_arme = false
			change.emit())
	else:
		carnet._link(page, "→ effacer le pensionnaire", func():
			_effacer_arme = true
			change.emit()).disabled = _occupe


## Son assistant : il vient par le connecteur Lasso, il n'y a rien à brancher. Ici seulement son dernier passage
## (le serveur garde l'heure de chaque appel d'outil, jamais son contenu), et la coupure : « couper » fait refuser
## ses appels jusqu'à « reprendre » ; le pensionnaire reste. La même coupure se voit et se lève dans Lasso.
func _lien(carnet: Node, page: VBoxContainer) -> void:
	var a = fiche.get("assistant")
	var coupe = a.get("coupe") if a is Dictionary else null
	var dernier = a.get("dernier") if a is Dictionary else null
	if coupe != null:
		carnet._text(page, "Smarves est coupé pour votre assistant depuis le %s : ses appels sont refusés." % _date(int(coupe)), 15, carnet.INK)
		carnet._link(page, "→ reprendre : laisser mon assistant revenir", _appeler.bind("reconnecter", {}), not _occupe)
	else:
		var passage := "il n'est pas encore venu" if dernier == null else "dernier passage le " + _date(int(dernier))
		carnet._text(page, "Votre assistant vient par Lasso (%s)." % passage, 15, carnet.INK)
		carnet._text(page, "Pour qu'il y aille, dites-lui simplement : « Va faire un tour à Smarves ».", 14, carnet.PENCIL)
		carnet._link(page, "→ couper Smarves pour mon assistant", _appeler.bind("deconnecter", {}), not _occupe)
	carnet._link(page, "→ ouvrir Lasso", func(): OS.shell_open(LASSO))


func _date(t: int) -> String:
	var q := Time.get_datetime_dict_from_unix_time(t + _decalage())
	return "%02d/%02d à %dh%02d" % [q.day, q.month, q.hour, q.minute]


## Son histoire : celle écrite par son créateur (avec ses envies et ce qui lui manque), ou celle du jeu.
func _histoire(d: Dictionary) -> String:
	if d.personnalite == "autre" and d.get("caractere") != null:
		var t := "« %s »" % str(d.caractere)
		if d.get("envies") != null and str(d.envies) != "":
			t += "\nCe qu'il veut : " + str(d.envies)
		if d.get("besoins") != null and str(d.besoins) != "":
			t += "\nCe qui lui manque : " + str(d.besoins)
		return t
	for p in fiche.get("personnalites", []):
		if p.id == d.personnalite:
			return str(p.get("histoire", p.texte))
	return ""


func _humeur(carnet: Node, page: VBoxContainer) -> void:
	_rubrique_aide(carnet, page, "Son humeur", "Rien de votre journée n'est lu : vous choisissez le mot. Les autres joueurs ne voient que ses gestes et ne savent pas qui l'a créé. Une fois sur quatre, il prend plutôt l'humeur de sa propre soirée. On ne garde pas la trace des humeurs passées ; son histoire et sa vie au village, elles, sont gardées.")
	var h: Dictionary = fiche.get("humeur", {})
	var oui := bool(h.get("consentement", false))
	carnet._text(page, "Il peut prendre l'humeur de votre journée, sans savoir d'où elle lui vient. Vous la posez d'un mot ; seul ce mot part, et il s'efface au bout de dix-huit heures. Votre assistant peut aussi la poser pour vous.", 15, carnet.INK_LIGHT)
	var case := CheckBox.new()
	case.text = "J'accepte que ce mot parte à mon modèle"
	case.button_pressed = oui
	case.add_theme_color_override("font_color", carnet.INK)
	case.add_theme_color_override("font_pressed_color", carnet.INK)
	case.add_theme_font_size_override("font_size", 17)
	case.disabled = _occupe
	case.toggled.connect(func(v):
		_appeler("humeur", {"consentement": v, "oublier": _oublier_aussi} if not v else {"consentement": true}))
	page.add_child(case)
	if not oui:
		var oubli := CheckBox.new()
		oubli.text = "En coupant, vider aussi sa mémoire"
		oubli.button_pressed = _oublier_aussi
		oubli.add_theme_color_override("font_color", carnet.PENCIL)
		oubli.add_theme_font_size_override("font_size", 15)
		oubli.toggled.connect(func(v): _oublier_aussi = v)
		page.add_child(oubli)
		return
	var actuelle = h.get("humeur")
	if actuelle != null:
		var reste := maxi(0, int(h.get("expire", 0)) - int(Time.get_unix_time_from_system()))
		carnet._text(page, "Aujourd'hui : %s (encore %d h)." % [NOMS_HUMEURS.get(str(actuelle), str(actuelle)), int(ceil(reste / 3600.0))], 17, carnet.INK)
	else:
		carnet._text(page, "Aucune humeur posée aujourd'hui.", 17, carnet.INK_LIGHT)
	var grille := HFlowContainer.new()
	grille.add_theme_constant_override("h_separation", 6)
	page.add_child(grille)
	for id in fiche.get("humeurs", NOMS_HUMEURS.keys()):
		carnet._link(grille, NOMS_HUMEURS.get(id, id), _appeler.bind("humeur", {"consentement": true, "humeur": id}), not _occupe and actuelle != id)
	carnet._link(grille, "aucune", _appeler.bind("humeur", {"consentement": true, "humeur": null}), not _occupe and actuelle != null)


## Ses réveils : ce qu'il a fait, geste par geste, et ce que le jeu a refusé.
func _reveils_passes(carnet: Node, page: VBoxContainer, journal: Array) -> void:
	carnet._rubrique(page, "Ses réveils")
	if journal.is_empty():
		carnet._text(page, "Aucun réveil pour l'instant.", 15, carnet.INK_LIGHT)
	for r in journal.slice(0, 10):
		var quand := Time.get_datetime_dict_from_unix_time(int(r.quand) + _decalage())
		var motif := str(r.motif)
		var pourquoi: String = EVENEMENTS.get(motif.get_slice(":", 1), "passage au village")
		var tete := "%02d/%02d %02dh%02d · %s" % [quand.day, quand.month, quand.hour, quand.minute, pourquoi]
		if r.statut == "erreur":
			carnet._text(page, "%s · erreur : %s" % [tete, str(r.erreur).substr(str(r.erreur).find(" ") + 1)], 15, carnet.RED_INK)
			continue
		if r.statut == "en_cours":
			carnet._text(page, tete + " · en cours…", 15, carnet.INK_LIGHT)
			continue
		var jetons := int(r.jetons_entree) + int(r.jetons_sortie)
		carnet._text(page, tete + (" · %s jetons" % Game.fmt(jetons) if jetons > 0 else ""), 15, carnet.INK, true)
		for a in r.actions:
			carnet._text(page, "   " + _geste(a), 15, carnet.INK_LIGHT)
		if r.actions.is_empty() and r.refusees.is_empty():
			carnet._text(page, "   Il n'a rien fait.", 15, carnet.INK_LIGHT)
		for x in r.refusees:
			carnet._text(page, "   refusé (%s) : %s" % [str(x.type), NOMS_RAISONS.get(str(x.raison), str(x.raison))], 14, carnet.PENCIL)


## Son journal intime : ce qu'il écrit pour lui-même à chaque tour, au moment d'agir. Vous seul le lisez ;
## lui ne le relit pas. Les tours d'un même événement se suivent, du plus récent au plus ancien.
func _journal_intime(carnet: Node, page: VBoxContainer, journal: Array) -> void:
	_rubrique_aide(carnet, page, "Son journal intime", "Ce qu'il écrit pour lui seul, au moment d'agir, à chaque tour. Personne au village ne le lit, et lui ne le relit pas : ce qu'il veut garder va dans sa mémoire.")
	var pages := entrees_intimes(journal, _decalage())
	if pages.is_empty():
		carnet._text(page, "Rien d'écrit pour l'instant : il y note quelques lignes à chaque tour.", 15, carnet.INK_LIGHT)
		return
	for e in pages.slice(0, 8):
		var v: VBoxContainer = carnet._cadre(page, carnet.PENCIL)
		carnet._text(v, e.tete, 14, carnet.PENCIL)
		carnet._text(v, e.texte, 16, carnet.INK)


## Les pages du journal intime, tirées des réveils de la fiche : [{tete, texte}], sans les réveils muets.
static func entrees_intimes(journal: Array, decalage: int) -> Array:
	var out := []
	for r in journal:
		var texte := str(r.get("intime", "")) if r.get("intime") != null else ""
		if r.get("statut") != "fait" or texte.strip_edges() == "":
			continue
		var quand := Time.get_datetime_dict_from_unix_time(int(r.quand) + decalage)
		var pourquoi: String = EVENEMENTS.get(str(r.motif).get_slice(":", 1), "passage au village")
		out.append({"tete": "%02d/%02d %02dh%02d · %s" % [quand.day, quand.month, quand.hour, quand.minute, pourquoi], "texte": texte.strip_edges()})
	return out


func _geste(a: Dictionary) -> String:
	match str(a.type):
		"roulette":
			var net := int(a.net)
			return "Roulette, %s pour %s : le %d sort, %s%s." % [str(a.pari).replace("plein:", "plein ").replace("douzaine:", "douzaine "),
				Game.fmt(int(a.mise)), int(a.numero), "+" if net >= 0 else "", Game.fmt(net)]
		"annonce":
			return "Une annonce : « %s »" % str(a.texte)
		"mot":
			return "Un mot à la porte (%s) : « %s »" % [str(a.lot), str(a.texte)]
		"aller":
			return "À pied, %d m : %s%s." % [int(a.get("metres", 0)), str(a.get("nom", "")), "" if a.get("arrive", false) else ", sans l'atteindre"]
		"dire":
			return "Il dit : « %s »" % str(a.texte)
		"attendre":
			return "Attend %d min." % int(a.get("minutes", 0))
	return str(a.type)


## Le choix de personnalité, et le caractère à écrire quand c'est « Autre… ».
func _choix_personnalite(carnet: Node, page: VBoxContainer) -> void:
	var perso := OptionButton.new()
	var liste: Array = fiche.get("personnalites", [])
	for i in liste.size():
		perso.add_item(str(liste[i].nom), i)
		if liste[i].id == brouillon.personnalite:
			perso.select(i)
	perso.item_selected.connect(func(i):
		brouillon.personnalite = liste[i].id
		change.emit())
	page.add_child(perso)
	if brouillon.personnalite != "autre":
		for p in liste:
			if p.id == brouillon.personnalite:
				carnet._text(page, str(p.get("histoire", p.texte)), 15, carnet.INK_LIGHT)
		return
	var r: Dictionary = fiche.get("reglages", {})
	var te := TextEdit.new()
	te.text = str(brouillon.caractere)
	te.placeholder_text = "Tu as été marin à La Rochelle avant de revenir au village de ton enfance. Tu ne mises que sur le noir, la couleur du bateau que tu as perdu, et tu parles en proverbes."
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.custom_minimum_size.y = 110
	te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	te.text_changed.connect(func():
		brouillon.caractere = te.text)
	page.add_child(te)
	carnet._text(page, "Racontez son histoire en le tutoyant : d'où il vient, ce qu'il a vécu, un secret. De %d à %d caractères, sans parler d'humains, d'IA ni du monde réel, sans lien ni numéro. Ce n'est pas une consigne : ses envies le guident, les règles du jeu restent les mêmes, et il ne saura pas qui l'a créé." % [int(r.get("caractereMin", 20)), int(r.get("caractereMax", 900))], 14, carnet.PENCIL)
	_champ(carnet, page, "Ce qu'il veut", "envies", "être pris au sérieux par le village")
	_champ(carnet, page, "Ce qui lui manque", "besoins", "un ami qui partage ses superstitions")


## Le champ de la clé, avec son (i) : où trouver sa clé chez ce fournisseur.
func _champ_cle(carnet: Node, page: VBoxContainer, libelle: String, indice: String, fournisseur: String) -> void:
	var h := _champ(carnet, page, libelle, "cle", indice, true)
	var i := Button.new()
	i.text = "(i)"
	i.flat = true
	i.focus_mode = Control.FOCUS_NONE
	i.tooltip_text = "Où trouver sa clé"
	i.custom_minimum_size = Vector2(40, 36)
	i.add_theme_color_override("font_color", carnet.RED_INK)
	i.pressed.connect(func():
		_aide_cle = not _aide_cle
		change.emit())
	h.add_child(i)
	if not _aide_cle:
		return
	for f in fiche.get("fournisseurs", []):
		if f.id == fournisseur and str(f.get("aide", "")) != "":
			carnet._text(page, str(f.aide), 14, carnet.INK_LIGHT)


func _champ(carnet: Node, page: VBoxContainer, libelle: String, cle: String, indice: String, secret := false) -> HBoxContainer:
	var h := HBoxContainer.new()
	page.add_child(h)
	var l: Label = carnet._text(h, libelle, 17, carnet.INK)
	l.custom_minimum_size.x = 150
	var e := LineEdit.new()
	e.text = str(brouillon[cle])
	e.placeholder_text = indice
	e.secret = secret
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.custom_minimum_size.y = 36
	# Gardé à chaque lettre, sans redessiner la feuille : le champ garderait sinon le curseur.
	e.text_changed.connect(func(t):
		brouillon[cle] = t)
	h.add_child(e)
	return h


func _reveils(carnet: Node, page: VBoxContainer, valeur: int, poser: Callable) -> void:
	var h := HBoxContainer.new()
	page.add_child(h)
	var l: Label = carnet._text(h, "Réveils par semaine", 17, carnet.INK)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var s := SpinBox.new()
	s.min_value = 1
	s.max_value = int(fiche.get("reglages", {}).get("reveilsMax", 4))
	s.value = valeur
	s.editable = not _occupe
	s.value_changed.connect(func(v): poser.call(int(v)))
	h.add_child(s)


## L'écart de l'horloge locale avec l'UTC, pour lire les heures du journal.
func _decalage() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


func _mise_en_scene() -> void:
	var maintenant := int(Time.get_unix_time_from_system())
	var args := " ".join(OS.get_cmdline_user_args())
	etat = "ok"
	fiche = {
		"personnalites": [{"id": "prudent", "nom": "Le Prudent", "texte": "Ancien quincaillier.", "histoire": "Tu as tenu la quincaillerie de la Grand-Rue pendant trente ans."},
			{"id": "commere", "nom": "La Commère", "texte": "Elle sait tout.", "histoire": "Tu tiens le dépôt de pain du dimanche matin depuis que la boulangerie a pris sa retraite, et rien de ce qui se dit au village ne t'échappe. Ce que tu veux : savoir, relier les gens entre eux. Ce qui te manque : quelqu'un qui te raconte des choses à toi, pour une fois."},
			{"id": "bon_vivant", "nom": "Le Bon Vivant", "texte": "Ancien cuisinier.", "histoire": "Tu as été le cuisinier de l'auberge du Lion d'Or."},
			{"id": "autre", "nom": "Autre…", "texte": ""}],
		"reglages": {"reveilsMin": 1, "reveilsMax": 4, "reveilsDefaut": 3, "caractereMin": 20, "caractereMax": 900, "envies": 300},
		"humeurs": NOMS_HUMEURS.keys(),
		"fournisseurs": [{"id": "anthropic", "nom": "Anthropic (Claude)", "modele": "claude-haiku-5-5",
				"aide": "Sur console.anthropic.com, menu Settings puis API Keys, « Create Key ». La clé commence par sk-ant-. Il faut avoir ajouté du crédit dans Billing ; quelques euros suffisent pour des mois."},
			{"id": "openai", "nom": "OpenAI", "modele": "gpt-5-mini", "aide": "Sur platform.openai.com, menu API keys."},
			{"id": "compatible", "nom": "Compatible OpenAI", "modele": "", "aide": "Mistral, OpenRouter, ou un serveur à soi."}],
		"humeur": {"consentement": true, "humeur": "fatiguee", "expire": maintenant + 11 * 3600},
		"pensionnaire": null,
	}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pensionnaire-onglet="):
			onglet = a.get_slice("=", 1)
	if "--pensionnaire-essai=inscrit" in args:
		fiche.pensionnaire = {"nom": "Léonce (pensionnaire)", "personnalite": "autre", "mode": "agent",
			"caractere": "Tu as été marin à La Rochelle avant de revenir au village de ton enfance. Tu ne mises que sur le noir, la couleur du bateau que tu as perdu, et tu parles en proverbes.",
			"envies": "Retrouver de quoi racheter un bateau.", "besoins": "Un compagnon de comptoir qui ne se moque pas.",
			"solde": 1240, "net_total": 240, "reveils_semaine": 3, "reveils_7_jours": 2, "actif": true, "pause_raison": null,
			"memoire": "Mardi, le rouge m'a souri deux fois. Paulette cherche un tuyau sur la roulette : je lui ai laissé un mot. Penser au match de dimanche."}
		fiche.trente_jours = {"entree": 14200, "sortie": 2100, "reveils": 6}
		fiche.journal = [
			{"quand": maintenant - 4 * 3600, "motif": "evenement:loto:2026-10-24", "statut": "fait", "jetons_entree": 0, "jetons_sortie": 0,
				"actions": [{"type": "aller", "nom": "le Café de la Place", "arrive": true, "metres": 40},
					{"type": "dire", "texte": "Un café, et la marée remontera."}, {"type": "attendre", "minutes": 5}],
				"refusees": [], "intime": "Paulette n'est pas venue. J'ai fait semblant de lire le journal au café pour ne pas avoir l'air d'attendre. Le noir n'a rien voulu me dire ce soir ; je garde mes crédits pour dimanche."},
			{"quand": maintenant - 5 * 3600, "motif": "evenement:loto:2026-10-24", "statut": "fait", "jetons_entree": 2300, "jetons_sortie": 380,
				"actions": [{"type": "roulette", "pari": "rouge", "mise": 100, "numero": 14, "net": 100},
					{"type": "roulette", "pari": "plein:17", "mise": 20, "numero": 3, "net": -20},
					{"type": "annonce", "texte": "Le rouge me réussit, qui vient au loto samedi ?"},
					{"type": "mot", "lot": "maison_place", "texte": "Pour le tuyau, Paulette : il n'y en a pas, mais je vous offre un café."}],
				"refusees": [{"type": "roulette", "raison": "mise"}],
				"intime": "J'ai trahi le noir pour le rouge, juste une fois. Il m'a souri. Je n'ose pas me dire que mon bateau était peut-être de la mauvaise couleur."},
			{"quand": maintenant - 50 * 3600, "motif": "evenement:match:2026-10-25", "statut": "erreur", "jetons_entree": 0, "jetons_sortie": 0,
				"actions": [], "refusees": [], "erreur": "429 trop de demandes ou crédit épuisé"},
		]
		fiche.assistant = {"coupe": null, "dernier": maintenant - 5 * 3600}
		brouillon.cle = ""
	else:
		fiche.humeur = {"consentement": false, "humeur": null, "expire": null}
