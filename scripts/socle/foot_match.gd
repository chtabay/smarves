class_name FootMatch
extends RefCounted
## Le match minute par minute, repris du Vestiaire (Zeus, src/moteur/match.js, tactique.js et
## commentaire.js) : l'état est un dictionnaire sérialisable qu'on fait avancer d'une minute, avec ses
## occasions, ses buts, ses cartons, ses blessures et les changements de l'adjoint, et un commentateur qui
## raconte. Tout vient d'un Hasard : à graine égale, même match, chez tout le monde (docs/SUITE.md, 6).
## Ici rien ne dépend des autoloads : Football fournit les clubs, les joueurs et la graine.

const MAX_REMPLACEMENTS := 5
const AVANTAGE_DOMICILE := 1.07
const CHANCE_BASE := 0.13

## Chaque case d'une formation : poste attendu, rôle, position sur le schéma (x de gauche à droite,
## y du but adverse en haut à son propre but en bas, de 0 à 100).
const FORMATIONS := {
	"4-4-2": [["G", "GB", 50, 92], ["D", "DG", 15, 72], ["D", "DC", 38, 76], ["D", "DC", 62, 76], ["D", "DD", 85, 72],
		["M", "MG", 15, 46], ["M", "MC", 38, 52], ["M", "MC", 62, 52], ["M", "MD", 85, 46], ["A", "BU", 38, 20], ["A", "BU", 62, 20]],
	"4-3-3": [["G", "GB", 50, 92], ["D", "DG", 15, 72], ["D", "DC", 38, 76], ["D", "DC", 62, 76], ["D", "DD", 85, 72],
		["M", "MC", 28, 52], ["M", "MDC", 50, 58], ["M", "MC", 72, 52], ["A", "AG", 18, 24], ["A", "BU", 50, 18], ["A", "AD", 82, 24]],
	"4-2-3-1": [["G", "GB", 50, 92], ["D", "DG", 15, 72], ["D", "DC", 38, 76], ["D", "DC", 62, 76], ["D", "DD", 85, 72],
		["M", "MDC", 38, 58], ["M", "MDC", 62, 58], ["M", "MG", 18, 36], ["M", "MOC", 50, 38], ["M", "MD", 82, 36], ["A", "BU", 50, 16]],
	"4-5-1": [["G", "GB", 50, 92], ["D", "DG", 15, 72], ["D", "DC", 38, 76], ["D", "DC", 62, 76], ["D", "DD", 85, 72],
		["M", "MG", 12, 44], ["M", "MC", 32, 52], ["M", "MDC", 50, 58], ["M", "MC", 68, 52], ["M", "MD", 88, 44], ["A", "BU", 50, 18]],
	"3-5-2": [["G", "GB", 50, 92], ["D", "DC", 28, 76], ["D", "DC", 50, 78], ["D", "DC", 72, 76],
		["M", "PG", 10, 48], ["M", "MC", 32, 54], ["M", "MDC", 50, 60], ["M", "MC", 68, 54], ["M", "PD", 90, 48], ["A", "BU", 38, 20], ["A", "BU", 62, 20]],
	"5-3-2": [["G", "GB", 50, 92], ["D", "DLG", 10, 66], ["D", "DC", 30, 76], ["D", "DC", 50, 78], ["D", "DC", 70, 76], ["D", "DLD", 90, 66],
		["M", "MC", 28, 50], ["M", "MC", 50, 54], ["M", "MC", 72, 50], ["A", "BU", 38, 20], ["A", "BU", 62, 20]],
}

const MENTALITES := {
	"defensive": {"nom": "Défensive", "attaque": 0.86, "defense": 1.12, "milieu": 0.98},
	"prudente": {"nom": "Prudente", "attaque": 0.94, "defense": 1.05, "milieu": 1.0},
	"equilibree": {"nom": "Équilibrée", "attaque": 1.0, "defense": 1.0, "milieu": 1.0},
	"offensive": {"nom": "Offensive", "attaque": 1.08, "defense": 0.93, "milieu": 1.01},
	"tout": {"nom": "Tout pour l'attaque", "attaque": 1.16, "defense": 0.84, "milieu": 1.02},
}

const PRESSINGS := {
	"bas": {"nom": "Bloc bas", "milieu": 0.96, "defense": 1.03, "fatigue": 0.8},
	"normal": {"nom": "Normal", "milieu": 1.0, "defense": 1.0, "fatigue": 1.0},
	"haut": {"nom": "Pressing haut", "milieu": 1.06, "defense": 0.98, "fatigue": 1.35},
}

