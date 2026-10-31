extends Node
## Le courrier du joueur (autoload « Avis ») : tout ce que les activités ont à lui dire, au même endroit
## (demande de Guillaume du 23 octobre 2026 : « un petit système de notif »). La fiche de conception est
## notifications/conception.md, dans les fichiers du projet.
##
## Un avis : {id, quand (secondes locales, comme Agenda), genre, titre, texte, lien, importance, lu}.
## - id dit deux fois la même chose une seule fois : « match/3/7/smarves » relu au serveur ne revient pas ;
## - importance : « forte » et « normale » font glisser la fiche du carnet, « discrete » va seulement au
##   courrier (la recette des vingt mises tombe trop souvent pour une fiche à chaque fois) ;
## - lien : où mène le bouton de l'avis. {vers: "courrier"}, {vers: "carnet", onglet}, {vers: "agenda"},
##   {vers: "bureau", club, page} (le bureau du club de football, ouvert par-dessus le carnet, où qu'on soit),
##   {vers: "gerer", sport: "basket", club, page} (le bureau du club de basket, de même), {vers: "notaire",
##   sport, club} (le registre des parts chez le notaire, ouvert par téléphone par-dessus le carnet ; l'ancien
##   {vers: "registre", club} y mène aussi, au football), {vers: "stade", club} (le stade du club),
##   {vers: "salle", club} (la salle de basket).
##
## Il s'affiche à trois endroits : la fiche (une seule à la fois, cliquable, celles qui arrivent ensemble
## se fondent en une), la pastille « Messages : 3 nouvelles » tant qu'il reste du non lu, et la rubrique
## « Messages » du carnet. Jamais en pleine main : quand l'habitant est figé à une table ou dans une
## fenêtre, la fiche attend qu'il se lève. Au lancement, ce qui est arrivé pendant l'absence tient en une
## seule fiche.
##
## Les activités publient (publier) ; ce qu'elles ne disent pas d'elles-mêmes, le courrier le voit en
## relisant Football toutes les trente secondes (verifier) : le résultat des clubs dont on tient une part,
## les parts prises par d'autres joueurs, la direction perdue ou gagnée, la composition pas posée la
## veille du match, la trêve et le mercato.

signal change
## Une fiche est à montrer : son texte, et l'avis qu'elle ouvre ({} : le courrier entier). Le carnet la dessine.
signal fiche(texte: String, avis: Dictionary)

## Ce que le courrier garde, au plus.
const GARDES := 80
## Les avis arrivés à moins de deux secondes d'écart se fondent en une seule fiche.
const FUSION := 2.0
## Le temps de laisser le jeu s'ouvrir avant la première fiche (celle de l'absence).
const DEMARRAGE := 4.0
## Une fiche reste lisible le temps de la lire (le carnet compte de même).
static func duree(texte: String) -> float:
	return 6.1 + texte.length() * 0.03

## Les genres, et leur nom au singulier et au pluriel pour la fiche qui résume.
const GENRES := {
	"match": ["un match", "%d matchs"],
	"dividende": ["un dividende", "%d dividendes"],
	"parts": ["une part prise", "%d parts prises"],
	"direction": ["la direction d'un club", "%d changements de direction"],
	"rappel": ["un rappel", "%d rappels"],
	"calendrier": ["le calendrier", "%d nouvelles du calendrier"],
	"ticket": ["un ticket réglé", "%d tickets réglés"],
	"mercato": ["une nouvelle du mercato", "%d nouvelles du mercato"],
	"bourse": ["une position encaissée", "%d positions encaissées"],
	"biens": ["une nouvelle de vos biens", "%d nouvelles de vos biens"],
	"dilemme": ["une décision à prendre", "%d décisions à prendre"],
	"suite": ["la suite d'une décision", "%d suites de décisions"],
}

