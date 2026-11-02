extends RefCounted
## Le calendrier des deux championnats, pour l'onglet « Le calendrier » du carnet (demande de Guillaume du
## 23 octobre au soir : « le calendrier du championnat, intersaisons, mercatos, etc. est très facilement
## trouvable dans l'interface »). `moteur` est l'autoload Football ou Basket ; tout se calcule depuis leurs
## coups d'envoi, comme le reste du jeu.

const DIRIGER := preload("res://scripts/socle/diriger.gd")
const MOIS_COURTS := ["janv.", "févr.", "mars", "avr.", "mai", "juin", "juil.", "août", "sept.", "oct.", "nov.", "déc."]


## Le prochain coup d'envoi après t : [saison, journée, secondes].
static func prochain(moteur: Node, t: int) -> Array:
	var s: int = maxi(1, int(moteur.saison))
	for k in [s, s + 1]:
		for j in range(1, moteur.JOURNEES + 1):
			if t < moteur.coup_envoi(k, j):
				return [k, j, moteur.coup_envoi(k, j)]
	return [s + 2, 1, moteur.coup_envoi(s + 2, 1)]


## « 25 oct. », « 1er nov. ».
static func jour_court(t: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(t)
	return "%s %s" % ["1er" if d.day == 1 else str(d.day), MOIS_COURTS[d.month - 1]]


## Les lignes d'un championnat : [[libellé, valeur]], puis le détail des journées et la règle des montées.
## {titre, lignes, journees, regle}.
static func page(moteur: Node, sport: String) -> Dictionary:
	var t: int = moteur.maintenant()
	var s: int = int(moteur.saison)
	var jouees: int = moteur.journee_jouee_a(t, s)
	var lignes: Array = []
	var p := prochain(moteur, t)
	if jouees == 0:
		lignes.append(["La saison %d" % s, "commence le %s" % DIRIGER.date(moteur.coup_envoi(s, 1))])
	elif jouees >= moteur.JOURNEES:
		lignes.append(["La saison %d" % s, "est jouée ; la %d commence le %s" % [s + 1, DIRIGER.date(moteur.coup_envoi(s + 1, 1))]])
	else:
		lignes.append(["La saison %d" % s, "journée %d sur %d jouée" % [jouees, moteur.JOURNEES]])
	lignes.append(["Le prochain match", "journée %d, %s" % [p[1], DIRIGER.date(int(p[2]))]])
	var inter := DIRIGER.intersaison(moteur, t)
	if DIRIGER.en_intersaison(moteur):
		lignes.append(["L'intersaison", "maintenant, jusqu'au %s" % DIRIGER.date(int(inter[1]))])
	else:
		lignes.append(["L'intersaison", "du %s au %s" % [DIRIGER.date(int(inter[0])), DIRIGER.date(int(inter[1]))]])
	lignes.append(["La relève", "le %s" % DIRIGER.date(DIRIGER.releve_suivante(t))])
	lignes.append(["", "chaque lundi à midi, la direction des clubs change de main ; les parts se prennent toute l'année"])
	if sport == "football":
		var m: int = moteur.prochain_mercato()
		var ouvert: bool = moteur.periode() == "mercato"
		if ouvert:
			lignes.append(["Le mercato", "ouvert jusqu'au %s" % DIRIGER.date(moteur.coup_envoi(s, 1))])
		else:
			lignes.append(["Le mercato", "du %s au %s" % [DIRIGER.date(m), DIRIGER.date(m + 7 * 86400)]])
		lignes.append(["", "une recrue par club, la semaine d'avant la première journée"])
	else:
		var j: int = moteur.journee_du_marche()
		if j > 0:
			lignes.append(["Le marché", "clôture le %s, pour la journée %d" % [DIRIGER.date(moteur.cloture(s, j)), j]])
		else:
			lignes.append(["Le marché", "rouvre avant la journée 2 de la saison %d, le %s" % [s + 1, DIRIGER.date(moteur.cloture(s + 1, 2))]])
		lignes.append(["", "chaque semaine, les enchères ferment le jeudi à 22 h"])
	var k: int = s if jouees < moteur.JOURNEES else s + 1
	var js: Array = []
	for n in range(1, moteur.JOURNEES + 1):
		var c: int = moteur.coup_envoi(k, n)
		js.append({"n": n, "jour": jour_court(c), "jouee": t >= c + DIRIGER.FIN_DE_JOURNEE, "prochaine": k == int(p[0]) and n == int(p[1])})
	return {"titre": "Le football" if sport == "football" else "Le basket", "lignes": lignes, "saison_des_journees": k, "journees": js,
		"regle": "En fin de saison, le premier de chaque groupe monte, les deux derniers descendent. Une journée par semaine, %s." \
			% ("le dimanche à 15 h" if sport == "football" else "le samedi à 20 h")}


## En une phrase, pour les bureaux et les registres : la journée, l'intersaison, le mercato ou le marché.
static func resume(moteur: Node, sport: String) -> String:
	var d := page(moteur, sport)
	var out: Array = []
	for l in d.lignes:
		if str(l[0]) != "" and str(l[0]) != "Le prochain match":
			out.append("%s %s" % [str(l[0]).to_lower() if str(l[0]).begins_with("L") else str(l[0]), l[1]])
	var t := " ; ".join(out) + "."
	return t.substr(0, 1).to_upper() + t.substr(1)


## Ouvre le carnet à l'onglet du calendrier.
static func ouvrir() -> void:
	var c: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Carnet")
	if c != null:
		c.ouvrir_calendrier()
