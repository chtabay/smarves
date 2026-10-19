extends Node
## Le basket de la Vienne (autoload « Basket ») : un championnat sur les résultats réels. Les joueurs sont
## de vrais joueurs de l'Euroleague et de l'EuroCup, notés chaque vendredi soir par la fonction « basket »
## du serveur (addict, supabase/functions/basket) ; la spec est basket/spec-basket-reel.md du projet.
## Rien n'y touche au football.
##
## Toute commune qui déclare un gymnase (« gymnase ») a un club. Les groupes ont toujours huit places :
## celles qu'aucune commune ne tient sont tenues par des clubs figurants, villages réels de la Vienne. Un
## club nouveau prend la place du premier figurant du niveau le plus bas, avec ses points, son calendrier
## et son effectif : il joue dès la journée qui vient. Quand le bas n'a plus de figurant, un niveau s'ouvre
## dessous (deux fois plus de groupes), rempli de figurants. En fin de saison, le premier de chaque groupe
## monte, les deux derniers descendent, un dans chaque groupe du dessous. Même code pour un club ou pour cent.
##
## Une saison : quatorze journées aller-retour, le samedi à 20 h, puis deux semaines sans match. Chaque
## journée se joue avec le cliché du vendredi qui la précède (BasketMatch, déterministe) : même cliché,
## même score chez tout le monde ; hors ligne, le dernier cliché gardé sert.

signal change

## Le moteur de match, chargé par son chemin : un autoload ne doit pas dépendre du cache des class_name,
## qu'un dossier .godot ancien n'a pas encore (le script ne se chargerait pas).
const MOTEUR := preload("res://scripts/socle/basket_match.gd")
const SERVEUR := "https://alvxrjftenialifyktyz.supabase.co/functions/v1/basket"
const EPOQUE := {"year": 2026, "month": 10, "day": 24}
const HEURE_MATCH := 20
const JOURNEES := 14
const SEMAINES_PAR_SAISON := 16
const TAILLE := 8
const DESCENDENT := 2
const EFFECTIF := 10
const FICHIER := "basket.json"
const NOMS_FIGURANTS := ["Basket-club %s", "Union basket %s", "Avenir basket %s", "Étoile basket %s",
	"Cercle basket %s", "Entente basket %s", "Espérance basket %s", "Jeunesse basket %s"]
const COULEURS := [["#14213d", "#d4a93a"], ["#7a1e2c", "#f4f1ea"], ["#0f5c4d", "#f2c94c"], ["#2b4c7e", "#e8eef7"],
	["#3d2c5c", "#f0c987"], ["#b4471f", "#1d1d1d"], ["#1d1d1d", "#e85d04"], ["#2d6a4f", "#ffffff"]]
## La commune de référence pour choisir les figurants les plus proches : Smarves, la même pour tous.
const ORIGINE_INSEE := "86263"

## Les clubs inscrits (un gymnase au registre) : id de la commune -> {nom, court, couleurs, commune, salle}.
var clubs := {}
## La pyramide : niveaux[n][g] = huit places ; une place = [[depuis la journée, club ou "fig/<insee>"], …]
## à partir de la saison où elle a été posée (la dernière entrée tient la place).
var niveaux: Array = []
var saison := 1
## Les effectifs de la saison : "n/g/place" -> [codes des joueurs réels], tirés au début de la saison.
var effectifs := {}
var historique: Array = []
var dossier := Communes.GREFFES
## Les clichés gardés sur l'appareil : id (le vendredi, « 2026-10-23 ») -> cliché.
var cliches := {}
## Remplaçables par les tests : l'horloge (secondes locales), les gymnases du registre, le cliché d'une semaine.
var _horloge := Callable()
var source_gymnases := Callable()
var _matchs := {}


func _ready() -> void:
	if get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()):
		return
	charger()
	Registre.change.connect(actualiser)
	actualiser()
	telecharger.call_deferred()


# ---------------------------------------------------------------- le calendrier

func maintenant() -> int:
	if _horloge.is_valid():
		return _horloge.call()
	return int(Time.get_unix_time_from_system()) + Time.get_time_zone_from_system().bias * 60


func regler_horloge(h: Callable) -> void:
	_horloge = h


