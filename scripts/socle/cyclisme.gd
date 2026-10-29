extends Node
## Les courses cyclistes des communes (autoload « Cyclisme », socle 1.28) : une activité transverse sur le
## modèle de docs/ACTIVITES.md. Une commune déclare sa course (structure « course_velo ») : un parcours, une
## suite de repères de sa scène, sa longueur, le nombre de tours, le relief, le jour et l'heure du départ.
## Le socle fait le reste, pour toutes les communes à la fois :
##
## - le rendez-vous : chaque semaine au jour et à l'heure de la course, au vrai calendrier (Agenda) ;
## - les coureurs : un peloton tiré de la graine de la course et de l'année (prénom, nom, grimpeur, rouleur,
##   sprinteur, régularité), le même chez tout le monde ;
## - le résultat commun : chaque édition se rejoue à l'identique d'une graine (la forme du jour, les écarts
##   de chaque tour, une crevaison, un abandon, le sprint du peloton), sans serveur ;
## - le direct : la position de chaque coureur à chaque seconde (position), que Peloton pose sur le parcours
##   de la scène, et l'état de la course pour le bandeau (en_direct) ;
## - les paris à places : gagnant ou placé (dans les trois premiers), à cote fixe, la marge de la maison
##   déduite, la mise libre ; le ticket se règle dix minutes après l'arrivée, où que soit le joueur ;
## - la fiche : le classement de la dernière édition, les écarts et les abandons (CoursePanel).
##
## Les heures sont des « secondes locales », celles du football (Football.maintenant) : un essai règle les deux
## d'un coup. Les tickets restent sur l'appareil, comme ceux du comptoir de Josiane.

signal change

## La vitesse moyenne d'une course, en mètres par seconde (40 km/h) : elle donne la durée d'une édition.
const VITESSE := 11.1
## Ce que la maison garde sur chaque cote, comme au comptoir du football.
const MARGE := 0.12
const MISES := [10, 20, 50, 100, 200]
const MISE_MIN := 1
## Le règlement des tickets, après l'arrivée du dernier coureur.
const REGLEMENT := 600
## Les reliefs et le poids de chaque qualité (grimpeur, rouleur, sprinteur) dans la force d'un coureur.
const RELIEFS := {"plat": [0.15, 0.45, 0.4], "vallonne": [0.35, 0.4, 0.25], "montagne": [0.6, 0.3, 0.1]}
const RELIEFS_DITS := {"plat": "plat", "vallonne": "vallonné", "montagne": "de montagne"}
const JOURS := ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
## Ce que la structure prend quand elle ne le dit pas.
const DEFAUTS := {"tours": 1, "relief": "vallonne", "jour": "samedi", "heure": 15.0, "coureurs": 12}
## Les bornes des champs de la structure (Structures.verifier).
const COUREURS := [6, 16]
const TOURS := [1, 30]
const DISTANCE := [200.0, 100000.0]
const HEURES := [6.0, 22.0]
## La couleur des maillots, par numéro de dossard.
const MAILLOTS := ["#c8322b", "#1f4fa8", "#e8c33a", "#2e7d4f", "#f2f0ea", "#1d1d22", "#e07a2e", "#7a3fa0",
	"#4fb3d9", "#a3263f", "#8bb040", "#d86fa6", "#3b5b2a", "#c9a46a", "#5d6670", "#23807f"]
const FICHIER := "cyclisme.json"
## Le moteur : l'amplitude de la forme du jour (en points de force), ce qu'un point de force retire au temps
## d'un tour, l'aléa d'un tour (pour un coureur irrégulier), et combien de fois le pronostic rejoue la course.
const FORME := 14.0
const POIDS_FORCE := 0.0025
const ALEA := 0.05
const PRONOSTICS := 300

