class_name Avatar
extends RefCounted
## L'allure du joueur, qu'il fait retoucher en ville (fiche : docs/AVATAR.md). La tenue reste un bien
## (Biens.worn) ; par-dessus, des réglages qu'on paie chez ceux qui savent les faire :
## - chez un couturier (Raymonde, et tout commerce de tenues d'une commune) : la coupe et la couleur du haut
##   et du bas, le chapeau, ce qu'on porte au cou, les lunettes ;
## - chez la coiffeuse (Gisèle) : la coupe, la couleur des cheveux, la moustache ou la barbe ;
## - chez le chirurgien (le docteur Maupas) : le sexe, le teint, le nez, la taille ;
## - à la salle de sport (Smarves Forme) : on perd des crans de corpulence ;
## - au restaurant (la Pizzeria du Clain) : on en prend.
##
## Les réglages sont rangés dans les biens (Biens.avatar, sauvegardés avec eux et donc avec le compte) :
## un dictionnaire épars {champ: indice}, où ne figure que ce qui diffère du joueur d'origine. Les autres
## joueurs les voient par la présence (Presences), qui ne porte qu'un mot [a-z0-9_]{0,40} : la tenue,
## puis « __ » et un code d'une lettre par champ (code(), decoder()). Un ancien jeu qui reçoit ce mot ne
## connaît pas la tenue et montre le costume bleu nuit, comme pour une tenue d'une commune.
##
## Les communes s'en servent sans rien déclarer : Prestation.ouvrir(métier, options) ouvre la boutique du
## socle, Prestation.panneau(métier, options) donne le panneau seul (scripts/socle/prestation.gd).

## Les champs, dans l'ordre du code. [champ, défaut, décalage] : le décalage fait d'un indice négatif une
## lettre (-1 : « comme la tenue » ; la corpulence va de -3 à +4).
const CHAMPS := [
	["sexe", 0, 0], ["peau", 0, 0], ["nez", 0, 0], ["taille", 1, 0], ["poids", 0, 3],
	["coupe", 1, 0], ["cheveux", 6, 0], ["pilosite", 0, 0],
	["haut", -1, 1], ["couleur_haut", -1, 1], ["bas", -1, 1], ["couleur_bas", -1, 1],
	["chapeau", -1, 1], ["cou", -1, 1], ["lunettes", -1, 1],
]
## La version du code : la première lettre après « __ ».
const VERSION := "a"
const SEPARATEUR := "__"
const CHIFFRES := "0123456789abcdefghijklmnopqrstuvwxyz"

## Les choix de chaque champ : [valeur, libellé]. L'indice est ce qu'on garde.
const SEXES := [["h", "homme"], ["f", "femme"]]
const PEAUX := [["#f3d6bd", "clair"], ["#eac4a2", "rosé"], ["#e0b08a", "doré"], ["#c99068", "mat"], ["#a8714c", "hâlé"],
	["#f6e0cf", "porcelaine"], ["#8a5a3a", "brun"], ["#6a4430", "ébène"]]
const NEZ := [["rond", "rond"], ["patate", "en patate"], ["long", "long"], ["busque", "busqué"], ["retrousse", "retroussé"]]
## La taille : le facteur des jambes (le joueur d'origine est à 1,02).
const TAILLES := [[0.92, "petit"], [1.02, "moyen"], [1.12, "grand"]]
## La corpulence, de -3 à +4 : [ventre, carrure, libellé].
const POIDS_MIN := -3
const POIDS_MAX := 4
const CORPULENCES := {-3: [0.74, 0.84, "sec comme un coup de trique"], -2: [0.82, 0.9, "mince"], -1: [0.91, 0.95, "svelte"],
	0: [1.0, 1.0, "dans la moyenne"], 1: [1.18, 1.06, "bien portant"], 2: [1.36, 1.12, "enveloppé"], 3: [1.55, 1.18, "rond"],
	4: [1.75, 1.25, "très rond"]}
const COUPES := [["court", "court"], ["raie", "à la raie"], ["houppe", "à la houppe"], ["gomina", "gominé"],
	["degarni", "dégarni"], ["chauve", "chauve"], ["brushing", "brushing"], ["carre", "carré"], ["permanente", "permanente"],
	["chignon", "chignon"], ["queue", "queue-de-cheval"], ["frange", "à frange"]]
const CHEVEUX := [["#16141a", "noir"], ["#2a2420", "brun"], ["#4a3426", "châtain"], ["#6a4a32", "châtain clair"],
	["#8a6a45", "blond foncé"], ["#c8a050", "blond"], ["#c8642e", "roux"], ["#9a4a2a", "auburn"], ["#8a8278", "poivre et sel"],
	["#c8c4bc", "gris"], ["#e8e2d8", "blanc"]]
