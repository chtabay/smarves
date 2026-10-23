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
## Au tirage du début de saison, les joueurs pris en haut du classement des notes ; les autres au milieu.
const ETOILES := 2
const FICHIER := "basket.json"
const NOMS_FIGURANTS := ["Basket-club %s", "Union basket %s", "Avenir basket %s", "Étoile basket %s",
	"Cercle basket %s", "Entente basket %s", "Espérance basket %s", "Jeunesse basket %s"]
const COULEURS := [["#14213d", "#d4a93a"], ["#7a1e2c", "#f4f1ea"], ["#0f5c4d", "#f2c94c"], ["#2b4c7e", "#e8eef7"],
	["#3d2c5c", "#f0c987"], ["#b4471f", "#1d1d1d"], ["#1d1d1d", "#e85d04"], ["#2d6a4f", "#ffffff"]]
## La commune de référence pour choisir les figurants les plus proches : Smarves, la même pour tous.
const ORIGINE_INSEE := "86263"
## L'argent du club : la masse salariale par journée qu'aucun club ne dépasse, la recette d'une journée
## (×0,7 à ×1,4 selon le classement), les neuf obligations (comme au football) et leur reprise.
const PLAFOND := 900
const RECETTE := 3000
const OBLIGATIONS := [500, 1000, 1500, 2250, 3000, 4000, 5000, 6250, 7500]
const TOTAL := 31000
const RACHAT := 0.8

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
var _marches := {}
## Le bureau lu au serveur (smarves_basket_bureau) : obligations [{club, rang, par, moi}], encheres [{saison,
## journee, groupe, joueur, club, montant, par, moi, quand}], liberations [{saison, journee, club, joueur}],
## consignes [{saison, journee, club, consigne}], noms [{club, nom, par}] (le nom choisi par le dirigeant).
var bureau := {"obligations": [], "encheres": [], "liberations": [], "consignes": [], "noms": []}
## Les obligations prises (true) ou rendues (false) ici que le serveur ne sait pas encore : club -> {rang: bool}.
var a_declarer := {}
## Les mises retenues sur les crédits, par lot « saison/journée/niveau/groupe/joueur ».
var retenues := {}
## La dernière journée dont le dividende est versé, club -> {s, j} ; et tout ce qui a été versé.
var dividendes := {}
var dividendes_total := 0
## Remplaçable par les tests : l'appel au serveur, (fonction, corps) -> {code, corps}.
var appel := Callable()


func _ready() -> void:
	if get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()):
		return
	charger()
	Registre.change.connect(actualiser)
	actualiser()
	telecharger.call_deferred()
	lire.call_deferred()


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
		_oublier()
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
## qui vient ; quand le bas n'a plus de figurant, un niveau s'ouvre dessous. Avant le premier coup d'envoi
## d'une saison, les nouveaux de la saison se replacent tous ensemble, dans l'ordre de leur id : un appareil
## qui les découvre un par un et un autre qui les découvre d'un coup les mettent aux mêmes places.
func _accueillir() -> bool:
	var nouveaux: Array = _gymnases().filter(func(e): return not clubs.has(e.commune))
	if nouveaux.is_empty():
		return false
	var a_placer: Array = []
	for e in nouveaux:
		var champs: Dictionary = e.get("champs", {})
		clubs[e.commune] = {"nom": str(champs.get("club", e.nom)), "court": str(champs.get("court", "")),
			"couleurs": champs.get("couleurs", COULEURS[Hasard.graine(e.commune) % COULEURS.size()]),
			"commune": e.commune, "salle": str(e.nom), "fondation": saison}
		a_placer.append(str(e.commune))
	var depuis := journee_jouee()
	if depuis == 0:
		for niv in niveaux:
			for grp in niv:
				for place in grp:
					var qui := str(place[-1][1])
					if place.size() > 1 and int(clubs.get(qui, {}).get("fondation", -1)) == saison and not a_placer.has(qui):
						a_placer.append(qui)
						place.pop_back()
		# Les niveaux du bas qui n'ont plus que des figurants se referment : ils se rouvriront s'il le faut.
		while niveaux.size() > 1 and niveaux[-1].all(func(grp): return grp.all(func(place): return str(place[-1][1]).begins_with("fig/"))):
			niveaux.pop_back()
	a_placer.sort()
	for qui in a_placer:
		var place := _place_de_figurant()
		if place.is_empty():
			var n := niveaux.size()
			niveaux.append([])
			for g in 1 << n:
				niveaux[n].append(_groupe_de_figurants(n, g))
			place = _place_de_figurant()
		niveaux[place[0]][place[1]][place[2]].append([depuis, qui])
	return true


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