const POSTES := {"G": "Gardien", "D": "Défenseur", "M": "Milieu", "A": "Attaquant"}

## Les phrases du commentateur : {j} joueur, {a} passeur, {g} gardien adverse, {e} équipe, {o} adversaire,
## {s} stade, {sc} score. Plusieurs tournures par situation, pour ne pas lasser.
const PHRASES := {
	"coupEnvoi": ["C'est parti au {s} ! {e} donne le coup d'envoi.", "L'arbitre siffle, le ballon roule au {s}. {e} engage.",
		"Coup d'envoi au {s}, sous les chants des tribunes. {e} a le ballon."],
	"ambiance": ["{e} fait tourner patiemment au milieu.", "{j} cherche une ouverture, rien ne se dessine.", "Longue séquence de possession pour {e}.",
		"{j} demande le ballon dans l'espace, la passe est trop longue.", "Le public du {s} pousse son équipe.", "Le bloc de {o} reste bien en place.",
		"{j} temporise, personne ne se démarque.", "Duel âpre au milieu, {j} finit par récupérer.", "{e} essaie de jouer vite vers l'avant.",
		"Changement d'aile signé {j}, mais {o} se replace.", "Petit temps faible, le jeu se hache.", "{j} se fait masser, rien de grave semble-t-il."],
	"occasion": ["Belle combinaison de {e}, {a} trouve {j} en position de frappe…", "Centre de {a}, {j} est à la réception…", "{a} lance {j} en profondeur…",
		"Récupération haute de {e}, {a} sert {j}…", "Une-deux entre {a} et {j} à l'entrée de la surface…"],
	"occasionSolo": ["{j} s'infiltre dans la surface…", "{j} élimine son vis-à-vis et arme…", "{j} tente sa chance de loin…",
		"Ballon perdu par {o}, {j} récupère et file vers le but…"],
	"corner": ["Corner pour {e}. {a} le tire, {j} s'élève…", "Sur le corner de {a}, {j} gagne son duel aérien…"],
	"penaltyObtenu": ["PENALTY ! {j} est fauché dans la surface, l'arbitre n'hésite pas.", "Main dans la surface ! Penalty pour {e}.",
		"L'arbitre désigne le point de penalty après une faute sur {j} !"],
	"but": ["BUT ! {j} trompe {g} ! {sc}", "BUUUT pour {e} ! {j} ne tremble pas. {sc}", "Et c'est le but ! Frappe imparable de {j}. {sc}",
		"BUT ! {j} conclut en force, {g} est battu. {sc}", "BUT ! Tout en finesse, {j} glisse le ballon au fond. {sc}"],
	"butTete": ["BUT de la tête de {j} ! {sc}", "BUT ! {j} catapulte le ballon de la tête au fond des filets. {sc}"],
	"butPenalty": ["BUT ! {j} transforme le penalty, {g} est parti du mauvais côté. {sc}", "Penalty transformé par {j}, plein centre. {sc}"],
	"penaltyRate": ["ARRÊTÉ ! {g} détourne le penalty de {j} !", "{j} manque le cadre ! Le penalty file à côté."],
	"passeur": ["Passe décisive de {a}.", "Quel service de {a} !", "Le travail de {a} en amont a tout fait."],
	"arret": ["Arrêt de {g} ! Il repousse la frappe de {j}.", "{g} s'envole et sort le tir de {j} en corner.", "Parade réflexe de {g} devant {j} !",
		"{g} capte sans trembler la frappe de {j}."],
	"rate": ["La frappe de {j} passe au-dessus.", "{j} croise trop sa frappe, à côté.", "Contré ! La défense de {o} s'interpose devant {j}.",
		"{j} tergiverse et se fait reprendre.", "Tir non cadré de {j}."],
	"poteau": ["POTEAU ! La frappe de {j} heurte le montant !", "Sur la barre ! {j} n'était pas loin."],
	"jaune": ["Carton jaune pour {j}, coupable d'une faute grossière.", "{j} est averti après un tacle en retard.", "Avertissement pour {j}, qui a trop protesté."],
	"deuxiemeJaune": ["Deuxième jaune pour {j} : il est expulsé ! {e} va finir à dix."],
	"rouge": ["CARTON ROUGE ! {j} est exclu pour un tacle dangereux.", "Expulsion directe pour {j}, l'arbitre ne laisse rien passer."],
	"blessure": ["{j} se tient la cuisse et ne peut pas continuer.", "{j} reste au sol après un choc. Il doit sortir."],
	"remplacement": ["Changement pour {e} : {j} entre à la place de {a}.", "{e} effectue un changement, {a} cède sa place à {j}."],
	"gardienDeChamp": ["Plus de changement possible : {j} enfile les gants et va dans les cages !"],
	"miTemps": ["C'est la mi-temps au {s}. {sc}", "L'arbitre renvoie les joueurs aux vestiaires. {sc}"],
	"reprise": ["C'est reparti pour la seconde période !", "Les acteurs reviennent sur la pelouse, place à la deuxième mi-temps."],
	"tempsAdditionnel": ["{n} minute{s} de temps additionnel annoncée{s}."],
	"fin": ["C'est terminé au {s} ! {sc}", "Coup de sifflet final. {sc}"],
}


