class_name BasketMatch
extends RefCounted
## Le match de basket, possession par possession, nourri par les notes des vrais joueurs (le cliché de
## la semaine que publie la fonction « basket » du serveur ; spec : basket/spec-basket-reel.md du projet).
## Tout vient d'un Hasard : à cliché et graine égaux, même match chez tout le monde, comme FootMatch.
## Rien ne dépend des autoloads : on lui donne les deux équipes et la graine.
##
## Une équipe : {"nom", "joueurs": [{"code", "nom", "note", "profil": [extérieur, intérieur, rebond,
## création, défense], "dispo"}], "consigne": "titulaires" | "rotation"}. Notes et profil vont de 1 à 99.
## Les absents (dispo faux) ne jouent pas ; moins de cinq présents, des joueurs du village complètent.

const QUARTS := 4
const MINUTES_QUART := 10
const MINUTES_PROLONGATION := 5
## Les rotations : on refait les cinq sur le terrain toutes les 5 minutes.
const TRANCHE := 5
const POSSESSIONS_PAR_MINUTE := 1.8
const NOTE_VILLAGE := 25
const AVANTAGE_DOMICILE := 0.015
const PERTE_BASE := 0.13
const FAUTE_BASE := 0.11
const REUSSITE_2 := 0.51
const REUSSITE_3 := 0.35
const REUSSITE_LF := 0.76
const REBOND_OFFENSIF := 0.27
const PASSE_DECISIVE := 0.58
## Minutes visées pour un joueur selon son rang dans l'équipe, de la meilleure note à la moins bonne.
const MINUTES_VISEES := {
	"titulaires": [33, 32, 31, 30, 29, 18, 13, 8, 4, 2],
	"rotation": [27, 26, 26, 25, 25, 22, 20, 16, 7, 6],
}
const EXT := 0
const INT := 1
const REB := 2
const CRE := 3
const DEF := 4


## Joue le match. Rend {"score": [domicile, extérieur], "quarts": [[d, e], …], "prolongations": n,
## "joueurs": [[{code, nom, min, pts, reb, pd, int, ct, bp, t2, t3, lf}, …], […]]}.
static func jouer(domicile: Dictionary, exterieur: Dictionary, graine: int) -> Dictionary:
	var h := Hasard.depuis(graine)
	var eq := [_preparer(domicile), _preparer(exterieur)]
	var score := [0, 0]
	var quarts: Array = []
	var periode := 0
	var prolongations := 0
	var attaque := 0 if h.chance(0.5) else 1
	while periode < QUARTS or score[0] == score[1]:
		var duree := MINUTES_QUART if periode < QUARTS else MINUTES_PROLONGATION
		if periode >= QUARTS:
			prolongations += 1
		var avant := score.duplicate()
		var minute := 0
		while minute < duree:
			var tranche := mini(TRANCHE, duree - minute)
			var terrain := [_cinq(eq[0], tranche), _cinq(eq[1], tranche)]
			var possessions := int(round(tranche * POSSESSIONS_PAR_MINUTE * 2.0))
			for p in possessions:
				score[attaque] += _possession(h, terrain[attaque], terrain[1 - attaque], attaque == 0)
				attaque = 1 - attaque
			minute += tranche
		quarts.append([score[0] - avant[0], score[1] - avant[1]])
		periode += 1
	return {"score": score, "quarts": quarts, "prolongations": prolongations,
		"joueurs": [_feuille(eq[0]), _feuille(eq[1])]}


## Les présents, triés par note (puis par code, pour ne rien laisser au hasard), complétés par des joueurs
## du village jusqu'à cinq, chacun avec ses minutes visées.
static func _preparer(e: Dictionary) -> Array:
	var presents: Array = []
	for j in e.get("joueurs", []):
		if j.get("dispo", true):
			presents.append(j)
	presents.sort_custom(func(a, b): return a.note > b.note if a.note != b.note else str(a.code) < str(b.code))
	presents = presents.slice(0, 10)
	var n := 0
	while presents.size() < 5:
		n += 1
		presents.append({"code": "village-%d" % n, "nom": "Joueur du village %d" % n, "note": NOTE_VILLAGE,
			"profil": [NOTE_VILLAGE, NOTE_VILLAGE, NOTE_VILLAGE, NOTE_VILLAGE, NOTE_VILLAGE]})
	var visees: Array = MINUTES_VISEES.get(str(e.get("consigne", "titulaires")), MINUTES_VISEES.titulaires)
	var total := 0.0
	for i in presents.size():
		total += visees[i]
	var out: Array = []
	for i in presents.size():
		var j: Dictionary = presents[i]
		# Les minutes visées remplissent toujours les 200 minutes du match, même à cinq ou six.
		out.append({"j": j, "visees": visees[i] * 200.0 / total, "min": 0.0,
			"pts": 0, "reb": 0, "pd": 0, "int": 0, "ct": 0, "bp": 0, "t2": [0, 0], "t3": [0, 0], "lf": [0, 0]})
	return out