## Le nom, le sigle et les couleurs d'un club ou d'un figurant. Le nom d'un club est celui que son
## dirigeant a choisi (renommer), sinon celui de sa structure « gymnase ».
func fiche(id: String) -> Dictionary:
	if clubs.has(id):
		var choisi := nom_choisi(id)
		if choisi == "":
			return clubs[id]
		var f: Dictionary = clubs[id].duplicate()
		f.nom = choisi
		return f
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
## Chaque club reçoit deux joueurs du haut du classement des notes et huit du milieu : sa masse salariale
## tient sous le plafond (PLAFOND), et le marché garde de bons joueurs libres. Rien à tirer tant que ce
## cliché-là n'est pas gardé (un autre donnerait d'autres effectifs que chez les voisins).
func _tirer_effectifs() -> bool:
	var c: Dictionary = cliches.get(id_cliche(saison, 1), {})
	if c.is_empty():
		return false
	var bouge := false
	var tous: Array = c.joueurs.keys()
	tous.sort_custom(func(a, b):
		var na: int = c.joueurs[a].note
		var nb: int = c.joueurs[b].note
		return na > nb if na != nb else a < b)
	var haut := tous.slice(0, TAILLE * ETOILES * 2)
	var milieu_debut := int(tous.size() * 0.3)
	var milieu := tous.slice(milieu_debut, milieu_debut + TAILLE * (EFFECTIF - ETOILES) * 2)
	for n in niveaux.size():
		for g in niveaux[n].size():
			if effectifs.has("%d/%d/0" % [n, g]):
				continue
			# Le vivier du groupe, mélangé par sa graine : deux groupes n'ont pas les mêmes joueurs aux mêmes
			# places, mais chacun tire équitablement.
			var h := Hasard.depuis(Hasard.graine("basket/effectifs/%d/%d/%d" % [saison, n, g]))
			var ordre := h.melanger(range(TAILLE))
			for p in TAILLE:
				effectifs["%d/%d/%d" % [n, g, p]] = []
			for r in EFFECTIF:
				var vivier: Array = haut if r < ETOILES else milieu
				var tour: int = r if r < ETOILES else r - ETOILES
				for k in TAILLE:
					var p: int = ordre[k if r % 2 == 0 else TAILLE - 1 - k]
					var i: int = mini((tour * TAILLE + k) * 2 + h.entier(0, 1), vivier.size() - 1)
					effectifs["%d/%d/%d" % [n, g, p]].append(vivier[i])
			bouge = true
	return bouge


## L'équipe de la place p pour la journée j, prête pour BasketMatch : les notes, le profil et la
## disponibilité du cliché de la semaine ; un joueur que le cliché ne connaît plus est indisponible.
func equipe(s: int, n: int, g: int, p: int, j: int) -> Dictionary:
	var c := cliche(id_cliche(s, j))
	var joueurs: Array = []
	for e in effectif(s, n, g, p, j):
		var code: String = e.code
		var f: Dictionary = c.get("joueurs", {}).get(code, {})
		if f.is_empty():
			joueurs.append({"code": code, "nom": code, "note": 1, "profil": [1, 1, 1, 1, 1], "dispo": false})
		else:
			joueurs.append({"code": code, "nom": f.nom, "note": int(f.note), "profil": f.profil, "dispo": bool(f.dispo),
				"club": f.club, "forme": int(f.get("forme", 0)), "derniere": f.get("derniere", {})})
	var qui := titulaire(n, g, p, j)
	return {"nom": fiche(qui).nom, "club": qui, "joueurs": joueurs, "consigne": consigne_de(s, j, qui)}


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
	_oublier()


# ---------------------------------------------------------------- le marché des vrais joueurs

## Le salaire d'un joueur par journée, d'après sa note au moment où le club le prend, et fixé pour la saison :
## il croît vite avec la note (une étoile à 85 coûte trois fois un joueur moyen à 55).
static func salaire_de(note: int) -> int:
	return maxi(10, int(round(pow(float(note), 3.0) / 40000.0)) * 10)


## Le prix de départ d'un joueur libre au marché : huit journées de son salaire.
static func prix_de(note: int) -> int:
	return maxi(50, salaire_de(note) * 8)


## Le surplus minimum sur une offre : 2 %, au moins 10 crédits, à la dizaine supérieure (le même calcul
## que le serveur, en entiers).
static func pas(x: int) -> int:
	return maxi(10, ((x + 499) / 500) * 10)


## La clôture des enchères qui servent à la journée j : le jeudi d'avant à 22 h, avant le cliché du vendredi.
static func cloture(s: int, j: int) -> int:
	return coup_envoi(s, j) - 46 * 3600