## Le coup d'envoi de la journée j de la saison s, le samedi à 20 h, en secondes locales.
static func coup_envoi(s: int, j: int) -> int:
	var semaine := (s - 1) * SEMAINES_PAR_SAISON + (j - 1)
	return Time.get_unix_time_from_datetime_dict({"year": EPOQUE.year, "month": EPOQUE.month, "day": EPOQUE.day,
		"hour": HEURE_MATCH, "minute": 0, "second": 0}) + semaine * 7 * 86400


static func saison_a(t: int) -> int:
	return maxi(1, 1 + int(floor(float(t - coup_envoi(1, 1) + 7 * 86400) / (SEMAINES_PAR_SAISON * 7 * 86400))))


static func journee_jouee_a(t: int, s: int) -> int:
	var n := 0
	for j in range(1, JOURNEES + 1):
		if t >= coup_envoi(s, j):
			n = j
	return n


func journee_jouee() -> int:
	return journee_jouee_a(maintenant(), saison)


## Le cliché qui sert à la journée j de la saison s : celui du vendredi d'avant (« 2026-10-23 »).
static func id_cliche(s: int, j: int) -> String:
	var d := Time.get_datetime_dict_from_unix_time(coup_envoi(s, j) - 86400)
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


## Le cliché pour un id : le sien s'il est gardé, sinon le dernier gardé d'avant ({} s'il n'y en a aucun).
func cliche(id: String) -> Dictionary:
	if cliches.has(id):
		return cliches[id]
	var avant := cliches.keys().filter(func(k): return k <= id)
	if avant.is_empty():
		return {}
	avant.sort()
	return cliches[avant[-1]]


# ---------------------------------------------------------------- la pyramide

func _gymnases() -> Array:
	if source_gymnases.is_valid():
		return source_gymnases.call()
	return Registre.de_type("gymnase")


## Met la pyramide au jour : saisons closes, clubs nouveaux placés, effectifs tirés. Sans effet si rien
## n'a bougé.
func actualiser() -> void:
	var bouge := false
	if niveaux.is_empty():
		niveaux = [[_groupe_de_figurants(0, 0)]]
		bouge = true
	var cible := saison_a(maintenant())
	while saison < cible:
		clore_saison()
		bouge = true
	if _accueillir():
		bouge = true
	if _tirer_effectifs():
		bouge = true
	if bouge:
		_matchs.clear()
		sauver()
		change.emit()


## Huit figurants pour le groupe g du niveau n : les villages de la Vienne les plus proches de Smarves
## qui ne sont pas encore dans la pyramide, dans l'ordre.
func _groupe_de_figurants(n: int, g: int) -> Array:
	var pris := {}
	for niv in niveaux:
		for grp in niv:
			for place in grp:
				for e in place:
					pris[str(e[1])] = true
	var centre := Vienne.centre(ORIGINE_INSEE)
	var candidates := Vienne.communes().filter(func(c): return not pris.has("fig/" + str(c.insee)) and str(c.insee) != ORIGINE_INSEE)
	candidates.sort_custom(func(a, b):
		var da: float = Vector2(a.centre[0], a.centre[1]).distance_squared_to(centre)
		var db: float = Vector2(b.centre[0], b.centre[1]).distance_squared_to(centre)
		return da < db if da != db else str(a.insee) < str(b.insee))
	var groupe: Array = []
	for c in candidates.slice(0, TAILLE):
		groupe.append([[0, "fig/" + str(c.insee)]])
	return groupe


## Les gymnases nouveaux prennent chacun la place du premier figurant du niveau le plus bas, à la journée
## qui vient ; quand le bas n'a plus de figurant, un niveau s'ouvre dessous.
func _accueillir() -> bool:
	var bouge := false
	var nouveaux: Array = _gymnases().filter(func(e): return not clubs.has(e.commune))
	nouveaux.sort_custom(func(a, b): return str(a.commune) < str(b.commune))
	for e in nouveaux:
		var champs: Dictionary = e.get("champs", {})
		clubs[e.commune] = {"nom": str(champs.get("club", e.nom)), "court": str(champs.get("court", "")),
			"couleurs": champs.get("couleurs", COULEURS[Hasard.graine(e.commune) % COULEURS.size()]),
			"commune": e.commune, "salle": str(e.nom), "fondation": saison}
		var place := _place_de_figurant()
		if place.is_empty():
			var n := niveaux.size()
			niveaux.append([])
			for g in 1 << n:
				niveaux[n].append(_groupe_de_figurants(n, g))
			place = _place_de_figurant()
		niveaux[place[0]][place[1]][place[2]].append([journee_jouee(), e.commune])
		bouge = true
	return bouge