# ---------------------------------------------------------------- la tactique

## Ce que vaut un joueur hors de son poste.
static func compatibilite(poste_joueur: String, poste_case: String) -> float:
	if poste_joueur == poste_case:
		return 1.0
	if poste_joueur == "G" or poste_case == "G":
		return 0.3
	return 0.86 if (poste_joueur == "M" or poste_case == "M") else 0.72


static func note_effective(j: Dictionary, poste_case: String, condition := -1.0) -> float:
	var c: float = float(j.get("condition", 100)) if condition < 0.0 else condition
	return float(j.note) * compatibilite(str(j.poste), poste_case) * (0.62 + 0.38 * c / 100.0) * (0.95 + 0.1 * float(j.get("moral", 70)) / 100.0)


## La force par ligne d'un onze (moins de onze après une expulsion) : onze = [{joueur, poste}].
static func force_equipe(onze: Array, mentalite := "equilibree", pressing := "normal") -> Dictionary:
	var somme := {"G": 0.0, "D": 0.0, "M": 0.0, "A": 0.0}
	for e in onze:
		somme[e.poste] += note_effective(e.joueur, e.poste)
	var m: Dictionary = MENTALITES.get(mentalite, MENTALITES.equilibree)
	var p: Dictionary = PRESSINGS.get(pressing, PRESSINGS.normal)
	return {
		"gardien": somme.G if somme.G > 0.0 else 20.0,
		"defense": (somme.D + 0.3 * somme.M + 0.05 * somme.A) / 5.3 * m.defense * p.defense,
		"milieu": (somme.M + 0.25 * (somme.D + somme.A)) / 5.5 * m.milieu * p.milieu,
		"attaque": (somme.A + 0.35 * somme.M + 0.1 * somme.D) / 3.8 * m.attaque,
	}


## Le meilleur onze pour une formation : chaque case prend d'abord le meilleur joueur du poste ; on ne
## déplace un joueur hors de son poste que s'il n'y a plus personne. ids : les joueurs disponibles.
static func compo_auto(ids: Array, joueurs: Dictionary, formation: String) -> Array:
	var cases: Array = FORMATIONS.get(formation, FORMATIONS["4-4-2"])
	var libres: Array = ids.duplicate()
	var compo: Array = []
	compo.resize(cases.size())
	for naturel in [true, false]:
		for poste in ["G", "A", "D", "M"]:
			for i in cases.size():
				if cases[i][0] != poste or compo[i] != null:
					continue
				var meilleur = null
				var score := -1.0
				for id in libres:
					if naturel and joueurs[id].poste != poste:
						continue
					var s := note_effective(joueurs[id], poste)
					if s > score:
						score = s
						meilleur = id
				if meilleur != null:
					compo[i] = meilleur
					libres.erase(meilleur)
	return compo


## Les remplaçants : les sept meilleurs restants, dont un gardien si possible.
static func banc_auto(ids: Array, joueurs: Dictionary, compo: Array, taille := 7) -> Array:
	var restants: Array = ids.filter(func(id): return not compo.has(id))
	restants.sort_custom(func(a, b): return joueurs[a].note > joueurs[b].note)
	var banc: Array = []
	for id in restants:
		if joueurs[id].poste == "G":
			banc.append(id)
			break
	for id in restants:
		if banc.size() >= taille:
			break
		if not banc.has(id):
			banc.append(id)
	return banc


# ---------------------------------------------------------------- le match

