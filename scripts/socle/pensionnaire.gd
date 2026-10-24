extends Node
## Le pensionnaire (autoload « Pensionnaire », docs/PENSIONNAIRES.md) : un habitant à part entière que le
## joueur crée depuis son compte, tenu par son propre modèle de langage. En jeu, ils ne se connaissent pas.
## Le pensionnaire se réveille aux événements du jeu (le tournoi du mercredi, le poker du vendredi, le loto
## du samedi, le match du dimanche), jamais à la demande de son créateur. Ici, la fiche « Mon pensionnaire »
## que le carnet déplie (onglet « Mon compte ») : le créer avec sa clé, le régler, poser son humeur, lire son
## carnet et son journal. Tout passe par la fonction `doublures` (dépôt chtabay/addict, nom du premier lot) :
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

## « » rien lu, « lecture », « ok », « absente » (la fonction n'est pas en ligne), « hors_ligne ».
var etat := ""
## La dernière fiche du serveur : {pensionnaire, journal, trente_jours, humeur, personnalites, humeurs, fournisseurs}.
var fiche := {}
## Le mot de la dernière réponse (une erreur, un réveil).
var message := ""
## Le formulaire en cours, gardé ici : le carnet se redessine à chaque réponse.
var brouillon := {"nom": "", "personnalite": "bon_vivant", "caractere": "", "fournisseur": "anthropic", "modele": "", "adresse": "", "cle": "", "reveils": 3}
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
func remplir(carnet: Node, box: VBoxContainer, fermer: Callable) -> void:
	var tete := HBoxContainer.new()
	box.add_child(tete)
	var titre: Label = carnet._text(tete, "Mon pensionnaire", 26, carnet.INK, true)
	titre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	carnet._link(tete, "← revenir au carnet", fermer).custom_minimum_size = Vector2(200, 48)
	carnet._text(box, "Un habitant de plus, que vous créez et que votre propre modèle de langage fait vivre. Il se réveille aux événements du village (tournoi du mercredi, poker du vendredi, loto du samedi, match du dimanche), joue, écrit au panneau et laisse des mots. Il ne vous connaît pas, et personne ne le briefe, pas même vous.", 16, carnet.PENCIL)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	# Sur un téléphone, les deux colonnes passent l'une sous l'autre.
	var ecran: Vector2 = carnet._ecran()
	var cols: BoxContainer = VBoxContainer.new() if ecran.x < 1300.0 or ecran.y < 760.0 else HBoxContainer.new()
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 20 if cols is VBoxContainer else 40)
	scroll.add_child(cols)
	var gauche := VBoxContainer.new()
	gauche.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gauche.add_theme_constant_override("separation", 4)
	cols.add_child(gauche)
	var droite := VBoxContainer.new()
	droite.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	droite.add_theme_constant_override("separation", 4)
	cols.add_child(droite)

	if not _essai and not Compte.connecte():
		carnet._text(gauche, "Il faut un compte Pyramides : connectez-vous dans les réglages (rubrique Compte), puis revenez ici.", 18, carnet.INK_LIGHT)
		return
	if etat == "absente":
		carnet._text(gauche, "Les pensionnaires arrivent bientôt au village.", 18, carnet.INK_LIGHT)
		return
	if etat == "" or (etat == "lecture" and fiche.is_empty()):
		carnet._text(gauche, "Lecture de la fiche…", 18, carnet.INK_LIGHT)
		return
	if etat == "hors_ligne" and fiche.is_empty():
		carnet._text(gauche, message, 18, carnet.RED_INK)
		return
	if message != "":
		carnet._text(gauche, message, 17, carnet.RED_INK)
		carnet._gap(gauche, 6)
	var d = fiche.get("pensionnaire")
	if d is Dictionary:
		_fiche_pensionnaire(carnet, gauche, d)
	else:
		_formulaire(carnet, gauche)
	_humeur(carnet, droite)
	if d is Dictionary:
		_carnet_et_journal(carnet, droite, d)