## La pilosité : ce qu'elle met dans « face ».
const PILOSITES := [[[], "rasé de près"], [["moustache"], "moustache"], [["barbe", "moustache"], "barbe"], [["favoris"], "favoris"],
	[["bouc"], "bouc"]]
const HAUTS := [["veste", "veste"], ["gilet", "gilet"], ["pull", "pull"], ["chemise", "chemise"], ["mariniere", "marinière"],
	["smoking", "smoking"], ["robe", "robe"]]
const COULEURS := [["#1d2a55", "bleu nuit"], ["#2f5aa8", "bleu de travail"], ["#16151b", "noir"], ["#f4f1ea", "blanc cassé"],
	["#efe6d2", "crème"], ["#7a1f30", "bordeaux"], ["#b8402e", "brique"], ["#d1a23a", "moutarde"], ["#2e5a40", "vert bouteille"],
	["#3a3b44", "anthracite"], ["#8b5a2b", "tabac"], ["#8a7bb8", "lavande"], ["#d98f9c", "rose"], ["#7d7566", "prince-de-galles"]]
const BAS := [["pantalon", "pantalon"], ["jupe", "jupe"]]
## Les chapeaux : [forme, libellé, couleur, ruban].
const CHAPEAUX := [["", "tête nue", "", ""], ["beret", "béret", "#1f1d24", ""], ["casquette", "casquette", "#3a3b44", ""],
	["canotier", "canotier", "#e6c66e", "#1d2a55"], ["feutre", "feutre", "#1c1a20", "#7a1f30"],
	["haut_de_forme", "haut-de-forme", "#141318", "#d4a443"], ["cloche", "cloche", "#174f3e", "#d4a443"], ["fleur", "fleur", "#d06a8a", "#d4a443"]]
const COUS := [["", "col ouvert"], ["noeud", "nœud papillon"], ["cravate", "cravate"], ["foulard", "foulard"], ["collier", "collier"]]
## Les lunettes : [ce qu'elles mettent dans « face », libellé, monture].
const LUNETTES := [["", "sans lunettes", ""], ["lunettes", "lunettes", "#2a2224"], ["demi_lune", "demi-lunes", "#d4a443"],
	["monocle", "monocle", "#d4a443"]]

## Les métiers et ce qu'ils retouchent. « champs » : les réglages qu'on choisit dans la liste ; « formules » :
## ce qu'on achète d'un coup (la corpulence). Les prix sont ceux de Smarves ; une commune les multiplie
## par son « tarif ».
const METIERS := {
	"couture": {"nom": "La cabine d'essayage", "champs": {"couleur_haut": 80, "couleur_bas": 60, "haut": 250, "bas": 150,
		"chapeau": 120, "cou": 60, "lunettes": 90}},
	"coiffure": {"nom": "Le fauteuil de la coiffeuse", "champs": {"coupe": 60, "cheveux": 90, "pilosite": 40}},
	"chirurgie": {"nom": "Le cabinet du chirurgien", "champs": {"nez": 1500, "peau": 2500, "taille": 4000, "sexe": 6000}},
	"sport": {"nom": "La salle de sport", "formules": [
		{"id": "seance", "nom": "La séance d'haltères", "prix": 200, "poids": -1, "dit": "« Une heure de fonte, et le pantalon flotte déjà. »"},
		{"id": "stage", "nom": "La semaine de stage", "prix": 500, "poids": -2, "dit": "« Footing au bord du Clain à six heures. Vous me remercierez. »"},
		{"id": "coach", "nom": "Le coach particulier", "prix": 1200, "poids": -3, "dit": "« Je ne vous lâche plus. Même au casino, je compte vos petits-fours. »"}]},
	"restaurant": {"nom": "Le restaurant", "formules": [
		{"id": "plat", "nom": "La pizza du jour", "prix": 40, "poids": 1, "dit": "« Et une pizza pour la trois ! Avec un supplément de fromage, c'est la maison qui offre. »"},
		{"id": "menu", "nom": "Le menu complet", "prix": 110, "poids": 2, "dit": "« Entrée, pizza, tiramisu. Le digestif, je vous l'offre si vous gagnez ce soir. »"},
		{"id": "festin", "nom": "Le festin du samedi", "prix": 260, "poids": 3, "dit": "« Quatre plats, et le gâteau de la patronne. On roule jusqu'au casino. »"}]},
}

## Les libellés des champs, pour les panneaux.
const LIBELLES := {"sexe": "Le sexe", "peau": "Le teint", "nez": "Le nez", "taille": "La taille", "poids": "La corpulence",
	"coupe": "La coupe", "cheveux": "La couleur des cheveux", "pilosite": "La moustache, la barbe",
	"haut": "Le haut", "couleur_haut": "La couleur du haut", "bas": "Le bas", "couleur_bas": "La couleur du bas",
	"chapeau": "Le chapeau", "cou": "Au cou", "lunettes": "Les lunettes"}

