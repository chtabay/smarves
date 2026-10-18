extends Node
## Le marché des transferts du football de la Vienne (autoload « Mercato », docs/SUITE.md section 6,
## « le mercato ») : un marché à la Hattrick, ouvert toute l'année. Chaque dimanche à 17 h, deux heures
## après le coup d'envoi, quarante nouveaux joueurs sont mis en vente par des clubs de la Vienne, les mêmes
## chez tout le monde (tirage de la semaine) ; chacun part aux enchères jusqu'à sa date limite, du lundi
## au samedi soir, et le plus offrant l'emporte. Un club peut remettre en vente un joueur acheté au
## marché ; les dix-huit joueurs du cru, que le moteur tire chaque saison, sont du pays et ne se vendent pas.
##
## Les clubs invités enchérissent aussi : chaque joueur a ses acheteurs dans la Vienne, avec un plafond
## secret tiré de sa graine. Sous ce plafond, ils surenchérissent aussitôt ; au-dessus, on mène. Le
## plafond étant le même partout, tout le monde tire la même issue des mêmes offres.
##
## Les offres et les ventes sont communes : elles vivent au serveur (fonctions public.smarves_mercato,
## smarves_mercato_encherir et smarves_mercato_vendre, migration supabase/migrations/*_smarves_mercato.sql),
## qui tient les dates limites (et la prolongation d'Hattrick : une offre dans les trois dernières minutes
## les repousse de trois minutes) et la règle de direction. Enchérir demande donc un compte ; hors ligne,
## on lit le dernier état connu. C'est celui qui dirige le club qui enchérit, de sa poche : sa mise est
## retenue tant qu'il mène, rendue dès qu'il est dépassé, dépensée s'il gagne. Ce qu'un club vend revient
## dans la poche de celui qui l'a mis en vente.
##
## Les joueurs achetés vieillissent d'un an par saison de seize semaines (le rythme d'Hattrick) et
## progressent ou déclinent avec l'âge ; leur forme change chaque semaine. Ils entrent dans l'effectif
## du club au coup d'envoi qui suit l'achat (Football.renforts), jamais dans un match déjà joué.

signal change

## Les joueurs mis en vente chaque semaine, et leurs postes (mélangés chaque semaine) : quatre gardiens,
## douze défenseurs, treize milieux, onze attaquants.
const LOTS := 40
const POSTES_LOTS := ["G", "G", "G", "G", "D", "D", "D", "D", "D", "D", "D", "D", "D", "D", "D", "D",
	"M", "M", "M", "M", "M", "M", "M", "M", "M", "M", "M", "M", "M", "A", "A", "A", "A", "A", "A", "A", "A", "A", "A", "A"]
## Les deux compétences qui disent un joueur à son poste, pour la liste compacte.
const PRINCIPALES := {"G": ["gardien", "cpa"], "D": ["defense", "jeu"], "M": ["jeu", "passe"], "A": ["but", "passe"]}
## Une année de football dure une saison de seize semaines : 112 jours (comme à Hattrick).
const JOURS_PAR_AN := 112
const SEMAINE := 7 * 86400
## Une offre dans les trois dernières minutes repousse la date limite d'autant (le serveur la tient).
const PROLONGATION := 180
## Une vente d'un club se clôt à 21 h, dans un, trois ou sept jours.
const DUREES := [1, 3, 7]
const HEURE_VENTE := 21
const FICHIER := "mercato.json"
## L'échelle des compétences, en mots, un cran tous les cinq points (0 à 100).
const NIVEAUX := ["inexistant", "catastrophique", "désastreux", "piètre", "faible", "médiocre", "insuffisant",
	"passable", "correct", "honorable", "bon", "très bon", "excellent", "remarquable", "formidable",
	"brillant", "exceptionnel", "extraordinaire", "légendaire", "mythique", "divin"]
## La forme, de 1 à 8.
const FORMES := ["", "désastreuse", "catastrophique", "faible", "médiocre", "passable", "honorable", "excellente", "formidable"]

## Le dernier état lu au serveur : {encheres: [{lot, club, montant, par, moi, quand}],
## ventes: [{id, club, joueur, saison, prix_depart, echeance, cree, par, moi}], prolongations: {lot: echeance}}.
## Les heures sont en secondes locales, comme Football.maintenant().
var etat := {"encheres": [], "ventes": [], "prolongations": {}}
## Ce qu'on a retenu de sa poche pour une offre qui mène : lot -> crédits.
var retenues := {}
## Les ventes déjà encaissées et les achats déjà annoncés : lot -> true.
var reglees := {}
## Les joueurs qu'on suit (lot -> true), et les filtres de la dernière recherche.
var suivis := {}
var filtres := {}
## Les dernières nouvelles du marché pour celui qui joue (gagné, dépassé, vendu), les plus récentes d'abord.
var nouvelles: Array = []
## « » (jamais lu), « en_cours », « a_jour », « hors_ligne ».
var lecture := ""
## Où lire et écrire ; un test le déplace. « » : rien n'est écrit.
var dossier := Communes.GREFFES
## Un serveur de remplacement (essais, captures) : func(fonction, corps) -> {code, corps}.
var appel: Callable = Callable()

