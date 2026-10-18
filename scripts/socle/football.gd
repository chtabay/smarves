extends Node
## Le football de la Vienne (autoload « Football ») : une pyramide de divisions à huit clubs au plus, à la
## Hattrick, qui lit les terrains du registre des structures (docs/SUITE.md, section 6). Toute commune
## qui déclare un terrain (« terrain_foot ») a un club, qui entre dans la division la plus basse à la
## saison suivante. Seuls les clubs inscrits jouent : pas de club fictif pour remplir (demande de
## Guillaume du 18 octobre 2026), deux clubs suffisent pour commencer, et un club seul attend le
## deuxième. Le premier de chaque groupe monte, les deux derniers descendent dans les deux groupes fils.
## Le championnat vit sur le calendrier réel : un match le dimanche à 15 h, quatorze journées puis une
## semaine de trêve et une de mercato, trois saisons par an. Un résultat ne dépend que d'une graine
## (saison, journée, clubs) et des consignes prises avant le coup d'envoi : tout le monde calcule le
## même, hors ligne : le match est joué minute par minute (FootMatch, repris du Vestiaire) avec les
## effectifs de la saison, et son score est le résultat officiel.
##
## Les consignes (formation, mentalité, pressing, et depuis le 18 octobre la composition, le banc et un
## rôle par joueur) sont la seule chose qu'un joueur change au championnat, et elles entrent dans la
## graine : pour que le résultat reste commun, elles sont tenues au serveur (fonctions
## public.smarves_consignes et smarves_consigne_poser, supabase/migrations) et lues au lancement. Une
## consigne posée sans compte reste « locale » : le jeu la garde, la montre comme telle, et l'envoie dès
## que le joueur se connecte, si le coup d'envoi n'est pas passé.

## La pyramide a changé (une saison s'est finie, un club est entré).
signal change

## L'effectif de fondation d'un club : deux gardiens, six défenseurs, six milieux, quatre attaquants,
## tirés une fois pour toutes de la graine du club ; des noms inventés, combinés sans viser personne.
## Ils restent d'une saison à l'autre, vieillissent d'un an par saison, progressent ou déclinent avec
## l'âge (progression), et un joueur qui passe RETRAITE laisse sa place à un jeune du cru.
const EFFECTIF := [["G", 2], ["D", 6], ["M", 6], ["A", 4]]
const RETRAITE := 35
## Le rôle d'un joueur sur le terrain, la consigne individuelle de la tactique (FootMatch.EFFETS_ROLES
## dit ce que chacun fait au match) ; « normal » ne s'écrit pas dans la consigne.
const ROLES := {"normal": "Normal", "offensif": "Offensif", "defensif": "Défensif", "createur": "Créateur", "tireur": "Tireur de coups de pied arrêtés"}
const ROLE_DEFAUT := "normal"
const PRENOMS := ["Adrien", "Alban", "Alexis", "Amaury", "Anselme", "Arno", "Aurèle", "Bastien", "Benoît", "Bertrand",
	"Bruno", "Cédric", "Célestin", "Clément", "Corentin", "Damien", "Denis", "Dorian", "Edgar", "Élie",
	"Émile", "Enzo", "Éric", "Étienne", "Fabien", "Félix", "Firmin", "Florent", "Gaël", "Gaspard",
	"Gilles", "Gustave", "Hugo", "Ilan", "Isaac", "Jasper", "Joachim", "Jonas", "Jules", "Kilian",
	"Léandre", "Léon", "Loïc", "Lucien", "Malo", "Marius", "Mathis", "Maxence", "Milo", "Nathan",
	"Nils", "Noé", "Octave", "Olivier", "Oscar", "Pablo", "Pascal", "Quentin", "Rafael", "Rémi",
	"Romain", "Ruben", "Sacha", "Samir", "Simon", "Stan", "Sylvain", "Théo", "Thibault", "Timéo",
	"Tristan", "Ugo", "Valentin", "Victor", "Willem", "Xavier", "Yanis", "Yohan", "Zacharie", "Ziad",
	"Kofi", "Moussa", "Idrissa", "Tomás", "Matteo", "Luka", "Jens", "Sören", "Iker", "Davide"]
const NOMS := ["Aubrac", "Barneville", "Belcastel", "Bérard", "Boisseau", "Brémond", "Carvin", "Castagné", "Chabrol", "Chauvelin",
	"Cordier", "Courtil", "Dalbret", "Daumas", "Delorme", "Desvignes", "Dorval", "Duclair", "Escoffier", "Faverge",
	"Fenouil", "Flamand", "Fourcade", "Gaillac", "Garrigou", "Gauvrit", "Guérande", "Hallier", "Hébrard", "Jaouen",
	"Joubert", "Kerlaz", "Labarthe", "Lacombe", "Lagarde", "Lamothe", "Larcher", "Lebrun", "Lemarié", "Loubière",
	"Malaurie", "Marceau", "Maréchal", "Mazière", "Méjean", "Montel", "Morvan", "Nadeau", "Navarre", "Noblet",
	"Ollivier", "Orsini", "Pagès", "Perrault", "Peyrol", "Pichon", "Plantier", "Quéré", "Rabier", "Raynal",
	"Renaudin", "Rivière", "Rochette", "Roustan", "Sabatier", "Saulnier", "Ségalen", "Solère", "Tardieu", "Tessier",
	"Thouvenel", "Trémolet", "Vachon", "Valette", "Vasseur", "Verdier", "Vidalenc", "Villard", "Yvinec", "Zaragoz",
	"Abadie", "Bakary", "Diarrao", "Ekwalla", "Fonsagrives", "Haddadi", "Kabila", "Mbango", "Ndoumbé", "Okafar",
	"Brandvold", "Halvard", "Iturbe", "Lindqvar", "Moravec", "Ostrovan", "Pellegrina", "Sandoret", "Torvik", "Valdemar"]

## Le premier dimanche de la première saison, à 15 h locale, et la longueur d'une saison en semaines.
const EPOQUE := {"year": 2026, "month": 10, "day": 25}
const HEURE_COUP_ENVOI := 15
const JOURNEES := 14
const SEMAINES_PAR_SAISON := 16
const TAILLE := 8
const MONTENT := 1
const DESCENDENT := 2
## Le fichier de la pyramide (dans le dossier des greffes, à côté du catalogue).
const FICHIER := "football.json"

## Les noms d'un club de village (clubs_de_la_vienne : les vendeurs et acheteurs du marché, hors
## championnat), tirés de la graine de sa commune, et des paires de couleurs.
## Les joueurs libres d'une saison : combien par poste, et le prix d'une recrue d'après sa note.
const LIBRES := [["G", 2], ["D", 4], ["M", 4], ["A", 2]]
const NOMS_INVITES := ["Union sportive %s", "Étoile sportive %s", "Avenir %s", "Jeunesse sportive %s", "Football-club %s", "Espérance %s", "Entente sportive %s", "Olympique %s"]
const COULEURS := [["#1b3c8c", "#f2c94c"], ["#a3192e", "#ffffff"], ["#0f6b3f", "#ffffff"], ["#2a8fd1", "#0b2340"], ["#5b2a86", "#e6d8f5"],
	["#f07a1a", "#1a1a1a"], ["#111111", "#e8e8e8"], ["#7a1f3d", "#f4d6b0"], ["#e6c229", "#123a6b"], ["#2b2b2b", "#d23b2b"], ["#3d7a2a", "#f2e6c9"], ["#c8102e", "#0e2b5c"]]