## Le dossier du courrier (les tests en prennent un à part).
var dossier := "user://"
## Les avis, le plus récent d'abord.
var liste: Array = []
## Ce que le courrier a déjà vu de Football, pour n'annoncer que ce qui change : {matchs: {club: "s/j"},
## porteurs: {club: {rang: par}}, direction: {club: bool}, periode: "s/periode"}.
var suivi := {}
## Les avis qui attendent leur fiche.
var _file: Array = []
var _attente := 0.0
## La fiche à l'écran se lit encore pendant ce temps.
var _occupe_fiche := 0.0
var _demarre := false
var _actif := false
## La première fiche après le lancement résume l'absence (« Pendant votre absence »).
var _absence := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Les tests et les captures partent d'un courrier vide, sans toucher au fichier du joueur.
	if get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()):
		return
	_actif = true
	charger()
	var minuteur := Timer.new()
	minuteur.wait_time = 30.0
	minuteur.autostart = true
	minuteur.timeout.connect(verifier)
	add_child(minuteur)
	Biens.note.connect(_note_des_biens)
	Football.change.connect(func(): verifier.call_deferred())
	(func():
		await get_tree().create_timer(DEMARRAGE).timeout
		verifier()
		_absence = not _file.is_empty()
		_demarre = true
		_attente = 0.0).call_deferred()


# ---------------------------------------------------------------- publier

## Publie un avis ; faux s'il était déjà publié (même id). Les champs manquants prennent leur valeur par défaut.
func publier(a: Dictionary) -> bool:
	var id := str(a.get("id", ""))
	if id == "" or deja(id):
		return false
	var avis := a.duplicate(true)
	avis.merge({"quand": maintenant(), "genre": "", "titre": "", "texte": "", "lien": {"vers": "courrier"}, "importance": "normale"})
	avis.quand = int(avis.quand)
	avis.lu = false
	liste.push_front(avis)
	liste.sort_custom(func(x, y): return int(x.quand) > int(y.quand))
	if liste.size() > GARDES:
		liste = liste.slice(0, GARDES)
	if avis.importance != "discrete":
		_file.append(avis)
		_attente = FUSION
	sauver()
	change.emit()
	return true


func deja(id: String) -> bool:
	return liste.any(func(x): return x.id == id)


func non_lus() -> Array:
	return liste.filter(func(x): return not bool(x.lu))


func tout_lu() -> void:
	var bouge := false
	for x in liste:
		if not bool(x.lu):
			x.lu = true
			bouge = true
	if bouge:
		sauver()
		change.emit()


## Marque lu un avis qu'on vient d'ouvrir (comme un message ouvert dans Football Manager).
func lire(id: String) -> void:
	for x in liste:
		if x.id == id and not bool(x.lu):
			x.lu = true
			sauver()
			change.emit()
			return


## Marque lus les avis dont la chose à faire est faite (demande de Guillaume du 24 octobre 2026 : « la boîte
## me donne 2 tâches, je les remplis, les messages apparaissent encore en non lus ») : la décision de la
## semaine tranchée (où que ce soit) ou close, le rappel de la composition une fois la tactique posée ou le
## match passé. Vrai si un avis a changé.
func solder() -> bool:
	var f := get_node_or_null("/root/Football")
	if f == null:
		return false
	var bouge := false
	for x in liste:
		if bool(x.lu):
			continue
		var fait := false
		if str(x.get("genre", "")) == "dilemme":
			var ch := choix_de(x)
			fait = ch.is_empty() or not ch[0].ouvert or ch.any(func(c): return c.fait)
		elif str(x.id).begins_with("compo/"):
			var p := str(x.id).split("/")
			if p.size() >= 4:
				var s := int(p[1])
				var j := int(p[2])
				fait = FootDilemmes.tactique_posee(f, p[3], s, j) or int(f.maintenant()) >= int(f.coup_envoi(s, j)) or not f.peut_decider(p[3])
		if fait:
			x.lu = true
			bouge = true
	if bouge:
		sauver()
		change.emit()
	return bouge


## Les secondes locales « maintenant », à l'horloge de l'agenda (celle du football).
func maintenant() -> int:
	return Agenda.maintenant()