## Depuis quand ce jeu suit le marché : on ne règle ni n'annonce rien de clos avant (un appareil neuf ne
## réencaisse pas les ventes d'un autre).
var depuis := 0

var _issues := {}
var _transferts: Array = []
var _calcule := false
var _calcule_a := 0
var _signature := ""
var _lu_a := 0


func _ready() -> void:
	# Les joueurs achetés entrent dans l'effectif par le crochet du moteur, quand il existe.
	(func():
		var f := foot()
		if f != null and "renforts" in f:
			f.renforts = renforts).call_deferred()
	if get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()):
		return
	charger()
	var dernier := [Game.staked]
	Game.changed.connect(func():
		# Une nouvelle partie emporte ce qu'on avait retenu et encaissé avec le reste.
		if Game.staked < dernier[0]:
			retenues = {}
			reglees = {}
			nouvelles = []
			sauver()
		dernier[0] = Game.staked)
	# Le marché se relit de lui-même : à chaque date limite qui nous concerne, et toutes les cinq minutes,
	# pour qu'une enchère close s'annonce où que soit le joueur.
	var veille := Timer.new()
	veille.wait_time = 60.0
	veille.timeout.connect(_veiller)
	add_child(veille)
	veille.start()
	(func():
		lire()
		var compte := _compte()
		if compte != null:
			compte.change.connect(func():
				if compte.etat == "a_jour":
					lire())).call_deferred()


static func foot() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Football")


func _compte() -> Node:
	return get_node_or_null("/root/Compte")


func maintenant() -> int:
	return foot().maintenant()


# ---------------------------------------------------------------- le calendrier du marché

## Le début de la semaine k du marché : le dimanche à 17 h (k = 1 : le 25 octobre 2026, jour de la
## première journée ; k = 0 : le 18 octobre). Les semaines se suivent sans s'occuper des saisons.
static func debut_semaine(k: int) -> int:
	return foot().coup_envoi(1, 1) + (k - 1) * SEMAINE + 2 * 3600


static func semaine_a(t: int) -> int:
	return int(floor(float(t - debut_semaine(0)) / SEMAINE))


## La date limite du lot i de la semaine k : du lundi au samedi, entre 19 h et 22 h (le même calcul que
## smarves.mercato_echeance).
static func echeance_lot(k: int, i: int) -> int:
	var jour: int = 1 + (i * 6) / LOTS
	var heure: int = 19 + i % 4
	return foot().coup_envoi(1, 1) + (k - 1) * SEMAINE + jour * 86400 + (heure - 15) * 3600


## La date limite d'une vente posée à t pour n jours : à 21 h.
static func echeance_vente(t: int, jours: int) -> int:
	return int(floor(float(t) / 86400.0)) * 86400 + jours * 86400 + HEURE_VENTE * 3600


## Le surplus minimum sur une offre : 2 %, au moins 10 crédits, à la dizaine supérieure (le même calcul
## que le serveur, en entiers).
static func pas(x: int) -> int:
	return maxi(10, ((x + 499) / 500) * 10)


# ---------------------------------------------------------------- les joueurs

## La valeur d'un joueur d'après sa note et son âge : la jeunesse se paie, l'âge se brade.
static func valeur_de(note: int, age: int) -> int:
	var f := 1.5 if age <= 20 else (1.25 if age <= 23 else (1.0 if age <= 28 else (0.7 if age <= 30 else (0.45 if age <= 32 else 0.3))))
	return int(round(foot().prix_de(note) * f / 10.0)) * 10


## Le salaire de la semaine : un quarantième de la valeur, au moins 50 crédits.
static func salaire_de(valeur: int) -> int:
	return maxi(50, int(round(valeur / 400.0)) * 10)


## Le cran d'une compétence (0 à 20) et son mot.
static func niveau(c: float) -> int:
	return clampi(int(floor(c / 5.0)), 0, NIVEAUX.size() - 1)


static func mot_niveau(c: float) -> String:
	return NIVEAUX[niveau(c)]


## Le joueur d'un lot hebdomadaire tel qu'il est arrivé sur le marché : {id, prenom, nom, poste, age, note,
## competences, experience, saison} (saison : celle de son arrivée, d'où l'on compte son âge).
func naissance(id: String) -> Dictionary:
	var k := lot_semaine(id)
	var i := lot_rang(id)
	if i < 0 or i >= LOTS:
		return {}
	var f := foot()
	var postes: Array = Hasard.depuis(Hasard.graine("mercato/postes/%d" % k)).melanger(POSTES_LOTS)
	var h := Hasard.depuis(Hasard.graine("mercato/%s" % id))
	var r := h.suivant()
	var age: int = h.entier(17, 20) if r < 0.3 else (h.entier(21, 28) if r < 0.8 else h.entier(29, 33))
	var moyenne := 50.0 if age <= 20 else (62.0 if age <= 28 else 64.0)
	var j := {"id": id, "prenom": h.choix(f.PRENOMS), "nom": h.choix(f.NOMS), "poste": postes[i], "age": age,
		"note": clampi(int(roundf(h.normal(moyenne, 9.0))), 38, 90), "saison": f.saison_a(debut_semaine(k)),
		"experience": clampi(int(roundf((age - 17) * 0.7 + h.normal(0.0, 1.5))), 0, 20)}
	j.competences = FootMatch.tirer_competences(j, Hasard.depuis(Hasard.graine("mercato/competences/%s" % id)))
	return j