## La journée dont le marché est ouvert (la prochaine clôture), ou 0 quand la saison n'en a plus. La
## journée 1 n'en a pas : les effectifs se tirent avec le cliché de la veille.
func journee_du_marche() -> int:
	for j in range(2, JOURNEES + 1):
		if maintenant() < cloture(saison, j):
			return j
	return 0


## Les effectifs d'un groupe à la journée j, marché compris : {effectifs: [[{code, salaire, depuis}] × 8],
## liberes: [[{code, salaire}] × 8], ventes: [{code, club, place, montant, par, moi}]}. Le tirage de la
## saison, puis, avant chaque journée close, les joueurs libérés et les enchères : la plus grosse enchère
## d'abord, et pour chacune la meilleure offre d'un club du groupe qui a encore une place et la masse
## salariale pour le salaire. Les mêmes offres donnent les mêmes effectifs chez tout le monde.
func marche_du_groupe(s: int, n: int, g: int, j: int) -> Dictionary:
	var cle := "%d/%d/%d/%d" % [s, n, g, j]
	if _marches.has(cle):
		return _marches[cle]
	var m: Dictionary
	if j <= 1 or s != saison:
		m = {"effectifs": [], "liberes": [], "ventes": []}
		var c: Dictionary = cliches.get(id_cliche(s, 1), {})
		for p in TAILLE:
			var e: Array = []
			for code in effectifs.get("%d/%d/%d" % [n, g, p], []) if s == saison else []:
				e.append({"code": code, "salaire": salaire_de(int(c.get("joueurs", {}).get(code, {}).get("note", 1))), "depuis": 1})
			m.effectifs.append(e)
			m.liberes.append([])
	else:
		var avant: Dictionary = marche_du_groupe(s, n, g, j - 1)
		m = {"effectifs": [], "liberes": [], "ventes": []}
		for p in TAILLE:
			m.effectifs.append((avant.effectifs[p] as Array).duplicate(true))
			m.liberes.append((avant.liberes[p] as Array).duplicate(true))
		if maintenant() >= cloture(s, j):
			_clore_marche(m, s, n, g, j)
	_marches[cle] = m
	return m


func _clore_marche(m: Dictionary, s: int, n: int, g: int, j: int) -> void:
	var place_du := {}
	for p in TAILLE:
		place_du[titulaire(n, g, p, j)] = p
	for l in bureau.liberations:
		if int(l.saison) != s or int(l.journee) != j or not place_du.has(str(l.club)):
			continue
		var p: int = place_du[str(l.club)]
		for e in m.effectifs[p]:
			if e.code == str(l.joueur):
				m.effectifs[p].erase(e)
				m.liberes[p].append({"code": e.code, "salaire": int(e.salaire)})
				break
	var pris := {}
	for p in TAILLE:
		for e in m.effectifs[p]:
			pris[e.code] = true
	var groupe := "%d-%d" % [n, g]
	var lots := {}
	for o in bureau.encheres:
		if int(o.saison) == s and int(o.journee) == j and str(o.groupe) == groupe and not pris.has(str(o.joueur)):
			if not lots.has(str(o.joueur)):
				lots[str(o.joueur)] = []
			lots[str(o.joueur)].append(o)
	var ordre: Array = lots.keys()
	for code in ordre:
		lots[code].sort_custom(func(a, b): return int(a.montant) > int(b.montant) if int(a.montant) != int(b.montant) else str(a.quand) < str(b.quand))
	ordre.sort_custom(func(a, b):
		var ma: int = lots[a][0].montant
		var mb: int = lots[b][0].montant
		return ma > mb if ma != mb else a < b)
	var vente := cliche(id_cliche(s, j - 1))
	for code in ordre:
		var note := int(vente.get("joueurs", {}).get(code, {}).get("note", 0))
		if note <= 0:
			continue
		var salaire := salaire_de(note)
		for o in lots[code]:
			if int(o.montant) < prix_de(note):
				break
			if not place_du.has(str(o.club)) or str(o.club).begins_with("fig/"):
				continue
			var p: int = place_du[str(o.club)]
			if (m.effectifs[p] as Array).size() >= EFFECTIF or _masse(m, p) + salaire > PLAFOND:
				continue
			m.effectifs[p].append({"code": code, "salaire": salaire, "depuis": j})
			m.ventes.append({"code": code, "club": str(o.club), "place": p, "montant": int(o.montant), "par": str(o.get("par", "")), "moi": bool(o.get("moi", false))})
			break


static func _masse(m: Dictionary, p: int) -> int:
	var t := 0
	for e in m.effectifs[p]:
		t += int(e.salaire)
	for e in m.liberes[p]:
		t += int(e.salaire) / 2
	return t


## L'effectif d'une place à la journée j : [{code, salaire, depuis}].
func effectif(s: int, n: int, g: int, p: int, j: int) -> Array:
	return marche_du_groupe(s, n, g, j).effectifs[p]