## La saison en cours (1 au départ) et la pyramide : niveaux[n] est la liste des groupes du niveau n
## (le niveau 0 est le haut), un groupe est une liste d'ids de clubs (de zéro à TAILLE). clubs : id ->
## {nom, court, couleurs, commune, insee, stade, fondation (la saison où le club est entré)}.
## historique : [{saison, champion, montes, descendus}].
var saison := 1
var niveaux: Array = []
var clubs := {}
var historique: Array = []
## Les consignes prises avant un match : "saison/journee/club" -> {formation, mentalite, pressing, puis
## s'ils sont donnés compo (onze ids, « » pour une case laissée à l'adjoint), banc ([ids]) et roles ({id:
## role})}, toujours ces clés dans cet ordre (consigne()) : elles entrent telles quelles dans la graine.
var decisions := {}
## Les consignes de cet appareil que le serveur n'a pas encore : clé -> true. Le tableau le dit.
var locales := {}
## Qui a posé chaque consigne lue au serveur : clé -> nom du joueur.
var auteurs := {}
## « » tant que rien n'est lu, puis « lecture », « ok » ou « hors_ligne ».
var consignes_etat := ""
## Les obligations des clubs, cédées chez le notaire (docs/SUITE.md, section 6), sur le modèle d'Impérial
## 2030 : neuf par club, de tailles différentes (OBLIGATIONS, rang 1 à 9) et chacune en un seul exemplaire ;
## la plus grosse somme investie dirige le club (peut_decider) ; chaque journée jouée verse un dividende
## (DIVIDENDE par cran, selon le classement). Celles lues au serveur, club -> {rang: {par, moi}} ; les
## siennes d'ici, club -> [rangs] (la sauvegarde fait foi) ; ce qui reste à dire au serveur, club ->
## {rang: true (prise) | false (rendue)} ; et la dernière journée dont le dividende est versé, club -> {s, j}.
const OBLIGATIONS := [500, 1000, 1500, 2250, 3000, 4000, 5000, 6250, 7500]
const DIVIDENDE := 50
## Ce que l'étude reprend d'une obligation rendue.
const RACHAT := 0.8
var obligations := {}
var obligations_locales := {}
var obligations_a_declarer := {}
var dividendes := {}
var dividendes_total := 0
## Le crochet du module mercato : salaires(club) -> int, ce que les joueurs achetés au marché coûtent par
## semaine ; retenu sur les dividendes, au prorata de ce que chacun a investi. Invalide sans module.
var salaires := Callable()
## Le mercato (docs/SUITE.md, section 6) : la recrue de chaque club pour une saison, "saison/club" ->
## {joueur (le rang du joueur libre), par}, et celles de cet appareil que le serveur n'a pas : clé -> true.
var transferts := {}
var transferts_locaux := {}
## Où lire et écrire la pyramide ; un test le déplace. « » : rien n'est écrit.
var dossier := Communes.GREFFES
var _horloge: Callable = Callable()
## Les matchs déjà joués et les effectifs déjà tirés, en mémoire : tout se recalcule à l'identique.
var _matchs := {}
var _effectifs := {}
## Le crochet du module mercato (fil dédié) : renforts(s, j, club) -> Array de joueurs {id, prenom, nom, poste,
## age, note, condition, moral, competences, ...} achetés au marché, que le club a au coup d'envoi de la journée
## j ; ils s'ajoutent à l'effectif du cru (la composition prend les meilleurs). Leur id commence par « club/ ».
## Invalide sans module, et l'effectif est celui du tirage.
var renforts := Callable()


func _ready() -> void:
	# Les tests et les captures partent d'une pyramide vide, sans toucher au fichier du joueur.
	if get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()):
		return
	charger()
	Registre.change.connect(actualiser)
	actualiser()
	# Les dividendes tombent après chaque journée jouée, où que soit le joueur : une passe au lancement, puis
	# toutes les minutes ; la fiche du carnet l'annonce.
	var minuteur := Timer.new()
	minuteur.wait_time = 60.0
	minuteur.autostart = true
	minuteur.timeout.connect(tic)
	add_child(minuteur)
	tic.call_deferred()
	# Le compte (autoload Compte) arrive après Football dans l'arbre : on l'attend une image.
	(func():
		lire_consignes()
		lire_obligations()
		lire_transferts()
		var compte := _compte()
		if compte != null:
			compte.change.connect(func():
				if compte.etat == "a_jour":
					if not locales.is_empty():
						envoyer_locales()
					if not obligations_a_declarer.is_empty():
						envoyer_obligations()
					if not transferts_locaux.is_empty():
						envoyer_transferts())).call_deferred()


# ---------------------------------------------------------------- le calendrier réel

## Les secondes écoulées « maintenant », en temps local (un test remplace l'horloge).
func maintenant() -> int:
	if _horloge.is_valid():
		return _horloge.call()
	return int(Time.get_unix_time_from_system()) + Time.get_time_zone_from_system().bias * 60


## Remplace l'horloge (essais) : une fonction qui rend des secondes locales, ou une Callable vide.
func regler_horloge(h: Callable) -> void:
	_horloge = h


## Le coup d'envoi de la journée j (1 à 14) de la saison s, en secondes locales.
static func coup_envoi(s: int, j: int) -> int:
	var semaine := (s - 1) * SEMAINES_PAR_SAISON + (j - 1)
	return Time.get_unix_time_from_datetime_dict({"year": EPOQUE.year, "month": EPOQUE.month, "day": EPOQUE.day,
		"hour": HEURE_COUP_ENVOI, "minute": 0, "second": 0}) + semaine * 7 * 86400


## Le début d'une saison : deux semaines avant son premier coup d'envoi (la trêve, puis le mercato,
## appartiennent à la saison qui s'ouvre : c'est là que les clubs nouveaux entrent).
static func debut(s: int) -> int:
	return coup_envoi(s, 1) - 2 * 7 * 86400


## La saison du calendrier à cet instant (1 avant l'époque), et la journée qui vient de se jouer
## (0 avant la première, 14 après la dernière).
static func saison_a(t: int) -> int:
	return maxi(1, 1 + int(floor(float(t - debut(1)) / (SEMAINES_PAR_SAISON * 7 * 86400))))


static func journee_jouee_a(t: int, s: int) -> int:
	var n := 0
	for j in range(1, JOURNEES + 1):
		if t >= coup_envoi(s, j):
			n = j
	return n


## Le prochain coup d'envoi après t : [saison, journee, secondes].
static func prochain_coup_envoi(t: int) -> Array:
	var s := saison_a(t)
	for j in range(1, JOURNEES + 1):
		if t < coup_envoi(s, j):
			return [s, j, coup_envoi(s, j)]
	return [s + 1, 1, coup_envoi(s + 1, 1)]


## Combien de journées de la saison en cours sont jouées, et où l'on en est (« treve » la semaine qui
## suit la dernière journée de la saison passée, « mercato » la semaine d'avant la première journée,
## « saison » sinon).
func journee_jouee() -> int:
	return journee_jouee_a(maintenant(), saison)


func periode() -> String:
	var t := maintenant()
	if saison_a(t) != saison:
		return "saison"
	var semaine := int(floor(float(t - debut(saison)) / (7 * 86400)))
	return "treve" if semaine == 0 else ("mercato" if semaine == 1 else "saison")


# ---------------------------------------------------------------- la pyramide

## Met la pyramide au jour du calendrier : chaque saison finie est close (montées, descentes), et les
## terrains nouveaux du registre reçoivent leur club à la saison suivante, tant qu'elle n'a pas
## commencé. À appeler à l'ouverture et quand le registre change ; sans effet si rien n'a bougé.
func actualiser() -> void:
	var bouge := false
	if niveaux.is_empty():
		_fonder()
		bouge = true
	var cible := saison_a(maintenant())
	while saison < cible:
		clore_saison()
		bouge = true
	if journee_jouee() == 0 and _accueillir():
		bouge = true
	if bouge:
		sauver()
		change.emit()


## Le premier groupe : les terrains du registre, et rien d'autre (vide tant qu'aucune commune n'a de terrain).
func _fonder() -> void:
	clubs = {}
	for e in Registre.de_type("terrain_foot"):
		_club_du_registre(e)
	var groupe: Array = clubs.keys()
	groupe.sort()
	niveaux = [[groupe]]


## Ferme la saison en cours : classements finaux, le premier de chaque groupe monte dans le groupe
## père, les deux derniers descendent dans les deux groupes fils. Puis la saison suivante s'ouvre.
func clore_saison() -> void:
	var finals := []
	for n in niveaux.size():
		var rangs := []
		for g in niveaux[n].size():
			rangs.append(classement(saison, n, g, JOURNEES).map(func(l): return l.club))
		finals.append(rangs)
	var champion: String = finals[0][0][0] if not finals[0][0].is_empty() else ""
	var montes := []
	var descendus := []
	var suivants := []
	for n in niveaux.size():
		var groupes := []
		for g in niveaux[n].size():
			groupes.append(finals[n][g].duplicate())
		suivants.append(groupes)
	# Du bas vers le haut : les fils (niveau n+1, groupes 2g et 2g+1) envoient leur premier au père g,
	# le père envoie son avant-dernier au fils 2g et son dernier au fils 2g+1. Un fils vide n'envoie
	# personne et ne reçoit personne ; un père trop petit pour descendre quelqu'un sous son champion garde tout.
	for n in range(niveaux.size() - 2, -1, -1):
		for g in niveaux[n].size():
			var pere: Array = suivants[n][g]
			for k in 2:
				var f: int = 2 * g + k
				if f >= suivants[n + 1].size():
					continue
				var fils: Array = suivants[n + 1][f]
				var i: int = pere.size() - DESCENDENT + k
				if fils.is_empty() or i < 1:
					continue
				var monte: String = fils[0]
				var descend: String = pere[i]
				fils[0] = descend
				pere[i] = monte
				montes.append(monte)
				descendus.append(descend)
	historique.append({"saison": saison, "champion": champion, "montes": montes, "descendus": descendus})
	for n in suivants.size():
		for g in suivants[n].size():
			suivants[n][g].sort()
	niveaux = suivants
	saison += 1