static func lot_semaine(id: String) -> int:
	return int(id.trim_prefix("s").get_slice("-", 0)) if id.begins_with("s") else 0


static func lot_rang(id: String) -> int:
	if not id.begins_with("s") or not "-" in id.substr(1):
		return -1
	var p := id.substr(1).rsplit("-", true, 1)
	return int(p[1]) if p[1].is_valid_int() else -1


## Ce que l'âge fait d'une saison à l'autre : les jeunes progressent, les anciens déclinent.
static func progression(age: int, h: Hasard) -> int:
	if age <= 20:
		return 4 + h.entier(0, 2)
	if age <= 23:
		return 2 + h.entier(0, 1)
	if age <= 28:
		return h.entier(0, 1)
	if age <= 30:
		return -1 - h.entier(0, 1)
	if age <= 32:
		return -3 - h.entier(0, 1)
	return -5 - h.entier(0, 2)


## Un joueur du marché à la saison s : vieilli d'un an par saison depuis son arrivée, sa note et ses
## compétences passées par l'âge, avec sa valeur et son salaire du moment.
func joueur_en(id: String, s: int) -> Dictionary:
	var j := naissance(id)
	if j.is_empty():
		return {}
	for ss in range(int(j.saison) + 1, s + 1):
		j.age += 1
		var h := Hasard.depuis(Hasard.graine("mercato/progres/%s/%d" % [id, ss]))
		var d := progression(int(j.age), h)
		j.note = clampi(int(j.note) + d, 30, 95)
		for c in j.competences:
			j.competences[c] = clampi(int(j.competences[c]) + d + h.entier(-1, 1), 10, 99)
		j.experience = mini(20, int(j.experience) + 1)
	j.valeur = valeur_de(int(j.note), int(j.age))
	j.salaire = salaire_de(int(j.valeur))
	return j


## La forme d'un joueur la semaine k (1 à 8), et ce qu'elle fait au moral du moteur.
static func forme(id: String, k: int) -> int:
	var h := Hasard.depuis(Hasard.graine("mercato/forme/%s/%d" % [id, k]))
	return clampi(int(roundf(h.normal(5.0, 1.4))), 1, 8)


# ---------------------------------------------------------------- les lots

## Les lots d'une semaine : les quarante joueurs mis en vente ce dimanche-là.
func lots_semaine(k: int) -> Array:
	var out: Array = []
	for i in LOTS:
		out.append(enchere("s%d-%d" % [k, i]))
	return out


## Les ventes des clubs, valables (le club possédait le joueur quand il l'a mis en vente).
func ventes() -> Array:
	_calculer()
	var out: Array = []
	for v in etat.ventes:
		if _issues.has("v%d" % int(v.id)):
			out.append(enchere("v%d" % int(v.id)))
	return out


## Les clubs de village de la Vienne hors championnat, triés (Football.clubs_de_la_vienne) : les vendeurs et
## les acheteurs du marché.
func _invites() -> Array:
	return foot().clubs_de_la_vienne()