## Les tickets, du plus ancien au plus récent : {cle, commune, course, depart, num, genre (« gagnant »,
## « place »), mise, cote, etat (« ouvert », « gagne », « perdu »), gain, quand, vu}.
var tickets: Array = []
var total_mise := 0
var total_gagne := 0
## Où lire et écrire ; un test le déplace. « » : rien n'est écrit.
var dossier := Communes.GREFFES
var _resultats := {}
var _chances := {}


func _ready() -> void:
	var agenda := get_node_or_null("/root/Agenda")
	if agenda != null:
		agenda.inscrire("cyclisme", rendez_vous)
	if get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()):
		return
	charger()
	# Une nouvelle partie (le total misé retombe) emporte les tickets avec le reste, comme au comptoir.
	var dernier := [Game.staked]
	Game.changed.connect(func():
		if Game.staked < dernier[0]:
			effacer()
			change.emit()
		dernier[0] = Game.staked)
	var minuteur := Timer.new()
	minuteur.wait_time = 60.0
	minuteur.autostart = true
	minuteur.timeout.connect(tic)
	add_child(minuteur)
	tic.call_deferred()


func maintenant() -> int:
	return get_node("/root/Football").maintenant()


# ---------------------------------------------------------------- les courses du registre

## Les courses des communes installées : les entrées du registre (Registre), type « course_velo ».
func courses() -> Array:
	return get_node("/root/Registre").de_type("course_velo", true)


## Une course par sa commune et son id, ou {}.
func course(commune: String, id: String) -> Dictionary:
	for e in courses():
		if e.commune == commune and e.id == id:
			return e
	return {}


## Un champ de la course, ou sa valeur par défaut.
static func champ(e: Dictionary, nom: String) -> Variant:
	return e.get("champs", {}).get(nom, DEFAUTS.get(nom))


## La course est ouverte au joueur : le lieu de même id dans le manifeste lui donne son seuil (sans lieu, 0).
func ouverte(e: Dictionary) -> bool:
	return int(Game.won) >= seuil(e)


func seuil(e: Dictionary) -> int:
	var c = Communes.commune(str(e.get("commune", "")))
	for l in (c.lieux() if c != null else []):
		if str(l.get("id", "")) == str(e.get("id", "")):
			return int(l.get("seuil", 0))
	return 0


# ---------------------------------------------------------------- le calendrier

## La durée d'une édition, du départ à l'arrivée du vainqueur, en secondes.
static func duree(e: Dictionary) -> int:
	return int(round(float(champ(e, "distance")) * int(champ(e, "tours")) / VITESSE))


## Les départs entre deux instants (secondes locales), au jour et à l'heure de la course.
static func departs(e: Dictionary, debut: int, fin: int) -> Array:
	var h := float(champ(e, "heure"))
	return Agenda.occurrences(JOURS.find(str(champ(e, "jour"))), int(h), int(round((h - int(h)) * 60.0)), debut, fin)


## Le prochain départ après t.
static func prochain_depart(e: Dictionary, t: int) -> int:
	return departs(e, t + 1, t + 1 + 8 * 86400)[0]


## Le dernier départ avant t (compris).
static func dernier_depart(e: Dictionary, t: int) -> int:
	var d: Array = departs(e, t - 8 * 86400, t + 1)
	return d[-1]


## L'édition dont on parle à l'instant t : celle qui court, ou dont les tickets ne sont pas encore réglés ;
## sinon la prochaine.
func edition(e: Dictionary, t: int) -> int:
	var d := dernier_depart(e, t)
	if t < fin(e, d) + REGLEMENT:
		return d
	return prochain_depart(e, t)


## L'arrivée du dernier coureur (ou le dernier abandon) d'une édition, en secondes locales.
func fin(e: Dictionary, depart: int) -> int:
	var dernier := 0.0
	for p in resultat(e, depart).passages.values():
		if not p.is_empty():
			dernier = maxf(dernier, float(p[-1]))
	return depart + int(ceil(dernier))


static func cle(e: Dictionary, depart: int) -> String:
	return "%s/%s/%s" % [e.commune, e.id, Time.get_date_string_from_unix_time(depart)]