# ---------------------------------------------------------------- la fiche

func _process(delta: float) -> void:
	if _occupe_fiche > 0.0:
		_occupe_fiche -= delta
	if not _demarre and _actif:
		return
	if _file.is_empty():
		return
	_attente -= delta
	if _attente > 0.0 or _occupe_fiche > 0.0 or occupe():
		return
	montrer_file()


## Montre ce qui attend, en une fiche : l'avis seul, ou le résumé de plusieurs. Rend le texte montré.
func montrer_file() -> String:
	var a := _filtrer(_file.duplicate())
	_file.clear()
	if a.is_empty():
		return ""
	var texte := ""
	var avis := {}
	if a.size() == 1:
		avis = a[0]
		texte = phrase(avis)
	else:
		texte = resume(a, not _absence)
	_absence = false
	_occupe_fiche = duree(texte)
	fiche.emit(texte, avis)
	return texte


## Le réglage du menu : « toutes » les fiches, l'« important » seulement (les fortes), ou « aucune ».
func _filtrer(a: Array) -> Array:
	var r := str(Settings.fiches)
	if r == "aucune":
		return []
	if r == "important":
		return a.filter(func(x): return x.importance == "forte")
	return a


## La fiche d'un avis : son titre, son texte, et où mène le clic.
func phrase(a: Dictionary) -> String:
	var t := str(a.titre)
	if str(a.texte) != "":
		t += "\n" + str(a.texte)
	var bouton := nom_du_lien(a.get("lien", {}))
	if bouton != "":
		t += "\n→ " + bouton
	return t


## La fiche de plusieurs avis : « Pendant votre absence » (au lancement) ou « 3 nouvelles », puis ce qu'il y a.
func resume(a: Array, en_jeu := true) -> String:
	var par := {}
	var ordre: Array = []
	var dividendes := 0
	for x in a:
		var g := str(x.genre) if GENRES.has(str(x.genre)) else "autre"
		if not par.has(g):
			ordre.append(g)
		par[g] = int(par.get(g, 0)) + 1
		if g == "dividende":
			dividendes += int(x.get("montant", 0))
	var morceaux: Array = []
	for g in ordre:
		var n: int = par[g]
		var mot: String = (GENRES.get(g, ["une nouvelle", "%d nouvelles"]) as Array)[0 if n == 1 else 1]
		if "%d" in mot:
			mot = mot % n
		if g == "dividende" and dividendes > 0:
			mot += " (%s crédits)" % Game.fmt(dividendes)
		morceaux.append(mot)
	var tete := ("%d nouvelles" % a.size()) if en_jeu else "Pendant votre absence"
	var corps := ", ".join(morceaux)
	return "%s\n%s.\n→ Lire le courrier (%d)" % [tete, corps.left(1).to_upper() + corps.substr(1), non_lus().size()]


## Le nom du bouton d'un lien.
func nom_du_lien(l) -> String:
	if not l is Dictionary:
		return ""
	match str(l.get("vers", "")):
		"bureau":
			var pages := {"championnat": "Le classement", "tactique": "Préparer la tactique", "entrainement": "L'entraînement", "offres": "Les offres en cours", "adversaire": "Le rapport de l'adjoint"}
			return str(pages.get(str(l.get("page", "")), "Le bureau du club"))
		"gerer":
			return {"marche": "Le marché", "comptes": "Les comptes"}.get(str(l.get("page", "")), "Le bureau du club")
		"notaire", "registre":
			return "Le notaire"
		"stade":
			return "Le stade du club"
		"salle":
			return "La salle du club"
		"carnet":
			return {"compte": "Mes comptes", "biens": "Mes comptes", "cartes": "Mes cartes", "clubs": "Mes clubs", "carriere": "Ma carrière",
				"aujourdhui": "Les messages", "boite": "Les messages", "courrier": "Les messages"}.get(str(l.get("onglet", "")), "Le carnet")
		"agenda":
			return "La semaine"
	return ""