## Une enchère, ouverte ou close : {lot, joueur (la fiche du moment), ouverture, echeance, prix_depart,
## vendeur (nom), club_vendeur (le club qui vend, « » pour un lot de la semaine), acheteur (le club invité
## qui enchérit), offres (les offres des joueurs, de la plus haute à la plus basse), prix (le prix du
## moment), meneur (un club, « invite » ou « »), minimum (la plus petite offre recevable), ferme,
## gagnant (un club, « invite » ou « » une fois close), valable}.
func enchere(lot: String) -> Dictionary:
	var f := foot()
	var e := {"lot": lot, "valable": true}
	var h: Hasard
	var base := {}
	var joueur_id := lot
	if lot.begins_with("s"):
		var k := lot_semaine(lot)
		joueur_id = lot
		base = naissance(lot)
		if base.is_empty():
			return {}
		e.ouverture = debut_semaine(k)
		e.echeance = int(etat.prolongations.get(lot, echeance_lot(k, lot_rang(lot))))
		e.echeance_prevue = echeance_lot(k, lot_rang(lot))
		e.club_vendeur = ""
		h = Hasard.depuis(Hasard.graine("mercato/enchere/%s" % lot))
		var valeur := valeur_de(int(base.note), int(base.age))
		e.prix_depart = maxi(100, int(round(valeur * (0.4 + 0.3 * h.suivant()) / 50.0)) * 50)
		e.plafond = int(round(valeur * (0.75 + 0.55 * h.suivant()) / 10.0)) * 10
		var inv := _invites()
		e.vendeur = str(h.choix(inv)) if not inv.is_empty() else "un club de la Vienne"
		e.acheteur = str(h.choix(inv)) if not inv.is_empty() else "un club de la Vienne"
		e.joueur = joueur_en(lot, f.saison_a(maxi(maintenant(), int(e.ouverture))))
	else:
		var v := _vente(int(lot.trim_prefix("v")))
		if v.is_empty():
			return {}
		joueur_id = str(v.joueur)
		e.ouverture = int(v.cree)
		e.echeance = int(v.echeance)
		e.echeance_prevue = int(v.echeance)
		e.club_vendeur = str(v.club)
		e.vendeur = str(f.clubs.get(v.club, {}).get("nom", v.club))
		e.par = str(v.get("par", ""))
		e.moi = bool(v.get("moi", false))
		e.prix_depart = maxi(10, int(v.prix_depart))
		var j := joueur_en(joueur_id, int(v.saison))
		if j.is_empty():
			return {}
		h = Hasard.depuis(Hasard.graine("mercato/revente/%s/%d/%s" % [joueur_id, int(v.saison), v.club]))
		e.plafond = int(round(int(j.valeur) * (0.7 + 0.5 * h.suivant()) / 10.0)) * 10
		var inv := _invites()
		e.acheteur = str(h.choix(inv)) if not inv.is_empty() else "un club de la Vienne"
		e.joueur = joueur_en(joueur_id, f.saison_a(maxi(maintenant(), int(e.ouverture))))
		_calculer()
		e.valable = _issues.has(lot)
	e.joueur.forme = forme(joueur_id, semaine_a(maxi(maintenant(), int(e.ouverture))))
	e.entree = 0.15 + 0.45 * h.suivant()
	# Les offres des joueurs, recevables (au prix de départ au moins), de la plus haute à la plus basse.
	var offres: Array = []
	for o in etat.encheres:
		if str(o.lot) == lot and int(o.montant) >= int(e.prix_depart) and str(o.club) != e.club_vendeur:
			offres.append(o)
	offres.sort_custom(func(a, b): return int(a.montant) > int(b.montant) if int(a.montant) != int(b.montant) else str(a.quand) < str(b.quand))
	e.offres = offres
	var t := maintenant()
	e.ferme = t >= int(e.echeance)
	_prix(e, mini(t, int(e.echeance)))
	if e.ferme:
		e.gagnant = e.meneur
	else:
		e.gagnant = ""
	return e


## Le prix et le meneur d'une enchère à l'instant t : la meilleure offre d'un joueur contre l'acheteur
## invité, qui monte avec le temps vers son plafond et surenchérit aussitôt sous celui-ci.
func _prix(e: Dictionary, t: int) -> void:
	var b: int = int(e.offres[0].montant) if not e.offres.is_empty() else 0
	var depart: int = e.prix_depart
	var plafond: int = e.plafond
	var duree: float = maxf(1.0, float(int(e.echeance_prevue) - int(e.ouverture)))
	var p: float = clampf(float(t - int(e.ouverture)) / duree, 0.0, 1.0)
	var invite := 0
	if plafond >= depart and (p >= float(e.entree) or b > 0 or t >= int(e.echeance)):
		invite = depart + int((plafond - depart) * p * p / 10.0) * 10
		if t >= int(e.echeance):
			invite = plafond
		if b > 0 and b < plafond:
			invite = maxi(invite, mini(plafond, b + pas(b)))
		invite = mini(invite, plafond)
	if b > 0 and b >= invite:
		e.prix = b
		e.meneur = str(e.offres[0].club)
		e.meneur_moi = bool(e.offres[0].get("moi", false))
	elif invite > 0:
		e.prix = invite
		e.meneur = "invite"
		e.meneur_moi = false
	else:
		e.prix = depart
		e.meneur = ""
		e.meneur_moi = false
	e.minimum = depart if e.meneur == "" else int(e.prix) + pas(int(e.prix))


func _vente(id: int) -> Dictionary:
	for v in etat.ventes:
		if int(v.id) == id:
			return v
	return {}


# ---------------------------------------------------------------- qui possède qui

