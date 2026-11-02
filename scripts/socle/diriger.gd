extends RefCounted
## Qui dirige un club, et ce qu'il faut pour le diriger, pour le football et le basket (`moteur` est
## l'autoload Football ou Basket ; les deux ont les mêmes règles : neuf obligations, chacune en un
## exemplaire, et la plus grosse somme investie décide).
##
## Les règles de Guillaume du 31 octobre 2026 (la relève des présidents), qui remplacent celles du 23 :
## - **Les parts se prennent toute l'année**, et se rendent quand on veut.
## - **Un club à la fois.** Un président ne dirige qu'un club par sport. S'il dirige un club et devient le
##   plus gros porteur d'un autre, il reste à la tête du premier ; le second revient au plus gros porteur
##   suivant.
## - **La relève, le lundi à midi.** Prendre la main sur un club qu'un autre dirige, ou quitter son club pour
##   un autre, se déclare quand on veut et prend effet à la relève suivante, le lundi à midi : les matchs du
##   week-end sont joués, et le nouveau président a la semaine pour la consigne, le mercato et le marché du
##   basket (clôture le jeudi à 22 h). Une direction vacante se prend tout de suite, si l'on n'en tient pas.
## - **Un changement de club pendant la saison, un pendant l'intersaison** (le mercato) : la période est
##   celle de la relève où il prend effet. La première prise d'un club, quand on n'en dirige aucun, ne
##   compte pas.
## La direction est tenue au serveur (smarves_directions, smarves_direction_releves, smarves_direction_prendre
## et smarves_direction_renoncer, supabase/migrations/20261101120000_smarves_releve_des_presidents.sql) : le
## moteur en garde la copie dans `directions` (club -> {par, moi, division}), `releves` ([{club, par, moi,
## effet}], les relèves annoncées) et `changements` ([{periode, club}], les siens). Une direction tenue par
## quelqu'un qui n'a plus de part ne compte plus : la place est vacante, et le plus gros porteur qui ne
## dirige pas déjà un club la prend.
##
## Plutôt que d'aligner « Lucien 2 250, vous 500 » et de laisser la soustraction au joueur, on la fait ici,
## et l'on dit quelle obligation libre y suffit (demande du 23 octobre après-midi).

## La fin d'une journée : trois heures après son coup d'envoi, le match est joué.
const FIN_DE_JOURNEE := 3 * 3600
## La relève : le lundi (1 ; 0 est le dimanche) à midi.
const RELEVE_JOUR := 1
const RELEVE_HEURE := 12


# ---------------------------------------------------------------- la relève

## La relève qui suit l'instant t (secondes locales), strictement après : le lundi à midi.
static func releve_suivante(t: int) -> int:
	var d := Time.get_datetime_dict_from_unix_time(t)
	var minuit: int = t - int(d.hour) * 3600 - int(d.minute) * 60 - int(d.second)
	var r: int = minuit - ((int(d.weekday) - RELEVE_JOUR + 7) % 7) * 86400 + RELEVE_HEURE * 3600
	return r if r > t else r + 7 * 86400


static func prochaine_releve(moteur: Node) -> int:
	return releve_suivante(moteur.maintenant())


## La relève annoncée pour soi : {club, effet}, ou {}.
static func ma_releve(moteur: Node) -> Dictionary:
	for r in moteur.releves:
		if bool(r.get("moi", false)):
			return r
	return {}


## Les relèves annoncées pour un club, par d'autres que soi.
static func releves_de(moteur: Node, club: String) -> Array:
	return (moteur.releves as Array).filter(func(r): return str(r.get("club", "")) == club and not bool(r.get("moi", false)))


## La période d'un instant, comme le serveur la compte (smarves.periode_de) : « s<k> » de la première journée
## de la saison k à la fin de sa dernière, « i<k> » pendant l'intersaison qui précède la saison k.
static func periode(moteur: Node, t: int) -> String:
	var premier: int = moteur.coup_envoi(1, 1)
	if t < premier:
		return "i1"
	var k := int(floor(float(t - premier) / (moteur.SEMAINES_PAR_SAISON * 7 * 86400))) + 1
	return ("i%d" % (k + 1)) if t >= moteur.coup_envoi(k, moteur.JOURNEES) + FIN_DE_JOURNEE else ("s%d" % k)


## On a déjà changé de club pendant la période (la saison, ou l'intersaison) de la prochaine relève.
static func deja_change(moteur: Node) -> bool:
	var p := periode(moteur, prochaine_releve(moteur))
	return (moteur.changements as Array).any(func(c): return str(c.get("periode", "")) == p)


## « cette saison » ou « cette intersaison », selon la période de la prochaine relève.
static func cette_periode(moteur: Node) -> String:
	return "cette intersaison" if periode(moteur, prochaine_releve(moteur)).begins_with("i") else "cette saison"


# ---------------------------------------------------------------- l'intersaison