# ---------------------------------------------------------------- les coureurs

## Les engagés d'une édition : le peloton de la course pour l'année du départ, le même chez tout le monde.
## {num, prenom, nom, grimpeur, rouleur, sprinteur, regularite (40 à 85), maillot}.
static func engages(e: Dictionary, depart: int) -> Array:
	var annee := int(Time.get_datetime_dict_from_unix_time(depart).year)
	var h := Hasard.depuis(Hasard.graine("cyclisme/%s/%s/%d" % [e.commune, e.id, annee]))
	var foot: GDScript = load("res://scripts/socle/football.gd")
	var out := []
	var noms := {}
	for i in clampi(int(champ(e, "coureurs")), COUREURS[0], COUREURS[1]):
		var r := {"num": i + 1, "prenom": h.choix(foot.PRENOMS), "nom": h.choix(foot.NOMS),
			"grimpeur": h.entier(40, 85), "rouleur": h.entier(40, 85), "sprinteur": h.entier(40, 85), "regularite": h.entier(40, 85),
			"maillot": MAILLOTS[i % MAILLOTS.size()]}
		# Deux coureurs du même nom se confondraient au bandeau.
		while noms.has(r.nom):
			r.nom = h.choix(foot.NOMS)
		noms[r.nom] = true
		out.append(r)
	return out


## Ce qu'est un coureur, en un mot : sa meilleure qualité.
static func profil(r: Dictionary) -> String:
	var q := {"grimpeur": int(r.grimpeur), "rouleur": int(r.rouleur), "sprinteur": int(r.sprinteur)}
	var meilleur := "rouleur"
	for k in q:
		if q[k] > q[meilleur]:
			meilleur = k
	return meilleur


## La force d'un coureur sur le relief de la course (40 à 85).
static func force(e: Dictionary, r: Dictionary) -> float:
	var w: Array = RELIEFS.get(str(champ(e, "relief")), RELIEFS.vallonne)
	return w[0] * int(r.grimpeur) + w[1] * int(r.rouleur) + w[2] * int(r.sprinteur)


# ---------------------------------------------------------------- les chances et les cotes

## Les chances d'une édition, tirées du moteur lui-même : la course rejouée PRONOSTICS fois d'une autre graine
## que la sienne (la forme du jour et les tours restent cachés aux parieurs). {gagnant: [p], place: [p]}, dans
## l'ordre des dossards ; gagnant fait 1, place fait 3 (moins les abandons). Le même chez tout le monde.
func chances(e: Dictionary, depart: int) -> Dictionary:
	var k := cle(e, depart)
	if not _chances.has(k):
		_chances[k] = pronostic(e, depart)
	return _chances[k]


static func pronostic(e: Dictionary, depart: int) -> Dictionary:
	var coureurs := engages(e, depart)
	var n := coureurs.size()
	var h := Hasard.depuis(Hasard.graine("cyclisme/pronostic/" + cle(e, depart)))
	var gagne := []
	var place := []
	gagne.resize(n)
	gagne.fill(0.0)
	place.resize(n)
	place.fill(0.0)
	for k in PRONOSTICS:
		var ordre: Array = _courir(e, coureurs, h).ordre
		if not ordre.is_empty():
			gagne[int(ordre[0]) - 1] += 1.0
		for i in mini(3, ordre.size()):
			place[int(ordre[i]) - 1] += 1.0
	# Un demi-succès de plus à chacun : personne n'est jamais sûr de perdre.
	var lisse := func(x: float, total: float) -> float: return (x + 0.5) / (PRONOSTICS + 0.5 * n / total)
	return {"gagnant": gagne.map(func(x): return lisse.call(x, 1.0)), "place": place.map(func(x): return minf(0.995, lisse.call(x, 3.0)))}


## Une cote d'après une chance, marge de la maison déduite, au vingtième près, entre 1,05 et 99.
static func cote_de(p: float) -> float:
	return clampf(floorf((1.0 - MARGE) / maxf(p, 0.0001) * 20.0) / 20.0, 1.05, 99.0)