## Les transferts entre clubs, dans l'ordre : [{joueur, vers (un club, « » s'il quitte la Vienne), quand, prix, lot}].
## Un lot de la semaine gagné par un club, puis les ventes des clubs dans l'ordre où elles ont été posées :
## une vente ne vaut que si le club possédait le joueur à ce moment-là (une seule vente ouverte à la fois).
func _calculer() -> void:
	# Le temps clôt des enchères : on recompte au plus toutes les trente secondes.
	if _calcule and absi(maintenant() - _calcule_a) < 30:
		return
	_calcule = true
	_calcule_a = maintenant()
	_issues = {}
	_transferts = []
	var lots := {}
	for o in etat.encheres:
		if str(o.lot).begins_with("s"):
			lots[str(o.lot)] = true
	for lot in lots:
		var e := enchere(lot)
		if not e.is_empty() and e.ferme and e.gagnant != "" and e.gagnant != "invite":
			_transferts.append({"joueur": lot, "vers": e.gagnant, "quand": int(e.echeance), "prix": int(e.prix), "lot": lot})
	var vs: Array = etat.ventes.duplicate()
	vs.sort_custom(func(a, b): return int(a.cree) < int(b.cree) if int(a.cree) != int(b.cree) else int(a.id) < int(b.id))
	var ouvertes := {}
	for v in vs:
		var lot := "v%d" % int(v.id)
		var j := str(v.joueur)
		if proprietaire(j, int(v.cree)) != str(v.club) or int(ouvertes.get(j, 0)) > int(v.cree):
			continue
		_issues[lot] = true
		ouvertes[j] = int(v.echeance)
		var e := enchere(lot)
		if e.ferme and e.gagnant != "":
			_transferts.append({"joueur": j, "vers": "" if e.gagnant == "invite" else e.gagnant, "quand": int(e.echeance), "prix": int(e.prix), "lot": lot})
	# Un transfert de plus (une enchère close, un état relu) : le moteur oublie les effectifs qu'il gardait.
	var sig := JSON.stringify(_transferts)
	if sig != _signature:
		var premier := _signature == ""
		_signature = sig
		var f := foot()
		if not premier and f != null and f.has_method("oublier_effectifs"):
			f.oublier_effectifs.call_deferred()


## Le club qui possède un joueur du marché à l'instant t, ou « ».
func proprietaire(joueur: String, t: int) -> String:
	var out := ""
	var quand := -1
	for tr in _transferts:
		if tr.joueur == joueur and int(tr.quand) <= t and int(tr.quand) >= quand:
			out = tr.vers
			quand = int(tr.quand)
	return out


## Les joueurs du marché d'un club à l'instant t : [id].
func joueurs_de(club: String, t: int) -> Array:
	_calculer()
	var vus := {}
	for tr in _transferts:
		vus[tr.joueur] = true
	var out: Array = []
	for j in vus:
		if proprietaire(j, t) == club:
			out.append(j)
	out.sort()
	return out


## Le crochet du moteur : les joueurs achetés au marché qu'un club aligne au coup d'envoi de la journée j
## de la saison s, au format de l'effectif ({id (« club/m-s3-7 » : la composition lit le club en tête), prenom, nom, poste, age, note, condition, moral,
## competences, experience, forme, salaire}).
func renforts(s: int, j: int, club: String) -> Array:
	var t: int = foot().coup_envoi(s, maxi(1, j))
	var out: Array = []
	for id in joueurs_de(club, t):
		var p := joueur_en(id, s)
		var fm := forme(id, semaine_a(t))
		out.append({"id": "%s/m-%s" % [club, id], "prenom": p.prenom, "nom": p.nom, "poste": p.poste, "age": p.age, "note": p.note,
			"condition": 100, "moral": 40 + fm * 7, "competences": p.competences, "experience": p.experience,
			"forme": fm, "salaire": p.salaire})
	return out


## Ce que coûtent par semaine les joueurs du marché d'un club.
func salaires(club: String) -> int:
	var t := maintenant()
	var s: int = foot().saison_a(t)
	var n := 0
	for id in joueurs_de(club, t):
		n += int(joueur_en(id, s).salaire)
	return n


## Une vente ouverte pour ce joueur, ou {}.
func vente_ouverte(joueur: String) -> Dictionary:
	for e in ventes():
		if e.valable and not e.ferme and str(e.joueur.id) == joueur:
			return e
	return {}


## Suivre un joueur du marché (ou ne plus le suivre).
func suivre(lot: String, oui := true) -> void:
	if oui:
		suivis[lot] = true
	else:
		suivis.erase(lot)
	sauver()
	change.emit()


## Les enchères suivies, ouvertes ou closes depuis moins de trois jours, de la plus proche à la plus lointaine.
func encheres_suivies() -> Array:
	var t := maintenant()
	var out: Array = []
	for lot in suivis:
		var e := enchere(lot)
		if not e.is_empty() and e.valable and t - int(e.echeance) < 3 * 86400:
			out.append(e)
	out.sort_custom(func(a, b): return int(a.echeance) < int(b.echeance))
	return out


## Les enchères ouvertes, lots de la semaine et ventes des clubs.
func ouvertes() -> Array:
	var t := maintenant()
	var out: Array = lots_semaine(semaine_a(t)).filter(func(e): return not e.ferme)
	for e in ventes():
		if e.valable and not e.ferme:
			out.append(e)
	return out