## Les cinq qui jouent la tranche : ceux à qui il reste le plus de minutes visées.
static func _cinq(eq: Array, tranche: int) -> Array:
	var ordre := range(eq.size())
	ordre.sort_custom(func(a, b):
		var ra: float = eq[a].visees - eq[a].min
		var rb: float = eq[b].visees - eq[b].min
		return ra > rb if ra != rb else a < b)
	var cinq: Array = []
	for i in ordre.slice(0, 5):
		eq[i].min += tranche
		cinq.append(eq[i])
	return cinq


static func _moyenne(cinq: Array, k: int) -> float:
	var s := 0.0
	for x in cinq:
		s += float(x.j.profil[k])
	return s / cinq.size()


static func _note(cinq: Array) -> float:
	var s := 0.0
	for x in cinq:
		s += float(x.j.note)
	return s / cinq.size()


## Une possession : rend les points marqués. Pertes, tirs à 2 et 3 points, fautes et lancers, rebonds
## offensifs (la possession continue), passes décisives.
static func _possession(h: Hasard, att: Array, dfn: Array, domicile: bool) -> int:
	var ecart := (_note(att) - _note(dfn)) / 50.0
	var bonus := AVANTAGE_DOMICILE if domicile else -AVANTAGE_DOMICILE
	for essai in 3:
		var perte := PERTE_BASE * (1.0 - 0.25 * (_moyenne(att, CRE) - 50.0) / 50.0 + 0.25 * (_moyenne(dfn, DEF) - 50.0) / 50.0 - 0.2 * ecart)
		if essai == 0 and h.chance(clampf(perte, 0.05, 0.25)):
			var porteur: Dictionary = h.pondere(att, func(x): return 10.0 + float(x.j.profil[CRE]))
			porteur.bp += 1
			if h.chance(0.55):
				var voleur: Dictionary = h.pondere(dfn, func(x): return 10.0 + float(x.j.profil[DEF]))
				voleur.int += 1
			return 0
		var tireur: Dictionary = h.pondere(att, func(x): return pow(float(x.j.note) + 15.0, 1.6))
		var ext := float(tireur.j.profil[EXT])
		var inte := float(tireur.j.profil[INT])
		if h.chance(clampf(FAUTE_BASE * (0.6 + 0.8 * inte / 100.0), 0.04, 0.2)):
			var pts := 0
			for lf in 2:
				tireur.lf[1] += 1
				if h.chance(clampf(REUSSITE_LF + 0.08 * (ext - 50.0) / 50.0, 0.5, 0.92)):
					tireur.lf[0] += 1
					pts += 1
			tireur.pts += pts
			return pts
		var trois := h.chance(clampf(0.12 + 0.42 * ext / (ext + inte), 0.05, 0.6))
		var defense := (_moyenne(dfn, DEF) - 50.0) / 50.0
		var reussite: float
		if trois:
			reussite = REUSSITE_3 + 0.09 * (ext - 50.0) / 50.0
		else:
			reussite = REUSSITE_2 + 0.08 * (inte - 50.0) / 50.0
		reussite += 0.05 * ecart - 0.03 * defense + bonus
		var tir: Array = tireur.t3 if trois else tireur.t2
		tir[1] += 1
		if h.chance(clampf(reussite, 0.15, 0.75)):
			tir[0] += 1
			var pts := 3 if trois else 2
			tireur.pts += pts
			if h.chance(PASSE_DECISIVE):
				var autres := att.filter(func(x): return x != tireur)
				var passeur: Dictionary = h.pondere(autres, func(x): return 5.0 + float(x.j.profil[CRE]))
				passeur.pd += 1
			return pts
		if not trois and h.chance(0.06 + 0.05 * defense):
			var contreur: Dictionary = h.pondere(dfn, func(x): return 5.0 + float(x.j.profil[DEF]) + float(x.j.profil[REB]))
			contreur.ct += 1
		var offensif := REBOND_OFFENSIF * (1.0 + 0.5 * (_moyenne(att, REB) - _moyenne(dfn, REB)) / 50.0)
		var preneurs := att if h.chance(clampf(offensif, 0.12, 0.45)) else dfn
		var rebondeur: Dictionary = h.pondere(preneurs, func(x): return 5.0 + float(x.j.profil[REB]))
		rebondeur.reb += 1
		if preneurs == dfn:
			return 0
	return 0


static func _feuille(eq: Array) -> Array:
	var out: Array = []
	for x in eq:
		out.append({"code": x.j.code, "nom": x.j.nom, "min": int(x.min), "pts": x.pts, "reb": x.reb, "pd": x.pd,
			"int": x.int, "ct": x.ct, "bp": x.bp, "t2": x.t2, "t3": x.t3, "lf": x.lf})
	return out