## L'habitant est à une table, dans une fenêtre, ou le carnet est ouvert : la fiche attend.
func occupe() -> bool:
	if Carnet.is_open() or Settings.is_open() or get_tree().paused:
		return true
	var s := get_tree().current_scene
	if s == null or s.name == "Titre":
		return true
	var p = s.get("player")
	return p is Node and is_instance_valid(p) and bool(p.get("frozen"))


# ---------------------------------------------------------------- aller où l'avis mène

## Un lien qui change de lieu (le stade, la salle) ne s'ouvre pas en pleine main. Le bureau d'un club et le
## notaire, eux, s'ouvrent par-dessus le carnet, où qu'on soit (demandes de Guillaume du 24 octobre : gérer
## sans aller au stade, acheter ses parts chez le notaire comme le reste).
func change_de_lieu(l) -> bool:
	return l is Dictionary and str(l.get("vers", "")) in ["stade", "salle"]


func peut_aller(l) -> bool:
	if not change_de_lieu(l):
		return true
	var s := get_tree().current_scene
	var p = s.get("player") if s != null else null
	return not (p is Node and is_instance_valid(p) and bool(p.get("frozen")))


## Suit le lien d'un avis (ou ouvre le courrier) ; marque l'avis lu.
func aller(a: Dictionary) -> void:
	if not a.is_empty():
		for x in liste:
			if x.id == a.id and not bool(x.lu):
				x.lu = true
				sauver()
				change.emit()
	var l = a.get("lien", {"vers": "courrier"}) if not a.is_empty() else {"vers": "courrier"}
	if not peut_aller(l):
		l = {"vers": "courrier"}
	match str(l.get("vers", "courrier")):
		"bureau":
			Carnet.gerer("football", str(l.get("club", "")), str(l.get("page", "")))
		"gerer":
			Carnet.gerer(str(l.get("sport", "football")), str(l.get("club", "")), str(l.get("page", "")))
		"notaire", "registre":
			Carnet.notaire(str(l.get("sport", "football")), str(l.get("club", "")))
		"stade":
			if Carnet.is_open():
				Carnet.toggle()
			load("res://scripts/village/stade.gd").ouvrir_sur(str(l.get("club", "")), "")
		"salle":
			if Carnet.is_open():
				Carnet.toggle()
			Basket.ouvrir_salle(str(l.get("club", "")))
		"agenda":
			Carnet.ouvrir_sur("agenda")
		"carnet":
			Carnet.ouvrir_sur(str(l.get("onglet", "compte")))
		_:
			Carnet.ouvrir_sur("courrier")


# ---------------------------------------------------------------- ce que Football ne dit pas de lui-même

## Relit Football (les matchs joués, les porteurs des parts, la direction, la composition, le calendrier)
## et le basket (les matchs joués des clubs dont on tient une part).
func verifier() -> void:
	var f := get_node_or_null("/root/Football")
	var bouge := _basket()
	if f != null and not f.niveaux.is_empty():
		for club in _clubs_suivis(f):
			bouge = _matchs(f, club) or bouge
			bouge = _compo(f, club) or bouge
			bouge = _dilemme(f, club) or bouge
			bouge = _suite(f, club) or bouge
		# Les clubs suivis en supporter, sans part : les résultats seulement.
		for club in favoris("football"):
			if f.clubs.has(club) and not _clubs_suivis(f).has(club):
				bouge = _matchs(f, club) or bouge
		bouge = _porteurs(f) or bouge
		bouge = _periode(f) or bouge
	solder()
	if bouge:
		sauver()