## Un match prêt pour le coup d'envoi. dom et ext : {id, nom, court, stade, formation, mentalite, pressing,
## effectif (ids)} ; joueurs : {id: {prenom, nom, poste, age, note, condition, moral}}.
static func creer(dom: Dictionary, ext: Dictionary, joueurs: Dictionary, h: Hasard) -> Dictionary:
	var etat := {
		"dom": dom.id, "ext": ext.id, "stade": str(dom.get("stade", "le stade")),
		"minute": 0, "periode": 1, "fini": false, "pause": "",
		"additionnel": [h.entier(1, 3), h.entier(2, 6)],
		"score": [0, 0],
		"equipes": [_creer_equipe(dom, joueurs), _creer_equipe(ext, joueurs)],
		"stats": [_stats(), _stats()],
		"buts": [],
		"evenements": [],
	}
	_ajouter(etat, "coupEnvoi", -1, phrase(h, "coupEnvoi", {"s": etat.stade, "e": dom.nom}))
	return etat


static func _stats() -> Dictionary:
	return {"possession": 0, "tirs": 0, "cadres": 0, "corners": 0, "fautes": 0, "jaunes": 0, "rouges": 0}


static func _creer_equipe(club: Dictionary, joueurs: Dictionary) -> Dictionary:
	var formation := str(club.get("formation", "4-4-2"))
	var cases: Array = FORMATIONS.get(formation, FORMATIONS["4-4-2"])
	var compo: Array = club.get("compo", compo_auto(club.effectif, joueurs, formation))
	var banc: Array = club.get("banc", banc_auto(club.effectif, joueurs, compo))
	var onze: Array = []
	for i in compo.size():
		if compo[i] != null:
			onze.append({"id": compo[i], "poste": cases[i][0]})
	var condition := {}
	var notes := {}
	for id in compo:
		if id != null:
			condition[id] = float(joueurs[id].get("condition", 100))
	for id in banc:
		condition[id] = float(joueurs[id].get("condition", 100))
	for e in onze:
		notes[e.id] = 6.0
	return {"club": club.id, "nom": club.nom, "court": club.court, "formation": formation,
		"onze": onze, "banc": banc.duplicate(), "sortis": [], "expulses": [], "blesses": [],
		"remplacements": 0, "mentalite": str(club.get("mentalite", "equilibree")), "pressing": str(club.get("pressing", "normal")),
		"condition": condition, "notes": notes, "jaunes": {}, "auto": true}


static func _ajouter(etat: Dictionary, type: String, equipe: int, texte: String, extra := {}) -> Dictionary:
	var ev := {"minute": libelle_minute(etat), "type": type, "equipe": equipe, "texte": texte}
	ev.merge(extra)
	etat.evenements.append(ev)
	return ev


static func libelle_minute(etat: Dictionary) -> String:
	if etat.minute == 0:
		return "0'"
	if etat.periode == 1 and etat.minute > 45:
		return "45+%d'" % (etat.minute - 45)
	if etat.periode == 2 and etat.minute > 90:
		return "90+%d'" % (etat.minute - 90)
	return "%d'" % etat.minute


static func score_texte(etat: Dictionary) -> String:
	return "%s %d-%d %s" % [etat.equipes[0].court, etat.score[0], etat.score[1], etat.equipes[1].court]


static func nom_court(j: Dictionary) -> String:
	return "%s. %s" % [str(j.prenom).left(1), j.nom]


static func phrase(h: Hasard, cle: String, vars := {}) -> String:
	var t := str(h.choix(PHRASES[cle]))
	for k in ["j", "a", "g", "e", "o", "s", "sc", "n"]:
		t = t.replace("{%s}" % k, str(vars.get(k, "")))
	return t


## Le joueur tel qu'il est maintenant : sa condition baisse pendant le match.
static func _onze_actuel(eq: Dictionary, joueurs: Dictionary) -> Array:
	var out: Array = []
	for e in eq.onze:
		var j: Dictionary = joueurs[e.id].duplicate()
		j.condition = eq.condition[e.id]
		out.append({"poste": e.poste, "joueur": j})
	return out


static func forces(etat: Dictionary, joueurs: Dictionary) -> Array:
	var out: Array = []
	for eq in etat.equipes:
		var f := force_equipe(_onze_actuel(eq, joueurs), eq.mentalite, eq.pressing)
		# Jouer à moins de onze coûte plus que la simple absence d'un joueur.
		var manque: int = 11 - eq.onze.size()
		if manque > 0:
			var k := pow(0.93, manque)
			f.milieu *= k
			f.attaque *= k
			f.defense *= k
		out.append(f)
	return out


