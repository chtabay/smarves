extends Node
## L'agenda de la semaine (autoload « Agenda ») : les rendez-vous de toutes les activités, à l'heure du
## calendrier réel, que le carnet montre jour par jour. Chaque activité y inscrit ses rendez-vous par un
## fournisseur (inscrire) ; le football, le mercato et les paris sont lus ici par leurs fonctions
## publiques tant qu'ils n'ont pas inscrit le leur, et les rendez-vous de chaque semaine (le loto du
## samedi, le tournoi fermé du mercredi, les parties de poker du panneau) sont écrits ci-dessous.
##
## Un rendez-vous est un dictionnaire : {id, titre, lieu, quand (secondes locales, comme Football),
## duree (secondes), detail, activite, annonce}. Le modèle des activités (docs/ACTIVITES.md, brique 1)
## écrit quoi pour titre et ou pour lieu : les deux se lisent. annonce est vrai pour ce qui est seulement annoncé :
## l'activité n'existe pas encore à cette heure-là (les tables à plusieurs ouvriront plus tard, par des
## seuils) ; faux pour ce qui se joue vraiment (le match du dimanche, la clôture du mercato).

signal change

const JOUR := 86400
const SEMAINE := 7 * JOUR
const JOURS := ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
const MOIS := ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]

## Les rendez-vous de chaque semaine qui ne sont qu'annoncés : jour (0 : dimanche), heure, minute, durée
## en heures, quoi, où, activité, un mot. Les parties de poker du panneau (Voisinage.RENDEZ_VOUS) s'y ajoutent.
const HEBDOMADAIRES := [
	[3, 20, 30, 3, "Le tournoi fermé de poker", "le Fumoir du Casino, à l'étage", "poker",
		"Sur invitation, six joueurs, une seule table. Les tables à plusieurs ouvrent plus tard."],
	[6, 20, 30, 3, "Le grand tirage du samedi", "la salle François-Rabelais", "loto",
		"Le loto de M. Gaudin, tiré pour tout le monde à la même heure. Les cartons de tous les jours restent au comptoir."],
]

## Ce qui se joue à toute heure, sans rendez-vous : la feuille de la semaine le rappelle en bas, pour
## qu'on sache où aller entre deux rendez-vous. [quoi, où].
const TOUS_LES_JOURS := [
	["Le poker des Ambassadeurs, contre les habitués", "la Salle des Ambassadeurs, au Casino"],
	["Les cartons du grand loto", "la salle François-Rabelais"],
	["Les paris sur la journée du dimanche", "le comptoir de Josiane, au Café de la Place"],
]

## Les fournisseurs inscrits par les activités : source → Callable(debut, fin) qui rend [rendez-vous].
## Une source inscrite remplace la lecture d'ici du même nom (« football », « mercato », « paris »).
var _sources := {}


## Inscrit (ou remplace) les rendez-vous d'une activité : f(debut, fin) rend ceux qui tombent entre les deux.
func inscrire(source: String, f: Callable) -> void:
	_sources[source] = f
	change.emit()


func retirer(source: String) -> void:
	if _sources.erase(source):
		change.emit()


## Les secondes locales « maintenant » : l'horloge du football, pour qu'un essai règle les deux d'un coup.
func maintenant() -> int:
	var foot := _noeud("Football")
	if foot != null:
		return foot.maintenant()
	return int(Time.get_unix_time_from_system()) + int(Time.get_time_zone_from_system().get("bias", 0)) * 60


## Les rendez-vous de la semaine, dans l'ordre : ceux du reste de la journée (et ceux en cours), puis
## ceux des sept jours suivants, jusqu'au même jour de la semaine prochaine compris (le dimanche soir,
## on voit encore le match du dimanche qui vient).
func semaine(t := -1) -> Array:
	if t < 0:
		t = maintenant()
	return entre(t, fin_de_semaine(t))


## La fin de la semaine vue depuis t : minuit à la fin du même jour, la semaine prochaine.
static func fin_de_semaine(t: int) -> int:
	return (int(floor(t / float(JOUR))) + 8) * JOUR


## Les prochains rendez-vous, au plus n.
func prochains(n := 3, t := -1) -> Array:
	return semaine(t).slice(0, n)