## Le basket des clubs dont on tient une part : chaque journée jouée depuis la dernière lecture, un avis
## (la première fois, rien, comme au football). Sans cliché gardé, aucun match ne se joue ici.
func _basket() -> bool:
	var b := get_node_or_null("/root/Basket")
	if b == null or b.niveaux.is_empty() or b.cliches.is_empty():
		return false
	var aujourdhui: GDScript = load("res://scripts/socle/aujourdhui.gd")
	var vus: Dictionary = suivi.get("basket", {})
	var s: int = b.saison
	var jj: int = b.journee_jouee()
	var bouge := false
	for club in aujourdhui.suivis_basket(b, self):
		var cle := "%d/%d" % [s, jj]
		if str(vus.get(club, "")) == cle:
			continue
		var depuis := 0
		if vus.has(club):
			var p: PackedStringArray = str(vus[club]).split("/")
			depuis = int(p[1]) if int(p[0]) == s else 0
			for k in range(depuis + 1, jj + 1):
				var m: Dictionary = aujourdhui.match_basket(b, club, s, k)
				if m.is_empty() or (m.score as Array).is_empty():
					continue
				var gagne: bool = int(m.score[0]) > int(m.score[1])
				var c: Dictionary = aujourdhui.carte_basket(b, club) if k == jj else {}
				publier({"id": "basket/%d/%d/%s" % [s, k, club], "quand": int(m.quand) + 2 * 3600, "genre": "match",
					"titre": "%s : %s %d-%d %s %s" % [b.fiche(club).nom, "victoire" if gagne else "défaite", int(m.score[0]), int(m.score[1]),
						"contre" if m.dom else "chez", b.fiche(str(m.adv)).nom],
					"texte": "Basket, journée %d.%s" % [k, (" %s du groupe après la journée." % _rang(int(c.rang))) if not c.is_empty() and int(c.rang) > 0 else ""],
					"lien": {"vers": "carnet", "onglet": "clubs"}})
		vus[club] = cle
		bouge = true
	if bouge:
		suivi["basket"] = vus
	return bouge


# ---------------------------------------------------------------- les clubs suivis en supporter

## Les clubs qu'on suit sans y tenir de part (demande de Guillaume du 31 octobre 2026 : « s'informer en
## tant que fan »), par sport (« football », « basket ») : leur page reste dans Mes clubs, leurs résultats
## arrivent au courrier. Gardés ici, avec ce que le courrier a déjà vu : suivi.favoris = {sport: [clubs]}.
func favoris(sport: String) -> Array:
	var f: Dictionary = suivi.get("favoris", {}) if suivi.get("favoris", {}) is Dictionary else {}
	var l = f.get(sport, [])
	return (l as Array).map(func(c): return str(c)) if l is Array else []


func suit(sport: String, club: String) -> bool:
	return favoris(sport).has(club)


## Suit un club en supporter (oui), ou cesse de le suivre.
func suivre(sport: String, club: String, oui := true) -> void:
	if club == "" or suit(sport, club) == oui:
		return
	var f: Dictionary = suivi.get("favoris", {}) if suivi.get("favoris", {}) is Dictionary else {}
	var l := favoris(sport)
	if oui:
		l.append(club)
	else:
		l.erase(club)
	f[sport] = l
	suivi["favoris"] = f
	sauver()
	change.emit()


## Les clubs dont on tient au moins une part.
func _clubs_suivis(f: Node) -> Array:
	return f.obligations_locales.keys().filter(func(c): return not (f.mes_obligations(c) as Array).is_empty())


func _nom(f: Node, club: String) -> String:
	return str((f.clubs.get(club, {}) as Dictionary).get("nom", club))