func _place_de_figurant() -> Array:
	var n := niveaux.size() - 1
	for g in niveaux[n].size():
		for p in TAILLE:
			if str(niveaux[n][g][p][-1][1]).begins_with("fig/"):
				return [n, g, p]
	return []


## Qui tient la place p du groupe (n, g) à la journée j (celui arrivé avant ou à j - 1 joue j).
func titulaire(n: int, g: int, p: int, j: int) -> String:
	var qui := ""
	for e in niveaux[n][g][p]:
		if int(e[0]) < j or qui == "":
			qui = str(e[1])
	return qui


## Le nom, le sigle et les couleurs d'un club ou d'un figurant.
func fiche(id: String) -> Dictionary:
	if clubs.has(id):
		return clubs[id]
	var c := Vienne.commune(id.trim_prefix("fig/"))
	var nom := str(c.get("nom", id))
	var h := Hasard.depuis(Hasard.graine("basket/" + id))
	var court := ""
	for m in nom.replace("-", " ").replace("'", " ").split(" ", false):
		if m.length() > 2:
			court += m.left(1).to_upper()
	return {"nom": NOMS_FIGURANTS[h.entier(0, NOMS_FIGURANTS.size() - 1)] % _de(nom), "court": (court + "BC").left(3),
		"couleurs": COULEURS[h.entier(0, COULEURS.size() - 1)], "commune": "", "figurant": true}


static func _de(nom: String) -> String:
	return ("d'%s" if nom.left(1).to_lower() in ["a", "e", "i", "o", "u", "y", "é", "h"] else "de %s") % nom


## Le niveau, le groupe et la place qu'un club tient maintenant : [n, g, p], ou [].
func place_de(club: String) -> Array:
	for n in niveaux.size():
		for g in niveaux[n].size():
			for p in TAILLE:
				if str(niveaux[n][g][p][-1][1]) == club:
					return [n, g, p]
	return []


# ---------------------------------------------------------------- les effectifs

## Les effectifs de la saison, tirés au serpent dans chaque groupe à partir du cliché de sa première
## journée : chaque groupe a son propre vivier, si bien qu'un joueur réel n'est qu'à un club par groupe.
## Rien à tirer tant qu'aucun cliché n'est gardé.
func _tirer_effectifs() -> bool:
	var c := cliche(id_cliche(saison, 1))
	if c.is_empty():
		return false
	var bouge := false
	var tous: Array = c.joueurs.keys()
	tous.sort_custom(func(a, b):
		var na: int = c.joueurs[a].note
		var nb: int = c.joueurs[b].note
		return na > nb if na != nb else a < b)
	for n in niveaux.size():
		for g in niveaux[n].size():
			if effectifs.has("%d/%d/0" % [n, g]):
				continue
			# Le vivier du groupe, mélangé par sa graine, puis trié par note : deux groupes n'ont pas les
			# mêmes joueurs aux mêmes places, mais chacun tire équitablement.
			var h := Hasard.depuis(Hasard.graine("basket/effectifs/%d/%d/%d" % [saison, n, g]))
			var ordre := h.melanger(range(TAILLE))
			var vivier := tous.slice(0, TAILLE * EFFECTIF * 2)
			for p in TAILLE:
				effectifs["%d/%d/%d" % [n, g, p]] = []
			for r in EFFECTIF:
				for k in TAILLE:
					var p: int = ordre[k if r % 2 == 0 else TAILLE - 1 - k]
					effectifs["%d/%d/%d" % [n, g, p]].append(vivier[(r * TAILLE + k) * 2 + (h.entier(0, 1))])
			bouge = true
	return bouge


## L'équipe de la place p pour la journée j, prête pour BasketMatch : les notes, le profil et la
## disponibilité du cliché de la semaine ; un joueur que le cliché ne connaît plus est indisponible.
func equipe(s: int, n: int, g: int, p: int, j: int) -> Dictionary:
	var c := cliche(id_cliche(s, j))
	var joueurs: Array = []
	for code in effectifs.get("%d/%d/%d" % [n, g, p], []):
		var f: Dictionary = c.get("joueurs", {}).get(code, {})
		if f.is_empty():
			joueurs.append({"code": code, "nom": code, "note": 1, "profil": [1, 1, 1, 1, 1], "dispo": false})
		else:
			joueurs.append({"code": code, "nom": f.nom, "note": int(f.note), "profil": f.profil, "dispo": bool(f.dispo),
				"club": f.club, "forme": int(f.get("forme", 0)), "derniere": f.get("derniere", {})})
	var qui := titulaire(n, g, p, j)
	return {"nom": fiche(qui).nom, "club": qui, "joueurs": joueurs, "consigne": "titulaires"}