## Tous les rendez-vous qui commencent avant fin et ne sont pas finis à debut, dans l'ordre.
func entre(debut: int, fin: int) -> Array:
	var out := []
	var lus := {"hebdo": func(a, b): return hebdomadaires(a, b), "football": _football, "mercato": _mercato, "paris": _paris}
	for s in _sources:
		lus[s] = _sources[s]
	for s in lus:
		var f: Callable = lus[s]
		if not f.is_valid():
			continue
		# Une semaine plus tôt : un rendez-vous long qui a commencé avant debut est encore là.
		for rv in f.call(debut - JOUR, fin):
			var r: Dictionary = _complet(rv)
			if r.quand < fin and r.quand + r.duree > debut:
				out.append(r)
	out.sort_custom(func(a, b): return a.quand < b.quand or (a.quand == b.quand and a.titre < b.titre))
	return out


static func _complet(rv: Dictionary) -> Dictionary:
	var r := {"id": "", "titre": "", "lieu": "", "quand": 0, "duree": 0, "detail": "", "activite": "", "annonce": false}
	r.merge(rv, true)
	if r.titre == "" and rv.has("quoi"):
		r.titre = str(rv.quoi)
	if r.lieu == "" and rv.has("ou"):
		r.lieu = str(rv.ou)
	if r.id == "":
		r.id = "%s@%d" % [r.titre, r.quand]
	return r


# ---------------------------------------------------------------- les rendez-vous de chaque semaine

## Les rendez-vous de chaque semaine entre debut et fin : ceux d'ici et les parties de poker du panneau.
static func hebdomadaires(debut: int, fin: int) -> Array:
	var regles: Array = HEBDOMADAIRES.duplicate()
	var voisinage: GDScript = load("res://scripts/socle/voisinage.gd")
	for rv in voisinage.RENDEZ_VOUS:
		regles.append([rv[0], rv[1], rv[2], 3, rv[3], rv[4], "poker", "Les tables à plusieurs ouvrent bientôt : venez déjà vous montrer."])
	var out := []
	for r in regles:
		for quand in occurrences(int(r[0]), int(r[1]), int(r[2]), debut, fin):
			out.append({"id": "%s@%d" % [r[6], quand], "titre": r[4], "lieu": r[5], "quand": quand, "duree": int(r[3]) * 3600,
				"activite": r[6], "detail": r[7], "annonce": true})
	return out


## Les instants entre debut (compris) et fin (exclu) qui tombent tel jour de la semaine à telle heure.
static func occurrences(jour_semaine: int, heure: int, minute: int, debut: int, fin: int) -> Array:
	var jour := int(floor(debut / float(JOUR)))
	var semaine_du_jour := (jour + 4) % 7  # le 1er janvier 1970 était un jeudi
	var quand := (jour + (jour_semaine - semaine_du_jour + 7) % 7) * JOUR + heure * 3600 + minute * 60
	if quand < debut:
		quand += SEMAINE
	var out := []
	while quand < fin:
		out.append(quand)
		quand += SEMAINE
	return out


# ---------------------------------------------------------------- le football, lu par ses fonctions publiques

## Les journées du championnat : le match du club de la commune d'origine s'il en a un, sinon la journée.
func _football(debut: int, fin: int) -> Array:
	var foot := _noeud("Football")
	if foot == null:
		return []
	var out := []
	var s0: int = maxi(1, foot.saison_a(debut))
	for s in [s0, s0 + 1]:
		for j in range(1, foot.JOURNEES + 1):
			var quand: int = foot.coup_envoi(s, j)
			if quand < debut or quand >= fin:
				continue
			var rv := {"id": "football@%d/%d" % [s, j], "titre": "Championnat de la Vienne, journée %d" % j,
				"lieu": "sur les terrains de la Vienne", "quand": quand, "duree": 2 * 3600, "activite": "football",
				"detail": "Tous les matchs à 15 h. Le tableau du dimanche est au Café de la Place."}
			var m := _match_de_la_commune(foot, s, j)
			if not m.is_empty():
				var dom: Dictionary = foot.clubs.get(m.dom, {})
				var ext: Dictionary = foot.clubs.get(m.ext, {})
				rv.titre = "%s – %s" % [dom.get("nom", m.dom), ext.get("nom", m.ext)]
				rv.lieu = str(dom.get("stade", "")) if not dom.get("invite", true) and str(dom.get("stade", "")) != "" \
					else "chez %s" % dom.get("nom", m.dom)
				rv.detail = "Championnat de la Vienne, %s, journée %d. Les consignes se donnent avant 15 h, au bureau du club." \
					% [foot.nom_division(m.n, m.g), j]
			out.append(rv)
	return out