## Les champs de vêtements, qu'un changement de tenue remet comme la tenue (les accessoires restent).
const VETEMENTS := ["haut", "couleur_haut", "bas", "couleur_bas"]


# --- Les choix -------------------------------------------------------------------------------------

static func defaut(champ: String) -> int:
	for c in CHAMPS:
		if c[0] == champ:
			return int(c[1])
	return 0


## Les choix d'un champ : un tableau de [valeur, libellé, …] (la corpulence n'en a pas : voir CORPULENCES).
static func choix(champ: String) -> Array:
	match champ:
		"sexe": return SEXES
		"peau": return PEAUX
		"nez": return NEZ
		"taille": return TAILLES
		"coupe": return COUPES
		"cheveux": return CHEVEUX
		"pilosite": return PILOSITES
		"haut": return HAUTS
		"couleur_haut", "couleur_bas": return COULEURS
		"bas": return BAS
		"chapeau": return CHAPEAUX
		"cou": return COUS
		"lunettes": return LUNETTES
	return []


## Les bornes d'un champ : [plus petit indice, plus grand].
static func bornes(champ: String) -> Vector2i:
	if champ == "poids":
		return Vector2i(POIDS_MIN, POIDS_MAX)
	var bas := -1 if champ in ["haut", "couleur_haut", "bas", "couleur_bas", "chapeau", "cou", "lunettes"] else 0
	return Vector2i(bas, choix(champ).size() - 1)


## La valeur d'un champ dans des réglages (le défaut s'il manque ou s'il sort des bornes).
static func valeur(reglages: Dictionary, champ: String) -> int:
	var v := int(reglages.get(champ, defaut(champ)))
	var b := bornes(champ)
	return v if v >= b.x and v <= b.y else defaut(champ)


## Le libellé d'une valeur (« roux », « comme la tenue », « enveloppé »).
static func libelle(champ: String, v: int) -> String:
	if champ == "poids":
		return str(CORPULENCES[clampi(v, POIDS_MIN, POIDS_MAX)][2])
	if v < 0:
		return "comme la tenue"
	var c := choix(champ)
	return str(c[v][1]) if v < c.size() else ""


## Les coupes d'homme (les six premières) et de femme (les autres) : au changement de sexe, le chirurgien
## remet une coupe qui va, si l'ancienne n'allait qu'à l'autre (la coiffeuse les propose toutes).
static func coupe_pour(coupe: int, femme: bool) -> int:
	if femme and coupe < 6:
		return 7
	if not femme and coupe >= 6:
		return 1
	return coupe


## Les réglages nettoyés : seulement les champs connus, dans leurs bornes, et différents du défaut.
static func nettoyer(reglages: Variant) -> Dictionary:
	var out := {}
	if not reglages is Dictionary:
		return out
	for c in CHAMPS:
		if (reglages as Dictionary).has(c[0]):
			var v := valeur(reglages, c[0])
			if v != int(c[1]):
				out[c[0]] = v
	return out


# --- La fiche du personnage ------------------------------------------------------------------------

## La fiche (Cast) du joueur dans sa tenue, retouchée par ses réglages.
static func fiche(tenue: String, reglages: Dictionary) -> Dictionary:
	var l: Dictionary = Cast.player(tenue).duplicate(true)
	return appliquer(l, reglages)


