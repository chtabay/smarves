extends RefCounted
## Qui dirige un club, et ce qu'il faut pour le diriger, pour le football et le basket (`moteur` est
## l'autoload Football ou Basket ; les deux ont les mêmes règles : neuf obligations, chacune en un
## exemplaire, et la plus grosse somme investie décide).
##
## Les règles de Guillaume du 23 octobre au soir :
## - **Un club par division.** Un joueur ne dirige pas deux clubs de la même division. S'il dirige un club
##   et devient le plus gros porteur d'un autre de la même division, il reste à la tête du premier ; le
##   second revient au plus gros porteur suivant. Il ne change de club qu'à l'intersaison.
## - **Les parts ne s'achètent qu'à l'intersaison**, entre la dernière journée d'une saison et la première
##   de la suivante (avant la toute première saison aussi). On les rend quand on veut.
## La direction est tenue au serveur (fonctions smarves_directions et smarves_direction_prendre,
## supabase/migrations/20261024000000_smarves_directions.sql) : le moteur en garde la copie dans
## `directions` (club -> {par, moi, division}). Une direction tenue par quelqu'un qui n'a plus de part ne
## compte plus : la place est vacante, et le plus gros porteur qui ne dirige pas déjà un club de la même
## division la prend.
##
## Plutôt que d'aligner « Lucien 2 250, vous 500 » et de laisser la soustraction au joueur, on la fait ici,
## et l'on dit quelle obligation libre y suffit (demande du 23 octobre après-midi).

## La fin d'une journée : trois heures après son coup d'envoi, le match est joué.
const FIN_DE_JOURNEE := 3 * 3600


# ---------------------------------------------------------------- l'intersaison

## L'intersaison où l'on est, ou la prochaine : [début, fin] en secondes locales ; on y est si
## début <= t < fin. Avant la première saison, elle court jusqu'au premier coup d'envoi.
static func intersaison(moteur: Node, t := -1) -> Array:
	if t < 0:
		t = moteur.maintenant()
	var premier: int = moteur.coup_envoi(1, 1)
	if t < premier:
		return [0, premier]
	var periode: int = moteur.SEMAINES_PAR_SAISON * 7 * 86400
	var k := int(floor(float(t - premier) / periode)) + 1
	return [moteur.coup_envoi(k, moteur.JOURNEES) + FIN_DE_JOURNEE, moteur.coup_envoi(k + 1, 1)]


static func en_intersaison(moteur: Node) -> bool:
	var t: int = moteur.maintenant()
	var i := intersaison(moteur, t)
	return t >= int(i[0]) and t < int(i[1])


## « jusqu'au dimanche 25 octobre à 15 h » ou « du dimanche 24 janvier à 18 h au dimanche 14 février à 15 h ».
static func phrase_intersaison(moteur: Node) -> String:
	var i := intersaison(moteur)
	if en_intersaison(moteur):
		return "jusqu'au %s" % date(int(i[1]))
	return "du %s au %s" % [date(int(i[0])), date(int(i[1]))]


## « dimanche 25 octobre à 15 h ».
static func date(t: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(t)
	var jours := ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
	var mois := ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]
	return "%s %d %s à %d h%s" % [jours[d.weekday], d.day, mois[d.month - 1], d.hour, "" if d.minute == 0 else "%02d" % d.minute]


# ---------------------------------------------------------------- qui dirige

## La division d'un club, pour la règle d'un club par division : son niveau dans la pyramide (« 0 » pour
## la première), ou « » s'il n'y est pas.
static func division(moteur: Node, club: String) -> String:
	var p: Array = moteur.place_de(club)
	return str(p[0]) if not p.is_empty() else ""


## La direction tenue au serveur, si elle compte encore (son titulaire a des parts) : {nom, moi}, ou {}.
static func direction_valide(moteur: Node, club: String) -> Dictionary:
	var d: Dictionary = moteur.directions.get(club, {})
	if d.is_empty():
		return {}
	if bool(d.get("moi", false)):
		return {"nom": "vous", "moi": true} if int(moteur.investi(club)) > 0 else {}
	for x in moteur.actionnaires(club):
		if not bool(x.moi) and str(x.nom) == str(d.get("par", "")):
			return {"nom": str(x.nom), "moi": false}
	return {}