## Les journées jouées depuis la dernière lecture, une par avis. La première fois, rien : on ne refait pas
## l'histoire de la saison.
func _matchs(f: Node, club: String) -> bool:
	var vus: Dictionary = suivi.get("matchs", {})
	var s: int = f.saison
	var jj: int = f.journee_jouee()
	var cle := "%d/%d" % [s, jj]
	if not vus.has(club):
		vus[club] = cle
		suivi["matchs"] = vus
		return true
	var p: PackedStringArray = str(vus[club]).split("/")
	var depuis := int(p[1]) if int(p[0]) == s else 0
	if depuis >= jj:
		if str(vus[club]) != cle and int(p[0]) != s:
			vus[club] = cle
			return true
		return false
	var place: Array = f.place_de(club)
	for k in range(depuis + 1, jj + 1):
		var m: Dictionary = FootCourrier.match_de(f, club, s, k)
		if m.is_empty() or (m.score as Array).is_empty():
			continue
		var i := FootCourrier.issue(m, club)
		var rang := ""
		if not place.is_empty() and k == jj:
			var cl: Array = f.classement(s, place[0], place[1])
			for r in cl.size():
				if cl[r].club == club:
					rang = " %s du groupe après la journée." % _rang(r + 1)
		publier({"id": "match/%d/%d/%s" % [s, k, club], "quand": int(f.coup_envoi(s, k)) + 2 * 3600, "genre": "match",
			"titre": "%s : %s %d-%d %s %s" % [_nom(f, club), str(i.mot).to_lower(), i.pour, i.contre, "contre" if i.domicile else "chez", _nom(f, str(i.adv))],
			"texte": "Journée %d.%s" % [k, rang], "lien": {"vers": "bureau", "club": club, "page": "championnat"}})
	vus[club] = cle
	suivi["matchs"] = vus
	return true


static func _rang(r: int) -> String:
	return "1er" if r == 1 else "%de" % r


## La veille du match, la composition d'un club qu'on dirige n'est pas posée.
func _compo(f: Node, club: String) -> bool:
	if not f.peut_decider(club):
		return false
	var r: Dictionary = f.prochain_match(club)
	if r.is_empty():
		return false
	var reste: int = int(f.coup_envoi(r.s, r.j)) - int(f.maintenant())
	if reste <= 0 or reste > 86400:
		return false
	if FootDilemmes.tactique_posee(f, club, int(r.s), int(r.j)):
		return false
	return publier({"id": "compo/%d/%d/%s" % [r.s, r.j, club], "genre": "rappel",
		"titre": "%s : la composition de demain n'est pas posée" % _nom(f, club),
		"texte": "Sans consigne, l'adjoint aligne l'équipe type en 4-4-2, mentalité équilibrée. Coup d'envoi %s à %s." % [Agenda.jour_relatif(int(f.coup_envoi(r.s, r.j)), int(f.maintenant())), Agenda.heure(int(f.coup_envoi(r.s, r.j)))],
		"lien": {"vers": "bureau", "club": club, "page": "tactique"}})


## Les parts des clubs qu'on suit : qui a pris laquelle depuis la dernière lecture, et la direction.
## Tant que le serveur n'a rien dit (obligations vides), rien ne se compare.
func _porteurs(f: Node) -> bool:
	if f.obligations.is_empty():
		return false
	var avant: Dictionary = suivi.get("porteurs", {})
	var dir_avant: Dictionary = suivi.get("direction", {})
	var apres := {}
	var dir_apres := {}
	var clubs: Array = _clubs_suivis(f)
	for club in avant.keys():
		if not clubs.has(club):
			clubs.append(club)
	for club in clubs:
		var p := {}
		for r in (f.obligations.get(club, {}) as Dictionary):
			var o: Dictionary = f.obligations[club][r]
			p[str(r)] = "vous" if bool(o.get("moi", false)) else str(o.get("par", ""))
		for r in f.mes_obligations(club):
			p[str(r)] = "vous"
		apres[club] = p
		dir_apres[club] = bool(f.peut_decider(club))
		if not avant.has(club):
			continue
		var a: Dictionary = avant[club]
		for r in p:
			var qui := str(p[r])
			if qui == "" or qui == "vous" or str(a.get(r, "")) == qui:
				continue
			var etait := str(a.get(r, ""))
			publier({"id": "parts/%s/%s/%s" % [club, r, qui], "genre": "parts", "importance": "forte",
				"titre": "%s a pris l'obligation n° %s de %s" % [qui, r, _nom(f, club)],
				"texte": "Elle était à vous : un autre l'avait prise avant, elle vous est rendue à sa valeur." if etait == "vous" else "",
				"lien": {"vers": "notaire", "sport": "football", "club": club}})
		if dir_avant.has(club) and bool(dir_avant[club]) != bool(dir_apres[club]):
			var ac: Array = f.actionnaires(club)
			var tete: String = "" if ac.is_empty() or bool(ac[0].get("moi", false)) else str(ac[0].get("nom", ""))
			publier({"id": "direction/%s/%d/%d/%s" % [club, f.saison, f.journee_jouee(), "oui" if dir_apres[club] else "non"], "genre": "direction", "importance": "forte",
				"titre": ("Vous dirigez désormais %s" % _nom(f, club)) if dir_apres[club] else ("Vous ne dirigez plus %s" % _nom(f, club)),
				"texte": "La plus grosse somme investie dirige : la tactique, l'entraînement et le mercato sont à vous." if dir_apres[club] \
					else ("%s a investi davantage. Vous gardez vos parts et leurs dividendes." % tete if tete != "" else "Un autre a investi davantage. Vous gardez vos parts et leurs dividendes."),
				"lien": {"vers": "bureau", "club": club, "page": ""}})
	if apres == avant and dir_apres == dir_avant:
		return false
	suivi["porteurs"] = apres
	suivi["direction"] = dir_apres
	return true