## Les terrains du registre qui n'ont pas encore de club : un club chacun, dans la division la plus
## basse, au premier groupe qui a de la place ; quand le bas est plein, un niveau s'ouvre dessous.
## Un club dont la commune a disparu du registre reste : on ne raye pas un club du jour au lendemain.
func _accueillir() -> bool:
	var bouge := false
	for e in Registre.de_type("terrain_foot"):
		if clubs.has(e.commune):
			continue
		_club_du_registre(e)
		var place := _place_libre()
		if place < 0:
			niveaux.append([])
			for g in 1 << (niveaux.size() - 1):
				niveaux[-1].append([])
			place = 0
		niveaux[-1][place].append(e.commune)
		bouge = true
	if bouge:
		for n in niveaux.size():
			for g in niveaux[n]:
				g.sort()
	return bouge


## Le premier groupe du dernier niveau qui n'est pas plein, ou -1.
func _place_libre() -> int:
	for g in niveaux[-1].size():
		if niveaux[-1][g].size() < TAILLE:
			return g
	return -1


## Le nom d'un club de village pour une commune de la Vienne (une entrée de Vienne.communes()), tiré de
## sa graine : « Union sportive de Nouaillé », « Avenir d'Iteuil ».
static func nom_de_village(c: Dictionary) -> String:
	var h := Hasard.depuis(Hasard.graine("invite/" + str(c.insee)))
	var nom: String = str(c.nom)
	var patron: String = NOMS_INVITES[h.entier(0, NOMS_INVITES.size() - 1)]
	return patron % _de(nom)


## Les clubs de village de la Vienne qui ne sont pas au championnat : les quarante communes réelles sans
## paquet les plus proches de la commune d'origine, par leur nom de club, triés. Le marché (module
## mercato) y prend ses vendeurs et ses acheteurs ; ils ne jouent aucun match.
func clubs_de_la_vienne() -> Array:
	var prises := {}
	for id in clubs:
		prises[str(clubs[id].insee)] = true
	var centre := Vienne.centre(Communes.origine().insee) if Communes.origine() else Vector2.ZERO
	var candidates := Vienne.communes().filter(func(c): return not prises.has(str(c.insee)) and str(c.insee) != "86194" and Communes.par_insee(str(c.insee)) == null)
	candidates.sort_custom(func(a, b):
		var da: float = Vector2(a.centre[0], a.centre[1]).distance_squared_to(centre)
		var db: float = Vector2(b.centre[0], b.centre[1]).distance_squared_to(centre)
		return da < db if da != db else str(a.insee) < str(b.insee))
	var out: Array = []
	for c in candidates.slice(0, 40):
		out.append(nom_de_village(c))
	out.sort()
	return out


func _club_du_registre(e: Dictionary) -> void:
	var champs: Dictionary = e.champs
	var nom := str(champs.get("club", e.nom))
	var court := str(champs.get("court", ""))
	if court == "":
		for m in nom.replace("-", " ").replace("'", " ").split(" ", false):
			if m.length() > 2:
				court += m.left(1).to_upper()
		court = court.left(3)
	var couleurs: Array = champs.get("couleurs", COULEURS[Hasard.graine(e.commune) % COULEURS.size()])
	clubs[e.commune] = {"nom": nom, "court": court, "couleurs": couleurs, "commune": e.commune, "insee": e.insee,
		"stade": str(champs.get("stade", e.nom)), "fondation": saison}


## Les terrains du registre qui attendent la prochaine saison pour avoir leur club : [commune].
func en_attente() -> Array:
	return Registre.de_type("terrain_foot").map(func(e): return e.commune).filter(func(c): return not clubs.has(c))


## Ouvre le stade d'une commune qui a un terrain : la scène du socle (scenes/stade.tscn, scripts/village/
## stade.gd), habillée du club, des couleurs et du nom de stade de sa structure « terrain_foot ». La
## commune l'appelle depuis sa scène (la porte de son terrain) ; la sortie du stade la ramène chez elle.
func ouvrir_stade(commune: String) -> void:
	load("res://scripts/village/stade.gd").ouvrir(commune)


## Le niveau et le groupe d'un club : [n, g], ou [] s'il n'est pas dans la pyramide.
func place_de(club: String) -> Array:
	for n in niveaux.size():
		for g in niveaux[n].size():
			if niveaux[n][g].has(club):
				return [n, g]
	return []


## Le nom d'une division : « Division 1 », « Division 2, groupe B ».
static func nom_division(n: int, g: int) -> String:
	return "Division %d" % (n + 1) if n == 0 else "Division %d, groupe %s" % [n + 1, char(65 + g)]


# ---------------------------------------------------------------- le calendrier d'un groupe

## Les quatorze journées d'un groupe : [{dom, ext}] par journée. Un tour complet (méthode du cercle,
## comme le Vestiaire) dans un ordre tiré de la graine de la saison et du groupe, rejoué autant de fois
## qu'il faut pour remplir les quatorze dimanches, en inversant le terrain à chaque tour : à huit clubs,
## c'est l'aller puis le retour ; à deux, les deux se rencontrent quatorze fois, chacun chez soi à son tour.
## Moins de deux clubs : quatorze journées vides.
static func calendrier(s: int, groupe: Array, n: int, g: int) -> Array:
	var out := []
	if groupe.size() < 2:
		for j in JOURNEES:
			out.append([])
		return out
	var h := Hasard.depuis(Hasard.graine("calendrier/%d/%d/%d" % [s, n, g]))
	var equipes := h.melanger(groupe)
	if equipes.size() % 2 == 1:
		equipes.append("")
	var taille := equipes.size()
	var tours := []
	var tour := equipes.duplicate()
	for j in taille - 1:
		var journee := []
		for k in taille / 2:
			var a: String = tour[k]
			var b: String = tour[taille - 1 - k]
			if a == "" or b == "":
				continue
			var inverse := (j % 2 == 1) if k == 0 else (k % 2 == 1)
			journee.append({"dom": b, "ext": a} if inverse else {"dom": a, "ext": b})
		tours.append(journee)
		tour.insert(1, tour.pop_back())
	for j in JOURNEES:
		var cycle: int = j / tours.size()
		var base: Array = tours[j % tours.size()]
		out.append(base.map(func(m): return {"dom": m.ext, "ext": m.dom} if cycle % 2 == 1 else {"dom": m.dom, "ext": m.ext}))
	return out


## Les matchs de la journée j du groupe (n, g) de la saison s, avec leur score s'ils sont joués
## (joues : combien de journées compter ; par défaut celles que le calendrier réel a passées).
func journee(s: int, n: int, g: int, j: int, joues := -1) -> Array:
	if joues < 0:
		joues = journee_jouee() if s == saison else (JOURNEES if s < saison else 0)
	var cal := calendrier(s, niveaux[n][g], n, g)
	var out := []
	for m in cal[j - 1]:
		var r := {"dom": m.dom, "ext": m.ext, "score": []}
		if j <= joues:
			r.score = resultat(s, j, m.dom, m.ext)
		out.append(r)
	return out


## Le classement du groupe (n, g) de la saison s après « joues » journées : [{club, j, g, n, p, bp, bc,
## diff, pts}], le meilleur d'abord (points, différence, buts marqués, puis l'id).
func classement(s: int, n: int, g: int, joues := -1) -> Array:
	if joues < 0:
		joues = journee_jouee() if s == saison else (JOURNEES if s < saison else 0)
	var lignes := {}
	for id in niveaux[n][g]:
		lignes[id] = {"club": id, "j": 0, "g": 0, "n": 0, "p": 0, "bp": 0, "bc": 0, "diff": 0, "pts": 0}
	for j in range(1, joues + 1):
		for m in journee(s, n, g, j, joues):
			var a: int = m.score[0]
			var b: int = m.score[1]
			var d: Dictionary = lignes[m.dom]
			var e: Dictionary = lignes[m.ext]
			d.j += 1
			e.j += 1
			d.bp += a
			d.bc += b
			e.bp += b
			e.bc += a
			if a > b:
				d.g += 1
				e.p += 1
				d.pts += 3
			elif a < b:
				e.g += 1
				d.p += 1
				e.pts += 3
			else:
				d.n += 1
				e.n += 1
				d.pts += 1
				e.pts += 1
	var out: Array = lignes.values()
	for l in out:
		l.diff = l.bp - l.bc
	out.sort_custom(func(x, y):
		if x.pts != y.pts:
			return x.pts > y.pts
		if x.diff != y.diff:
			return x.diff > y.diff
		if x.bp != y.bp:
			return x.bp > y.bp
		return x.club < y.club)
	return out