static func _eff(eq: Dictionary, joueurs: Dictionary, id, poste: String) -> float:
	return note_effective(joueurs[id], poste, eq.condition[id])


static func _choisir_tireur(eq: Dictionary, joueurs: Dictionary, h: Hasard, exclu = null) -> Variant:
	var poids := {"A": 3.0, "M": 1.3, "D": 0.35, "G": 0.0}
	var cands: Array = eq.onze.filter(func(e): return e.id != exclu and e.poste != "G")
	if cands.is_empty():
		return eq.onze[0] if not eq.onze.is_empty() else null
	return h.pondere(cands, func(e): return poids[e.poste] * _eff(eq, joueurs, e.id, e.poste))


static func _choisir_passeur(eq: Dictionary, joueurs: Dictionary, h: Hasard, exclu = null) -> Variant:
	var poids := {"A": 1.4, "M": 2.0, "D": 0.6, "G": 0.02}
	var cands: Array = eq.onze.filter(func(e): return e.id != exclu)
	if cands.is_empty():
		return null
	return h.pondere(cands, func(e): return poids[e.poste] * _eff(eq, joueurs, e.id, e.poste))


static func _gardien_de(eq: Dictionary) -> Variant:
	for e in eq.onze:
		if e.poste == "G":
			return e
	return null


static func _noter(eq: Dictionary, id, delta: float) -> void:
	if eq.notes.has(id):
		eq.notes[id] = clampf(eq.notes[id] + delta, 3.0, 10.0)


## Fait sortir un joueur (blessure ou expulsion) ; comble le trou si un changement reste possible.
static func _retirer(etat: Dictionary, i: int, id, raison: String, joueurs: Dictionary, h: Hasard) -> void:
	var eq: Dictionary = etat.equipes[i]
	var idx := -1
	for k in eq.onze.size():
		if eq.onze[k].id == id:
			idx = k
	if idx < 0:
		return
	var poste: String = eq.onze[idx].poste
	eq.onze.remove_at(idx)
	if raison == "rouge":
		eq.expulses.append(id)
	if raison == "blessure":
		eq.blesses.append(id)
	if raison == "blessure" and eq.remplacements < MAX_REMPLACEMENTS and not eq.banc.is_empty():
		var entrant = _meilleur_remplacant(eq, joueurs, poste)
		if entrant != null:
			_faire_entrer(etat, i, entrant, poste, id, joueurs, h)
			return
	if poste == "G":
		# Gardien sorti : on sacrifie un joueur de champ pour faire entrer le gardien remplaçant, sinon
		# un joueur de champ va dans les cages.
		var g_banc = null
		for b in eq.banc:
			if joueurs[b].poste == "G":
				g_banc = b
				break
		if g_banc != null and eq.remplacements < MAX_REMPLACEMENTS and not eq.onze.is_empty():
			var sacrifie: Dictionary = eq.onze[-1]
			for e in eq.onze:
				if e.poste == "A":
					sacrifie = e
			eq.onze.erase(sacrifie)
			eq.sortis.append(sacrifie.id)
			_faire_entrer(etat, i, g_banc, "G", sacrifie.id, joueurs, h)
		elif not eq.onze.is_empty():
			var volontaire: Dictionary = eq.onze[0]
			for e in eq.onze:
				if e.poste == "D":
					volontaire = e
					break
			volontaire.poste = "G"
			_ajouter(etat, "info", i, phrase(h, "gardienDeChamp", {"j": nom_court(joueurs[volontaire.id])}))


static func _meilleur_remplacant(eq: Dictionary, joueurs: Dictionary, poste: String) -> Variant:
	var meilleur = null
	var score := -1.0
	for b in eq.banc:
		var s := _eff(eq, joueurs, b, poste)
		if s > score:
			score = s
			meilleur = b
	return meilleur


static func _faire_entrer(etat: Dictionary, i: int, entrant, poste: String, sortant, joueurs: Dictionary, h: Hasard) -> void:
	var eq: Dictionary = etat.equipes[i]
	eq.banc.erase(entrant)
	eq.onze.append({"id": entrant, "poste": poste})
	eq.notes[entrant] = 6.0
	eq.remplacements += 1
	_ajouter(etat, "remplacement", i, phrase(h, "remplacement", {"e": eq.nom, "j": nom_court(joueurs[entrant]), "a": nom_court(joueurs[sortant])}),
		{"entrant": entrant, "sortant": sortant})