## La décision de la semaine d'un club qu'on dirige (FootDilemmes) : elle arrive à la fin du match d'avant
## et se tranche au courrier, jusqu'au coup d'envoi. L'avis porte {dilemme: {s, j, club}} : le carnet y met
## les deux boutons.
func _dilemme(f: Node, club: String) -> bool:
	if not f.peut_decider(club):
		return false
	var r: Dictionary = f.prochain_match(club)
	if r.is_empty():
		return false
	var t: int = f.maintenant()
	if int(r.j) > 1 and t < int(f.coup_envoi(r.s, int(r.j) - 1)) + 3 * 3600:
		return false
	var d: Dictionary = FootDilemmes.du_jour(f, club, int(r.s), int(r.j))
	if d.is_empty():
		return false
	return publier({"id": "dilemme/%d/%d/%s" % [r.s, r.j, club], "genre": "dilemme", "importance": "forte",
		"titre": "%s : %s" % [_nom(f, club), d.titre], "texte": str(d.texte),
		"dilemme": {"s": int(r.s), "j": int(r.j), "club": club}, "lien": {"vers": "courrier"}})


## La suite d'une décision, une fois le match joué : ce qu'elle a fait, et le résultat. Sans réponse, l'avis
## dit que l'adjoint n'a rien tranché. Seulement pour une décision que ce courrier a montrée.
func _suite(f: Node, club: String) -> bool:
	var s: int = f.saison
	var j: int = f.journee_jouee()
	if j < 1 or not deja("dilemme/%d/%d/%s" % [s, j, club]) or deja("suite/%d/%d/%s" % [s, j, club]):
		return false
	var m: Dictionary = FootCourrier.match_de(f, club, s, j)
	if m.is_empty() or (m.score as Array).is_empty():
		return false
	var d: Dictionary = FootDilemmes.du_jour(f, club, s, j)
	var choix: String = FootDilemmes.choix_de(f, club, s, j)
	var i := FootCourrier.issue(m, club)
	var resultat := "%s %d-%d %s %s." % [i.mot, i.pour, i.contre, "contre" if i.domicile else "chez", _nom(f, str(i.adv))]
	var texte := (str(d[choix].suite) if choix != "" else "Personne n'a tranché : l'adjoint a laissé faire, rien n'a changé.") + " " + resultat
	return publier({"id": "suite/%d/%d/%s" % [s, j, club], "quand": int(f.coup_envoi(s, j)) + 2 * 3600 + 60, "genre": "suite",
		"titre": "%s : %s" % [_nom(f, club), ("suite de « %s »" % str(d[choix].libelle)) if choix != "" else "la décision de la semaine est restée sans réponse"],
		"texte": texte, "lien": {"vers": "bureau", "club": club, "page": "championnat"}})