# ---------------------------------------------------------------- le calendrier et les résultats

## Les rencontres de la journée j (1 à 14) d'un groupe de huit : [place à domicile, place à l'extérieur].
## Le tourniquet classique : sept journées aller, sept retour à domicile inversé.
static func rencontres(j: int) -> Array:
	var r := (j - 1) % (TAILLE - 1)
	var places := [0]
	for k in TAILLE - 1:
		places.append(1 + (k + r) % (TAILLE - 1))
	var out: Array = []
	for k in TAILLE / 2:
		var a: int = places[k]
		var b: int = places[TAILLE - 1 - k]
		var paire := [a, b] if (r + k) % 2 == 0 else [b, a]
		out.append(paire if j <= TAILLE - 1 else [paire[1], paire[0]])
	return out


## Le match joué (ou à jouer) : BasketMatch sur le cliché de la semaine, graine tirée de la saison, du
## groupe, de la journée, des places et du cliché.
func rencontre(s: int, n: int, g: int, j: int, dom: int, ext: int) -> Dictionary:
	var cle := "%d/%d/%d/%d/%d/%d" % [s, n, g, j, dom, ext]
	if not _matchs.has(cle):
		var c := cliche(id_cliche(s, j))
		var graine := Hasard.graine("basket/%s/%s" % [cle, str(c.get("id", ""))])
		_matchs[cle] = MOTEUR.jouer(equipe(s, n, g, dom, j), equipe(s, n, g, ext, j), graine)
	return _matchs[cle]


## Le classement d'un groupe après « joues » journées : par place, avec le club qui la tient.
func classement(s: int, n: int, g: int, joues := -1) -> Array:
	if joues < 0:
		joues = journee_jouee() if s == saison else JOURNEES
	var t: Array = []
	for p in TAILLE:
		t.append({"place": p, "club": titulaire(n, g, p, joues + 1), "j": 0, "v": 0, "d": 0, "pour": 0, "contre": 0, "pts": 0})
	for j in range(1, joues + 1):
		for paire in rencontres(j):
			var m := rencontre(s, n, g, j, paire[0], paire[1])
			for k in 2:
				var l: Dictionary = t[paire[k]]
				var pour: int = m.score[k]
				var contre: int = m.score[1 - k]
				l.j += 1
				l.pour += pour
				l.contre += contre
				if pour > contre:
					l.v += 1
					l.pts += 2
				else:
					l.d += 1
					l.pts += 1
	t.sort_custom(func(a, b):
		if a.pts != b.pts:
			return a.pts > b.pts
		if a.pour - a.contre != b.pour - b.contre:
			return a.pour - a.contre > b.pour - b.contre
		return a.place < b.place)
	return t


## Ferme la saison : le premier de chaque groupe monte au groupe père, les deux derniers du père descendent,
## un dans chaque groupe fils. Les places gardent leur club ; les effectifs se retirent à la saison suivante.
func clore_saison() -> void:
	var finals: Array = []
	for n in niveaux.size():
		var rangs: Array = []
		for g in niveaux[n].size():
			rangs.append(classement(saison, n, g, JOURNEES).map(func(l): return l.club))
		finals.append(rangs)
	historique.append({"saison": saison, "champion": finals[0][0][0]})
	for n in range(niveaux.size() - 2, -1, -1):
		for g in niveaux[n].size():
			var pere: Array = finals[n][g]
			for k in 2:
				var fils: Array = finals[n + 1][2 * g + k]
				var i: int = TAILLE - DESCENDENT + k
				var monte: String = fils[0]
				fils[0] = pere[i]
				pere[i] = monte
	saison += 1
	for n in niveaux.size():
		for g in niveaux[n].size():
			var groupe: Array = []
			for club in finals[n][g]:
				groupe.append([[0, club]])
			niveaux[n][g] = groupe
	effectifs = {}
	_matchs.clear()