## Un changement demandé par l'entraîneur. Rend un message d'erreur, ou "" si c'est fait.
static func remplacer(etat: Dictionary, i: int, sortant, entrant, joueurs: Dictionary, h: Hasard) -> String:
	var eq: Dictionary = etat.equipes[i]
	if etat.fini:
		return "Le match est terminé."
	if eq.remplacements >= MAX_REMPLACEMENTS:
		return "Les %d changements ont été faits." % MAX_REMPLACEMENTS
	var idx := -1
	for k in eq.onze.size():
		if eq.onze[k].id == sortant:
			idx = k
	if idx < 0:
		return "Ce joueur n'est pas sur le terrain."
	if not eq.banc.has(entrant):
		return "Ce joueur n'est pas sur le banc."
	var poste: String = eq.onze[idx].poste
	eq.onze.remove_at(idx)
	eq.sortis.append(sortant)
	_faire_entrer(etat, i, entrant, poste, sortant, joueurs, h)
	return ""


static func changer_consignes(etat: Dictionary, i: int, mentalite := "", pressing := "") -> void:
	var eq: Dictionary = etat.equipes[i]
	if mentalite != "":
		eq.mentalite = mentalite
	if pressing != "":
		eq.pressing = pressing


## Les changements de l'adjoint : les fatigués à partir de l'heure de jeu, un attaquant de plus si on perd.
static func _changements_auto(etat: Dictionary, i: int, joueurs: Dictionary, h: Hasard) -> void:
	var eq: Dictionary = etat.equipes[i]
	if not eq.auto or eq.remplacements >= MAX_REMPLACEMENTS or eq.banc.is_empty():
		return
	if etat.periode != 2 or not (etat.minute in [60, 68, 75, 82]):
		return
	var ecart: int = etat.score[i] - etat.score[1 - i]
	var fatigues: Array = eq.onze.filter(func(e): return e.poste != "G" and eq.condition[e.id] < 72.0)
	fatigues.sort_custom(func(a, b): return eq.condition[a.id] < eq.condition[b.id])
	var nb: int = 2 if etat.minute == 60 else 1
	for sortant in fatigues.slice(0, nb):
		if eq.remplacements >= MAX_REMPLACEMENTS:
			break
		var poste: String = sortant.poste
		if ecart < 0 and etat.minute >= 68 and poste == "D":
			poste = "A"
		var entrant = _meilleur_remplacant(eq, joueurs, poste)
		if entrant == null or joueurs[entrant].poste == "G":
			continue
		remplacer(etat, i, sortant.id, entrant, joueurs, h)
		var ajout: Dictionary = eq.onze[-1]
		if ajout.id == entrant:
			ajout.poste = poste
	if ecart < 0 and etat.minute >= 75 and eq.mentalite != "tout":
		eq.mentalite = "tout" if ecart <= -2 else "offensive"
	if ecart > 0 and etat.minute >= 82 and eq.mentalite != "defensive":
		eq.mentalite = "prudente"


static func _fatiguer(etat: Dictionary, joueurs: Dictionary) -> void:
	for eq in etat.equipes:
		var k: float = PRESSINGS.get(eq.pressing, PRESSINGS.normal).fatigue
		for e in eq.onze:
			var j: Dictionary = joueurs[e.id]
			var age: int = int(j.get("age", 26))
			var endurance := 1.15 if age > 31 else (0.9 if age < 22 else 1.0)
			var perte := (0.08 if j.poste == "G" else 0.3) * k * endurance
			eq.condition[e.id] = maxf(20.0, eq.condition[e.id] - perte)


## Avance d'une minute. Rend les événements de cette minute.
static func avancer(etat: Dictionary, joueurs: Dictionary, h: Hasard) -> Array:
	if etat.fini:
		return []
	var debut: int = etat.evenements.size()
	if etat.pause == "mi-temps":
		etat.pause = ""
		etat.periode = 2
		etat.minute = 45
		for eq in etat.equipes:
			for id in eq.condition:
				eq.condition[id] = minf(100.0, eq.condition[id] + 4.0)
		etat.minute += 1
		_ajouter(etat, "reprise", -1, phrase(h, "reprise"))
	else:
		etat.minute += 1
	var fin: int = 45 + etat.additionnel[0] if etat.periode == 1 else 90 + etat.additionnel[1]
	if etat.minute == (45 if etat.periode == 1 else 90):
		var n: int = etat.additionnel[etat.periode - 1]
		_ajouter(etat, "info", -1, phrase(h, "tempsAdditionnel", {"n": n, "s": "s" if n > 1 else ""}))
	_jouer_minute(etat, joueurs, h)
	_fatiguer(etat, joueurs)
	for i in 2:
		_changements_auto(etat, i, joueurs, h)
	if etat.minute >= fin:
		var vars := {"s": etat.stade, "sc": score_texte(etat)}
		if etat.periode == 1:
			etat.pause = "mi-temps"
			_ajouter(etat, "mi-temps", -1, phrase(h, "miTemps", vars))
		else:
			etat.fini = true
			_cloturer(etat)
			_ajouter(etat, "fin", -1, phrase(h, "fin", vars))
	return etat.evenements.slice(debut)