# ---------------------------------------------------------------- le résultat d'un match

## La force d'un club pour une saison : la note moyenne de ses onze meilleurs joueurs du cru (les paris
## s'en servent pour leurs cotes).
func force(club: String, s: int) -> float:
	var notes: Array = _effectif_cru(club, s).values().map(func(j): return float(j.note))
	if notes.is_empty():
		return 50.0
	notes.sort()
	notes.reverse()
	var onze: Array = notes.slice(0, 11)
	return onze.reduce(func(a, b): return a + b, 0.0) / onze.size()


## L'effectif d'un club pour une saison : {id: {prenom, nom, poste, age, note, condition, moral, competences}},
## les fondateurs vieillis jusqu'à la saison s (les retraités remplacés par des jeunes du cru) et la recrue
## libre de la saison. Avec une journée j, s'y ajoutent les joueurs achetés au marché que le club a ce
## dimanche-là (le crochet renforts).
func effectif(club: String, s: int, j := 0) -> Dictionary:
	var cru := _effectif_cru(club, s)
	if j <= 0 or not renforts.is_valid():
		return cru
	var cle := "%d/%d/%s" % [s, j, club]
	if _effectifs.has(cle):
		return _effectifs[cle]
	var out: Dictionary = cru.duplicate(true)
	for r in renforts.call(s, j, club):
		if r is Dictionary and r.has("id"):
			var copie: Dictionary = (r as Dictionary).duplicate(true)
			copie.erase("id")
			out[str(r.id)] = copie
	_effectifs[cle] = out
	return out


## Un joueur tiré au sort : son nom, sa note autour d'un niveau, ses compétences (d'un tirage à part, pour
## laisser les noms et les notes où ils sont).
func _joueur(h: Hasard, poste: String, age: int, niveau: float, graine: String) -> Dictionary:
	var j := {"prenom": h.choix(PRENOMS), "nom": h.choix(NOMS), "poste": poste, "age": age,
		"note": clampi(int(roundf(h.normal(niveau, 5.0))), 35, 92), "condition": 100, "moral": 70}
	j.competences = FootMatch.tirer_competences(j, Hasard.depuis(Hasard.graine("competences/" + graine)))
	return j


## Les dix-huit fondateurs d'un club, tirés une fois pour toutes de sa graine : les premiers de chaque poste un
## peu au-dessus du niveau du club, les autres un peu en dessous.
func fondateurs(club: String) -> Dictionary:
	var h := Hasard.depuis(Hasard.graine("fondation/" + club))
	var niveau: float = clampf(h.normal(60.0, 6.0), 45.0, 75.0)
	var out := {}
	var n := 0
	for ligne in EFFECTIF:
		var poste: String = ligne[0]
		var titulaires: int = 1 if poste == "G" else (2 if poste == "A" else 4)
		for k in ligne[1]:
			n += 1
			var id := "%s/%d" % [club, n]
			out[id] = _joueur(h, poste, clampi(int(roundf(h.normal(26.0, 4.0))), 17, 33), niveau + (3.0 if k < titulaires else -3.0), "fondation/" + id)
	return out


## Ce que l'âge fait d'une saison à l'autre : les jeunes progressent, les anciens déclinent (le marché a la même).
static func progression(age: int, h: Hasard) -> int:
	if age <= 20:
		return 4 + h.entier(0, 2)
	if age <= 23:
		return 2 + h.entier(0, 1)
	if age <= 28:
		return h.entier(0, 1)
	if age <= 30:
		return -1 - h.entier(0, 1)
	if age <= 32:
		return -3 - h.entier(0, 1)
	return -5 - h.entier(0, 2)


func _effectif_cru(club: String, s: int) -> Dictionary:
	var cle := "%d/%s" % [s, club]
	if _effectifs.has(cle):
		return _effectifs[cle]
	var out := fondateurs(club)
	var n := out.size()
	# Saison après saison depuis la fondation : un an de plus, la progression de l'âge, et la retraite.
	for ss in range(int(clubs.get(club, {}).get("fondation", 1)) + 1, s + 1):
		var h := Hasard.depuis(Hasard.graine("saison/%d/%s" % [ss, club]))
		var moyenne := 0.0
		for id in out:
			moyenne += float(out[id].note)
		moyenne /= maxi(out.size(), 1)
		for id in out.keys():
			var j: Dictionary = out[id]
			j.age = int(j.age) + 1
			if int(j.age) > RETRAITE:
				n += 1
				var nid := "%s/%d" % [club, n]
				out.erase(id)
				out[nid] = _joueur(h, str(j.poste), h.entier(17, 19), moyenne - 8.0, "jeune/%s/%d" % [nid, ss])
				continue
			var d := progression(int(j.age), h)
			j.note = clampi(int(j.note) + d, 30, 95)
			for c in j.competences:
				j.competences[c] = clampi(int(j.competences[c]) + d + h.entier(-1, 1), 10, 99)
	# La recrue du mercato prend la place du plus faible de son poste.
	var r := recrue(s, club)
	if not r.is_empty():
		var sortant := ""
		for id in out:
			if out[id].poste == r.poste and (sortant == "" or int(out[id].note) < int(out[sortant].note)):
				sortant = id
		if sortant != "":
			out.erase(sortant)
		var nid := "%s/libre%d" % [club, int(r.rang)]
		var copie: Dictionary = r.duplicate(true)
		copie.erase("rang")
		copie.erase("prix")
		out[nid] = copie
	_effectifs[cle] = out
	return out


## La saison et la journée du prochain coup d'envoi du championnat : [s, j] (la dernière journée de la
## saison en cours si la suivante n'est pas tirée).
func prochaine_journee() -> Array:
	var pce := prochain_coup_envoi(maintenant())
	return [pce[0], pce[1]] if pce[0] == saison else [saison, JOURNEES]


## Les joueurs d'un club au prochain coup d'envoi (le cru et les renforts du marché), pour le bureau : une
## liste triée gardiens, défenseurs, milieux, attaquants puis par note, chacun avec son id.
func effectif_actuel(club: String) -> Array:
	var pj := prochaine_journee()
	var e := effectif(club, pj[0], pj[1])
	var out: Array = []
	for id in e:
		var j: Dictionary = e[id].duplicate(true)
		j["id"] = id
		out.append(j)
	var ordre := {"G": 0, "D": 1, "M": 2, "A": 3}
	out.sort_custom(func(a, b):
		var pa: int = ordre.get(str(a.poste), 9)
		var pb: int = ordre.get(str(b.poste), 9)
		if pa != pb:
			return pa < pb
		if int(a.note) != int(b.note):
			return int(a.note) > int(b.note)
		return str(a.id) < str(b.id))
	return out


## Un joueur d'un club à une journée, avec son id, ou {} s'il n'y est pas.
func joueur_de(club: String, s: int, j: int, id: String) -> Dictionary:
	var e := effectif(club, s, j)
	if not e.has(id):
		return {}
	var out: Dictionary = e[id].duplicate(true)
	out["id"] = id
	return out


## Le onze que l'adjoint alignerait pour une formation à une journée : les ids, dans l'ordre des cases de
## FootMatch.FORMATIONS[formation]. Et le banc qui va avec un onze.
func compo_auto(club: String, s: int, j: int, formation: String) -> Array:
	var e := effectif(club, s, j)
	return FootMatch.compo_auto(e.keys(), e, formation)


func banc_auto(club: String, s: int, j: int, compo: Array) -> Array:
	var e := effectif(club, s, j)
	return FootMatch.banc_auto(e.keys(), e, compo)


## Oublie les effectifs et les matchs calculés : à appeler quand ce qui les fait (recrues, renforts) a changé.
func oublier_effectifs() -> void:
	_effectifs.clear()
	_matchs.clear()
	change.emit()


# ---------------------------------------------------------------- les statistiques du championnat

## Les buteurs, les passeurs et les clean sheets d'un groupe après « joues » journées : {buteurs: [{id, prenom,
## nom, club, buts, penaltys}], passeurs: [{..., passes}], clean_sheets: [{..., n}]} (le clean sheet va au gardien
## sur la pelouse au coup de sifflet final d'un match sans but encaissé), les meilleurs d'abord.
func statistiques(s: int, n: int, g: int, joues := -1) -> Dictionary:
	if joues < 0:
		joues = journee_jouee() if s == saison else (JOURNEES if s < saison else 0)
	var buteurs := {}
	var passeurs := {}
	var gardiens := {}
	for j in range(1, joues + 1):
		for m in journee(s, n, g, j, joues):
			var etat := rencontre(s, j, m.dom, m.ext)
			for b in etat.buts:
				var club: String = m.dom if int(b.equipe) == 0 else m.ext
				var l := _ligne(buteurs, club, str(b.buteur), s, j, {"buts": 0, "penaltys": 0})
				l.buts += 1
				if bool(b.get("penalty", false)):
					l.penaltys += 1
				if b.passeur != null:
					_ligne(passeurs, club, str(b.passeur), s, j, {"passes": 0}).passes += 1
			for i in 2:
				if int(etat.score[1 - i]) == 0:
					var gid = FootMatch.gardien(etat, i)
					if gid != null:
						_ligne(gardiens, m.dom if i == 0 else m.ext, str(gid), s, j, {"n": 0}).n += 1
	return {"buteurs": _classer(buteurs, "buts"), "passeurs": _classer(passeurs, "passes"), "clean_sheets": _classer(gardiens, "n")}