## Ce qu'un club paie par journée à la journée j : ses joueurs, et la moitié du salaire de ceux qu'il a libérés.
func masse_salariale(club: String, j := -1) -> int:
	var ici := place_de(club)
	if ici.is_empty():
		return 0
	if j < 0:
		j = maxi(1, journee_jouee())
	return _masse(marche_du_groupe(saison, ici[0], ici[1], j), ici[2])


## Les effectifs du groupe d'un club sont-ils tirés ? Ils le sont avec le cliché du vendredi d'avant la
## première journée ; avant, le club n'a personne et le marché attend.
func tirage_fait(club: String) -> bool:
	var ici := place_de(club)
	return not ici.is_empty() and effectifs.has("%d/%d/0" % [ici[0], ici[1]])


## Le vendredi soir du tirage de la saison (secondes locales) : celui du cliché de la première journée.
func quand_tirage() -> int:
	return coup_envoi(saison, 1) - 86400


## Les joueurs libres du groupe d'un club pour le marché ouvert : [{code, nom, club, comp, poste, note, forme,
## prix, salaire, offre, meneur, moi}], les meilleures notes d'abord. « offre » est la meilleure offre posée.
func joueurs_libres(club: String) -> Array:
	var ici := place_de(club)
	var j := journee_du_marche()
	if ici.is_empty() or j == 0 or not tirage_fait(club):
		return []
	var m := marche_du_groupe(saison, ici[0], ici[1], j - 1)
	var pris := {}
	for p in TAILLE:
		for e in m.effectifs[p]:
			pris[e.code] = true
	var c := cliche(id_cliche(saison, j - 1))
	var out: Array = []
	for code in c.get("joueurs", {}):
		if pris.has(code):
			continue
		var f: Dictionary = c.joueurs[code]
		var lot := offres_du_lot(saison, j, ici[0], ici[1], code)
		var tete: Dictionary = lot[0] if not lot.is_empty() else {}
		out.append({"code": code, "nom": f.nom, "club": f.club, "comp": f.get("comp", ""), "poste": f.get("poste", ""),
			"note": int(f.note), "forme": int(f.get("forme", 0)), "derniere": f.get("derniere", {}), "prix": prix_de(int(f.note)),
			"salaire": salaire_de(int(f.note)), "offre": int(tete.get("montant", 0)), "meneur": str(tete.get("club", "")), "moi": bool(tete.get("moi", false))})
	out.sort_custom(func(a, b): return a.note > b.note if a.note != b.note else a.code < b.code)
	return out


## Les offres posées sur un joueur pour la journée j dans un groupe, la meilleure d'abord.
func offres_du_lot(s: int, j: int, n: int, g: int, code: String) -> Array:
	var groupe := "%d-%d" % [n, g]
	var out: Array = bureau.encheres.filter(func(o): return int(o.saison) == s and int(o.journee) == j and str(o.groupe) == groupe and str(o.joueur) == code)
	out.sort_custom(func(a, b): return int(a.montant) > int(b.montant) if int(a.montant) != int(b.montant) else str(a.quand) < str(b.quand))
	return out


## La consigne d'un club pour la journée j : celle posée pour j, sinon la dernière d'avant dans la saison,
## sinon « titulaires ».
func consigne_de(s: int, j: int, club: String) -> String:
	var meilleure := 0
	var quoi := "titulaires"
	for c in bureau.consignes:
		if int(c.saison) == s and str(c.club) == club and int(c.journee) <= j and int(c.journee) > meilleure:
			meilleure = int(c.journee)
			quoi = str(c.consigne)
	return quoi


# ---------------------------------------------------------------- les obligations du club

## La valeur d'une obligation, par son rang (1 à 9) ; les neuf font TOTAL.
static func valeur(rang: int) -> int:
	return int(OBLIGATIONS[clampi(rang, 1, OBLIGATIONS.size()) - 1])


## Qui tient une obligation : {nom, moi}, ou {} si elle est libre. Ce qu'on vient de faire ici compte avant
## que le serveur le sache.
func porteur(club: String, rang: int) -> Dictionary:
	var attente = (a_declarer.get(club, {}) as Dictionary).get(str(rang))
	if attente != null:
		return {"nom": "vous", "moi": true} if bool(attente) else {}
	for o in bureau.obligations:
		if str(o.club) == club and int(o.rang) == rang:
			return {"nom": "vous" if bool(o.get("moi", false)) else str(o.get("par", "")), "moi": bool(o.get("moi", false))}
	return {}


func mes_obligations(club: String) -> Array:
	var out: Array = []
	for r in range(OBLIGATIONS.size(), 0, -1):
		if bool(porteur(club, r).get("moi", false)):
			out.append(r)
	return out