## Les deux boutons d'un avis de décision : [{choix, libelle, fait, ouvert}] ; [] si l'avis n'en est pas un.
## fait : le choix tranché ; ouvert : on peut encore trancher (on dirige, le match n'est pas joué).
func choix_de(a: Dictionary) -> Array:
	var x = a.get("dilemme", null)
	var f := get_node_or_null("/root/Football")
	if not (x is Dictionary) or f == null:
		return []
	var d: Dictionary = FootDilemmes.du_jour(f, str(x.club), int(x.s), int(x.j))
	if d.is_empty():
		return []
	var tranche: String = FootDilemmes.choix_de(f, str(x.club), int(x.s), int(x.j))
	var ouvert: bool = f.peut_decider(str(x.club)) and int(f.maintenant()) < int(f.coup_envoi(int(x.s), int(x.j))) and int(x.s) == int(f.saison)
	return ["a", "b"].map(func(c): return {"choix": c, "libelle": str(d[c].libelle), "fait": tranche == c, "ouvert": ouvert})


## Tranche la décision d'un avis, et le marque lu.
func trancher(a: Dictionary, choix: String) -> bool:
	var x = a.get("dilemme", null)
	var f := get_node_or_null("/root/Football")
	if not (x is Dictionary) or f == null or not FootDilemmes.choisir(f, str(x.club), int(x.s), int(x.j), choix):
		return false
	for y in liste:
		if y.id == a.id:
			y.lu = true
	sauver()
	change.emit()
	return true


## La trêve et le mercato, quand la période change.
func _periode(f: Node) -> bool:
	var p: String = f.periode()
	var cle := "%d/%s" % [f.saison, p]
	if str(suivi.get("periode", "")) == cle:
		return false
	var premiere := not suivi.has("periode")
	suivi["periode"] = cle
	if premiere or p == "saison":
		return true
	var suivis := not _clubs_suivis(f).is_empty()
	if p == "treve":
		publier({"id": "periode/" + cle, "genre": "calendrier", "importance": "normale" if suivis else "discrete",
			"titre": "La trêve : la saison %d est finie" % (int(f.saison) - 1),
			"texte": "Les premiers de chaque groupe montent, les deux derniers descendent. Une semaine de trêve, puis une de mercato avant la première journée.",
			"lien": {"vers": "agenda"}})
	elif p == "mercato":
		publier({"id": "periode/" + cle, "genre": "calendrier", "importance": "normale" if suivis else "discrete",
			"titre": "Le mercato d'avant-saison est ouvert",
			"texte": "Une semaine pour renforcer l'effectif avant la première journée de la saison %d." % int(f.saison),
			"lien": {"vers": "agenda"}})
	return true


# ---------------------------------------------------------------- les activités qui publient

## La recette des biens (toutes les vingt mises) : discrète, sauf quand M. Brunet s'en mêle.
func _note_des_biens(texte: String) -> void:
	var fort := "\n" in texte or "M. Brunet" in texte
	publier({"id": "biens/%d/%d" % [int(Biens.get("recettes")), maintenant()], "genre": "biens", "importance": "forte" if fort else "discrete",
		"titre": texte.get_slice("\n", 0), "texte": texte.get_slice("\n", 1) if "\n" in texte else "", "lien": {"vers": "carnet", "onglet": "compte"}})


# ---------------------------------------------------------------- la sauvegarde

func _chemin() -> String:
	return dossier.path_join("avis.json")


func charger() -> void:
	var f := FileAccess.open(_chemin(), FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		liste = (d.get("liste", []) as Array).filter(func(x): return x is Dictionary and x.has("id"))
		suivi = d.get("suivi", {}) if d.get("suivi", {}) is Dictionary else {}
		for x in liste:
			x.quand = int(x.get("quand", 0))


func sauver() -> void:
	if not _actif and dossier == "user://":
		return
	var f := FileAccess.open(_chemin(), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"liste": liste, "suivi": suivi}))


func effacer() -> void:
	liste = []
	suivi = {}
	_file.clear()
	if FileAccess.file_exists(_chemin()):
		DirAccess.remove_absolute(_chemin())
	change.emit()