func _ligne(table: Dictionary, club: String, id: String, s: int, j: int, zero: Dictionary) -> Dictionary:
	if not table.has(id):
		var joueur: Dictionary = effectif(club, s, j).get(id, {})
		var l := {"id": id, "prenom": str(joueur.get("prenom", "")), "nom": str(joueur.get("nom", id)), "club": club}
		l.merge(zero)
		table[id] = l
	return table[id]


static func _classer(table: Dictionary, cle: String) -> Array:
	var out: Array = table.values()
	out.sort_custom(func(a, b):
		if int(a[cle]) != int(b[cle]):
			return int(a[cle]) > int(b[cle])
		return str(a.nom) + str(a.id) < str(b.nom) + str(b.id))
	return out


# ---------------------------------------------------------------- le mercato

## Les joueurs libres d'une saison, les mêmes chez tout le monde : [{rang, prenom, nom, poste, age, note,
## condition, moral, competences, prix}], douze, deux gardiens, quatre défenseurs, quatre milieux, deux attaquants.
func libres(s: int) -> Array:
	var h := Hasard.depuis(Hasard.graine("libres/%d" % s))
	var out: Array = []
	for ligne in LIBRES:
		for k in ligne[1]:
			var j := {"rang": out.size(), "prenom": h.choix(PRENOMS), "nom": h.choix(NOMS), "poste": ligne[0],
				"age": clampi(int(roundf(h.normal(27.0, 4.0))), 18, 34), "note": clampi(int(roundf(h.normal(62.0, 9.0))), 45, 88),
				"condition": 100, "moral": 70}
			j.competences = FootMatch.tirer_competences(j, Hasard.depuis(Hasard.graine("competences/libres/%d/%d" % [s, out.size()])))
			j.prix = prix_de(int(j.note))
			out.append(j)
	return out


## Ce que coûte une recrue d'après sa note : 1 200 à 60, 3 680 à 75, 6 080 à 85.
static func prix_de(note: int) -> int:
	return int(round(pow(maxi(note - 40, 5), 2) * 3.0 / 10.0)) * 10


## Le mercato d'une saison est ouvert la semaine qui précède sa première journée.
func mercato_ouvert(s: int) -> bool:
	return s == saison and periode() == "mercato"


## Le prochain mercato : le début de celui de la saison s si on est avant, sinon celui de la suivante.
func prochain_mercato() -> int:
	var t := maintenant()
	var s := saison
	while coup_envoi(s, 1) - 7 * 86400 <= t:
		s += 1
	return coup_envoi(s, 1) - 7 * 86400


## La recrue d'un club pour une saison, ou {} : le joueur libre, avec son rang.
func recrue(s: int, club: String) -> Dictionary:
	var t: Dictionary = transferts.get("%d/%s" % [s, club], {})
	if t.is_empty():
		return {}
	var l := libres(s)
	var rang := int(t.get("joueur", -1))
	return l[rang] if rang >= 0 and rang < l.size() else {}


## Quel club a pris ce joueur libre cette saison, ou « ».
func preneur(s: int, rang: int) -> String:
	for cle in transferts:
		var p: PackedStringArray = str(cle).split("/")
		if int(p[0]) == s and int(transferts[cle].get("joueur", -1)) == rang:
			return p[1]
	return ""


## La recrue d'un club et d'où elle vient : {etat: aucune|locale|commune, par, joueur}.
func transfert_de(s: int, club: String) -> Dictionary:
	var cle := "%d/%s" % [s, club]
	if not transferts.has(cle):
		return {"etat": "aucune", "par": "", "joueur": {}}
	return {"etat": "locale" if transferts_locaux.has(cle) else "commune", "par": str(transferts[cle].get("par", "")), "joueur": recrue(s, club)}


## Recrute un joueur libre pour un club : une recrue par club et par saison, pendant le mercato, par celui
## qui parle pour le club ; un libre ne part qu'une fois. {ok} ou {ok: false, raison: ferme|parts|deja|pris|inconnu}.
func recruter(s: int, club: String, rang: int) -> Dictionary:
	if not mercato_ouvert(s):
		return {"ok": false, "raison": "ferme"}
	if not peut_decider(club):
		return {"ok": false, "raison": "parts"}
	var cle := "%d/%s" % [s, club]
	if transferts.has(cle):
		return {"ok": false, "raison": "deja"}
	if rang < 0 or rang >= libres(s).size():
		return {"ok": false, "raison": "inconnu"}
	if preneur(s, rang) != "":
		return {"ok": false, "raison": "pris"}
	transferts[cle] = {"joueur": rang, "par": ""}
	transferts_locaux[cle] = true
	_effectifs = {}
	_matchs = {}
	sauver()
	change.emit()
	envoyer_transferts()
	return {"ok": true}


## Les recrues lues au serveur : [{saison, club, joueur, par}] ; elles l'emportent sur celles d'ici.
func appliquer_transferts(liste: Array) -> bool:
	var bouge := false
	var vus := {}
	for t in liste:
		if not t is Dictionary or not t.has("club"):
			continue
		var cle := "%d/%s" % [int(t.get("saison", 0)), str(t.club)]
		vus[cle] = true
		var d := {"joueur": int(t.get("joueur", -1)), "par": str(t.get("par", ""))}
		if transferts.get(cle) != d or transferts_locaux.has(cle):
			bouge = true
		transferts[cle] = d
		transferts_locaux.erase(cle)
	if bouge:
		_effectifs = {}
		_matchs = {}
		sauver()
		change.emit()
	return bouge


func lire_transferts() -> void:
	var compte := _compte()
	if compte == null or get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()):
		return
	var r: Dictionary = await compte.appeler("smarves_transferts", {})
	if r.code == 200 and r.corps is Array:
		appliquer_transferts(r.corps)
		envoyer_transferts()


## Envoie au serveur les recrues d'ici ; refusée (mercato fermé, un autre a parlé, le joueur est pris), une
## recrue locale est retirée : elle n'a compté pour personne.
func envoyer_transferts() -> void:
	var compte := _compte()
	if compte == null or not compte.connecte() or get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()):
		return
	for cle in transferts_locaux.keys():
		var p: PackedStringArray = str(cle).split("/")
		var r: Dictionary = await compte.appeler("smarves_transfert_recruter", {"p_saison": int(p[0]), "p_club": p[1], "p_joueur": int(transferts.get(cle, {}).get("joueur", -1))})
		if r.code == 200 and r.corps is Dictionary:
			if r.corps.get("ok", false):
				transferts_locaux.erase(cle)
				transferts[cle].par = compte.nom
			elif r.corps.has("raison"):
				transferts_locaux.erase(cle)
				transferts.erase(cle)
				_effectifs = {}
				_matchs = {}
			sauver()
			change.emit()


## La rencontre de la journée j de la saison s, jouée d'une traite minute par minute (FootMatch) et gardé en
## mémoire : la graine ne dépend que de la saison, de la journée, des deux clubs et des décisions prises
## avant le coup d'envoi (decider), donc tout le monde voit le même match.
func rencontre(s: int, j: int, dom: String, ext: String) -> Dictionary:
	var cle := "match/%d/%d/%s/%s" % [s, j, dom, ext]
	for c in [dom, ext]:
		var d: Dictionary = decisions.get("%d/%d/%s" % [s, j, c], {})
		if not d.is_empty():
			cle += "|%s:%s" % [c, JSON.stringify(d)]
	if _matchs.has(cle):
		return _matchs[cle]
	var direct := rencontre_en_direct(s, j, dom, ext)
	FootMatch.simuler(direct.etat, direct.joueurs, direct.hasard)
	_matchs[cle] = direct.etat
	return direct.etat