## Les porteurs d'un club, la plus grosse somme d'abord : [{nom, investi, rangs, moi}]. À égalité, soi d'abord.
func actionnaires(club: String) -> Array:
	var par_nom := {}
	for r in range(1, OBLIGATIONS.size() + 1):
		var p := porteur(club, r)
		if p.is_empty():
			continue
		if not par_nom.has(p.nom):
			par_nom[p.nom] = {"nom": p.nom, "investi": 0, "rangs": [], "moi": bool(p.moi)}
		par_nom[p.nom].investi += valeur(r)
		par_nom[p.nom].rangs.append(r)
	var out: Array = par_nom.values()
	out.sort_custom(func(x, y): return x.investi > y.investi if x.investi != y.investi else (x.moi and not y.moi))
	return out


func investi(club: String) -> int:
	var t := 0
	for r in mes_obligations(club):
		t += valeur(r)
	return t


## Qui dirige le club (le mercato, la consigne) : sans porteur, tout le monde ; sinon la plus grosse somme
## investie, et chacun à égalité. Le serveur en juge de même (basket.dirige).
func peut_decider(club: String) -> bool:
	var a := actionnaires(club)
	return a.is_empty() or investi(club) >= int(a[0].investi)


func phrase_actionnaires(club: String) -> String:
	var a := actionnaires(club)
	if a.is_empty():
		return "Personne ne tient d'obligation du club : le bureau est ouvert à tous."
	var morceaux: Array = []
	for x in a:
		morceaux.append("%s %s" % ["vous" if x.moi else x.nom, Game.fmt(int(x.investi))])
	var qui := "c'est vous qui dirigez le club" if peut_decider(club) else "c'est %s qui dirige le club" % a[0].nom
	return "Au capital : %s crédits ; %s." % [", ".join(morceaux), qui]


## Ce que le classement fait à la recette : ×1,4 en tête, ×0,7 en queue, ×1 tant que rien n'est joué.
func recette_facteur(club: String, j := -1) -> float:
	var ici := place_de(club)
	if j < 0:
		j = journee_jouee()
	if ici.is_empty() or j <= 0:
		return 1.0
	var cl := classement(saison, ici[0], ici[1], j)
	for i in cl.size():
		if cl[i].club == club:
			return 0.7 + 0.7 * float(TAILLE - 1 - i) / float(TAILLE - 1)
	return 1.0


## Le dividende d'une obligation pour la journée j : la recette du club (RECETTE, selon le classement), moins
## ses salaires, partagée au prorata de la valeur de l'obligation sur les neuf.
func dividende(club: String, rang: int, j: int) -> int:
	var benefice := RECETTE * recette_facteur(club, j) - masse_salariale(club, j)
	return int(round(maxf(0.0, benefice) * valeur(rang) / float(TOTAL)))


## Prend une obligation libre, de ses crédits : {ok: true} ou {ok: false, raison} « club », « prise »,
## « credits ». Elle vaut tout de suite ici et part au serveur, qui a le dernier mot.
func prendre(club: String, rang: int) -> Dictionary:
	if not clubs.has(club) or rang < 1 or rang > OBLIGATIONS.size():
		return {"ok": false, "raison": "club"}
	if not porteur(club, rang).is_empty():
		return {"ok": false, "raison": "prise"}
	if Game.credits < valeur(rang):
		return {"ok": false, "raison": "credits"}
	Game.credits -= valeur(rang)
	Game.changed.emit()
	if not dividendes.has(club):
		dividendes[club] = {"s": saison, "j": journee_jouee()}
	_declarer(club, rang, true)
	return {"ok": true}


## Rend une obligation, reprise à RACHAT de sa valeur : {ok: true, montant} ou {ok: false, raison: « absente »}.
func rendre(club: String, rang: int) -> Dictionary:
	if not mes_obligations(club).has(rang):
		return {"ok": false, "raison": "absente"}
	var montant := int(round(valeur(rang) * RACHAT))
	Game.credits += montant
	Game.changed.emit()
	_declarer(club, rang, false)
	return {"ok": true, "montant": montant}


func _declarer(club: String, rang: int, prise: bool) -> void:
	if not a_declarer.has(club):
		a_declarer[club] = {}
	a_declarer[club][str(rang)] = prise
	sauver()
	change.emit()
	envoyer()