## L'intersaison où l'on est, ou la prochaine : [début, fin] en secondes locales ; on y est si
## début <= t < fin. Avant la première saison, elle court jusqu'au premier coup d'envoi. Elle ne règle plus
## les parts ni la direction : le calendrier la montre.
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


## « dimanche 25 octobre à 15 h », « lundi 2 novembre à midi ».
static func date(t: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(t)
	var jours := ["dimanche", "lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
	var mois := ["janvier", "février", "mars", "avril", "mai", "juin", "juillet", "août", "septembre", "octobre", "novembre", "décembre"]
	var heure := "midi" if d.hour == 12 and d.minute == 0 else "%d h%s" % [d.hour, "" if d.minute == 0 else "%02d" % d.minute]
	return "%s %d %s à %s" % [jours[d.weekday], d.day, mois[d.month - 1], heure]


# ---------------------------------------------------------------- qui dirige

## La division d'un club : son niveau dans la pyramide (« 0 » pour la première), ou « » s'il n'y est pas.
## Elle n'entre plus dans la règle (un club par sport) ; le serveur la garde pour l'affichage.
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


## L'autre club du sport qu'un porteur dirige déjà (« » s'il n'en dirige pas).
static func dirige_ailleurs(moteur: Node, club: String, porteur: Dictionary) -> String:
	for c in moteur.clubs:
		if c == club:
			continue
		var d := direction_valide(moteur, c)
		if not d.is_empty() and bool(d.moi) == bool(porteur.moi) and (bool(porteur.moi) or str(d.nom) == str(porteur.nom)):
			return str(c)
	return ""


## Qui dirige le club : {nom, moi, investi, vacance} ; {} si personne n'a de part (le bureau est à tous).
## Sans direction tenue, le plus gros porteur qui ne dirige pas déjà un autre club (vacance).
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


## On a mis au moins autant que chacun des autres porteurs qui ne dirigent pas un autre club (le titulaire
## compte).
static func en_tete(moteur: Node, club: String) -> bool:
	var mien: int = moteur.investi(club)
	if mien <= 0:
		return false
	for x in moteur.actionnaires(club):
		if not bool(x.moi) and dirige_ailleurs(moteur, club, x) == "" and int(x.investi) > mien:
			return false
	return true


## On peut prendre la direction tout de suite : elle est vacante, on n'en tient pas d'autre, et l'on est en
## tête. Le jeu la demande alors de lui-même au serveur.
static func peut_prendre(moteur: Node, club: String) -> bool:
	var d: Dictionary = moteur.directions.get(club, {})
	if bool(d.get("moi", false)):
		return int(moteur.investi(club)) > 0 and str(d.get("division", "")) != division(moteur, club)
	if not direction_valide(moteur, club).is_empty():
		return false
	if dirige_ailleurs(moteur, club, {"nom": "vous", "moi": true}) != "":
		return false
	return en_tete(moteur, club)


## Ce qu'on peut déclarer pour la relève : {ok, changer (on quitte son club), raison} ; raison « dirige »
## (c'est déjà le sien), « annoncee » (déjà déclarée pour ce club), « immediate » (vacante : elle se prend
## tout de suite), « parts », « saison » (on a déjà changé de club dans la période : la saison ou l'intersaison).
static func relevable(moteur: Node, club: String) -> Dictionary:
	var e := {"ok": false, "changer": false, "raison": ""}
	if decide(moteur, club) and int(moteur.investi(club)) > 0 and not direction_valide(moteur, club).is_empty():
		e.raison = "dirige"
		return e
	if str(ma_releve(moteur).get("club", "")) == club:
		e.raison = "annoncee"
		return e
	if not en_tete(moteur, club):
		e.raison = "parts"
		return e
	e.changer = dirige_ailleurs(moteur, club, {"nom": "vous", "moi": true}) != ""
	if not e.changer and direction_valide(moteur, club).is_empty():
		e.raison = "immediate"
		return e
	if e.changer and deja_change(moteur):
		e.raison = "saison"
		return e
	e.ok = true
	return e


# ---------------------------------------------------------------- ce qu'il faut pour diriger

## {dirige, mien, tete (le dirigeant, ou le premier des autres qui pourrait l'être), sa_mise, manque, suffit
## (le rang libre le moins cher qui suffit, 0 sinon), libres, personne, ailleurs (l'autre club qu'on dirige),
## tenue (la direction est tenue par quelqu'un), releve (la relève qu'on a annoncée pour ce club, 0 sinon),
## arrivee ({par, effet} : un autre prend la main à la relève, ou {})}.
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
	var mienne := ma_releve(moteur)
	var autres := releves_de(moteur, club)
	return {"dirige": bool(dg.get("moi", false)) and mien > 0, "mien": mien, "tete": tete, "sa_mise": sa_mise,
		"manque": manque, "suffit": suffit, "libres": libres, "personne": a.is_empty(),
		"ailleurs": dirige_ailleurs(moteur, club, {"nom": "vous", "moi": true}),
		"tenue": not direction_valide(moteur, club).is_empty(),
		"releve": int(mienne.get("effet", 0)) if str(mienne.get("club", "")) == club else 0,
		"arrivee": {} if autres.is_empty() else autres[0]}


## La phrase à afficher : ce qui manque et comment le combler, l'avance qu'on a, la relève annoncée, ou la
## règle qui bloque.
static func phrase(moteur: Node, club: String) -> String:
	var e := etat(moteur, club)
	var quand := "à la relève, %s" % date(prochaine_releve(moteur))
	if e.personne:
		return "Personne ne tient de part : la n° 1, à %s crédits, vous fait dirigeant." % Game.fmt(moteur.valeur(1)) if e.libres.has(1) \
			else "Personne ne tient de part : la première prise fait son porteur dirigeant."
	if not (e.arrivee as Dictionary).is_empty():
		if e.dirige:
			return "Vous dirigez le club ; %s en prend la direction à la relève, %s." % [str(e.arrivee.par), date(int(e.arrivee.effet))]
		return "%s prend la direction du club à la relève, %s." % [str(e.arrivee.par), date(int(e.arrivee.effet))]
	if e.dirige:
		if e.tete == "":
			return "Vous dirigez le club, seul porteur."
		var avance: int = int(e.mien) - int(e.sa_mise)
		return "Vous dirigez le club ; %s est %s." % [e.tete, "à égalité" if avance == 0 else ("à %s crédits derrière" % Game.fmt(avance) if avance > 0 else "devant vous : il peut demander la direction pour la relève du lundi")]
	if int(e.releve) > 0:
		return "Vous prenez la direction du club à la relève, %s." % date(int(e.releve))
	var rel := relevable(moteur, club)
	if str(e.ailleurs) != "":
		var nom := str(moteur.clubs.get(e.ailleurs, {}).get("nom", e.ailleurs))
		var t := "Vous dirigez déjà %s : un président ne dirige qu'un club à la fois." % nom
		if rel.raison == "saison":
			return t + " Vous en avez déjà changé %s ; on change de club une fois pendant la saison, une fois pendant l'intersaison." % cette_periode(moteur)
		if rel.ok:
			return t + " Vous pouvez le quitter pour celui-ci %s (un changement pendant la saison, un pendant l'intersaison)." % quand
		return t + " Pour en changer, il vous faut ici la plus grosse mise (%s en a %s)." % [e.tete, Game.fmt(int(e.sa_mise))]
	if rel.ok:
		return "%s dirige le club, mais vous avez mis plus : demandez la direction, elle vous revient %s." % [e.tete, quand]
	var m := "Il vous manque %s crédits de parts pour diriger (%s en a %s)" % [Game.fmt(int(e.manque)), e.tete, Game.fmt(int(e.sa_mise))]
	if e.tenue:
		m = "%s dirige le club. Il vous manque %s crédits de parts pour le diriger à votre tour" % [e.tete, Game.fmt(int(e.manque))]
	if int(e.suffit) > 0:
		return m + " : la n° %d, à %s, y suffit." % [e.suffit, Game.fmt(moteur.valeur(e.suffit))]
	if e.libres.is_empty():
		return m + " : toutes les obligations sont prises."
	return m + " : il y faut plusieurs obligations."


## Le texte du bouton qui demande la direction pour la relève, ou « » s'il n'y a rien à demander.
static func bouton_releve(moteur: Node, club: String) -> String:
	var rel := relevable(moteur, club)
	if not rel.ok:
		return ""
	var quand := date(prochaine_releve(moteur))
	if rel.changer:
		var ailleurs := str(moteur.clubs.get(dirige_ailleurs(moteur, club, {"nom": "vous", "moi": true}), {}).get("nom", ""))
		return "Diriger ce club à la place %s, %s" % [de(ailleurs), quand]
	return "Demander la direction pour la relève, %s" % quand


## Pourquoi la direction n'a pas été prise, en une phrase (les raisons du serveur).
static func pourquoi(raison: String) -> String:
	return {"parts": "Un autre porteur a mis plus que vous dans le club.",
		"ailleurs": "Vous dirigez déjà un club : un président n'en dirige qu'un à la fois.",
		"saison": "Vous avez déjà changé de club dans cette période : on en change une fois pendant la saison, une fois pendant l'intersaison.",
		"compte": "Il faut être connecté à son compte Pyramides pour diriger un club.",
		"reseau": "Le serveur ne répond pas ; réessayez dans un moment."}.get(raison, "")


## Le texte d'un bouton « Prendre » qu'on ne peut pas payer : ce qui manque.
static func manque_credits(prix: int) -> String:
	return "il manque %s" % Game.fmt(prix - Game.credits)


## « de » devant le nom d'un club : « des Hérons du Clain », « de l'Étoile de Smarves », « du Racing ».
static func de(nom: String) -> String:
	for x in [["Les ", "des "], ["Le ", "du "], ["La ", "de la "], ["L'", "de l'"], ["L’", "de l’"]]:
		if nom.begins_with(x[0]):
			return x[1] + nom.substr(x[0].length())
	return "de " + nom