static func _jouer_minute(etat: Dictionary, joueurs: Dictionary, h: Hasard) -> void:
	var f := forces(etat, joueurs)
	var fd: Dictionary = f[0]
	var fe: Dictionary = f[1]
	var md := pow(fd.milieu * AVANTAGE_DOMICILE, 2)
	var me := pow(fe.milieu, 2)
	var i := 0 if h.chance(md / (md + me)) else 1
	var att: Dictionary = etat.equipes[i]
	var def: Dictionary = etat.equipes[1 - i]
	var fa: Dictionary = fd if i == 0 else fe
	var fo: Dictionary = fe if i == 0 else fd
	etat.stats[i].possession += 1

	# Les fautes et les cartons, commis par l'équipe qui défend.
	if h.chance(0.2):
		etat.stats[1 - i].fautes += 1
		var champ: Array = def.onze.filter(func(e): return e.poste != "G")
		var fautif = h.choix(champ) if not champ.is_empty() else (def.onze[0] if not def.onze.is_empty() else null)
		if fautif != null:
			if h.chance(0.004):
				_expulser(etat, 1 - i, fautif.id, "rouge", joueurs, h)
			elif h.chance(0.12):
				etat.stats[1 - i].jaunes += 1
				def.jaunes[fautif.id] = int(def.jaunes.get(fautif.id, 0)) + 1
				_noter(def, fautif.id, -0.3)
				if def.jaunes[fautif.id] >= 2:
					_expulser(etat, 1 - i, fautif.id, "deuxiemeJaune", joueurs, h)
				else:
					_ajouter(etat, "jaune", 1 - i, phrase(h, "jaune", {"j": nom_court(joueurs[fautif.id])}), {"joueur": fautif.id})

	# Une blessure, rare, d'un côté ou de l'autre.
	for k in 2:
		var eq: Dictionary = etat.equipes[k]
		if not eq.onze.is_empty() and h.chance(0.0016):
			var touche: Dictionary = h.choix(eq.onze)
			_ajouter(etat, "blessure", k, phrase(h, "blessure", {"j": nom_court(joueurs[touche.id])}), {"joueur": touche.id})
			_retirer(etat, k, touche.id, "blessure", joueurs, h)

	var domicile := 1.03 if i == 0 else 1.0
	var ratio := clampf(pow(fa.attaque * domicile / fo.defense, 2), 0.3, 3.0)
	if not h.chance(CHANCE_BASE * ratio):
		if h.chance(0.12):
			var acteur = _choisir_passeur(att, joueurs, h)
			if acteur != null:
				_ajouter(etat, "ambiance", i, phrase(h, "ambiance", {"e": att.nom, "o": def.nom, "s": etat.stade, "j": nom_court(joueurs[acteur.id])}))
		return
	_occasion(etat, i, joueurs, h)


static func _expulser(etat: Dictionary, i: int, id, cle: String, joueurs: Dictionary, h: Hasard) -> void:
	var eq: Dictionary = etat.equipes[i]
	etat.stats[i].rouges += 1
	_noter(eq, id, -1.5)
	_ajouter(etat, "rouge", i, phrase(h, cle, {"j": nom_court(joueurs[id]), "e": eq.nom}), {"joueur": id})
	_retirer(etat, i, id, "rouge", joueurs, h)