## Les dividendes que les journées jouées depuis le dernier versement doivent aux obligations d'ici :
## [{club, j, montant}].
func dividendes_dus() -> Array:
	var out: Array = []
	for club in clubs:
		var rangs := mes_obligations(club)
		if rangs.is_empty():
			continue
		var marque: Dictionary = dividendes.get(club, {"s": saison, "j": journee_jouee()})
		var depuis: int = int(marque.j) if int(marque.s) == saison else 0
		for j in range(depuis + 1, journee_jouee() + 1):
			var t := 0
			for r in rangs:
				t += dividende(club, r, j)
			out.append({"club": club, "j": j, "montant": t})
	return out


func verser_dividendes() -> int:
	var t := 0
	for d in dividendes_dus():
		t += int(d.montant)
		dividendes[d.club] = {"s": saison, "j": int(d.j)}
	if t > 0:
		Game.credits += t
		dividendes_total += t
		Game.changed.emit()
	sauver()
	return t


# ---------------------------------------------------------------- les actes du bureau

## Le nom qu'a choisi le dirigeant d'un club (« » : aucun).
func nom_choisi(club: String) -> String:
	for x in bureau.get("noms", []):
		if str(x.get("club", "")) == club:
			return str(x.get("nom", ""))
	return ""


## Un nom de club acceptable : de 3 à 40 caractères, lettres (accents compris), chiffres, espaces,
## apostrophes, tirets, points et « & ». Le serveur applique la même règle.
static func nom_valide(nom: String) -> bool:
	var r := RegEx.create_from_string("^[A-Za-zÀ-ÖØ-öø-ÿŒœ0-9 '’.&-]{3,40}$")
	return r.search(nom) != null and nom.strip_edges() == nom and not nom.contains("  ")


## Renomme le club (demande de Guillaume du 23 octobre 2026) : seul un porteur de parts qui le dirige le
## peut, et le nouveau nom vaut pour tous les joueurs. {ok: true} ou {ok: false, raison} « compte », « parts »,
## « club », « detenir » (aucune part), « nom » (nom refusé), « reseau ».
func renommer(club: String, nom: String) -> Dictionary:
	nom = " ".join(nom.strip_edges().split(" ", false))
	var raison := refus_bureau(club)
	if raison == "" and investi(club) <= 0:
		raison = "detenir"
	if raison == "" and not nom_valide(nom):
		raison = "nom"
	if raison != "":
		return {"ok": false, "raison": raison}
	var r: Dictionary = await _appeler("smarves_basket_nommer", {"p_club": club, "p_nom": nom})
	if r.code != 200 or not r.corps is Dictionary or r.corps.has("erreur"):
		return {"ok": false, "raison": "reseau" if r.code != 200 or not r.corps is Dictionary else "compte"}
	if not bool(r.corps.get("ok", false)):
		lire()
		return {"ok": false, "raison": str(r.corps.get("raison", "parts"))}
	bureau.noms = (bureau.noms as Array).filter(func(x): return str(x.get("club", "")) != club)
	bureau.noms.append({"club": club, "nom": nom, "par": "vous"})
	sauver()
	change.emit()
	return {"ok": true}


## Ce qui empêche le bureau d'agir pour un club, ou « » : « compte » (pas connecté), « parts » (un autre
## dirige), « club » (pas au championnat).
func refus_bureau(club: String) -> String:
	if place_de(club).is_empty() or not clubs.has(club):
		return "club"
	if not connecte():
		return "compte"
	if not peut_decider(club):
		return "parts"
	return ""


## Enchérit sur un joueur libre pour la journée du marché : {ok: true} ou {ok: false, raison} « compte »,
## « parts », « club », « ferme », « pris », « bas », « credits », « reseau ».
func encherir(club: String, code: String, montant: int) -> Dictionary:
	var raison := refus_bureau(club)
	var j := journee_du_marche()
	if raison == "" and j == 0:
		raison = "ferme"
	var libre: Array = joueurs_libres(club).filter(func(x): return x.code == code) if raison == "" else []
	if raison == "" and libre.is_empty():
		raison = "pris"
	if raison == "":
		var mini_ := maxi(int(libre[0].prix), int(libre[0].offre) + pas(int(libre[0].offre)) if int(libre[0].offre) > 0 else 0)
		if montant < mini_:
			raison = "bas"
	var ici := place_de(club)
	var lot := "%d/%d/%d/%d/%s" % [saison, j, ici[0] if not ici.is_empty() else 0, ici[1] if not ici.is_empty() else 0, code]
	if raison == "" and Game.credits + int(retenues.get(lot, 0)) < montant:
		raison = "credits"
	if raison != "":
		return {"ok": false, "raison": raison}
	var r: Dictionary = await _appeler("smarves_basket_encherir", {"p_saison": saison, "p_journee": j, "p_groupe": "%d-%d" % [ici[0], ici[1]],
		"p_joueur": code, "p_club": club, "p_montant": montant})
	if r.code != 200 or not r.corps is Dictionary:
		return {"ok": false, "raison": "reseau"}
	if not bool(r.corps.get("ok", false)):
		lire()
		return {"ok": false, "raison": str(r.corps.get("raison", "compte"))}
	bureau.encheres.append({"saison": saison, "journee": j, "groupe": "%d-%d" % [ici[0], ici[1]], "joueur": code, "club": club,
		"montant": montant, "par": "vous", "moi": true, "quand": str(r.corps.get("quand", "9999"))})
	Game.credits -= montant - int(retenues.get(lot, 0))
	retenues[lot] = montant
	Game.changed.emit()
	_oublier()
	sauver()
	change.emit()
	return {"ok": true}