## Le même match, prêt pour le coup d'envoi et pas encore joué : {etat, joueurs, hasard}. Le stade le fait
## avancer minute par minute (FootMatch.avancer) et retombe sur le score de rencontre().
func rencontre_en_direct(s: int, j: int, dom: String, ext: String) -> Dictionary:
	var cle := "match/%d/%d/%s/%s" % [s, j, dom, ext]
	for c in [dom, ext]:
		var d: Dictionary = decisions.get("%d/%d/%s" % [s, j, c], {})
		if not d.is_empty():
			cle += "|%s:%s" % [c, JSON.stringify(d)]
	var joueurs := {}
	joueurs.merge(effectif(dom, s, j))
	joueurs.merge(effectif(ext, s, j))
	var h := Hasard.depuis(Hasard.graine(cle))
	return {"etat": FootMatch.creer(_equipe(s, j, dom, joueurs), _equipe(s, j, ext, joueurs), joueurs, h), "joueurs": joueurs, "hasard": h}


## Ce que FootMatch attend d'un club : son identité, sa tactique du jour (les décisions : formation, mentalité,
## pressing, et s'ils sont donnés le onze, le banc et les rôles) et son effectif. Un joueur de la consigne qui
## n'est plus là au coup d'envoi (vendu) laisse sa case à l'adjoint, qui la comble avec le meilleur restant.
func _equipe(s: int, j: int, club: String, joueurs: Dictionary) -> Dictionary:
	var c: Dictionary = clubs[club]
	var d: Dictionary = decisions.get("%d/%d/%s" % [s, j, club], {})
	var ids: Array = joueurs.keys().filter(func(id): return str(id).begins_with(club + "/"))
	var formation: String = str(d.get("formation", "4-4-2")) if FootMatch.FORMATIONS.has(str(d.get("formation", ""))) else "4-4-2"
	var out := {"id": club, "nom": c.nom, "court": c.court, "stade": str(c.get("stade", "le stade %s" % _de(c.nom))),
		"formation": formation,
		"mentalite": str(d.get("mentalite", "equilibree")) if FootMatch.MENTALITES.has(str(d.get("mentalite", ""))) else "equilibree",
		"pressing": str(d.get("pressing", "normal")) if FootMatch.PRESSINGS.has(str(d.get("pressing", ""))) else "normal",
		"effectif": ids}
	var voulu: Array = d.get("compo", [])
	if voulu is Array and voulu.any(func(x): return str(x) != "" and ids.has(str(x))):
		out["compo"] = FootMatch.compo_auto(ids, joueurs, formation, voulu.map(func(x): return str(x) if ids.has(str(x)) else null))
	var banc: Array = d.get("banc", [])
	if banc is Array and not banc.is_empty():
		var sur_le_terrain: Array = out.get("compo", FootMatch.compo_auto(ids, joueurs, formation))
		out["banc"] = FootMatch.banc_auto(ids, joueurs, sur_le_terrain, 7, banc.map(func(x): return str(x)).filter(func(x): return ids.has(x) and not sur_le_terrain.has(x)))
	var roles: Dictionary = d.get("roles", {})
	if roles is Dictionary and not roles.is_empty():
		var propres := {}
		for id in roles:
			if ids.has(str(id)) and ROLES.has(str(roles[id])):
				propres[str(id)] = str(roles[id])
		if not propres.is_empty():
			out["roles"] = propres
	return out


## « de l'Étoile », « d'Avenir », « de Jeunesse »…
static func _de(nom: String) -> String:
	return ("d'%s" if nom.left(1).to_lower() in ["a", "e", "i", "o", "u", "y", "é", "h"] else "de %s") % nom


## Le score d'un match, le même pour tout le monde : celui du match joué minute par minute.
func resultat(s: int, j: int, dom: String, ext: String) -> Array:
	return (rencontre(s, j, dom, ext).score as Array).duplicate()


## Une consigne prise avant un match (la tactique du dimanche) ; sans effet sur un match déjà joué.
## Elle vaut tout de suite ici, et part au serveur si le joueur est connecté ; sinon elle reste locale.
func decider(s: int, j: int, club: String, d: Dictionary) -> bool:
	if s < saison or (s == saison and j <= journee_jouee()) or not peut_decider(club):
		return false
	var cle := "%d/%d/%s" % [s, j, club]
	decisions[cle] = consigne(d)
	locales[cle] = true
	auteurs.erase(cle)
	sauver()
	change.emit()
	envoyer_locales()
	return true


## Une consigne propre : les trois clés de la tactique, dans le même ordre partout, les valeurs inconnues ramenées
## au défaut ; puis, seulement s'ils disent quelque chose, compo (onze cases, « » pour une case laissée à
## l'adjoint), banc (jusqu'à sept ids) et roles (id -> rôle, les clés triées, « normal » omis). Une consigne
## sans eux reste la consigne d'avant, mot pour mot : la graine des matchs déjà joués ne bouge pas.
static func consigne(d: Dictionary) -> Dictionary:
	var out := {"formation": str(d.get("formation", "")) if FootMatch.FORMATIONS.has(str(d.get("formation", ""))) else "4-4-2",
		"mentalite": str(d.get("mentalite", "")) if FootMatch.MENTALITES.has(str(d.get("mentalite", ""))) else "equilibree",
		"pressing": str(d.get("pressing", "")) if FootMatch.PRESSINGS.has(str(d.get("pressing", ""))) else "normal"}
	var compo: Array = []
	var source = d.get("compo", [])
	if source is Array:
		for i in 11:
			var x = source[i] if i < source.size() else null
			compo.append("" if x == null else str(x))
	if compo.any(func(x): return x != ""):
		out["compo"] = compo
	var banc: Array = []
	source = d.get("banc", [])
	if source is Array:
		for x in source:
			if x != null and str(x) != "" and not banc.has(str(x)) and banc.size() < 7:
				banc.append(str(x))
	if not banc.is_empty():
		out["banc"] = banc
	var roles := {}
	source = d.get("roles", {})
	if source is Dictionary:
		var cles: Array = source.keys().map(func(k): return str(k))
		cles.sort()
		for k in cles:
			var r := str(source.get(k, source.get(StringName(k), "")))
			if ROLES.has(r) and r != ROLE_DEFAUT:
				roles[k] = r
	if not roles.is_empty():
		out["roles"] = roles
	return out


## La consigne d'un club pour une journée, et d'où elle vient : {consigne, etat, par}, etat « aucune »,
## « locale » (sur cet appareil seulement) ou « commune » (au serveur, par le joueur nommé). La consigne
## porte compo, banc et roles seulement s'ils ont été donnés (consigne()).
func consigne_de(s: int, j: int, club: String) -> Dictionary:
	var cle := "%d/%d/%s" % [s, j, club]
	if not decisions.has(cle):
		return {"consigne": consigne({}), "etat": "aucune", "par": ""}
	return {"consigne": decisions[cle], "etat": "locale" if locales.has(cle) else "commune", "par": str(auteurs.get(cle, ""))}


## Le prochain match d'un club : {s, j, dom, ext, quand}, ou {} si la saison qui vient n'est pas tirée.
func prochain_match(club: String) -> Dictionary:
	var pce := prochain_coup_envoi(maintenant())
	var s: int = pce[0]
	var j: int = pce[1]
	if s != saison:
		return {}
	var place := place_de(club)
	if place.is_empty():
		return {}
	for m in journee(s, place[0], place[1], j, 0):
		if m.dom == club or m.ext == club:
			return {"s": s, "j": j, "dom": m.dom, "ext": m.ext, "quand": pce[2]}
	return {}


## Les consignes lues au serveur : elles l'emportent sur celles d'ici, et une consigne locale que le
## serveur porte aussi cesse d'être locale. Vrai si quelque chose a changé.
func appliquer_consignes(liste: Array) -> bool:
	var bouge := false
	for c in liste:
		if not c is Dictionary or not c.has("club"):
			continue
		var cle := "%d/%d/%s" % [int(c.get("saison", 0)), int(c.get("journee", 0)), str(c.club)]
		# Le détail (compo, banc, roles) voyage dans une colonne à part du serveur.
		var source: Dictionary = (c as Dictionary).duplicate()
		if c.get("detail") is Dictionary:
			source.merge(c.detail, true)
		var d := consigne(source)
		if decisions.get(cle) != d or locales.has(cle):
			bouge = true
		decisions[cle] = d
		locales.erase(cle)
		auteurs[cle] = str(c.get("par", ""))
	if bouge:
		sauver()
		change.emit()
	return bouge


## Relit toutes les consignes au serveur (sans compte aussi), puis envoie celles d'ici qui manquent.
func lire_consignes() -> void:
	var compte := _compte()
	if compte == null or consignes_etat == "lecture" or get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()):
		return
	consignes_etat = "lecture"
	var r: Dictionary = await compte.appeler("smarves_consignes", {})
	if r.code == 200 and r.corps is Array:
		consignes_etat = "ok"
		appliquer_consignes(r.corps)
		envoyer_locales()
	else:
		consignes_etat = "hors_ligne"


