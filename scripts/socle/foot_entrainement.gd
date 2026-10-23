class_name FootEntrainement
extends RefCounted
## L'entraînement de la semaine (demande de Guillaume du 23 octobre 2026 : un bureau « réellement addictif, à
## la Football Manager »). Celui qui dirige le club choisit un programme pour la semaine qui mène au match ;
## les joueurs y progressent, les jeunes beaucoup, les anciens à peine, et chacun surtout dans ce que son
## poste lui fait travailler. Le choix voyage dans la consigne du match (clé « entrainement », dans le détail
## que le serveur garde déjà) : tout le monde calcule les mêmes progrès, et donc les mêmes matchs.
##
## Le programme d'une journée compte une fois le match joué : l'effectif de la journée j porte les semaines
## 1 à j - 1 de la saison, et celui d'une saison nouvelle porte toute la saison d'avant. Sans consigne, l'adjoint
## fait travailler « Général » : tous les clubs progressent un peu, celui qu'on dirige progresse où l'on veut.
## Ici rien ne dépend des autoloads : Football fournit les programmes de chaque semaine.

const DEFAUT := "general"
## Les programmes : le nom, une phrase, les compétences travaillées, et ce que chaque poste en retire.
const PROGRAMMES := {
	"general": {"nom": "Général", "phrase": "Un peu de tout : chacun entretient tout son jeu, sans rien pousser.",
		"competences": ["gardien", "defense", "jeu", "aile", "passe", "but", "cpa", "endurance"], "postes": {"G": 1.0, "D": 1.0, "M": 1.0, "A": 1.0}},
	"defense": {"nom": "Défense", "phrase": "Le placement, les duels, la ligne qui monte ensemble.",
		"competences": ["defense"], "postes": {"G": 0.3, "D": 1.0, "M": 0.6, "A": 0.25}},
	"gardiens": {"nom": "Gardiens", "phrase": "Les gardiens à part, avec l'entraîneur des gardiens ; les autres font tourner.",
		"competences": ["gardien"], "postes": {"G": 1.3, "D": 0.0, "M": 0.0, "A": 0.0}},
	"construction": {"nom": "Construction", "phrase": "Le jeu au sol, les passes courtes, la conservation.",
		"competences": ["jeu", "passe"], "postes": {"G": 0.2, "D": 0.5, "M": 1.0, "A": 0.6}},
	"ailes": {"nom": "Jeu sur les ailes", "phrase": "Les débordements, les centres, les latéraux qui montent.",
		"competences": ["aile"], "postes": {"G": 0.0, "D": 0.7, "M": 1.0, "A": 0.8}},
	"finition": {"nom": "Finition", "phrase": "Devant le but, encore et encore : la frappe, la tête, le sang-froid.",
		"competences": ["but"], "postes": {"G": 0.0, "D": 0.2, "M": 0.6, "A": 1.0}},
	"cpa": {"nom": "Coups de pied arrêtés", "phrase": "Les corners, les coups francs, les penaltys : tout le monde y passe.",
		"competences": ["cpa"], "postes": {"G": 0.7, "D": 0.7, "M": 0.7, "A": 0.7}},
	"physique": {"nom": "Physique", "phrase": "Le foncier, les fractionnés : on tient mieux la dernière demi-heure.",
		"competences": ["endurance"], "postes": {"G": 0.6, "D": 1.0, "M": 1.0, "A": 1.0}},
}
## Ce qu'une semaine fait gagner, en points de compétence (cinq points font un cran), à un joueur de vingt
## et un ans du bon poste : un programme ciblé le pousse, le général l'entretient.
const GAIN_CIBLE := 0.75
const GAIN_GENERAL := 0.06
## La note suit les compétences que le poste valorise : un défenseur qui gagne en défense gagne en note
## (un tiers de point par semaine à vingt et un ans ; le général, moitié moins).
const PART_NOTE := 0.4


## Le programme propre d'une consigne (le défaut si rien ou inconnu).
static func programme(cle) -> String:
	return str(cle) if PROGRAMMES.has(str(cle)) else DEFAUT


## Ce que l'âge laisse progresser : un jeune de dix-neuf ans gagne huit fois plus qu'un vétéran.
static func facteur_age(age: int) -> float:
	if age <= 19:
		return 1.25
	if age <= 21:
		return 1.0
	if age <= 23:
		return 0.8
	if age <= 26:
		return 0.6
	if age <= 29:
		return 0.4
	if age <= 32:
		return 0.25
	return 0.15


## Le gain d'une semaine pour un joueur : {competence: points}, et « note ».
static func gains(j: Dictionary, prog: String) -> Dictionary:
	var p: Dictionary = PROGRAMMES[programme(prog)]
	var poste := str(j.get("poste", "M"))
	var k: float = facteur_age(int(j.get("age", 25))) * float(p.postes.get(poste, 0.0))
	var out := {}
	if k <= 0.0:
		return out
	var base: float = GAIN_GENERAL if prog == DEFAUT else GAIN_CIBLE / float(p.competences.size()) * (1.4 if p.competences.size() > 1 else 1.0)
	var profil: Dictionary = FootMatch.PROFILS.get(poste, FootMatch.PROFILS.M)
	var somme := 0.0
	for c in profil:
		somme += float(profil[c])
	var note := 0.0
	for c in p.competences:
		var g: float = base * k
		out[c] = g
		note += g * float(profil.get(c, 0.5))
	out["note"] = note * PART_NOTE * 6.0 / maxf(somme, 1.0)
	return out


## Fait travailler un joueur (sur place) une semaine du programme donné. Les compétences restent des nombres
## à virgule : on progresse par petites touches, le cran tombe quand il tombe.
static func travailler(j: Dictionary, prog: String) -> void:
	var g := gains(j, prog)
	if g.is_empty():
		return
	if not j.has("competences"):
		j["competences"] = FootMatch.tirer_competences(j, Hasard.depuis(1))
	for c in g:
		if c == "note":
			j.note = clampf(float(j.note) + float(g.note), 30.0, 95.0)
		else:
			j.competences[c] = clampf(float(j.competences.get(c, FootMatch.competence(j, c))) + float(g[c]), 10.0, 99.0)


## Fait travailler tout un effectif (sur place) plusieurs semaines : programmes, une clé par semaine, dans l'ordre.
static func appliquer(effectif: Dictionary, programmes: Array) -> void:
	for prog in programmes:
		for id in effectif:
			travailler(effectif[id], programme(prog))


## Ce qu'un joueur a gagné entre deux états de lui-même : {competence: delta} pour les compétences qui ont
## bougé d'un cran au moins (cran : cinq points), et les crans d'avant et d'après.
static func crans_gagnes(avant: Dictionary, apres: Dictionary) -> Array:
	var out: Array = []
	for c in FootMatch.COMPETENCES:
		var a := int(floor(FootMatch.competence(avant, c) / 5.0))
		var b := int(floor(FootMatch.competence(apres, c) / 5.0))
		if b != a:
			out.append({"competence": c, "avant": a, "apres": b})
	return out


## Où en est un joueur vers le cran suivant d'une compétence, de 0 à 1.
static func vers_cran(v: float) -> float:
	return fposmod(v, 5.0) / 5.0