## La recherche de transferts, à la Hattrick : f = {poste, age_min, age_max, comp1, niv1, comp2, niv2,
## prix_max, tri} (tout est facultatif ; niv en crans de 0 à 20 ; tri : echeance, prix, age, note, comp1).
func rechercher(f: Dictionary) -> Array:
	var out: Array = []
	for e in ouvertes():
		var j: Dictionary = e.joueur
		if str(f.get("poste", "")) != "" and j.poste != f.poste:
			continue
		if int(j.age) < int(f.get("age_min", 0)) or int(j.age) > int(f.get("age_max", 99)):
			continue
		if int(f.get("prix_max", 0)) > 0 and int(e.prix) > int(f.prix_max):
			continue
		var ok := true
		for n in ["1", "2"]:
			var c := str(f.get("comp" + n, ""))
			if c != "" and niveau(float(j.competences.get(c, 0))) < int(f.get("niv" + n, 0)):
				ok = false
		if ok:
			out.append(e)
	var tri := str(f.get("tri", "echeance"))
	var c1 := str(f.get("comp1", ""))
	out.sort_custom(func(a, b):
		match tri:
			"prix":
				return int(a.prix) < int(b.prix)
			"age":
				return int(a.joueur.age) < int(b.joueur.age)
			"note":
				return int(a.joueur.note) > int(b.joueur.note)
			"comp1":
				if c1 != "":
					return float(a.joueur.competences.get(c1, 0)) > float(b.joueur.competences.get(c1, 0))
		return int(a.echeance) < int(b.echeance))
	return out


## Les jours passés depuis le dernier anniversaire, à l'instant t (l'année du football : une saison).
func age_jours(t: int) -> int:
	var f := foot()
	return clampi(int(floor(float(t - f.debut(f.saison_a(t))) / 86400.0)), 0, JOURS_PAR_AN - 1)


# ---------------------------------------------------------------- enchérir, vendre

func connecte() -> bool:
	if appel.is_valid():
		return true
	var c := _compte()
	return c != null and c.connecte()


func _appeler(fonction: String, corps: Dictionary) -> Dictionary:
	if appel.is_valid():
		return await appel.call(fonction, corps)
	var c := _compte()
	if c == null:
		return {"code": 0, "corps": null}
	return await c.appeler(fonction, corps)


## Ce qui empêche d'enchérir, ou « » : compte, parts, ferme, bas, vendeur, credits, inconnu.
func refus(lot: String, club: String, montant: int) -> String:
	var e := enchere(lot)
	if e.is_empty() or not e.valable:
		return "inconnu"
	if not connecte():
		return "compte"
	if not foot().peut_decider(club):
		return "parts"
	if e.ferme or maintenant() < int(e.ouverture):
		return "ferme"
	if e.club_vendeur == club:
		return "vendeur"
	if montant < int(e.minimum):
		return "bas"
	if Game.credits + int(retenues.get(lot, 0)) < montant:
		return "credits"
	return ""


## Enchérit pour un club : {ok, mene, prix} ou {ok: false, raison}. Si l'acheteur invité surenchérit
## aussitôt, l'offre compte mais rien n'est retenu.
func encherir(lot: String, club: String, montant: int) -> Dictionary:
	var raison := refus(lot, club, montant)
	if raison != "":
		return {"ok": false, "raison": raison}
	var r: Dictionary = await _appeler("smarves_mercato_encherir", {"p_lot": lot, "p_club": club, "p_montant": montant})
	if r.code != 200 or not r.corps is Dictionary:
		return {"ok": false, "raison": "reseau"}
	if not r.corps.get("ok", false):
		if r.corps.has("raison"):
			lire()
		return {"ok": false, "raison": str(r.corps.get("raison", "compte"))}
	var compte := _compte()
	etat.encheres.append({"lot": lot, "club": club, "montant": montant, "par": compte.nom if compte != null else "",
		"moi": true, "quand": _horodatage(maintenant())})
	if r.corps.has("echeance") and lot.begins_with("s"):
		var ech := _heure(r.corps.echeance)
		if ech != echeance_lot(lot_semaine(lot), lot_rang(lot)):
			etat.prolongations[lot] = ech
	elif r.corps.has("echeance"):
		var v := _vente(int(lot.trim_prefix("v")))
		if not v.is_empty():
			v.echeance = _heure(r.corps.echeance)
	_oublier()
	var e := enchere(lot)
	if e.meneur_moi:
		Game.credits -= montant - int(retenues.get(lot, 0))
		retenues[lot] = montant
		Game.changed.emit()
	_regler()
	sauver()
	change.emit()
	return {"ok": true, "mene": e.meneur_moi, "prix": int(e.prix)}


## Ce qui empêche de mettre un joueur en vente, ou « » : compte, parts, pas_a_nous, deja, prix, duree.
func refus_vente(club: String, joueur: String, prix: int, jours: int) -> String:
	if not connecte():
		return "compte"
	if not foot().peut_decider(club):
		return "parts"
	_calculer()
	if proprietaire(joueur, maintenant()) != club:
		return "pas_a_nous"
	if not vente_ouverte(joueur).is_empty():
		return "deja"
	if prix < 10:
		return "prix"
	if not jours in DUREES:
		return "duree"
	return ""