## Le club de la même division qu'un porteur dirige déjà (« » s'il n'en dirige pas).
static func dirige_ailleurs(moteur: Node, club: String, porteur: Dictionary) -> String:
	var div := division(moteur, club)
	if div == "":
		return ""
	for c in moteur.clubs:
		if c == club or division(moteur, c) != div:
			continue
		var d := direction_valide(moteur, c)
		if not d.is_empty() and bool(d.moi) == bool(porteur.moi) and (bool(porteur.moi) or str(d.nom) == str(porteur.nom)):
			return str(c)
	return ""


## Qui dirige le club : {nom, moi, investi, vacance} ; {} si personne n'a de part (le bureau est à tous).
## Sans direction tenue, le plus gros porteur qui ne dirige pas déjà un club de la même division (vacance).
static func dirigeant(moteur: Node, club: String) -> Dictionary:
	var a: Array = moteur.actionnaires(club)
	if a.is_empty():
		return {}
	var d := direction_valide(moteur, club)
	for x in a:
		if not d.is_empty() and bool(x.moi) == bool(d.moi) and (bool(d.moi) or str(x.nom) == str(d.nom)):
			return {"nom": str(x.nom), "moi": bool(x.moi), "investi": int(x.investi), "vacance": false}
	for x in a:
		if dirige_ailleurs(moteur, club, x) == "":
			return {"nom": str(x.nom), "moi": bool(x.moi), "investi": int(x.investi), "vacance": true}
	return {}


## Ce que le moteur répond à « puis-je décider ? » : personne n'a de part, ou c'est moi qui dirige.
static func decide(moteur: Node, club: String) -> bool:
	if moteur.actionnaires(club).is_empty():
		return true
	return bool(dirigeant(moteur, club).get("moi", false))


## On peut demander la direction au serveur : on y a droit (le plus gros porteur qui ne dirige pas déjà un
## club de la même division, ou celui qui veut changer de club à l'intersaison) et on ne la tient pas déjà
## pour la bonne division.
static func peut_prendre(moteur: Node, club: String, changer := false) -> bool:
	var mien: int = moteur.investi(club)
	if mien <= 0:
		return false
	var d: Dictionary = moteur.directions.get(club, {})
	if bool(d.get("moi", false)):
		return str(d.get("division", "")) != division(moteur, club)
	var valide := direction_valide(moteur, club)
	var inter := en_intersaison(moteur)
	if not valide.is_empty() and not inter:
		return false
	var ailleurs := dirige_ailleurs(moteur, club, {"nom": "vous", "moi": true})
	if ailleurs != "" and not (changer and inter):
		return false
	# Le plus gros porteur parmi ceux qui ne dirigent pas un autre club de la division.
	for x in moteur.actionnaires(club):
		if bool(x.moi):
			return true
		if dirige_ailleurs(moteur, club, x) == "" and int(x.investi) > mien:
			return false
	return true


# ---------------------------------------------------------------- ce qu'il faut pour diriger