## Envoie au serveur les consignes locales encore à venir ; celles dont le match est passé sont retirées
## (le serveur ne les a pas : elles n'ont compté pour personne).
func envoyer_locales() -> void:
	var compte := _compte()
	if compte == null or not compte.connecte() or get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()):
		return
	for cle in locales.keys():
		var p: PackedStringArray = str(cle).split("/")
		var d: Dictionary = decisions.get(cle, {})
		var corps := {"p_saison": int(p[0]), "p_journee": int(p[1]), "p_club": p[2],
			"p_formation": d.get("formation", "4-4-2"), "p_mentalite": d.get("mentalite", "equilibree"), "p_pressing": d.get("pressing", "normal")}
		var detail := {}
		for k in ["compo", "banc", "roles"]:
			if d.has(k):
				detail[k] = d[k]
		if not detail.is_empty():
			corps["p_detail"] = detail
		var r: Dictionary = await compte.appeler("smarves_consigne_poser", corps)
		if r.code == 200 and r.corps is Dictionary:
			if r.corps.get("ok", false):
				locales.erase(cle)
				auteurs[cle] = compte.nom
			elif r.corps.get("raison", "") in ["joue", "parts"]:
				# Match passé, ou un autre actionnaire parle pour le club : la consigne d'ici n'a compté pour personne.
				locales.erase(cle)
				decisions.erase(cle)
			sauver()
			change.emit()


# ---------------------------------------------------------------- les obligations du club

## La valeur d'une obligation, par son rang (1 à 9).
static func valeur(rang: int) -> int:
	return int(OBLIGATIONS[clampi(rang, 1, OBLIGATIONS.size()) - 1])


## Ce qu'une obligation verse à chaque journée jouée, avant le classement : 50 crédits par cran.
static func dividende_de(rang: int) -> int:
	return rang * DIVIDENDE


## Les obligations d'un club qu'on tient sur cet appareil, les plus grosses d'abord.
func mes_obligations(club: String) -> Array:
	var out: Array = []
	for r in obligations_locales.get(club, []):
		out.append(int(r))
	out.sort()
	out.reverse()
	return out


## Qui tient une obligation : {nom, moi}, ou {} si elle est libre. Les siennes viennent d'ici, celles des
## autres du serveur.
func porteur(club: String, rang: int) -> Dictionary:
	if mes_obligations(club).has(rang):
		return {"nom": "vous", "moi": true}
	var p: Dictionary = (obligations.get(club, {}) as Dictionary).get(str(rang), {})
	if p is Dictionary and not p.is_empty() and not bool(p.get("moi", false)):
		return {"nom": str(p.get("par", "")), "moi": false}
	return {}


## Les porteurs d'un club, la plus grosse somme d'abord : [{nom, investi, rangs, moi}]. À égalité, soi d'abord.
func actionnaires(club: String) -> Array:
	var par_nom := {}
	for r in OBLIGATIONS.size():
		var p := porteur(club, r + 1)
		if p.is_empty():
			continue
		if not par_nom.has(p.nom):
			par_nom[p.nom] = {"nom": p.nom, "investi": 0, "rangs": [], "moi": bool(p.moi)}
		par_nom[p.nom].investi += valeur(r + 1)
		par_nom[p.nom].rangs.append(r + 1)
	var out: Array = par_nom.values()
	out.sort_custom(func(x, y):
		if x.investi != y.investi:
			return x.investi > y.investi
		return x.moi and not y.moi)
	return out


## Ce qu'on a investi dans un club, d'ici.
func investi(club: String) -> int:
	var t := 0
	for r in mes_obligations(club):
		t += valeur(r)
	return t


## Qui parle pour un club au bureau : sans porteur, tout le monde ; sinon la plus grosse somme investie,
## et chacun à égalité.
func peut_decider(club: String) -> bool:
	var a := actionnaires(club)
	if a.is_empty():
		return true
	return investi(club) >= int(a[0].investi)


## Une phrase pour le notaire, le président et le bureau : qui a mis combien, et qui parle.
func phrase_actionnaires(club: String) -> String:
	var a := actionnaires(club)
	if a.is_empty():
		return "Personne ne tient d'obligation du club : le président écoute tout le monde."
	var morceaux: Array = []
	for x in a:
		if morceaux.is_empty():
			morceaux.append("%s %s %s crédits dans le club" % ["Vous" if x.moi else x.nom, "avez" if x.moi else "a", Game.fmt(int(x.investi))])
		else:
			morceaux.append("%s %s" % ["vous" if x.moi else x.nom, Game.fmt(int(x.investi))])
	var qui := "c'est vous qui parlez au président" if peut_decider(club) else "c'est %s qui parle au président" % a[0].nom
	return "%s : %s." % [", ".join(morceaux), qui]


## Ce que le classement fait au dividende : ×1,4 en tête, ×0,7 en queue (et entre les deux au prorata, quelle
## que soit la taille du groupe), ×1 tant que rien n'est joué ou qu'on est seul.
func recette_facteur(club: String) -> float:
	var place := place_de(club)
	if place.is_empty() or journee_jouee() <= 0:
		return 1.0
	var cl := classement(saison, place[0], place[1])
	if cl.size() < 2:
		return 1.0
	for i in cl.size():
		if cl[i].club == club:
			return 0.7 + 0.7 * float(cl.size() - 1 - i) / float(cl.size() - 1)
	return 1.0


## Prend une obligation libre, de ses crédits : {ok: true} ou {ok: false, raison} « rang », « prise »,
## « credits ». Elle vaut tout de suite ici et part au serveur, qui a le dernier mot (envoyer_obligations).
func prendre(club: String, rang: int) -> Dictionary:
	if rang < 1 or rang > OBLIGATIONS.size() or not clubs.has(club):
		return {"ok": false, "raison": "rang"}
	if not porteur(club, rang).is_empty():
		return {"ok": false, "raison": "prise"}
	if Game.credits < valeur(rang):
		return {"ok": false, "raison": "credits"}
	Game.credits -= valeur(rang)
	_poser(club, rang, true)
	Game.changed.emit()
	return {"ok": true}


## Rend une obligation à l'étude, qui la reprend à RACHAT : {ok: true, montant} ou {ok: false, raison: « absente »}.
func rendre(club: String, rang: int) -> Dictionary:
	if not mes_obligations(club).has(rang):
		return {"ok": false, "raison": "absente"}
	var montant := int(round(valeur(rang) * RACHAT))
	Game.credits += montant
	_poser(club, rang, false)
	Game.changed.emit()
	return {"ok": true, "montant": montant}


## Échange une de ses obligations contre une plus grosse, libre, en payant la différence (comme à Impérial) :
## {ok: true, montant} ou {ok: false, raison} « absente », « rang », « prise », « credits ».
func echanger(club: String, bas: int, haut: int) -> Dictionary:
	if not mes_obligations(club).has(bas):
		return {"ok": false, "raison": "absente"}
	if haut <= bas or haut > OBLIGATIONS.size():
		return {"ok": false, "raison": "rang"}
	if not porteur(club, haut).is_empty():
		return {"ok": false, "raison": "prise"}
	var montant := valeur(haut) - valeur(bas)
	if Game.credits < montant:
		return {"ok": false, "raison": "credits"}
	Game.credits -= montant
	_poser(club, bas, false)
	_poser(club, haut, true)
	Game.changed.emit()
	return {"ok": true, "montant": montant}


func _poser(club: String, rang: int, prise: bool) -> void:
	var miennes: Array = obligations_locales.get(club, [])
	if prise:
		if not miennes.has(rang):
			miennes.append(rang)
		if not dividendes.has(club):
			# Les dividendes courent à partir de maintenant, pas sur les journées déjà jouées.
			dividendes[club] = {"s": saison, "j": journee_jouee()}
	else:
		miennes.erase(rang)
	if miennes.is_empty():
		obligations_locales.erase(club)
	else:
		obligations_locales[club] = miennes
	if not obligations_a_declarer.has(club):
		obligations_a_declarer[club] = {}
	obligations_a_declarer[club][str(rang)] = prise
	sauver()
	change.emit()
	envoyer_obligations()