## Le match du club de la commune d'origine à la journée j de la saison s : {dom, ext, n, g}, ou {}.
func _match_de_la_commune(foot: Node, s: int, j: int) -> Dictionary:
	var communes := _noeud("Communes")
	var origine = communes.origine() if communes != null else null
	if origine == null or s != foot.saison:
		return {}
	var place: Array = foot.place_de(origine.id)
	if place.is_empty():
		return {}
	for m in foot.journee(s, place[0], place[1], j, 0):
		if m.dom == origine.id or m.ext == origine.id:
			return {"dom": m.dom, "ext": m.ext, "n": place[0], "g": place[1]}
	return {}


## Le mercato (autoload Mercato) : quarante joueurs mis aux enchères chaque dimanche à 17 h, dont les
## dernières dates limites tombent le samedi soir ; et nos propres enchères et ventes, par
## Mercato.rendez_vous(de, a), avec leur date limite.
func _mercato(debut: int, fin: int) -> Array:
	var mercato := _noeud("Mercato")
	if mercato == null:
		return []
	var out := []
	var k0: int = mercato.semaine_a(debut)
	for k in [k0, k0 + 1, k0 + 2]:
		var ouvre: int = mercato.debut_semaine(k)
		if ouvre >= debut and ouvre < fin:
			out.append({"id": "mercato@%d/lots" % k, "titre": "Quarante joueurs mis aux enchères", "lieu": "le mercato, au bureau du club",
				"quand": ouvre, "activite": "mercato", "detail": "Le plus offrant l'emporte ; les dates limites courent du lundi au samedi soir."})
		var dernier := 0
		for i in mercato.LOTS:
			dernier = maxi(dernier, int(mercato.echeance_lot(k, i)))
		if dernier >= debut and dernier < fin:
			out.append({"id": "mercato@%d/fin" % k, "titre": "Dernières enchères de la semaine", "lieu": "le mercato, au bureau du club",
				"quand": dernier, "activite": "mercato", "detail": "Les derniers joueurs de la semaine partent au plus offrant."})
	if mercato.has_method("rendez_vous"):
		for rv in mercato.rendez_vous(debut, fin):
			var r: Dictionary = rv.duplicate()
			r.activite = "mercato"
			r.erase("lieu")  # Mercato écrit le lieu en code (« stade ») et l'adresse dans ou.
			out.append(r)
	return out


## Les tickets ouverts au comptoir de Josiane : leur règlement, le dimanche à 17 h.
func _paris(debut: int, fin: int) -> Array:
	var foot := _noeud("Football")
	var paris := _noeud("Paris")
	if foot == null or paris == null:
		return []
	var journees := {}
	for t in paris.ouverts():
		var k := "%d/%d" % [int(t.s), int(t.j)]
		journees[k] = journees.get(k, 0) + 1
	var out := []
	for k in journees:
		var quand: int = foot.coup_envoi(int(k.get_slice("/", 0)), int(k.get_slice("/", 1))) + int(paris.REGLEMENT)
		if quand >= debut and quand < fin:
			var n: int = journees[k]
			out.append({"id": "paris@" + k, "titre": "Règlement de vos tickets" if n > 1 else "Règlement de votre ticket",
				"lieu": "au comptoir de Josiane, au Café de la Place", "quand": quand, "activite": "paris",
				"detail": "%d ticket%s en jeu sur la journée." % [n, "s" if n > 1 else ""]})
	return out


func _noeud(nom: String) -> Node:
	var arbre := Engine.get_main_loop() as SceneTree
	return arbre.root.get_node_or_null(nom) if arbre != null else null


# ---------------------------------------------------------------- l'écriture des dates

## « mercredi 21 octobre »
static func date(t: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(t)
	return "%s %s %s" % [JOURS[d.weekday], "1er" if d.day == 1 else str(d.day), MOIS[d.month - 1]]


## « 20 h 30 », « 15 h »
static func heure(t: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(t)
	return "%d h" % d.hour if d.minute == 0 else "%d h %02d" % [d.hour, d.minute]


## « aujourd'hui », « demain », ou la date.
static func jour_relatif(t: int, maintenant: int) -> String:
	var ecart := int(floor(t / float(JOUR))) - int(floor(maintenant / float(JOUR)))
	if ecart == 0:
		return "aujourd'hui"
	if ecart == 1:
		return "demain"
	return date(t)


## Le rendez-vous a commencé et n'est pas fini.
static func en_cours(rv: Dictionary, maintenant: int) -> bool:
	return rv.quand <= maintenant and maintenant < rv.quand + rv.duree