## Les cotes d'une édition : {num: {gagnant, place}}.
func cotes(e: Dictionary, depart: int) -> Dictionary:
	var p := chances(e, depart)
	var out := {}
	for i in p.gagnant.size():
		out[i + 1] = {"gagnant": cote_de(p.gagnant[i]), "place": cote_de(p.place[i])}
	return out


# ---------------------------------------------------------------- le résultat commun

## Le résultat d'une édition, rejoué de sa graine : {ordre: [num], temps: {num: secondes}, passages: {num:
## [secondes à la fin de chaque tour]}, abandons: {num: tour}, crevaisons: {num: tour}, groupe: {num: même
## temps que le précédent}}. Les temps comptent depuis le départ.
func resultat(e: Dictionary, depart: int) -> Dictionary:
	var k := cle(e, depart)
	if not _resultats.has(k):
		_resultats[k] = calculer(e, depart)
	return _resultats[k]


static func calculer(e: Dictionary, depart: int) -> Dictionary:
	return _courir(e, engages(e, depart), Hasard.depuis(Hasard.graine("cyclisme/edition/" + cle(e, depart))))


## Une course, tirée de h : la forme du jour de chacun, ses tours, une crevaison, un abandon, puis le sprint.
static func _courir(e: Dictionary, coureurs: Array, h: Hasard) -> Dictionary:
	var tours := int(champ(e, "tours"))
	var tour_moyen := float(duree(e)) / tours
	var passages := {}
	var abandons := {}
	var crevaisons := {}
	var finis := []
	for r in coureurs:
		var num := int(r.num)
		# La forme du jour : une cloche autour de zéro, cachée aux parieurs.
		var forme := (h.suivant() + h.suivant() + h.suivant() - 1.5) * FORME
		var s := force(e, r) + forme
		var ecart := ALEA * (1.25 - int(r.regularite) / 100.0)
		var crevaison := h.entier(1, tours) if h.chance(0.03) else 0
		var abandon := h.entier(1, tours) if h.chance(0.012) else 0
		var t := 0.0
		var p := []
		for tour in range(1, tours + 1):
			if abandon == tour:
				abandons[num] = tour
				break
			var dt := tour_moyen * (1.0 - (s - 62.0) * POIDS_FORCE) * (1.0 + (h.suivant() - 0.5) * ecart)
			if crevaison == tour:
				crevaisons[num] = tour
				dt += h.entier(25, 80)
			t += dt
			p.append(t)
		passages[num] = p
		if not abandons.has(num):
			finis.append({"num": num, "t": t, "sprint": int(r.sprinteur) + h.suivant() * 12.0})
	finis.sort_custom(func(a, b): return a.t < b.t)
	# Le sprint : les coureurs arrivés à moins de deux secondes les uns des autres forment un groupe, classé
	# au sprint et crédité du temps de sa tête (« même temps »).
	var ordre := []
	var temps := {}
	var groupe := {}
	var i := 0
	while i < finis.size():
		var j := i + 1
		while j < finis.size() and finis[j].t - finis[j - 1].t < 2.0:
			j += 1
		var g := finis.slice(i, j)
		g.sort_custom(func(a, b): return a.sprint > b.sprint)
		var tete: float = finis[i].t
		for k in g.size():
			var num := int(g[k].num)
			ordre.append(num)
			temps[num] = tete
			groupe[num] = k > 0
			# À l'arrivée, l'ordre du sprint se lit sur la ligne : quelques dixièmes entre les roues.
			passages[num][-1] = tete + k * 0.3
		i = j
	return {"ordre": ordre, "temps": temps, "passages": passages, "abandons": abandons, "crevaisons": crevaisons, "groupe": groupe}