static func _occasion(etat: Dictionary, i: int, joueurs: Dictionary, h: Hasard) -> void:
	var att: Dictionary = etat.equipes[i]
	var def: Dictionary = etat.equipes[1 - i]
	var tireur = _choisir_tireur(att, joueurs, h)
	if tireur == null:
		return
	var passeur = _choisir_passeur(att, joueurs, h, tireur.id) if h.chance(0.72) else null
	var g = _gardien_de(def)
	var nj := nom_court(joueurs[tireur.id])
	var na := nom_court(joueurs[passeur.id]) if passeur != null else ""
	var ng := nom_court(joueurs[g.id]) if g != null else "le gardien improvisé"
	var eff_tir := _eff(att, joueurs, tireur.id, "M" if tireur.poste == "G" else tireur.poste)
	var eff_g := _eff(def, joueurs, g.id, "G") if g != null else 25.0
	var vars := {"j": nj, "a": na if na != "" else "un partenaire", "g": ng, "e": att.nom, "o": def.nom}
	etat.stats[i].tirs += 1

	# Le penalty.
	if h.chance(0.03):
		_ajouter(etat, "occasion", i, phrase(h, "penaltyObtenu", vars))
		etat.stats[i].cadres += 1
		var p := clampf(0.76 + (eff_tir - eff_g) / 200.0, 0.6, 0.88)
		if h.chance(p):
			_marquer(etat, i, tireur.id, null, "butPenalty", vars, joueurs, h)
		else:
			if g != null:
				_noter(def, g.id, 0.8)
			_ajouter(etat, "rate", i, phrase(h, "penaltyRate", vars))
		return

	var sur_corner: bool = passeur != null and h.chance(0.15)
	_ajouter(etat, "occasion", i, phrase(h, "corner" if sur_corner else ("occasion" if passeur != null else "occasionSolo"), vars))
	if sur_corner:
		etat.stats[i].corners += 1
	var cadre := h.chance(clampf(0.45 * sqrt(eff_tir / 68.0), 0.25, 0.6))
	if not cadre:
		if h.chance(0.06):
			_ajouter(etat, "poteau", i, phrase(h, "poteau", vars))
		else:
			_ajouter(etat, "rate", i, phrase(h, "rate", vars))
		if h.chance(0.25):
			etat.stats[i].corners += 1
		return
	etat.stats[i].cadres += 1
	var p_but := clampf(0.4 * pow(eff_tir / maxf(eff_g, 20.0), 1.3), 0.12, 0.72)
	if h.chance(p_but):
		_marquer(etat, i, tireur.id, passeur.id if passeur != null else null, "butTete" if sur_corner else "but", vars, joueurs, h)
	else:
		if g != null:
			_noter(def, g.id, 0.3)
		_ajouter(etat, "arret", i, phrase(h, "arret", vars))
		if h.chance(0.35):
			etat.stats[i].corners += 1


static func _marquer(etat: Dictionary, i: int, buteur, passeur, cle: String, vars: Dictionary, joueurs: Dictionary, h: Hasard) -> void:
	var att: Dictionary = etat.equipes[i]
	var def: Dictionary = etat.equipes[1 - i]
	etat.score[i] += 1
	var v := vars.duplicate()
	v.sc = score_texte(etat)
	_ajouter(etat, "but", i, phrase(h, cle, v), {"joueur": buteur, "passeur": passeur})
	if passeur != null:
		_ajouter(etat, "info", i, phrase(h, "passeur", vars))
	etat.buts.append({"equipe": i, "minute": libelle_minute(etat), "buteur": buteur, "passeur": passeur, "penalty": cle == "butPenalty"})
	_noter(att, buteur, 1.0)
	if passeur != null:
		_noter(att, passeur, 0.6)
	for e in def.onze:
		if e.poste == "G":
			_noter(def, e.id, -0.4)
		elif e.poste == "D":
			_noter(def, e.id, -0.15)


static func _cloturer(etat: Dictionary) -> void:
	for i in 2:
		var eq: Dictionary = etat.equipes[i]
		var bonus := 0.3 if etat.score[i] > etat.score[1 - i] else (-0.3 if etat.score[i] < etat.score[1 - i] else 0.0)
		var encaisse: int = etat.score[1 - i]
		for id in eq.notes:
			eq.notes[id] = roundf(clampf(eq.notes[id] + bonus + (0.2 if encaisse == 0 else 0.0), 3.0, 10.0) * 10.0) / 10.0


## Le match joué d'une traite.
static func simuler(etat: Dictionary, joueurs: Dictionary, h: Hasard) -> Dictionary:
	while not etat.fini:
		avancer(etat, joueurs, h)
	return etat


static func possession(etat: Dictionary) -> Array:
	var a: int = etat.stats[0].possession
	var b: int = etat.stats[1].possession
	var total: int = maxi(a + b, 1)
	var pa := int(roundf(100.0 * a / total))
	return [pa, 100 - pa]