## Libère un joueur de l'effectif à la prochaine clôture : il compte encore pour la moitié de son salaire
## jusqu'à la fin de la saison. {ok: true} ou {ok: false, raison} « compte », « parts », « club », « ferme »,
## « absent », « reseau ».
func liberer(club: String, code: String) -> Dictionary:
	var raison := refus_bureau(club)
	var j := journee_du_marche()
	if raison == "" and j == 0:
		raison = "ferme"
	if raison == "":
		var ici := place_de(club)
		if not effectif(saison, ici[0], ici[1], ici[2], j - 1).any(func(e): return e.code == code):
			raison = "absent"
	if raison != "":
		return {"ok": false, "raison": raison}
	var r: Dictionary = await _appeler("smarves_basket_liberer", {"p_saison": saison, "p_journee": j, "p_club": club, "p_joueur": code})
	if r.code != 200 or not r.corps is Dictionary:
		return {"ok": false, "raison": "reseau"}
	if not bool(r.corps.get("ok", false)):
		lire()
		return {"ok": false, "raison": str(r.corps.get("raison", "compte"))}
	bureau.liberations.append({"saison": saison, "journee": j, "club": club, "joueur": code})
	_oublier()
	sauver()
	change.emit()
	return {"ok": true}


## Les joueurs que le club libère à la prochaine clôture.
func liberations_prevues(club: String) -> Array:
	var j := journee_du_marche()
	return bureau.liberations.filter(func(l): return int(l.saison) == saison and int(l.journee) == j and str(l.club) == club).map(func(l): return str(l.joueur))


## Pose la consigne du prochain match (« titulaires » ou « rotation ») : {ok: true} ou {ok: false, raison}.
func poser_consigne(club: String, consigne: String) -> Dictionary:
	var raison := refus_bureau(club)
	var j := mini(journee_jouee() + 1, JOURNEES)
	if raison == "" and (not consigne in ["titulaires", "rotation"] or maintenant() >= coup_envoi(saison, j)):
		raison = "ferme"
	if raison != "":
		return {"ok": false, "raison": raison}
	var r: Dictionary = await _appeler("smarves_basket_consigne", {"p_saison": saison, "p_journee": j, "p_club": club, "p_consigne": consigne})
	if r.code != 200 or not r.corps is Dictionary:
		return {"ok": false, "raison": "reseau"}
	if not bool(r.corps.get("ok", false)):
		return {"ok": false, "raison": str(r.corps.get("raison", "compte"))}
	bureau.consignes = bureau.consignes.filter(func(c): return not (int(c.saison) == saison and int(c.journee) == j and str(c.club) == club))
	bureau.consignes.append({"saison": saison, "journee": j, "club": club, "consigne": consigne})
	_oublier()
	sauver()
	change.emit()
	return {"ok": true}


# ---------------------------------------------------------------- le serveur du bureau

func _compte() -> Node:
	return get_node_or_null("/root/Compte")


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


## Relit le bureau au serveur (public : les obligations, les offres, les libérations, les consignes de tous
## les clubs), puis déclare les obligations d'ici qu'il ne sait pas encore.
func lire() -> void:
	if not appel.is_valid() and (get_tree().get_script() != null or "--capture" in " ".join(OS.get_cmdline_user_args()) or _compte() == null):
		return
	var r: Dictionary = await _appeler("smarves_basket_bureau", {"p_saison": saison})
	if r.code == 200 and r.corps is Dictionary:
		appliquer(r.corps)
		envoyer()


## L'état lu au serveur remplace ce qu'on en savait ; puis les mises se règlent.
func appliquer(corps: Dictionary) -> void:
	for k in ["obligations", "encheres", "liberations", "consignes", "noms"]:
		bureau[k] = (corps.get(k, []) as Array).filter(func(x): return x is Dictionary)
	_oublier()
	_regler()
	sauver()
	change.emit()


