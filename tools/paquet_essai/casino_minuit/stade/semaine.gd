extends RefCounted
## La semaine du stade de la Fortune, à l'horloge du jeu (Football.maintenant, secondes locales) : désert du
## lundi au samedi, sauf l'entraînement public du mercredi de 18 h à 20 h ; le dimanche, les portes ouvrent à
## 13 h, le coup d'envoi est à 15 h (Football.HEURE_COUP_ENVOI), le stade se vide jusqu'à 19 h. Ses rendez-vous
## vont à l'agenda (source « stade_fortune »).

const MERCREDI := 3
const DIMANCHE := 0
const ENTRAINEMENT := [18, 20]
const PORTES := 13
const FERMETURE := 19
## Ce que le stade vit à un instant : « desert », « entrainement », « portes » (avant le coup d'envoi),
## « match » (le coup d'envoi et les deux heures qui suivent), « sortie » (la foule qui s'en va).
const MOMENTS := ["desert", "entrainement", "portes", "match", "sortie"]


static func moment(t: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(t)
	var h: float = d.hour + d.minute / 60.0
	var ke: int = Engine.get_main_loop().root.get_node("Football").HEURE_COUP_ENVOI
	if d.weekday == MERCREDI and h >= ENTRAINEMENT[0] and h < ENTRAINEMENT[1]:
		return "entrainement"
	if d.weekday == DIMANCHE:
		if h >= PORTES and h < ke:
			return "portes"
		if h >= ke and h < ke + 2.0:
			return "match"
		if h >= ke + 2.0 and h < FERMETURE:
			return "sortie"
	return "desert"


## La part des places occupées à cet instant (0 à 1) : la foule entre de 13 h à 15 h et sort de 17 h à 19 h.
static func remplissage(t: int) -> float:
	var d := Time.get_datetime_dict_from_unix_time(t)
	var h: float = d.hour + d.minute / 60.0
	var ke: float = Engine.get_main_loop().root.get_node("Football").HEURE_COUP_ENVOI
	match moment(t):
		"entrainement": return 0.03
		"portes": return clampf(0.15 + 0.85 * (h - PORTES) / (ke - PORTES), 0.0, 1.0)
		"match": return 1.0
		"sortie": return clampf(1.0 - (h - ke - 2.0) / (FERMETURE - ke - 2.0), 0.0, 1.0)
	return 0.0


## Inscrit les rendez-vous du stade à l'agenda (une fois suffit : l'agenda les garde pour la partie).
static func inscrire() -> void:
	var agenda: Node = Engine.get_main_loop().root.get_node_or_null("Agenda")
	if agenda:
		agenda.inscrire("stade_fortune", rendez_vous)


## Les rendez-vous du stade entre debut et fin : l'entraînement public du mercredi, et le dimanche du Racing
## Club Minuit (les portes à 13 h, le match à 15 h).
static func rendez_vous(debut: int, fin: int) -> Array:
	var out := []
	var ag: Node = Engine.get_main_loop().root.get_node("Agenda")
	for q in ag.occurrences(MERCREDI, ENTRAINEMENT[0], 0, debut - 2 * 3600, fin):
		out.append({"id": "stade_fortune/entrainement@%d" % q, "titre": "Entraînement public du Racing Club Minuit",
			"lieu": "au stade de la Fortune, Las Vegas", "quand": q, "duree": (ENTRAINEMENT[1] - ENTRAINEMENT[0]) * 3600,
			"activite": "football", "annonce": false,
			"detail": "Les tribunes sont ouvertes : on regarde le RCM s'entraîner sous la roue. Le taxi est à la porte-cochère du casino."})
	for q in ag.occurrences(DIMANCHE, PORTES, 0, debut - 6 * 3600, fin):
		out.append({"id": "stade_fortune/dimanche@%d" % q, "titre": "Le dimanche du Racing Club Minuit",
			"lieu": "au stade de la Fortune, Las Vegas", "quand": q, "duree": (FERMETURE - PORTES) * 3600,
			"activite": "football", "annonce": false,
			"detail": "Portes à 13 h, coup d'envoi à 15 h. Quand le RCM joue à l'extérieur, le match passe sur l'écran géant."})
	return out