## Met en vente un joueur du marché : {ok, lot} ou {ok: false, raison}.
func vendre(club: String, joueur: String, prix: int, jours: int) -> Dictionary:
	var raison := refus_vente(club, joueur, prix, jours)
	if raison != "":
		return {"ok": false, "raison": raison}
	var s: int = foot().saison_a(maintenant())
	var r: Dictionary = await _appeler("smarves_mercato_vendre", {"p_club": club, "p_joueur": joueur, "p_prix": prix, "p_jours": jours, "p_saison": s})
	if r.code != 200 or not r.corps is Dictionary:
		return {"ok": false, "raison": "reseau"}
	if not r.corps.get("ok", false):
		return {"ok": false, "raison": str(r.corps.get("raison", "compte"))}
	var compte := _compte()
	var id := int(r.corps.get("id", 0))
	etat.ventes.append({"id": id, "club": club, "joueur": joueur, "saison": s, "prix_depart": prix,
		"echeance": _heure(r.corps.get("echeance", "")) if r.corps.has("echeance") else echeance_vente(maintenant(), jours),
		"cree": _heure(r.corps.cree) if r.corps.has("cree") else maintenant(), "par": compte.nom if compte != null else "", "moi": true})
	_oublier()
	sauver()
	change.emit()
	return {"ok": true, "lot": "v%d" % id}


# ---------------------------------------------------------------- le serveur

## Relit le marché au serveur (sans compte aussi : il est public, comme le championnat).
func lire() -> void:
	if lecture == "en_cours":
		return
	if not appel.is_valid() and (get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()) or _compte() == null):
		return
	lecture = "en_cours"
	var r: Dictionary = await _appeler("smarves_mercato", {})
	_lu_a = maintenant()
	if r.code == 200 and r.corps is Dictionary:
		if depuis == 0:
			depuis = maintenant()
		appliquer(r.corps)
		lecture = "a_jour"
	else:
		lecture = "hors_ligne"
		change.emit()


## L'état lu au serveur, heures en texte (« 2026-10-24 22:00:00 », heure de Paris) : il remplace ce qu'on
## en savait ; puis les mises retenues et les ventes se règlent.
func appliquer(corps: Dictionary) -> void:
	var nouveau := {"encheres": [], "ventes": [], "prolongations": {}}
	for o in corps.get("encheres", []):
		if o is Dictionary and o.has("lot"):
			nouveau.encheres.append({"lot": str(o.lot), "club": str(o.get("club", "")), "montant": int(o.get("montant", 0)),
				"par": str(o.get("par", "")), "moi": bool(o.get("moi", false)), "quand": str(o.get("quand", ""))})
	for v in corps.get("ventes", []):
		if v is Dictionary and v.has("id"):
			nouveau.ventes.append({"id": int(v.id), "club": str(v.get("club", "")), "joueur": str(v.get("joueur", "")),
				"saison": int(v.get("saison", 1)), "prix_depart": int(v.get("prix_depart", 0)), "echeance": _heure(v.get("echeance", "")),
				"cree": _heure(v.get("cree", "")), "par": str(v.get("par", "")), "moi": bool(v.get("moi", false))})
	for p in corps.get("prolongations", []):
		if p is Dictionary and p.has("lot"):
			nouveau.prolongations[str(p.lot)] = _heure(p.get("echeance", ""))
	etat = nouveau
	_oublier()
	_regler()
	sauver()
	change.emit()


## Règle ce qui peut l'être : une mise dépassée est rendue, une mise gagnante est dépensée, une vente
## close rapporte son prix à celui qui l'a posée. Chaque fois, une nouvelle pour la fenêtre.
func _regler() -> void:
	var bouge := false
	for lot in retenues.keys():
		var e := enchere(lot)
		var montant := int(retenues[lot])
		var nom: String = "%s %s" % [e.joueur.prenom, e.joueur.nom] if not e.is_empty() else lot
		if not e.is_empty() and e.valable and e.meneur_moi and int(e.offres[0].montant) == montant:
			if e.ferme:
				retenues.erase(lot)
				reglees[lot] = true
				_nouvelle("Enchère gagnée : %s rejoint %s pour %s crédits. Il joue dès le prochain coup d'envoi." % [nom, _nom_club(e.gagnant), Game.fmt(montant)])
				bouge = true
			continue
		retenues.erase(lot)
		Game.credits += montant
		bouge = true
		_nouvelle("Enchère dépassée sur %s : vos %s crédits vous sont rendus." % [nom, Game.fmt(montant)])
	# Les enchères où l'on a offert et qu'un autre emporte.
	var vus := {}
	for o in etat.encheres:
		var lot := str(o.lot)
		if not bool(o.get("moi", false)) or vus.has(lot) or reglees.has(lot) or retenues.has(lot):
			continue
		vus[lot] = true
		var e := enchere(lot)
		if e.is_empty() or not e.valable or not e.ferme or int(e.echeance) < depuis or e.meneur_moi:
			continue
		reglees[lot] = true
		bouge = true
		var qui: String = "personne" if e.gagnant == "" else (e.acheteur if e.gagnant == "invite" else _nom_club(e.gagnant))
		_nouvelle("Enchère perdue : %s %s part %s pour %s crédits." % [e.joueur.prenom, e.joueur.nom, "chez " + qui if e.gagnant != "" else "sans preneur", Game.fmt(int(e.prix))])
	for v in etat.ventes:
		var lot := "v%d" % int(v.id)
		if not bool(v.get("moi", false)) or reglees.has(lot):
			continue
		var e := enchere(lot)
		if e.is_empty() or not e.valable or not e.ferme or e.gagnant == "" or int(e.echeance) < depuis:
			continue
		reglees[lot] = true
		Game.credits += int(e.prix)
		bouge = true
		var qui: String = e.acheteur if e.gagnant == "invite" else _nom_club(e.gagnant)
		_nouvelle("Vendu : %s %s part pour %s, %s crédits dans votre poche." % [e.joueur.prenom, e.joueur.nom, qui, Game.fmt(int(e.prix))])
	if bouge:
		Game.changed.emit()
		var f := foot()
		if f.has_method("oublier_effectifs"):
			f.oublier_effectifs()