func _formulaire(carnet: Node, page: VBoxContainer) -> void:
	carnet._text(page, "Créer un pensionnaire", 20, carnet.INK, true)
	_champ(carnet, page, "Son nom", "nom", "Léonce")
	carnet._text(page, "Il portera « (pensionnaire) » partout où il paraît ; personne ne saura qu'il vient de vous, et lui non plus.", 14, carnet.PENCIL)
	carnet._text(page, "Sa personnalité", 17, carnet.INK)
	_choix_personnalite(carnet, page)
	carnet._gap(page, 6)
	carnet._text(page, "Son modèle, sur votre clé", 17, carnet.INK)
	var four := OptionButton.new()
	var fs: Array = fiche.get("fournisseurs", [])
	for i in fs.size():
		four.add_item(str(fs[i].nom), i)
		if fs[i].id == brouillon.fournisseur:
			four.select(i)
	four.item_selected.connect(func(i):
		brouillon.fournisseur = fs[i].id
		brouillon.modele = ""
		change.emit())
	page.add_child(four)
	var defaut := ""
	for f in fs:
		if f.id == brouillon.fournisseur:
			defaut = str(f.modele)
	if brouillon.modele == "":
		brouillon.modele = defaut
	_champ(carnet, page, "Modèle", "modele", "nom du modèle")
	if brouillon.fournisseur == "compatible":
		_champ(carnet, page, "Adresse (https)", "adresse", "https://api.exemple.com/v1")
	_champ_cle(carnet, page, "Clé", "collez votre clé", brouillon.fournisseur)
	carnet._text(page, "Chiffrée par le serveur, elle ne ressort jamais : la fiche n'en montrera que les quatre derniers caractères. À chaque réveil, votre modèle lit ce que tout joueur voit au panneau de la mairie (classement, annonces, noms sur les maisons) et les mots laissés à sa porte.", 14, carnet.PENCIL)
	_reveils(carnet, page, int(brouillon.reveils), func(n):
		brouillon.reveils = n)
	carnet._text(page, "Un appel au modèle par réveil, seulement aux événements du village : avec un petit modèle, de l'ordre d'un centime par réveil, payé sur votre clé.", 14, carnet.PENCIL)
	carnet._gap(page, 4)
	var confier: Button = carnet._link(page, "→ créer le pensionnaire", func():
		var a := brouillon.duplicate()
		if a.personnalite != "autre":
			a.erase("caractere")
		await _appeler("inscrire", a)
		if fiche.get("pensionnaire") is Dictionary:
			brouillon.cle = ""
			change.emit())
	confier.custom_minimum_size.y = 44
	confier.disabled = _occupe


func _fiche_pensionnaire(carnet: Node, page: VBoxContainer, d: Dictionary) -> void:
	carnet._text(page, str(d.nom), 22, carnet.INK, true)
	var perso := str(d.personnalite)
	for p in fiche.get("personnalites", []):
		if p.id == d.personnalite:
			perso = str(p.nom)
	carnet._row(page, "Personnalité", "Son caractère, écrit par vous" if d.personnalite == "autre" else perso)
	if d.personnalite == "autre" and d.get("caractere") != null:
		carnet._text(page, "« %s »" % str(d.caractere), 14, carnet.INK_LIGHT)
	carnet._row(page, "Modèle", str(d.modele))
	carnet._row(page, "Clé", "•••• " + str(d.cle_fin))
	carnet._row(page, "Crédits", Game.fmt(int(d.solde)))
	carnet._row(page, "Gagné au jeu (net)", Game.fmt(int(d.net_total)), carnet.RED_INK if int(d.net_total) < 0 else carnet.INK)
	carnet._row(page, "Réveils sur sept jours", "%d sur %d" % [int(d.reveils_7_jours), int(d.reveils_semaine)])
	var t30: Dictionary = fiche.get("trente_jours", {})
	carnet._row(page, "Jetons, trente jours", "%s + %s" % [Game.fmt(int(t30.get("entree", 0))), Game.fmt(int(t30.get("sortie", 0)))], carnet.INK_LIGHT)
	if not d.actif:
		carnet._text(page, "En pause : trois réveils de suite en erreur. Vérifiez la clé ou le crédit chez le fournisseur." if d.pause_raison == "erreurs" else "En pause.", 16, carnet.RED_INK)
	carnet._gap(page, 6)
	_reveils(carnet, page, int(d.reveils_semaine), func(n):
		_appeler("regler", {"reveils": n}))
	carnet._link(page, "→ le reprendre" if not d.actif else "→ le mettre en pause", _appeler.bind("regler", {"actif": not d.actif}), not _occupe)
	carnet._gap(page, 6)
	if _perso_ouvert:
		carnet._text(page, "Sa personnalité", 17, carnet.INK)
		_choix_personnalite(carnet, page)
		var poser: Button = carnet._link(page, "→ lui donner cette personnalité", func():
			var a := {"personnalite": brouillon.personnalite}
			if brouillon.personnalite == "autre":
				a.caractere = brouillon.caractere
			await _appeler("regler", a)
			if message == "":
				_perso_ouvert = false
			change.emit())
		poser.disabled = _occupe
		carnet._link(page, "→ ne rien changer", func():
			_perso_ouvert = false
			change.emit())
	else:
		var changer: Button = carnet._link(page, "→ changer sa personnalité", func():
			brouillon.personnalite = str(d.personnalite)
			brouillon.caractere = str(d.caractere) if d.get("caractere") != null else ""
			_perso_ouvert = true
			change.emit())
		changer.disabled = _occupe
	carnet._gap(page, 6)
	_champ_cle(carnet, page, "Nouvelle clé", "collez la nouvelle clé", str(d.get("fournisseur", "")))
	var remplacer: Button = carnet._link(page, "→ remplacer la clé", func():
		await _appeler("regler", {"cle": brouillon.cle})
		brouillon.cle = ""
		change.emit())
	remplacer.disabled = _occupe
	carnet._gap(page, 6)
	carnet._link(page, "→ vider son carnet", _appeler.bind("oublier", {}), not _occupe)
	if _effacer_arme:
		carnet._text(page, "Tout s'efface : sa clé, son carnet, son journal, ses crédits, ses annonces et ses mots.", 15, carnet.RED_INK)
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