## La distance parcourue par un coureur (mètres depuis le départ) à l'instant t ; -1 s'il a abandonné et
## n'est plus en course.
func position(e: Dictionary, depart: int, num: int, t: float) -> float:
	var res := resultat(e, depart)
	var p: Array = res.passages.get(num, [])
	var longueur := float(champ(e, "distance"))
	var dt := t - depart
	if dt <= 0.0:
		return 0.0
	var avant := 0.0
	for k in p.size():
		if dt < p[k]:
			return (k + (dt - avant) / maxf(1.0, p[k] - avant)) * longueur
		avant = p[k]
	if res.abandons.has(num):
		return -1.0
	return p.size() * longueur


## L'état de la course à l'instant t, pour le bandeau et la fenêtre : {etat (« avant », « course »,
## « arrivee »), depart, tour, tours, tete (num), ecart (secondes entre la tête et le peloton), classement
## (les nums, du premier au dernier en course)}.
func en_direct(e: Dictionary, t: int) -> Dictionary:
	var depart := edition(e, t)
	var tours := int(champ(e, "tours"))
	var out := {"etat": "avant", "depart": depart, "tour": 0, "tours": tours, "tete": 0, "ecart": 0, "classement": []}
	if t < depart:
		return out
	var res := resultat(e, depart)
	var longueur := float(champ(e, "distance"))
	var pos := []
	for r in engages(e, depart):
		var d := position(e, depart, int(r.num), t)
		if d >= 0.0:
			pos.append([int(r.num), d])
	if pos.is_empty():
		out.etat = "arrivee"
		return out
	pos.sort_custom(func(a, b): return a[1] > b[1])
	out.classement = pos.map(func(x): return x[0])
	out.tete = pos[0][0]
	var fini: bool = pos.all(func(x): return x[1] >= tours * longueur - 0.01)
	out.etat = "arrivee" if fini else "course"
	out.tour = mini(tours, int(floor(pos[0][1] / longueur)) + 1)
	# L'écart : le temps que met le peloton (le coureur du milieu) à passer où est la tête.
	var milieu: float = pos[pos.size() / 2][1]
	out.ecart = int(round((pos[0][1] - milieu) / VITESSE))
	if fini:
		out.classement = res.ordre
		out.tete = res.ordre[0] if not res.ordre.is_empty() else 0
		out.ecart = 0
	return out


# ---------------------------------------------------------------- les paris

## Pose un ticket sur l'édition qui part à depart : genre « gagnant » ou « place ». La mise part tout de suite.
## {ok: true, ticket} ou {ok: false, raison} : « inconnu », « mise », « ferme » (le départ est donné),
## « credits ».
func parier(e: Dictionary, depart: int, num: int, genre: String, mise: int) -> Dictionary:
	var c: Dictionary = cotes(e, depart)
	if not c.has(num) or not genre in ["gagnant", "place"]:
		return {"ok": false, "raison": "inconnu"}
	if mise < MISE_MIN:
		return {"ok": false, "raison": "mise"}
	if maintenant() >= depart:
		return {"ok": false, "raison": "ferme"}
	if not Game.spend(mise):
		return {"ok": false, "raison": "credits"}
	var tk := {"cle": cle(e, depart), "commune": str(e.commune), "course": str(e.id), "nom_course": str(e.get("nom", "")),
		"depart": depart, "num": num, "genre": genre, "mise": mise, "cote": float(c[num][genre]), "etat": "ouvert",
		"gain": 0, "quand": maintenant()}
	tickets.append(tk)
	total_mise += mise
	sauver()
	change.emit()
	return {"ok": true, "ticket": tk}


func ouverts() -> Array:
	return tickets.filter(func(t): return t.etat == "ouvert")