## {dirige, mien, tete (le dirigeant, ou le premier des autres qui pourrait l'être), sa_mise, manque, suffit
## (le rang libre le moins cher qui suffit, 0 sinon), libres, personne, ailleurs (le club de la même division
## qu'on dirige déjà), inter (on est à l'intersaison)}.
static func etat(moteur: Node, club: String) -> Dictionary:
	var a: Array = moteur.actionnaires(club)
	var mien: int = moteur.investi(club)
	var tete := ""
	var sa_mise := 0
	var dg := dirigeant(moteur, club)
	if not dg.is_empty() and not bool(dg.moi):
		tete = str(dg.nom)
		sa_mise = int(dg.investi)
	else:
		for x in a:
			if not bool(x.moi) and dirige_ailleurs(moteur, club, x) == "":
				tete = str(x.nom)
				sa_mise = int(x.investi)
				break
	var libres: Array = []
	for r in range(1, moteur.OBLIGATIONS.size() + 1):
		if moteur.porteur(club, r).is_empty():
			libres.append(r)
	var manque := maxi(0, sa_mise - mien)
	var suffit := 0
	for r in libres:
		if moteur.valeur(r) >= manque and (manque > 0 or mien == 0):
			suffit = r
			break
	return {"dirige": bool(dg.get("moi", false)) and mien > 0, "mien": mien, "tete": tete, "sa_mise": sa_mise,
		"manque": manque, "suffit": suffit, "libres": libres, "personne": a.is_empty(),
		"ailleurs": dirige_ailleurs(moteur, club, {"nom": "vous", "moi": true}), "inter": en_intersaison(moteur),
		"tenue": not direction_valide(moteur, club).is_empty()}


## La phrase à afficher : ce qui manque et comment le combler, l'avance qu'on a, ou la règle qui bloque.
static func phrase(moteur: Node, club: String) -> String:
	var e := etat(moteur, club)
	var quand := "les parts se prennent à l'intersaison, %s" % phrase_intersaison(moteur)
	if e.personne:
		if not e.inter:
			return "Personne ne tient de part ; %s." % quand
		return "Personne ne tient de part : la n° 1, à %s crédits, vous fait dirigeant." % Game.fmt(moteur.valeur(1)) if e.libres.has(1) \
			else "Personne ne tient de part : la première prise fait son porteur dirigeant."
	if e.dirige:
		if e.tete == "":
			return "Vous dirigez le club, seul porteur."
		var avance: int = int(e.mien) - int(e.sa_mise)
		return "Vous dirigez le club ; %s est %s." % [e.tete, "à égalité" if avance == 0 else ("à %s crédits derrière" % Game.fmt(avance) if avance > 0 else "devant vous, mais vous gardez la main jusqu'à l'intersaison")]
	if str(e.ailleurs) != "":
		var nom := str(moteur.clubs.get(e.ailleurs, {}).get("nom", e.ailleurs))
		return "Vous dirigez déjà %s, de la même division : un joueur ne dirige qu'un club par division. %s" \
			% [nom, "Vous pouvez en changer pendant l'intersaison, %s." % phrase_intersaison(moteur) if e.inter else "Vous pourrez en changer à l'intersaison, %s." % phrase_intersaison(moteur)]
	if not e.inter:
		var qui := "%s dirige le club jusqu'à l'intersaison" % e.tete if e.tenue else "Il vous manque %s crédits de parts pour diriger" % Game.fmt(int(e.manque))
		return "%s ; %s." % [qui, quand]
	var t := "Il vous manque %s crédits de parts pour diriger (%s en a %s)" % [Game.fmt(int(e.manque)), e.tete, Game.fmt(int(e.sa_mise))]
	if int(e.suffit) > 0:
		return t + " : la n° %d, à %s, y suffit." % [e.suffit, Game.fmt(moteur.valeur(e.suffit))]
	if e.libres.is_empty():
		return t + " : toutes les obligations sont prises."
	return t + " : il y faut plusieurs obligations."


## Le texte d'un bouton « Prendre » qu'on ne peut pas payer : ce qui manque.
static func manque_credits(prix: int) -> String:
	return "il manque %s" % Game.fmt(prix - Game.credits)


## Ce que dit une rangée « Prendre » éteinte hors de l'intersaison.
static func ferme_texte(moteur: Node) -> String:
	return "à l'intersaison, " + phrase_intersaison(moteur)


## « de » devant le nom d'un club : « des Hérons du Clain », « de l'Étoile de Smarves », « du Racing ».
static func de(nom: String) -> String:
	for x in [["Les ", "des "], ["Le ", "du "], ["La ", "de la "], ["L'", "de l'"], ["L’", "de l’"]]:
		if nom.begins_with(x[0]):
			return x[1] + nom.substr(x[0].length())
	return "de " + nom