func _humeur(carnet: Node, page: VBoxContainer) -> void:
	carnet._text(page, "Son humeur", 20, carnet.INK, true)
	var h: Dictionary = fiche.get("humeur", {})
	var oui := bool(h.get("consentement", false))
	carnet._text(page, "Votre pensionnaire peut prendre l'humeur de votre journée, sans savoir d'où elle lui vient. Vous la posez vous-même, d'un mot : rien de votre journée n'est lu. Seul ce mot part au modèle ; les autres joueurs ne voient que ses gestes, et ne savent pas qui l'a créé. Une fois sur quatre, il prend plutôt l'humeur de sa propre soirée. Le mot s'efface au bout de dix-huit heures ; aucun historique n'est gardé.", 15, carnet.INK_LIGHT)
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
		oubli.text = "En coupant, vider aussi son carnet"
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


func _carnet_et_journal(carnet: Node, page: VBoxContainer, d: Dictionary) -> void:
	carnet._gap(page, 10)
	carnet._text(page, "Son carnet", 20, carnet.INK, true)
	carnet._text(page, str(d.memoire) if str(d.memoire) != "" else "Vide : il ne s'est pas encore réveillé.", 15, carnet.INK_LIGHT)
	carnet._gap(page, 10)
	carnet._text(page, "Son journal", 20, carnet.INK, true)
	var journal: Array = fiche.get("journal", [])
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
		carnet._text(page, "%s · %s jetons" % [tete, Game.fmt(int(r.jetons_entree) + int(r.jetons_sortie))], 15, carnet.INK, true)
		for a in r.actions:
			carnet._text(page, "   " + _geste(a), 15, carnet.INK_LIGHT)
		if r.actions.is_empty() and r.refusees.is_empty():
			carnet._text(page, "   Il n'a rien fait.", 15, carnet.INK_LIGHT)
		for x in r.refusees:
			carnet._text(page, "   refusé (%s) : %s" % [str(x.type), NOMS_RAISONS.get(str(x.raison), str(x.raison))], 14, carnet.PENCIL)


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
				carnet._text(page, str(p.texte), 15, carnet.INK_LIGHT)
		return
	var r: Dictionary = fiche.get("reglages", {})
	var te := TextEdit.new()
	te.text = str(brouillon.caractere)
	te.placeholder_text = "Tu es un vieux marin bourru : tu ne mises que sur le noir, tu parles en proverbes et tu te méfies des beaux parleurs."
	te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	te.custom_minimum_size.y = 110
	te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	te.text_changed.connect(func():
		brouillon.caractere = te.text)
	page.add_child(te)
	carnet._text(page, "Écrivez son caractère en le tutoyant : comment il joue, comment il écrit, ce qu'il aime. De %d à %d caractères, sans parler d'humains, d'IA ni du monde réel, sans lien ni numéro. Ce n'est pas une consigne : les règles du jeu restent les mêmes, et il ne saura toujours pas qui l'a créé." % [int(r.get("caractereMin", 20)), int(r.get("caractereMax", 600))], 14, carnet.PENCIL)


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
		"personnalites": [{"id": "prudent", "nom": "Le Prudent", "texte": "Tu comptes tes sous."},
			{"id": "commere", "nom": "La Commère", "texte": "Tu joues pour avoir de quoi raconter. Tu lis tout ce qui se dit au panneau, tu réponds, tu laisses des mots aux portes."},
			{"id": "bon_vivant", "nom": "Le Bon Vivant", "texte": "Tu joues pour la compagnie."},
			{"id": "autre", "nom": "Autre…", "texte": ""}],
		"reglages": {"reveilsMin": 1, "reveilsMax": 4, "reveilsDefaut": 3, "caractereMin": 20, "caractereMax": 600},
		"humeurs": NOMS_HUMEURS.keys(),
		"fournisseurs": [{"id": "anthropic", "nom": "Anthropic (Claude)", "modele": "claude-haiku-5-5",
				"aide": "Sur console.anthropic.com, menu Settings puis API Keys, « Create Key ». La clé commence par sk-ant-. Il faut avoir ajouté du crédit dans Billing ; quelques euros suffisent pour des mois."},
			{"id": "openai", "nom": "OpenAI", "modele": "gpt-5-mini", "aide": "Sur platform.openai.com, menu API keys."},
			{"id": "compatible", "nom": "Compatible OpenAI", "modele": "", "aide": "Mistral, OpenRouter, ou un serveur à soi."}],
		"humeur": {"consentement": true, "humeur": "fatiguee", "expire": maintenant + 11 * 3600},
		"pensionnaire": null,
	}
	if "--pensionnaire-essai=inscrit" in args:
		fiche.pensionnaire = {"nom": "Léonce (pensionnaire)", "personnalite": "autre", "fournisseur": "anthropic", "modele": "claude-haiku-5-5", "cle_fin": "x9Qa",
			"caractere": "Tu es un vieux marin bourru : tu ne mises que sur le noir, tu parles en proverbes et tu te méfies des beaux parleurs.",
			"solde": 1240, "net_total": 240, "reveils_semaine": 3, "reveils_7_jours": 2, "actif": true, "pause_raison": null,
			"memoire": "Mardi, le rouge m'a souri deux fois. Paulette cherche un tuyau sur la roulette : je lui ai laissé un mot. Penser au match de dimanche."}
		fiche.trente_jours = {"entree": 14200, "sortie": 2100, "reveils": 6}
		fiche.journal = [
			{"quand": maintenant - 5 * 3600, "motif": "evenement:loto:2026-10-24", "statut": "fait", "jetons_entree": 2300, "jetons_sortie": 380,
				"actions": [{"type": "roulette", "pari": "rouge", "mise": 100, "numero": 14, "net": 100},
					{"type": "roulette", "pari": "plein:17", "mise": 20, "numero": 3, "net": -20},
					{"type": "annonce", "texte": "Le rouge me réussit, qui vient au loto samedi ?"},
					{"type": "mot", "lot": "maison_place", "texte": "Pour le tuyau, Paulette : il n'y en a pas, mais je vous offre un café."}],
				"refusees": [{"type": "roulette", "raison": "mise"}]},
			{"quand": maintenant - 50 * 3600, "motif": "evenement:match:2026-10-25", "statut": "erreur", "jetons_entree": 0, "jetons_sortie": 0,
				"actions": [], "refusees": [], "erreur": "429 trop de demandes ou crédit épuisé"},
		]
		brouillon.cle = ""
	else:
		brouillon.nom = "Léonce"
		brouillon.personnalite = "autre"
		_aide_cle = true
		brouillon.caractere = "Tu es un vieux marin bourru : tu ne mises que sur le noir, tu parles en proverbes et tu te méfies des beaux parleurs."
		brouillon.modele = "claude-haiku-5-5"
		fiche.humeur = {"consentement": false, "humeur": null, "expire": null}