func _nouvelle(t: String) -> void:
	nouvelles.push_front(t)
	nouvelles = nouvelles.slice(0, 6)
	# La fiche du carnet glisse en bas de l'écran, où que l'on soit (docs/ACTIVITES.md, brique 4).
	var carnet := get_node_or_null("/root/Carnet")
	if carnet != null and carnet.has_method("show_slip") and get_tree().get_script() == null and not "--capture" in " ".join(OS.get_cmdline_user_args()):
		carnet.show_slip(t)


## Ce qui nous concerne au marché : nos offres sur des enchères ouvertes et nos ventes ouvertes, avec leur
## date limite. Pour l'agenda : [{id, quoi, ou, lieu, quand, duree, reglement}] entre de et a.
func rendez_vous(de: int, a: int) -> Array:
	var out: Array = []
	var vus := {}
	var lots: Array = []
	for o in etat.encheres:
		if bool(o.get("moi", false)) and not vus.has(str(o.lot)):
			vus[str(o.lot)] = true
			lots.append(str(o.lot))
	for v in etat.ventes:
		if bool(v.get("moi", false)):
			lots.append("v%d" % int(v.id))
	for lot in lots:
		var e := enchere(lot)
		if e.is_empty() or not e.valable or int(e.echeance) < de or int(e.echeance) > a:
			continue
		var nom := "%s %s" % [e.joueur.prenom, e.joueur.nom]
		out.append({"id": "mercato/" + lot, "quoi": ("Fin de la vente : " if e.get("moi", false) else "Fin de l'enchère : ") + nom,
			"ou": "le mercato, au bureau du club", "lieu": "stade", "quand": int(e.echeance), "duree": 0, "reglement": int(e.echeance)})
	out.sort_custom(func(x, y): return x.quand < y.quand)
	return out


## Relit le marché quand une date limite qui nous concerne est passée, et toutes les cinq minutes.
func _veiller() -> void:
	var t := maintenant()
	if t - _lu_a >= 300:
		lire()
		return
	for r in rendez_vous(_lu_a - SEMAINE, t):
		if int(r.quand) > _lu_a:
			lire()
			return


func _nom_club(club: String) -> String:
	return str(foot().clubs.get(club, {}).get("nom", club))


func _oublier() -> void:
	_calcule = false


## Une heure de Paris en texte (« 2026-10-24 22:00:00 », ou ISO) en secondes locales.
static func _heure(v) -> int:
	if v is int or v is float:
		return int(v)
	var t := str(v).replace("T", " ").substr(0, 19)
	return Time.get_unix_time_from_datetime_string(t) if t.length() >= 16 else 0


static func _horodatage(t: int) -> String:
	return Time.get_datetime_string_from_unix_time(t, true)


# ---------------------------------------------------------------- la sauvegarde

func charger() -> void:
	if dossier == "":
		return
	var lu = Portail.lire_json(dossier.path_join(FICHIER))
	if lu is Dictionary:
		var e = lu.get("etat", {})
		if e is Dictionary:
			etat = {"encheres": e.get("encheres", []), "ventes": e.get("ventes", []), "prolongations": e.get("prolongations", {})}
		retenues = lu.get("retenues", {})
		reglees = lu.get("reglees", {})
		nouvelles = lu.get("nouvelles", [])
		suivis = lu.get("suivis", {})
		filtres = lu.get("filtres", {})
		depuis = int(lu.get("depuis", 0))
		_oublier()


func sauver() -> void:
	if dossier == "":
		return
	Portail.ecrire(dossier.path_join(FICHIER), JSON.stringify({"etat": etat, "retenues": retenues, "reglees": reglees, "nouvelles": nouvelles, "depuis": depuis, "suivis": suivis, "filtres": filtres}))


## Repart de rien (essais, nouvelle partie).
func effacer() -> void:
	etat = {"encheres": [], "ventes": [], "prolongations": {}}
	retenues = {}
	reglees = {}
	nouvelles = []
	suivis = {}
	filtres = {}
	lecture = ""
	depuis = 0
	_lu_a = 0
	_signature = ""
	_oublier()
	if dossier != "":
		DirAccess.remove_absolute(dossier.path_join(FICHIER))