## Règle les tickets dont la course est arrivée (dix minutes après le dernier coureur) ; rend ceux qui
## viennent de l'être. Une course qui n'est plus installée attend son retour.
func regler() -> Array:
	var regles := []
	var t := maintenant()
	for tk in tickets:
		if tk.etat != "ouvert":
			continue
		var e := course(str(tk.commune), str(tk.course))
		if e.is_empty():
			continue
		var depart := int(tk.depart)
		if t < fin(e, depart) + REGLEMENT:
			continue
		var ordre: Array = resultat(e, depart).ordre
		var rang := ordre.find(int(tk.num))
		if rang == 0 or (tk.genre == "place" and rang >= 0 and rang < 3):
			tk.gain = int(round(int(tk.mise) * float(tk.cote)))
			tk.etat = "gagne"
			total_gagne += int(tk.gain)
			Game.cash_in(int(tk.gain))
		else:
			tk.etat = "perdu"
		regles.append(tk)
	if not regles.is_empty():
		sauver()
		change.emit()
	return regles


## Règle ce qui est à régler et l'annonce au courrier (autoload Avis).
func tic() -> void:
	var avis := get_node_or_null("/root/Avis")
	for tk in regler():
		if avis != null:
			avis.publier({"id": "cyclisme/%s/%d/%d" % [tk.cle, int(tk.num), int(tk.quand)], "genre": "ticket",
				"importance": "normale" if tk.etat == "gagne" else "discrete",
				"titre": "%s : ticket %s" % [str(tk.get("nom_course", "La course")), "gagné, %s crédits" % Game.fmt(int(tk.gain)) if tk.etat == "gagne" else "perdu"],
				"texte": "N° %d %s, mise %s, cote %s." % [int(tk.num), "gagnant" if tk.genre == "gagnant" else "placé", Game.fmt(int(tk.mise)), str(tk.cote)],
				"lien": {"vers": "carnet", "onglet": "compte"}})


## Les tickets réglés dont personne n'a encore parlé ; les marque vus.
func non_vus() -> Array:
	var out := []
	for tk in tickets:
		if tk.etat != "ouvert" and not bool(tk.get("vu", false)):
			tk.vu = true
			out.append(tk)
	if not out.is_empty():
		sauver()
	return out


func bilan() -> Dictionary:
	var g := 0
	for tk in tickets:
		if tk.etat == "gagne":
			g += 1
	return {"mise": total_mise, "gagne": total_gagne, "tickets": tickets.size(), "gagnes": g}


# ---------------------------------------------------------------- l'agenda

## Les départs des courses ouvertes entre deux instants (secondes locales), au format de l'Agenda.
func rendez_vous(de: int, a: int) -> Array:
	var out := []
	for e in courses():
		if not ouverte(e):
			continue
		var tours := int(champ(e, "tours"))
		var km := float(champ(e, "distance")) * tours / 1000.0
		for depart in departs(e, de - duree(e), a):
			out.append({"id": "cyclisme@%s" % cle(e, depart), "titre": str(e.nom), "lieu": str(e.get("commune_nom", e.commune)),
				"quand": depart, "duree": duree(e), "activite": "cyclisme", "annonce": false,
				"detail": "%s, %s km, parcours %s. Paris gagnant ou placé jusqu'au départ." % [
					"%d tours" % tours if tours > 1 else "un tour", String.num(km, 1).replace(".", ","), RELIEFS_DITS.get(str(champ(e, "relief")), "")]})
	return out


# ---------------------------------------------------------------- la sauvegarde

func charger() -> void:
	if dossier == "":
		return
	var lu = Portail.lire_json(dossier.path_join(FICHIER))
	if lu is Dictionary and lu.has("tickets"):
		tickets = lu.tickets
		total_mise = int(lu.get("total_mise", 0))
		total_gagne = int(lu.get("total_gagne", 0))


func sauver() -> void:
	if dossier == "":
		return
	Portail.ecrire(dossier.path_join(FICHIER), JSON.stringify({"tickets": tickets, "total_mise": total_mise, "total_gagne": total_gagne}))


func effacer() -> void:
	tickets = []
	total_mise = 0
	total_gagne = 0
	_resultats = {}
	_chances = {}
	if dossier != "":
		DirAccess.remove_absolute(dossier.path_join(FICHIER))