## Les dividendes que les journées jouées depuis le dernier versement doivent à ce qu'on tient :
## [{club, s, j, brut, salaires, net}], par journée. Le brut suit le classement (recette_facteur) ; les
## salaires du module mercato se retiennent au prorata de ce qu'on a investi.
func dividendes_dus() -> Array:
	var out: Array = []
	for club in obligations_locales.keys():
		var rangs := mes_obligations(club)
		if rangs.is_empty():
			continue
		var marque: Dictionary = dividendes.get(club, {"s": saison, "j": journee_jouee()})
		var depuis: int = int(marque.j) if int(marque.s) == saison else 0
		if int(marque.s) > saison:
			continue
		var brut_journee := 0
		for r in rangs:
			brut_journee += dividende_de(r)
		var total := 0
		for a in actionnaires(club):
			total += int(a.investi)
		var part_salaires := 0
		if salaires.is_valid() and total > 0:
			part_salaires = int(round(float(salaires.call(club)) * float(investi(club)) / float(total)))
		for j in range(depuis + 1, journee_jouee() + 1):
			var brut := int(round(brut_journee * recette_facteur(club)))
			out.append({"club": club, "s": saison, "j": j, "brut": brut, "salaires": part_salaires, "net": brut - part_salaires})
	return out


## Verse les dividendes dus dans la bourse, et s'en souvient ; renvoie ce qui a été versé.
func verser_dividendes() -> Array:
	var dus := dividendes_dus()
	if dus.is_empty():
		return dus
	var net := 0
	for d in dus:
		net += int(d.net)
		dividendes[d.club] = {"s": int(d.s), "j": int(d.j)}
	Game.credits += net
	dividendes_total += net
	sauver()
	Game.changed.emit()
	change.emit()
	return dus


## Verse les dividendes dus et l'annonce par la fiche du carnet, un mot par club.
func tic() -> void:
	var verses := verser_dividendes()
	if verses.is_empty():
		return
	var carnet: Node = get_tree().root.get_node_or_null("Carnet")
	if carnet == null:
		return
	var par_club := {}
	for d in verses:
		par_club[d.club] = int(par_club.get(d.club, 0)) + int(d.net)
	for club in par_club:
		var nom := str(clubs.get(club, {}).get("nom", club))
		carnet.show_slip("%s : dividende de la journée %d, %s crédits." % [nom, int(verses[-1].j), Game.fmt(int(par_club[club]))] if par_club.size() == 1 and verses.size() == 1 \
			else "%s : %s crédits de dividendes." % [nom, Game.fmt(int(par_club[club]))])


## Des porteurs forcés pour une capture : « vous:3+1,Lucien:5 » (les rangs des obligations).
func forcer_porteurs(spec: String, club: String) -> void:
	var autres := {}
	obligations_locales.erase(club)
	for morceau in spec.split(","):
		var kv := morceau.split(":")
		if kv.size() != 2:
			continue
		for r in kv[1].split("+"):
			if kv[0] == "vous":
				obligations_locales[club] = obligations_locales.get(club, []) + [int(r)]
			else:
				autres[str(int(r))] = {"par": kv[0], "moi": false}
	obligations[club] = autres


## Les obligations lues au serveur : [{club, rang, par, moi}] ; remplacent ce qu'on en savait. Le serveur a
## le dernier mot : une obligation qu'il dit à un autre, ou à personne, alors qu'elle était prise ici et déjà
## déclarée, est rendue à sa valeur ; une qu'il nous donne et qu'on n'a pas ici (un autre appareil) arrive.
func appliquer_obligations(liste: Array) -> void:
	obligations = {}
	for p in liste:
		if p is Dictionary and p.has("club") and p.has("rang"):
			if not obligations.has(p.club):
				obligations[p.club] = {}
			obligations[p.club][str(int(p.rang))] = {"par": str(p.get("par", "")), "moi": bool(p.get("moi", false))}
	for club in obligations.keys():
		for r in obligations[club]:
			if bool(obligations[club][r].moi) and not mes_obligations(club).has(int(r)) and not (obligations_a_declarer.get(club, {}) as Dictionary).has(str(r)):
				var miennes: Array = obligations_locales.get(club, [])
				miennes.append(int(r))
				obligations_locales[club] = miennes
				if not dividendes.has(club):
					dividendes[club] = {"s": saison, "j": journee_jouee()}
	for club in obligations_locales.keys():
		for r in mes_obligations(club):
			var p: Dictionary = (obligations.get(club, {}) as Dictionary).get(str(r), {})
			if not (obligations_a_declarer.get(club, {}) as Dictionary).has(str(r)) and not bool(p.get("moi", false)):
				obligations_locales[club].erase(r)
				if obligations_locales[club].is_empty():
					obligations_locales.erase(club)
				Game.credits += valeur(r)
	sauver()
	change.emit()


## Relit les obligations de tous les clubs au serveur (sans compte aussi : elles sont publiques), puis
## déclare celles d'ici qui manquent.
func lire_obligations() -> void:
	var compte := _compte()
	if compte == null or get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()):
		return
	var r: Dictionary = await compte.appeler("smarves_obligations", {})
	if r.code == 200 and r.corps is Array:
		appliquer_obligations(r.corps)
		envoyer_obligations()


## Dit au serveur les obligations prises et rendues ici qu'il ne sait pas encore. Une prise qu'il refuse
## (« prise » : un autre l'a eue avant) est rendue à sa valeur.
func envoyer_obligations() -> void:
	var compte := _compte()
	if compte == null or not compte.connecte() or get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()):
		return
	for club in obligations_a_declarer.keys():
		for rang in (obligations_a_declarer[club] as Dictionary).keys():
			var prise: bool = obligations_a_declarer[club][rang]
			var r: Dictionary = await compte.appeler("smarves_obligation_prendre" if prise else "smarves_obligation_rendre", {"p_club": club, "p_rang": int(rang)})
			if r.code != 200 or not (r.corps is Dictionary):
				continue
			var fini: bool = bool(r.corps.get("ok", false)) or str(r.corps.get("raison", "")) in ["prise", "absente"]
			if prise and not bool(r.corps.get("ok", false)) and str(r.corps.get("raison", "")) == "prise":
				var miennes: Array = obligations_locales.get(club, [])
				miennes.erase(int(rang))
				if miennes.is_empty():
					obligations_locales.erase(club)
				Game.credits += valeur(int(rang))
				Game.changed.emit()
			if fini:
				obligations_a_declarer[club].erase(rang)
				if obligations_a_declarer[club].is_empty():
					obligations_a_declarer.erase(club)
				sauver()
				change.emit()
	lire_obligations()


func _compte() -> Node:
	return get_node_or_null("/root/Compte")


# ---------------------------------------------------------------- la sauvegarde

func charger() -> void:
	if dossier == "":
		return
	var lu = Portail.lire_json(dossier.path_join(FICHIER))
	if lu is Dictionary and lu.has("niveaux") and lu.has("clubs"):
		saison = int(lu.get("saison", 1))
		niveaux = lu.niveaux
		clubs = lu.clubs
		# Les clubs invités des sauvegardes d'avant le 18 octobre 2026 s'en vont : seuls les inscrits jouent.
		for id in clubs.keys():
			if bool(clubs[id].get("invite", false)):
				clubs.erase(id)
			else:
				clubs[id].erase("invite")
				if not clubs[id].has("fondation"):
					clubs[id].fondation = 1
		for n in niveaux.size():
			for g in niveaux[n].size():
				niveaux[n][g] = (niveaux[n][g] as Array).filter(func(id): return clubs.has(id))
		historique = lu.get("historique", [])
		decisions = lu.get("decisions", {})
		locales = lu.get("locales", {})
		auteurs = lu.get("auteurs", {})
		obligations = lu.get("obligations", {})
		obligations_locales = lu.get("obligations_locales", {})
		obligations_a_declarer = lu.get("obligations_a_declarer", {})
		dividendes = lu.get("dividendes", {})
		dividendes_total = int(lu.get("dividendes_total", 0))
		transferts = lu.get("transferts", {})
		transferts_locaux = lu.get("transferts_locaux", {})


func sauver() -> void:
	if dossier == "":
		return
	Portail.ecrire(dossier.path_join(FICHIER), JSON.stringify({"saison": saison, "niveaux": niveaux, "clubs": clubs, "historique": historique, "decisions": decisions, "locales": locales, "auteurs": auteurs,
		"obligations": obligations, "obligations_locales": obligations_locales, "obligations_a_declarer": obligations_a_declarer,
		"dividendes": dividendes, "dividendes_total": dividendes_total,
		"transferts": transferts, "transferts_locaux": transferts_locaux}))


## Repart de rien (essais, nouvelle partie) : la pyramide se refonde au prochain actualiser().
func effacer() -> void:
	saison = 1
	niveaux = []
	clubs = {}
	historique = []
	decisions = {}
	locales = {}
	auteurs = {}
	obligations = {}
	obligations_locales = {}
	obligations_a_declarer = {}
	dividendes = {}
	dividendes_total = 0
	transferts = {}
	transferts_locaux = {}
	_matchs = {}
	_effectifs = {}
	if dossier != "":
		DirAccess.remove_absolute(dossier.path_join(FICHIER))