## Applique des réglages à une fiche de joueur (Cast.player) ; rend la fiche.
static func appliquer(l: Dictionary, reglages: Dictionary) -> Dictionary:
	var r := nettoyer(reglages)
	if r.is_empty():
		return l
	var femme := valeur(r, "sexe") == 1
	# Le corps.
	l.fur = PEAUX[valeur(r, "peau")][0]
	l.nose = NEZ[valeur(r, "nez")][0]
	var corps: Array = CORPULENCES[valeur(r, "poids")]
	var build: Dictionary = (l.get("build", {}) as Dictionary).duplicate()
	build.leg = TAILLES[valeur(r, "taille")][0]
	build.belly = float(build.get("belly", 1.0)) * float(corps[0])
	build.width = float(build.get("width", 1.0)) * float(corps[1]) * (0.93 if femme else 1.0)
	l.build = build
	# La tête.
	l.hair = COUPES[valeur(r, "coupe")][0]
	l.hair_color = CHEVEUX[valeur(r, "cheveux")][0]
	var visage: Array = []
	if not femme:
		visage.append_array(PILOSITES[valeur(r, "pilosite")][0])
		if visage.has("moustache"):
			l.moustache = l.hair_color
	else:
		l.lip = "#a3172b"
	var lu := valeur(r, "lunettes")
	if lu > 0:
		visage.append(LUNETTES[lu][0])
		l.frame = LUNETTES[lu][2]
	elif lu < 0:
		for f in l.get("face", []):
			if not f in ["moustache", "barbe", "favoris", "bouc"]:
				visage.append(f)
	l.face = visage
	# Les vêtements, par-dessus la tenue.
	var haut := valeur(r, "haut")
	if haut >= 0:
		l.top = HAUTS[haut][0]
		match l.top:
			"robe":
				l.skirt_len = 0.62
				l.sleeves = "longues"
			"chemise", "pull", "mariniere":
				l.sleeves = "longues"
				l.top2 = "#f4f1ea"
	var ch := valeur(r, "couleur_haut")
	if ch >= 0:
		l.top_color = COULEURS[ch][0]
		l.lapel = Color(COULEURS[ch][0]).darkened(0.12).to_html(false)
		if l.top == "mariniere":
			l.top2 = "#f4f1ea"
	var bas := valeur(r, "bas")
	var cb := valeur(r, "couleur_bas")
	if bas == 1 and l.get("top", "") != "robe":
		l.erase("legs")
		l.skirt = true
		l.skirt_len = 0.55
		l.skirt_color = COULEURS[cb][0] if cb >= 0 else l.get("legs_color", "#1d2a55")
	elif cb >= 0:
		l.legs_color = COULEURS[cb][0]
		if l.get("top", "") == "robe":
			l.skirt_color = COULEURS[cb][0]
	var chap := valeur(r, "chapeau")
	if chap >= 0:
		var c: Array = CHAPEAUX[chap]
		l.hat = c[0]
		if c[0] != "":
			l.hat_color = c[2]
			if c[3] != "":
				l.hat_band = c[3]
	var cou := valeur(r, "cou")
	if cou >= 0:
		l.neck = COUS[cou][0]
		if COUS[cou][0] != "" and not l.has("neck_color"):
			l.neck_color = "#d4a443"
	return l


# --- Le code de la présence ------------------------------------------------------------------------

## Le code des réglages : « a » puis une lettre par champ ; « » pour le joueur d'origine.
static func code(reglages: Dictionary) -> String:
	var r := nettoyer(reglages)
	if r.is_empty():
		return ""
	var s := VERSION
	for c in CHAMPS:
		s += CHIFFRES[clampi(valeur(r, c[0]) + int(c[2]), 0, CHIFFRES.length() - 1)]
	return s


## Les réglages d'un code (un code inconnu ou abîmé rend le joueur d'origine, champ par champ).
static func decoder(c: String) -> Dictionary:
	var out := {}
	if not c.begins_with(VERSION):
		return out
	for i in CHAMPS.size():
		if i + 1 >= c.length():
			break
		var n := CHIFFRES.find(c[i + 1])
		if n < 0:
			continue
		out[CHAMPS[i][0]] = n - int(CHAMPS[i][2])
	return nettoyer(out)


## Le mot de la présence : la tenue, puis « __ » et le code (la tenue tombe si le mot dépasserait 40
## lettres, ou si elle n'est pas un mot simple, comme celles des communes).
static func mot(tenue: String, reglages: Dictionary) -> String:
	var t := tenue if tenue.length() <= 40 and tenue.is_valid_ascii_identifier() and tenue == tenue.to_lower() else ""
	var c := code(reglages)
	if c == "":
		return t
	if t.length() + SEPARATEUR.length() + c.length() > 40:
		t = ""
	return t + SEPARATEUR + c


## Le mot d'une présence en [tenue, réglages].
static func lire_mot(m: String) -> Array:
	var i := m.find(SEPARATEUR)
	if i < 0:
		return [m, {}]
	return [m.left(i), decoder(m.substr(i + SEPARATEUR.length()))]


# --- Les prix --------------------------------------------------------------------------------------

## Ce que coûtent des changements chez un métier : la somme des prix des champs qui changent, au tarif.
static func prix(metier: String, avant: Dictionary, apres: Dictionary, tarif := 1.0) -> int:
	var champs: Dictionary = METIERS.get(metier, {}).get("champs", {})
	var total := 0
	for champ in champs:
		if valeur(avant, champ) != valeur(apres, champ):
			total += prix_champ(metier, champ, tarif)
	return total


static func prix_champ(metier: String, champ: String, tarif := 1.0) -> int:
	var p := int(METIERS.get(metier, {}).get("champs", {}).get(champ, 0))
	return int(round(p * tarif / 5.0)) * 5 if tarif != 1.0 else p