## Dit au serveur les obligations prises et rendues ici. Une prise qu'il refuse (un autre l'a eue avant)
## est remboursée.
func envoyer() -> void:
	if not connecte() or (not appel.is_valid() and get_tree().get_script() != null):
		return
	for club in a_declarer.keys():
		for rang in (a_declarer[club] as Dictionary).keys():
			var prise: bool = a_declarer[club][rang]
			var r: Dictionary = await _appeler("smarves_basket_obligation_prendre" if prise else "smarves_basket_obligation_rendre", {"p_club": club, "p_rang": int(rang)})
			if r.code != 200 or not r.corps is Dictionary or r.corps.has("erreur"):
				continue
			if prise and not bool(r.corps.get("ok", false)) and str(r.corps.get("raison", "")) == "prise":
				Game.credits += valeur(int(rang))
				Game.changed.emit()
			bureau.obligations = bureau.obligations.filter(func(o): return not (str(o.club) == club and int(o.rang) == int(rang) and bool(o.get("moi", false))))
			if prise and bool(r.corps.get("ok", false)):
				bureau.obligations.append({"club": club, "rang": int(rang), "par": "vous", "moi": true})
			a_declarer[club].erase(rang)
			if a_declarer[club].is_empty():
				a_declarer.erase(club)
	sauver()
	change.emit()


## Les mises retenues se règlent : rendue quand une meilleure offre passe devant ou que le joueur va
## ailleurs à la clôture ; gardée (le joueur est payé) quand on l'emporte.
func _regler() -> void:
	for lot in retenues.keys():
		var morceaux: PackedStringArray = lot.split("/")
		var s := int(morceaux[0])
		var j := int(morceaux[1])
		var n := int(morceaux[2])
		var g := int(morceaux[3])
		var code := morceaux[4]
		var montant := int(retenues[lot])
		var offres := offres_du_lot(s, j, n, g, code)
		var en_tete: bool = not offres.is_empty() and bool(offres[0].get("moi", false)) and int(offres[0].montant) == montant
		if s != saison or maintenant() >= cloture(s, j):
			var gagne: bool = s == saison and n < niveaux.size() and g < niveaux[n].size() and \
				(marche_du_groupe(s, n, g, j).ventes as Array).any(func(v): return v.code == code and bool(v.moi) and int(v.montant) == montant)
			if not gagne:
				Game.credits += montant
			retenues.erase(lot)
		elif not en_tete:
			Game.credits += montant
			retenues.erase(lot)
	Game.changed.emit()


func _oublier() -> void:
	_marches.clear()
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

## Va chercher au serveur les clichés qui manquent : le dernier publié, puis ceux des vendredis de la
## saison qui ne sont pas gardés (le tirage, les matchs et le marché veulent chacun le leur exactement).
func telecharger() -> void:
	var dernier := await _lire_cliche("dernier")
	if dernier.is_empty():
		return
	for j in range(1, JOURNEES + 1):
		var id := id_cliche(saison, j)
		if id >= str(dernier.id):
			break
		if not cliches.has(id):
			await _lire_cliche(id)


func _lire_cliche(id: String) -> Dictionary:
	var http := HTTPRequest.new()
	add_child(http)
	if http.request(SERVEUR + "?cliche=" + id) != OK:
		http.queue_free()
		return {}
	var r: Array = await http.request_completed
	http.queue_free()
	if r[0] != HTTPRequest.RESULT_SUCCESS or r[1] != 200:
		return {}
	var c = JSON.parse_string((r[3] as PackedByteArray).get_string_from_utf8())
	if not (c is Dictionary and c.has("id") and c.has("joueurs")):
		return {}
	if not cliches.has(str(c.id)):
		garder(c)
	return c


## Garde un cliché sur l'appareil, et remet la pyramide au jour.
func garder(c: Dictionary) -> void:
	cliches[str(c.id)] = c
	if dossier != "":
		Portail.ecrire(dossier.path_join("basket/%s.json" % c.id), JSON.stringify(c))
	_oublier()
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
		bureau = lu.get("bureau", bureau)
		# Une partie d'avant les noms choisis (23 octobre 2026).
		if not bureau.has("noms"):
			bureau.noms = []
		a_declarer = lu.get("a_declarer", {})
		retenues = lu.get("retenues", {})
		dividendes = lu.get("dividendes", {})
		dividendes_total = int(lu.get("dividendes_total", 0))
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
		"effectifs": effectifs, "historique": historique, "bureau": bureau, "a_declarer": a_declarer, "retenues": retenues,
		"dividendes": dividendes, "dividendes_total": dividendes_total}))


func effacer() -> void:
	saison = 1
	niveaux = []
	clubs = {}
	effectifs = {}
	historique = []
	cliches = {}
	bureau = {"obligations": [], "encheres": [], "liberations": [], "consignes": [], "noms": []}
	a_declarer = {}
	retenues = {}
	dividendes = {}
	dividendes_total = 0
	_oublier()