# ---------------------------------------------------------------- la salle

## Le match d'un club à montrer : le dernier joué s'il date de moins de cinq jours, sinon le prochain.
## [saison, niveau, groupe, journée, place à domicile, place à l'extérieur], ou [] hors championnat.
func match_du_club(club: String) -> Array:
	var ici := place_de(club)
	if ici.is_empty():
		return []
	var jj := journee_jouee()
	var j := jj if jj > 0 and maintenant() - coup_envoi(saison, jj) < 5 * 86400 else mini(jj + 1, JOURNEES)
	for paire in rencontres(j):
		if ici[2] in paire:
			return [saison, ici[0], ici[1], j, paire[0], paire[1]]
	return []


## Le match pour la salle (SalleBasket.charger_match) : {dom, ext, score, quarts, feuilles, fini, quand} ;
## {} hors championnat ou sans cliché, ce que la salle prend pour un entraînement.
func match_pour_salle(club: String) -> Dictionary:
	var m := match_du_club(club)
	if m.is_empty() or cliches.is_empty():
		return {}
	var s: int = m[0]
	var dom: String = fiche(titulaire(m[1], m[2], m[4], m[3])).nom
	var ext: String = fiche(titulaire(m[1], m[2], m[5], m[3])).nom
	var envoi := coup_envoi(s, m[3])
	if maintenant() < envoi:
		var d := Time.get_datetime_dict_from_unix_time(envoi)
		return {"dom": dom, "ext": ext, "fini": false, "quand": "samedi %d/%02d à %d h" % [d.day, d.month, d.hour]}
	var r := rencontre(s, m[1], m[2], m[3], m[4], m[5])
	var feuilles: Array = []
	for f in r.joueurs:
		feuilles.append(f.map(func(x): return {"nom": x.nom, "pts": x.pts, "reb": x.reb, "pas": x.pd}))
	return {"dom": dom, "ext": ext, "score": r.score, "quarts": r.quarts, "feuilles": feuilles, "fini": true}


## Ouvre la salle du gymnase d'une commune (la scène du socle, fil de la salle), avec son match.
func ouvrir_salle(commune: String) -> void:
	const SALLE := "res://scripts/village/salle_basket.gd"
	if ResourceLoader.exists(SALLE):
		load(SALLE).ouvrir(commune, match_pour_salle(commune))


# ---------------------------------------------------------------- les clichés et la sauvegarde

## Va chercher au serveur les clichés qui manquent, du premier de la saison au dernier publié.
func telecharger() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	if http.request(SERVEUR + "?cliche=dernier") != OK:
		http.queue_free()
		return
	var r: Array = await http.request_completed
	http.queue_free()
	if r[0] != HTTPRequest.RESULT_SUCCESS or r[1] != 200:
		return
	var c = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())
	if c is Dictionary and c.has("id") and c.has("joueurs") and not cliches.has(c.id):
		garder(c)


## Garde un cliché sur l'appareil, et remet la pyramide au jour.
func garder(c: Dictionary) -> void:
	cliches[str(c.id)] = c
	if dossier != "":
		Portail.ecrire(dossier.path_join("basket/%s.json" % c.id), JSON.stringify(c))
	_matchs.clear()
	actualiser()
	change.emit()


func charger() -> void:
	if dossier == "":
		return
	var lu = Portail.lire_json(dossier.path_join(FICHIER))
	if lu is Dictionary and lu.has("niveaux"):
		saison = int(lu.get("saison", 1))
		niveaux = lu.niveaux
		clubs = lu.get("clubs", {})
		effectifs = lu.get("effectifs", {})
		historique = lu.get("historique", [])
	var d := DirAccess.open(dossier.path_join("basket"))
	if d:
		for f in d.get_files():
			var c = Portail.lire_json(dossier.path_join("basket").path_join(f))
			if c is Dictionary and c.has("id"):
				cliches[str(c.id)] = c


func sauver() -> void:
	if dossier == "":
		return
	Portail.ecrire(dossier.path_join(FICHIER), JSON.stringify({"saison": saison, "niveaux": niveaux, "clubs": clubs,
		"effectifs": effectifs, "historique": historique}))


func effacer() -> void:
	saison = 1
	niveaux = []
	clubs = {}
	effectifs = {}
	historique = []
	cliches = {}
	_matchs.clear()
